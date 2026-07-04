#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Setup PowerDNS .env and pdns.conf on JKT and SBY nodes
# Run from local workspace.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Credentials
MJK_HOST="103.80.214.226"; MJK_PORT=2280; MJK_USER="root";   MJK_PW='!Proxmox@Redi123'
JKT_HOST="103.149.238.98"; JKT_PORT=22;   JKT_USER="devapp"; JKT_PW='BitApp2026!@#'
SBY_HOST="103.80.214.144"; SBY_PORT=2280; SBY_USER="root";   SBY_PW='!Proxmox@Redi123'

ssh_run() {
  local host="$1" port="$2" user="$3" pw="$4"
  shift 4
  sshpass -p "${pw}" ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -p "${port}" \
    "${user}@${host}" "$@"
}

echo "Generating PowerDNS .env and pdns.conf for redi-jkt-01..."
# Write .env on JKT
ssh_run "${JKT_HOST}" "${JKT_PORT}" "${JKT_USER}" "${JKT_PW}" "cat > /opt/redi/compose/powerdns/.env" << 'EOF'
PDNS_NODE_ROLE=primary
PDNS_HOSTNAME=redi-jkt-01
PDNS_TAILSCALE_IP=100.79.82.92
MARIADB_PRIMARY_HOST=100.79.82.92
MARIADB_PORT=3306
MARIADB_ROOT_PASSWORD=41P66r6hqnKOo3gdlMVNWqHrXAE1twcV
MARIADB_REPLICATION_USER=repl_user
MARIADB_REPLICATION_PASSWORD=lb0oG2GO3plpx2yj4pT2kKNHseupUMrV
MARIADB_PDNS_USER=pdns
MARIADB_PDNS_PASSWORD=FAoHoZGkAPqA3TJrJJApbC3c
MARIADB_DATABASE=powerdns
PDNS_API_KEY=gTdeiOyI2gr49qVzpQkFA1nFPchUMHkxvkVFc8Dh
PDNS_WEBSERVER_ADDRESS=0.0.0.0
PDNS_WEBSERVER_PORT=8081
PDNS_WEBSERVER_ALLOW_FROM=100.64.0.0/10,127.0.0.1,172.28.0.0/24
REDI_DOMAIN=letsredi.com
PDNS_SOA_RNAME=hostmaster.letsredi.com
PDNS_SOA_REFRESH=3600
PDNS_SOA_RETRY=600
PDNS_SOA_EXPIRE=604800
PDNS_SOA_MINIMUM=3600
MARIADB_IMAGE=mariadb:10.11
PDNS_IMAGE=powerdns/pdns-auth-48:4.8.4
PDNS_CONFIG_PATH=../../config/powerdns
PDNS_DATA_PATH=../../data/powerdns
PDNS_LOG_PATH=../../logs/powerdns
EOF

# Render pdns.conf on JKT
ssh_run "${JKT_HOST}" "${JKT_PORT}" "${JKT_USER}" "${JKT_PW}" "
  export MARIADB_PDNS_USER=pdns
  export MARIADB_PDNS_PASSWORD=FAoHoZGkAPqA3TJrJJApbC3c
  export MARIADB_DATABASE=powerdns
  export PDNS_API_KEY=gTdeiOyI2gr49qVzpQkFA1nFPchUMHkxvkVFc8Dh
  export PDNS_WEBSERVER_ADDRESS=0.0.0.0
  export PDNS_WEBSERVER_PORT=8081
  export PDNS_WEBSERVER_ALLOW_FROM=100.64.0.0/10,127.0.0.1,172.28.0.0/24
  export PDNS_HOSTNAME=redi-jkt-01
  export PDNS_SOA_RNAME=hostmaster.letsredi.com
  export PDNS_SOA_REFRESH=3600
  export PDNS_SOA_RETRY=600
  export PDNS_SOA_EXPIRE=604800
  export PDNS_SOA_MINIMUM=3600
  export MARIADB_HOST=mariadb
  envsubst < /opt/redi/config/powerdns/pdns.conf.template > /opt/redi/config/powerdns/pdns.conf
  chmod 644 /opt/redi/config/powerdns/pdns.conf
"

