# STAGE 02 — REDI DNS High Availability

| Field | Value |
|-------|-------|
| **RAS Version** | 1.0 |
| **Sprint** | Sprint 2 — REDI Platform Foundation |
| **Stage** | 2 — REDI DNS High Availability |
| **Primary** | `redi-jkt-01` (`ns1.letsredi.com` / `103.149.238.98`) |
| **Replica** | `redi-sby-01` (`ns2.letsredi.com` / `103.80.214.144`) |
| **Executed** | 2026-06-29 |
| **Decision** | **PASS** |

---

## Executive Summary

PowerDNS authoritative DNS is now deployed on **redi-sby-01** as the secondary nameserver. MariaDB async replication from the Jakarta primary is active with zero lag. Both `ns1` and `ns2` answer authoritatively for `letsredi.com`, with identical zone content (87 records each).

---

## Deployment

| Component | Node | Status |
|-----------|------|--------|
| PowerDNS Authoritative 4.8.4 | `redi-sby-01` | ✅ Healthy |
| MariaDB 10.11 (slave) | `redi-sby-01` | ✅ Healthy |
| MariaDB 10.11 (master) | `redi-jkt-01` | ✅ Healthy (existing) |
| PowerDNS Authoritative | `redi-jkt-01` | ✅ Healthy (existing) |

### Compose

- Replica stack: `compose/powerdns/docker-compose.replica-stack.yml`
- Deploy: `scripts/deploy/deploy-powerdns.sh --role replica`
- Replication seed: `scripts/deploy/setup-mariadb-replication.sh`

### Networking

| Port | Exposure (sby) | Purpose |
|------|----------------|---------|
| 53/tcp+udp | Public `0.0.0.0` | Authoritative DNS |
| 8081/tcp | Mesh `100.67.138.25` | PowerDNS API |
| 3306/tcp | Mesh `100.67.138.25` | MariaDB (replica) |

---

## MariaDB Replication

| Check | Result |
|-------|--------|
| Primary host | `100.79.82.92` (jkt Tailscale) |
| Replication user | `repl_user` |
| `Slave_IO_Running` | **Yes** |
| `Slave_SQL_Running` | **Yes** |
| `Seconds_Behind_Master` | **0** |

**Method:** `mysqldump --master-data=2` from primary → restore on replica → `CHANGE MASTER TO` with binlog coordinates → `START SLAVE`.

---

## Zone Replication

| Check | ns1 (jkt) | ns2 (sby) | Match |
|-------|-----------|-----------|-------|
| `records` table count | 87 | 87 | ✅ |
| `letsredi.com` SOA | `ns1… hostmaster… 2026062904` | Same | ✅ |
| `letsredi.com` NS | `ns1`, `ns2` | Same | ✅ |
| `git.letsredi.com` A | `103.149.238.98` | `103.149.238.98` | ✅ |

---

## Authoritative DNS — ns2.letsredi.com

| Record | Value |
|--------|-------|
| Glue A | `103.80.214.144` |
| Public resolver | `dig @8.8.8.8 ns2.letsredi.com` → `103.80.214.144` |

---

## Validation Results

| Check | Command / Target | Result |
|-------|------------------|--------|
| SOA via ns1 | `dig @103.149.238.98 letsredi.com SOA` | ✅ |
| SOA via ns2 | `dig @103.80.214.144 letsredi.com SOA` | ✅ |
| SOA via ns2 hostname | `dig @ns2.letsredi.com letsredi.com SOA` | ✅ |
| NS via ns1 | `dig @103.149.238.98 letsredi.com NS` | ✅ `ns1`, `ns2` |
| NS via ns2 | `dig @103.80.214.144 letsredi.com NS` | ✅ `ns1`, `ns2` |
| Public NS delegation | `dig @8.8.8.8 letsredi.com NS` | ✅ `ns1`, `ns2` |
| Public query | `dig @8.8.8.8 git.letsredi.com A` | ✅ `103.149.238.98` |
| Zone sync | Record count primary vs replica | ✅ 87 = 87 |
| Replication | `SHOW SLAVE STATUS` on sby | ✅ IO/SQL running, lag 0 |

---

## Configuration Changes (repo)

| File | Change |
|------|--------|
| `compose/powerdns/docker-compose.replica-stack.yml` | New — full MariaDB slave + PowerDNS on sby |
| `scripts/deploy/setup-mariadb-replication.sh` | New — dump/restore/replicate workflow |
| `scripts/deploy/deploy-powerdns.sh` | Replica uses replica-stack + replication setup |
| `config/powerdns/mariadb-replica.cnf` | Removed unsupported `super_read_only` for MariaDB 10.11 in LXC |

---

## Warnings

1. **MariaDB `super_read_only`** — Not supported in the sby MariaDB build; replica uses `read_only=1` only.
2. **PowerDNS 4.8.4 EOL notice** — Logged at startup; plan upgrade in a future maintenance window.
3. **Replication bootstrap** — Initial `setup-mariadb-replication.sh` heredoc failed silently; fixed to use discrete `docker exec mysql -e` commands (script updated in repo).

---

## Decision

### **PASS**

All Stage 2 requirements are met: PowerDNS replica deployed on `redi-sby-01`, MariaDB replication active, zone content synchronized, `ns2.letsredi.com` authoritative on the public Internet, and public DNS queries succeed.

**Ready for Stage 3 (Authentik) upon CTO approval.**
