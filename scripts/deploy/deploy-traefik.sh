#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy Traefik (redi-jkt-01 primary edge)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/traefik"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

ENV_FILE="${COMPOSE_DIR}/.env"
JKT_ENV="${COMPOSE_DIR}/.env.redi-jkt-01.example"
PDNS_ENV="${REDI_ROOT}/compose/powerdns/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${JKT_ENV}" ]]; then
    log_warn ".env missing — copying from .env.redi-jkt-01.example"
    cp "${JKT_ENV}" "${ENV_FILE}"
  else
    log_error "Missing ${ENV_FILE}. Copy from .env.redi-jkt-01.example and configure."
    exit 1
  fi
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

if [[ -f "${PDNS_ENV}" ]] && grep -q "^PDNS_API_KEY=" "${PDNS_ENV}"; then
  PDNS_KEY="$(grep "^PDNS_API_KEY=" "${PDNS_ENV}" | cut -d= -f2-)"
  if [[ -n "${PDNS_KEY}" && "${PDNS_KEY}" != *"CHANGE_ME"* ]]; then
    sed -i "s|^PDNS_API_KEY=.*|PDNS_API_KEY=${PDNS_KEY}|" "${ENV_FILE}"
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
  fi
fi

TS_IP="$(get_tailscale_ip)"
sed -i "s|^TRAEFIK_TAILSCALE_IP=.*|TRAEFIK_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
# shellcheck source=/dev/null
source "${ENV_FILE}"

for acme_file in acme.json acme-http.json; do
  ACME_PATH="${REDI_ROOT}/config/traefik/${acme_file}"
  if [[ -d "${ACME_PATH}" ]]; then
    log_warn "Removing mistaken directory ${ACME_PATH}"
    rm -rf "${ACME_PATH}"
  fi
  if [[ ! -f "${ACME_PATH}" ]]; then
    echo '{}' > "${ACME_PATH}"
  fi
  chmod 600 "${ACME_PATH}"
done

mkdir -p "${REDI_ROOT}/logs/traefik"
chmod 777 "${REDI_ROOT}/logs/traefik" 2>/dev/null || true

# PowerDNS env for optional DNS-01 (do not inject into Traefik container — breaks HTTP-01 TLS load)
cat > "${REDI_ROOT}/config/traefik/powerdns.env" <<EOF
PDNS_API_URL=${PDNS_API_URL:-http://redi-pdns-auth:8081}
PDNS_API_KEY=${PDNS_API_KEY}
EOF
chmod 600 "${REDI_ROOT}/config/traefik/powerdns.env"

sed -i "s|email:.*|email: ${REDI_ACME_EMAIL}|" \
  "${REDI_ROOT}/config/traefik/traefik.yml"

HOSTNAME="$(hostname -s)"
DASHBOARD_DOMAIN="traefik-${HOSTNAME#redi-}.redi.lab"
if [[ -f "${REDI_ROOT}/config/traefik/dynamic/routers.yml" ]]; then
  sed -i "s|__TRAEFIK_DASHBOARD_HOST__|${DASHBOARD_DOMAIN}|g" \
    "${REDI_ROOT}/config/traefik/dynamic/routers.yml"
fi

if grep -q "^PDNS_API_URL=" "${ENV_FILE}"; then
  sed -i "s|^PDNS_API_URL=.*|PDNS_API_URL=http://redi-pdns-auth:8081|" "${ENV_FILE}"
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

mkdir -p "${REDI_ROOT}/logs/traefik" "${REDI_ROOT}/data/traefik"
ensure_docker_network "redi-proxy" "172.29.0.0/24"
ensure_docker_network "redi-dns" "172.28.0.0/24"
ensure_docker_network "redi-management" "172.30.0.0/24"

log_info "Deploying Traefik on ${HOSTNAME} (dashboard 127.0.0.1:${TRAEFIK_DASHBOARD_PORT:-8888})"
cd "${COMPOSE_DIR}"

# Remove manual one-off container if present
if docker ps -a --format '{{.Names}}' | grep -qx 'redi-traefik'; then
  docker rm -f redi-traefik 2>/dev/null || true
fi

docker compose --env-file "${ENV_FILE}" config >/dev/null
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 8
docker compose --env-file "${ENV_FILE}" ps
docker logs redi-traefik --tail 15

if curl -sf "http://127.0.0.1:${TRAEFIK_DASHBOARD_PORT:-8888}/ping" >/dev/null 2>&1; then
  log_info "Traefik dashboard ping OK on :${TRAEFIK_DASHBOARD_PORT:-8888}"
else
  log_warn "Dashboard ping not ready yet — check logs"
fi

if ! ss -tlnp | grep -q ':8080.*docker'; then
  log_info "No Traefik bind on host :8080 (Patroni conflict avoided)"
fi

log_info "Traefik deployment complete"
