#!/usr/bin/env bash
# =============================================================================
# REDI — Deploy Redis HAProxy on current node (redis.redi.internal → Sentinel master)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
case "${HOSTNAME}" in
  redi-mjk-01|redi-jkt-01|redi-sby-01) ;;
  *)
    log_error "Redis HAProxy deploys on redi-mjk-01, redi-jkt-01, or redi-sby-01. Current: ${HOSTNAME}"
    exit 1
    ;;
esac

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.${HOSTNAME}"
# shellcheck source=/dev/null
source "${ENV_BASE}"
[[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"

bash "${SCRIPT_DIR}/sync-redis-haproxy.sh"
log_info "Redis HAProxy deployed on ${HOSTNAME}"
