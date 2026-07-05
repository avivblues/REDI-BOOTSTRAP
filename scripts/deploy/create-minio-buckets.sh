#!/usr/bin/env bash
# =============================================================================
# REDI — Create MinIO buckets for GitLab object storage
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
# shellcheck source=/dev/null
source "${ENV_FILE}"

ENDPOINT="http://${MJK_MESH_IP}:9000"
BUCKETS=(
  gitlab-artifacts gitlab-mr-diffs gitlab-lfs gitlab-uploads
  gitlab-packages gitlab-dep-proxy gitlab-terraform gitlab-ci-secure-files
  gitlab-registry
  redi-pg-wal
)

docker run --rm --network host --entrypoint /bin/sh minio/mc:latest -c "
  mc alias set redi ${ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
  for b in ${BUCKETS[*]}; do mc mb -p redi/\$b || true; done
  mc ls redi
"
log_info "MinIO buckets ready"
