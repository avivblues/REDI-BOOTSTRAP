#!/usr/bin/env bash
# =============================================================================
# REDI Phase 7 — Update DNS for Grafana (public Traefik edge)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
ZONE_NAME="letsredi.com"
TTL=3600
JKT_PUBLIC_IP="${JKT_PUBLIC_IP:-103.149.238.98}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# shellcheck source=/dev/null
source "${ENV_FILE}"
require_root

[[ "$(hostname -s)" == "redi-jkt-01" ]] || { log_error "Run on redi-jkt-01 (PowerDNS primary)"; exit 1; }

DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
  -e "SELECT id FROM domains WHERE name='${ZONE_NAME}'" 2>/dev/null)"

for name in grafana.letsredi.com prometheus.letsredi.com status.letsredi.com; do
  log_info "UPDATE ${name} → A ${JKT_PUBLIC_IP}"
  docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns -e "
    DELETE FROM records WHERE domain_id=${DOMAIN_ID} AND name='${name}';
    INSERT INTO records (domain_id,name,type,content,ttl,prio,disabled,auth)
    VALUES (${DOMAIN_ID},'${name}','A','${JKT_PUBLIC_IP}',${TTL},0,0,1);
  "
done

docker exec redi-pdns-auth pdns_control reload
log_info "Monitoring DNS updated (Grafana/Prometheus/Status → Traefik edge)"
