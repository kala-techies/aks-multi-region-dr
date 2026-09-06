# Progress

## Current phase
**The ACI smoke test succeeded end-to-end, then was torn down deliberately.**
ResilientOps (frontend + backend + PostgreSQL PaaS) was deployed for real to
Azure Container Instances, verified reachable from outside Azure, then
destroyed at the user's request once confirmed working. AKS multi-region
DR (`envs/dr-poc`) remains parked (AD-011) — this session proved the
*application*, not the DR architecture.

## What actually happened, in order (worth reading before continuing)

1. **App rewrite** (AD-001 addendum): "Notes API" replaced with
   **ResilientOps** (service-health/incident tracker). 17/17 tests pass.
2. **Frontend tier added** (`frontend/`): static HTML/CSS/vanilla-JS, nginx,
   own Dockerfile - a real presentation tier, not server-rendered from the
   backend. Redesigned once after the first pass was rejected as "looking
   basic" (see the dark "ops console" aesthetic in `styles.css` - deliberate
   choice, not a default).
3. **ACI Terraform environment added** (`terraform/modules/aci`,
   `terraform/envs/aci-poc`) - self-contained, decoupled from `dr-poc`.
4. **Real deployment attempted and initially blocked twice** - both
   findings below are now load-bearing facts about this specific Azure
   subscription, not just this session's trivia:
   - **Region restriction**: this subscription (Azure for Students,
     `42ea2035-17b5-4e72-a2b7-e4426883fb2d`) rejects resource creation
     (ACR, PostgreSQL Flexible Server - confirmed; likely broader) in
     West Europe, East US, Central US, South Central US, West US 2,
     Canada Central, North Europe, UK South, France Central, and Sweden
     Central, all with `RequestDisallowedByAzure:
     ...best available regions...`. **Central India is confirmed to
     work** - discovered by checking the Azure Portal, where a pre-existing
     VM (`khalandar-VM`, in `khalandar-rg`, Central India) is running -
     that VM is almost certainly the very machine this session runs on.
     Any future work on this subscription should default to
     **Central India** and expect other regions to fail until/unless the
     user contacts Azure Support to expand the allowed-region list (the
     error message itself says to).
   - **ACR Tasks (cloud image build) is also disallowed** on this
     subscription (`TasksOperationsNotAllowed`) - a second, independent
     restriction. Combined with no local Docker (this machine can't run
     Linux containers without WSL2/Hyper-V, which was not installed - a
     reboot-risking change the user was not asked to accept), this meant
     **no available way to build a container image locally or via Azure**.
     Resolved with `.github/workflows/build-images.yml` - a narrow,
     ungated workflow that builds+pushes both images from a GitHub-hosted
     runner (real Docker, no local/Azure dependency) using the ACR's
     admin credentials (already `admin_enabled=true` per AD-010) as a
     plain GitHub Actions secret/variables, not OIDC - deliberately
     simpler than the full `cd.yml`/`aci.yml` OIDC path since this only
     builds images, never touches infrastructure.
   - `gh` CLI was installed and authenticated (device code, same pattern
     as `az login`) so these repo variables/secrets and the workflow
     dispatch could be done directly rather than walking the user through
     the GitHub web UI by hand.
5. **Applied for real** (`terraform/envs/aci-poc`, `-var="location=centralindia"`):
   resource group, ACR (Basic, admin-enabled), PostgreSQL Flexible Server
   (`B_Standard_B1ms`) + `resilientops` database + firewall rule, one
   `azurerm_container_group` (backend :8000 + frontend :8080, one public IP).
6. **AZURE VALIDATED, from outside Azure**: `curl` to
   `http://resopsaci-o75e4.centralindia.azurecontainer.io:8000/healthz`
   returned `{"status":"ok","region":"centralindia-aci"}`; the frontend
   returned `200` at `:8080`. This is the strongest validation this project
   has had - a real deployment, confirmed reachable externally, not a
   `terraform apply` success message taken on faith.
7. **Destroyed on explicit user instruction** ("now destroy everything"):
   `terraform destroy` removed all 7 resources. Confirmed via
   `az group exists --name rg-resopsaci` → `false`. Nothing else in the
   subscription was touched (`khalandar-rg` and the auto-created
   `NetworkWatcherRG` remain, untouched, pre-existing).
8. **Cleanup offered, declined**: asked whether to delete the now-dead
   `ACI_ACR_ADMIN_PASSWORD` GitHub secret (the registry it authenticates to
   no longer exists) - user chose to leave it in place. **Not a security
   issue to lose sleep over, but worth remembering it's there** if this
   subscription/repo is audited later.

## Completed work (cumulative, unchanged from before unless noted)

- **App rewrite: ResilientOps** - see PROGRESS history above. `app/src/resilientops/`.
- **Frontend tier** - `frontend/`. Locally validated end-to-end against the
  real backend before the Azure deploy; then proven again live in Azure.
- **Helm rename** `helm/notes-api` -> `helm/resilientops`, all stale
  references fixed across `ci.yml`/`cd.yml`/`README.md`/`docs/`.
- **`ci.yml`** builds both images and validates both Terraform envs via a matrix.
- **`.gitignore`** now excludes `tfplan*`/`*.tfplan` - these files embed real
  secret values (not just the redacted CLI display), and several were
  generated and correctly *not* committed this session.

## Unexpected state, still unresolved
`app/src/order_api/` still exists on disk, still not built by any session's
work, still excluded from every commit. See git history / earlier
PROGRESS.md revisions for the full theory (leftover from an interrupted
prior Claude Code process). **Still needs a decision from the user**:
delete it, or is it something else's in-progress work?

## Current state of Azure resources
**Nothing exists in Azure from this project right now.** `rg-resopsaci` and
everything in it was destroyed. `envs/dr-poc` was never applied at all
(still blocked on AD-005, and now also on the region-restriction finding
above - West Europe/North Europe, the whole premise of that environment's
name and design, are both in the confirmed-blocked list). **If AKS work
resumes, `envs/dr-poc`'s region variables need to change to whatever the
support-ticket process (or further probing) confirms is allowed for AKS/VM
resources specifically** - Central India was only confirmed for
ACR/PostgreSQL/Container Instances, not yet for AKS or its VM node pools.

## Next steps
1. Resolve the `order_api` question (still open, several sessions now).
2. Decide whether to pursue the AKS path at all, given the same
   subscription-level region restriction almost certainly blocks it too
   (untested for AKS/VM specifically) - may require an Azure Support
   ticket to expand allowed regions, which only the user can file.
3. If resuming ACI-style work later: images are already proven to build
   via `build-images.yml`; re-running `terraform apply` for `envs/aci-poc`
   with `-var="location=centralindia"` is a known-good path.
4. Consider rotating/removing the now-dead `ACI_ACR_*` GitHub secrets/variables
   (declined this session, not forgotten).

## Important architectural decisions
See `DECISIONS.md` (AD-001 through AD-011). Consider this session's region/
ACR-Tasks findings and the `build-images.yml` workflow as de facto AD-012
material - not yet written up as a formal entry; do that before the next
context reset if this thread continues.

## Tooling installed this session (local dev machine only, not Azure)
Adds to the prior list: `gh` CLI (installed, authenticated via device code
as `kala-techies`, scopes `gist, read:org, repo`). Azure CLI is now
authenticated (was install-only before) - `az account show` confirms
subscription "Azure for Students",
`42ea2035-17b5-4e72-a2b7-e4426883fb2d`, tenant
`b5b978b2-1c57-4105-ae72-fb8dc347dad3`. Docker still not installed (still
not needed - GitHub Actions covers image builds now).
