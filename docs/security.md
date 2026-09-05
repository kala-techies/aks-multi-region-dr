# Security review (Phase 7)

Reviewed against what actually exists in this repo as of Phase 6
completion: the `app/` source, `terraform/` modules, `helm/` chart, and
`.github/workflows/`. Each finding is framed as POC state / production
recommendation per project rule 17 — nothing here is hidden or assumed away.

## Secrets handling

| Area | POC implementation | Production recommendation |
|---|---|---|
| PostgreSQL admin password | Supplied via `TF_VAR_postgres_administrator_password` (local) / `secrets.POSTGRES_ADMIN_PASSWORD` (CI). Never committed; `terraform.tfvars` is gitignored. | Rotate via Azure Key Vault + `azurerm_key_vault_secret`, referenced by Terraform, not a GitHub Actions secret at all. |
| App's DB connection string | Read from a pre-existing Kubernetes Secret (`notes-api-db-credentials`), created out-of-band with `kubectl create secret` — **not** a Helm value, so it never appears in `helm --set`, shell history, or Helm release metadata. | Azure Key Vault Provider for Secrets Store CSI Driver, or migrate the app to Postgres AAD authentication (below) and drop the password entirely. |
| Database authentication | Password-based (PostgreSQL native auth). | Azure AD authentication for PostgreSQL Flexible Server + AKS workload identity — removes the password from the system entirely. Not implemented here to keep the POC's moving parts down. |
| Azure credentials in CI | OIDC federated credentials (`azure/login@v2`), no stored client secret. See `docs/github-oidc-setup.md`. | Same approach; scope the federated credential's `subject` per-environment (already noted as an option in that doc) rather than per-branch. |

## Identity & access

| Area | POC implementation | Production recommendation |
|---|---|---|
| ACR access | `admin_enabled = false`; each AKS cluster's kubelet managed identity is granted `AcrPull` via `azurerm_role_assignment`, scoped to the registry only. | Same pattern — this is already the recommended approach, keep it. |
| AKS cluster identity | `SystemAssigned` managed identity per cluster. | Consider `UserAssigned` if you need the identity to exist independently of cluster lifecycle (e.g., referenced before the cluster is created). |
| GitHub Actions -> Azure role | Contributor on the whole subscription (see `docs/github-oidc-setup.md`, step 2). | Scope to a custom role restricted to the specific resource types this project creates, on the specific resource groups, not the whole subscription. |
| Kubernetes RBAC | Default AKS local accounts / built-in Kubernetes RBAC. Azure AD integration is **not** enabled in the `aks` module. | Enable Azure AD + Azure RBAC for Kubernetes Authorization (`azure_active_directory_role_based_access_control` block) so cluster access is managed through Entra ID groups, not `kubeconfig` files. |

## Network exposure

| Area | POC implementation | Production recommendation |
|---|---|---|
| PostgreSQL Flexible Server | Public network access enabled, with a broad `AllowAzureServices` (`0.0.0.0`–`0.0.0.0`) firewall rule — see `DECISIONS.md` AD-003 and `terraform/modules/postgresql/main.tf`. This allows any Azure-hosted resource (not just this project's AKS clusters) to attempt a connection; the password is still required, but the attack surface is wider than necessary. | Private access (VNet injection) with no public endpoint at all — see `terraform/modules/network`'s POC-implementation comment for the corresponding networking change this requires (delegated subnet + private DNS zone). |
| App traffic (Service -> Traffic Manager) | Plain HTTP on port 80/8000, no TLS anywhere in the request path. | Terminate TLS at Azure Front Door Premium (also the production recommendation for faster failover, AD-006) or add an in-cluster ingress controller with `cert-manager`. |
| AKS network policy / pod security | None configured — any pod can talk to any pod, no Pod Security Standards enforced. | Add a `network_profile.network_policy` (Azure or Calico) and a `Restricted` Pod Security Standard namespace label once there's more than one workload in the cluster. |
| Container registry network | ACR has its own public endpoint (Basic tier has no private endpoint support anyway). | Premium tier + private endpoint, consistent with the geo-replication upgrade already recommended in AD-004. |

## Supply chain / CI

| Area | POC implementation | Production recommendation |
|---|---|---|
| Dependency pinning | `app/requirements.txt` pins exact versions. | Add Dependabot (repo Settings — a GitHub remote-modification the user must enable, not Claude) for automated update PRs, and `pip-audit`/`safety` as a CI step. |
| Image provenance | `docker/build-push-action` tags images `:${{ github.sha }}` and `:latest`. | Add image signing (cosign) and vulnerability scanning (Trivy/Defender for Containers) as a CI gate before `build-and-push-image` pushes to ACR. |
| Secret scanning | Relies on GitHub's default secret scanning (a repo setting, not something in this codebase). | Confirm it's enabled in repo Settings; add push protection. |

## Summary of POC-accepted risk

Everything above that's flagged "POC implementation" is an intentional,
documented cost/complexity tradeoff for a Free-Trial-budget demo — not an
oversight. The two highest-impact items to fix before any real production
use are: (1) PostgreSQL's public network access + broad firewall rule, and
(2) the complete absence of TLS on the application's request path.
