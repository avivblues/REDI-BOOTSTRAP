# REDI LAB — Validation Update (READ ONLY)

**Date:** 2026-06-29  
**Scope:** `redi-mjk-01` endpoint confirmation  
**Permission:** LEVEL 0 — no changes made  

---

## Target

| Field | Inventory value |
|-------|-----------------|
| Node ID | `redi-mjk-01` |
| Expected hostname | `redi-mjk-01` |
| Endpoint | `root@103.80.214.144:2280` |

---

## Results

| Check | Result |
|-------|--------|
| TCP / SSH reachability | ✅ PASS |
| Authentication (password) | ✅ PASS |
| Hostname `hostname -f` | ❌ **FAIL** — reports `redi-sby-01` |
| `/etc/hostname` | ❌ **FAIL** — contains `redi-sby-01` |
| Ubuntu 22.04 | ✅ PASS (22.04.5 LTS) |
| Docker / Compose | ✅ PASS (29.6.1 / v5.2.0) |
| Running containers | ✅ 0 |
| Ports 80/443 | ✅ Free |

---

## Observed Hostname

```
hostname -f  → redi-sby-01
hostname -s  → redi-sby-01
/etc/hostname → redi-sby-01
```

**Inventory expects:** `redi-mjk-01`  
**Live system reports:** `redi-sby-01`

---

## Topology Note

`redi-sby-01` and `redi-mjk-01` share the same endpoint (`103.80.214.144:2280`) and the same `machine-id` (`e6ec0c9829f544199620fbe6c6fe366e`). They resolve to **one physical host** currently hostnamed `redi-sby-01`.

---

## Decision

| Check | Status |
|-------|--------|
| Endpoint / port 2280 | ✅ PASS |
| Hostname `redi-mjk-01` | ❌ **FAIL** |

**Overall for this confirmation: FAIL** — SSH works, hostname not yet `redi-mjk-01` on the server.

---

## Required Action (requires approval — not performed)

To align live hostname with inventory (LEVEL 1+):

```bash
# On 103.80.214.144 (as root) — NOT executed by agent
hostnamectl set-hostname redi-mjk-01
# Update /etc/hosts: 127.0.1.1 redi-mjk-01
```

Alternatively, update inventory to `redi-sby-01` if that remains the canonical hostname.

---

*Awaiting CTO approval. No infrastructure modified.*
