# REDI LAB — OS Foundation Report

**Task:** REDI Agent Task 004  
**RAS Version:** 1.0  
**Stage:** 1.2 — Operating System Foundation  
**Permission:** LEVEL 1  
**Date:** 2026-06-29  
**Inventory:** `inventory/servers.example.yaml`  
**Script:** `scripts/bootstrap/os-foundation.sh`  

---

## Executive Summary

Operating system foundation standardized across **all 3 infrastructure nodes**. Chrony, Fail2Ban, and UFW configured per approved REDI baseline. Docker was **not modified**; no containers deployed.

| Node | Chrony | Fail2Ban | UFW | SSH | Tailscale |
|------|:------:|:--------:|:---:|:---:|:---------:|
| `redi-jkt-01` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `redi-sby-01` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `redi-mjk-01` | ✅ | ✅ | ✅ | ✅ | ✅ |

**Decision: PASS**

---

## Installed Components

| Component | Version / Package | Applied On |
|-----------|-------------------|------------|
| Chrony | `chrony` (Ubuntu 22.04) | All 3 nodes |
| Fail2Ban | `0.11.2-6` | All 3 nodes |
| UFW | Ubuntu `ufw` | All 3 nodes |
| Base packages | `01-install-packages.sh` | All 3 nodes (rsync, jq, curl, etc.) |

### Not installed / not modified (per scope)

| Item | Status |
|------|--------|
| Docker | Untouched |
| Containers | 0 running (unchanged) |
| PowerDNS / Traefik / Portainer / GitLab | Not deployed |

---

## Service Status

### `redi-jkt-01` — Edge Primary (Jakarta)

| Service | Status | Detail |
|---------|--------|--------|
| Chrony | ✅ active | Leap status: Normal; ref: `id-ntp.com` |
| Fail2Ban | ✅ active | SSH jail port **22**; 7 IPs banned (brute-force) |
| UFW | ✅ active | Default deny inbound |
| Docker | ✅ active | 0 containers |
| Tailscale | ✅ online | `100.79.82.92` |

### `redi-sby-01` — Edge Secondary (Surabaya)

| Service | Status | Detail |
|---------|--------|--------|
| Chrony | ✅ active | Leap status: Normal; ref: `ipv4-9-159-252.as55666.net` |
| Fail2Ban | ✅ active | SSH jail port **2280** |
| UFW | ✅ active | Default deny inbound |
| Docker | ✅ active | 0 containers |
| Tailscale | ✅ online | `100.79.40.61` |

### `redi-mjk-01` — Management (Mojokerto)

| Service | Status | Detail |
|---------|--------|--------|
| Chrony | ✅ active | Migrated from `systemd-timesyncd`; Leap status: Normal |
| Fail2Ban | ✅ active | SSH jail port **2280** (newly installed) |
| UFW | ✅ active | Default deny inbound (newly enabled) |
| Docker | ✅ active | 0 containers |
| Tailscale | ✅ online | `100.116.166.60` |

---

## Firewall Summary

### `redi-jkt-01` (edge — SSH port 22)

| Rule | Action | Source |
|------|--------|--------|
| 22/tcp | ALLOW | Anywhere (SSH) |
| 80, 443/tcp | ALLOW | Anywhere (Traefik / ACME) |
| 53/tcp, 53/udp | ALLOW | Anywhere (DNS) |
| `tailscale0` | ALLOW IN | Anywhere (kernel TUN) |
| 8081, 3306/tcp | ALLOW | `100.64.0.0/10` (mesh internal) |
| Specific IPs | REJECT | Fail2Ban bans (9 entries) |

### `redi-sby-01` (edge — SSH port 2280)

| Rule | Action | Source |
|------|--------|--------|
| 2280/tcp | ALLOW | Anywhere (SSH) |
| 80, 443/tcp | ALLOW | Anywhere (Traefik / ACME) |
| 53/tcp, 53/udp | ALLOW | Anywhere (DNS) |
| All ports | ALLOW | `100.64.0.0/10` (userspace Tailscale) |
| 8081, 3306/tcp | ALLOW | `100.64.0.0/10` (mesh internal) |

### `redi-mjk-01` (management — SSH port 2280)

| Rule | Action | Source |
|------|--------|--------|
| 2280/tcp | ALLOW | Anywhere (SSH) |
| All ports | ALLOW | `100.64.0.0/10` (userspace Tailscale) |
| 8081, 3306/tcp | ALLOW | `100.64.0.0/10` (mesh internal) |
| 80, 443, 53 | — | Not exposed (management tier) |

