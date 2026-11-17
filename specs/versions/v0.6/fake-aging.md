# Fake aging: a second aging mode

Status: draft v5, 2026-11-16, **consolidated** the same day into the
[master spec](master-spec.md), section 9, which wins where they differ
(D514); kept as the working record. The owner's direction of 2026-11-15
(D489–D491) and spec-writer's reading of it on the bar (D492); O22
closed (D493); the owner's rulings of the same day: the players are
never told about the aging process (D494, O271 closed), v0.6 covers
the shop and the campaign (D495, O272 closed); refined on 2026-11-16:
once the game is concluded, a reported tell may be explained (D496),
within the feedback's two parts (D497). Every remaining proposal
accepted as written on 2026-11-16 (D498). Draft v5 closes the
review's findings: the initiator who also plays (D504), the restart
record (D506), the monitoring started at the restart and the early
check's time (D507), P0's reach and the campaign's fallback (D508),
the blind reads in v1.0 gating (D509). What stays open is
technical: the estimates of 2.4, to be measured, and section 9.

Inputs, on branch `research/fake-aging` (10d1bc6), worktree
`~/work/db_audit_gm-wt/research-fake-aging`:
- `specs/research/fake-aging/results-2026-11-15.md` (the results: Q1–Q8,
  the tells table, M3, the blind read, the proposal);
- `specs/research/fake-aging/run-2026-11-14.md` (the run sheet, which
  wins over the test plan), `test-plan.md`, `fault-impact.md`;
- `tools/research/fake_aging/` (the prototypes) and its `results/`
  folder (about 2 GB, **not committed**: R's and F's Prometheus copies,
  M1 dumps, the M3 profile, the calibrations).

Below, "the results" means the first file, "fault-impact" the last.

## 0. The owner's direction

The owner, 2026-11-15, after reading the results:

> Would the option to keep both method (true and fake aging) available
> be possible ? your few caveat about fake aging that can be fixed must
> be, those that can't must be documented. A fake aged run may need to
> curate its faults so that they don't use known limits of the fake
> aging. Thus, a quick game can still be started, and extended one
> remains available with true aging.

Then: "lets work on integrating fake aging into the game".

- **D489**: two aging modes. Real aging stays as it is (D114, D150) for
  extended games; fake aging joins it for quick games.
- **D490**: every fixable caveat of fake aging is fixed (section 3);
  every one that can't be fixed is documented (section 4).
- **D491**: a fake-aged game curates its faults, so that none relies on
  a known limit of fake aging (section 2).
- **D492**: the bar is "a student doing the audit doesn't stumble on
  it" (section 6).
- **D493**: O22 closed: fake aging is forged history plus a compressed
  fill before the game, never fake time (section 8).
- **D494**: the players are never told about the aging process: not
  during the game, not in the feedback, not after the final answer
  (4.1). Refined by D496.
- **D496**: during the game, still never; once the game is concluded,
  a tell the report names may be explained in the feedback, the fake
  aging included (4.1).
