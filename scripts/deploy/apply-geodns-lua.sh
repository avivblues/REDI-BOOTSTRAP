#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Apply GeoDNS Lua records to PowerDNS (Sprint 3D)
# Run on redi-jkt-01 as root (or any node with API access to jkt pdns).
#
# What this does:
#   - Converts public proxy/app A records to LUA type in PowerDNS
#   - Geo-logic: Jawa Timur (subdivision JI) → SBY (103.80.214.144)
#                all others                   → JKT (103.149.238.98)
#   - Adds traefik-sby.letsredi.com A record
#   - DOES NOT touch: ns1, ns2, internal .redi.internal, postgres/redis/minio
#
# Idempotent — safe to re-run. LUA records are REPLACED, not appended.
#
# Prerequisite: setup-geoip2-pdns.sh must have been run first.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PDNS_ENV="${REDI_ROOT}/compose/powerdns/.env"
[[ -f "${PDNS_ENV}" ]] || { log_error "Missing ${PDNS_ENV}"; exit 1; }
# shellcheck source=/dev/null
source "${PDNS_ENV}"

PDNS_API_URL="${PDNS_API_URL:-http://127.0.0.1:8081}"
if ! curl -sf -o /dev/null -H "X-API-Key: ${PDNS_API_KEY}" "${PDNS_API_URL}/api/v1/servers/localhost" 2>/dev/null; then
  PDNS_API_URL="http://$(get_tailscale_ip):${PDNS_WEBSERVER_PORT:-8081}"
fi
ZONE="letsredi.com."
API="${PDNS_API_URL}/api/v1/servers/localhost/zones/${ZONE}"

JKT_IP="103.149.238.98"
SBY_IP="103.80.214.144"
MMDB_PATH="/etc/powerdns/geoip/GeoLite2-City.mmdb"
JT_CIDR="103.80.214.0/24"

# ---------------------------------------------------------------------------
# Helper: call pdns API
# ---------------------------------------------------------------------------
pdns_patch() {
  local payload="$1"
  local resp http_code
  resp="$(curl -s -w $'\n%{http_code}' -X PATCH \
    -H "X-API-Key: ${PDNS_API_KEY}" \
    -H "Content-Type: application/json" \
    "${API}" \
    -d "${payload}")"
  http_code="${resp##*$'\n'}"
  if [[ "${http_code}" =~ ^2 ]]; then
    return 0
  fi
  log_error "PowerDNS API PATCH failed (HTTP ${http_code}): ${resp%$'\n'*}"
  return 1
}

pdns_get_record() {
  local name="$1" type="$2"
  curl -sf \
    -H "X-API-Key: ${PDNS_API_KEY}" \
    "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rr in data.get('rrsets', []):
    if rr['name'] == '${name}.' and rr['type'] == '${type}':
        print(json.dumps(rr))
" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Build LUA record content
# GeoIP2: subdivisions[0].iso_code == 'JI' (Jawa Timur) → SBY
#         fallback if mmdb lookup fails → JKT
# bestwho() returns ECS client IP if present, else resolver IP
# ---------------------------------------------------------------------------
geo_lua_content() {
  cat <<EOF
A ";local ip=bestwho:toString():gsub(':%d+$',''); if ip:match('^103%.80%.214%.') then return {'${SBY_IP}'} end; local m=require('mmdb'); local db=m.open('${MMDB_PATH}'); local res=db:search_ipv4(ip); if res and res.subdivisions and res.subdivisions[1] then local c=res.subdivisions[1].iso_code or res.subdivisions[1]['iso_code']; if c=='JI' then return {'${SBY_IP}'} end end; return {'${JKT_IP}'}"
EOF
}

LUA_CONTENT="$(geo_lua_content | tr -d '\n')"

log_info "GeoDNS Lua logic: ${JT_CIDR} or Jawa Timur (JI) → ${SBY_IP} | others → ${JKT_IP}"

# ---------------------------------------------------------------------------
# Records to geo-route (public, behind Traefik edge)
# Guard: NEVER touch ns1, ns2, portainer, mesh, redi.internal records
# ---------------------------------------------------------------------------
GEO_RECORDS=(
  "git.letsredi.com."
  "registry.letsredi.com."
  "auth.letsredi.com."
  "proxy.letsredi.com."
)

NOT_GEO_RECORDS=(
  "ns1.letsredi.com."
  "ns2.letsredi.com."
  "postgres.redi.internal."
  "redis.redi.internal."
  "minio.redi.internal."
)

log_info "Records protected (NOT geo-routed): ${NOT_GEO_RECORDS[*]}"
log_info ""

# ---------------------------------------------------------------------------
# Step 1: Add traefik-sby.letsredi.com A record (SBY Traefik anchor)
# ---------------------------------------------------------------------------
log_info "[DNS] traefik-sby.letsredi.com A ${SBY_IP}"
pdns_patch "{
  \"rrsets\": [{
    \"name\": \"traefik-sby.letsredi.com.\",
    \"type\": \"A\",
    \"ttl\": 3600,
    \"changetype\": \"REPLACE\",
    \"records\": [{\"content\": \"${SBY_IP}\", \"disabled\": false}]
  }]
}" && log_info "  → OK" || log_warn "  → FAILED"

