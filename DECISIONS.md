# Architecture Decisions

This log records significant architecture decisions in chronological order. Each entry uses:
Decision / Reason / Alternatives / Tradeoff / Status.

Status values: `ASSUMPTION`, `VERIFIED (docs)`, `UNVERIFIED (needs Azure CLI check)`, `AZURE VALIDATED`.

---

## AD-001: Application scope

**Decision:** Build a small two-tier "Notes API" — a stateless REST API (CRUD on short text notes) backed by a stateful PostgreSQL database. Includes a `/healthz` liveness endpoint and a `/readyz` readiness endpoint (checks DB connectivity) for Kubernetes probes and Traffic Manager health checks.

**Reason:** No application spec was provided at project start. A two-tier CRUD service is the minimum shape that meaningfully exercises every layer this project is about: stateless pods that can run in two regions behind a load balancer, and a stateful database that needs real geo-replication and failover/promotion logic. It's small enough to implement, test, and containerize quickly, leaving the bulk of the effort for the actual DR infrastructure (the point of the project).

**Alternatives considered:** (a) no app at all, just deploy nginx placeholders — rejected because it can't demonstrate DB failover/data-loss (RPO) behavior, which is central to a DR project. (b) A more elaborate multi-service app — rejected as scope creep; adds implementation time without adding DR-architecture value.

**Tradeoff:** The app itself is not the deliverable; it exists to be deployable, testable, and to prove data survives a regional failover. Kept deliberately simple.

**Status:** Superseded — see the AD-001 addendum below. Left here for the historical record of the original reasoning.

**Tech stack:** Python 3.12 + FastAPI + SQLAlchemy + PostgreSQL driver (`psycopg`). Reason: FastAPI is lightweight, has built-in OpenAPI docs, async-friendly, and containerizes trivially.

---

## AD-002: Regions (original design — see AD-012)

**Decision:** Primary region = West Europe, Secondary/DR region = North Europe.

**Reason:** Both are long-established, full-feature Azure regions, geographically separated within the EU (data residency friendly), and both support every service this project needs: AKS, Azure Database for PostgreSQL Flexible Server, Azure Container Registry, Traffic Manager. Azure's own "paired regions" documentation lists these as a canonical pair, which simplifies reasoning about platform-level maintenance windows.

**Tradeoff:** West Europe/North Europe are geographically closer than e.g. West US/East US, so this is not protection against a truly continent-scale event — acceptable for a proof-of-concept.

**Status:** VERIFIED (docs) for general service availability. **Superseded in practice by AD-012**: on the subscription this project actually deploys to, both regions are confirmed to reject resource creation outright. This entry is kept for the original design reasoning; AD-012 is authoritative on which region to actually use.

---

## AD-003: Database — Azure Database for PostgreSQL Flexible Server

**Decision:** Use Azure Database for PostgreSQL Flexible Server, Burstable `B1ms` tier, with a cross-region read replica in the secondary region. On failover, the replica is promoted to a standalone read-write server.

**Reason:** Flexible Server supports cross-region read replicas natively (physical streaming replication), Terraform support (`azurerm_postgresql_flexible_server` + replica configuration) is mature, and Burstable tier is the cheapest compute tier suitable for a low-traffic workload.

**Alternatives considered:**
- **Azure SQL Database** — supports auto-failover groups (arguably simpler DR story) but higher baseline cost and introduces T-SQL/licensing considerations not needed here.
- **Azure Database for MySQL Flexible Server** — functionally similar geo-replication story to Postgres; Postgres chosen for richer ecosystem/extension support.

**Tradeoff:** Replication is asynchronous — expected RPO up to ~5 minutes under normal conditions, worse during a severe regional failure (replica lag at time of failure). Stated explicitly in the DR runbook rather than assumed away.

**Status:** VERIFIED (docs) — Microsoft Learn confirms cross-region read replicas, promotion to standalone, and the ~5 minute RPO expectation for Flexible Server.

**Production recommendation:** Use General Purpose or Memory Optimized tier for real production load (Burstable is not intended for sustained traffic), and consider Azure SQL auto-failover groups or a synchronous-replication design if RPO≈0 is a hard requirement — Postgres Flexible Server geo-replication cannot guarantee zero data loss.

---

## AD-004: Container Registry — single ACR, Basic tier, no geo-replication

**Decision:** One Azure Container Registry, Basic tier, hosted in the primary region. The secondary region's AKS cluster pulls images cross-region from the same registry.

**Reason:** ACR geo-replication (registry mirrored per region, in-region pulls) requires the **Premium** tier, which carries a fixed ~$50/month fee *per replicated region* on top of storage — not appropriate for this project's budget.

