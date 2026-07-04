#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Update PowerDNS redis.redi.internal from Sentinel master
# Run on redi-jkt-01 (PowerDNS primary) or via SSH from mjk
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/redis-sentinel.sh"

PLATFORM_ENV="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
[[ -f "${PLATFORM_ENV}" ]] && source "${PLATFORM_ENV}"

ZONE="redi.internal"
HOST="redis.${ZONE}"
TTL="${REDIS_DNS_TTL:-60}"
STATE_FILE="${REDI_ROOT}/config/shared-platform/.redis-dns-ip"

mapfile -t _master < <(redis_sentinel_master_addr || true)
MASTER_IP="${_master[0]:-}"
[[ -n "${MASTER_IP}" ]] || { log_error "Cannot resolve Sentinel master"; exit 1; }

PREV="$(cat "${STATE_FILE}" 2>/dev/null || true)"
if [[ "${PREV}" == "${MASTER_IP}" ]]; then
  log_info "PowerDNS ${HOST} unchanged (${MASTER_IP})"
  exit 0
fi

if ! docker ps --format '{{.Names}}' | grep -qx 'redi-mariadb'; then
  log_error "redi-mariadb not running — run on redi-jkt-01"
  exit 1
fi

MARIADB_ROOT="$(docker exec redi-mariadb printenv MARIADB_ROOT_PASSWORD)"
DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT}" powerdns \
  -e "SELECT id FROM domains WHERE name='${ZONE}'" 2>/dev/null)"

[[ -n "${DOMAIN_ID}" ]] || { log_error "Zone ${ZONE} missing — run setup-internal-dns.sh"; exit 1; }

docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT}" powerdns -e "
  DELETE FROM records WHERE domain_id=${DOMAIN_ID} AND name='${HOST}';
  INSERT INTO records (domain_id,name,type,content,ttl,prio,disabled,auth)
  VALUES (${DOMAIN_ID},'${HOST}','A','${MASTER_IP}',${TTL},0,0,1);
"
docker exec redi-pdns-auth pdns_control reload 2>/dev/null || true
echo "${MASTER_IP}" > "${STATE_FILE}"
log_info "PowerDNS ${HOST} → ${MASTER_IP}"
