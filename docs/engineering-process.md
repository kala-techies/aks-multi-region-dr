# Engineering process and guardrails

This project is built and operated under a deliberately conservative set of
rules, because it targets real cloud infrastructure and a real (if small)
budget. This document is the rulebook: what gets built locally without
asking, what requires a human sign-off before it touches anything real, and
how the codebase's own files (`PROGRESS.md`, `DECISIONS.md`) are used as
persistent project memory across work sessions.

## What can be done freely

Local, reversible commands needed to build and validate the repository are
run without special approval:

```bash
git status / git diff
terraform fmt / validate / init -backend=false / plan
docker build / docker run
pytest / npm test / npm run lint
kubectl version / helm lint / helm template
yamllint
```

Inspecting generated files, running tests, validating Terraform syntax,
rendering Helm templates, and building/running containers locally are all
routine and don't require sign-off.

## What requires explicit sign-off before it happens

The following are treated as human-approval gates, not automation targets:

- **Creating Azure resources** — `terraform apply`, `az * create`
- **Deleting Azure resources** — `terraform destroy`, `az group delete`
- **Database-destructive operations** — `DROP`, `DELETE DATABASE`, failover/failback
- **Remote GitHub changes** — `git push`, repository settings, secrets, environments, branch protection
- **Anything that could affect an existing or shared environment**

Generating the code and configuration for these operations happens freely;
*executing* them against real infrastructure does not.

## No destructive shortcuts

Destructive operations are never used as a shortcut past a problem —
`terraform destroy`, `git reset --hard`, `git clean -fd`, force-pushes, and
similar are only used with explicit direction, never to "clean up" an
awkward state. If a destructive step looks necessary, it's raised as a
question first.

## No committed secrets

Real credentials — client secrets, passwords, private keys, access tokens,
database credentials — are never written into `.tfvars`, YAML, JSON, `.env`
files, Dockerfiles, or GitHub workflow files. Example/template files are
clearly marked as examples with placeholder values; real values are
supplied via environment variables or a secret store, never committed.

## Distinguishing validated from assumed

Claims like "deployment successful" or "failover completed" are only made
after the operation actually ran and was verified — not inferred from a
plan or a config file looking correct. Work is tracked at one of four
levels:

- **STATICALLY VALIDATED** — syntax/config checked, nothing executed
- **LOCALLY VALIDATED** — run and passed locally (tests, local containers)
- **AZURE VALIDATED** — actually deployed and confirmed working against real Azure
- **NOT YET VALIDATED** — not yet checked at all

`PROGRESS.md` and `docs/validation-checklist.md` track which level applies
to each part of the system, and that distinction is kept honest rather than
rounded up.

## Project memory: `PROGRESS.md` and `DECISIONS.md`

Because this project spans many separate working sessions, the filesystem
— not any single conversation — is the source of truth for where things
stand:

- **`PROGRESS.md`** — current phase, what's done, current blockers, what's
  validated at which level, and next steps.
- **`DECISIONS.md`** — every non-default architecture choice, numbered
  (AD-001, AD-002, ...), each with the reasoning, alternatives considered,
  the tradeoff accepted, and a production recommendation where relevant.

Anyone (human or AI assistant) picking this project back up starts by
reading `PROGRESS.md` and `DECISIONS.md`, not by re-deriving state from the
code alone — and doesn't regenerate files that already exist just because
they aren't in view.

## Phased delivery

Work proceeds in phases rather than jumping around: architecture and
feasibility research, application implementation, containerization,
infrastructure-as-code, Kubernetes/Helm, CI/CD, security review, DR design,
testing/validation, documentation. Each component is implemented, tested,
fixed, documented, and recorded in `PROGRESS.md` before moving to the next
— not left as a pile of partially-finished files.

## Free-tier / budget awareness

Cost is treated as a first-class constraint, not an afterthought. Before
adopting any Azure resource: is it available in the target region, does it
require a paid tier, does it have an hourly or per-second charge, does it
have a minimum footprint, does it add networking cost — and is it
appropriate for the budget this project actually has. Every deliberate
cost/complexity tradeoff is written up in `DECISIONS.md` with a paired
production recommendation, so the compromise is visible rather than
silently baked in.

## Every compromise is written down, not hidden

Anywhere this project takes the cheaper or simpler option over the
"correct" production one, that tradeoff is documented explicitly as:

```
POC implementation:            <what was actually built and why>
Production recommendation:     <what a production system should do instead>
```

This shows up throughout `DECISIONS.md` and `docs/production-hardening.md`.

## Reversible DR testing

Any disaster-recovery test is designed as a safe, reversible simulation —
scaling a deployment to zero, disabling a traffic endpoint, temporarily
rerouting — never permanently destroying the environment being tested
against. Exactly how to reverse the test is documented before the test
runs, in `docs/dr-runbook.md`.
