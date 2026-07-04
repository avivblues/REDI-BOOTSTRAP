# REDI LAB — DNS Production Go-Live Report

**Task:** REDI Agent Task 008 — Part A  
**RAS Version:** 1.0  
**Stage:** 4 — DNS Production Go-Live  
**Permission:** LEVEL 2  
**Date:** 2026-06-29  

---

## Executive Summary

Production zone **`letsredi.com`** is live on **redi-jkt-01** (PowerDNS primary). All required record types validate from localhost and peer nodes. **ns1.letsredi.com** answers authoritatively. **ns2.letsredi.com** glue is published but Surabaya does not yet run DNS (replica blocked). PowerDNS API remains mesh-only.

**Decision: PASS WITH WARNINGS**

---

## Zone Status

| Zone | Type | Serial | SOA TTL | Status |
|------|------|--------|---------|--------|
| `letsredi.com` | Native | `2026062901` | 3600 | ✅ Active |
| `redi.lab` | Native | `2026010101` | 3600 | ✅ Active (lab) |

---

## Record Verification

| Record | Type | Value | TTL | Status |
|--------|------|-------|-----|--------|
| `letsredi.com` | SOA | `ns1.letsredi.com. hostmaster.letsredi.com. 2026062901 3600 600 604800 3600` | 3600 | ✅ |
| `letsredi.com` | NS | `ns1.letsredi.com.` | 3600 | ✅ |
| `letsredi.com` | NS | `ns2.letsredi.com.` | 3600 | ✅ |
| `ns1.letsredi.com` | A (glue) | `103.149.238.98` | 300 | ✅ |
| `ns2.letsredi.com` | A (glue) | `103.80.214.144` | 300 | ✅ |
| `letsredi.com` | A | `103.149.238.98` | 300 | ✅ |
| `www.letsredi.com` | CNAME | `letsredi.com.` | 300 | ✅ |
| `api.letsredi.com` | CNAME | `traefik-jkt.letsredi.com.` | 300 | ✅ |
| `portainer.letsredi.com` | A | `100.116.166.60` | 300 | ✅ |
| `traefik-jkt.letsredi.com` | A | `100.79.82.92` | 300 | ✅ |
| `traefik-sby.letsredi.com` | A | `100.79.40.61` | 300 | ✅ |

**SOA timers:** refresh `3600`, retry `600`, expire `604800`, minimum `3600`.

---

## Name Server Authority

| Nameserver | Glue IP | Authoritative response | Status |
|------------|---------|------------------------|--------|
| `ns1.letsredi.com` | `103.149.238.98` | ✅ SOA `aa` flag, serial `2026062901` | **PASS** |
| `ns2.letsredi.com` | `103.80.214.144` | ❌ Connection refused (no DNS on sby) | **WARNING** |

---

## Validation Matrix

| Source | Method | Result |
|--------|--------|--------|
| **localhost** (jkt) | `dig @127.0.0.1 letsredi.com SOA/NS` | ✅ PASS |
| **Peer** (sby → jkt `:53`) | All record types | ✅ PASS |
| **Peer** (mjk → jkt `:53`) | SOA, glue, CNAME | ✅ PASS |
| **Public resolver** (8.8.8.8) | `letsredi.com NS` | ✅ `ns1` / `ns2` returned |
| **Public resolver** (1.1.1.1) | `letsredi.com SOA` | ✅ Serial `2026062901` |
| **ns1 direct** | `dig @ns1.letsredi.com` | ✅ PASS |
| **ns2 direct** | `dig @ns2.letsredi.com` | ❌ FAIL (sby DNS not deployed) |

---

## API & Security

| Check | Result |
|-------|--------|
| PowerDNS API on public IP `:8081` | ✅ **Not exposed** (connection refused / timeout) |
| API on mesh `100.79.82.92:8081` | ✅ Reachable (Tailscale / Docker network) |
| Public DNS `:53` on jkt | ✅ Authoritative only (no recursion) |

---

## Zone Export & Backup

| Artifact | Path | Status |
|----------|------|--------|
| Zone export (JSON) | `/opt/redi/backup/zones/letsredi.com-20260629-104341.json` | ✅ |
| MariaDB dump | `/opt/redi/backup/20260629-104341/powerdns-mariadb.sql.gz` | ✅ |
| Traefik ACME backup | `/opt/redi/backup/20260629-104341/traefik-acme.json` | ✅ |
| Manifest | `/opt/redi/backup/20260629-104341/manifest.json` | ✅ |

---

## Issues Resolved During Go-Live

| Issue | Resolution |
|-------|------------|
| MariaDB schema missing `options` / `catalog` columns | Applied `03-schema-4.7-migration.sql` (PowerDNS 4.7+ API compatibility) |
| PowerDNS API zone POST returned HTTP 500 | Zone created via MariaDB SQL + `pdns_control reload` |
| Zone queries REFUSED until restart | `docker restart redi-pdns-auth` after SQL insert |

---

## Warnings

| ID | Warning | Impact |
|----|---------|--------|
| W1 | **ns2.letsredi.com** does not answer — PowerDNS replica not on sby | Secondary NS unreachable; single DNS authority |
| W2 | Zone provisioned via **SQL fallback** (API POST broken on hostname SOA) | Documented; script updated with fallback |
| W3 | **Schema migration** required on existing MariaDB | New deploys include updated `01-schema.sql` |
| W4 | Registrar delegation assumed active (public resolvers return NS/SOA) | Confirm glue at registrar matches published A records |

---

## Deployment Artifacts

| Path | Purpose |
|------|---------|
| `scripts/deploy/create-production-zone.sh` | Production zone creation (API + SQL fallback) |
| `scripts/deploy/export-zone.sh` | Zone export via PowerDNS API |
| `config/powerdns/03-schema-4.7-migration.sql` | Schema migration for API compatibility |
| `config/powerdns/01-schema.sql` | Updated domains table (4.7+ columns) |

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  DNS PRODUCTION GO-LIVE:  PASS WITH WARNINGS                      │
│                                                                   │
│  Zone letsredi.com:     ✅ LIVE on redi-jkt-01                    │
│  ns1.letsredi.com:      ✅ Authoritative                          │
│  ns2.letsredi.com:      ⚠️  Glue only (no DNS service on sby)     │
│  API public exposure:   ✅ NOT EXPOSED                            │
│  Export & backup:       ✅ VERIFIED                               │
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

*Report generated: 2026-06-29 — RAS v1.0 Stage 4 Part A*
