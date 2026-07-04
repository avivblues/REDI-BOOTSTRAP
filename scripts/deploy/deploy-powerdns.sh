#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Deploy PowerDNS Stack
# Usage: deploy-powerdns.sh --role primary|replica
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="${REDI_ROOT}/compose/powerdns"
source "${SCRIPT_DIR}/../lib/common.sh"

ROLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "${ROLE}" ]] || [[ "${ROLE}" != "primary" && "${ROLE}" != "replica" ]]; then
  log_error "Usage: deploy-powerdns.sh --role primary|replica"
  exit 1
fi

require_root

configure_dns_stub_listener() {
  local conf="/etc/systemd/resolved.conf"
  if grep -qE '^DNSStubListener=no' "${conf}" 2>/dev/null; then
    log_info "DNSStubListener already disabled"
    return
  fi
  if ! grep -qE '^\[Resolve\]' "${conf}"; then
    printf '\n[Resolve]\n' >> "${conf}"
  fi
  if grep -qE '^#?DNSStubListener=' "${conf}"; then
    sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' "${conf}"
  else
    echo 'DNSStubListener=no' >> "${conf}"
  fi
  if ! grep -qE '^DNS=' "${conf}"; then
    echo 'DNS=8.8.8.8 1.1.1.1' >> "${conf}"
  fi
  systemctl restart systemd-resolved
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null || true
  log_info "Disabled DNS stub listener; using upstream DNS for resolver"
}

configure_dns_stub_listener

ENV_FILE="${COMPOSE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log_error "Missing ${ENV_FILE}. Copy from .env.example and configure."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

# Validate role matches env
if [[ "${PDNS_NODE_ROLE}" != "${ROLE}" ]]; then
  log_warn "Overriding PDNS_NODE_ROLE=${PDNS_NODE_ROLE} with --role ${ROLE}"
  sed -i "s/^PDNS_NODE_ROLE=.*/PDNS_NODE_ROLE=${ROLE}/" "${ENV_FILE}"
  source "${ENV_FILE}"
fi

# Set Tailscale IP dynamically if not configured
if [[ -z "${PDNS_TAILSCALE_IP:-}" ]] || [[ "${PDNS_TAILSCALE_IP}" == "100.64.0."* ]]; then
  TS_IP="$(get_tailscale_ip)"
  sed -i "s/^PDNS_TAILSCALE_IP=.*/PDNS_TAILSCALE_IP=${TS_IP}/" "${ENV_FILE}"
  source "${ENV_FILE}"
fi

# Make init scripts executable
chmod +x "${REDI_ROOT}/config/powerdns/init-primary.sh"
chmod +x "${REDI_ROOT}/config/powerdns/init-replica.sh"

# Render PowerDNS config from template
export MARIADB_PDNS_USER MARIADB_PDNS_PASSWORD MARIADB_DATABASE
export PDNS_API_KEY PDNS_WEBSERVER_ADDRESS PDNS_WEBSERVER_PORT PDNS_WEBSERVER_ALLOW_FROM
export PDNS_HOSTNAME PDNS_SOA_RNAME PDNS_SOA_REFRESH PDNS_SOA_RETRY PDNS_SOA_EXPIRE PDNS_SOA_MINIMUM
export MARIADB_HOST="mariadb"
envsubst < "${REDI_ROOT}/config/powerdns/pdns.conf.template" \
  > "${REDI_ROOT}/config/powerdns/pdns.conf"
chmod 644 "${REDI_ROOT}/config/powerdns/pdns.conf"

# Ensure MariaDB data/log dirs are writable by container mysql user (999)
mkdir -p "${REDI_ROOT}/data/powerdns/mariadb" "${REDI_ROOT}/logs/powerdns/mariadb" "${REDI_ROOT}/logs/powerdns/pdns"
chown -R 999:999 "${REDI_ROOT}/data/powerdns/mariadb" "${REDI_ROOT}/logs/powerdns/mariadb" 2>/dev/null || true

ensure_docker_network "redi-dns" "172.28.0.0/24"

apt-get install -y -qq gettext-base 2>/dev/null || apt-get install -y -qq gettext 2>/dev/null || true

log_info "Deploying PowerDNS stack (role: ${ROLE})"
cd "${COMPOSE_DIR}"

COMPOSE_FILES=(-f docker-compose.yml)
if [[ "${ROLE}" == "replica" ]]; then
  COMPOSE_FILES=(-f docker-compose.replica-stack.yml)
fi

docker compose --env-file "${ENV_FILE}" "${COMPOSE_FILES[@]}" pull
docker compose --env-file "${ENV_FILE}" "${COMPOSE_FILES[@]}" up -d

# Wait for health
sleep 10

if [[ "${ROLE}" == "replica" ]]; then
  log_info "Replica mode: local MariaDB slave + PowerDNS (primary at ${MARIADB_PRIMARY_HOST})"
  wait_for_service "${MARIADB_PRIMARY_HOST}" "${MARIADB_PORT:-3306}" 120
  chmod +x "${SCRIPT_DIR}/setup-mariadb-replication.sh"
  "${SCRIPT_DIR}/setup-mariadb-replication.sh"
fi

docker compose --env-file "${ENV_FILE}" "${COMPOSE_FILES[@]}" ps

log_info "PowerDNS deployment complete"
log_info "Verify: dig @$(hostname -I | awk '{print $1}') ${REDI_DOMAIN:-redi.lab} SOA"
