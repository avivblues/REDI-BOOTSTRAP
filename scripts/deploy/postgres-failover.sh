#!/usr/bin/env bash
# =============================================================================
# REDI — Promote PostgreSQL replica (failover drill)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

if docker exec redi-postgres test -f /var/lib/postgresql/data/pgdata/standby.signal 2>/dev/null; then
  docker exec redi-postgres pg_ctl promote -D /var/lib/postgresql/data/pgdata -U postgres
  log_info "Replica promoted to primary"
else
  log_info "Instance is already primary"
fi
docker exec redi-postgres psql -U postgres -c "SELECT pg_is_in_recovery();"
