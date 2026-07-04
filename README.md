# REDI Cloud Platform
> Enterprise Cloud Platform for Building, Operating, and Scaling REDI Digital Products

| Metadata | Value |
|---|---|
| Product | REDI Cloud Platform |
| Repository | `avivblues/REDI-BOOTSTRAP` |
| Version | `1.0` |
| Status | Active Development |
| Architecture | CTO Freeze v1.0 |
| Primary Documentation | `README.md` |
| Current Scope | Infrastructure through Monitoring Platform |

---
## Overview

| Server | Hostname | Role | Services |
|--------|----------|------|----------|
| Edge 1 | `redi-jkt-01` | Jakarta | PowerDNS (Primary), Traefik |
| Edge 2 | `redi-sby-01` | Surabaya | PowerDNS (Replica), Traefik |
| Management | `redi-mgmt-01` | Control Plane | GitLab CE, Portainer |

All inter-service communication uses **Tailscale** private networking. Only **Traefik** exposes HTTP/HTTPS to the public internet.

# 1. Executive Summary

REDI Cloud Platform is the infrastructure and shared platform foundation for the REDI ecosystem.

The platform provides reusable infrastructure, data services, networking, security, identity, source control, container management, backup, disaster recovery, and observability capabilities required by REDI products.

REDI Cloud Platform is deployed across three independent VPS nodes:

- Jakarta
- Mojokerto
- Surabaya

The nodes are connected through a secure NetBird/WireGuard Private Mesh Network.

The platform follows a Shared Platform architecture.

Applications MUST consume shared infrastructure services and MUST NOT deploy duplicate infrastructure services when shared services are available.

The primary platform priorities are:

1. Data Integrity
2. High Availability
3. Disaster Recovery
4. Operational Simplicity
5. Scalability

The primary infrastructure objective is:

> NO TRANSACTION LOSS

High Availability MUST NOT sacrifice data integrity.

---

# 2. Vision

Build a secure, highly available, reusable, scalable, and operationally manageable Enterprise Cloud Platform for the entire REDI ecosystem.

---

# 3. Mission

Provide a standardized cloud foundation consisting of:

- Infrastructure
- Private Networking
- Security
- Shared Data Platform
- DNS Platform
- Reverse Proxy and Load Balancing
- Container Management
- Git Platform
- Identity Platform
- Backup Platform
- Disaster Recovery
- Monitoring Platform

---

# 4. Product Philosophy

REDI Cloud Platform follows these principles:

- Shared Platform First
- Data Integrity First
- High Availability
- Disaster Recovery
- Operational Simplicity
- Infrastructure as Code
- Automation First
- Security by Design
- Private by Default
- Public by Exception
- API First
- Cloud Native
- Reusable Infrastructure
- Observable Platform
- AI Ready

---

# 5. Product Goals

## 5.1 Business Goals

- Standardize REDI infrastructure.
- Eliminate duplicated infrastructure services.
- Accelerate application deployment.
- Reduce infrastructure operational cost.
- Simplify platform maintenance.
- Build reusable enterprise infrastructure.
- Provide a common platform for future REDI products.
- Reduce application dependency on individual infrastructure stacks.

---

## 5.2 Technical Goals

- Operate three interconnected infrastructure nodes.
- Provide secure Private Mesh Network connectivity.
- Provide centralized reverse proxy and load balancing.
- Provide High Availability authoritative DNS.
- Provide Shared PostgreSQL.
- Provide Shared Redis.
- Provide Shared MinIO.
- Provide centralized container management.
- Provide GitLab EE with High Availability architecture.
- Provide Container Registry.
- Provide centralized identity through Authentik.
- Provide backup and disaster recovery.
- Provide centralized metrics, logs, alerts, and uptime monitoring.
- Prevent direct public exposure of internal platform services.
- Protect transactional data from infrastructure failure.

---

## 5.3 Availability Goals

- Minimize single points of failure.
- Support application failover.
- Support database failover.
- Support Redis failover.
- Support DNS failover.
- Support Git Platform failover.
- Support Identity Platform failover.
- Maintain service availability during single-node failure where architecture supports it.

---

## 5.4 Data Integrity Goals

- Prevent transaction loss.
- Maintain PostgreSQL replication integrity.
- Maintain Redis persistence.
- Maintain object storage durability.
- Provide PostgreSQL WAL archival.
- Provide Point-in-Time Recovery.
- Validate backup restoration.
- Validate failover data integrity.

---

## 5.5 Security Goals

- Implement Zero Trust principles.
- Implement Least Privilege.
- Encrypt node-to-node communication.
- Isolate internal services.
- Enforce HTTPS for public applications.
- Implement centralized identity.
- Support RBAC.
- Support MFA.
- Maintain audit logging.
- Protect backup data.

---

# 6. Product Scope

## 6.1 Infrastructure Platform

- Three VPS Nodes
- Linux Operating System
- Docker Engine
- Docker Compose
- Private Mesh Network
- Firewall
- Host Security

---

## 6.2 Network Platform

- NetBird
- WireGuard
- Private Mesh Network
- Public Network
- Docker Internal Network
- Service Communication
- Replication Network

---

## 6.3 Shared Platform

- PostgreSQL 16
- Redis
- Redis Sentinel
- MinIO

---

## 6.4 Infrastructure Services

- PowerDNS
- Traefik
- Portainer

---

## 6.5 Platform Services

- GitLab EE
- GitLab Container Registry
- Authentik
- Backup Platform
- Disaster Recovery
- Monitoring Platform

---

## 6.6 Monitoring Scope

- Prometheus
- Grafana
- Loki
- Alertmanager
- Uptime Kuma

---

## 6.7 Out of Current Scope

The following platforms are NOT part of the current implementation scope:

- Workflow Platform
- Knowledge Platform
- AI Platform
- ERP Applications
- REDI OS Applications
- Kubernetes

Implementation of these platforms requires completion and validation of the REDI Cloud Platform foundation.

---

# 7. Platform Architecture

```text
                             Internet
                                │
                                ▼
                     Public Domains (HTTPS)
                                │
                                ▼
               Traefik Reverse Proxy & Load Balancer
                                │
               ┌────────────────┼────────────────┐
               │                │                │
               ▼                ▼                ▼
         redi-jkt-01      redi-mjk-01      redi-sby-01
           Jakarta          Mojokerto         Surabaya
               │                │                │
               └────────────────┼────────────────┘
                                │
                                ▼
                   NetBird / WireGuard Mesh
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
     Shared Data          Platform Services      Operations
       Platform                                    Platform
          │                     │                     │
    ┌─────┼─────┐        ┌──────┼──────┐       ┌──────┼──────┐
    │     │     │        │      │      │       │      │      │
    ▼     ▼     ▼        ▼      ▼      ▼       ▼      ▼      ▼
 PostgreSQL Redis MinIO GitLab Authentik Registry Backup Monitoring DR
 # 8. Infrastructure Topology

## 8.1 Purpose

Provide the physical and logical infrastructure foundation for REDI Cloud Platform across three independent locations.

---

## 8.2 Infrastructure Nodes

| Node | Location | Primary Role | Status |
|---|---|---|---|
| `redi-jkt-01` | Jakarta | Edge, Reverse Proxy, Load Balancer, Primary DNS, HA Platform Node, Portainer Agent | Production |
| `redi-mjk-01` | Mojokerto | Shared Platform, GitLab EE, Authentik, HA Platform Node, Portainer Server | Production |
| `redi-sby-01` | Surabaya | Secondary DNS, Disaster Recovery, HA Platform Node, Portainer Agent | Production |

---

## 8.3 Infrastructure Architecture

```text
                           Internet
                               │
                               ▼
                     Public Domains (HTTPS)
                               │
                               ▼
              Traefik Reverse Proxy & Load Balancer
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
   redi-jkt-01           redi-mjk-01          redi-sby-01
     Jakarta              Mojokerto             Surabaya
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
                               ▼
                  NetBird / WireGuard Overlay
                               │
                               ▼
                    Shared Platform Services
                               │
                               ▼
                  Portainer Management Platform
```

---

## 8.4 Current State

| Component | Current State |
|---|---|
| Jakarta VPS | Operational |
| Mojokerto VPS | Operational |
| Surabaya VPS | Operational |
| Docker | Operational |
| Private Node Connectivity | Operational |
| PowerDNS HA | Operational |
| Traefik | Operational |
| Shared PostgreSQL | Operational with streaming replication |
| Shared Redis | Operational with Sentinel |
| Shared MinIO | Operational in single-node erasure configuration |
| GitLab EE | Operational |
| Authentik | Operational |
| Portainer | Target |
| Monitoring Platform | Target |

---

## 8.5 Target

- Three independent infrastructure nodes.
- Multi-location platform architecture.
- Secure node-to-node connectivity.
- No backend communication through the public Internet.
- Shared infrastructure services.
- High Availability for critical services.
- Disaster Recovery capability.
- Centralized infrastructure management.
- Centralized monitoring.
- Infrastructure capable of supporting REDI applications.

---

## 8.6 Implementation

- Deploy and maintain three independent VPS nodes.
- Install Docker Engine.
- Install Docker Compose.
- Connect all nodes through NetBird/WireGuard.
- Deploy PowerDNS authoritative DNS.
- Deploy Traefik Reverse Proxy and Load Balancer.
- Deploy Shared Data Platform.
- Deploy Portainer management.
- Deploy GitLab EE.
- Deploy Authentik.
- Deploy Backup and Disaster Recovery capabilities.
- Deploy Monitoring Platform.

---

## 8.7 Verification

### Service Health

- [ ] `redi-jkt-01` healthy.
- [ ] `redi-mjk-01` healthy.
- [ ] `redi-sby-01` healthy.
- [ ] Docker Engine healthy on all nodes.
- [ ] Required containers healthy.

### Network

- [ ] Jakarta can reach Mojokerto through Private Mesh Network.
- [ ] Jakarta can reach Surabaya through Private Mesh Network.
- [ ] Mojokerto can reach Surabaya through Private Mesh Network.
- [ ] Backend communication does not depend on the public Internet.
- [ ] Replication traffic uses Private Mesh Network.

### Functional

- [ ] Public applications reachable.
- [ ] Internal services reachable between authorized nodes.
- [ ] Container management operational.
- [ ] Replication operational.
- [ ] Backup communication operational.

---

## 8.8 Definition of Done

- Three infrastructure nodes operational.
- Docker operational on all required nodes.
- Private Mesh Network operational.
- Node-to-node communication validated.
- Shared services accessible through the Private Mesh Network.
- Public services accessible through Traefik.
- Infrastructure management operational.
- Security validation passed.
- Infrastructure ready for High Availability services.

---

# 9. Network Architecture

## 9.1 Purpose

Provide secure communication between users, public services, infrastructure nodes, containers, shared services, replication services, and management platforms.

---

## 9.2 Technology

- NetBird
- WireGuard
- Docker Network
- Traefik
- PowerDNS
- UFW

---

## 9.3 Network Layers

| Network | Purpose | Access |
|---|---|---|
| Public Network | Public application access | Internet |
| Private Mesh Network | Node and service communication | Authorized REDI nodes |
| Docker Network | Container communication | Local containers |
| Management Network | Infrastructure management | Private Mesh Network |
| Replication Network | Database and platform replication | Private Mesh Network |

---

## 9.4 Public Network

### Purpose

Provide controlled access to REDI Cloud Platform public services.

### Public Domains

| Platform | Domain | Protocol |
|---|---|---|
| Git Platform | `git.letsredi.com` | HTTPS |
| Container Registry | `registry.letsredi.com` | HTTPS |
| Identity Platform | `auth.letsredi.com` | HTTPS |
| Object Storage | `storage.letsredi.com` | HTTPS |
| Monitoring | `grafana.letsredi.com` | HTTPS |
| Platform Status | `status.letsredi.com` | HTTPS |
| Primary DNS | `ns1.letsredi.com` | DNS |
| Secondary DNS | `ns2.letsredi.com` | DNS |

---

## 9.5 Private Mesh Network

### Technology

- NetBird
- WireGuard

### Purpose

- Secure node-to-node communication.
- Database replication.
- Redis replication.
- Internal service communication.
- Cluster communication.
- Container management.
- Backup traffic.
- Disaster Recovery traffic.
- Infrastructure management.
- Monitoring traffic.

### Rules

- Public Internet MUST NOT be used for backend platform communication.
- Database replication MUST use the Private Mesh Network.
- Redis replication MUST use the Private Mesh Network.
- Platform management MUST use the Private Mesh Network.
- Portainer communication MUST use the Private Mesh Network.
- Backup traffic MUST use the Private Mesh Network.
- Disaster Recovery traffic MUST use the Private Mesh Network.
- Monitoring traffic SHOULD use the Private Mesh Network.

---

## 9.6 Internal Service Access

Internal services MUST use private node addresses and Docker service discovery.

Public DNS names MUST NOT be required for internal service communication.

| Service | Access Policy |
|---|---|
| PostgreSQL | Private Mesh / Docker Network |
| Redis | Private Mesh / Docker Network |
| MinIO Backend | Private Mesh / Docker Network |
| Traefik Dashboard | Private Mesh |
| Portainer | Private Mesh |
| Replication Services | Private Mesh |
| Backup Services | Private Mesh |
| Monitoring Backend | Private Mesh / Docker Network |

---

## 9.7 Docker Network

### Purpose

- Container-to-container communication.
- Application-to-shared-service communication.
- Service isolation.
- Internal API communication.

### Rules

- Containers MUST use dedicated Docker networks where required.
- Database services MUST NOT expose unnecessary public ports.
- Redis MUST NOT expose unnecessary public ports.
- Internal MinIO communication MUST NOT require public access.
- Management services MUST use restricted access.

---

## 9.8 Traffic Flow

### External Traffic

```text
Internet
   │
   ▼
