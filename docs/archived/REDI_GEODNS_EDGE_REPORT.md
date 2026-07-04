# REDI_GEODNS_EDGE_REPORT

| Field | Value |
|-------|-------|
| **Sprint** | 3D — GeoDNS Edge |
| **Deliverable** | GeoDNS edge routing — client dekat SBY masuk lewat edge SBY |
| **Status** | **READY TO DEPLOY** |
| **Prepared** | 2026-06-30 |
| **Depends on** | Sprint 3C (Redis HA) — PASS |

---

## Architecture

```
Internet client
      │
      ▼ DNS query (git.letsredi.com / auth / registry / proxy)
PowerDNS ns1/ns2 — LUA record evaluates ECS client IP
      │
      ├── Jawa Timur (subdivision JI) ──► 103.80.214.144  Traefik SBY ─► mjk backends
      │                                                                   (via Tailscale)
      └── All other regions            ──► 103.149.238.98  Traefik JKT ─► mjk backends
                                                                          (via Tailscale)

mjk backends (100.81.86.37):
  GitLab   :8929
  Authentik :9100
  Registry  :5000
```

Both Traefik edges proxy to the same mjk backends via Tailscale mesh. No backend is on SBY or JKT — the edge nodes are pure reverse proxies.

---

## Steps Executed

### 3D.1 — Traefik SBY (mirror config jkt, backend ke mjk)

**Files created:**

