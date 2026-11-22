"""
PT HTI Tool & Equipment Inventory System (HTI-TEIS)
Baseline Excel Parser for Sheet 'Nov 25' of '2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx'.

Menangani seluruh 4 edge-case nyata pada data PT HTI:
1. Header kategori 'TOOLS' muncul 2 kali (baris 52 & 152) -> digabung ke TLS.
2. Typo 'ELECTRICAL & PENEUMATIC TOOLS' (baris 168) -> dinormalisasi ke 'ELECTRICAL & PNEUMATIC TOOLS' (ELP).
3. Variasi kapitalisasi kategori & 16 variasi penulisan satuan + 2 baris tanpa unit (baris 273-274 -> PCS).
4. Ekstraksi multi-job code dari kolom REMARKS (menangani typo seperti '1 d Job', '1p-89--037', '1p-31- 180').
"""

from __future__ import annotations

import re
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

CATEGORIES_MASTER: List[Tuple[str, str]] = [
    ("EQP", "EQUIPMENT"),
    ("TLS", "TOOLS"),
    ("ELP", "ELECTRICAL & PNEUMATIC TOOLS"),
    ("MSR", "MEASURING TOOLS"),
    ("HND", "HAND TOOLS"),
    ("LFT", "LIFTING AND PULLING TOOLS"),
    ("WHI", "INVENTARIS WAREHOUSE"),
    ("QCT", "QUALITY CONTROL (QC) TOOLS"),
    ("SFT", "INVENTARIS SAFETY"),
]

CATEGORY_ALIAS_TO_CODE: Dict[str, str] = {
    "EQUIPMENT": "EQP",
    "TOOLS": "TLS",
    "ELECTRICAL & PNEUMATIC TOOLS": "ELP",
    "ELECTRICAL & PENEUMATIC TOOLS": "ELP",  # Typo asli di Excel baris 168
    "MEASURING TOOLS": "MSR",
    "HAND TOOLS": "HND",
    "LIFTING AND PULLING TOOLS": "LFT",
    "INVENTARIS WAREHOUSE": "WHI",
    "QUALITY CONTROL (QC) TOOLS": "QCT",
    "INVENTARIS SAFETY": "SFT",
}

LOCATIONS_MASTER: List[Tuple[str, str, str]] = [
    ("WH-1", "Warehouse 1", "WAREHOUSE"),
    ("WH-2", "Warehouse 2", "WAREHOUSE"),
    ("SITE-PTS", "Site PTS", "SITE"),
    ("SITE-NON-PTS", "Site Non PTS", "SITE"),
]

UNIT_STANDARD_MAP: Dict[str, str] = {
    "UNIT": "UNIT",
    "UNT": "UNIT",
    "PCS": "PCS",
    "PC": "PCS",
    "SET": "SET",
    "SETS": "SET",
    "ROLL": "ROLL",
    "ROL": "ROLL",
    "EA": "EA",
    "EACH": "EA",
    "PAIR": "PAIR",
    "PSG": "PAIR",
    "BOX": "BOX",
    "BTL": "BTL",
    "BOTOL": "BTL",
}

# Kolom lokasi pada sheet 'Nov 25' (1-indexed: B=2, C=3, D=4, E=5, I=9..T=20, X=24)
LOCATION_COLUMNS: List[Tuple[str, int, int, int]] = [
    ("WH-1", 9, 10, 11),
    ("SITE-NON-PTS", 12, 13, 14),
    ("WH-2", 15, 16, 17),
    ("SITE-PTS", 18, 19, 20),
]

# Pola kode proyek PT HTI (misal: 1p-31-180, 1p-89--037, 1p-31- 180)
JOB_CODE_PATTERN = re.compile(r"\b(\d+[a-zA-Z]\s*-\s*\d+\s*-+\s*\d+)\b")


@dataclass
class ParsedStock:
    location_code: str
    qty_good: int
    qty_service: int
    qty_broken: int
    job_code: Optional[str] = None
    remarks: Optional[str] = None

    @property
    def total(self) -> int:
        return self.qty_good + self.qty_service + self.qty_broken


@dataclass
class ParsedItem:
    excel_row: int
    item_code: str
    category_code: str
    description: str
    specification: Optional[str]
    unit: str
    raw_remarks: Optional[str]
    extracted_job_codes: Optional[str]
    stocks: List[ParsedStock] = field(default_factory=list)


@dataclass
class ParsedDataset:
    categories: List[Tuple[str, str]]
    locations: List[Tuple[str, str, str]]
    items: List[ParsedItem]
    warnings: List[str] = field(default_factory=list)


