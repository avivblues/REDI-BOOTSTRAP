# REDI LAB — Docker Foundation Report

**Task:** REDI Agent Task 005  
**RAS Version:** 1.0  
**Stage:** 1.3 — Docker Foundation  
**Permission:** LEVEL 1  
**Date:** 2026-06-29  
**Script:** `scripts/bootstrap/docker-foundation.sh`  

---

## Executive Summary

Docker runtime standardized across **all 3 infrastructure nodes**. Engine and Compose validated, daemon baseline applied, directory layout created, and four REDI bridge networks provisioned. **No application containers deployed.**

| Node | Docker | Compose | Daemon | Networks | Containers |
|------|:------:|:-------:|:------:|:--------:|:------------:|
| `redi-jkt-01` | ✅ 29.6.1 | ✅ v5.2.0 | ✅ | 4/4 | 0 |
| `redi-sby-01` | ✅ 29.6.1 | ✅ v5.2.0 | ✅ | 4/4 | 0 |
| `redi-mjk-01` | ✅ 29.6.1 | ✅ v5.2.0 | ✅ | 4/4 | 0 |

**Decision: PASS WITH WARNINGS**

---

## Docker Version

| Node | Engine | Compose Plugin | Upgrade |
|------|--------|----------------|---------|
| `redi-jkt-01` | 29.6.1 | v5.2.0 | Not required — skipped |
| `redi-sby-01` | 29.6.1 | v5.2.0 | Not required — skipped |
| `redi-mjk-01` | 29.6.1 | v5.2.0 | Not required — skipped |

All nodes already met baseline. No upgrade performed per RAS policy.

---

## Docker Root Directory

| Node | `DockerRootDir` | `daemon.json` |
|------|-----------------|---------------|
| `redi-jkt-01` | `/var/lib/docker` | ✅ Present |
| `redi-sby-01` | `/var/lib/docker` | ✅ Present |
| `redi-mjk-01` | `/var/lib/docker` | ✅ Present |

### Daemon baseline (`/etc/docker/daemon.json`)

| Setting | Value |
|---------|-------|
| `log-driver` | `json-file` |
| `log-opts.max-size` | `50m` |
| `log-opts.max-file` | `5` |
| `live-restore` | `true` |
| `userland-proxy` | `false` |
| `no-new-privileges` | `true` |
| `default-ulimits.nofile` | 65536 soft/hard |

### Boot persistence

| Node | `docker.service` enabled | Status |
|------|:------------------------:|--------|
| All 3 | ✅ `enabled` | ✅ `active` |

---

## Networks

| Network | Subnet | Bridge iface | jkt | sby | mjk |
|---------|--------|--------------|:---:|:---:|:---:|
| `redi-dns` | `172.28.0.0/24` | `br-redi-dns` | ✅ | ✅ | ✅ |
| `redi-proxy` | `172.29.0.0/24` | `br-redi-proxy` | ✅ | ✅ | ✅ |
| `redi-management` | `172.30.0.0/24` | `br-redi-mgmt` | ✅ | ✅ | ✅ |
| `redi-internal` | `172.32.0.0/24` | `br-redi-int` | ✅ | ✅ | ✅ |

All networks: driver `bridge`, scope `local`. Created idempotently — no existing networks removed.

> **Note:** `redi-internal` is a Stage 1.3 addition. Bridge names truncated to fit Linux 15-character interface limit (`br-redi-mgmt`, `br-redi-int`).

---

## Volumes & Directory Structure

### Top-level layout (`/opt/redi`)

| Directory | jkt | sby | mjk | Permissions |
|-----------|:---:|:---:|:---:|-------------|
| `compose/` | ✅ | ✅ | ✅ | 750 |
| `config/` | ✅ | ✅ | ✅ | 750 |
| `data/` | ✅ | ✅ | ✅ | 750 `root:root` |
| `backup/` | ✅ | ✅ | ✅ | 750 |
| `logs/` | ✅ | ✅ | ✅ | 750 |
| `scripts/` | ✅ | ✅ | ✅ | 750 |
| `docs/` | ✅ | ✅ | ✅ | 750 |

