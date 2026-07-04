#!/usr/bin/env bash
# =============================================================================
# REDI — Validate Shared Platform Foundation (Phase 5)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
MJK_MESH_IP="$(grep -E '^MJK_MESH_IP=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
POSTGRES_SUPERUSER_PASSWORD="$(grep -E '^POSTGRES_SUPERUSER_PASSWORD=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
REDIS_PASSWORD="$(grep -E '^REDIS_PASSWORD=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"

PASS=0
FAIL=0
warn() { log_warn "$*"; }
ok() { log_info "PASS: $*"; PASS=$((PASS + 1)); }
bad() { log_error "FAIL: $*"; FAIL=$((FAIL + 1)); }

# PostgreSQL HA
if docker run --rm -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" postgres:16-alpine \
  psql -h "${MJK_MESH_IP}" -p 5432 -U postgres -c "SELECT 1" &>/dev/null; then
  ok "PostgreSQL HA endpoint (postgres.redi.internal:5432)"
else
  bad "PostgreSQL HA endpoint"
fi

# Redis
if docker run --rm redis:7.4-alpine redis-cli -h "${MJK_MESH_IP}" -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q PONG; then
  ok "Redis endpoint"
else
  bad "Redis endpoint"
fi

# MinIO
if curl -sf "http://${MJK_MESH_IP}:9000/minio/health/live" &>/dev/null; then
  ok "MinIO cluster health"
else
  bad "MinIO cluster health"
fi

# GitLab
if docker ps --format '{{.Names}}' | grep -q '^redi-gitlab$'; then
  gitlab_env="$(docker inspect redi-gitlab --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null || true)"
  if echo "${gitlab_env}" | grep -q "postgres.redi.internal" && echo "${gitlab_env}" | grep -q "redis.redi.internal"; then
    ok "GitLab uses shared PostgreSQL and Redis"
  elif host="$(timeout 30 docker exec redi-gitlab gitlab-rails runner "puts Gitlab::Database.default_connection_config[:host]" 2>/dev/null || true)" && \
       { [[ "${host}" == *"postgres"* ]] || [[ "${host}" == "${MJK_MESH_IP}" ]]; }; then
    ok "GitLab uses shared PostgreSQL (rails runner: ${host})"
  else
    bad "GitLab shared DB/Redis config not confirmed"
  fi
  if echo "${gitlab_env}" | grep -q "postgresql\['enable'\] = false"; then
    ok "GitLab local PostgreSQL disabled"
  elif docker exec redi-gitlab gitlab-ctl status 2>/dev/null | grep -q "postgresql.*disabled"; then
    ok "GitLab local PostgreSQL disabled"
  else
    warn "GitLab postgresql status unclear"
  fi
  curl -sk -o /dev/null -w "%{http_code}" https://git.letsredi.com/users/sign_in 2>/dev/null | grep -q 200 && ok "GitLab HTTPS" || bad "GitLab HTTPS"
else
  bad "GitLab container not running"
fi

# Authentik
if docker ps --format '{{.Names}}' | grep -q '^redi-authentik-server$'; then
  curl -sf "http://${MJK_MESH_IP}:9100/-/health/ready/" &>/dev/null && ok "Authentik healthy" || bad "Authentik health"
else
  bad "Authentik not running"
fi

# Internal DNS (check via PowerDNS on jkt when not local)
for h in postgres redis minio; do
  ip=$(dig +short "${h}.redi.internal" @100.79.82.92 2>/dev/null | head -1)
  [[ -z "${ip}" ]] && ip=$(dig +short "${h}.redi.internal" 2>/dev/null | head -1)
  [[ "${ip}" == "${MJK_MESH_IP}" ]] && ok "DNS ${h}.redi.internal → ${ip}" || bad "DNS ${h}.redi.internal (${ip:-missing})"
done

log_info "Validation: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
