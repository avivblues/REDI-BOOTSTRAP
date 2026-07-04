#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Apply letsredi.com DNS Blueprint (Task 008A)
# Creates ONLY missing records. Never overwrites existing RRsets.
# Never modifies SOA, NS, or glue (ns1/ns2).
# Usage: apply-dns-blueprint.sh [--env /opt/redi/compose/powerdns/.env] [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
BLUEPRINT="${SCRIPT_DIR}/../../config/powerdns/letsredi-blueprint.yaml"
ZONE_NAME="letsredi.com"
DRY_RUN=false
REPORT_FILE="${SCRIPT_DIR}/../../logs/dns-blueprint-apply-$(date +%Y%m%d-%H%M%S).json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# shellcheck source=/dev/null
source "${ENV_FILE}"

require_root

if [[ ! -f "${BLUEPRINT}" ]]; then
  log_error "Blueprint not found: ${BLUEPRINT}"
  exit 1
fi

JKT_PUBLIC="${PDNS_NS1_IP:-103.149.238.98}"
SBY_PUBLIC="${PDNS_NS2_IP:-103.80.214.144}"
JKT_MESH="${PDNS_NS1_MESH_IP:-100.79.82.92}"
SBY_MESH="${PDNS_NS2_MESH_IP:-100.67.138.25}"
MJK_MESH="${PDNS_MGMT_MESH_IP:-100.81.86.37}"
GATEWAY_PUBLIC="${PDNS_GATEWAY_IP:-103.149.238.98}"

substitute() {
  local v="$1"
  v="${v//\{jkt_public\}/${JKT_PUBLIC}}"
  v="${v//\{sby_public\}/${SBY_PUBLIC}}"
  v="${v//\{jkt_mesh\}/${JKT_MESH}}"
  v="${v//\{sby_mesh\}/${SBY_MESH}}"
  v="${v//\{mjk_mesh\}/${MJK_MESH}}"
  v="${v//\{gateway_public\}/${GATEWAY_PUBLIC}}"
  v="${v//\{gateway_cname\}/proxy.letsredi.com}"
  echo "${v}"
}

log_info "Task 008A — applying DNS blueprint for ${ZONE_NAME} (missing records only)"

DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
  -e "SELECT id FROM domains WHERE name='${ZONE_NAME}'" 2>/dev/null || true)"

if [[ -z "${DOMAIN_ID}" ]]; then
  log_error "Zone ${ZONE_NAME} not found — run create-production-zone.sh first"
  exit 1
fi

record_exists() {
  local name="$1" rtype="$2"
  docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
    -e "SELECT COUNT(*) FROM records WHERE domain_id=${DOMAIN_ID} AND name='${name}' AND type='${rtype}'" 2>/dev/null
}

is_protected() {
  local name="$1" rtype="$2"
  case "${name}" in
    ns1.letsredi.com|ns2.letsredi.com) return 0 ;;
    letsredi.com)
      [[ "${rtype}" == "SOA" || "${rtype}" == "NS" ]] && return 0
      ;;
  esac
  return 1
}

APPLIED=0
SKIPPED=0
PROTECTED=0
PLACEHOLDERS=0
CONFLICTS=0

SQL_FILE="$(mktemp)"
echo "SET @did=${DOMAIN_ID};" > "${SQL_FILE}"

APPLIED_LIST=()
SKIPPED_LIST=()
PROTECTED_LIST=()
CONFLICT_LIST=()

in_records=false
current_name="" current_type="" current_value="" current_ttl="3600" current_status="production" current_note=""