PowerDNS
   │
   ▼
Traefik
   │
   ▼
Application
   │
   ▼
Shared Platform
```

### Internal Traffic

```text
Application
   │
   ▼
Private Mesh / Docker Network
   │
   ├── PostgreSQL
   │
   ├── Redis
   │
   └── MinIO
```

### Infrastructure Management

```text
Administrator
   │
   ▼
Private Mesh Network
   │
   ▼
Portainer Server
   │
   ▼
Portainer Agents
   │
   ▼
Docker Engine
```

### Replication Traffic

```text
Primary Service
   │
   ▼
Private Mesh Network
   │
   ▼
Replica Service
```

---

## 9.9 Current State

| Component | Current State |
|---|---|
| Public DNS | Operational |
| PowerDNS Primary | Operational |
| PowerDNS Secondary | Operational |
| Traefik | Operational |
| Node Private Connectivity | Existing connectivity operational |
| NetBird Standardization | Target |
| Docker Networks | Operational |
| PostgreSQL Replication Network | Operational |
| Redis Replication Network | Operational |

---

## 9.10 Target

- NetBird/WireGuard standardized across all nodes.
- All backend traffic uses Private Mesh Network.
- All replication traffic uses Private Mesh Network.
- Internal services are not publicly accessible.
- Public services are accessible only through controlled entry points.
- Network access follows Least Privilege.
- Network architecture supports High Availability.
- Network architecture supports Disaster Recovery.

---

## 9.11 Implementation

- Deploy NetBird management architecture.
- Connect all REDI nodes.
- Validate WireGuard tunnels.
- Configure Private Mesh Network addressing.
- Restrict internal service access.
- Configure Docker network isolation.
- Configure UFW rules.
- Route public applications through Traefik.
- Route internal traffic through Private Mesh Network.
- Validate replication traffic paths.
- Validate management traffic paths.
- Validate monitoring traffic paths.

---

## 9.12 Verification

### Service Health

- [ ] NetBird healthy.
- [ ] WireGuard tunnels healthy.
- [ ] Docker networks healthy.
- [ ] Traefik network connectivity healthy.

### Connectivity

- [ ] Jakarta to Mojokerto connectivity verified.
- [ ] Jakarta to Surabaya connectivity verified.
- [ ] Mojokerto to Surabaya connectivity verified.
- [ ] Container-to-container connectivity verified.
- [ ] Application-to-PostgreSQL connectivity verified.
- [ ] Application-to-Redis connectivity verified.
- [ ] Application-to-MinIO connectivity verified.

### Security

- [ ] PostgreSQL not publicly accessible.
- [ ] Redis not publicly accessible.
- [ ] MinIO backend access restricted.
- [ ] Traefik Dashboard not publicly accessible.
- [ ] Portainer not publicly accessible.
- [ ] Replication ports restricted.
- [ ] Management ports restricted.

---

## 9.13 Definition of Done

- Private Mesh Network operational.
- All infrastructure nodes connected.
- Internal traffic isolated.
- Replication traffic protected.
- Management traffic protected.
- Public traffic controlled through Traefik.
- Network security validation passed.
- Network ready for production platform services.

---

# 10. Security Architecture

## 10.1 Purpose

Protect REDI Cloud Platform infrastructure, network, applications, shared services, data, management interfaces, and backups.

---

## 10.2 Security Principles

- Zero Trust
- Least Privilege
- Private by Default
- Public by Exception
- TLS Everywhere
- Identity First
- Defense in Depth
- Secure by Default
- Data Integrity First
- Auditable Operations

---

## 10.3 Security Layers

| Layer | Security Control |
|---|---|
| Infrastructure | UFW, Fail2Ban, Host Hardening |
| Network | NetBird, WireGuard |
| Container | Docker Network Isolation |
| Edge | Traefik, TLS |
| Identity | Authentik |
| Application | RBAC, MFA |
| Data | Authentication, Isolation, Backup |
| Operations | Audit Logging |
| Disaster Recovery | Backup and Restore Validation |

---

## 10.4 Infrastructure Security

### Technology

- UFW
- Fail2Ban
- SSH
- Docker Isolation
- NetBird
- WireGuard

### Requirements

- UFW MUST be enabled.
- Only required ports MUST be allowed.
- SSH access MUST be restricted.
- Fail2Ban MUST be operational.
- Internal services MUST NOT be directly exposed.
- Administrative services MUST use the Private Mesh Network.
- Infrastructure access MUST follow Least Privilege.

---

## 10.5 Network Security

### Requirements

- Node-to-node communication MUST use encrypted tunnels.
- Backend communication MUST use the Private Mesh Network.
- Replication traffic MUST use the Private Mesh Network.
- Management traffic MUST use the Private Mesh Network.
- Public exposure MUST be explicitly approved.
- Unnecessary ports MUST remain closed.

---

## 10.6 Application Security

### Requirements

- Public applications MUST use HTTPS.
- TLS certificates MUST be valid.
- TLS certificate renewal MUST be automated.
- Authentication MUST use centralized identity where supported.
- RBAC MUST be implemented where supported.
- MFA MUST be enabled for privileged access where supported.
- Administrative interfaces MUST have restricted access.

---

## 10.7 Data Security

### Requirements

- PostgreSQL MUST require authentication.
- Redis MUST require authentication.
- MinIO MUST require authentication.
- Application credentials MUST NOT be hardcoded.
- Persistent data MUST be backed up.
- Backup data MUST be protected.
- Restore procedures MUST be validated.
- Data Integrity MUST be validated after failover.

---

## 10.8 Public Services

| Service | Domain | Access Policy |
|---|---|---|
| GitLab EE | `git.letsredi.com` | Public HTTPS |
| Container Registry | `registry.letsredi.com` | Authenticated HTTPS |
| Authentik | `auth.letsredi.com` | Public HTTPS |
| MinIO Public Endpoint | `storage.letsredi.com` | Controlled HTTPS |
| Grafana | `grafana.letsredi.com` | Authenticated HTTPS |
| Uptime Kuma | `status.letsredi.com` | Controlled HTTPS |
| PowerDNS Primary | `ns1.letsredi.com` | Public DNS |
| PowerDNS Secondary | `ns2.letsredi.com` | Public DNS |

---

## 10.9 Internal Services

| Service | Access Method | Public Exposure |
|---|---|---|
| PostgreSQL | Private Mesh / Docker Network | Prohibited |
| Redis | Private Mesh / Docker Network | Prohibited |
| MinIO Backend | Private Mesh / Docker Network | Prohibited |
| Traefik Dashboard | Private Mesh | Prohibited |
| Portainer | Private Mesh | Prohibited |
| Replication Services | Private Mesh | Prohibited |
| Backup Services | Private Mesh | Prohibited |
| Monitoring Backend | Private Mesh / Docker Network | Prohibited |

---

## 10.10 Secrets Management

### Current State

- Environment files.
- Protected configuration files.
- Restricted file permissions.

### Target

- No credentials committed to Git.
- No credentials stored in documentation.
- Restricted secret access.
- Centralized secrets management when production requirements justify implementation.
- Secret rotation procedures.
- Auditability of privileged credentials.

### Implementation

- Remove secrets from source code.
- Remove secrets from Git history where required.
- Use protected environment files.
- Apply restrictive file permissions.
- Separate secrets from application configuration.
- Document secret rotation procedures.
- Evaluate dedicated secrets management before production application deployment.

---

## 10.11 Security Target

- Zero unnecessary public exposure.
- Encrypted node communication.
- Centralized authentication.
- Restricted administrative access.
- Protected persistent data.
- Protected backup data.
- Valid TLS across public applications.
- Auditable platform operations.
- Production security validation completed.

---

## 10.12 Security Implementation

- Configure UFW.
- Configure Fail2Ban.
- Configure NetBird/WireGuard.
- Restrict SSH access.
- Isolate Docker networks.
- Configure Traefik HTTPS.
- Configure automated TLS certificates.
- Deploy Authentik.
- Configure RBAC.
- Configure MFA for privileged accounts where supported.
- Protect secrets.
- Protect backups.
- Enable audit logging.
- Validate public exposure.
- Validate internal service isolation.

---

## 10.13 Security Verification

### Infrastructure

- [ ] UFW active on Jakarta.
- [ ] UFW active on Mojokerto.
- [ ] UFW active on Surabaya.
- [ ] Fail2Ban active on Jakarta.
- [ ] Fail2Ban active on Mojokerto.
- [ ] Fail2Ban active on Surabaya.
- [ ] SSH access validated.

### Network

- [ ] Private Mesh Network encrypted.
- [ ] Internal services isolated.
- [ ] Replication traffic protected.
- [ ] Management traffic protected.
- [ ] Unnecessary public ports closed.

### Application

- [ ] `https://git.letsredi.com` TLS valid.
- [ ] `https://registry.letsredi.com` TLS valid.
- [ ] `https://auth.letsredi.com` TLS valid.
- [ ] `https://storage.letsredi.com` TLS valid.
- [ ] `https://grafana.letsredi.com` TLS valid.
- [ ] `https://status.letsredi.com` TLS valid.

### Data

- [ ] PostgreSQL authentication enabled.
- [ ] Redis authentication enabled.
- [ ] MinIO authentication enabled.
- [ ] Backup access restricted.
- [ ] Restore validation completed.
- [ ] Failover data integrity validated.

### Identity

- [ ] Authentik operational.
- [ ] RBAC validated.
- [ ] MFA validated where required.
- [ ] Administrative access restricted.

---

## 10.14 Definition of Done

- Infrastructure security controls operational.
- Network communication protected.
- Internal services isolated.
- Public services protected by HTTPS.
- TLS certificates valid.
- Centralized identity operational.
- Administrative access restricted.
- Persistent data protected.
- Backup data protected.
- Security verification passed.
- Platform security ready for production workloads.

---

# 11. Infrastructure Platform

## 11.1 Purpose

Provide standardized compute, container runtime, private connectivity, edge routing, and infrastructure management for REDI Cloud Platform.

---

## 11.2 Components

| Component | Technology | Role |
|---|---|---|
| Container Runtime | Docker Engine | Application and platform runtime |
| Container Orchestration | Docker Compose | Service deployment |
| Private Network | NetBird / WireGuard | Secure node communication |
| Reverse Proxy | Traefik | Routing and load balancing |
| Container Management | Portainer | Centralized Docker management |

---

# 11.3 Docker Platform

## Purpose

Provide standardized container runtime for REDI Cloud Platform services.

---

## Technology

- Docker Engine
- Docker Compose

---

## Current State

- Docker operational.
- Platform services deployed using containers.
- Docker Compose used for service deployment.
- Persistent volumes used for stateful services.
- Docker networks used for service communication.

---

## Target

- Standardized Docker installation.
- Standardized Docker Compose structure.
- Persistent data protection.
- Service isolation.
- Health checks.
- Restart policies.
- Centralized management through Portainer.
- Reproducible deployments.
- Documented deployment procedures.

---

## Implementation

- Standardize Docker versions.
- Standardize Docker Compose versions.
- Standardize directory structure.
- Configure persistent storage paths.
- Configure Docker networks.
- Configure container health checks.
- Configure restart policies.
- Configure logging.
- Integrate Docker hosts with Portainer.
- Validate container recovery after restart.

---

## Verification

### Service Health

- [ ] Docker Engine healthy on Jakarta.
- [ ] Docker Engine healthy on Mojokerto.
- [ ] Docker Engine healthy on Surabaya.
- [ ] Docker Compose operational.
- [ ] Required containers healthy.

### Functional

- [ ] Containers start successfully.
- [ ] Containers restart successfully.
- [ ] Persistent data survives container restart.
- [ ] Docker networks operational.
- [ ] Health checks operational.
- [ ] Portainer can manage authorized Docker environments.

---

## Definition of Done

- Docker operational on all required nodes.
- Docker Compose standardized.
- Persistent storage protected.
- Docker networks operational.
- Health checks operational.
- Restart behavior validated.
- Portainer integration operational.

---

# 11.4 Private Mesh Platform

## Purpose

Provide secure encrypted communication between REDI Cloud Platform infrastructure nodes.

---

## Technology

- NetBird
- WireGuard

---

## Current State

- Private node connectivity exists.
- Platform communication uses private connectivity.
- Migration and standardization target is NetBird/WireGuard.

---

## Target

- NetBird deployed.
- All three nodes connected.
- WireGuard tunnels healthy.
- Backend communication uses Private Mesh Network.
- Replication uses Private Mesh Network.
- Management uses Private Mesh Network.
- Backup uses Private Mesh Network.
- Monitoring uses Private Mesh Network where applicable.

---

## Implementation

- Deploy NetBird.
- Configure REDI network.
- Register Jakarta node.
- Register Mojokerto node.
- Register Surabaya node.
- Validate WireGuard tunnels.
- Configure access policies.
- Migrate backend communication.
- Migrate replication communication.
- Migrate management communication.
- Validate network security.

