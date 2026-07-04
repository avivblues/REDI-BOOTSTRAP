# REDI LAB — Stage 1: Bootstrap Report

**Date:** 2026-06-29  
**Status:** ✅ **PASSED**

---

## Summary

Bootstrap executed on both physical VPS hosts. All base packages, security tooling, and directory structure are in place. Tailscale package installed but **not yet joined to mesh** (Stage 2).

| Host | Bootstrap | Duration | Log |
|------|-----------|----------|-----|
| `redi-jkt-01` | ✅ Complete | ~2 min (partial) + resume | `/opt/redi/logs/bootstrap-20260629-082519.log` |
| `redi-sby-01` | ✅ Complete | ~2.5 min | `/opt/redi/logs/bootstrap-20260629-082644.log` |
| `redi-mgmt-01` | ✅ Via VPS2 | Same host as sby | — |

---

## Installed Components

| Component | redi-jkt-01 | redi-sby-01 |
|-----------|:-------------:|:-------------:|
| apt packages (git, curl, jq, htop, vim, rsync) | ✅ | ✅ |
| Docker CE 29.6.1 | ✅ (pre-existing) | ✅ (pre-existing) |
| Docker Compose v5.2.0 | ✅ | ✅ |
| Chrony NTP | ✅ active | ✅ active |
| UFW firewall | ✅ active | ✅ active |
| Fail2Ban | ✅ active | ✅ active |
| Tailscale 1.98.4 | ✅ installed | ✅ installed |
| `/opt/redi` directory tree | ✅ | ✅ |

---

## UFW Rules Applied

### redi-jkt-01 (SSH port 22)

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (ACME) |
| 443 | TCP | HTTPS (Traefik) |
| 53 | TCP/UDP | DNS |
| * | tailscale0 | Tailscale mesh |
| 8081 | TCP | PowerDNS API (100.64.0.0/10) |
| 3306 | TCP | MariaDB replication (100.64.0.0/10) |

### redi-sby-01 (SSH port 2280)

Same as above except SSH on **2280**.

---

## Fail2Ban

| Host | SSH Port | Jail Status |
|------|----------|-------------|
| `redi-jkt-01` | 22 | active, 0 banned |
| `redi-sby-01` | 2280 | active, 0 banned |

---

## Directory Structure Created

```
/opt/redi/
├── compose/{powerdns,traefik,portainer,gitlab}
├── config/{powerdns,traefik,gitlab,tailscale}
├── data/{powerdns,traefik,portainer,gitlab}
├── backup/{powerdns,traefik,portainer,gitlab}
├── logs/{powerdns,traefik,portainer,gitlab}
├── scripts/{bootstrap,deploy,backup,restore,lib}
├── docs/
└── inventory/
```

`config/traefik/acme.json` created with mode `600`.

---

## Issues Encountered & Resolved

| Issue | Resolution |
|-------|------------|
| Fail2Ban status check raced service start on jkt | Added retry loop in `05-install-fail2ban.sh` |
| Bootstrap interrupted on jkt at step 05 | Resumed steps 06–07 manually |
| `inventory/servers.env` not present | Expected — secrets to be configured before Stage 2 |

---

## Post-Bootstrap Verification

### redi-jkt-01

```
Hostname:    redi-jkt-01
Docker:      29.6.1 [active]
Compose:     v5.2.0
Chrony:      active
UFW:         active
Fail2Ban:    active
Tailscale:   1.98.4 (not connected)
Containers:  0
```

### redi-sby-01

```
Hostname:    redi-sby-01
Docker:      29.6.1 [active]
Compose:     v5.2.0
Chrony:      active
UFW:         active
Fail2Ban:    active
Tailscale:   1.98.4 (not connected)
Containers:  0
```

---

## Warnings

| # | Warning | Impact |
|---|---------|--------|
| W1 | Chrony not yet synced to NTP upstream | Should resolve within minutes |
| W2 | Tailscale installed but not configured | **Blocks Stage 2** |
| W3 | `inventory/servers.env` missing on servers | **Blocks Stage 2+** |
| W4 | Native process on port 20128 (`next-server`) on sby | Does not conflict with REDI services |

---

## Decision

```
┌─────────────────────────────────────────────────────────┐
│  STAGE 1 RESULT: PASSED                                   │
│  STAGE 2 TAILSCALE: BLOCKED — requires TAILSCALE_AUTH_KEY  │
└─────────────────────────────────────────────────────────┘
```

### Required before Stage 2

1. Create `inventory/servers.env` on each server with production secrets
2. Provide valid `TAILSCALE_AUTH_KEY` (reusable, pre-authorized)
3. Run `configure-tailscale.sh` on all nodes

---

*Report generated: 2026-06-29T08:30 UTC*
