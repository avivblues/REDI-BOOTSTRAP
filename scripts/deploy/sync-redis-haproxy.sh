#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Sync Redis HAProxy backend to Sentinel master (mjk)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/redis-sentinel.sh"

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.$(hostname -s)"
# shellcheck source=/dev/null
source "${ENV_BASE}"
[[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"
export NODE_MESH_IP

SHARED_CONFIG_PATH="${REDI_ROOT}/config/shared-platform"
STATE_FILE="${SHARED_CONFIG_PATH}/.redis-master-ip"
MODE_FILE="${SHARED_CONFIG_PATH}/.redis-haproxy-mode"
CFG="${SHARED_CONFIG_PATH}/haproxy-redis.cfg"

mapfile -t _master < <(redis_sentinel_master_addr || true)
REDIS_MASTER_IP="${_master[0]:-}"
REDIS_MASTER_PORT="${_master[1]:-${REDIS_MASTER_PORT:-6379}}"

[[ -n "${REDIS_MASTER_IP}" ]] || { log_error "Cannot resolve Sentinel master"; exit 1; }

mapfile -t _backend < <(redis_haproxy_backend_addr "${REDIS_MASTER_IP}" "${REDIS_MASTER_PORT}")
REDIS_BACKEND_HOST="${_backend[0]}"
REDIS_BACKEND_PORT="${_backend[1]}"

# Bridge mode keeps docker alias redis.redi.internal on redi-internal for all HA nodes.
HAPROXY_MODE="bridge"
export REDIS_HAPROXY_BIND="0.0.0.0"

PREV="$(cat "${STATE_FILE}" 2>/dev/null || true)"
PREV_MODE="$(cat "${MODE_FILE}" 2>/dev/null || true)"
redis_haproxy_running() {
  docker ps --filter name=^redi-redis-haproxy$ --filter status=running --format '{{.Names}}' | grep -qx 'redi-redis-haproxy'
}

redis_haproxy_remove_stale() {
  docker compose -f "${HAPROXY_COMPOSE_FILE}" --env-file "${ENV_BASE}" down --remove-orphans >/dev/null 2>&1 || true
  docker ps -aq --filter name=redi-redis-haproxy | xargs -r docker rm -f >/dev/null 2>&1 || true
  for _ in $(seq 1 30); do
    docker ps -a --filter name=redi-redis-haproxy --format '{{.Status}}' 2>/dev/null | grep -qi removing || break
    sleep 1
  done
}
if [[ "${PREV}" == "${REDIS_BACKEND_HOST}:${REDIS_BACKEND_PORT}" && "${PREV_MODE}" == "${HAPROXY_MODE}" && -f "${CFG}" ]] \
  && redis_haproxy_running; then
  log_info "Redis HAProxy unchanged (backend ${REDIS_BACKEND_HOST}:${REDIS_BACKEND_PORT})"
  exit 0
fi
HAPROXY_COMPOSE="${REDI_ROOT}/compose/shared-platform/haproxy-redis"
HAPROXY_COMPOSE_FILE="${HAPROXY_COMPOSE}/docker-compose.yml"

if ! redis_haproxy_running; then
  log_info "Redis HAProxy missing or not running — recreating"
  redis_haproxy_remove_stale
fi
export REDIS_BACKEND_HOST REDIS_BACKEND_PORT REDIS_PASSWORD
envsubst < "${REDI_ROOT}/config/shared-platform/haproxy-redis.cfg.template" > "${CFG}.tmp"
mv "${CFG}.tmp" "${CFG}"
echo "${REDIS_BACKEND_HOST}:${REDIS_BACKEND_PORT}" > "${STATE_FILE}"
echo "${HAPROXY_MODE}" > "${MODE_FILE}"

NEED_RECREATE=false
[[ "${PREV_MODE}" != "${HAPROXY_MODE}" ]] && NEED_RECREATE=true

if [[ "${NEED_RECREATE}" == "true" ]] || ! redis_haproxy_running; then
  redis_haproxy_remove_stale
  docker compose -f "${HAPROXY_COMPOSE_FILE}" --env-file "${ENV_BASE}" up -d --force-recreate
else
  docker exec redi-redis-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
  docker kill -s HUP redi-redis-haproxy >/dev/null 2>&1 || log_warn "Redis HAProxy HUP failed; container still running with prior config"
fi

log_info "Redis HAProxy → ${REDIS_BACKEND_HOST}:${REDIS_BACKEND_PORT} (sentinel master ${REDIS_MASTER_IP})"
