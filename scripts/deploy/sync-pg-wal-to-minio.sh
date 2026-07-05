#!/usr/bin/env bash
# =============================================================================
# REDI — Upload PostgreSQL WAL archive files to MinIO (redi-pg-wal bucket)
# Runs on any Patroni node; syncs only when local node is cluster leader.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

WAL_DIR="${SHARED_DATA_PATH}/postgres/wal_archive"
BUCKET="redi-pg-wal"
ENDPOINT="http://${MJK_MESH_IP}:9000"
MARKER_DIR="${REDI_ROOT}/data/shared-platform/.wal-synced"

patroni_role() {
  curl -sf --max-time 5 "http://127.0.0.1:8008/patroni" 2>/dev/null \
    | grep -o '"role": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown"
}

ROLE="$(patroni_role)"
if [[ "${ROLE}" != "master" && "${ROLE}" != "leader" ]]; then
  exit 0
fi

[[ -d "${WAL_DIR}" ]] || exit 0
mkdir -p "${MARKER_DIR}"

shopt -s nullglob
files=("${WAL_DIR}"/*)
[[ ${#files[@]} -gt 0 ]] || exit 0

docker run --rm --network host \
  -v "${WAL_DIR}:/wal:ro" \
  -v "${MARKER_DIR}:/markers" \
  --entrypoint /bin/sh minio/mc:latest -c "
    mc alias set redi ${ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
    mc mb -p redi/${BUCKET} 2>/dev/null || true
    for f in /wal/*; do
      base=\$(basename \"\$f\")
      [ -f \"/markers/\$base\" ] && continue
      mc cp \"\$f\" \"redi/${BUCKET}/\$base\" && touch \"/markers/\$base\"
    done
  "

log_info "WAL sync (${ROLE}@$(hostname -s)): $(ls -1 "${MARKER_DIR}" 2>/dev/null | wc -l | tr -d ' ') files tracked"
