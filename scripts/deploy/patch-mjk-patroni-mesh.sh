#!/usr/bin/env bash
# =============================================================================
# Patch mjk Spilo /run/postgres.yml to advertise mesh IP (docker DNS overrides hostname)
# =============================================================================
set -euo pipefail

MESH_IP="${1:?mesh IP required}"
PG_PORT="${2:-5433}"

docker exec redi-postgres python3 -c "
import yaml
target = '${MESH_IP}:${PG_PORT}'
with open('/run/postgres.yml') as f:
    c = yaml.safe_load(f)
if c.get('postgresql', {}).get('connect_address') == target:
    raise SystemExit(0)
c['postgresql']['connect_address'] = target
c['restapi']['connect_address'] = '${MESH_IP}:8008'
with open('/run/postgres.yml', 'w') as f:
    yaml.dump(c, f, default_flow_style=False)
print('patched', target)
"

docker restart redi-postgres >/dev/null
for _ in $(seq 1 40); do
  docker exec redi-postgres pg_isready -U postgres -h 127.0.0.1 -p "${PG_PORT}" 2>/dev/null && exit 0
  sleep 3
done
exit 1
