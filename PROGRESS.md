# Progress

## Current phase
Direction changed twice after the original 10-phase AKS/DR pass (see
`DECISIONS.md` AD-001 addendum, AD-010, AD-011). Current focus: prove the
ResilientOps app works as a real Azure workload via the fast, cheap path
(Azure Container Instances) before returning to the full AKS multi-region
DR build, which is parked, not abandoned.

- **AKS multi-region DR (Phases 1-10, original scope)** — parked. Terraform/Helm
  for `envs/dr-poc` still exist and still validate, but are not the active
  work. Blocked on AD-005 (Free Trial vCPU quota) regardless.
- **App rewrite** — complete. The original "Notes API" was replaced with
  **ResilientOps**, a service-health & incident tracker (see AD-001 addendum
  below). 17/17 tests pass.
- **Frontend tier added** — complete, locally validated. `frontend/` is a
  static HTML/CSS/vanilla-JS presentation tier (nginx, its own Dockerfile,
  its own deployable unit) — this is what makes the app a genuine 3-tier
  architecture (presentation / application / data) rather than an API with
  a docs page. Confirmed working end-to-end against the real backend API in
  this session, including the write path (API-key gate, status transition,
  live timeline update).
- **Azure Container Instances smoke-test environment** — complete, statically
  validated (`terraform fmt`/`validate`, `helm` n/a here). NOT YET deployed to
  real Azure. This is the active near-term goal: deploy both tiers + a real
  PostgreSQL Flexible Server (PaaS) to ACI via `.github/workflows/aci.yml`,
  then test the public URL from outside Azure entirely.

## Completed work

### App rewrite: ResilientOps (supersedes the original "Notes API")
- Rejected as too basic by the user; rebuilt as a service-health & incident
  tracker: Services, Incidents (severity + status workflow), per-incident
  timeline of Updates, a derived `/status` summary endpoint, API-key auth on
  writes, Prometheus-format `/metrics`, router-per-resource structure.
- `app/src/resilientops/` (was `app/src/notes_api/` - fully replaced, old
  package deleted).
- 17/17 tests pass (`app/tests/`), including auth-gate and status-transition
  behavior, not just CRUD happy paths.
- CORS added (`ALLOWED_ORIGINS` env var) so the new frontend tier can call it
  from a browser.

### Frontend tier (`frontend/`)
- `public/index.html` + `styles.css` + `app.js` (vanilla, no build step) +
  `config.js`/`config.template.js` (the same image is used in both regions;
  `docker-entrypoint.sh` renders the real API URL into `config.js` at
  container start via `envsubst`, keyed off `FRONTEND_API_BASE_URL`).
- `Dockerfile`: `nginxinc/nginx-unprivileged:1.27-alpine`, non-root, port
  8080, `/healthz` endpoint, `nginx.conf` with `no-store` on `config.js`.
- **LOCALLY VALIDATED in this session**: ran the real backend (uvicorn,
  SQLite) and the frontend (`python -m http.server`) side by side, seeded
  realistic sample data, confirmed via the Browser tool: dashboard renders
  live API data, derived status pill matches incident severity, the API-key
  dialog correctly gates writes, and a `PATCH` status transition + new
  timeline entry round-trips through the real API and re-renders.
