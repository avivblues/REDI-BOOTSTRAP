# REDI LAB — DNS Placeholder Policy Report

**Task:** REDI Agent Task 008C — DNS Placeholder Policy Migration  
**RAS Version:** 1.0  
**Stage:** 4C — DNS Placeholder Policy  
**Permission:** LEVEL 2  
**Date:** 2026-06-29  
**Authority:** PowerDNS on `redi-jkt-01` (`ns1.letsredi.com`)

---

## Executive Summary

Task 008C aligned all placeholder DNS records with the **canonical REDI Placeholder Policy** (`config/powerdns/placeholder-policy.yaml`). This was a **DNS-only policy migration** — no GitLab, Portainer, Traefik, or PowerDNS platform configuration was modified.

| Action | Count |
|--------|------:|
| Records migrated (final run) | **47** |
| Already compliant (skipped) | **9** |
| LAB records protected | **3** |
| Production records protected | **14** |
| Anchor created | `placeholder.letsredi.com` |

**Decision: PASS WITH WARNINGS**

---

## Policy Model (Canonical)

| Category | DNS target | Purpose |
|----------|------------|---------|
| **Public Platform** | `CNAME placeholder.letsredi.com` | Undeployed user-facing services → gateway landing chain |
| **Internal Platform** | `A 100.81.86.37` | Undeployed internal/data/observability services → mesh placeholder (not public) |
| **LAB** | Unchanged mesh A records | Direct node lab access |
| **Production** | Unchanged | Active services (ops, portainer, api, status, infrastructure) |

**Anchor record:**

| Hostname | Type | Target |
|----------|------|--------|
| `placeholder.letsredi.com` | CNAME | `proxy.letsredi.com` → `traefik-jkt.letsredi.com` → REDI Gateway |

---

## Audit — Record Classification

### Production (protected — not modified)

`letsredi.com`, `www`, `ns1`, `ns2`, `dns`, `proxy`, `mesh`, `gateway`, `api`, `ops`, `portainer`, `status`, `traefik-jkt`, `traefik-sby`

### LAB (protected — not modified)

| Hostname | Type | Target |
|----------|------|--------|
| `jkt.lab.letsredi.com` | A | `100.79.82.92` |
| `sby.lab.letsredi.com` | A | `100.67.138.25` |
| `mjk.lab.letsredi.com` | A | `100.81.86.37` |

### Public Platform (33 hostnames → `placeholder.letsredi.com`)

`git`, `registry`, `auth`, `apps`, `runtime`, `capture`, `knowledge`, `graph`, `search`, `docs`, `taxonomy`, `objects`, `ai`, `agents`, `studio`, `flow`, `llm`, `models`, `prompt`, `storage`, `queue`, `events`, `cloud`, `console`, `billing`, `marketplace`, `customer`, `dev`, `staging`, `sandbox`, `test`, `webhook`, `integration`

### Internal Platform (22 hostnames → `100.81.86.37`)

`postgres`, `redis`, `neo4j`, `qdrant`, `minio`, `mongodb`, `mariadb`, `vault`, `runner`, `prometheus`, `grafana`, `loki`, `mqtt`, `nats`, `monitor`, `logs`, `uptime`, `security`, `ca`, `pki`, `secret`, `kms`

### Unknown

None — all placeholder records in zone classified.

---

## Records Migrated

### Anchor (created)

| Hostname | Before | After |
|----------|--------|-------|
| `placeholder.letsredi.com` | *(missing)* | `CNAME proxy.letsredi.com` |

### Public Platform (32 migrated + 1 in partial run)

Legacy public placeholders migrated from:

- `A 100.81.86.37` (23 records — Task 008A debt), or
- `A 103.149.238.98` / `CNAME proxy.letsredi.com` (008A gateway placeholders)

→ **`CNAME placeholder.letsredi.com`** (TTL 3600)

### Internal Platform (15 migrated from gateway; 7 already internal)

Records at `103.149.238.98` from Task 008A corrected to internal mesh placeholder:

`redis`, `neo4j`, `qdrant`, `minio`, `mongodb`, `mariadb`, `vault`, `runner`, `mqtt`, `nats`, `security`, `ca`, `pki`, `secret`, `kms`

