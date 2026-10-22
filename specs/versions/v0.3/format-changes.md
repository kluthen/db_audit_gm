# v0.3 — format and tooling changes

Status: draft v1

Every change v0.3 makes to the scenario format, the brick and fault
definitions, the script contracts, the local implementation and
`gmctl`, gathered from the other drafts so the format skill, the
templates and the loader change once. Each line cites the ruling it
serves; names and shapes are (proposed) until the owner reviews this
draft. The cross-version [formats.md](../../formats.md) takes them at
consolidation.

## Scenario (`scenario.yaml`, `gm/answer-key.yaml`)

| Change | Serves |
|---|---|
| Scheduler nodes: brick `scheduler`, role `producer` or `consumer`, seed files `queries.yaml`, `builders/`, `jobs.yaml`, `schedule.yaml` under `nodes/<node>/` | D115, D116 |
| `aging:` the aging minimum (at least 48 h) and the intended hand-over time of day, in scenario time | D114, D129 |
| `difficulty:` the score, which the loader checks against the number of fault instances, and optionally the level it targets | D120, D134 |
| A fault instance's planting moment: `plant_at: T0` (the default) or a moment before hand-over (`handover-20h`) | D127 |
| A fault instance's aging minimum, when it needs more than its definition says | D114 |
| Per-file write policy: the node's `write_policy` is the default, and `write_overrides` set `fixable` on paths the brick lists as writable; a `fix` resolution needs the policy of the file the fault lives in | D130; O99 |
| Behavioural sealed checks state their window and threshold in the answer key | D124 |
| The story names the customer's time zone | D129 |
| Prometheus' retention covers the aging minimum plus four hours, checked by the loader against `aging:` unless the retention is a planted fault | D140 |

## Fault definition (`fault.yaml`)

| Change | Serves |
|---|---|
| `aging:` the technique (`real-time`, the only one in v0.3) and the minimum duration before the evidence shows; in the spec since v0.1, absent from the template and the loader | D114, D140 |
| Evidence: free text moves to `source`; `where` takes the location set, `node` meaning the target node | D140; O101 |
| Faults living in a scheduler's files use the existing seed-change injection kind on `queries.yaml`, `jobs.yaml` or `schedule.yaml` | D115 |
| `applies_to` lists the new bricks' versions (`scheduler` 0.1.0, `pgbouncer` 0.1.0) | D59, D86 |

## Brick definition (`brick.yaml`)

| Change | Serves |
|---|---|
| New role `pooler` in the roles list | D119 |
| `snapshot:` how the brick's volumes are copied at hand-over (online command, or stop and copy) | D126; O98 |
| `writable_paths` read by the loader for per-file overrides | D130 |
| Aged growth declared in the footprint's disk | D114 |

## Script contracts

| Change | Serves |
|---|---|
| Sealed checks: exit 3 means "too soon to tell", with the remaining window on the first output line | D124 |
| Sealed checks and validators connect so that the load cannot lock them out (ordinary roles for clients; the GM as `postgres` over the socket) | D124; O100 |

## Local implementation

| Change | Serves |
|---|---|
| Per-node placement on the playground's hosts, rendered as constraints | D128 |
| The registry every host reaches | D128 |
| The shift in whole hours, T0, the aging minimum, the earliest hand-over, the hand-over | D129, D114 |
| The seed | D136 |
| Where the hand-over snapshot is, and each restart (old and new game id, time, snapshot or not) | D126; O81 |
| Scheduled setup actions (faults planted during aging, the early check) | D127 |

## `gmctl` (proposed verbs)

| Verb | Does |
|---|---|
| `fit` (extended) | per host, counting aged growth and the snapshot |
| `start-load` | starts every scheduler's schedule at T0; refused once the game is handed over |
| `inject --at` | plants a fault at its moment during aging, scheduled on the manager |
| `snapshot` | takes the hand-over snapshot |
| `restart` | the rebuild of D123, from the snapshot or from nothing; only after the GM records the players' confirmation |
| `status` (extended) | the aging's progress, the shift, the snapshot; RG-3's tools-password line fixed |

No verb pauses, speeds up or triggers the load (D131).
