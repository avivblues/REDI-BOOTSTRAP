# REDI LAB — Infrastructure Validation Report

**Specification:** RAS v1.0  
**Stage:** 1 — Validation (re-run)  
**Permission:** LEVEL 0 — READ ONLY  
**Date:** 2026-06-29  
**Inventory:** `inventory/servers.example.yaml`  
**Secrets:** `secrets/servers.yaml` (loaded locally)  

---

## Executive Summary

Read-only validation executed against **all 3 declared VPS** nodes. Each node is **reachable**, **authenticated**, and reports the **expected hostname**. All nodes run Ubuntu 22.04 with Docker and Compose installed.

| Node | Reachability | Auth | Hostname | OS | Docker |
|------|:------------:|:----:|:--------:|:--:|:------:|
| `redi-jkt-01` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `redi-sby-01` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `redi-mjk-01` | ✅ | ✅ | ✅ | ✅ | ✅ |

**Inter-node connectivity** from Jakarta to both Surabaya and Mojokerto SSH ports: ✅ PASS

**Decision: PASS WITH WARNINGS**

Warnings relate to deployment readiness (Tailscale, bootstrap state on `redi-mjk-01`) — not connectivity failures.

---

## Reachability

| Node ID | Site | Endpoint | TCP/SSH | Result |
|---------|------|----------|---------|--------|
| `redi-jkt-01` | Jakarta | `devapp@103.149.238.98:22` | ✅ | PASS |
| `redi-sby-01` | Surabaya | `root@103.80.214.144:2280` | ✅ | PASS |
| `redi-mjk-01` | Mojokerto | `root@103.80.214.226:2280` | ✅ | PASS |

### Inter-node connectivity

| From | To | Test | Result |
|------|-----|------|--------|
| `redi-jkt-01` | `103.80.214.144:2280` (sby) | TCP | ✅ |
| `redi-jkt-01` | `103.80.214.226:2280` (mjk) | TCP | ✅ |

---

## Authentication Result

| Node | Method | Result |
|------|--------|--------|
| `redi-jkt-01` | Password (`ssh-password-redi-jkt-01`) | ✅ PASS |
| `redi-sby-01` | Password (`ssh-password-redi-sby-01`) | ✅ PASS |
| `redi-mjk-01` | Password (`ssh-password-redi-mjk-01`) | ✅ PASS |

**Warning:** Password authentication active on all nodes. No SSH private keys in `secrets/ssh.yaml`.

---

## Host Information

### `redi-jkt-01` — Edge Primary (Jakarta)

| Property | Inventory | Observed | Match |
|----------|-----------|----------|-------|
| Hostname | `redi-jkt-01` | `redi-jkt-01` | ✅ |
| Role | `role-edge-primary` | — | — |
| OS | Ubuntu 22.04 | 22.04.4 LTS | ✅ |
| Kernel | — | 5.15.0-185-generic | — |
| CPU | ≥ 2 | 12 vCPU | ✅ |
| RAM | ≥ 4 GB | 15 Gi (~14 Gi free) | ✅ |
| Disk `/` | ≥ 40 GB free | 96 GB, 78 GB free (16%) | ✅ |
| Docker | — | 29.6.1 active | ✅ |
| Compose | — | v5.2.0 | ✅ |
| Git | — | 2.34.1 | ✅ |
| Chrony | — | synchronized | ✅ |
| UFW | — | active | — |
| Fail2Ban | — | active | — |
| Tailscale | — | 1.98.4 — not connected | ⚠️ |
| `/opt/redi` | — | present | — |

**Open ports:** 22 (SSH), 53 (local resolver). Ports **80, 443** — free ✅

---

### `redi-sby-01` — Edge Secondary (Surabaya)

| Property | Inventory | Observed | Match |
|----------|-----------|----------|-------|
| Hostname | `redi-sby-01` | `redi-sby-01` | ✅ |
| Role | `role-edge-secondary` | — | — |
| OS | Ubuntu 22.04 | 22.04.5 LTS | ✅ |
| Kernel | — | 6.8.4-2-pve | — |
| CPU | ≥ 2 | 12 cores (Xeon E5630) | ✅ |
| RAM | ≥ 4 GB | 16 Gi (~15 Gi free) | ✅ |
| Disk `/` | ≥ 40 GB free | 197 GB, 184 GB free (3%) | ✅ |
| Docker | — | 29.6.1 active | ✅ |
| Compose | — | v5.2.0 | ✅ |
| Git | — | 2.34.1 | ✅ |
| Chrony | — | synchronized | ✅ |
| UFW | — | active | — |
| Fail2Ban | — | active | — |
| Tailscale | — | 1.98.4 — not connected | ⚠️ |
| `/opt/redi` | — | present | — |

**Open ports:** 2280 (SSH). Ports **80, 443** — free ✅

---

