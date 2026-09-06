# GitHub Actions -> Azure OIDC setup (one-time, manual)

The workflows in `.github/workflows/cd.yml` authenticate to Azure using
**OpenID Connect (OIDC) federated credentials** — no client secret is ever
stored in GitHub. This document is the one-time setup a human must perform
before `cd.yml` can run. None of it has been done by Claude: it requires
creating real Azure AD (Entra ID) objects and GitHub repository settings,
both of which are outside the "generate and validate locally" scope of the
implementation phase (project rules 4 and 18).

## 1. Create an Azure AD App Registration + federated credential

```bash
# Read-only up to this point; the next two commands create real Azure AD objects.
az ad app create --display-name "aks-multi-region-dr-gha"
APP_ID=$(az ad app list --display-name "aks-multi-region-dr-gha" --query "[0].appId" -o tsv)

az ad sp create --id "$APP_ID"

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "gha-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:kala-techies/aks-multi-region-dr:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Also add one for workflow_dispatch on any branch if you plan to run cd.yml
# from a branch other than main, and one for `environment:infra-apply` /
# `environment:infra-plan` subjects if you want to scope trust per-environment:
#   "subject": "repo:kala-techies/aks-multi-region-dr:environment:infra-apply"
```

## 2. Grant the app Contributor on the subscription (or narrower scope)

```bash
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>"
```

**Production recommendation:** scope this to a resource group or use a
custom role with only the permissions Terraform actually needs, instead of
subscription-wide Contributor. Contributor-on-subscription is a POC
convenience.

## 3. Configure the GitHub repository (requires repo admin — done by the user, not Claude)

In `kala-techies/aks-multi-region-dr` -> Settings:

- **Environments**: create `infra-plan` and `infra-apply`.
  - `infra-apply` MUST have "Required reviewers" enabled — this is the
    human-approval gate for `terraform apply` and `helm upgrade` (project
    rule 18). Do not skip this.
- **Variables** (Settings -> Secrets and variables -> Actions -> Variables),
  set at the repository or environment level:
  - `AZURE_CLIENT_ID` = the App Registration's Application (client) ID
  - `AZURE_TENANT_ID` = your Azure AD tenant ID
  - `AZURE_SUBSCRIPTION_ID` = the target subscription ID
  - `ACR_NAME`, `ACR_LOGIN_SERVER` = from `terraform output` after Phase 4 apply
  - `AKS_PRIMARY_NAME`, `AKS_SECONDARY_NAME`, `RG_PRIMARY`, `RG_SECONDARY` = from `terraform output`
- **Secrets** (Actions -> Secrets, not Variables — these are sensitive):
  - `POSTGRES_ADMIN_PASSWORD` — used only by the `terraform-plan`/`terraform-apply`
    jobs via `TF_VAR_postgres_administrator_password`. Generate a strong
    password out-of-band; never derive it from anything checked into the repo.

### For `.github/workflows/aci.yml` specifically (the ACI smoke-test path)

Same federated credential and environments as above (this is one App
Registration used by every workflow in this repo) — just a few more
Variables/Secrets, kept separate from the AKS path's names so the two
environments' outputs never get cross-wired by accident:

- **Variables**: `ACI_ACR_NAME`, `ACI_ACR_LOGIN_SERVER` — from `terraform
  output acr_login_server` after `envs/aci-poc` is first applied (chicken-
  and-egg for the very first apply: leave these unset and the
  `build-and-push-images` job's `az acr login` step will simply fail
  informatively until they're filled in post-apply, or apply once by hand
  first to bootstrap the ACR before wiring CI to it).
- **Secrets**: `ACI_POSTGRES_ADMIN_PASSWORD`, `ACI_BACKEND_API_KEY` — same
  handling as `POSTGRES_ADMIN_PASSWORD` above; the API key becomes the
  value operators must supply in the frontend's "Operator key required"
  dialog to exercise any write endpoint against the deployed instance.

## Why OIDC instead of a service principal secret

A traditional service-principal client secret is a long-lived credential
that has to be rotated, can be copy-pasted, and is a stored bearer token —
if `cd.yml` used one, it would violate project rule 5 ("never write secrets
into GitHub workflow files"). OIDC federated credentials issue a
short-lived token per workflow run, scoped to the exact repo/branch/environment
subject configured above, and nothing secret is stored in GitHub at all for
the Azure login step itself.
