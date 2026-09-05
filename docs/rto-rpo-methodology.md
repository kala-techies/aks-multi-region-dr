# RTO / RPO methodology (Phase 9)

## Definitions used in this project

- **RTO (Recovery Time Objective):** wall-clock time from "primary marked
  unhealthy" to "the system is serving correct read-write requests from the
  secondary region."
- **RPO (Recovery Point Objective):** the maximum amount of committed data
  that can be lost in a failover, measured as replication lag at the moment
  of promotion.

## RTO measurement method

Timestamps are taken at the two points defined in `docs/dr-runbook.md`:

1. **T0** — the moment the primary is marked down (Traffic Manager's
   `monitor_config` transitions the primary endpoint to `Degraded`, per its
   `interval_in_seconds = 30`, `tolerated_number_of_failures = 3`
   configuration in `terraform/modules/traffic-manager/main.tf` — so T0 is
   bounded below by roughly 90 seconds of missed health checks before
   Traffic Manager even reacts, before any DNS TTL or manual step is
   counted).
2. **T1** — the first HTTP 200 from `GET https://<traffic-manager-fqdn>/healthz`
   whose `region` field reads `northeurope`, following the manual replica
   promotion step.

**RTO = T1 − T0.**

Components this RTO includes, so the number isn't misleading:
- Traffic Manager failure detection (~90s minimum, per the monitor config above)
- DNS TTL (30s, `dns_config.ttl` in the Traffic Manager module) for any
  resolver that had already cached the primary's answer
- Manual replica promotion time (human-executed, per the runbook — this is
  typically the dominant term, and is **not** automated on purpose per
  project rule 18)
- Any manual Secret/redeploy step, if the design changes to require one

## RPO measurement method

PostgreSQL Flexible Server exposes replication lag; before promoting in a
real test, capture it (exact query/metric name to confirm against current
Microsoft Learn docs at test time — **UNVERIFIED**, likely
`pg_stat_replication` on the primary or the `Replication Lag` metric in
Azure Monitor for the replica). The lag value at the moment of promotion
**is** the RPO for that test run: any transaction committed on the primary
within that lag window, but not yet streamed to the replica, is lost.

**RPO = replication lag (seconds) at time of promotion, converted to "worst-case rows lost" by cross-referencing the Notes API's write rate during the test.**

## Results

**NOT YET VALIDATED.** No failover test has been executed against real
Azure infrastructure — Phase 4 has not been applied (per project rule 2,
`terraform apply` requires explicit user go-ahead, and per AD-005 the vCPU
quota question must be resolved first). This section is a placeholder to be
filled in after a real `docs/dr-runbook.md` execution:

| Test date | RTO observed | RPO observed | Notes |
|---|---|---|---|
| _(pending)_ | _(pending)_ | _(pending)_ | _(pending)_ |

## Known limitation of this methodology

This measures **one** failover path (primary total outage, clean manual
promotion). It does not cover: partial/degraded-but-not-down primaries,
split-brain scenarios (both regions briefly accepting writes — not possible
here since the secondary is read-only until explicitly promoted, but worth
stating explicitly), or failure of the promotion step itself. A production
DR program would run this test repeatedly (a "game day" cadence) and track
RTO/RPO trend over time, not treat one run as definitive.
