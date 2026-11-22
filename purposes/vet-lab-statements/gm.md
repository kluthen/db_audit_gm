# Purpose 10, the lab's statements: GM notes

The practices' monthly statements (v0.5 master spec 11.3, 12.1, 12.2
purpose 10; v0.5's `clinic-purposes.md`
section 14; vet-lab rule 13; spec D294, D300, D304, D436): **pulled,
periodic**. Published in the back office's database `office`: each
practice's charges fed daily from the laboratory's database, its statement
on the 1st. A design-time source: copy the material into a scenario and
adapt the names there.

## What it is for

The lab bills the region's practices (vet-lab rule 13): each test at the
price of its order's day, a handling fee per order, half again when urgent,
billable once released, voided on a cancellation or an unfit sample; the
month's charges gathered into each practice's statement with a volume
discount of 3 to 15 % by the month's total. The centre's own account is
never charged. A feeder copies yesterday's charge events into `office` at
night; on the 1st each account's statement follows. The lab has **no
standby** (D304): the jobs read its only node, at night, as `lab_reports`.

## The material

Written for the clinic's mapping: `source` `lab/lab`, `target`
`records/office`, `runner` `backoffice`.

| File | Copied to | What |
|---|---|---|
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml), [`queries.yaml`](material/runner/queries.yaml), [`schedule.yaml`](material/runner/schedule.yaml), [`scripts/lab_statements.py`](material/runner/scripts/lab_statements.py) | the report runner's files (scenario layer `compose/backoffice/`) | the two jobs below; connections `lab-reports` (`lab:5432/lab` as `lab_reports`, purpose 9's identical entry) and `office` (`records:5432/office` as `office_jobs`), pool 1 each |
| [`material/target/office.sql`](material/target/office.sql) | the head of the purposes' share of `records`' data file, once | `office`, `office_jobs`, `office_reader`, the database `office`, its `runs` and `regulatory_submissions`; byte-identical in purposes 5, 7, 8, 9, 10 and 12 (W4 item 5) |
| [`material/target/data.sql`](material/target/data.sql) | after `office.sql` in `records`' data file | `lab_charge_lines`, `lab_statements`; `office_jobs` `SELECT, INSERT`, `office_reader` `SELECT` |
| [`material/history.sql`](material/history.sql) | nothing: `history:`, read from the catalogue by `load-data` | the planted past (below) |

No `ddl:`: the purpose adds nothing to `lab`; `lab_reports` reads every lab
table by vet-lab's own grant.

**Names to adapt** when copying: the lab's node in `lab-reports`, the
primary in `office`; `LAB` and `OFFICE` in the checks.

## The jobs

| Job | Key | Cadence | What |
|---|---|---|---|
| `feed-lab-charges` (feeder) | `charges.feed` | `30 2 * * *` | yesterday (local, the lab's settings) read by `charges.feed.read`: each practice's charge made billable that day (`billable_on`, the release's date) and each voided that day, one line each (`event` `billable` or `void`): its order, test, kind, amount, the order's patient reference and client surname |
| `close-lab-statements` | `charges.close` | `0 4 * * *`, acting on the 1st | each practice account's statement for the past month (`charges.close.compute`, on `office`): billable lines and their sum, less the month's voids of charges stated by the month's end, the bracket by the total, the discount on the total rounded once, the amount due |

**The brackets** (game values, in `charges.close.compute` and ST3's rule):
3 % from 0, 5 % from 200, 10 % from 400, 15 % from 600 (the month's
total, in the price list's currency).

Each periodic job runs daily and does nothing, **writing neither output
nor `runs` row**, unless the customer's local date is its own (spec D436);
a month already stated is not closed again. The feeder writes its day once:
a day `office` already holds is skipped (its `runs` row says 0 written).
Every run writes one `runs` row in the transaction of its output. The
scripts read the SQL keys from the runner's `queries.yaml` at each run:
**the queries are the jobs' code**, the place a fault edits.

**The planted past** (`history.sql`, W4 item 5): from the history's first
charge event, each feeder's day `d` when `d + 1` at 02:30 is before
`load_epoch`, each month's statements when its next 1st at 04:00 is; each
run its `runs` row. A T0 before 02:30 finds yesterday unplanted, the
feeder's to write.

**Seen on the load** (for the GM): the lab's loaded charges are voided only
before they are billable (a cancelled or unfit test is never released), so
the planted statements' `voided` is 0; a void after billing comes from a
fault or the GM's own edit.

## The invariants and where they run

| Id | Judged | Reads |
|---|---|---|
| ST1 | runs | `feed-lab-charges`' runs; `lab_charges`, `lab_accounts` (the lab); `lab_charge_lines` |
| ST2 | runs | the same runs; the centre's accounts and orders (the lab); `lab_charge_lines`, `lab_statements` |
| ST3 | code | `close-lab-statements`' code as loaded (`jobs.yaml`, `queries.yaml`), run read only on `office` for the last planted month, against the check's own rule; any statement written since the judged moment |

All on the report runner (`backoffice`), as root, `check-runs` and
`check-sql` as `gm_check` on `lab` and on the primary's `office`, each
guarding its reads (spec D432, exit 2). A day is the run's yesterday,
local. ST3 never judges the planted figures: a fix to the code leaves
them, and the players recommend the rerun (master spec 12.1).

## The faults this purpose carries

From v0.5's `clinic-purposes.md`
section 14 (the selection is the scenario's): the feeder run at bench hours
(`jobs.yaml`); voids taken only for charges made the same day
(`charges.feed.read`, ST1); a charge at today's price (the lab's own
charge, then the feeder's next run); the discount applied per line
(`charges.close.compute`, ST3).

## Trace

`office`'s two tables and `runs`; the runner's log (counts and dates only,
never a patient reference or a surname).

## Data moved

`lab_orders.patient_ref` and `client_surname` (personal) into
`office.lab_charge_lines`: the practice's statement lists its own clients'
orders.

## Fixture

`tools/tests/fixtures/fixture-reports/` (chunk 20): the feeder moved to the
next minute writing yesterday once from `lab`, the close run on a date not
its own; ST1 to ST3 exit 0 unfaulted.
