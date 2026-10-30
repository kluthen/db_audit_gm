# db_audit_gm v0.4 — Build plan

Status: v1 (2026-10-30): the first plan, written from the approved
master spec's section 19.
Approval: **awaiting the owner** (G1).
Written from: [master-spec.md](master-spec.md) and
[access-model.md](access-model.md), approved 2026-10-30 (spec D215),
with the owner's rulings spec D211 to D214 written in.
No design set (no interface to design, spec D2).

The model is `~/.local/share/dev_team/references/build-plan-model.md`; this
plan states only its deltas. Its conventions follow v0.3's
[build plan](../../archive/v0.3/build-plan.md).

## Read first

- **Baseline.** v0.3's code on `main` (merge cba7be3; `main` at 6d6abb1
  when this plan was written): `postgres` and `bastion` at 0.3.0,
  `prometheus`, `postgres-exporter` and `grafana` at 0.2.0, `scheduler`
  and `pgbouncer` at 0.1.0, `tools/gm/`, the three skills, nineteen
  catalog faults, the scenarios `tarnbeck-outdoor-shop`,
  `bookshop-new-server` and `fernway-clinics-monitoring`, the fixtures
  `fixture-audit`, `fixture-mounted`, `fixture-monitoring`,
  `fixture-load` and `fixture-v03-refusals`. v0.3's wave-log captures W1
  to W4 ([../v0.3/wave-log.md](../v0.3/wave-log.md)) still fix the
  `gmctl` command lines, the bricks' paths and `brick.yaml` keys, the
  scheduler's runtime interface and the fixtures' shape. A chunk that
  changes one of them says so, and the wave driver records the new shape
  as a v0.4 capture.
- **No intent register and no data register** (no `.atd`, no `intent/`,
  no `data-register/`; checked 2026-10-30), and every scenario's data is
  synthetic. So there is no `documentalist` wave preflight, capture or
  sync, and no `data-steward` preflight or sync. Where a chunk names an
  **Architecture capture**, the wave driver records it in the wave log
  (`W<n>-<letter>`) on the wave branch before the chunk that depends on
  it starts, as in v0.1 to v0.3. Every chunk's **Atoms** and **Data**
  lines are therefore "none" and are left out below.
- **Dependency gating applies.** The project keeps a `.tech` file, kept
  by `security-advisor`. `postgres` 0.4.0 adds two packages, so its
  chunk waits for a dependency preflight (G5) and is followed by a
  post-change check (G6); `scheduler` 0.2.0 adds none.
- **One version per brick in the catalog.** The loader refuses a pin that
  does not match the brick's `version`. Chunk 1 bumps `postgres` to
  0.4.0 and `scheduler` to 0.2.0, adds the new version to every fault's
  `applies_to` that names either brick (seven each), and re-pins the
  three scenarios and the four fixtures that pin either brick, in the same
  commit; every later v0.4 change to either brick folds into that
  version, a brick version being released only by v0.4's release gate.
  The other five bricks are unchanged and keep their versions.
- **Templates are the loader's schema**, as in v0.3: `tools/gm/model.py`
  checks every definition against the format skill's templates, and the
  unit suite loads every folder under `bricks/`, `faults/` and
  `scenarios/`; from chunk 2 also `purposes/` and `domains/`.
- **Approved with the spec, and easy to miss** (spec D211 to D215):
  - `postgres` 0.4.0 gets **no report-only write policy** and no
    `cron.allow`; every database node stays fixable, `reporting` is the
    agency's by the story and the answer key alone, and an overstep is
    judged in the feedback, never credited (master spec 7.2, 16.5);
    `bi`, a scheduler node, keeps the report-only policy its brick
    enforces;
  - `shop_etl` reads `orders` without `customer_id` (a column grant), and
    `reporting`'s foreign tables declare only the columns the close needs
    (9.6, 9.7);
  - the baseline jobs judge consent by the latest consent event, never
    the opt-in flag (9.3, 10.2, 10.3);
  - a node's crontab roles are declared in `scenario.yaml` as
    `crontab_roles`, their secrets mounted for the password file (6.1,
    7.2);
  - f9's planting is a second foreign server, a foreign table, the churn
    table and a `pg_cron` job, and its check requires all of them gone
    (16.2);
  - f10 is an order-level roll-up calling a procedure from `reporting`'s
    crontab as `bi_etl`; a failed f10 is never re-planted within the
    aging (16.3);
  - f7 is expected to stay present in a game: its job is on `bi`, which
    the players cannot move (16.1, 16.5);
  - the gateway stub never acknowledges about one declaration in fifty,
    as standing behaviour (10.4);
  - the rehearsal runs without f10, by a harness-only override (18).
- **No fake time, and nobody triggers a job.** No chunk or test may speed
  up, freeze or forge a clock (master spec 8.4). A smoke cycle moves a
  job's time and reloads its runner, as a player may (an edit of
  `jobs.yaml`, of a crontab through `gm-crontab`), the harness doing it
  as root on a report-only node too; it never runs a job by hand (a
  `CALL`, a crontab entry's command typed in a shell).
  The rehearsal reaches its hand-over early through v0.3's test-harness
  override of the aging minimum (spec D161): it shortens the wait, never
  a clock.
- **Build host** (observed 2026-10-30): armenelos, a laptop, 12 CPUs,
  11 GiB of memory with about 3.1 GiB available, 11 GiB of swap with
  4.2 GiB in use, 10 GB free on `/`; `shellcheck` not installed. v0.3's
  build found it suspends when left idle (wave log, chunk 15b): long
  runs hold a sleep inhibitor ("Workflow deltas"). The new scenario
  reserves about 1.85 GB, and f10 deliberately exhausts a node's memory
  there (master spec 20).
- **What v0.3's build taught** ([../v0.3/wave-log.md](../v0.3/wave-log.md)):
  docker-using checks are serialized by the host lock; a fresh GM session
  reading `.claude/skills/game-master/` plays the GM at the gates,
  verifier agents play as `player` through the bastion only, GM-side
  checks run from the host; findings outside a chunk's Files line are
  fixed on the wave branch by a `coding-executor` in their own commits;
  the auto-mode classifier may refuse a step on the VPS, which the owner
  then runs.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | Plan approval | The owner | Wave 1 | open |
| G2 | [formats.md](../../formats.md) carries master spec 6: the purpose and the domain, `governance:`, the new scenario, answer-key, fault and brick fields, the optional crontab and `crontab_roles` (section 19: the format skill is updated after it) | `spec-writer` | Chunk 1 | done (2026-10-30, cf484b9; formats.md v22) |
| G3 | Network access at image build time: Debian 13's repositories (`cron`), the PostgreSQL apt repository (`postgresql-18`, `postgresql-18-cron`), the s6-overlay release, as in v0.3 | Hand check by the wave driver | Chunks 1, 3, 4 (image builds); every wave gate's builds | open |
| G4 | A Docker host in swarm mode: armenelos' swarm, the VPS a drained worker in it | Hand check by the wave driver | Every stack test, deployment and smoke run, chunk 9, every wave gate, the release gate | open |
| G5 | **Dependency preflight** on `postgres` 0.4.0's new packages: the candidate versions of `postgresql-18-cron` (PGDG) and of Debian's `cron` with what it pulls in, installed without recommends (master spec 7.2, 19). A finding the owner must rule on becomes a gate of its own | `security-advisor` (skill `dependency-check`), called by the wave driver at wave 1's start | Chunk 4's branch | open |
| G6 | **Dependency post-change check** on the versions chunk 4 resolved, and `.tech` updated (`postgres` 0.4.0, `scheduler` 0.2.0, the two packages), committed on `v0.4-w1` | `security-advisor`, called by the wave driver once chunk 4 has merged | Wave 1's gate | open |
| G7 | The VPS ready for two-host runs, under the VPS rule ("Workflow deltas"): `tailscale status` on both hosts; the VPS still a worker of armenelos' swarm, drained; no game port published on it; at least 5G free; filetstudio.com answering before and after | Hand check by the wave driver | The two-host `smoke-load.sh` from wave 2's gate; chunk 17's two-host runs; the release gate's two-host runs | open |
| G8 | **The judged moment before the hand-over.** Master spec 12.1 sets `CHECK_SINCE` to the hand-over by default, and says nothing of the checks run before it: the early check and the hand-over check, which must read each purpose fault present, and the smoke runs, which plant at once and never hand over. Proposed: before the hand-over, `CHECK_SINCE` is the instance's planting moment (as f10's incident check already reads, 16.3), raised to the runner's last reload as after it | The owner (a ruling for `spec-writer` to write into the spec and this plan) | Chunk 8's merge; the "Done when" of chunks 10, 11, 14, 15 as far as they read a check before a hand-over | open |
| G9 | **f10's measurement without swap, on armenelos only.** Master spec 16.3 measures `memory.peak` "on a host with swap and one without", and spec D213 keeps the calibration on armenelos, which has swap. Proposed: the no-swap figure taken from a container whose swap is zero (`docker run --memory=<limit> --memory-swap=<limit>`, outside Swarm, which cannot set it), never by turning armenelos' swap off; the alternative is the owner turning swap off on armenelos for the measurement | The owner | Chunk 9's no-swap measurement | open |
| G10 | **f10's calibration outcome** (spec D213): the backfill needs more than twice `reporting`'s limit and a normal run less than half of it, after `shared_buffers`, within a window the restored history allows. If so, the window is set from chunk 9's figures; if not, the fault comes back to the owner before anything is reshaped, lowering `reporting`'s limit the likely lever, offered then | Chunk 9's figures, applied by the wave driver; the owner on a shortfall | Chunk 15's f10 half; chunk 16 | open |
| G11 | The owner's judgement at release close: the smoke cycles, f10's run, the rehearsal, the feedback (overstepping and the incident report included), the named known limits | The owner | Release close | open |

