#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Fix Patroni mesh IPs for cross-node failover
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

HOSTNAME="$(hostname -s)"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.${HOSTNAME}"
# shellcheck source=/dev/null
[[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"

export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"
export NODE_MESH_IP
case "${HOSTNAME}" in
  redi-mjk-01) NODE_MESH_IP="${MJK_MESH_IP}"; export ETCD3_HOSTS="${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379" ;;
  redi-jkt-01) NODE_MESH_IP="${JKT_MESH_IP}"; export ETCD3_HOSTS="${MJK_MESH_IP}:2379,${JKT_MESH_IP}:2379,${SBY_MESH_IP}:2379" ;;
  *) { log_error "Unsupported host ${HOSTNAME}"; exit 1; } ;;
esac

PG_PORT="${POSTGRES_DIRECT_PORT:-5433}"
COMPOSE_DIR="${REDI_ROOT}/compose/shared-platform/postgres"

patch_etcd_member() {
  local name="$1" mesh_ip="$2" role="$3"
  docker exec redi-etcd etcdctl put "/service/${POSTGRES_SCOPE}/members/${name}" \
    "{\"conn_url\":\"postgres://${mesh_ip}:${PG_PORT}/postgres\",\"api_url\":\"http://${mesh_ip}:8008/patroni\",\"state\":\"running\",\"role\":\"${role}\",\"version\":\"3.2.2\"}"
}

redeploy_spilo() {
  log_info "Redeploy Spilo host-network on ${HOSTNAME}"
  docker stop redi-postgres 2>/dev/null || true
  docker rm redi-postgres 2>/dev/null || true
  cd "${COMPOSE_DIR}"
  docker compose -f docker-compose.yml --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d
  for _ in $(seq 1 40); do
    docker exec redi-postgres pg_isready -U postgres -h 127.0.0.1 -p "${PG_PORT}" 2>/dev/null && return 0
    sleep 3
  done
  log_error "Spilo not ready on ${HOSTNAME}"
  docker logs redi-postgres 2>&1 | tail -20
  exit 1
}

case "${HOSTNAME}" in
  redi-mjk-01)
    log_info "Remove stale jkt member from DCS"
    docker exec redi-etcd etcdctl del "/service/${POSTGRES_SCOPE}/members/jkt" 2>/dev/null || true
    redeploy_spilo
    patch_etcd_member "mjk" "${MJK_MESH_IP}" "master"
    docker exec redi-postgres patronictl list 2>/dev/null || true
    bash "${SCRIPT_DIR}/deploy-haproxy-patroni.sh"
    bash "${SCRIPT_DIR}/deploy-pgbouncer.sh"
    ;;
  redi-jkt-01)
    log_info "Wipe replica data for clean Patroni bootstrap via mesh IP"
    docker stop redi-postgres 2>/dev/null || true
    docker rm redi-postgres 2>/dev/null || true
    rm -rf "${SHARED_DATA_PATH}/postgres/pgdata" "${SHARED_DATA_PATH}/postgres/pgroot" 2>/dev/null || true
    redeploy_spilo
  ;;
esac

log_info "Patroni mesh fix complete on ${HOSTNAME}"
