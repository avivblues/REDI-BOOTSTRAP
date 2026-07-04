#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy Portainer
# Management server only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/portainer"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

HOSTNAME="$(hostname -s)"
if [[ "${HOSTNAME}" != "redi-mgmt-01" && "${HOSTNAME}" != "redi-mjk-01" ]]; then
  log_error "Portainer must be deployed on management host (redi-mjk-01). Current: ${HOSTNAME}"
  exit 1
fi

ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}. Copy from .env.example and configure."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

TS_IP="$(get_tailscale_ip)"
if grep -q "^PORTAINER_TAILSCALE_IP=" "${ENV_FILE}"; then
  sed -i "s|^PORTAINER_TAILSCALE_IP=.*|PORTAINER_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
fi

mkdir -p "${REDI_ROOT}/data/portainer" "${REDI_ROOT}/logs/portainer"

ensure_docker_network "redi-management" "172.30.0.0/24"
ensure_docker_network "redi-proxy" "172.29.0.0/24"

log_info "Deploying Portainer Server on ${HOSTNAME}"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 5
docker compose --env-file "${ENV_FILE}" ps

log_info "Portainer available at https://${TS_IP}:9443 (mesh) or https://portainer.letsredi.com (via Traefik)"
