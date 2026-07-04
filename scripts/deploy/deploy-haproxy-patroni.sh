#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — HAProxy Patroni-aware router (mesh :5432 → spilo :5433)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || return 0

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

export MJK_MESH_IP JKT_MESH_IP POSTGRES_MJK_PORT=5433 POSTGRES_JKT_PORT=5433
export SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"

envsubst < "${REDI_ROOT}/config/shared-platform/haproxy.cfg.template" \
  > "${SHARED_CONFIG_PATH}/haproxy.cfg"

cd "${REDI_ROOT}/compose/shared-platform/haproxy"
docker compose --env-file "${ENV_BASE}" up -d --force-recreate
docker exec redi-shared-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
log_info "HAProxy Patroni router on redi-internal (pg-router.redi.internal:5432)"
