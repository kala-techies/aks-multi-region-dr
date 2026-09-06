# DR runbook

Implements the pattern chosen in `DECISIONS.md` AD-007 (active-passive) and
the test-safety requirements of AD-008 (reversible
simulation, never destructive — see `docs/engineering-process.md`). **Do not run the failover steps below
against real infrastructure without the human owner's explicit approval for
that specific test run — this is a human-approval-gated operation (project
rule 18) even though it is designed to be reversible.**

## Steady state

- Primary (West Europe): AKS deployment running, Traffic Manager priority 1,
  serving 100% of traffic. PostgreSQL Flexible Server primary accepts reads
  and writes.
- Secondary (North Europe): AKS deployment already running (`helm upgrade
  --install` applied, 1 replica per AD-005's vCPU constraint), Traffic
  Manager priority 2 (idle — receives no traffic while priority 1 is
  healthy). PostgreSQL read replica continuously streaming from the primary,
  read-only, lag typically small but not bounded (AD-003).
- **Important:** the secondary app's `resilientops-db-credentials` Secret
  already points at the *replica's own* FQDN (`psql-<prefix>-sec-<suffix>.postgres.database.azure.com`),
  not the primary's. This is deliberate — it means failover does **not**
  require editing the secondary's connection string; promoting the replica
  in place makes that same hostname become writable.

## Failover procedure (simulated primary failure)

1. **Get approval.** Confirm with the project owner that this specific test
   run is authorized, and that it's acceptable for the primary to serve no
   traffic for the test's duration.

2. **Simulate the failure** (reversible — pick one):
   - `kubectl --context <primary> scale deployment/resilientops --replicas=0`, or
   - Disable the primary endpoint in the Traffic Manager profile (Azure
     Portal, or `az network traffic-manager endpoint update --endpoint-status Disabled ...`
     — **UNVERIFIED exact flag names**: confirm against `az network
     traffic-manager endpoint update --help` before running; do not guess).
   Do NOT delete the primary resource group, cluster, or database.

3. **Observe Traffic Manager mark the primary Degraded** and start
   answering DNS queries with the secondary endpoint's address instead.
   Record the timestamp — this is the start of your RTO measurement window
   (see `docs/rto-rpo-methodology.md`).

4. **Promote the read replica to standalone read-write:**
   ```bash
   az postgres flexible-server replica promote \
     --name <secondary-server-name> \
     --resource-group <rg-secondary>
   ```
   **UNVERIFIED exact command/flags** — confirm current syntax against
   `az postgres flexible-server replica --help` (this subcommand's shape
   has changed across `az` CLI versions); do not run this against real data
   without first confirming the command against current Microsoft Learn
   docs and, ideally, rehearsing it against a disposable replica first.
   This step is **irreversible**: once promoted, this server can no longer
   be re-attached as a replica of the original primary (see Failback,
   below).

5. **Confirm the secondary app is serving correctly:**
   ```bash
   curl https://<traffic-manager-fqdn>/healthz
   ```
   The response's `region` field should now read `northeurope`. Also
   exercise `/notes` (GET and POST) to confirm read-write access against
   the newly-promoted database.

6. **Measure recovery time** from the timestamp in step 3 to the first
   successful end-to-end request in step 5 — this is your observed RTO for
   this test run. Record it in `docs/rto-rpo-methodology.md`'s results
   section.

## Failback (restoring primary as the active region)

This is the part most DR plans gloss over — be explicit about it instead
(see `docs/engineering-process.md` on distinguishing validated from assumed).

**Postgres Flexible Server replica promotion is one-way.** Once the
secondary is promoted, it is a fully independent primary server; the
original West Europe server is not automatically resynchronized and cannot
simply "resume" being primary. Restoring the original topology means one
of:

- **(a) Accept North Europe as the new permanent primary.** Re-run the
  Terraform config with the primary/secondary region variables swapped, so
  a *new* cross-region replica is created back in West Europe from the
  (now-authoritative) North Europe server. This is the operationally
  simplest option and is what most real incidents end up doing.
- **(b) Restore West Europe from a fresh backup/export of the promoted
  server**, then re-establish it as primary and recreate North Europe as
  its replica — effectively rebuilding the original topology, at the cost
  of a maintenance window and a second data-migration step.

Either way: **any writes accepted by the promoted secondary during the
incident are the ones that survive.** There is no automatic reconciliation
of writes that might otherwise have landed on the original primary after
its failure — this is the real-world meaning of "asynchronous replication,
RPO up to ~5 minutes" from AD-003, and it is why failback is a planned,
manual exercise, not a button.

To restore traffic to West Europe once its infrastructure is healthy again
(under option (a) or (b) above): re-enable the Traffic Manager primary
endpoint (or scale its deployment back to `replicas: 1`), and optionally
lower the new West Europe endpoint's priority back to 1 once you're
confident it's fully caught up.

## What this runbook deliberately does not automate

Steps 4 (promotion) and the failback rebuild are not wired into `cd.yml` as
one-click jobs. They are destructive/irreversible-adjacent database
operations requiring explicit human approval (see `docs/engineering-process.md`,
which lists failover/failback explicitly among database-destructive
operations) — they
must be run deliberately, by a human, watching the output.