def normalize_unit(raw_unit: Optional[object], excel_row: int, description: str, warnings: List[str]) -> str:
    if raw_unit is None or str(raw_unit).strip() == "":
        warnings.append(
            f"Row {excel_row} ('{description}'): kolom Unit kosong -> fallback ke standar 'PCS'."
        )
        return "PCS"
    cleaned = str(raw_unit).strip().upper()
    if cleaned not in UNIT_STANDARD_MAP:
        raise ValueError(f"Row {excel_row}: satuan tidak dikenal '{raw_unit}' (tambahkan ke UNIT_STANDARD_MAP).")
    return UNIT_STANDARD_MAP[cleaned]


def extract_job_codes(raw_remarks: Optional[str]) -> Optional[str]:
    if not raw_remarks:
        return None
    matches = JOB_CODE_PATTERN.findall(raw_remarks)
    if not matches:
        return None
    seen = []
    for m in matches:
        # Normalisasi spasi & double hyphen: '1p-89--037' -> '1P-89-037', '1p-31- 180' -> '1P-31-180'
        normalized = re.sub(r"\s+", "", m).upper()
        normalized = re.sub(r"-{2,}", "-", normalized)
        if normalized not in seen:
            seen.append(normalized)
    joined = ", ".join(seen)
    return joined[:255] if joined else None


def to_non_negative_int(val: Optional[object], excel_row: int, col_label: str) -> int:
    if val is None:
        return 0
    if isinstance(val, bool):
        raise ValueError(f"Row {excel_row} ({col_label}): nilai boolean tidak valid ({val!r}).")
    if isinstance(val, (int, float)):
        num = int(round(val))
    else:
        s = str(val).strip()
        if s == "" or s == "-":
            return 0
        num = int(round(float(s)))
    if num < 0:
        raise ValueError(f"Row {excel_row} ({col_label}): kuantitas negatif terdeteksi ({num}).")
    return num


def _col_letters_to_index(col_str: str) -> int:
    idx = 0
    for ch in col_str:
        idx = idx * 26 + (ord(ch.upper()) - ord("A") + 1)
    return idx


def _read_sheet_rows_stdlib(xlsx_path: Path, sheet_name: str) -> Dict[int, Dict[int, object]]:
    """Fallback pembaca .xlsx berbasis stdlib XML bila openpyxl belum terpasang."""
    ns = {
        "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
        "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    }
    with zipfile.ZipFile(xlsx_path) as zf:
        shared_strings: List[str] = []
        if "xl/sharedStrings.xml" in zf.namelist():
            ss_root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            for si in ss_root.findall("m:si", ns):
                shared_strings.append("".join(t.text or "" for t in si.findall(".//m:t", ns)))

        wb_root = ET.fromstring(zf.read("xl/workbook.xml"))
        rels_root = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        rel_map = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels_root}

        target_path = None
        for sh in wb_root.findall(".//m:sheet", ns):
            if sh.attrib["name"].strip().lower() == sheet_name.strip().lower():
                rid = sh.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]
                target = rel_map[rid].lstrip("/")
                target_path = target if target.startswith("xl/") else f"xl/{target}"
                break

        if not target_path:
            raise ValueError(f"Sheet '{sheet_name}' tidak ditemukan pada {xlsx_path}.")

        ws_root = ET.fromstring(zf.read(target_path))
        rows: Dict[int, Dict[int, object]] = defaultdict(dict)
        for row_el in ws_root.findall(".//m:sheetData/m:row", ns):
            r_num = int(row_el.attrib["r"])
            for c_el in row_el.findall("m:c", ns):
                ref = c_el.attrib["r"]
                m = re.match(r"([A-Z]+)(\d+)", ref)
                if not m:
                    continue
                c_idx = _col_letters_to_index(m.group(1))
                c_type = c_el.attrib.get("t")
                v_el = c_el.find("m:v", ns)
                is_el = c_el.find("m:is", ns)
                val: Optional[object] = None
                if c_type == "s" and v_el is not None and v_el.text is not None:
                    val = shared_strings[int(v_el.text)]
                elif c_type == "inlineStr" and is_el is not None:
                    val = "".join(t.text or "" for t in is_el.findall(".//m:t", ns))
                elif v_el is not None and v_el.text is not None:
                    raw = v_el.text
                    try:
                        f = float(raw)
                        val = int(f) if f.is_integer() else f
                    except ValueError:
                        val = raw
                if val is not None and str(val).strip() != "":
                    rows[r_num][c_idx] = val
        return rows


