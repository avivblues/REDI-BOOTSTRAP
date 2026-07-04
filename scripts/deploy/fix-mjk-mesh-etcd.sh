#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Fix mjk Patroni mesh IP in etcd (Spilo POD_IP on bridge network)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01 only"; exit 1; }

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.redi-mjk-01"
# shellcheck source=/dev/null
source "${ENV_BASE}"
# shellcheck source=/dev/null
[[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"

export NODE_MESH_IP="${MJK_MESH_IP}"
export ETCD3_HOSTS="${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379"
export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"
PG_PORT="${POSTGRES_DIRECT_PORT:-5433}"
TARGET="${MJK_MESH_IP}:${PG_PORT}"
MJK_MEMBER="${PATRONI_MJK_MEMBER:-mjk-mesh}"

COMPOSE_DIR="${REDI_ROOT}/compose/shared-platform/postgres"

log_info "Recreate mjk Spilo (member=${MJK_MEMBER}, mesh ${TARGET})"
cd "${COMPOSE_DIR}"
docker compose -f docker-compose.mjk-bridge.yml --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate

for _ in $(seq 1 40); do
  docker exec redi-postgres test -f /run/postgres.yml 2>/dev/null && break
  sleep 3
done

bash "${SCRIPT_DIR}/patch-mjk-patroni-mesh.sh" "${MJK_MESH_IP}" "${PG_PORT}"
log_info "Patroni config patched and container restarted"

for _ in $(seq 1 30); do
  DCS_CONN="$(docker exec redi-etcd etcdctl get "/service/${POSTGRES_SCOPE}/members/${MJK_MEMBER}" --print-value-only 2>/dev/null \
    | grep -o 'postgres://[^/]*' | sed 's|postgres://||' || true)"
  [[ "${DCS_CONN}" == "${TARGET}" ]] && break
  sleep 3
done

docker exec redi-etcd etcdctl del "/service/${POSTGRES_SCOPE}/members/mjk" 2>/dev/null || true

docker exec redi-postgres patronictl list 2>/dev/null || true
[[ "${DCS_CONN}" == "${TARGET}" ]] || { log_error "etcd ${MJK_MEMBER} conn_url still ${DCS_CONN:-missing}"; exit 1; }

bash "${SCRIPT_DIR}/deploy-haproxy-patroni.sh"
bash "${SCRIPT_DIR}/deploy-pgbouncer.sh"

log_info "PASS: ${MJK_MEMBER} mesh IP ${TARGET} in patronictl and etcd"
