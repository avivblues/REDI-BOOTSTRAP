#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy Landing Page + Status Dashboard
# Edge primary only (redi-jkt-01)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/landing"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

HOSTNAME="$(hostname -s)"
if [[ "${HOSTNAME}" != "redi-jkt-01" ]]; then
  log_error "Landing page deploys on edge primary (redi-jkt-01). Current: ${HOSTNAME}"
  exit 1
fi

ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${COMPOSE_DIR}/.env.example" "${ENV_FILE}"
  log_warn "Created ${ENV_FILE} from example"
fi

ensure_docker_network "redi-proxy" "172.29.0.0/24"
ensure_docker_network "redi-dns" "172.28.0.0/24"
ensure_docker_network "redi-management" "172.30.0.0/24"

log_info "Building and deploying REDI landing on ${HOSTNAME}"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" build --pull
docker compose --env-file "${ENV_FILE}" up -d

sleep 5
docker compose --env-file "${ENV_FILE}" ps
docker logs redi-landing --tail 10

log_info "Landing available at https://letsredi.com and https://status.letsredi.com"
