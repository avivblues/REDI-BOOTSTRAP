# Runbook — PowerDNS Failure

## Symptoms
- DNS queries timeout or return SERVFAIL
- `docker ps` shows `redi-pdns-auth` not running
- PowerDNS API unreachable on port 8081

## Diagnosis

```bash
docker ps -a | grep redi-pdns
docker logs redi-pdns-auth --tail 100
docker exec redi-pdns-auth pdns_control rping
dig @127.0.0.1 redi.lab SOA
```

## Resolution

### Container crashed
```bash
cd /opt/redi/compose/powerdns
docker compose up -d pdns-auth
```

### Database connection failure
```bash
docker logs redi-mariadb --tail 50
docker exec redi-mariadb mysqladmin -uroot -p ping
docker compose restart mariadb
# Wait for healthy, then:
docker compose restart pdns-auth
```

### Corrupted zone data
Restore from backup — see [restore.md](../restore.md).

## Escalation
If both edge nodes are down, activate DR procedure for full edge loss.
