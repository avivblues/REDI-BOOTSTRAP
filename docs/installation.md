# REDI LAB — Installation Guide

## Prerequisites

- Three Ubuntu 22.04 LTS servers provisioned per inventory
- SSH access to all servers
- Tailscale account with auth key (reusable, pre-authorized)
- Domain `redi.lab` (or your chosen domain) with NS records pointing to edge nodes
- Minimum resources:
  - Edge nodes: 2 vCPU, 4 GB RAM, 40 GB disk
  - Management node: 4 vCPU, 8 GB RAM, 100 GB disk

## Step 1 — Deploy Repository

On each server:

```bash
sudo mkdir -p /opt/redi
sudo git clone <repository-url> /opt/redi
cd /opt/redi
```

Alternatively, rsync from your workstation:

```bash
rsync -avz --exclude '.git' ./ devapp@103.149.238.98:/opt/redi/
rsync -avz --exclude '.git' -e 'ssh -p 2280' ./ root@103.80.214.144:/opt/redi/
```

## Step 2 — Configure Inventory

On each server (or centrally and distribute):

```bash
cp inventory/servers.env.example inventory/servers.env
chmod 600 inventory/servers.env
vim inventory/servers.env
```

Generate strong passwords:

```bash
openssl rand -base64 32
```

Generate Traefik dashboard password:

```bash
htpasswd -nbB admin 'your-secure-password' | sed -e 's/\$/\$\$/g'
```

## Step 3 — Bootstrap All Servers

Run on **each server** as root:

```bash
cd /opt/redi
chmod +x scripts/**/*.sh
sudo ./scripts/bootstrap/bootstrap.sh
```

This installs:
- Docker CE + Compose plugin
- Git, curl, chrony, UFW, Fail2Ban, Tailscale
- Directory structure under `/opt/redi`

## Step 4 — Configure Tailscale

On **each server**:

```bash
sudo ./scripts/bootstrap/configure-tailscale.sh
```

Verify mesh connectivity:

```bash
tailscale status
tailscale ping redi-jkt-01
tailscale ping redi-sby-01
tailscale ping redi-mgmt-01
```

Update `inventory/servers.env` with actual Tailscale IPs.

## Step 5 — Deploy PowerDNS

### Primary (redi-jkt-01)

```bash
cd /opt/redi/compose/powerdns
cp .env.example .env
# Set PDNS_NODE_ROLE=primary, fill all passwords
sudo /opt/redi/scripts/deploy/deploy-powerdns.sh --role primary
```

### Replica (redi-sby-01)

```bash
cd /opt/redi/compose/powerdns
cp .env.example .env
# Set PDNS_NODE_ROLE=replica, MARIADB_PRIMARY_HOST=<jkt-tailscale-ip>
sudo /opt/redi/scripts/deploy/deploy-powerdns.sh --role replica
```

Verify:

```bash
dig @103.149.238.98 redi.lab SOA
dig @103.80.214.144 redi.lab SOA
docker exec redi-mariadb mysql -uroot -p -e "SHOW SLAVE STATUS\G"  # on replica
```

## Step 6 — Deploy Traefik

On **both edge nodes**:

```bash
cd /opt/redi/compose/traefik
cp .env.example .env
# Configure PDNS_API_KEY, REDI_ACME_EMAIL, dashboard hash
sudo /opt/redi/scripts/deploy/deploy-traefik.sh
```

Verify:

```bash
curl -I https://traefik-jkt.redi.lab
docker logs redi-traefik --tail 30
```

## Step 7 — Deploy Portainer

On **redi-mgmt-01 only**:

```bash
cd /opt/redi/compose/portainer
cp .env.example .env
sudo /opt/redi/scripts/deploy/deploy-portainer.sh
```

Access: `https://portainer.redi.lab`

## Step 8 — Deploy GitLab CE

On **redi-mgmt-01 only**:

```bash
cd /opt/redi/compose/gitlab
cp .env.example .env
# Set GITLAB_EXTERNAL_URL and GITLAB_ROOT_PASSWORD
sudo /opt/redi/scripts/deploy/deploy-gitlab.sh
```

Initial startup takes 5–10 minutes. Access: `https://gitlab.redi.lab`

Login: `root` / password from `GITLAB_ROOT_PASSWORD`

## Step 9 — Configure DNS Delegation

At your domain registrar, set NS records:

```
redi.lab.  NS  ns1.redi.lab.
redi.lab.  NS  ns2.redi.lab.
ns1.redi.lab.  A  103.149.238.98
ns2.redi.lab.  A  103.80.214.144
```

## Step 10 — Schedule Backups

Add to crontab on each server:

```bash
# Daily backup at 02:00
0 2 * * * /opt/redi/scripts/backup/backup-all.sh >> /opt/redi/logs/backup.log 2>&1
```

## Post-Installation Checklist

- [ ] All three nodes visible in `tailscale status`
- [ ] DNS resolves for all service hostnames
- [ ] HTTPS certificates issued (check Traefik logs)
- [ ] MariaDB replication running (`Slave_IO_Running: Yes`)
- [ ] GitLab health check passes
- [ ] Portainer accessible and admin configured
- [ ] Backups scheduled and tested
- [ ] All `.env` files have `chmod 600`
- [ ] Credentials stored in secure vault (not in git)

## Troubleshooting

See runbooks in `docs/runbooks/`.
