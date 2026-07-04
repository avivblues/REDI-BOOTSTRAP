#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Install Base Packages
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

export DEBIAN_FRONTEND=noninteractive

log_info "Updating package index"
apt-get update -qq

log_info "Installing base packages"
apt-get install -y -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  git \
  jq \
  netcat-openbsd \
  unzip \
  wget \
  htop \
  vim \
  logrotate \
  rsync

log_info "Base packages installed"
