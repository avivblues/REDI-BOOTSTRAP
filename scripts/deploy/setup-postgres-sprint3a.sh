#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3A — PostgreSQL data integrity (replication slot + WAL archive)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01 only"; exit 1; }

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

SLOT_NAME="${POSTGRES_REPLICATION_SLOT:-redi_jkt_standby}"
WAL_DIR="${SHARED_DATA_PATH}/postgres-wal-archive"
CRON_FILE="/etc/cron.d/redi-pg-wal-sync"

mkdir -p "${WAL_DIR}"
chown -R 70:70 "${WAL_DIR}" 2>/dev/null || chmod 1777 "${WAL_DIR}"

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -v ON_ERROR_STOP=1 <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = '${SLOT_NAME}') THEN
    PERFORM pg_create_physical_replication_slot('${SLOT_NAME}', true);
  END IF;
END \$\$;
EOSQL

log_info "Replication slot: ${SLOT_NAME}"
docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -c "SELECT slot_name, active, restart_lsn FROM pg_replication_slots;"

ARCHIVE_MODE="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SHOW archive_mode;" 2>/dev/null | tr -d '[:space:]')"
if [[ "${ARCHIVE_MODE}" != "on" ]]; then
  log_warn "archive_mode=${ARCHIVE_MODE} — redeploy postgres primary compose to enable WAL archive"
else
  log_info "archive_mode=on"
fi

bash "${SCRIPT_DIR}/create-minio-buckets.sh"

SYNC_SCRIPT="${REDI_ROOT}/scripts/deploy/sync-pg-wal-to-minio.sh"
chmod +x "${SYNC_SCRIPT}"
cat > "${CRON_FILE}" <<EOF
# REDI — sync PostgreSQL WAL archives to MinIO every 2 minutes
*/2 * * * * root ${SYNC_SCRIPT} >> ${REDI_ROOT}/logs/shared-platform/pg-wal-sync.log 2>&1
EOF
chmod 644 "${CRON_FILE}"

bash "${SYNC_SCRIPT}" || log_warn "Initial WAL sync returned non-zero (empty archive dir is OK)"

log_info "Sprint 3A PostgreSQL setup complete"
