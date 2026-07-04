# REDI LAB — PowerDNS Platform Report

**Task:** REDI Agent Task 006  
**RAS Version:** 1.0  
**Stage:** 2 — PowerDNS Platform  
**Permission:** LEVEL 2  
**Date:** 2026-06-29  

---

## Executive Summary

PowerDNS authoritative platform deployed on **redi-jkt-01 (primary)**. MariaDB backend, PowerDNS API, and public DNS (port 53) are operational. **redi-sby-01 (replica) deployment is blocked** — Proxmox LXC cannot run Docker containers (sysctl restriction).

| Node | Role | MariaDB | PowerDNS | Status |
|------|------|:-------:|:--------:|--------|
| `redi-jkt-01` | Primary | ✅ healthy | ✅ healthy | **Deployed** |
| `redi-sby-01` | Replica | ❌ blocked | ❌ blocked | **Not deployed** |
| `redi-mjk-01` | Management | N/A | N/A | Out of scope |

**Decision: PASS WITH WARNINGS**

---

## Container Status

### `redi-jkt-01` (Primary)

| Container | Image | Status | Restart Policy | Ports |
|-----------|-------|--------|----------------|-------|
| `redi-mariadb` | `mariadb:10.11` | ✅ healthy | `unless-stopped` | `100.79.82.92:3306` |
| `redi-pdns-auth` | `powerdns/pdns-auth-48:4.8.4` | ✅ healthy | `unless-stopped` | `53/tcp+udp`, `100.79.82.92:8081` |

### `redi-sby-01` (Replica)

| Container | Status | Reason |
|-----------|--------|--------|
| All | ❌ Not running | LXC: `ip_unprivileged_port_start` sysctl denied — Docker cannot start any container |

---

## Database Status

### Primary (`redi-jkt-01`)

| Check | Result |
|-------|--------|
| MariaDB healthcheck | ✅ Pass |
| Database `powerdns` | ✅ Present |
| Schema tables | ✅ 7 tables (domains, records, …) |
| Binlog (master) | ✅ `mysql-bin.000002` active |
| Persistent volume | ✅ `/opt/redi/data/powerdns/mariadb` |
| Tailscale exposure | `100.79.82.92:3306` |

### Replica (`redi-sby-01`)

| Check | Result |
|-------|--------|
| MariaDB container | ❌ Not deployed (LXC blocker) |
| MariaDB replication | ❌ Not configured |

---

## Replication Status

| Metric | Primary | Replica |
|--------|---------|---------|
| `server-id` | 1 | — |
| Binlog | ✅ Active | — |
| `SHOW SLAVE STATUS` | N/A (master) | ❌ No replica instance |
| GTID | Configured | — |

**Architecture note:** Full MariaDB replica on `redi-sby-01` requires Proxmox LXC host change (`features: nesting=1` or sysctl allowance). Planned replica compose prepared (`docker-compose.replica.yml`) for when LXC is upgraded.

---

## API Status

| Check | Result |
|-------|--------|
| API enabled | ✅ `api=yes` |
| Endpoint | `http://100.79.82.92:8081/api/v1` |
| Auth | ✅ `X-API-Key` header |
| Statistics endpoint | ✅ JSON response verified |
| ACL | `100.64.0.0/10`, `127.0.0.1`, `172.28.0.0/24` |
| Mesh API access (sby→jkt:8081) | ⚠️ Timeout — UFW/Tailscale routing (DNS via public IP works) |

```bash
# Verified via Docker network on primary:
curl -H "X-API-Key: …" http://100.79.82.92:8081/api/v1/servers/localhost/statistics
```

---

## DNS Query Results

### Zone: `redi.lab` (seeded + validated)

| Query | Server | Result |
|-------|--------|--------|
| `redi.lab SOA` | `127.0.0.1` (jkt) | ✅ `ns1.redi.lab. hostmaster.redi.lab. 2026010101 …` |
| `redi.lab NS` | `127.0.0.1` (jkt) | ✅ `ns1.redi.lab.`, `ns2.redi.lab.` |
| `ns1.redi.lab A` | `127.0.0.1` (jkt) | ✅ `103.149.238.98` |
| `redi.lab SOA` | `@103.149.238.98` (sby) | ✅ Resolves |
| `redi.lab NS` | `@103.149.238.98` (mjk) | ✅ Resolves |