def _read_sheet_rows(xlsx_path: Path, sheet_name: str) -> Dict[int, Dict[int, object]]:
    try:
        import openpyxl  # type: ignore

        wb = openpyxl.load_workbook(xlsx_path, data_only=True, read_only=True)
        matched = next((s for s in wb.sheetnames if s.strip().lower() == sheet_name.strip().lower()), None)
        if not matched:
            raise ValueError(f"Sheet '{sheet_name}' tidak ditemukan pada {xlsx_path}.")
        ws = wb[matched]
        rows: Dict[int, Dict[int, object]] = {}
        for r_idx, row_vals in enumerate(ws.iter_rows(min_row=1, max_col=26, values_only=True), start=1):
            row_dict = {c_idx: val for c_idx, val in enumerate(row_vals, start=1) if val is not None and str(val).strip() != ""}
            if row_dict:
                rows[r_idx] = row_dict
        wb.close()
        return rows
    except ImportError:
        return _read_sheet_rows_stdlib(xlsx_path, sheet_name)


def parse_nov25_excel(xlsx_path: Path, sheet_name: str = "Nov 25") -> ParsedDataset:
    rows = _read_sheet_rows(xlsx_path, sheet_name)
    warnings: List[str] = []
    items: List[ParsedItem] = []
    category_seq: Dict[str, int] = defaultdict(int)
    current_cat_code: Optional[str] = None

    for r_num in sorted(rows.keys()):
        if r_num < 9:
            continue
        row = rows[r_num]
        col_b = row.get(2)
        col_c = row.get(3)

        # Berhenti saat mencapai blok tanda tangan footer ("Prepared By")
        if col_c is not None and str(col_c).strip().lower() == "prepared by":
            break

        # Deteksi baris header kategori (kolom B kosong, kolom C berisi nama kategori)
        if col_b is None and col_c is not None:
            cat_text = " ".join(str(col_c).strip().split()).upper()
            if cat_text in CATEGORY_ALIAS_TO_CODE:
                new_code = CATEGORY_ALIAS_TO_CODE[cat_text]
                if cat_text == "ELECTRICAL & PENEUMATIC TOOLS":
                    warnings.append(
                        f"Row {r_num}: normalisasi typo kategori '{col_c}' -> 'ELECTRICAL & PNEUMATIC TOOLS' (ELP)."
                    )
                if current_cat_code == new_code and new_code == "TLS":
                    warnings.append(
                        f"Row {r_num}: header kategori duplikat 'TOOLS' digabung ke kategori 'TLS'."
                    )
                current_cat_code = new_code
                continue

        # Abaikan baris kosong atau tanpa deskripsi
        if col_c is None:
            continue
        if current_cat_code is None:
            raise ValueError(f"Row {r_num}: ditemukan item '{col_c}' sebelum header kategori pertama.")

        description = " ".join(str(col_c).strip().split())
        raw_spec = row.get(4)
        specification = " ".join(str(raw_spec).strip().split()) if raw_spec is not None else None
        unit = normalize_unit(row.get(5), r_num, description, warnings)

        raw_rem_obj = row.get(24)
        raw_remarks = str(raw_rem_obj).strip() if raw_rem_obj is not None else None
        extracted_jobs = extract_job_codes(raw_remarks)

        category_seq[current_cat_code] += 1
        item_code = f"HTI-{current_cat_code}-{category_seq[current_cat_code]:04d}"

        stocks: List[ParsedStock] = []
        for loc_code, cg, cs, cb in LOCATION_COLUMNS:
            g = to_non_negative_int(row.get(cg), r_num, f"{loc_code}.Good")
            s = to_non_negative_int(row.get(cs), r_num, f"{loc_code}.Service")
            b = to_non_negative_int(row.get(cb), r_num, f"{loc_code}.Broken")
            stocks.append(ParsedStock(location_code=loc_code, qty_good=g, qty_service=s, qty_broken=b))

        # Pasang job_code & remarks pada lokasi paling relevan (prioritas SITE-NON-PTS / SITE-PTS bila ada stok, lalu WH-1/WH-2)
        if raw_remarks:
            target_stock = None
            for pref in ("SITE-NON-PTS", "SITE-PTS", "WH-1", "WH-2"):
                candidate = next((st for st in stocks if st.location_code == pref and st.total > 0), None)
                if candidate:
                    target_stock = candidate
                    break
            if target_stock is None:
                target_stock = stocks[0]  # fallback WH-1
            target_stock.job_code = extracted_jobs
            target_stock.remarks = raw_remarks

        items.append(
            ParsedItem(
                excel_row=r_num,
                item_code=item_code,
                category_code=current_cat_code,
                description=description,
                specification=specification,
                unit=unit,
                raw_remarks=raw_remarks,
                extracted_job_codes=extracted_jobs,
                stocks=stocks,
            )
        )

    return ParsedDataset(
        categories=CATEGORIES_MASTER,
        locations=LOCATIONS_MASTER,
        items=items,
        warnings=warnings,
    )
