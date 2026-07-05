#!/usr/bin/env bash
# =============================================================================
# REDI Phase 5 — Authentik backup (PostgreSQL authentik DB + media/templates)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

BACKUP_DATE="${1:-$(date +%Y%m%d-%H%M%S)}"
BACKUP_DIR="${REDI_ROOT}/backup/${BACKUP_DATE}"
ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
AUTH_ENV="${REDI_ROOT}/compose/authentik/.env"

mkdir -p "${BACKUP_DIR}"
# shellcheck source=/dev/null
source "${ENV_BASE}"
# shellcheck source=/dev/null
[[ -f "${AUTH_ENV}" ]] && source "${AUTH_ENV}"

DATA_PATH="${AUTHENTIK_DATA_PATH:-${REDI_ROOT}/data/authentik}"

log_info "Backing up Authentik → ${BACKUP_DIR}"

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
  pg_dump -U postgres -Fc authentik > "${BACKUP_DIR}/authentik-db.dump"

tar czf "${BACKUP_DIR}/authentik-media.tar.gz" \
  -C "${DATA_PATH}" media templates 2>/dev/null || \
  tar czf "${BACKUP_DIR}/authentik-media.tar.gz" -C "${DATA_PATH}" media

# Config without secrets
tar czf "${BACKUP_DIR}/authentik-compose.tar.gz" \
  -C "${REDI_ROOT}/compose" authentik/docker-compose.yml \
  authentik/.env.example 2>/dev/null || true

cat > "${BACKUP_DIR}/authentik-manifest.json" <<EOF
{
  "service": "authentik",
  "timestamp": "${BACKUP_DATE}",
  "database": "authentik-db.dump",
  "media": "authentik-media.tar.gz"
}
EOF

log_info "Authentik backup complete: $(du -sh "${BACKUP_DIR}/authentik-db.dump" "${BACKUP_DIR}/authentik-media.tar.gz" | paste -sd' ' -)"
