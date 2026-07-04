#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Redis Sentinel failover drill + DNS/HAProxy verification
# Usage: redis-failover-test.sh [--execute]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/redis-sentinel.sh"

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

EXECUTE=false
[[ "${1:-}" == "--execute" ]] && EXECUTE=true

export SSHPASS="${REDI_SSH_JKT_PASS:-BitApp2026!@#}"
JKT_HOST="${JKT_PUBLIC_IP:-103.149.238.98}"
SSH_JKT=(sshpass -e ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "devapp@${JKT_HOST}")

log_info "Redis Sentinel status (redi-master)"
docker exec redi-redis-sentinel redis-cli -p 26379 sentinel master redi-master 2>/dev/null | grep -E '^name|^ip|^port|^flags' || true

MASTER_IP="$(redis_sentinel_master_ip || true)"
MASTER_PORT="${REDIS_MASTER_PORT:-6379}"
log_info "Sentinel master: ${MASTER_IP:-unknown}:${MASTER_PORT}"

if docker run --rm --network redi-internal redis:7.4-alpine \
  redis-cli -h redis.redi.internal -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q PONG; then
  log_info "PASS: redis.redi.internal (HAProxy) responds PONG"
else
  log_error "FAIL: redis.redi.internal unreachable"
  exit 1
fi

DNS_IP="$("${SSH_JKT[@]}" "dig +short redis.redi.internal @127.0.0.1 2>/dev/null | head -1" || true)"
if [[ "${DNS_IP}" == "${MASTER_IP}" ]]; then
  log_info "PASS: PowerDNS redis.redi.internal → ${DNS_IP}"
else
  log_warn "DNS redis.redi.internal=${DNS_IP:-missing} (master=${MASTER_IP})"
fi

TEST_KEY="redi-3c-drill-$(date +%s)"
if docker run --rm --network redi-internal redis:7.4-alpine \
  redis-cli -h redis.redi.internal -a "${REDIS_PASSWORD}" SET "${TEST_KEY}" ok EX 120 2>/dev/null | grep -q OK; then
  log_info "PASS: write via redis.redi.internal"
else
  log_error "FAIL: cannot write via redis.redi.internal (readonly replica?)"
  exit 1
fi

if [[ "${EXECUTE}" != "true" ]]; then
  log_info "Dry-run only. Pass --execute to trigger Sentinel failover."
  exit 0
fi

log_warn "Executing sentinel failover for redi-master..."
docker exec redi-redis-sentinel redis-cli -p 26379 sentinel failover redi-master

START=$(date +%s)
NEW_IP=""
for _ in $(seq 1 30); do
  NEW_IP="$(redis_sentinel_master_ip || true)"
  [[ -n "${NEW_IP}" && "${NEW_IP}" != "${MASTER_IP}" ]] && break
  sleep 2
done
log_info "Failover in $(( $(date +%s) - START ))s — new master: ${NEW_IP:-unknown}"

bash "${SCRIPT_DIR}/sync-redis-master.sh" || true
sleep 5

NEW_IP="$(redis_sentinel_master_ip || true)"
DNS_IP="$("${SSH_JKT[@]}" "dig +short redis.redi.internal @127.0.0.1 2>/dev/null | head -1" || true)"

HAPROXY_MODE="$(cat "${REDI_ROOT}/config/shared-platform/.redis-haproxy-mode" 2>/dev/null || echo bridge)"
REDIS_HOST="redis.redi.internal"
[[ "${HAPROXY_MODE}" == "host" ]] && REDIS_HOST="${REDI_INTERNAL_GATEWAY:-172.32.0.1}"

docker run --rm --network redi-internal redis:7.4-alpine \
  redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" GET "${TEST_KEY}" 2>/dev/null | grep -q ok \
  && log_info "PASS: read key after failover via ${REDIS_HOST}"

[[ "${DNS_IP}" == "${NEW_IP}" ]] \
  && log_info "PASS: PowerDNS updated to ${NEW_IP}" \
  || log_warn "DNS lag: ${DNS_IP:-missing} vs master ${NEW_IP}"

curl -sk -o /dev/null -w "gitlab=%{http_code}\n" https://git.letsredi.com/users/sign_in 2>/dev/null || true
log_info "Sprint 3C Redis failover drill complete"
