# CLAUDE EXECUTION LIMITS AND OPERATING RULES

This project is intentionally large.
Do NOT attempt to complete everything in a single response or a single uninterrupted reasoning cycle.
Work as an autonomous engineering agent across multiple iterations/context windows.
The repository filesystem is the source of truth for project progress.

## 1. WHAT YOU ARE ALLOWED TO EXECUTE

You MAY execute local, reversible commands required to build and validate the repository.

Examples:

```bash
pwd
ls
find
git status
git diff

terraform fmt
terraform validate
terraform init -backend=false
terraform plan

docker build
docker run
docker compose up
docker compose down

pytest
npm test
npm run lint

kubectl version
helm lint
helm template

yamllint
```

You may inspect generated files, run tests, validate Terraform syntax, render Helm templates, build containers, and perform local application testing.
Prefer local/reversible validation wherever possible.

## 2. AZURE RESOURCE CREATION

DO NOT create Azure resources during the initial implementation phase.
Specifically, DO NOT execute:

```bash
terraform apply
terraform destroy
az deployment ...
az group create
az aks create
az sql ...
az postgres ...
az mysql ...
az acr ...
```

during the repository-generation phase.
The goal of Phase 1 is to generate and validate the implementation.
I will execute the actual Azure deployment later.

## 3. NO DESTRUCTIVE ACTIONS

Never execute destructive commands without explicit user approval.

Examples:

```bash
terraform destroy
terraform apply -destroy
az group delete
kubectl delete namespace
kubectl delete deployment
rm -rf
git reset --hard
git clean -fd
git push --force
```

Do not use destructive operations as shortcuts for solving problems.
If a destructive operation becomes necessary, STOP and ask me.

## 4. NO GIT PUSH

You may create commits locally if useful, but:

DO NOT:

```bash
git push
```

DO NOT create or modify remote GitHub repositories unless explicitly instructed.
DO NOT modify:

* GitHub organization settings
* GitHub repository settings
* Branch protection
* GitHub secrets
* GitHub environments

without explicit approval.
You may generate the required workflow YAML and documentation.

## 5. NO REAL CREDENTIALS

Never ask me to paste:

* Azure client secrets
* passwords
* private keys
* access tokens
* GitHub personal access tokens
* database credentials

into source files.
Use placeholders/environment variables/examples.
Never write secrets into:

```text
.tfvars
.yaml
.json
.env
Dockerfiles
GitHub workflow files
```

unless the file is explicitly an example file and clearly marked as such.

## 6. AZURE CLI

You MAY use Azure CLI for READ-ONLY inspection if Azure credentials are already configured.

Examples:

```bash
az account show
az account list
az provider list
az vm list-skus
az aks get-versions
az group list
```

However, do not make assumptions from stale local CLI output.
For architecture decisions involving Azure service availability or limitations, consult current official Microsoft documentation.

## 7. TERRAFORM

Terraform should be developed and validated locally.

You MAY execute:

```bash
terraform fmt
terraform validate
terraform init -backend=false
terraform plan
```

where doing so does not create resources.
If a Terraform plan requires access to a real Azure backend or subscription and would create/modify resources, STOP before apply.

The expected workflow is:

```text
Terraform code
      |
      v
terraform fmt
      |
      v
terraform validate
      |
      v
terraform plan
      |
      v
Human review
      |
      v
GitHub Actions
      |
      v
terraform apply
```

## 8. DO NOT FAKE VALIDATION

Never say:

```text
Terraform deployment successful
AKS successfully deployed
Database successfully replicated
Failover successfully completed
```

unless the operation was actually performed and verified.

Distinguish clearly between:

```text
STATICALLY VALIDATED
LOCALLY VALIDATED
AZURE VALIDATED
NOT YET VALIDATED
```

## 9. USE THE FILESYSTEM AS PROJECT MEMORY

Because this is a long-running project, maintain:

```text
PROGRESS.md
```

This file must contain:

```text
Current phase
Completed work
Current blockers
Known issues
Validation performed
Next steps
Important architectural decisions
Azure assumptions requiring verification
```

Also maintain:

```text
DECISIONS.md
```

for significant architecture decisions.

Example:

```text
Decision:
Use Azure Database for PostgreSQL

Reason:
Lowest practical cost + supported geo-replication + Terraform support

Alternatives:
Azure SQL
MySQL

Tradeoff:
...
```

This allows you to continue safely after a context-window reset.

## 10. NEVER RESTART FROM SCRATCH

When continuing the task:

FIRST inspect:

```text
PROGRESS.md
DECISIONS.md
README.md
git status
git diff
```

Then inspect the existing repository.
Do not regenerate files that already exist simply because the current conversation context does not contain them.
The filesystem is the source of truth.

## 11. WORK IN PHASES

Follow this order.

