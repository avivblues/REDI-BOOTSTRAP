#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Sync Redis master to HAProxy (all HA nodes) + PowerDNS (jkt)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

export SSHPASS="${REDI_SSH_JKT_PASS:-BitApp2026!@#}"
JKT_HOST="${JKT_PUBLIC_IP:-103.149.238.98}"
JKT_PW="${REDI_SSH_JKT_PASS:-BitApp2026!@#}"
SBY_HOST="${SBY_HOST:-root@103.80.214.144}"
SBY_PORT="${SBY_PORT:-2280}"
SBY_PW="${REDI_SSH_SBY_PASS:-!Proxmox@Redi123}"
SSH_JKT=(sshpass -e ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "devapp@${JKT_HOST}")

remote_haproxy() {
  local label="$1" host="$2" port="${3:-22}" pw="$4"
  log_info "Syncing Redis HAProxy on ${label}"
  export SSHPASS="${pw}"
  if [[ "${label}" == "redi-jkt-01" ]]; then
    sshpass -e ssh -p "${port}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${host}" \
      "echo '${pw}' | sudo -S bash -c 'bash ${REDI_ROOT}/scripts/deploy/sync-redis-haproxy.sh'"
  else
    sshpass -e ssh -p "${port}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${host}" \
      "bash ${REDI_ROOT}/scripts/deploy/sync-redis-haproxy.sh"
  fi
}

bash "${SCRIPT_DIR}/sync-redis-haproxy.sh"
remote_haproxy "redi-jkt-01" "devapp@${JKT_HOST}" 22 "${JKT_PW}"
remote_haproxy "redi-sby-01" "${SBY_HOST}" "${SBY_PORT}" "${SBY_PW}"

"${SSH_JKT[@]}" "bash -s" <<EOF
set -euo pipefail
export REDI_ROOT=/opt/redi
bash /opt/redi/scripts/deploy/sync-redis-master-dns.sh
EOF

log_info "Redis master synced to HAProxy (mjk/jkt/sby) + PowerDNS"
