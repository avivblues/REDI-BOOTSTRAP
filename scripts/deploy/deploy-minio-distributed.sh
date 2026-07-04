#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy MinIO Distributed 3-node cluster (Sprint 3E Rev2)
# Run on redi-mjk-01 as root. Requires SSH access to jkt and sby.
#
# ARSITEKTUR Rev2 (EC:3+3, 9-drive cluster):
#   mjk: /data1 + /data2 + /data3  (3 drives)
#   jkt: /data1 + /data2 + /data3  (3 drives)
#   sby: /data1 + /data2 + /data3  (3 drives)
#   Total: 9 drives, EC:3+3, mjk BUKAN SPOF (hanya 3/9 drives)
#   Cluster survive kehilangan 1 node penuh (siapapun)
#   Storage usable: ~50% dari total raw
#
# Steps:
#   PRE-1  CTO gate check (storage on jkt+sby)
#   PRE-2  Preflight (connectivity, storage space)
#   1.     Backup all MinIO buckets to local filesystem via mc mirror
#   2.     Stop single-node MinIO on mjk
#   3.     Prepare data dirs (3 × 3) on jkt + sby (SSH)
#   4.     Start distributed cluster on jkt+sby (SSH), then mjk
#   5.     Wait for cluster quorum
#   6.     Create buckets
#   7.     Restore data via mc mirror (filesystem → cluster)
#   8.     Update minio.redi.internal DNS → round-robin A all 3 nodes
#   9.     Smoke test
#
# Idempotent: if cluster already running, skips steps 1-4.
# Skip backup with --skip-backup (for fresh installs with no data)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
SKIP_BACKUP=false
SKIP_DNS_UPDATE=false
for arg in "$@"; do
  case "${arg}" in
    --skip-backup)  SKIP_BACKUP=true  ;;
    --skip-dns)     SKIP_DNS_UPDATE=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ENV_FILE="${REDI_ROOT}/compose/shared-platform/.env"
