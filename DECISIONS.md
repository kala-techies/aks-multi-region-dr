# Architecture Decisions

This log records significant architecture decisions in chronological order. Each entry uses:
Decision / Reason / Alternatives / Tradeoff / Status.

Status values: `ASSUMPTION (needs user confirmation)`, `VERIFIED (docs)`, `UNVERIFIED (needs Azure CLI check)`.

---

## AD-001: Demo application scope

**Decision:** Build a small two-tier "Notes API" — a stateless REST API (CRUD on short text notes) backed by a stateful PostgreSQL database. Includes a `/healthz` liveness endpoint and a `/readyz` readiness endpoint (checks DB connectivity) for Kubernetes probes and Traffic Manager health checks.

**Reason:** No application spec was provided. A two-tier CRUD service is the minimum shape that meaningfully exercises every layer this project is about: stateless pods that can run in two regions behind a load balancer, and a stateful database that needs real geo-replication and failover/promotion logic. It's small enough to implement, test, and containerize quickly, leaving the bulk of the effort for the actual DR infrastructure (the point of the project).

**Alternatives considered:** (a) no app at all, just deploy nginx placeholders — rejected because it can't demonstrate DB failover/data-loss (RPO) behavior, which is central to a DR project. (b) A more elaborate multi-service app — rejected as scope creep; adds implementation time without adding DR-architecture value.

**Tradeoff:** The app itself is not the deliverable; it exists to be deployable, testable, and to prove data survives a regional failover. Kept deliberately simple.

**Status:** ASSUMPTION (needs user confirmation) — flag to user: if a specific application/tech stack was expected (e.g. for a course rubric), replace this.

**Tech stack:** Python 3.12 + FastAPI + SQLAlchemy + PostgreSQL driver (`psycopg`). Reason: FastAPI is lightweight, has built-in OpenAPI docs (useful for demoing/grading), async-friendly, and containerizes trivially. No frontend — API-only, exercised via `curl`/tests/Swagger UI.

---

## AD-002: Regions

**Decision:** Primary region = West Europe, Secondary/DR region = North Europe.

**Reason:** Both are long-established, full-feature Azure regions (not newer/limited ones), geographically separated within the EU (data residency friendly), and both support every service this project needs: AKS, Azure Database for PostgreSQL Flexible Server, Azure Container Registry, Traffic Manager. This pairing was also named explicitly in the original project brief.

**Alternatives considered:** Azure "paired regions" list still shows West Europe/North Europe as a canonical pair, which simplifies reasoning about platform-level maintenance windows.

**Tradeoff:** West Europe/North Europe are geographically closer than e.g. West US/East US, so this is not protection against a truly continent-scale event — acceptable for a POC/demo.

**Status:** VERIFIED (docs) for general service availability of AKS/PostgreSQL Flexible Server/ACR/Traffic Manager in both regions. UNVERIFIED for specific VM SKU and quota availability at deploy time — run `az vm list-skus -l westeurope -o table` / `-l northeurope` and `az postgres flexible-server list-skus -l <region>` once Azure credentials are available, before Phase 4 apply.

---

## AD-003: Database — Azure Database for PostgreSQL Flexible Server

**Decision:** Use Azure Database for PostgreSQL Flexible Server, Burstable `B1ms` tier, with a cross-region read replica in North Europe. On failover, the replica is promoted to a standalone read-write server.

**Reason:** Flexible Server supports cross-region read replicas natively (physical streaming replication), Terraform support (`azurerm_postgresql_flexible_server` + `azurerm_postgresql_flexible_server` replica configuration) is mature, and Burstable tier is the cheapest compute tier suitable for a low-traffic demo.

**Alternatives considered:**
- **Azure SQL Database** — supports auto-failover groups (arguably simpler DR story) but higher baseline cost and introduces T-SQL/licensing considerations not needed here.
- **Azure Database for MySQL Flexible Server** — functionally similar geo-replication story to Postgres; Postgres chosen for richer ecosystem/extension support and because it was used as the worked example in the project's own decision-log template.

**Tradeoff:** Replication is asynchronous — expected RPO up to ~5 minutes under normal conditions, worse during a severe regional failure (replica lag at time of failure). This must be stated honestly in the DR runbook, not glossed over.

