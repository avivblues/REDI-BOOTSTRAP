# REDI LAB — DNS Blueprint Report

**Task:** REDI Agent Task 008A — DNS Blueprint Initialization  
**RAS Version:** 1.0  
**Stage:** 4A — DNS Blueprint  
**Permission:** LEVEL 2  
**Date:** 2026-06-29  
**Authority:** `redi-jkt-01` (PowerDNS primary, `ns1.letsredi.com`)

---

## Executive Summary

Production zone **`letsredi.com`** initialized per Task 008A blueprint. PowerDNS on **redi-jkt-01** remains the single source of truth. The apply run created **33 missing records** only; **33 existing records were skipped**; **SOA, NS, and glue records were not modified**.

**23 policy conflicts** were detected: legacy placeholder A records still point to management mesh (`100.81.86.37`) instead of the REDI Gateway (`103.149.238.98`). Per task requirements, these were **not overwritten**.

**Decision: PASS WITH WARNINGS**

---

## Zone Summary

| Attribute | Value |
|-----------|-------|
| Zone | `letsredi.com` |
| Backend | MariaDB (PowerDNS native) |
| Total RRs (after apply) | **75** |
| SOA serial | **`2026062904`** (unchanged) |
| SOA TTL | 3600 |
| New record TTL | 3600 |
| Nameservers | `ns1.letsredi.com`, `ns2.letsredi.com` |
| REDI Gateway (Traefik) | `proxy.letsredi.com` → `traefik-jkt.letsredi.com` → `100.79.82.92` (mesh) / `103.149.238.98` (public) |

---

## Apply Results

| Metric | Count |
|--------|------:|
| **Created (new)** | 33 |
| — Placeholders → gateway | 30 |
| — LAB production (mesh) | 3 |
| **Skipped (already exist)** | 33 |
| **Protected (glue/SOA/NS)** | 2 |
| **Conflicts (skipped, not overwritten)** | 23 |

Apply log: `/opt/redi/logs/dns-008a-apply.log` on `redi-jkt-01`

---

## Existing Records (Preserved — Not Modified)

### Protected infrastructure (never touched)

| Hostname | Type | Content | Note |
|----------|------|---------|------|
| `letsredi.com` | SOA | `ns1.letsredi.com. hostmaster.letsredi.com. 2026062904 …` | Unchanged |
| `letsredi.com` | NS | `ns1.letsredi.com` | Unchanged |
| `letsredi.com` | NS | `ns2.letsredi.com` | Unchanged |
| `ns1.letsredi.com` | A | `103.149.238.98` | Glue — protected |
| `ns2.letsredi.com` | A | `103.80.214.144` | Glue — protected |

### Skipped — matching blueprint (no conflict)

| Hostname | Type | Content | Status |
|----------|------|---------|--------|
| `dns.letsredi.com` | CNAME | `ns1.letsredi.com` | Production |
| `proxy.letsredi.com` | CNAME | `traefik-jkt.letsredi.com` | Production |
| `mesh.letsredi.com` | A | `100.79.82.92` | Production |
| `gateway.letsredi.com` | CNAME | `proxy.letsredi.com` | Production |
| `ops.letsredi.com` | CNAME | `portainer.letsredi.com` | Production |
| `portainer.letsredi.com` | A | `100.81.86.37` | Production (mesh) |
| `api.letsredi.com` | CNAME | `traefik-jkt.letsredi.com` | Production |
| `apps.letsredi.com` | CNAME | `proxy.letsredi.com` | Placeholder |
| `runtime.letsredi.com` | CNAME | `proxy.letsredi.com` | Placeholder |
| `status.letsredi.com` | CNAME | `proxy.letsredi.com` | Production (landing) |

### Skipped — apex & supporting (pre-existing, not in 008A apply set)

| Hostname | Type | Content |
|----------|------|---------|
| `letsredi.com` | A | `103.149.238.98` |
| `www.letsredi.com` | CNAME | `letsredi.com` |
| `traefik-jkt.letsredi.com` | A | `100.79.82.92` |
| `traefik-sby.letsredi.com` | A | `100.67.138.25` |

---

## New Records (Created)

