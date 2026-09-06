# Cost analysis

**All figures below are approximate, USD, pay-as-you-go retail list price,
gathered from web research — not pulled from the Azure
Pricing Calculator against this specific subscription/region/currency.
Treat every number as UNVERIFIED until confirmed against
https://azure.microsoft.com/pricing/calculator/ for the actual subscription
this gets deployed to.** Cost is treated as a first-class constraint
throughout this project (see `docs/engineering-process.md`) — the point of this table is to make the
order of magnitude visible before anything is deployed, not to be an
invoice.

## Estimated monthly cost, POC architecture (both regions running continuously)

| Resource | Quantity | Approx. unit cost | Approx. monthly cost | Source of estimate |
|---|---|---|---|---|
| AKS control plane (Free tier) | 2 | $0/hour | $0 | Verified: Free tier has no control-plane charge — see `DECISIONS.md` AD-005 |
| AKS node VM (`Standard_B2s`, 2 vCPU/4GiB) | 2 | ~$0.0416/hour (Linux, base rate — regional rate for West/North Europe not separately confirmed) | ~$60 total (2 x ~$30) | Community pricing aggregators (azurespeed.com, instances.vantage.sh); confirm against the Azure Pricing Calculator for West Europe/North Europe specifically |
| PostgreSQL Flexible Server, Burstable `B1ms` | 1 primary + 1 replica = 2 | Burstable B1ms is Azure's cheapest Postgres compute tier (exact $/hour not confirmed) | UNVERIFIED — check Azure Pricing Calculator | A replica bills as a second server, roughly doubling compute cost vs. a single-region deployment |
| PostgreSQL storage | 32 GB x 2 | Low, storage is billed per GB/month | UNVERIFIED — small (<$10 combined estimate) | — |
| Azure Container Registry, Basic | 1 | Basic tier has a small flat monthly fee (well under Premium's ~$50/month) | UNVERIFIED, but confirmed cheaper than Premium — see AD-004 sources | Premium (~$50/month, confirmed) was rejected specifically because of this gap |
| Standard Public IP (static) | 2 | Small flat monthly fee per IP (historically on the order of a few dollars/month) | UNVERIFIED exact rate | — |
| Traffic Manager | 1 profile | Billed per DNS query received + a small per-monitored-endpoint fee | UNVERIFIED exact rate, but confirmed to be Azure's cheapest cross-region traffic-routing option — see AD-006 sources | Negligible at demo traffic volumes |
| Data transfer (cross-region ACR pulls, replication) | — | Small at low traffic/deploy frequency | UNVERIFIED | Called out explicitly in AD-004 as a real but minor cost of the single-ACR compromise |

**Rough order of magnitude: dominated by the two AKS node VMs and the two
PostgreSQL servers — likely in the tens of dollars per month range for a
demo left running continuously, not hundreds.** This still needs to be
confirmed against the Pricing Calculator before relying on it for a Free
Trial's finite credit.

## The single biggest cost/feasibility risk: not billing, but quota

Money isn't actually the tightest constraint here — Azure Free Trial's
$200 credit would comfortably cover the estimate above for its 30-day
window. The tighter constraint is the **documented 4 total vCPU cap that
Free Trial subscriptions cannot request an increase for** (`DECISIONS.md`
AD-005). Two `Standard_B2s` nodes already consume all 4 vCPUs, before
counting anything else (a jump box, a local CI runner, scaling either
cluster). **This must be checked with `az vm list-usage --location
westeurope -o table` (and `northeurope`) before running `terraform apply` —
see PROGRESS.md's Known issues.**

## Things this POC intentionally does NOT pay for (see the paired production recommendation in `DECISIONS.md`/`docs/security.md`)

- ACR Premium + geo-replication (~$50/month/region) — AD-004
- Azure Front Door Premium (meaningfully more than Traffic Manager) — AD-006
- PostgreSQL General Purpose/Memory Optimized tiers (Burstable is not a production-grade choice) — AD-003
- AKS Standard/Premium control-plane tier (SLA) — AD-005
- Private networking (VNet-integrated Postgres, no public endpoints) — `docs/security.md`
- Azure Key Vault, Defender for Cloud, Azure Policy — not costed or implemented in this POC at all
