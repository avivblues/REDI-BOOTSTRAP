#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3A — Non-destructive PostgreSQL PITR validation
# Spilo-compatible recovery container; production untouched.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

DRILL_PORT=5435
DRILL_CONTAINER="redi-postgres-pitr-drill"
DRILL_DIR="${REDI_ROOT}/data/shared-platform/postgres-pitr-drill"
WAL_FETCH="${DRILL_DIR}/wal_archive"
BUCKET="redi-pg-wal"
ENDPOINT="http://${MJK_MESH_IP}:9000"
TEST_TABLE="redi_pitr_drill"
MARKER="pitr_$(date +%s)"
PGPORT="${POSTGRES_DIRECT_PORT:-5433}"
REPL_USER="${POSTGRES_REPLICATION_USER:-standby}"
REPL_PASS="${POSTGRES_REPLICATION_PASSWORD:-standby}"
SPILO_IMAGE="${SPILO_IMAGE:-ghcr.io/zalando/spilo-16:3.2-p2}"

sanitize_spilo_drill_config() {
  local dir="$1"
  rm -f "${dir}/patroni.dynamic.json" "${dir}/standby.signal" 2>/dev/null || true
  mkdir -p "${dir}/pg_log"
  sed -i "s/^logging_collector = .*/logging_collector = off/" "${dir}/postgresql.conf"
  sed -i "s/^ssl = .*/ssl = off/" "${dir}/postgresql.conf"
  chown -R 101:103 "${dir}" 2>/dev/null || true
  chmod 700 "${dir}"
  find "${dir}" -type d -exec chmod 700 {} \; 2>/dev/null || true
  find "${dir}" -type f -exec chmod 600 {} \; 2>/dev/null || true
}

docker rm -f "${DRILL_CONTAINER}" 2>/dev/null || true
rm -rf "${DRILL_DIR}"
mkdir -p "${WAL_FETCH}"

log_info "Step 1: pg_basebackup (before PITR markers)"
docker exec redi-postgres rm -rf /tmp/pitr_base
if ! docker exec -e PGPASSWORD="${REPL_PASS}" redi-postgres \
  pg_basebackup -h 127.0.0.1 -p "${PGPORT}" -U "${REPL_USER}" -D /tmp/pitr_base -Fp -Xs -P 2>/dev/null; then
  REPL_PASS="standby"
  docker exec -e PGPASSWORD="${REPL_PASS}" redi-postgres \
    pg_basebackup -h 127.0.0.1 -p "${PGPORT}" -U "${REPL_USER}" -D /tmp/pitr_base -Fp -Xs -P
fi

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -c "CHECKPOINT; SELECT pg_switch_wal();" >/dev/null
bash "${SCRIPT_DIR}/sync-pg-wal-to-minio.sh" || true
sleep 2

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -v ON_ERROR_STOP=1 \
  -c "DROP TABLE IF EXISTS ${TEST_TABLE}; CREATE TABLE ${TEST_TABLE} (id serial PRIMARY KEY, marker text, created_at timestamptz DEFAULT now());"

log_info "Step 2: Insert marker A + WAL switch"
docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -v ON_ERROR_STOP=1 \
  -c "INSERT INTO ${TEST_TABLE} (marker) VALUES ('${MARKER}_A'); SELECT pg_switch_wal(); CHECKPOINT;"
bash "${SCRIPT_DIR}/sync-pg-wal-to-minio.sh" || true
sleep 2

RECOVERY_TARGET="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SELECT to_char(now(), 'YYYY-MM-DD HH24:MI:SS.US') || '+00';")"
log_info "Recovery target (after A, before B): ${RECOVERY_TARGET}"
sleep 3

log_info "Step 3: Insert marker B + WAL switch"
docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -v ON_ERROR_STOP=1 \
  -c "INSERT INTO ${TEST_TABLE} (marker) VALUES ('${MARKER}_B'); SELECT pg_switch_wal(); CHECKPOINT;"