**Status:** VERIFIED (docs) — Microsoft Learn confirms cross-region read replicas, promotion to standalone, and the ~5 minute RPO expectation for Flexible Server. UNVERIFIED — exact Burstable SKU availability/pricing in North Europe at deploy time.

**Production recommendation:** For a real production DR target, use General Purpose or Memory Optimized tier (Burstable is not intended for sustained production load), and consider Azure SQL auto-failover groups or a synchronous-replication design if RPO≈0 is a hard requirement — Postgres Flexible Server geo-replication cannot guarantee zero data loss.

---

## AD-004: Container Registry — single ACR, Basic tier, no geo-replication

**Decision:** One Azure Container Registry, Basic tier, hosted in West Europe. The North Europe AKS cluster pulls images cross-region from the same registry.

**Reason:** ACR geo-replication (registry mirrored per region, in-region pulls) requires the **Premium** tier, which carries a fixed ~$50/month fee *per replicated region* on top of storage — not appropriate for an Azure Free Trial budget for a POC.

**Alternatives considered:** Premium ACR with geo-replication — the correct production answer, rejected here purely on cost grounds (AD project rule: treat cost as a first-class constraint on Free Trial).

**Tradeoff:** Cross-region image pulls add latency to pod startup in the secondary region and incur cross-region data-transfer charges (small, since images are pulled infrequently, not per-request). This is an accepted POC compromise, not a hidden one.

**Status:** VERIFIED (docs) — Microsoft Learn: "Geo-replication is only supported in Premium."

**Production recommendation:** Upgrade to Premium tier and enable geo-replication to North Europe so each cluster pulls from a local, in-region registry replica.

---

## AD-005: AKS cluster tier and node sizing — Free Trial vCPU constraint

**Decision:** Both AKS clusters use the **Free** control-plane tier (no SLA, $0/hour) with a single-node system pool sized `Standard_B2s` (2 vCPU / 4 GiB, burstable).

**Reason:** Free control-plane tier has no direct cost — only node VMs are billed. `Standard_B2s` is the smallest burstable size generally accepted for AKS system node pools.

**Critical constraint — flagged, not hidden:** Azure Free Trial subscriptions carry a **documented 4 total vCPU quota cap that is NOT eligible for increase** (Free Trial/Azure-for-Students subscriptions are explicitly excluded from quota-increase requests per Microsoft Learn/Q&A). Two clusters × one `B2s` node (2 vCPU) each = **4 vCPU total**, which already consumes the entire subscription-wide compute quota with **zero headroom** for anything else (a jump box, a CI runner VM, scaling either cluster beyond 1 node, etc.).

**Alternatives considered:** Running only one AKS cluster and simulating the second region with a second node pool or namespace — rejected because it would not actually validate cross-region infrastructure (network, DNS, registry pull, DB replica) which is the point of a DR project.

**Tradeoff / Status:** UNVERIFIED — the exact current quota for this specific subscription cannot be checked from this environment (Azure CLI is not installed/authenticated here). **Action required before Phase 4 (Terraform) is applied:** run `az vm list-usage --location westeurope -o table` and the same for `northeurope` to confirm actual headroom. If the true quota is 4 vCPU total as documented, this architecture is only barely feasible (exactly at the limit) and has no room for error — the practical fallback is to request a one-time quota increase (may require upgrading off Free Trial to Pay-As-You-Go, since Free Trial itself cannot request increases) before Phase 4.

**Production recommendation:** Standard control-plane tier (99.95% SLA) with multi-node pools (minimum 3 nodes for HA) sized to real workload requirements — not vCPU-quota-constrained sizing.

---

## AD-006: Cross-region traffic management — Azure Traffic Manager

**Decision:** Azure Traffic Manager, Priority routing method, with the West Europe AKS ingress as priority 1 (active) and North Europe AKS ingress as priority 2 (passive/failover). Health checks probe `/healthz` on each endpoint.

**Reason:** Traffic Manager is a low-cost, DNS-level service (billed per DNS query + per monitored endpoint, no fixed premium fee), appropriate for a Free Trial budget, and its Priority routing method directly implements an active-passive DR pattern.

