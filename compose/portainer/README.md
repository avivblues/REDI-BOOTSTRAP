# Portainer CE — REDI LAB Management

Container management UI deployed exclusively on **redi-mgmt-01**.

## Deployment

```bash
cp .env.example .env
sudo ../../scripts/deploy/deploy-portainer.sh
```

## Access

- URL: `https://portainer.redi.lab`
- TLS terminated by Traefik on edge node
- First login creates admin user

## Data

Persistent data stored in `data/portainer/`.

## Security

- HTTPS only via Traefik
- Not exposed on public port directly
- Connected to `redi-management` and `redi-proxy` networks
