# v0.3 — review list

Status: **closed 2026-10-22.** First round: every item accepted as
proposed (D146), v0.5 adjusting them after use; R6 and R4's example
amended by the eight-hour floor (D150). Second round (R47–R62, below),
the spec writer's choices made while applying the independent review
(D151): R47 ruled as option (a), lost time up to thirty minutes not
moving the earliest hand-over (D152); R48–R62 accepted as proposed
(D153); approved with the master spec (D154).

Every item still marked `(proposed)` in the v0.3 drafts and on the v0.3
page, for the owner to review in one pass. Everything else in the drafts
is ruled (D114–D145). The themes run from the costliest to change once
the build starts (formats that scenarios, faults and tools are written
against) to the cheapest (figures measured in the build). An item the
owner accepts becomes a decision and loses its `(proposed)` tag in its
draft; an item he changes is rewritten there first. IDs `R1`… are local
to this list.

## 1. Formats and contracts

Written into templates, the loader, the catalog faults and the new
scenario; changing one later reopens all of them.

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R1 | Query repository format | `queries.yaml`: per key `sql` + `params` (generators: int or decimal range, choice, sequence, current time), a list for a pool with optional `weight`, `steps:` + `transaction:` (isolation, hold) for sequences, `builder: file:function` + `options` | [scheduler.md](scheduler.md) "The query repository" | one SQL file per key, parameters in comments |
| R2 | Schedule format | `schedule.yaml`: `intensity`, named `connections` (driver, target, role, pool size or per-call), `streams` (key, connection, rate per minute, Poisson or even arrivals, shape, concurrency), `shapes` as hourly multipliers in scenario time, optionally per weekday, and `timeline` | [scheduler.md](scheduler.md) "The schedule" | shapes as a list of peaks (time, height, width) rather than hourly multipliers |
| R3 | Fixed-time operations format | `jobs.yaml`: name, key, connection, a cron expression, a time zone (UTC by default), rendered already shifted (D129) | [scheduler.md](scheduler.md) "Fixed-time operations" | a real crontab file read by the scheduler |
| R4 | Timeline moments | Written relative to hand-over (`handover-20h`), for both schedule changes and a fault instance's `plant_at` (default `T0`), so the shift carries them | [scheduler.md](scheduler.md) "The schedule"; [aging-and-timeline.md](aging-and-timeline.md) "Faults and changes during aging" | relative to T0; or absolute times in scenario time |
| R5 | Timeline guard | The loader refuses a timeline entry at or after hand-over | [scheduler.md](scheduler.md) "The schedule" | the scheduler ignores it at run time |
| R6 | Scenario `aging:` block | The aging minimum (at least 48 h) and the intended hand-over time of day, in scenario time | [format-changes.md](format-changes.md) "Scenario" | — |
| R7 | Fault `aging:` block | The technique (`real-time`, the only one in v0.3) and the minimum before the evidence shows; a fault instance may raise it | [format-changes.md](format-changes.md) "Fault definition" | — |
| R8 | `difficulty:` in the scenario | The score, which the loader checks against the number of fault instances, and optionally the level it targets | [format-changes.md](format-changes.md) "Scenario"; [faults-with-activity.md](faults-with-activity.md) "Difficulty" | the loader computes the score and the scenario records nothing |
| R9 | "Too soon to tell" exit code | Exit 3, with the remaining window on the first output line; a behavioural check's window and threshold stated in the answer key | [checks-under-load.md](checks-under-load.md) "Principles"; [format-changes.md](format-changes.md) "Script contracts" | another number; or exit 1 with an "undetermined" first line |
| R10 | The `snapshot:` key | In `brick.yaml`, the brick's online copy method per volume (D142 settles the methods; the key's name and shape are proposed) | [format-changes.md](format-changes.md) "Brick definition" | a companion script per brick instead of a key |
| R11 | Role names | A new role `pooler` for PgBouncer; scheduler nodes take `producer` or `consumer` | [format-changes.md](format-changes.md) "Brick definition"; [pgbouncer.md](pgbouncer.md) "Shape" | PgBouncer under the `database` role |
| R12 | Retention check | The loader checks Prometheus' retention against the aging minimum plus four hours, unless a planted fault is about retention | [format-changes.md](format-changes.md) "Scenario" | a check in the format skill only |