flush_record() {
  [[ -z "${current_name}" || -z "${current_type}" ]] && return

  if is_protected "${current_name}" "${current_type}"; then
    log_info "PROTECTED (SOA/NS/glue): ${current_name} ${current_type}"
    PROTECTED_LIST+=("${current_name}|${current_type}|protected")
    PROTECTED=$((PROTECTED + 1))
    current_name=""
    return
  fi

  local val count existing_content
  val="$(substitute "${current_value}")"
  count="$(record_exists "${current_name}" "${current_type}")"

  if [[ "${count}" -gt 0 ]]; then
    existing_content="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
      -e "SELECT content FROM records WHERE domain_id=${DOMAIN_ID} AND name='${current_name}' AND type='${current_type}' LIMIT 1" 2>/dev/null || true)"
    if [[ "${existing_content}" != "${val}" ]]; then
      log_warn "SKIP (exists, conflict): ${current_name} ${current_type} have=${existing_content} blueprint=${val}"
      CONFLICT_LIST+=("${current_name}|${current_type}|${existing_content}|${val}")
      CONFLICTS=$((CONFLICTS + 1))
    else
      log_info "SKIP (exists): ${current_name} ${current_type} ${existing_content}"
    fi
    SKIPPED_LIST+=("${current_name}|${current_type}|${existing_content}|${current_status}")
    SKIPPED=$((SKIPPED + 1))
    current_name=""
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "DRY-RUN CREATE: ${current_name} ${current_type} ${val} ttl=${current_ttl} [${current_status}]"
    APPLIED_LIST+=("${current_name}|${current_type}|${val}|${current_status}")
    APPLIED=$((APPLIED + 1))
    [[ "${current_status}" == "placeholder" ]] && PLACEHOLDERS=$((PLACEHOLDERS + 1))
    current_name=""
    return
  fi

  cat >> "${SQL_FILE}" <<EOSQL
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth)
VALUES (@did, '${current_name}', '${current_type}', '${val}', ${current_ttl}, 0, 0, 1);
EOSQL

  log_info "CREATE: ${current_name} ${current_type} ${val} ttl=${current_ttl} [${current_status}]"
  APPLIED_LIST+=("${current_name}|${current_type}|${val}|${current_status}")
  APPLIED=$((APPLIED + 1))
  [[ "${current_status}" == "placeholder" ]] && PLACEHOLDERS=$((PLACEHOLDERS + 1))
  current_name=""
}

while IFS= read -r line; do
  line="${line%%#*}"
  line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "${line}" ]] && continue

  if [[ "${line}" == "records:" ]]; then
    in_records=true
    continue
  fi
  [[ "${in_records}" != "true" ]] && continue

  if [[ "${line}" == "- name:"* ]]; then
    flush_record
    current_name="$(echo "${line}" | sed 's/- name: //;s/"//g')"
    current_type="" current_value="" current_ttl="3600" current_status="production" current_note=""
  elif [[ "${line}" == "type:"* ]]; then
    current_type="$(echo "${line}" | sed 's/type: //')"
  elif [[ "${line}" == "value:"* ]]; then
    current_value="$(echo "${line}" | sed 's/value: //;s/"//g')"
  elif [[ "${line}" == "ttl:"* ]]; then
    current_ttl="$(echo "${line}" | sed 's/ttl: //')"
  elif [[ "${line}" == "status:"* ]]; then
    current_status="$(echo "${line}" | sed 's/status: //')"
  fi
done < "${BLUEPRINT}"

flush_record

mkdir -p "$(dirname "${REPORT_FILE}")"
{
  echo "{"
  echo "  \"zone\": \"${ZONE_NAME}\","
  echo "  \"applied\": ${APPLIED},"
  echo "  \"skipped\": ${SKIPPED},"
  echo "  \"protected\": ${PROTECTED},"
  echo "  \"conflicts\": ${CONFLICTS},"
  echo "  \"placeholders_created\": ${PLACEHOLDERS},"
  echo "  \"dry_run\": ${DRY_RUN}"
  echo "}"
} > "${REPORT_FILE}"

if [[ "${DRY_RUN}" == "true" ]]; then
  rm -f "${SQL_FILE}"
  echo "REPORT=${REPORT_FILE} APPLIED=${APPLIED} SKIPPED=${SKIPPED} PROTECTED=${PROTECTED} CONFLICTS=${CONFLICTS} PLACEHOLDERS=${PLACEHOLDERS}"
  exit 0
fi

if [[ "${APPLIED}" -gt 0 ]]; then
  docker exec -i redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns < "${SQL_FILE}"
  docker exec redi-pdns-auth pdns_control reload
else
  log_info "No new records to insert — zone unchanged"
fi

rm -f "${SQL_FILE}"

log_info "Blueprint apply complete: ${APPLIED} created (${PLACEHOLDERS} placeholders), ${SKIPPED} skipped, ${PROTECTED} protected, ${CONFLICTS} conflicts"
echo "REPORT=${REPORT_FILE} APPLIED=${APPLIED} SKIPPED=${SKIPPED} PROTECTED=${PROTECTED} CONFLICTS=${CONFLICTS} PLACEHOLDERS=${PLACEHOLDERS}"
