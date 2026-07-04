#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Create Directory Structure
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

DIRS=(
  "${REDI_ROOT}/compose/powerdns"
  "${REDI_ROOT}/compose/traefik"
  "${REDI_ROOT}/compose/portainer"
  "${REDI_ROOT}/compose/gitlab"
  "${REDI_ROOT}/config/powerdns"
  "${REDI_ROOT}/config/traefik/dynamic"
  "${REDI_ROOT}/config/gitlab"
  "${REDI_ROOT}/data/powerdns/mariadb"
  "${REDI_ROOT}/data/powerdns/mariadb-replica"
  "${REDI_ROOT}/data/traefik"
  "${REDI_ROOT}/data/portainer"
  "${REDI_ROOT}/data/gitlab/config"
  "${REDI_ROOT}/data/gitlab/logs"
  "${REDI_ROOT}/data/gitlab/data"
  "${REDI_ROOT}/backup/powerdns"
  "${REDI_ROOT}/backup/traefik"
  "${REDI_ROOT}/backup/portainer"
  "${REDI_ROOT}/backup/gitlab"
  "${REDI_ROOT}/logs/powerdns"
  "${REDI_ROOT}/logs/traefik"
  "${REDI_ROOT}/logs/portainer"
  "${REDI_ROOT}/logs/gitlab"
  "${REDI_ROOT}/scripts/backup"
  "${REDI_ROOT}/scripts/restore"
  "${REDI_ROOT}/docs/runbooks"
)

for dir in "${DIRS[@]}"; do
  mkdir -p "${dir}"
done

# Traefik ACME store — restricted permissions
touch "${REDI_ROOT}/config/traefik/acme.json"
chmod 600 "${REDI_ROOT}/config/traefik/acme.json"

# Set ownership for Docker volumes
chown -R root:root "${REDI_ROOT}"
chmod 750 "${REDI_ROOT}"
chmod -R 750 "${REDI_ROOT}/data"
chmod -R 750 "${REDI_ROOT}/backup"
chmod -R 750 "${REDI_ROOT}/logs"

log_info "Directory structure created under ${REDI_ROOT}"
