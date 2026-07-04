#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Seed MariaDB replica from primary and start replication
# Sprint 2 Stage 2 — run on redi-sby-01 after PowerDNS stack is up
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/powerdns"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

ENV_FILE="${COMPOSE_DIR}/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

PRIMARY="${MARIADB_PRIMARY_HOST}"
PORT="${MARIADB_PORT:-3306}"
DUMP="/tmp/redi-powerdns-replica-seed.sql"

if ! docker ps --format '{{.Names}}' | grep -q '^redi-mariadb$'; then
  log_error "redi-mariadb not running on this host"
  exit 1
fi

log_info "Waiting for primary MariaDB at ${PRIMARY}:${PORT}"
wait_for_service "${PRIMARY}" "${PORT}" 120

IO_RUNNING="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" \
  -e "SHOW SLAVE STATUS\G" 2>/dev/null | awk -F': ' '/Slave_IO_Running:/{print $2}' | tr -d ' \r' || true)"
if [[ "${IO_RUNNING}" == "Yes" ]]; then
  log_info "Replication already running (Slave_IO_Running=Yes)"
  docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW SLAVE STATUS\G" \
    | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_IO_Error|Last_SQL_Error" || true
  exit 0
fi

log_info "Dumping ${MARIADB_DATABASE} from primary (with master coordinates)"
docker run --rm mariadb:10.11 mysqldump \
  -h "${PRIMARY}" -P "${PORT}" -uroot -p"${MARIADB_ROOT_PASSWORD}" \
  --single-transaction --routines --triggers --master-data=2 \
  --databases "${MARIADB_DATABASE}" > "${DUMP}"

MASTER_FILE="$(grep -m1 '^-- CHANGE MASTER TO' "${DUMP}" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")"
MASTER_POS="$(grep -m1 '^-- CHANGE MASTER TO' "${DUMP}" | sed -n "s/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p")"

if [[ -z "${MASTER_FILE}" || -z "${MASTER_POS}" ]]; then
  log_error "Could not parse MASTER_LOG_FILE/POS from dump"
  exit 1
fi

log_info "Restoring database on replica"
docker exec -i redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" < "${DUMP}"

log_info "Configuring replication (file=${MASTER_FILE}, pos=${MASTER_POS})"
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "SET GLOBAL read_only=0;"
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e \
  "CREATE USER IF NOT EXISTS '${MARIADB_PDNS_USER}'@'%' IDENTIFIED BY '${MARIADB_PDNS_PASSWORD}'; \
   GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_PDNS_USER}'@'%'; \
   FLUSH PRIVILEGES;"
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "STOP SLAVE; RESET SLAVE ALL;" 2>/dev/null || true
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e \
  "CHANGE MASTER TO MASTER_HOST='${PRIMARY}', MASTER_PORT=${PORT}, \
   MASTER_USER='${MARIADB_REPLICATION_USER}', MASTER_PASSWORD='${MARIADB_REPLICATION_PASSWORD}', \
   MASTER_LOG_FILE='${MASTER_FILE}', MASTER_LOG_POS=${MASTER_POS};"
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "START SLAVE; SET GLOBAL read_only=1;"

rm -f "${DUMP}"

sleep 5
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW SLAVE STATUS\G" \
  | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Last_IO_Error|Last_SQL_Error"

IO_RUNNING="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" \
  -e "SHOW SLAVE STATUS\G" | awk -F': ' '/Slave_IO_Running:/{print $2}' | tr -d ' \r')"
SQL_RUNNING="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" \
  -e "SHOW SLAVE STATUS\G" | awk -F': ' '/Slave_SQL_Running:/{print $2}' | tr -d ' \r')"

if [[ "${IO_RUNNING}" != "Yes" || "${SQL_RUNNING}" != "Yes" ]]; then
  log_error "Replication failed to start"
  exit 1
fi

log_info "MariaDB replication active"
