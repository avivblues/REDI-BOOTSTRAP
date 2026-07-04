# REDI LAB — Restore Guide

## General Principles

1. **Stop the affected service** before restoring data
2. **Verify backup integrity** before proceeding
3. **Test on staging** when possible
4. **Document** the incident and recovery steps taken

## PowerDNS / MariaDB Restore

### When to Use
- Database corruption
- Accidental zone deletion
- Primary node failure (promote replica first — see runbook)

### Procedure

```bash
# On the target edge node
sudo /opt/redi/scripts/restore/restore-powerdns.sh \
  /opt/redi/backup/YYYYMMDD-HHMMSS/powerdns-mariadb.sql.gz
```

### Verify

```bash
dig @127.0.0.1 redi.lab SOA
docker exec redi-pdns-auth pdns_control list-zones
curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
  http://127.0.0.1:8081/api/v1/servers/localhost/zones
```

## Traefik Certificate Restore

```bash
cd /opt/redi
docker compose -f compose/traefik/docker-compose.yml stop traefik

cp /opt/redi/backup/YYYYMMDD-HHMMSS/traefik-acme.json \
   config/traefik/acme.json
chmod 600 config/traefik/acme.json

tar xzf /opt/redi/backup/YYYYMMDD-HHMMSS/traefik-config.tar.gz \
  -C config/

docker compose -f compose/traefik/docker-compose.yml start traefik
```

## Portainer Restore

```bash
cd /opt/redi/compose/portainer
docker compose stop portainer

rm -rf /opt/redi/data/portainer/*
tar xzf /opt/redi/backup/YYYYMMDD-HHMMSS/portainer-data.tar.gz \
  -C /opt/redi/data/

docker compose start portainer
```

## GitLab Restore

### Prerequisites
- GitLab container running (but services stopped during restore)
- Backup tar file and `gitlab-secrets.json` from the **same** backup date

### Procedure

```bash
sudo /opt/redi/scripts/restore/restore-gitlab.sh \
  /opt/redi/backup/YYYYMMDD-HHMMSS/1234567890_gitlab_backup.tar \
  /opt/redi/backup/YYYYMMDD-HHMMSS/gitlab-secrets.json
```

### Verify

```bash
docker exec redi-gitlab gitlab-rake gitlab:check SANITIZE=true
curl -I https://gitlab.redi.lab
```

## Full Disaster Recovery — Primary Edge Loss

If `redi-jkt-01` is lost:

1. **DNS:** Traffic fails over to `redi-sby-01` (ensure NS records include both)
2. **MariaDB:** Promote sby replica to primary:

```bash
# On redi-sby-01
docker exec redi-mariadb mysql -uroot -p -e "
  STOP SLAVE;
  RESET SLAVE ALL;
  SET GLOBAL read_only = OFF;
  SET GLOBAL super_read_only = OFF;
"
```

3. Update `compose/powerdns/.env` on sby: `PDNS_NODE_ROLE=primary`
4. Provision replacement jkt node and configure as replica
5. Restore Traefik config and ACME from backup
6. Update DNS NS glue records if IP changes

## Full Disaster Recovery — Management Node Loss

1. Provision new `redi-mgmt-01` VM on Proxmox
2. Bootstrap and join Tailscale mesh
3. Restore GitLab from most recent backup
4. Restore Portainer data
5. Verify Traefik routes to new Tailscale IP (update DNS A records)
6. Re-register GitLab runners if any exist

## Recovery Time Objectives

| Service | RTO Target | RPO Target |
|---------|-----------|-----------|
| DNS | 15 minutes | 24 hours |
| HTTPS (Traefik) | 30 minutes | 24 hours |
| GitLab | 2 hours | 24 hours |
| Portainer | 30 minutes | 24 hours |