G8 and G9 are questions this plan raises on the approved spec; neither
blocks wave 1, and both should be ruled before wave 2's first chunk
starts.

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3, 4, 5 | G1; G2 (chunk 1, done); G3, G4; G5 (chunk 4); G6 before its gate | planned |
| 2 | 6, 7, 8, 9, 10, 11 | wave 1; G8 (chunk 8's merge, the purpose checks); G9 (chunk 9); G7 (the gate's two-host run) | planned |
| 3 | 12, 13, 14, 15 | wave 2; G10 (chunk 15's f10 half) | planned |
| 4 | 16, 17, 18 | wave 3; G7 (chunk 17's two-host runs) | planned |

```
1 ──> 2, 3, 4          (in wave 1, cut once chunk 1 has merged into v0.4-w1; W1)
1 ──> 5                (in-wave: runs beside chunk 1, its files all under domains/shop/; W1)
G5 ──> 4
1, 2 ──> 6
2, 4 ──> 7
6 ──> 7                (in-wave: render's crontab shift and crontab_roles' secrets, fixed by master spec 14; W2)
2 ──> 8
4, 5 ──> 9
3, 5 ──> 10
3, 5 ──> 11
3, 4, 7 ──> 12
5, 6, 7, 10, 11 ──> 13
2, 7, 8, 10, 11 ──> 14
13 ──> 14              (in-wave: the fixture's nodes, roles and jobs, fixed by master spec 16.1; W3)
4, 6, 7, 9, 10 ──> 15
13, 12 ──> 15          (in-wave: the fixture, and the governance set's call interface; W3)
13, 14, 15 ──> 16
16 ──> 17              (in-wave: the scenario's instances and the jobs the harness moves; W4)
8, 9, 12 ──> 17
6, 7, 8, 14, 15 ──> 18
```

Wave 1's order: chunks 1 and 5 run first, side by side; chunks 2, 3 and 4
are cut from `v0.4-w1` once chunk 1 has merged (chunk 4 once G5 is
cleared too), so no two chunks running at once share a file. Chunk 1
owns the version lines of `postgres` and `scheduler`; chunks 3 and 4 own
the rest of their brick.

Wave 2: chunks 9, 10 and 11 need only wave 1, and chunk 9 runs as early
in the wave as the host lock allows: it is the early calibration spec
D213 asks for, and its outcome (G10) must be known before wave 3's f10
work. Chunk 7 is cut once chunk 6 has merged.

Wave 3: chunks 12 and 13 run first; chunks 14 and 15 are cut once chunk
13 has merged (chunk 15 once chunk 12 has too).

## Workflow deltas

- **κ = 3**, as in v0.3 (spec D156), unless the owner sets another at
  approval: chunks with no path between them run side by side, each in its
  own worktree. Docker-using checks (image builds, stack tests,
  deployments, smoke runs, the calibration, the rehearsal) are serialized
  by the host lock, `flock /tmp/dbagm-docker.lock <command>`. Chunk 9,
  chunk 15's f10 run, chunk 17's runs and the release gate hold the lock
  for their whole duration and run alone on the hosts.
- **Sleep inhibitor.** armenelos is a laptop and suspended during v0.3's
  build. Every docker run longer than a few minutes (a stack test series,
  a deployment, the calibration, a smoke run, the rehearsal, a wave gate,
  the release gate) runs under `systemd-inhibit --what=sleep:idle:handle-lid-switch`,
  held by the script itself where it is committed (as `rehearsal.sh`
  does) or by the wave driver around it, and released after.
- **The VPS** (spec D159, D209): the driver and its agents may work on it
  (`ssh vps`, `ssh://dbagm-vps` for the playground), never disturbing the
  applications it already hosts; filetstudio.com stays up throughout. Its
  own documentation is read before any change there; each session
  touching it checks `tailscale status` on both hosts first. A swarm
  membership change on the VPS is a downtime scheduled with the owner,
  never done unannounced. The VPS node **stays `drain`**; only a two-host
  run (a wave gate's two-host smoke run, chunk 17's two-host runs, the
  release gate's) sets it `active`, inside that run's host lock, and
  drains it again after, pass or fail (`docker node update
  --availability active|drain vps-5718ad52`, run by the owner if the
  auto-mode classifier refuses). **Never for f10**: chunk 9's
  calibration, chunk 15's f10 run, f10's smoke run and every run moving
  f10's job happen on armenelos alone, with the VPS drained. From chunk
  8, every playground declaration naming the VPS marks it `shared`
  (`--host vps-5718ad52,shared,endpoint=ssh://dbagm-vps,…`).
- **Never `docker * prune`** (`system`, `image`, `container`, `volume`,
  `network`, `builder`) on either host: superseded `dbagm` images are
  removed by name (`docker image rm 127.0.0.1:5000/dbagm/<brick>:<old>`)
  when the disk runs short, and nothing else is removed on the VPS.
- **Branches and worktrees**: waves `v0.4-w<n>` in
  `/home/bastien/work/db_audit_gm-wt/v0.4-w<n>`; chunks
  `v0.4-c<id>-<slug>` in `/home/bastien/work/db_audit_gm-wt/v0.4-c<id>-<slug>`.
  Never in the main checkout.
- **Shared lists**, under the model's in-wave rule: `tools/gm/__init__.py`'s
  verb and option registrations, `.claude/skills/game-master/gmctl.md`'s
  verb table, the root `README.md`'s brick, fault, purpose and domain
  tables, the bricks' "Supported faults" sections in `docs/gm.md` (chunks
  14 and 15 both add to `postgres`'), and the smoke scripts' `IMAGES=`
  lists.
- **Chunk checks**, in addition to the model's:
  - Python: `python3 -m unittest discover -s tools/tests -t .`;
  - the scheduler program's unit tests, run inside its image:
    `sh bricks/scheduler/tests/run-unit-tests.sh`;
  - Python outside both suites (transformer scripts, purpose and fault
    checks written in Python): `python3 -m py_compile` on every file the
    chunk touches;
  - shell: `sh -n` on every shell file the chunk touches, those without an
    extension included (s6 `run` files, `rootfs/usr/local/sbin/*`,
    `rootfs/usr/local/lib/gm/*`, fault and purpose check scripts);
    `shellcheck` too when installed;
  - Perl: `perl -c` on every Perl file the chunk touches;
  - YAML: every YAML file the chunk touches loads with PyYAML;
  - SQL: a data file, schema or material the chunk adds runs into the
    `postgres` image at its current tag, in a throwaway container under
    the host lock;
  - a chunk touching a brick: `docker build -t
    127.0.0.1:5000/dbagm/<brick>:<version> bricks/<brick>` and its stack
    test, `sh bricks/<brick>/tests/run-stack-test.sh` (needs G4);
  - a chunk changing a scenario's or fixture's `scenario.yaml` or
    `gm/answer-key.yaml`: its `README.md` regenerated with the
    scenario-document skill in the same commit;
  - a chunk adding or changing a `gmctl` invocation in a Markdown file:
    the invocation parses with `gmctl`'s own parser.
- **Wave gate (full quality command)**, every step under the host lock and
  the sleep inhibitor, at κ = 1 for the gate itself: the full unit suite;
  the scheduler's unit tests; `sh -n` on every shell file, `perl -c` on
  every Perl file, `py_compile` on every Python file outside the suites;
  all seven bricks' image builds and stack tests; `sh tools/tests/smoke.sh`;
  `sh tools/tests/smoke-monitoring.sh`; `sh tools/tests/smoke-scenario.sh`
  on `bookshop-new-server`, `fernway-clinics-monitoring` and
  `tarnbeck-outdoor-shop`, v0.3's smoke runs unchanged on the new
  versions (master spec 16.4); `sh tools/tests/smoke-load.sh` on armenelos
  alone, and from wave 2 on armenelos plus the VPS (G7; the VPS `active`
  for that run only, declared `shared`); from wave 3, chunk 13's
  deployment of `fixture-campaign` with every job running and G1 to G4
  passing; from wave 4, chunk 17's runs on the new scenario.
- No link checker is configured; Markdown links are checked by reading.
- Images are tagged `127.0.0.1:5000/dbagm/<brick>:<version>`, as before;
  every pinned download is checked against its published checksum in the
  Dockerfile.
- The release gate runs on `v0.4-w4` before it merges, as v0.3's did.

## Measurements and hand checks

- G3, G4 and G7: hand checks by the wave driver, G3 and G4 before wave 1,
  G7 before wave 2's gate; G7 under the VPS rule (`tailscale status` on
  both hosts first, filetstudio.com answering before and after).
- G5 and G6: `security-advisor`'s dependency checks, recorded in the wave
  log; `.tech` updated on `v0.4-w1`.
- Each bumped brick's footprint at rest: in its chunk's stack test
  (chunks 3, 4), as a first figure.
- f10's calibration: chunk 9, on armenelos alone, the VPS drained, under
  the host lock: the `reporting` container's `memory.peak` around a
  normal run and around the backfill, with swap (a Swarm service at the
  scenario's limit) and without (G9), with machine and date; G10 applies
  them.
- f10's incident for real: chunk 15 on `fixture-campaign`, then chunk 17
  and the release gate on the scenario, armenelos alone.
- Every node's memory at peak, `reporting`, `bi`, `crm` and `gateway`
  included; the trace's growth per hour, extrapolated over the
  sixteen-hour aging and stated as an extrapolation: chunk 17b's
  rehearsal on armenelos plus the VPS, recorded in the wave log with
  machine and date; measured again at the release gate.
- No aged run (spec D193): none is planned before v1.0.

## Left for the build (master spec 22)

Each item is settled by the chunk named, recorded in its **Record** line
and, where it is a brick's, in the brick's `docs/gm.md`; the release gate
checks that each is recorded.

| Item | Chunk |
|---|---|
| Every footprint, the new nodes' starting sizes, the trace's growth per hour | 3, 4 (at rest); 17b (rehearsal) |
| f10's backfill window | 9 (G10) |
| The gateway's acknowledgement delay and how the unacknowledged one in fifty is chosen | 11 |
| The gateway outage's moment, and the timeline moments of f2 and f8 within the aging | 14 (the faults' definitions), 16 (the scenario) |
| The `etl_runs` columns each job fills; the payload schemas of the two outboxes | 5 (the tables), 10, 11 (the jobs) |
| The mapping-roles function's name and the read policy's form | 7 |
| Where the governance check set lives and how a fault's check calls it | 12 |
| The scheduler-side means a purpose check uses to read runs, the last reload and the next run | 3b |

## Chunks

### Chunk 1 — Format skill, templates, the v0.4 versions and the re-pins

Status: planned
Wave: 1
Depends on: G1, G2; G3, G4 (the two images at their new tags)
Architecture capture: recorded by the wave driver at wave 1 start (W1),
for chunks 2 to 5:
- the template keys of master spec 6.9 and where each sits: `purposes:`
  with each part's mapping, `domain:`, `governance:` (`policy`,
  `classes` with `locations`, `readers`, `outbound` with `to` and
  `fields`, `separation`), a node's `crontab_roles`, the answer key's
  `judges` and `threshold`, the fault's `applies_to.purposes`,
  `sealed_check.judges` and `needs_unshared_host`, the brick's
  `seed.optional`;
- the purpose and domain layouts (6.7, 6.8), the keys of `purpose.yaml`
  and `domain.yaml`, and the shape of `classification.yaml`;
- the transformer script's repository entry and a script job's
  `connections:` (7.1), the `scripts/` seed entry;
- `postgres` 0.4.0's new `brick.yaml` entries as chunk 4 is to build
  them: the optional seed `crontab` and its live path, the volume
  `cronspool` (snapshot `copy`), `gm-crontab` in the sudoers, the crontab
  roles' secrets (`role_<role>_password`) and the password file's path,
  the cron log directory on `pglog`.

- Goal: v0.4's formats in the format and scenario-document skills, the
  two bumped bricks at their v0.4 versions, every pin and `applies_to`
  brought to them, the suite green.
- Scope: in:
  - **1a, versions and the brick and fault formats**: `postgres` 0.4.0
    and `scheduler` 0.2.0 (`brick.yaml`'s version line, `docs/gm.md`'s
    version lines and image tags, the stack tests' tags); the seven
    faults applying to `postgres` and the seven applying to `scheduler`
    given the new version in `applies_to`; `tarnbeck-outdoor-shop`
    re-pinned to both, `bookshop-new-server` and
    `fernway-clinics-monitoring` to `postgres` 0.4.0, the fixtures
    `fixture-audit`, `fixture-load`, `fixture-monitoring` and
    `fixture-v03-refusals` likewise, otherwise unchanged; their READMEs
    regenerated; the templates `brick.yaml` (`seed.optional`, the
    `transformer` role), `fault.yaml` (`applies_to.purposes`,
    `sealed_check.judges`, `needs_unshared_host`, the `governance-*` and
    `security-*` ids in the Security family, `data-flow` and `rules` for
    purpose faults, the aging minimum counted from the job's first run
    after planting), `brick-gm.md` (a section per database-node job
    kind), `layouts.md` (`purposes/`, `domains/`, `scripts/`, the
    crontab); the skill's brick and fault rules;
  - **1b, the scenario, purpose and domain formats**: the templates
    `scenario.yaml` (`purposes:`, `domain:`, `governance:`, several
    `postgres` nodes, `crontab_roles`), `answer-key.yaml` (`judges`,
    `threshold`, no window; a tooling expectation naming an unmonitored
    instance), `queries.yaml` and `jobs.yaml` (the script entry,
    `connections:`), and new templates `purpose.yaml`, `domain.yaml` and
    `classification.yaml`; the skill's completeness rules for a purpose
    and a domain, for `governance:` and the policy file (written by the
    GM from `governance:`, in the story's voice, correct, unchecked rules
    stated unmarked), every `database` node of a scenario with
    `governance:` admitting the GM check role from the game network in
    its seed `pg_hba.conf` under the DO NOT TAMPER comment, the optional
    crontab with its `crontab_roles`, `pg_cron` turned on by the seed
    and the data file, `{{customer_timezone}}` in scheduler seed files
    and `cron.timezone`, the crontab written in scenario time, the
    placement guideline (8.7), a second instance's exporter (13.4), the
    starter pack naming every job the players may move; the
    scenario-document skill: the purposes a scenario uses, its governance
    and policy file, its database-node jobs.
  - Out: any loader, renderer or image change (chunks 2, 4, 6); the
    bricks' features (chunks 3, 4).
- Files: `.claude/skills/scenario-format/SKILL.md`,
  `.claude/skills/scenario-format/templates/{brick.yaml,brick-gm.md,fault.yaml,layouts.md,scenario.yaml,answer-key.yaml,queries.yaml,jobs.yaml}`,
  `.claude/skills/scenario-format/templates/{purpose.yaml,domain.yaml,classification.yaml}`
  (new), `.claude/skills/scenario-document/{SKILL,template}.md`;
  `bricks/{postgres,scheduler}/brick.yaml` and `docs/gm.md` (version
  lines and tags only), `bricks/{postgres,scheduler}/tests/{run-stack-test.sh,stack.test.yml}`
  (tags only); the fourteen `faults/*/fault.yaml`;
  `scenarios/{tarnbeck-outdoor-shop,bookshop-new-server,fernway-clinics-monitoring}/{scenario.yaml,README.md}`;
  `tools/tests/fixtures/fixture-{audit,load,monitoring,v03-refusals}/`
  (pins and READMEs); the unit tests and smoke scripts naming the old
  tags, as the build finds them; the root `README.md`'s tables.
- Spec sections: master spec 5, 6, 7.1 (the repository entry), 7.2 (the
  seed and the crontab), 8.5, 8.7, 11.3, 11.5, 13.4, 14 ("The format
  skill", "The scenario document skill"), 16.4, 19;
  [formats.md](../../formats.md) after G2; spec D206, D207, D211, D215.
- Done when: every template carries every item master spec 6 requires
  and loads as YAML; the loader, unchanged, loads every brick at its
  version, every fault, the three scenarios and the fixtures; the unit
  suite (with `test_brick_docs`) passes; both images build at their new
  tags and their stack tests pass; every README matches a fresh
  regeneration.
- Verification: chunk checks.
- Split rule: 1a versions, re-pins and the brick and fault formats; 1b
  the scenario, answer-key, purpose and domain formats and the
  scenario-document skill. Each half leaves the suite green.

### Chunk 2 — Loader checks for v0.4

Status: planned
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; W1
Architecture capture: none of its own; it implements W1.

- Goal: the scripts refuse what master spec 6 and 14 say the loader
  refuses, with the list of what is missing or wrong.
- Scope: in:
  - **2a**: scenarios: `purposes:` (each purpose exists under
    `purposes/`; every part mapped to a node of the right role and, for
    `source` and `target`, a database its data file creates; every job's
    key and name existing on the mapped runner); `domain:` naming a
    domain under `domains/`; `governance:` (every class named defined,
    every location a `database` node and a database its data file
    creates, every reader a role a data file creates, the policy file
    present); faults: `applies_to.purposes` naming existing purposes,
    `sealed_check.judges` one of `runs`, `triggers` or absent,
    `needs_unshared_host` a boolean; answer keys: `judges` with a
    `threshold` and no window; bricks: `seed.optional` among the seed
    files; the unit suite loading `purposes/` and `domains/` as it loads
    bricks and faults;
  - **2b**: `scheduler` 0.2.0's files: a script key's file and function
    existing, a stream naming a script key refused, a script key's job
    naming `connections:` (each a connection of the schedule) and no
    `connection:`, any other job the reverse; `postgres` 0.4.0's
    optional `crontab`, a seeded crontab requiring `crontab_roles`, each
    a role a data file of the node creates, `crontab_roles` without a
    crontab refused; a data file creating `pg_cron` only on a node whose
    seed `postgresql.conf` preloads it, `cron.database_name` naming a
    database that data file creates;
  - refusal fixtures and unit tests for each.
  - Out: rendering any of it (chunk 6); `fit` (chunk 8).
- Files: `tools/gm/model.py`, `tools/tests/test_model.py`,
  `tools/tests/fixtures/fixture-v04-refusals/` (new).
- Spec sections: master spec 6.1 to 6.4, 6.9, 7.1, 7.2, 14 ("The
  loader"), 20.
- Done when: unit tests show each refusal with its message, and the
  acceptance of a valid fixture; every catalog definition still loads;
  the unit suite passes.
- Verification: chunk checks.
- Split rule: 2a scenario, fault, answer-key and brick checks with
  purposes, domains and governance; 2b the scheduler's script keys and
  the `postgres` crontab and `pg_cron` checks.

### Chunk 3 — `scheduler` 0.2.0

Status: planned
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; W1; G3, G4
Architecture capture: none of its own; it records as built, as W1-x
(read by chunks 10, 11, 12, 14): the script call and its log lines, the
scripts' digests in `/run/scheduler/loaded`, and the means a purpose
check uses on the node.

- Goal: the job runner of master spec 7.1, extended, not forked:
  transformer scripts and the `transformer` role, and what a purpose
  check reads on a scheduler node.
- Scope: in:
  - **3a, the transformer script**: the fifth repository form
    `{script: scripts/<file>:<function>, options}`; the optional seed
    entry `scripts/`, read by the players and fixable where the
    repository is, as `builders/` are; a script key's job naming
    `connections:`, checked by the program and its `check` verb; the
    call `<function>(conns, options, log)`, each connection open as the
    schedule's role for it, autocommit off, the script committing and
    returning the rows it wrote; `script job=<name> <text>` lines; the
    run in a worker thread, the next skipped while one is going; an
    exception ending the run with `status=error` (`sqlstate=` or
    `error=`); the scripts' digests in `/run/scheduler/loaded` and in
    `pending`; the `transformer` role in `brick.yaml`; unit tests (rows
    moved between two databases as two roles, an exception, a skipped
    run, a stream refused on a script key);
  - **3b, what the checks read, the documentation and the stack test**:
    a root-only means beside `check-sql` (its form the chunk's, recorded
    in W1-x) giving a job's completed runs since a moment from the log,
    the runner's last `reload status=ok`, and a job's next run in the
    loaded `jobs.yaml` by the program's own cron parser (12.1, 12.2);
    `docs/player.md` (scripts, connections, moving a job to verify a
    fix) and `docs/gm.md` (the script contract, the role, the means
    above, footprint); the stack test: a transformer node running a
    script job between two databases, its run lines, the means' answers;
    the footprint at rest.
  - Out: any package (none added, master spec 19); the purposes'
    material (chunks 10, 11).
- Files: `bricks/scheduler/program/gm_scheduler/{repository,jobs,runner,policy,textlog,__main__}.py`
  and a new module for scripts if the build wants one,
  `bricks/scheduler/{brick.yaml,docs/gm.md,docs/player.md}`, a new
  helper under `bricks/scheduler/rootfs/usr/local/lib/gm/`,
  `bricks/scheduler/tests/unit/{test_program,test_parts}.py`,
  `bricks/scheduler/tests/fixtures/scripts/` (new),
  `bricks/scheduler/tests/{run-stack-test.sh,stack.test.yml}`.
- Spec sections: master spec 6.5, 7.1, 12.1, 12.2, 20; access model 4,
  5, 8, 12.
- Done when: the unit tests show each item of 3a; the image builds and
  its stack test passes; the loader accepts the brick; `test_brick_docs`
  passes; v0.3's schedulers behave as before (tarnbeck's smoke run at the
  wave gate).
- Verification: chunk checks, plus the scheduler's unit tests and its
  stack test (needs G4).
- Split rule: 3a the script form, the call and the run; 3b the checks'
  means, the documentation and the stack test.

### Chunk 4 — `postgres` 0.4.0

Status: planned
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; W1; G5 cleared before the branch is cut; G3, G4
Architecture capture: none of its own; it records as built, as W1-x
(read by chunks 6, 7, 9, 12, 15): the cron service, the crontab's and the
password file's paths, `gm-crontab`'s form, `check-psql`'s other-node
form.

- Goal: the database brick of master spec 7.2: jobs on a database node,
  the out-of-memory victim, the check helper reaching another instance.
- Scope: in:
  - **4a, `pg_cron` and the cron daemon**: the Dockerfile installing
    `postgresql-18-cron` and Debian's `cron` without recommends, at the
    versions G5 cleared; the s6 longrun `cron` (`cron -f`, after
    `postgres`; marked down and exiting when the node seeds no crontab);
    shutdown stopping `cron` before `postgres`; the optional seed
    `crontab`, installed once into `postgres`'s spool on the volume
    `cronspool` (snapshot `copy`), a player's replacement surviving a
    restart; `gm-crontab -l` and `gm-crontab <file>` through `sudo`;
    `gm-entrypoint` writing the password file of the node's
    `crontab_roles` from their mounted secrets, readable by OS user
    `postgres` only; `/var/log/postgresql/cron/` on `pglog`, readable by
    the players' group; `brick.yaml` (`seed.optional: [crontab]`, the
    volume, the secrets, the protected files); stack test: a crontab
    entry connecting as a customer role through `PGPASSFILE`, the daemon
    down without a crontab, `gm-crontab` listing and replacing,
    `pg_cron` preloaded with a job scheduled by
    `cron.schedule_in_database(…, username => <role>)` running as that
    role and filling `cron.job_run_details`;
  - **4b, the victim, `check-psql` and the documentation**: the run
    script exporting `PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj` and
    `PG_OOM_ADJUST_VALUE=300`, a backend at +300 and the postmaster, s6,
    `sshd` and `cron` at 0 in the stack test; `check-psql <node>`
    reaching another database node's instance as the GM check role over
    the game network (two containers in the stack test); `docs/player.md`
    and `docs/gm.md` sections for `pg_cron` and the cron daemon (what
    each is, how a scenario turns it on, its cost, the faults it
    allows), the victim, `check-psql`'s other-node form; the footprint at
    rest.
  - Out: a report-only write policy and `cron.allow` (none, spec D211);
    `load-data`'s read policy and mapping-roles function (chunk 7).
- Files: `bricks/postgres/{Dockerfile,brick.yaml}`,
  `bricks/postgres/rootfs/etc/s6-overlay/s6-rc.d/cron/` (new),
  `bricks/postgres/rootfs/etc/s6-overlay/user-bundles.d/user/contents.d/cron`
  (new), `bricks/postgres/rootfs/etc/s6-overlay/s6-rc.d/postgres/run`,
  `bricks/postgres/rootfs/usr/local/sbin/{gm-entrypoint,gm-crontab}`
  (`gm-crontab` new), `bricks/postgres/rootfs/etc/sudoers.d/gm-player`,
  `bricks/postgres/rootfs/usr/local/lib/gm/check-psql`,
  `bricks/postgres/docs/{gm,player}.md`,
  `bricks/postgres/tests/{run-stack-test.sh,stack.test.yml,fixtures/}`.
- Spec sections: master spec 6.4, 6.5, 7.2, 12.5, 16.3 (the victim), 19,
  20; access model 5, 8, 9.4, 12; spec D206, D209, D211.
- Done when: the stack test shows each item of 4a and 4b; the loader
  accepts the brick; `test_brick_docs` passes; a node seeding neither
  `pg_cron` nor a crontab behaves as 0.3.0 (v0.3's scenarios at the wave
  gate); G6 run once merged.
- Verification: chunk checks, plus the stack test (needs G4); G6 after
  its merge.
- Split rule: 4a the packages, `pg_cron` and the cron daemon; 4b the
  victim, `check-psql` and the documentation.

### Chunk 5 — The shop domain

Status: planned
Wave: 1
Depends on: chunk 1 (in-wave, W1: runs beside chunk 1, its files all
under `domains/shop/`)
Architecture capture: none of its own; it uses W1.

- Goal: the shop as the first domain, `domains/shop/`, derived from
  `tarnbeck-outdoor-shop`'s data file, which stays as it is.
- Scope: in:
  - **5a, the data model**: `domain.yaml` (identity, parts, the four
    purposes that fit); `data/schema.sql`: tarnbeck's business tables
    plus `business_settings`, customers' address, country and time zone,
    `consent_events` beside `marketing_opt_in`, `orders.packed_at`,
    `shipped_at` and `ship_country`, `export_countries`, `last_order_at`
    from an archived history, the purposes' tables in `shop`
    (`campaigns`, `leads`, `mail_outbox`, `customs_outbox`,
    `customs_acks`, `incidents`, `etl_runs`), the materialized view
    `popular_products`, `daily_sales` gone; the roles and grants of
    master spec 9.7 (`shop_etl` without `orders.customer_id`,
    `shop_refresh` with `MAINTAIN`); `data/load.sql`: the generated
    history at tarnbeck's sizes, recipients' zones relative to the
    customer's as 9.3 distributes them, the consent history, about a
    third lapsed, one active `winback` campaign, `business_settings`
    written from the `psql` variables `customer_timezone` and
    `customer_utc_offset`; `data/classification.yaml` classing every
    column as 9.9 does;
  - **5b, the producer and the notes**: `producers/`, the web shop's
    repository and schedule fragments from tarnbeck's producer plus
    `consent.unsubscribe` (about 20 an hour, weighted to lapsed
    customers), `consent.subscribe` (about 30 an hour), `orders.status`
    setting `packed_at` and `shipped_at`, `orders.place` setting
    `ship_country`; `docs/gm.md` (the business, its rules, its traps).
  - Out: the reporting instance's tables (chunk 10); any scenario.
- Files: `domains/shop/{domain.yaml,data/schema.sql,data/load.sql,data/classification.yaml,docs/gm.md}`
  and `domains/shop/producers/` (all new); the root `README.md`'s table.
- Spec sections: master spec 6.8, 8.5, 9, 11.2, 11.3; access model 9.1.
- Done when: the format skill (1b's rules) finds nothing missing; the
  schema and the load run into the `postgres` image with both variables
  set, a shift of 0 and a non-zero one; every role holds exactly the
  grants of 9.7 (`shop_etl` refused `orders.customer_id`); every column
  is classed; the producer fragments parse as `queries.yaml` and
  `schedule.yaml` fragments; the unit suite loads the domain once chunk 2
  has merged.
- Verification: chunk checks.
- Split rule: 5a the data model and the classification; 5b the producer
  fragments and the notes.

### Chunk 6 — Render for v0.4

Status: planned
Wave: 2
Depends on: chunks 1, 2
Architecture capture: none.

- Goal: render as master spec 8.5 and 14 say: the customer's zone in the
  new seed files, a crontab's hours shifted, the crontab roles' secrets
  mounted.
- Scope: in: `{{customer_timezone}}` (as `Etc/GMT∓N`) substituted in
  every scheduler node's seed files and in a `postgres` node's seed
  `postgresql.conf` (`cron.timezone`); a seeded crontab's hour fields
  shifted from scenario time to UTC as `jobs.yaml`'s are (lists, ranges
  and steps, wrapping modulo 24); the secrets of a node's
  `crontab_roles` (`role_<role>_password`, the ones `load-data` sets)
  declared for that node and mounted into it; the loader's
  `{{customer_timezone}}` rule widened to the files render now fills.
  Out: `pg_cron` schedules (written in scenario time, unshifted, 8.5).
- Files: `tools/gm/{render,localimpl,deploy}.py`, `tools/gm/model.py`
  (the placeholder rule only), `tools/tests/{test_render,test_deploy}.py`.
- Spec sections: master spec 7.2, 8.5, 14 (`render`); access model 8.
- Done when: unit tests show the zone substituted, crontab entries with
  ranges and lists shifted at shifts of 0 and non-zero, the crontab
  roles' secrets declared and mounted; v0.3's scenarios and fixtures
  render as before.
- Verification: chunk checks.

### Chunk 7 — `load-data` for v0.4

Status: planned
Wave: 2
Depends on: chunks 2, 4; chunk 6 (in-wave, W2: its fixture's crontab
role needs render's mount), merged into `v0.4-w2` before this chunk's
branch is cut
Architecture capture: none of its own; it records as built, as W2-x
(read by chunks 12, 15): the mapping-roles function's name and signature
and the read policy's form.

- Goal: `load-data` as master spec 14 says, and a small two-instance
  fixture to prove it on.
- Scope: in: the zone and its offset passed to `psql` as
  `-v customer_timezone=… -v customer_utc_offset=…` for every data file;
  each user mapping's password set from its remote role's secret, where a
  data file creates a foreign server; the GM check role's read policy on
  `cron.job` and `cron.job_run_details` where `pg_cron` exists, narrower
  than `BYPASSRLS`; the mapping-roles function (owned by `postgres`,
  `SECURITY DEFINER`, executable by the GM check role only, returning
  each mapping's server, local role and remote role, never its password)
  where a foreign server exists; `CONNECT` for the GM check role on every
  database of every instance; `fixture-instances` (new: two `postgres`
  0.4.0 nodes, `pg_cron` on one, a foreign server and a user mapping
  between them, a seeded crontab with a crontab role, no scheduler node).
- Files: `tools/gm/inject.py`, `tools/gm/localimpl.py` if the secret
  names need it, `tools/tests/test_inject.py`,
  `tools/tests/fixtures/fixture-instances/` (new).
- Spec sections: master spec 7.2, 8.5, 8.6, 11.6, 14 (`load-data`);
  access model 8.
- Done when: unit tests show each step and its order; on a deployment of
  `fixture-instances` on armenelos, the GM check role reads both `pg_cron`
  tables and every job in them, calls the function and sees no password,
  the user mapping connects, the crontab entry runs as its role; the
  fixture's README matches a fresh regeneration.
- Verification: chunk checks, plus the deployment (needs G4).

### Chunk 8 — `fit` and `check`: shared hosts, the judged moment

Status: planned
Wave: 2
Depends on: chunk 2; G8 before merge
Architecture capture: none.

- Goal: `fit` keeps a node that may exhaust its memory off shared hosts;
  `check` gives a purpose check its judged moment.
- Scope: in:
  - **8a, `fit`**: the host declaration `--host <name>[,manager][,shared],…`;
    a node carrying a fault instance whose fault declares
    `needs_unshared_host` refused on a shared host, naming the mapping
    to change, as a node publishing ports off the manager is; a
    playground whose only hosts are shared refused for such a scenario;
    the VPS declared `shared` in the harness's committed playground
    declarations and usage comments (`rehearsal.sh`, `smoke-load.sh`);
  - **8b, `check`**: `CHECK_SINCE` (UTC) passed to a check whose answer
    key says `judges: runs` or `triggers`, with `CHECK_THRESHOLD`: the
    hand-over from the state, and before it as G8 rules; `--since
    <time>`, per instance with `--instance <id>`; the result line for an
    exit 3 naming the time to the next run.
  - Out: the checks themselves (chunks 10 to 15).
- Files: `tools/gm/{fit,checks,__init__}.py`,
  `tools/tests/{test_fit,test_checks}.py`,
  `tools/tests/{rehearsal,smoke-load}.sh` (the declarations only).
- Spec sections: master spec 6.3, 6.5, 12.1, 12.8, 13.3, 14 (`fit`,
  `check`); access model 6, 7; spec D159, D209.
- Done when: unit tests show the shared mark parsed, the refusal with its
  message, the only-shared playground refused, `CHECK_SINCE` passed per
  G8 and by `--since` per instance; a v0.3 scenario fits and checks as
  before.
- Verification: chunk checks.
- Split rule: 8a `fit`; 8b `check`.

### Chunk 9 — f10's early calibration

Status: planned
Wave: 2
Depends on: chunks 4, 5; G9 (the no-swap measurement); G4
Architecture capture: none of its own; its figures feed G10 and chunk 15.

- Goal: measure, early and on armenelos only, whether the out-of-memory
  incident can be had as master spec 16.3 designs it (spec D213).
- Scope: in: a calibration fixture standing for `db` and `reporting`
  (two `postgres` 0.4.0 instances, the shop's data from chunk 5,
  `reporting` at the scenario's starting limit and reservation,
  512M / 256M), the foreign server and the foreign tables the roll-up
  reads, the draft of `rpt.sales_detail_rollup()` (the order lines
  changed since its last run, in one `jsonb_agg` over the window), its
  backfill request table and the crontab entry calling it as `bi_etl`;
  a script, under the host lock and a sleep inhibitor, the VPS drained,
  reading the container's `memory.peak` around a normal run and around
  backfills of growing windows, as a Swarm service (swap equal to the
  limit) and without swap (G9); the figures (machine, date, limit,
  `shared_buffers`, window, peak, whether the kill happened) recorded in
  the Record line and the wave log; whether the history allows a window
  reaching twice the limit while a normal run stays under half.
  Out: the catalog fault (chunk 15); reshaping anything on a shortfall
  (G10, the owner).
- Files: `tools/tests/calibrate-f10.sh` (new),
  `tools/tests/fixtures/calibrate-f10/` (new).
- Spec sections: master spec 13.3, 16.3, 18 (item 5), 19; spec D209,
  D213.
- Done when: the figures are recorded for both swap settings; G10's
  question is answered yes or no from them; the host's other games and
  the VPS untouched.
- Verification: chunk checks, plus the calibration run (needs G4, G9).

### Chunk 10 — P1, sales reporting

Status: planned
Wave: 2
Depends on: chunks 3, 5; G8 for its checks' reading before a hand-over
Architecture capture: none.

- Goal: `purposes/shop-sales-reporting/`, complete by the format skill.
- Scope: in: `purpose.yaml` (identity, parts `source`, `target`,
  `runner`, `consumer`; the jobs `rollup-hourly` and `rollup-close`;
  trace, invariants R1 to R5 with witnesses, data moved, roles);
  material: `scripts/rollup.py:hourly` (watermark on `updated_at`, one
  target transaction holding the watermark, one `rpt.etl_runs` row), the
  repository entries and `jobs.yaml` lines, `reporting`'s DDL (`rpt.*`,
  `rpt.etl_runs`, the foreign server owned by `postgres`, `bi_etl`'s
  user mapping to `shop_etl`, the foreign tables `src.orders` without
  `customer_id`, `src.order_lines`, `src.products`, the `SECURITY
  INVOKER` procedure `rpt.close_day()` cutting yesterday in the
  customer's zone from `business_settings`, the roles `bi_etl` and
  `bi_reader`), the consumer's dashboard queries; `checks/` (one per
  invariant, judging runs since `CHECK_SINCE` through chunk 3's means and
  `check-sql`, exit 3 with `remaining=`, R5 a definition check running
  the dashboard's `SELECT` read-only); `gm.md`.
- Files: `purposes/shop-sales-reporting/` (new); the root `README.md`'s
  table.
- Spec sections: master spec 6.7, 8.2, 8.6, 8.7, 9.6, 9.7, 10.1, 12.1 to
  12.3, 12.6; access model 9.1, 9.2.
- Done when: the format skill finds nothing missing; the loader accepts
  it; the script, called in the scheduler's unit-test harness on two
  databases loaded with the shop's data, moves the right rows; the
  procedure closes a day right at a non-zero shift; each check reads 1
  on a crafted violation, 0 on clean runs with a witness, 3 with no run
  since `CHECK_SINCE`.
- Verification: chunk checks.
- Split rule: 10a `purpose.yaml` and the material; 10b the checks and
  `gm.md`.

### Chunk 11 — P2, P3 and P5: leads, mailing, export declarations

Status: planned
Wave: 2
Depends on: chunks 3, 5; G8 for its checks' reading before a hand-over
Architecture capture: none.

- Goal: `purposes/shop-winback-leads/`, `purposes/shop-customer-mailing/`
  and `purposes/shop-export-declarations/`, complete by the format
  skill, with the customs gateway stub.
- Scope: in: each `purpose.yaml`; material: the jobs `leads-extract`,
  `mail-shipped`, `mail-campaign`, `declare-exports` and
  `escalate-customs` as SQL on the shop's database (the latest consent
  event, never the flag; sending hours in the recipient's local time),
  their repository entries and `jobs.yaml` lines, the payload schemas of
  the two outboxes; the receiver: the gateway stub's repository and
  schedule (a stream reading new `customs_outbox` rows as `customs_gw`,
  writing `customs_acks` within a minute, accepting every well-formed
  declaration, never acknowledging about one in fifty as standing
  behaviour, spec D214); `checks/` for L1 to L3, M1 to M5 and E1 to E4
  (runs, or triggers for E1 and E4, since `CHECK_SINCE`); each `gm.md`.
- Files: `purposes/{shop-winback-leads,shop-customer-mailing,shop-export-declarations}/`
  (new); the root `README.md`'s table.
- Spec sections: master spec 6.7, 8.2, 9.3, 9.6, 9.7, 10.2 to 10.4, 12.1
  to 12.4; access model 9.1; spec D214.
- Done when: the format skill finds nothing missing; the loader accepts
  each; every job's SQL runs on the shop's data at a shift of 0 and a
  non-zero one; the stub leaves about one declaration in fifty
  unacknowledged; each check reads 1 on a crafted violation, 0 on clean
  runs or triggers with a witness, 3 otherwise.
- Verification: chunk checks.
- Split rule: 11a P2 and P3; 11b P5 and the gateway stub.

### Chunk 12 — The governance check set G1 to G4

Status: planned
Wave: 3
Depends on: chunks 3, 4, 7
Architecture capture: recorded at wave 3 start (W3-a), for chunk 15's
f9: where the set lives, how a fault's sealed check calls it and the
rules it names, and what it reads (`governance:` and the classification,
on which node).

- Goal: G1 to G4 implemented once, as master spec 11.6 says, for the
  governance faults' checks and the baseline's proof.
- Scope: in: G1 (classed columns only in their allowed locations, over
  every database of every `database` node: tables, views, materialized
  views and foreign tables; a foreign table's column by the remote column
  it maps, a copy by table and column name, the `personal` content probe
  for e-mail addresses); G2 (`has_column_privilege` for every customer
  login role, through membership and `PUBLIC`); G3 (foreign tables, user
  mappings' remote roles through the mapping-roles function, a mapping
  for `PUBLIC`, transformer jobs' source roles read from the runner's
  `jobs.yaml` and schedule, `SECURITY DEFINER` owners, `pg_cron` jobs'
  `username` in their database, a superuser reaching everything); G4
  (the outboxes' payload keys against `outbound.fields` on rows written
  since `CHECK_SINCE`); the game's own roles skipped by name; exit 0 or
  1 for G1 to G3; tests on `fixture-instances` with each rule broken and
  kept.
- Files: the set's home as W3-a records it (under `tools/` or a shared
  check library mounted with the checks), its tests, and
  `tools/tests/fixtures/fixture-instances/` (a governance section and
  the breaches its tests plant).
- Spec sections: master spec 7.2 (`check-psql`), 11.4 to 11.7, 12.6, 14;
  access model 8, 9.3.
- Done when: each rule reads 1 on its planted breach and 0 on the
  compliant fixture, a renamed copy of personal data included; the
  game's own roles never flagged; the fixture's README current.
- Verification: chunk checks, plus a deployment of `fixture-instances`
  (needs G4).
- Split rule: 12a G1 and G2; 12b G3 and G4.

### Chunk 13 — `fixture-campaign`: the v0.4 topology, unfaulted

Status: planned
Wave: 3
Depends on: chunks 5, 6, 7, 10, 11
Architecture capture: recorded at wave 3 start (W3-b), for chunks 14 and
15: the fixture's node names, roles, job names and keys, databases and
data files, as master spec 16.1 sets them.

- Goal: a deployable copy of the new scenario's system with no fault
  instance, to plant and check the faults on, and the shape chunk 16
  copies.
- Scope: in: the topology of master spec 16.1 (`db` with its crontab
  refreshing `popular_products` as `shop_refresh`, `pooler`, `producer`
  with the domain's fragments, `consumer` with the dashboards,
  `reporting` with `pg_cron` and its cron daemon, `bi`, `crm`, `gateway`,
  the monitoring of `db`), the starting limits and reservations, the
  designed placement on two hosts (`reporting` on the first);
  `purposes:` mapping the four purposes, `domain: shop`, `governance:`
  and `player/data-policy.md` (personal and customer-linked data kept out
  of `reporting`, the back office allowed to read names and e-mails);
  every database node's seed `pg_hba.conf` admitting the GM check role
  from the game network; both data files; `aging:` at the floor.
  Out: fault instances, the story and issues (chunk 16).
- Files: `tools/tests/fixtures/fixture-campaign/` (new),
  `tools/tests/test_model.py` (the fixture loads).
- Spec sections: master spec 9, 10, 11.5, 13.1, 13.2, 13.4, 16.1;
  access model 9.
- Done when: the format skill finds nothing missing; `fit` and `render`
  accept it on armenelos alone and on two declared hosts; deployed on
  armenelos with the load started, every job of the four purposes, the
  `pg_cron` job and both crontabs run in their logs and ledgers; every
  purpose check reads 0 or 3, none 1. It places at wave 3's gate:
  G1 to G4 passing on it (chunk 12 merged).
- Verification: chunk checks, plus the deployment (needs G4).

### Chunk 14 — The purpose faults f1 to f5 and f8

Status: planned
Wave: 3
Depends on: chunks 2, 7, 8, 10, 11; chunk 13 (in-wave, W3-b), merged into
`v0.4-w3` before this chunk's branch is cut
Architecture capture: none of its own; its fault ids, seed changes,
parameters, aging minima and timeline needs are recorded at its merge as
W3-c, for chunk 16.

- Goal: six catalog faults of master spec 16.2, each with injection,
  aging minimum, sealed check and solvability description.
- Scope: in: `purpose-mail-overlapping-window` (f1),
  `purpose-leads-stale-consent` (f2, its producer release written as a
  timeline need its definition states), `purpose-mail-outside-hours`
  (f3), `purpose-watermark-misses-updates` (f4),
  `purpose-etl-role-expired` (f5, a `state` change), and
  `purpose-receiver-down-unnoticed` (f8, the gateway's two-hour outage as
  a timeline need); each with `fault.yaml` (`applies_to.bricks` with the
  `scheduler` 0.2.0 or `postgres` 0.4.0 it needs, `applies_to.purposes`,
  `sealed_check.judges`, the aging minimum from the job's first run after
  planting), its seed changes or injection, `checks/fixed.sh` (judging
  runs or triggers since `CHECK_SINCE`), `checks/probe.md`, `gm.md`; the
  bricks' "Supported faults" sections, folding into their versions.
- Files: `faults/<fault-id>/` for each (new),
  `bricks/{scheduler,postgres}/docs/gm.md` ("Supported faults" only).
- Spec sections: master spec 6.3, 12, 16.2; access model 7.
- Done when: the loader accepts each; on a deployment of
  `fixture-campaign` with each planted, its evidence shows within its
  aging minimum and its check reads 1; after its acceptance fix and its
  job moved, 3 then 0 (f5 with `--since`).
- Verification: chunk checks, plus the faults planted on
  `fixture-campaign` (needs G4).
- Split rule: 14a f1, f2, f3 (`crm`'s mail and leads); 14b f4, f5, f8.

### Chunk 15 — The database-node faults f6, f7, f9 and f10

Status: planned
Wave: 3
Depends on: chunks 4, 6, 7, 9, 10; chunks 12 and 13 (in-wave, W3-a,
W3-b), merged into `v0.4-w3` before this chunk's branch is cut; G10 for
15b
Architecture capture: none of its own; recorded at its merge as W3-d,
for chunk 16.

- Goal: the four catalog faults of master spec 16.2 on database nodes,
  each complete.
- Scope: in:
  - **15a**: `security-crontab-superuser` (f6: `db`'s hourly refresh
    connecting as `postgres` by peer, `shop_refresh` prepared and unused;
    its check requiring every live crontab entry's role to be no
    superuser); `purpose-day-boundary-wrong-zone` (f7: `rpt.close_day()`
    cutting the day N hours off the customer's zone, N a non-zero
    parameter render writes; its check judging the close's runs from
    `rpt.etl_runs`); `governance-personal-copied` (f9: the second foreign
    server mapped for `bi_etl` to `shop_reports`, the foreign table over
    `customers`, `rpt.customer_activity`, the `pg_cron` job as `bi_etl`
    refilling it every thirty minutes; its check calling G1 and G3 and
    requiring the job, the table, the foreign table and the server gone);
  - **15b**: `purpose-heavy-job-on-database-node` (f10: chunk 9's
    procedure and crontab entry as its seed at T0, the backfill request
    as a `state` change at `handover-12h`, the window G10 set,
    `needs_unshared_host: true`; its incident check exiting 1 while the
    kill and the recovery are in the log since the planting moment,
    never 0 or 3; its notes for a failed planting, never re-planted
    within the aging; report only); f10 planted for real on
    `fixture-campaign` on armenelos alone, the VPS drained, its entry
    moved to run within two minutes through `gm-crontab`;
  - each with `fault.yaml`, its seed changes or injection, its check,
    `checks/probe.md`, `gm.md`; `postgres`' "Supported faults".
- Files: `faults/<fault-id>/` for each (new),
  `bricks/postgres/docs/gm.md` ("Supported faults" only).
- Spec sections: master spec 6.3, 7.2, 11.6, 11.7, 12.5 to 12.7, 13.3,
  16.2, 16.3, 16.5; access model 7, 9.4, 12; spec D209, D211, D213.
- Done when: the loader accepts each; on `fixture-campaign` f6 and f9
  read 1, then 0 after their acceptance fix (f9 still 1 with only the
  table dropped); f7 reads 1 after the close runs (its job moved), 3
  then 0 after the fix and a move; f10's run kills a backend, PostgreSQL
  recovers by itself, s6, `sshd` and `cron` untouched, its check reads
  1, the next run normal; `fit` refuses a mapping placing f10's node on a
  shared host.
- Verification: chunk checks, plus the faults planted on
  `fixture-campaign` (needs G4), f10's run alone on armenelos under the
  host lock.
- Split rule: 15a f6, f7, f9; 15b f10.

### Chunk 16 — The v0.4 scenario

Status: planned
Wave: 4
Depends on: chunks 13, 14, 15
Architecture capture: recorded at wave 4 start (W4), for chunk 17: the
scenario's id, its ten instances, which jobs a smoke cycle moves on which
node, and each acceptance fix.

- Goal: `tarnbeck-outdoor-campaign` (working id) of master spec 16.1,
  complete by the format skill.
- Scope: in: `fixture-campaign`'s system copied into
  `scenarios/<id>/` at the starting sizes; `difficulty:` normal, ten;
  the ten instances of 16.1 with their nodes, plantings and visibility,
  each instance's aging minimum raised to its job's first run after
  planting; the producer's release at T0 (f2) and the gateway's
  two-hour outage (f8) as timeline changes of their schedules; the story
  (Tarnbeck six months on, Lumen Analytics, Ines Varga), the issues I1
  to I6, the starter pack naming every job the players may move and the
  agency's nodes, `player/data-policy.md`; `reporting` unscraped, a
  silent tooling expectation; `gm/answer-key.yaml` with each instance's
  expected resolution, and the overstep notes of 16.5 for f7, f9 and
  f10 (a change on the agency's system judged, never credited); f7
  expected to stay present; `gm/notes.md`, `brief.md`, `README.md`
  regenerated.
- Files: `scenarios/<id>/` (new); the root `README.md`'s table.
- Spec sections: master spec 11.5, 13.2, 13.4, 16.1, 16.2, 16.5;
  access model 7, 12.
- Done when: the format skill finds nothing missing; `fit` and `render`
  accept it on armenelos alone and on armenelos plus the VPS declared
  `shared`, `fit` refusing the VPS for `reporting`; its README matches a
  fresh regeneration.
- Verification: chunk checks.

### Chunk 17 — Smoke cycles, f10's run and the rehearsal

Status: planned
Wave: 4
Depends on: chunks 8, 9, 12; chunk 16 (in-wave, W4), merged into `v0.4-w4`
before this chunk's branch is cut; G4; G7 (17a's two-host run, 17b)
Architecture capture: none of its own; it uses W4.

- Goal: the harness and the runs master spec 18 asks for, run once on the
  merged scenario.
- Scope: in:
  - **17a, the smoke cycles**: on the scenario, every fault planted at
    once and every scheduler key and job running, on armenelos alone and
    on armenelos plus the VPS (`reporting` mapped to armenelos; f10's job
    never moved there); every purpose fault through its whole cycle
    (planted; its job moved to run within two minutes by an edit of
    `jobs.yaml` and a reload, done as root on a report-only node; present;
    its acceptance fix; too soon; moved again; fixed), f4's cycle moving
    the producer's invoicing, f5's passing `--since`; f6 and f9 present
    then fixed after their acceptance fix; the unfaulted scenario,
    rendered with every instance left out by the harness-only override,
    passing G1 to G4; f10's own run on armenelos alone, the VPS drained,
    its check present, PostgreSQL recovered, s6, `sshd` and `cron`
    untouched;
  - **17b, the rehearsal and the figures**: `rehearsal.sh` on the
    scenario, about two hours on armenelos plus the VPS, the aging
    capped by the harness override, its hand-over placed so the hourly
    and quarter-hour jobs and the peak run inside it; `start-load`, a
    scheduled `inject --at`, the early check fired by the host's timer,
    a scheduler killed and resuming, the hand-over check and snapshot, a
    restart; without f10, by the harness-only override leaving an
    instance out (never usable in a game); every node's memory and the
    trace's growth per hour, extrapolated over the sixteen hours; the
    figures into the bricks' `docs/gm.md` and `brick.yaml` ("Footprint")
    and the scenario's `resources`, `fit` re-run.
  - Out: the release notes (release gate).
- Files: `tools/tests/smoke-purposes.sh` (new; or `smoke-scenario.sh`
  extended, as the build finds), `tools/tests/{smoke-scenario,rehearsal}.sh`,
  the harness override where `render` and `inject` read the instance
  list (`tools/gm/{render,inject,aging}.py` as the build finds) and its
  unit tests; 17b: `bricks/{scheduler,postgres}/{brick.yaml,docs/gm.md}`
  ("Footprint"), `scenarios/<id>/{scenario.yaml,README.md}`.
- Spec sections: master spec 12.1, 13.3, 16.3, 18 (items 1 to 6); access
  model 6, 7.
- Done when: every run passes as listed, its figures recorded with
  machine and date in the Record line and the wave log; the VPS drained
  after each two-host run and never active during f10's.
- Verification: chunk checks, plus the runs (needs G4, G7), each under
  the host lock and a sleep inhibitor, alone on the hosts.
- Split rule: 17a the smoke cycles, the baseline's G1 to G4 and f10's
  run; 17b the rehearsal and the figures.

### Chunk 18 — The GM skill for v0.4

Status: planned
Wave: 4
Depends on: chunks 6, 7, 8, 14, 15
Architecture capture: none.

- Goal: the GM designs and runs a v0.4 game as master spec 14 says.
- Scope: in: `SKILL.md`: designing with purposes and a domain (copying
  the material, the placement guideline, a second instance's exporter);
  writing the data policy from `governance:`; the starter pack telling
  which jobs the players may move; the judged moment and `--since` from
  the players' report; a shared host refused by `fit`; a failed
  incident's handling (the hand-over check failing, the offer to set the
  game up again); a job run by hand refused as load control.
  `feedback.md`: governance faults ("fixed" as 11.7), a report judged
  against an incident, an overstep on the agency's system (16.5), an
  exit 3 at the final answer. `gmctl.md`: every line chunks 6 to 8
  left. Out: new scripts; the stance itself.
- Files: `.claude/skills/game-master/{SKILL,gmctl,feedback}.md`.
- Spec sections: master spec 12.8, 13.3, 14 ("The GM skill"), 16.3,
  16.5; access model 7, 10, 12.
- Done when: the skill covers each item of master spec 14's "The GM
  skill"; every `gmctl` invocation in the three files parses with
  `gmctl`'s own parser; v0.3's stance check-list items are unchanged and
  v0.4's are added (an overstep judged, never credited; a job run by hand
  refused; `--since` from the report).
- Verification: chunk checks; the stance check-list runs at the release
  gate.

## Release gate

Against master spec sections 17 and 18, on `v0.4-w4` before it merges,
alone on the hosts, under the host lock and a sleep inhibitor, with
v0.1's to v0.3's checks still applying. **No aged run** (spec D193): an
aged run is a one-off check, none before v1.0. GM sessions are fresh
agents reading `.claude/skills/game-master/` as their instructions; the
driver plays the initiator; verifier agents play as `player` through the
bastion only; GM-side checks run from the host.

1. Item 1: `scheduler` 0.2.0 and `postgres` 0.4.0 pass the format skill's
   `docs/gm.md` check, with their validators and measured footprints;
   G5 and G6 cleared, `.tech` current.
2. Item 2: `formats.md`, the templates, the loader and the format skill
   carry master spec 6, the placement guideline included.
3. Items 3 and 4: the four purposes and the shop domain complete by the
   format skill, every column classed.
4. Item 5: the ten faults complete (injection, aging minimum, sealed
   check, solvability description); the governance check set G1 to G4.
5. Item 6: the scenario complete by the format skill, its data policy
   written, its README current.
6. Item 7: `gmctl`, the loader and render as in master spec 14, checked
   through items 8 to 12.
7. Item 8: the three existing scenarios re-pinned, each deploying and
   passing its v0.3 smoke test unchanged; every existing fault's
   `applies_to` carrying the new versions.
8. Master spec 18.1: the scenario's smoke run on armenelos alone and on
   armenelos plus the VPS, every fault planted at once, every key and job
   running; `fit` refusing the VPS for `reporting`; the VPS drained after.
9. Master spec 18.2 and 18.3: every purpose fault's full cycle (f1 to f5,
   f7, f8), f4's moving the producer's invoicing, f5's with `--since`;
   f6 and f9 present, then fixed after their acceptance fix.
10. Master spec 18.4: the unfaulted scenario passing G1 to G4.
11. Master spec 18.5: f10 calibrated (G10 done) and run on armenelos
    alone, the VPS drained: its check present, PostgreSQL recovered, s6,
    `sshd` and `cron` untouched.
12. Master spec 18.6: the rehearsal re-run on the merged code without
    f10, on armenelos plus the VPS, every step passing, every node's
    memory within the declared figures, the trace's growth per hour
    measured and extrapolated, stated as such.
13. Item 9, the stance check-list on a deployment of the scenario: v0.3's
    items, plus an overstep on `reporting` judged and not credited, a
    request to run a job by hand refused, `--since` taken from a report
    dating a fix outside the runner, the feedback on a report about f10
    judged against the incident.
14. The wave-gate quality command, green.
15. Every row of "Left for the build" has its finding recorded in the
    chunk's Record line and, for a brick, its `docs/gm.md`.
16. G11: the owner's judgement.
17. Release notes in [README.md](README.md): the measured figures, the
    known limits named by master spec 18.7 (the nightly close running at
    its story's time; the trace's growth over a full aging extrapolated,
    not observed; hosts and timers through a night; f10 within a real
    aging), and the access model's known gaps that stand.
