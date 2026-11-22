# Phase 1: Core Services Platform

## Overview

Phase 1 establishes the foundational infrastructure of the **Private Network Service Platform**. The system distributes services across four macOS machines on a local private network to provide secure, authenticated, and load-balanced web services.

### Core Architecture
- **Private DNS Resolution (Mac 1):** Dedicated DNS resolver running `dnsmasq` mapping private domains (`app.team1.test`, `api.team1.test`) to the NGINX edge.
- **Edge Reverse Proxy & TLS Termination (Mac 2):** High-performance NGINX edge terminating TLS 1.2/1.3 on TCP port 8443 and load balancing HTTP traffic.
- **Upstream Backend Cluster (Mac 3 & Mac 4):** Dual multithreaded Python HTTP backends running on TCP ports 3001 (Backend A) and 3002 (Backend B) with HTTP ETag caching support.

---

## Directory Structure

```
phase1/
├── README.md                           # Phase 1 documentation and operational manual
│
├── backend_a/
│   └── server.py                       # Python HTTP application server A (Port 3001)
│
├── backend-b/
│   └── server.py                       # Python HTTP application server B (Port 3002)
│
├── dns/
│   └── dnsmasq.conf                    # Authoritative dnsmasq configuration template
│
├── nginx/
│   └── network-project.conf            # NGINX reverse proxy & upstream configuration
│
└── scripts/
    ├── setup-mac1.sh                   # Automated setup wrapper for Mac 1 (DNS)
    ├── setup-mac2.sh                   # Automated setup wrapper for Mac 2 (NGINX + Client DNS)
    ├── setup-mac3.sh                   # Automated setup wrapper for Mac 3 (Client DNS + Backend A)
    ├── setup-mac4.sh                   # Automated setup wrapper for Mac 4 (Client DNS + Backend B)
    └── helpers/
        ├── common.sh                   # Shared validation, logging, and environment helpers
        ├── configure-client-dns.sh     # Sets macOS Wi-Fi DNS to Mac 1 and flushes cache
        ├── mac1-update-dns.sh          # Patches, validates, and installs dnsmasq configuration
        ├── mac2-update-nginx.sh        # Patches upstream IPs, validates, and reloads NGINX
        ├── mac3-start-backend.sh       # Validates and starts Backend A (Port 3001)
        ├── mac4-start-backend.sh       # Validates and starts Backend B (Port 3002)
        └── ping/                       # Connectivity test suite verifying LAN reachability
            ├── ping-mac1.sh
            ├── ping-mac2.sh
            ├── ping-mac3.sh
            └── ping-mac4.sh
```

---

## Service & Node Inventory

| Machine | Role | IP Address (LAN) | Service / Protocol | Port | Description |
|---|---|---|---|---|---|
| **Mac 1** | Private DNS Server | `10.7.6.132` | `dnsmasq` (UDP/TCP) | 53 | Resolves local domain queries for all network clients |
| **Mac 2** | Reverse Proxy / Load Balancer | `10.7.17.119` | `nginx` (HTTPS) | 8443 | Terminates TLS and load-balances across backends |
| **Mac 3** | Application Backend A | `10.7.21.15` | Python HTTP | 3001 | Application server instance A (X-Backend: A) |
| **Mac 4** | Application Backend B | `10.7.5.213` | Python HTTP | 3002 | Application server instance B (X-Backend: B) |

*Note: IP addresses are defined in the repository root `.env` configuration file.*

---

## Operational Execution Guide

Ensure the root `.env` file is populated with the correct local LAN IPs before running setup scripts.

### Step 1: Deploy Mac 1 (DNS Server)
Run the automated setup on Mac 1:
```bash
bash phase1/scripts/setup-mac1.sh
```
*Validates network interface, renders `phase1/dns/dnsmasq.conf`, backs up existing Homebrew configuration, tests syntax, and starts `dnsmasq`.*

### Step 2: Deploy Mac 2 (Reverse Proxy / Load Balancer)
Run the automated setup on Mac 2:
```bash
bash phase1/scripts/setup-mac2.sh
```
*Renders upstream block in `phase1/nginx/network-project.conf`, generates self-signed TLS certificates if missing, tests configuration with `nginx -t`, starts/reloads NGINX, and configures client DNS.*

### Step 3: Deploy Mac 3 (Backend A)
Run the automated setup on Mac 3:
```bash
bash phase1/scripts/setup-mac3.sh
```
*Configures local resolver to point to Mac 1 and starts Backend A on port 3001.*

### Step 4: Deploy Mac 4 (Backend B)
Run the automated setup on Mac 4:
```bash
bash phase1/scripts/setup-mac4.sh
```
*Configures local resolver to point to Mac 1 and starts Backend B on port 3002.*

---

## Verification & Testing

1. **LAN Connectivity:**
   ```bash
   bash phase1/scripts/helpers/ping/ping-mac1.sh
   ```
2. **Direct DNS Resolution:**
   ```bash
   dig +short @10.7.6.132 app.team1.test
   # Expected output: 10.7.17.119
   ```
3. **End-to-End HTTPS Request & Load Balancing:**
   ```bash
   for i in {1..4}; do curl -k -s -D - https://app.team1.test:8443/ | grep -E '^(HTTP|X-Backend)'; done
   ```
4. **HTTP Caching Validation (ETag):**
   ```bash
   curl -k -i -H 'If-None-Match: "status-v1"' https://app.team1.test:8443/
   # Expected output: HTTP/1.1 304 Not Modified
   ```

---

## Evidence Location

All historical screenshots, packet captures, and terminal logs for Phase 1 are cataloged under:
`evidence/Phase-1/`
- `DNS/`: DNS resolution screenshots and Wireshark captures
- `LAN/`: Ping reachability outputs
- `NGINX/`: NGINX configuration and listening status screenshots
- `HTTP/`: HTTPS connection success evidence
- `Load-Balancing/`: Round-robin distribution evidence
- `Caching/`: HTTP 304 Not Modified and cache header captures
- `TCP/`: TCP three-way handshake captures
- `TLS/`: TLS handshake and certificate validation captures
- `Failures/`: Fault injection and failure testing captures
