# v0.3 — archive

Status: archived 2026-10-30. v0.3 was released at its release gate on
2026-10-30 (items 1 to 15 passed, G9 and G10 cleared) and merged into
`main` the same day as cba7be3, on the owner's word. Live summary: the
[v0.3 page](../../versions/v0.3/README.md) and its release notes, and the
[v0.3 master spec](../../versions/v0.3/master-spec.md).

## Archived files

Kept verbatim; never edited after this pass. The moved documents keep
their names and depth (`specs/versions/v0.3/` to `specs/archive/v0.3/`);
their links to `master-spec.md`, `access-model.md`, `README.md` and
`wave-log.md`, which stay in `specs/versions/v0.3/`, no longer resolve
from here, as each file's notice says.

| File | Purpose |
|---|---|
| [build-plan.md](build-plan.md) | The v0.3 build plan, v15: chunks 1 to 15 in four waves, the gates G1 to G11, the release gate. Fully executed |
| [scheduler.md](scheduler.md) | Draft: the scheduler brick, the query repository, the schedule, fixed-time operations, what the players reach, drivers |
| [aging-and-timeline.md](aging-and-timeline.md) | Draft: real-time aging, time of day, the timeline from deployment to teardown, the restart |
| [load-and-capacity.md](load-and-capacity.md) | Draft: calibrating load, `max_connections`, load control, always-on hosts, several hosts |
| [faults-with-activity.md](faults-with-activity.md) | Draft: difficulty, v0.3's scenario, fault families that need activity, candidate faults |
| [checks-under-load.md](checks-under-load.md) | Draft: sealed checks, validators and smoke tests on a living system |
| [pgbouncer.md](pgbouncer.md) | Draft: the PgBouncer brick |
| [carried-items.md](carried-items.md) | Draft: earlier rulings and known issues landing in v0.3 |
| [format-changes.md](format-changes.md) | Draft: every change to the formats, script contracts, local implementation and `gmctl` |
| [review-list.md](review-list.md) | Every `(proposed)` item of the drafts and the consolidation, ruled in two rounds (R1–R46, R47–R62) |
| [decisions-D108-D112.md](decisions-D108-D112.md) | Decisions left live at the v0.2 close and since applied or settled: v0.2's report-only limit, its release-close rulings, the restart allowed from v0.3 |
| [decisions-D114-D189.md](decisions-D114-D189.md) | The decisions log from v0.3's drafting to wave 4's rulings, D114 to D189 |
| [open-questions-resolved.md](open-questions-resolved.md) | The open-questions register's "Resolved since v0.2 closed" list and its v0.3 section at v0.3 close |

The eight drafts were consolidated into the master spec on 2026-10-22
and kept since as the working record, stale by design where the master
spec supersedes them; they are archived as superseded snapshots.

## Where it now lives

Every archived decision is stated as fact in a live document, or marked
as history. Paths are relative to `specs/`. "MS" is
`versions/v0.3/master-spec.md` and "AM" `versions/v0.3/access-model.md`,
followed by their section numbers. "History" marks wording a later
decision replaced, or a process or build-sequencing ruling with no
standing content; "build record" points to the code or skill that now
carries a build ruling.

