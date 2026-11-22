#!/usr/bin/env bash
# ==============================================================================
# PT HTI Tool & Equipment Inventory System — Local Dev One-Command Bootstrap
# Menyiapkan PostgreSQL 16 + Migrasi Skema + Role Least-Privilege + Seed Akun
# + Import Data Baseline Excel 'Nov 25' (531 Item / 12.808 Unit) untuk Android Studio.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$PROJECT_ROOT"

if [[ ! -f ".env" ]]; then
  echo "[ERROR] File .env belum ada. Salin .env.example ke .env lalu isi password/secret terlebih dahulu." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

echo "[1/6] Menyalakan PostgreSQL 16 (dev localhost:5432)..."
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d postgres

echo "[2/6] Menunggu PostgreSQL siap menerima koneksi..."
until docker exec hti_postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; do
  sleep 1
done

echo "[3/6] Menjalankan Prisma migrate deploy..."
(cd backend && npx prisma migrate deploy)

echo "[4/6] Menerapkan least-privilege DB role (REVOKE UPDATE/DELETE pada stock_logs)..."
docker exec -i hti_postgres psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" < infra/scripts/apply_db_grants.sql

echo "[5/6] Seeding kategori, lokasi & akun awal RBAC..."
SEED_PW="${SEED_INITIAL_PASSWORD:-HtiDevBootstrap2026!}"
(cd backend && SEED_INITIAL_PASSWORD="$SEED_PW" npm run prisma:seed)

EXCEL_FILE="${PROJECT_ROOT}/2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx"
if [[ -f "$EXCEL_FILE" ]]; then
  EXISTING_ITEMS="$(docker exec hti_postgres psql -tAc "SELECT COUNT(*) FROM items" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | tr -d '[:space:]')"
  if [[ "$EXISTING_ITEMS" == "0" ]]; then
    echo "[6/6] Mengimpor data baseline Excel 'Nov 25' (531 item / 12.808 unit)..."
    TMP_SQL="$(mktemp /tmp/hti_nov25_XXXXXX.sql)"
    trap 'rm -f "$TMP_SQL"' EXIT
    python3 migration/migrate_nov25.py --export-sql "$TMP_SQL"
    docker exec -i hti_postgres psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" < "$TMP_SQL"
    docker exec hti_postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
      "SELECT COUNT(*) AS items, (SELECT SUM(qty_good) FROM item_stocks) AS good, (SELECT SUM(qty_service) FROM item_stocks) AS service, (SELECT SUM(qty_broken) FROM item_stocks) AS broken FROM items WHERE is_active = TRUE;"
  else
    echo "[6/6] Tabel items sudah terisi (${EXISTING_ITEMS} item) — melewati import Excel."
  fi
else
  echo "[6/6] File Excel baseline tidak ditemukan — melewati import Excel."
fi

echo ""
echo "=============================================================================="
echo "Database & migrasi siap!"
echo "Akun awal (wajib ganti sandi saat login pertama): superadmin / admin_wh1 / site_pts / hanif / vika"
echo "Password awal dev : ${SEED_PW}"
echo "Jalankan Backend  : cd backend && npm run dev"
echo "URL Android Studio: http://10.0.2.2:3000 (otomatis terpilih pada build debug!)"
echo "=============================================================================="
