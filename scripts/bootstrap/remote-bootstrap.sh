#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Remote Bootstrap Helper
# Runs bootstrap on all servers from your workstation via SSH
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Server connection map — adjust keys/users as needed
declare -A SERVERS=(
  ["redi-jkt-01"]="devapp@103.149.238.98"
  ["redi-sby-01"]="root@103.80.214.144"
  ["redi-mgmt-01"]="root@103.80.214.144"
)

declare -A SSH_PORTS=(
  ["redi-jkt-01"]="22"
  ["redi-sby-01"]="2280"
  ["redi-mgmt-01"]="2280"
)

usage() {
  echo "Usage: remote-bootstrap.sh [--sync-only] [--host HOSTNAME]"
  echo "  --sync-only   Rsync repo only, do not run bootstrap"
  echo "  --host NAME   Target single host (default: all)"
}

SYNC_ONLY=false
TARGET_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync-only) SYNC_ONLY=true; shift ;;
    --host) TARGET_HOST="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1"; usage; exit 1 ;;
  esac
done

sync_host() {
  local name="$1"
  local conn="${SERVERS[$name]}"
  local port="${SSH_PORTS[$name]}"

  echo "=== Syncing to ${name} (${conn}:${port}) ==="
  rsync -avz --delete \
    --exclude '.git' \
    --exclude 'data/' \
    --exclude 'logs/' \
    --exclude 'backup/' \
    --exclude 'inventory/servers.env' \
    -e "ssh -p ${port} -o StrictHostKeyChecking=accept-new" \
    "${REDI_ROOT}/" "${conn}:/opt/redi/"
}

bootstrap_host() {
  local name="$1"
  local conn="${SERVERS[$name]}"
  local port="${SSH_PORTS[$name]}"

  echo "=== Bootstrapping ${name} ==="
  ssh -p "${port}" "${conn}" \
    "cd /opt/redi && chmod +x scripts/**/*.sh config/powerdns/*.sh && sudo ./scripts/bootstrap/bootstrap.sh"
}

hosts=()
if [[ -n "${TARGET_HOST}" ]]; then
  hosts=("${TARGET_HOST}")
else
  hosts=("redi-jkt-01" "redi-sby-01" "redi-mgmt-01")
fi

for host in "${hosts[@]}"; do
  sync_host "${host}"
  if [[ "${SYNC_ONLY}" == "false" ]]; then
    bootstrap_host "${host}"
  fi
done

echo "=== Done ==="
