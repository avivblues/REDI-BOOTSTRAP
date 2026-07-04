#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Migrate plain PostgreSQL to Spilo/Patroni + routing
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01"; exit 1; }

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.redi-mjk-01"
# shellcheck source=/dev/null
source "${ENV_BASE}"
source "${NODE_ENV}"

export NODE_MESH_IP="${MJK_MESH_IP}"
export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"
export SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"
export ETCD3_HOSTS="${ETCD3_HOSTS:-${MJK_MESH_IP}:2379,${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379}"

BACKUP="${REDI_ROOT}/backup/pre-patroni-$(date +%Y%m%d-%H%M%S).sql.gz"
log_info "Pre-Patroni backup → ${BACKUP}"
mkdir -p "$(dirname "${BACKUP}")"
docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  pg_dumpall -U postgres | gzip > "${BACKUP}"

export ETCD3_HOSTS="${ETCD3_HOSTS:-${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379}"

log_info "Stopping legacy PostgreSQL on mjk"
docker stop redi-postgres 2>/dev/null || true
docker rm redi-postgres 2>/dev/null || true

log_info "Starting Spilo/Patroni on mjk"
cd "${REDI_ROOT}/compose/shared-platform/postgres"
docker compose -f docker-compose.yml --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate

for _ in $(seq 1 60); do
  if docker exec redi-postgres pg_isready -U postgres -h 127.0.0.1 &>/dev/null; then
    break
  fi
  sleep 3
done

docker exec redi-postgres pg_isready -U postgres -h 127.0.0.1
curl -sf "http://${MJK_MESH_IP}:8008/patroni" | head -c 200
echo

# Spilo initdb on empty dir — restore application data from backup
if ! docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='gitlabhq_production'" 2>/dev/null | grep -q 1; then
  log_warn "Restoring databases from ${BACKUP}"
  gunzip -c "${BACKUP}" | docker exec -i -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
    psql -U postgres -v ON_ERROR_STOP=0 >/dev/null
fi

bash "${SCRIPT_DIR}/deploy-haproxy-patroni.sh"

log_info "Patroni primary on mjk — bootstrap jkt replica next (run migrate-postgres-patroni-jkt.sh on jkt)"
