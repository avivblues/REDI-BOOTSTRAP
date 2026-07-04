#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Create production DNS zone via PowerDNS API
# Usage: create-production-zone.sh [--env /opt/redi/compose/powerdns/.env] [--zone letsredi.com]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
ZONE_NAME="letsredi.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --zone) ZONE_NAME="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# shellcheck source=/dev/null
source "${ENV_FILE}"

API_BASE="http://${PDNS_TAILSCALE_IP}:${PDNS_WEBSERVER_PORT}/api/v1"
ZONE="${ZONE_NAME}."
SERIAL="$(date +%Y%m%d)01"
NS1="ns1.${ZONE_NAME}."
NS2="ns2.${ZONE_NAME}."
JKT_PUBLIC="${PDNS_NS1_IP:-103.149.238.98}"
SBY_PUBLIC="${PDNS_NS2_IP:-103.80.214.144}"
JKT_MESH="${PDNS_NS1_MESH_IP:-100.79.82.92}"
SBY_MESH="${PDNS_NS2_MESH_IP:-100.79.40.61}"
MJK_MESH="${PDNS_MGMT_MESH_IP:-100.81.86.37}"

curl -sf -X POST "${API_BASE}/servers/localhost/zones" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${ZONE}\",\"kind\":\"Native\",\"nameservers\":[\"${NS1}\",\"${NS2}\"]}" \
  2>/dev/null || true

if ! curl -sf "${API_BASE}/servers/localhost/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" >/dev/null 2>&1; then
  log_warn "API zone create failed — applying via MariaDB SQL"
  docker exec -i redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE:-powerdns}" <<EOSQL
INSERT INTO domains (name, type, account) VALUES ('${ZONE_NAME}', 'NATIVE', 'redi-admin')
ON DUPLICATE KEY UPDATE account='redi-admin';
SET @did = (SELECT id FROM domains WHERE name='${ZONE_NAME}');
DELETE FROM records WHERE domain_id=@did;
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth) VALUES
(@did, '${ZONE_NAME}', 'SOA', '${NS1} hostmaster.${ZONE_NAME}. ${SERIAL} 3600 600 604800 3600', 3600, 0, 0, 1),
(@did, '${ZONE_NAME}', 'NS', 'ns1.${ZONE_NAME}', 3600, 0, 0, 1),
(@did, '${ZONE_NAME}', 'NS', 'ns2.${ZONE_NAME}', 3600, 0, 0, 1),
(@did, 'ns1.${ZONE_NAME}', 'A', '${JKT_PUBLIC}', 300, 0, 0, 1),
(@did, 'ns2.${ZONE_NAME}', 'A', '${SBY_PUBLIC}', 300, 0, 0, 1),
(@did, '${ZONE_NAME}', 'A', '${JKT_PUBLIC}', 300, 0, 0, 1),
(@did, 'www.${ZONE_NAME}', 'CNAME', '${ZONE_NAME}', 300, 0, 0, 1),
(@did, 'traefik-jkt.${ZONE_NAME}', 'A', '${JKT_MESH}', 300, 0, 0, 1),
(@did, 'traefik-sby.${ZONE_NAME}', 'A', '${SBY_MESH}', 300, 0, 0, 1),
(@did, 'portainer.${ZONE_NAME}', 'A', '${MJK_MESH}', 300, 0, 0, 1),
(@did, 'api.${ZONE_NAME}', 'CNAME', 'traefik-jkt.${ZONE_NAME}', 300, 0, 0, 1);
EOSQL
  docker exec redi-pdns-auth pdns_control reload
  echo "Production zone ${ZONE} created/updated via SQL (serial ${SERIAL})"
  exit 0
fi

curl -sf -X PATCH "${API_BASE}/servers/localhost/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"rrsets\": [
      {
        \"name\": \"${ZONE}\",
        \"type\": \"SOA\",
        \"ttl\": 3600,
        \"changetype\": \"REPLACE\",
        \"records\": [{
          \"content\": \"${NS1} hostmaster.${ZONE_NAME}. ${SERIAL} 3600 600 604800 3600\",
          \"disabled\": false
        }]
      },
      {
        \"name\": \"${ZONE}\",
        \"type\": \"NS\",
        \"ttl\": 3600,
        \"changetype\": \"REPLACE\",
        \"records\": [
          {\"content\": \"${NS1}\", \"disabled\": false},
          {\"content\": \"${NS2}\", \"disabled\": false}
        ]
      },
      {
        \"name\": \"${NS1}\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${JKT_PUBLIC}\", \"disabled\": false}]
      },
      {
        \"name\": \"${NS2}\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${SBY_PUBLIC}\", \"disabled\": false}]
      },
      {
        \"name\": \"${ZONE_NAME}.\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${JKT_PUBLIC}\", \"disabled\": false}]
      },
      {
        \"name\": \"www.${ZONE_NAME}.\",
        \"type\": \"CNAME\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${ZONE}\", \"disabled\": false}]
      },
      {
        \"name\": \"traefik-jkt.${ZONE_NAME}.\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${JKT_MESH}\", \"disabled\": false}]
      },
      {
        \"name\": \"traefik-sby.${ZONE_NAME}.\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${SBY_MESH}\", \"disabled\": false}]
      },
      {
        \"name\": \"portainer.${ZONE_NAME}.\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${MJK_MESH}\", \"disabled\": false}]
      },
      {
        \"name\": \"api.${ZONE_NAME}.\",
        \"type\": \"CNAME\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"traefik-jkt.${ZONE_NAME}.\", \"disabled\": false}]
      }
    ]
  }"

echo "Production zone ${ZONE} created/updated (serial ${SERIAL})"
