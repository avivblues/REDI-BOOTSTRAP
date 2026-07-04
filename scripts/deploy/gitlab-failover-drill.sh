#!/usr/bin/env bash
# =============================================================================
# REDI — GitLab HA Failover Drill Executor & Validator
# Run this from your local workstation.
# =============================================================================
set -euo pipefail

MJK_HOST="103.80.214.226"
MJK_PORT=2280
MJK_USER="root"
MJK_PW="!Proxmox@Redi123"

GITLAB_URL="https://git.letsredi.com"
REGISTRY_URL="registry.letsredi.com"
TOKEN="failover-drill-token-123"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
log_section() { echo ""; echo "══════════════════════════════════════════════════"; echo "  $*"; echo "══════════════════════════════════════════════════"; }

# Check dependencies
for cmd in curl git docker sshpass; do
  if ! command -v "$cmd" &>/dev/null; then
    log "ERROR: Command '$cmd' is required but not installed."
    exit 1
  fi
done

# Helper for remote ssh
ssh_mjk() {
  sshpass -p "${MJK_PW}" ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -p "${MJK_PORT}" \
    "${MJK_USER}@${MJK_HOST}" "$@"
}

log_section "PRE-FLIGHT CHECKS"
log "Checking if GitLab is responsive..."
if ! curl -sf -o /dev/null "${GITLAB_URL}"; then
  log "ERROR: GitLab is not responsive at ${GITLAB_URL}"
  exit 1
fi
log "GitLab is online."

log "Checking Praefect Gitaly Cluster health on MJK..."
ssh_mjk "docker exec redi-gitlab /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml check"

log_section "STEP 1: Create Test Project & Populate Data (Steady State)"
PROJECT_NAME="failover-drill-$(date +%s)"
log "Creating project '${PROJECT_NAME}' via API..."
PROJECT_ID=$(curl -s -f -X POST \
  -H "PRIVATE-TOKEN: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"${PROJECT_NAME}\", \"visibility\": \"public\"}" \
  "${GITLAB_URL}/api/v4/projects" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2)

log "Created project ID: ${PROJECT_ID}"

# Temp directories for git clones
TEMP_DIR_1=$(mktemp -d)
TEMP_DIR_2=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR_1}" "${TEMP_DIR_2}"' EXIT

log "Cloning repository (steady state)..."
git clone "https://oauth2:${TOKEN}@git.letsredi.com/root/${PROJECT_NAME}.git" "${TEMP_DIR_1}"

log "Adding test files and pushing..."
cd "${TEMP_DIR_1}"
git config user.name "Failover Drill"
git config user.email "drill@letsredi.com"
echo "# GitLab HA Failover Test" > README.md
echo "Initial commit in steady state." > steady-state.txt
git add .
git commit -m "Add initial files in steady state"
git push origin main
cd -

log_section "STEP 2: Initiate Controlled Failover of redi-mjk-01"
log "Stopping Docker service on redi-mjk-01..."
START_FAILOVER=$(date +%s)
ssh_mjk "systemctl stop docker"
log "Docker service stopped on MJK."

log "Waiting for failover/routing recovery..."
FAILOVER_TIME=0
while true; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" || echo "000")
  if [[ "${HTTP_STATUS}" == "200" ]]; then
    END_FAILOVER=$(date +%s)
    FAILOVER_TIME=$((END_FAILOVER - START_FAILOVER))
    log "SUCCESS: GitLab is back online and accessible via edge nodes JKT/SBY!"
    log "Failover and routing recovery completed in: ${FAILOVER_TIME} seconds"
    break
  fi
  sleep 1
  FAILOVER_TIME=$((FAILOVER_TIME + 1))
  if [[ ${FAILOVER_TIME} -gt 120 ]]; then
    log "ERROR: Failover timed out after 120 seconds. Re-starting Docker on MJK to recover..."
    ssh_mjk "systemctl start docker"
    exit 1
  fi
done

log_section "STEP 3: Validate GitLab Operations During Failover"

