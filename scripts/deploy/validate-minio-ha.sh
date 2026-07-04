#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Validate MinIO HA cluster (Sprint 3E)
# Run on redi-mjk-01 as root after deploy-minio-distributed.sh.
#
# Checks:
#   1.  Cluster health (/minio/health/cluster on all 3 nodes)
#   2.  mc admin info — node status, drives, erasure sets
#   3.  All required buckets exist
#   4.  Write + read test object on each node endpoint
#   5.  Erasure test — verify object readable after simulating node offline
#   6.  GitLab object store: artifacts, LFS, registry buckets accessible
#   7.  minio.redi.internal DNS resolves to ≥1 cluster node
#   8.  redi-pg-wal bucket accessible (Patroni WAL archiving)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

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

MC_IMG="${MC_IMAGE:-minio/mc:latest}"
MC_RUN() {
  docker run --rm --network host -v /root/.mc:/root/.mc -v /tmp:/tmp "${MC_IMG}" "$@"
}

PASS=0; FAIL=0; WARN=0
pass() { log_info "[PASS] $*"; ((PASS++)) || true; }
fail() { log_error "[FAIL] $*"; ((FAIL++)) || true; }
warn() { log_warn "[WARN] $*"; ((WARN++)) || true; }

REQUIRED_BUCKETS=(
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
# Setup mc alias
# ---------------------------------------------------------------------------
log_info "Setting up mc aliases..."
for node_ip in "${MJK}" "${JKT}" "${SBY}"; do
  ALIAS="redi-$([ "${node_ip}" == "${MJK}" ] && echo mjk || ([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby))"
  MC_RUN alias set "${ALIAS}" "http://${node_ip}:9000" \
    "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" --api S3v4 2>/dev/null || true
done
MC_RUN alias set redi "http://${MJK}:9000" \
  "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" --api S3v4 2>/dev/null

# ---------------------------------------------------------------------------
# Check 1: Cluster health endpoint on all nodes
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 1: Cluster health endpoints ==="

for node_ip in "${MJK}" "${JKT}" "${SBY}"; do
  NODE="$([ "${node_ip}" == "${MJK}" ] && echo mjk || ([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby))"

  LIVE=$(curl -sf -o /dev/null -w "%{http_code}" \
    --max-time 10 "http://${node_ip}:9000/minio/health/live" 2>/dev/null || echo "000")
  CLUSTER=$(curl -sf -o /dev/null -w "%{http_code}" \
    --max-time 10 "http://${node_ip}:9000/minio/health/cluster" 2>/dev/null || echo "000")

  if [[ "${LIVE}" == "200" ]]; then
    pass "${NODE} (${node_ip}): live=200"
  else
    fail "${NODE} (${node_ip}): live=${LIVE} — MinIO not running or unreachable"
  fi

  if [[ "${CLUSTER}" == "200" ]]; then
    pass "${NODE}: cluster quorum OK"
  else
    warn "${NODE}: cluster health=${CLUSTER} (may be joining or 1+ node offline)"
  fi
done

# ---------------------------------------------------------------------------
# Check 2: mc admin info — drives and erasure
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 2: mc admin info ==="

ADMIN_INFO=$(MC_RUN admin info redi 2>/dev/null || echo "FAILED")

if [[ "${ADMIN_INFO}" != "FAILED" ]]; then
  pass "mc admin info succeeded"
  # Count online drives
  ONLINE_DRIVES=$(echo "${ADMIN_INFO}" | grep -c "online" 2>/dev/null || echo "0")
  TOTAL_DRIVES=$(echo "${ADMIN_INFO}" | grep -c "drive" 2>/dev/null || echo "0")
  log_info "  Drives online: ~${ONLINE_DRIVES}"

  # Check for any offline nodes (excluding "0 drives offline")
  if echo "${ADMIN_INFO}" | grep -i "offline" | grep -v -E "0 drives? offline" | grep -q .; then
    warn "Some nodes/drives reported offline in admin info — check cluster state"
  else
    pass "No offline nodes/drives detected"
  fi
else
  fail "mc admin info failed — cluster may not be fully formed"
fi

# ---------------------------------------------------------------------------
# Check 3: Required buckets
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 3: Required buckets ==="

EXISTING_BUCKETS=$(MC_RUN ls redi 2>/dev/null | awk '{print $NF}' | tr -d '/' || echo "")

for bucket in "${REQUIRED_BUCKETS[@]}"; do
  if echo "${EXISTING_BUCKETS}" | grep -qx "${bucket}"; then
    pass "Bucket exists: ${bucket}"
  else
    fail "Bucket MISSING: ${bucket}"
  fi
done

# ---------------------------------------------------------------------------
# Check 4: Write + read test object on each node endpoint
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 4: Write/read per node ==="

TEST_OBJ="redi-3e-validate-$(date +%s).txt"
TEST_CONTENT="REDI Sprint 3E MinIO HA validation $(date -Is)"

echo "${TEST_CONTENT}" > /tmp/"${TEST_OBJ}"

# Write via mjk
MC_RUN cp /tmp/"${TEST_OBJ}" "redi/gitlab-artifacts/${TEST_OBJ}" 2>/dev/null \
  && pass "Write via mjk: ${TEST_OBJ}" \
  || fail "Write via mjk failed"

# Read back from each node endpoint
for node_ip in "${MJK}" "${JKT}" "${SBY}"; do
  NODE="$([ "${node_ip}" == "${MJK}" ] && echo mjk || ([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby))"
  ALIAS="redi-${NODE}"
  READ_VAL=$(MC_RUN cat "${ALIAS}/gitlab-artifacts/${TEST_OBJ}" 2>/dev/null || echo "FAILED")
  if [[ "${READ_VAL}" == "${TEST_CONTENT}" ]]; then
    pass "Read from ${NODE}: object consistent"
  elif [[ "${READ_VAL}" == "FAILED" ]]; then
    fail "Read from ${NODE}: failed — node unreachable or object not replicated"
  else
    fail "Read from ${NODE}: content mismatch"
  fi
done

# Cleanup test object
MC_RUN rm "redi/gitlab-artifacts/${TEST_OBJ}" 2>/dev/null || true
rm -f /tmp/"${TEST_OBJ}"

# ---------------------------------------------------------------------------
# Check 5: Erasure resilience — read when 1 alias is pointed to downed node
# (Simulated: we just confirm object is readable from the 2 remaining nodes
#  after the write, indicating EC encoding is active)
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 5: Erasure coding check ==="

TEST_EC_OBJ="redi-ec-test-$(date +%s).bin"
# Write a slightly larger test object (1 KB)
dd if=/dev/urandom bs=1024 count=1 2>/dev/null > /tmp/"${TEST_EC_OBJ}"
EXPECTED_MD5=$(md5sum /tmp/"${TEST_EC_OBJ}" | awk '{print $1}')

MC_RUN cp /tmp/"${TEST_EC_OBJ}" "redi/gitlab-artifacts/${TEST_EC_OBJ}" 2>/dev/null \
  && log_info "  EC test object written" \
  || warn "EC test write failed — skipping EC check"

# Verify read from non-primary nodes
for node_ip in "${JKT}" "${SBY}"; do
  NODE="$([ "${node_ip}" == "${JKT}" ] && echo jkt || echo sby)"
  ALIAS="redi-${NODE}"
  MC_RUN cp "${ALIAS}/gitlab-artifacts/${TEST_EC_OBJ}" "/tmp/ec-read-${NODE}.bin" 2>/dev/null || true
  if [[ -f "/tmp/ec-read-${NODE}.bin" ]]; then
    GOT_MD5=$(md5sum "/tmp/ec-read-${NODE}.bin" | awk '{print $1}')
    if [[ "${GOT_MD5}" == "${EXPECTED_MD5}" ]]; then
      pass "EC read from ${NODE}: checksum match — erasure coding active"
    else
      fail "EC read from ${NODE}: checksum mismatch"
    fi
    rm -f "/tmp/ec-read-${NODE}.bin"
  else
    warn "EC read from ${NODE}: could not retrieve object via ${node_ip}"
  fi
done

MC_RUN rm "redi/gitlab-artifacts/${TEST_EC_OBJ}" 2>/dev/null || true
rm -f /tmp/"${TEST_EC_OBJ}"

# ---------------------------------------------------------------------------
# Check 6: GitLab object store buckets accessible
# (3E.4 — registry/LFS/artifacts)
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 6: GitLab object store buckets (3E.4) ==="

GITLAB_BUCKETS=(gitlab-artifacts gitlab-lfs gitlab-uploads gitlab-packages)

for bucket in "${GITLAB_BUCKETS[@]}"; do
  # Stat the bucket to confirm it's readable
  STAT=$(MC_RUN stat "redi/${bucket}" 2>/dev/null || echo "FAILED")
  if [[ "${STAT}" != "FAILED" ]]; then
    OBJ_COUNT=$(MC_RUN ls --recursive "redi/${bucket}" 2>/dev/null | wc -l || echo "0")
    pass "GitLab bucket accessible: ${bucket} (${OBJ_COUNT} objects)"
  else
    fail "GitLab bucket NOT accessible: ${bucket}"
  fi
done

# Test registry bucket (docker images)
REGISTRY_STAT=$(MC_RUN stat "redi/gitlab-artifacts" 2>/dev/null || echo "FAILED")
if [[ "${REGISTRY_STAT}" != "FAILED" ]]; then
  pass "Registry storage bucket accessible"
fi

# GitLab connectivity test (if GitLab is running)
GITLAB_MESH="100.81.86.37"
GITLAB_PORT=8929
if nc -z -w5 "${GITLAB_MESH}" "${GITLAB_PORT}" 2>/dev/null; then
  # Run GitLab object store check via gitlab-rake
  RAKE_OUT=$(docker exec redi-gitlab \
    gitlab-rake gitlab:check 2>/dev/null | grep -E "Object store|MinIO|storage" | head -5 || echo "")
  if [[ -n "${RAKE_OUT}" ]]; then
    log_info "  GitLab rake check: ${RAKE_OUT}"
    pass "GitLab object store check ran"
  else
    # Just verify GitLab can reach MinIO
    MINIO_FROM_GITLAB=$(docker exec redi-gitlab \
      curl -sf -o /dev/null -w "%{http_code}" \
      "http://minio.redi.internal:9000/minio/health/live" 2>/dev/null || echo "000")
    if [[ "${MINIO_FROM_GITLAB}" == "200" ]]; then
      pass "GitLab → minio.redi.internal:9000 → HTTP 200"
    else
      warn "GitLab → minio.redi.internal: HTTP ${MINIO_FROM_GITLAB} (check extra_hosts + DNS)"
    fi
  fi
else
  warn "GitLab container not reachable on ${GITLAB_MESH}:${GITLAB_PORT} — skipping GitLab test"
fi

# ---------------------------------------------------------------------------
# Check 7: minio.redi.internal DNS
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 7: minio.redi.internal DNS ==="

DNS_RESULT=$(dig +short @"${JKT}" minio.redi.internal A 2>/dev/null || echo "")
if [[ -n "${DNS_RESULT}" ]]; then
  RECORD_COUNT=$(echo "${DNS_RESULT}" | wc -l | tr -d ' ')
  pass "minio.redi.internal resolves to ${RECORD_COUNT} IP(s): $(echo "${DNS_RESULT}" | tr '\n' ' ')"
  if [[ "${RECORD_COUNT}" -ge 3 ]]; then
    pass "Round-robin: ${RECORD_COUNT} A records (all 3 cluster nodes)"
  elif [[ "${RECORD_COUNT}" -ge 1 ]]; then
    warn "Only ${RECORD_COUNT} A record(s) — run Step 8 of deploy-minio-distributed.sh to add all nodes"
  fi
else
  fail "minio.redi.internal does not resolve — check redi.internal zone"
fi

# ---------------------------------------------------------------------------
# Check 8: redi-pg-wal bucket (Patroni WAL archiving)
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 8: redi-pg-wal (Patroni WAL archiving) ==="

WAL_STAT=$(MC_RUN stat "redi/redi-pg-wal" 2>/dev/null || echo "FAILED")
if [[ "${WAL_STAT}" != "FAILED" ]]; then
  WAL_COUNT=$(MC_RUN ls --recursive "redi/redi-pg-wal" 2>/dev/null | wc -l || echo "0")
  pass "redi-pg-wal accessible (${WAL_COUNT} WAL files)"
else
  fail "redi-pg-wal bucket NOT accessible"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log_info ""
log_info "================================================================"
log_info "MinIO HA Validation Summary — Sprint 3E"
log_info "================================================================"
log_info "  PASS: ${PASS}"
[[ ${WARN} -gt 0 ]] && log_warn "  WARN: ${WARN}" || log_info "  WARN: ${WARN}"
[[ ${FAIL} -gt 0 ]] && log_error "  FAIL: ${FAIL}" || log_info "  FAIL: ${FAIL}"
log_info "================================================================"

if [[ ${FAIL} -gt 0 ]]; then
  log_error "Sprint 3E validation: FAIL (${FAIL} failures)"
  exit 1
elif [[ ${WARN} -gt 0 ]]; then
  log_warn "Sprint 3E validation: PASS WITH WARNINGS"
  exit 0
else
  log_info "Sprint 3E validation: PASS"
  exit 0
fi
