# Production-hardening recommendations

Consolidated from the POC-vs-production tables scattered through
`DECISIONS.md` and `docs/security.md`, so there's one list to work from if
this ever moves past a demo. Ordered roughly by impact.

1. **Remove PostgreSQL's public network access entirely.** Use VNet
   injection / private access instead of the `AllowAzureServices` firewall
   rule (AD-003, `docs/security.md`). This is the single highest-impact
   change — it's currently reachable, in principle, from any Azure tenant's
   resources, not just this project's.
2. **Add TLS to the request path.** Currently plain HTTP end-to-end.
   Terminate at Azure Front Door Premium (also fixes the DNS-TTL-bound
   failover speed, AD-006) or add an ingress controller with `cert-manager`.
3. **Resolve the vCPU-quota-driven sizing.** Everything about node count (1),
   node size (`B2s`), and control-plane tier (Free) in `modules/aks` is
   sized around AD-005's Free Trial constraint, not real workload
   requirements or HA best practice (which wants >=3 nodes across zones and
   a Standard/Premium SLA tier).
4. **Move the PostgreSQL admin password out of the system.** Either Azure
   AD authentication for Flexible Server (removes the password entirely) or
   Key Vault + CSI driver for secret delivery instead of a plain Kubernetes
   Secret created via `kubectl create secret`.
5. **Enable ACR Premium + geo-replication** (AD-004) so each region pulls
   from an in-region registry instead of cross-region.
6. **Enable Azure AD + Azure RBAC for Kubernetes Authorization** on both
   AKS clusters instead of relying on local `kubeconfig` access.
7. **Scope the GitHub Actions OIDC role down from subscription-wide
   Contributor** to a custom role limited to the resource types/groups this
   project actually manages (`docs/github-oidc-setup.md`).
8. **Add automated DR testing on a schedule** ("game days"), rather than
   the one-off manual runbook execution this POC assumes — track RTO/RPO
   trend over multiple runs (`docs/rto-rpo-methodology.md`).
9. **Add image scanning and signing** to `cd.yml`'s `build-and-push-image`
   job (Trivy/Defender for Containers, cosign) before pushing to ACR.
10. **Enable Azure Policy and Defender for Cloud** on the subscription —
    neither is configured anywhere in this repo; both are standard
    production guardrails for a multi-region Azure estate.
11. **Consider bidirectional/active-active for the database tier** if the
    business requirement is lower RPO than Postgres Flexible Server's
    asynchronous replication can offer (AD-003) — this would mean a
    different database technology or a different replication topology, not
    a small config change.

None of the above are implemented in this repo. They're listed here so the
POC-vs-production gap is a checklist, not a vague disclaimer.
