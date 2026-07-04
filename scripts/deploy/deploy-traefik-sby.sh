#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy Traefik on redi-sby-01 (Sprint 3D GeoDNS edge)
# Run this script ON redi-sby-01 as root.
#
# Prerequisites:
#   - Tailscale connected (mesh access to mjk + jkt)
#   - Docker + Compose installed
#   - compose/traefik/.env populated from .env.redi-sby-01.example
#   - PDNS_API_URL=http://100.79.82.92:8081 (jkt pdns via Tailscale)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/traefik"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

# SBY-specific env file (copy from .env.redi-sby-01.example if .env missing)
ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${COMPOSE_DIR}/.env.redi-sby-01.example" ]]; then
    log_warn ".env missing — copying from .env.redi-sby-01.example (edit secrets before use)"
    cp "${COMPOSE_DIR}/.env.redi-sby-01.example" "${ENV_FILE}"
  else
    log_error "Missing ${ENV_FILE}. Copy from .env.redi-sby-01.example and configure."
    exit 1
  fi
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

# Validate PDNS API is reachable from SBY via Tailscale
PDNS_HOST="${PDNS_API_URL#http://}"
PDNS_HOST="${PDNS_HOST%%:*}"
PDNS_PORT="${PDNS_API_URL##*:}"
log_info "Checking PowerDNS API reachability: ${PDNS_HOST}:${PDNS_PORT}"
if ! nc -z -w5 "${PDNS_HOST}" "${PDNS_PORT}" 2>/dev/null; then
  log_warn "Cannot reach PowerDNS API at ${PDNS_API_URL} — ACME DNS-01 will fail"
  log_warn "Ensure Tailscale is active and jkt pdns API is bound to Tailscale IP"
fi

# Auto-detect Tailscale IP and write to env
TS_IP="$(get_tailscale_ip)"
log_info "Tailscale IP: ${TS_IP}"
sed -i "s|^TRAEFIK_TAILSCALE_IP=.*|TRAEFIK_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"

# SBY-specific ACME storage (separate from jkt acme.json)
ACME_FILE="${REDI_ROOT}/config/traefik/acme-sby.json"
touch "${ACME_FILE}"
chmod 600 "${ACME_FILE}"
log_info "ACME store: ${ACME_FILE}"

# PowerDNS credentials for ACME DNS-01 (Traefik pdns provider reads from env)
PDNS_ENV="${REDI_ROOT}/config/traefik/powerdns.env"
cat > "${PDNS_ENV}" <<EOF
PDNS_API_URL=${PDNS_API_URL}
PDNS_API_KEY=${PDNS_API_KEY}
EOF
chmod 600 "${PDNS_ENV}"

# Docker networks (same as jkt)
ensure_docker_network "redi-proxy" "172.29.0.0/24"
ensure_docker_network "redi-management" "172.30.0.0/24"
# Note: redi-dns not needed on sby (no local pdns)

# Log dirs
mkdir -p "${REDI_ROOT}/logs/traefik-sby" "${REDI_ROOT}/data/traefik-sby"

# Deploy with SBY overlay (uses traefik.sby.yml static config + acme-sby.json)
log_info "Deploying Traefik on redi-sby-01"
cd "${COMPOSE_DIR}"
docker compose \
  -f docker-compose.yml \
  -f docker-compose.sby.yml \
  --env-file "${ENV_FILE}" \
  pull

docker compose \
  -f docker-compose.yml \
  -f docker-compose.sby.yml \
  --env-file "${ENV_FILE}" \
  up -d

sleep 5
docker compose \
  -f docker-compose.yml \
  -f docker-compose.sby.yml \
  --env-file "${ENV_FILE}" \
  ps

docker logs redi-traefik-sby --tail 30

# Verify ping
sleep 3
if curl -sf "http://localhost:8080/ping" > /dev/null 2>&1; then
  log_info "Traefik SBY ping OK"
else
  log_warn "Traefik ping on :8080 not responding yet — check logs"
fi

# Add DNS record traefik-sby.letsredi.com → SBY public IP
SBY_PUBLIC="103.80.214.144"
ZONE="letsredi.com."
PDNS_API_BASE="${PDNS_API_URL}/api/v1/servers/localhost"

log_info "Ensuring traefik-sby.letsredi.com A ${SBY_PUBLIC} in DNS"
curl -sf -X PATCH \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  "${PDNS_API_BASE}/zones/${ZONE}" \
  -d "{
    \"rrsets\": [{
      \"name\": \"traefik-sby.letsredi.com.\",
      \"type\": \"A\",
      \"ttl\": 3600,
      \"changetype\": \"REPLACE\",
      \"records\": [{\"content\": \"${SBY_PUBLIC}\", \"disabled\": false}]
    }]
  }" && log_info "DNS record traefik-sby.letsredi.com added" || log_warn "DNS update failed — run manually"

log_info "Traefik SBY deployment complete"
log_info "Next: run setup-geoip2-pdns.sh on jkt, then apply-geodns-lua.sh"
