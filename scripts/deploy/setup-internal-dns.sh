#!/usr/bin/env bash
# =============================================================================
# REDI — Register shared platform internal DNS (redi.internal zone)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

PLATFORM_ENV="${SCRIPT_DIR}/../../compose/shared-platform/.env"
MJK="$(grep -E '^MJK_MESH_IP=' "${PLATFORM_ENV}" | cut -d= -f2- | tr -d '"' | tr -d "'")"

ZONE="redi.internal"
TTL=300

DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
  -e "SELECT id FROM domains WHERE name='${ZONE}'" 2>/dev/null || true)"

if [[ -z "${DOMAIN_ID}" ]]; then
  docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns -e "
    INSERT INTO domains (name,type) VALUES ('${ZONE}','NATIVE');
  "
  DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
    -e "SELECT id FROM domains WHERE name='${ZONE}'")"
  docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns -e "
    INSERT INTO records (domain_id,name,type,content,ttl,prio,disabled,auth) VALUES
    (${DOMAIN_ID},'${ZONE}','SOA','ns1.letsredi.com. hostmaster.letsredi.com. 1 3600 600 604800 300',${TTL},0,0,1),
    (${DOMAIN_ID},'${ZONE}','NS','ns1.letsredi.com.',${TTL},0,0,1);
  "
  log_info "Created zone ${ZONE}"
fi

for host in postgres redis minio; do
  name="${host}.${ZONE}"
  docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns -e "
    DELETE FROM records WHERE domain_id=${DOMAIN_ID} AND name='${name}';
    INSERT INTO records (domain_id,name,type,content,ttl,prio,disabled,auth)
    VALUES (${DOMAIN_ID},'${name}','A','${MJK}',${TTL},0,0,1);
  "
  log_info "DNS ${name} → ${MJK}"
done

docker exec redi-pdns-auth pdns_control reload 2>/dev/null || true
log_info "Internal DNS records published"
