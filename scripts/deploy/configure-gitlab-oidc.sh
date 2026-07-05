#!/usr/bin/env bash
# =============================================================================
# REDI Phase 5 — Apply GitLab OIDC from Authentik (.env.oidc on server)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
OIDC_ENV="${REDI_ROOT}/compose/gitlab/.env.oidc"
COMPOSE_DIR="${REDI_ROOT}/compose/gitlab"
ENV_FILE="${COMPOSE_DIR}/.env"

[[ -f "${OIDC_ENV}" ]] || { log_error "Missing ${OIDC_ENV} — run configure-authentik-identity.sh first"; exit 1; }
# shellcheck source=/dev/null
source "${OIDC_ENV}"

NODE_ENV="${COMPOSE_DIR}/.env.${HOSTNAME}"
[[ -f "${NODE_ENV}" ]] && cp "${NODE_ENV}" "${ENV_FILE}"

{
  grep -v '^GITLAB_OIDC_' "${ENV_FILE}" 2>/dev/null || true
  cat "${OIDC_ENV}"
} > "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "${ENV_FILE}"

log_info "Reconfiguring GitLab OIDC on ${HOSTNAME}"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" up -d
docker exec redi-gitlab gitlab-ctl reconfigure
docker exec redi-gitlab gitlab-ctl restart

for _ in $(seq 1 20); do
  if docker exec redi-gitlab gitlab-rails runner "puts Gitlab.config.omniauth.enabled" 2>/dev/null | grep -q true; then
    log_info "GitLab OmniAuth enabled on ${HOSTNAME}"
    exit 0
  fi
  sleep 10
done
log_warn "GitLab OmniAuth verification pending — check gitlab logs"
