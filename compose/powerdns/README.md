# PowerDNS Authoritative Server with MariaDB Backend

Production deployment for REDI LAB edge DNS nodes.

## Architecture

| Node | Role | MariaDB | PowerDNS |
|------|------|---------|----------|
| redi-jkt-01 | Primary | Master | Authoritative |
| redi-sby-01 | Replica | Slave | Authoritative |

Both nodes run PowerDNS Authoritative against a replicated MariaDB backend.

## Prerequisites

- Bootstrap complete
- Tailscale mesh active
- Docker networks created by deploy script

## Deployment

### Primary (redi-jkt-01)

```bash
cp .env.example .env
# Set PDNS_NODE_ROLE=primary and fill credentials
sudo ../../scripts/deploy/deploy-powerdns.sh --role primary
```

### Replica (redi-sby-01)

```bash
cp .env.example .env
# Set PDNS_NODE_ROLE=replica, MARIADB_PRIMARY_HOST to jkt Tailscale IP
sudo ../../scripts/deploy/deploy-powerdns.sh --role replica
```

## Verification

```bash
# API health
curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
  http://127.0.0.1:8081/api/v1/servers/localhost/statistics

# DNS query
dig @127.0.0.1 redi.lab SOA

# Replication status (on replica)
docker exec redi-mariadb mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" \
  -e "SHOW SLAVE STATUS\G"
```

## Ports

| Port | Protocol | Exposure | Purpose |
|------|----------|----------|---------|
| 53 | TCP/UDP | Public + Tailscale | DNS |
| 8081 | TCP | Tailscale only | PowerDNS API |
| 3306 | TCP | Tailscale only | MariaDB replication |

## Backup

See `docs/backup.md` — PowerDNS section.
