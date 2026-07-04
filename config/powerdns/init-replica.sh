#!/bin/bash
# =============================================================================
# MariaDB Replica — Configure replication from primary
# =============================================================================
set -euo pipefail

PRIMARY_HOST="${MARIADB_PRIMARY_HOST}"
PRIMARY_PORT="${MARIADB_PORT:-3306}"

echo "Waiting for primary MariaDB at ${PRIMARY_HOST}:${PRIMARY_PORT}..."
until mysqladmin ping -h "${PRIMARY_HOST}" -P "${PRIMARY_PORT}" --silent 2>/dev/null; do
  sleep 3
done

mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
  STOP SLAVE;
  CHANGE MASTER TO
    MASTER_HOST='${PRIMARY_HOST}',
    MASTER_PORT=${PRIMARY_PORT},
    MASTER_USER='${MARIADB_REPLICATION_USER}',
    MASTER_PASSWORD='${MARIADB_REPLICATION_PASSWORD}',
    MASTER_AUTO_POSITION=1;
  START SLAVE;
EOSQL

echo "Replica replication configured"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW SLAVE STATUS\G"