- **D497**: the GM's appreciation of a report has two parts, the
  customer side and a teaching moment; beyond fake aging, so stated in
  the [v0.6 page](README.md#the-gms-feedback-d497).
- **D498**: the draft's proposals accepted as written (2026-11-16):
  the mode and the GM's steps, the fault format, the tail, the
  calibration, the fix list with its additions and its departure, the
  limits' documentation, the product's shape and the verification.
- **D495**: v0.6 makes the shop and the campaign fake-ageable, the
  campaign without its f10; the clinic later (2.4).

Unchanged and not re-proposed: no fake time, no NTP, no container
clock. Every handout is a static snapshot of the mission's start
(D488). Faults that hide or wipe another's trail are wanted, and the
fake must reproduce them, never repair them. Fault overlays are
mandatory.

## 1. The two modes

### 1.1 Choosing the mode

The mode is chosen per game, by the GM, at setup. It is not a
scenario field: a scenario allows fake aging when the fault selection
the GM makes for it is eligible (section 2).

- **The initiator states the time available**, as today (D150), and may
  ask for a quick or an extended game. The initiator never picks faults
  or a mode's mechanics: fault selection is the GM's.
- **Whether the initiator plays** (D504): the GM asks once, within
  D150's setup dialogue, whether the initiator will play the game (a
  student playing alone does). When the initiator may play, the
  dialogue speaks of a **quick game** or an **extended game** by
  duration only ("ready in about an hour and a half" or "ready in about
  16 hours"), and never names the technique: no aging, fill, forged,
  virtual clock or fake, as 4.1 holds for anything a player reads. An
  initiator who will not play (a teacher, the owner) may be told the
  mode and its limits.
- **Default**: real aging when the time available covers
  the scenario's declared aging; fake aging when it doesn't, or when the
  initiator asks for a quick game. This keeps D150's judgment as it
  stands and adds one option before declining.
- **Fake aging needs an eligible selection.** The GM selects, or
  replaces, the scenario's fault instances so that every one is
  eligible (2.1), then sets the tail (2.2). If no acceptable selection
  fits the scenario, the GM declines it or proposes another scenario, as
  D150 already has it do.
- **Recorded**: `gmctl render --aging fake` writes the
  mode, the virtual T0, the anchor and the tail into the local
  implementation's restart record (2.1). `gmctl` refuses a fake game holding a `real-only`
  fault, or a fault not assessed for fake aging.
- A scenario with no scheduler node has no aging (D157) and so no mode.

### 1.2 A fake game's timeline

Every instant is computed from the planned hand-over H, as for a real
game.

| Instant | Fake game | Real game |
|---|---|---|
| virtual T0 | H minus the scenario's declared aging (the shop: 22:00 the evening before) | T0, real |
| fill | virtual T0 to the anchor, run in minutes, before the tail | no fill |
| clean-up | just before the anchor, ending with the "maintenance restart" | none |
| anchor | H minus the tail: the maintenance restart's instant, every service of the game, the monitoring included, started there; the tail's real start | none |
| tail | anchor to H, real time, everything running | the whole aging |
| history import | about 12 minutes into the tail | none |
| early check | halfway through the tail, no later than one hour before H, never before the history import (step 9) | v0.3's rule |
| H | hand-over | hand-over |

- **The virtual span is the scenario's declared aging**, so
  the virtual T0 is the T0 a real game of the scenario would have. The
  research ran 24 h for the comparison with R; the product uses the
  scenario's own aging. The instances' aging minima (the shop's f5,
  15 h) then count in virtual time from the virtual T0. The
  Prometheus retention rule ("the aging minimum plus four hours",
  formats.md "Scenario") covers the forged span, the tail and the game
  unchanged.
- **The tail** follows 2.2. The research's tail was 3 h.

### 1.3 The GM's steps in fake mode

Steps 1 to 4 are today's setup.

1. `gmctl render --aging fake`: the timeline above, recorded. The
   starter pack's story line on the restart (3, fix 2) is rendered with
   the clean-up's planned time.
2. `gmctl deploy`, the monitoring (Prometheus, Grafana, the exporters,
   pgwatch) kept scaled to 0 until the maintenance restart (step 6).
3. `gmctl load-data`, unseen as today (`tools/gm/inject.py`'s
   `UNSEEN_SQL`: no statement log, no pgaudit, no
   `pg_stat_statements`).
4. `gmctl inject`: the faults planted at T0.
5. **`gmctl fill`**: the scheduler program's fill mode (section 5) on
   every scheduler node, one virtual clock, from the virtual T0 to the
   anchor. It runs the producers' streams, the consumers' keys and the
   jobs as fast as the database allows, the database's time-of-day
   functions bound to the virtual instant. It writes the scheduler logs
   at virtual times, their latencies from the shared queue model. It
   pauses at each `state` fault's virtual planting, runs that fault's
   inject unchanged, records the instant, and goes on. Statistics stay
   off as in step 3 (fix 3). The real-clock actors (`pg_cron`, the
   database node's cron daemon, archiving) stay off.
6. **`gmctl clean-restart`**: the maintenance restart (fix 2, fix 4):
   the WAL padded and checkpointed, the statement and shared statistics
   reset, the fill's PostgreSQL, pooler and cron logs removed, the data
   files' modification times set to their virtual times, then **every
   service of the game restarted** at the same instant, the monitoring
   scaled up from 0 in that same restart (D507), so Prometheus,
   Grafana, the exporters and pgwatch start with the rest and no start
   time stands apart; the standbys and base backup built after it. The
   restart's instant is the anchor; `clean-restart` records it in the
   restart record (2.1).
7. `gmctl start-load` right after the restart, T0 recorded as the
   virtual T0, writing no `reload status=ok` line: the purpose checks
   date their judged moment from that line.
8. **`gmctl history`**, run by a host timer about 12 minutes into the
   tail: read the tail's first 10 minutes from Prometheus, compose the
   baseline and the selected faults' overlays, rebase them on the
   tail, write the past as OpenMetrics, `promtool tsdb
   create-blocks-from openmetrics`, copy the blocks in, check the seam.
   A failed import is recorded, never a teardown, as the early check's
   failures are (v0.3 master spec 8.7).
9. **The early check** (D507), run by a host timer as today: halfway
   through the tail, and no later than one hour before the earliest
   hand-over, but never before `gmctl history` has recorded its import;
   so in a tail under two hours, and in the tests' short tails, it runs
   right after the import. It checks what v0.3's does (every fault
   planted so far reads present, the fill's plantings included, every
   scheduler key running, no node unhealthy, the outages) and reads the
   import's recorded result. Then the hand-over check, the hand-over
   snapshot and `status --set handed-over`, as today. The earliest
   hand-over is the anchor plus the tail; the instances' aging minima
   count from the virtual T0.

Planting times:
- a `state` fault planted between the virtual T0 and the anchor is
  planted by the fill (step 5);
- one planted in the tail is planted by a host timer, as today;
- a fault with `plant_in: tail` (2.1) must be planted in the tail.

### 1.4 What stays as in a real game

Hand-over, the issues, the GM's stance during the game, the final
answer, the checks, restarts (D126) and the hand-over snapshot. A fake
game's restart from its snapshot restores the imported history with
the rest of Prometheus' volume (to verify, section 9).

## 2. Fault eligibility

### 2.1 The fields

A `fault.yaml` keeps its `aging:` block (`technique: real-time`, the
real mode's, and `minimum`) and gains two things.

```yaml
aging:
  technique: real-time
  minimum: 30m
  fake:                         # absent: not assessed; refused in a fake game
    support: supported          # supported | tail-only | real-only
    reason: >-
      one sentence: what the fill makes, what the tail must hold, or
      why it can't be faked
    tail_minimum: 2h            # tail-only: genuine evidence needed before H
    tail_covers: ["12:00"]      # tail-only: scenario-time instants the tail must hold
    plant_in: any               # any | tail: may it be planted in the fill?
    fill:
      emulate: [held-snapshot]  # what the fill must imitate (held-snapshot,
                                # refused-logins, model-latency, ...)
history:                        # mandatory unless support is real-only
  - kind: counter_per_call
    series: 'node_health_cpu_seconds_total{node="{NODE}"}'
    key: '{KEY}'
    per_call: 0.067             # measured, never guessed (2.3)
```

- **`support`**:
  - `supported`: the fill makes the fault's state, its overlays draw
    its Prometheus trail, and its evidence holds whatever the tail.
  - `tail-only`: its evidence must be genuine and needs the tail: a
    minimum length, instants the tail must cover, or a planting in the
    tail.
  - `real-only`: it needs something fake aging can't make (section 4),
    so `gmctl` refuses it in a fake game, naming the `reason`.
- **`history:`** is the fault's history signature: today's
  `overlays.yaml` classes, written per fault definition with the
  fault's parameter placeholders, not per instance. A fault with no
  trail in Prometheus says so with `- kind: none` and a comment.
  Overlays are mandatory; an empty or missing `history:` on a
  `supported` or `tail-only` fault is refused.
  - Kinds: `queue` (latency, never drawn per fault: the fault declares
    its effect on the one shared queue model, which writes both the
    scheduler's log lines and the `scheduler_call_duration_seconds`
    histograms), `counter_per_call`, `gauge_sawtooth`, `remove`, and
    two to add: `gauge_before` (a level before the planting, f8's index
    size) and `daily_spike` (f5's noon, never exercised in the test).
  - `remove` wins over every baseline and overlay on its series.
  - `suppressed_by: [<fault id>]` drops an overlay while the hiding
    fault is selected. Hiding is a feature, never repaired: the forged
    past is always before any fix.
- **How it fits the format**: `aging.fake` nests under the existing
  block, so `fault.yaml`'s "aging technique and minimum" item
  (formats.md "Fault definition") grows a sentence. `history:` is a new
  item. The loader's checks (`tools/gm/model.py`) gain the refusals
  above. The scenario format is unchanged: the mode is the game's.
- **The restart record** (D506), one per fake game: the maintenance
  restart, an in-world event of the customer's system, with what it
  explains. Not a fault, never counted; the feedback uses it as 4.1
  says. It is the game's, not the scenario's: `gmctl` writes it into
  the game's local implementation, `local/<playground>/fake-aging.yaml`,
  GM-side and out of the players' reach like `gm/answer-key.yaml`, so
  the scenario format stays unchanged. `render --aging fake` writes the
  plan, `clean-restart` the restart, `history` the import:

  ```yaml
  mode: fake
  virtual_t0: 2026-11-20T22:00:00Z    # H minus the scenario's declared aging
  anchor: 2026-11-21T11:00:00Z        # the planned restart, H minus the tail
  tail: 3h
  handover_planned: 2026-11-21T14:00:00Z
  refused: []                         # each {instance, reason}; the shop's full selection refuses none
  restart:
    at: 2026-11-21T11:00:04Z          # measured, every service's start
    story_line: >-                    # as rendered into the starter pack
      The servers were restarted this morning at 11:00 for maintenance;
      older logs were archived.
    explains:                         # the rows of section 4 that hold in this game
      - observation: statement and shared statistics reset at 11:00
        where: pg_stat_statements_info.stats_reset, pg_stat_bgwriter.stats_reset
        in_world: the maintenance restart reset them
      - observation: no PostgreSQL, pooler or cron log before 11:00
        where: /var/log/postgresql/, the pooler's and cron's logs
        in_world: older logs archived at the restart
  history: {at: 2026-11-21T11:12:30Z, result: ok, seam: ok}   # gmctl history
  ```

  `observation`, `where` and `in_world` for each limit of section 4
  that touches this game's evidence, `explains` drawn from that table
  by `render`; the scenario document's "Fake aging" section lists the
  same rows for the scenario. `gmctl status` shows the mode, the
  anchor, the tail, the refused instances and the import's result.

### 2.2 The tail's length

The tail is the longest of:
- a floor of **1 h**, so the statement statistics and the logs hold an
  hour of genuine traffic and the import (step 8) is done well before
  the hand-over;
- each selected fault's `tail_minimum`;
- for each `tail_covers` instant, the time from one floor before it to
  H, so the instant has an hour of genuine traffic before it (D532);
- for each instance planted in the tail, the time from its planting
  moment to H; that moment lies inside the tail, at least the
  instance's aging minimum before H, so the tail is never shorter than
  that minimum.

Tests may cap the floor, as v0.3's rehearsal caps the aging minimum
(D161; section 7).

### 2.3 Every number is measured

Four guesses in the test were 4× to 55× off (f8's CPU and latency, the
roll-up, the export). Every number in a `history:` entry, and each
key's service time in the queue model, comes from one real run of the
fault:
- **short**: under 30 minutes, the fault planted at once and
  its job moved into the window as a player would move it. Per-call
  costs and service times don't need a day; the day's shape comes from
  the producer profiles. This keeps calibration within D314's short
  tests, and one-off per fault version (D193);
- the shop's numbers already come from R (`results/calibrate-r-*.txt`).

The per-key service times describe the scenario's or the domain's
keys, so they live beside the query repository that defines them
(`queries.yaml`), not in the scheduler brick (the results put them in
the brick). The brick ships the model's code.

### 2.4 Starting estimate, to be measured

Only the shop is measured (the test); the rest is fault-impact's
reading, amended. "P0" is the virtual clock in the SQL the fill runs,
the server-side functions it calls included, unproven: if it fails,
the purpose faults marked P0 drop to `tail-only`. `pg_cron` never runs
in the fill (step 5), so no `pg_cron` job is P0's: its runs are the
tail's, a limit of section 4 (D508).

**Shop** (`tarnbeck-outdoor-shop`, measured on R and F1–F6):

| Instance | Fault | Estimate | Why |
|---|---|---|---|
| f1 | scheduler-query-error | supported | errors overlay on the key |
| f2 | scheduler-report-unbounded | supported | temp bytes and files per call |
| f3 | scheduler-insert-retry-duplicates | supported | state; rows at virtual times |
| f4 | scheduler-transaction-held-open | tail-only, 2 h | autovacuum's "not yet removable" lines are tail-only; the fill holds the snapshot |
| f5 | scheduler-batch-at-peak | tail-only, covers 12:00 | the noon lock waits are genuine only in the tail; `daily_spike` untested |
| f6 | scheduler-job-wrong-timezone | supported | the 10:00 run, in the fill or the tail |
| f7 | pgbouncer-pool-too-small | tail-only, covers 12:00 | the fill bypasses the pooler; SHOW STATS starts at the restart |
| f8 | pg-join-index-missing | supported | planted by the fill at virtual 08:00; calibrated on R |
| f9 | pg-table-autovacuum-off | supported | state; hides f4's trail on `orders` as in R (Q8) |
| f10 | prometheus-scrape-target-missing | supported | `remove` |

The full selection's tail: 3 h (anchor 11:00, the noon peak inside).

**Campaign** (`tarnbeck-outdoor-campaign`):

| Instance | Fault | Estimate | Why |
|---|---|---|---|
| f1 | purpose-mail-overlapping-window | supported (P0) | job every 5 min, virtual |
| f2 | purpose-leads-stale-consent | supported (P0) | the release at virtual T0, jobs virtual |
| f3 | purpose-mail-outside-hours | supported (P0) | the campaign job, virtual |
| f4 | purpose-watermark-misses-updates | supported (P0) | the roll-up and the 12:00 close, virtual; whether its check needs the close in the tail is to verify |
| f5 | purpose-etl-role-expired | tail-only, `plant_in: tail` | its refusals in the PostgreSQL log must follow its planting; planted at 09:00 today, which a tail starting at 11:00 misses |
| f6 | security-crontab-superuser | tail-only, 1 h | the cron daemon is off in the fill; its hourly runs and peer logins are tail-only |
| f7 | purpose-day-boundary-wrong-zone | supported (P0) | the 01:30 close, virtual |
| f8 | purpose-receiver-down-unnoticed | supported | the gateway's outage at virtual 08:00–10:00 |
| f9 | governance-personal-copied | supported | its definitions are state; `job_run_details` holds the tail's runs only (pg_cron off in the fill) |
| f10 | purpose-heavy-job-on-database-node | **real-only** | a real OOM kill and crash recovery at 03:00, read from the PostgreSQL log since the request; a redesign moving the incident into the tail is possible later, not in v0.6 |

The campaign's hiding: f5 hides f4, f7 and f10. With f10 out of a fake
selection and f5 planted in the tail, the GM checks f5's order against
f4's and f7's runs when it composes the selection (fault-impact 3).

**If P0 fails** (D508): f1–f4 and f7 drop to `tail-only`, each with
the tail its job's runs need. v0.6's short campaign check (section 7)
then keeps f8 and f9, which need no P0, and f1, whose job runs every
five minutes and so fits a 15-minute tail; f2, f3, f4 and f7 wait for
the full selection's run in v1.0 gating. The check still proves the
mode's mechanism on the campaign: the fill, the restart, the history,
the seam and the tells.

**Clinic** (`aldermoor-centre`, two hosts, a standby, the archive, the
partners):

| Instance | Fault | Estimate | Why |
|---|---|---|---|
| s1 | purpose-urgent-priority-dropped | supported (P0, emulated) | the fill must drive the lab round trip under the virtual clock; timeouts can't be compressed, only their outcome emulated |
| s2 | pg-archive-command-silent | tail-only | archiving is off in the fill; the vault holds a gap for the fill's span unless manifests are planted |
| s3 | purpose-herd-use-dropped | supported (P0) | the 02:00 feeder, virtual |
| s5 | security-policy-ownership-end-dropped | supported | state; planted at H − 3 h, in the tail or the fill |
| s6 | governance-register-flow-undeclared | supported | a handout and a state |
| s7 | governance-statement-log-personal | tail-only | the server log starts at the restart |
| s8 | pg-standby-apply-delay | real-only, unless the fill emulates the delayed read | the standby is built after the fill; the 00:30 feeder's short report needs the delay at virtual 00:30 |
| s9 | scheduler-display-refresh-loop | supported | statement calls overlay |
| s10 | pg-monitoring-option-absent | supported | `remove` of the lab's `pg_*` series, `pg_up` 0 |

The clinic also needs things the shop didn't: a standby and a base
backup built after the fill, the vault's gap, two hosts. **v0.6 covers
the shop and the campaign, the campaign's f10 `real-only`; the clinic
comes later** (D495). A fault no covered scenario uses stays not
assessed, so refused in a fake game.

## 3. The fix list (D490)

Every fixable caveat is in scope. "Tested" says whether the test
exercised the fix, not only the defect.

| # | Fix | Fixable? | How | Tested |
|---|---|---|---|---|
| 1 | **Generator bugs** | yes | noise clamped at 0 and scaled to the value (no negative `scrape_duration_seconds`); start times are constants that step only at a restart (the `ts_now` class caught `process_start_time_seconds`); the forged past draws the clean-up's restart: a `pg_up` and `up` blip, start times stepping, the restarted processes' counters resetting at that instant, the anchor (D507), never later | defects seen (M5); fixes not |
| 2 | **A coherent restart** | yes | one event, the clean-up: every service of the game restarted there (fresh process namespaces, so start times and process IDs agree with it), the statement and shared statistics reset there and not at the deploy, no `reload status=ok` line; the PostgreSQL, pooler and cron logs start there, the forged log volume grows through the day and drops at the restart ("older logs archived"); the starter pack's story says "the servers were restarted this morning for maintenance; older logs archived", with the time render planned | partly (F runs restarted PostgreSQL and the pooler only) |
| 3 | **Statistics off during the load and the fill** | yes | the fill's sessions run as `load-data`'s do: `pg_stat_statements` not tracking, no statement log, no pgaudit; `pg_stat_statements` then holds the tail only and agrees with its reset; the fill's `$n` duplicates and the load's statements disappear. `track_counts` stays on: autovacuum and the faults read the table statistics | yes (F3) |
| 4 | **WAL, checkpoints, the LSN** | the segments yes; the LSN probably | at the clean-up: pad the WAL with `pg_logical_emit_message` to a day's worth at the scenario's measured WAL rate, then `CHECKPOINT` and `pg_switch_wal()` twice, so PostgreSQL recycles the fill's segments (`pg_wal` near R's 84 MB, not 305 MiB); the checkpointer and WAL statistics reset with the shared ones | no |
| 5 | **Calibrated overlays** | yes | f8's CPU 0.067 s per order detail (R), not 0.25; a `gauge_before` for f8's dropped index on the size gauges; no overlay drives the baseline below the night's floor; the backends and other activity gauges drawn around the tail's median with R's spread (±1), not 1–11; database size growing with the load shape, not evenly | the numbers come from R; the drawing not |
| 6 | **Drop the recorded baseline** | yes | the profile baseline is the product's only one; the recorded one stays a research calibration tool (it needs a real run, and its gauges don't join) | yes (F4) |
| 7 | **Autovacuum through the fill** | probably | `autovacuum_naptime` lowered for the fill (to 1 s, say), so autovacuum visits a table as often per dirtied row as in a real day (products: 8 runs against R's 218). The results' manual `VACUUM` per virtual hour is not proposed: it counts in `vacuum_count`, not `autovacuum_count`, and would itself be a tell | no |
| 8 | **Data files' modification times** | mtime yes; ctime no (4) | `touch -d` each data file to its last virtual write before the restart (file times, not the clock) | no |
| 9 | **Monitoring's footprint in the database** | probably | the fill opens the exporter's and pgwatch's sessions against their databases at the scrape rate in virtual time, since `pg_stat_database` can't be reset without the table statistics (`sessions`, the `postgres` database's commits: 0.13–0.40 of R's) | no |
| 10 | **Fault parameters, not constants** | yes | the queue model and the overlays read the instance's parameters (f7's pool, f4's hold) and the keys' measured service times (2.3); the prototype hardcodes them (`latency.py`) | — |

Not proposed, from the results' Q6:
- **Resetting the table and index statistics at the clean-up.** It would
  hide the last-use times, but it zeroes `n_dead_tup` and the counters
  autovacuum triggers on. f4's evidence and f9's dead rows read them,
  and so does Q8's hiding pair. The table statistics are kept;
  `last_seq_scan`, `last_idx_scan` and `last_autovacuum` stay a
  documented limit (4).
- **Keeping the statement text with statistics on** (binding the
  virtual time through a session setting): fix 3 makes it moot.

## 4. Documented limits

What fake aging can't hide without fake time, which stays ruled out. A
student doing the audit isn't expected to find these (D492); a DBA
hunting with superuser access can.

| Limit | Where it shows | The story covers it? | Curation |
|---|---|---|---|
| The maintenance restart itself: the postmaster's start, every container's start, process IDs counted from it, the shared and statement statistics' `stats_reset`, the logs' first lines | `pg_postmaster_start_time()`, `ps`, `stats_reset`, `/var/log/postgresql/` | yes, the story line | none |
| No log before the restart: PostgreSQL, the pooler, pgaudit, the cron jobs (the scheduler's own log does cover the fill) | the log folders | yes, "older logs archived" | a fault whose evidence is a pre-restart log line is `real-only`, or `tail-only` planted in the tail |
| Real-clock actors start at the restart: `pg_cron`'s `job_run_details`, the crontab's runs, PgBouncer's `SHOW STATS`, archiving, Grafana's alert state and history | those views | partly: a real restart keeps Grafana's alert history | a fault read through these is `tail-only` with enough tail, or `real-only` |
| Inode change times (ctime) of the data files are the fill's real minutes | `pg_stat_file()`'s `change`, `stat`, `ls -lc` | partly | none |
| Last-use times: `last_seq_scan`, `last_idx_scan`, `last_autovacuum`, `last_analyze` of what only the fill touched fall in the minutes before the restart (a 01:30 roll-up's index last used at 10:4x) | `pg_stat_user_tables`, `pg_stat_user_indexes` | no | none: kept so `n_dead_tup` holds (3) |
| The LSN and WAL volume, if fix 4's padding doesn't hold | `pg_current_wal_lsn()`, the WAL segments' names | partly, with the reset | none |
| Time-driven behaviour in the fill is emulated in outcome only: a held snapshot, a timeout, a lock wait, an OOM kill | the logs and views of the fill's span | no | a fault that needs it genuine is `tail-only` or `real-only` |
| The archive vault and the standby date from the clean-up (archiving off in the fill, the standby cloned after it) | the vault, `pg_stat_replication`, the slot's age | partly | the clinic's s2 and s8 (2.4; the clinic is later, D495) |
| Prometheus' imported blocks carry their creation time (block ids), and Prometheus' start is the restart | the TSDB's files on its node; `/api/v1/status/runtimeinfo` | the start, yes | none; the players have no shell on the Prometheus node (to verify) |
| Fine shape of the forged past: series appearing over the day (R gains about 50, the forged past is flat), rarely called statements | Prometheus | no | none |

Host-level evidence (the host's uptime, Docker's task history) is out
of the players' reach: they have the bastion only.

**Where it is documented**:
- GM-facing, once: the limits above in the GM's guide to aging (today
  [scenario-lifecycle.md](../../scenario-lifecycle.md) "Aging" and
  [gm-stance.md](../../gm-stance.md) "Aging feasibility"), at
  consolidation.
- Per fault: `aging.fake.reason`, and a "Fake aging" note in the
  fault's `gm.md` when it is `tail-only` or `real-only`.
- Per scenario: the scenario document (skill `scenario-document`) gains
  a "Fake aging" section, generated: each instance's support, the tail
  the full selection needs, the instances refused, and the limits from
  this table that touch its evidence.
- Per game: the restart record (2.1) in the local implementation holds
  the mode, the instants, the tail, the refused instances and the rows
  of this table that hold in the game; `gmctl status` shows them.

All of these are GM-facing: the scenario document opens with its "do
not read" warning, and nothing above reaches the bastion, the starter
pack or a handout during the game. Once the game is concluded, they
are also what the feedback's explanation of a reported tell is drawn
from (4.1).

<a id="41-the-players-are-never-told-d494"></a>
### 4.1 What the players are told, and when (D494, D496)

The owner, 2026-11-15: "players are never meant to be told about aging
process" (D494). Refined on 2026-11-16 (D496): "if the tell has been
reported in the report, the gm may include the information about the
aging process. The game is already concluded, thus it's okay." The
three readings below (when the game is concluded, what a reported tell
is, no mention without one) were okayed by the owner on 2026-11-16.

**During the game: never.** The game is concluded when the players
have given their final answer and the GM has processed it
([gm-stance.md](../../gm-stance.md) "The final answer"). Until then:
- only the in-world facts are ever spoken of: the customer's system
  was restarted for maintenance this morning, and its older logs are
  archived. That restart really happened in the game;
- the GM never uses the words aging, fill, forged, virtual clock or
  fake in anything a player reads, a restart's confirmation (D126)
  included, nor in the setup dialogue when the initiator may play
  (1.1, D504), and neither confirms nor denies a suspicion of forged
  history.

**After the final answer, in the feedback** (its two parts, D497):
- **The customer side** (a) stays in-world in every case. A reported
  tell matches no fault there: it is neither credited nor counted as a
  mistake. A sound reading of the restart's consequences is
  acknowledged from the restart record (2.1).
- **The teaching moment** (b) may explain a reported tell: that the
  game was fake-aged, how, and why the thing looked as it did. "A tell
  reported" means the report names an observation from section 4's
  table or the results' tells, whatever cause the player gave it: "the
  statistics were reset this morning", "autovacuum barely ran on
  products", "the graphs before 11:00 look generated: negative scrape
  durations" all count. A suspicion that names no observation ("this
  history looks generated") is answered as any unsupported claim is:
  noted as not backed by the report's evidence. It reports no tell, so
  the aging isn't explained (next item).
- **When no tell is reported, the feedback doesn't mention aging.** The teaching
  part doesn't need it to stay truthful: it explains each missed or
  unexplained finding from the evidence this game actually held (the
  tail's log, the forged graphs as they read), never from evidence a
  real aging would have left and this game didn't (a fault's PostgreSQL
  log lines from before the restart, say). If explaining a finding the
  report did make would be false without the aging, that finding rests
  on a tell, so the rule above applies.
- **The same in a real game**: a report claiming a forged history gets
  the same customer side, and the teaching part explains why the thing
  really looked as it did.

**Where the explanation comes from**, all GM-facing (section 4's
"Where it is documented"):
- the scenario document's "Fake aging" section: which limits touch
  this scenario's evidence, so the GM matches the reported observation
  to a row of section 4's table, whose wording is written to be
  explained to a player in plain words;
- the per-fault `aging.fake.reason` and the "Fake aging" note in the
  fault's `gm.md`, when the tell touches a fault's evidence (f4's
  autovacuum lines covering only the tail, say). `gm.md` is already
  the "explanation the GM uses for feedback" (formats.md "Fault
  definition");
- the restart record (2.1): the virtual T0, the restart's real time,
  the tail and the rows that hold, so the explanation names this
  game's instants.

## 5. Where it belongs

| Research piece (`tools/research/fake_aging/`) | In the product |
|---|---|
| `fill.py`, the fill driver | the scheduler program's **fill mode** (`bricks/scheduler/program/gm_scheduler/`): it reuses the repository, builders, generators, the log's format and the minute summaries, as the prototype does |
| `latency.py`, the queue model | the model's code in the scheduler program, used by the fill's log lines and by `gmctl history`'s histograms; the keys' service times beside their `queries.yaml` (2.3); the faults' effects in their `history: queue` entries |
| `fake_aging.py fill`, `fill_run.py` | `gmctl fill` (step 5), with the pauses at plantings |
| `fake_aging.py cleanup`, `start-tail` | `gmctl clean-restart` (step 6) and `start-load` with a virtual T0 (step 7) |
| `gen_history.py`, `snapshot.py`, `prom.py`, `import_history.sh`, `seam_check.py` | `gmctl history` (step 8): a GM tool, not a brick; it composes the overlays from the GM's selection, reads the live tail, writes into the game's Prometheus, and checks the seam |
| `overlays.yaml` | each fault's `history:` (2.1) |
| `calibrate.py` | a calibration tool for the short real runs (2.3), in the repository's tooling, not `gmctl` |
| `m1_dump.sh`, `m1_compare.py`, `m3_profile.py`, `m4_tells.sh` | the verification's tools (section 7) |
| `gen_history.py`'s `recorded` baseline | stays research (fix 6) |
| `inventory.py`, `deploy_f.sh`, `run_f.sh`, `run_tail.sh`, `runner/`, the `HANDOFF-*` briefs | stay research |
| `results/` | the shop's reference: kept (section 7) |

Nothing is copied as is: the prototypes hardcode the shop's instances,
keys and parameters. They show what works.

## 6. The bar (D492)

The results asked the owner to choose:
- (a) a student doing the audit doesn't stumble on the fake;
- (b) a DBA hunting for it with superuser access can't prove it.

(b) can't be reached without fake time: the inode change times, the
last-use times and time-driven behaviour can't be back-dated. The
direction accepts limits that remain and are documented, which (b)
can't allow. The direction also sets the fix list by itself (every
fixable caveat is fixed, D490), so the bar no longer decides how much
of it is built. What it sets is what the verification checks: a
student-like reader of a fake game alone, with no real game beside it
and not told to look, doesn't come to suspect it.

## 7. Verification

Consistent with: aged runs are one-off, never a standing gate item
(D193); milestone tests are short, on the least environment (D314); any
test over 30 minutes runs once, before v1.0 (D314).

**v0.6's gate: a short fake-only check, on the shop and on the
campaign (D495), under 30 minutes each**:
- a fake game with a selection whose tail fits a capped floor of
  15 minutes: for the shop f1, f2, f3, f6, f8, f9, f10 (no f4, f5,
  f7); for the campaign f1–f4 and f7–f9 (no f5, f6, f10);
- fill, clean-restart, a 15-minute tail, `gmctl history` at about
  12 minutes, the early check right after it (1.3 step 9);
- if P0 fails, the campaign's fallback selection (2.4);
- the checks read every selected fault present;
- the seam check: no negative value, no counter reset outside the
  restart, gauges joining;
- the tells script (`m4_tells.sh`, made a test tool) on the fixed
  tells: no negative or moving start time, no fill statement in
  `pg_stat_statements`, one `stats_reset` instant, `pg_wal`'s size,
  autovacuum counts in range;
- for the shop, M1 and the M3 profile against the saved R as the
  reference, not a new real run. The campaign has no R: its check is
  the checks reading present, P0's jobs' outputs against their
  invariants, and the seam and tells.

**Before v1.0, once** ([v1.0 gating](../README.md#v10-gating), D509),
each run longer than 30 minutes:
- the full selections with their real tails (the shop's 3 h, f4, f5
  and f7 included; the campaign's, f10 refused);
- **a blind read of a fake game alone**, on the shop and on the
  campaign: a fresh agent with player access only, told nothing about
  aging, asked to audit the scenario (not to find a fake), then asked
  at the end whether anything about the system's history looked wrong.
  The game is a fake game of the full selection, kept up for the read.
  It passes under D492 if the reader doesn't come to suspect the
  history. The reader is a test agent, not a player: D494 doesn't apply
  to it. An audit takes longer than 30 minutes, so v0.6's gate has no
  blind read.

**The reference.** R's data (`results/` on the research worktree,
about 2 GB, untracked) is the only real run of the shop. It must
survive the research worktree: the small files (M1 dumps,
the M3 profile, the calibrations, the tells) committed with the
verification tools; R's Prometheus copy kept as an archive outside git,
its path and checksum recorded beside them.

## 8. Impact on earlier rulings and documents

- **D114** (real time in v0.3, "no forged history"): stands for the
  real mode. D489 adds the fake mode, with forged Prometheus history
  and a compressed fill; no sped-up clock.
- **D132** (no time compression; players verify a job's fix by moving
  its time): stands for play. The fill compresses the past before the
  game; a fake game is played in real time like any other.
- **D125** (classroom swarms wait for aged volumes copied to them): its
  path changes. A quick game ages on the class's own hosts in about ten
  minutes plus the tail. An extended game keeps D125's always-on hosts.
  The volume copy is no longer planned; moving a real-aged game to
  other hosts is O232's ("age once, restore many").
- **D150** (eight-hour floor, the GM judges the aging per game): the
  floor holds for the virtual span, the scenario's declared aging. The
  GM's judgment gains the fake mode before declining (1.1).
- **D193** and **D314**: section 7 follows them.
- **O22**: closed by D493.
- **O48** (where the solvability probe as a gate enters): stays open.
  A fake game's hand-over comes about a tail after setup, so a probe
  failing at hand-over costs a tail, not a day.
- **O232** (game snapshot and restore): unchanged; it inherits the
  volume copy's use.
- **The v1.0 README's aging lines**: classroom swarms no longer wait
  for the volume copy; aging has two modes. Updated with this draft.
- At consolidation: formats.md (`aging.fake`, `history:`), the
  scenario-format skill's templates, scenario-lifecycle.md "Aging",
  gm-stance.md "Aging feasibility", the scenario-document skill's
  template.

## 9. To measure during the build

Technical unknowns; none is the owner's.
- **P0**: binding `now()`, `current_date` and `current_timestamp` to the
  virtual instant inside the server-side functions the fill's SQL calls
  (`rpt.close_day()`), not only in the scheduler's own SQL. `pg_cron`
  stays off in the fill (D508). If it can't be done, the faults marked
  P0 drop to `tail-only` and the campaign's short check takes its
  fallback selection (2.4).
- Fix 4's padding: its time and the WAL it leaves after the checkpoints.
- Fix 7: whether a short naptime brings `autovacuum_count` within range
  without slowing the fill.
- Fix 2: that a restart of every service keeps everything the fill
  wrote (the scheduler logs on their volume), and gives fresh process
  namespaces.
- `daily_spike` (f5) and `gauge_before` (f8), never exercised.
- A fake game's restart from its hand-over snapshot keeps the imported
  blocks (1.4).
- Prometheus' retention against imported blocks older than the head:
  held on 3.16.0 over 24 h (Q3); recheck after a compaction.

## Questions for the owner

None open. Closed on 2026-11-15:
- **O271** (closed, D494, against the recommendation): are the players
  ever told that their game was fake-aged? The owner: never, not even
  after the final answer; the recommendation had been to say so in the
  feedback. Refined on 2026-11-16 (D496): never during the game; after
  it, a reported tell may be explained. Now 4.1.
- **O272** (closed, D495, as recommended): which scenarios does v0.6
  make fake-ageable? The shop and the campaign (f10 `real-only`); the
  clinic later. Now 2.4.
