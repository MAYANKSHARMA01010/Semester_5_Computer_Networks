# IP and Service Inventory

This document details the network inventory, IP assignments, and service architecture for our Computer Networks private LAN project. The setup implements an end-to-end distributed system featuring a dedicated private DNS server, an NGINX edge reverse proxy and load balancer, and two backend application servers. All four machines communicate over a local private network to serve client requests securely and efficiently.

## Machine Inventory

| Machine | Role | IP Address | Service | Port | Description |
|---|---|---|---|---|---|
| Mac 1 | Private DNS Server | 10.7.6.132 | dnsmasq | UDP 53 | Resolves local private domains for all network clients |
| Mac 2 | NGINX Edge / Load Balancer | 10.7.17.119 | nginx | TCP 8443 | Edge reverse proxy, terminates TLS and load-balances requests |
| Mac 3 | Backend A | 10.7.21.15 | Python backend | TCP 3001 | Upstream backend application instance A |
| Mac 4 | Backend B | 10.7.5.213 | Python backend | TCP 3002 | Upstream backend application instance B |

## DNS Records

| Domain | Record Type | Resolves To | Purpose |
|---|---|---|---|
| app.team1.test | A | 10.7.17.119 | Main web application entry point on Mac 2 |
| api.team1.test | A | 10.7.17.119 | API service entry point on Mac 2 |

## Service Map

- **Mac 1** → DNS
- **Mac 2** → NGINX/HTTPS
- **Mac 3** → Backend A
- **Mac 4** → Backend B

## Request Flow

1. Client requests `app.team1.test`
2. DNS query goes to Mac 1 on UDP 53
3. Mac 1 returns `10.7.17.119`
4. Client connects to Mac 2 on TCP 8443
5. NGINX terminates TLS
6. NGINX forwards the request to Backend A or Backend B
7. Backend sends the response through NGINX to the client

## Quick Reference

| Machine | Role | IP Address | Port | Protocol / Service |
|---|---|---|---|---|
| Mac 1 | DNS Server | 10.7.6.132 | 53 | UDP (dnsmasq) |
| Mac 2 | Edge / Load Balancer | 10.7.17.119 | 8443 | TCP (HTTPS / NGINX) |
| Mac 3 | Backend A | 10.7.21.15 | 3001 | TCP (HTTP / Python) |
| Mac 4 | Backend B | 10.7.5.213 | 3002 | TCP (HTTP / Python) |

## Notes

- All four machines are intended to communicate over the same private LAN.
- Mac 2 is the edge/reverse proxy and load balancer.
- Mac 1 is the DNS server.
- TLS termination occurs at Mac 2 using certificates valid for `app.team1.test` and `api.team1.test`.
- NGINX routes traffic across Backend A (`10.7.21.15:3001`) and Backend B (`10.7.5.213:3002`).
