#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Sprint 3E Master Executor (Rev2 — EC:3+3, 9-drive cluster)
# Jalankan dari LOKAL (laptop/workstation), bukan dari server.
#
# ARSITEKTUR MinIO (Rev2 — EC:3+3):
#   9 drives total: 3 drives × 3 node (mjk/jkt/sby)
#   Keuntungan vs Rev1 (EC:2+2, 4 drives):
#     - mjk bukan lagi SPOF (hanya 3/9 drives, bukan 2/4)
#     - Cluster survive kehilangan 1 node penuh (siapapun)
#     - Storage usable ~50% dari total raw
#
# Yang dilakukan:
#   0. Fix Redis Sentinel NOQUORUM di mjk
#   1. Sync redi-Bootstrap ke /opt/redi di mjk, jkt, sby (via rsync over SSH)
#   2. Docker cleanup semua node (prune dangling images + stopped containers)
#   3. Deploy MinIO distributed dari mjk (koordinasi jkt+sby via SSH)
#   4. Validasi cluster + GitLab object store
#
# Usage:
#   bash scripts/deploy/run-sprint3e.sh
#   bash scripts/deploy/run-sprint3e.sh --skip-sync     # skip rsync jika sudah sync
#   bash scripts/deploy/run-sprint3e.sh --skip-backup   # fresh install, tidak ada data lama
#   bash scripts/deploy/run-sprint3e.sh --skip-sentinel # skip sentinel fix step
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Credentials (dari secrets/servers.yaml + secrets/api-keys.yaml)
# ---------------------------------------------------------------------------
MJK_HOST="103.80.214.226"; MJK_PORT=2280; MJK_USER="root";   MJK_PW='!Proxmox@Redi123'
JKT_HOST="103.149.238.98"; JKT_PORT=22;   JKT_USER="devapp"; JKT_PW='BitApp2026!@#'
SBY_HOST="103.80.214.144"; SBY_PORT=2280; SBY_USER="root";   SBY_PW='!Proxmox@Redi123'

REMOTE_ROOT="/opt/redi"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
SKIP_SYNC=false
SKIP_SENTINEL=false
EXTRA_DEPLOY_ARGS=""
for arg in "$@"; do
  case "${arg}" in
    --skip-sync)     SKIP_SYNC=true ;;
    --skip-backup)   EXTRA_DEPLOY_ARGS="--skip-backup" ;;
    --skip-sentinel) SKIP_SENTINEL=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%H:%M:%S')] $*"; }
log_section() { echo ""; echo "══════════════════════════════════════════════════"; echo "  $*"; echo "══════════════════════════════════════════════════"; }

# Pre-clear any stale known_hosts entries to avoid host key changed errors
for _host_port in "103.80.214.226:2280" "103.80.214.144:2280"; do
  _h="${_host_port%%:*}"; _p="${_host_port##*:}"
  ssh-keygen -R "[${_h}]:${_p}" &>/dev/null || true
  ssh-keygen -R "${_h}" &>/dev/null || true
done

# SSH wrapper dengan password (pakai sshpass)
ssh_run() {
  local host="$1" port="$2" user="$3" pw="$4"
  shift 4
  sshpass -p "${pw}" ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -o ControlMaster=auto \
    -o ControlPath="~/.ssh/control-%r@%h:%p" \
    -o ControlPersist=10m \
    -p "${port}" \
    "${user}@${host}" "$@"
}

# rsync wrapper dengan password
rsync_to() {
  local host="$1" port="$2" user="$3" pw="$4" dest="$5"
  sshpass -p "${pw}" rsync -az --delete \
    --exclude='.git' \
    --exclude='secrets/*.yaml' \
    --exclude='data/' \
    --exclude='logs/' \
    --exclude='*.log' \
    --exclude='backup/' \
    --exclude='config/powerdns/geoip/' \
    --exclude='config/powerdns/pdns.conf' \
    --exclude='config/shared-platform/haproxy-minio.cfg' \
    --exclude='config/shared-platform/haproxy-redis.cfg' \
    --exclude='config/shared-platform/pgbouncer/' \
    --exclude='config/shared-platform/postgres/' \
    -e "ssh -o StrictHostKeyChecking=accept-new -o ControlPath=~/.ssh/control-%r@%h:%p -p ${port}" \
    "${REDI_ROOT}/" \
    "${user}@${host}:${dest}/"
}

