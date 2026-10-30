# v0.4 — checks: invariants over a trace, definitions, the release gate

Status: draft v1

How a purpose's invariants and the governance rules are judged by sealed
checks, and what v0.4's release gate checks with no aged run (D193). The
invariants themselves are in [purpose-catalogue.md](purpose-catalogue.md)
and [governance.md](governance.md).

## What v0.3 gives

- Exit 0 fixed, 1 present, 3 "too soon to tell" with `remaining=<s>` on
  the first line, anything else an error (formats.md, "Script
  contracts"; D124).
- A behavioural check judges a trailing window from the answer key
  (`CHECK_WINDOW_SECONDS`, `CHECK_THRESHOLD`) and is never told when a
  fix happened: v0.3's duplicates check calls a violation "present" when
  the newest is younger than half the window, else "too soon"
  (`faults/scheduler-insert-retry-duplicates/checks/fixed.sh`).
- A check runs on its fault instance's node only; on a scheduler node it
  reaches any database as `gm_check` through `check-sql`, one statement
  per call (D185). A check comparing two databases calls it twice.
- `gmctl check` runs at the final answer, the load still running; nobody
  triggers a job, not even for the final checks (D131).

A daily job breaks the trailing-window model: no window short enough to
judge a fix is long enough to contain a run.

## Invariant checks: judged by runs since a moment (O124)

Proposed. A purpose fault's sealed check judges **the job's runs since
a moment**, not a window:

- **The judged moment**, `CHECK_SINCE`, which `gmctl check` passes: the
  hand-over by default; raised by the check itself to the runner's last
  successful reload (`reload status=ok` in its log) when that is later,
  since a fix to a job's SQL or time takes effect only through a reload;
  raised by the GM with `gmctl check --since <time>` when the players'
  report says they fixed something outside the runner (a constraint, a
  consent view, a grant) at a given time.
- **The runs**: the job's `run … phase=end status=ok` lines in the
  runner's log after the judged moment. Trace rows are tied to a run by
  their time (written inside the run's transaction, so between its start
  and end) or by their `etl_runs` id.
- **The verdict**:
  - no completed run since the judged moment: **exit 3**, with
    `remaining=` the seconds to the job's next run in the loaded
    `jobs.yaml` (read with the program's own cron, as the
    wrong-time-zone check does);
  - a run since the judged moment that violates the invariant: **exit
    1**, naming the run and one violating row;
  - every run since the judged moment clean, and at least one of them a
    witness (below): **exit 0**;
  - runs since, all clean, none a witness: **exit 3**, `remaining=` to
    the next run.
- **Past violations never count** and stay in the trace as evidence
  (D190: "fixed" means no new violation since the fix).

Rejected: running the job, or its query, in a rolled-back transaction to
predict the next run. It would answer at once, but it triggers a job
during the game, which D131 rules out even for the final checks, and it
would need the job role's password on the check side.

### Witnesses

A clean run proves a fix only if it could have violated. Each invariant
states its **witness condition** (purposes.md), and the check counts the
material where it can: opted-out customers among the campaign's pending
leads at the run's time (M2), recipients outside their sending hours
among those pending (M3), orders crossing a local midnight in the day
the run closed (R3). Where the check cannot count it, the purpose's
design guarantees it (the producer's streams, the recipients' zones) and
the fault's `gm.md` says so.

### Pushed obligations (P5)

A deadline invariant (E1, E4) judges **triggers** rather than runs:

- every trigger since the judged moment past its deadline with no
  declaration: **exit 1**;
- every trigger since the judged moment older than two dispatch cycles
  declared in time (and acknowledged or escalated, for E4), with at
  least one such trigger: **exit 0**;
- otherwise (no trigger old enough yet): **exit 3**, `remaining=` until
  the oldest pending trigger reaches two cycles or its deadline.

So a fix to the dispatcher shows within ten or fifteen minutes whatever
the deadline's length, while a miss is called only once its deadline
has passed.

### Answer key and format

- `sealed_check.judges: runs` (or `triggers`) beside v0.3's
  `behavioural: true` (proposed; O104); the answer key states a
  `threshold` (violations tolerated, 0 by default) and no `window`.
- The check's parameters name the job, the databases (`FAULT_SOURCE_NODE`,
  `FAULT_TARGET_NODE`) and the tables; the customer's zone and sending
  hours come from `business_settings`.
- The fault instance's node is the purpose's runner; the database nodes'
  `pg_hba.conf` admit `gm_check` from the game network (D185).

### At the final answer

An exit 3 is reported as undetermined in the feedback (v0.3 master spec
11, rule 3). The players' lever is moving the job's time (D116, D132),
which the starter pack says for every purpose job they may edit.

## Definition checks

A purpose's definitions (a dashboard's query, a job's configuration) and
the governance rules G1 to G3 are judged on the live state, as v0.3's
`seed-file` and configuration checks are: exit 0 or 1, never 3. A
definition check may run a dashboard's `SELECT` read-only as `gm_check`
to compare its result with the published table (R5): it reads, it runs
no job (proposed).

## Changes to `gmctl` and the format (proposed)

- `gmctl check` passes `CHECK_SINCE` (the hand-over from the state) and
  takes `--since <time>`; per instance with `--instance`.
- `load-data` passes `customer_timezone` and `customer_utc_offset` to
  `psql` as variables (O122), and sets each user mapping's password from
  its remote role's secret (O123).
- `render` substitutes `{{customer_timezone}}` in scheduler seed files
  (O122).
- The loader: `purposes:` and `governance:` in `scenario.yaml`
  (purposes.md, governance.md); `judges:` in `fault.yaml`.

## The release gate without an aged run (O121)

v0.4's gate has the smoke tests, the rehearsal and the timer-fired early
check (D193). Proposed, for purposes:

- **Every purpose fault through its whole cycle in a smoke run**: the
  fault planted, its job moved to run within two minutes (an edit of
  `jobs.yaml` and a reload, as a player may: D116), the check read
  present; the acceptance fix applied, the check read too soon; the job
  moved again, the check read fixed. Frequent jobs need no move.
- **The rehearsal's planned hand-over** is chosen so that the hourly and
  quarter-hour jobs run inside its two hours, with the peak, as v0.3
  chose it for the traffic.
- **What no gate shows**, named in the definition of done as known
  limits: the nightly close running at its story's time, the trace's
  growth over a full aging (extrapolated from the rehearsal's per-hour
  figures and stated as such), hosts and timers through a night.
