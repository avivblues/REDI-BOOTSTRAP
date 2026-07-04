# REDI Inventory & Secret Management Specification

**Version:** 1.1  
**Governance:** RAS v1.0  
**Status:** Structure definition — no deployment  

---

## 1. Purpose

This document defines how REDI LAB separates **inventory** (non-sensitive, committable operational metadata) from **secrets** (sensitive operational data, never committed when populated).

Agents and operators load both layers before execution. Inventory drives topology; secrets drive authentication and credential injection.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     REDI LAB Repository                      │
├──────────────────────────┬──────────────────────────────────┤
│   inventory/  (GIT ✓)    │   secrets/  (GIT ✗ when filled)  │
│   Non-sensitive metadata │   Sensitive operational data       │
│   Dummy examples only  │   Schema stubs only in repo        │
└──────────────────────────┴──────────────────────────────────┘
              │                              │
              └──────────┬───────────────────┘
                         ▼
              Deployment / Validation Agent
              (loads both; never embeds secrets in prompts)
```

---

## 3. Directory Structure

```
inventory/
├── servers.example.yaml      # Node identity, roles, OS requirements
├── roles.example.yaml        # Service roles and deployment phases
├── domains.example.yaml      # DNS zones and records (dummy targets)
├── network.example.yaml      # Mesh, Docker networks, connectivity
├── storage.example.yaml      # Volumes, backup policy
└── environment.example.yaml  # Project metadata and file registry

secrets/
├── .gitignore                # Local secret file protection rules
├── servers.yaml              # Public IP, SSH port, username (schema stub)
├── ssh.yaml                  # SSH key paths, backup targets (schema stub)
├── api-keys.yaml             # API keys and tokens (schema stub)
└── certificates.yaml         # TLS cert/key paths (schema stub)
```

---

## 4. Inventory Files

Inventory files **may be committed to Git**. They contain schema, inline documentation, and dummy examples using RFC 5737 (`203.0.113.x`) and RFC 2606 (`example.invalid`) addresses only.

### 4.1 `inventory/servers.example.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Declares node identity, role assignment, OS requirements |
| **Owner** | Platform team |
| **Contains** | `id`, `hostname`, `role_ref`, `site`, `secrets_ref`, `os` |
| **Must NOT contain** | IP addresses, SSH ports, usernames, passwords, keys |

**Cross-references:** `role_ref` → `roles.example.yaml`; `secrets_ref` → `secrets/servers.yaml`

---

### 4.2 `inventory/roles.example.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Logical roles, service placement, deployment phases |
| **Owner** | Platform / architecture team |
| **Contains** | `id`, `tier`, `phase`, `services`, `constraints`, `depends_on` |
| **Must NOT contain** | Credentials, endpoints, tokens |

**Cross-references:** Referenced by `servers.example.yaml`; `services` → `compose/` stacks

---

### 4.3 `inventory/domains.example.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | DNS zones, records, ACME configuration |
| **Owner** | Platform / DNS administrator |
| **Contains** | `base_domain`, `name_servers`, `records`, `acme` |
| **Must NOT contain** | API keys, real production domains in committed examples |

**Cross-references:** `server_ref` → `servers.example.yaml`; real IPs resolved via `secrets/servers.yaml`

---

### 4.4 `inventory/network.example.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Tailscale mesh, Docker networks, connectivity matrix |
| **Owner** | Network / platform team |
| **Contains** | `mesh`, `docker_networks`, `connectivity`, `colocation_policy` |
| **Must NOT contain** | Auth keys, mesh pre-auth keys |

---

### 4.5 `inventory/storage.example.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Volume paths, capacity requirements, backup schedule |
| **Owner** | Platform / operations team |
| **Contains** | `base_path`, `volumes`, `backup`, `disk_thresholds` |
| **Must NOT contain** | Backup credentials (→ `secrets/ssh.yaml`) |

---

