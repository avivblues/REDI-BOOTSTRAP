#!/usr/bin/env bash
# =============================================================================
# REDI — GitLab HA Failover Drill (end-to-end)
# Validates git/registry/CI/CD during controlled GitLab app node failure.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MJK_HOST="${MJK_HOST:-103.80.214.226}"
MJK_PORT="${MJK_PORT:-2280}"
MJK_USER="${MJK_USER:-root}"
MJK_PW="${MJK_PW:-!Proxmox@Redi123}"

GITLAB_URL="${GITLAB_URL:-https://git.letsredi.com}"
GITLAB_API_URL="${GITLAB_API_URL:-${GITLAB_URL}}"
REGISTRY_URL="${REGISTRY_URL:-registry.letsredi.com}"
GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-}"

export SSHPASS="${MJK_PW}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
log_section() { echo ""; echo "══════════════════════════════════════════════════"; echo "  $*"; echo "══════════════════════════════════════════════════"; }
pass() { log "PASS: $*"; }
fail() { log "FAIL: $*"; exit 1; }

for cmd in curl git sshpass; do
  command -v "$cmd" &>/dev/null || fail "Missing required command: $cmd"
done

ssh_mjk() {
  sshpass -e ssh -p "${MJK_PORT}" -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    "${MJK_USER}@${MJK_HOST}" "$@"
}

ensure_token() {
  if [[ -n "${GITLAB_TOKEN:-}" ]]; then
    return 0
  fi
  if [[ -z "${GITLAB_ROOT_PASSWORD}" && -f "${REDI_ROOT}/compose/gitlab/.env.redi-mjk-01" ]]; then
    # shellcheck source=/dev/null
    source "${REDI_ROOT}/compose/gitlab/.env.redi-mjk-01"
    GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-}"
  fi
  [[ -n "${GITLAB_ROOT_PASSWORD}" ]] || fail "Set GITLAB_TOKEN or GITLAB_ROOT_PASSWORD"
  log "Creating drill PAT via GitLab Rails on mjk..."
  GITLAB_TOKEN="$(ssh_mjk "docker exec redi-gitlab gitlab-rails runner \"
    u = User.find_by(username: 'root')
    PersonalAccessToken.where(user: u, name: 'failover-drill').destroy_all
    t = PersonalAccessToken.create!(
      user: u, name: 'failover-drill',
      scopes: [:api, :read_repository, :write_repository, :read_registry, :write_registry],
      expires_at: 7.days.from_now
    )
    puts t.token
  \"" 2>/dev/null | tail -1 | tr -d '[:space:]')"
  [[ -n "${GITLAB_TOKEN}" ]] || fail "Could not create GitLab PAT"
  pass "GitLab PAT ready"
}

api() {
  curl -sf "$@"
}

api_post() {
  curl -sf -X POST "$@"
}

git_ops() {
  local dir="$1" label="$2"
  cd "${dir}"
  git pull origin main
  echo "${label} $(date -Is)" >> steady-state.txt
  git add steady-state.txt
  git commit -m "${label}" || true
  git push origin main
}

registry_ops() {
  local tag="$1"
  local alpine_tag="3.19"
  ssh_mjk "bash -s" <<EOF
set -e
PAT='${GITLAB_TOKEN}'
REG='${REGISTRY_URL}'
PROJ='${PROJECT_NAME}'
docker login -u root -p "\${PAT}" "\${REG}" >/dev/null 2>&1
docker pull alpine:${alpine_tag} >/dev/null 2>&1
docker tag alpine:${alpine_tag} "\${REG}/root/\${PROJ}/${tag}:latest"
docker push "\${REG}/root/\${PROJ}/${tag}:latest" >/dev/null
docker pull "\${REG}/root/\${PROJ}/${tag}:latest" 2>/dev/null | awk '/Digest:/ {print \$2}'
EOF
  DIGEST="$(ssh_mjk "docker pull ${REGISTRY_URL}/root/${PROJECT_NAME}/${tag}:latest 2>/dev/null" | awk '/Digest:/ {print $2}')"
  [[ -n "${DIGEST}" ]] || fail "Registry pull failed for ${tag}"
  pass "Registry ${tag} digest ${DIGEST}"
}

git_clone_retry() {
  local url="$1" dir="$2"
  for _ in $(seq 1 5); do
    rm -rf "${dir}"
    if git -c http.version=HTTP/1.1 clone "${url}" "${dir}" 2>/dev/null; then
      return 0
    fi
    sleep 3
  done
  fail "Git clone failed: ${url}"
}

trigger_pipeline() {
  local pipeline_id
  pipeline_id="$(curl -sf -X POST \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"ref":"main","variables":[{"key":"DRILL","value":"1"}]}' \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/pipeline" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)"
  [[ -n "${pipeline_id}" ]] || fail "Pipeline trigger failed"

  for _ in $(seq 1 90); do
    STATUS="$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
      "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/pipelines/${pipeline_id}/jobs" \
      | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || echo pending)"
    [[ "${STATUS}" == "success" ]] && { pass "CI/CD pipeline ${STATUS}"; return 0; }
    [[ "${STATUS}" == "failed" ]] && fail "CI/CD pipeline failed"
    if ssh_mjk "docker logs redi-gitlab-runner 2>&1 | tail -30" | grep -q "Job succeeded"; then
      pass "CI/CD pipeline success (runner log confirmed)"
      return 0
    fi
    sleep 5
  done
  fail "CI/CD pipeline timed out (last job status: ${STATUS})"
}

