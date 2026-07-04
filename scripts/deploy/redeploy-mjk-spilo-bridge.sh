#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Redeploy mjk Spilo on redi-internal (local leader HA path)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "mjk only"; exit 1; }

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.redi-mjk-01"
# shellcheck source=/dev/null
source "${ENV_BASE}"
# shellcheck source=/dev/null
[[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"

export NODE_MESH_IP="${MJK_MESH_IP}"
export ETCD3_HOSTS="${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379"
export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"

COMPOSE_DIR="${REDI_ROOT}/compose/shared-platform/postgres"
log_info "Redeploy mjk Spilo on redi-internal (mesh connect_address preserved)"
docker stop redi-postgres 2>/dev/null || true
docker rm redi-postgres 2>/dev/null || true
cd "${COMPOSE_DIR}"
docker compose -f docker-compose.mjk-bridge.yml --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d

for _ in $(seq 1 40); do
  docker exec redi-postgres test -f /run/postgres.yml 2>/dev/null && break
  sleep 3
done

bash "${SCRIPT_DIR}/patch-mjk-patroni-mesh.sh" "${MJK_MESH_IP}" "${POSTGRES_DIRECT_PORT:-5433}"

docker exec redi-postgres patronictl list
bash "${SCRIPT_DIR}/deploy-haproxy-patroni.sh"
bash "${SCRIPT_DIR}/deploy-pgbouncer.sh"
log_info "mjk Spilo bridge redeploy complete"
