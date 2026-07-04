#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy Traefik
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/traefik"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}. Copy from .env.example and configure."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

# Set Tailscale IP
TS_IP="$(get_tailscale_ip)"
if grep -q "^TRAEFIK_TAILSCALE_IP=" "${ENV_FILE}"; then
  sed -i "s|^TRAEFIK_TAILSCALE_IP=.*|TRAEFIK_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
fi

# Ensure ACME store exists with correct permissions
touch "${REDI_ROOT}/config/traefik/acme.json"
chmod 600 "${REDI_ROOT}/config/traefik/acme.json"

# Create PowerDNS provider env file for Traefik DNS challenge
cat > "${REDI_ROOT}/config/traefik/powerdns.env" <<EOF
PDNS_API_URL=${PDNS_API_URL}
PDNS_API_KEY=${PDNS_API_KEY}
EOF
chmod 600 "${REDI_ROOT}/config/traefik/powerdns.env"

# Update traefik.yml ACME email from env
sed -i "s|email:.*|email: ${REDI_ACME_EMAIL}|" \
  "${REDI_ROOT}/config/traefik/traefik.yml"

# Update dashboard hostname in routers (placeholder avoids sed breaking YAML)
HOSTNAME="$(hostname -s)"
DASHBOARD_DOMAIN="traefik-${HOSTNAME#redi-}.redi.lab"
if [[ -f "${REDI_ROOT}/config/traefik/dynamic/routers.yml" ]]; then
  sed -i "s|__TRAEFIK_DASHBOARD_HOST__|${DASHBOARD_DOMAIN}|g" \
    "${REDI_ROOT}/config/traefik/dynamic/routers.yml"
fi

# PowerDNS API via Docker DNS network (not public)
if grep -q "^PDNS_API_URL=" "${ENV_FILE}"; then
  sed -i "s|^PDNS_API_URL=.*|PDNS_API_URL=http://redi-pdns-auth:8081|" "${ENV_FILE}"
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

mkdir -p "${REDI_ROOT}/logs/traefik" "${REDI_ROOT}/data/traefik"
chown -R root:root "${REDI_ROOT}/logs/traefik" "${REDI_ROOT}/data/traefik" 2>/dev/null || true

ensure_docker_network "redi-proxy" "172.29.0.0/24"
ensure_docker_network "redi-dns" "172.28.0.0/24"
ensure_docker_network "redi-management" "172.30.0.0/24"

log_info "Deploying Traefik on ${HOSTNAME}"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 5
docker compose --env-file "${ENV_FILE}" ps
docker logs redi-traefik --tail 20

log_info "Traefik deployment complete"
