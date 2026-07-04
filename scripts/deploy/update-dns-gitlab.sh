#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Update production DNS for GitLab (git + registry only)
# Replaces placeholder CNAMEs with proxy.letsredi.com (REDI Gateway)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
ZONE_NAME="letsredi.com"
TTL=3600
GATEWAY_CNAME="proxy.letsredi.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# shellcheck source=/dev/null
source "${ENV_FILE}"
require_root

DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
  -e "SELECT id FROM domains WHERE name='${ZONE_NAME}'" 2>/dev/null)"

# Public edge IP for production GitLab (Traefik on redi-jkt-01)
JKT_PUBLIC_IP="${JKT_PUBLIC_IP:-103.149.238.98}"

for host in git registry; do
  name="${host}.letsredi.com"
  existing="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
    -e "SELECT CONCAT(type,'|',content) FROM records WHERE domain_id=${DOMAIN_ID} AND name='${name}' LIMIT 1" 2>/dev/null || true)"
  if [[ "${existing}" == "A|${JKT_PUBLIC_IP}" ]]; then
    log_info "SKIP ${name} already A ${JKT_PUBLIC_IP}"
    continue
  fi
  log_info "UPDATE ${name}: ${existing:-missing} → A ${JKT_PUBLIC_IP}"
  docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns -e "
    DELETE FROM records WHERE domain_id=${DOMAIN_ID} AND name='${name}';
    INSERT INTO records (domain_id,name,type,content,ttl,prio,disabled,auth)
    VALUES (${DOMAIN_ID},'${name}','A','${JKT_PUBLIC_IP}',${TTL},0,0,1);
  "
done

docker exec redi-pdns-auth pdns_control reload
log_info "GitLab DNS records updated"