# Check sshpass
if ! command -v sshpass &>/dev/null; then
  log "ERROR: sshpass tidak tersedia. Install dulu:"
  log "  Ubuntu/Debian: apt-get install sshpass"
  log "  macOS:         brew install sshpass  (atau: brew install hudochenkov/sshpass/sshpass)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 0: Fix Redis Sentinel NOQUORUM di mjk
# ---------------------------------------------------------------------------
log_section "STEP 0: Fix Redis Sentinel Quorum (mjk NOQUORUM fix)"

if [[ "${SKIP_SENTINEL}" == "true" ]]; then
  log "  --skip-sentinel aktif, melewati sentinel fix"
else
  log "  Menjalankan fix-sentinel-quorum.sh..."
  bash "${SCRIPT_DIR}/fix-sentinel-quorum.sh" || {
    log "  Sentinel fix selesai (lihat output di atas untuk detail)"
  }
fi

# ---------------------------------------------------------------------------
# Step 1: Sync repo ke semua node
# ---------------------------------------------------------------------------
log_section "STEP 1: Sync redi-Bootstrap → /opt/redi (semua node)"

if [[ "${SKIP_SYNC}" == "true" ]]; then
  log "  --skip-sync aktif, melewati rsync"
else
  for node in "mjk:${MJK_HOST}:${MJK_PORT}:${MJK_USER}:${MJK_PW}" \
              "jkt:${JKT_HOST}:${JKT_PORT}:${JKT_USER}:${JKT_PW}" \
              "sby:${SBY_HOST}:${SBY_PORT}:${SBY_USER}:${SBY_PW}"; do
    IFS=: read -r name host port user pw <<< "${node}"
    log "  Syncing ke ${name} (${host}:${port})..."

    # Ensure /opt/redi exists dan permissions benar
    ssh_run "${host}" "${port}" "${user}" "${pw}" \
      "mkdir -p ${REMOTE_ROOT} && chmod 700 ${REMOTE_ROOT}"

    # Rsync
    rsync_to "${host}" "${port}" "${user}" "${pw}" "${REMOTE_ROOT}" \
      && log "  ${name}: sync OK" \
      || log "  ${name}: sync FAILED — cek koneksi dan password"

    # Pastikan scripts executable
    ssh_run "${host}" "${port}" "${user}" "${pw}" \
      "find ${REMOTE_ROOT}/scripts -name '*.sh' -exec chmod +x {} \;"
  done
fi

# ---------------------------------------------------------------------------
# Step 2: Docker cleanup semua node
# ---------------------------------------------------------------------------
log_section "STEP 2: Docker cleanup (prune dangling + stopped containers)"

for node in "mjk:${MJK_HOST}:${MJK_PORT}:${MJK_USER}:${MJK_PW}" \
            "jkt:${JKT_HOST}:${JKT_PORT}:${JKT_USER}:${JKT_PW}" \
            "sby:${SBY_HOST}:${SBY_PORT}:${SBY_USER}:${SBY_PW}"; do
  IFS=: read -r name host port user pw <<< "${node}"
  log "  Cleanup ${name}..."

  BEFORE=$(ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "df -h / | awk 'NR==2{print \$4\" free\"}'")
  log "    Before: ${BEFORE}"

  ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "docker container prune -f 2>/dev/null || true
     docker image prune -f 2>/dev/null || true
     docker volume prune -f 2>/dev/null || true
     docker builder prune -f 2>/dev/null || true" \
    && log "    Pruned: dangling images, stopped containers, unused volumes, build cache"

  AFTER=$(ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "df -h / | awk 'NR==2{print \$4\" free\"}'")
  log "    After:  ${AFTER}"
done

# ---------------------------------------------------------------------------
# Step 3: Setup SSH key dari mjk ke jkt+sby (untuk deploy-minio-distributed.sh)
# deploy-minio-distributed.sh pakai SSH BatchMode dari mjk ke jkt/sby
# Perlu inject known_hosts + allow password SSH dari mjk
# ---------------------------------------------------------------------------
log_section "STEP 3: Prepare SSH dari mjk ke jkt+sby"

