# Purpose 9, the head office's figures: GM notes

The centre's monthly activity figures to the franchise's head office
(v0.5 master spec 11.3, 12.1, 12.2 purpose 9;
v0.5's `clinic-purposes.md`
section 13; one-centre 1; vet-housing O189; spec D300, D318, D436): a
**pushed obligation, periodic**. The figures are fed daily into the back
office's database `office`, the back office's own business report; the
month's go to the head office by the 5th, answered with a reference. A
design-time source: copy the material into a scenario and adapt the names
there.

## What it is for

Each centre owes the franchise's head office its month's activity figures
by the 5th. A feeder copies yesterday's figures into `office` at 00:30, one
row per section and measure; from the 1st to the 5th a daily run posts the
past month to the head office's stub, kept with its reference, retried each
morning, escalated on the 5th if still unanswered. The record and housing
are read on the **standby** (master spec 11.1), the lab on its only node
(it has no standby, D304).

## The material

Written for the clinic's mapping: `source` `records/clinic` (read on its
standby, `standby`), `source_lab` `lab/lab`, `target` `records/office`,
`runner` `backoffice`, `receiver` `partners-api` (hostname `head-office`).

| File | Copied to | What |
|---|---|---|
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml), [`queries.yaml`](material/runner/queries.yaml), [`schedule.yaml`](material/runner/schedule.yaml), [`scripts/head_office_figures.py`](material/runner/scripts/head_office_figures.py) | the report runner's files (scenario layer `compose/backoffice/`) | the two jobs below; connections `clinic-reports` (`standby:5432/clinic` as `vet_reports`), `lab-reports` (`lab:5432/lab` as `lab_reports`), `office` (`records:5432/office` as `office_jobs`), identical to purposes 7, 8, 10 and 12's entries, and `headoffice` (`http`, `head-office:8000`, the customer's key `headoffice_customer`) |
| [`material/target/office.sql`](material/target/office.sql) | the head of the purposes' share of `records`' data file, once | `office`, `office_jobs`, `office_reader`, the database `office`, its `runs` and `regulatory_submissions`; byte-identical in purposes 5, 7, 8, 9, 10 and 12 (W4 item 5) |
| [`material/target/data.sql`](material/target/data.sql) | after `office.sql` in `records`' data file | `daily_figures`, `monthly_figures`; `office_jobs` `SELECT, INSERT` and `UPDATE` of the send columns, `office_reader` `SELECT` |
| [`material/history.sql`](material/history.sql) | nothing: `history:`, read from the catalogue by `load-data` | the planted past (below) |
| [`material/receiver/headoffice/`](material/receiver/headoffice/) (`api.yaml`, `routes/`, `db/`, `queries.yaml`, `schedule.yaml`, `data.sql`) | `api.yaml`, `routes/`, `db/` into `compose/partners-api/`; `queries.yaml`, `schedule.yaml` into `compose/partners-backend/`; `data.sql` after the partners' shared `data.sql` (and any other stub's) in `partners-db`'s data file | the head office's stub (prefix `headoffice`): `POST /figures` under `head-office` behind `headoffice_customer`, a reference `HO<YYYYMM>-NNNN` per month (a repeat answers the same), one call in fifty 503; its role `headoffice`, schema, state, `headoffice.figures` and `headoffice.figure_calls`; the baseline stream `headoffice.normal` |

No `ddl:`: the purpose adds nothing to `clinic` or `lab`; `vet_reports` and
`lab_reports` read every table by their domains' own grants (housing's
tables by vet-housing's). The fixture's `partners-db` `pg_hba.conf` lists
the role `headoffice` on the partners' line.

**Names to adapt** when copying: the standby, the lab and the primary in
the connections, the head office's hostname; `CLINIC`, `LAB` and `OFFICE`
in the checks (the checks read the primary).

## The jobs