**Tradeoff:** Cross-region image pulls add latency to pod startup in the secondary region and incur cross-region data-transfer charges (small, since images are pulled infrequently, not per-request). An accepted, documented compromise, not a hidden one.

**Status:** VERIFIED (docs) — Microsoft Learn: "Geo-replication is only supported in Premium."

**Production recommendation:** Upgrade to Premium tier and enable geo-replication so each cluster pulls from a local, in-region registry replica.

---

## AD-005: AKS cluster tier and node sizing — vCPU quota constraint

**Decision:** Both AKS clusters use the **Free** control-plane tier (no SLA, $0/hour) with a single-node system pool sized `Standard_B2s` (2 vCPU / 4 GiB, burstable).

**Reason:** Free control-plane tier has no direct cost — only node VMs are billed. `Standard_B2s` is the smallest burstable size generally accepted for AKS system node pools.

**Constraint:** Free Trial and Azure-for-Students subscriptions carry a documented total vCPU quota cap that is not eligible for a self-service increase. Two clusters × one `B2s` node (2 vCPU) each = 4 vCPU total, which can consume the entire subscription-wide compute quota with little or no headroom for anything else.

**Alternatives considered:** Running only one AKS cluster and simulating the second region with a second node pool or namespace — rejected because it would not actually validate cross-region infrastructure (network, DNS, registry pull, DB replica), which is the point of a DR project.

**Status:** UNVERIFIED for this project's actual subscription — quota headroom needs confirming with `az vm list-usage --location <region> -o table` for whichever region AD-012 ultimately confirms works for AKS, before this Terraform environment is applied. **Secondary in priority to AD-012's region-restriction finding** — resolve that first.

**Production recommendation:** Standard control-plane tier (99.95% SLA) with multi-node pools (minimum 3 nodes for HA) sized to real workload requirements, not quota-constrained sizing.

---

## AD-006: Cross-region traffic management — Azure Traffic Manager

**Decision:** Azure Traffic Manager, Priority routing method, with the primary region's AKS ingress as priority 1 (active) and the secondary region's as priority 2 (passive/failover). Health checks probe `/healthz` on each endpoint.

**Reason:** Traffic Manager is a low-cost, DNS-level service (billed per DNS query + per monitored endpoint, no fixed premium fee), and its Priority routing method directly implements an active-passive DR pattern.

**Alternatives considered:** Azure Front Door (Standard/Premium) — faster failover (HTTP-layer, no DNS TTL wait) and adds WAF/edge TLS, but Premium tier carries meaningfully higher fixed monthly cost; rejected on cost grounds.

**Tradeoff:** Failover speed is bounded by DNS TTL — clients (and resolver caches) may keep hitting the failed primary for up to the TTL window after Traffic Manager marks it down. Measured and reported honestly as part of the RTO methodology, not assumed to be instant.

**Status:** VERIFIED (docs).

**Production recommendation:** Azure Front Door Premium for sub-second failover and integrated WAF, once budget allows.

---

## AD-007: DR pattern — active-passive with database replica promotion

**Decision:** Active-passive. The primary region serves 100% of production traffic in steady state. The secondary region runs a fully deployed, scaled-down copy of the app (Helm release applied, 1 replica) at all times, so failover is "promote and route," not "build from scratch." Database failover promotes the secondary region's read replica to standalone read-write, then repoints the app's connection string (via Kubernetes Secret + rolling restart, or external config) at the promoted server.

**Reason:** Active-active would require bidirectional/conflict-aware database replication, which Postgres Flexible Server's read-replica model does not provide — read replicas are read-only until promoted. Active-passive is the pattern the chosen database technology actually supports.

