#!/usr/bin/env bash
# =============================================================================
# REDI — Deploy and register GitLab Runner (instance runner on redi-mjk-01)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/gitlab-runner"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01"; exit 1; }

GITLAB_ENV="${REDI_ROOT}/compose/gitlab/.env"
# shellcheck source=/dev/null
source "${GITLAB_ENV}"

RUNNER_CONFIG="${REDI_ROOT}/data/gitlab-runner"
mkdir -p "${RUNNER_CONFIG}"

ensure_docker_network "redi-management" "172.30.0.0/24"

cd "${COMPOSE_DIR}"
docker compose up -d

if [[ -f "${RUNNER_CONFIG}/config.toml" ]] && grep -q 'url = ' "${RUNNER_CONFIG}/config.toml"; then
  log_info "GitLab Runner already registered"
  docker exec redi-gitlab-runner gitlab-runner verify 2>/dev/null || true
  docker exec redi-gitlab-runner gitlab-runner list 2>/dev/null || true
  exit 0
fi

log_info "Creating drill PAT and instance runner via GitLab API"
PAT="$(docker exec redi-gitlab gitlab-rails runner "
  u = User.find_by(username: 'root')
  PersonalAccessToken.where(user: u, name: 'runner-deploy').destroy_all
  t = PersonalAccessToken.create!(user: u, name: 'runner-deploy', scopes: [:api], expires_at: 30.days.from_now)
  puts t.token
" 2>/dev/null | tail -1 | tr -d '[:space:]')"

[[ -n "${PAT}" ]] || { log_error "Failed to create PAT for runner registration"; exit 1; }

GITLAB_API_URL="${GITLAB_API_URL:-http://${GITLAB_TAILSCALE_IP:-100.81.86.37}:${GITLAB_HTTP_PORT:-8929}}"

RUNNER_AUTH="$(curl -sf -X POST \
  -H "PRIVATE-TOKEN: ${PAT}" \
  -F "runner_type=instance_type" \
  -F "description=redi-mjk-01-instance" \
  -F "tag_list=redi,docker,mjk" \
  "${GITLAB_API_URL}/api/v4/user/runners" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)"

[[ -n "${RUNNER_AUTH}" ]] || { log_error "Failed to create runner via API (${GITLAB_API_URL})"; exit 1; }

docker exec redi-gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_EXTERNAL_URL}" \
  --token "${RUNNER_AUTH}" \
  --executor docker \
  --docker-image alpine:latest \
  --description "redi-mjk-01-instance" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"

docker exec redi-gitlab gitlab-rails runner "PersonalAccessToken.where(name: 'runner-deploy').destroy_all" 2>/dev/null || true

docker exec redi-gitlab-runner gitlab-runner verify
docker exec redi-gitlab-runner gitlab-runner list
log_info "GitLab Runner deployed and registered"
