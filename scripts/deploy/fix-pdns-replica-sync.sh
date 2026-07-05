#!/usr/bin/env bash
# =============================================================================
# REDI — Repair PowerDNS MariaDB replica sync (NS2 / redi-sby-01)
# Resolves duplicate-key drift so LUA records replicate from NS1.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
[[ "${HOSTNAME}" == "redi-sby-01" ]] || {
  log_error "Run on redi-sby-01 (NS2). Current: ${HOSTNAME}"
  exit 1
}

ENV_FILE="${REDI_ROOT}/compose/powerdns/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

ROOT_PW="${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD not set}"
MYSQL=(docker exec redi-mariadb mariadb -uroot -p"${ROOT_PW}")

log_info "Checking MariaDB replication status"
"${MYSQL[@]}" -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_SQL_Error" || true

if "${MYSQL[@]}" -e "SHOW SLAVE STATUS\G" | grep -q "Slave_SQL_Running: Yes"; then
  log_info "Replica SQL thread already running"
  exit 0
fi

log_info "Stopping replica SQL thread and skipping duplicate-key event"
"${MYSQL[@]}" -e "STOP SLAVE SQL_THREAD; SET GLOBAL sql_slave_skip_counter = 1; START SLAVE SQL_THREAD;"

sleep 3
if "${MYSQL[@]}" -e "SHOW SLAVE STATUS\G" | grep -q "Slave_SQL_Running: Yes"; then
  log_info "Replica sync recovered"
  exit 0
fi

log_warn "Single skip insufficient — removing stale geo A rows on replica"
"${MYSQL[@]}" powerdns -e "
DELETE FROM records
WHERE domain_id = (SELECT id FROM domains WHERE name='letsredi.com')
  AND name IN ('git.letsredi.com','registry.letsredi.com','auth.letsredi.com','proxy.letsredi.com')
  AND type='A';
"
"${MYSQL[@]}" -e "STOP SLAVE SQL_THREAD; START SLAVE SQL_THREAD;"

sleep 5
"${MYSQL[@]}" -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_SQL_Error" || true

if "${MYSQL[@]}" -e "SHOW SLAVE STATUS\G" | grep -q "Slave_SQL_Running: Yes"; then
  log_info "Replica sync recovered after stale row cleanup"
else
  log_error "Replica still broken — manual DBA intervention required"
  exit 1
fi
