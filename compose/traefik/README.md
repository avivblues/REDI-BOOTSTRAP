# Traefik Reverse Proxy — REDI LAB Edge

HTTPS-ready reverse proxy with Docker provider and Let's Encrypt DNS-01 via PowerDNS.

## Deployment

Deploy on **redi-jkt-01** and **redi-sby-01**.

```bash
cp .env.example .env
# Configure TRAEFIK_HOSTNAME, TRAEFIK_DASHBOARD_DOMAIN, PDNS_API_KEY
sudo ../../scripts/deploy/deploy-traefik.sh
```

## Features

- Automatic HTTPS via Let's Encrypt (DNS-01 challenge)
- Docker provider for dynamic routing
- Security headers middleware
- Rate limiting
- Dashboard with basic auth (Tailscale only)
- Persistent ACME certificate store

## Networks

Traefik connects to:
- `redi-proxy` — external-facing proxy network
- `redi-dns` — PowerDNS API access
- `redi-management` — routes to management services (via Tailscale)

## Verification

```bash
curl -I https://traefik-jkt.redi.lab
docker logs redi-traefik --tail 50
```