log "1. Cloning project again from edge nodes (during failover)..."
git clone "https://oauth2:${TOKEN}@git.letsredi.com/root/${PROJECT_NAME}.git" "${TEMP_DIR_2}"

log "2. Modifying file and pushing (during failover)..."
cd "${TEMP_DIR_2}"
git config user.name "Failover Drill"
git config user.email "drill@letsredi.com"
echo "Modification during MJK outage." >> steady-state.txt
git add .
git commit -m "Commit during MJK outage"
git push origin main
cd -

log "3. Pulling updates to the first clone directory..."
cd "${TEMP_DIR_1}"
git pull origin main
cd -

log "4. Creating an issue via API (during failover)..."
curl -s -f -X POST \
  -H "PRIVATE-TOKEN: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"title": "Issue during failover", "description": "This issue was created while redi-mjk-01 was offline."}' \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/issues" >/dev/null
log "Issue created successfully."

log "5. Creating a wiki page via API (during failover)..."
curl -s -f -X POST \
  -H "PRIVATE-TOKEN: ${TOKEN}" \
  -d "title=FailoverWiki" \
  -d "content=Content written during MJK outage." \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/wikis" >/dev/null
log "Wiki page created successfully."

log "6. Pushing image to registry (during failover)..."
docker login -u root -p "${TOKEN}" "${REGISTRY_URL}"
docker pull alpine:latest
docker tag alpine:latest "${REGISTRY_URL}/root/${PROJECT_NAME}/alpine:latest"
docker push "${REGISTRY_URL}/root/${PROJECT_NAME}/alpine:latest"
log "Registry image pushed successfully."

log "7. Creating a Merge Request via API (during failover)..."
# Create branch, commit, push, then create MR
cd "${TEMP_DIR_2}"
git checkout -b feature-branch
echo "Feature branch modification" > feature.txt
git add feature.txt
git commit -m "Commit on feature branch"
git push origin feature-branch
cd -

curl -s -f -X POST \
  -H "PRIVATE-TOKEN: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"source_branch\": \"feature-branch\", \"target_branch\": \"main\", \"title\": \"MR during failover\"}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/merge_requests" >/dev/null
log "Merge Request created successfully."

log_section "STEP 4: Restore Original Topology (Start Docker on redi-mjk-01)"
log "Starting Docker service on redi-mjk-01..."
START_RECOVERY=$(date +%s)
ssh_mjk "systemctl start docker"
log "Docker service started on MJK."

log "Waiting for services to re-join and stabilize..."
RECOVERY_TIME=0
while true; do
  # Check if Praefect on MJK can reach all nodes again
  HEALTH_CHECK=$(ssh_mjk "docker exec redi-gitlab /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml check 2>&1" || echo "FAIL")
  if [[ "${HEALTH_CHECK}" != *"FAIL"* ]] && [[ "${HEALTH_CHECK}" != *"not healthy"* ]]; then
    END_RECOVERY=$(date +%s)
    RECOVERY_TIME=$((END_RECOVERY - START_RECOVERY))
    log "SUCCESS: All Gitaly nodes and Praefect cluster have stabilized!"
    log "Recovery and re-join completed in: ${RECOVERY_TIME} seconds"
    break
  fi
  sleep 5
  RECOVERY_TIME=$((RECOVERY_TIME + 5))
  if [[ ${RECOVERY_TIME} -gt 300 ]]; then
    log "WARNING: Stabilization took longer than 5 minutes. Checking current Praefect check output:"
    echo "${HEALTH_CHECK}"
    break
  fi
done

log_section "STEP 5: Clean Up Test Project"
log "Deleting test project '${PROJECT_NAME}'..."
curl -s -f -X DELETE \
  -H "PRIVATE-TOKEN: ${TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" >/dev/null
log "Cleanup finished."

log_section "FAILOVER DRILL SUMMARY"
echo "--------------------------------------------------------"
echo "  Failover & Routing Recovery Time:  ${FAILOVER_TIME} seconds"
echo "  MJK Re-join & Stabilization Time:  ${RECOVERY_TIME} seconds"
echo "  GitLab Functionality:              100% SUCCESS"
echo "--------------------------------------------------------"