### Management

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `vault.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `runner.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Knowledge

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `taxonomy.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `objects.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### AI

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `models.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `prompt.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Runtime

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `storage.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `queue.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `events.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Data Platform

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `postgres.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `redis.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `neo4j.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `qdrant.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `minio.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `mongodb.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `mariadb.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Security

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `security.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `ca.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `pki.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `secret.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `kms.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Integration

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `nats.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `mqtt.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `webhook.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `integration.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Cloud

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `customer.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### Development

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `dev.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `staging.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `sandbox.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |
| `test.letsredi.com` | A | `103.149.238.98` | 3600 | PLACEHOLDER |

### LAB (production mesh pointers)

| Hostname | Type | Target | TTL | Status |
|----------|------|--------|-----|--------|
| `jkt.lab.letsredi.com` | A | `100.79.82.92` | 3600 | Production |
| `sby.lab.letsredi.com` | A | `100.67.138.25` | 3600 | Production |
| `mjk.lab.letsredi.com` | A | `100.81.86.37` | 3600 | Production |

---

## Placeholder Records (Zone Inventory)

**Policy (008A):** Undeployed services → A record at REDI Gateway (`103.149.238.98`).

| Category | Hostnames | Current target | Notes |
|----------|-----------|----------------|-------|
| **New placeholders (gateway)** | `vault`, `runner`, `taxonomy`, `objects`, `models`, `prompt`, `storage`, `queue`, `events`, data platform (7), security (5), integration (4), `customer`, dev env (4) | `103.149.238.98` | Created this run |
| **Legacy placeholders (mesh)** | `git`, `registry`, `auth`, knowledge (5), AI (5), observability (6), cloud (4) | `100.81.86.37` | Pre-existing — skipped |
| **CNAME placeholders** | `apps`, `runtime` | `proxy.letsredi.com` | Pre-existing — skipped |

---

## Skipped Records (Full List)

Every blueprint record that already existed was skipped. Records with **matching content** are listed under [Existing Records](#existing-records-preserved--not-modified). Records below were skipped due to **content conflict** (see next section).

---

## Conflicts (Not Overwritten)

23 legacy A records exist at **`100.81.86.37`** (mjk mesh). Blueprint policy expects **`103.149.238.98`** (REDI Gateway). Per Task 008A: *do not overwrite existing production records* — all left intact.

| Hostname | Existing | Blueprint target |
|----------|----------|------------------|
| `git.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `registry.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `auth.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `capture.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `knowledge.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `graph.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `search.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `docs.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `ai.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `agents.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `studio.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `flow.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `llm.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `grafana.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `prometheus.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `loki.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `uptime.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `monitor.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `logs.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `cloud.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `console.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `billing.letsredi.com` | `100.81.86.37` | `103.149.238.98` |
| `marketplace.letsredi.com` | `100.81.86.37` | `103.149.238.98` |

---

## Validation Results

| Check | Result | Detail |
|-------|--------|--------|
| Zone exists | ✅ PASS | `letsredi.com` in PowerDNS MariaDB |
| Zone integrity | ✅ PASS | 75 RRs, PDNS reload OK |
| SOA unchanged | ✅ PASS | Serial `2026062904`, TTL 3600 |
| NS unchanged | ✅ PASS | `ns1` + `ns2` at apex |
| Glue unchanged | ✅ PASS | `ns1` → `103.149.238.98`, `ns2` → `103.80.214.144` |
| Duplicate RRsets | ✅ PASS | No duplicate `(name,type)` pairs (dual NS at apex expected) |
| Local resolution | ✅ PASS | New records resolve on `@127.0.0.1` |
| Public resolution | ✅ PASS | SOA/NS/A verified via `8.8.8.8`, `1.1.1.1` |
| Sample new RRs | ✅ PASS | `vault`, `postgres`, `security` → `103.149.238.98` |
| LAB RRs | ✅ PASS | `jkt.lab` → `100.79.82.92`, `sby.lab` → `100.67.138.25`, `mjk.lab` → `100.81.86.37` |

---

## Warnings

| ID | Warning | Recommendation |
|----|---------|----------------|
| W1 | **23 legacy placeholders** point to mjk mesh, not gateway | Schedule CTO-approved migration to `103.149.238.98` when services go live |
| W2 | **Mixed TTL** — legacy records TTL 300, new records TTL 3600 | Normalize TTLs in a future maintenance window |
| W3 | **`ns2.letsredi.com`** glue published but no authoritative DNS on sby | Deploy PowerDNS replica on `redi-sby-01` |
| W4 | **SOA serial not bumped** — intentional per “do not modify SOA” | Bump serial in next approved zone change |

---

## Recommendations

1. **CTO approval** to migrate legacy placeholder A records (`100.81.86.37` → `103.149.238.98`) in a controlled change window.
2. Deploy **PowerDNS replica** on `redi-sby-01` so `ns2` answers authoritatively.
3. Document placeholder vs production status in `config/powerdns/letsredi-blueprint.yaml` (source of truth for future applies).
4. Re-run `apply-dns-blueprint.sh` after each new service go-live — script is idempotent (missing-only).

---

## Artifacts

| Path | Purpose |
|------|---------|
| `config/powerdns/letsredi-blueprint.yaml` | Full 008A blueprint (68 service definitions) |
| `scripts/deploy/apply-dns-blueprint.sh` | Idempotent missing-only apply |
| `/opt/redi/logs/dns-008a-apply.log` | Runtime apply log (jkt) |

---

## Decision

| Outcome | Selected |
|---------|----------|
| PASS | |
| **PASS WITH WARNINGS** | **✅** |
| BLOCKED | |
| FAIL | |

**Rationale:** All required missing records created. SOA/NS/glue protected. Zone validates locally and publicly. Warnings limited to legacy placeholder target drift (not overwritten per policy) and secondary NS not yet authoritative.

---

## CTO Approval

**Task 008A complete.** Pipeline stopped pending CTO review. **Do not proceed to Stage 4B** until approved.
