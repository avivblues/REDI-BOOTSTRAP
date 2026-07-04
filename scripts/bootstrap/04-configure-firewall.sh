#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Configure UFW Firewall
# Default deny inbound. Allow SSH, HTTP, HTTPS, Tailscale.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
load_inventory

export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq ufw

HOSTNAME="$(hostname -s)"
SSH_PORT="${REDI_SSH_PORT:-22}"

# Detect SSH port from inventory based on hostname
case "${HOSTNAME}" in
  redi-sby-01|redi-mjk-01|redi-mgmt-01) SSH_PORT="${REDI_SBY_SSH_PORT:-2280}" ;;
  redi-jkt-01)              SSH_PORT="${REDI_JKT_SSH_PORT:-22}" ;;
esac

log_info "Configuring UFW for ${HOSTNAME} (SSH port: ${SSH_PORT})"

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow "${SSH_PORT}/tcp" comment 'SSH'

# HTTP/HTTPS — only on edge servers running Traefik
case "${HOSTNAME}" in
  redi-jkt-01|redi-sby-01)
    ufw allow 80/tcp comment 'HTTP for ACME challenge'
    ufw allow 443/tcp comment 'HTTPS Traefik'
    ufw allow 53/tcp comment 'DNS TCP'
    ufw allow 53/udp comment 'DNS UDP'
    ;;
esac

# Tailscale mesh — kernel TUN or userspace (Proxmox LXC)
if ip link show tailscale0 &>/dev/null; then
  ufw allow in on tailscale0 comment 'Tailscale mesh'
else
  log_warn "tailscale0 absent (userspace mode) — allowing Tailscale CGNAT range"
  ufw allow from 100.64.0.0/10 comment 'Tailscale mesh userspace'
fi

# Docker bridge — allow from Tailscale only for internal API access
ufw allow from 100.64.0.0/10 to any port 8081 proto tcp comment 'PowerDNS API internal'
ufw allow from 100.64.0.0/10 to any port 3306 proto tcp comment 'MariaDB replication internal'

ufw --force enable
ufw status verbose

log_info "UFW configured"
