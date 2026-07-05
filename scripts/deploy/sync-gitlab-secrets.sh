#!/usr/bin/env bash
# =============================================================================
# REDI — Sync gitlab-secrets.json from redi-mjk-01 to HA application nodes
# Required for PAT/API auth on all GitLab backends behind Traefik.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01 (secrets source)"; exit 1; }

REDI_ROOT="${REDI_ROOT:-/opt/redi}"
SECRETS="${REDI_ROOT}/data/gitlab/config/gitlab-secrets.json"
[[ -f "${SECRETS}" ]] || { log_error "Missing ${SECRETS}"; exit 1; }

JKT_HOST="${JKT_HOST:-devapp@103.149.238.98}"
JKT_PW="${JKT_PW:-BitApp2026!@#}"
SBY_HOST="${SBY_HOST:-root@103.80.214.144}"
SBY_PORT="${SBY_PORT:-2280}"
SBY_PW="${SBY_PW:-!Proxmox@Redi123}"

sync_to() {
  local label="$1" host="$2" port="${3:-22}" pw="$4" remote_path="$5"
  log_info "Syncing gitlab-secrets.json to ${label}"
  export SSHPASS="${pw}"
  sshpass -e scp -P "${port}" -o StrictHostKeyChecking=no "${SECRETS}" "${host}:/tmp/gitlab-secrets.json"
  if [[ "${label}" == "redi-jkt-01" ]]; then
    sshpass -e ssh -o StrictHostKeyChecking=no "${host}" \
      "echo '${pw}' | sudo -S cp /tmp/gitlab-secrets.json ${remote_path} && echo '${pw}' | sudo -S chmod 600 ${remote_path} && echo '${pw}' | sudo -S docker exec redi-gitlab gitlab-ctl reconfigure && echo '${pw}' | sudo -S docker exec redi-gitlab gitlab-ctl restart"
  else
    sshpass -e ssh -p "${port}" -o StrictHostKeyChecking=no "${host}" \
      "cp /tmp/gitlab-secrets.json ${remote_path} && chmod 600 ${remote_path} && docker exec redi-gitlab gitlab-ctl reconfigure && docker exec redi-gitlab gitlab-ctl restart"
  fi
}

sync_to "redi-jkt-01" "${JKT_HOST}" 22 "${JKT_PW}" "/opt/redi/data/gitlab/config/gitlab-secrets.json"
sync_to "redi-sby-01" "${SBY_HOST}" "${SBY_PORT}" "${SBY_PW}" "/opt/redi/data/gitlab/config/gitlab-secrets.json"

log_info "gitlab-secrets.json synced to jkt and sby"
