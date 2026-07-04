#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Create REDI Docker Bridge Networks
# Idempotent — does not remove existing networks.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

if ! docker info &>/dev/null; then
  log_error "Docker daemon not healthy"
  exit 1
fi

# Subnets per inventory/network.example.yaml + redi-internal (Stage 1.3)
declare -A NETWORKS=(
  ["redi-dns"]="172.28.0.0/24"
  ["redi-proxy"]="172.29.0.0/24"
  ["redi-management"]="172.30.0.0/24"
  ["redi-internal"]="172.32.0.0/24"
)

for name in "${!NETWORKS[@]}"; do
  subnet="${NETWORKS[$name]}"
  if docker network inspect "${name}" &>/dev/null; then
    existing_subnet="$(docker network inspect "${name}" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"
    if [[ -n "${existing_subnet}" && "${existing_subnet}" != "${subnet}" ]]; then
      log_warn "Network ${name} exists with subnet ${existing_subnet} (expected ${subnet}) — preserving existing"
    else
      log_info "Network ${name} already exists (${subnet})"
    fi
  else
    ensure_docker_network "${name}" "${subnet}"
  fi
done

log_info "Docker networks ready"
docker network ls --filter name=redi --format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}'
