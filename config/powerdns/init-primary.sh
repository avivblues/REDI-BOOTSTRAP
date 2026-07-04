#!/bin/bash
# =============================================================================
# MariaDB Primary — Initialize replication user and PowerDNS schema
# =============================================================================
set -euo pipefail

mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
  CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

  CREATE USER IF NOT EXISTS '${MARIADB_PDNS_USER}'@'%' IDENTIFIED BY '${MARIADB_PDNS_PASSWORD}';
  GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_PDNS_USER}'@'%';

  CREATE USER IF NOT EXISTS '${MARIADB_REPLICATION_USER}'@'%' IDENTIFIED BY '${MARIADB_REPLICATION_PASSWORD}';
  GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${MARIADB_REPLICATION_USER}'@'%';

  FLUSH PRIVILEGES;
EOSQL

echo "Primary MariaDB initialized with PowerDNS schema"