### 4.6 `inventory/environment.example.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Project identity, deployment phase, locale, file registry |
| **Owner** | CTO / platform lead |
| **Contains** | `project`, `deployment`, `locale`, `inventory`, `secrets`, `reporting` |
| **Must NOT contain** | Any secret values |

---

## 5. Secrets Files

Secrets files hold sensitive operational data. **Schema stubs** ship in the repository (empty structures). **Populated files must never be committed.**

### 5.1 `secrets/servers.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Per-node connection metadata |
| **Owner** | Operations lead (operator-local) |
| **May contain** | `public_ip`, `ssh_port`, `username`, `auth_method`, `tailscale_ip` |
| **Must NOT contain** | Passwords, private keys |

**Required fields per entry:** `id`, `public_ip`, `ssh_port`, `username`, `auth_method`  
**Validation:** `id` must match `inventory` → `servers[].secrets_ref`

---

### 5.2 `secrets/ssh.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | SSH private key file paths and backup SSH targets |
| **Owner** | Operations lead (operator-local) |
| **May contain** | Key `path` on operator workstation, `authorized_on` server ids |
| **Must NOT contain** | Private key PEM content, passphrases inline |

**Required fields per key:** `id`, `path`, `type`, `authorized_on`

---

### 5.3 `secrets/api-keys.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Service API keys, tokens, application passwords |
| **Owner** | Security / operations lead (operator-local) |
| **May contain** | `value` for each named secret, `inject_as` env var name |
| **Must NOT contain** | Committed production values |

**Required fields per secret:** `id`, `service`, `inject_as`, `value`  
**Validation:** Passwords ≥ 16 chars; API keys ≥ 32 chars

---

### 5.4 `secrets/certificates.yaml`

| Attribute | Value |
|-----------|-------|
| **Purpose** | TLS certificate and key file paths on target servers |
| **Owner** | Security / operations lead (operator-local) |
| **May contain** | `cert_path`, `key_path`, `domain`, `auto_renew` |
| **Must NOT contain** | PEM/DER certificate or key content |

**Required fields per entry:** `id`, `type`, `service`, `cert_path`, `key_path`

---

## 6. Ownership

| Layer | Owner | Review cadence |
|-------|-------|----------------|
| `inventory/*.example.yaml` | Platform team | Per release / architecture change |
| `secrets/servers.yaml` | Operations lead | Per node change |
| `secrets/ssh.yaml` | Security officer | Per key rotation (90 days) |
| `secrets/api-keys.yaml` | Security officer | Per rotation policy |
| `secrets/certificates.yaml` | Security officer | Per cert expiry |
| This specification | CTO / platform architect | Per RAS version change |

---

## 7. Update Procedure

### 7.1 Inventory changes (committable)

1. Propose change via pull request  
2. Platform team reviews referential integrity  
3. Update `*.example.yaml` with dummy values only  
4. Update `INVENTORY_SPECIFICATION.md` if schema changes  
5. CTO approval for topology changes  
6. Merge to main  

### 7.2 Secrets changes (operator-local)

1. Never commit populated `secrets/*.yaml`  
2. Edit files locally: `chmod 600 secrets/*.yaml`  
3. Validate cross-references against inventory `id` fields  
4. Store backup in approved secret manager (out of band)  
5. Document rotation in operations log (not in git)  
6. Re-run Stage 0 validation after secret updates  

### 7.3 New node onboarding

```
1. Add entry to inventory/servers.example.yaml     (metadata)
2. Add role assignment in inventory/roles.example.yaml (if new role)
3. Add DNS records in inventory/domains.example.yaml
4. Populate secrets/servers.yaml                     (connection data)
5. Add SSH key ref in secrets/ssh.yaml
6. Add service secrets in secrets/api-keys.yaml
7. Validate → Stage 0
```

---

## 8. Validation Rules

### 8.1 Global

| ID | Rule |
|----|------|
| G-01 | `schema_version: "1.0"` required in every file |
| G-02 | All `id` fields unique within their file |
| G-03 | Cross-references must resolve across inventory ↔ secrets |
| G-04 | No passwords, keys, or tokens in `inventory/` |
| G-05 | No PEM content in any `secrets/` file |
| G-06 | Populated `secrets/` files must not appear in `git status` |

