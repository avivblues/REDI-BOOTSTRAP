#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Restore GitLab from Backup
# Usage: restore-gitlab.sh /path/to/gitlab-backup.tar /path/to/gitlab-secrets.json
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

BACKUP_FILE="${1:-}"
SECRETS_FILE="${2:-}"

if [[ -z "${BACKUP_FILE}" ]] || [[ ! -f "${BACKUP_FILE}" ]]; then
  log_error "Usage: restore-gitlab.sh /path/to/gitlab-backup.tar [/path/to/gitlab-secrets.json]"
  exit 1
fi

log_warn "This will overwrite GitLab data. Continue in 15 seconds (Ctrl+C to abort)..."
sleep 15

BACKUP_NAME="$(basename "${BACKUP_FILE}")"
docker cp "${BACKUP_FILE}" "redi-gitlab:/var/opt/gitlab/backups/${BACKUP_NAME}"

if [[ -n "${SECRETS_FILE}" ]] && [[ -f "${SECRETS_FILE}" ]]; then
  docker cp "${SECRETS_FILE}" redi-gitlab:/etc/gitlab/gitlab-secrets.json
fi

BACKUP_ID="${BACKUP_NAME%_gitlab_backup.tar}"

log_info "Stopping GitLab services for restore"
docker exec redi-gitlab gitlab-ctl stop puma
docker exec redi-gitlab gitlab-ctl stop sidekiq

log_info "Restoring GitLab backup: ${BACKUP_ID}"
docker exec redi-gitlab gitlab-backup restore BACKUP="${BACKUP_ID}" force=yes

log_info "Reconfiguring and restarting GitLab"
docker exec redi-gitlab gitlab-ctl reconfigure
docker exec redi-gitlab gitlab-ctl restart

log_info "GitLab restore complete. Verify at ${GITLAB_EXTERNAL_URL:-https://gitlab.redi.lab}"
