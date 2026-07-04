#!/usr/bin/env bash
# =============================================================================
# REDI Sprint 3C — Sync Redis master to HAProxy (mjk) + PowerDNS (jkt)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

export SSHPASS="${REDI_SSH_JKT_PASS:-BitApp2026!@#}"
JKT_HOST="${JKT_PUBLIC_IP:-103.149.238.98}"
SSH_JKT=(sshpass -e ssh -p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "devapp@${JKT_HOST}")

bash "${SCRIPT_DIR}/sync-redis-haproxy.sh"

"${SSH_JKT[@]}" "bash -s" <<EOF
set -euo pipefail
export REDI_ROOT=/opt/redi
bash /opt/redi/scripts/deploy/sync-redis-master-dns.sh
EOF

log_info "Redis master synced to HAProxy + PowerDNS"
