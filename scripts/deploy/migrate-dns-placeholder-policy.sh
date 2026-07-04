#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Task 008C DNS Placeholder Policy Migration
# Policy migration only — DNS RRsets via MariaDB; no platform deploy.
# Usage: migrate-dns-placeholder-policy.sh [--env /opt/redi/compose/powerdns/.env] [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
POLICY="${SCRIPT_DIR}/../../config/powerdns/placeholder-policy.yaml"
ZONE_NAME="letsredi.com"
DRY_RUN=false
LOG_FILE="${SCRIPT_DIR}/../../logs/dns-008c-migrate-$(date +%Y%m%d-%H%M%S).log"

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

TTL=3600
INTERNAL_IP="${PDNS_INTERNAL_PLACEHOLDER_IP:-100.81.86.37}"
PLACEHOLDER_CNAME="placeholder.letsredi.com"
GATEWAY_CNAME="${PDNS_GATEWAY_CNAME:-proxy.letsredi.com}"

mkdir -p "$(dirname "${LOG_FILE}")"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "Task 008C — DNS placeholder policy migration for ${ZONE_NAME}"

DOMAIN_ID="$(docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
  -e "SELECT id FROM domains WHERE name='${ZONE_NAME}'" 2>/dev/null)"

[[ -n "${DOMAIN_ID}" ]] || { log_error "Zone not found"; exit 1; }

get_rr() {
  local name="$1"
  docker exec redi-mariadb mysql -N -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns \
    -e "SELECT CONCAT(type,'|',content,'|',ttl) FROM records WHERE domain_id=${DOMAIN_ID} AND name='${name}' LIMIT 1" 2>/dev/null || true
}

# Parse YAML lists (simple grep after section headers)
parse_list() {
  local section="$1"
  awk -v s="${section}:" '
    $0 ~ "^" s "$" { f=1; next }
    f && /^  - / { gsub(/^  - /, ""); print; next }
    f && /^[a-z][a-z0-9_]*:/ { exit }
  ' "${POLICY}"
}

SQL_FILE="$(mktemp)"
echo "SET @did=${DOMAIN_ID};" > "${SQL_FILE}"

MIGRATED=0
SKIPPED=0
LAB_SKIPPED=0
PROD_SKIPPED=0

migrate_public() {
  local name="$1"
  local cur target_type="CNAME" target_content="${PLACEHOLDER_CNAME}"
  cur="$(get_rr "${name}")"
  [[ -z "${cur}" ]] && return 0
  if [[ "${cur}" == "CNAME|${PLACEHOLDER_CNAME}|"* ]] || [[ "${cur}" == "CNAME|${PLACEHOLDER_CNAME}."* ]]; then
    log_info "SKIP (public ok): ${name} → ${PLACEHOLDER_CNAME}"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  log_info "MIGRATE public: ${name} was ${cur} → CNAME ${PLACEHOLDER_CNAME}"
  if [[ "${DRY_RUN}" != "true" ]]; then
    cat >> "${SQL_FILE}" <<EOSQL
DELETE FROM records WHERE domain_id=@did AND name='${name}';
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth)
VALUES (@did, '${name}', 'CNAME', '${PLACEHOLDER_CNAME}', ${TTL}, 0, 0, 1);
EOSQL
  fi
  MIGRATED=$((MIGRATED + 1))
}

migrate_internal() {
  local name="$1"
  local cur
  cur="$(get_rr "${name}")"
  [[ -z "${cur}" ]] && return 0
  if [[ "${cur}" == "A|${INTERNAL_IP}|"* ]]; then
    log_info "SKIP (internal ok): ${name} → ${INTERNAL_IP}"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  log_info "MIGRATE internal: ${name} was ${cur} → A ${INTERNAL_IP}"
  if [[ "${DRY_RUN}" != "true" ]]; then
    cat >> "${SQL_FILE}" <<EOSQL
DELETE FROM records WHERE domain_id=@did AND name='${name}';
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth)
VALUES (@did, '${name}', 'A', '${INTERNAL_IP}', ${TTL}, 0, 0, 1);
EOSQL
  fi
  MIGRATED=$((MIGRATED + 1))
}

# --- Anchor: placeholder.letsredi.com ---
anchor_cur="$(get_rr "${PLACEHOLDER_CNAME}")"
if [[ -z "${anchor_cur}" ]]; then
  log_info "CREATE anchor: ${PLACEHOLDER_CNAME} CNAME ${GATEWAY_CNAME}"
  if [[ "${DRY_RUN}" != "true" ]]; then
    cat >> "${SQL_FILE}" <<EOSQL
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth)
VALUES (@did, '${PLACEHOLDER_CNAME}', 'CNAME', '${GATEWAY_CNAME}', ${TTL}, 0, 0, 1);
EOSQL
  fi
  MIGRATED=$((MIGRATED + 1))
elif [[ "${anchor_cur}" == "CNAME|${GATEWAY_CNAME}|"* ]] || [[ "${anchor_cur}" == "CNAME|${GATEWAY_CNAME}."* ]]; then
  log_info "SKIP (anchor ok): ${PLACEHOLDER_CNAME}"
  SKIPPED=$((SKIPPED + 1))
else
  log_info "MIGRATE anchor: ${PLACEHOLDER_CNAME} was ${anchor_cur} → CNAME ${GATEWAY_CNAME}"
  if [[ "${DRY_RUN}" != "true" ]]; then
    cat >> "${SQL_FILE}" <<EOSQL
DELETE FROM records WHERE domain_id=@did AND name='${PLACEHOLDER_CNAME}';
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth)
VALUES (@did, '${PLACEHOLDER_CNAME}', 'CNAME', '${GATEWAY_CNAME}', ${TTL}, 0, 0, 1);
EOSQL
  fi
  MIGRATED=$((MIGRATED + 1))
fi

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  log_info "LAB protected: ${name}"
  LAB_SKIPPED=$((LAB_SKIPPED + 1))
done < <(parse_list lab)

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  log_info "PRODUCTION protected: ${name}"
  PROD_SKIPPED=$((PROD_SKIPPED + 1))
done < <(parse_list production)

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  migrate_public "${name}"
done < <(parse_list public_platform)

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  migrate_internal "${name}"
done < <(parse_list internal_platform)

if [[ "${DRY_RUN}" == "true" ]]; then
  rm -f "${SQL_FILE}"
  echo "LOG=${LOG_FILE} MIGRATED=${MIGRATED} SKIPPED=${SKIPPED} LAB=${LAB_SKIPPED} PROD=${PROD_SKIPPED}"
  exit 0
fi

if [[ "${MIGRATED}" -gt 0 ]]; then
  docker exec -i redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" powerdns < "${SQL_FILE}"
  docker exec redi-pdns-auth pdns_control reload
else
  log_info "No DNS changes required"
fi
rm -f "${SQL_FILE}"

log_info "Migration complete: ${MIGRATED} migrated, ${SKIPPED} already compliant, ${LAB_SKIPPED} LAB, ${PROD_SKIPPED} production protected"
echo "LOG=${LOG_FILE} MIGRATED=${MIGRATED} SKIPPED=${SKIPPED} LAB=${LAB_SKIPPED} PROD=${PROD_SKIPPED}"