## 2. Brick interfaces

Ids, protocols and roles other parts depend on.

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R13 | Brick id | `scheduler`, version 0.1.0 | [scheduler.md](scheduler.md) "Terms" | `workload` (avoids a clash with cron and Swarm's scheduler) |
| R14 | Driver interface | Connect, run one statement with its parameters, begin, commit, roll back, close; reports a latency and an error code | [scheduler.md](scheduler.md) "Drivers" | — |
| R15 | Scheduler metrics endpoint | Per-key counters (calls, errors, latency histogram) on an endpoint Prometheus may scrape; also read by sealed checks through the exec verb | [scheduler.md](scheduler.md) "Its own monitoring" | log only, the checks parsing the log |
| R16 | Scheduler database roles | The scenario's roles, created by the data load; passwords generated secrets mounted into the scheduler and set at the data load | [scheduler.md](scheduler.md) "What the brick is" | — |
| R17 | PgBouncer authentication | `auth_query` against the database with a lookup role whose password is a generated secret, no plain-text user list | [pgbouncer.md](pgbouncer.md) "Shape" | a generated `userlist.txt` |
| R18 | PgBouncer brick | Id `pgbouncer` 0.1.0, a full node, Debian 13's package (amended by D177: the PostgreSQL apt repository's 1.26.1, master spec 7.2), seed-once `pgbouncer.ini`, reload through `gm-reload-pgbouncer` | [pgbouncer.md](pgbouncer.md) "Shape" | — |
| R19 | PgBouncer knobs | Envelopes on `default_pool_size`, `max_client_conn`, `max_db_connections`, `reserve_pool_size`; `pool_mode` allowed `session`, `transaction` | [pgbouncer.md](pgbouncer.md) "Shape" | — |
| R20 | Bastion on multi-host | Published in host mode on its own pinned host (a bastion bump) | [load-and-capacity.md](load-and-capacity.md) "Several hosts" | the VPS firewalls the published ports |
| R21 | Report-only monitoring nodes | On a report-only node, seed files read-only for `player` and the reload wrappers refused | [carried-items.md](carried-items.md) | — |

## 3. The scenario and its faults

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R22 | The new catalog faults | Eight: a query with a syntax or type error; a query without its `WHERE`; an unbounded BI query; non-idempotent retried inserts; a consumer holding transactions open; a nightly batch at the peak; a job in the wrong time zone; a PgBouncer pool too small | [faults-with-activity.md](faults-with-activity.md) "Candidate faults" | swap in any of the seven other candidates |
| R23 | Scenario topology | Bastion, one `postgres`, PgBouncer, a producer and a consumer, the three v0.2 monitoring bricks; single-host on armenelos, and deployed once across armenelos and the VPS | [faults-with-activity.md](faults-with-activity.md) "v0.3's scenario" | two producers; no PgBouncer in the default game |
| R24 | Scenario faults | Six or seven new faults plus three or four existing ones (`pg-join-index-missing`, `pg-table-autovacuum-off`, one monitoring fault), at least one planted during aging | [faults-with-activity.md](faults-with-activity.md) "v0.3's scenario" | — |
| R25 | Scenario write policies | Database and PgBouncer fixable; scheduler nodes report-only, the producer's repository and both `jobs.yaml` fixable; one monitoring node fixable, one report-only | [faults-with-activity.md](faults-with-activity.md) "v0.3's scenario" | — |