### `redi-mjk-01` — Management (Mojokerto)

| Property | Inventory | Observed | Match |
|----------|-----------|----------|-------|
| Hostname | `redi-mjk-01` | `redi-mjk-01` | ✅ |
| Role | `role-management` | — | — |
| OS | Ubuntu 22.04 | 22.04 LTS | ✅ |
| Kernel | — | 6.8.12-9-pve | — |
| CPU | ≥ 4 | 12 cores (Xeon E5-2680 v4) | ✅ |
| RAM | ≥ 8 GB | 16 Gi (~15 Gi free) | ✅ |
| Disk `/` | ≥ 100 GB free | 196 GB, 185 GB free (1%) | ✅ |
| Docker | — | 29.6.1 active | ✅ |
| Compose | — | v5.2.0 | ✅ |
| Git | — | 2.34.1 | ✅ |
| Time sync | — | systemd — synchronized | ✅ |
| UFW | — | **inactive** | ⚠️ |
| Fail2Ban | — | **NOT_INSTALLED** | ⚠️ |
| Tailscale | — | **NOT_INSTALLED** | ⚠️ |
| `/opt/redi` | — | **NOT_PRESENT** | ⚠️ |

**Open ports:** 2280 (SSH) only. Ports **80, 443** — free ✅

**Note:** `redi-mjk-01` is a clean management VPS — Docker installed but bootstrap not yet applied.

---

## Existing Workloads

| Node | Running containers | Docker networks (custom) |
|------|-------------------|--------------------------|
| `redi-jkt-01` | **0** | None |
| `redi-sby-01` | **0** | None |
| `redi-mjk-01` | **0** | None (default only) |

No conflicting application stacks detected on any node.

---

## Deployment Readiness

| Criterion | jkt | sby | mjk |
|-----------|:---:|:---:|:---:|
| SSH reachable | ✅ | ✅ | ✅ |
| Auth works | ✅ | ✅ | ✅ |
| Hostname matches inventory | ✅ | ✅ | ✅ |
| Ubuntu 22.04 | ✅ | ✅ | ✅ |
| CPU/RAM/disk minimums | ✅ | ✅ | ✅ |
| Docker + Compose | ✅ | ✅ | ✅ |
| No port 80/443 conflict (edge) | ✅ | ✅ | N/A |
| Bootstrap complete | ⚠️ partial | ⚠️ partial | ❌ |
| Tailscale connected | ❌ | ❌ | ❌ |
| SSH key auth | ❌ | ❌ | ❌ |
| Service API secrets | ❌ | ❌ | ❌ |

---

## Risks

| ID | Risk | Severity |
|----|------|----------|
| R1 | Password SSH on all nodes | High |
| R2 | Tailscale not connected (jkt, sby); not installed (mjk) | High |
| R3 | `redi-mjk-01` not bootstrapped — no UFW, Fail2Ban, `/opt/redi` | Medium |
| R4 | Prior bootstrap on jkt/sby may pre-date current inventory baseline | Low |
| R5 | Service secrets (Tailscale key, MariaDB, PDNS API) not populated | Medium |

---

## Warnings

| ID | Warning |
|----|---------|
| W1 | `redi-mjk-01` requires Stage 1 bootstrap before management services |
| W2 | `redi-jkt-01` and `redi-sby-01` have Tailscale package but mesh not joined |
| W3 | LXC/Proxmox kernels on sby (`6.8.4-2-pve`) and mjk (`6.8.12-9-pve`) |
| W4 | `redi-jkt-01` uses non-root `devapp` — sudo required for deployment |

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE VALIDATION:  PASS WITH WARNINGS                     │
│                                                                   │
│  Nodes validated:  3 / 3                                          │
│  Reachability:   3 / 3 PASS                                       │
│  Authentication: 3 / 3 PASS                                       │
│  Hostname:       3 / 3 PASS                                       │
│                                                                   │
│  Before Stage 1 deployment on redi-mjk-01:                        │
│  - Bootstrap required (UFW, Fail2Ban, Tailscale, /opt/redi)      │
│                                                                   │
│  Before Stage 2:                                                    │
│  - Tailscale auth key in secrets/api-keys.yaml                    │
│                                                                   │
│  Status: Awaiting CTO approval for Level 1                          │
└──────────────────────────────────────────────────────────────────┘
```

| Outcome | Selected |
|---------|----------|
| PASS | |
| **PASS WITH WARNINGS** | **✓** |
| FAIL | |

---

## Agent Compliance

- ✅ Inventory and secrets loaded from project files  
- ✅ Connected only to declared endpoints  
- ✅ No deployment, install, or configuration changes  
- ✅ No host rename, service restart, or container stop  
- ✅ No network scan outside inventory  
- ✅ No automatic remediation  

---

*Report generated: 2026-06-29 — RAS v1.0 READ ONLY re-validation*
