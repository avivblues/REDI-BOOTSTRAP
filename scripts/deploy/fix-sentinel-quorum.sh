#!/usr/bin/env bash
# =============================================================================
# REDI — Fix Redis Sentinel Quorum (Sprint 3C Gap Fix)
#
# Masalah: mjk sentinel NOQUORUM — hanya 1/3 usable sentinel (diri sendiri)
#          mjk sentinel tidak bisa gossip ke jkt/sby karena host-network mode
#          tidak mengekspos port 26379 secara benar di Tailscale.
#
# Solusi:
#   1. Restart mjk sentinel agar reload sentinel.conf + announce-ip
#   2. Trigger SENTINEL RESET dari jkt (agar peer discovery diulang)
#   3. Trigger SENTINEL RESET dari sby
#   4. Verifikasi quorum dari semua 3 node
#
# Jalankan dari: lokal (laptop) — script ini SSH ke semua node
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------
MJK_HOST="103.80.214.226"; MJK_PORT=2280; MJK_USER="root";   MJK_PW='!Proxmox@Redi123'
JKT_HOST="103.149.238.98"; JKT_PORT=22;   JKT_USER="devapp"; JKT_PW='BitApp2026!@#'
SBY_HOST="103.80.214.144"; SBY_PORT=2280; SBY_USER="root";   SBY_PW='!Proxmox@Redi123'

REDIS_PASSWORD="XH9DaLjRd0QeI6JB"
MASTER_HOST="100.81.86.37"
MASTER_PORT=6379