| ID | Ruling | Now lives in |
|---|---|---|
| D108 | The monitoring bricks are fixable only in v0.2; report-only monitoring nodes later | MS 7.4, 15.2, 16; `versions/v0.2/access-model.md` 11 |
| D109 | The tooling and the feedback judged good (G11) | `versions/v0.2/README.md` "Release notes" |
| D110 | Restarts from the next version, on explicit confirmation only | MS 12; `gm-stance.md` "During the game"; `versions/v0.2/README.md` "Known issues" |
| D111 | `bookshop-new-server`'s seed meets `postgres` 0.2.0 | `versions/v0.2/master-spec.md` 11.2; `versions/v0.2/README.md` "Release notes" |
| D112 | RG-2 and RG-3 accepted as v0.2 known issues | `versions/v0.2/README.md` "Known issues"; fixed in v0.3: MS 16 |
| D114 | Aging is real time | MS 8.1; `scenario-lifecycle.md` "Aging". History: its two days replaced by D150's floor |
| D115 | Producers and consumers are scheduler nodes running a query repository | MS 7.1 |
| D116 | What the players read and edit of the repository and the schedule | MS 7.1, 14; `planes-and-access.md` "The scheduler nodes" |
| D117 | No events outside the schedule | MS 9; `gm-stance.md` "During the game" |
| D118 | SQL against PostgreSQL in v0.3; other targets from v0.5 | MS 7.1, 2 "Out of scope"; `versions/v0.5/README.md` "In scope" |
| D119 | An optional PgBouncer brick | MS 7.2 |
| D120 | Difficulty is a fault count; scoring post-v1.0 | MS 15.1; `bricks-and-faults.md` "Faults"; open parts in O23, O38 |
| D121 | `ALTER SYSTEM` on a report-only database node on the trust line | MS 7.3, 14; `planes-and-access.md` "The database node" |
| D122 | Capacity discussed with the initiator; Swarm the platform | `platform.md` "Hosting"; MS 10 |
| D123 | A restart rebuilds the game from scratch | MS 12; `gm-stance.md` "During the game" |
| D124 | Checks judge a living system by its cause first | MS 11 |
| D125 | Always-on hosts only | MS 10.1; `platform.md` "Hosting"; the later volume copy in O22 |
| D126 | A restart restores a hand-over snapshot where the disk allows | MS 12 |
| D127 | Timeline changes at fixed moments during aging only | MS 8.4 |
| D128 | Multi-host in v0.3 | MS 10.2. History: its registry replaced by D149 |
| D129 | The schedule shifted by whole hours | MS 8.3 |
| D130 | The scheduler's log and configuration visible; write policy per file | MS 7.1, 14; `planes-and-access.md` "The scheduler nodes" |
| D131 | Nobody pauses, speeds up or triggers the load | MS 9 |
| D132 | No time compression | MS 8.1, 7.1 |
| D133 | A repository list is a pool | MS 7.1 |
| D134 | One new normal scenario, six to eight new catalog faults | MS 15.1, 15.2, 15.3 |
| D135 | The release gate includes one full aged run | MS 17; `versions/v0.3/README.md` "The aged run". History: its 48 h replaced by the scenario's declared aging (D150) |
| D136 | Randomness seeded per game | MS 7.1, 13 |
| D137 | A pluggable driver, SQL on PostgreSQL first | MS 7.1 |
| D138 | `max_connections` keeps 100; scenarios set low values | MS 7.3 |
| D139 | No PgBouncer metrics brick | MS 7.2 |
| D140 | v0.3 takes every carried item | MS 16 |
| D141 | Any player confirms a restart once the GM has stated what is lost | MS 12; AM; `gm-stance.md` "During the game" |
| D142 | The hand-over snapshot taken online, per brick | MS 6.4, 12; `formats.md` "Brick definition". History: its Prometheus method replaced by D147 |
| D143 | Write policy per file through `write_overrides` | MS 6.1, 6.4, 14; `planes-and-access.md` |
| D144 | The GM's connection reserve | MS 7.3, 11 |
| D145 | A fault definition's evidence locations | MS 6.3 |
| D146 | The review list R1–R46 accepted; v0.5 adjusts after use | MS; `versions/v0.5/README.md` "In scope"; `archive/v0.3/review-list.md` (archived) |
| D147 | Prometheus snapshotted by a brief stop | MS 6.4, 7.4; `formats.md` "Brick definition" |
| D148 | A fixable builder's schedule leak on the trust line | MS 7.1, 20; AM 8, 11 |
| D149 | Multi-host copies images, no registry | MS 10.2; `platform.md` "Image distribution" |
| D150 | An eight-hour aging floor; each scenario declares its aging | MS 8.2, 11; `gm-stance.md` "Aging feasibility". History: amended by D157 |
| D151 | The independent review's REJECT applied | History (process): its outcome is the master spec and the access model |
| D152 | Lost time up to thirty minutes does not move the earliest hand-over | MS 4, 7.1, 8.7; AM 6; `concept.md` "Vocabulary" |
| D153 | The review list's second round accepted | MS; AM. History (process) |
| D154 | The v0.3 master spec and access model approved | MS status line; AM |
| D155 | The re-review's nine corrections applied | MS 6.7, 7.1, 7.3, 8.3, 8.7, 11–13, 20; AM 3 |
| D156 | The v0.3 build plan approved | `versions/v0.3/README.md` "Status"; `archive/v0.3/build-plan.md` (archived) |
| D157 | Only a scenario with scheduler nodes ages | MS 8, 15.4 |
| D158 | A scenario with no scheduler node omits `aging:` | MS 6.1, 8, 13 |
| D159 | The VPS is shared; filetstudio.com never disturbed | `platform.md` "Hosting" |
| D160 | A static scenario's faults' own aging minima not counted | MS 8, 15.4 |
| D161 | The harness override caps each instance's aging minimum | MS 11 |
| D162 | Static games keep the hand-over check and snapshot | MS 8, 15.4 |
| D163 | `schedule.yaml` read in place from the seed config | MS 7.1 |
| D164 | Every `postgres` seed carries the replication line | Build record: `bricks/postgres/docs/gm.md`; the scenarios' and fixtures' seed `pg_hba.conf` |
| D165 | A behavioural check's window and threshold passed to its script | Build record: `.claude/skills/scenario-format/templates/fault.yaml`, `layouts.md`; `tools/gm/checks.py` |
| D166 | Wave 1's chunk order | History (build sequencing): `archive/v0.3/build-plan.md` "Waves" |
| D167 | Chunk 1 writes capture W1's brick keys and values | Build record: `bricks/*/brick.yaml`; capture W1 in `versions/v0.3/wave-log.md` (left in place) |
| D168 | `timezone_offset` in the wrong-time-zone fault's seed change | Build record: `bricks/scheduler/docs/gm.md`; `.claude/skills/scenario-format/templates/jobs.yaml`; `.claude/skills/game-master/gmctl.md` |
| D169 | `postgres`' root-only `check-psql` helper | Build record: `bricks/postgres/docs/gm.md`; `.claude/skills/scenario-format/SKILL.md` |
| D170 | The scheduler's writable paths are two directories | MS 6.7 |
| D171 | The GM check role's DO NOT TAMPER seed line | Build record: `bricks/postgres/docs/gm.md`; `.claude/skills/scenario-format/SKILL.md`, `templates/scenario.yaml` |
| D172 | The snapshot condition arrives with `snapshot` (chunk 11a) | History (build sequencing) |
| D173 | Host timers are persistent systemd user units | Build record: `.claude/skills/game-master/gmctl.md` |
| D174 | Outages read from Swarm's task history are a lower bound | Build record: `.claude/skills/game-master/gmctl.md` (`status`) |
| D175 | The lost time beyond thirty minutes moves the whole earliest hand-over | MS 8.7; AM 6 (`aging-done`) |
| D176 | `gmctl load-data` grants the GM check role `CONNECT` | MS 7.3 |
| D177 | PgBouncer from `trixie-pgdg`, pinned | MS 7.2 |
| D178 | The VPS may join armenelos' swarm; a membership change is a downtime | `platform.md` "Hosting" (written there at this archive) |
| D179 | Teardown per host is chunk 10b's | History (build sequencing); built in `tools/gm/teardown.py` |
| D180 | A node publishing ports is placed on the manager only | MS 7.5, 10.2 |
| D181 | The image copy goes through the host's SSH Docker context | MS 10.2, 20; `platform.md` "Image distribution" |
| D182 | A multi-host game's overlay /24 from a reserved range | MS 10.2. History: "reserved for `gmctl`" replaced by D183 |
| D183 | The overlay's range is the GM's to choose, per playground | MS 10.2, 13 |
| D184 | The overlay and ingress keep MTU 1230 | MS 10.2, 20 |
| D185 | The duplicates fault's sealed check as the GM check role, straight to port 5432 | MS 6.5, 7.1 |
| D186 | The held transactions' seed changes name both files | MS 15.3 |
| D187 | Without a snapshot, the restart names lost evidence by place and time span | MS 12 |
| D188 | Chunk 15a builds the v0.3 scenario as capture W4 item 10 proposes | MS 15.2 |
| D189 | A time-of-day fault's aging minimum counts from the first occurrence | MS 6.3 |

