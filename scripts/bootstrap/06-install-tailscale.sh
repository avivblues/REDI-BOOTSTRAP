#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Install Tailscale
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

if command -v tailscale &>/dev/null; then
  log_info "Tailscale already installed: $(tailscale version | head -1)"
  exit 0
fi

log_info "Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh

systemctl enable tailscaled
systemctl start tailscaled

log_info "Tailscale installed. Run configure-tailscale.sh to join the mesh."
