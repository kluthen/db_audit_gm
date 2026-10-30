# shop-sales-reporting — GM notes

P1 of v0.4 (master spec 10.1): the back office's sales figures, which the
shop's database used to roll up itself, now live in a reporting database
that a BI agency, Lumen Analytics, runs. A **pulled** purpose: published
results that readers query when they like.

## What it is for

The accountant and the back office read their revenue, orders and units
from the agency's dashboards, never from the shop's database. Two jobs on
the agency's transformer feed them, as an agency's newer loader beside its
older nightly procedure would:

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `rollup-hourly` | `5 * * * *` | transformer script `scripts/rollup.py:hourly`, `source` as `shop_etl`, `target` as `bi_etl` | the orders changed since the watermark (`updated_at`), read row by row from one snapshot of the source; their local hours (per category) and days recomputed whole and rewritten in `rpt.sales_hourly` and `rpt.sales_daily`, in one target transaction holding the run's `rpt.etl_runs` row and its new watermark |
| `rollup-close` | `30 1 * * *` | `CALL rpt.close_day()` on `reporting` as `bi_etl` | yesterday in the customer's zone (`rpt.business_settings`), its hours and its day recomputed from `src.*` over `postgres_fdw` and the day marked `closed`; one `rpt.etl_runs` row |

Both follow the placement guideline (master spec 8.7): the script's
row-by-row work runs on the transformer; the close is scheduled there but
computes on the receiving instance, one set-based procedure off-peak, the
shop's instance serving only the remote scan of one day.

A closed day keeps the close's orders and revenue: the hourly script then
moves only its invoiced revenue (the 12:00 invoicing invoices orders days
after they were placed). Its `run_id` stays the close's.

## What the material holds

Written for the first v0.4 scenario's names; adapt them when copying.

| File | Goes to | Names to adapt |
|---|---|---|
| `material/runner/queries.yaml`, `jobs.yaml`, `schedule.yaml`, `scripts/rollup.py` | the runner's (`bi`) seed files; `scripts/` as `seed_files: {scripts/: nodes/bi/scripts/}` | the schedule's targets `db:5432/shop`, `reporting:5432/reporting` |
| `material/consumer/queries.yaml`, `schedule.yaml` | merged into the consumer's (`consumer`) files | the target `reporting:5432/reporting`; the shape `dashboard-hours` if the node has one of that name |
| `material/target/data.sql` | the target node's (`reporting`) data file | the database `reporting`; the foreign server's `host 'db'`, `dbname 'shop'` |
| `checks/*.sh` | the sealed checks of the faults attached to the purpose | the constants at the top of each (`SOURCE`, `TARGET`, the job names) |

