#!/usr/bin/env bash
# =============================================================================
# REDI — Deploy Authentik Identity Platform (HA on mjk/jkt/sby)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/authentik"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
if [[ "${HOSTNAME}" != "redi-mjk-01" && "${HOSTNAME}" != "redi-jkt-01" && "${HOSTNAME}" != "redi-sby-01" ]]; then
  log_error "Authentik deploys on redi-mjk-01, redi-jkt-01, or redi-sby-01. Current: ${HOSTNAME}"
  exit 1
fi

ENV_FILE="${COMPOSE_DIR}/.env"
NODE_ENV="${COMPOSE_DIR}/.env.${HOSTNAME}"
if [[ -f "${NODE_ENV}" ]]; then
  cp "${NODE_ENV}" "${ENV_FILE}"
elif [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}. Copy from .env.${HOSTNAME}.example and configure."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

TS_IP="$(get_tailscale_ip)"
if grep -q "^AUTHENTIK_TAILSCALE_IP=" "${ENV_FILE}"; then
  sed -i "s|^AUTHENTIK_TAILSCALE_IP=.*|AUTHENTIK_TAILSCALE_IP=${TS_IP}|" "${ENV_FILE}"
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

ensure_docker_network "redi-internal" "172.31.0.0/24"
ensure_docker_network "redi-management" "172.30.0.0/24"
mkdir -p "${AUTHENTIK_DATA_PATH:-${REDI_ROOT}/data/authentik}"/{media/public,templates}
chown -R 1000:1000 "${AUTHENTIK_DATA_PATH:-${REDI_ROOT}/data/authentik}"

# redis.redi.internal is provided by redi-redis-haproxy on each HA node (jkt/sby lose
# DNS after recreate unless HAProxy is redeployed first).
log_info "Ensuring Redis HAProxy (redis.redi.internal) on ${HOSTNAME}"
bash "${SCRIPT_DIR}/deploy-redis-haproxy-node.sh"

log_info "Waiting for redis.redi.internal on ${HOSTNAME}"
REDIS_DNS_OK=false
for _ in $(seq 1 30); do
  if docker ps --filter name=^redi-redis-haproxy$ --filter health=healthy --format '{{.Names}}' | grep -qx 'redi-redis-haproxy' \
    && docker run --rm --network redi-internal busybox:1.36 nslookup redis.redi.internal >/dev/null 2>&1; then
    REDIS_DNS_OK=true
    break
  fi
  sleep 2
done
if [[ "${REDIS_DNS_OK}" != "true" ]]; then
  log_error "redis.redi.internal not resolvable after Redis HAProxy deploy"
  exit 1
fi
log_info "redis.redi.internal resolvable on ${HOSTNAME}"

log_info "Deploying Authentik on ${HOSTNAME} (mesh ${AUTHENTIK_TAILSCALE_IP}:9100)"
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" pull
docker compose --env-file "${ENV_FILE}" up -d --force-recreate

sleep 10
docker compose --env-file "${ENV_FILE}" ps

for _ in $(seq 1 24); do
  if curl -sf "http://${AUTHENTIK_TAILSCALE_IP}:9100/-/health/ready/" >/dev/null 2>&1; then
    log_info "Authentik ready on ${HOSTNAME}"
    exit 0
  fi
  sleep 5
done

log_error "Authentik health not ready on ${HOSTNAME}"
docker logs redi-authentik-server --tail 20
exit 1
