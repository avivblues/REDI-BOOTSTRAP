#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3E — Deploy MinIO HAProxy Load Balancer
# Run this on all 3 nodes (mjk, jkt, sby).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

export MJK_MESH_IP JKT_MESH_IP SBY_MESH_IP
export SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"
mkdir -p "${SHARED_CONFIG_PATH}"

# Generate the active config from the template
envsubst < "${REDI_ROOT}/config/shared-platform/haproxy-minio.cfg.template" \
  > "${SHARED_CONFIG_PATH}/haproxy-minio.cfg"

# Start the docker container
cd "${REDI_ROOT}/compose/shared-platform/haproxy-minio"
docker compose --env-file "${ENV_BASE}" up -d --force-recreate
docker exec redi-minio-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

log_info "HAProxy MinIO Load Balancer deployed on $(hostname -s) (port 9000 API, port 9003 Console)"