**Tradeoff:** Secondary region compute is paid for but idle in steady state (small cost, since it's a single burstable node). Promotion is a manual/scripted step, documented explicitly in the DR runbook as a deliberate, approved action — not an automated failover.

**Status:** VERIFIED (docs) — consistent with Flexible Server's documented promote-to-standalone DR operation.

---

## AD-008: DR test methodology — reversible simulation, not destruction

**Decision:** The DR test will: (1) mark the primary Traffic Manager endpoint disabled (not deleted) and/or scale the primary AKS deployment to 0 replicas, (2) observe failover to the secondary region, (3) measure time-to-recovery against the `/healthz` endpoint from an external prober, (4) restore by re-enabling the primary endpoint / scaling back up. At no point is the primary region's resource group, cluster, or database deleted.

**Reason:** Any DR test must be reversible and must not destroy the environment it's testing — see `docs/engineering-process.md`.

**Status:** Decision recorded; execution deferred until the multi-region environment is actually deployed, and requires explicit sign-off before running even though it is designed to be non-destructive.

---

## AD-009: IaC and CI/CD approach

**Decision:** Terraform for all Azure infrastructure (networking, AKS, PostgreSQL, ACR, Traffic Manager), organized as reusable modules under `terraform/modules/` with a thin `terraform/envs/` root module wiring them together with region as a variable. Helm chart for the application, deployed identically to both clusters via `helm upgrade --install`. GitHub Actions workflows for CI (lint/test/build/plan) using OIDC federated credentials (no stored client secret) — `terraform apply` and `helm upgrade` to real infrastructure gated behind a GitHub Environment requiring manual approval.

**Reason:** OIDC avoids storing any Azure credential as a GitHub secret. Manual-approval environments enforce the human-approval gate described in `docs/engineering-process.md` at the CI level, not only as a matter of local discipline.

**Status:** Decision recorded; implemented in `.github/workflows/cd.yml`.

---

## AD-001 addendum: application scope revised — "Notes API" replaced by "ResilientOps"

**Decision:** The original AD-001 application (a bare CRUD "Notes API") was reconsidered after review found it didn't represent a realistic system — too little real behavior to meaningfully exercise the infrastructure around it. It was fully replaced by **ResilientOps**, a service-health & incident tracker: `Service` and `Incident` resources, a severity/status workflow (`investigating → identified → monitoring → resolved`), a per-incident `IncidentUpdate` timeline, a derived `/status` summary endpoint (the same idea as a public status-page banner), shared-secret API-key auth on write endpoints, and Prometheus-format `/metrics`.

**Reason:** Thematically apt for a DR project (it's a tool for tracking outages, itself made resilient), and exercises real domain modeling (relationships, a state machine, derived computation) instead of flat CRUD, while remaining small enough to build and test quickly.

**Tradeoff:** More code than the original design; still not a full production incident-management tool (no pagination cursor stability guarantees, no rate limiting, no multi-tenant scoping) — appropriately scoped as the workload this infrastructure exists to run, not as the deliverable itself.

**Status:** LOCALLY VALIDATED — 17/17 tests pass (`app/tests/`). Tech stack (FastAPI + SQLAlchemy + PostgreSQL Flexible Server) is unchanged from the original AD-001 decision; only the application domain changed.

---

## AD-010: Frontend tier, and Azure Container Instances as a validation environment

**Decision:** Two related additions: (1) a genuine presentation tier — `frontend/`, static HTML/CSS/vanilla JS served by `nginx-unprivileged`, its own container/Dockerfile, calling the backend over HTTP with CORS enabled — making this a real three-tier architecture rather than an API with a docs page; and (2) a new, self-contained Terraform environment (`terraform/envs/aci-poc`) that deploys both tiers plus a single (non-replicated) PostgreSQL Flexible Server to a single Azure Container Instances group, as the fastest possible path to confirming the application actually runs and serves traffic in Azure, reachable from the outside world, before committing further effort to the multi-region AKS path.

**Reason:** Validating that the containers work correctly in Azure is cheaper and faster to prove via Container Instances than via the full AKS environment, and doing so is decoupled from the AKS vCPU-quota question (AD-005) that was already a blocker for that path. ACI's vCPU quota is a separate resource-provider quota family (`Microsoft.ContainerInstance`) from the AKS node pool's VM quota (`Microsoft.Compute`), so this environment sidesteps AD-005 entirely rather than needing it resolved first.

**Design choices specific to this environment, each a deliberate departure from the AKS path's equivalent choice:**
- **Both containers in one `azurerm_container_group`**, sharing one public IP, each on its own port (backend `:8000`, frontend `:8080`) — no ingress, no path-based routing, no TLS. Simplest possible topology for validation; not how the AKS path is or should be built.
- **ACR admin account enabled** (`admin_enabled = true`, a new variable added to `modules/acr`, defaulted to `false` so the AKS/`dr-poc` environment's existing managed-identity approach is unaffected) — Container Instances' support for pulling images via managed identity is more limited than AKS's `AcrPull` role-assignment pattern; admin credentials, passed as Terraform-managed secure environment variables, are the simpler, well-documented path for this specific, short-lived environment.
- **Single PostgreSQL server, no replica** — this environment doesn't exercise DR at all, only "does the app run correctly"; a replica would be pure cost with no purpose here.
- **The frontend's `FRONTEND_API_BASE_URL` is computed from the container group's predictable FQDN** (`<dns_name_label>.<location>.azurecontainer.io`) rather than waited-on as a `terraform output`, avoiding a circular dependency between the two containers in the same apply.

**Tradeoff:** None of this environment's choices are meant to carry forward into the AKS path — it is explicitly a disposable, deploy-then-destroy environment (Container Instances bill continuously while running; there's no scale-to-zero). Documented here so the ACR admin-account usage or the single-container-group topology are never mistaken for this project's actual production security/architecture position, which remains what AD-003 through AD-009 describe.

**Status:** AZURE VALIDATED — see AD-012 for the full deployment/validation/teardown record.

**Production recommendation:** N/A — there is no production recommendation for this environment because it isn't a production candidate. The production path for this workload is, and remains, `terraform/modules/aks`.

---

## AD-011: AKS multi-region DR path — paused, not abandoned

**Decision:** Work on `terraform/envs/dr-poc` (the two-region AKS/Traffic Manager/PostgreSQL-replica architecture from AD-002 through AD-009) was paused in favor of proving the application against real Azure infrastructure via the faster Container Instances path (AD-010) first. Nothing about the AKS design changed or was reconsidered — it remains statically validated, blocked only on AD-005's quota question and now also AD-012's region-restriction finding.

**Reason:** Sequencing, not a scope cut: validate the application works as a real Azure workload via the cheaper, faster, less-constrained path first, then return to the full DR architecture.

**Status:** `terraform/envs/dr-poc` and `helm/resilientops` have continued to be kept in sync with application changes (for example, the Helm chart's Deployment template was updated for the `API_KEY`/`ALLOWED_ORIGINS` environment variables at the same time this path was paused) so that resuming it later doesn't mean resuming it stale.

---

## AD-012: Subscription-level region restriction; Central India confirmed working; ACR Tasks disallowed; image builds moved to GitHub Actions

**Finding:** The Azure subscription this project deploys to ("Azure for Students", subscription `42ea2035-17b5-4e72-a2b7-e4426883fb2d`) rejects resource creation in a wide set of regions with `RequestDisallowedByAzure: ...This policy maintains a set of best available regions...`. Confirmed **blocked**, by direct testing against both ACR and PostgreSQL Flexible Server: West Europe, East US, Central US, South Central US, West US 2, Canada Central, North Europe, UK South, France Central, Sweden Central. Confirmed **working**: **Central India** — identified by checking the Azure Portal and finding a pre-existing virtual machine (`khalandar-VM`, resource group `khalandar-rg`) already running there, almost certainly the same host this project's development environment runs on.

Separately, **ACR Tasks (`az acr build`, cloud-hosted image builds) is also disallowed** on this subscription (`TasksOperationsNotAllowed`), independent of the region restriction. Combined with no local container runtime available in the development environment (Linux containers require WSL2/Hyper-V, which was not installed, as enabling it risks requiring a reboot of a shared machine), there was no available way to produce a container image locally or via Azure's own build service.

**Resolution:** `.github/workflows/build-images.yml` — a narrow, ungated workflow (no environment gate, no OIDC, no Terraform) that only builds and pushes both images, using a GitHub-hosted `ubuntu-latest` runner (which has Docker built in) authenticated to the ACR via its admin credentials. Deliberately simpler than `cd.yml`/`aci.yml`'s OIDC-gated pattern, because this workflow never touches Azure infrastructure — the only reason it needs an Azure-adjacent credential at all is to push to the registry.

**Why this matters going forward:** any future work on this subscription should default to **Central India**, not the regions named in this project's earlier design documentation (West Europe/North Europe throughout `dr-poc`; West Europe/East US as first attempted for `aci-poc`). Those regions are not merely suboptimal — they are confirmed to fail outright on this subscription. The AKS architecture in `dr-poc`, if resumed, will very likely hit the same restriction (untested for AKS/VM resources specifically, but the pattern — a subscription-wide allow-list — makes it likely rather than merely possible) and may require filing an Azure Support ticket (as the error message itself directs) to expand the allowed-region list before that path is viable.

**Tradeoff:** ACR admin credentials exist as a GitHub Actions secret (`ACI_ACR_ADMIN_PASSWORD`), consistent with AD-010's existing choice to enable ACR admin access for this registry. The registry (and thus this credential's validity) no longer exists following the teardown described below; removing the now-unused secret/variables was considered and deferred.

**Status:** AZURE VALIDATED. The full stack was deployed for real to Central India — resource group, ACR, PostgreSQL Flexible Server, and a running container group — and confirmed reachable and correct from *outside* Azure (a direct request to the public endpoint returned a live, correct API response). This is the strongest validation this project has produced. The environment was then destroyed in full (`terraform destroy`), and its removal was confirmed (`az group exists` → `false`).

**Production recommendation:** N/A for the ACI environment itself (per AD-010, never a production target). For the AKS path: before investing further Terraform/Helm work in `dr-poc`, verify that Central India (or whatever region a support ticket ultimately unlocks) actually supports AKS, the `Standard_B2s` VM size, and PostgreSQL Flexible Server together, and update AD-002 accordingly — West Europe/North Europe should no longer be treated as merely "a design choice with tradeoffs"; on this subscription, they are presently non-functional.
