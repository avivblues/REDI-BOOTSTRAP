#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3A — Non-destructive PostgreSQL backup restore drill
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

DRILL_PORT=5434
DRILL_CONTAINER="redi-postgres-drill"
DRILL_DIR="${REDI_ROOT}/data/shared-platform/postgres-drill"
DUMP_FILE="${REDI_ROOT}/backup/sprint3a-drill-$(date +%Y%m%d).sql.gz"

log_info "Creating pg_dumpall snapshot"
mkdir -p "$(dirname "${DUMP_FILE}")"
docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  pg_dumpall -U postgres | gzip > "${DUMP_FILE}"

SRC_USERS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SELECT count(*) FROM pg_roles WHERE rolcanlogin;")"
SRC_GITLAB_USERS=0
if docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='gitlabhq_production'" 2>/dev/null | grep -q 1; then
  SRC_GITLAB_USERS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
    psql -U postgres -d gitlabhq_production -tAc "SELECT count(*) FROM users;" 2>/dev/null || echo 0)"
fi

docker rm -f "${DRILL_CONTAINER}" 2>/dev/null || true
rm -rf "${DRILL_DIR}"
mkdir -p "${DRILL_DIR}"

log_info "Restoring to isolated drill instance :${DRILL_PORT}"
docker run -d --name "${DRILL_CONTAINER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" \
  -v "${DRILL_DIR}:/var/lib/postgresql/data" \
  -p "127.0.0.1:${DRILL_PORT}:5432" \
  postgres:16-alpine

for _ in $(seq 1 30); do
  docker exec "${DRILL_CONTAINER}" pg_isready -U postgres &>/dev/null && break
  sleep 2
done

gunzip -c "${DUMP_FILE}" | docker exec -i -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -U postgres -v ON_ERROR_STOP=0 >/dev/null

DST_USERS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -U postgres -tAc "SELECT count(*) FROM pg_roles WHERE rolcanlogin;" 2>/dev/null || echo 0)"
DST_GITLAB_ROWS=0
if docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='gitlabhq_production'" 2>/dev/null | grep -q 1; then
  DST_GITLAB_ROWS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
    psql -U postgres -d gitlabhq_production -tAc "SELECT count(*) FROM users;" 2>/dev/null || echo 0)"
fi

docker rm -f "${DRILL_CONTAINER}" 2>/dev/null || true

log_info "Source login roles: ${SRC_USERS} | Restored: ${DST_USERS}"
log_info "GitLab users source: ${SRC_GITLAB_USERS} | restored: ${DST_GITLAB_ROWS}"
log_info "Dump file: ${DUMP_FILE} ($(du -h "${DUMP_FILE}" | cut -f1))"

[[ "${SRC_USERS}" == "${DST_USERS}" ]] || { log_error "Role count mismatch"; exit 1; }
[[ "${SRC_GITLAB_USERS}" == "${DST_GITLAB_ROWS}" ]] || { log_error "GitLab user count mismatch"; exit 1; }

log_info "PASS: PostgreSQL restore drill"
