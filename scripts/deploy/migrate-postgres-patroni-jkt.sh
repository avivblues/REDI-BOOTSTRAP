#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Join jkt as Patroni replica
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-jkt-01" ]] || { log_error "Run on redi-jkt-01"; exit 1; }

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.redi-jkt-01"
# shellcheck source=/dev/null
source "${ENV_BASE}"
source "${NODE_ENV}"

export NODE_MESH_IP="${JKT_MESH_IP}"
export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"
export ETCD3_HOSTS="${ETCD3_HOSTS:-${MJK_MESH_IP}:2379,${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379}"

log_info "Stopping legacy PostgreSQL replica on jkt"
docker stop redi-postgres 2>/dev/null || true
docker rm redi-postgres 2>/dev/null || true

if [[ -d "${SHARED_DATA_PATH}/postgres/pgdata" ]]; then
  mv "${SHARED_DATA_PATH}/postgres/pgdata" \
    "${SHARED_DATA_PATH}/postgres/pgdata.pre-patroni-$(date +%Y%m%d)"
  log_info "Archived legacy replica data"
fi

log_info "Starting Spilo/Patroni on jkt"
cd "${REDI_ROOT}/compose/shared-platform/postgres"
docker compose -f docker-compose.yml --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate

for _ in $(seq 1 90); do
  if docker exec redi-postgres pg_isready -U postgres -h 127.0.0.1 &>/dev/null; then
  curl -sf "http://${JKT_MESH_IP}:8008/patroni" 2>/dev/null | grep -q replica && break
  fi
  sleep 3
done

docker exec redi-postgres pg_isready -U postgres -h 127.0.0.1
curl -sf "http://${JKT_MESH_IP}:8008/patroni" | head -c 200
echo
log_info "Patroni replica on jkt ready"
