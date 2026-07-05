#!/usr/bin/env bash
# =============================================================================
# REDI — Sync Authentik media/templates from redi-mjk-01 to HA nodes
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01"; exit 1; }

REDI_ROOT="${REDI_ROOT:-/opt/redi}"
DATA="${REDI_ROOT}/data/authentik"
ARCHIVE="/tmp/authentik-media-sync.tar.gz"

tar -czf "${ARCHIVE}" -C "${DATA}" media templates 2>/dev/null || tar -czf "${ARCHIVE}" -C "${DATA}" media

JKT_HOST="${JKT_HOST:-devapp@103.149.238.98}"
JKT_PW="${JKT_PW:-BitApp2026!@#}"
SBY_HOST="${SBY_HOST:-root@103.80.214.144}"
SBY_PORT="${SBY_PORT:-2280}"
SBY_PW="${SBY_PW:-!Proxmox@Redi123}"

sync_to() {
  local label="$1" host="$2" port="${3:-22}" pw="$4"
  log_info "Syncing Authentik media to ${label}"
  export SSHPASS="${pw}"
  sshpass -e scp -P "${port}" -o StrictHostKeyChecking=no "${ARCHIVE}" "${host}:/tmp/authentik-media-sync.tar.gz"
  if [[ "${label}" == "redi-jkt-01" ]]; then
    sshpass -e ssh -p "${port}" -o StrictHostKeyChecking=no "${host}" \
      "echo '${pw}' | sudo -S bash -c 'mkdir -p ${DATA} && tar -xzf /tmp/authentik-media-sync.tar.gz -C ${DATA} && chown -R 1000:1000 ${DATA}'"
  else
    sshpass -e ssh -p "${port}" -o StrictHostKeyChecking=no "${host}" \
      "mkdir -p ${DATA} && tar -xzf /tmp/authentik-media-sync.tar.gz -C ${DATA} && chown -R 1000:1000 ${DATA}"
  fi
}

sync_to "redi-jkt-01" "${JKT_HOST}" 22 "${JKT_PW}"
sync_to "redi-sby-01" "${SBY_HOST}" "${SBY_PORT}" "${SBY_PW}"
rm -f "${ARCHIVE}"
log_info "Authentik media synced to jkt and sby"
