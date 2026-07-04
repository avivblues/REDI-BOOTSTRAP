#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Restore PowerDNS from Backup
# Usage: restore-powerdns.sh /path/to/powerdns-mariadb.sql.gz
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

BACKUP_FILE="${1:-}"
if [[ -z "${BACKUP_FILE}" ]] || [[ ! -f "${BACKUP_FILE}" ]]; then
  log_error "Usage: restore-powerdns.sh /path/to/powerdns-mariadb.sql.gz"
  exit 1
fi

# shellcheck source=/dev/null
source "${REDI_ROOT}/compose/powerdns/.env"

log_warn "This will overwrite the PowerDNS database. Continue in 10 seconds (Ctrl+C to abort)..."
sleep 10

log_info "Stopping PowerDNS"
cd "${REDI_ROOT}/compose/powerdns"
docker compose stop pdns-auth

log_info "Restoring MariaDB from ${BACKUP_FILE}"
gunzip -c "${BACKUP_FILE}" | docker exec -i redi-mariadb \
  mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE}"

log_info "Starting PowerDNS"
docker compose start pdns-auth

sleep 5
docker exec redi-pdns-auth pdns_control rping
log_info "PowerDNS restore complete"