**Alternatives considered:** Azure Front Door (Standard/Premium) — faster failover (HTTP-layer, no DNS TTL wait) and adds WAF/edge TLS, but Premium tier carries meaningfully higher fixed monthly cost; rejected for the POC on cost grounds.

**Tradeoff:** Failover speed is bounded by DNS TTL — clients (and resolver caches) may keep hitting the failed primary for up to the TTL window after Traffic Manager marks it down. This will be measured and reported honestly as part of the RTO methodology (Phase 9), not assumed to be instant.

**Status:** VERIFIED (docs).

**Production recommendation:** Azure Front Door Premium for sub-second failover and integrated WAF, once budget allows.

---

## AD-007: DR pattern — active-passive with database replica promotion

**Decision:** Active-passive. Primary (West Europe) serves 100% of production traffic in steady state. Secondary (North Europe) runs a fully deployed, scaled-down copy of the app (Helm release applied, 1 replica) at all times, so failover is "promote and route," not "build from scratch." Database failover = promote the North Europe read replica to standalone read-write, then repoint the app's connection string (via Kubernetes Secret + rolling restart, or external config) at the promoted server.

**Reason:** Active-active would require bidirectional/conflict-aware database replication, which Postgres Flexible Server's read-replica model does not provide — read replicas are read-only until promoted. Active-passive is the pattern the chosen database technology actually supports.