# Restart pdns stack on JKT (with geodns support if built)
ssh_run "${JKT_HOST}" "${JKT_PORT}" "${JKT_USER}" "${JKT_PW}" "
  cd /opt/redi/compose/powerdns
  # Check if custom geodns image exists, if not build it
  if docker image inspect redi-pdns-auth-geodns:latest &>/dev/null; then
    docker compose -f docker-compose.yml -f docker-compose.geodns.yml --env-file .env up -d pdns-auth --force-recreate
  else
    # Build and start
    docker compose -f docker-compose.yml -f docker-compose.geodns.yml --env-file .env build pdns-auth
    docker compose -f docker-compose.yml -f docker-compose.geodns.yml --env-file .env up -d pdns-auth --force-recreate
  fi
"

echo "Generating PowerDNS .env and pdns.conf for redi-sby-01..."
# Write .env on SBY
ssh_run "${SBY_HOST}" "${SBY_PORT}" "${SBY_USER}" "${SBY_PW}" "cat > /opt/redi/compose/powerdns/.env" << 'EOF'
PDNS_NODE_ROLE=replica
PDNS_HOSTNAME=redi-sby-01
PDNS_TAILSCALE_IP=100.67.138.25
MARIADB_PRIMARY_HOST=100.79.82.92
MARIADB_PORT=3306
MARIADB_ROOT_PASSWORD=41P66r6hqnKOo3gdlMVNWqHrXAE1twcV
MARIADB_REPLICATION_USER=repl_user
MARIADB_REPLICATION_PASSWORD=lb0oG2GO3plpx2yj4pT2kKNHseupUMrV
MARIADB_PDNS_USER=pdns
MARIADB_PDNS_PASSWORD=FAoHoZGkAPqA3TJrJJApbC3c
MARIADB_DATABASE=powerdns
PDNS_API_KEY=gTdeiOyI2gr49qVzpQkFA1nFPchUMHkxvkVFc8Dh
PDNS_WEBSERVER_ADDRESS=0.0.0.0
PDNS_WEBSERVER_PORT=8081
PDNS_WEBSERVER_ALLOW_FROM=100.64.0.0/10,127.0.0.1,172.28.0.0/24
REDI_DOMAIN=letsredi.com
PDNS_SOA_RNAME=hostmaster.letsredi.com
PDNS_SOA_REFRESH=3600
PDNS_SOA_RETRY=600
PDNS_SOA_EXPIRE=604800
PDNS_SOA_MINIMUM=3600
MARIADB_IMAGE=mariadb:10.11
PDNS_IMAGE=powerdns/pdns-auth-48:4.8.4
PDNS_CONFIG_PATH=../../config/powerdns
PDNS_DATA_PATH=../../data/powerdns
PDNS_LOG_PATH=../../logs/powerdns
EOF

# Render pdns.conf on SBY
ssh_run "${SBY_HOST}" "${SBY_PORT}" "${SBY_USER}" "${SBY_PW}" "
  export MARIADB_PDNS_USER=pdns
  export MARIADB_PDNS_PASSWORD=FAoHoZGkAPqA3TJrJJApbC3c
  export MARIADB_DATABASE=powerdns
  export PDNS_API_KEY=gTdeiOyI2gr49qVzpQkFA1nFPchUMHkxvkVFc8Dh
  export PDNS_WEBSERVER_ADDRESS=0.0.0.0
  export PDNS_WEBSERVER_PORT=8081
  export PDNS_WEBSERVER_ALLOW_FROM=100.64.0.0/10,127.0.0.1,172.28.0.0/24
  export PDNS_HOSTNAME=redi-sby-01
  export PDNS_SOA_RNAME=hostmaster.letsredi.com
  export PDNS_SOA_REFRESH=3600
  export PDNS_SOA_RETRY=600
  export PDNS_SOA_EXPIRE=604800
  export PDNS_SOA_MINIMUM=3600
  export MARIADB_HOST=mariadb
  envsubst < /opt/redi/config/powerdns/pdns.conf.template > /opt/redi/config/powerdns/pdns.conf
  chmod 644 /opt/redi/config/powerdns/pdns.conf
"

# Restart pdns stack on SBY (replica does not use geodns build usually, let's keep it simple)
ssh_run "${SBY_HOST}" "${SBY_PORT}" "${SBY_USER}" "${SBY_PW}" "
  cd /opt/redi/compose/powerdns
  docker compose -f docker-compose.replica-stack.yml --env-file .env up -d pdns-auth --force-recreate
"

echo "Re-deploy and config updates finished."
