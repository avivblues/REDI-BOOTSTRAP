#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Create test DNS zone via PowerDNS API
# Usage: create-test-zone.sh [--env /opt/redi/compose/powerdns/.env]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# shellcheck source=/dev/null
source "${ENV_FILE}"

API_BASE="http://${PDNS_TAILSCALE_IP}:${PDNS_WEBSERVER_PORT}/api/v1"
ZONE="${REDI_DOMAIN:-redi.lab}."
NS1="ns1.${REDI_DOMAIN:-redi.lab}."
NS2="ns2.${REDI_DOMAIN:-redi.lab}."
TEST_HOST="test.${REDI_DOMAIN:-redi.lab}."
JKT_PUBLIC="${PDNS_NS1_IP:-103.149.238.98}"
SBY_PUBLIC="${PDNS_NS2_IP:-103.80.214.144}"

curl -sf -X POST "${API_BASE}/servers/localhost/zones" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${ZONE}\",\"kind\":\"Native\",\"nameservers\":[\"${NS1}\",\"${NS2}\"]}" \
  2>/dev/null || true

curl -sf -X PATCH "${API_BASE}/servers/localhost/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"rrsets\": [
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
        \"name\": \"${TEST_HOST}\",
        \"type\": \"A\",
        \"ttl\": 300,
        \"changetype\": \"REPLACE\",
        \"records\": [{\"content\": \"${JKT_PUBLIC}\", \"disabled\": false}]
      }
    ]
  }"

echo "Test zone ${ZONE} created/updated"
