You are acting as a Principal DevOps Engineer and Platform Architect.

Your responsibility is to bootstrap the infrastructure for REDI LAB.

This is NOT a demo project.

This infrastructure will become the foundation of an Enterprise Knowledge Platform for the next 10 years.

Always prioritize:

- Security
- Maintainability
- Scalability
- Disaster Recovery
- Infrastructure as Code
- Documentation

==================================================
PROJECT
==================================================

Project Name

REDI LAB

Purpose

Enterprise Infrastructure Platform

==================================================
CURRENT PHASE
==================================================

Phase 1

Infrastructure Bootstrap

DO NOT install Kubernetes.

DO NOT install application services.

DO NOT install REDI Capture OS.

Only build infrastructure.

==================================================
SERVER
==================================================

Server 1

Hostname

redi-jkt-01

Public IP

103.149.238.98

Credential :

SSH : 103.149.238.98
user : devapp 
pass : BitApp2026!@#

Role

PowerDNS
Traefik

--------------------------------------------------

Server 2

Hostname

redi-sby-01

Public IP

103.80.214.144

Credential :

ssh : 103.80.214.144:2280
user : root
pass : !Proxmox@Redi123

Role

PowerDNS
Traefik

--------------------------------------------------

Server 3

Hostname

redi-mgmt-01

Credential :

ssh : 103.80.214.144:2280
user : root
pass : !Proxmox@Redi123

Role

Management Plane

GitLab CE
Portainer
Authentik
Prometheus
Grafana
Loki
Uptime Kuma

==================================================
OPERATING SYSTEM
==================================================

Ubuntu Server 22.04 LTS

==================================================
INSTALL ORDER
==================================================

Step 1

Bootstrap all servers.

Install

- Docker CE
- Docker Compose Plugin
- Git
- Curl
- Chrony
- UFW
- Fail2Ban
- Tailscale

--------------------------------------------------

Step 2

Configure Tailscale

All servers must communicate using private network.

No service should depend on public IP internally.

--------------------------------------------------

Step 3

Deploy PowerDNS Cluster

Requirements

PowerDNS Authoritative

PowerDNS API

MariaDB

Replication ready

Persistent Volume

Docker Compose

Environment file

Automatic restart

Healthcheck

PowerDNS API enabled

--------------------------------------------------

Step 4

Deploy Traefik

Requirements

HTTPS Ready

Docker Provider

Let's Encrypt Ready

Dynamic Configuration

Persistent Volume

--------------------------------------------------

Step 5

Deploy Portainer

Management Server only

HTTPS

Persistent Data

--------------------------------------------------

Step 6

Deploy GitLab CE

Management Server only

Persistent Data

External URL configurable

Registry disabled for now

GitLab Pages disabled

Mattermost disabled

Monitoring disabled

Optimize memory usage

==================================================
DIRECTORY STRUCTURE
==================================================

Use

/opt/redi

Create

/opt/redi

compose/

config/

data/

backup/

logs/

scripts/

docs/

Every service must have

docker-compose.yml

.env

README.md

==================================================
DOCUMENTATION
==================================================

Generate

README

Architecture

Installation Guide

Backup Guide

Restore Guide

Upgrade Guide

==================================================
SECURITY
==================================================

Never expose internal services unnecessarily.

Use Docker Networks.

Separate

management

dns

monitoring

Only Traefik exposes HTTP/HTTPS.

==================================================
OUTPUT
==================================================

Generate

1.

Complete folder structure

2.

All Docker Compose files

3.

Bootstrap shell scripts

4.

Environment templates

5.

PowerDNS configuration

6.

Traefik configuration

7.

Portainer configuration

8.

GitLab configuration

9.

Runbooks

10.

Architecture documentation

The output must be production-grade.

Never create placeholders.

Never simplify configuration.

Act as if this infrastructure will be maintained for the next 10 years.