# Runbook — Traefik Certificate Failure

## Symptoms
- HTTPS returns certificate errors
- Traefik logs show ACME challenge failures
- `acme.json` empty or missing certificates

## Diagnosis

```bash
docker logs redi-traefik 2>&1 | grep -i acme
docker logs redi-traefik 2>&1 | grep -i error
ls -la /opt/redi/config/traefik/acme.json
```

Test PowerDNS API (required for DNS-01 challenge):

```bash
source /opt/redi/compose/traefik/.env
curl -s -H "X-API-Key: ${PDNS_API_KEY}" \
  "${PDNS_API_URL}/api/v1/servers/localhost/statistics"
```

## Resolution

### PowerDNS API unreachable
- Verify PowerDNS is running on jkt node
- Confirm `PDNS_API_URL` points to jkt Tailscale IP
- Check UFW allows 8081 from Tailscale subnet

### Rate limited by Let's Encrypt
- Restore `acme.json` from backup
- Wait for rate limit reset (see LE docs)
- Use staging CA for testing: add `caServer: https://acme-staging-v02.api.letsencrypt.org/directory` to traefik.yml

### Force certificate renewal
```bash
cd /opt/redi/compose/traefik
docker compose stop traefik
rm /opt/redi/config/traefik/acme.json
touch /opt/redi/config/traefik/acme.json
chmod 600 /opt/redi/config/traefik/acme.json
docker compose up -d traefik
docker logs -f redi-traefik
```

### DNS propagation delay
Increase `delayBeforeCheck` in `traefik.yml` from 30s to 60s.

## Prevention
- Backup `acme.json` daily
- Monitor certificate expiry (Phase 2: Prometheus blackbox exporter)
- Ensure NS records are correctly delegated
