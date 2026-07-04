#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Configure Chrony NTP
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq chrony

# Disable systemd-timesyncd when present (conflicts with chrony)
if systemctl is-enabled systemd-timesyncd &>/dev/null; then
  systemctl stop systemd-timesyncd 2>/dev/null || true
  systemctl disable systemd-timesyncd 2>/dev/null || true
fi

cat > /etc/chrony/chrony.conf <<'EOF'
# REDI LAB — Chrony configuration
# Use public NTP pools with local fallback

pool 0.id.pool.ntp.org iburst maxsources 4
pool 1.id.pool.ntp.org iburst maxsources 4
pool 2.id.pool.ntp.org iburst maxsources 4
pool 3.id.pool.ntp.org iburst maxsources 4

# Allow monitoring from Tailscale subnet
allow 100.64.0.0/10

# Record rate and reachability
driftfile /var/lib/chrony/drift

# Enable kernel RTC sync
rtcsync

# Leap seconds
leapsectz right/UTC

# Log directory
logdir /var/log/chrony
EOF

systemctl enable chrony
systemctl restart chrony

log_info "Chrony configured and running"
chronyc tracking
