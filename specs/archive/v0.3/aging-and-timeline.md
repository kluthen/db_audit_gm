> **Archived 2026-10-30.** One of v0.3's eight drafts, consolidated into the v0.3 master spec on 2026-10-22 and kept since as the working record, stale by design where the master spec supersedes it; v0.3 was released on 2026-10-30 and merged into `main` as cba7be3. Live summary: [v0.3 master spec](../../versions/v0.3/master-spec.md). Relative links were written from `specs/versions/v0.3/`: `master-spec.md`, `access-model.md`, `README.md` and `wave-log.md` are in `../../versions/v0.3/`, and `../v0.2/` is `../../versions/v0.2/`; links between the files archived here still resolve.

# v0.3 — aging in real time, and the game timeline

Status: draft v3, consolidated

Consolidated into the [master spec](master-spec.md) and its [access
model](access-model.md) on 2026-10-22; its `(proposed)` items were accepted
as proposed (D146). Kept as v0.3's working record until the milestone is
archived; where it and the master spec differ, the master spec wins.

How a v0.3 game gets its history, and the moments from deployment to
teardown. Settled: real-time aging (D114), always-on hosts (D125), the
restart (D123, D126, D141, D142), timeline changes during aging (D127), the shift by
whole hours (D129), no time compression (D132), Prometheus retention
(D140). Everything else is (proposed) until the owner reviews this
draft. The general lifecycle is
[scenario-lifecycle.md](../../scenario-lifecycle.md).

## The ruling (D114)

The stack runs in the background, its producers and consumers following
their schedules, for **at least two full, meaningful days** before
hand-over. No sped-up clock, no forged history and no time compression in
v0.3 (D114, D132): every timestamp, log line, metric and counter the
players see was produced by the system itself, at the time it says.

## Why real time

The aging research (2026-10-22, measured on armenelos) compared real
time, a sped-up clock (libfaketime), container pause and resume, VM
snapshots, CRIU, time namespaces and whole-system simulation. Only real
time is consistent everywhere with no tricks. The sped-up clock's
caveats are real: every query duration PostgreSQL records is multiplied
by the speed-up (faithful only up to about 4x at a quarter-CPU nerf);
timeouts fire late; the Go binaries (Prometheus, Grafana,
`postgres_exporter`) cannot be faked, so Prometheus' history would have
to be forged and loaded by backfill, without alert history; file times
and process start times stay real and would give the trick away. Pause
and resume without a clock jump works only for a whole VM, for one exact
hand-over moment. Its cost, two days of host time per game, is accepted.

## What "meaningful" means

Two full days of the story's ordinary life (proposed):

- every traffic shape has gone through two full daily cycles (peaks,
  quiet nights) and every daily fixed-time operation has run at least
  twice;
- every fault instance has reached its aging minimum
  ([format-changes.md](format-changes.md)), e.g. two failed nightly runs,
  a table bloated past a threshold;
- the scenario states its aging minimum: at least 48 hours, more when a
  fault needs it.

A shape may differ by weekday; the GM picks the deployment time so that
the aged days are the ones the story needs (two working days, say).

## Time of day (D129)

A scenario is written in **scenario time**: its traffic shapes, its
fixed-time operations and its timeline changes, with the hand-over time
of day it was designed for. The local implementation shifts all of them
by a whole number of hours so that the real hand-over falls where the
design put it, and the game window gets the designed load. Every clock
stays real UTC (D81): the nodes, the logs and the tools are not touched,
only the schedule is rendered shifted. The story names the customer's
time zone, so a "nightly" batch the players see at 14:00 UTC is
nightly where the customer is. The shift is recorded in the local
implementation.

## The timeline

Every time is UTC (D81).

| Moment | What happens |
|---|---|
| **Design** | The scenario is written in scenario time, with its schedules, its timeline changes, its aging minimum and its intended hand-over time of day |
| **T0, deployment** | On always-on hosts (D125): `fit`, `render` (the shift applied, D129), `deploy`; data load; state faults planted. The scheduler nodes start idle |
| **T0, aging starts** | The GM starts the schedules, a setup action recorded in the local implementation with T0 |
| **During aging** | The stack runs unattended. The GM session may end; the hosts stay up. Timeline changes happen at their fixed times (D127). An early check confirms the faults are taking (below) |
| **G, hand-over** | At least the aging minimum after T0. Solvability probes, if any (O20, O48); the hand-over snapshot (D126); then the starter pack and the issues. The GM refuses to hand over before the aging minimum, as it refuses a playground too small (proposed) |
| **G to G + 4 h, the game** | At most four hours. The load keeps running; nobody touches it (D131); checks judge a living system ([checks-under-load.md](checks-under-load.md)) |
| **Final answer** | Sealed checks and the official validator run, load still running (D124, D131) |
| **Teardown** | As in v0.2 (D36), the hand-over snapshot with it |

