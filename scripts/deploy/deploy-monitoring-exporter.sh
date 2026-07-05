#!/usr/bin/env bash
# =============================================================================
# REDI Phase 7 — Deploy Node Exporter + cAdvisor on all nodes
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/monitoring-exporter"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
case "${HOSTNAME}" in
  redi-jkt-01|redi-mjk-01|redi-sby-01) ;;
  *) log_error "Unsupported host ${HOSTNAME}"; exit 1 ;;
esac

ENV_FILE="${COMPOSE_DIR}/.env"
NODE_ENV="${COMPOSE_DIR}/.env.${HOSTNAME}"
if [[ -f "${NODE_ENV}" ]]; then
  cp "${NODE_ENV}" "${ENV_FILE}"
elif [[ ! -f "${ENV_FILE}" ]]; then
  cp "${COMPOSE_DIR}/.env.example" "${ENV_FILE}"
  log_warn "Created ${ENV_FILE} from example — configure mesh IP"
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

TS_IP="$(get_tailscale_ip)"
sed -i "s|^MONITORING_EXPORTER_TAILSCALE_IP=.*|MONITORING_EXPORTER_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
# shellcheck source=/dev/null
source "${ENV_FILE}"

log_info "Deploying monitoring exporters on ${HOSTNAME} (mesh ${MONITORING_EXPORTER_TAILSCALE_IP})"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 5
docker compose --env-file "${ENV_FILE}" ps
curl -sf "http://${MONITORING_EXPORTER_TAILSCALE_IP}:9102/metrics" | head -1 >/dev/null
curl -sf "http://${MONITORING_EXPORTER_TAILSCALE_IP}:8085/metrics" | head -1 >/dev/null
log_info "Exporters ready on ${HOSTNAME}"
