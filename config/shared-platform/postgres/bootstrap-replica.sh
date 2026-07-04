#!/bin/bash
set -euo pipefail
if [ -s "${PGDATA}/PG_VERSION" ]; then
  exit 0
fi
export PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}"
until pg_isready -h "${PRIMARY_HOST}" -p "${PRIMARY_PORT}" -U "${POSTGRES_USER:-postgres}"; do sleep 2; done
rm -rf "${PGDATA}"/*
pg_basebackup -h "${PRIMARY_HOST}" -p "${PRIMARY_PORT}" -U repl -D "${PGDATA}" -Fp -Xs -P -R
touch "${PGDATA}/standby.signal"
echo "primary_conninfo = 'host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=repl password=${REPL_PASSWORD}'" >> "${PGDATA}/postgresql.auto.conf"
chown -R postgres:postgres "${PGDATA}"
chmod 700 "${PGDATA}"
