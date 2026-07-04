#!/usr/bin/env bash
# RAS v1.0 — Read-only infrastructure validation (Level 0)
# Loads inventory + secrets; performs no modifications.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY="${REPO_ROOT}/inventory/servers.example.yaml"
SECRETS_SERVERS="${REPO_ROOT}/secrets/servers.yaml"
SECRETS_KEYS="${REPO_ROOT}/secrets/api-keys.yaml"
REMOTE_SCRIPT="${REPO_ROOT}/scripts/deploy/precheck-remote.sh"

if [[ ! -f "${INVENTORY}" ]] || [[ ! -f "${SECRETS_SERVERS}" ]] || [[ ! -f "${SECRETS_KEYS}" ]]; then
  echo "ERROR: Missing inventory or secrets files"
  exit 1
fi

get_password() {
  local ref="$1"
  python3 -c "
import yaml, sys
with open('${SECRETS_KEYS}') as f:
    data = yaml.safe_load(f)
for s in data.get('secrets', []):
    if s.get('id') == '${ref}':
        print(s.get('value', ''))
        sys.exit(0)
sys.exit(1)
"
}

get_server_field() {
  local id="$1" field="$2"
  python3 -c "
import yaml
with open('${SECRETS_SERVERS}') as f:
    data = yaml.safe_load(f)
for s in data.get('servers', []):
    if s.get('id') == '${id}':
        print(s.get('${field}', ''))
        sys.exit(0)
sys.exit(1)
"
}

get_inventory_hostname() {
  local id="$1"
  python3 -c "
import yaml
with open('${INVENTORY}') as f:
    data = yaml.safe_load(f)
for s in data.get('servers', []):
    if s.get('id') == '${id}':
        print(s.get('hostname', ''))
        sys.exit(0)
sys.exit(1)
"
}

validate_node() {
  local id="$1"
  local host port user pass_ref pass expected_hostname
  host="$(get_server_field "${id}" public_ip)"
  port="$(get_server_field "${id}" ssh_port)"
  user="$(get_server_field "${id}" username)"
  pass_ref="$(get_server_field "${id}" password_ref)"
  pass="$(get_password "${pass_ref}")"
  expected_hostname="$(get_inventory_hostname "${id}")"

  echo "===== NODE:${id} ====="
  echo "INVENTORY_HOSTNAME:${expected_hostname}"
  echo "ENDPOINT:${user}@${host}:${port}"

  # Reachability + auth test
  if SSHPASS="${pass}" sshpass -e ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -o BatchMode=no \
    -p "${port}" "${user}@${host}" "echo AUTH_OK" 2>/dev/null; then
    echo "AUTH:PASS"
  else
    echo "AUTH:FAIL"
    echo "VALIDATION_ABORTED:true"
    return 1
  fi

  # Remote read-only collection
  local ssh_cmd="bash -s"
  if [[ "${user}" != "root" ]]; then
    ssh_cmd="echo '${pass}' | sudo -S bash -s"
  fi

  SSHPASS="${pass}" sshpass -e ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -p "${port}" "${user}@${host}" "${ssh_cmd}" < "${REMOTE_SCRIPT}" 2>/dev/null \
    | grep -v '^\[sudo\]' || true

  # Inter-node ping from this node to others (inventory nodes only)
  echo "=== MESH_PING ==="
  for target_id in redi-jkt-01 redi-sby-01 redi-mjk-01; do
    [[ "${target_id}" == "${id}" ]] && continue
    local target_ip
    target_ip="$(get_server_field "${target_id}" public_ip)"
    SSHPASS="${pass}" sshpass -e ssh -o ConnectTimeout=10 -p "${port}" "${user}@${host}" \
      "ping -c 2 -W 3 ${target_ip} 2>&1 | tail -2" 2>/dev/null || echo "ping ${target_id}:FAIL"
  done
}

SERVER_IDS=$(python3 -c "
import yaml
with open('${INVENTORY}') as f:
    for s in yaml.safe_load(f).get('servers', []):
        print(s['id'])
")

for sid in ${SERVER_IDS}; do
  validate_node "${sid}" || true
  echo ""
done
