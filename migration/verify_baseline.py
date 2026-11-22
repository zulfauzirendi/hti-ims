"""
Automated Reconciliation & Verification Gate untuk Baseline Excel 'Nov 25' (SRS-CAP-026).
Migrasi hanya dinyatakan PASS bila 100% cocok hingga satuan unit per lokasi & status.
"""

from __future__ import annotations

from typing import Dict

from excel_parser import ParsedDataset

EXPECTED_CATEGORIES = 9
EXPECTED_LOCATIONS = 4
EXPECTED_ITEMS = 531

EXPECTED_BY_LOCATION: Dict[str, Dict[str, int]] = {
    "WH-1": {"good": 8096, "service": 111, "broken": 2242, "total": 10449},
    "WH-2": {"good": 1830, "service": 8, "broken": 107, "total": 1945},
    "SITE-NON-PTS": {"good": 214, "service": 0, "broken": 0, "total": 214},
    "SITE-PTS": {"good": 200, "service": 0, "broken": 0, "total": 200},
}

EXPECTED_GRAND = {"good": 10340, "service": 119, "broken": 2349, "total": 12808}


def verify_parsed_dataset(dataset: ParsedDataset) -> Dict[str, object]:
    assert len(dataset.categories) == EXPECTED_CATEGORIES, (
        f"Expected {EXPECTED_CATEGORIES} categories, got {len(dataset.categories)}"
    )
    assert len(dataset.locations) == EXPECTED_LOCATIONS, (
        f"Expected {EXPECTED_LOCATIONS} locations, got {len(dataset.locations)}"
    )
    assert len(dataset.items) == EXPECTED_ITEMS, (
        f"Expected {EXPECTED_ITEMS} items, got {len(dataset.items)}"
    )

    # Pastikan seluruh item_code unik
    codes = [it.item_code for it in dataset.items]
    assert len(codes) == len(set(codes)), "Duplicate item_code detected!"

    actual_loc = {k: {"good": 0, "service": 0, "broken": 0, "total": 0} for k in EXPECTED_BY_LOCATION}
    for it in dataset.items:
        for st in it.stocks:
            bucket = actual_loc[st.location_code]
            bucket["good"] += st.qty_good
            bucket["service"] += st.qty_service
            bucket["broken"] += st.qty_broken
            bucket["total"] += st.total

    for loc_code, expected in EXPECTED_BY_LOCATION.items():
        got = actual_loc[loc_code]
        assert got == expected, f"Mismatch at {loc_code}: expected {expected}, got {got}"

    grand = {
        "good": sum(v["good"] for v in actual_loc.values()),
        "service": sum(v["service"] for v in actual_loc.values()),
        "broken": sum(v["broken"] for v in actual_loc.values()),
        "total": sum(v["total"] for v in actual_loc.values()),
    }
    assert grand == EXPECTED_GRAND, f"Grand total mismatch: expected {EXPECTED_GRAND}, got {grand}"

    return {
        "categories": len(dataset.categories),
        "locations": len(dataset.locations),
        "items": len(dataset.items),
        "by_location": actual_loc,
        "grand_total": grand,
    }


def verify_database_cursor(cur) -> Dict[str, object]:
    """Verifikasi langsung di dalam transaksi PostgreSQL sebelum COMMIT."""
    cur.execute("SELECT COUNT(*) FROM categories")
    cat_count = cur.fetchone()[0]
    assert cat_count == EXPECTED_CATEGORIES, f"DB categories={cat_count}, expected {EXPECTED_CATEGORIES}"

    cur.execute("SELECT COUNT(*) FROM locations WHERE is_active = TRUE")
    loc_count = cur.fetchone()[0]
    assert loc_count == EXPECTED_LOCATIONS, f"DB locations={loc_count}, expected {EXPECTED_LOCATIONS}"

    cur.execute("SELECT COUNT(*) FROM items WHERE is_active = TRUE")
    item_count = cur.fetchone()[0]
    assert item_count == EXPECTED_ITEMS, f"DB items={item_count}, expected {EXPECTED_ITEMS}"

    cur.execute(
        """
        SELECT l.code,
               COALESCE(SUM(s.qty_good), 0),
               COALESCE(SUM(s.qty_service), 0),
               COALESCE(SUM(s.qty_broken), 0),
               COALESCE(SUM(s.qty_in_transit), 0)
        FROM locations l
        LEFT JOIN item_stocks s ON s.location_id = l.id
        GROUP BY l.code
        """
    )
    actual_loc = {}
    for code, g, s, b, t in cur.fetchall():
        assert t == 0, f"Initial migration must have qty_in_transit=0 at {code}, got {t}"
        actual_loc[code] = {"good": int(g), "service": int(s), "broken": int(b), "total": int(g + s + b)}

    for loc_code, expected in EXPECTED_BY_LOCATION.items():
        got = actual_loc.get(loc_code)
        assert got == expected, f"DB mismatch at {loc_code}: expected {expected}, got {got}"

    cur.execute("SELECT COALESCE(SUM(qty_changed), 0) FROM stock_logs WHERE action_type = 'INITIAL_IMPORT'")
    logged_total = int(cur.fetchone()[0])
    assert logged_total == EXPECTED_GRAND["total"], (
        f"DB INITIAL_IMPORT stock_logs sum={logged_total}, expected {EXPECTED_GRAND['total']}"
    )

    return {
        "categories": cat_count,
        "locations": loc_count,
        "items": item_count,
        "by_location": actual_loc,
        "grand_total": EXPECTED_GRAND,
        "initial_import_logs_sum": logged_total,
    }