---

## Verification

### Service Health

- [ ] NetBird services healthy.
- [ ] Jakarta peer connected.
- [ ] Mojokerto peer connected.
- [ ] Surabaya peer connected.
- [ ] WireGuard tunnels healthy.

### Functional

- [ ] Jakarta reaches Mojokerto.
- [ ] Jakarta reaches Surabaya.
- [ ] Mojokerto reaches Surabaya.
- [ ] PostgreSQL replication operational.
- [ ] Redis replication operational.
- [ ] Portainer communication operational.
- [ ] Backup communication operational.

### Security

- [ ] Unauthorized access blocked.
- [ ] Internal services not publicly exposed.
- [ ] Mesh policies validated.

---

## Definition of Done

- NetBird operational.
- Three nodes connected.
- WireGuard tunnels operational.
- Backend communication migrated.
- Replication communication protected.
- Management communication protected.
- Security validation passed.

---

# 11.5 Infrastructure Platform Target

- Docker standardized.
- Docker Compose standardized.
- NetBird operational.
- WireGuard tunnels operational.
- Private Mesh Network operational.
- Traefik operational.
- Portainer operational.
- Infrastructure services centrally manageable.
- Infrastructure security validated.

---

# 11.6 Infrastructure Platform Verification

- [ ] Three Docker hosts healthy.
- [ ] Docker Compose operational.
- [ ] Private Mesh Network healthy.
- [ ] Traefik healthy.
- [ ] Portainer healthy.
- [ ] Public routing healthy.
- [ ] Internal routing healthy.
- [ ] Persistent storage validated.
- [ ] Infrastructure security validated.

---

# 11.7 Infrastructure Platform Definition of Done

- Infrastructure runtime operational.
- Private networking operational.
- Edge routing operational.
- Container management operational.
- Infrastructure security operational.
- Infrastructure verification passed.
- Platform ready for Shared Data Platform services.
# 12. Shared Data Platform

## 12.1 Purpose

Provide centralized, reusable, highly available, and protected data services for REDI Cloud Platform and future REDI applications.

---

## 12.2 Components

| Component | Technology | Primary Function |
|---|---|---|
| Relational Database | PostgreSQL 16 | Transactional and relational data |
| Cache and Runtime Data | Redis | Cache, session, queue, runtime state |
| Redis High Availability | Redis Sentinel | Redis monitoring and automatic failover |
| Object Storage | MinIO | Files, artifacts, media, backup, object storage |

---

## 12.3 Architecture Principle

Applications MUST use Shared Data Platform services when technically applicable.

Applications MUST NOT deploy embedded or duplicate PostgreSQL, Redis, or MinIO services when Shared Data Platform services are available.

The primary objective is:

> NO TRANSACTION LOSS

High Availability MUST NOT sacrifice data integrity.

Shared Data Platform priorities:

1. Data Integrity
2. High Availability
3. Disaster Recovery
4. Operational Simplicity
5. Scalability

---

## 12.4 Shared Data Architecture

```text
                     Application Platform
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         PostgreSQL         Redis           MinIO
              │               │               │
              ▼               ▼               ▼
         Replication       Sentinel        Object Data
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                   Private Mesh Network
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         redi-jkt-01     redi-mjk-01     redi-sby-01
```

---

## 12.5 Current State

| Service | Current State |
|---|---|
| PostgreSQL 16 | Operational |
| PostgreSQL Primary | Mojokerto |
| PostgreSQL Replica | Jakarta |
| PostgreSQL Streaming Replication | Operational |
| PostgreSQL Replication Mode | Asynchronous |
| PostgreSQL Manual Failover Drill | Passed |
| PostgreSQL Automatic Failover | Target |
| PostgreSQL WAL Archive | Target |
| PostgreSQL PITR | Target |
| PostgreSQL Connection Pooling | Target |
| Redis | Operational |
| Redis Replication | Operational |
| Redis Sentinel | Operational |
| Redis Failover | Validated |
| MinIO | Operational |
| MinIO Current Architecture | Single-node 4-drive erasure |
| MinIO Distributed Architecture | Target when infrastructure is available |

---

## 12.6 Shared Data Platform Target

- Shared PostgreSQL operational.
- PostgreSQL replication operational.
- PostgreSQL automatic failover operational.
- PostgreSQL split-brain protection operational.
- PostgreSQL connection routing operational.
- PostgreSQL WAL archival operational.
- PostgreSQL Point-in-Time Recovery operational.
- Shared Redis operational.
- Redis replication operational.
- Redis Sentinel quorum operational.
- Redis automatic failover operational.
- Redis endpoint routing after failover operational.
- Shared MinIO operational.
- MinIO data protected.
- MinIO backup or replication operational.
- Shared services isolated from public Internet.
- Data Integrity validation passed.
- High Availability validation passed.
- Disaster Recovery validation passed.

---

## 12.7 Shared Data Platform Implementation

- Complete PostgreSQL High Availability.
- Implement PostgreSQL replication slot.
- Implement WAL archival.
- Implement Point-in-Time Recovery.
- Implement PostgreSQL automatic failover.
- Implement PostgreSQL connection routing.
- Complete Redis Sentinel topology.
- Validate Redis quorum.
- Implement Redis endpoint routing after failover.
- Protect Redis persistence.
- Maintain Shared MinIO.
- Implement MinIO backup or replication.
- Validate backup.
- Validate restore.
- Validate failover.
- Validate Data Integrity.

---

## 12.8 Shared Data Platform Verification

### PostgreSQL

- [ ] PostgreSQL primary healthy.
- [ ] PostgreSQL replica healthy.
- [ ] Streaming replication healthy.
- [ ] Replication slot operational.
- [ ] WAL archive operational.
- [ ] PITR operational.
- [ ] Automatic failover operational.
- [ ] Connection routing operational.
- [ ] Failover integrity validated.
- [ ] Split-brain protection validated.

### Redis

- [ ] Redis master healthy.
- [ ] Redis replicas healthy.
- [ ] Sentinel nodes healthy.
- [ ] Sentinel quorum healthy.
- [ ] Automatic failover operational.
- [ ] Endpoint routing after failover operational.
- [ ] Redis persistence validated.
- [ ] Redis data integrity validated.

### MinIO

- [ ] MinIO healthy.
- [ ] Required buckets available.
- [ ] Object upload successful.
- [ ] Object download successful.
- [ ] Persistent data validated.
- [ ] Backup or replication operational.
- [ ] Restore validated.

### Security

- [ ] PostgreSQL not publicly accessible.
- [ ] Redis not publicly accessible.
- [ ] MinIO backend not unnecessarily publicly accessible.
- [ ] Replication traffic uses Private Mesh Network.
- [ ] Authentication enabled.
- [ ] Access restrictions validated.

---

## 12.9 Shared Data Platform Definition of Done

- PostgreSQL High Availability operational.
- PostgreSQL automatic failover operational.
- PostgreSQL connection routing operational.
- WAL archival operational.
- PITR operational.
- Redis High Availability operational.
- Redis automatic failover operational.
- Redis endpoint routing operational.
- MinIO operational and protected.
- Backup validated.
- Restore validated.
- Failover validated.
- Data Integrity validated.
- Shared Data Platform ready for production applications.

---

# 13. PostgreSQL Platform

## 13.1 Purpose

Provide centralized relational and transactional database services for REDI Cloud Platform.

---

## 13.2 Technology

- PostgreSQL 16
- PostgreSQL Streaming Replication
- Physical Replication Slot
- WAL Archiving
- Point-in-Time Recovery
- PostgreSQL Automatic Failover
- PgBouncer

---

## 13.3 Architecture

```text
                       Application
                            │
                            ▼
                  PostgreSQL Entry Point
                            │
                            ▼
                       PgBouncer
                            │
                            ▼
                   Active PostgreSQL
                            │
                            ▼
                 Streaming Replication
                            │
                            ▼
                  PostgreSQL Replica
                            │
                            ▼
                       WAL Archive
                            │
                            ▼
                           MinIO
```

---

## 13.4 Current State

| Requirement | Current State |
|---|---|
| PostgreSQL 16 | Operational |
| Primary | `redi-mjk-01` |
| Replica | `redi-jkt-01` |
| Streaming Replication | Operational |
| Replication State | Streaming |
| Replication Mode | Asynchronous |
| Manual Failover | Validated |
| Failover Promotion | Approximately 2 seconds during drill |
| Data Integrity | Validated during failover drill |
| Replica Rebuild | Validated |
| Automatic Failover | Not Implemented |
| Physical Replication Slot | Target |
| WAL Archive | Target |
| PITR | Target |
| PgBouncer | Target |

---

## 13.5 Architecture Requirements

- Applications MUST use Shared PostgreSQL.
- Applications MUST NOT deploy embedded PostgreSQL when Shared PostgreSQL is applicable.
- PostgreSQL MUST NOT be publicly exposed.
- PostgreSQL replication MUST use Private Mesh Network.
- Persistent data MUST survive container restart.
- Failover MUST preserve transactional data.
- Automatic failover MUST include split-brain protection.
- Applications SHOULD use a stable PostgreSQL connection endpoint.
- PostgreSQL backups MUST support restoration.
- PostgreSQL MUST support Point-in-Time Recovery.

---

## 13.6 Data Integrity Target

- Prevent avoidable transaction loss.
- Prevent WAL loss when replica is temporarily unavailable.
- Maintain consistent database state.
- Validate row integrity after failover.
- Validate application data after failover.
- Protect against accidental deletion.
- Support recovery to a defined point in time.

---

## 13.7 High Availability Target

- Primary failure detection.
- Automatic PostgreSQL promotion.
- Split-brain protection.
- Stable application database endpoint.
- Automatic or controlled connection rerouting.
- Replica recovery.
- Failed-node rejoin procedure.
- Failover validation.

---

## 13.8 Disaster Recovery Target

- PostgreSQL backups operational.
- WAL archival operational.
- PITR operational.
- Backup retention defined.
- Restore procedure documented.
- Restore drill validated.
- Database recovery independent from the failed primary node.

---

## 13.9 Implementation

### Replication Protection

- Configure physical replication slot.
- Validate replication slot.
- Validate WAL retention.
- Monitor replication lag.

### WAL Archive

- Configure PostgreSQL `archive_mode`.
- Configure `archive_command`.
- Archive WAL to Shared MinIO.
- Validate archived WAL files.
- Define WAL retention policy.

### Point-in-Time Recovery

- Configure base backup process.
- Integrate base backup with WAL archive.
- Define recovery procedure.
- Execute PITR test.
- Validate recovered database.

### Automatic Failover

- Evaluate and implement the simplest approved PostgreSQL automatic failover architecture.
- Prefer operational simplicity.
- Implement split-brain protection.
- Validate primary failure detection.
- Validate promotion.
- Validate failed-node recovery.
- Validate topology restoration.

### Connection Routing

- Deploy PgBouncer.
- Provide stable PostgreSQL connection entry point.
- Configure application database connections.
- Validate connection behavior during failover.
- Validate connection recovery after failover.

---

## 13.10 Verification

### Service Health

- [ ] PostgreSQL primary healthy.
- [ ] PostgreSQL replica healthy.
- [ ] Replication state is streaming.
- [ ] Replication lag within acceptable threshold.
- [ ] PgBouncer healthy.
- [ ] Automatic failover component healthy.

### Data Integrity

- [ ] Test transaction committed.
- [ ] Test transaction replicated.
- [ ] Primary failure simulated.
- [ ] Replica promoted.
- [ ] Test transaction exists after failover.
- [ ] No database corruption detected.
- [ ] Application data validated.

### High Availability

- [ ] Primary failure detected.
- [ ] Automatic failover executed.
- [ ] Split-brain prevented.
- [ ] Application database endpoint remains functional.
- [ ] Application reconnect succeeds.
- [ ] Failed node can rejoin safely.

### Backup

- [ ] PostgreSQL backup successful.
- [ ] Backup stored successfully.
- [ ] Backup retention validated.
- [ ] Restore successful.
- [ ] Restored database integrity validated.

### WAL Archive and PITR

- [ ] WAL archive enabled.
- [ ] WAL files stored in MinIO.
- [ ] Base backup available.
- [ ] PITR recovery executed.
- [ ] Recovery target validated.
- [ ] Recovered database integrity validated.

### Security

- [ ] PostgreSQL not publicly accessible.
- [ ] PostgreSQL authentication enabled.
- [ ] Replication access restricted.
- [ ] Replication traffic uses Private Mesh Network.
- [ ] Backup access restricted.

---

## 13.11 Definition of Done

- PostgreSQL 16 operational.
- Streaming replication operational.
- Physical replication slot operational.
- Automatic failover operational.
- Split-brain protection validated.
- PgBouncer operational.
- Stable application endpoint operational.
- WAL archival operational.
- PITR operational.
- Backup successful.
- Restore successful.
- Failover successful.
- Data Integrity validation passed.
- PostgreSQL Platform ready for production applications.

---

# 14. Redis Platform

## 14.1 Purpose

Provide centralized cache, session, queue, and runtime data services for REDI Cloud Platform.

---

## 14.2 Technology

- Redis
- Redis Replication
- Redis Sentinel
- Redis AOF

---

## 14.3 Architecture