PHASE 1 — Architecture and Azure feasibility research.
PHASE 2 — Application implementation.
PHASE 3 — Containerization.
PHASE 4 — Terraform.
PHASE 5 — Kubernetes/Helm.
PHASE 6 — GitHub Actions.
PHASE 7 — Security and configuration.
PHASE 8 — DR implementation.
PHASE 9 — Testing and validation.
PHASE 10 — Documentation.

Do not jump randomly between phases.

## 12. COMPLETE EACH COMPONENT BEFORE MOVING ON

For each component:

```text
Implement
   |
   v
Test
   |
   v
Fix
   |
   v
Document
   |
   v
Update PROGRESS.md
   |
   v
Move to next component
```

Do not create dozens of partially implemented files and leave them unfinished.

## 13. IF YOU HIT A CONTEXT LIMIT

If you are approaching your context/output limit:

DO NOT rush and produce an incomplete repository.

Instead:

1. Finish the current safe unit of work.
2. Save progress to `PROGRESS.md`.
3. Save architectural decisions to `DECISIONS.md`.
4. Ensure files are syntactically consistent.
5. Report what remains.
6. Continue in the next iteration.

## 14. IF SOMETHING CANNOT BE VERIFIED

Do not guess.

For example:

```text
Azure service availability
Azure SKU availability
Free Trial eligibility
Regional database capabilities
Terraform resource support
AKS feature support
```

If you cannot verify something, explicitly mark:

```text
UNVERIFIED
```

and explain what needs to be checked.

## 15. IF AZURE DOCUMENTATION CONTRADICTS THE PLAN

STOP and reassess the architecture.
Do not force the original architecture simply because it was specified earlier.

For example:
If a service is not available in West Europe / North Europe, or the required SKU is unavailable/too expensive, evaluate alternatives.

Document:

```text
Original approach
Problem
Evidence
Alternative
Decision
Production recommendation
```

## 16. FREE TRIAL SAFETY

Treat cost as a first-class constraint.

Before recommending any Azure resource, evaluate:

```text
Is it available in the selected region?
Is the required SKU available?
Does it require a paid tier?
Does it have hourly charges?
Does it have minimum capacity?
Does it create additional networking charges?
Is it appropriate for Azure Free Trial?
```

Do not assume that because AKS itself has a free control plane option, the entire AKS deployment is free.
Clearly identify compute, storage, networking, database, monitoring, registry, and traffic-management costs.

## 17. PRODUCTION VS POC

Never hide compromises.

Every significant compromise should be documented as:

```text
POC IMPLEMENTATION
------------------

Production Recommendation
-------------------------

Reason
------
```

## 18. HUMAN APPROVAL GATES

The following operations require explicit approval from me:

Azure resource creation (`terraform apply`, `az * create`)
Azure resource deletion (`terraform destroy`, `az group delete`)
Database destructive operations (`DROP`, `DELETE DATABASE`, `FAILOVER`, `FAILBACK`)
GitHub remote modifications (`git push`, repository settings, secrets, environments, branch protection)
Production-impacting operations — anything that could affect an existing/shared environment.

## 19. DR TEST SAFETY

The DR test must initially be designed as a safe simulation.
Do not automatically destroy or permanently disable the West Europe environment.

Prefer techniques such as:

```text
scale application to zero
temporarily disable traffic
use health-check failure simulation
temporarily route traffic away
```

depending on the selected architecture.

The DR test must be reversible.
Document exactly how to restore the primary region.

## 20. OUTPUT STYLE

Do not spend the entire response explaining what you intend to do.

When working in the repository:

1. Inspect.
2. Implement.
3. Test.
4. Fix.
5. Document.
6. Report concise progress.

Use the available tools aggressively for independent tasks where safe.
For independent file inspection/testing operations, parallelize them when practical.

## 21. FINAL COMPLETION CRITERIA

Do NOT declare the project complete until:

```text
[ ] Application source exists
[ ] Application tests exist
[ ] Dockerfile exists
[ ] Container builds successfully
[ ] Terraform exists
[ ] Terraform validates
[ ] Helm/Kubernetes manifests exist
[ ] Helm templates validate
[ ] GitHub Actions workflows exist
[ ] GitHub OIDC documentation exists
[ ] Azure architecture is documented
[ ] DR architecture is documented
[ ] Database architecture is documented
[ ] Cost limitations are documented
[ ] Azure limitations are documented
[ ] Security considerations are documented
[ ] Troubleshooting guide exists
[ ] Validation checklist exists
[ ] Screenshot/evidence checklist exists
[ ] RTO/RPO methodology exists
[ ] Production-hardening recommendations exist
[ ] PROGRESS.md is updated
[ ] No secrets are committed
[ ] No destructive operations were performed
[ ] No Azure resources were created without explicit approval
```

## FINAL RULE

The most important rule is:

Generate everything first. Validate locally. Do not deploy Azure infrastructure until I explicitly tell you to deploy it.

When I later say:

"Proceed with Azure deployment"

then switch from implementation mode to deployment mode and walk through the deployment carefully, starting with pre-flight validation before running `terraform apply`.
