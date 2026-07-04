# GitLab CE — REDI LAB Source Control

Self-hosted GitLab Community Edition on **redi-mgmt-01**.

## Configuration

| Feature | Status |
|---------|--------|
| Container Registry | Disabled |
| GitLab Pages | Disabled |
| Mattermost | Disabled |
| Bundled Monitoring | Disabled |
| SMTP | Configurable |

## Deployment

```bash
cp .env.example .env
# Set GITLAB_EXTERNAL_URL and GITLAB_ROOT_PASSWORD
sudo ../../scripts/deploy/deploy-gitlab.sh
```

Initial startup takes 5–10 minutes.

## Access

- Web: `https://gitlab.redi.lab`
- SSH Git: `ssh://git@gitlab.redi.lab:2222/group/project.git`
- Default user: `root` (password from `GITLAB_ROOT_PASSWORD`)

## Memory Optimization

GitLab is tuned for a 4 GB memory limit via `config/gitlab/gitlab.rb`:
- Puma workers reduced
- Sidekiq concurrency reduced
- Prometheus/exporter disabled

## Backup

See `docs/backup.md` — GitLab section.
