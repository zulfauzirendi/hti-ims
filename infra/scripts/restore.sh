#!/usr/bin/env bash
# ==============================================================================
# PT HTI Inventory System — Disaster Recovery Restore Script (RTO <= 2 Hours)
# Usage: ./infra/scripts/restore.sh <TIMESTAMP_YYYYMMDD_HHMMSS>
# ==============================================================================
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <TIMESTAMP_YYYYMMDD_HHMMSS>" >&2
  exit 1
fi

TS="$1"
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
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[RESTORE] Verifying SHA-256 checksums for backup ${TS}..."
(cd "$BACKUP_DIR" && sha256sum -c "hti_backup_${TS}.sha256")

echo "[RESTORE] Decrypting database & evidence archives..."
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in "${BACKUP_DIR}/hti_db_${TS}.dump.enc" \
  -out "${TMP_DIR}/hti_db.dump" \
  -pass env:BACKUP_ENC_KEY

openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in "${BACKUP_DIR}/hti_evidence_${TS}.tar.gz.enc" \
  -out "${TMP_DIR}/hti_evidence.tar.gz" \
  -pass env:BACKUP_ENC_KEY

echo "[RESTORE] Stopping API container during restore..."
docker stop hti_api || true

echo "[RESTORE] Restoring PostgreSQL database '${POSTGRES_DB}'..."
docker exec -i hti_postgres pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists < "${TMP_DIR}/hti_db.dump"

echo "[RESTORE] Restoring evidence_storage volume..."
docker run --rm -v hti_evidence_data:/data -v "${TMP_DIR}:/in:ro" alpine \
  sh -c "rm -rf /data/* && tar -xzf /in/hti_evidence.tar.gz -C /data && chown -R 1000:1000 /data"

echo "[RESTORE] Restarting API container..."
docker start hti_api
echo "[RESTORE] COMPLETE. Verifikasi kesehatan via GET /api/v1/health."
