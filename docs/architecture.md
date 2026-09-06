# Architecture (Phase 10 summary)

> This document describes the two-region AKS/DR architecture (`terraform/envs/dr-poc`),
> currently parked pending the AD-005 vCPU-quota question. The active near-term
> deployment target is the single-region Azure Container Instances smoke test
> (`terraform/envs/aci-poc`, AD-010) - a deliberately simpler rig with no
> multi-region concerns, described in `DECISIONS.md` rather than diagrammed here.

## Overview

```
                         ┌──────────────────────────┐
                         │   Azure Traffic Manager   │
                         │  (Priority routing, DNS)  │
                         └────────────┬─────────────┘
                    priority 1 ──────┴────── priority 2
                          │                        │
                 ┌────────▼────────┐      ┌────────▼────────┐
                 │  West Europe    │      │  North Europe   │
                 │  (primary)      │      │  (secondary)    │
                 │                 │      │                 │
                 │  AKS (Free tier)│      │  AKS (Free tier)│
                 │  1x B2s node    │      │  1x B2s node    │
                 │  resilientops   │      │  resilientops   │
                 │  backend pod    │      │  backend pod    │
                 │  Static Public  │      │  Static Public  │
                 │  IP (LB Svc)    │      │  IP (LB Svc)    │
                 └────────┬────────┘      └────────┬────────┘
                          │                         │
                          │ pulls images            │ pulls images
                          │ (cross-region)          ▼
                 ┌────────▼────────────────────────────┐
                 │   ACR (Basic, West Europe only)      │
                 └───────────────────────────────────────┘

                 ┌─────────────────┐      ┌─────────────────┐
                 │ PostgreSQL       │──streams──▶│ PostgreSQL │
                 │ Flexible Server  │  (async)   │ read replica│
                 │ (primary, R/W)   │            │ (R/O until  │
                 │ West Europe      │            │ promoted)   │
                 └─────────────────┘            │ North Europe│
                                                  └─────────────┘
```

## Component -> Terraform module map

| Component | Module | Notes |
|---|---|---|
| Resource groups | `envs/dr-poc/main.tf` | One per region + one global (for Traffic Manager) |
| VNets | `modules/network` | One per region, one AKS subnet each, no peering (not needed — no cross-region private traffic in this design) |
| AKS clusters | `modules/aks` | Free tier, 1x `Standard_B2s` node each — see AD-005 |
| Container registry | `modules/acr` | Single Basic-tier instance, West Europe — see AD-004 |
| Database | `modules/postgresql` | Primary + cross-region replica via `create_mode` — see AD-003 |
| Static IPs | inline in `envs/dr-poc/main.tf` | One per region, in the AKS node resource group, referenced by Helm's Service annotation |
| Traffic Manager | `modules/traffic-manager` | Priority routing over the two static IPs — see AD-006 |

## Data flow (steady state)

1. Client resolves `<profile>.trafficmanager.net` -> Traffic Manager returns the West Europe static IP (priority 1, healthy).
2. Client hits the West Europe `resilientops` Service (`LoadBalancer`, static IP) -> pod.
3. Pod reads `DATABASE_URL` from its region's Kubernetes Secret -> connects to the West Europe PostgreSQL primary.
4. The North Europe replica continuously streams from the primary in the background; its own AKS deployment is up and serving from its own (read-only) copy would fail writes if it ever received traffic in this state — it doesn't, because Traffic Manager routes 100% of traffic to priority 1 while healthy.

## Why no cross-region VNet peering

Each region's app only ever talks to its *own* region's PostgreSQL server
(primary talks to primary, secondary/replica talks to the replica) — there
is no cross-region application traffic that would need private networking.
The only cross-region traffic is PostgreSQL's own replication stream, which
Flexible Server handles over the public endpoint (see AD-003's public
network access + firewall compromise) without requiring Terraform to set up
peering.

## See also

- `DECISIONS.md` — the reasoning behind every non-default choice above.
- `docs/security.md` — POC-vs-production security posture.
- `docs/dr-runbook.md` — how failover/failback actually works operationally.
- `docs/cost-analysis.md` — what each of these components costs.
