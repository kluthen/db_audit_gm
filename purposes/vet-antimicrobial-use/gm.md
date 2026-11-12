# Purpose 8, the antimicrobial use: GM notes

The yearly antimicrobial-use report to the authority (v0.5 master spec
11.3, 12.1, 12.2 purpose 8; [clinic-purposes.md](../../specs/versions/v0.5/clinic-purposes.md)
section 12; core rule 4; spec D436): a **pushed obligation, periodic**. Fed
daily into `office` for every species from the record's standby; on 15
January last year's report for the species due, posted to the authority,
which answers with a reference. A design-time source: copy the material
into a scenario and adapt the names there.

## What it is for

The law asks for a yearly report of the antimicrobials used per species,
species by species as they fall due: the cattle today, sheep, goats and
horses from mid-2027, dogs and cats from mid-2030 (core rule 4). The
feeder sums yesterday's doses given and dispensings of antimicrobials per
species and ATCvet code; a **herd treatment** (a herd visit's prescription:
a herd, no animal) counts under its herd's species, the trap of AM2. The
report sums the year's daily rows for the species due, posts them, keeps
the authority's reference and a copy in `regulatory_submissions` (kind
`amu-report`), deadline 31 January (a game value).

## The material

Written for the clinic's mapping: `source` `records/clinic` (read on the
standby), `target` `records/office`, `runner` `backoffice`, `receiver`
`partners-api` (hostname `authority`).

| File | Copied to | What |
|---|---|---|
| [`material/runner/`](material/runner/) (`jobs.yaml`, `queries.yaml`, `schedule.yaml`, `scripts/antimicrobial_use.py`) | the report runner's files (`compose/backoffice/`) | the two jobs; connections `clinic-reports` (`standby:5432/clinic`, `vet_reports`), `office` (`office_jobs`), `authority` (`http`, `authority:8000`, `authority_customer`: purpose 5's entry) |
| [`material/target/office.sql`](material/target/office.sql), [`data.sql`](material/target/data.sql) | `records`' data file, `office.sql` once | `office` (W4 item 5); `antimicrobial_use`, `amu_reports` |
| [`material/history.sql`](material/history.sql) | nothing: `history:` | the planted past |
| [`material/receiver/authority/`](material/receiver/authority/) (`api.yaml`, `routes/`, `db/`, `queries.yaml`, `schedule.yaml`, `data.sql`) | `compose/partners-api/`, `compose/partners-backend/`; `data.sql` in `partners-db`'s data file | the authority's yearly-report route, `POST /amu-reports` behind `authority_customer`: `authority.amu_reports`, `authority.amu_report_calls` |

**The authority is one prefix for two purposes** (W4 item 0): purpose 5
ships the same folder with its notifications route. The block between
`-- authority: begin` and `-- authority: end` of `data.sql`, `queries.yaml`
and `schedule.yaml` are byte-identical in both (`tools/tests/test_purposes.py`
compares them); the call counter `authority.calls` and its 503 one call in
fifty are shared by both routes.

**Names to adapt**: the standby and the primary in the connections, the
authority's hostname, `CLINIC` and `OFFICE` in the checks.

## The jobs

| Job | Key | Cadence | What |
|---|---|---|---|
| `feed-antimicrobial-use` (feeder) | `amu.feed` | `0 2 * * *` | yesterday (local), `amu.feed.read`: per species and ATCvet code, doses, dispensings, quantity, animals and herds treated |
| `report-antimicrobial-use` | `amu.report` | `0 4 * * *`, acting on 15 January | last year's report per species due (options `due`), summed on `office` (`amu.report.compute`), posted up to three times while the authority answers 5xx or not at all; acknowledged: its reference and the copy; still not: escalated at once (`escalated_at`) |

A run on any other date writes neither output nor `runs` row (spec
D436). The feeder writes its day once. **The planted past**: every day
from the history's first use when its 02:00 run is before `load_epoch`,
and each 15 January's report before it (last year's, the cattle's, 11
lines), referenced as the authority's stub references live,
`AMU<year>-NNNN` (D451: the year posted, the stub's count), and copied.

## The invariants and where they run

| Id | Judged | Reads |
|---|---|---|
| AM1 | runs | the feeder's runs; the day's antimicrobial doses and dispensings; `antimicrobial_use` |
| AM2 | runs | the same; each herd treatment under its herd's species (witness: a Tuesday's or Thursday's herd visits) |
| AM3 | code | `report-antimicrobial-use`'s code as loaded (its `due` option, `amu.report.compute`) for the last reported year, against the rule and the daily rows; any report sent since the judged moment |
| AM4 | triggers | `amu_reports` past their deadline or sent since the judged moment: acknowledged or escalated by the deadline |

All on the report runner, as root, through `check-runs` and `check-sql`
as `gm_check`, guarded (spec D432). AM3 and AM4 judge January's report:
the planted one, or a run the GM places.

## The faults this purpose carries

From clinic-purposes.md section 12: herd prescriptions dropped by a join
on `animals` (AM2, AM1; `amu.feed.read`, the planted report under-reported
too: chunk 24's s3 rewrites it); prescriptions counted instead of doses and
dispensings (AM1); the species filtered on `bovine` (AM3; the `due`
option or `amu.report.compute`); the feeder at the base backup's hour
(`jobs.yaml`).

## Trace

`antimicrobial_use`, `amu_reports`, `regulatory_submissions` (kind
`amu-report`), `runs`; the runner's log; the stub's `authority.amu_reports`
and `authority.amu_report_calls`.

## Fixture

`tools/tests/fixtures/fixture-reports/` (chunk 20).
