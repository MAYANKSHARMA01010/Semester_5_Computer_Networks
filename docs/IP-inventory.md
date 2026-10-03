# IP and Service Inventory

This document defines the network layout, IP assignments, and service configurations for our Computer Networks private LAN project. The network demonstrates a distributed multi-node architecture comprising a dedicated DNS resolver, an edge reverse proxy and load balancer, and two backend application servers. All components communicate across a private local area network to process client requests end-to-end.

## Machine Inventory

| Machine | Role | IP Address | Service | Port | Description |
|---|---|---|---|---|---|
| Mac 1 | Private DNS Server | 10.7.6.132 | dnsmasq | UDP 53 | Resolves custom private domain names for the network |
| Mac 2 | NGINX Edge / Load Balancer | 10.7.17.119 | nginx | TCP 8443 | Edge reverse proxy terminating TLS and balancing backend traffic |
| Mac 3 | Backend A | 10.7.21.15 | Python backend | TCP 3001 | First upstream application server instance |
| Mac 4 | Backend B | 10.7.5.213 | Python backend | TCP 3002 | Second upstream application server instance |

## DNS Records

| Domain | Record Type | Resolves To | Purpose |
|---|---|---|---|
| app.team1.test | A | 10.7.17.119 | Main web application entry point on Mac 2 |
| api.team1.test | A | 10.7.17.119 | API service entry point on Mac 2 |

## Service Map

- **Mac 1** → DNS (`dnsmasq` on UDP 53)
- **Mac 2** → NGINX / HTTPS (Reverse Proxy & Load Balancer on TCP 8443)
- **Mac 3** → Backend A (Python application on TCP 3001)
- **Mac 4** → Backend B (Python application on TCP 3002)

## Request Flow

1. Client requests `app.team1.test`.
2. DNS query goes to Mac 1 on UDP 53.
3. Mac 1 returns `10.7.17.119`.
4. Client connects to Mac 2 on TCP 8443.
5. NGINX terminates TLS using the certificate covering `app.team1.test` and `api.team1.test`.
6. NGINX forwards the request to Backend A (`10.7.21.15:3001`) or Backend B (`10.7.5.213:3002`).
7. Backend sends the response through NGINX to the client.

## Quick Reference

| Machine | Hostname / Domain | IP Address | Port | Protocol |
|---|---|---|---|---|
| Mac 1 | Private DNS | 10.7.6.132 | 53 | UDP |
| Mac 2 | app.team1.test / api.team1.test | 10.7.17.119 | 8443 | TCP (HTTPS) |
| Mac 3 | Backend A | 10.7.21.15 | 3001 | TCP (HTTP) |
| Mac 4 | Backend B | 10.7.5.213 | 3002 | TCP (HTTP) |

## Notes

- All four machines are intended to communicate over the same private LAN.
- Mac 2 serves as the single edge entry point, operating as both a reverse proxy and load balancer.
- Mac 1 serves as the central DNS server for resolving private domain queries within the network.
- TLS is terminated exclusively at Mac 2 (NGINX), while communication between NGINX and the backend pool occurs over standard HTTP.