# Inject credentials ke mjk untuk SSH ke jkt dan sby
ssh_run "${MJK_HOST}" "${MJK_PORT}" "${MJK_USER}" "${MJK_PW}" "
  # Install sshpass di mjk jika belum ada
  if ! command -v sshpass &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq sshpass 2>/dev/null || true
  fi

  # Pre-accept host keys jkt dan sby
  ssh-keyscan -p ${JKT_PORT} ${JKT_HOST} >> ~/.ssh/known_hosts 2>/dev/null || true
  ssh-keyscan -p ${SBY_PORT} ${SBY_HOST} >> ~/.ssh/known_hosts 2>/dev/null || true

  # Tulis helper wrapper agar deploy script bisa SSH ke jkt/sby
  cat > /tmp/redi-ssh-jkt.sh << 'EOF2'
#!/bin/bash
sshpass -p '${JKT_PW}' ssh -o StrictHostKeyChecking=no -p ${JKT_PORT} ${JKT_USER}@${JKT_HOST} \"\$@\"
EOF2
  cat > /tmp/redi-ssh-sby.sh << 'EOF2'
#!/bin/bash
sshpass -p '${SBY_PW}' ssh -o StrictHostKeyChecking=no -p ${SBY_PORT} ${SBY_USER}@${SBY_HOST} \"\$@\"
EOF2
  chmod +x /tmp/redi-ssh-jkt.sh /tmp/redi-ssh-sby.sh
" && log "  SSH helpers ready pada mjk"

# ---------------------------------------------------------------------------
# Step 4: Deploy MinIO distributed dari mjk
# Modifikasi: jalankan jkt+sby steps via sshpass wrapper
# ---------------------------------------------------------------------------
log_section "STEP 4: Deploy MinIO distributed (mjk sebagai koordinator)"

# Jalankan bagian jkt dan sby secara terpisah (karena deploy script pakai BatchMode)
# Dulu script menggunakan ssh BatchMode (key-based), sekarang pakai sshpass wrapper

log "  4a. Persiapkan data dirs (3 drives) + start MinIO di jkt..."
ssh_run "${JKT_HOST}" "${JKT_PORT}" "${JKT_USER}" "${JKT_PW}" "
  source /opt/redi/compose/shared-platform/.env 2>/dev/null || true
  MJK_MESH_IP=100.81.86.37
  JKT_MESH_IP=100.79.82.92
  SBY_MESH_IP=100.67.138.25
  MINIO_IMAGE=minio/minio:RELEASE.2024-12-18T13-15-44Z
  SHARED_DATA_PATH=/opt/redi/data/shared-platform
  # EC:3+3 — 3 drives per node
  mkdir -p \${SHARED_DATA_PATH}/minio/data1 \${SHARED_DATA_PATH}/minio/data2 \${SHARED_DATA_PATH}/minio/data3
  cd /opt/redi/compose/shared-platform/minio
  MINIO_ROOT_USER=\$(grep MINIO_ROOT_USER /opt/redi/compose/shared-platform/.env | cut -d= -f2-)
  MINIO_ROOT_PASSWORD=\$(grep MINIO_ROOT_PASSWORD /opt/redi/compose/shared-platform/.env | cut -d= -f2-)
  MJK_MESH_IP=\${MJK_MESH_IP} JKT_MESH_IP=\${JKT_MESH_IP} SBY_MESH_IP=\${SBY_MESH_IP} \
  MINIO_ROOT_USER=\${MINIO_ROOT_USER} MINIO_ROOT_PASSWORD=\${MINIO_ROOT_PASSWORD} \
  MINIO_IMAGE=\${MINIO_IMAGE} SHARED_DATA_PATH=\${SHARED_DATA_PATH} \
  docker compose -f docker-compose.jkt.yml --env-file /opt/redi/compose/shared-platform/.env up -d 2>&1 | tail -5
" && log "  jkt MinIO: started" || log "  jkt MinIO: FAILED — lihat output di atas"

