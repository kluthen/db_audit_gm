# v0.4 — candidate faults

Status: draft v4

Faults that break the purposes' invariants
([purpose-catalogue.md](purpose-catalogue.md)) and the governance rules
([governance.md](governance.md)). Candidates, not a list to build: which
ship follows the purposes (D197) and the scenario ([scenario-sketch.md](scenario-sketch.md)).
Ids are working names. Every one is planted as v0.3's are: a
`seed-file` change at render (to a runner's `queries.yaml`, a
transformer script or `jobs.yaml`, or a database node's data file,
`postgresql.conf` or `crontab`), a `state` change during the
aging, or a timeline change of a schedule (D127) for an outside party's
behaviour.

Families: `data-flow` (v0.3's family for duplicates and dropped records),
`rules` (as v0.3's wrong-time-zone fault), `security` (governance,
proposed in governance.md).

## Sales reporting (P1)

| Id | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|
| `purpose-watermark-misses-updates` | R1 | the hourly script picks rows by `placed_at` past the watermark, so an order invoiced at the noon close never reaches reporting: invoiced revenue in `rpt` lags the source, more each day | seed-file, the script | the script's query; `rpt.sales_daily.invoiced_revenue` against the source's per day | watermark on `updated_at`; restating the affected days is an *improve* |
| `purpose-rerun-double-counts` | R2 | the hourly load inserts the overlapping hours again with no delete or upsert: hours that straddle two runs counted twice | seed-file | duplicate (hour, category) rows; day ≠ sum of hours | delete-and-insert per hour, or a unique key and upsert; remove the duplicates |
| `purpose-day-boundary-wrong-zone` | R3 | the day is cut in a zone N hours off the customer's (`offset` parameter, never 0; render writes it, O122) | seed-file | daily totals shifted against the source's local days; the zone in the SQL | the customer's zone from `business_settings` |
| `purpose-etl-role-expired` | R4 | `shop_etl`, the hourly script's source role and the user mapping's remote role, gets `VALID UNTIL` a moment during the aging: every run of either job since fails with 28P01, the dashboards freeze | state, `plant_at: handover-<N>h` | the runner's log; `etl_runs` stops; `\du` on the source | `ALTER ROLE … VALID UNTIL 'infinity'` (or a new password in the role, the schedule's secret and the mapping) |
| `purpose-dashboard-fanout` | R5 | the dashboard's revenue query sums `orders.total` over a join with `order_lines`: each order counted once per line | seed-file, the consumer's `queries.yaml` | the query; its figure against `rpt.sales_daily` | sum before the join, or read `rpt` |

## Movement methods (D202)

Faults of the way data moves between instances, beside what it computes.
Each method has its own (purposes.md, "Moving data between instances").