log()         { echo "[$(date '+%H:%M:%S')] $*"; }
log_ok()      { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
log_warn()    { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
log_error()   { echo "[$(date '+%H:%M:%S')] ❌ $*"; }
log_section() { echo ""; echo "══════════════════════════════════════════════════"; echo "  $*"; echo "══════════════════════════════════════════════════"; }

ssh_run() {
  local host="$1" port="$2" user="$3" pw="$4"
  shift 4
  sshpass -p "${pw}" ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -p "${port}" \
    "${user}@${host}" "$@"
}

if ! command -v sshpass &>/dev/null; then
  log_error "sshpass tidak tersedia. Install: brew install hudochenkov/sshpass/sshpass"
  exit 1
fi

# ===========================================================================
# STEP 1: Cek status awal Redis Sentinel di semua node
# ===========================================================================
log_section "STEP 1: Status awal Sentinel sebelum fix"

for label_host_port_user_pw in \
    "mjk:${MJK_HOST}:${MJK_PORT}:${MJK_USER}:${MJK_PW}" \
    "jkt:${JKT_HOST}:${JKT_PORT}:${JKT_USER}:${JKT_PW}" \
    "sby:${SBY_HOST}:${SBY_PORT}:${SBY_USER}:${SBY_PW}"; do
  IFS=: read -r label host port user pw <<< "${label_host_port_user_pw}"
  log "  [${label}] Cek sentinel quorum..."
  ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "docker exec redi-redis-sentinel redis-cli -p 26379 sentinel ckquorum redi-master 2>&1 || echo 'sentinel not reachable'" \
    2>/dev/null || log_warn "  [${label}] SSH error atau sentinel tidak running"
done

# ===========================================================================
# STEP 2: Restart mjk sentinel (host-network mode) agar re-announce
# ===========================================================================
log_section "STEP 2: Restart mjk sentinel (host-sentinel profile)"

log "  [mjk] Stopping sentinel-host container..."
ssh_run "${MJK_HOST}" "${MJK_PORT}" "${MJK_USER}" "${MJK_PW}" \
  "docker restart redi-redis-sentinel 2>&1 | tail -3 || docker start redi-redis-sentinel 2>&1 | tail -3" \
  && log_ok "[mjk] Sentinel restarted" \
  || log_warn "[mjk] Sentinel restart failed — coba manual: docker restart redi-redis-sentinel"

log "  Waiting 8s for sentinel to reinitialize..."
sleep 8

# ===========================================================================
# STEP 3: SENTINEL RESET dari jkt dan sby (trigger peer rediscovery)
# ===========================================================================
log_section "STEP 3: SENTINEL RESET redi-master dari jkt dan sby"

log "  [jkt] Running SENTINEL RESET redi-master..."
ssh_run "${JKT_HOST}" "${JKT_PORT}" "${JKT_USER}" "${JKT_PW}" \
  "docker exec redi-redis-sentinel redis-cli -p 26379 sentinel reset redi-master 2>&1" \
  && log_ok "[jkt] SENTINEL RESET OK" \
  || log_warn "[jkt] SENTINEL RESET failed"

sleep 3

log "  [sby] Running SENTINEL RESET redi-master..."
ssh_run "${SBY_HOST}" "${SBY_PORT}" "${SBY_USER}" "${SBY_PW}" \
  "docker exec redi-redis-sentinel redis-cli -p 26379 sentinel reset redi-master 2>&1" \
  && log_ok "[sby] SENTINEL RESET OK" \
  || log_warn "[sby] SENTINEL RESET failed"

sleep 3

log "  [mjk] Running SENTINEL RESET redi-master dari mjk (host-network)..."
ssh_run "${MJK_HOST}" "${MJK_PORT}" "${MJK_USER}" "${MJK_PW}" \
  "docker exec redi-redis-sentinel redis-cli -p 26379 sentinel reset redi-master 2>&1" \
  && log_ok "[mjk] SENTINEL RESET OK" \
  || log_warn "[mjk] SENTINEL RESET failed"

log "  Waiting 15s for sentinel gossip to stabilize..."
sleep 15

# ===========================================================================
# STEP 4: Verifikasi quorum dari semua node + cek num-other-sentinels
# ===========================================================================
log_section "STEP 4: Verifikasi Quorum Post-Fix"

ALL_PASS=true

for label_host_port_user_pw in \
    "mjk:${MJK_HOST}:${MJK_PORT}:${MJK_USER}:${MJK_PW}" \
    "jkt:${JKT_HOST}:${JKT_PORT}:${JKT_USER}:${JKT_PW}" \
    "sby:${SBY_HOST}:${SBY_PORT}:${SBY_USER}:${SBY_PW}"; do
  IFS=: read -r label host port user pw <<< "${label_host_port_user_pw}"

  log "  [${label}] Checking quorum..."
  RESULT=$(ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "docker exec redi-redis-sentinel redis-cli -p 26379 -a '${REDIS_PASSWORD}' sentinel ckquorum redi-master 2>&1" \
    2>/dev/null || echo "SSH_ERROR")

  if echo "${RESULT}" | grep -q "OK "; then
    USABLE=$(echo "${RESULT}" | grep -oE '[0-9]+ usable' | head -1)
    log_ok "[${label}] Quorum OK — ${USABLE}"
  else
    log_warn "[${label}] Quorum NOT OK: ${RESULT}"
    ALL_PASS=false
  fi

  # Cek berapa sentinel yang diketahui
  log "  [${label}] num-other-sentinels check..."
  ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "docker exec redi-redis-sentinel redis-cli -p 26379 -a '${REDIS_PASSWORD}' sentinel sentinels redi-master 2>&1 | grep -E 'name|ip|port' | head -20" \
    2>/dev/null || true
  echo ""
done

# ===========================================================================
# STEP 5: Cek master info dari semua sentinel
# ===========================================================================
log_section "STEP 5: Verifikasi Master Info"

for label_host_port_user_pw in \
    "mjk:${MJK_HOST}:${MJK_PORT}:${MJK_USER}:${MJK_PW}" \
    "jkt:${JKT_HOST}:${JKT_PORT}:${JKT_USER}:${JKT_PW}" \
    "sby:${SBY_HOST}:${SBY_PORT}:${SBY_USER}:${SBY_PW}"; do
  IFS=: read -r label host port user pw <<< "${label_host_port_user_pw}"
  log "  [${label}] Master info:"
  ssh_run "${host}" "${port}" "${user}" "${pw}" \
    "docker exec redi-redis-sentinel redis-cli -p 26379 -a '${REDIS_PASSWORD}' sentinel master redi-master 2>&1 | grep -E '^(name|ip|port|num-slaves|num-other-sentinels|quorum|flags)$' -A1 | head -30" \
    2>/dev/null | sed 's/^/    /' || true
  echo ""
done

# ===========================================================================
# STEP 6: Summary
# ===========================================================================
log_section "STEP 6: Summary"

if [[ "${ALL_PASS}" == "true" ]]; then
  log_ok "Sentinel quorum fix: PASS — semua 3 sentinel melaporkan quorum OK"
  log "    mjk sentinel sekarang bisa berpartisipasi dalam quorum"
else
  log_warn "Sentinel quorum fix: PARTIAL"
  log "    Jika mjk masih NOQUORUM setelah restart+reset, ini adalah"
  log "    limitasi host-network mode: sentinel mjk tidak expose port 26379"
  log "    ke Tailscale secara langsung. Workaround:"
  log "    1. Tambahkan 'sentinel announce-ip 100.81.86.37' ke /data/sentinel.conf"
  log "    2. Pastikan port 26379 tidak diblok firewall di mjk"
  log "    3. Cek: ss -tlnp | grep 26379  (di mjk harus ada 0.0.0.0:26379)"
  log ""
  log "    CATATAN: 2/3 quorum (jkt+sby) sudah CUKUP untuk failover otomatis."
  log "    mjk isolated dari gossip adalah known limitation; tidak menghalangi HA."
fi
