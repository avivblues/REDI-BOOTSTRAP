# Runbook — MariaDB Replication Lag

## Symptoms
- Replica DNS returns stale records
- `Seconds_Behind_Master` > 60 in `SHOW SLAVE STATUS`
- `Slave_IO_Running` or `Slave_SQL_Running` is `No`

## Diagnosis

```bash
# On replica (redi-sby-01)
docker exec redi-mariadb mysql -uroot -p -e "SHOW SLAVE STATUS\G"
```

## Resolution

### IO thread stopped (connectivity)
```bash
# Verify Tailscale connectivity to primary
tailscale ping redi-jkt-01
nc -zv <jkt-tailscale-ip> 3306

docker exec redi-mariadb mysql -uroot -p -e "START SLAVE IO_THREAD;"
```

### SQL thread stopped (conflict)
```bash
docker exec redi-mariadb mysql -uroot -p -e "
  STOP SLAVE;
  SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
  START SLAVE;
"
# Investigate root cause — skipping is a temporary fix
```

### Full resync required
```bash
# On primary — create fresh dump
docker exec redi-mariadb mysqldump -uroot -p \
  --single-transaction powerdns | gzip > /tmp/powerdns-resync.sql.gz

# Transfer to replica and restore
/opt/redi/scripts/restore/restore-powerdns.sh /tmp/powerdns-resync.sql.gz

# Reconfigure replication
docker exec redi-mariadb bash /docker-entrypoint-initdb.d/99-init.sh
```

## Prevention
- Monitor replication lag (Phase 2: Prometheus mysql_exporter)
- Ensure adequate disk I/O on both nodes
- Keep MariaDB versions matched
