#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Backup All Services
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

BACKUP_DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${REDI_ROOT}/backup/${BACKUP_DATE}"
HOSTNAME="$(hostname -s)"

mkdir -p "${BACKUP_DIR}"
log_info "Starting backup on ${HOSTNAME} → ${BACKUP_DIR}"

backup_powerdns() {
  if docker ps --format '{{.Names}}' | grep -q '^redi-mariadb$'; then
    log_info "Backing up PowerDNS MariaDB"
  # shellcheck source=/dev/null
    source "${REDI_ROOT}/compose/powerdns/.env" 2>/dev/null || true
    docker exec redi-mariadb mysqldump \
      -uroot -p"${MARIADB_ROOT_PASSWORD}" \
      --single-transaction \
      --routines \
      --triggers \
      "${MARIADB_DATABASE:-powerdns}" \
      | gzip > "${BACKUP_DIR}/powerdns-mariadb.sql.gz"
  fi
}

backup_traefik() {
  if [[ -f "${REDI_ROOT}/config/traefik/acme.json" ]]; then
    log_info "Backing up Traefik ACME certificates"
    cp "${REDI_ROOT}/config/traefik/acme.json" "${BACKUP_DIR}/traefik-acme.json"
    chmod 600 "${BACKUP_DIR}/traefik-acme.json"
  fi
  tar czf "${BACKUP_DIR}/traefik-config.tar.gz" \
    -C "${REDI_ROOT}/config" traefik/
}

backup_portainer() {
  if [[ -d "${REDI_ROOT}/data/portainer" ]]; then
    log_info "Backing up Portainer data"
    tar czf "${BACKUP_DIR}/portainer-data.tar.gz" \
      -C "${REDI_ROOT}/data" portainer/
  fi
}

backup_gitlab() {
  if docker ps --format '{{.Names}}' | grep -q '^redi-gitlab$'; then
    log_info "Backing up GitLab (this may take several minutes)"
    docker exec redi-gitlab gitlab-backup create STRATEGY=copy SKIP=registry,artifacts,builds,pages
    LATEST_BACKUP="$(docker exec redi-gitlab ls -t /var/opt/gitlab/backups/ | head -1)"
    docker cp "redi-gitlab:/var/opt/gitlab/backups/${LATEST_BACKUP}" \
      "${BACKUP_DIR}/gitlab-${LATEST_BACKUP}"
    docker cp redi-gitlab:/etc/gitlab/gitlab.rb \
      "${BACKUP_DIR}/gitlab.rb"
    docker cp redi-gitlab:/etc/gitlab/gitlab-secrets.json \
      "${BACKUP_DIR}/gitlab-secrets.json" 2>/dev/null || true
  fi
}

backup_shared_postgres() {
  if docker ps --format '{{.Names}}' | grep -q '^redi-postgres$'; then
    log_info "Backing up shared PostgreSQL"
    # shellcheck source=/dev/null
    source "${REDI_ROOT}/compose/shared-platform/.env" 2>/dev/null || true
    docker exec -e PGPASSWORD="${POSTGRES_SUPERUSER_PASSWORD}" redi-postgres \
      pg_dumpall -U postgres | gzip > "${BACKUP_DIR}/shared-postgres-all.sql.gz"
  fi
}

backup_shared_redis() {
  if [[ -d "${REDI_ROOT}/data/shared-platform/redis" ]]; then
    log_info "Backing up shared Redis AOF data"
    tar czf "${BACKUP_DIR}/shared-redis-data.tar.gz" \
      -C "${REDI_ROOT}/data/shared-platform" redis/
  fi
}

backup_shared_minio() {
  if docker ps --format '{{.Names}}' | grep -q '^redi-minio$'; then
    log_info "Backing up MinIO bucket inventory"
    # shellcheck source=/dev/null
    source "${REDI_ROOT}/compose/shared-platform/.env" 2>/dev/null || true
    docker run --rm --network host --entrypoint /bin/sh minio/mc:latest -c "
      mc alias set redi http://127.0.0.1:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
      mc ls -r redi > /dev/stdout
    " > "${BACKUP_DIR}/minio-inventory.txt" 2>/dev/null || true
  fi
}

case "${HOSTNAME}" in
  redi-jkt-01|redi-sby-01)
    backup_powerdns
    backup_traefik
    ;;
  redi-mgmt-01|redi-mjk-01)
    backup_portainer
    backup_shared_postgres
    backup_shared_redis
    backup_shared_minio
    backup_gitlab
    if [[ -f "${REDI_ROOT}/scripts/backup/backup-authentik.sh" ]]; then
      bash "${REDI_ROOT}/scripts/backup/backup-authentik.sh" "${BACKUP_DATE}"
    fi
    ;;
esac

# Manifest
cat > "${BACKUP_DIR}/manifest.json" <<EOF
{
  "hostname": "${HOSTNAME}",
  "timestamp": "${BACKUP_DATE}",
  "created_at": "$(date -Is)",
  "services": $(ls -1 "${BACKUP_DIR}" | jq -R . | jq -s .)
}
EOF

log_info "Backup complete: ${BACKUP_DIR}"
du -sh "${BACKUP_DIR}"
