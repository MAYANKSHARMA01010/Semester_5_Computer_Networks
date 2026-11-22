# Semester_5_Computer_Networks

## Private Network Service Platform — Computer Networks Course Project

A multi-tier private network platform deployed across four macOS machines on a local area network, featuring private domain resolution, reverse proxy TLS termination, round-robin load balancing, service isolation, high availability, and active-standby edge migration.

---

## Repository Structure

The repository is structured into distinct phase directories to organize the Phase 1 build and Phase 2 extensions:

```text
Semester_5_Computer_Networks/
│
├── phase1/                             # Phase 1: Core Services Platform
│   ├── backend_a/                      # Python HTTP Backend A (Port 3001)
│   ├── backend-b/                      # Python HTTP Backend B (Port 3002)
│   ├── dns/                            # dnsmasq authoritative configuration
│   ├── nginx/                          # NGINX edge reverse proxy & upstream configuration
│   ├── scripts/                        # Automated setup, helper, and ping scripts
│   └── README.md                       # Phase 1 documentation and operational manual
│
├── phase2/                             # Phase 2: High Availability & Security
│   ├── config/                         # Phase 2 configuration variants (DNS, NGINX, PF)
│   ├── scripts/                        # Phase 2 deployment and verification scripts
│   ├── REPORT.md                       # Phase 2 rehearsal results
│   └── README.md                       # Phase 2 operations and verification
│
├── docs/                               # Shared Project Documentation
│   ├── IP-inventory.md                 # Complete network inventory and machine assignments
│   ├── topology.png                    # Network topology diagram
│   └── request-flow.png                # Client request flow diagram
│
├── evidence/                           # Test and Verification Artifacts
│   ├── Phase-1/                        # Phase 1 evidence catalog
│   │   ├── DNS/                        # DNS resolution terminal logs & Wireshark captures
│   │   ├── LAN/                        # Ping connectivity verification outputs
│   │   ├── NGINX/                      # NGINX listener & configuration screenshots
│   │   ├── HTTP/                       # HTTPS success logs
│   │   ├── Load-Balancing/             # Round-robin distribution logs
│   │   ├── Caching/                    # ETag caching & HTTP 304 evidence
│   │   ├── TCP/                        # Three-way handshake packet captures
│   │   ├── TLS/                        # TLS session negotiation evidence
│   │   └── Failures/                   # Fault injection and negative test evidence
│   │
│   ├── Phase-2/                        # Phase 2 evidence by extension
│   └── README.md                       # Evidence checklist
│
├── .env.example                        # Template for environment configuration
├── .gitignore                          # Git ignore rules for backups, certs, and pcaps
├── LICENSE                             # Project license
└── README.md                           # Main repository documentation
```

---

## Network Architecture Summary

| Machine | Role | IP Address (Default) | Services & Ports | Description |
|---|---|---|---|---|
| **Mac 1** | Private DNS Server | `10.7.6.132` | `dnsmasq` (UDP/TCP 53) | Authoritative DNS for `app.team1.test` and `api.team1.test` |
| **Mac 2** | Edge Load Balancer | `10.7.17.119` | `nginx` (TCP 8443) | Terminates TLS and load-balances across backends |
| **Mac 3** | Application Backend A | `10.7.21.15` | Python HTTP (TCP 3001) | Application backend returning `{"backend": "A"}` |
| **Mac 4** | Application Backend B | `10.7.5.213` | Python HTTP (TCP 3002) | Application backend returning `{"backend": "B"}` |

---

## Project Phases

### Phase 1: Core Services Platform
Phase 1 establishes the foundational infrastructure:
- Local DNS resolution with domain forwarding to edge
- TLS termination with self-signed certificate generation
- Upstream HTTP reverse proxying and round-robin load balancing
- Application-level ETag caching validation (`If-None-Match` -> `304 Not Modified`)
- Detailed documentation and operational guides located in **[phase1/README.md](phase1/README.md)**.

### Phase 2: High Availability, Redundancy & Security
Phase 2 introduces enterprise resilience extensions:
- Secondary Backup DNS resolver on Mac 4 with client failover
- 30-second DNS TTL control and dynamic record cutover
- macOS Packet Filter (PF) firewall anchors isolating backend ports
- NGINX passive failure detection and upstream retry
- Active-standby edge migration (Mac 2 -> Mac 3)
- Systematic 4-layer diagnostic troubleshooting protocol
- See the [Phase 2 runbook](phase2/README.md), [report](phase2/REPORT.md), and [evidence checklist](evidence/README.md).

---

## Quick Start

1. Copy `.env.example` to `.env` and fill in current LAN IPs:
   ```bash
   cp .env.example .env
   ```
2. Navigate to Phase 1 and run the setup script corresponding to each machine's assigned role:
   ```bash
   # On Mac 1:
   bash phase1/scripts/setup-mac1.sh

   # On Mac 2:
   bash phase1/scripts/setup-mac2.sh

   # On Mac 3:
   bash phase1/scripts/setup-mac3.sh

   # On Mac 4:
   bash phase1/scripts/setup-mac4.sh
   ```
3. Consult [docs/IP-inventory.md](docs/IP-inventory.md) for detailed service mappings.
