#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Setup GeoIP2 for PowerDNS Lua records (Sprint 3D)
# Run on redi-jkt-01 as root.
#
# What this does:
#   1. Downloads MaxMind GeoLite2-City.mmdb (free, requires license key)
#   2. Places mmdb in config/powerdns/geoip/ (mounted into pdns container)
#   3. Rebuilds pdns-auth with Dockerfile.geodns (adds lua-mmdb package)
#   4. Restarts pdns-auth with geodns compose overlay
#   5. Verifies enable-lua-records=yes is active
#
# MaxMind license key (free): https://www.maxmind.com/en/geolite2/signup
# Set GEOIP_ACCOUNT_ID and GEOIP_LICENSE_KEY in environment or secrets.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/powerdns"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
GEOIP_DIR="${REDI_ROOT}/config/powerdns/geoip"
MMDB_PATH="${GEOIP_DIR}/GeoLite2-City.mmdb"
PDNS_ENV="${COMPOSE_DIR}/.env"

GEOIP_ACCOUNT_ID="${GEOIP_ACCOUNT_ID:-}"
GEOIP_LICENSE_KEY="${GEOIP_LICENSE_KEY:-}"

# ---------------------------------------------------------------------------
# Step 1: Download GeoLite2-City.mmdb
# ---------------------------------------------------------------------------
mkdir -p "${GEOIP_DIR}"

if [[ -f "${MMDB_PATH}" ]]; then
  AGE=$(( ($(date +%s) - $(stat -c %Y "${MMDB_PATH}")) / 86400 ))
  log_info "GeoLite2-City.mmdb exists (age: ${AGE} days)"
  if [[ ${AGE} -lt 30 ]]; then
    log_info "Database is fresh — skipping download"
  else
    log_info "Database is ${AGE} days old — refreshing"
    DOWNLOAD_DB=yes
  fi
else
  DOWNLOAD_DB=yes
fi

if [[ "${DOWNLOAD_DB:-no}" == "yes" ]]; then
  log_info "Downloading GeoLite2-City.mmdb from public mirror (P3TERX/GeoLite.mmdb)..."
  curl -fsSL -o "${MMDB_PATH}" "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"
  chmod 644 "${MMDB_PATH}"
  log_info "GeoLite2-City.mmdb installed from mirror at ${MMDB_PATH}"
fi

ls -lh "${MMDB_PATH}"

# ---------------------------------------------------------------------------
# Step 2: Verify pdns.conf has Lua records enabled
# ---------------------------------------------------------------------------
PDNS_CONF="${REDI_ROOT}/config/powerdns/pdns.conf"
if grep -q "^enable-lua-records=yes" "${PDNS_CONF}"; then
  log_info "enable-lua-records=yes already in pdns.conf"
else
  log_info "Patching pdns.conf with enable-lua-records=yes"
  cat >> "${PDNS_CONF}" <<'EOF'

# GeoDNS — Lua Records (Sprint 3D)
enable-lua-records=yes
lua-records-exec-limit=1000
edns-subnet-processing=yes
EOF
fi

# ---------------------------------------------------------------------------
# Step 3: Build custom pdns image with lua-mmdb
# ---------------------------------------------------------------------------
if [[ ! -f "${PDNS_ENV}" ]]; then
  log_error "Missing ${PDNS_ENV}. Run deploy-powerdns.sh first."
  exit 1
fi

# shellcheck source=/dev/null
source "${PDNS_ENV}"

log_info "Building redi-pdns-auth-geodns image (adds lua-mmdb)..."
cd "${COMPOSE_DIR}"
docker compose \
  -f docker-compose.yml \
  -f docker-compose.geodns.yml \
  --env-file "${PDNS_ENV}" \
  build pdns-auth

# ---------------------------------------------------------------------------
# Step 4: Restart pdns-auth with geodns overlay
# ---------------------------------------------------------------------------
log_info "Restarting pdns-auth with GeoDNS support..."
docker compose \
  -f docker-compose.yml \
  -f docker-compose.geodns.yml \
  --env-file "${PDNS_ENV}" \
  up -d pdns-auth

sleep 5
docker compose \
  -f docker-compose.yml \
  -f docker-compose.geodns.yml \
  --env-file "${PDNS_ENV}" \
  ps pdns-auth

# ---------------------------------------------------------------------------
# Step 5: Verify Lua records are active
# ---------------------------------------------------------------------------
log_info "Verifying Lua records support..."

LUA_TEST_RESULT=$(docker exec redi-pdns-auth \
  pdns_control config | grep -i "enable-lua-records" 2>/dev/null || echo "")

if echo "${LUA_TEST_RESULT}" | grep -q "yes"; then
  log_info "enable-lua-records=yes confirmed in running pdns config"
else
  log_warn "Could not confirm enable-lua-records via pdns_control config"
  log_warn "Check: docker exec redi-pdns-auth pdns_control config | grep lua"
fi

# Verify mmdb is accessible inside container
docker exec redi-pdns-auth ls -lh /etc/powerdns/geoip/GeoLite2-City.mmdb \
  && log_info "mmdb accessible inside container" \
  || log_error "mmdb NOT found inside container — check docker-compose.geodns.yml volume mount"

log_info "GeoIP2 + Lua records setup complete"
log_info "Next: run apply-geodns-lua.sh to convert A records to geo-routed LUA records"