- NOT YET containerized/build-tested (no Docker in this environment - same
  constraint as the backend's Dockerfile).

### Azure Container Instances path (`terraform/modules/aci`, `terraform/envs/aci-poc`)
- New, self-contained Terraform environment - its own resource group, its
  own ACR, its own single-instance PostgreSQL Flexible Server (no replica;
  this isn't the DR architecture, see AD-011). Deliberately decoupled from
  `envs/dr-poc` so it doesn't wait on the AKS vCPU-quota question.
- One `azurerm_container_group` running both tiers behind one public IP:
  backend on port 8000, frontend on port 8080 (both externally reachable at
  `<dns-label>.<region>.azurecontainer.io:<port>` - see AD-010 for why no
  port 80/reverse proxy).
- ACR admin credentials used for image pulls (AD-010) - a different,
  simpler tradeoff than the AKS path's managed-identity `AcrPull`, and
  explicitly not the pattern to carry into AKS.
- `.github/workflows/aci.yml`: `plan-only` / `apply` / `destroy`, same
  OIDC + environment-approval gating as `cd.yml`. `apply` also builds and
  pushes both images first.
- **STATICALLY VALIDATED**: `terraform fmt -check`, `terraform init
  -backend=false`, `terraform validate` all pass. Also re-validated
  `envs/dr-poc` after a shared-module change (adding `admin_enabled` to
  `modules/acr`) - still passes.
- **NOT YET VALIDATED**: nothing has been applied to Azure. `az login` has
  not been completed in this environment (see Current blockers).

### Housekeeping done while in the area
- Renamed `helm/notes-api/` -> `helm/resilientops/` (chart name, template
  helper names, container name, Secret name, image repository references)
  - this chart still deploys the backend tier only; the frontend tier has
  no Helm template yet (noted directly in the chart's `values.yaml`).
  Re-validated: `helm lint` clean, `helm template` renders correctly.
  - Also added `API_KEY` and `ALLOWED_ORIGINS` to the Deployment template,
  which the original chart predated (written before the app had auth/CORS).
- Fixed every other stale `notes-api`/`notes_api` reference this rename
  touched: `ci.yml`, `cd.yml`, `README.md`, and the `docs/` files that
  named it directly (`security.md`, `dr-runbook.md`, `architecture.md`,
  `troubleshooting.md`, `validation-checklist.md`).
- `ci.yml` now builds both images (backend + frontend) and validates both
  Terraform environments (`dr-poc` and `aci-poc`) via a matrix.

## Unexpected state found this session — flagged, not resolved
`app/src/order_api/` exists on disk and is **not** something built in this
conversation. Its contents are a near-verbatim copy of the *original*
"Notes API" code (pre-ResilientOps), oddly renamed. `git status` detects it
as a rename target for the deleted `notes_api/*` files, which is how it was
noticed. Best working theory: leftover from an earlier Claude Code process
on this machine that was interrupted (a background-task notification
earlier in this session referenced "no completion record... may have been
running when the previous Claude Code process exited"). It has been left
untouched and is deliberately excluded from every commit made this session
- flagged to the user directly rather than deleted or silently absorbed.
**Needs a decision: delete it, or is it something else's in-progress work?**

## Current blockers (in order of what to resolve first)
1. **`app/src/order_api/` needs a decision** — see above.
2. **The ACI path needs the GitHub OIDC/environment setup done before `aci.yml` can actually run** — `docs/github-oidc-setup.md` now also needs `ACI_ACR_NAME`/`ACI_ACR_LOGIN_SERVER` variables and `ACI_POSTGRES_ADMIN_PASSWORD`/`ACI_BACKEND_API_KEY` secrets added for this specific environment (not yet written into that doc - see Next steps).
3. **AD-005's AKS vCPU quota risk remains unresolved and out of scope for now** — parked along with the rest of the AKS path.
4. Docker is not installed in this execution environment, so neither Dockerfile has been build-tested end-to-end here.

## Git status
Commits `f1ad880` and `c9f28a8` pushed to `origin/main` on 2026-09-05 (the
original AKS/DR POC). This session's changes (app rewrite, frontend tier,
ACI environment, Helm rename) are **not yet committed** - awaiting the
`order_api` decision above before staging, so that decision doesn't get
made implicitly by what a broad `git add` happens to sweep in.

## Next steps
1. Resolve the `order_api` question, then commit this session's work
   (targeted `git add`, not `-A`, until that's resolved).
2. Add the ACI-specific variables/secrets section to `docs/github-oidc-setup.md`.
3. Complete that OIDC/environment setup, then run `aci.yml` with
   `plan-only`, review, then `apply` with explicit sign-off.
4. Test the deployed frontend URL from outside Azure; report back before
   deciding whether to resume the AKS path.
5. `aci.yml` → `destroy` once done testing, to stop the continuous billing
   (ACI has no scale-to-zero for a running container group).

## Important architectural decisions
See `DECISIONS.md` (AD-001 through AD-011, including the AD-001 addendum
recording the app-scope rejection and rewrite).

## Azure assumptions requiring verification
- Actual current vCPU quota for this subscription in West Europe and North Europe (AD-005) - still relevant only if/when the AKS path resumes.
- PostgreSQL Flexible Server Burstable `B1ms` SKU availability in West Europe (AD-003/AD-011).
- All cost figures in `docs/cost-analysis.md` - gathered from general web research; does not yet include ACI's own per-second billing model.
- Exact `az` CLI syntax for Traffic Manager endpoint disable and PostgreSQL replica promotion (`docs/dr-runbook.md`) - AKS-path-specific, irrelevant to the current ACI focus.

## Tooling installed this session (local dev machine only, not Azure)
Unchanged from before: `python312`, `python314` (unused), `terraform`, `kubernetes-cli`, `kubernetes-helm`, `azure-cli` (installed, never authenticated), `yamllint` (pip, into the `python312` install). Docker still deliberately not installed.