The data file creates the roles `reporting` (owner, no login), `bi_etl` and
`bi_reader`, the database, `postgres_fdw`, `rpt.business_settings` (one
row from load-data's variables, as the shop's own), `rpt.etl_runs`,
`rpt.sales_hourly` and `rpt.sales_daily` (each row's `run_id` the run that
wrote it), the foreign server `shop_db` owned by `postgres`, the only user
mapping (`bi_etl` to `shop_etl`, its password set by `load-data` from
`shop_etl`'s secret), the foreign tables `src.orders` (no `customer_id`),
`src.order_lines` and `src.products` with only the columns the close
needs, and the `SECURITY INVOKER` procedure, `EXECUTE` revoked from
`PUBLIC`. `bi_etl` has no `USAGE` on the server: it cannot change its
mapping. The published tables start empty: the first hourly run, right
after the data load, publishes the whole fifteen-day history (300 000
orders read, a few seconds).

The scenario must give: the shop's `pg_hba.conf` admitting `shop_etl`
from `bi` and `reporting`, the reporting node's admitting `bi_etl` from
`bi` and `bi_reader` from `consumer`, and, for the checks, `gm_check` from
the game network on both instances (`host all gm_check samenet
scram-sha-256`).

## How it goes wrong

The catalogue faults attached to it (master spec 16.2): the watermark on
`placed_at` (`purpose-watermark-misses-updates`, R1: an order invoiced at
noon never reaches reporting), the source role expired
(`purpose-etl-role-expired`, R4: both jobs refused, the dashboards
frozen), the close's day cut in the wrong zone
(`purpose-day-boundary-wrong-zone`, R3 and R2), and the personal data
copied into a churn table (`governance-personal-copied`, G1 and G3).
Other ways it breaks, for players' proposals: the script's two
connections committed separately (a crash between them doubles or loses a
run); an error swallowed into a clean-looking run; a dashboard query
summing something else than the published day (R5).

## The checks

One per invariant. R1 to R4 run on the runner (`bi`) as root, R5 on the
consumer. Each reads the runs with `check-runs` and the databases as
`gm_check` with `check-sql`; none runs a job. The judged moment is
`CHECK_SINCE` raised to the runner's last reload (`check-runs since`), the
same before and after the hand-over (spec D217). Exit 3's first line is
`remaining=<seconds to the job's next run>`.

- **R1 reconciled** (`checks/r1-reconciled.sh`). A bucket (an hour and
  category, a day) is compared at the latest run since the judged moment
  only when the source has not changed it since 60 s before that run's
  start (its last order placed, a day's last order invoiced): the source
  then stands as the run found it. A difference counts when the run due
  to publish it ran since the judged moment (the hourly run that wrote the
  bucket, or the first run after the source's last change); an older one
  is a past violation, left as evidence. A closed day is compared on its
  invoiced revenue only. Witness: a published hour of orders and a past
  day re-invoiced after it ended, both since the judged moment. **Under
  the watermark fault** a day is wrong once the noon invoicing touches it;
  after a hand-over at 14:00 the next counted invoicing is the next day's
  noon, so R1 reads 3 for the rest of a four-hour game and 1 at the
  hand-over check (judged since the planting moment). A fix of the script
  alone never restates the days it missed (an *improve*): those stay as
  past violations.
- **R2 counted once** (`checks/r2-counted-once.sh`): the rows a run since
  the judged moment wrote, of either job; a duplicated (hour, category) or
  a day whose revenue is not its hours' sum. The hourly run rewrites the
  current day every hour, so R2 has a witness within the hour.
- **R3 local days** (`checks/r3-local-days.sh`): the rows a run since the
  judged moment wrote, compared on what an order's placing fixes (orders,
  units, revenue) with the source's local hour or day (the source's
  `business_settings.timezone`), once the bucket was whole when the run
  read it. Witness: a whole day with orders in its first and its last
  local hour (any other cut moves them). The close runs at 01:30 only: a
  check after a 14:00 hand-over judges the hourly run's hours alone and
  has no day witness until the next night, so R3 reads 3 then; the
  hand-over check (since the planting moment) judges the night's close.
- **R4 fresh** (`checks/r4-fresh.sh`): a `run ... status=error` or a
  `skip ... reason=connection-refused` line of `rollup-hourly` since the
  judged moment (the program's own log parser), a run since then with no
  `rpt.etl_runs` row or reading no changed order between 08:00 and 20:00
  customer time, or a latest run older than 70 minutes or reading no row:
  present. Under the expired role the first refused run after the judged
  moment makes it 1; after `ALTER ROLE shop_etl VALID UNTIL 'infinity'`,
  give the fix's time to `gmctl check`, as in `gmctl check
  scenarios/tarnbeck-outdoor-campaign --playground class-a
  --since 2026-10-30T14:30:00Z`: the next run reads 0.
- **R5 dashboard faithful** (`checks/r5-dashboard-faithful.sh`), a
  definition, 0 or 1 only (master spec 12.6): the live repository's
  `dashboard.revenue` run read-only as `gm_check`, each day it shows
  against `rpt.sales_daily`. The query keeps the columns `day_local` and
  `revenue`; one that no longer runs, or shows nothing while days are
  published, is present.

Where a check cannot count its witness the purpose's design guarantees
it: the producer places orders every hour, night included (a tenth of the
noon peak), and invoices shipped orders at 12:00 every day.

Tested in the scheduler's unit-test harness (`tests/run-tests.sh`, about
fifteen minutes, under the host lock): the script moving the right rows
at a shift of +5, the close closing yesterday right, each check 0 on clean
runs, 3 with no run since `CHECK_SINCE`, and 1 on a crafted violation
(the close cut three hours off, the script's watermark on `placed_at`, the
source role expired, a dashboard showing invoiced revenue as revenue).

## Feedback notes

- Reading the script, not only the job: which column the watermark is
  on, whether the target's writes and the watermark share one
  transaction, what the source role may read whatever the code selects
  (access model 9.2).
- A user mapping is a credential: its remote role's reach is the
  reporting database's reach (`\deu+`, `pg_user_mappings`).
- A stored procedure's zone, its `SECURITY` mode and who may execute it.
- Reconciling published figures with the source needs the source's state
  at the run, not now: good reports compare closed periods.
- The agency's nodes are report-only by the story (master spec 16.5):
  their findings are *propose* or *report*.
