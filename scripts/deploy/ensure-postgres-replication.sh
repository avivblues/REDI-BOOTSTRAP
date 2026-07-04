#!/usr/bin/env bash
# =============================================================================
# REDI — Ensure PostgreSQL replication user and pg_hba for replicas
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
POSTGRES_SUPERUSER_PASSWORD="$(grep -E '^POSTGRES_SUPERUSER_PASSWORD=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
POSTGRES_REPLICATION_PASSWORD="$(grep -E '^POSTGRES_REPLICATION_PASSWORD=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")"

docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres psql -U postgres -v ON_ERROR_STOP=1 <<-EOSQL
DO \$\$ BEGIN
  CREATE USER repl WITH REPLICATION PASSWORD '${POSTGRES_REPLICATION_PASSWORD}';
EXCEPTION WHEN duplicate_object THEN
  ALTER USER repl WITH PASSWORD '${POSTGRES_REPLICATION_PASSWORD}';
END \$\$;
EOSQL

HBA_LINE="host replication repl 0.0.0.0/0 scram-sha-256"
if ! docker exec redi-postgres grep -qF "${HBA_LINE}" /var/lib/postgresql/data/pgdata/pg_hba.conf; then
  docker exec redi-postgres sh -c "echo '${HBA_LINE}' >> /var/lib/postgresql/data/pgdata/pg_hba.conf"
  docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
    psql -U postgres -c "SELECT pg_reload_conf();"
  log_info "Added replication pg_hba rule"
fi

log_info "PostgreSQL replication user ready"