## 4. Aging and the timeline

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R26 | "Meaningful" days | Every traffic shape through two full daily cycles, every daily job run at least twice, every fault at its aging minimum; at least 48 h | [aging-and-timeline.md](aging-and-timeline.md) "What meaningful means" | — |
| R27 | No early hand-over | The GM refuses to hand over before the aging minimum, as it refuses a playground too small | [aging-and-timeline.md](aging-and-timeline.md) "The timeline" | hand over with a warning, the initiator deciding |
| R28 | The early check | Halfway through the aging, or after each job's first run: faults present, keys running, nodes healthy | [aging-and-timeline.md](aging-and-timeline.md) "The early check" | check only at hand-over |
| R29 | Unattended setup actions | Faults planted during the aging and the early check run as scheduled `gmctl` calls on the manager, recorded in the local implementation, with no GM session open | [aging-and-timeline.md](aging-and-timeline.md) "Faults and changes during aging" | the GM session stays open, or is reopened, at each moment |
| R30 | Load start | The scheduler nodes start idle; the GM starts the schedules at T0 (`start-load`), recorded with T0 | [aging-and-timeline.md](aging-and-timeline.md) "The timeline" | schedules start with their nodes |
| R31 | Aged growth in `fit` | The volumes' growth over the aging and the game, measured, declared in the footprints and counted by `fit` (the snapshot's copies: D142) | [aging-and-timeline.md](aging-and-timeline.md) "Disk over the aging" | — |
| R32 | Intensity is absolute | The scenario's intensity is never rescaled to the playground, as resource limits are not (D32) | [scheduler.md](scheduler.md) "The schedule"; [load-and-capacity.md](load-and-capacity.md) | `fit` scales it to the playground |

## 5. Scheduler behaviour

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R33 | Restart without replay | s6 restarts a dead scheduler, which resumes at the current time and never replays what it missed | [scheduler.md](scheduler.md) "What the brick is" | — |
| R34 | Skipped jobs | A job that cannot start (overlap, refused connection) is logged and skipped, never queued | [scheduler.md](scheduler.md) "Fixed-time operations" | queued once |
| R35 | Job reload | A player's change to `jobs.yaml` takes effect on a reload through a `sudo` wrapper | [scheduler.md](scheduler.md) "Fixed-time operations" | the scheduler rereads the file each minute |
| R36 | Log contents | Every fixed-time run, every error (key, SQLSTATE, message), a per-key summary each minute; keys, never rates or shapes | [scheduler.md](scheduler.md) "What the players reach" | — |
| R37 | Implementation | Python 3.13 on Debian 13, asyncio, `psycopg` from the distribution; one task per stream and per job | [scheduler.md](scheduler.md) "What the brick is" | — |

## 6. Tooling and tests

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R38 | `gmctl` verbs | `start-load`, `inject --at`, `snapshot`, `restart` (only once the confirmation is recorded), `fit` and `status` extended; none pauses or triggers load | [format-changes.md](format-changes.md) "`gmctl`" | — |
| R39 | Smoke tests | A few minutes of schedules; every fault "present" with polling and per-check timeouts; keys running; faults due during aging planted at once (a test harness, never a game) | [checks-under-load.md](checks-under-load.md) "The smoke tests" | — |
| R40 | The full aged run | Also restarts once from the hand-over snapshot | [checks-under-load.md](checks-under-load.md) "The smoke tests" | the restart tested separately on a short run |

## 7. Figures, to measure in the build

| # | Item | Proposal | Where |
|---|---|---|---|
| R41 | Scheduler footprint | Limits 0.25 CPU / 128M, reservations 0.1 CPU / 64M | [scheduler.md](scheduler.md) "What the brick is" |
| R42 | PgBouncer footprint | Limits 0.25 CPU / 64M, reservations 0.05 CPU / 32M | [pgbouncer.md](pgbouncer.md) "Shape" |
| R43 | A single-host game | About 5G of memory on armenelos | [load-and-capacity.md](load-and-capacity.md) "The hosts at hand" |

## 8. The page and the words

| # | Item | Proposal | Where |
|---|---|---|---|
| R44 | Definition of done | The nine points of the v0.3 page | [README.md](README.md) "Definition of done" |
| R45 | Vocabulary | The terms table (scheduler, query repository, query, pool, builder, schedule, stream, fixed-time operation, timeline change, intensity, traffic shape, driver), moving into `concept.md` at consolidation | [scheduler.md](scheduler.md) "Terms" |
| R46 | Shapes of the carried fixes | RG-2: the reload wrappers restore owner and mode; RG-3: no tools-password line without a web front | [carried-items.md](carried-items.md) |

## Second round: after the independent review (closed)

The independent review of the consolidated master spec (REJECT, seven
blocking issues) and the owner's answers to it (D147–D149) and his
eight-hour floor (D150) left choices nobody had made. Each is written into
the [master spec](master-spec.md) or the [access model](access-model.md)
tagged `(proposed)` until the owner's answers (D152, D153), which
dropped the tags. Ranked from the most consequential.

