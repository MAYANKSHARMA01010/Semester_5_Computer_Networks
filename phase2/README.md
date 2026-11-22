# Phase 2: High Availability, Redundancy, and Service Isolation

## Overview

This directory is reserved for the upcoming **Phase 2** implementation of the Private Network Service Platform.

Phase 2 will introduce:
- **Backup DNS Resolver:** Secondary DNS resolver on Mac 4 with failover and upstream internet forwarding.
- **DNS TTL & Controlled Propagation:** Dynamic record cutover and caching verification using 30-second TTLs.
- **Backend Service Isolation:** macOS Packet Filter (PF) firewall rules restricting access to backend ports strictly to the NGINX edge.
- **High-Availability Backend Failover:** Passive upstream health monitoring and zero-drop request failover.
- **Controlled Edge Migration:** Active-standby edge proxy cutover between Mac 2 and Mac 3.
- **Systematic Troubleshooting Framework:** Multi-layer diagnostic protocol for faculty evaluation.

---

## Directory Organization

```text
phase2/
├── README.md       # Phase 2 overview and reserved specification
├── src/            # Source code for Phase 2 services and extensions
├── config/         # Service configurations (DNS, NGINX, Firewall PF anchors)
├── scripts/        # Setup, migration, and operational scripts
└── tests/          # Verification, fault-injection, and test suites
```

> **Status:** Directory structure established. Implementation will begin upon approval of Phase 2 rollout.