### Persistent volume paths (future services)

```
/opt/redi/data/
├── powerdns/mariadb
├── powerdns/mariadb-replica
├── traefik/
├── portainer/
└── gitlab/{config,logs,data}
```

`config/traefik/acme.json` created with mode `600`.

---

## Existing Containers

| Node | Running | Stopped | Total | Impact |
|------|:-------:|:-------:|:-----:|--------|
| `redi-jkt-01` | 0 | 0 | 0 | None |
| `redi-sby-01` | 0 | 0 | 0 | None |
| `redi-mjk-01` | 0 | 0 | 0 | None |

No existing workloads interrupted. No containers removed.

---

## Validation Results

| Check | jkt | sby | mjk |
|-------|:---:|:---:|:---:|
| `docker info` healthy | ✅ | ✅ | ✅ |
| `docker compose version` | ✅ | ✅ | ✅ |
| Compose file parse (`compose/powerdns`) | ✅ | ✅ | ✅ |
| 4 REDI networks present | ✅ | ✅ | ✅ |
| Correct subnets | ✅ | ✅ | ✅ |
| Log driver `json-file` | ✅ | ✅ | ✅ |
| Live restore enabled | ✅ | ✅ | ✅ |
| `docker.service` enabled on boot | ✅ | ✅ | ✅ |
| Directory structure complete | ✅ | ✅ | ✅ |
| Data dir permissions 750 | ✅ | ✅ | ✅ |
| SSH reachable post-change | ✅ | ✅ | ✅ |
| Tailscale reachable | ✅ | ✅ | ✅ |

---

## Security Observations

| ID | Observation | Severity |
|----|-------------|----------|
| S1 | `no-new-privileges: true` enforced daemon-wide | Positive |
| S2 | Log rotation capped at 50 MB × 5 files | Positive |
| S3 | `live-restore: true` — containers survive daemon restart | Info |
| S4 | `userland-proxy: false` — reduces NAT overhead | Info |
| S5 | Data directories `750 root:root` — not world-readable | Positive |
| S6 | No containers running — attack surface minimal | Info |
| S7 | Docker socket accessible only to root/docker group | Info |

---

## Warnings

| ID | Warning |
|----|---------|
| W1 | Initial network create failed on long bridge names (`br-redi-management` > 15 chars) — fixed with `br-redi-mgmt` / `br-redi-int` |
| W2 | `redi-internal` (`172.32.0.0/24`) not yet in `inventory/network.example.yaml` — document before Stage 3 |
| W3 | All 4 networks created on every node (local bridge scope) — expected for per-host compose stacks |

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  DOCKER FOUNDATION:  PASS WITH WARNINGS                            │
│                                                                   │
│  Nodes standardized:     3 / 3                                    │
│  Docker healthy:         3 / 3                                    │
│  Compose working:        3 / 3                                    │
│  Networks created:       4 × 3 nodes                              │
│  Application containers: 0 (none deployed)                        │
│  Existing workloads:     Unaffected                               │
│                                                                   │
│  Status: COMPLETE — Awaiting CTO approval for Stage 2+             │
└──────────────────────────────────────────────────────────────────┘
```

| Outcome | Selected |
|---------|----------|
| PASS | |
| **PASS WITH WARNINGS** | **✓** |
| BLOCKED | |
| FAIL | |

---

## Agent Compliance

- ✅ Docker validated; no upgrade without approval  
- ✅ Daemon baseline applied  
- ✅ Directory layout and volume paths created  
- ✅ Networks created idempotently  
- ✅ No PowerDNS / Traefik / Portainer / GitLab / MariaDB deployed  
- ✅ No existing Docker resources removed  
- ✅ No production workloads interrupted  

---

*Report generated: 2026-06-29 — RAS v1.0 Stage 1.3*
