#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Configure Docker Daemon (idempotent)
# Applies REDI baseline daemon.json without reinstalling Docker.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

if ! command -v docker &>/dev/null; then
  log_error "Docker not installed — run 02-install-docker.sh first"
  exit 1
fi

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "5"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF

systemctl enable docker
systemctl restart docker

# Wait for daemon
for i in 1 2 3 4 5 6 7 8 9 10; do
  if docker info &>/dev/null; then
    break
  fi
  sleep 2
done

if ! docker info &>/dev/null; then
  log_error "Docker daemon failed to start"
  exit 1
fi

log_info "Docker daemon configured: $(docker --version)"
log_info "Compose: $(docker compose version)"
log_info "Log driver: $(docker info --format '{{.LoggingDriver}}' 2>/dev/null || echo unknown)"
log_info "Live restore: $(docker info --format '{{.LiveRestoreEnabled}}' 2>/dev/null || echo unknown)"