| File | Purpose |
|------|---------|
| `config/traefik/traefik.sby.yml` | Static config for SBY — ACME DNS-01 via jkt pdns (100.79.82.92:8081 over Tailscale) |
| `compose/traefik/docker-compose.sby.yml` | Compose overlay — mounts traefik.sby.yml + acme-sby.json |
| `compose/traefik/.env.redi-sby-01.example` | Env template for SBY (PDNS_API_URL=http://100.79.82.92:8081) |
| `scripts/deploy/deploy-traefik-sby.sh` | Deploy script for redi-sby-01 |

**Deploy command (on redi-sby-01):**
```bash
# 1. Copy and fill env
cp compose/traefik/.env.redi-sby-01.example compose/traefik/.env
# Edit: PDNS_API_KEY, TRAEFIK_DASHBOARD_PASSWORD_HASH

# 2. Deploy
sudo bash scripts/deploy/deploy-traefik-sby.sh
```

**Key differences from JKT Traefik:**

| | JKT | SBY |
|--|-----|-----|
| Static config | `traefik.yml` | `traefik.sby.yml` |
| ACME storage | `acme.json` | `acme-sby.json` |
| ACME PDNS API | `http://redi-pdns-auth:8081` (local) | `http://100.79.82.92:8081` (jkt via Tailscale) |
| Dashboard | `traefik-jkt.redi.lab` | `traefik-sby.redi.lab` |
| Container name | `redi-traefik` | `redi-traefik-sby` |

Dynamic config (`config/traefik/dynamic/`) is shared verbatim — backends (100.81.86.37:8929 etc.) resolve identically from both nodes via Tailscale.

---

### 3D.2 — GeoIP2 (MaxMind) + Lua records PowerDNS

**Files created:**

| File | Purpose |
|------|---------|
| `compose/powerdns/Dockerfile.geodns` | Extends pdns-auth-48 with `lua-mmdb` package |
| `compose/powerdns/docker-compose.geodns.yml` | Compose overlay — custom image + geoip volume mount |
| `scripts/deploy/setup-geoip2-pdns.sh` | Downloads GeoLite2-City.mmdb, rebuilds pdns, restarts |
| `config/powerdns/pdns.conf` | **Patched** — added `enable-lua-records=yes`, `lua-records-exec-limit=1000`, `edns-subnet-processing=yes` |

**pdns.conf additions:**
```ini
enable-lua-records=yes
lua-records-exec-limit=1000
edns-subnet-processing=yes          # enables bestwho() ECS client IP
```

**MaxMind license required (free):**
```
https://www.maxmind.com/en/geolite2/signup
```

**Setup command (on redi-jkt-01):**
```bash
GEOIP_ACCOUNT_ID=123456 GEOIP_LICENSE_KEY=xxxxx \
  sudo bash scripts/deploy/setup-geoip2-pdns.sh
```

mmdb path inside container: `/etc/powerdns/geoip/GeoLite2-City.mmdb`

---

### 3D.3 — Geo route: proxy, git, auth → JKT vs SBY by region

**Script:** `scripts/deploy/apply-geodns-lua.sh`

**Lua record logic (PowerDNS LUA type, TTL 30s):**
```lua
local ok, iso = pcall(function()
  return geoiplookup2(bestwho(), '/etc/powerdns/geoip/GeoLite2-City.mmdb',
                      'subdivisions', '0.iso_code')
end)
if ok and iso == 'JI' then
  return {'103.80.214.144'}   -- Jawa Timur → SBY
else
  return {'103.149.238.98'}   -- semua region lain → JKT
end
```

- `bestwho()` — returns ECS client IP when EDNS-subnet present, else resolver IP
- `pcall()` wrapper — graceful fallback to JKT if mmdb lookup fails
- TTL 30 — low TTL untuk geo records (fast failover capability)
- Jawa Timur ISO 3166-2 subdivision code: `JI`

**Records converted to LUA:**

| Record | Before | After | TTL |
|--------|--------|-------|-----|
| `git.letsredi.com` | A → 103.149.238.98 | LUA → JI:SBY / rest:JKT | 30 |
| `registry.letsredi.com` | A → 103.149.238.98 | LUA → JI:SBY / rest:JKT | 30 |
| `auth.letsredi.com` | A → 103.149.238.98 | LUA → JI:SBY / rest:JKT | 30 |
| `proxy.letsredi.com` | CNAME → traefik-jkt | LUA → JI:SBY / rest:JKT | 30 |

**New record added:**

| Record | Type | Value |
|--------|------|-------|
| `traefik-sby.letsredi.com` | A | 103.80.214.144 |

**Apply command (on redi-jkt-01, after setup-geoip2-pdns.sh):**
```bash
sudo bash scripts/deploy/apply-geodns-lua.sh
```

---

### 3D.4 — Validasi GeoDNS

**Script:** `scripts/deploy/validate-geodns.sh`

**Validation checks:**
1. LUA records exist for all geo-routed hosts
2. Internal records (.redi.internal, ns1/ns2 glue) NOT geo-routed
3. ECS dig simulation — JKT subnet → JKT IP, Jatim subnet → SBY IP
4. Traefik JKT HTTPS reachability (`--resolve` force to JKT IP)
5. Traefik SBY HTTPS reachability (`--resolve` force to SBY IP)
6. mjk backends reachable from SBY via Tailscale mesh

**ECS simulation:**
```bash
# Simulate Jawa Timur client → should return SBY IP
dig @103.149.238.98 +short +subnet=114.122.0.0/24 git.letsredi.com A

# Simulate JKT client → should return JKT IP
dig @103.149.238.98 +short +subnet=180.247.0.0/24 git.letsredi.com A
```

**Run validation:**
```bash
sudo bash scripts/deploy/validate-geodns.sh
```

---

### 3D.5 — Tidak geo-route postgres/redis/minio.redi.internal ke sby

**Enforced by `apply-geodns-lua.sh`:**
- Script only touches explicitly listed public records: `git`, `registry`, `auth`, `proxy`
- Guard list checked: `ns1`, `ns2`, `postgres.redi.internal`, `redis.redi.internal`, `minio.redi.internal`
- Internal records remain A records pointing to Tailscale mesh IPs only
- `validate-geodns.sh` check #2 asserts no LUA records exist for `.redi.internal`

---

## Deployment Sequence

```
redi-jkt-01
  1. GEOIP_ACCOUNT_ID=xxx GEOIP_LICENSE_KEY=xxx sudo bash scripts/deploy/setup-geoip2-pdns.sh
  2. sudo bash scripts/deploy/apply-geodns-lua.sh

redi-sby-01
  3. cp compose/traefik/.env.redi-sby-01.example compose/traefik/.env  (fill secrets)
  4. sudo bash scripts/deploy/deploy-traefik-sby.sh

redi-jkt-01 (validation)
  5. sudo bash scripts/deploy/validate-geodns.sh
```

---

## DNS Record State After Sprint 3D

| Record | Type | Result | Note |
|--------|------|--------|------|
| `git.letsredi.com` | LUA | JI→SBY / rest→JKT | geo-routed |
| `registry.letsredi.com` | LUA | JI→SBY / rest→JKT | geo-routed |
| `auth.letsredi.com` | LUA | JI→SBY / rest→JKT | geo-routed |
| `proxy.letsredi.com` | LUA | JI→SBY / rest→JKT | was CNAME |
| `gateway.letsredi.com` | CNAME | → proxy.letsredi.com | follows proxy |
| `traefik-jkt.letsredi.com` | A | 103.149.238.98 | unchanged |
| `traefik-sby.letsredi.com` | A | 103.80.214.144 | new |
| `ns1.letsredi.com` | A | 103.149.238.98 | glue — unchanged |
| `ns2.letsredi.com` | A | 103.80.214.144 | glue — unchanged |
| `postgres.redi.internal` | A | Tailscale mesh | NOT geo-routed |
| `redis.redi.internal` | A | Tailscale mesh | NOT geo-routed |
| `minio.redi.internal` | A | Tailscale mesh | NOT geo-routed |

---

## Artifacts

| File | Role |
|------|------|
| `config/traefik/traefik.sby.yml` | Traefik static config SBY |
| `compose/traefik/docker-compose.sby.yml` | Compose overlay SBY |
| `compose/traefik/.env.redi-sby-01.example` | Env template SBY |
| `compose/powerdns/Dockerfile.geodns` | pdns + lua-mmdb image |
| `compose/powerdns/docker-compose.geodns.yml` | Compose overlay geodns |
| `config/powerdns/pdns.conf` | Patched — lua-records enabled |
| `scripts/deploy/deploy-traefik-sby.sh` | 3D.1 deploy |
| `scripts/deploy/setup-geoip2-pdns.sh` | 3D.2 geoip setup |
| `scripts/deploy/apply-geodns-lua.sh` | 3D.3 apply LUA records |
| `scripts/deploy/validate-geodns.sh` | 3D.4 validation |

---

## Warnings / Constraints

| # | Warning | Mitigation |
|---|---------|-----------|
| W1 | MaxMind GeoLite2 accuracy at city/subdivision level: ~75–85% | Acceptable for lab; enterprise: buy GeoIP2-City |
| W2 | Resolvers without ECS — `bestwho()` returns resolver IP, not client IP | Most major ISPs support ECS; fallback to JKT is safe |
| W3 | TLS certs on SBY Traefik take ~60s to issue on first boot | DNS-01 propagation via jkt pdns API over Tailscale |
| W4 | `proxy.letsredi.com` changed from CNAME to LUA A — `gateway.letsredi.com` CNAME still resolves correctly | CNAME → LUA A chain is valid in PowerDNS |
| W5 | MariaDB replica on sby replicates LUA record content — sby ns2 will serve geo records too | Correct and intended |

---

## Decision

### **READY TO DEPLOY**

Sprint 3D artifacts complete. GeoDNS edge architecture is designed and deployable:

- Traefik SBY mirrors JKT config — backends are mjk via Tailscale, no changes to application layer
- PowerDNS Lua records with GeoIP2 (`geoiplookup2`) provide transparent, per-client-IP geo routing
- Internal records (postgres, redis, minio) are explicitly protected and not geo-routed
- Low-TTL (30s) on LUA records enables fast failover during incidents
- Validation script covers end-to-end path: DNS → Traefik → mjk backend

**Next Sprint: 3E — MinIO HA** (after CTO storage procurement approval)

---

*Generated by REDI Bootstrap — Sprint 3D GeoDNS Edge*
*2026-06-30*
