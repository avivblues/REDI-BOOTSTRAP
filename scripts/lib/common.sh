#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Common Library
# =============================================================================
set -euo pipefail

REDI_ROOT="${REDI_ROOT:-/opt/redi}"

log_info()  { echo "[INFO]  $(date -Is) $*"; }
log_warn()  { echo "[WARN]  $(date -Is) $*" >&2; }
log_error() { echo "[ERROR] $(date -Is) $*" >&2; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
  fi
}

require_ubuntu_2204() {
  if [[ ! -f /etc/os-release ]]; then
    log_error "Cannot detect OS version"
    exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]] || [[ "${VERSION_ID}" != "22.04" ]]; then
    log_error "Ubuntu 22.04 LTS required. Detected: ${PRETTY_NAME:-unknown}"
    exit 1
  fi
}

run_step() {
  local script="$1"
  log_info "Running: $(basename "${script}")"
  bash "${script}"
}

load_inventory() {
  local inventory="${REDI_ROOT}/inventory/servers.env"
  if [[ -f "${inventory}" ]]; then
    # shellcheck source=/dev/null
    set -a
    source "${inventory}"
    set +a
  else
    log_warn "Inventory file not found: ${inventory}"
  fi
}

get_tailscale_ip() {
  tailscale ip -4 2>/dev/null || echo "127.0.0.1"
}

wait_for_service() {
  local host="$1"
  local port="$2"
  local timeout="${3:-60}"
  local elapsed=0
  while ! nc -z "${host}" "${port}" 2>/dev/null; do
    sleep 2
    elapsed=$((elapsed + 2))
    if [[ "${elapsed}" -ge "${timeout}" ]]; then
      log_error "Timeout waiting for ${host}:${port}"
      return 1
    fi
  done
  log_info "Service ready: ${host}:${port}"
}

generate_secret() {
  openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

docker_compose() {
  docker compose -f "$1" --env-file "$2" "$3" "${@:4}"
}

ensure_docker_network() {
  local network="$1"
  local subnet="$2"
  local bridge_name="br-${network}"
  # Linux interface names are limited to 15 characters
  case "${network}" in
    redi-management) bridge_name="br-redi-mgmt" ;;
    redi-internal)   bridge_name="br-redi-int" ;;
  esac
  if [[ ${#bridge_name} -gt 15 ]]; then
    bridge_name="${bridge_name:0:15}"
  fi
  if ! docker network inspect "${network}" &>/dev/null; then
    docker network create \
      --driver bridge \
      --subnet "${subnet}" \
      --opt "com.docker.network.bridge.name=${bridge_name}" \
      "${network}"
    log_info "Created Docker network: ${network} (${subnet}, ${bridge_name})"
  fi
}