[[ -f "${ENV_FILE}" ]] || { log_error "Missing ${ENV_FILE}"; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

MJK="${MJK_MESH_IP}"   # 100.81.86.37
JKT="${JKT_MESH_IP}"   # 100.79.82.92
SBY="${SBY_MESH_IP}"   # 100.67.138.25

COMPOSE_DIR="${REDI_ROOT}/compose/shared-platform/minio"
DATA_BASE="${SHARED_DATA_PATH:-/opt/redi/data/shared-platform}/minio"
BACKUP_DIR="${REDI_ROOT}/data/minio-migration-backup"
MC="docker run --rm --network host -v /root/.mc:/root/.mc -v ${BACKUP_DIR}:/backup -v /tmp:/tmp minio/mc:latest"

BUCKETS=(
  gitlab-artifacts
  gitlab-mr-diffs
  gitlab-lfs
  gitlab-uploads
  gitlab-packages
  gitlab-dep-proxy
  gitlab-terraform
  gitlab-ci-secure-files
  redi-pg-wal
)

# ---------------------------------------------------------------------------
# 3E.1 — Storage preflight
# VPS spec: 200GB per node — lebih dari cukup untuk MinIO data1.
# MinIO data tumbuh sesuai pemakaian GitLab (LFS, artifacts, registry).
# Threshold warning: 5GB (praktis tidak pernah tercapai di awal).
# ---------------------------------------------------------------------------
MIN_FREE_GB=5   # warn jika sisa < 5GB (dari 200GB total)

log_info "====== 3E.1 Storage Preflight (VPS 200GB, EC:3+3) ======"

# Audit disk pada semua node sebelum deploy
log_info "Disk state sebelum deploy (3 drives per node):"

# Check local (mjk) — 3 drives
for d in data1 data2 data3; do
  mkdir -p "${DATA_BASE}/${d}"
  AVAIL=$(df -BG "${DATA_BASE}/${d}" | awk 'NR==2{gsub(/G/,"",$4); print $4}')
  log_info "  mjk ${d}: ${AVAIL}GB free"
  [[ "${AVAIL}" -lt "${MIN_FREE_GB}" ]] && log_warn "  mjk ${d}: LOW DISK (< ${MIN_FREE_GB}GB) — jalankan cleanup-docker-nodes.sh --clean"
done

# Check jkt + sby via SSH
for node_ip in "${JKT}" "${SBY}"; do
  NODE_TAG="$([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby)"
  if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${node_ip}" true 2>/dev/null; then
    REMOTE_AVAIL=$(ssh "root@${node_ip}" \
      "mkdir -p '${DATA_BASE}/data1'; df -BG '${DATA_BASE}/data1' | awk 'NR==2{gsub(/G/,\"\",\$4); print \$4}'" 2>/dev/null || echo "0")
    log_info "  ${NODE_TAG} data1: ${REMOTE_AVAIL}GB free"
    if [[ "${REMOTE_AVAIL:-0}" -lt "${MIN_FREE_GB}" ]]; then
      log_warn "  ${NODE_TAG}: sisa < ${MIN_FREE_GB}GB — jalankan cleanup-docker-nodes.sh --clean lalu retry"
      log_warn "  Tip: docker image prune -a -f untuk hapus images yang tidak dipakai"
    fi
  else
    log_warn "  ${NODE_TAG}: SSH tidak terjangkau (${node_ip}) — pastikan Tailscale aktif"
    log_warn "  Setelah SSH tersedia, script bisa dilanjutkan"
  fi
done

# ---------------------------------------------------------------------------
# PRE-2 — Connectivity
# ---------------------------------------------------------------------------
log_info ""
log_info "====== Preflight: Connectivity ======"
for node_ip in "${JKT}" "${SBY}"; do
  if nc -z -w5 "${node_ip}" 9000 2>/dev/null; then
    log_info "  ${node_ip}:9000 reachable"
  else
    log_info "  ${node_ip}:9000 not yet reachable (MinIO not running — expected for fresh deploy)"
  fi
done

# ---------------------------------------------------------------------------
# Step 1 — Backup existing data via mc mirror
# ---------------------------------------------------------------------------
CLUSTER_RUNNING=false
if curl -sf "http://${MJK}:9000/minio/health/live" &>/dev/null; then
  CURRENT_MODE=$(docker inspect redi-minio 2>/dev/null \
    | python3 -c "import sys,json; cmd=' '.join(json.load(sys.stdin)[0]['Config']['Cmd']); print('distributed' if 'http://' in cmd else 'single')" \
    || echo "unknown")

  if [[ "${CURRENT_MODE}" == "distributed" ]]; then
    log_info "MinIO is already running in distributed mode — skipping migration"
    CLUSTER_RUNNING=true
    SKIP_BACKUP=true
  else
    log_info "MinIO running in single-node mode — will migrate"
  fi
fi

if [[ "${SKIP_BACKUP}" == "false" ]] && [[ "${CLUSTER_RUNNING}" == "false" ]]; then
  log_info ""
  log_info "====== Step 1: Backup via mc mirror ======"
  mkdir -p "${BACKUP_DIR}"
  log_info "Backup dir: ${BACKUP_DIR}"

  # Configure mc alias for existing single-node
  ${MC} alias set redi-old "http://${MJK}:9000" \
    "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" --api S3v4 || true

  for bucket in "${BUCKETS[@]}"; do
    BUCKET_EXISTS=$(${MC} ls redi-old/"${bucket}" &>/dev/null && echo "yes" || echo "no")
    if [[ "${BUCKET_EXISTS}" == "yes" ]]; then
      log_info "  Mirroring redi-old/${bucket} → /backup/${bucket}/"
      ${MC} mirror --preserve "redi-old/${bucket}" "/backup/${bucket}/" \
        && log_info "    → Done" \
        || log_warn "    → Mirror failed for ${bucket} (may be empty)"
    else
      log_info "  Skipping ${bucket} (bucket does not exist)"
    fi
  done

  BACKUP_SIZE=$(du -sh "${BACKUP_DIR}" 2>/dev/null | awk '{print $1}' || echo "0")
  log_info "Backup complete: ${BACKUP_SIZE} in ${BACKUP_DIR}"
fi

# ---------------------------------------------------------------------------
# Step 2 — Stop single-node MinIO on mjk
# ---------------------------------------------------------------------------
if [[ "${CLUSTER_RUNNING}" == "false" ]]; then
  log_info ""
  log_info "====== Step 2: Stop single-node MinIO ======"
  cd "${COMPOSE_DIR}"
  docker stop redi-minio 2>/dev/null && log_info "  redi-minio stopped" || log_info "  redi-minio was not running"
  docker rm redi-minio 2>/dev/null || true

  # Clear data dirs for clean distributed start
  # IMPORTANT: mjk /data1 and /data2 are REUSED by distributed — do NOT wipe
  # MinIO distributed will format/reuse existing dirs
  log_info "  Retaining ${DATA_BASE}/data1 and data2 (cluster will reuse)"
fi

# ---------------------------------------------------------------------------
# Step 3 — Prepare data dirs on jkt + sby
# ---------------------------------------------------------------------------
if [[ "${CLUSTER_RUNNING}" == "false" ]]; then
  log_info ""
  log_info "====== Step 3: Prepare remote data dirs (3 drives each) ======"
  for node_ip in "${JKT}" "${SBY}"; do
    NODE_TAG="$([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby)"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${node_ip}" true 2>/dev/null; then
      log_info "  ${NODE_TAG}: creating ${DATA_BASE}/data1, data2, data3"
      ssh "root@${node_ip}" "mkdir -p '${DATA_BASE}/data1' '${DATA_BASE}/data2' '${DATA_BASE}/data3'" \
        && log_info "  ${NODE_TAG}: data dirs ready (3 drives)" \
        || log_warn "  ${NODE_TAG}: could not create data dirs — check SSH access"
    else
      log_warn "  ${NODE_TAG}: SSH not reachable — deploy MinIO manually on ${node_ip}"
      log_warn "    Run on ${NODE_TAG}: bash ${REDI_ROOT}/scripts/deploy/deploy-minio-distributed.sh --node-only"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Step 4 — Start distributed cluster
# ---------------------------------------------------------------------------
if [[ "${CLUSTER_RUNNING}" == "false" ]]; then
  log_info ""
  log_info "====== Step 4: Start distributed cluster ======"

  # Start jkt and sby first (they'll wait for mjk)
  for node_ip in "${JKT}" "${SBY}"; do
    NODE_TAG="$([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby)"
    COMPOSE_FILE="docker-compose.${NODE_TAG}.yml"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${node_ip}" true 2>/dev/null; then
      log_info "  Starting MinIO on ${NODE_TAG} (${node_ip})..."
      ssh "root@${node_ip}" "
        cd '${REDI_ROOT}/compose/shared-platform/minio'
        export MJK_MESH_IP=${MJK} JKT_MESH_IP=${JKT} SBY_MESH_IP=${SBY}
        export MINIO_ROOT_USER='${MINIO_ROOT_USER}' MINIO_ROOT_PASSWORD='${MINIO_ROOT_PASSWORD}'
        export MINIO_IMAGE='${MINIO_IMAGE}' SHARED_DATA_PATH='${SHARED_DATA_PATH}'
        mkdir -p '${SHARED_DATA_PATH}/minio/data1'
        docker compose -f ${COMPOSE_FILE} --env-file '${ENV_FILE}' up -d
      " && log_info "  ${NODE_TAG}: MinIO started" || log_warn "  ${NODE_TAG}: start failed — check SSH/Docker"
    else
      log_warn "  ${NODE_TAG}: SSH not reachable — start MinIO manually"
    fi
  done

  # Start mjk last
  log_info "  Starting MinIO on mjk (local)..."
  cd "${COMPOSE_DIR}"
  docker compose -f docker-compose.mjk.yml --env-file "${ENV_FILE}" up -d
  log_info "  mjk: MinIO started"
fi

# ---------------------------------------------------------------------------
# Step 5 — Wait for cluster quorum
# ---------------------------------------------------------------------------
log_info ""
log_info "====== Step 5: Waiting for cluster quorum ======"
log_info "  MinIO requires all nodes to form quorum (up to 120s)..."

TIMEOUT=120
ELAPSED=0
until curl -sf "http://${MJK}:9000/minio/health/cluster" &>/dev/null || [[ ${ELAPSED} -ge ${TIMEOUT} ]]; do
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  log_info "  Waiting... ${ELAPSED}s"
done

if curl -sf "http://${MJK}:9000/minio/health/cluster" &>/dev/null; then
  log_info "  Cluster healthy (responded in ${ELAPSED}s)"
elif curl -sf "http://${MJK}:9000/minio/health/live" &>/dev/null; then
  log_warn "  Live endpoint OK but /cluster not ready — node(s) may still be joining"
else
  log_error "  Cluster not responding after ${TIMEOUT}s"
  log_error "  Check: docker logs redi-minio --tail 50"
  log_error "  Verify jkt + sby nodes are up: curl http://${JKT}:9000/minio/health/live"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 6 — Create buckets
# ---------------------------------------------------------------------------
log_info ""
log_info "====== Step 6: Create buckets ======"
${MC} alias set redi-new "http://${MJK}:9000" \
  "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" --api S3v4

for bucket in "${BUCKETS[@]}"; do
  ${MC} mb -p "redi-new/${bucket}" 2>/dev/null \
    && log_info "  Created: ${bucket}" \
    || log_info "  Exists:  ${bucket}"
done

# ---------------------------------------------------------------------------
# Step 7 — Restore from backup
# ---------------------------------------------------------------------------
if [[ "${SKIP_BACKUP}" == "false" ]] && [[ -d "${BACKUP_DIR}" ]]; then
  log_info ""
  log_info "====== Step 7: Restore from backup ======"

  for bucket in "${BUCKETS[@]}"; do
    if [[ -d "${BACKUP_DIR}/${bucket}" ]]; then
      OBJ_COUNT=$(find "${BACKUP_DIR}/${bucket}" -type f 2>/dev/null | wc -l)
      if [[ "${OBJ_COUNT}" -gt 0 ]]; then
        log_info "  Restoring ${bucket} (${OBJ_COUNT} objects)..."
        ${MC} mirror --preserve \
          "/backup/${bucket}/" \
          "redi-new/${bucket}" \
          && log_info "    → Done" \
          || log_warn "    → Partial restore — re-run: mc mirror /backup/${bucket}/ redi-new/${bucket}"
      else
        log_info "  ${bucket}: empty backup — skipping"
      fi
    fi
  done
fi

# ---------------------------------------------------------------------------
# Step 8 — Update minio.redi.internal DNS (round-robin all 3 nodes)
# ---------------------------------------------------------------------------
if [[ "${SKIP_DNS_UPDATE}" == "false" ]]; then
  log_info ""
  log_info "====== Step 8: Update minio.redi.internal DNS ======"

  PDNS_ENV="${REDI_ROOT}/compose/powerdns/.env"
  if [[ -f "${PDNS_ENV}" ]]; then
    # shellcheck source=/dev/null
    source "${PDNS_ENV}"
    ZONE="redi.internal."
    API="${PDNS_API_URL}/api/v1/servers/localhost/zones/${ZONE}"

    # Round-robin A records for all 3 nodes (any node serves the full API)
    curl -sf -X PATCH \
      -H "X-API-Key: ${PDNS_API_KEY}" \
      -H "Content-Type: application/json" \
      "${API}" \
      -d "{
        \"rrsets\": [{
          \"name\": \"minio.redi.internal.\",
          \"type\": \"A\",
          \"ttl\": 60,
          \"changetype\": \"REPLACE\",
          \"records\": [
            {\"content\": \"${MJK}\", \"disabled\": false},
            {\"content\": \"${JKT}\", \"disabled\": false},
            {\"content\": \"${SBY}\", \"disabled\": false}
          ]
        }]
      }" && log_info "  minio.redi.internal → round-robin ${MJK}, ${JKT}, ${SBY}" \
         || log_warn "  DNS update failed — minio.redi.internal still points to ${MJK} (single A)"
  else
    log_warn "  PowerDNS env not found — update minio.redi.internal manually"
  fi
fi

# ---------------------------------------------------------------------------
# Step 9 — Smoke test
# ---------------------------------------------------------------------------
log_info ""
log_info "====== Step 9: Smoke test ======"

${MC} admin info redi-new 2>/dev/null | head -30 || log_warn "mc admin info failed"

log_info ""
log_info "MinIO distributed deployment complete."
log_info "Run: bash ${REDI_ROOT}/scripts/deploy/validate-minio-ha.sh"
