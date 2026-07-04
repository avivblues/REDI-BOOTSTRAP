# REDI LAB — Gateway Platform Report

**Task:** REDI Agent Task 007  
**RAS Version:** 1.0  
**Stage:** 3 — Traefik Gateway  
**Permission:** LEVEL 2  
**Date:** 2026-06-29  

---

## Executive Summary

Traefik unified gateway deployed on **redi-jkt-01 (primary edge)**. Docker Socket Proxy mediates Docker API access; dashboard is bound to the Tailscale mesh IP only. File and Docker providers are active with zero configuration errors after deployment fixes.

| Node | Role | Traefik | Socket Proxy | Status |
|------|------|:-------:|:------------:|--------|
| `redi-jkt-01` | Edge Primary | ✅ healthy | ✅ healthy | **Deployed** |
| `redi-sby-01` | Edge Secondary | ❌ | ❌ | **Not deployed** (LXC Docker blocker) |
| `redi-mjk-01` | Management | N/A | N/A | Out of scope |

**Decision: PASS WITH WARNINGS**

---

## Gateway Status

### `redi-jkt-01`

| Container | Image | Status | Ports |
|-----------|-------|--------|-------|
| `redi-traefik` | `traefik:v3.6.1` | ✅ healthy | `0.0.0.0:80`, `0.0.0.0:443`, `100.79.82.92:8080` |
| `redi-docker-socket-proxy` | `tecnativa/docker-socket-proxy:latest` | ✅ healthy | `2375/tcp` (internal) |

| Check | Result |
|-------|--------|
| `traefik healthcheck --ping` | ✅ `OK` |
| `/ping` endpoint | ✅ `OK` |
| Container restart policy | ✅ `unless-stopped` |
| Coexistence with PowerDNS | ✅ Both stacks running |

---

## EntryPoints

| Name | Address | Purpose | Binding |
|------|---------|---------|---------|
| `web` | `:80` | HTTP ingress | `0.0.0.0:80` (public) |
| `websecure` | `:443` | HTTPS ingress + ACME | `0.0.0.0:443` (public) |
| `traefik` | `:8080` | Dashboard / internal API | `100.79.82.92:8080` (mesh only) |

**HTTP → HTTPS:** Permanent redirect from `web` to `websecure` is configured.

**TLS:** `letsencrypt` resolver with PowerDNS DNS-01 challenge (`127.0.0.1:53`).

---

## Providers

| Provider | Endpoint / Path | Status | Notes |
|----------|-----------------|--------|-------|
| **Docker** | `tcp://docker-socket-proxy:2375` | ✅ Healthy | `exposedByDefault: false`, network `redi-proxy`, `watch: true` |
| **File** | `/etc/traefik/dynamic` | ✅ Healthy | `watch: true`; routers and middlewares loaded |

### API Overview (post-deploy)

```json
{
  "http": { "routers": { "total": 4, "errors": 0 }, "services": { "total": 5, "errors": 0 } },
  "providers": ["Docker", "File"],
  "features": { "accessLog": true }
}
```

### Active HTTP Routers

| Router | Provider | Status |
|--------|----------|--------|
| `traefik-dashboard@file` | File | ✅ enabled |
| `gateway-file-probe@file` | File | ✅ enabled |
| `ping@internal` | Internal | ✅ enabled |
| `web-to-websecure@internal` | Internal | ✅ enabled |

**Docker service discovery:** Provider is connected and watching. No application routes are published because all running containers use `traefik.enable=false` (by design — no application services deployed in this task).

---

## Dashboard

| Check | Result |
|-------|--------|
| Reachable via mesh IP | ✅ `HTTP 200` at `http://100.79.82.92:8080/dashboard/` |
| Host header required | `Host: traefik-jkt-01.redi.lab` |
| Basic auth | ✅ `admin` + dashboard password |
| `internal-only` middleware | ✅ Tailscale/private ranges enforced |
| Public exposure (`103.149.238.98:8080`) | ✅ **Blocked** (connection refused / not bound) |
| Cross-node mesh (sby → jkt `:8080`) | ⚠️ Timeout (known mesh TCP issue, see R4) |

**Dashboard domain:** `traefik-jkt-01.redi.lab` (rendered from hostname at deploy time)

---

## Logs

| Log | Path | Format | Status |
|-----|------|--------|--------|
| Traefik application | `/opt/redi/logs/traefik/traefik.log` | JSON | ✅ Active |
| Access log | `/opt/redi/logs/traefik/access.log` | JSON | ✅ Active (4xx–5xx filtered in config) |
| Container stdout | `docker logs redi-traefik` | json-file driver | ✅ `50m × 5` rotation |

**Sample access log entry (JSON):**

```json
{"ClientAddr":"172.28.0.1:38806","DownstreamStatus":502,"RequestHost":"gateway-probe.redi.lab","RouterName":"gateway-file-probe@file","entryPointName":"traefik","level":"info","time":"2026-06-29T10:21:39Z"}
```

---

## Health

| Component | Healthcheck | Result |
|-----------|-------------|--------|
| `redi-traefik` | `traefik healthcheck --ping` | ✅ healthy |
| `redi-docker-socket-proxy` | `wget http://localhost:2375/_ping` | ✅ healthy |
| Docker provider | No errors after `v3.6.1` upgrade | ✅ |
| File provider | Routers loaded, 0 errors | ✅ |
| Dynamic config (file probe) | Router matches requests | ✅ (backend returns 502 — loopback design, see W3) |

---

## Security Observations

