#!/usr/bin/env bash
# =============================================================================
# REDI Phase 7 — Validate Monitoring Platform
# Run on redi-mjk-01
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
SECRETS_FILE="${REDI_ROOT}/secrets/api-keys.yaml"
GRAFANA_PW="$(grep -A3 'grafana-admin-password' "${SECRETS_FILE}" 2>/dev/null | awk -F"'" '/value:/ {print $2; exit}')"

curl -sf "http://${MJK_MESH}:9090/-/ready" >/dev/null && ok "Prometheus healthy" || bad "Prometheus healthy"
curl -sf "http://${MJK_MESH}:3000/api/health" >/dev/null && ok "Grafana healthy" || bad "Grafana healthy"
curl -sf "http://${MJK_MESH}:9093/-/ready" >/dev/null && ok "Alertmanager healthy" || bad "Alertmanager healthy"
curl -sf "http://${MJK_MESH}:9115/metrics" >/dev/null && ok "Blackbox Exporter healthy" || bad "Blackbox Exporter healthy"

if curl -sk --connect-timeout 3 "http://${MJK_PUBLIC}:9090/-/ready" >/dev/null 2>&1; then
  bad "Prometheus public exposure blocked"
else
  ok "Prometheus public exposure blocked"
fi

check_node_exporter() {
  local mesh="$1"
  local label="$2"
  curl -sf "http://${mesh}:9102/metrics" >/dev/null && ok "${label} node-exporter" || bad "${label} node-exporter"
  curl -sf "http://${mesh}:8085/metrics" >/dev/null && ok "${label} cAdvisor" || bad "${label} cAdvisor"
}

check_node_exporter "${JKT_MESH}" "Jakarta"
check_node_exporter "${MJK_MESH}" "Mojokerto"
check_node_exporter "${SBY_MESH}" "Surabaya"

TARGETS_UP="$(curl -sfG "http://${MJK_MESH}:9090/api/v1/query" --data-urlencode 'query=count(up{job="node-exporter"}==1)' | python3 -c "import sys,json; r=json.load(sys.stdin)[\"data\"][\"result\"]; print(int(float(r[0][\"value\"][1])) if r else 0)" 2>/dev/null || echo 0)"
[[ "${TARGETS_UP}" -ge 3 ]] && ok "Three node exporters scraped (${TARGETS_UP})" || bad "Three node exporters scraped (${TARGETS_UP})"

CADVISOR_UP="$(curl -sfG "http://${MJK_MESH}:9090/api/v1/query" --data-urlencode 'query=count(up{job="cadvisor"}==1)' | python3 -c "import sys,json; r=json.load(sys.stdin)[\"data\"][\"result\"]; print(int(float(r[0][\"value\"][1])) if r else 0)" 2>/dev/null || echo 0)"
[[ "${CADVISOR_UP}" -ge 3 ]] && ok "Three cAdvisor targets scraped (${CADVISOR_UP})" || bad "Three cAdvisor targets scraped (${CADVISOR_UP})"

HTTP_UP="$(curl -sfG "http://${MJK_MESH}:9090/api/v1/query" --data-urlencode 'query=count(probe_success{job="blackbox-http"}==1)' | python3 -c "import sys,json; r=json.load(sys.stdin)[\"data\"][\"result\"]; print(int(float(r[0][\"value\"][1])) if r else 0)" 2>/dev/null || echo 0)"
[[ "${HTTP_UP}" -ge 4 ]] && ok "Public URL probes passing (${HTTP_UP})" || bad "Public URL probes passing (${HTTP_UP})"

GRAFANA_CODE="$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:${GRAFANA_PW}" "https://grafana.letsredi.com/api/org" 2>/dev/null || echo 000)"
[[ "${GRAFANA_CODE}" == "200" ]] && ok "Grafana HTTPS + auth (${GRAFANA_CODE})" || bad "Grafana HTTPS + auth (${GRAFANA_CODE})"

STATUS_CODE="$(curl -sk -o /dev/null -w '%{http_code}' https://status.letsredi.com/ 2>/dev/null || echo 000)"
[[ "${STATUS_CODE}" =~ ^(200|301|302)$ ]] && ok "status.letsredi.com (${STATUS_CODE})" || bad "status.letsredi.com (${STATUS_CODE})"

ALERTS="$(curl -sf "http://${MJK_MESH}:9093/api/v2/alerts" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)"
[[ "${ALERTS}" -ge 1 ]] && ok "Alertmanager receiving alerts (${ALERTS})" || bad "Alertmanager receiving alerts (${ALERTS})"

log_info "Validation complete: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
