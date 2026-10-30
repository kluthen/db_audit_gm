# v0.4 — candidate faults

Status: draft v1

Faults that break the purposes' invariants
([purpose-catalogue.md](purpose-catalogue.md)) and the governance rules
([governance.md](governance.md)). Candidates, not a list to build: which
ship follows the purposes (D197) and the scenario ([scenario-sketch.md](scenario-sketch.md)).
Ids are working names. Every one is planted as v0.3's are: a
`seed-file` change at render (to a runner's `queries.yaml` or
`jobs.yaml`, or a database's data file), a `state` change during the
aging, or a timeline change of a schedule (D127) for an outside party's
behaviour.

Families: `data-flow` (v0.3's family for duplicates and dropped records),
`rules` (as v0.3's wrong-time-zone fault), `security` (governance,
proposed in governance.md).

## Sales reporting (P1)

| Id | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|
| `purpose-watermark-misses-updates` | R1 | the incremental load picks rows by `placed_at` past the watermark, so an order invoiced at the noon close never reaches reporting: invoiced revenue in `rpt` lags the source, more each day | seed-file, `queries.yaml` | the key's SQL; `rpt.sales_daily.invoiced_revenue` against the source's per day | watermark on `updated_at`; restating the affected days is an *improve* |
| `purpose-rerun-double-counts` | R2 | the hourly load inserts the overlapping hours again with no delete or upsert: hours that straddle two runs counted twice | seed-file | duplicate (hour, category) rows; day ≠ sum of hours | delete-and-insert per hour, or a unique key and upsert; remove the duplicates |
| `purpose-day-boundary-wrong-zone` | R3 | the day is cut in a zone N hours off the customer's (`offset` parameter, never 0; render writes it, O122) | seed-file | daily totals shifted against the source's local days; the zone in the SQL | the customer's zone from `business_settings` |
| `purpose-mapping-password-expired` | R4 | the user mapping's remote role `shop_etl` gets `VALID UNTIL` a moment during the aging: every run since fails with 28P01, the dashboards freeze | state, `plant_at: handover-<N>h` | the runner's log; `etl_runs` stops; `\du` on the source | `ALTER ROLE … VALID UNTIL 'infinity'` (or a new password in role and mapping) |
| `purpose-dashboard-fanout` | R5 | the dashboard's revenue query sums `orders.total` over a join with `order_lines`: each order counted once per line | seed-file, the consumer's `queries.yaml` | the query; its figure against `rpt.sales_daily` | sum before the join, or read `rpt` |

## Win-back leads (P2)

| Id | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|
| `purpose-leads-stale-consent` | L2 (then M2) | the extraction reads `customers.marketing_opt_in`, which the unsubscribe link no longer updates since a release (a timeline change of the producer): withdrawn customers stay leads | seed-file plus timeline change | leads whose latest consent event is a withdrawal; the producer's unsubscribe entry | read the latest `consent_events`; repair the flag |
| `purpose-leads-duplicated` | L3 (then M1) | no unique (campaign, customer) and no `NOT EXISTS`: every hourly run re-inserts the segment | seed-file | `leads` grouped by (campaign, customer) | dedupe, unique constraint, `ON CONFLICT DO NOTHING` |
| `purpose-leads-wrong-segment` | L1 | the segment reads `created_at` for `last_order_at`: active customers get win-back mail | seed-file | leads with recent orders | the right column |

## Customer mailing (P3)

| Id | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|
| `purpose-mail-overlapping-window` | M1 | the shipped-notice job, every five minutes, picks orders shipped in the last ten: every notice sent twice | seed-file | two `order-shipped` rows per order, ten minutes apart | select since the last run (a watermark) or `NOT EXISTS`; a unique (order, template) |
| `purpose-mail-ignores-consent` | M2 | the campaign job mails its leads without checking consent at sending time | seed-file | marketing mail to customers who withdrew before `sent_at` | check the latest consent at sending |
| `purpose-mail-outside-hours` | M3 | the campaign job's hours are the company's, not the recipient's | seed-file | marketing mail at night in the recipient's zone | filter recipients by their local hour |
| `purpose-mail-payload-other-customer` | M4 | the payload's order comes from a join on the wrong key: another customer's order in the mail | seed-file | payload `order` not the recipient's | the right join; a data breach to report (severity high) |
| `purpose-mail-silently-disabled` | M5 | the shipped-notice job's `at` never fires (`0 3 31 2 *`): no notice since | seed-file, `jobs.yaml` | `job … next=never` in the log; shipped orders without a notice | a real schedule |

## Export declarations (P5)

| Id | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|
| `purpose-trigger-code-unmapped` | E1 | a release of the web shop writes `UK` where `export_countries` holds `GB` (a timeline change of the producer): those orders are never declared | timeline change | export orders with no declaration; the codes in `orders` against `export_countries` | map the code (and declare the missed orders) |
| `purpose-declaration-overlapping-window` | E2 | the dispatcher picks orders packed in the last ten minutes every five minutes, with no check for an existing declaration and no unique key: each export order declared twice | seed-file | two accepted references for one order | select undeclared orders; a unique idempotency key |
| `purpose-receiver-down-unnoticed` | E4 | the gateway stops acknowledging for two hours (a timeline change of its schedule) and the escalation job has no rule for missing acknowledgements | timeline change plus seed-file | declarations without acknowledgement or incident | escalate missing acknowledgements |
| `purpose-deadline-wrong-zone` | E1 | the deadline is computed as "before local end of day" in a zone off the customer's: late declarations look on time | seed-file | declarations later than two hours after `packed_at` | the deadline from `packed_at` |
| `governance-declaration-overshares` | E3, G4 | the declaration's payload carries the customer's e-mail and id | seed-file | payload keys against the gateway's schema | the listed fields only |

Moved to v0.5 (D201): `purpose-retry-without-key`, the dispatcher
resending unacknowledged declarations with a fresh key during a gateway
slowdown. Resending on a missing acknowledgement means waiting on it
with a timeout, which is the round trip, not v0.4's push.

## Governance (G1 to G4)

| Id | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|
| `governance-personal-copied` | G1 | the BI agency's churn dashboard keeps `rpt.customer_activity` with names and e-mails, refreshed by a job | seed-file (data file and runner) | the table in `reporting`; the policy | stop the job and drop or strip the table (O119) |
| `governance-fdw-imports-personal` | G1, G3 | `IMPORT FOREIGN SCHEMA` brought `src.customers` into `reporting`, and `shop_etl` may read it | seed-file (both data files) | `\det` in `reporting`; `shop_etl`'s grants | drop the foreign table and revoke |
| `governance-reader-not-allowed` | G2 | `bi_reader`'s login also reads `consent_events` through `PUBLIC` | seed-file | `has_column_privilege`; `\dp` | revoke from `PUBLIC` |
| `governance-statement-log-personal` | (settings, held) | `ALTER DATABASE shop SET log_statement = 'all'`: every outbox insert, e-mails included, in the logs and pgBadger | seed-file | the log and the report | redaction; held for v0.5 (governance.md) |

## Existing faults that fit

- `prometheus-scrape-target-missing` on the reporting instance's
  exporter, if it has one (O125).
- `pg-join-index-missing` on `consent_events (customer_id, at)`: the
  consent lookups of P2 and P3 crawl.
- v0.3's `scheduler-job-wrong-timezone` on a purpose job (the nightly
  close at the wrong hour), unchanged.

## Aging minima

A purpose fault's evidence shows at its job's runs: its definition's
minimum counts from the first run after planting, and the scenario
raises the instance's minimum to that offset (D189). Quarter-hour and
hourly jobs need an hour; the nightly close needs T0 to 01:30 plus one
run. A timeline-change fault counts from its moment.