| ID | Observation | Severity |
|----|-------------|----------|
| S1 | Dashboard **not** bound to `0.0.0.0:8080` — only `100.79.82.92:8080` | ✅ Good |
| S2 | Traefik container has **no** `/var/run/docker.sock` mount | ✅ Good |
| S3 | Docker API accessed via **tecnativa/docker-socket-proxy** with restricted flags | ✅ Good |
| S4 | Dashboard protected by **basic auth** + **IP allowlist** | ✅ Good |
| S5 | `traefik.enable=false` on gateway container itself | ✅ Good |
| S6 | `cap_drop: ALL` + `NET_BIND_SERVICE` only on Traefik | ✅ Good |
| S7 | `no-new-privileges` on both containers | ✅ Good |
| S8 | Public HTTP/HTTPS (`80`/`443`) exposed for future ingress | ℹ️ Expected |
| S9 | ACME credentials and dashboard password in `/opt/redi/compose/traefik/.env` (chmod 600) | ✅ Acceptable |
| S10 | Cross-node mesh TCP to jkt non-standard ports may be blocked by UFW | ⚠️ Medium |

---

## Validation Results

| Requirement | Result |
|-------------|--------|
| Traefik healthy | ✅ PASS |
| Dashboard reachable through REDI Mesh (on-node) | ✅ PASS |
| Dashboard not publicly exposed | ✅ PASS |
| Docker provider healthy | ✅ PASS |
| File provider healthy | ✅ PASS |
| Dynamic configuration working | ✅ PASS |
| Automatic service discovery working | ✅ PASS (provider active; no labeled app services) |
| Docker Compose | ✅ |
| REDI Docker networks (`redi-proxy`, `redi-dns`, `redi-management`) | ✅ |
| Configuration under `/opt/redi` | ✅ |
| No direct Docker socket on Traefik | ✅ |
| No application services deployed | ✅ |

---

## Deployment Fixes Applied During Task

| Issue | Resolution |
|-------|------------|
| `deploy-traefik.sh` sed broke `routers.yml` YAML | Replaced with `__TRAEFIK_DASHBOARD_HOST__` placeholder |
| `services: {}` invalid in Traefik v3.6 file provider | Removed empty `services` block from `routers.yml` |
| Traefik `v3.3.4` incompatible with Docker 29 (API 1.24 vs 1.44) | Upgraded to `traefik:v3.6.1` |
| Invalid `experimental.plugins` block caused startup warning | Removed from `traefik.yml` |
| TLS on dashboard router for plain `:8080` entrypoint | Removed (HTTP-only internal entrypoint) |

---

## Warnings

| ID | Warning | Impact |
|----|---------|--------|
| W1 | **redi-sby-01 not deployed** — LXC cannot run Docker | No secondary edge gateway |
| W2 | **Traefik image upgraded** `v3.3.4` → `v3.6.1` for Docker 29 compatibility | Documented deviation |
| W3 | **gateway-file-probe** returns HTTP 502 | File provider routes correctly; backend targets `127.0.0.1:8080/ping` (loopback) |
| W4 | **Cross-node mesh TCP** to jkt `:8080` times out from sby | Same pattern as PowerDNS API (Stage 2 R4); on-node mesh access works |
| W5 | **No Docker-discovered routes** yet | Expected — no application services with `traefik.enable=true` |

---

## Deployment Artifacts

| Path | Purpose |
|------|---------|
| `/opt/redi/compose/traefik/docker-compose.yml` | Traefik + socket proxy stack |
| `/opt/redi/compose/traefik/.env` | Node config (chmod 600) |
| `/opt/redi/config/traefik/traefik.yml` | Static Traefik config |
| `/opt/redi/config/traefik/dynamic/` | File provider (routers, middlewares, probe, tls) |
| `/opt/redi/config/traefik/acme.json` | ACME certificate store (chmod 600) |
| `/opt/redi/logs/traefik/` | JSON application + access logs |
| `/opt/redi/scripts/deploy/deploy-traefik.sh` | Deploy automation |

### Networks

| Network | Bridge | Traefik attached |
|---------|--------|:----------------:|
| `redi-proxy` | `br-redi-proxy` | ✅ |
| `redi-dns` | `br-redi-dns` | ✅ |
| `redi-management` | `br-redi-mgmt` | ✅ |

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  REDI GATEWAY PLATFORM:  PASS WITH WARNINGS                       │
│                                                                   │
│  Primary (redi-jkt-01):   Traefik ✅  Socket Proxy ✅  Dashboard ✅ │
│  Secondary (redi-sby-01): NOT DEPLOYED (LXC Docker blocker)       │
│  Docker provider:         ✅ (v3.6.1 + Docker 29)                 │
│  File provider:           ✅                                      │
│  Public dashboard:        ✅ NOT EXPOSED                          │
│                                                                   │
│  Status: STOPPED — Awaiting CTO approval                          │
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

- ✅ Docker Compose used
- ✅ REDI Docker networks used
- ✅ Configuration under `/opt/redi`
- ✅ Docker Provider, File Provider, Dashboard, Healthcheck, Access Log, JSON Log enabled
- ✅ Automatic service discovery (Docker watch) enabled
- ✅ Dashboard mesh-only (Tailscale IP binding)
- ✅ Docker Socket Proxy (no direct socket on Traefik)
- ✅ No application services deployed
- ⚠️ Secondary edge gateway deferred (infrastructure blocker)

---

*Report generated: 2026-06-29 — RAS v1.0 Stage 3*
