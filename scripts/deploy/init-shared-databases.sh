#!/usr/bin/env bash
# =============================================================================
# REDI — Initialize databases on shared PostgreSQL HA
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
MJK_MESH_IP="$(grep -E '^MJK_MESH_IP=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
POSTGRES_SUPERUSER_PASSWORD="$(grep -E '^POSTGRES_SUPERUSER_PASSWORD=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"

PGHOST="${MJK_MESH_IP}"
PGPORT=5432
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}"

RUNTIME_ENV="${REDI_ROOT}/secrets/runtime/shared-db.env"
if [[ -f "${RUNTIME_ENV}" ]]; then
  # shellcheck source=/dev/null
  set +u
  source "${RUNTIME_ENV}"
  set -u
fi

GITLAB_DB_PASSWORD="${GITLAB_DB_PASSWORD:-$(openssl rand -base64 18 | tr -d '/+=' | head -c 18)}"
AUTHENTIK_DB_PASSWORD="${AUTHENTIK_DB_PASSWORD:-$(openssl rand -base64 18 | tr -d '/+=' | head -c 18)}"

wait_for_service "${PGHOST}" "${PGPORT}" 180

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres psql -U postgres -v ON_ERROR_STOP=1 <<-EOSQL
DO \$\$ BEGIN
  CREATE USER gitlab WITH PASSWORD '${GITLAB_DB_PASSWORD}';
EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
DO \$\$ BEGIN
  CREATE DATABASE gitlabhq_production OWNER gitlab;
EXCEPTION WHEN duplicate_database THEN NULL; END \$\$;
DO \$\$ BEGIN
  CREATE USER authentik WITH PASSWORD '${AUTHENTIK_DB_PASSWORD}';
EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
DO \$\$ BEGIN
  CREATE DATABASE authentik OWNER authentik;
EXCEPTION WHEN duplicate_database THEN NULL; END \$\$;
GRANT ALL PRIVILEGES ON DATABASE gitlabhq_production TO gitlab;
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
EOSQL

mkdir -p "${REDI_ROOT}/secrets/runtime"
cat > "${REDI_ROOT}/secrets/runtime/shared-db.env" <<EOF
GITLAB_DB_PASSWORD=${GITLAB_DB_PASSWORD}
AUTHENTIK_DB_PASSWORD=${AUTHENTIK_DB_PASSWORD}
EOF
chmod 600 "${REDI_ROOT}/secrets/runtime/shared-db.env"
log_info "Shared databases initialized (gitlabhq_production, authentik)"
