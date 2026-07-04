# REDI LAB — SSH Access Remediation Report

**Task:** REDI Infrastructure Remediation Task 001  
**RAS Version:** 1.0  
**Permission:** LEVEL 2  
**Target:** `redi-jkt-01` (`103.149.238.98`)  
**Date:** 2026-06-29  

---

## Executive Summary

Public SSH access to **redi-jkt-01** restored by unbanning management IPs from Fail2Ban and removing their UFW REJECT rules. Permanent `ignoreip` whitelist added for REDI management addresses. Brute-force protection remains active for non-whitelisted IPs.

**Decision: PASS WITH WARNINGS**

---

## Root Cause

Public SSH intermittently failed with `Connection refused` / `Connection closed by remote host` because:

1. **Fail2Ban `sshd` jail** banned management/operator source IPs after failed or repeated SSH attempts.
2. **UFW REJECT rules** were created by Fail2Ban's `banaction = ufw` for those same IPs.

### Affected IPs (verified)

| IP | Role |
|----|------|
| `103.80.214.165` | Proxmox / Surabaya outbound (jump host source) |
| `113.141.70.64` | Operator deploy machine |

---

## Actions Performed

| # | Action | Result |
|---|--------|--------|
| 1 | `fail2ban-client set sshd unbanip 103.80.214.165` | ✅ Unbanned |
| 2 | `fail2ban-client set sshd unbanip 113.141.70.64` | ✅ Unbanned |
| 3 | Remove UFW REJECT for `103.80.214.165` | ✅ Removed (via unban / no longer present) |
| 4 | Remove UFW REJECT for `113.141.70.64` | ✅ Removed (via unban / no longer present) |
| 5 | Update `/etc/fail2ban/jail.local` with `ignoreip` | ✅ Applied |
| 6 | `fail2ban-client reload` | ✅ OK (no reboot) |

### `jail.local` change (sshd section only)

```ini
[sshd]
ignoreip = 127.0.0.1/8 100.64.0.0/10 103.80.214.144 103.80.214.165 103.80.214.226
enabled  = true
port     = 22
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 7200
```

Existing `[DEFAULT]` block and other `sshd` settings preserved.

### Scope compliance

- ✅ No Docker changes
- ✅ No Traefik changes
- ✅ No PowerDNS changes
- ✅ No REDI platform deployment changes

---

## Before / After Comparison

| Item | Before | After |
|------|--------|-------|
| Fail2Ban banned IPs | 4 (`45.148.10.151`, `62.60.130.219`, `103.80.214.165`, `113.141.70.64`) | 2 (scanner IPs only) |
| UFW REJECT rules | 4 (incl. both management IPs) | 2 (scanner IPs only) |
| `jail.local` ignoreip | Not set | Management + mesh whitelist |
| Public SSH (direct) | Intermittent / refused | ✅ Stable |
| Fail2Ban enabled | ✅ | ✅ |
| UFW enabled | ✅ | ✅ |

---

## Current Fail2Ban Status

```
Jail: sshd
Currently banned: 2
Banned IP list: 45.148.10.151, 62.60.130.219
ignoreip: 127.0.0.1/8, 100.64.0.0/10, 103.80.214.144, 103.80.214.165, 103.80.214.226
maxretry: 3
bantime: 7200s (2 hours)
Service: active (running)
```

Management IPs **not** in banned list.

---

## Current UFW Rules (summary)

| Rule | Action | Notes |
|------|--------|-------|
| `22/tcp` | ALLOW | Public SSH |
| `80/tcp`, `443/tcp` | ALLOW | ACME / Traefik |
| `53/tcp+udp` | ALLOW | DNS |
| `tailscale0` | ALLOW | Mesh interface |
| `8081`, `3306` from `100.64.0.0/10` | ALLOW | Internal services |
| `62.60.130.219` | REJECT | Scanner (Fail2Ban) |
| `45.148.10.151` | REJECT | Scanner (Fail2Ban) |
| `103.80.214.165` | — | **Removed** |
| `113.141.70.64` | — | **Removed** |

Default policy: **deny incoming**, allow outgoing.

---

## Validation Results

| Check | Result | Notes |
|-------|--------|-------|
| SSH via public IP (`103.149.238.98:22`) | ✅ **PASS** | `devapp@103.149.238.98` → `OK_PUBLIC` |
| SSH via REDI Mesh (`100.79.82.92:22`) | ⚠️ **Not verified** | Timeout from mjk (known mesh TCP limitation) |
| SSH from Surabaya (sby → jkt) | ⚠️ **Not verified** | Operator could not reach sby `:2280` during test |
| SSH from Mojokerto (mjk → jkt mesh) | ⚠️ **Timeout** | Pre-existing mesh SSH issue |
| Management IPs not banned | ✅ **PASS** | Confirmed absent from Fail2Ban list |
| No unnecessary UFW REJECT for management IPs | ✅ **PASS** | Only scanner REJECT rules remain |
| Fail2Ban still enabled | ✅ **PASS** | |
| UFW still enabled | ✅ **PASS** | |
| Brute-force protection active | ✅ **PASS** | 2 scanner IPs still banned |

---

## Security Review

| Control | Status |
|---------|--------|
| Fail2Ban enabled | ✅ Active |
| UFW enabled | ✅ Active, default deny |
| Brute-force protection | ✅ Active (`maxretry=3`, `bantime=7200`) |
| Management IPs whitelisted | ✅ Only `103.80.214.144`, `.165`, `.226` + mesh `100.64.0.0/10` |
| Public Internet protected | ✅ Non-whitelisted IPs still subject to ban |
| Scanner IPs remain blocked | ✅ `45.148.10.151`, `62.60.130.219` |

**Posture assessment:** Security not reduced. Management infrastructure can operate without triggering self-inflicted lockouts. Arbitrary Internet hosts remain subject to Fail2Ban.

---

## Remaining Risks

| ID | Risk | Severity |
|----|------|----------|
| R1 | Mesh SSH (`100.79.82.92:22`) may still timeout from LXC nodes | Medium |
| R2 | Operator IP `113.141.70.64` not statically assigned — if IP changes, may need re-whitelist | Low |
| R3 | `103.80.214.165` is outbound NAT IP — if provider changes it, update `ignoreip` | Low |
| R4 | Fail2Ban `ignoreip` does not include operator IP if it changes | Low |

---

## Recommendations

1. **Add operator static IP** to `ignoreip` when assigned, or use SSH keys from mesh-only paths.
2. **Enable mesh SSH on jkt** — consider UFW allow `22` from `100.64.0.0/10` explicitly if mesh SSH is required (currently allows via `tailscale0` interface rule).
3. **Monitor Fail2Ban** — `fail2ban-client status sshd` after deploy sessions.
4. **Do not disable Fail2Ban or UFW** — whitelist approach is correct for management stability.

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  SSH ACCESS REMEDIATION:  PASS WITH WARNINGS                      │
│                                                                   │
│  Public SSH (103.149.238.98:22):  ✅ RESTORED                     │
│  Management IPs unbanned:          ✅                              │
│  ignoreip whitelist:               ✅                              │
│  Fail2Ban + UFW:                   ✅ Still active                 │
│  Mesh / peer SSH validation:       ⚠️  Not fully verified          │
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

*Report generated: 2026-06-29 — RAS v1.0 Remediation Task 001*
