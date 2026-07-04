#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Deploy PgBouncer (postgres.redi.internal alias)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
if [[ "${HOSTNAME}" != "redi-mjk-01" && "${HOSTNAME}" != "redi-jkt-01" && "${HOSTNAME}" != "redi-sby-01" ]]; then
  log_info "PgBouncer not needed on ${HOSTNAME}"
  exit 0
fi

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

export MJK_MESH_IP JKT_MESH_IP
export PGROUTER_HOST="${PGROUTER_HOST:-redi-shared-haproxy}"
export SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"
mkdir -p "${SHARED_CONFIG_PATH}/pgbouncer"

envsubst < "${REDI_ROOT}/config/shared-platform/pgbouncer/pgbouncer.ini.template" \
  > "${SHARED_CONFIG_PATH}/pgbouncer/pgbouncer.ini"

echo "\"postgres\" \"${POSTGRES_SUPERUSER_PASSWORD}\"" > "${SHARED_CONFIG_PATH}/pgbouncer/userlist.txt"

cd "${REDI_ROOT}/compose/shared-platform/pgbouncer"
docker compose --env-file "${ENV_BASE}" up -d --force-recreate
log_info "PgBouncer deployed (postgres.redi.internal)"
