# Progress

## Current status

The application is built, tested, and has been deployed to Azure once
successfully (Azure Container Instances path), verified working from
outside Azure, then torn down after validation. The multi-region AKS
architecture — the actual disaster-recovery target — is fully written and
locally validated but has not yet been deployed, pending the region
constraint noted below.

**Nothing is currently running in Azure.**

## Milestones

### Application: ResilientOps
A service-health and incident-tracking application replaced an earlier,
minimal placeholder app partway through the project once it became clear
the placeholder didn't exercise enough real behavior to be a meaningful
test of the infrastructure. ResilientOps models Services and Incidents
with a severity/status workflow, a per-incident update timeline, a derived
overall-status summary, API-key-gated writes, and Prometheus-format
metrics. 17 automated tests cover the CRUD paths, the auth gate, and the
status-transition logic. See `DECISIONS.md` AD-001 for the reasoning.

### Frontend tier
A static HTML/CSS/JavaScript dashboard was added as its own presentation
tier — a separate container, calling the backend over HTTP with CORS
enabled — rather than server-rendered pages bolted onto the API. This
makes the application a genuine three-tier system rather than an API with
a documentation page. The visual design went through one full revision
after an initial pass read as unfinished; the current design is a
deliberate dark, data-dense "operations console" aesthetic (see
`frontend/public/styles.css`).

### Infrastructure as code
Two independent Terraform environments exist:
- **`terraform/envs/dr-poc`** — the production target: two AKS clusters
  (one per region), PostgreSQL Flexible Server with a cross-region read
  replica, Traffic Manager for failover, a shared container registry.
- **`terraform/envs/aci-poc`** — a single-region Azure Container Instances
  environment, deliberately simpler and decoupled from the AKS design, used
  to validate that the application actually runs correctly in Azure before
  committing further effort to the multi-region build.

Both validate cleanly (`terraform fmt`, `terraform validate`). A shared
Helm chart (`helm/resilientops`) deploys the backend tier to AKS; CI
(`ci.yml`) builds both container images and validates both Terraform
environments on every push.

### Real deployment and validation (Azure Container Instances)
The `aci-poc` environment was deployed for real: a resource group,
container registry, PostgreSQL Flexible Server, and a running container
group (both application tiers behind one public IP). The deployment was
confirmed working with a request from outside Azure entirely (`curl` to
the public endpoint returned a correct, live API response) — the strongest
validation this project has produced to date. The environment was then
destroyed on request once proven, and its removal was confirmed
(`az group exists` returned `false`).

### Subscription-specific constraints discovered
Two limitations specific to the Azure subscription this project deploys to
were found by direct testing, not assumption, and now shape every
deployment decision going forward:

1. **Region restriction.** Resource creation (confirmed for the container
   registry and PostgreSQL Flexible Server) is rejected by Azure in West
   Europe, East US, Central US, South Central US, West US 2, Canada
   Central, North Europe, UK South, France Central, and Sweden Central —
   every region this project's original design assumed. **Central India is
   confirmed to work** and is now the default for any deployment on this
   subscription. This directly affects the AKS path, which was designed
   around West Europe/North Europe and has not yet been re-validated
   against this constraint.
2. **Cloud image builds (ACR Tasks) are also disallowed** on this
   subscription, independent of the region restriction. Combined with no
   local container runtime available in the development environment, this
   meant images had to be built somewhere else entirely. `.github/workflows/build-images.yml`
   was added to solve this: a small, ungated workflow that builds and
   pushes both images from a GitHub-hosted runner.

Full detail, evidence, and the production implications of both findings
are in `DECISIONS.md` AD-012.

## Open items

1. **`app/src/order_api/`** — a leftover directory not produced by any
   tracked work on this project (its contents are a near-verbatim copy of
   the pre-ResilientOps application under a different name). It has been
   excluded from every commit pending a decision on whether to remove it.
2. **Region re-validation for AKS.** The region restriction above was
   confirmed for ACR and PostgreSQL; it has not yet been tested against AKS
   cluster/node-pool creation specifically. Assume it applies until proven
   otherwise.
3. **Quota headroom.** The original vCPU-quota question for the AKS node
   pools (`DECISIONS.md` AD-005) is still open and is secondary to the
   region question above — both need to be clear before `terraform apply`
   is run against `dr-poc`.
4. Two `az` CLI commands referenced in `docs/dr-runbook.md` (Traffic
   Manager endpoint disable, PostgreSQL replica promotion) have unverified
   exact syntax — confirm against current documentation before relying on
   that runbook verbatim.

## Validation reference

See `docs/validation-checklist.md` for the itemized status of every
component (statically validated / locally validated / Azure validated /
not yet validated) — kept there as the single source of truth rather than
duplicated here.

## Architecture decisions

See `DECISIONS.md` for the full numbered log (AD-001 through AD-012), each
with the reasoning, alternatives considered, and the tradeoff accepted.
