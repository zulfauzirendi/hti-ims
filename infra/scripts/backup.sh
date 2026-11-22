#!/usr/bin/env bash
# ==============================================================================
# PT HTI Inventory System — Automated AES-256 Encrypted Daily Backup (ISO 9001)
# Cron (02:00 WIB): 0 2 * * * /path/to/infra/scripts/backup.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${POSTGRES_DB:?POSTGRES_DB required}"
: "${POSTGRES_USER:?POSTGRES_USER required}"
: "${BACKUP_ENC_KEY:?BACKUP_ENC_KEY required}"

BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TS="$(date +%Y%m%d_%H%M%S)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$BACKUP_DIR"

echo "[BACKUP] (${TS}) Dumping PostgreSQL database '${POSTGRES_DB}'..."
docker exec hti_postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "${TMP_DIR}/hti_db_${TS}.dump"

echo "[BACKUP] (${TS}) Archiving ISO 45001 evidence_storage volume..."
docker run --rm -v hti_evidence_data:/data:ro -v "${TMP_DIR}:/out" alpine \
  tar -czf "/out/hti_evidence_${TS}.tar.gz" -C /data .

echo "[BACKUP] (${TS}) Encrypting archives with AES-256-CBC (PBKDF2)..."
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -in "${TMP_DIR}/hti_db_${TS}.dump" \
  -out "${BACKUP_DIR}/hti_db_${TS}.dump.enc" \
  -pass env:BACKUP_ENC_KEY

openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -in "${TMP_DIR}/hti_evidence_${TS}.tar.gz" \
  -out "${BACKUP_DIR}/hti_evidence_${TS}.tar.gz.enc" \
  -pass env:BACKUP_ENC_KEY

(cd "$BACKUP_DIR" && sha256sum "hti_db_${TS}.dump.enc" "hti_evidence_${TS}.tar.gz.enc" > "hti_backup_${TS}.sha256")

echo "[BACKUP] Pruning encrypted backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -type f \( -name "*.enc" -o -name "*.sha256" \) -mtime "+${RETENTION_DAYS}" -delete

# Disk usage alert > 80% (SRS-LOG-002)
DISK_PCT="$(df -P "$BACKUP_DIR" | awk 'NR==2 {gsub("%",""); print $5}')"
if (( DISK_PCT > 80 )); then
  echo "[WARNING] Kapasitas disk penyimpanan backup mencapai ${DISK_PCT}% (> 80%)!" >&2
fi

echo "[BACKUP] SUCCESS: ${BACKUP_DIR}/hti_backup_${TS}.sha256"
