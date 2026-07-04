#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy GitLab CE (Sprint 2 Stage 1)
# Management server: redi-mjk-01
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/gitlab"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

HOSTNAME="$(hostname -s)"
if [[ "${HOSTNAME}" != "redi-mjk-01" && "${HOSTNAME}" != "redi-jkt-01" && "${HOSTNAME}" != "redi-sby-01" ]]; then
  log_error "GitLab must be deployed on redi-mjk-01, redi-jkt-01, or redi-sby-01. Current: ${HOSTNAME}"
  exit 1
fi

ENV_FILE="${COMPOSE_DIR}/.env"
NODE_ENV="${COMPOSE_DIR}/.env.${HOSTNAME}"
if [[ -f "${NODE_ENV}" ]]; then
  cp "${NODE_ENV}" "${ENV_FILE}"
elif [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}"
  exit 1
fi

# shellcheck source=/dev/null
set +u
source "${ENV_FILE}"
set -u

TS_IP="$(get_tailscale_ip)"
if grep -q "^GITLAB_TAILSCALE_IP=" "${ENV_FILE}"; then
  sed -i "s|^GITLAB_TAILSCALE_IP=.*|GITLAB_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
  # shellcheck source=/dev/null
  set +u
  source "${ENV_FILE}"
  set -u
fi

cat > /etc/sysctl.d/99-gitlab.conf <<'EOF'
vm.max_map_count = 262144
kernel.shmmax = 17179869184
kernel.shmall = 4194304
EOF
sysctl --system >/dev/null

ensure_docker_network "redi-management" "172.30.0.0/24"
ensure_docker_network "redi-proxy" "172.29.0.0/24"

mkdir -p "${REDI_ROOT}/data/gitlab/"{config,logs,data}
mkdir -p "${REDI_ROOT}/backup/gitlab"

log_info "Deploying GitLab EE on ${HOSTNAME} (mesh ${GITLAB_TAILSCALE_IP})"
log_warn "Initial startup may take 10-15 minutes"

cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d

log_info "Waiting for GitLab health..."
healthy=false
for i in $(seq 1 40); do
  if docker exec redi-gitlab /opt/gitlab/bin/gitlab-healthcheck --fail --max-time 15 2>/dev/null; then
    healthy=true
    log_info "GitLab healthy after ${i} checks"
    break
  fi
  log_info "Starting... (${i}/40)"
  sleep 30
done

if [[ "${healthy}" != "true" ]]; then
  log_error "GitLab failed health check"
  docker logs redi-gitlab --tail 30
  exit 1
fi

if [[ -n "${GITLAB_ROOT_PASSWORD:-}" ]] && [[ "${GITLAB_ROOT_PASSWORD}" != *"CHANGE_ME"* ]]; then
  docker exec redi-gitlab gitlab-rails runner \
    "u = User.find_by(username: 'root'); u.password = '${GITLAB_ROOT_PASSWORD}'; u.password_confirmation = '${GITLAB_ROOT_PASSWORD}'; u.save!" \
    2>/dev/null && log_info "Root password set" || log_warn "Root password may already be set"
fi

log_info "Running initial GitLab backup..."
docker exec redi-gitlab gitlab-backup create STRATEGY=copy SKIP=artifacts,builds,pages 2>/dev/null \
  && log_info "Initial backup complete" || log_warn "Initial backup pending — retry via backup-all.sh"

log_info "GitLab deployed — ${GITLAB_EXTERNAL_URL}"