Plus `postgres` (first partial run).

---

## Records Skipped (already compliant)

| Hostname | Reason |
|----------|--------|
| `placeholder.letsredi.com` | Anchor correct after create |
| `git.letsredi.com` | Migrated in first partial run |
| `postgres.letsredi.com` | Internal target correct after first run |
| `prometheus`, `grafana`, `loki` | Already `100.81.86.37` |
| `monitor`, `logs`, `uptime` | Already `100.81.86.37` |

---

## Validation Results

| Check | Result | Detail |
|-------|--------|--------|
| Zone integrity | ✅ PASS | PDNS reload OK |
| SOA unchanged | ✅ PASS | Serial `2026062904` |
| NS unchanged | ✅ PASS | `ns1`, `ns2` |
| Glue unchanged | ✅ PASS | `103.149.238.98`, `103.80.214.144` |
| No duplicate RRsets | ✅ PASS | Dual NS at apex only (expected) |
| Public placeholder resolution | ✅ PASS | `git` → `placeholder` → `proxy` → gateway chain |
| Internal placeholders internal | ✅ PASS | `postgres`, `vault`, `nats` → `100.81.86.37` |
| LAB unchanged | ✅ PASS | All three lab hosts preserved |
| Production preserved | ✅ PASS | `ops`, `portainer`, `api`, `status` intact |
| Public resolver (8.8.8.8) | ✅ PASS | `git`, `postgres`, `jkt.lab` verified |

### Sample resolution (authoritative)

```
placeholder.letsredi.com → proxy.letsredi.com → traefik-jkt → 100.79.82.92
git.letsredi.com         → placeholder.letsredi.com → (same chain)
postgres.letsredi.com    → 100.81.86.37
jkt.lab.letsredi.com     → 100.79.82.92
ops.letsredi.com         → portainer.letsredi.com → 100.81.86.37
```

---

## Remaining Technical Debt

| ID | Item | Severity | Notes |
|----|------|----------|-------|
| D1 | Traefik host rule for `placeholder.letsredi.com` | Low | DNS chain reaches gateway; dedicated placeholder landing page optional |
| D2 | Mixed TTL (300 vs 3600) on some infrastructure RRs | Low | Normalize in future maintenance |
| D3 | `ns2` not authoritative | Medium | **Out of scope** — separate platform task |
| D4 | Blueprint YAML record targets not bulk-updated | Low | `placeholder-policy.yaml` is canonical classifier; run `migrate-dns-placeholder-policy.sh` for enforcement |

---

## Recommendations

1. **Future platform go-live:** Replace placeholder with production target only for that service (e.g. `git.letsredi.com` → production A/CNAME). Do not restructure DNS manually.
2. **Use** `config/powerdns/placeholder-policy.yaml` as the single classification source.
3. **Re-run** `scripts/deploy/migrate-dns-placeholder-policy.sh --dry-run` after any manual DNS edits to detect drift.
4. **Optional:** Add Traefik router for `placeholder.letsredi.com` → static “service not deployed” page (separate UI task).

---

## Artifacts

| Path | Purpose |
|------|---------|
| `config/powerdns/placeholder-policy.yaml` | Canonical placeholder classification |
| `scripts/deploy/migrate-dns-placeholder-policy.sh` | Idempotent policy migration |
| `config/powerdns/letsredi-blueprint.yaml` | Full zone blueprint (references 008C policy) |
| `/opt/redi/logs/dns-008c-migrate-final.log` | Runtime log on jkt |

---

## Decision

| Outcome | Selected |
|---------|----------|
| PASS | |
| **PASS WITH WARNINGS** | **✅** |
| BLOCKED | |
| FAIL | |

**Rationale:** All placeholders classified and migrated per policy. Production, LAB, SOA, NS, and glue preserved. Public and internal resolution validated. Minor warnings: optional Traefik placeholder UI and TTL normalization.

---

## CTO Approval

**Task 008C complete.** Pipeline stopped pending CTO review. **Do not proceed to Knowledge Platform phase** until approved.