### 8.2 Inventory

| ID | Rule |
|----|------|
| I-01 | `servers[].secrets_ref` must exist in `secrets/servers.yaml` when populated |
| I-02 | `servers[].role_ref` must exist in `roles.example.yaml` |
| I-03 | Docker subnets in `network.example.yaml` must not overlap |
| I-04 | Dummy IPs must use RFC 5737 ranges only |
| I-05 | Dummy domains must use RFC 2606 (`example.invalid`) only |

### 8.3 Secrets

| ID | Rule |
|----|------|
| S-01 | `secrets/servers.yaml` ids match inventory `secrets_ref` |
| S-02 | SSH `keys[].path` must be operator-local, outside repository |
| S-03 | `api-keys.yaml` values must meet `min_length` when set |
| S-04 | `certificates.yaml` paths must reference target server filesystem |
| S-05 | File permissions `600` on all populated secrets files |

---

## 9. Security Rules

| Rule | Enforcement |
|------|-------------|
| Inventory never contains secrets | Code review + agent validation |
| Secrets never committed when populated | `.gitignore` + pre-commit hook (recommended) |
| No passwords in inventory SSH blocks | Schema separation |
| SSH private keys stored outside repo | `secrets/ssh.yaml` path only |
| API keys injected at deploy time | `secrets/api-keys.yaml` → compose `.env` |
| TLS material on disk only | `secrets/certificates.yaml` paths only |
| Agents never read prompts for credentials | RAS execution policy |
| Stage 0 is read-only | RAS Level 0 permission |
| Rotation documented out of band | Operations runbook |

### Recommended pre-commit hook

```bash
# Reject staged secrets with populated values
if git diff --cached --name-only | grep -q '^secrets/'; then
  for f in secrets/*.yaml; do
    if grep -qE 'public_ip:\s+[0-9]' "$f" 2>/dev/null; then
      echo "ERROR: Populated secrets must not be committed: $f"
      exit 1
    fi
  done
fi
```

---

## 10. Agent Usage (RAS v1.0)

| Stage | Inventory required | Secrets required |
|-------|-------------------|------------------|
| Stage 0 — Precheck | All `inventory/*.example.yaml` | `servers.yaml` (connection test) |
| Stage 1 — Bootstrap | `servers`, `environment`, `network`, `storage` | `servers`, `ssh` |
| Stage 2 — Tailscale | `network` | `api-keys` (`tailscale-auth-key`) |
| Stage 3 — PowerDNS | `roles`, `domains` | `api-keys` (MariaDB, PDNS) |
| Stage 4 — Traefik | `domains`, `network` | `api-keys`, `certificates` |
| Stage 5 — Portainer | `roles` | `api-keys` |
| Stage 6 — GitLab | `roles`, `storage` | `api-keys` |

Agents **must fail** if required files are missing or cross-references are unresolved.

---

## 11. Cross-Reference Map

```
inventory/servers.example.yaml
    ├── role_ref      →  inventory/roles.example.yaml
    └── secrets_ref   →  secrets/servers.yaml

inventory/domains.example.yaml
    └── server_ref    →  inventory/servers.example.yaml

inventory/storage.example.yaml
    └── backup.destination_ref  →  secrets/ssh.yaml

secrets/servers.yaml
    └── id            →  inventory servers[].secrets_ref

secrets/ssh.yaml
    └── keys[].authorized_on  →  inventory servers[].id

secrets/api-keys.yaml
    └── service       →  compose/{service}/

secrets/certificates.yaml
    └── domain        →  inventory/domains.example.yaml
```

---

## 12. Revision History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-06-29 | Initial inventory templates |
| 1.1 | 2026-06-29 | Separated secrets layer; removed credentials from inventory |

---

*End of specification. No deployment performed. No infrastructure accessed.*
