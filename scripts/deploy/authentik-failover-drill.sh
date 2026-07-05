#!/usr/bin/env bash
# =============================================================================
# REDI Phase 5 — Authentik identity failover drill (single node stop/start)
# Usage: authentik-failover-drill.sh [redi-mjk-01|redi-jkt-01|redi-sby-01]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET="${1:-redi-mjk-01}"
declare -A HOSTS=(
  [redi-mjk-01]="2280 root@103.80.214.226"
  [redi-jkt-01]="22 devapp@103.149.238.98"
  [redi-sby-01]="2280 root@103.80.214.144"
)
declare -A PWS=(
  [redi-mjk-01]="!Proxmox@Redi123"
  [redi-jkt-01]="BitApp2026!@#"
  [redi-sby-01]="!Proxmox@Redi123"
)

[[ -n "${HOSTS[$TARGET]:-}" ]] || { log_error "Unknown target ${TARGET}"; exit 1; }

read -r PORT SSH_HOST <<< "${HOSTS[$TARGET]}"
export SSHPASS="${PWS[$TARGET]}"

check_endpoints() {
  local label="$1"
  local auth_code gitlab_code
  auth_code="$(curl -sk -o /dev/null -w '%{http_code}' https://auth.letsredi.com/ 2>/dev/null || echo 000)"
  gitlab_code="$(curl -sk -o /dev/null -w '%{http_code}' https://git.letsredi.com/users/sign_in 2>/dev/null || echo 000)"
  log_info "${label}: auth=${auth_code} gitlab=${gitlab_code}"
  [[ "${auth_code}" =~ ^(200|302)$ ]] || return 1
}

log_info "Baseline check"
check_endpoints "baseline" || exit 1

log_info "Stopping Authentik on ${TARGET}"
if [[ "${TARGET}" == "redi-jkt-01" ]]; then
  sshpass -e ssh -p "${PORT}" -o StrictHostKeyChecking=no "${SSH_HOST}" \
    "echo '${SSHPASS}' | sudo -S bash -c 'cd /opt/redi/compose/authentik && docker compose stop authentik-server authentik-worker'"
else
  sshpass -e ssh -p "${PORT}" -o StrictHostKeyChecking=no "${SSH_HOST}" \
    "cd /opt/redi/compose/authentik && docker compose stop authentik-server authentik-worker"
fi

sleep 8
check_endpoints "during_failover" || { log_error "Auth unavailable during failover"; exit 1; }

log_info "Recovering ${TARGET}"
if [[ "${TARGET}" == "redi-jkt-01" ]]; then
  sshpass -e ssh -p "${PORT}" -o StrictHostKeyChecking=no "${SSH_HOST}" \
    "echo '${SSHPASS}' | sudo -S bash -c 'cd /opt/redi/compose/authentik && docker compose start authentik-server authentik-worker'"
else
  sshpass -e ssh -p "${PORT}" -o StrictHostKeyChecking=no "${SSH_HOST}" \
    "cd /opt/redi/compose/authentik && docker compose start authentik-server authentik-worker"
fi

sleep 20
check_endpoints "after_recovery" || exit 1
log_info "PASS: Authentik failover drill (${TARGET})"
