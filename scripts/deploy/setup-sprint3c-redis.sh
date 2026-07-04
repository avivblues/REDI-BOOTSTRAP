#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Redis Sentinel HA (HAProxy router + PowerDNS hook)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

HOSTNAME="$(hostname -s)"
ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
NODE_ENV="${REDI_ROOT}/compose/shared-platform/.env.${HOSTNAME}"

export SSHPASS="${REDI_SSH_JKT_PASS:-BitApp2026!@#}"
JKT_HOST="${JKT_PUBLIC_IP:-103.149.238.98}"

case "${HOSTNAME}" in
  redi-mjk-01)
    log_info "Sprint 3C — redeploy Redis without docker DNS alias"
    cd "${REDI_ROOT}/compose/shared-platform/redis"
    # shellcheck source=/dev/null
    source "${ENV_BASE}"
    # shellcheck source=/dev/null
    [[ -f "${NODE_ENV}" ]] && source "${NODE_ENV}"
    export COMPOSE_PROFILES="$(grep -E '^COMPOSE_PROFILES=' "${NODE_ENV}" | cut -d= -f2- || echo host-sentinel)"
    docker compose --env-file "${ENV_BASE}" --env-file "${NODE_ENV}" up -d --force-recreate

    bash "${SCRIPT_DIR}/deploy-redis-haproxy.sh"

    CRON_LINE="*/1 * * * * root ${REDI_ROOT}/scripts/deploy/sync-redis-master.sh >> ${REDI_ROOT}/logs/shared-platform/redis-sync.log 2>&1"
    CRON_FILE="/etc/cron.d/redi-redis-sentinel-sync"
    echo "${CRON_LINE}" > "${CRON_FILE}"
    chmod 644 "${CRON_FILE}"

  # Push DNS sync script to jkt (devapp can write /opt/redi — no sudo)
    export SSHPASS
    sshpass -e ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "devapp@${JKT_HOST}" \
      "mkdir -p /opt/redi/scripts/deploy /opt/redi/scripts/lib /opt/redi/config/shared-platform /opt/redi/logs/shared-platform"
    sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "${REDI_ROOT}/scripts/deploy/sync-redis-master-dns.sh" \
      "devapp@${JKT_HOST}:/opt/redi/scripts/deploy/"
    sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "${REDI_ROOT}/scripts/lib/redis-sentinel.sh" \
      "devapp@${JKT_HOST}:/opt/redi/scripts/lib/"
    sshpass -e ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "devapp@${JKT_HOST}" \
      "chmod +x /opt/redi/scripts/deploy/sync-redis-master-dns.sh"

    bash "${SCRIPT_DIR}/sync-redis-master.sh"
    log_info "Sprint 3C complete on mjk"
    ;;
  redi-jkt-01)
    bash "${SCRIPT_DIR}/sync-redis-master-dns.sh"
    log_info "Sprint 3C DNS sync run on jkt"
    ;;
  *)
    log_info "Sprint 3C: no action on ${HOSTNAME}"
    ;;
esac