```text
                        Application
                             │
                             ▼
                     Redis Entry Point
                             │
                             ▼
                       Redis Master
                             │
                 ┌───────────┴───────────┐
                 │                       │
                 ▼                       ▼
          Redis Replica             Redis Replica
                 │                       │
                 └───────────┬───────────┘
                             │
                             ▼
                      Redis Sentinel
                             │
                             ▼
                    Automatic Failover
```

---

## 14.4 Current State

| Requirement | Current State |
|---|---|
| Redis | Operational |
| Redis Master | Operational |
| Redis Replication | Operational |
| Redis Replicas | Operational |
| Redis Sentinel | Operational |
| Sentinel Nodes | Mojokerto, Jakarta, Surabaya |
| Sentinel Failover | Validated |
| Failover Time | Approximately 2 seconds during validation |
| Redis Persistence | AOF |
| Endpoint Routing After Failover | Target |
| Restore Drill | Target |

---

## 14.5 Architecture Requirements

- Applications MUST use Shared Redis where technically applicable.
- Applications MUST NOT deploy duplicate Redis services unnecessarily.
- Redis MUST NOT be publicly exposed.
- Redis replication MUST use Private Mesh Network.
- Sentinel communication MUST use consistent reachable addresses.
- Sentinel quorum MUST remain operational.
- Redis failover MUST preserve persisted data.
- Applications MUST have a valid path to the active Redis master after failover.

---

## 14.6 High Availability Target

- Redis master operational.
- Multiple Redis replicas operational.
- Three Sentinel nodes operational.
- Sentinel quorum operational.
- Automatic failover operational.
- Active master discovery operational.
- Stable application routing after failover.
- Failed Redis node recovery operational.

---

## 14.7 Data Protection Target

- Redis AOF enabled.
- Persistence validated.
- Redis backup operational.
- Redis restore procedure available.
- Restore drill validated.
- Data integrity validated after failover.

---

## 14.8 Implementation

### Replication

- Validate Redis master.
- Validate Redis replicas.
- Validate `master_link_status`.
- Validate replication consistency.

### Sentinel

- Standardize Sentinel configuration.
- Standardize monitor addresses.
- Configure correct announce addresses.
- Validate three-node Sentinel visibility.
- Validate quorum.
- Validate master detection.

### Automatic Failover

- Execute Sentinel failover.
- Validate replica promotion.
- Validate new master.
- Validate remaining replicas.
- Validate old master recovery.
- Validate topology restoration.

### Endpoint Routing

- Implement approved active-master routing.
- Maintain stable Redis application access.
- Update routing after Sentinel failover.
- Validate application connectivity after failover.

### Persistence and Restore

- Validate AOF.
- Backup Redis persistence data.
- Define restore procedure.
- Execute Redis restore drill.
- Validate restored data.

---

## 14.9 Verification

### Service Health

- [ ] Redis master healthy.
- [ ] Redis replica Jakarta healthy.
- [ ] Redis replica Surabaya healthy.
- [ ] Sentinel Mojokerto healthy.
- [ ] Sentinel Jakarta healthy.
- [ ] Sentinel Surabaya healthy.

### Replication

- [ ] Redis replicas connected.
- [ ] `master_link_status` is `up`.
- [ ] Replication data validated.
- [ ] Replication traffic uses Private Mesh Network.

### Sentinel

- [ ] All Sentinel nodes detect the same master.
- [ ] Sentinel quorum available.
- [ ] Sentinel failover available.
- [ ] Sentinel addresses reachable.

### Failover

- [ ] Master failure detected.
- [ ] Automatic failover executed.
- [ ] Replica promoted.
- [ ] New master writable.
- [ ] Application endpoint routes to new master.
- [ ] Redis data available after failover.
- [ ] Failed node recovery validated.

### Persistence

- [ ] AOF enabled.
- [ ] AOF persistence validated.
- [ ] Redis backup successful.
- [ ] Redis restore successful.
- [ ] Restored data validated.

### Security

- [ ] Redis authentication enabled.
- [ ] Redis not publicly accessible.
- [ ] Sentinel not publicly accessible.
- [ ] Redis replication protected.
- [ ] Redis management access restricted.

---

## 14.10 Definition of Done

- Shared Redis operational.
- Redis replication operational.
- Three-node Sentinel operational.
- Sentinel quorum operational.
- Automatic failover operational.
- Stable Redis endpoint routing operational.
- Redis persistence validated.
- Redis backup validated.
- Redis restore validated.
- Failover Data Integrity validated.
- Redis Platform ready for production applications.

---

# 15. MinIO Platform

## 15.1 Purpose

Provide centralized S3-compatible object storage for REDI Cloud Platform and REDI applications.

---

## 15.2 Technology

- MinIO
- S3-Compatible API
- Erasure Coding
- MinIO Client

---

## 15.3 Usage

Shared MinIO provides object storage for:

- GitLab object data.
- GitLab artifacts.
- GitLab uploads.
- GitLab packages.
- GitLab backups.
- Application files.
- Media.
- Documents.
- PostgreSQL WAL archives.
- Platform backups.
- Future REDI application objects.

---

## 15.4 Architecture

### Current Architecture

```text
                    Application Platform
                             │
                             ▼
                        Shared MinIO
                             │
                             ▼
                   Single-Node Erasure
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
            Drive          Drive          Drives
```

### Target Architecture

```text
                    Application Platform
                             │
                             ▼
                        MinIO Service
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
         redi-jkt-01    redi-mjk-01    redi-sby-01
              │              │              │
              └──────────────┼──────────────┘
                             │
                             ▼
                  Protected Object Storage
```

---

## 15.5 Current State

| Requirement | Current State |
|---|---|
| Shared MinIO | Operational |
| Current Node | Mojokerto |
| Current Architecture | Single-node |
| Storage Layout | Four-drive erasure |
| GitLab Buckets | Operational |
| Object Storage API | Operational |
| Distributed Multi-Node MinIO | Target |
| Secondary Object Copy | Target |
| Restore Validation | Target |

---

## 15.6 Architecture Requirements

- Applications SHOULD use Shared MinIO for object storage.
- Applications MUST NOT deploy unnecessary duplicate MinIO instances.
- MinIO access MUST require authentication.
- MinIO administrative access MUST be restricted.
- MinIO backend traffic MUST use private connectivity.
- Critical objects MUST have backup or secondary copies.
- Object restore MUST be validated.
- MinIO failure MUST NOT cause permanent loss of critical platform data.

---

## 15.7 Availability Target

- Shared object storage operational.
- Persistent storage protected.
- Critical objects backed up or replicated.
- Recovery procedure available.
- Distributed MinIO implemented when required infrastructure capacity is available.
- Object storage architecture capable of surviving defined infrastructure failures.

---

## 15.8 Data Protection Target

- Required buckets protected.
- Backup policy defined.
- Object retention defined where applicable.
- Secondary copy available for critical data.
- Restore procedure documented.
- Restore drill validated.
- Object integrity validated.

---

## 15.9 Implementation

### Current Platform Protection

- Maintain four-drive erasure configuration.
- Validate storage health.
- Validate disk health.
- Validate required buckets.
- Validate object upload.
- Validate object download.
- Validate persistent data.
- Implement backup or secondary object copy.

### Backup and Recovery

- Define critical buckets.
- Configure MinIO backup or mirror.
- Store secondary copy outside the active MinIO failure domain.
- Define retention policy.
- Define restore procedure.
- Execute restore drill.
- Validate restored objects.

### Distributed MinIO Target

- Validate storage capacity requirements.
- Validate node storage requirements.
- Prepare Jakarta storage.
- Prepare Mojokerto storage.
- Prepare Surabaya storage.
- Deploy distributed architecture when infrastructure is approved.
- Validate node failure behavior.
- Validate object availability.
- Validate recovery.

---

## 15.10 Verification

### Service Health

- [ ] MinIO service healthy.
- [ ] MinIO API healthy.
- [ ] Storage healthy.
- [ ] Required disks healthy.
- [ ] Required buckets available.

### Functional

- [ ] Object upload successful.
- [ ] Object download successful.
- [ ] Object deletion policy validated.
- [ ] Application S3 access successful.
- [ ] GitLab object storage access successful.
- [ ] PostgreSQL WAL archive access successful.

### Data Protection

- [ ] Critical bucket list defined.
- [ ] Backup or secondary copy operational.
- [ ] Backup data validated.
- [ ] Restore successful.
- [ ] Restored object integrity validated.

### Security

- [ ] MinIO authentication enabled.
- [ ] Administrative access restricted.
- [ ] Backend communication protected.
- [ ] Credentials protected.
- [ ] Unnecessary public exposure blocked.

### Distributed Architecture

- [ ] Multi-node architecture requirement approved.
- [ ] Storage capacity available.
- [ ] Distributed MinIO deployed.
- [ ] Node failure validated.
- [ ] Object availability validated.
- [ ] Recovery validated.

---

## 15.11 Definition of Done

- Shared MinIO operational.
- Required buckets operational.
- Object API operational.
- Persistent storage validated.
- Critical data backup or replication operational.
- Restore validated.
- Security validation passed.
- Distributed architecture implemented when required by approved production availability target.
- MinIO Platform ready for production applications.

---

# 16. PowerDNS Platform

## 16.1 Purpose

Provide authoritative DNS services, domain management, service discovery support, and DNS High Availability for REDI Cloud Platform.

---

## 16.2 Technology

- PowerDNS Authoritative Server
- PostgreSQL Backend
- PowerDNS API
- Primary/Secondary DNS Architecture

---

## 16.3 Public Domains

| DNS Service | Domain |
|---|---|
| Primary DNS | `ns1.letsredi.com` |
| Secondary DNS | `ns2.letsredi.com` |

---

## 16.4 Architecture

```text
                          Internet
                              │
                 ┌────────────┴────────────┐
                 │                         │
                 ▼                         ▼
         ns1.letsredi.com          ns2.letsredi.com
                 │                         │
                 ▼                         ▼
           PowerDNS Primary          PowerDNS Secondary
                 │                         │
                 └────────────┬────────────┘
                              │
                              ▼
                        DNS Replication
                              │
                              ▼
                     Private Mesh Network
```

---

## 16.5 Current State

| Requirement | Current State |
|---|---|
| PowerDNS | Operational |
| Primary DNS | Operational |
| Secondary DNS | Operational |
| DNS HA | Operational |
| `ns1.letsredi.com` | Operational |
| `ns2.letsredi.com` | Operational |
| PostgreSQL Backend | Operational |
| DNS API Automation | Available / Target Expansion |
| Service Failover DNS Automation | Target where applicable |

---

## 16.6 Architecture Requirements

- REDI public domains MUST use authoritative DNS.
- Primary and Secondary DNS MUST run on independent nodes.
- DNS failure on one node MUST NOT make the authoritative DNS service unavailable.
- DNS synchronization MUST be validated.
- DNS administrative interfaces MUST be protected.
- DNS API credentials MUST be protected.
- DNS automation MAY be used for approved failover routing.

---

## 16.7 High Availability Target

- Primary DNS operational.
- Secondary DNS operational.
- Independent DNS nodes.
- DNS synchronization operational.
- Zone consistency validated.
- Single DNS node failure tolerated.
- DNS recovery procedure available.

---

## 16.8 Implementation

- Maintain PowerDNS Primary.
- Maintain PowerDNS Secondary.
- Validate DNS replication.
- Validate DNS zone consistency.
- Validate public authoritative responses.
- Protect PowerDNS API.
- Protect PowerDNS backend.
- Implement DNS automation for approved platform failover use cases.
- Validate DNS node failure.
- Validate DNS recovery.

---

## 16.9 Verification

### Service Health

- [ ] PowerDNS Primary healthy.
- [ ] PowerDNS Secondary healthy.
- [ ] PostgreSQL backend healthy.
- [ ] DNS synchronization healthy.

### Public DNS

- [ ] `ns1.letsredi.com` reachable.
- [ ] `ns2.letsredi.com` reachable.
- [ ] Authoritative DNS query successful through Primary.
- [ ] Authoritative DNS query successful through Secondary.
- [ ] Public platform domains resolve correctly.

### High Availability

- [ ] Primary DNS failure simulated.
- [ ] Secondary DNS continues serving requests.
- [ ] DNS service remains available.
- [ ] Primary recovery validated.
- [ ] Zone consistency validated after recovery.

### Security

- [ ] PowerDNS API access restricted.
- [ ] PowerDNS credentials protected.
- [ ] Database access restricted.
- [ ] DNS replication traffic protected.
- [ ] Unnecessary administrative ports closed.

---

## 16.10 Definition of Done

- PowerDNS Primary operational.
- PowerDNS Secondary operational.
- DNS synchronization operational.
- `ns1.letsredi.com` healthy.
- `ns2.letsredi.com` healthy.
- Public domain resolution validated.
- DNS failover validated.
- DNS recovery validated.
- DNS security validation passed.
- PowerDNS Platform ready for production services.
# 17. GitLab Platform

## 17.1 Purpose

Provide centralized Source Code Management, Container Registry, CI/CD, DevOps collaboration, and software delivery platform for REDI Cloud Platform and future REDI applications.

---

## 17.2 Technology

- GitLab EE 17.8
- GitLab Container Registry
- GitLab CI/CD
- External PostgreSQL
- External Redis
- External MinIO
- Traefik Reverse Proxy
- Private Mesh Network

---

## 17.3 Public Domains

| Service | Domain |
|---|---|
| GitLab | `git.letsredi.com` |
| Container Registry | `registry.letsredi.com` |

