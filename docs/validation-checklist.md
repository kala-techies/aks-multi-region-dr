# Validation checklist (Phase 9)

Status legend: `STATICALLY VALIDATED` / `LOCALLY VALIDATED` / `AZURE
VALIDATED` / `NOT YET VALIDATED` — see project rule 8. Nothing below is
marked done unless it was actually run and its output observed in this
repo's history.

## Application (Phase 2)
- [x] LOCALLY VALIDATED — `pytest` in `app/`: 8/8 tests pass (health checks, full notes CRUD, 404, validation).
- [ ] NOT YET VALIDATED — load/performance testing (out of scope for a demo app; not planned).

## Container (Phase 3)
- [x] STATICALLY VALIDATED — Dockerfile manually reviewed (non-root user, `HEALTHCHECK`, `.dockerignore`, slim base image).
- [ ] NOT YET VALIDATED — `docker build` / `docker run` — Docker is not installed in this execution environment; CI's `docker-build` job (`.github/workflows/ci.yml`) will validate this on first push.

## Terraform (Phase 4)
- [x] STATICALLY VALIDATED — `terraform fmt -check -recursive` clean.
- [x] STATICALLY VALIDATED — `terraform validate` → "Success! The configuration is valid."
- [ ] NOT YET VALIDATED — `terraform plan` against a real subscription (attempted; failed at the Azure authorizer step because `az` is not installed/authenticated here — see PROGRESS.md).
- [ ] NOT YET VALIDATED — actual vCPU quota check (`az vm list-usage`) — see AD-005, this is the top feasibility risk.
- [ ] AZURE VALIDATED — nothing applied. Per project rule 2, `terraform apply` requires explicit user approval and has not been requested yet.

## Helm (Phase 5)
- [x] LOCALLY VALIDATED — `helm lint helm/resilientops` → 0 charts failed.
- [x] LOCALLY VALIDATED — `helm template` renders correctly with default values and with `values-primary.yaml` + `--set service.loadBalancerIP=... --set service.resourceGroup=...` (annotation confirmed present).
- [ ] NOT YET VALIDATED — actual `helm upgrade --install` against a real AKS cluster (requires Phase 4 to be applied first).

## GitHub Actions (Phase 6)
- [x] STATICALLY VALIDATED — `yamllint` clean on both workflow files.
- [ ] NOT YET VALIDATED — `ci.yml` has not actually run in GitHub Actions (requires a push to the real remote, which this session has not done per project rule 4 — no `git push`).
- [ ] NOT YET VALIDATED — `cd.yml` — requires the one-time OIDC/environment setup in `docs/github-oidc-setup.md`, which is a GitHub-admin action outside this session's scope.

## Security (Phase 7)
- [x] Reviewed — see `docs/security.md` for the full table of POC-state vs. production-recommended findings. No automated security scanning has been run (no SAST/dependency-scan tool was executed in this session).

## DR (Phase 8)
- [x] Documented — `docs/dr-runbook.md` (failover + failback procedures) and `DECISIONS.md` AD-007/AD-008.
- [ ] NOT YET VALIDATED — no failover test has been executed against real infrastructure. See `docs/rto-rpo-methodology.md`.

## Documentation (Phase 10)
- [x] `docs/architecture.md`, `docs/cost-analysis.md`, `docs/security.md`, `docs/dr-runbook.md`, `docs/rto-rpo-methodology.md`, `docs/troubleshooting.md`, `docs/production-hardening.md`, `docs/github-oidc-setup.md`, this file, `README.md`, `PROGRESS.md`, `DECISIONS.md`.

## Screenshot / evidence checklist (to capture once Azure deployment happens)
- [ ] `az vm list-usage` output showing available quota before apply
- [ ] `terraform plan` output against the real subscription
- [ ] `terraform apply` output / Azure Portal resource list after apply
- [ ] `kubectl get pods -A` for both clusters showing Running pods
- [ ] `helm list` output for both regions
- [ ] A successful `curl` against the Traffic Manager FQDN's `/healthz` and `/notes`
- [ ] The DR test: primary disabled, Traffic Manager Portal showing the primary endpoint Degraded, a `/healthz` response with `region: northeurope`
- [ ] Replica promotion command output
- [ ] Failback completion (whichever option from `docs/dr-runbook.md` was chosen)
