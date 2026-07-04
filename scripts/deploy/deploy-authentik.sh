#!/usr/bin/env bash
# =============================================================================
# REDI — Deploy Authentik (Phase 3)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/authentik"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Authentik deploys on redi-mjk-01"; exit 1; }

ENV_FILE="${COMPOSE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] || { log_error "Missing ${ENV_FILE}"; exit 1; }

ensure_docker_network "redi-internal" "172.31.0.0/24"
ensure_docker_network "redi-management" "172.30.0.0/24"
mkdir -p "${REDI_ROOT}/data/authentik"/{media/public,templates}
chown -R 1000:1000 "${REDI_ROOT}/data/authentik"

cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

log_info "Authentik deployed — https://auth.letsredi.com"