# ---------------------------------------------------------------------------
# Step 2: Convert each public record to LUA type
# For CNAME records (proxy.letsredi.com): delete CNAME first, then add LUA
# For A records: delete A first, then add LUA
# Using two separate PATCH calls for clarity
# ---------------------------------------------------------------------------

convert_to_lua() {
  local fqdn="$1"
  local short="${fqdn%.}"

  log_info "[GEO] Converting ${short} → LUA"

  # Check what type currently exists
  local existing_type
  existing_type=$(curl -sf \
    -H "X-API-Key: ${PDNS_API_KEY}" \
    "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rr in data.get('rrsets', []):
    if rr['name'] == '${fqdn}':
        print(rr['type'])
        break
" 2>/dev/null || echo "")

  if [[ -n "${existing_type}" && "${existing_type}" != "LUA" ]]; then
    log_info "  Removing existing ${existing_type} record for ${short}"
    pdns_patch "{
      \"rrsets\": [{
        \"name\": \"${fqdn}\",
        \"type\": \"${existing_type}\",
        \"changetype\": \"DELETE\"
      }]
    }" || log_warn "  Delete ${existing_type} failed (may not exist)"
  fi

  # Insert LUA record (TTL 30 — low TTL for geo records to enable fast failover)
  pdns_patch "{
    \"rrsets\": [{
      \"name\": \"${fqdn}\",
      \"type\": \"LUA\",
      \"ttl\": 30,
      \"changetype\": \"REPLACE\",
      \"records\": [{
        \"content\": $(echo "${LUA_CONTENT}" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))'),
        \"disabled\": false
      }]
    }]
  }" && log_info "  → LUA record applied (TTL 30)" || log_error "  → FAILED to apply LUA record for ${fqdn}"
}

for record in "${GEO_RECORDS[@]}"; do
  convert_to_lua "${record}"
done

# ---------------------------------------------------------------------------
# Step 3: Notify replica (sby) to refresh zone
# ---------------------------------------------------------------------------
log_info ""
log_info "[NOTIFY] Triggering AXFR notify to ns2.letsredi.com (sby)..."
docker exec redi-pdns-auth \
  pdns_control notify letsredi.com 2>/dev/null \
  && log_info "  → Notify sent to replicas" \
  || log_warn "  → Notify failed — replica will sync on SOA refresh"

# ---------------------------------------------------------------------------
# Step 4: Bump SOA serial and flush caches
# ---------------------------------------------------------------------------
log_info "[SOA] Rectifying zone and flushing cache..."
docker exec redi-pdns-auth \
  pdnsutil rectify-zone letsredi.com 2>/dev/null \
  && log_info "  → Zone rectified" || true

docker exec redi-pdns-auth \
  pdns_control purge letsredi.com 2>/dev/null \
  && log_info "  → DNS cache purged" || true

# ---------------------------------------------------------------------------
# Step 5: Verify LUA records are readable back via API
# ---------------------------------------------------------------------------
log_info ""
log_info "Verifying LUA records in zone..."
curl -sf \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
lua_records = [rr for rr in data.get('rrsets', []) if rr['type'] == 'LUA']
if lua_records:
    print(f'  LUA records ({len(lua_records)} total):')
    for rr in lua_records:
        print(f'    {rr[\"name\"]}  TTL={rr[\"ttl\"]}')
else:
    print('  No LUA records found!')
"

log_info ""
log_info "GeoDNS Lua records applied."
log_info "Run validate-geodns.sh to verify geo-routing behaviour."
log_info ""
log_info "3D.5 Guard: internal records NOT touched:"
for r in "${NOT_GEO_RECORDS[@]}"; do
  log_info "  ${r} — unchanged"
done
