# REDI LAB — Backup Guide

## Overview

Backups are service-specific and run per-server based on hostname. The master script `scripts/backup/backup-all.sh` detects the server role and backs up relevant data.

## Backup Schedule

Recommended: daily at 02:00 local time (Asia/Jakarta).

```bash
0 2 * * * /opt/redi/scripts/backup/backup-all.sh >> /opt/redi/logs/backup.log 2>&1
```

## Backup Locations

```
/opt/redi/backup/
└── YYYYMMDD-HHMMSS/
    ├── manifest.json
    ├── powerdns-mariadb.sql.gz      # edge nodes
    ├── traefik-acme.json            # edge nodes
    ├── traefik-config.tar.gz        # edge nodes
    ├── portainer-data.tar.gz        # mgmt node
    ├── gitlab-*_gitlab_backup.tar   # mgmt node
    ├── gitlab.rb                    # mgmt node
    └── gitlab-secrets.json          # mgmt node
```

## Service-Specific Backups

### PowerDNS / MariaDB

**What:** Full database dump of `powerdns` schema including zones and records.

**Method:** `mysqldump` with `--single-transaction` for consistency.

**Retention:** Keep 30 daily backups minimum.

**Critical data:**
- DNS zones and records
- DNSSEC keys (in `cryptokeys` table)
- Domain metadata

### Traefik

**What:**
- `acme.json` — Let's Encrypt certificates
- Static and dynamic configuration files

**Method:** File copy and tar archive.

**Note:** Certificates can be re-issued via ACME, but backing up avoids rate limits during recovery.

### Portainer

**What:** `/data/portainer/` volume containing settings, users, and endpoint configurations.

**Method:** tar archive.

### GitLab CE

**What:**
- GitLab application backup (repositories, database, uploads, CI/CD artifacts)
- `gitlab.rb` configuration
- `gitlab-secrets.json` (encryption keys — **critical**)

**Method:** `gitlab-backup create` inside container.

**Skip:** registry, artifacts (if not used), builds, pages.

```bash
docker exec redi-gitlab gitlab-backup create STRATEGY=copy SKIP=registry,artifacts,builds,pages
```

## Off-Site Backup

Copy backups to external storage after each run:

```bash
# Example: rsync to remote backup server via Tailscale
rsync -avz --delete /opt/redi/backup/ backup@redi-backup:/redi-lab/
```

## Backup Verification

Monthly verification procedure:

1. Restore PowerDNS backup to a test MariaDB instance
2. Verify zone record count matches production
3. Restore GitLab backup to a staging environment
4. Verify repository access and CI/CD configuration
5. Confirm `gitlab-secrets.json` matches backup

## Encryption

For off-site storage, encrypt backups:

```bash
gpg --symmetric --cipher-algo AES256 backup.tar.gz
```

Store the GPG passphrase in your secrets vault, not on the server.

## Monitoring

Phase 2 will add backup success/failure alerts via Prometheus. Until then, check backup logs:

```bash
tail -50 /opt/redi/logs/backup.log
ls -la /opt/redi/backup/ | tail -5
```
