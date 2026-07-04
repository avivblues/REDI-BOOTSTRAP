# Runbook — GitLab Unavailable

## Symptoms
- `https://gitlab.redi.lab` returns 502/504
- Git push/pull fails
- Container health check failing

## Diagnosis

```bash
docker ps -a | grep redi-gitlab
docker logs redi-gitlab --tail 100
docker exec redi-gitlab gitlab-ctl status
docker stats redi-gitlab --no-stream
df -h /opt/redi/data/gitlab
```

## Resolution

### Container not running
```bash
cd /opt/redi/compose/gitlab
docker compose up -d
# Wait 5-10 minutes for startup
docker exec redi-gitlab gitlab-ctl status
```

### Out of memory
```bash
# Check memory
free -h
docker stats redi-gitlab --no-stream

# Restart with memory reclaim
docker exec redi-gitlab gitlab-ctl restart
```

If persistent, reduce workers in `GITLAB_OMNIBUS_CONFIG` and redeploy.

### Disk full
```bash
df -h
docker exec redi-gitlab gitlab-ctl tail
# Clean old backups
docker exec redi-gitlab find /var/opt/gitlab/backups -mtime +7 -delete
# Run gitlab housekeeping
docker exec redi-gitlab gitlab-rake gitlab:cleanup:dirs
```

### Service-specific failure
```bash
docker exec redi-gitlab gitlab-ctl status
docker exec redi-gitlab gitlab-ctl restart nginx
docker exec redi-gitlab gitlab-ctl restart puma
docker exec redi-gitlab gitlab-ctl restart sidekiq
docker exec redi-gitlab gitlab-ctl restart postgresql
```

### Full reconfigure
```bash
docker exec redi-gitlab gitlab-ctl reconfigure
docker exec redi-gitlab gitlab-ctl restart
docker exec redi-gitlab gitlab-rake gitlab:check SANITIZE=true
```

### Data corruption — restore from backup
See [restore.md](../restore.md).

## Escalation
If management node is lost, follow full DR procedure in restore guide.
