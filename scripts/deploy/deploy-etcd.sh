#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Deploy etcd DCS (all nodes)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.${HOSTNAME}"

# shellcheck source=/dev/null
set +u
source "${ENV_BASE}"
[[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"
set -u

if [[ -f "${NODE_ENV}" ]] && grep -qE '^NODE_MESH_IP=' "${NODE_ENV}"; then
  NODE_MESH_IP="$(grep -E '^NODE_MESH_IP=' "${NODE_ENV}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
else
  NODE_MESH_IP="$(get_tailscale_ip)"
fi
export NODE_MESH_IP
export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"

case "${HOSTNAME}" in
  redi-mjk-01) export ETCD_CLUSTER_STATE="${ETCD_CLUSTER_STATE:-new}" ;;
  *) export ETCD_CLUSTER_STATE="${ETCD_CLUSTER_STATE:-existing}" ;;
esac

ensure_docker_network "redi-internal" "172.31.0.0/24"
mkdir -p "${SHARED_DATA_PATH}/etcd"

cd "${REDI_ROOT}/compose/shared-platform/etcd"
docker compose --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate

sleep 5
docker exec redi-etcd etcdctl endpoint health --write-out=table
log_info "etcd ready on ${HOSTNAME} (state=${ETCD_CLUSTER_STATE})"
