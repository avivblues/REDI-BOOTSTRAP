#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Validate GeoDNS edge routing (Sprint 3D)
# Run from any node with Tailscale access and dig/curl installed.
#
# Checks:
#   1. LUA records exist in PowerDNS zone for geo-routed hosts
#   2. Traefik SBY is reachable and serving TLS
#   3. Traefik JKT is reachable and serving TLS
#   4. Internal records (postgres/redis/minio) are NOT geo-routed
#   5. GeoDNS simulation: dig with ECS to simulate JKT vs Jatim client
#   6. GitLab accessible via both JKT and SBY Traefik backends
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PDNS_ENV="${REDI_ROOT}/compose/powerdns/.env"
[[ -f "${PDNS_ENV}" ]] || { log_error "Missing ${PDNS_ENV}"; exit 1; }
# shellcheck source=/dev/null
source "${PDNS_ENV}"

PDNS_API_KEY="${PDNS_API_KEY:?PDNS_API_KEY not set}"
PDNS_API_URL="${PDNS_API_URL:-http://127.0.0.1:8081}"
if ! curl -sf -o /dev/null -H "X-API-Key: ${PDNS_API_KEY}" "${PDNS_API_URL}/api/v1/servers/localhost" 2>/dev/null; then
  PDNS_API_URL="http://$(get_tailscale_ip):${PDNS_WEBSERVER_PORT:-8081}"
fi
ZONE="letsredi.com."
API="${PDNS_API_URL}/api/v1/servers/localhost/zones/${ZONE}"

JKT_IP="103.149.238.98"    # redi-jkt-01 public
SBY_IP="103.80.214.144"    # redi-sby-01 public
NS1="103.149.238.98"       # ns1.letsredi.com (jkt)
NS2="103.80.214.144"       # ns2.letsredi.com (sby)

# Simulation: IPs used to mimic regional clients via dig +subnet
# JKT/West Java area — Telkom Jakarta range (example)
ECS_JKT="180.247.0.0/24"
# Jawa Timur/Surabaya area — SBY public IP (confirmed JI in MaxMind)
ECS_JATIM="103.80.214.165/32"

PASS=0; FAIL=0; WARN=0

pass() { log_info "[PASS] $*"; ((PASS++)) || true; }
fail() { log_error "[FAIL] $*"; ((FAIL++)) || true; }
warn() { log_warn "[WARN] $*"; ((WARN++)) || true; }