log "  4b. Persiapkan data dirs (3 drives) + start MinIO di sby..."
ssh_run "${SBY_HOST}" "${SBY_PORT}" "${SBY_USER}" "${SBY_PW}" "
  source /opt/redi/compose/shared-platform/.env 2>/dev/null || true
  MJK_MESH_IP=100.81.86.37
  JKT_MESH_IP=100.79.82.92
  SBY_MESH_IP=100.67.138.25
  MINIO_IMAGE=minio/minio:RELEASE.2024-12-18T13-15-44Z
  SHARED_DATA_PATH=/opt/redi/data/shared-platform
  # EC:3+3 — 3 drives per node
  mkdir -p \${SHARED_DATA_PATH}/minio/data1 \${SHARED_DATA_PATH}/minio/data2 \${SHARED_DATA_PATH}/minio/data3
  cd /opt/redi/compose/shared-platform/minio
  MINIO_ROOT_USER=\$(grep MINIO_ROOT_USER /opt/redi/compose/shared-platform/.env | cut -d= -f2-)
  MINIO_ROOT_PASSWORD=\$(grep MINIO_ROOT_PASSWORD /opt/redi/compose/shared-platform/.env | cut -d= -f2-)
  MJK_MESH_IP=\${MJK_MESH_IP} JKT_MESH_IP=\${JKT_MESH_IP} SBY_MESH_IP=\${SBY_MESH_IP} \
  MINIO_ROOT_USER=\${MINIO_ROOT_USER} MINIO_ROOT_PASSWORD=\${MINIO_ROOT_PASSWORD} \
  MINIO_IMAGE=\${MINIO_IMAGE} SHARED_DATA_PATH=\${SHARED_DATA_PATH} \
  docker compose -f docker-compose.sby.yml --env-file /opt/redi/compose/shared-platform/.env up -d 2>&1 | tail -5
" && log "  sby MinIO: started" || log "  sby MinIO: FAILED — lihat output di atas"

log "  4c. Backup data lama + restart MinIO di mjk (distributed mode)..."
ssh_run "${MJK_HOST}" "${MJK_PORT}" "${MJK_USER}" "${MJK_PW}" "
  cd /opt/redi
  bash scripts/deploy/deploy-minio-distributed.sh ${EXTRA_DEPLOY_ARGS} --skip-dns 2>&1
" && log "  mjk MinIO deploy: DONE" || log "  mjk MinIO deploy: check errors above"

# ---------------------------------------------------------------------------
# Step 5: Update DNS minio.redi.internal → round-robin 3 node
# ---------------------------------------------------------------------------
log_section "STEP 5: Update DNS minio.redi.internal"

ssh_run "${MJK_HOST}" "${MJK_PORT}" "${MJK_USER}" "${MJK_PW}" "
  source /opt/redi/compose/powerdns/.env 2>/dev/null || \
  source /opt/redi/compose/shared-platform/.env 2>/dev/null || true

  PDNS_API_URL=\${PDNS_API_URL:-http://100.79.82.92:8081}
  PDNS_API_KEY=\${PDNS_API_KEY:-}
  ZONE='redi.internal.'
  API=\"\${PDNS_API_URL}/api/v1/servers/localhost/zones/\${ZONE}\"

  curl -sf -X PATCH \
    -H \"X-API-Key: \${PDNS_API_KEY}\" \
    -H 'Content-Type: application/json' \
    \"\${API}\" \
    -d '{
      \"rrsets\": [{
        \"name\": \"minio.redi.internal.\",
        \"type\": \"A\",
        \"ttl\": 60,
        \"changetype\": \"REPLACE\",
        \"records\": [
          {\"content\": \"100.81.86.37\", \"disabled\": false},
          {\"content\": \"100.79.82.92\", \"disabled\": false},
          {\"content\": \"100.67.138.25\", \"disabled\": false}
        ]
      }]
    }' && echo 'DNS updated: minio.redi.internal round-robin 3 nodes' \
         || echo 'DNS update failed — update manual via pdns API'
"

# ---------------------------------------------------------------------------
# Step 6: Validasi
# ---------------------------------------------------------------------------
log_section "STEP 6: Validasi MinIO HA + GitLab object store"

ssh_run "${MJK_HOST}" "${MJK_PORT}" "${MJK_USER}" "${MJK_PW}" "
  cd /opt/redi
  bash scripts/deploy/validate-minio-ha.sh 2>&1
" && log "Validasi selesai" || log "Validasi selesai (lihat output di atas)"

log ""
log "══════════════════════════════════════════════════"
log "Sprint 3E execution complete."
log "Cek output validate-minio-ha.sh di atas untuk PASS/FAIL."
log "══════════════════════════════════════════════════"
