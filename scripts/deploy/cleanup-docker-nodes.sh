#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Docker disk audit + cleanup (semua node)
# Run on redi-mjk-01 as root (SSH ke jkt + sby otomatis).
#
# Mode:
#   --audit-only   : tampilkan disk usage saja, tidak hapus apa pun (default)
#   --clean        : hapus dangling images, stopped containers, unused volumes,
#                    build cache — TIDAK hapus images yang sedang dipakai
#   --clean-all    : seperti --clean, + hapus semua images yang tidak ada
#                    container aktif (aggressive — pull ulang diperlukan)
#
# Usage:
#   bash scripts/deploy/cleanup-docker-nodes.sh --audit-only
#   bash scripts/deploy/cleanup-docker-nodes.sh --clean
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
MODE="audit-only"
for arg in "$@"; do
  case "${arg}" in
    --clean)     MODE="clean" ;;
    --clean-all) MODE="clean-all" ;;
    --audit-only) MODE="audit-only" ;;
  esac
done

log_info "Mode: ${MODE}"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
[[ -f "${ENV_FILE}" ]] || { log_error "Missing ${ENV_FILE}"; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

MJK="${MJK_MESH_IP}"
JKT="${JKT_MESH_IP}"
SBY="${SBY_MESH_IP}"

NODES=("local:mjk:${MJK}" "ssh:jkt:${JKT}" "ssh:sby:${SBY}")

# ---------------------------------------------------------------------------
# Helper: run command locally or via SSH
# ---------------------------------------------------------------------------
run_on() {
  local method="$1" node="$2" ip="$3"
  shift 3
  if [[ "${method}" == "local" ]]; then
    bash -c "$*"
  else
    ssh -o ConnectTimeout=10 -o BatchMode=yes "root@${ip}" "$*" 2>/dev/null \
      || { log_warn "  SSH to ${node} (${ip}) failed — skipping"; return 1; }
  fi
}

# ---------------------------------------------------------------------------
# Audit function
# ---------------------------------------------------------------------------
audit_node() {
  local method="$1" node="$2" ip="$3"
  log_info ""
  log_info "══════════════════════════════════════════"
  log_info "  NODE: ${node} (${ip})"
  log_info "══════════════════════════════════════════"

  # Disk usage
  log_info "[ Disk usage ]"
  run_on "${method}" "${node}" "${ip}" "df -h / /opt 2>/dev/null | head -5" || true

  # Docker disk usage breakdown
  log_info ""
  log_info "[ Docker disk breakdown ]"
  run_on "${method}" "${node}" "${ip}" "docker system df 2>/dev/null" || true

  # Images dengan size
  log_info ""
  log_info "[ Docker images on ${node} ]"
  run_on "${method}" "${node}" "${ip}" \
    "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' 2>/dev/null | sort" || true

  # Running containers
  log_info ""
  log_info "[ Running containers ]"
  run_on "${method}" "${node}" "${ip}" \
    "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null" || true

  # Volumes
  log_info ""
  log_info "[ Volumes ]"
  run_on "${method}" "${node}" "${ip}" \
    "docker volume ls --format 'table {{.Name}}\t{{.Driver}}' 2>/dev/null" || true

  # /opt/redi disk usage breakdown
  log_info ""
  log_info "[ /opt/redi disk breakdown ]"
  run_on "${method}" "${node}" "${ip}" \
    "du -sh /opt/redi/data/* /opt/redi/logs/* 2>/dev/null | sort -rh | head -20" || true
}

# ---------------------------------------------------------------------------
# Clean function
# ---------------------------------------------------------------------------
clean_node() {
  local method="$1" node="$2" ip="$3" aggressive="$4"
  log_info ""
  log_info "[ Cleaning ${node} ]"

  BEFORE=$(run_on "${method}" "${node}" "${ip}" \
    "df -h / | awk 'NR==2{print \$3\"/\"\$2\" used (\"\$5\")\"}'")
  log_info "  Before: ${BEFORE}"

  # Stopped containers
  run_on "${method}" "${node}" "${ip}" \
    "docker container prune -f 2>/dev/null" \
    && log_info "  Stopped containers removed" || true

  # Dangling images (untagged layers, <none>:<none>)
  run_on "${method}" "${node}" "${ip}" \
    "docker image prune -f 2>/dev/null" \
    && log_info "  Dangling images removed" || true

  # Unused volumes (not attached to any container)
  run_on "${method}" "${node}" "${ip}" \
    "docker volume prune -f 2>/dev/null" \
    && log_info "  Unused volumes removed" || true

  # Build cache
  run_on "${method}" "${node}" "${ip}" \
    "docker builder prune -f 2>/dev/null" \
    && log_info "  Build cache removed" || true

  # Aggressive: remove ALL unused images (not just dangling)
  if [[ "${aggressive}" == "yes" ]]; then
    log_warn "  AGGRESSIVE: removing all images not used by a running container"
    run_on "${method}" "${node}" "${ip}" \
      "docker image prune -a -f 2>/dev/null" \
      && log_info "  All unused images removed" || true
  fi

  AFTER=$(run_on "${method}" "${node}" "${ip}" \
    "df -h / | awk 'NR==2{print \$3\"/\"\$2\" used (\"\$5\")\"}'")
  log_info "  After:  ${AFTER}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
AGGRESSIVE="no"
[[ "${MODE}" == "clean-all" ]] && AGGRESSIVE="yes"

for node_entry in "${NODES[@]}"; do
  IFS=: read -r method node ip <<< "${node_entry}"
  audit_node "${method}" "${node}" "${ip}"
done

if [[ "${MODE}" != "audit-only" ]]; then
  log_info ""
  log_info "══════════════════════════════════════════"
  log_info "  CLEANUP (mode: ${MODE})"
  log_info "══════════════════════════════════════════"
  for node_entry in "${NODES[@]}"; do
    IFS=: read -r method node ip <<< "${node_entry}"
    clean_node "${method}" "${node}" "${ip}" "${AGGRESSIVE}"
  done

  log_info ""
  log_info "Post-cleanup disk state:"
  for node_entry in "${NODES[@]}"; do
    IFS=: read -r method node ip <<< "${node_entry}"
    DISK=$(run_on "${method}" "${node}" "${ip}" \
      "df -h / | awk 'NR==2{print \$4\" free of \"\$2}'" 2>/dev/null || echo "N/A")
    log_info "  ${node}: ${DISK}"
  done
fi

log_info ""
log_info "Done. Run --clean to remove unused Docker artifacts."
log_info "Run --clean-all to also remove unused images (requires re-pull on deploy)."
