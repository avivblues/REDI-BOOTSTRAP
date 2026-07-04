#!/usr/bin/env bash
# REDI LAB — Remote precheck collector (runs on target server)
set -euo pipefail

echo "=== HOSTNAME ==="
hostname -f 2>/dev/null || hostname

echo "=== UBUNTU_VERSION ==="
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  echo "${PRETTY_NAME:-unknown}"
  echo "VERSION_ID=${VERSION_ID:-unknown}"
fi

echo "=== KERNEL ==="
uname -r
uname -m

echo "=== CPU ==="
nproc 2>/dev/null || echo "unknown"
lscpu 2>/dev/null | grep "Model name" | sed 's/^[ \t]*//' || true

echo "=== RAM ==="
free -h | awk '/^Mem:/ {print $2 " total, " $3 " used, " $7 " available"}'

echo "=== DISK ==="
df -hT / /opt 2>/dev/null | tail -n +2

echo "=== FILESYSTEM ==="
findmnt -no SOURCE,FSTYPE,OPTIONS / 2>/dev/null || mount | grep "on / "

echo "=== DOCKER ==="
if command -v docker &>/dev/null; then
  docker --version
  systemctl is-active docker 2>/dev/null || echo "inactive"
else
  echo "NOT_INSTALLED"
fi

echo "=== DOCKER_COMPOSE ==="
if docker compose version &>/dev/null; then
  docker compose version
elif command -v docker-compose &>/dev/null; then
  docker-compose --version
else
  echo "NOT_INSTALLED"
fi

echo "=== GIT ==="
git --version 2>/dev/null || echo "NOT_INSTALLED"

echo "=== UFW ==="
if command -v ufw &>/dev/null; then
  ufw status verbose 2>/dev/null | head -5 || echo "ufw present, needs root"
else
  echo "NOT_INSTALLED"
fi

echo "=== FAIL2BAN ==="
if command -v fail2ban-client &>/dev/null; then
  systemctl is-active fail2ban 2>/dev/null || echo "inactive"
  fail2ban-client status 2>/dev/null | head -3 || true
else
  echo "NOT_INSTALLED"
fi

echo "=== TAILSCALE ==="
if command -v tailscale &>/dev/null; then
  tailscale version 2>/dev/null | head -1 || true
  tailscale status 2>/dev/null | head -5 || echo "not connected"
else
  echo "NOT_INSTALLED"
fi

echo "=== OPEN_PORTS ==="
ss -tulnp 2>/dev/null | grep LISTEN || netstat -tulnp 2>/dev/null | grep LISTEN || echo "requires root for process names"

echo "=== TIME_SYNC ==="
if command -v chronyc &>/dev/null; then
  chronyc tracking 2>/dev/null | grep -E "Reference ID|System time|Leap status" || chronyc tracking
elif command -v timedatectl &>/dev/null; then
  timedatectl status
else
  date -Is
fi

echo "=== SUDO ==="
if [[ "${EUID}" -eq 0 ]]; then
  echo "root"
elif sudo -n true 2>/dev/null; then
  echo "passwordless_sudo"
else
  echo "sudo_required"
fi

echo "=== OPT_REDI ==="
ls -la /opt/redi 2>/dev/null || echo "NOT_PRESENT"