| Job | Key | Cadence | What |
|---|---|---|---|
| `feed-daily-figures` (feeder) | `figures.feed` | `30 0 * * *` | yesterday (local), one row per section and measure: per section (its kind: `horse`, `farm`, `domestic`) the consultations begun per kind (`consultations.<kind>`), `admissions`, `discharges` (the stays ended), `stays.midnight`, `units.occupied` and `units.in-service` at the day's closing midnight (`figures.feed.read`, on the standby); `centre` `owners.new`, `animals.new`; `lab` `tests.<discipline>.<priority>` (released), `orders.outside` (the practices' orders placed), `turnaround.outside.median-minutes` (receipt to release of their tests released; none on a day without) (`figures.feed.lab`, on the lab) |
| `send-monthly-figures` | `figures.send` | `0 5 * * *`, acting on the 1st to the 5th | the past month's figures (`figures.send.compute`, on `office`: each measure summed over its days, the turnaround the median of its days'), computed on its first run and kept in `monthly_figures`, posted to `POST /figures` (three attempts a run); acknowledged: the reference on the month's rows; unanswered after the 5th's attempts: `escalated_at`; a month acknowledged or escalated is not sent again |

Each periodic job runs daily and does nothing, **writing neither output
nor `runs` row**, unless the customer's local date is its own (spec D436).
The feeder writes its day once: a day `office` already holds is skipped
(its `runs` row says 0 written). Every run writes one `runs` row in the
transaction of its output. The scripts read the SQL keys from the runner's
`queries.yaml` at each run: **the queries are the jobs' code**, the place a
fault edits.

**The planted past** (`history.sql`, W4 item 5): from the history's first
consultation, each feeder's day `d` when `d + 1` at 00:30 is before
`load_epoch`, each month's figures when its next 1st at 05:00 is,
acknowledged at once with the reference its stub gives live,
`HO<YYYYMM>-NNNN` (D451: the figures' month, the stub's count); each run its
`runs` row. The feeder runs at 00:30, so **a T0 before 00:30 local** (and a
`load_epoch` before it, the same night) finds yesterday unplanted, the
feeder's to write; a later T0 finds it planted, and a moved feeder writes 0.

## The invariants and where they run

| Id | Judged | Reads |
|---|---|---|
| HO1 | runs | `feed-daily-figures`' runs; the record's and housing's tables (the primary), the lab's; `daily_figures` |
| HO2 | runs | the same runs; the centre's sections, the lab's catalogue (the grid); `daily_figures` |
| HO3 | code | `send-monthly-figures`' code as loaded (`jobs.yaml`, `queries.yaml`: its days, its computation run read only on `office` for the last planted month), against the check's own rule; every month past its 5th acknowledged or escalated; any month sent since the judged moment |

All on the report runner (`backoffice`), as root, `check-runs` and
`check-sql` as `gm_check` on the primary's `clinic` and `office` and on
`lab`, each guarding its reads (spec D432, exit 2). A day is the run's
yesterday, local. HO3 never judges the planted figures: a fix to the code
leaves them, and the players recommend the rerun (master spec 12.1).

## The faults this purpose carries

From v0.5's `clinic-purposes.md`
section 13 (the selection is the scenario's): the stays counted when the
feeder runs, not at midnight (`figures.feed.read`, HO1); the turnaround's
median taking cancelled and unperformed tests (`figures.feed.lab`, HO1);
`office_jobs` holding write grants on `clinic` (the grants); the runner's
role on the standby expired (the role; HO1 and HO2 find no run); out-of-
service units counted as available (`figures.feed.read`, HO1; vet-housing
T171).

## Trace

`office`'s two tables and `runs`; the head office's `headoffice.figures`
and `headoffice.figure_calls`; the runner's log (counts, dates, keys and
statuses only).

## Fixture

`tools/tests/fixtures/fixture-reports/` (chunk 20): T0 before 00:30 local,
the feeder moved to the next minute writing yesterday once from the standby
and the lab, the send run on a date not its own; HO1 to HO3 exit 0
unfaulted.