# ---------------------------------------------------------------------------
# Check 1: LUA records exist for geo-routed hosts
# ---------------------------------------------------------------------------
log_info "=== CHECK 1: LUA records in PowerDNS zone ==="
LUA_NAMES=$(curl -sf \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rr in data.get('rrsets', []):
    if rr['type'] == 'LUA':
        print(rr['name'])
" 2>/dev/null || echo "")

for host in "git.letsredi.com." "registry.letsredi.com." "auth.letsredi.com." "proxy.letsredi.com."; do
  if echo "${LUA_NAMES}" | grep -q "^${host}$"; then
    pass "LUA record: ${host}"
  else
    fail "LUA record missing: ${host}"
  fi
done

# Check traefik-sby anchor A record
SBY_ANCHOR=$(curl -sf \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rr in data.get('rrsets', []):
    if rr['name'] == 'traefik-sby.letsredi.com.' and rr['type'] == 'A':
        print(rr['records'][0]['content'])
" 2>/dev/null || echo "")

if [[ "${SBY_ANCHOR}" == "${SBY_IP}" ]]; then
  pass "traefik-sby.letsredi.com A ${SBY_IP}"
else
  fail "traefik-sby.letsredi.com not found or wrong IP (got: '${SBY_ANCHOR}')"
fi

# ---------------------------------------------------------------------------
# Check 2: Internal records NOT geo-routed
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 2: Internal records protected (3D.5) ==="

INTERNAL_LUA=$(curl -sf \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rr in data.get('rrsets', []):
    if rr['type'] == 'LUA' and 'redi.internal' in rr['name']:
        print(rr['name'])
" 2>/dev/null || echo "")

if [[ -z "${INTERNAL_LUA}" ]]; then
  pass "No .redi.internal records converted to LUA — internal routing intact"
else
  fail "LUA records found for internal hosts (should not be geo-routed): ${INTERNAL_LUA}"
fi

# Verify ns1/ns2 glue are plain A records
for glue in "ns1.letsredi.com." "ns2.letsredi.com."; do
  GLUE_TYPE=$(curl -sf \
    -H "X-API-Key: ${PDNS_API_KEY}" \
    "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rr in data.get('rrsets', []):
    if rr['name'] == '${glue}':
        print(rr['type'])
        break
" 2>/dev/null || echo "")
  if [[ "${GLUE_TYPE}" == "A" ]]; then
    pass "Glue record ${glue} is type A (not LUA) — protected"
  else
    fail "Glue record ${glue} type is '${GLUE_TYPE}' — expected A"
  fi
done

# ---------------------------------------------------------------------------
# Check 3: GeoDNS simulation via dig +subnet (ECS)
# Tests which IP ns1 returns for each simulated region
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 3: GeoDNS simulation (ECS dig) ==="

if ! command -v dig &>/dev/null; then
  warn "dig not installed — skipping ECS simulation (install: apt-get install dnsutils)"
else
  for host in "git.letsredi.com" "auth.letsredi.com" "proxy.letsredi.com"; do
    # Simulate JKT client
    JKT_RESULT=$(dig @"${NS1}" +short +subnet="${ECS_JKT}" "${host}" A 2>/dev/null | head -1 || echo "")
    # Simulate Jatim client
    JATIM_RESULT=$(dig @"${NS1}" +short +subnet="${ECS_JATIM}" "${host}" A 2>/dev/null | head -1 || echo "")

    log_info "  ${host}:"
    log_info "    ECS JKT  (${ECS_JKT}): ${JKT_RESULT:-<no answer>}"
    log_info "    ECS Jatim (${ECS_JATIM}): ${JATIM_RESULT:-<no answer>}"

    if [[ "${JKT_RESULT}" == "${JKT_IP}" ]]; then
      pass "  ${host}: JKT client → ${JKT_IP} (correct)"
    elif [[ -n "${JKT_RESULT}" ]]; then
      warn "  ${host}: JKT client → ${JKT_RESULT} (expected ${JKT_IP})"
    else
      warn "  ${host}: JKT ECS query returned no answer (resolver may not support ECS)"
    fi

    if [[ "${JATIM_RESULT}" == "${SBY_IP}" ]]; then
      pass "  ${host}: Jatim client → ${SBY_IP} (correct)"
    elif [[ -n "${JATIM_RESULT}" ]]; then
      warn "  ${host}: Jatim client → ${JATIM_RESULT} (expected ${SBY_IP} — ECS may not have Jatim range)"
    else
      warn "  ${host}: Jatim ECS query returned no answer"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Check 4: Traefik JKT reachability (HTTPS)
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 4: Traefik JKT HTTPS ==="

for host in "git.letsredi.com" "auth.letsredi.com"; do
  HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
    --resolve "${host}:443:${JKT_IP}" \
    --max-time 10 \
    "https://${host}/" 2>/dev/null || echo "000")
  if [[ "${HTTP_STATUS}" =~ ^[23] ]]; then
    pass "JKT: https://${host}/ → HTTP ${HTTP_STATUS}"
  elif [[ "${HTTP_STATUS}" == "401" || "${HTTP_STATUS}" == "302" ]]; then
    pass "JKT: https://${host}/ → HTTP ${HTTP_STATUS} (auth redirect — Traefik OK)"
  else
    warn "JKT: https://${host}/ → HTTP ${HTTP_STATUS}"
  fi
done

# ---------------------------------------------------------------------------
# Check 5: Traefik SBY reachability (HTTPS)
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 5: Traefik SBY HTTPS ==="

for host in "git.letsredi.com" "auth.letsredi.com"; do
  HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
    --resolve "${host}:443:${SBY_IP}" \
    --max-time 10 \
    "https://${host}/" 2>/dev/null || echo "000")
  if [[ "${HTTP_STATUS}" =~ ^[23] ]]; then
    pass "SBY: https://${host}/ → HTTP ${HTTP_STATUS}"
  elif [[ "${HTTP_STATUS}" == "401" || "${HTTP_STATUS}" == "302" ]]; then
    pass "SBY: https://${host}/ → HTTP ${HTTP_STATUS} (auth redirect — Traefik OK)"
  else
    warn "SBY: https://${host}/ → HTTP ${HTTP_STATUS} (SBY Traefik may not be deployed yet)"
  fi
done

# ---------------------------------------------------------------------------
# Check 6: Traefik SBY → mjk backend connectivity (GitLab ping via mesh)
# ---------------------------------------------------------------------------
log_info ""
log_info "=== CHECK 6: SBY Traefik → mjk backend (Tailscale mesh) ==="

MJK_MESH="100.81.86.37"
GITLAB_PORT=8929

if nc -z -w5 "${MJK_MESH}" "${GITLAB_PORT}" 2>/dev/null; then
  pass "mjk GitLab backend ${MJK_MESH}:${GITLAB_PORT} reachable via mesh"
else
  warn "mjk GitLab backend ${MJK_MESH}:${GITLAB_PORT} not reachable — check Tailscale on sby"
fi

AUTHENTIK_PORT=9100
if nc -z -w5 "${MJK_MESH}" "${AUTHENTIK_PORT}" 2>/dev/null; then
  pass "mjk Authentik backend ${MJK_MESH}:${AUTHENTIK_PORT} reachable via mesh"
else
  warn "mjk Authentik backend ${MJK_MESH}:${AUTHENTIK_PORT} not reachable"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log_info ""
log_info "================================================================"
log_info "GeoDNS Validation Summary"
log_info "================================================================"
log_info "  PASS: ${PASS}"
log_warn "  WARN: ${WARN}"
[[ ${FAIL} -gt 0 ]] && log_error "  FAIL: ${FAIL}" || log_info "  FAIL: ${FAIL}"
log_info "================================================================"

if [[ ${FAIL} -gt 0 ]]; then
  log_error "Sprint 3D validation: FAIL (${FAIL} failures)"
  exit 1
elif [[ ${WARN} -gt 0 ]]; then
  log_warn "Sprint 3D validation: PASS WITH WARNINGS (${WARN} warnings)"
  exit 0
else
  log_info "Sprint 3D validation: PASS"
  exit 0
fi