### Tailscale / UFW compatibility

| Node | Tailscale mode | UFW mesh rule |
|------|----------------|---------------|
| `redi-jkt-01` | Kernel TUN (`tailscale0`) | `allow in on tailscale0` |
| `redi-sby-01` | Userspace (Proxmox LXC) | `allow from 100.64.0.0/10` |
| `redi-mjk-01` | Userspace (Proxmox LXC) | `allow from 100.64.0.0/10` |

---

## Validation Results

### Chrony synchronization

| Node | `chrony` active | NTP sync | Leap status |
|------|:---------------:|:--------:|:-----------:|
| `redi-jkt-01` | ✅ | ✅ | Normal |
| `redi-sby-01` | ✅ | ✅ | Normal |
| `redi-mjk-01` | ✅ | ✅ | Normal |

NTP pools: `0–3.id.pool.ntp.org` (Indonesia pools per baseline).

### Fail2Ban

| Node | Service active | `sshd` jail | SSH port |
|------|:------------:|:-----------:|:--------:|
| `redi-jkt-01` | ✅ | ✅ enabled | 22 |
| `redi-sby-01` | ✅ | ✅ enabled | 2280 |
| `redi-mjk-01` | ✅ | ✅ enabled | 2280 |

### UFW without disrupting SSH or Tailscale

| Check | Result |
|-------|--------|
| Public SSH to `redi-jkt-01:22` | ✅ Reachable |
| Public SSH to `redi-sby-01:2280` | ✅ Reachable |
| Public SSH to `redi-mjk-01:2280` | ✅ Reachable |
| `tailscale ping` jkt → sby | ✅ 12ms |
| `tailscale ping` jkt → mjk | ✅ 13ms |
| `tailscale ping` sby → jkt | ✅ 12ms |
| `tailscale ping` mjk → sby | ✅ 2ms |

### Existing services preserved

| Node | Running containers | Listening services | Impact |
|------|:------------------:|--------------------|--------|
| `redi-jkt-01` | 0 | SSH 22, Tailscale 41641 | None |
| `redi-sby-01` | 0 | SSH 2280, Tailscale | None |
| `redi-mjk-01` | 0 | SSH 2280, Tailscale | None |

No production application stacks were running prior to or after this stage.

---

## Security Observations

| ID | Observation | Severity |
|----|-------------|----------|
| S1 | Password SSH on all nodes — migrate to keys in `secrets/ssh.yaml` | High |
| S2 | `redi-jkt-01` Fail2Ban actively blocking 7 brute-force IPs | Info |
| S3 | UFW default deny inbound on all nodes | Positive |
| S4 | Management node (`redi-mjk-01`) exposes only SSH + mesh — no public HTTP/DNS | Positive |
| S5 | LXC nodes use userspace Tailscale — mesh allowed via CGNAT CIDR, not interface | Info |
| S6 | `redi-mjk-01` migrated from `systemd-timesyncd` to Chrony | Info |

---

## Warnings

| ID | Warning |
|----|---------|
| W1 | UFW `reset` on `redi-jkt-01` cleared manual REJECT rules; Fail2Ban re-applied bans automatically |
| W2 | Proxmox LXC kernels lack `/dev/net/tun` — userspace Tailscale + CIDR firewall rule used |

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  OS FOUNDATION:  PASS                                              │
│                                                                   │
│  Nodes standardized:   3 / 3                                      │
│  Chrony synchronized:  3 / 3                                      │
│  Fail2Ban active:      3 / 3                                      │
│  UFW active:           3 / 3                                      │
│  SSH + Tailscale:      Verified                                   │
│  Docker/containers:    Unchanged                                  │
│                                                                   │
│  Status: COMPLETE — Awaiting CTO approval for Stage 2+             │
└──────────────────────────────────────────────────────────────────┘
```

| Outcome | Selected |
|---------|----------|
| **PASS** | **✓** |
| BLOCKED | |
| FAIL | |

---

## Agent Compliance

- ✅ Inventory and secrets used for connection only  
- ✅ Chrony, Fail2Ban, UFW per approved baseline scripts  
- ✅ Docker not modified; no containers deployed  
- ✅ No PowerDNS / Traefik / Portainer / GitLab  
- ✅ SSH and Tailscale connectivity verified post-change  

---

*Report generated: 2026-06-29 — RAS v1.0 Stage 1.2*
