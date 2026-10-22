# v0.3 — aging in real time, and the game timeline

Status: draft v1

How a v0.3 game gets its history, and the moments from deployment to
teardown. The owner chose real-time aging (D114); everything else here
is (proposed). The general lifecycle is
[scenario-lifecycle.md](../../scenario-lifecycle.md); the research the
ruling rests on is summarised under "Why real time".

## The ruling (D114)

The stack runs in the background, its producers and consumers following
their schedules, for **at least two full, meaningful days** before
hand-over. No sped-up clock and no forged history in v0.3: every
timestamp, log line, metric and counter the players see was produced by
the system itself, at the time it says.

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
- every fault instance has reached its aging minimum: its definition's
  `aging` minimum duration ([formats.md](../../formats.md), "`fault.yaml`
  must contain"; not yet in the templates, which carry no aging field),
  e.g. two failed nightly runs, a table bloated past a threshold;
- the scenario states its aging minimum: at least 48 hours, more when a
  fault needs it.

A shape may differ by weekday; the GM picks the deployment time so that
the aged days are the ones the story needs (two working days, say).

## The timeline

Every time is UTC (D81).

| Moment | What happens |
|---|---|
| **Design** | The scenario is written, with its schedules, its aging minimum, and its intended hand-over time of day (O86) |
| **T0, deployment** | `fit`, `render`, `deploy`; data load; state faults planted. The scheduler nodes start idle |
| **T0, aging starts** | The GM starts the schedules, a setup action recorded in the local implementation with T0. From here no one touches the load (D117; O88) |
| **During aging** | The stack runs unattended. The GM session may end; the hosts must stay up. Scheduled steps, if allowed (O85), happen at their fixed times. An early check confirms the faults are taking (below) |
| **G, hand-over** | At least the aging minimum after T0. Solvability probes, if any (O20, O48), then the starter pack and the issues. The GM refuses to hand over before the aging minimum, as it refuses a playground too small (proposed) |
| **G to G + 4 h, the game** | At most four hours. The load keeps running; checks judge a living system ([checks-under-load.md](checks-under-load.md)) |
| **Final answer** | Sealed checks and the official validator run, load still running |
| **Teardown** | As in v0.2 (D36) |

The local implementation records T0, the aging minimum, the earliest
hand-over and the hand-over itself, so a fresh GM session (D39) finds
where the game is.

### Faults during aging

State faults are planted at T0, so their history covers the whole aging.
A fault meant to start later ("the index was dropped yesterday", "the new
release broke this query at 14:00") needs a step at a fixed time during
the aging, written into the scenario at design time: allowed or not is
O85.

### The early check

Halfway through, or after the first run of each fixed-time operation,
the GM (in a fresh session or through a scheduled `gmctl` run) checks
that every fault is present and the schedules are running: the sealed
checks read "present", the scheduler's log shows its keys running, and no
node is unhealthy. A failure found then still leaves time to set the
game up again; one found at hand-over costs the class (proposed).

### Monitoring retention

Prometheus keeps at least the aged history plus the game: a retention
of at least the aging minimum plus four hours, and a size bound that
holds it, unless a short retention is the planted fault.
`fernway-clinics-monitoring` keeps `1d` / `256MB` today
(`nodes/prometheus/prometheus.yml`), so it needs a longer retention
before it can be aged (proposed: carried, [carried-items.md](carried-items.md)).

### Disk over the aging

Fifty-two hours of load grow the volumes: tables, WAL, the PostgreSQL
logs pgBadger reads, the Prometheus TSDB, the scheduler's log. `fit`
counts the declared disk; the aged growth must be measured on the v0.3
scenario and declared in the footprints (proposed;
[load-and-capacity.md](load-and-capacity.md)).

## Restart (D110, D123)

A restart rebuilds the game from scratch (D123): every node shut down,
the game's data destroyed, fresh nodes started, the game set up again.
The replayed game may differ. It still needs the players' explicit
confirmation (D110).

With real-time aging, "set up again" meets the two days the first setup
took: a restart destroys the aged history. Options (O84):

- **(a) no history**: the restarted game has only the history since the
  restart. Faults whose evidence needs aging lose it; the GM says which
  before the players confirm, and judges the final answer accordingly.
- **(b) re-age**: the restarted game waits another aging minimum. Within
  a class, not a restart but a postponement.
- **(c) a hand-over snapshot** (the research's maintenance-snapshot
  hybrid, in real time): at hand-over the GM keeps a consistent copy of
  every volume of the game; a restart starts fresh nodes on fresh copies.
  The history then has a gap from hand-over to the restart, which the
  story can call a maintenance window. Costs disk (a copy of every
  volume) and a way to copy consistently: a short stop of every node at
  hand-over, or per-brick online copies (`pg_basebackup`, Prometheus'
  snapshot API, which needs its admin API on).

Recommended: (c) where the disk allows, (a) otherwise, with the GM
stating the lost evidence before confirmation. Still open in O81: who
may confirm, whether the game id and the players' credentials survive
(recommended: credentials kept, so the players log in as before; the
game id renewed, since a redeploy never reuses a volume, D36), how a
restart is recorded, and its place in the access model.

## Playgrounds that are not up for two days

Real-time aging needs the playground's hosts up from T0 to the end of
the game. A classroom swarm of the students' own laptops (a target
environment, [platform.md](../../platform.md), "Hosting") is not there
two days before the class, and a stateful node's volumes live on one
host (local driver). Options: O83.

## Open points

O20, O48 (probes as a gate), O81 and O84 (restart), O83 (playgrounds not
up for two days), O85 (scheduled steps), O86 (time of day), O88 (load
control), O89 (time compression).