**Tradeoff:** Secondary region compute is paid for but idle in steady state (small cost, since it's a single burstable node). Promotion is a manual/scripted step, not automatic — documented explicitly in the DR runbook (Phase 8) as a deliberate, approved action per this project's human-approval-gate rule, not an automated failover.

**Status:** VERIFIED (docs) — consistent with Flexible Server's documented promote-to-standalone DR operation.

---

## AD-008: DR test methodology — reversible simulation, not destruction

**Decision:** The DR "game day" test (Phase 9) will: (1) mark the primary Traffic Manager endpoint disabled (not deleted) and/or scale the primary AKS deployment to 0 replicas, (2) observe failover to North Europe, (3) measure time-to-recovery against the `/healthz` endpoint from an external prober, (4) restore by re-enabling the primary endpoint / scaling back up. At no point is the West Europe resource group, cluster, or database deleted.

**Reason:** Required by project rule 19 (DR Test Safety) — the test must be reversible and must not destroy the primary environment.

**Status:** Decision recorded; execution deferred to Phase 9 and requires explicit human approval per rule 18 before running, even though it is non-destructive.

---

## AD-009: IaC and CI/CD approach

**Decision:** Terraform for all Azure infrastructure (networking, AKS, PostgreSQL, ACR, Traffic Manager), organized as reusable modules under `terraform/modules/` with a thin `terraform/envs/` root module wiring them together with region as a variable (deployed twice: once per region, plus one shared/global root for Traffic Manager and cross-region wiring). Helm chart for the application, deployed identically to both clusters via `helm upgrade --install`. GitHub Actions workflows for CI (lint/test/build/plan) using OIDC federated credentials (`azure/login` with `client-id`/`tenant-id`/`subscription-id`, no stored client secret) — `terraform apply` and `helm upgrade` to real infrastructure gated behind a GitHub Environment requiring manual approval.

**Reason:** OIDC avoids storing any Azure credential as a GitHub secret (project rule 5). Manual-approval environments satisfy the human-approval-gate rule (rule 18) at the CI level, not just in this chat.

**Status:** Decision recorded; implementation in Phases 4–6.

---

## AD-001 addendum: application scope revised — "Notes API" replaced by "ResilientOps"

**Decision:** The original AD-001 app (a bare CRUD "Notes API") was rejected by the user as "looking basic" — not representative of a real system. It was fully replaced by **ResilientOps**, a service-health & incident tracker: `Service` and `Incident` resources, a severity/status workflow (`investigating → identified → monitoring → resolved`), a per-incident `IncidentUpdate` timeline, a derived `/status` summary endpoint (the same idea as a public status-page banner), shared-secret API-key auth on write endpoints, and Prometheus-format `/metrics`.

**Reason:** Thematically apt for a DR project (it's a tool for tracking outages, itself made resilient), and exercises real domain modeling (relationships, a state machine, derived computation) instead of flat CRUD — while remaining small enough to build and test in one session.

**Tradeoff:** More code than the original design; still not a "real" production incident-management tool (no pagination cursor stability guarantees, no rate limiting, no multi-tenant scoping) — appropriately scoped for a demo workload, not a rewrite of PagerDuty.

**Status:** LOCALLY VALIDATED — 17/17 tests pass (`app/tests/`). Supersedes AD-001's tech-stack assumption only insofar as the domain changed; FastAPI + SQLAlchemy + PostgreSQL Flexible Server stays as originally decided.

---

## AD-010: Frontend tier, and Azure Container Instances as a smoke-test environment

**Decision:** Two related additions, requested together: (1) a genuine presentation tier — `frontend/`, static HTML/CSS/vanilla JS served by `nginx-unprivileged`, its own container/Dockerfile, calling the backend over HTTP with CORS enabled — making this a real 3-tier architecture rather than an API with a docs page; and (2) a new, self-contained Terraform environment (`terraform/envs/aci-poc`) that deploys both tiers plus a single (non-replicated) PostgreSQL Flexible Server to a single Azure Container Instances group, as the fastest possible path to answering "does this image actually run and serve traffic in Azure, reachable from the outside world" — before committing further effort to the AKS multi-region path.

**Reason:** The user's own framing: "an image is an image if it runs on the Azure Container Instance or anywhere" — i.e., prove the containers work in Azure cheaply and quickly, decoupled from the AKS vCPU-quota question (AD-005) that was already blocking that path. ACI's vCPU quota is a separate resource-provider quota family (`Microsoft.ContainerInstance`) from the AKS node pool's VM quota (`Microsoft.Compute`), so this environment sidesteps AD-005 entirely rather than needing it resolved first.

**Design choices specific to this environment, each a deliberate departure from the AKS path's equivalent choice:**
- **Both containers in one `azurerm_container_group`**, sharing one public IP, each on its own port (backend `:8000`, frontend `:8080`) — no ingress, no path-based routing, no TLS. Simplest possible topology for a smoke test; not how the AKS path is or should be built.
- **ACR admin account enabled** (`admin_enabled = true`, a new variable added to `modules/acr`, defaulted to `false` so the AKS/`dr-poc` environment's existing managed-identity approach is unaffected) — Container Instances' support for pulling images via managed identity is more limited/newer than AKS's `AcrPull` role-assignment pattern; admin credentials, passed as Terraform-managed secure environment variables, are the simpler, well-documented path for this specific, short-lived rig.
- **Single PostgreSQL server, no replica** — this environment is not exercising DR at all, just "does the app run"; a replica would be pure cost with no purpose here.
- **The frontend's `FRONTEND_API_BASE_URL` is computed from the container group's predictable FQDN** (`<dns_name_label>.<location>.azurecontainer.io`) rather than waited-on as a `terraform output`, avoiding a circular dependency between the two containers in the same apply.

**Tradeoff:** None of this environment's choices are meant to carry forward into the AKS path — it is explicitly a disposable, run-then-`destroy` rig (ACI bills continuously while the container group exists; there's no scale-to-zero). Documented here so nobody mistakes ACR admin-account usage or the single-container-group topology for this project's actual security/architecture position, which remains what AD-003 through AD-009 already describe.

**Status:** STATICALLY VALIDATED (`terraform fmt`, `terraform validate`). NOT YET AZURE VALIDATED — nothing has been applied.

**Production recommendation:** N/A — there is no production recommendation for this environment because it isn't a production candidate. The production path for this workload is, and remains, `terraform/modules/aks`.

---

## AD-011: AKS multi-region DR path — parked, not abandoned

**Decision:** Work on `terraform/envs/dr-poc` (the two-region AKS/Traffic Manager/PostgreSQL-replica architecture from AD-002 through AD-009) is paused while the ACI smoke-test path (AD-010) is pursued instead. Nothing about the AKS design has changed or been reconsidered — it remains statically validated and unblocked except for AD-005's vCPU-quota question.

**Reason:** User direction: prove the application works as a real Azure workload via the cheaper, faster, quota-unconstrained path first; return to the full DR architecture afterward. This is a sequencing decision, not a scope cut.

**Status:** `terraform/envs/dr-poc` and `helm/resilientops` continue to be kept in sync with app changes (e.g., the Helm chart's Deployment template was updated for the new `API_KEY`/`ALLOWED_ORIGINS` env vars in the same session this was parked) so that resuming it later doesn't mean resuming it *stale*.

---

## AD-012: Subscription-level region restriction discovered; Central India confirmed working; ACR Tasks disallowed; image builds moved to GitHub Actions

**Decision/finding:** This project's actual Azure subscription ("Azure for Students", `42ea2035-17b5-4e72-a2b7-e4426883fb2d`) rejects resource creation in a wide set of regions with `RequestDisallowedByAzure: ...This policy maintains a set of best available regions...`. Confirmed **blocked**: West Europe, East US, Central US, South Central US, West US 2, Canada Central, North Europe, UK South, France Central, Sweden Central (tested against both ACR and PostgreSQL Flexible Server). Confirmed **working**: **Central India** — discovered by checking the Azure Portal for a verification prompt (per project rule 14, don't guess) and finding a pre-existing VM (`khalandar-VM`, resource group `khalandar-rg`) already running there, almost certainly the very machine this project's sessions run on.

Separately, **ACR Tasks (`az acr build`, cloud-hosted image builds) is also disallowed** on this subscription/registry (`TasksOperationsNotAllowed`), independent of the region restriction. Combined with no local Docker (this Windows Server machine can't run Linux containers without WSL2/Hyper-V, not installed — a reboot-risking change no one has approved), there was no available way to produce a container image from this machine or via Azure's own build service.

**Resolution:** `.github/workflows/build-images.yml` — a narrow, ungated workflow (no `environment:` gate, no OIDC, no Terraform) that only builds and pushes both images, using a GitHub-hosted `ubuntu-latest` runner (real Docker, zero local dependency) authenticated to the ACR via its admin credentials (`docker/login-action` with `ACI_ACR_LOGIN_SERVER`/`ACI_ACR_ADMIN_USERNAME`/`ACI_ACR_ADMIN_PASSWORD` variables/secret). Deliberately simpler than `cd.yml`/`aci.yml`'s OIDC-gated pattern because this workflow never touches Azure infrastructure — only reason it needs any Azure credential at all is to push to the registry.

**Reason it's a real decision, not just a workaround:** every future session working on this subscription should default to **Central India**, not the regions named in this project's own earlier documentation (`westeurope`/`northeurope` throughout `dr-poc`, or `westeurope`/`eastus` as first tried for `aci-poc`). Those regions are not hypothetically suboptimal — they are **confirmed to fail outright** on this specific subscription. `envs/dr-poc`'s AKS architecture, if resumed, will very likely hit the same restriction (untested for AKS/VM resources specifically, but the pattern — a subscription-wide "best available regions" allow-list — makes it likely rather than merely possible) and may require the user to file an Azure Support ticket (the error message itself directs this) to expand the allowed region list before that path is viable again.

**Tradeoff:** ACR admin credentials now exist as a plain GitHub Actions secret (`ACI_ACR_ADMIN_PASSWORD`). This is consistent with AD-010's existing choice to enable ACR admin access for this specific registry — not a new pattern, just a second consumer of the same credential. The registry (and thus this credential's validity) no longer exists as of this session's teardown; the user was offered removal of the now-dead secret/variables and declined, choosing to leave them in place.

**Status:** AZURE VALIDATED — this is the strongest validation this project has produced: real resources were created (resource group, ACR, PostgreSQL Flexible Server, container group), the application was confirmed reachable and correct from *outside* Azure (`curl` from this session returned real API responses), and everything was then destroyed cleanly on explicit instruction (`terraform destroy`, confirmed via `az group exists` → `false`).

**Production recommendation:** N/A for the ACI environment itself (per AD-010, it was never meant to be a production target). For the AKS path: before investing further Terraform/Helm work in `dr-poc`, verify Central India (or whatever region a support ticket ultimately unlocks) actually supports AKS + the `Standard_B2s` VM size + PostgreSQL Flexible Server together, and update AD-002 (regions) accordingly — don't assume West Europe/North Europe are merely "a POC choice with tradeoffs" anymore; on this subscription, they are presently non-functional.
