#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Master Bootstrap Script
# Installs Docker CE, security tooling, and base packages on Ubuntu 22.04 LTS
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${REDI_ROOT}/logs/bootstrap-$(date +%Y%m%d-%H%M%S).log"

# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_ubuntu_2204

mkdir -p "${REDI_ROOT}/logs"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "REDI LAB bootstrap starting on $(hostname -f)"
log_info "Log file: ${LOG_FILE}"

run_step "${SCRIPT_DIR}/01-install-packages.sh"
run_step "${SCRIPT_DIR}/02-install-docker.sh"
run_step "${SCRIPT_DIR}/03-configure-chrony.sh"
run_step "${SCRIPT_DIR}/04-configure-firewall.sh"
run_step "${SCRIPT_DIR}/05-install-fail2ban.sh"
run_step "${SCRIPT_DIR}/06-install-tailscale.sh"
run_step "${SCRIPT_DIR}/07-create-directories.sh"

log_info "Bootstrap complete. Next: configure Tailscale with configure-tailscale.sh"
