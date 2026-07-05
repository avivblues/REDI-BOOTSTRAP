#!/usr/bin/env bash
# =============================================================================
# REDI Phase 6 — Validate Portainer Management Platform
# Run on redi-mjk-01 (Portainer server host).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0
FAIL=0
ok() { log_info "PASS: $*"; PASS=$((PASS + 1)); }
bad() { log_error "FAIL: $*"; FAIL=$((FAIL + 1)); }

MJK_MESH="100.81.86.37"
JKT_MESH="100.79.82.92"
SBY_MESH="100.67.138.25"
MJK_PUBLIC="103.80.214.226"
PORTAINER_URL="https://${MJK_MESH}:9443"
SECRETS_FILE="${REDI_ROOT}/secrets/api-keys.yaml"
ADMIN_PASSWORD="$(grep -A3 'portainer-admin-password' "${SECRETS_FILE}" 2>/dev/null | awk -F"'" '/value:/ {print $2; exit}')"

[[ -n "${ADMIN_PASSWORD}" ]] || { log_error "Missing portainer-admin-password"; exit 1; }

docker ps --format '{{.Names}} {{.Status}}' | grep -q '^redi-portainer Up' && ok "Portainer Server healthy" || bad "Portainer Server healthy"
docker ps --format '{{.Names}} {{.Status}}' | grep -q '^redi-portainer-agent Up' && ok "MJK Portainer Agent healthy" || bad "MJK Portainer Agent healthy"

check_agent_port() {
  local mesh="$1"
  local label="$2"
  nc -z -w3 "${mesh}" 9001 &>/dev/null && ok "${label} agent port 9001 reachable" || bad "${label} agent port 9001 reachable"
}

check_agent_port "${JKT_MESH}" "Jakarta"
check_agent_port "${SBY_MESH}" "Surabaya"
check_agent_port "${MJK_MESH}" "Mojokerto"

if curl -sk --connect-timeout 3 "https://${MJK_PUBLIC}:9443/" &>/dev/null; then
  bad "Public IP 9443 blocked"
else
  ok "Public IP 9443 blocked"
fi

if ! python3 <<PY > /tmp/validate-portainer.out
import json, subprocess, sys, time

admin_password = ${ADMIN_PASSWORD@Q}
portainer_url = ${PORTAINER_URL@Q}
sby_mesh = ${SBY_MESH@Q}
results = []

def record(name, passed, detail=""):
    results.append((name, passed, detail))

auth = subprocess.check_output([
    "curl", "-sk", "-X", "POST", f"{portainer_url}/api/auth",
    "-H", "Content-Type: application/json",
    "-d", json.dumps({"Username": "admin", "Password": admin_password}),
])
token = json.loads(auth).get("jwt")
record("Portainer admin authentication", bool(token))
if not token:
    for name, passed, detail in results:
        print(f"{'PASS' if passed else 'FAIL'}:{name}:{detail}")
    sys.exit(0)

headers = ["-H", f"Authorization: Bearer {token}"]
settings = json.loads(subprocess.check_output(["curl", "-sk", *headers, f"{portainer_url}/api/settings"]))
eps = json.loads(subprocess.check_output(["curl", "-sk", *headers, f"{portainer_url}/api/endpoints"]))
names = {e.get("Name"): e for e in eps}
required = ["redi-jkt-01", "redi-mjk-01", "redi-sby-01"]
connected = all(n in names and names[n].get("Status") == 1 for n in required)
record("Three environments connected", connected, ",".join(required))

for name in required:
    eid = names[name]["Id"]
    containers = json.loads(subprocess.check_output([
        "curl", "-sk", *headers,
        f"{portainer_url}/api/endpoints/{eid}/docker/containers/json?all=1",
    ]))
    record(f"{name} containers visible", len(containers) > 0, str(len(containers)))

oauth = settings.get("OAuthSettings", {})
oauth_ok = settings.get("AuthenticationMethod") == 3 and bool(oauth.get("ClientID"))
record("Portainer OAuth configured", oauth_ok, oauth.get("ClientID", ""))
disc_code = subprocess.check_output([
    "curl", "-sk", "-o", "/dev/null", "-w", "%{http_code}",
    "https://auth.letsredi.com/application/o/portainer/.well-known/openid-configuration",
]).decode().strip()
record("Authentik Portainer OIDC discovery", disc_code == "200", disc_code)

endpoint_id = names["redi-sby-01"]["Id"]
containers = json.loads(subprocess.check_output([
    "curl", "-sk", *headers,
    f"{portainer_url}/api/endpoints/{endpoint_id}/docker/containers/json?all=1",
]))
target = next(c for c in containers if c.get("Names") == ["/redi-portainer-agent"])
cid = target["Id"]
before = target.get("State")
subprocess.run([
    "curl", "-sk", "-X", "POST", *headers,
    f"{portainer_url}/api/endpoints/{endpoint_id}/docker/containers/{cid}/restart",
], check=True, stdout=subprocess.DEVNULL)
time.sleep(15)
containers = json.loads(subprocess.check_output([
    "curl", "-sk", *headers,
    f"{portainer_url}/api/endpoints/{endpoint_id}/docker/containers/json?all=1",
]))
target = next(c for c in containers if c.get("Names") == ["/redi-portainer-agent"])
after = target.get("State")
remote = subprocess.check_output([
    "curl", "-sk", "-o", "/dev/null", "-w", "%{http_code}", f"https://{sby_mesh}:9001/ping",
]).decode().strip()
record(
    "Safe container restart on SBY",
    after == "running" and remote == "204",
    f"before={before} after={after} ping={remote}",
)

for name, passed, detail in results:
    print(f"{'PASS' if passed else 'FAIL'}:{name}:{detail}")
if not all(p for _, p, _ in results):
    sys.exit(1)
PY
then
  cat /tmp/validate-portainer.out >&2 || true
  bad "Portainer API validation"
fi

while IFS=: read -r status name detail; do
  [[ "${status}" == PASS ]] && ok "${name}${detail:+ (${detail})}" || bad "${name}${detail:+ (${detail})}"
done < /tmp/validate-portainer.out

log_info "Validation complete: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