bash "${SCRIPT_DIR}/sync-pg-wal-to-minio.sh" || true
sleep 2

docker cp "redi-postgres:/tmp/pitr_base/." "${DRILL_DIR}/"
docker exec redi-postgres rm -rf /tmp/pitr_base
sanitize_spilo_drill_config "${DRILL_DIR}"

log_info "Step 4: Fetch WAL segments from MinIO"
docker run --rm --network host \
  -v "${WAL_FETCH}:/fetch" \
  --entrypoint /bin/sh minio/mc:latest -c "
    mc alias set redi ${ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
    mc mirror --overwrite redi/${BUCKET}/ /fetch/
  "

WAL_COUNT="$(find "${WAL_FETCH}" -type f 2>/dev/null | wc -l | tr -d ' ')"
[[ "${WAL_COUNT}" -ge 1 ]] || { log_error "No WAL files fetched from MinIO"; exit 1; }

cat >> "${DRILL_DIR}/postgresql.auto.conf" <<EOF
restore_command = 'cp /wal_archive/%f %p'
recovery_target_time = '${RECOVERY_TARGET}'
recovery_target_action = 'promote'
EOF
touch "${DRILL_DIR}/recovery.signal"

log_info "Step 5: PITR drill instance on port ${DRILL_PORT} (Spilo PG binary)"
docker run -d --name "${DRILL_CONTAINER}" --user 101 \
  -v "${DRILL_DIR}:/home/postgres/pgdata/pgroot/data" \
  -v "${WAL_FETCH}:/wal_archive:ro" \
  -p "127.0.0.1:${DRILL_PORT}:${DRILL_PORT}" \
  --entrypoint /usr/lib/postgresql/16/bin/postgres \
  "${SPILO_IMAGE}" \
  -D /home/postgres/pgdata/pgroot/data -p "${DRILL_PORT}" -c listen_addresses='*'

sleep 5
if ! docker ps --filter "name=${DRILL_CONTAINER}" --format '{{.Names}}' | grep -q "${DRILL_CONTAINER}"; then
  sleep 10
fi
if ! docker ps --filter "name=${DRILL_CONTAINER}" --format '{{.Names}}' | grep -q "${DRILL_CONTAINER}"; then
  log_error "PITR drill container failed to start"
  docker logs "${DRILL_CONTAINER}" 2>&1 | tail -20 >&2 || true
  exit 1
fi

for _ in $(seq 1 90); do
  if docker exec "${DRILL_CONTAINER}" pg_isready -h 127.0.0.1 -p "${DRILL_PORT}" -U postgres &>/dev/null; then
    IN_RECOVERY="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
      psql -h 127.0.0.1 -p "${DRILL_PORT}" -U postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo t)"
    [[ "${IN_RECOVERY}" == "f" ]] && break
  fi
  sleep 2
done

HAS_A="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -h 127.0.0.1 -p "${DRILL_PORT}" -U postgres -tAc \
  "SELECT count(*) FROM ${TEST_TABLE} WHERE marker='${MARKER}_A';" 2>/dev/null || echo 0)"
HAS_B="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -h 127.0.0.1 -p "${DRILL_PORT}" -U postgres -tAc \
  "SELECT count(*) FROM ${TEST_TABLE} WHERE marker='${MARKER}_B';" 2>/dev/null || echo 0)"

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -c "DROP TABLE IF EXISTS ${TEST_TABLE};" >/dev/null

docker rm -f "${DRILL_CONTAINER}" 2>/dev/null || true
rm -rf "${DRILL_DIR}"

log_info "PITR result — A: ${HAS_A} | B: ${HAS_B} | WAL files: ${WAL_COUNT}"

[[ "${HAS_A}" -ge 1 ]] || { log_error "Marker A missing after PITR"; exit 1; }
[[ "${HAS_B}" -eq 0 ]] || { log_error "Marker B present — recovery passed target time"; exit 1; }

log_info "PASS: PostgreSQL PITR drill"
