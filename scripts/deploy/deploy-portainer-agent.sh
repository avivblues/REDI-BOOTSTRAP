#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy Portainer Agent
# All REDI nodes
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/portainer-agent"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}. Copy from .env.example and configure."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

TS_IP="$(get_tailscale_ip)"
if grep -q "^PORTAINER_AGENT_TAILSCALE_IP=" "${ENV_FILE}"; then
  sed -i "s|^PORTAINER_AGENT_TAILSCALE_IP=.*|PORTAINER_AGENT_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
fi

ensure_docker_network "redi-management" "172.30.0.0/24"

HOSTNAME="$(hostname -s)"
log_info "Deploying Portainer Agent on ${HOSTNAME} (mesh ${TS_IP}:9001)"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 5
docker compose --env-file "${ENV_FILE}" ps
docker logs redi-portainer-agent --tail 10

log_info "Portainer Agent deployment complete on ${HOSTNAME}"