---

## 17.4 Architecture Principle

GitLab MUST use Shared Platform services.

GitLab MUST NOT use embedded:

- PostgreSQL
- Redis
- MinIO

GitLab architecture priorities:

1. Data Integrity
2. High Availability
3. Disaster Recovery
4. Operational Simplicity
5. Scalability

GitLab application nodes are replaceable.

GitLab persistent data MUST survive application node failure.

---

## 17.5 Architecture

```text
                              Internet
                                  │
                                  ▼
                       git.letsredi.com
                                  │
                                  ▼
                  Traefik Reverse Proxy & Load Balancer
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
                  ▼               ▼               ▼
             GitLab Node     GitLab Node     GitLab Node
              Jakarta         Mojokerto        Surabaya
                  │               │               │
                  └───────────────┼───────────────┘
                                  │
                                  ▼
                       Shared Data Platform
                                  │
                 ┌────────────────┼────────────────┐
                 │                │                │
                 ▼                ▼                ▼
            PostgreSQL          Redis            MinIO
```

---

## 17.6 Current State

| Requirement | Current State |
|---|---|
| GitLab EE 17.8 | Operational |
| GitLab Domain | Operational |
| `git.letsredi.com` | HTTP 200 |
| Container Registry | Operational |
| `registry.letsredi.com` | Operational |
| External PostgreSQL | Operational |
| External Redis | Operational |
| External MinIO | Operational |
| Embedded PostgreSQL | Disabled |
| Embedded Redis | Disabled |
| Embedded Object Storage | Disabled |
| GitLab HA | Target |
| GitLab Load Balancing | Target |
| Multi-Node GitLab | Target |
| GitLab Failover Validation | Target |

---

## 17.7 Target

- GitLab EE operational.
- `git.letsredi.com` operational.
- `registry.letsredi.com` operational.
- GitLab uses Shared PostgreSQL.
- GitLab uses Shared Redis.
- GitLab uses Shared MinIO.
- Multiple GitLab application nodes operational.
- Traefik load balancing operational.
- GitLab application node failure tolerated.
- Git repository data protected.
- GitLab object data protected.
- GitLab backup operational.
- GitLab restore validated.
- GitLab failover validated.
- GitLab High Availability operational.

---

## 17.8 Architecture Requirements

- GitLab MUST use Shared PostgreSQL.
- GitLab MUST use Shared Redis.
- GitLab MUST use Shared MinIO.
- GitLab MUST NOT deploy embedded data services.
- Public access MUST use HTTPS.
- Public traffic MUST enter through Traefik.
- Backend communication MUST use Private Mesh Network.
- GitLab application nodes MUST be replaceable.
- Persistent data MUST NOT depend on a single application container.
- GitLab node failure MUST NOT cause permanent transaction loss.
- GitLab node failure MUST NOT cause permanent repository loss.
- GitLab backup MUST support restoration.
- GitLab HA MUST be validated through controlled failure testing.

---

## 17.9 High Availability Target

- Multiple GitLab application nodes.
- Traefik load balancing.
- Application health checks.
- Failed application nodes automatically removed from active traffic.
- Healthy nodes continue serving requests.
- Shared PostgreSQL available during application failure.
- Shared Redis available during application failure.
- Shared MinIO available during application failure.
- GitLab sessions remain functional according to supported architecture.
- Application nodes can be rebuilt without persistent data loss.

---

## 17.10 Implementation

### GitLab Architecture Review

- Review current GitLab deployment.
- Review GitLab persistent volumes.
- Review GitLab configuration.
- Review external PostgreSQL integration.
- Review external Redis integration.
- Review external MinIO integration.
- Review GitLab Container Registry.
- Review Traefik routing.
- Review Private Mesh Network connectivity.
- Identify single points of failure.

### GitLab Application Nodes

- Prepare GitLab node on Jakarta.
- Maintain GitLab node on Mojokerto.
- Prepare GitLab node on Surabaya.
- Standardize GitLab version.
- Standardize GitLab configuration.
- Standardize secrets.
- Standardize external service configuration.
- Validate node health independently.

### Load Balancing

- Configure Traefik load balancing.
- Configure GitLab backend nodes.
- Configure health checks.
- Configure HTTPS routing.
- Configure `git.letsredi.com`.
- Configure `registry.letsredi.com`.
- Validate traffic distribution.
- Validate unhealthy node removal.

### Shared Platform Integration

- Validate PostgreSQL connection.
- Validate Redis connection.
- Validate MinIO connection.
- Validate GitLab object storage.
- Validate GitLab artifacts.
- Validate GitLab uploads.
- Validate GitLab packages.
- Validate GitLab Container Registry.

### Backup and Restore

- Validate GitLab backup.
- Validate PostgreSQL backup.
- Validate GitLab object storage backup.
- Validate repository backup.
- Define complete GitLab restore procedure.
- Execute restore drill.
- Validate restored GitLab data.

### Failover

- Simulate GitLab application node failure.
- Validate load balancer behavior.
- Validate user access.
- Validate Git operations.
- Validate Container Registry.
- Validate CI/CD operations.
- Restore failed node.
- Validate node rejoin.

---

## 17.11 Verification

### Service Health

- [ ] GitLab Jakarta node healthy.
- [ ] GitLab Mojokerto node healthy.
- [ ] GitLab Surabaya node healthy.
- [ ] Traefik GitLab backend healthy.
- [ ] Shared PostgreSQL connection healthy.
- [ ] Shared Redis connection healthy.
- [ ] Shared MinIO connection healthy.

### Public URL

- [ ] `https://git.letsredi.com` reachable.
- [ ] `https://git.letsredi.com` returns HTTP 200.
- [ ] `https://registry.letsredi.com` reachable.
- [ ] TLS certificate valid.
- [ ] HTTPS redirect operational.

### Functional

- [ ] User login successful.
- [ ] Repository creation successful.
- [ ] Git clone successful.
- [ ] Git push successful.
- [ ] Git pull successful.
- [ ] Container image push successful.
- [ ] Container image pull successful.
- [ ] CI/CD pipeline successful.
- [ ] Artifact upload successful.
- [ ] Artifact download successful.

### High Availability

- [ ] Traffic distributed across GitLab nodes.
- [ ] Application node failure detected.
- [ ] Failed node removed from active traffic.
- [ ] Remaining GitLab nodes continue serving requests.
- [ ] Git clone successful during node failure.
- [ ] Git push successful during node failure.
- [ ] Web access successful during node failure.
- [ ] Container Registry available during node failure.
- [ ] Failed node recovery successful.
- [ ] Recovered node rejoins load balancer.

### Data Integrity

- [ ] Repository data intact after failover.
- [ ] User data intact after failover.
- [ ] GitLab database data intact after failover.
- [ ] Object data intact after failover.
- [ ] Container Registry data intact after failover.
- [ ] No committed transaction lost during controlled failover validation.

### Backup and Restore

- [ ] GitLab backup successful.
- [ ] Repository backup successful.
- [ ] Database backup successful.
- [ ] Object storage backup successful.
- [ ] Restore successful.
- [ ] Restored GitLab accessible.
- [ ] Restored repository validated.
- [ ] Restored Container Registry validated.

### Security

- [ ] GitLab accessible only through HTTPS.
- [ ] GitLab backend ports protected.
- [ ] PostgreSQL not publicly accessible.
- [ ] Redis not publicly accessible.
- [ ] MinIO backend protected.
- [ ] GitLab internal traffic uses Private Mesh Network.
- [ ] Administrative access restricted.

---

## 17.12 Definition of Done

- GitLab EE operational.
- `git.letsredi.com` operational.
- `registry.letsredi.com` operational.
- Multiple GitLab application nodes operational.
- Traefik load balancing operational.
- Shared PostgreSQL integration operational.
- Shared Redis integration operational.
- Shared MinIO integration operational.
- GitLab application failover validated.
- Repository data integrity validated.
- Container Registry validated.
- CI/CD validated.
- Backup validated.
- Restore validated.
- Security validation passed.
- GitLab Platform ready for REDI software development.

---

# 18. Authentik Identity Platform

## 18.1 Purpose

Provide centralized Identity and Access Management for REDI Cloud Platform and future REDI applications.

---

## 18.2 Technology

- Authentik
- OpenID Connect
- OAuth2
- SAML
- External PostgreSQL
- External Redis
- Traefik Reverse Proxy
- Private Mesh Network

---

## 18.3 Public Domain

| Service | Domain |
|---|---|
| Identity Platform | `auth.letsredi.com` |

---

## 18.4 Architecture Principle

Authentik is the centralized Identity Platform for REDI.

Applications SHOULD integrate with Authentik when technically supported.

Identity architecture priorities:

1. Identity Security
2. Availability
3. Data Integrity
4. Operational Simplicity
5. Scalability

Authentik application nodes are replaceable.

Identity data MUST use Shared Platform services.

---

## 18.5 Architecture

```text
                              Internet
                                  │
                                  ▼
                       auth.letsredi.com
                                  │
                                  ▼
                  Traefik Reverse Proxy & Load Balancer
                                  │
                     ┌────────────┴────────────┐
                     │                         │
                     ▼                         ▼
              Authentik Server          Authentik Server
                     │                         │
                     └────────────┬────────────┘
                                  │
                                  ▼
                         Authentik Workers
                                  │
                                  ▼
                       Shared Data Platform
                                  │
                         ┌────────┴────────┐
                         │                 │
                         ▼                 ▼
                    PostgreSQL          Redis
```

---

## 18.6 Current State

| Requirement | Current State |
|---|---|
| Authentik | Operational |
| `auth.letsredi.com` | Healthy |
| External PostgreSQL | Operational |
| External Redis | Operational |
| Embedded PostgreSQL | Not Used |
| Embedded Redis | Not Used |
| Initial Admin Setup | Target |
| Central SSO | Target |
| MFA | Target |
| Authentik HA | Target |
| Failover Validation | Target |

---

## 18.7 Target

- Authentik operational.
- `auth.letsredi.com` operational.
- Initial administration completed.
- Shared PostgreSQL integration operational.
- Shared Redis integration operational.
- Centralized authentication operational.
- SSO operational.
- RBAC operational.
- MFA available.
- Application integration operational.
- Multiple Authentik instances operational.
- Authentik failover validated.
- Identity backup validated.
- Identity restore validated.

---

## 18.8 Architecture Requirements

- Authentik MUST use Shared PostgreSQL.
- Authentik MUST use Shared Redis.
- Authentik MUST NOT deploy embedded data services.
- Public access MUST use HTTPS.
- Backend communication MUST use Private Mesh Network.
- Administrative access MUST be protected.
- MFA SHOULD be enabled for privileged users.
- REDI applications SHOULD use centralized authentication.
- Identity data MUST be backed up.
- Identity restoration MUST be validated.
- Application node failure MUST NOT permanently destroy identity data.

---

## 18.9 Identity Target

- Central user identity.
- Central authentication.
- Single Sign-On.
- Role-Based Access Control.
- Multi-Factor Authentication.
- Application access policies.
- Administrative access policies.
- Identity audit capability.
- Standard authentication integration for future REDI applications.

---

## 18.10 High Availability Target

- Multiple Authentik application instances.
- Multiple Authentik workers where required.
- Traefik load balancing.
- Health checks.
- Application failure detection.
- Failed node traffic removal.
- Shared PostgreSQL availability.
- Shared Redis availability.
- Identity access remains available during application node failure.

---

## 18.11 Implementation

### Initial Setup

- Complete Authentik initial admin setup.
- Create administrative account.
- Protect administrative account.
- Configure MFA.
- Validate Authentik health.
- Validate PostgreSQL integration.
- Validate Redis integration.

### Identity Configuration

- Define REDI users.
- Define REDI groups.
- Define REDI roles.
- Define administrative policies.
- Define application access policies.
- Configure authentication flows.
- Configure recovery flows.

### Application Integration

- Integrate GitLab where approved.
- Integrate Portainer where supported.
- Integrate Grafana.
- Integrate future REDI applications.
- Validate OIDC.
- Validate OAuth2.
- Validate SAML where required.

### High Availability

- Prepare additional Authentik instance.
- Standardize Authentik configuration.
- Standardize secrets.
- Configure Traefik load balancing.
- Configure health checks.
- Validate worker architecture.
- Validate application node failure.
- Validate recovery.

### Backup and Restore

- Protect Authentik PostgreSQL data.
- Protect Authentik media.
- Protect Authentik configuration.
- Define restore procedure.
- Execute restore drill.
- Validate identity data.
- Validate application authentication after restore.

---

## 18.12 Verification

### Service Health

- [ ] Authentik service healthy.
- [ ] Authentik server healthy.
- [ ] Authentik worker healthy.
- [ ] PostgreSQL connection healthy.
- [ ] Redis connection healthy.

### Public URL

- [ ] `https://auth.letsredi.com` reachable.
- [ ] `https://auth.letsredi.com` healthy.
- [ ] TLS certificate valid.
- [ ] HTTPS redirect operational.

### Identity

- [ ] Admin login successful.
- [ ] MFA operational.
- [ ] User creation successful.
- [ ] Group creation successful.
- [ ] Role assignment successful.
- [ ] Authentication policy validated.
- [ ] Access policy validated.

### SSO