| # | Item | Proposal | Where | Alternative |
|---|---|---|---|---|
| R47 | Failures during the aging | **Ruled as option (a) (D152): lost time up to thirty minutes does not move the earliest hand-over, only the excess beyond it does.** As proposed: scheduled actions record failures, never tear down; the aging counts running time, every lost minute moving the earliest hand-over; up to 30 minutes lost in all needs nothing more; beyond, the GM judges at hand-over whether the evidence survived, then hands over (the gap told as an incident) or sets the game up again (stop, then start) | master spec 8.7 | restart the aging on any outage; or a threshold of one hour |
| R48 | The new scenario's aging | 16 hours, the hand-over in the customer's early afternoon: deployed the evening before, played after lunch; retention at least 20 hours | master spec 15.2 | the 8-hour floor (fixed-time faults all placed in the morning); or 24 hours |
| R49 | The rehearsal before the gate | About two hours, unattended, on armenelos plus the VPS: `start-load`, a scheduled `inject --at` and the early check, a scheduler killed and resuming, an outage recorded, the hand-over check, the snapshot, a restart; the game's memory measured | master spec 11 | the review's 12–24 h rehearsal, which the shorter aging makes less useful |
| R50 | The existing scenarios' aging | Both declare the 8-hour floor; fernway's one-day retention kept (it covers 12 hours), its 256 MB bound checked against measured growth | master spec 15.4 | no aging for them (an exception to the required `aging:`) |
| R51 | The early check and the hand-over check | The early check halfway through the aging minimum, or after each job due before the earliest hand-over has run once, never later than an hour before it; nobody notified, the result heading `gmctl status`; the same checks again at hand-over, the GM not handing over a failing game | master spec 8.5 | a notification channel (out of scope so far) |
| R52 | The no-history restart | Data loaded, every fault planted at once, the load started at once with the timeline applied; the four hours not extended | master spec 12 | extend the game by the restart's setup time |
| R53 | Secrets on a restart | Every generated secret kept, service ones included, so the restored databases and Grafana match | master spec 12 | regenerate service secrets and rewrite them into the restored data |
| R54 | The GM check role | Not a superuser: `pg_use_reserved_connections`, `pg_monitor`, `pg_read_all_data`, `SELECT` on `pg_hba_file_rules` | master spec 7.3 | a superuser check role |
| R55 | PgBouncer's console | The players' console role is `dba`, through `auth_query` with `auth_dbname`, in `stats_users` only, no extra password; the GM's admin account is PgBouncer's service account over the local socket | master spec 7.2 | a dedicated console role with its own password in the players' `~/.pgpass` |
| R56 | `postgres` write policy | Fixable only in v0.3; no scenario needs report-only, and an untested policy would ship unexercised | master spec 7.3 | add report-only in 0.3.0 |
| R57 | The multi-host playground declaration | A list of hosts (swarm node name, Docker endpoint, manager or not, capacity at available memory), plus a mapping from the scenario's `designed_for` hosts; one host keeps today's form | master spec 10.2 | — |
| R58 | Stages | `load-started` added after `injected`; the aging computed, not a stage; `status --set handed-over` requires the earliest hand-over, the hand-over check and the snapshot (or its not fitting) | master spec 13 | an `aging` stage recorded by the early check |
| R59 | Recording a restart's confirmation | `gmctl restart --confirmation "<the player's words>"`, refused without it | master spec 12, 13 | a separate `gmctl confirm-restart` verb |
| R60 | The planned hand-over | `gmctl render --handover <UTC date and hour>`; a later real hand-over keeps the rendered schedule; re-planning the hour is a new game | master spec 8.3 | re-render the schedulers' files when the hand-over moves before T0 |
| R61 | The schedule's delivery | The root run script passes `schedule.yaml` on standard input before dropping privileges; the program never opens it | master spec 7.1 | `root:<service group>` mode 0440, `player` not in the group |
| R62 | The load-started marker | `start-load` writes a root-owned marker holding T0 on each scheduler's state volume and restarts the service; a scheduler finding it comes back running | master spec 7.1 | the GM re-running `start-load` after every restart |
