# STAGE 01 — REDI DevOps Platform (GitLab CE)

| Field | Value |
|-------|-------|
| **RAS Version** | 1.0 |
| **Sprint** | Sprint 2 — REDI Platform Foundation |
| **Stage** | 1 — REDI DevOps Platform |
| **Target** | `redi-mjk-01` (management) |
| **Edge** | `redi-jkt-01` (Traefik TLS + SSH passthrough) |
| **Executed** | 2026-06-29 |
| **Decision** | **PASS WITH WARNINGS** |

---

## Executive Summary

GitLab CE 17.8.1 is deployed on `redi-mjk-01`, published through Traefik on `redi-jkt-01` at `https://git.letsredi.com` and `https://registry.letsredi.com`. Git over SSH is available on port `2222` via the edge proxy. The REDI group, eight repositories, labels, milestones, wiki, and issue template are initialized. Container health, HTTPS login, registry, backup, and daily cron are operational.

Minor gaps: merge request template and README are not yet committed to `redi-foundation` (branch push restriction after initial template commit), and the `/-/health` URL returns 404 through Traefik while the Docker healthcheck passes internally.

---

## Deployment

| Component | Status | Details |
|-----------|--------|---------|
| Docker Compose | ✅ | `/opt/redi/compose/gitlab/docker-compose.yml` |
| Image | ✅ | `gitlab/gitlab-ce:17.8.1-ce.0` |
| Container | ✅ | `redi-gitlab` — **healthy** |
| Persistent volumes | ✅ | `/opt/redi/data/gitlab/{config,logs,data}` |
| Mesh HTTP | ✅ | `100.81.86.37:8929` → GitLab nginx |
| Mesh registry | ✅ | `100.81.86.37:5000` → container registry |
| SSH | ✅ | `0.0.0.0:2222` on mjk; Traefik TCP `:2222` on jkt |
| Memory limit | ✅ | 6 GB |

---

## DNS

| Host | Type | Value | Public resolver (8.8.8.8) |
|------|------|-------|---------------------------|
| `git.letsredi.com` | A | `103.149.238.98` | `103.149.238.98` |
| `registry.letsredi.com` | A | `103.149.238.98` | `103.149.238.98` |

**Note:** Records were migrated from the placeholder CNAME chain (`proxy` → `traefik-jkt` → Tailscale mesh IP) to direct **A records** on the Jakarta edge public IP so Let's Encrypt HTTP-01 and public HTTPS can succeed.

---

## Traefik (redi-jkt-01)

| Route | Backend | TLS |
|-------|---------|-----|
| `git.letsredi.com` | `http://100.81.86.37:8929` | Let's Encrypt HTTP-01 (`acme-http.json`) |
| `registry.letsredi.com` | `http://100.81.86.37:5000` | Let's Encrypt HTTP-01 |
| TCP `:2222` | `100.81.86.37:2222` | Plain TCP (no TLS termination) |

Config: `/opt/redi/config/traefik/dynamic/gitlab.yml`

---

## Platform Initialization

| Item | Status | Count / Notes |
|------|--------|----------------|
| Group `REDI` | ✅ | `redi` (id=2) |
| `redi-foundation` | ✅ | |
| `redi-platform` | ✅ | |
| `redi-runtime` | ✅ | |
| `redi-infrastructure` | ✅ | |
| `redi-knowledge` | ✅ | |
| `redi-ai` | ✅ | |
| `redi-lab` | ✅ | |
| `redi-examples` | ✅ | |
| Labels | ✅ | 8 (`bug`, `enhancement`, `documentation`, `infrastructure`, `platform`, `security`, `ai`, `knowledge`) |
| Milestones | ✅ | 4 (Sprint 2, Sprint 3, Platform Foundation, Knowledge Foundation) |
| Wiki | ✅ | `redi-foundation` — page `home` |
| Issue template | ✅ | `redi-foundation/.gitlab/issue_templates/Bug.md` |
| MR template | ⚠️ | Not committed — follow-up via UI or unprotected branch |
| README | ⚠️ | Not committed — follow-up |
| Container Registry | ✅ | Enabled at instance level |

---

## Validation Results

| Check | Method | Result |
|-------|--------|--------|
| GitLab healthy (Docker) | `docker inspect redi-gitlab` | ✅ `healthy` |
| HTTPS login | `curl -sk https://git.letsredi.com/users/sign_in` | ✅ **200** (external) |
| HTTPS help | `curl -sk https://git.letsredi.com/help` | ✅ **200** |
| `/-/health` via Traefik | `curl -sk https://git.letsredi.com/-/health` | ⚠️ **404** (internal `gitlab-healthcheck` OK) |
| Registry | `curl -sk https://registry.letsredi.com/v2/` | ✅ **401** (auth required — expected) |
| TLS certificate | `openssl s_client -servername git.letsredi.com` | ✅ CN=`git.letsredi.com`, valid to 2026-09-27 |
| SSH Git | `ssh -p 2222 git@103.149.238.98` | ✅ `Permission denied (publickey)` — git-shell reachable |
| DNS public | `dig @8.8.8.8 git.letsredi.com` | ✅ `103.149.238.98` |
| Backup (in-container) | `/var/opt/gitlab/backups/` | ✅ `1782750413_2026_06_29_17.8.1_gitlab_backup.tar` (~570 KB) |
| Backup (host copy) | `/opt/redi/backup/gitlab/` | ✅ tar + `gitlab-secrets.json` |
| Daily backup cron | `crontab -l` on mjk | ✅ `0 2 * * * /opt/redi/scripts/backup/backup-all.sh` |

---

## Credentials Reference (no secrets)

| Item | Location |
|------|----------|
| GitLab root user | `root` |
| Root password | `secrets/api-keys.yaml` → `gitlab-root-password` |
| Initial bootstrap password | `/etc/gitlab/initial_root_password` inside container (superseded) |
| Registry login | Same as GitLab credentials |

---

## Warnings

1. **MR template / README** — Initial rails commit created the issue template on `main`; subsequent file commits were blocked by branch permissions. Add `.gitlab/merge_request_templates/Default.md` and `README.md` via GitLab UI or a follow-up commit as `root`.
2. **`/-/health` via edge** — Returns 404 through Traefik; use Docker healthcheck or `/users/sign_in` for edge probes until nginx routing is tuned.
3. **Wildcard DNS ACME** — Traefik `powerdns` DNS challenge provider is not available in the current image; per-host HTTP-01 certificates are used for `git` and `registry`.
4. **Compose env interpolation** — `$proxy_add_x_forwarded_for` / `$http_host` escaped as `$$` in `GITLAB_OMNIBUS_CONFIG` to avoid Compose warnings.

---

## Artifacts

| Path | Description |
|------|-------------|
| `compose/gitlab/docker-compose.yml` | GitLab CE stack |
| `compose/gitlab/.env.example` | Environment template |
| `config/traefik/dynamic/gitlab.yml` | Traefik routes |
| `scripts/deploy/deploy-gitlab.sh` | Deploy script |
| `scripts/deploy/init-gitlab-platform.sh` | Group/projects/labels init |
| `scripts/deploy/update-dns-gitlab.sh` | DNS go-live (A → edge IP) |

---

## Decision

### **PASS WITH WARNINGS**

All Stage 1 hard requirements are met: GitLab is healthy, HTTPS and SSH Git work, the container registry responds, backups exist with daily cron, and the REDI platform structure is initialized. Warnings are non-blocking and documented above.

**Awaiting CTO approval before Stage 2 (PowerDNS Replica / DNS HA).**
