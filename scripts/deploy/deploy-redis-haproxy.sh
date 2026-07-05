#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Deploy Redis HAProxy (redis.redi.internal → Sentinel master)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run sync-redis-master.sh on redi-mjk-01"; exit 1; }

bash "${SCRIPT_DIR}/sync-redis-haproxy.sh"
