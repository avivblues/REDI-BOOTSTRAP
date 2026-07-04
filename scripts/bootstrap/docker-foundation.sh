#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Docker Foundation (Stage 1.3)
# Validates/installs Docker, configures daemon, directories, networks.
# Does NOT deploy application containers.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${REDI_ROOT}/logs/docker-foundation-$(date +%Y%m%d-%H%M%S).log"

source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_ubuntu_2204

mkdir -p "${REDI_ROOT}/logs"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "REDI Docker foundation starting on $(hostname -f)"

# Install if missing (no upgrade if already present)
run_step "${SCRIPT_DIR}/02-install-docker.sh"
run_step "${SCRIPT_DIR}/configure-docker-daemon.sh"
run_step "${SCRIPT_DIR}/07-create-directories.sh"
run_step "${SCRIPT_DIR}/create-docker-networks.sh"

log_info "Docker foundation complete on $(hostname -f)"
