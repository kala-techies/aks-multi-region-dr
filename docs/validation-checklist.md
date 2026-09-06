# Validation checklist

Status legend: `STATICALLY VALIDATED` / `LOCALLY VALIDATED` / `AZURE
VALIDATED` / `NOT YET VALIDATED` — see `docs/engineering-process.md`.
Nothing below is marked done unless it was actually run and its output
observed and recorded in this repo's history (`PROGRESS.md`, `DECISIONS.md`).

## Application
- [x] LOCALLY VALIDATED — `pytest` in `app/`: 17/17 tests pass (services, incidents, status derivation, API-key auth gate, 404s, validation).
- [ ] NOT YET VALIDATED — load/performance testing (not planned at this scale).

## Frontend
- [x] LOCALLY VALIDATED — dashboard confirmed rendering live API data, correct status-pill derivation, working API-key gate, and a full write round-trip (status transition + new timeline entry) against the real backend.
- [ ] NOT YET VALIDATED — automated UI tests (none written; manual verification only so far).

## Container images
- [x] STATICALLY VALIDATED — both Dockerfiles manually reviewed (non-root users, `HEALTHCHECK`s, `.dockerignore`, slim/minimal base images).
- [x] AZURE VALIDATED — both images built and pushed successfully via `.github/workflows/build-images.yml` (GitHub-hosted runner; local Docker was never required).

## Terraform — `envs/dr-poc` (AKS multi-region)
- [x] STATICALLY VALIDATED — `terraform fmt -check -recursive` clean; `terraform validate` succeeds.
- [ ] NOT YET VALIDATED — `terraform plan`/`apply` against a real subscription. Blocked on the region restriction and quota question in `DECISIONS.md` AD-005/AD-012.

## Terraform — `envs/aci-poc` (Container Instances validation path)
- [x] STATICALLY VALIDATED — `terraform fmt -check`, `terraform validate` clean.
- [x] AZURE VALIDATED — applied for real to Central India: resource group, ACR, PostgreSQL Flexible Server, and a running container group. Confirmed reachable and correct from outside Azure via direct HTTP requests. Subsequently destroyed in full; removal confirmed (`az group exists` → `false`). Full record in `DECISIONS.md` AD-012.

## Helm
- [x] LOCALLY VALIDATED — `helm lint helm/resilientops` → 0 charts failed.
- [x] LOCALLY VALIDATED — `helm template` renders correctly with default values and with the per-region overlay + static-IP annotation.
- [ ] NOT YET VALIDATED — `helm upgrade --install` against a real AKS cluster (requires `envs/dr-poc` to be applied first).

## GitHub Actions
- [x] STATICALLY VALIDATED — `yamllint` clean on every workflow file.
- [x] AZURE VALIDATED — `build-images.yml` has run successfully in GitHub Actions (not merely reviewed locally).
- [ ] NOT YET VALIDATED — `cd.yml` (AKS path) — requires the one-time OIDC/environment setup in `docs/github-oidc-setup.md`.
- [ ] NOT YET VALIDATED — `aci.yml`'s own `apply`/`destroy` jobs — the `aci-poc` deployment recorded in `DECISIONS.md` AD-012 used direct `terraform` commands rather than this workflow; the workflow itself remains unexercised end-to-end.

## Security
- [x] Reviewed — see `docs/security.md` for the full table of current-state vs. production-recommended findings. No automated security scanning (SAST/dependency-scan) has been run yet.

## Disaster recovery
- [x] Documented — `docs/dr-runbook.md` (failover + failback procedures) and `DECISIONS.md` AD-007/AD-008.
- [ ] NOT YET VALIDATED — no failover test has been executed against real infrastructure yet (requires `envs/dr-poc` to be deployed first). See `docs/rto-rpo-methodology.md`.

## Documentation
- [x] `docs/architecture.md`, `docs/cost-analysis.md`, `docs/security.md`, `docs/dr-runbook.md`, `docs/rto-rpo-methodology.md`, `docs/troubleshooting.md`, `docs/production-hardening.md`, `docs/github-oidc-setup.md`, `docs/engineering-process.md`, this file, `README.md`, `PROGRESS.md`, `DECISIONS.md`.

## Evidence checklist (for the eventual multi-region deployment)
- [ ] `az vm list-usage` output showing available quota, for whichever region AD-012's follow-up confirms works for AKS
- [ ] `terraform plan` output against the real subscription
- [ ] `terraform apply` output / Azure Portal resource list after apply
- [ ] `kubectl get pods -A` for both clusters showing Running pods
- [ ] `helm list` output for both regions
- [ ] A successful request against the Traffic Manager FQDN's `/healthz` and `/status`
- [ ] The DR test: primary disabled, Traffic Manager showing the primary endpoint degraded, a `/healthz` response reporting the secondary region
- [ ] Replica promotion command output
- [ ] Failback completion (whichever option from `docs/dr-runbook.md` is chosen)

## Evidence already captured (Container Instances path)
- [x] Both images built and pushed via GitHub Actions (`build-images.yml` run output)
- [x] `terraform apply` output for `envs/aci-poc` — 7 resources created
- [x] Direct HTTP request to the deployed backend's `/healthz` from outside Azure, returning a live, correct response
- [x] `terraform destroy` output — 7 resources destroyed
- [x] `az group exists --name rg-resopsaci` → `false`, confirming full teardown
