# REDI LAB — Network Foundation Report

**Task:** REDI Agent Task 002  
**RAS Version:** 1.0  
**Stage:** 1.1 — Network Foundation  
**Permission:** LEVEL 1  
**Date:** 2026-06-29  
**Inventory:** `inventory/servers.example.yaml`  
**Secrets:** `secrets/servers.yaml`, `secrets/api-keys.yaml`  

---

## Executive Summary

Tailscale mesh **activated on all 3 VPS**. Every node is authenticated to the same tailnet (`avivblues@`) and private connectivity verified via `tailscale ping` in all directions.

| Objective | Result |
|-----------|--------|
| Install / activate `tailscaled` on all nodes | ✅ |
| Authenticate nodes to same Tailscale network | ✅ |
| Verify private connectivity (mesh ping) | ✅ 6/6 pairs |
| Verify MagicDNS | ⚠️ Tailnet enabled; nodes use `--accept-dns=false` |
| Verify stable Tailscale IP communication | ✅ |
| Public networking unchanged | ✅ |
| No Docker services deployed | ✅ |

**Decision: PASS WITH WARNINGS**

---

## Node Status

| Node | Role | Public Endpoint | Hostname | Tailscale Ver. | `tailscaled` | Mesh Status | Tailscale IP |
|------|------|-----------------|----------|----------------|--------------|-------------|--------------|
| `redi-jkt-01` | Edge Primary | `devapp@103.149.238.98:22` | `redi-jkt-01` | 1.98.4 | ✅ active | ✅ Online | `100.79.82.92` |
| `redi-sby-01` | Edge Secondary | `root@103.80.214.144:2280` | `redi-sby-01` | 1.98.4 | ✅ active | ✅ Online | `100.79.40.61` |
| `redi-mjk-01` | Management | `root@103.80.214.226:2280` | `redi-mjk-01` | 1.98.4 | ✅ active | ✅ Online | `100.116.166.60` |

### Node configuration persisted

Each node has `/opt/redi/config/tailscale/node.env` with hostname and Tailscale IP.

### LXC userspace networking

`redi-sby-01` and `redi-mjk-01` (Proxmox LXC) use `--tun=userspace-networking` via systemd drop-in. Mesh connectivity confirmed working.

---

## Peer Connectivity Matrix

All tests via `tailscale ping -c 2` using MagicDNS hostnames.

| From ↓ / To → | `redi-jkt-01` | `redi-sby-01` | `redi-mjk-01` |
|---------------|:-------------:|:-------------:|:-------------:|
| `redi-jkt-01` (`100.79.82.92`) | — | ✅ 12ms | ✅ 13ms |
| `redi-sby-01` (`100.79.40.61`) | ✅ 12ms | — | ✅ 2ms |
| `redi-mjk-01` (`100.116.166.60`) | ✅ 13ms | ✅ 2ms | — |

### Tailscale IP ping (from `redi-mjk-01`)

| Target IP | Result |
|-----------|--------|
| `100.79.82.92` (jkt) | ✅ pong 13ms |
| `100.79.40.61` (sby) | ✅ pong 1ms |

---

## Exit Node Status

| Node | Exit Node | Exit Node Option |
|------|:---------:|:----------------:|
| `redi-jkt-01` | ❌ No | ❌ No |
| `redi-sby-01` | ❌ No | ❌ No |
| `redi-mjk-01` | ❌ No | ❌ No |

No exit node configured. Public routing unchanged.

---

## MagicDNS Status

| Setting | Value |
|---------|-------|
| Tailnet MagicDNS (admin) | Enabled |
| Node `--accept-dns` | `false` (per REDI policy) |
| Local hostname resolve (`getent hosts redi-jkt-01`) | ❌ Not configured on nodes |

Nodes communicate via Tailscale hostnames in `tailscale ping` / `tailscale status`. Local OS resolver does not use MagicDNS — intentional for PowerDNS rollout in Stage 3.

---

## Auth Key & Rotation Reminder

| Field | Value |
|-------|-------|
| Secret ID | `tailscale-auth-key` |
| Provisioned | 2026-06-29 |
| **Rotate by** | **2026-09-27** (90 days) |
| Storage | `secrets/api-keys.yaml` |

### Notifications scheduled

| Channel | When | Detail |
|---------|------|--------|
| `secrets/api-keys.yaml` metadata | 2026-09-27 | `reminders.tailscale-auth-key-expiry` |
| `docs/reminders/TAILSCALE_AUTH_KEY_ROTATION.md` | Permanent | Runbook for rotation |
| macOS `launchd` | 2026-09-27 09:00 | `com.redi.tailscale-key-rotation` — desktop notification |

> Nodes already joined remain connected after key expiry. New key only needed for enrolling additional devices.

---

## Warnings

| ID | Warning | Severity |
|----|---------|----------|
| W1 | Auth key expires 2026-09-27 — rotation required for new enrollments | Medium |
| W2 | LXC nodes use userspace networking | Low |
| W3 | MagicDNS not accepted locally (`--accept-dns=false`) | Info |
| W4 | TCP to `100.79.82.92:22` from mesh timed out — UFW on jkt may need `tailscale0` rule for SSH-over-mesh | Low |
| W5 | Password SSH still active on all nodes | High |

---

## Compliance Checklist

| Requirement | Status |
|-------------|--------|
| Used existing inventory and secrets | ✅ |
| No public networking changes | ✅ |
| No routing changes outside Tailscale | ✅ |
| No Docker services deployed | ✅ |
| No PowerDNS / Portainer / GitLab | ✅ |
| Mesh authenticated and verified | ✅ |

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  NETWORK FOUNDATION:  PASS WITH WARNINGS                            │
│                                                                   │
│  tailscaled active:    3 / 3                                      │
│  Mesh joined:          3 / 3                                      │
│  Tailscale IPs:        3 / 3                                      │
│  Peer connectivity:    6 / 6 PASS                                 │
│                                                                   │
│  Auth key rotation due: 2026-09-27 (notification scheduled)      │
│                                                                   │
│  Status: COMPLETE — Awaiting CTO approval for Stage 2+             │
└──────────────────────────────────────────────────────────────────┘
```

| Outcome | Selected |
|---------|----------|
| PASS | |
| **PASS WITH WARNINGS** | **✓** |
| FAIL | |

---

*Report generated: 2026-06-29 — RAS v1.0 Stage 1.1 (mesh activated)*