### Test zone: `probe.redi.lab`

| Query | Result | Note |
|-------|--------|------|
| `probe.redi.lab A` | `100.64.0.1` | ⚠️ Wildcard `*.redi.lab` in seed data takes precedence |

Test A record inserted in MariaDB; wildcard override documented as warning.

---

## Inter-node DNS Queries

| From | Query | Target | Result |
|------|-------|--------|--------|
| `redi-sby-01` | `redi.lab SOA` | `103.149.238.98:53` | ✅ |
| `redi-mjk-01` | `redi.lab NS` | `103.149.238.98:53` | ✅ |
| `redi-sby-01` | `probe.redi.lab A` | `103.149.238.98:53` | ✅ (wildcard) |

---

## Health Status

| Component | jkt | sby |
|-----------|:---:|:---:|
| MariaDB healthcheck | ✅ | — |
| PowerDNS `pdns_control rping` | ✅ | — |
| Container restart policy | ✅ `unless-stopped` | — |
| Structured logging (`json-file`, 50m×5) | ✅ | — |
| Persistent data survives restart | ✅ | — |
| `systemd-resolved` stub disabled (port 53) | ✅ | ✅ (prepared) |

---

## Deployment Artifacts

| Path | Purpose |
|------|---------|
| `/opt/redi/compose/powerdns/.env` | Node credentials (chmod 600) |
| `/opt/redi/config/powerdns/pdns.conf` | Rendered PowerDNS config |
| `/opt/redi/data/powerdns/mariadb/` | MariaDB persistent data |
| `/opt/redi/logs/powerdns/` | Service logs |
| `scripts/deploy/deploy-powerdns.sh` | Deploy automation |
| `scripts/deploy/create-test-zone.sh` | API zone helper |

### Secrets provisioned (local `secrets/api-keys.yaml`)

- `mariadb-root-password`
- `mariadb-replication-password`
- `mariadb-pdns-password`
- `pdns-api-key`

---

## Risks

| ID | Risk | Severity |
|----|------|----------|
| R1 | **Replica not deployed** — single DNS/MariaDB point of failure | High |
| R2 | Proxmox LXC on sby/mjk cannot run Docker workloads | High |
| R3 | MariaDB replication not active | Medium |
| R4 | API/mesh port 8081 not reachable cross-node via Tailscale IP | Medium |
| R5 | Wildcard `*.redi.lab` complicates per-record testing | Low |
| R6 | PowerDNS 4.8.4 EOL security notice in logs | Medium |
| R7 | Operator IP intermittently blocked by Fail2Ban on jkt | Low |

---

## Remediation Required (Replica)

On Proxmox host for `redi-sby-01` LXC:

```
# /etc/pve/lxc/<id>.conf
features: nesting=1
```

Then re-run:

```bash
sudo /opt/redi/scripts/deploy/deploy-powerdns.sh --role replica
```

---

## Decision

```
┌──────────────────────────────────────────────────────────────────┐
│  POWERDNS PLATFORM:  PASS WITH WARNINGS                            │
│                                                                   │
│  Primary (redi-jkt-01):   MariaDB ✅  PowerDNS ✅  API ✅  DNS ✅   │
│  Replica (redi-sby-01):   BLOCKED (LXC Docker)                    │
│  Replication:             NOT ACTIVE                               │
│  Inter-node DNS queries:  ✅ via public primary IP                 │
│                                                                   │
│  Status: STOPPED — Awaiting CTO approval for Stage 3+              │
└──────────────────────────────────────────────────────────────────┘
```

| Outcome | Selected |
|---------|----------|
| PASS | |
| **PASS WITH WARNINGS** | **✓** |
| BLOCKED | (replica only) |
| FAIL | |

---

## Agent Compliance

- ✅ Docker Compose used on primary
- ✅ Persistent volumes configured
- ✅ `redi-dns` network used
- ✅ Configuration under `/opt/redi`
- ✅ API, healthcheck, restart, logging enabled
- ❌ Full replica + replication (infrastructure blocker)
- ✅ No Traefik / Portainer / GitLab / PowerDNS Admin deployed
- ✅ Existing workloads on jkt unaffected (0 pre-existing containers)

---

*Report generated: 2026-06-29 — RAS v1.0 Stage 2*