- [ ] OIDC provider operational.
- [ ] OAuth2 integration operational.
- [ ] SAML available where required.
- [ ] Application login through Authentik successful.
- [ ] Logout flow validated.
- [ ] Session behavior validated.

### High Availability

- [ ] Multiple Authentik instances healthy.
- [ ] Traefik load balancing operational.
- [ ] Application node failure detected.
- [ ] Failed node removed from traffic.
- [ ] Authentication remains available.
- [ ] Failed node recovery successful.

### Data Integrity

- [ ] User data intact after failover.
- [ ] Group data intact after failover.
- [ ] Policy data intact after failover.
- [ ] Identity configuration intact after failover.

### Backup and Restore

- [ ] Identity backup successful.
- [ ] Media backup successful.
- [ ] Restore successful.
- [ ] User login successful after restore.
- [ ] Application SSO successful after restore.

### Security

- [ ] HTTPS enabled.
- [ ] TLS valid.
- [ ] MFA enabled for privileged users.
- [ ] Administrative access restricted.
- [ ] PostgreSQL not publicly accessible.
- [ ] Redis not publicly accessible.
- [ ] Backend communication uses Private Mesh Network.

---

## 18.13 Definition of Done

- Authentik operational.
- `auth.letsredi.com` operational.
- Initial administration completed.
- Central Identity Platform operational.
- SSO operational.
- RBAC operational.
- MFA operational.
- Shared PostgreSQL integration operational.
- Shared Redis integration operational.
- Application integration validated.
- Authentik High Availability operational.
- Failover validated.
- Backup validated.
- Restore validated.
- Security validation passed.
- Authentik Identity Platform ready for REDI applications.

---

# 19. Portainer Management Platform

## 19.1 Purpose

Provide centralized Docker infrastructure management for all REDI Cloud Platform nodes.

---

## 19.2 Technology

- Portainer
- Portainer Agent
- Docker Engine
- Private Mesh Network

---

## 19.3 Access Endpoint

| Service | Endpoint |
|---|---|
| Portainer | Private Mesh Network Only |

Portainer MUST NOT be exposed directly to the public Internet.

---

## 19.4 Architecture

```text
                         Administrator
                               │
                               ▼
                    Private Mesh Network
                               │
                               ▼
                       Portainer Server
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
       Portainer Agent   Portainer Agent   Portainer Agent
          Jakarta          Mojokerto          Surabaya
              │                │                │
              ▼                ▼                ▼
         Docker Engine    Docker Engine    Docker Engine
```

---

## 19.5 Current State

| Requirement | Current State |
|---|---|
| Portainer Platform | Target / Existing Deployment Validation Required |
| Jakarta Agent | Target |
| Mojokerto Management | Target |
| Surabaya Agent | Target |
| Private Mesh Access | Target |
| Public Exposure Blocked | Target |

---

## 19.6 Target

- Portainer Server operational.
- Jakarta Docker environment connected.
- Mojokerto Docker environment connected.
- Surabaya Docker environment connected.
- Portainer communication uses Private Mesh Network.
- Central Docker management operational.
- Administrative access protected.
- Public exposure blocked.
- Container health visible.
- Stack management operational.

---

## 19.7 Architecture Requirements

- Portainer MUST use Private Mesh Network.
- Portainer MUST NOT expose management interfaces unnecessarily to the Internet.
- Docker environments MUST be managed through protected connectivity.
- Administrative access MUST be restricted.
- REDI infrastructure nodes MUST be visible from centralized management.
- Portainer failure MUST NOT stop running application containers.
- Portainer MUST remain a management platform, not an application runtime dependency.

---

## 19.8 Implementation

- Deploy or validate Portainer Server.
- Connect Jakarta Docker environment.
- Connect Mojokerto Docker environment.
- Connect Surabaya Docker environment.
- Configure Private Mesh Network communication.
- Restrict management ports.
- Configure administrative authentication.
- Validate Docker environments.
- Validate container visibility.
- Validate stack visibility.
- Validate logs.
- Validate container management.

---

## 19.9 Verification

### Service Health

- [ ] Portainer Server healthy.
- [ ] Jakarta Agent healthy.
- [ ] Mojokerto environment healthy.
- [ ] Surabaya Agent healthy.

### Connectivity

- [ ] Jakarta environment connected.
- [ ] Mojokerto environment connected.
- [ ] Surabaya environment connected.
- [ ] Agent traffic uses Private Mesh Network.
- [ ] Management traffic uses Private Mesh Network.

### Functional

- [ ] Docker containers visible.
- [ ] Docker images visible.
- [ ] Docker networks visible.
- [ ] Docker volumes visible.
- [ ] Docker stacks visible.
- [ ] Container logs accessible.
- [ ] Container restart functional.
- [ ] Stack management functional.

### Security

- [ ] Public management access blocked.
- [ ] Administrative authentication enabled.
- [ ] Administrative access restricted.
- [ ] Agent ports protected.
- [ ] Private Mesh connectivity validated.

---

## 19.10 Definition of Done

- Portainer Server operational.
- Three REDI infrastructure nodes connected.
- Central Docker management operational.
- Private Mesh communication operational.
- Administrative access protected.
- Public exposure blocked.
- Platform management validation passed.
- Portainer ready for REDI infrastructure operations.

---

# 20. Monitoring Platform

## 20.1 Purpose

Provide centralized infrastructure, platform, application, service, and availability monitoring for REDI Cloud Platform.

---

## 20.2 Technology

- Prometheus
- Grafana
- Alertmanager
- Node Exporter
- cAdvisor
- Blackbox Exporter

---

## 20.3 Public Domains

| Service | Domain |
|---|---|
| Monitoring Dashboard | `grafana.letsredi.com` |
| Platform Status | `status.letsredi.com` |

---

## 20.4 Architecture Principle

Monitoring MUST provide visibility without becoming a dependency for production application operation.

Monitoring priorities:

1. Service Health
2. Infrastructure Health
3. Data Platform Health
4. Application Availability
5. Alerting
6. Capacity Visibility
7. Operational Simplicity

---

## 20.5 Architecture

```text
                  REDI Infrastructure Nodes
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         Node Exporter     cAdvisor      Service Metrics
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                         Prometheus
                              │
                   ┌──────────┴──────────┐
                   │                     │
                   ▼                     ▼
                Grafana              Alertmanager
                   │
                   ▼
          grafana.letsredi.com

                    External Probes
                          │
                          ▼
                  Blackbox Exporter
                          │
                          ▼
                  status.letsredi.com
```

---

## 20.6 Monitoring Scope

### Infrastructure

- Jakarta VPS.
- Mojokerto VPS.
- Surabaya VPS.
- CPU.
- Memory.
- Disk.
- Network.
- Load.
- Docker Engine.

### Private Mesh Network

- NetBird connectivity.
- WireGuard connectivity.
- Node reachability.
- Inter-node latency.
- Packet loss.

### Shared Data Platform

- PostgreSQL.
- PostgreSQL replication.
- PostgreSQL replication lag.
- PostgreSQL connection health.
- Redis.
- Redis replication.
- Redis Sentinel.
- MinIO.
- MinIO storage health.

### Platform Services

- PowerDNS.
- Traefik.
- GitLab.
- GitLab Container Registry.
- Authentik.
- Portainer.

### Public Services

- `git.letsredi.com`
- `registry.letsredi.com`
- `auth.letsredi.com`
- `storage.letsredi.com`
- `grafana.letsredi.com`
- `status.letsredi.com`
- `ns1.letsredi.com`
- `ns2.letsredi.com`

---

## 20.7 Target

- Prometheus operational.
- Grafana operational.
- Alertmanager operational.
- Node Exporter operational on three nodes.
- cAdvisor operational on three nodes.
- Blackbox Exporter operational.
- Infrastructure monitoring operational.
- Docker monitoring operational.
- PostgreSQL monitoring operational.
- Redis monitoring operational.
- MinIO monitoring operational.
- PowerDNS monitoring operational.
- Traefik monitoring operational.
- GitLab monitoring operational.
- Authentik monitoring operational.
- Portainer monitoring operational.
- Public URL monitoring operational.
- Alerting operational.
- Monitoring data persistent.
- Monitoring security validated.

---

## 20.8 Architecture Requirements

- Monitoring MUST cover all three REDI infrastructure nodes.
- Monitoring backend communication MUST use Private Mesh Network.
- Metrics endpoints MUST NOT be unnecessarily exposed publicly.
- Grafana public access MUST use HTTPS.
- Grafana SHOULD integrate with Authentik.
- Monitoring MUST detect service failure.
- Monitoring MUST detect infrastructure resource exhaustion.
- Monitoring MUST detect PostgreSQL replication failure.
- Monitoring MUST detect Redis replication failure.
- Monitoring MUST detect public URL failure.
- Monitoring MUST provide actionable alerts.
- Monitoring failure MUST NOT stop production applications.

---

## 20.9 Implementation

### Prometheus

- Deploy Prometheus.
- Configure persistent storage.
- Configure scrape targets.
- Configure retention.
- Configure service discovery where applicable.
- Validate metric collection.

### Infrastructure Monitoring

- Deploy Node Exporter on Jakarta.
- Deploy Node Exporter on Mojokerto.
- Deploy Node Exporter on Surabaya.
- Monitor CPU.
- Monitor memory.
- Monitor disk.
- Monitor network.
- Monitor system load.

### Docker Monitoring

- Deploy cAdvisor.
- Monitor containers.
- Monitor CPU usage.
- Monitor memory usage.
- Monitor network usage.
- Monitor container restart state.

### Shared Data Monitoring

- Monitor PostgreSQL health.
- Monitor PostgreSQL replication.
- Monitor replication lag.
- Monitor database connections.
- Monitor Redis health.
- Monitor Redis replication.
- Monitor Redis Sentinel.
- Monitor MinIO health.
- Monitor MinIO capacity.

### Platform Monitoring

- Monitor PowerDNS.
- Monitor Traefik.
- Monitor GitLab.
- Monitor GitLab Container Registry.
- Monitor Authentik.
- Monitor Portainer.

### Public Availability Monitoring

- Deploy Blackbox Exporter.
- Monitor public HTTPS URLs.
- Monitor TLS certificates.
- Monitor DNS.
- Monitor HTTP status.
- Monitor response time.

### Grafana

- Deploy Grafana.
- Configure Prometheus datasource.
- Configure dashboards.
- Configure `grafana.letsredi.com`.
- Configure HTTPS.
- Integrate Authentik where approved.

### Alertmanager

- Deploy Alertmanager.
- Define alert rules.
- Define notification channels.
- Configure infrastructure alerts.
- Configure service alerts.
- Configure replication alerts.
- Configure public availability alerts.

---

## 20.10 Verification

### Prometheus

- [ ] Prometheus healthy.
- [ ] Prometheus targets healthy.
- [ ] Metrics collection successful.
- [ ] Persistent data validated.

### Infrastructure

- [ ] Jakarta metrics available.
- [ ] Mojokerto metrics available.
- [ ] Surabaya metrics available.
- [ ] CPU metrics available.
- [ ] Memory metrics available.
- [ ] Disk metrics available.
- [ ] Network metrics available.

### Docker

- [ ] Jakarta containers visible.
- [ ] Mojokerto containers visible.
- [ ] Surabaya containers visible.
- [ ] Container CPU metrics available.
- [ ] Container memory metrics available.
- [ ] Container network metrics available.

### Shared Data Platform

- [ ] PostgreSQL health visible.
- [ ] PostgreSQL replication visible.
- [ ] PostgreSQL replication lag visible.
- [ ] Redis health visible.
- [ ] Redis replication visible.
- [ ] Redis Sentinel visible.
- [ ] MinIO health visible.
- [ ] MinIO capacity visible.

### Platform Services

- [ ] PowerDNS health visible.
- [ ] Traefik health visible.
- [ ] GitLab health visible.
- [ ] Container Registry health visible.
- [ ] Authentik health visible.
- [ ] Portainer health visible.

### Public URLs

- [ ] `https://git.letsredi.com` healthy.
- [ ] `https://registry.letsredi.com` healthy.
- [ ] `https://auth.letsredi.com` healthy.
- [ ] `https://storage.letsredi.com` healthy.
- [ ] `https://grafana.letsredi.com` healthy.
- [ ] `https://status.letsredi.com` healthy.
- [ ] `ns1.letsredi.com` healthy.
- [ ] `ns2.letsredi.com` healthy.

### Alerting

- [ ] Node failure alert validated.
- [ ] Service failure alert validated.
- [ ] Disk capacity alert validated.
- [ ] PostgreSQL replication failure alert validated.
- [ ] Redis replication failure alert validated.
- [ ] Public URL failure alert validated.
- [ ] Alert notification delivered successfully.

### Security

- [ ] Grafana HTTPS enabled.
- [ ] TLS certificate valid.
- [ ] Metrics endpoints protected.
- [ ] Prometheus not unnecessarily exposed publicly.
- [ ] Alertmanager not unnecessarily exposed publicly.
- [ ] Backend monitoring traffic uses Private Mesh Network.
- [ ] Grafana authentication enabled.

---

## 20.11 Definition of Done

- Prometheus operational.
- Grafana operational.
- `grafana.letsredi.com` operational.
- Alertmanager operational.
- Node Exporter operational on all three nodes.
- cAdvisor operational on all three nodes.
- Blackbox Exporter operational.
- Infrastructure monitoring operational.
- Docker monitoring operational.
- Shared Data Platform monitoring operational.
- Platform service monitoring operational.
- Public URL monitoring operational.
- Alerting operational.
- Monitoring persistence validated.
- Monitoring security validated.
- Monitoring Platform ready for REDI Cloud Platform operations.

