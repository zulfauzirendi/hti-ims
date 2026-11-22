"""Unit & Reconciliation Tests untuk Baseline Migration Nov 25 (zero external deps)."""

import tempfile
import unittest
from pathlib import Path

from excel_parser import extract_job_codes, parse_nov25_excel
from migrate_nov25 import DEFAULT_EXCEL_PATH, export_dataset_to_sql
from verify_baseline import verify_parsed_dataset


class TestNov25Migration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dataset = parse_nov25_excel(DEFAULT_EXCEL_PATH, "Nov 25")

    def test_exact_baseline_reconciliation(self):
        report = verify_parsed_dataset(self.dataset)
        self.assertEqual(report["categories"], 9)
        self.assertEqual(report["locations"], 4)
        self.assertEqual(report["items"], 531)
        self.assertEqual(report["grand_total"]["good"], 10340)
        self.assertEqual(report["grand_total"]["service"], 119)
        self.assertEqual(report["grand_total"]["broken"], 2349)
        self.assertEqual(report["grand_total"]["total"], 12808)

    def test_edge_cases_handled(self):
        # 1. Typo 'ELECTRICAL & PENEUMATIC TOOLS' dinormalisasi ke ELP
        elp_items = [it for it in self.dataset.items if it.category_code == "ELP"]
        self.assertGreater(len(elp_items), 0)

        # 2. Dua baris tanpa unit (row 273 & 274) terisi fallback 'PCS'
        row_273 = next(it for it in self.dataset.items if it.excel_row == 273)
        row_274 = next(it for it in self.dataset.items if it.excel_row == 274)
        self.assertEqual(row_273.unit, "PCS")
        self.assertEqual(row_274.unit, "PCS")

        # 3. Seluruh satuan uppercase valid
        allowed_units = {"UNIT", "PCS", "SET", "ROLL", "EA", "PAIR", "BOX", "BTL"}
        for it in self.dataset.items:
            self.assertIn(it.unit, allowed_units)

        # 4. Deterministic SKU format
        self.assertEqual(self.dataset.items[0].item_code, "HTI-EQP-0001")

    def test_multi_job_code_extraction(self):
        sample = "9 di job 1p-73-105,4 di job 1p-45-088, 3 di job 1p-31-167,25 di job 1p-31- 180 "
        self.assertEqual(extract_job_codes(sample), "1P-73-105, 1P-45-088, 1P-31-167, 1P-31-180")
        self.assertEqual(extract_job_codes("1 gudang maharani, 1 di job 1p-89--037"), "1P-89-037")
        self.assertIsNone(extract_job_codes("29 dI JIIPEE"))

    def test_sql_export_generates_valid_transaction(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            sql_file = Path(tmpdir) / "baseline.sql"
            export_dataset_to_sql(self.dataset, sql_file)
            text = sql_file.read_text(encoding="utf-8")
            self.assertTrue(text.splitlines()[4] == "BEGIN;")
            self.assertTrue(text.strip().endswith("COMMIT;"))
            self.assertEqual(text.count("INSERT INTO items "), 531)


if __name__ == "__main__":
    unittest.main(verbosity=2)
