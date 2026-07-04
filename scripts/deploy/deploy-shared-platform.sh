#!/usr/bin/env bash
# =============================================================================
# REDI — Deploy Shared Platform Services (Phase 1)
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
MJK_MESH_IP="$(grep -E '^MJK_MESH_IP=' "${ENV_BASE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
POSTGRES_REPLICATION_PASSWORD="$(grep -E '^POSTGRES_REPLICATION_PASSWORD=' "${ENV_BASE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"

if [[ -f "${NODE_ENV}" ]] && grep -qE '^NODE_MESH_IP=' "${NODE_ENV}"; then
  NODE_MESH_IP="$(grep -E '^NODE_MESH_IP=' "${NODE_ENV}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
else
  NODE_MESH_IP="$(get_tailscale_ip)"
fi
export NODE_MESH_IP
export REDIS_ROLE COMPOSE_PROFILES 2>/dev/null || true
[[ -f "${NODE_ENV}" ]] && grep -qE '^REDIS_ROLE=' "${NODE_ENV}" && \
  export REDIS_ROLE="$(grep -E '^REDIS_ROLE=' "${NODE_ENV}" | cut -d= -f2-)"
export SHARED_DATA_PATH="${REDI_ROOT}/data/shared-platform"
export SHARED_LOG_PATH="${REDI_ROOT}/logs/shared-platform"
export SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"

ensure_docker_network "redi-internal" "172.31.0.0/24"
mkdir -p "${REDI_ROOT}/data/shared-platform"/{postgres,redis,redis-sentinel,minio/data{1,2,3,4}}
mkdir -p "${REDI_ROOT}/logs/shared-platform" "${REDI_ROOT}/config/shared-platform/postgres"
chmod +x "${REDI_ROOT}/config/shared-platform/postgres/bootstrap-replica.sh" 2>/dev/null || true

sed "s/REPL_PASSWORD_PLACEHOLDER/${POSTGRES_REPLICATION_PASSWORD}/" \
  "${REDI_ROOT}/config/shared-platform/postgres/init-primary.sql" \
  > "${REDI_ROOT}/config/shared-platform/postgres/init-primary.rendered.sql" 2>/dev/null || true
if [[ -f "${REDI_ROOT}/config/shared-platform/postgres/init-primary.rendered.sql" ]]; then
  cp "${REDI_ROOT}/config/shared-platform/postgres/init-primary.rendered.sql" \
    "${REDI_ROOT}/config/shared-platform/postgres/init-primary.sql"
fi

export MJK_MESH_IP JKT_MESH_IP POSTGRES_MJK_PORT=5433 POSTGRES_JKT_PORT=5433 REDIS_MASTER_HOST
envsubst < "${REDI_ROOT}/config/shared-platform/haproxy.cfg.template" \
  > "${REDI_ROOT}/config/shared-platform/haproxy.cfg"

deploy_postgres() {
  if [[ "${HOSTNAME}" != "redi-mjk-01" && "${HOSTNAME}" != "redi-jkt-01" ]]; then
    log_info "No postgres on ${HOSTNAME}"
    return 0
  fi

  log_info "Deploying Spilo/Patroni PostgreSQL on ${HOSTNAME}"
  cd "${REDI_ROOT}/compose/shared-platform/postgres"
  docker compose --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate
}

deploy_redis() {
  log_info "Redis on ${HOSTNAME}"
  cd "${REDI_ROOT}/compose/shared-platform/redis"
  if grep -q '^COMPOSE_PROFILES=' "${NODE_ENV}" 2>/dev/null; then
    export COMPOSE_PROFILES="$(grep -E '^COMPOSE_PROFILES=' "${NODE_ENV}" | cut -d= -f2-)"
  fi
  rm -rf "${REDI_ROOT}/data/shared-platform/redis-sentinel"/*
  docker compose --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate
  if docker exec redi-redis sh -c 'test -n "$NODE_MESH_IP"' 2>/dev/null; then
    log_info "Redis NODE_MESH_IP=${NODE_MESH_IP}"
  else
    log_error "Redis container missing NODE_MESH_IP — check ${NODE_ENV}"
    exit 1
  fi
}

deploy_haproxy() {
  if [[ "${HOSTNAME}" != "redi-mjk-01" && "${HOSTNAME}" != "redi-jkt-01" && "${HOSTNAME}" != "redi-sby-01" ]]; then
    return 0
  fi
  cd "${REDI_ROOT}/compose/shared-platform/haproxy"
  docker compose --env-file "${ENV_BASE}" up -d
}

deploy_minio() {
  # Sprint 3E: distributed MinIO on all 3 nodes
  cd "${REDI_ROOT}/compose/shared-platform/minio"
  case "${HOSTNAME}" in
    redi-mjk-01)
      mkdir -p "${REDI_ROOT}/data/shared-platform/minio/data1" \
               "${REDI_ROOT}/data/shared-platform/minio/data2"
      docker compose -f docker-compose.mjk.yml --env-file "${ENV_BASE}" up -d
      ;;
    redi-jkt-01)
      mkdir -p "${REDI_ROOT}/data/shared-platform/minio/data1"
      docker compose -f docker-compose.jkt.yml --env-file "${ENV_BASE}" up -d
      ;;
    redi-sby-01)
      mkdir -p "${REDI_ROOT}/data/shared-platform/minio/data1"
      docker compose -f docker-compose.sby.yml --env-file "${ENV_BASE}" up -d
      ;;
    *)
      log_info "No MinIO on ${HOSTNAME}"
      ;;
  esac
}

deploy_postgres
deploy_redis
deploy_haproxy
deploy_minio
log_info "Shared platform deploy complete on ${HOSTNAME}"