| Id | Method | Breaks | What is wrong | Planted | Evidence | Fix |
|---|---|---|---|---|---|---|
| `purpose-script-watermark-not-atomic` | script | R1, R2 | the script commits the rows to `reporting`, then moves the watermark kept in the source in a second transaction; a run failing between the two loads the same hours again, and one failing after a partial batch commit leaves a gap | seed-file, the script (and a `state` change making one run fail, or a timeline change on the source) | duplicate or missing hours after an `error` run; the script's two commits | the watermark in the target's transaction; delete-and-insert per hour |
| `purpose-script-swallows-errors` | script | R4 | the script catches every exception, logs nothing and returns 0: a failing source query looks like a quiet hour, `status=ok rows=0` | seed-file, the script, with a failure (a column renamed by a producer release, a timeline change) | `rows=0` runs in business hours; `etl_runs` with no row read; the `except` | let it fail, or log and re-raise |
| `security-fdw-mapping-public` | foreign tables | G3 | the user mapping is `FOR PUBLIC`: `bi_reader`, the dashboards' role, reads the shop's orders through `src.*` as `shop_etl` | seed-file, `reporting`'s data file | `\deu+`; `pg_user_mappings`; a query as `bi_reader` | a mapping for `bi_etl` only |
| `security-fdw-server-owned-by-reader` | foreign tables | G3 | the foreign server is owned by `bi_reader`, which therefore sees every mapping's password in `pg_user_mappings` and may add mappings | seed-file, `reporting`'s data file | `\des+`; `pg_user_mappings` read as `bi_reader` | the server owned by an administrative role; rotate `shop_etl`'s password |
| `security-definer-procedure-open` | stored procedure | G3 | `rpt.close_day()` is `SECURITY DEFINER`, owned by a role holding the mapping, with `EXECUTE` left to `PUBLIC` and no `SET search_path`: any `reporting` login runs it, or shadows the objects it names | seed-file, `reporting`'s data file | `\df+`; `proacl`; `proconfig` | `SECURITY INVOKER`, or `EXECUTE` revoked from `PUBLIC` and `SET search_path` |
| `purpose-pg-cron-hidden-job` | `pg_cron` | G1, or a purpose's invariant, by what the job does | a job in `cron.job` that no runner lists and no document names: for example the agency's refresh of `rpt.customer_activity` through the foreign tables (the sketch's f9) | seed-file, the data file (`cron.schedule_in_database`) and the seed's preload | `cron.job`; `cron.job_run_details`; `cron.log_statement` lines in the log | `cron.unschedule`, and undo what it wrote (O119) |
| `security-pg-cron-superuser-job` | `pg_cron` | G3 | the superuser scheduled the job with no `username`, so it runs as `postgres` and its SQL reaches every table and every user mapping; `cron.enable_superuser_jobs` left on | seed-file, the data file | `cron.job.username`; the setting | `cron.alter_job(…, username => <role>)` to a role holding the job's grants; `cron.enable_superuser_jobs = off` |
| `security-crontab-superuser` | cron daemon | G3 | the entry runs `psql` with no user, so as `postgres` by peer: a superuser for a job a narrow role could run (the role, its grant and its password file exist, never switched to) | seed-file, the crontab | `gm-crontab -l`; `pg_stat_activity` during a run; the role prepared and unused | connect as the job's role (`-U`, the password file); its check reads the live crontab and requires the entry's role to be no superuser (exit 0 or 1) |
| `security-crontab-credentials` | cron daemon | G3 (a credential exposed) | the entry carries the role's password (`PGPASSWORD=…`, or a connection URI holding it): in the crontab, and in `ps` while the job runs | seed-file, the crontab, `render` writing the role's password into it (new, below) | the entry; `ps -ef` during a run | the password file; the role's password rotated |
| `purpose-crontab-stale-target` | cron daemon | R4, or the purpose's freshness invariant | the entry still names a database since renamed or moved, so every run fails | seed-file, the crontab | the job's log, if it keeps one; the target's rows stop | the right target |
| `purpose-cron-output-lost` | cron daemon, or `pg_cron` | R4 | the entry redirects nothing, so a failing run leaves no trace: no mail, no syslog; for `pg_cron`, `cron.log_run = off` | seed-file, planted with a failure (the stale target), as `purpose-script-swallows-errors` is | no log; the trace stops | log to a file the team reads; fail loudly |

The jobs on a database node come with `postgres` 0.4.0 (D206;
[database-node-jobs.md](database-node-jobs.md)).
`security-crontab-credentials` needs `render` to write a role's
password into a seed file, for that fault's seed change only (proposed).
The same capability would release the fault held for scripts:
credentials written into a script, against the script's contract
(purposes.md, "The transformer script"). It stays held. An
**undersized transformer** (a script outgrowing its node's memory and
taking the runner down) is a later fault, in v0.5's catalogue and the
capacity family after v1.0 (D204, D205).

## Placement (D207)

Faults of where a job runs, against the placement guideline (light,
well-scheduled work on a database node; heavy or row-by-row work on a
transformer node; heavy work on the source instance the worst;
[database-node-jobs.md](database-node-jobs.md), "Placement"). They break
no purpose invariant.

| Id | What is wrong | Planted | Evidence | Resolution |
|---|---|---|---|---|
| `purpose-heavy-job-on-database-node` | a heavy transformation runs from a database node's crontab; a one-off backfill makes it exhaust the node's memory **once, during the aging**: its backend OOM-killed, PostgreSQL recovering by itself (D209) | seed-file, the crontab, at T0; a `state` change, the backfill request, at a planned moment before its run | the kill and the recovery in the log; `oom_kill` in `memory.events`; the statistics' reset time; the job's log and ledger; the request | *report*: the incident, its cause, and moving the transformation to a transformer node (D207); its check judges the incident, not a live state ([database-node-jobs.md](database-node-jobs.md), "The out-of-memory incident") |
| `purpose-database-node-job-at-peak` | a database node's job is scheduled in the shop's peak hours | seed-file | latency and CPU at the peak; the job's statements in the log at those times | *fix*: schedule it off-peak |

The heavy job's earlier form, a job that is merely heavy with no
incident, is folded into the first: without the incident it is a
performance finding with little evidence a player can tie to it.

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
| `governance-script-source-role-too-broad` | G3 (then G1) | the hourly script's `source` names the schedule's connection as `shop_reports`, which reads names and e-mails, rather than the one as `shop_etl` | seed-file, `jobs.yaml` (the schedule holds both connections) | `pg_stat_activity` on the source during a run; `shop_reports`' grants | `source` set back to the `shop_etl` connection in `jobs.yaml` |
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
