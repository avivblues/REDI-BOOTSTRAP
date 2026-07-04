#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Configure Fail2Ban
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq fail2ban

HOSTNAME="$(hostname -s)"
SSH_PORT="22"
case "${HOSTNAME}" in
  redi-sby-01|redi-mjk-01|redi-mgmt-01) SSH_PORT="2280" ;;
esac

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd
banaction = ufw

[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 7200
EOF

systemctl enable fail2ban
systemctl restart fail2ban

sleep 2
for i in 1 2 3 4 5; do
  if fail2ban-client status sshd &>/dev/null; then
    break
  fi
  sleep 2
done

log_info "Fail2Ban configured for SSH port ${SSH_PORT}"
fail2ban-client status sshd 2>/dev/null || log_warn "Fail2Ban installed; sshd jail pending first start"