---

# 21. Implementation Phases

## Phase 1 — Infrastructure Foundation

### Target

- Three VPS nodes operational.
- Private Mesh Network operational.
- Security baseline operational.
- Docker Engine operational.
- Inter-node communication operational.

### Implementation

- Prepare Jakarta VPS.
- Prepare Mojokerto VPS.
- Prepare Surabaya VPS.
- Deploy NetBird.
- Validate WireGuard overlay.
- Configure UFW.
- Configure Fail2Ban.
- Harden SSH.
- Install Docker Engine.
- Configure Docker networking.

### Verification

- [ ] Three nodes healthy.
- [ ] Private Mesh Network healthy.
- [ ] Inter-node connectivity healthy.
- [ ] Firewall active.
- [ ] Fail2Ban active.
- [ ] Docker healthy.

### Definition of Done

- Infrastructure Foundation operational.

---

## Phase 2 — Network, DNS, and Traffic Platform

### Target

- PowerDNS HA operational.
- Traefik operational.
- Public HTTPS routing operational.
- Private backend communication operational.

### Implementation

- Deploy PowerDNS.
- Configure Primary DNS.
- Configure Secondary DNS.
- Deploy Traefik.
- Configure public domains.
- Configure TLS.
- Configure load balancing.
- Validate backend routing.

### Verification

- [ ] PowerDNS healthy.
- [ ] DNS HA healthy.
- [ ] Traefik healthy.
- [ ] Public domains resolve.
- [ ] HTTPS operational.
- [ ] TLS valid.
- [ ] Load balancing operational.

### Definition of Done

- Network, DNS, and Traffic Platform operational.

---

## Phase 3 — Shared Data Platform

### Target

- PostgreSQL HA operational.
- Redis HA operational.
- MinIO operational and protected.
- No avoidable transaction loss.
- Backup and restore validated.

### Implementation

- Complete PostgreSQL replication protection.
- Implement WAL archival.
- Implement PITR.
- Implement PostgreSQL automatic failover.
- Implement PgBouncer.
- Complete Redis Sentinel.
- Implement Redis endpoint routing.
- Protect MinIO data.
- Implement backup.
- Execute restore drills.

### Verification

- [ ] PostgreSQL HA validated.
- [ ] PostgreSQL automatic failover validated.
- [ ] PostgreSQL Data Integrity validated.
- [ ] WAL archival validated.
- [ ] PITR validated.
- [ ] Redis HA validated.
- [ ] Redis automatic failover validated.
- [ ] Redis endpoint routing validated.
- [ ] MinIO protection validated.
- [ ] Backup validated.
- [ ] Restore validated.

### Definition of Done

- Shared Data Platform production-ready.

---

## Phase 4 — GitLab Platform

### Target

- GitLab EE High Availability operational.
- GitLab Load Balancing operational.
- GitLab uses Shared Platform services.
- Git repository data protected.
- Container Registry operational.

### Implementation

- Review existing GitLab deployment.
- Prepare GitLab application nodes.
- Configure Shared PostgreSQL.
- Configure Shared Redis.
- Configure Shared MinIO.
- Configure Traefik load balancing.
- Configure `git.letsredi.com`.
- Configure `registry.letsredi.com`.
- Validate GitLab failover.
- Validate backup.
- Validate restore.

### Verification

- [ ] GitLab nodes healthy.
- [ ] `https://git.letsredi.com` healthy.
- [ ] `https://registry.letsredi.com` healthy.
- [ ] Load balancing operational.
- [ ] Git operations operational.
- [ ] Container Registry operational.
- [ ] CI/CD operational.
- [ ] Application failover validated.
- [ ] Data Integrity validated.
- [ ] Backup validated.
- [ ] Restore validated.

### Definition of Done

- GitLab Platform production-ready.

---

## Phase 5 — Identity Platform

### Target

- Authentik operational.
- Central authentication operational.
- SSO operational.
- MFA operational.
- Authentik HA operational.

### Implementation

- Complete Authentik setup.
- Configure users.
- Configure groups.
- Configure roles.
- Configure MFA.
- Configure SSO.
- Integrate REDI platforms.
- Configure Authentik HA.
- Validate failover.
- Validate backup and restore.

### Verification

- [ ] `https://auth.letsredi.com` healthy.
- [ ] Admin authentication successful.
- [ ] MFA operational.
- [ ] SSO operational.
- [ ] Application integration operational.
- [ ] Authentik HA validated.
- [ ] Backup validated.
- [ ] Restore validated.

### Definition of Done

- Identity Platform production-ready.

---

## Phase 6 — Management Platform

### Target

- Central Docker management operational.
- Three infrastructure nodes connected.
- Management traffic protected.

### Implementation

- Deploy Portainer.
- Connect Jakarta.
- Connect Mojokerto.
- Connect Surabaya.
- Restrict public access.
- Validate centralized management.

### Verification

- [ ] Portainer healthy.
- [ ] Jakarta connected.
- [ ] Mojokerto connected.
- [ ] Surabaya connected.
- [ ] Docker management operational.
- [ ] Public management access blocked.

### Definition of Done

- Management Platform operational.

---

## Phase 7 — Monitoring Platform

### Target

- Infrastructure monitoring operational.
- Platform monitoring operational.
- Public availability monitoring operational.
- Alerting operational.

### Implementation

- Deploy Prometheus.
- Deploy Grafana.
- Deploy Alertmanager.
- Deploy Node Exporter.
- Deploy cAdvisor.
- Deploy Blackbox Exporter.
- Configure dashboards.
- Configure alert rules.
- Configure public URL monitoring.

### Verification

- [ ] Prometheus healthy.
- [ ] `https://grafana.letsredi.com` healthy.
- [ ] `https://status.letsredi.com` healthy.
- [ ] Three nodes monitored.
- [ ] Docker monitored.
- [ ] Shared Data Platform monitored.
- [ ] Platform services monitored.
- [ ] Public URLs monitored.
- [ ] Alert delivery validated.

### Definition of Done

- Monitoring Platform operational.

---

# 22. Global Verification

## Infrastructure

- [ ] Jakarta VPS healthy.
- [ ] Mojokerto VPS healthy.
- [ ] Surabaya VPS healthy.
- [ ] Docker Engine healthy on all nodes.
- [ ] Private Mesh Network healthy.

## Network

- [ ] NetBird healthy.
- [ ] WireGuard overlay healthy.
- [ ] Inter-node communication healthy.
- [ ] Backend traffic uses Private Mesh Network.
- [ ] Replication traffic uses Private Mesh Network.

## DNS

- [ ] `ns1.letsredi.com` healthy.
- [ ] `ns2.letsredi.com` healthy.
- [ ] DNS HA validated.
- [ ] Public domains resolve correctly.

## Reverse Proxy and Load Balancing

- [ ] Traefik healthy.
- [ ] HTTPS operational.
- [ ] TLS certificates valid.
- [ ] Load balancing operational.
- [ ] Backend health checks operational.

## Shared Data Platform

- [ ] PostgreSQL HA operational.
- [ ] PostgreSQL automatic failover operational.
- [ ] PostgreSQL Data Integrity validated.
- [ ] WAL archival operational.
- [ ] PITR operational.
- [ ] PgBouncer operational.
- [ ] Redis HA operational.
- [ ] Redis automatic failover operational.
- [ ] Redis endpoint routing operational.
- [ ] MinIO operational.
- [ ] MinIO data protected.

## GitLab

- [ ] `https://git.letsredi.com` healthy.
- [ ] `https://registry.letsredi.com` healthy.
- [ ] GitLab HA operational.
- [ ] GitLab load balancing operational.
- [ ] Git operations validated.
- [ ] Container Registry validated.
- [ ] CI/CD validated.

## Identity

- [ ] `https://auth.letsredi.com` healthy.
- [ ] Authentik operational.
- [ ] SSO operational.
- [ ] MFA operational.
- [ ] Authentik HA operational.

## Management

- [ ] Portainer operational.
- [ ] Three Docker environments connected.
- [ ] Management traffic protected.

## Monitoring

- [ ] Prometheus operational.
- [ ] `https://grafana.letsredi.com` healthy.
- [ ] `https://status.letsredi.com` healthy.
- [ ] Infrastructure monitoring operational.
- [ ] Platform monitoring operational.
- [ ] Public availability monitoring operational.
- [ ] Alerting operational.

## Backup and Disaster Recovery

- [ ] PostgreSQL backup validated.
- [ ] PostgreSQL restore validated.
- [ ] PITR validated.
- [ ] Redis backup validated.
- [ ] Redis restore validated.
- [ ] MinIO backup or replication validated.
- [ ] GitLab backup validated.
- [ ] GitLab restore validated.
- [ ] Authentik backup validated.
- [ ] Authentik restore validated.

## Security

- [ ] UFW active.
- [ ] Fail2Ban active.
- [ ] SSH hardened.
- [ ] Public services use HTTPS.
- [ ] TLS certificates valid.
- [ ] PostgreSQL not publicly accessible.
- [ ] Redis not publicly accessible.
- [ ] MinIO backend protected.
- [ ] Portainer not publicly exposed.
- [ ] Monitoring backend protected.
- [ ] Private Mesh Network validated.
- [ ] Administrative access restricted.

---

# 23. Global Definition of Done

REDI Cloud Platform is complete when:

- Three-node infrastructure is operational.
- Private Mesh Network is operational.
- PowerDNS High Availability is operational.
- Traefik Reverse Proxy and Load Balancing are operational.
- Shared PostgreSQL High Availability is operational.
- PostgreSQL automatic failover is operational.
- PostgreSQL WAL archival is operational.
- PostgreSQL PITR is operational.
- PostgreSQL connection routing is operational.
- Redis High Availability is operational.
- Redis automatic failover is operational.
- Redis endpoint routing is operational.
- Shared MinIO is operational and protected.
- GitLab EE High Availability is operational.
- GitLab Container Registry is operational.
- Authentik Identity Platform is operational.
- Central SSO is operational.
- MFA is operational.
- Portainer Management Platform is operational.
- Monitoring Platform is operational.
- Public service health monitoring is operational.
- Alerting is operational.
- Backup is validated.
- Restore is validated.
- Failover is validated.
- Data Integrity is validated.
- Security validation is passed.
- No critical Shared Platform service depends on an unprotected single point of failure.
- REDI Cloud Platform is ready for REDI application development and deployment.
# 24. Development Readiness Gate

REDI Cloud Platform MUST pass the Development Readiness Gate before REDI application development begins.

## Gate Requirements

- [ ] Infrastructure Foundation operational.
- [ ] Three VPS nodes operational.
- [ ] Private Mesh Network operational.
- [ ] Security baseline operational.
- [ ] PowerDNS HA operational.
- [ ] Traefik Reverse Proxy operational.
- [ ] Traefik Load Balancing operational.
- [ ] PostgreSQL HA operational.
- [ ] PostgreSQL automatic failover operational.
- [ ] PostgreSQL WAL archival operational.
- [ ] PostgreSQL PITR operational.
- [ ] PostgreSQL connection routing operational.
- [ ] Redis HA operational.
- [ ] Redis automatic failover operational.
- [ ] Redis endpoint routing operational.
- [ ] MinIO operational.
- [ ] MinIO data protection validated.
- [ ] GitLab EE operational.
- [ ] GitLab HA operational.
- [ ] GitLab Container Registry operational.
- [ ] GitLab CI/CD operational.
- [ ] Authentik operational.
- [ ] Central SSO operational.
- [ ] MFA operational.
- [ ] Portainer operational.
- [ ] Prometheus operational.
- [ ] Grafana operational.
- [ ] Alertmanager operational.
- [ ] Public availability monitoring operational.
- [ ] Backup validated.
- [ ] Restore validated.
- [ ] Failover validated.
- [ ] Data Integrity validated.
- [ ] Security validation passed.

## Gate Decision

| Decision | Condition |
|---|---|
| PASS | All critical requirements completed and validated |
| PASS WITH WARNINGS | Non-critical limitations exist with documented risk acceptance |
| FAIL | Critical infrastructure, data integrity, HA, DR, or security requirements are not met |

## Definition of Done

- REDI Cloud Platform passes Development Readiness Gate.
- Shared Platform is stable.
- Shared Platform is protected.
- Shared Platform is observable.
- Shared Platform recovery is validated.
- REDI application development can begin.

---

# 25. Platform Engineering Principles

## 25.1 Priority Order

All REDI Cloud Platform architecture decisions MUST follow this priority:

1. Data Integrity
2. High Availability
3. Disaster Recovery
4. Operational Simplicity
5. Scalability

---

## 25.2 Data Integrity

The primary objective of REDI Cloud Platform is:

> Do not lose committed transactions.

Requirements:

- Persistent data MUST survive application failure.
- Persistent data MUST survive controlled infrastructure failure.
- Database replication MUST be validated.
- Backup MUST be validated.
- Restore MUST be validated.
- PITR MUST be validated.
- Failover MUST NOT create uncontrolled split-brain.
- Application availability MUST NOT be prioritized above data integrity.

---

## 25.3 High Availability

High Availability MUST remove avoidable service interruption.

Requirements:

