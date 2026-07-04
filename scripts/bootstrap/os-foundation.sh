#!/usr/bin/env bash
# =============================================================================
# REDI LAB — OS Foundation (Stage 1.2)
# Chrony + UFW + Fail2Ban only. Does not modify Docker or deploy containers.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${REDI_ROOT}/logs/os-foundation-$(date +%Y%m%d-%H%M%S).log"

source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_ubuntu_2204

mkdir -p "${REDI_ROOT}/logs"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "REDI OS foundation starting on $(hostname -f)"

run_step "${SCRIPT_DIR}/01-install-packages.sh"
run_step "${SCRIPT_DIR}/03-configure-chrony.sh"
run_step "${SCRIPT_DIR}/04-configure-firewall.sh"
run_step "${SCRIPT_DIR}/05-install-fail2ban.sh"

log_info "OS foundation complete on $(hostname -f)"
