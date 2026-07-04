# REDI LAB — Enterprise Infrastructure Platform

Production-grade Infrastructure as Code for the REDI LAB platform foundation.

## Overview

| Server | Hostname | Role | Services |
|--------|----------|------|----------|
| Edge 1 | `redi-jkt-01` | Jakarta | PowerDNS (Primary), Traefik |
| Edge 2 | `redi-sby-01` | Surabaya | PowerDNS (Replica), Traefik |
| Management | `redi-mgmt-01` | Control Plane | GitLab CE, Portainer |

All inter-service communication uses **Tailscale** private networking. Only **Traefik** exposes HTTP/HTTPS to the public internet.

## Phase 1 Scope

- Server bootstrap (Docker, security hardening, Tailscale)
- PowerDNS authoritative cluster with MariaDB replication
- Traefik reverse proxy with Let's Encrypt
- Portainer container management
- GitLab CE source control

**Not in Phase 1:** Kubernetes, application services, REDI Capture OS, Authentik, Prometheus/Grafana/Loki/Uptime Kuma (prepared for Phase 2).

## Directory Layout

```
/opt/redi/
├── compose/          # Docker Compose stacks per service
├── config/           # Static configuration files
├── data/             # Persistent volumes (runtime, not in git)
├── backup/           # Backup artifacts
├── logs/             # Service logs
├── scripts/          # Bootstrap, deploy, backup, restore
├── docs/             # Architecture and runbooks
└── inventory/        # Server inventory templates
```

## Quick Start

### 1. Clone to management workstation

```bash
git clone <repository-url> /opt/redi
cd /opt/redi
```

### 2. Configure inventory

```bash
cp inventory/servers.env.example inventory/servers.env
# Edit inventory/servers.env with production values
chmod 600 inventory/servers.env
```

### 3. Bootstrap all servers

```bash
# Run on each server (or use remote deploy)
sudo ./scripts/bootstrap/bootstrap.sh
```

### 4. Configure Tailscale

```bash
sudo ./scripts/bootstrap/configure-tailscale.sh
```

### 5. Deploy services (in order)

```bash
# On redi-jkt-01 and redi-sby-01
sudo ./scripts/deploy/deploy-powerdns.sh --role primary   # jkt only
sudo ./scripts/deploy/deploy-powerdns.sh --role replica   # sby only
sudo ./scripts/deploy/deploy-traefik.sh

# On redi-mgmt-01
sudo ./scripts/deploy/deploy-portainer.sh
sudo ./scripts/deploy/deploy-gitlab.sh
```

## Documentation

| Document | Path |
|----------|------|
| Architecture | [docs/architecture.md](docs/architecture.md) |
| Installation Guide | [docs/installation.md](docs/installation.md) |
| Backup Guide | [docs/backup.md](docs/backup.md) |
| Restore Guide | [docs/restore.md](docs/restore.md) |
| Upgrade Guide | [docs/upgrade.md](docs/upgrade.md) |

## Security

- UFW default-deny with explicit allow rules
- Fail2Ban for SSH brute-force protection
- Docker networks isolate service tiers (`redi-dns`, `redi-proxy`, `redi-management`)
- Secrets in `.env` files (never committed to git)
- Internal services bound to Tailscale interfaces only
- Traefik handles TLS termination and certificate management

## Support

Operations runbooks are in `docs/runbooks/`.
