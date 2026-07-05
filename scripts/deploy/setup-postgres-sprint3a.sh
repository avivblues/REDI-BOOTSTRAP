#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3A — PostgreSQL data integrity (replication slot + WAL archive)
# Leader-aware: archive_command via Patroni DCS; WAL sync cron on every node.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

if ! docker ps --format '{{.Names}}' | grep -q '^redi-postgres$'; then
  log_warn "redi-postgres not running on $(hostname -s) — installing WAL sync cron only"
  chmod +x "${SYNC_SCRIPT}"
  mkdir -p "${REDI_ROOT}/logs/shared-platform"
  cat > "${CRON_FILE}" <<EOF
# REDI — sync PostgreSQL WAL archives to MinIO every 2 minutes (leader-aware)
*/2 * * * * root ${SYNC_SCRIPT} >> ${REDI_ROOT}/logs/shared-platform/pg-wal-sync.log 2>&1
EOF
  chmod 644 "${CRON_FILE}"
  exit 0
fi

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

SLOT_NAME="${POSTGRES_REPLICATION_SLOT:-redi_jkt_standby}"
WAL_DIR="${SHARED_DATA_PATH}/postgres/wal_archive"
ARCHIVE_CMD="test ! -f /home/postgres/pgdata/wal_archive/%f && cp %p /home/postgres/pgdata/wal_archive/%f"
CRON_FILE="/etc/cron.d/redi-pg-wal-sync"
SYNC_SCRIPT="${REDI_ROOT}/scripts/deploy/sync-pg-wal-to-minio.sh"

mkdir -p "${WAL_DIR}"
chown -R 101:103 "${WAL_DIR}" 2>/dev/null || chmod 1777 "${WAL_DIR}"

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

log_info "Setting Patroni archive_command (follows leader on failover)"
docker exec redi-postgres patronictl edit-config --force --set \
  "postgresql.parameters.archive_command=${ARCHIVE_CMD}" 2>/dev/null \
  || docker exec redi-postgres patronictl edit-config --force --set \
  "postgresql.parameters.archive_command='${ARCHIVE_CMD}'" 2>/dev/null \
  || log_warn "patronictl edit-config failed — trying REST API"
curl -sf -X PATCH "http://127.0.0.1:8008/config" \
  -H "Content-Type: application/json" \
  -d "{\"postgresql\":{\"parameters\":{\"archive_command\":\"${ARCHIVE_CMD}\"}}}" \
  2>/dev/null || log_warn "REST config patch skipped"

sleep 5
ARCHIVE_MODE="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SHOW archive_mode;" 2>/dev/null | tr -d '[:space:]')"
ARCHIVE_CMD_NOW="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SHOW archive_command;" 2>/dev/null | tr -d '[:space:]')"

ROLE="$(curl -sf --max-time 5 "http://127.0.0.1:8008/patroni" 2>/dev/null \
  | grep -o '"role": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")"
if [[ "${ROLE}" == "master" || "${ROLE}" == "leader" ]] && [[ "${ARCHIVE_CMD_NOW}" == "/bin/true" ]]; then
  log_info "Spilo override detected — applying archive_command via ALTER SYSTEM on leader"
  docker exec redi-postgres mkdir -p /home/postgres/pgdata/wal_archive
  docker exec redi-postgres chown postgres:postgres /home/postgres/pgdata/wal_archive 2>/dev/null || true
  docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
    psql -U postgres -c "ALTER SYSTEM SET archive_command = '${ARCHIVE_CMD}'; SELECT pg_reload_conf();"
  ARCHIVE_CMD_NOW="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
    psql -U postgres -tAc "SHOW archive_command;" 2>/dev/null | tr -d '[:space:]')"
fi

log_info "archive_mode=${ARCHIVE_MODE} archive_command=${ARCHIVE_CMD_NOW}"

bash "${SCRIPT_DIR}/create-minio-buckets.sh"

chmod +x "${SYNC_SCRIPT}"
mkdir -p "${REDI_ROOT}/logs/shared-platform"
cat > "${CRON_FILE}" <<EOF
# REDI — sync PostgreSQL WAL archives to MinIO every 2 minutes (leader-aware)
*/2 * * * * root ${SYNC_SCRIPT} >> ${REDI_ROOT}/logs/shared-platform/pg-wal-sync.log 2>&1
EOF
chmod 644 "${CRON_FILE}"

bash "${SYNC_SCRIPT}" || log_warn "Initial WAL sync returned non-zero (empty archive dir is OK)"

log_info "Sprint 3A PostgreSQL setup complete on $(hostname -s)"
