#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Configure Tailscale Mesh
# Joins the node to the Tailscale network with hostname and routes.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
load_inventory

require_root

if [[ -z "${TAILSCALE_AUTH_KEY:-}" ]] || [[ "${TAILSCALE_AUTH_KEY}" == *"REPLACE_ME"* ]]; then
  log_error "Set TAILSCALE_AUTH_KEY in inventory/servers.env before running this script"
  exit 1
fi

HOSTNAME="$(hostname -s)"
TS_HOSTNAME="${HOSTNAME}"

# Map hostname to inventory variable for advertised tags
case "${HOSTNAME}" in
  redi-jkt-01)  TS_TAGS="tag:redi-edge,tag:redi-dns" ;;
  redi-mjk-01)  TS_TAGS="tag:redi-management" ;;
  redi-sby-01)  TS_TAGS="tag:redi-edge,tag:redi-dns" ;;
  *)            TS_TAGS="tag:redi-infra" ;;
esac

log_info "Joining Tailscale mesh as ${TS_HOSTNAME}"

tailscale up \
  --authkey="${TAILSCALE_AUTH_KEY}" \
  --hostname="${TS_HOSTNAME}" \
  --accept-routes \
  --accept-dns=false \
  --ssh \
  --reset

TS_IP="$(tailscale ip -4)"
log_info "Tailscale IP: ${TS_IP}"

# Persist Tailscale IP for other services
cat > "${REDI_ROOT}/config/tailscale/node.env" <<EOF
TAILSCALE_HOSTNAME=${TS_HOSTNAME}
TAILSCALE_IP=${TS_IP}
TAILSCALE_CONFIGURED_AT=$(date -Is)
EOF
chmod 600 "${REDI_ROOT}/config/tailscale/node.env"

# Enable IP forwarding for edge DNS servers
case "${HOSTNAME}" in
  redi-jkt-01|redi-sby-01)
    sysctl -w net.ipv4.ip_forward=1
    grep -q 'net.ipv4.ip_forward' /etc/sysctl.d/99-redi.conf 2>/dev/null || \
      echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-redi.conf
    ;;
esac

log_info "Tailscale configuration complete"
tailscale status
