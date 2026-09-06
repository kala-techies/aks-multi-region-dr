# AKS Multi-Region DR

A disaster-recovery reference architecture on Azure, built around a real
three-tier application: a static frontend, a FastAPI backend, and a managed
PostgreSQL database. The end goal is an active-passive deployment across
two Azure regions with automatic traffic failover; the path there runs
through a working single-region deployment first, proven against real
Azure infrastructure.

## What's here

**ResilientOps** — a service-health and incident-tracking application (the
kind of internal tool that sits behind a public status page): services,
incidents with a severity/status workflow, a per-incident update timeline,
a derived overall-health summary, and metrics. It exists to give the
infrastructure something real to run and fail over, not as a demo for its
own sake.

| Tier | Implementation |
|---|---|
| Presentation | Static HTML/CSS/JS dashboard, served by nginx (`frontend/`) |
| Application | FastAPI REST API (`app/`) — 17 automated tests |
| Data | PostgreSQL (Azure Database for PostgreSQL Flexible Server in the cloud; SQLite for local development) |

Each tier is its own container image and its own deployable unit.

## Status

The full stack has been **deployed to Azure and verified working from
outside Azure** — a real resource group, container registry, managed
PostgreSQL server, and running containers, reached over the public internet
and confirmed responding correctly — then torn down deliberately once
proven. That deployment used **Azure Container Instances** as a fast,
low-cost way to validate the application end-to-end. The **multi-region
AKS architecture** (the actual disaster-recovery target) is designed,
written, and locally validated, but not yet deployed — see
[Roadmap](#roadmap) below for why and what's next.

Nothing is currently running in Azure. Redeploying either environment is a
`terraform apply` away; see [Running this project](#running-this-project).

## Architecture

```
                    ┌───────────────────────────┐
                    │      Azure Traffic Manager │
                    │     (priority routing)     │
                    └──────────────┬─────────────┘
                    priority 1 ────┴──── priority 2
                         │                    │
                ┌────────▼────────┐  ┌────────▼────────┐
                │   Region A      │  │   Region B      │
                │   (primary)     │  │   (secondary)    │
                │  AKS + frontend │  │  AKS + frontend  │
                │  + backend pods │  │  + backend pods  │
                └────────┬────────┘  └────────┬────────┘
                         │                     │
                ┌────────▼─────────┐  ┌────────▼─────────┐
                │ PostgreSQL        │──▶│ PostgreSQL        │
                │ Flexible Server   │   │ read replica      │
                │ (primary, R/W)    │   │ (R/O until        │
                └───────────────────┘   │  promoted)         │
                                        └───────────────────┘
```

Full component breakdown, request flow, and every non-default design
choice (with alternatives considered and the tradeoff accepted) are in
[`docs/architecture.md`](docs/architecture.md) and [`DECISIONS.md`](DECISIONS.md).

## Repository layout

```
app/                 FastAPI backend (ResilientOps). Dockerfile included.
frontend/             Static dashboard, its own Dockerfile - a genuine
                      presentation tier, not server-rendered from the backend.
terraform/
  modules/            network, aks, acr, postgresql, traffic-manager, aci
  envs/dr-poc/        two-region AKS + DR architecture (the production target)
  envs/aci-poc/       single-region Container Instances environment (fast
                      validation path, proven working - see PROGRESS.md)
helm/resilientops/    Helm chart for the AKS path
.github/workflows/    ci.yml (runs on every push), cd.yml + aci.yml (gated
                      deploys), build-images.yml (image builds)
docs/                 Architecture, security review, DR runbook, cost
                      analysis, RTO/RPO methodology, troubleshooting,
                      production-hardening guide, GitHub OIDC setup,
                      validation checklist, engineering process
PROGRESS.md           Current status: what's done, what's blocked, what's next
DECISIONS.md          Every architecture decision, numbered, with reasoning,
                      alternatives, and tradeoffs
```

## Running this project

### Locally, no Azure account needed

```bash
# Backend
cd app
python -m venv .venv && .venv/Scripts/activate   # or source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -v                                         # 17 tests, SQLite, no external deps
uvicorn resilientops.main:app --reload --app-dir src

# Frontend, in a second terminal
cd frontend/public
python -m http.server 5500
```

Open http://127.0.0.1:5500 for the dashboard, or use the API directly:

```bash
curl http://127.0.0.1:8000/healthz
curl -X POST http://127.0.0.1:8000/services \
  -H "X-API-Key: dev-local-only-change-me" -H "Content-Type: application/json" \
  -d '{"name":"checkout-api"}'
```

### Validating the infrastructure code, no Azure account needed

```bash
terraform -chdir=terraform/envs/dr-poc  fmt -check && terraform -chdir=terraform/envs/dr-poc  init -backend=false && terraform -chdir=terraform/envs/dr-poc  validate
terraform -chdir=terraform/envs/aci-poc init -backend=false && terraform -chdir=terraform/envs/aci-poc validate

helm lint helm/resilientops
helm template helm/resilientops --set image.repository=example.azurecr.io/resilientops-backend
```

### Deploying to Azure

**Single-region validation path (Azure Container Instances)** — the
fastest way to see this running for real:
1. Complete the one-time GitHub setup in [`docs/github-oidc-setup.md`](docs/github-oidc-setup.md).
2. Run `.github/workflows/build-images.yml` to build and push both images.
3. `terraform apply` (or `.github/workflows/aci.yml`) against `terraform/envs/aci-poc`.
   **Important:** this subscription only permits resource creation in a
   specific region (`centralindia` confirmed working; several others
   confirmed blocked) — see `DECISIONS.md` AD-012 before picking a region.
4. Test the resulting public URL, then `terraform destroy` when finished —
   this environment bills continuously while it exists.

**Multi-region AKS path** — the actual disaster-recovery target, not yet deployed:
1. Read `DECISIONS.md` AD-005 and AD-012 — region and quota constraints on
   this specific subscription need to be resolved before `terraform apply`
   will succeed.
2. Supply `terraform/envs/dr-poc/terraform.tfvars` (see the `.example`
   file) with real values, review the plan, then apply.
3. Deploy via `.github/workflows/cd.yml`.
4. Follow `docs/dr-runbook.md` for the failover test itself.

## Roadmap

- [x] Application built and tested (backend + frontend, 3-tier)
- [x] Infrastructure as code written for both the validation path and the DR target
- [x] Single-region deployment proven against real Azure infrastructure
- [ ] Resolve the region/quota constraints specific to this subscription (`DECISIONS.md` AD-005, AD-012) for the multi-region path
- [ ] Deploy the two-region AKS architecture
- [ ] Run and document the DR failover test (`docs/dr-runbook.md`)
- [ ] Production-hardening pass (`docs/production-hardening.md`)

## Key design decisions

Full reasoning for each is in `DECISIONS.md`; summarized here:

- PostgreSQL Flexible Server with a cross-region read replica for DR, promoted manually on failover (AD-003, AD-007)
- Single Basic-tier container registry, no geo-replication, on cost grounds (AD-004)
- Azure Traffic Manager (DNS-level failover) instead of Front Door, on cost grounds (AD-006)
- Azure Container Instances as a separate, fast validation environment, independent of the AKS target (AD-010)
- This subscription is restricted to a specific Azure region for resource creation, discovered by direct testing (AD-012)
