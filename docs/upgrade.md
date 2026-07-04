# REDI LAB — Upgrade Guide

## General Upgrade Procedure

1. Read release notes for the target version
2. Take a full backup (`scripts/backup/backup-all.sh`)
3. Upgrade one service at a time
4. Verify health after each upgrade
5. Document the upgrade in change log

## Docker Engine Upgrade

```bash
sudo apt-get update
sudo apt-get install --only-upgrade docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl restart docker
docker version
```

## PowerDNS Upgrade

### Pre-check
```bash
cd /opt/redi/compose/powerdns
docker compose ps
docker exec redi-mariadb mysql -uroot -p -e "SHOW SLAVE STATUS\G"
```

### Upgrade primary first, then replica

```bash
# Update PDNS_IMAGE in .env (e.g., powerdns/pdns-auth-48:4.8.5)
cd /opt/redi/compose/powerdns
docker compose pull
docker compose up -d
docker exec redi-pdns-auth pdns_control rping
```

Repeat on replica node after primary is healthy.

## MariaDB Upgrade

MariaDB minor version upgrades (10.11.x → 10.11.y):

```bash
# Update MARIADB_IMAGE in .env
docker compose stop pdns-auth
docker compose pull mariadb
docker compose up -d mariadb
# Wait for health check
docker compose up -d pdns-auth
```

Major version upgrades require `mariadb-upgrade` — plan a maintenance window.

## Traefik Upgrade

```bash
cd /opt/redi/compose/traefik
# Update TRAEFIK_IMAGE in .env
docker compose pull
docker compose up -d
docker logs redi-traefik --tail 30
curl -I https://traefik-jkt.redi.lab
```

Review [Traefik changelog](https://github.com/traefik/traefik/releases) for breaking changes in dynamic config.

## Portainer Upgrade

```bash
cd /opt/redi/compose/portainer
# Update PORTAINER_IMAGE in .env
docker compose pull
docker compose up -d
```

Portainer CE typically supports in-place upgrades. Backup data before upgrading across major versions.

## GitLab CE Upgrade

GitLab requires **incremental** upgrades — you cannot skip major versions.

### Check upgrade path
```bash
docker exec redi-gitlab cat /opt/gitlab/version-manifest.txt
```

### Upgrade procedure

```bash
cd /opt/redi/compose/gitlab
# Update GITLAB_IMAGE to next minor version in upgrade path
docker compose pull
docker compose up -d

# Monitor reconfiguration
docker logs -f redi-gitlab
docker exec redi-gitlab gitlab-rake gitlab:check
```

Reference: [GitLab upgrade paths](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/)

### Memory note
After upgrade, GitLab runs `gitlab-ctl reconfigure` automatically. Monitor memory usage:

```bash
docker stats redi-gitlab --no-stream
```

## OS Security Patches

Monthly patch cycle:

```bash
sudo apt-get update
sudo apt-get upgrade -y
# If kernel updated:
sudo reboot
```

Schedule during maintenance window. Verify all services after reboot:

```bash
docker ps
tailscale status
dig @127.0.0.1 redi.lab SOA
```

## Rollback

If an upgrade fails:

```bash
# Revert image tag in .env to previous version
docker compose pull
docker compose up -d
# If data migration occurred, restore from backup
```

## Version Pinning Policy

- All image versions are pinned in `.env` files
- Patch upgrades: monthly, after backup
- Minor upgrades: quarterly, with testing
- Major upgrades: planned maintenance window with staging validation