- Critical services MUST identify single points of failure.
- Automatic failover MUST be implemented where justified.
- Load balancing MUST use health checks.
- Failed application nodes MUST be removed from active traffic.
- Recovery procedures MUST be tested.
- HA claims MUST be proven through failover drills.

---

## 25.4 Disaster Recovery

Disaster Recovery MUST provide a tested path to recover REDI Cloud Platform.

Requirements:

- Backup without restore validation is NOT considered complete.
- DR procedures MUST be documented.
- Recovery procedures MUST be executable.
- Critical data MUST have recovery mechanisms.
- Recovery Point Objective MUST be measurable.
- Recovery Time Objective MUST be measurable.
- Disaster recovery drills MUST be performed.

---

## 25.5 Operational Simplicity

Architecture MUST use the minimum complexity required to satisfy platform requirements.

Requirements:

- Do not add infrastructure without a defined requirement.
- Do not add software only because it is industry standard.
- Do not create unnecessary abstraction layers.
- Do not create unnecessary internal domains.
- Do not create unnecessary documentation files.
- Prefer existing platform capabilities.
- Prefer native capabilities before adding new platforms.
- One service SHOULD have one deployment method.
- One service SHOULD have one validation method.
- One service SHOULD have one operational runbook.

---

## 25.6 Scalability

Scalability MUST be implemented according to actual platform requirements.

Requirements:

- Application services SHOULD scale horizontally.
- Shared services SHOULD scale according to measured requirements.
- Capacity MUST be observable.
- Scaling decisions MUST use monitoring data.
- Premature infrastructure complexity MUST be avoided.

---

# 26. Architecture Decision Rules

## Infrastructure

- Three primary infrastructure nodes:
  - Jakarta
  - Mojokerto
  - Surabaya
- Nodes MUST communicate through Private Mesh Network.
- NetBird and WireGuard are the approved Private Mesh technologies.
- Internal backend traffic MUST NOT use public Internet paths when Private Mesh connectivity is available.

## DNS

- PowerDNS is the authoritative DNS platform.
- DNS MUST support redundancy.
- Public DNS records MUST point only to approved public services.
- Internal services do not require unnecessary `.redi.internal` domains.
- Private service communication SHOULD use Private Mesh addresses, Docker networking, or approved service discovery.

## Reverse Proxy

- Traefik is the approved Reverse Proxy and Load Balancer.
- Public application access MUST pass through Traefik.
- Public applications MUST use HTTPS.
- Traefik health checks MUST be used for HA backend services.

## Database

- PostgreSQL is the primary relational database platform.
- Applications MUST use Shared PostgreSQL when appropriate.
- PostgreSQL MUST provide replication.
- PostgreSQL MUST provide automatic failover.
- PostgreSQL MUST provide WAL archival.
- PostgreSQL MUST provide PITR.
- PostgreSQL MUST provide controlled connection routing.
- PostgreSQL architecture MUST prioritize transaction integrity.

## Cache and Session Platform

- Redis is the Shared Cache and Session Platform.
- Redis HA MUST use replication and Sentinel.
- Redis failover routing MUST be validated.
- Redis Cluster MUST NOT be introduced without a demonstrated requirement.

## Object Storage

- MinIO is the Shared Object Storage Platform.
- Applications SHOULD use Shared MinIO when appropriate.
- MinIO data MUST be protected.
- MinIO expansion MUST follow actual capacity and durability requirements.

## Git Platform

- GitLab EE is the approved Git Platform.
- GitLab MUST use external Shared Platform services.
- GitLab MUST NOT use embedded PostgreSQL.
- GitLab MUST NOT use embedded Redis.
- GitLab MUST NOT use embedded object storage.
- GitLab MUST support High Availability.
- GitLab MUST use Traefik Load Balancing.

## Identity

- Authentik is the approved Identity Platform.
- REDI applications SHOULD use centralized authentication.
- MFA SHOULD be enabled for privileged users.
- Identity data MUST be protected.
- Authentik MUST use Shared Platform services.

## Management

- Portainer is the approved Docker Management Platform.
- Portainer MUST use Private Mesh Network.
- Portainer MUST NOT become a runtime dependency.
- Portainer failure MUST NOT stop production workloads.

## Monitoring

- Prometheus is the approved metrics platform.
- Grafana is the approved visualization platform.
- Alertmanager is the approved alerting platform.
- Blackbox Exporter is the approved public availability monitoring platform.
- Monitoring failure MUST NOT stop production applications.

---

# 27. Documentation Rules

## Primary Documentation

`README.md` is the primary REDI Cloud Platform architecture, requirement, implementation, verification, and target document.

## Documentation Principles

- Do not create unnecessary documentation files.
- Update existing documentation before creating new documentation.
- Architecture decisions MUST be reflected in `README.md`.
- Implementation status MUST be reflected in `README.md`.
- Verification results MUST be reflected in `README.md`.
- Target changes MUST be reflected in `README.md`.

## Reports

Implementation reports MAY be created only when required for:

- Major deployment validation.
- Failover drill results.
- Disaster recovery drill results.
- Security audit results.
- Major incident analysis.

Reports MUST NOT replace `README.md` as the primary platform specification.

## Archive Rules

- `docs/archive/` contains historical documentation.
- Development agents MUST NOT use `docs/archive/` as the current architecture source.
- Development agents MUST NOT modify `docs/archive/` unless explicitly instructed.
- Historical decisions MUST NOT override current decisions in `README.md`.

---

# 28. AI Development Agent Rules

AI development agents including Cursor, Antigravity, Codex, and other automation tools MUST follow these rules.

## Source of Truth

Before implementation:

1. Read `README.md`.
2. Read current infrastructure configuration.
3. Read current Docker Compose files.
4. Read current deployment scripts.
5. Read current validation scripts.
6. Inspect actual infrastructure state where access is available.

Do not assume architecture based on old reports.

Do not use `docs/archive/` as the current source of truth.

---

## Implementation Rules

- Review before modifying.
- Preserve working infrastructure.
- Do not destroy working services unnecessarily.
- Do not recreate services without validating persistent data paths.
- Do not change architecture without explicit approval.
- Do not add software without a defined requirement.
- Do not create unnecessary documentation.
- Do not create unnecessary scripts.
- Reuse existing scripts when possible.
- Extend existing validation scripts when possible.
- Maintain operational simplicity.
- Protect persistent data before infrastructure changes.
- Create backups before destructive operations.

---

## Execution Rules

For every implementation phase:

1. Review current state.
2. Compare current state with `README.md`.
3. Identify only the remaining gaps.
4. Create an implementation plan.
5. Execute approved changes.
6. Validate service health.
7. Validate URLs.
8. Validate functionality.
9. Validate HA where required.
10. Validate Data Integrity.
11. Validate backup and restore where required.
12. Update `README.md`.
13. Stop when Definition of Done is achieved.

---

## Prohibited Behavior

AI development agents MUST NOT:

- Repeatedly redesign approved architecture.
- Restart completed architecture discussions.
- Introduce unnecessary platforms.
- Introduce unnecessary complexity.
- Create multiple reports for the same implementation.
- Create documentation without a defined purpose.
- Modify archived documentation.
- Destroy persistent data.
- Change persistent data paths without migration validation.
- Expose internal services publicly.
- Claim PASS without verification.
- Claim HA without failover testing.
- Claim backup readiness without restore testing.
- Continue adding tasks after Definition of Done is achieved.

---

# 29. Implementation Status Management

Each phase MUST use one of these statuses:

| Status | Definition |
|---|---|
| NOT STARTED | Implementation has not started |
| IN PROGRESS | Implementation is currently being executed |
| BLOCKED | Implementation cannot continue due to a documented blocker |
| PASS WITH WARNINGS | Core requirements pass with documented non-critical limitations |
| COMPLETE | Implementation and verification passed |

---

## Current Platform Status

| Phase | Platform | Status |
|---|---|---|
| Phase 1 | Infrastructure Foundation | COMPLETE |
| Phase 2 | Network, DNS, and Traffic Platform | COMPLETE |
| Phase 3 | Shared Data Platform | PASS WITH WARNINGS |
| Phase 4 | GitLab Platform | IN PROGRESS |
| Phase 5 | Identity Platform | IN PROGRESS |
| Phase 6 | Management Platform | NOT STARTED / VALIDATION REQUIRED |
| Phase 7 | Monitoring Platform | NOT STARTED |

---

## Current Critical Gaps

- PostgreSQL automatic failover.
- PostgreSQL WAL archival.
- PostgreSQL PITR.
- PostgreSQL connection routing.
- Redis failover endpoint routing.
- MinIO durability protection.
- GitLab High Availability.
- GitLab Load Balancing.
- GitLab failover validation.
- Authentik initial administration.
- Authentik High Availability.
- Portainer three-node management validation.
- Monitoring Platform deployment.
- End-to-end backup validation.
- End-to-end restore validation.
- Development Readiness Gate validation.

---

# 30. Execution Roadmap

```text
PHASE 1
Infrastructure Foundation
        │
        ▼
PHASE 2
Network + DNS + Traefik
        │
        ▼
PHASE 3
Shared Data Platform
PostgreSQL + Redis + MinIO
        │
        ▼
PHASE 4
GitLab Platform
HA + Load Balancing
        │
        ▼
PHASE 5
Authentik Identity Platform
SSO + MFA + HA
        │
        ▼
PHASE 6
Portainer Management Platform
        │
        ▼
PHASE 7
Monitoring Platform
Prometheus + Grafana + Alertmanager
        │
        ▼
GLOBAL VALIDATION
        │
        ▼
DEVELOPMENT READINESS GATE
        │
        ▼
REDI APPLICATION DEVELOPMENT
```

---

# 31. Final Platform Target

REDI Cloud Platform MUST provide:

## Infrastructure

- Three-node distributed infrastructure.
- Jakarta VPS.
- Mojokerto VPS.
- Surabaya VPS.
- Private Mesh Network.
- Secure node-to-node communication.

## Network and Traffic

- PowerDNS High Availability.
- Traefik Reverse Proxy.
- Traefik Load Balancing.
- HTTPS.
- TLS certificate management.
- Backend health checks.

## Shared Data Platform

- PostgreSQL High Availability.
- PostgreSQL automatic failover.
- PostgreSQL WAL archival.
- PostgreSQL PITR.
- PostgreSQL connection routing.
- Redis High Availability.
- Redis automatic failover.
- Redis failover routing.
- Shared MinIO.
- Protected persistent data.

## DevOps Platform

- GitLab EE.
- GitLab High Availability.
- GitLab Container Registry.
- GitLab CI/CD.
- Git repository protection.

## Identity Platform

- Authentik.
- Central authentication.
- SSO.
- RBAC.
- MFA.
- Identity High Availability.

## Management Platform

- Portainer.
- Central Docker management.
- Three-node infrastructure visibility.
- Private management access.

## Monitoring Platform

- Prometheus.
- Grafana.
- Alertmanager.
- Node Exporter.
- cAdvisor.
- Blackbox Exporter.
- Infrastructure monitoring.
- Platform monitoring.
- Application monitoring.
- Public availability monitoring.
- Alerting.

## Data Protection

- Backup.
- Restore.
- Failover.
- PITR.
- Disaster Recovery.
- Data Integrity validation.

## Security

- Zero Trust.
- Least Privilege.
- Private-by-Default.
- Public-by-Exception.
- TLS Everywhere.
- Identity First.
- Defense in Depth.

---

# 32. REDI Cloud Platform Completion Criteria

The REDI Cloud Platform infrastructure phase is COMPLETE when:

- All seven implementation phases meet their Definition of Done.
- All critical public domains are healthy.
- All infrastructure nodes are healthy.
- Private Mesh Network is healthy.
- DNS redundancy is validated.
- Traefik routing is validated.
- Load balancing is validated.
- PostgreSQL Data Integrity is validated.
- PostgreSQL automatic failover is validated.
- PostgreSQL PITR is validated.
- Redis automatic failover is validated.
- Redis routing after failover is validated.
- MinIO data protection is validated.
- GitLab High Availability is validated.
- GitLab Container Registry is validated.
- GitLab CI/CD is validated.
- Authentik SSO is validated.
- Authentik MFA is validated.
- Authentik High Availability is validated.
- Portainer three-node management is validated.
- Monitoring is operational.
- Alerting is operational.
- Backup is validated.
- Restore is validated.
- Disaster Recovery procedures are validated.
- Security validation is passed.
- Development Readiness Gate returns PASS.

---

# 33. Next Milestone

```text
REDI CLOUD PLATFORM
        │
        ▼
INFRASTRUCTURE COMPLETE
        │
        ▼
DEVELOPMENT READINESS GATE
        │
        ▼
REDI APPLICATION PLATFORM
        │
        ▼
REDI KNOWLEDGE PLATFORM
        │
        ▼
REDI AI PLATFORM
        │
        ▼
REDI-OS
```

---

# 34. Final Definition of Done

```text
INFRASTRUCTURE
      +
NETWORK
      +
SECURITY
      +
SHARED DATA
      +
GITLAB
      +
IDENTITY
      +
MANAGEMENT
      +
MONITORING
      +
HIGH AVAILABILITY
      +
BACKUP
      +
RESTORE
      +
DISASTER RECOVERY
      +
DATA INTEGRITY
      +
VERIFICATION
      =
REDI CLOUD PLATFORM READY
```