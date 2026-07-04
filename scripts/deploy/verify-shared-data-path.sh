#!/usr/bin/env bash
# =============================================================================
# REDI — Verify SHARED_DATA_PATH is absolute on this node
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
EXPECTED="/opt/redi/data/shared-platform"
ACTUAL="$(grep -E '^SHARED_DATA_PATH=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" || true)"

[[ -n "${ACTUAL}" ]] || { log_error "SHARED_DATA_PATH not set in ${ENV_FILE}"; exit 1; }
[[ "${ACTUAL}" == "${EXPECTED}"* ]] || { log_error "SHARED_DATA_PATH must be absolute under /opt/redi: got ${ACTUAL}"; exit 1; }
[[ -d "${ACTUAL}" ]] || { log_error "SHARED_DATA_PATH directory missing: ${ACTUAL}"; exit 1; }

log_info "PASS $(hostname -s): SHARED_DATA_PATH=${ACTUAL}"