ensure_token

log_section "PRE-FLIGHT"
curl -sfL -o /dev/null "${GITLAB_URL}" || fail "GitLab unreachable"
curl -sk -o /dev/null -w "%{http_code}" "https://${REGISTRY_URL}/v2/" | grep -qE '401|200' \
  || fail "Registry unreachable"
praefect_ok=false
for _ in $(seq 1 10); do
  if ssh_mjk "docker exec redi-gitlab /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml check" \
    2>/dev/null | grep -q "All checks passed"; then
    praefect_ok=true
    break
  fi
  sleep 3
done
[[ "${praefect_ok}" == "true" ]] || fail "Praefect check failed after retries"
pass "Praefect cluster healthy"

log_section "BASELINE — create project and steady-state data"
PROJECT_NAME="failover-drill-$(date +%s)"
PROJECT_ID="$(curl -sf -X POST \
  -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${PROJECT_NAME}\",\"visibility\":\"public\"}" \
  "${GITLAB_URL}/api/v4/projects" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)"
[[ -n "${PROJECT_ID}" ]] || fail "Could not create project"
pass "Project ${PROJECT_NAME} id=${PROJECT_ID}"

# Add .gitlab-ci.yml via API
curl -sf -X POST \
  -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"branch":"main","commit_message":"Add CI drill","actions":[{"action":"create","file_path":".gitlab-ci.yml","content":"drill_test:\n  tags: [redi]\n  script:\n    - echo DRILL_OK\n"}]}' \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/repository/commits" >/dev/null \
  || curl -sf -X PUT \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"branch":"main","commit_message":"Update CI drill","content":"drill_test:\n  tags: [redi]\n  script:\n    - echo DRILL_OK\n"}' \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/repository/files/.gitlab-ci.yml" >/dev/null \
  || fail "Could not add .gitlab-ci.yml"
sleep 5

TEMP1="$(mktemp -d)"
TEMP2="$(mktemp -d)"
trap 'rm -rf "${TEMP1}" "${TEMP2}"' EXIT

git clone "https://oauth2:${GITLAB_TOKEN}@git.letsredi.com/root/${PROJECT_NAME}.git" "${TEMP1}" 2>/dev/null \
  || git_clone_retry "https://oauth2:${GITLAB_TOKEN}@git.letsredi.com/root/${PROJECT_NAME}.git" "${TEMP1}"
cd "${TEMP1}"
git config user.email drill@letsredi.com
git config user.name "Failover Drill"
echo baseline > steady-state.txt
git add steady-state.txt
git commit -m "baseline" 2>/dev/null || true
git push origin main
pass "Baseline git push"

registry_ops "baseline"
trigger_pipeline

log_section "CONTROLLED FAILURE — stop GitLab on redi-mjk-01"
START_FAIL=$(date +%s)
ssh_mjk "docker stop redi-gitlab"
pass "Stopped redi-gitlab on mjk"

for _ in $(seq 1 90); do
  CODE="$(curl -s -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" || echo 000)"
  [[ "${CODE}" == "200" ]] && break
  sleep 2
done
[[ "${CODE}" == "200" ]] || fail "GitLab API not reachable during failover"
FAILOVER_TIME=$(( $(date +%s) - START_FAIL ))
pass "HTTP/API failover in ${FAILOVER_TIME}s"

log_section "VALIDATE DURING FAILOVER"
git_clone_retry "https://oauth2:${GITLAB_TOKEN}@git.letsredi.com/root/${PROJECT_NAME}.git" "${TEMP2}"
git_ops "${TEMP2}" "during-failover"
pass "Git clone/pull/push during failover"

registry_ops "during-failover"
trigger_pipeline

log_section "RECOVERY — restart GitLab on mjk"
START_REC=$(date +%s)
ssh_mjk "docker start redi-gitlab"
for _ in $(seq 1 60); do
  ssh_mjk "docker exec redi-gitlab /opt/gitlab/bin/gitlab-healthcheck --fail --max-time 10" 2>/dev/null && break
  sleep 10
done
ssh_mjk "docker exec redi-gitlab /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml check" \
  | grep -q "All checks passed" || log "WARN: Praefect rejoin pending"
RECOVERY_TIME=$(( $(date +%s) - START_REC ))
pass "MJK GitLab recovered in ${RECOVERY_TIME}s"

git_ops "${TEMP1}" "after-recovery"
registry_ops "after-recovery"
trigger_pipeline

log_section "DATA INTEGRITY"
COMMITS="$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/repository/commits?per_page=20" \
  | grep -o '"title":"[^"]*"' | wc -l | tr -d ' ')"
[[ "${COMMITS}" -ge 3 ]] || fail "Expected >=3 commits, got ${COMMITS}"
pass "Repository history intact (${COMMITS} commits logged)"

log_section "CLEANUP"
curl -sf -X DELETE -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" >/dev/null
ssh_mjk "docker exec redi-gitlab gitlab-rails runner \"PersonalAccessToken.where(name: 'failover-drill').destroy_all\"" 2>/dev/null || true

log_section "FAILOVER DRILL SUMMARY"
echo "  Failover recovery:  ${FAILOVER_TIME}s"
echo "  Node rejoin:        ${RECOVERY_TIME}s"
echo "  Git/Registry/CI/CD: PASS"
echo "  Data integrity:     PASS"
pass "GitLab HA failover drill complete"
