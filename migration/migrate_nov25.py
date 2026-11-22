#!/usr/bin/env python3
"""
PT HTI Tool & Equipment Inventory System — Baseline Migration CLI (HTI-TEIS-MIG-01)

Penggunaan:
  1) Dry-run & verifikasi 100% rekonsiliasi Excel Nov 25:
     python3 migration/migrate_nov25.py --dry-run

  2) Ekspor SQL transaksional siap muat via psql:
     python3 migration/migrate_nov25.py --export-sql /tmp/nov25_baseline.sql

  3) Migrasi langsung ke PostgreSQL 16 (atomik + rollback otomatis bila verifikasi gagal):
     DIRECT_DATABASE_URL="postgresql://hti_migrator:...@127.0.0.1:5432/hti_inventory" \
       python3 migration/migrate_nov25.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from excel_parser import ParsedDataset, parse_nov25_excel
from verify_baseline import verify_database_cursor, verify_parsed_dataset

DEFAULT_EXCEL_PATH = Path(__file__).resolve().parent.parent / "2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx"


def sql_literal(val: object) -> str:
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    if isinstance(val, int):
        return str(val)
    escaped = str(val).replace("'", "''")
    return f"'{escaped}'"


def export_dataset_to_sql(dataset: ParsedDataset, out_path: Path) -> None:
    lines = [
        "-- ==============================================================================",
        "-- PT HTI Tool & Equipment Inventory System — Generated Baseline Import (Nov 25)",
        "-- 9 Categories | 4 Locations | 531 Items | 12.808 Total Units",
        "-- ==============================================================================",
        "BEGIN;",
        "",
        "-- 1. Upsert 9 Categories",
    ]
    for code, name in dataset.categories:
        lines.append(
            f"INSERT INTO categories (code, name) VALUES ({sql_literal(code)}, {sql_literal(name)}) "
            f"ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;"
        )

    lines.append("\n-- 2. Upsert 4 Locations")
    for code, name, loc_type in dataset.locations:
        lines.append(
            f"INSERT INTO locations (code, name, location_type, is_active) "
            f"VALUES ({sql_literal(code)}, {sql_literal(name)}, {sql_literal(loc_type)}::\"LocationType\", TRUE) "
            f"ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, location_type = EXCLUDED.location_type;"
        )

    lines.append("\n-- 3. Insert 531 Master Items, Real-Time Item Stocks & INITIAL_IMPORT Audit Logs")
    for it in dataset.items:
        lines.append(
            f"INSERT INTO items (item_code, category_id, description, specification, unit, is_active) "
            f"VALUES ({sql_literal(it.item_code)}, (SELECT id FROM categories WHERE code = {sql_literal(it.category_code)}), "
            f"{sql_literal(it.description)}, {sql_literal(it.specification)}, {sql_literal(it.unit)}, TRUE) "
            f"ON CONFLICT (item_code) DO NOTHING;"
        )
        for st in it.stocks:
            if st.total == 0 and st.remarks is None:
                continue
            lines.append(
                f"INSERT INTO item_stocks (item_id, location_id, qty_good, qty_service, qty_broken, qty_in_transit, job_code, remarks) "
                f"VALUES ((SELECT id FROM items WHERE item_code = {sql_literal(it.item_code)}), "
                f"(SELECT id FROM locations WHERE code = {sql_literal(st.location_code)}), "
                f"{st.qty_good}, {st.qty_service}, {st.qty_broken}, 0, {sql_literal(st.job_code)}, {sql_literal(st.remarks)}) "
                f"ON CONFLICT (item_id, location_id) DO NOTHING;"
            )
            if st.total > 0:
                after_json = json.dumps(
                    {"good": st.qty_good, "service": st.qty_service, "broken": st.qty_broken, "in_transit": 0}
                )
                note = "Baseline import Excel Nov 25"
                if st.remarks:
                    note = f"{note} | {st.remarks}"
                lines.append(
                    f"INSERT INTO stock_logs (item_id, to_location_id, action_type, qty_changed, qty_before, qty_after, job_code, note) "
                    f"VALUES ((SELECT id FROM items WHERE item_code = {sql_literal(it.item_code)}), "
                    f"(SELECT id FROM locations WHERE code = {sql_literal(st.location_code)}), "
                    f"'INITIAL_IMPORT'::\"StockActionType\", {st.total}, NULL, {sql_literal(after_json)}::jsonb, "
                    f"{sql_literal(st.job_code)}, {sql_literal(note)});"
                )

    lines.append("\nCOMMIT;\n")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def load_into_postgres(dataset: ParsedDataset, database_url: str, reset_existing: bool) -> None:
    try:
        import psycopg2  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "Paket psycopg2-binary belum terpasang. Jalankan: pip install -r migration/requirements.txt"
        ) from exc

    conn = psycopg2.connect(database_url)
    conn.autocommit = False
    try:
        with conn.cursor() as cur:
            if reset_existing:
                cur.execute("TRUNCATE TABLE stock_logs, stock_transfers, item_stocks, items RESTART IDENTITY CASCADE")
            else:
                cur.execute("SELECT COUNT(*) FROM items")
                existing = cur.fetchone()[0]
                if existing > 0:
                    raise RuntimeError(
                        f"Tabel items sudah berisi {existing} baris. Gunakan --reset-existing hanya di lingkungan non-produksi."
                    )

            cat_ids = {}
            for code, name in dataset.categories:
                cur.execute(
                    """
                    INSERT INTO categories (code, name)
                    VALUES (%s, %s)
                    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
                    RETURNING id
                    """,
                    (code, name),
                )
                cat_ids[code] = cur.fetchone()[0]

            loc_ids = {}
            for code, name, loc_type in dataset.locations:
                cur.execute(
                    """
                    INSERT INTO locations (code, name, location_type, is_active)
                    VALUES (%s, %s, %s::"LocationType", TRUE)
                    ON CONFLICT (code) DO UPDATE
                      SET name = EXCLUDED.name, location_type = EXCLUDED.location_type
                    RETURNING id
                    """,
                    (code, name, loc_type),
                )
                loc_ids[code] = cur.fetchone()[0]

            for it in dataset.items:
                cur.execute(
                    """
                    INSERT INTO items (item_code, category_id, description, specification, unit, is_active)
                    VALUES (%s, %s, %s, %s, %s, TRUE)
                    RETURNING id
                    """,
                    (it.item_code, cat_ids[it.category_code], it.description, it.specification, it.unit),
                )
                item_id = cur.fetchone()[0]

                for st in it.stocks:
                    if st.total == 0 and st.remarks is None:
                        continue
                    loc_id = loc_ids[st.location_code]
                    cur.execute(
                        """
                        INSERT INTO item_stocks (
                            item_id, location_id, qty_good, qty_service, qty_broken, qty_in_transit, job_code, remarks
                        ) VALUES (%s, %s, %s, %s, %s, 0, %s, %s)
                        """,
                        (item_id, loc_id, st.qty_good, st.qty_service, st.qty_broken, st.job_code, st.remarks),
                    )
                    if st.total > 0:
                        after_json = json.dumps(
                            {"good": st.qty_good, "service": st.qty_service, "broken": st.qty_broken, "in_transit": 0}
                        )
                        note = "Baseline import Excel Nov 25"
                        if st.remarks:
                            note = f"{note} | {st.remarks}"
                        cur.execute(
                            """
                            INSERT INTO stock_logs (
                                item_id, to_location_id, action_type, qty_changed, qty_before, qty_after, job_code, note
                            ) VALUES (%s, %s, 'INITIAL_IMPORT'::"StockActionType", %s, NULL, %s::jsonb, %s, %s)
                            """,
                            (item_id, loc_id, st.total, after_json, st.job_code, note),
                        )

            report = verify_database_cursor(cur)
        conn.commit()
        print("[MIGRATION] COMMIT SUCCESS — Verifikasi DB 100% PASS:")
        print(json.dumps(report, indent=2))
    except Exception:
        conn.rollback()
        print("[MIGRATION] ERROR — Transaksi di-ROLLBACK penuh!", file=sys.stderr)
        raise
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="HTI-TEIS Baseline Excel 'Nov 25' Migration Utility")
    parser.add_argument("--excel", type=Path, default=DEFAULT_EXCEL_PATH, help="Path ke file Excel aset PT HTI")
    parser.add_argument("--sheet", type=str, default="Nov 25", help="Nama sheet target (default: 'Nov 25')")
    parser.add_argument("--dry-run", action="store_true", help="Parse & verifikasi rekonsiliasi tanpa menulis ke DB")
    parser.add_argument("--export-sql", type=Path, default=None, help="Ekspor skrip SQL transaksional ke berkas target")
    parser.add_argument("--database-url", type=str, default=os.getenv("DIRECT_DATABASE_URL") or os.getenv("DATABASE_URL"))
    parser.add_argument("--reset-existing", action="store_true", help="Hapus isi tabel stok/item sebelum import (dev/staging only)")
    args = parser.parse_args()

    if not args.excel.exists():
        print(f"[ERROR] File Excel tidak ditemukan: {args.excel}", file=sys.stderr)
        sys.exit(1)

    dataset = parse_nov25_excel(args.excel, args.sheet)
    report = verify_parsed_dataset(dataset)

    print(f"[PARSER] Berhasil mem-parsing sheet '{args.sheet}' — 100% Reconciled!")
    if dataset.warnings:
        print(f"[PARSER] Normalisasi otomatis ({len(dataset.warnings)} catatan):")
        for w in dataset.warnings:
            print(f"  - {w}")

    if args.export_sql:
        export_dataset_to_sql(dataset, args.export_sql)
        print(f"[EXPORT] SQL transaksional ditulis ke: {args.export_sql}")

    if args.dry_run or args.export_sql:
        print(json.dumps(report, indent=2))
        return

    if not args.database_url:
        print("[ERROR] Setel DIRECT_DATABASE_URL atau gunakan --dry-run / --export-sql.", file=sys.stderr)
        sys.exit(1)

    load_into_postgres(dataset, args.database_url, reset_existing=args.reset_existing)


if __name__ == "__main__":
    main()
