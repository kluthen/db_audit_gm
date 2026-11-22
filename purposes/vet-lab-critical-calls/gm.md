# vet-lab-critical-calls — GM notes

Purpose 6 of v0.5 (master spec 12.2;
v0.5's `clinic-purposes.md` section
10; capture W4 items 0 and 3). A **pushed obligation** whose receiver is
the person owed the call: a critical result (the trigger) owes a call to the
requesting vet or the practice within 60 minutes (the deadline, lab rule
6), its read-back the acknowledgement, an escalation to the on-call
pathologist when none comes. The call itself is a person's, recorded by the
information system's `lab.critical.call` stream (`vet-lab`); the purpose is
the obligation's **watch**. Fits `vet-lab`.

## Parts and the watch

| Part | The clinic's | |
|---|---|---|
| `source`, `target` | `lab/lab` | the results and their calls read, the watch's incidents and runs written, as `lab_watch` |

No runner: the watch is light, set-based work on the database node, the
placement the guideline allows (v0.4 master spec 8.7).

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `watch-critical-calls` | `*/10 * * * *` | `pg_cron` in `lab`, job name `lab-critical-calls`, as `lab_watch` | one statement: an `ops.incidents` row (`kind` `uncalled`, `ref` the result's id) for each result flagged `critical-low` or `critical-high`, measured more than 60 minutes ago (and within the week), with no read-back call and no incident yet, and the run's `ops.runs` row, in one transaction |

**The lab's `pg_cron` lives in `lab` itself** (W4 item 3): the node's seed
`postgresql.conf` preloads it (`shared_preload_libraries` with `pg_cron`,
`cron.database_name` the lab's database, `cron.timezone` the customer's,
`cron.log_run = on`, `cron.use_background_workers = on`), and the
purpose's DDL creates the extension and schedules the watch there, in its
own database (`cron.schedule_in_database(..., current_database(),
'lab_watch')`). `load-data`'s survey then finds `pg_cron` in `lab`: the
read policy `gm_check_read` on `cron.job` and `cron.job_run_details`, and the
launcher's start-up lines cleaned up. A scenario placing `vet-lab` must so
preload `pg_cron` on its node, `cron.database_name` naming the database its
`at:` gives.

## What the material holds

`material/target/ddl.sql` (`ddl.target`): the `ops` schema (the shared
block, byte-identical in every purpose, `tools/tests/test_purposes.py`),
`CREATE EXTENSION IF NOT EXISTS pg_cron`, `lab_watch` (guarded, `LOGIN`:
pg_cron's background worker connects as it; `CONNECT` on `lab`), its
grants (`SELECT` on `lab_results`, `lab_critical_calls`,
`lab_order_tests`; the `ops` tables), and the watch's schedule. Read by
`load-data` at step (2b) from the catalogue, in the database the scenario
maps `target` to; the watch then runs from the load on.

## Trace and checks

`ops.incidents` (each row's `run_id`) and `ops.runs` (`id`). Outside the
trace, as evidence: `lab_results`' flags, `lab_critical_calls`, and
`cron.job_run_details` (the watch's runs, `cron.log_run` on; v0.4 master
spec 12.5).

The purpose has no runner, so its checks run on **the lab's database
node** (the target part's), as root, with `CHECK_SINCE` as given (no
runner's reload raises it), reading `lab` through `check-psql` as
`gm_check` (W4 item 0, "Where a check runs").

| Invariant | Judged | Check | Witness |
|---|---|---|---|
| CC1 each critical result read back within 60 minutes, or an incident by the next watch run | triggers | `checks/cc1-called-or-escalated.sh` | a critical result measured since the judged moment, its hour passed |
| CC2 one incident per uncalled result | runs | `checks/cc2-one-incident.sh` | an incident since the judged moment and a watch run after it |

CC2 also reads a watch with no successful run recorded for two cadences as
present: nothing then shows it alive (`cron.log_run` off, the job inactive,
or failing).

## Candidate faults (traps; a scenario's are the GM's to select)

| Candidate | What the players find | Fixed on |
|---|---|---|
| The watch scheduled by the superuser, `cron.job.username` `postgres` | a job running as superuser that no runner lists (adapting `security-crontab-superuser` to `pg_cron`) | `cron.job` |
| The watch filtering `flag = 'critical'` while the flags are `critical-low` and `critical-high` | it never escalates (CC1) | the job's statement |
| `cron.log_run` off | no run to judge, nothing showing the watch alive (CC2) | the setting |
| The call stream's key calling the centre's vets only (a fault riding the schedule) | the practices' critical values never phoned; the watch's incidents piling up | the information system's fragment |

## Data moved

None classed: the watch reads flags, times and ids and writes incidents
naming a result by its id. Its `ops` tables are all `internal` (its
`classification:`).
