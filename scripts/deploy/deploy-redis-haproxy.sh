#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Deploy Redis HAProxy (redis.redi.internal → Sentinel master)
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

export SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"
mkdir -p "${SHARED_CONFIG_PATH}"

bash "${SCRIPT_DIR}/sync-redis-haproxy.sh"

cd "${REDI_ROOT}/compose/shared-platform/haproxy-redis"
docker compose --env-file "${ENV_BASE}" up -d --force-recreate
docker exec redi-redis-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
log_info "Redis HAProxy deployed (redis.redi.internal:6379)"
