#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — TCP proxy for local Spilo (docker bridge -> host :5433)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
if [[ "${HOSTNAME}" != "redi-mjk-01" && "${HOSTNAME}" != "redi-jkt-01" ]]; then
  log_info "pg-local-proxy not needed on ${HOSTNAME}"
  exit 0
fi

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
cd "${REDI_ROOT}/compose/shared-platform/pg-local-proxy"
docker compose --env-file "${ENV_BASE}" up -d --force-recreate
log_info "pg-local-proxy ${PG_LOCAL_PROXY_HOST:-172.32.0.1}:${PG_LOCAL_PROXY_PORT:-5434} -> 127.0.0.1:5433"
