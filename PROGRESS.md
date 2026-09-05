# Progress

## Current phase
All 10 phases have a first complete pass. **Nothing has been deployed to
Azure.** Remaining work is entirely: (a) user decisions/confirmations, and
(b) validation that requires real Azure credentials this environment
doesn't have.

- Phase 1 (Architecture & feasibility research) — complete.
- Phase 2 (Application) — complete, locally validated (8/8 tests pass).
- Phase 3 (Containerization) — Dockerfile written, NOT locally build-validated (no Docker in this environment).
- Phase 4 (Terraform) — complete for POC scope; statically validated (`fmt`, `validate`); NOT plan/apply-validated against real Azure.
- Phase 5 (Helm) — complete, locally validated (`lint`, `template`).
- Phase 6 (GitHub Actions) — complete; workflows written and yamllint-clean; NOT run in real GitHub Actions (no `git push` performed, per project rule 4).
- Phase 7 (Security) — complete: `docs/security.md`.
- Phase 8 (DR) — complete: `docs/dr-runbook.md`, with two UNVERIFIED `az` command flags flagged for confirmation before real use.
- Phase 9 (Testing/validation) — complete as methodology + checklist (`docs/rto-rpo-methodology.md`, `docs/validation-checklist.md`); actual DR test results are NOT YET VALIDATED (no real infrastructure exists).
- Phase 10 (Documentation) — complete: `README.md` + everything under `docs/`.

## Completed work
See `docs/validation-checklist.md` for the authoritative, itemized status
of every phase (what's STATICALLY/LOCALLY/AZURE validated vs. NOT YET). Full
narrative of what was built and why is in `DECISIONS.md` (AD-001..AD-009).

Summary of what exists in the repo:
- `app/` — FastAPI Notes API, 8 passing tests, Dockerfile.
- `terraform/` — 5 modules (network, aks, acr, postgresql, traffic-manager) + `envs/dr-poc` root config. `fmt`/`validate` clean.
- `helm/notes-api/` — chart + per-region value overlays. `lint`/`template` clean.
- `.github/workflows/` — `ci.yml` (safe, auto-run) + `cd.yml` (gated, manual, OIDC-based).
- `docs/` — architecture, security, DR runbook, RTO/RPO methodology, cost analysis, troubleshooting, production-hardening, GitHub OIDC setup, validation checklist.

## Current blockers (in order of what to resolve first)
1. **AD-001 (app scope) is still an assumption**, never confirmed by the user. If a specific application/tech stack was expected (e.g. for a course rubric), this needs to be swapped before anything is deployed.
2. **AD-005's vCPU quota risk is unresolved, and deliberately not checked from this session.** Azure CLI was installed and `az login --use-device-code` was started, but the user declined to authenticate this session against their Azure account (a reasonable call — this session's environment is not somewhere they'd chosen to place Azure credentials). The login was not completed; no Azure session exists here. **The user will run the quota check themselves** (`az vm list-usage --location westeurope -o table` and the same for `northeurope`) before any `terraform apply`. Azure CLI remains installed on this machine for when they're ready to do that here, or they may check from elsewhere.
3. Docker is not installed in this execution environment, so Phase 3's container build could not be run end-to-end here — see `docs/troubleshooting.md` for what was attempted and why it stopped where it did.

## Git status
Initial commit `f1ad880` ("Initial AKS multi-region DR POC: app, Terraform, Helm, CI/CD, docs") created and pushed to `origin/main` (`kala-techies/aks-multi-region-dr`) on 2026-09-05. Authored solely by `shaik kalandar <shaik.kalandar20@gmail.com>` — no AI co-authorship trailer, per the user's explicit standing preference across all their repos. `ci.yml` should now run for real on GitHub Actions against this push; `cd.yml` still needs the one-time OIDC/environment setup in `docs/github-oidc-setup.md` before it can be used.

## Known issues
- PostgreSQL uses public network access + a broad `AllowAzureServices` firewall rule (AD-003) — documented, not hidden; top item in `docs/production-hardening.md`.
- ACR is single-region, no geo-replication (AD-004) — cross-region pulls will be slower.
- No TLS anywhere in the request path yet — flagged in `docs/security.md` and `docs/production-hardening.md`.
- Two `az` CLI commands in `docs/dr-runbook.md` (Traffic Manager endpoint disable, PostgreSQL replica promote) are marked UNVERIFIED exact syntax — confirm against `--help`/current docs before running for real.

## Validation performed
See `docs/validation-checklist.md` — kept there instead of duplicated here so there's one authoritative copy.

## Next steps (for the user, or a future session with more tooling access)
1. Confirm or override AD-001.
2. `az login`; run the quota check in blocker #2 above.
3. If quota allows: `terraform plan` against the real subscription, review carefully, then explicit sign-off before `terraform apply`.
4. Set up GitHub OIDC + environments (`docs/github-oidc-setup.md`) before using `cd.yml`.
5. Push to the `kala-techies/aks-multi-region-dr` remote when ready (this session has not run `git push` — see project rule 4) so `ci.yml` actually runs.
6. Once infrastructure exists: run the DR test in `docs/dr-runbook.md` (with explicit approval, per rule 18) and fill in the results table in `docs/rto-rpo-methodology.md`.
7. Work through `docs/production-hardening.md` for anything beyond POC/demo use.

## Important architectural decisions
See `DECISIONS.md` (AD-001 through AD-009).

## Azure assumptions requiring verification
- Actual current vCPU quota for this subscription in West Europe and North Europe (AD-005).
- `Standard_B2s` availability in both regions at deploy time (AD-005).
- PostgreSQL Flexible Server Burstable `B1ms` SKU availability in North Europe (AD-003).
- Whether this subscription is still an Azure Free Trial vs. already Pay-As-You-Go (changes the quota-increase option in AD-005).
- All cost figures in `docs/cost-analysis.md` — gathered from general web research, not the Azure Pricing Calculator against this specific subscription.
- Exact `az` CLI syntax for Traffic Manager endpoint disable and PostgreSQL replica promotion (`docs/dr-runbook.md`).

## Tooling installed this session (local dev machine only, not Azure)
Chocolatey packages: `python312` (used), `python314` (installed first, left in place but unused — its newer wheels weren't compatible with pinned dependency versions), `terraform`, `kubernetes-cli`, `kubernetes-helm`, `azure-cli` (installed but never authenticated — see Current blockers #2). Also `pip install yamllint` into the `python312` install for linting the GitHub Actions YAML. Docker was deliberately NOT installed (would need Windows containers/Hyper-V features + likely a reboot on this Windows Server machine — judged too invasive to do unilaterally).
