#!/usr/bin/env bash
# =============================================================================
# REDI Phase 7 — Deploy Monitoring Stack (MJK central server)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/monitoring"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01"; exit 1; }

ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}. Copy from .env.example and configure."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

SECRETS_FILE="${REDI_ROOT}/secrets/api-keys.yaml"
if grep -q "^GRAFANA_ADMIN_PASSWORD=" "${ENV_FILE}" && grep "CHANGE_ME" "${ENV_FILE}" >/dev/null; then
  GRAFANA_PW="$(grep -A3 'grafana-admin-password' "${SECRETS_FILE}" 2>/dev/null | awk -F"'" '/value:/ {print $2; exit}')"
  if [[ -n "${GRAFANA_PW}" ]]; then
    sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${GRAFANA_PW}|" "${ENV_FILE}"
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
  fi
fi

TS_IP="$(get_tailscale_ip)"
sed -i "s|^MONITORING_TAILSCALE_IP=.*|MONITORING_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
# shellcheck source=/dev/null
source "${ENV_FILE}"

mkdir -p "${REDI_ROOT}/data/monitoring"/{prometheus,grafana,alertmanager} "${REDI_ROOT}/logs/monitoring"
chown -R 65534:65534 "${REDI_ROOT}/data/monitoring/prometheus" 2>/dev/null || true
chown -R 472:472 "${REDI_ROOT}/data/monitoring/grafana" 2>/dev/null || true

ensure_docker_network "redi-management" "172.30.0.0/24"
ensure_docker_network "redi-proxy" "172.29.0.0/24"

log_info "Deploying monitoring stack on ${HOSTNAME} (mesh ${MONITORING_TAILSCALE_IP})"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 10
docker compose --env-file "${ENV_FILE}" ps

for _ in $(seq 1 20); do
  curl -sf "http://${MONITORING_TAILSCALE_IP}:9090/-/ready" >/dev/null && break
  sleep 5
done
curl -sf "http://${MONITORING_TAILSCALE_IP}:9090/-/ready" >/dev/null || { log_error "Prometheus not ready"; exit 1; }
curl -sf "http://${MONITORING_TAILSCALE_IP}:3000/api/health" >/dev/null || { log_error "Grafana not ready"; exit 1; }

log_info "Monitoring stack deployed — Grafana via https://grafana.letsredi.com"
