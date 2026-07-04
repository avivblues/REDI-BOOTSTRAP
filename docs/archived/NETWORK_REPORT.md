# REDI LAB — Stage 2: Tailscale Network Report

**Date:** 2026-06-29  
**Status:** ⏸️ **BLOCKED — Awaiting Tailscale Auth Key**

---

## Summary

Stage 2 cannot proceed. Tailscale 1.98.4 is **installed** on both physical hosts but nodes are **not joined** to the mesh. The `configure-tailscale.sh` script requires a valid `TAILSCALE_AUTH_KEY` in `inventory/servers.env`.

---

## Current State

| Node | Tailscale Package | Connected | Tailscale IP |
|------|-------------------|-----------|--------------|
| `redi-jkt-01` | 1.98.4 ✅ | ❌ | — |
| `redi-sby-01` | 1.98.4 ✅ | ❌ | — |
| `redi-mgmt-01` | *(colocated on sby)* | ❌ | — |

---

## Blocker

```
inventory/servers.env → TAILSCALE_AUTH_KEY=tskey-auth-REPLACE_ME
```

No production auth key has been provided.

---

## Required Action

1. Generate a reusable auth key at [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
   - Enable: Reusable, Ephemeral (optional), Pre-authorized
   - Add tags if using ACLs: `tag:redi-edge`, `tag:redi-management`

2. Create `/opt/redi/inventory/servers.env` on each server:

```bash
cp /opt/redi/inventory/servers.env.example /opt/redi/inventory/servers.env
chmod 600 /opt/redi/inventory/servers.env
# Edit TAILSCALE_AUTH_KEY and all passwords
```

3. Run on each node:

```bash
sudo /opt/redi/scripts/bootstrap/configure-tailscale.sh
```

4. Validate:

```bash
tailscale status
tailscale ping redi-jkt-01
tailscale ping redi-sby-01
```

---

## Expected Post-Stage-2 Validation

| Check | Target |
|-------|--------|
| Mesh connectivity | All nodes `tailscale status` shows connected |
| Latency jkt ↔ sby | `< 100ms` (Indonesia domestic) |
| Routing | `tailscale ping` succeeds between all nodes |
| No public IP dependency | Internal services bind to Tailscale IP |

---

## Decision

```
┌─────────────────────────────────────────────────────────┐
│  STAGE 2 RESULT: BLOCKED                                    │
│  STAGE 3 PowerDNS: NOT STARTED                              │
│  Action: Provide TAILSCALE_AUTH_KEY to continue             │
└─────────────────────────────────────────────────────────┘
```

---

*Report generated: 2026-06-29T08:30 UTC*
