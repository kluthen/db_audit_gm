# Purpose 12, the working-time record: GM notes

The record a labour inspector may ask for (v0.5 master spec 11.3, 12.1,
12.2 purpose 12; v0.5's `vet-scheduling-domain.md`,
purpose 12; Directive 2003/88/EC; CJEU C-55/18 *CCOO*; spec D265, D300,
D436): **pulled, periodic**. Fed daily into `office` from the record's
standby (vet-scheduling's shifts, the core's staff), summed monthly. A
design-time source: copy the material into a scenario and adapt the names
there.

## What it is for

The employer records each worker's daily working time objectively: the
clocked hours, not the plan. The feeder runs at **09:30**, once yesterday's
night shifts (ending 07:30 or 08:00) are clocked out (T124), and writes per
staff member and day the shifts, the planned hours (on call excluded), the
hours worked as clocked (an on-call shift only for its call-out, the
clinic's reading of the case law), the night shifts' hours and the
call-outs; and each **short rest**, under `sched_settings.min_rest_hours`
(11), between two shifts on site, whatever their days (T121). On the 1st
the month per staff member, with the weekly average over the last four
months.

**On call takes no part in the rests** (the reading taken here): the rota
leaves no short rest between shifts on site, and the history plants none;
counted with their call-outs, the on-call shifts would make about 500 a
year (a call-out ends about six and a half hours before the next day
shift), which the spec's "the rota leaves none" rules out.

## The material

Written for the clinic's mapping: `source` `records/clinic` (read on the
standby), `target` `records/office`, `runner` `backoffice`.

| File | Copied to | What |
|---|---|---|
| [`material/runner/`](material/runner/) (`jobs.yaml`, `queries.yaml`, `schedule.yaml`, `scripts/working_time.py`) | the report runner's files (`compose/backoffice/`) | the two jobs; connections `sched-reports` (`standby:5432/clinic` as `sched_reports`), `clinic-reports` (`vet_reports`, the names), `office` (`office_jobs`) |
| [`material/target/office.sql`](material/target/office.sql), [`data.sql`](material/target/data.sql) | `records`' data file, `office.sql` once | `office` (W4 item 5); `working_time_days`, `rest_breaches`, `working_time_months` |
| [`material/history.sql`](material/history.sql) | nothing: `history:` | the planted past |

No `ddl:`: `sched_reports` and `vet_reports` read the shifts and the
staff by their domains' grants. **Names to adapt**: the standby and the
primary in the connections, `CLINIC` and `OFFICE` in the checks.

## The jobs

| Job | Key | Cadence | What |
|---|---|---|---|
| `feed-working-time` (feeder) | `worktime.feed` | `30 9 * * *` | yesterday (local): `worktime.feed.read` and `worktime.feed.rests` as `sched_reports`, `worktime.feed.staff` as `vet_reports`; the day written once |
| `close-working-time` | `worktime.close` | `0 5 * * *`, acting on the 1st | the past month per staff member from the daily rows (`worktime.close.compute`) |

A run on another date writes neither output nor `runs` row (spec D436).
**The planted past**: every day from the history's first shift when its
09:30 run is before `load_epoch`, every month whose next 1st's 05:00 run
is: about 19 800 days, 1 000 months, no breach.

## The invariants and where they run

| Id | Judged | Reads |
|---|---|---|
| WT1 | runs | the feeder's runs; `sched_shifts` started on the day; `working_time_days` |
| WT2 | runs | the same runs; the shifts' short rests; `rest_breaches` |
| WT3 | code | `close-working-time`'s code as loaded, run read only on `office` for the last planted month; any run since the judged moment |

All on the report runner, as root, through `check-runs` and `check-sql`
as `gm_check`, guarded (spec D432).

## The faults this purpose carries

From vet-scheduling-domain.md step 8 (the selection is the scenario's):
T121 rests compared within a day (WT2; `worktime.feed.rests`), T123
planned hours for clocked (WT1), T124 the feeder moved into the night or
its day in UTC (WT1; `jobs.yaml`, the bounds), T125 on call counted whole
(WT1).

## Trace

`working_time_days`, `rest_breaches`, `working_time_months`, `runs`; the
runner's log (counts and dates only, never a name).

## Fixture

`tools/tests/fixtures/fixture-reports/` (chunk 20).
