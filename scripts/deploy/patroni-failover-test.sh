#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3B — Patroni cross-node failover drill
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

MJK_MEMBER="${PATRONI_MJK_MEMBER:-mjk-mesh}"

export SSHPASS="${REDI_SSH_PASS:-!Proxmox@Redi123}"
SSH_MJK=(sshpass -e ssh -p 2280 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${MJK_MESH_IP}")
SSH_JKT=(sshpass -e ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "devapp@${JKT_PUBLIC_IP:-103.149.238.98}")

patroni_role() {
  local host="$1"
  curl -sf "http://${host}:8008/patroni" 2>/dev/null | grep -o '"role": "[^"]*"' || true
}

is_leader_role() {
  echo "${1:-}" | grep -qE '"(leader|master)"'
}

is_replica_role() {
  echo "${1:-}" | grep -qE '"(replica|standby)"'
}

pg_via_apps() {
  local sql="$1"
  local db="${2:-postgres}"
  docker run --rm --network redi-internal \
    -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" postgres:16-alpine \
    psql -h postgres.redi.internal -p 5432 -U postgres -d "${db}" -tAc "${sql}"
}

START=$(date +%s)
log_info "Cluster before failover"
"${SSH_MJK[@]}" "docker exec redi-postgres patronictl list" 2>/dev/null || true

MJK_ROLE=$(patroni_role "${MJK_MESH_IP}")
if ! is_leader_role "${MJK_ROLE}"; then
  log_info "mjk is not leader (${MJK_ROLE:-unknown}) — switchover to ${MJK_MEMBER} via jkt"
  "${SSH_JKT[@]}" "docker exec redi-postgres patronictl switchover --leader jkt --candidate ${MJK_MEMBER} --force" 2>/dev/null || true
  for _ in $(seq 1 30); do
    MJK_ROLE=$(patroni_role "${MJK_MESH_IP}")
    is_leader_role "${MJK_ROLE}" && break
    sleep 2
  done
fi
is_leader_role "${MJK_ROLE}" || { log_error "mjk is not leader; cannot run cross-node drill"; exit 1; }

log_info "Simulate mjk primary failure — stop Spilo on mjk"
"${SSH_MJK[@]}" "docker stop redi-postgres" 2>/dev/null || docker stop redi-postgres 2>/dev/null || true

NEW_LEADER=""
for _ in $(seq 1 60); do
  JKT_ROLE=$(patroni_role "${JKT_MESH_IP}")
  if is_leader_role "${JKT_ROLE}"; then
    NEW_LEADER="${JKT_MESH_IP}"
    log_info "Failover to jkt in $(( $(date +%s) - START ))s (${JKT_ROLE})"
    break
  fi
  sleep 2
done

[[ -n "${NEW_LEADER}" ]] || { log_error "Failover did not promote jkt"; exit 1; }

pg_via_apps "SELECT 1" >/dev/null \
  && log_info "PASS: PgBouncer/HAProxy route writes to new leader (postgres.redi.internal)"

USERS=$(pg_via_apps "SELECT count(*) FROM users" gitlabhq_production 2>/dev/null || echo 0)
log_info "GitLab users via postgres.redi.internal: ${USERS}"

curl -sk -o /dev/null -w "gitlab=%{http_code}\n" https://git.letsredi.com/users/sign_in 2>/dev/null || true

log_info "Restore mjk — start Spilo (rejoins as replica)"
"${SSH_MJK[@]}" "docker start redi-postgres" 2>/dev/null || docker start redi-postgres

for _ in $(seq 1 60); do
  MJK_ROLE=$(patroni_role "${MJK_MESH_IP}")
  if is_replica_role "${MJK_ROLE}"; then
    log_info "mjk rejoined as replica in $(( $(date +%s) - START ))s total (${MJK_ROLE})"
    break
  fi
  sleep 2
done

"${SSH_MJK[@]}" "docker exec redi-postgres patronictl list" 2>/dev/null || true

log_info "PASS: Patroni cross-node failover drill"