Resolved questions, each living where its deciding decision lives (row
above, or the v0.2 archive for D121's and earlier rows):

| Questions | Resolved by |
|---|---|
| O45 | D121 |
| O46 | D128 |
| O78 | D140 (its `ui:`/`report:` detail: D145) |
| O81 | D141 (narrowed by D123, D126) |
| O82 | D124 |
| O83 | D125 |
| O84 | D126 |
| O85 | D127 |
| O86 | D129 |
| O87 | D130 |
| O88 | D131 |
| O89 | D132 |
| O90 | D133 |
| O91 | D134 |
| O92 | D135 |
| O93 | D136 |
| O94 | D137 |
| O95 | D138 |
| O96 | D139 |
| O97 | D140 |
| O98 | D142 |
| O99 | D143 |
| O100 | D144 |
| O101 | D145 |
| O102 | D171 |
| O103 | D175 |

## Left in place

| Document | Role | Referrers |
|---|---|---|
| `specs/versions/v0.3/README.md` | The version's page: scope, definition of done, status, release notes, known issues RG-4, RG-6, RG-7 and the intermittent `smoke-load.sh` | `specs/README.md`, `specs/versions/README.md`, `specs/decisions.md`, archived decisions |
| `specs/versions/v0.3/master-spec.md` | The contract for what v0.3 built; the skills' stated source | `.claude/skills/game-master/SKILL.md`, `.claude/skills/scenario-format/SKILL.md`, `.claude/skills/scenario-document/SKILL.md`, `specs/formats.md`, `specs/scenario-lifecycle.md`, `specs/gm-stance.md`, `specs/planes-and-access.md`, `specs/versions/v0.5/README.md`, `specs/README.md`, `specs/versions/README.md` |
| `specs/versions/v0.3/access-model.md` | The master spec's companion; in force for v0.3 games | `.claude/skills/game-master/SKILL.md`, `specs/README.md`, `specs/versions/README.md` |
| `specs/versions/v0.3/wave-log.md` | Execution record, but its captures (W1 to W4) fix the brick keys, the scheduler's files, the fault and scenario templates and `gmctl`'s forms; moving it would change released bricks (a brick changes version with any change, its comments included) and the generated scenario document | `bricks/*/brick.yaml`, `bricks/scheduler/docs/gm.md`, `bricks/scheduler/program/gm_scheduler/__init__.py`, `.claude/skills/game-master/SKILL.md` and `gmctl.md`, `.claude/skills/scenario-format/SKILL.md` and its templates, `scenarios/tarnbeck-outdoor-shop/` (`brief.md`, `README.md`, `scenario.yaml`), `tools/gm/aging.py`, `docker.py`, `fit.py`, `model.py`, `render.py`, `tools/tests/test_model.py`, `tools/tests/fixtures/fixture-v03-refusals/` |

## Carried forward

- Every open question stays live in
  [open-questions.md](../../open-questions.md) with its ID: O2, O5, O10
  to O12, O16, O20 to O25, O29 to O32, O38, O47 to O49, O52 to O54, O79
  and O80. None was raised or resolved by this pass.
- Decisions D107 and D113 stay live in
  [decisions.md](../../decisions.md): brick options and the `monitoring`
  role made conditional, both still to be applied in v0.5.
- The forward parts of archived rulings live in the next versions'
  pages: the scheduler's other targets (D118) and the adjustment of
  v0.3's accepted defaults after use (D146) in the
  [v0.5 page](../../versions/v0.5/README.md); the volume copy for
  classroom swarms (D125) in O22; scoring (D120) in O38.
- Known issues RG-4, RG-6, RG-7, the intermittent `smoke-load.sh` and the
  producer's reconnection errors after a restart: in the
  [v0.3 page](../../versions/v0.3/README.md), "Known issues".
