# AKS Multi-Region DR (POC)

A proof-of-concept Azure disaster-recovery architecture: an AKS cluster in
West Europe (primary) and one in North Europe (secondary), a two-tier demo
API backed by PostgreSQL Flexible Server with cross-region read replication,
and Azure Traffic Manager for DNS-level failover between them.

**Status: implementation generated and locally/statically validated. No
Azure resources have been created yet.** See `PROGRESS.md` for exactly
what's been validated vs. what still needs a real Azure subscription.

## Why this exists / how it's meant to be used

This repo follows a strict "generate everything, validate locally, don't
touch Azure until told to" workflow — see `CLAUDE.md` for the full operating
rules. If you're picking this project back up after a break, read
**`PROGRESS.md`** and **`DECISIONS.md`** first; the filesystem is the source
of truth for where things stand, not this README.

## Layout

```
app/            FastAPI "Notes API" - the demo workload (Phase 2)
                Dockerfile + .dockerignore (Phase 3)
terraform/
  modules/      network, aks, acr, postgresql, traffic-manager
  envs/dr-poc/  the root module wiring two regions together (Phase 4)
helm/notes-api/ Helm chart deployed identically to both clusters (Phase 5)
.github/
  workflows/    ci.yml (safe, runs on every push) and
                cd.yml (gated, manual, touches real Azure) (Phase 6)
docs/           architecture, security, DR runbook, cost analysis,
                RTO/RPO methodology, troubleshooting, production-hardening,
                GitHub OIDC setup, validation checklist (Phases 7-10)
PROGRESS.md     current phase, what's done, what's blocked, next steps
DECISIONS.md    every non-default architecture choice, with alternatives
                considered and a POC-vs-production tradeoff for each
CLAUDE.md       the operating rules this whole project follows
```

## Quick start (local, no Azure needed)

```bash
cd app
python -m venv .venv
.venv/Scripts/activate      # or: source .venv/bin/activate on Linux/macOS
pip install -r requirements-dev.txt
pytest -v                    # 8 tests, SQLite in-memory, no external dependencies
uvicorn notes_api.main:app --reload --app-dir src
```

Then open http://127.0.0.1:8000/docs for the interactive API docs, or:

```bash
curl http://127.0.0.1:8000/healthz
curl -X POST http://127.0.0.1:8000/notes -H "Content-Type: application/json" -d "{\"title\":\"hi\",\"body\":\"world\"}"
```

## Validating the infrastructure code (no Azure needed)

```bash
terraform -chdir=terraform/envs/dr-poc fmt -check
terraform -chdir=terraform/envs/dr-poc init -backend=false
terraform -chdir=terraform/envs/dr-poc validate

helm lint helm/notes-api
helm template helm/notes-api --set image.repository=example.azurecr.io/notes-api
```

## What it would take to actually deploy this

1. Read `DECISIONS.md` AD-001 (the app scope was assumed, not specified — confirm it's what you want) and AD-005 (the Free Trial vCPU quota risk — the biggest open question in this whole project).
2. `az login`, then `az vm list-usage --location westeurope -o table` (and `northeurope`) to confirm real quota headroom.
3. Copy `terraform/envs/dr-poc/terraform.tfvars.example` to `terraform.tfvars` (gitignored), fill in a real password via `TF_VAR_postgres_administrator_password` instead of the file.
4. `terraform plan`, review it carefully, then — only with explicit sign-off — `terraform apply`.
5. Set up GitHub OIDC + environments per `docs/github-oidc-setup.md`, then use `.github/workflows/cd.yml` for image builds and `helm upgrade` deploys.
6. When ready to test DR, follow `docs/dr-runbook.md` — and get explicit approval first, per its own instructions.

## Key architectural tradeoffs (see `DECISIONS.md` for the full reasoning)

- Single Basic-tier ACR, no geo-replication (cost) — AD-004
- PostgreSQL public network access + firewall allow-list, not a private endpoint (complexity/cost) — AD-003
- Traffic Manager (DNS-level) instead of Front Door (cost) — AD-006
- Free-tier AKS, single `Standard_B2s` node per cluster (Free Trial vCPU cap) — AD-005
- Active-passive DR with manual/scripted database replica promotion, not active-active (the database technology doesn't support it) — AD-007