The local implementation records T0, the shift, the aging minimum, the
earliest hand-over, the hand-over itself and the seed (D136), so a fresh
GM session (D39) finds where the game is.

### Faults and changes during aging (D127)

State faults are planted at T0 by default, so their history covers the
whole aging. A fault meant to start later ("the index was dropped
yesterday") or a change of behaviour ("the release of 14:00 broke this
query") is a timeline entry at a fixed moment during the aging, written
into the scenario at design time: a fault instance planted at
`handover-20h`, a stream switching key in the schedule's `timeline`
([scheduler.md](scheduler.md)). Never at or after hand-over (D117).
Planting a fault at its moment is a setup action of the GM's, run by a
scheduled `gmctl` call recorded in the local implementation (proposed),
since the GM session need not be open then.

### The early check

Halfway through, or after the first run of each fixed-time operation,
the GM (in a fresh session or through a scheduled `gmctl` run) checks
that every fault planted so far is present and the schedules are
running: the sealed checks read "present", the scheduler's log shows its
keys running, and no node is unhealthy. A failure found then still
leaves time to set the game up again; one found at hand-over costs the
class (proposed).

### Monitoring retention (D140)

Prometheus keeps at least the aged history plus the game: a retention of
at least the aging minimum plus four hours, and a size bound that holds
it, unless a short retention is the planted fault.
`fernway-clinics-monitoring` keeps `1d` / `256MB` today
(`nodes/prometheus/prometheus.yml`) and is raised in v0.3
([carried-items.md](carried-items.md)).

### Disk over the aging

Fifty-two hours of load grow the volumes: tables, WAL, the PostgreSQL
logs pgBadger reads, the Prometheus TSDB, the scheduler's log. The aged
growth is measured on the v0.3 scenario and declared in the footprints,
and `fit` counts it, plus the hand-over snapshot (proposed;
[load-and-capacity.md](load-and-capacity.md)).

## Restart (D110, D123, D126)

A restart rebuilds the game from scratch (D123): every node shut down,
the game's data destroyed, fresh nodes started, the game set up again.
The replayed game may differ (a new seed, D136). It needs the players'
explicit confirmation (D110).

What the restarted game starts from (D126):

- **The hand-over snapshot, where the disk allows.** At hand-over the GM
  keeps a consistent copy of every volume of the game. A restart starts
  fresh nodes on fresh copies of it. The history then has a gap from
  hand-over to the restart, which the story tells as a maintenance
  window. The copy is taken online, per brick (D142): each brick
  declares a `snapshot:` method in its definition, `pg_basebackup` for
  `postgres`, Prometheus' TSDB snapshot API for `prometheus` (its admin
  API on, reachable from the node's own shell: a trust-line exposure), a
  plain copy for volumes that hold only seeded files; a brick that
  declares none is stopped briefly while its volumes are copied. `fit`
  counts the copies' disk; when they do not fit, the game has no
  snapshot and a restart falls back to no history.
- **Otherwise, no history.** The restarted game has only the history
  since the restart. Before the players confirm, the GM names the
  evidence that is lost (the faults whose aging minimum the new game
  will not reach), and judges the final answer accordingly.

The players' credentials are kept, so they log in as before; the game id
is renewed, since a redeploy never reuses a volume (D36, D126).

The confirmation (D141): any player in the GM session may confirm, in so
many words, and only after the GM has stated that the game's state and
the players' changes are lost and, when there is no snapshot, which
evidence goes with them. A passing mention or a question never counts
(D110). The local implementation records each restart: the old and new
game ids, the time, from the snapshot or not. The access model lists
restart as a confirmed operation, beside `stop`, which needs no
confirmation.

## Playgrounds that are not up for two days (D125)

Real-time aging needs the playground's hosts up from T0 to the end of
the game, and a stateful node's volumes live on one host. v0.3 games run
on always-on hosts only. A classroom swarm of the students' own laptops,
which is not there two days before the class, waits for a later version
that copies the aged volumes to the class's hosts at hand-over (O22),
the hand-over snapshot's machinery (D142) being its first half.

## Open points

O20, O48 (probes as a gate).
