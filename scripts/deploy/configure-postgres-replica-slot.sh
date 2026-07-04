#!/usr/bin/env bash
# =============================================================================
# REDI — Configure jkt replica to use physical replication slot
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-jkt-01" ]] || { log_error "Run on redi-jkt-01 only"; exit 1; }

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

SLOT_NAME="${POSTGRES_REPLICATION_SLOT:-redi_jkt_standby}"
PGDATA="/var/lib/postgresql/data/pgdata"
AUTO_CONF="${PGDATA}/postgresql.auto.conf"

docker exec redi-postgres sh -c "
  grep -q \"primary_slot_name = '${SLOT_NAME}'\" '${AUTO_CONF}' 2>/dev/null || \
    echo \"primary_slot_name = '${SLOT_NAME}'\" >> '${AUTO_CONF}'
"

docker restart redi-postgres
sleep 5
docker exec redi-postgres pg_isready -U postgres
log_info "Replica using slot ${SLOT_NAME}"
