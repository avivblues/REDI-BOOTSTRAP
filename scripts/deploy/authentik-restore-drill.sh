#!/usr/bin/env bash
# =============================================================================
# REDI Phase 5 — Non-destructive Authentik restore drill (isolated Postgres)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_BASE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_BASE}"

BACKUP_DIR="${1:-}"
if [[ -z "${BACKUP_DIR}" ]]; then
  BACKUP_DIR="$(ls -dt "${REDI_ROOT}"/backup/*/ 2>/dev/null | head -1)"
fi
BACKUP_DIR="${BACKUP_DIR%/}"
DUMP="${BACKUP_DIR}/authentik-db.dump"
[[ -f "${DUMP}" ]] || { log_error "Missing ${DUMP}"; exit 1; }

DRILL_PORT=5435
DRILL_CONTAINER="redi-authentik-drill"
DRILL_DIR="${REDI_ROOT}/data/authentik-drill"

log_info "Authentik restore drill from ${DUMP}"

SRC_USERS="$(docker exec redi-authentik-server ak shell -c "from authentik.core.models import User; print(User.objects.count())" 2>/dev/null | tail -1)"
SRC_GROUPS="$(docker exec redi-authentik-server ak shell -c "from authentik.core.models import Group; print(Group.objects.filter(name__startswith='REDI').count())" 2>/dev/null | tail -1)"
SRC_PROVIDERS="$(docker exec redi-authentik-server ak shell -c "from authentik.providers.oauth2.models import OAuth2Provider; print(OAuth2Provider.objects.filter(name='REDI GitLab').count())" 2>/dev/null | tail -1)"

docker rm -f "${DRILL_CONTAINER}" 2>/dev/null || true
rm -rf "${DRILL_DIR}"
mkdir -p "${DRILL_DIR}"

docker run -d --name "${DRILL_CONTAINER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" \
  -v "${DRILL_DIR}:/var/lib/postgresql/data" \
  -p "127.0.0.1:${DRILL_PORT}:5432" \
  postgres:16-alpine

for _ in $(seq 1 30); do
  docker exec "${DRILL_CONTAINER}" pg_isready -U postgres &>/dev/null && break
  sleep 2
done

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  createdb -U postgres authentik 2>/dev/null || true
pg_restore -d "postgresql://postgres:${POSTGRES_SUPERUSER_PASSWORD}@127.0.0.1:${DRILL_PORT}/authentik" \
  --no-owner --no-acl "${DUMP}" 2>/dev/null || \
  cat "${DUMP}" | docker exec -i -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
    pg_restore -U postgres -d authentik --no-owner --no-acl 2>/dev/null || true

DST_USERS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -U postgres -d authentik -tAc "SELECT count(*) FROM authentik_core_user;" 2>/dev/null || echo 0)"
DST_GROUPS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -U postgres -d authentik -tAc "SELECT count(*) FROM authentik_core_group WHERE name LIKE 'REDI%';" 2>/dev/null || echo 0)"
DST_PROVIDERS="$(docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" "${DRILL_CONTAINER}" \
  psql -U postgres -d authentik -tAc "SELECT count(*) FROM authentik_providers_oauth2_oauth2provider;" 2>/dev/null || echo 0)"

docker rm -f "${DRILL_CONTAINER}" 2>/dev/null || true

log_info "Users source=${SRC_USERS} restored=${DST_USERS}"
log_info "REDI groups source=${SRC_GROUPS} restored=${DST_GROUPS}"
log_info "GitLab provider source=${SRC_PROVIDERS} restored=${DST_PROVIDERS}"

[[ "${SRC_USERS}" == "${DST_USERS}" ]] || { log_error "User count mismatch"; exit 1; }
[[ "${SRC_GROUPS}" == "${DST_GROUPS}" ]] || { log_error "Group count mismatch"; exit 1; }
[[ "${SRC_PROVIDERS}" == "${DST_PROVIDERS}" ]] || { log_error "OAuth provider count mismatch (${SRC_PROVIDERS} vs ${DST_PROVIDERS})"; exit 1; }

log_info "PASS: Authentik restore drill"
