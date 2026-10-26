# db_audit_gm v0.3 — Build plan

Status: v11 (2026-10-26): v10 with wave 3's preflight settlements from capture W3 written in: teardown per host in chunk 10 (spec D179), published ports on the manager only (spec D180), the image copy through the host's SSH Docker context (spec D181).
Approval: **approved 2026-10-22 by the owner** (G1, spec D156).
Written from: [master-spec.md](master-spec.md) and
[access-model.md](access-model.md), approved 2026-10-22 (spec D154), with
spec D152, D153 and D155 folded in, and amended the same day by spec
D157 and D158; confirmed at wave 1's start by spec D160 to D162; corrected
before wave 1's first chunk by spec D163 to D170 (capture W1) and the
owner's ruling D171.
No design set (no interface to design, D2).

The model is `~/.local/share/dev_team/references/build-plan-model.md`; this
plan states only its deltas. Its conventions follow v0.2's
[build plan](../../archive/v0.2/build-plan.md).

## Read first

- **Baseline.** v0.2's code on `main` (merge eedaa0d, closed at 824e1d5):
  `postgres` and `bastion` at 0.2.0, `prometheus`, `postgres-exporter` and
  `grafana` at 0.1.0, `tools/gm/`, the three skills, eleven catalog
  faults, `bookshop-new-server` and `fernway-clinics-monitoring`, the
  fixtures `fixture-audit`, `fixture-mounted` and `fixture-monitoring`.
  v0.2's wave-log captures W1 to W4-D
  ([../v0.2/wave-log.md](../v0.2/wave-log.md)) still fix the `gmctl`
  command lines, the bricks' paths, the `brick.yaml` keys and the
  fixtures' shape. A chunk that changes one of them says so, and the
  wave driver records the new shape as a v0.3 capture.
- **No intent register and no data register** (no `.atd`, no `intent/`,
  no `data-register/`; checked 2026-10-22). So there is no
  `documentalist` wave preflight, capture or sync, and no `data-steward`
  preflight or sync. Where a chunk names an **Architecture capture**, the
  wave driver records it in the wave log (`W<n>-<letter>`) on the wave
  branch before the chunk that depends on it starts, as in v0.1 and
  v0.2. Every chunk's **Atoms** and **Data** lines are therefore "none"
  and are left out below.
- **One version per brick in the catalog.** The loader refuses a pin that
  does not match the brick's `version` (`tools/gm/model.py`,
  `find_definition`). Chunk 1 bumps every existing brick to its v0.3
  version (`postgres` and `bastion` 0.3.0, the three monitoring bricks
  0.2.0), extends every fault's `applies_to` and re-pins both scenarios
  and the three fixtures in the same commit; every later v0.3 change to a
  brick folds into the version it already has, a brick version being
  released only by the v0.3 release gate (spec D100).
- **Templates are the loader's schema.** `tools/gm/model.py` checks every
  brick, fault and scenario against the format skill's templates
  (`template_schema`), and the unit suite loads every folder under
  `bricks/`, `faults/` and `scenarios/`. `difficulty:` becomes required
  in every scenario, so chunk 1 gives both scenarios and every fixture
  theirs itself. `aging:` is optional in the template: chunk 2's loader
  requires it in a scenario with scheduler nodes and refuses it in one
  without (spec D157, D158), so no existing scenario or fixture gets one,
  none having a scheduler node; `fixture-load` (chunk 12) is the first
  with `aging:`. A folder under
  `bricks/` without a complete `brick.yaml` fails the suite, so the
  scheduler program is built inside its brick's chunk, with its
  `brick.yaml` from its first commit.
- **Approved with the spec** (spec D152 to D155), and easy to miss: lost
  time up to thirty minutes does not move the earliest hand-over, only the
  excess beyond it does, and an outage minute is one with a node down or
  a scheduler writing no per-minute summary, which a running scheduler
  writes every minute even with no call (master spec 7.1, 8.7);
  `inject --at <moment> --instance <id>` acts on one instance, `now`
  planting at once (8.7); a restart keeps every secret's value under new
  Swarm secret objects, enters `handed-over` and leaves the snapshot for
  a later restart (12); the GM check role needs `EXECUTE` on
  `pg_hba_file_rules()` as well as `SELECT` on the view (7.3); 6.7's and
  7.1's shapes are normative until chunk 1 and chunk 2 put them in the
  templates.
- **Amended at the plan's approval** (spec D157, D158; master spec 6.1,
  8, 13, 15.4): only a scenario with scheduler nodes ages. A scenario
  with none omits `aging:` (refused there), has no `plant_at` other than
  T0, no instance `aging_minimum` and no `{{customer_timezone}}`; its
  faults' own aging minima are not counted (spec D160); `render
  --handover` is optional for it; its game goes from `injected` to the
  hand-over check, the snapshot with its brief stops (spec D162) and
  `handed-over` with no `load-started`, no T0 beyond the
  planting, no early check, no outages and no earliest hand-over, and a
  setup failure tears it down, as in v0.2.
- **No fake time anywhere.** No chunk or test may speed up, freeze or
  forge a clock (master spec 8.1). The smoke tests plant the faults due
  during the aging at once with `inject --at now` (a test harness, never a
  game); the rehearsal, and chunk 11's snapshot and restart run, reach
  their hand-over early through the test-harness override of the aging
  minimum, which caps each instance's own minimum too (chunk 8a, G6,
  spec D161): it shortens the wait, never a clock.
- **Build host** (observed 2026-10-22): armenelos, Debian 13, Docker
  Engine 29.9.1, swarm active (armenelos, leader; two nodes from 2026-10-26, G4), cgroup
  v2, 12 CPUs, 11G of memory with about 5G available and swap in use,
  10G free on `/`; the user's systemd manager runs with lingering on, so
  the game's persistent user timers outlive a session and start again at
  boot (the host timer of master spec 8.4, spec D173). Tailscale, reported logged out earlier that day, was
  up on both hosts when checked again on 2026-10-22: armenelos at
  100.78.85.1, the VPS `vps-5718ad52` at 100.126.172.117, `ssh vps`
  working; since 2026-10-26 the VPS runs Docker Engine 29.9.2 and is a
  worker in armenelos' swarm, re-created bound to Tailscale (G4). v0.3 adds two images (scheduler, PgBouncer), five
  rebuilt ones and the hand-over snapshots' copies: prune superseded
  `dbagm` tags after a wave gate when the disk runs short.
- **What v0.2's build taught** ([../v0.2/wave-log.md](../v0.2/wave-log.md)):
  - a chunk's stack test or smoke run started while another ran tripped
    the smoke run's "objects not belonging to the game are unchanged"
    check: docker-using checks are serialized (Workflow deltas);
  - a fresh GM session reading `.claude/skills/game-master/` plays the GM
    at the gates; verifier agents play as `player` through the bastion
    (and the web front) only; GM-side checks run from the host;
  - the session's auto-mode permission classifier refused the driver's
    restart request at v0.2's release gate ("Interfere With Workloads"),
    so the restart stance went untested: G9;
  - findings outside a chunk's Files line (a credential passed in an
    argument, stale wording in a brick's docs) were fixed on the wave
    branch by a `coding-executor` in their own commits, chunks owned by a
    `coding-leader` in chunk mode; the same holds here.
- `/run` is a named volume, not a tmpfs (spec D55); every new brick
  follows the existing bricks' pattern for it, for `sshd` host keys, the
  `sudo` log and the seed marker; it is never copied into a snapshot.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | Plan approval | The owner | Wave 1 | cleared 2026-10-22 (spec D156) |
| G2 | Network access at image build time: Debian 13's repositories (`python3-psycopg`, Python 3.13), the PostgreSQL apt repository (PostgreSQL, and `pgbouncer` from wave 2's gate, spec D177), the s6-overlay, Prometheus, `postgres_exporter` and Grafana sources, as in v0.2 | Hand check by the wave driver | Chunks 1, 3, 4, 5, 6 (every image build) | cleared 2026-10-23 for wave 1, 2026-10-26 for wave 2 (hand checks, wave log) |
| G3 | A Docker host in swarm mode: armenelos' swarm (active 2026-10-22; the VPS a drained worker in it from 2026-10-26, G4) | Hand check by the wave driver | Every stack test and smoke run, every wave gate, the release gate | cleared 2026-10-23, re-checked 2026-10-26 (hand checks, wave log) |
| G4 | The VPS ready, under the VPS rule (spec D159; "Workflow deltas"): first, Tailscale logged in on both hosts (`tailscale status`); the VPS's own documentation read before any change there; Docker Engine on the VPS (29.9.2 there, 29.9.1 on armenelos, 2026-10-26); the VPS joined to armenelos' swarm as a worker with `--advertise-addr` and `--data-path-addr` on its Tailscale interface (armenelos' own swarm bound likewise), and if the VPS's engine is already in a swarm or runs filetstudio.com as swarm services the driver stops and asks the owner; the swarm's ingress network recreated with an MTU leaving room for VXLAN inside Tailscale's 1280 bytes, with no game running; no game port published on the VPS (the bastion pinned to armenelos); SSH from armenelos to the VPS over Tailscale with a key (Docker context, image copy); at least 5G free on the VPS | The wave driver joins the VPS (spec D156); the owner's part, Tailscale and Docker on the VPS, is in place | Chunk 10b's two-host try; the two-host smoke run (from the wave 3 gate); chunk 15b; the release gate | cleared 2026-10-26 (spec D178; hand check, wave log) |
| G5 | Where the release gate's aged run runs, memory on armenelos being short (about 5G available, swap in use, a single-host game expected at about 5G): on armenelos alone if the game's peak memory measured by chunk 15b plus about 1G fits armenelos' available memory, otherwise on armenelos plus the VPS (spec D156) | Chunk 15b's measured figures, applied by the wave driver and recorded in the wave log | The release gate's aged run | ruled (spec D156); applied after chunk 15b |
| G6 | How the rehearsal reaches its hand-over in about two hours while the v0.3 scenario declares sixteen hours and the loader's floor is eight: a test-harness-only override of the aging minimum, capping each fault instance's own aging minimum too, in chunk 8a (spec D156, D161) | The owner | Chunk 8a builds it; chunks 11 and 15b use it | cleared 2026-10-22 (spec D156) |
| G7 | Review of the v0.3 scenario: its faults (chunk 14's among them), issues, aging, write policies and answer key (master spec 15.2) | The owner | Chunk 15's merge | open |
| G8 | The release gate's aged run window: the hosts G5 settles up and otherwise quiet for about twenty hours, deployed in an evening and handed over the next early afternoon (spec D156) | The owner, who sets the date with the driver | Release gate items 7 to 9 | ruled (spec D156); the date to set |
| G9 | The restart's confirmation at the release gate: the owner types the players' confirmation in the GM session himself (spec D156) | The owner, at the release gate | Release gate item 8 | ruled (spec D156); typed at the release gate |
| G10 | The owner's judgement at release close: the aged game, the feedback under load, the findings | The owner | Release close | open |
| G11 | O103: whether the lost time beyond thirty minutes moves the whole earliest hand-over (master spec 8.7, spec D152) or only the aging minimum's term (access model 6), when a fault instance's own minimum since its planting is the later term | The owner | Chunk 8's merge (8b's earliest hand-over) | cleared 2026-10-26 (spec D175) |

G6 was a question the plan raised on the approved spec (master spec 11
asks for a hand-over check, a snapshot and a restart within the
rehearsal's two hours, which `gmctl` refuses before the earliest
hand-over). Its ruling (spec D156) is in chunk 8a; the override is the
test harness's only and changes no spec behaviour for a game.

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3, 4, 5 | G1 (cleared); G2 (chunks 1, 3, 4, 5); G3 (stack tests) | merged 2026-10-26 (5faff6c) |
| 2 | 6, 7, 8, 9 | wave 1 | gated 2026-10-26; merged into `main` the same day |
| 3 | 10, 11, 12 | wave 2; G4 (chunk 10b's two-host try) | planned |
| 4 | 13, 14, 15 | wave 3; G4 (chunk 15b); G7 (chunk 15's merge) | planned |

```
1 ──> 3                (in-wave: the v0.3 template keys and contracts captured at wave 1 start, W1)
1 ──> 2, 4, 5          (in wave 1, after chunk 1's merge into v0.3-w1; 4 and 5 after 1a's at least; W1)
1, 4 ──> 6             (the PgBouncer lookup role, settled by chunk 4, capture W1-x)
1, 2 ──> 7
3, 7 ──> 8             (in-wave: the stages and records captured at wave 2 start, W2)
9 ──> 8                (in-wave: the "too soon to tell" verdict, W2)
1, 2, 4 ──> 9
7 ──> 10
3, 4, 5, 6, 8 ──> 11
10 ──> 11              (in-wave: hosts, contexts, where volumes live and teardown per host, W3; `teardown.py` and `test_teardown.py` pass to 11 at 10's merge)
2, 3, 6, 7, 8, 9 ──> 12
7, 8, 9, 10, 11 ──> 13
2, 3, 6, 9, 12 ──> 14
14 ──> 15              (in-wave: the chosen faults captured at wave 4 start, W4)
5, 10, 11, 12 ──> 15
```

Wave 1's order (spec D166): chunk 1 runs first, chunk 3 beside it; chunks
2, 4 and 5 are cut from `v0.3-w1` once chunk 1 has merged (chunks 4 and
5 once 1a has, at least), so no two chunks running at once share a file
and no shared list is needed. Chunk 1 owns the five existing bricks'
`brick.yaml` keys W1 item 3 lists; chunks 4 and 5 keep those values and
own the rest of the lines their scopes name.

Chunk 9 has slack (only 8, 12, 13 and 14 need it); it sits in wave 2
because 8 reads its verdict. Chunk 12 has slack too (14 needs it); it
fills wave 3.

## Workflow deltas

- **κ = 3** for this plan (spec D156), with three conditions: chunks
  with no path between them run side by side, each in its own worktree; docker-using checks (image
  builds, stack tests, smoke runs, the two-host try) are serialized by a
  host lock (`flock /tmp/dbagm-docker.lock <command>`), since a stack
  test started during a smoke run trips its "objects not belonging to the
  game" check and memory is short (G5); chunk 15b and the release gate
  run at κ = 1, alone on the hosts.
- **The VPS** (spec D159): the driver and its agents may work on it
  (`ssh vps`), but never disturb the applications it already hosts;
  filetstudio.com stays up throughout. A change that needs filetstudio.com
  down (a Docker upgrade, say) waits for a downtime scheduled with the
  owner beforehand; it is never taken down unannounced. The VPS's Caddy
  may be altered so long as filetstudio.com stays up. The documentation
  kept on the VPS itself describes its set-up: read it before any change
  there. Tailscale and the VPS are meant to be always up; each session
  touching the VPS checks `tailscale status` on both hosts first. A
  swarm membership change on the VPS (leaving, joining, re-creating the
  swarm) is a downtime too: it wiped the VPS containers' embedded DNS at
  G4 (spec D178), so it waits for a downtime scheduled with the owner,
  and is followed by restarting every container there and checking each
  app reaches its database. The VPS node stays `drain`, since the
  bricks' stack tests carry no placement constraint and would open a
  host-mode port on its public address; only a two-host run (chunk
  10b's try, a wave gate's two-host smoke run, and from wave 4 chunk
  15b's rehearsal and the release gate's two-host runs) sets it
  `active`, inside that run's host lock, and drains it again after,
  pass or fail (`docker node update --availability active|drain
  vps-5718ad52`, run by the owner if the auto-mode classifier refuses).
- **Branches and worktrees**: waves `v0.3-w<n>` in
  `/home/bastien/work/db_audit_gm-wt/v0.3-w<n>`; chunks
  `v0.3-c<id>-<slug>` in `/home/bastien/work/db_audit_gm-wt/v0.3-c<id>-<slug>`.
  Never in the main checkout.
- **Shared lists**: `tools/gm/__init__.py`'s verb and option
  registrations, `.claude/skills/game-master/gmctl.md`'s verb table, and
  the root `README.md`'s brick and fault tables count as shared lists
  under the model's in-wave rule: several chunks add rows, the chunk
  owner resolves them at its merge.
- **Chunk checks**, in addition to the model's:
  - Python: `python3 -m unittest discover -s tools/tests -t .` (the
    related tests, or all of them: the suite is small);
  - the scheduler program's own unit tests (chunk 3), run inside the
    scheduler's image so the host needs no `psycopg`:
    `sh bricks/scheduler/tests/run-unit-tests.sh`;
  - shell: `sh -n` on every shell file the chunk touches, those without
    an extension included (s6 `run` files, `rootfs/usr/local/sbin/*`,
    `rootfs/usr/local/lib/gm/*`, companion scripts, fault scripts);
    `shellcheck` too when installed;
  - Perl: `perl -c` on every Perl file the chunk touches;
  - YAML: every YAML file the chunk touches loads with PyYAML;
  - a chunk touching a brick: `docker build -t
    127.0.0.1:5000/dbagm/<brick>:<version> bricks/<brick>` and its stack
    test, `sh bricks/<brick>/tests/run-stack-test.sh` (needs G3);
  - a chunk changing a scenario's `scenario.yaml` or
    `gm/answer-key.yaml`: its `README.md` regenerated with the
    scenario-document skill in the same commit;
  - a chunk adding or changing a `gmctl` invocation in a Markdown file:
    the invocation parses with `gmctl`'s own parser.
- **Wave gate (full quality command)**: the full unit suite; the
  scheduler's unit tests (from wave 1); `sh -n` on every shell file and
  `perl -c` on every Perl file; all seven bricks' image builds and stack
  tests; `sh tools/tests/smoke.sh`; `sh tools/tests/smoke-monitoring.sh`;
  `sh tools/tests/smoke-scenario.sh bookshop-new-server` and
  `fernway-clinics-monitoring` (as they are until chunk 12 rewrites the
  script for load); from wave 3, `sh tools/tests/smoke-load.sh` on one
  host, and on armenelos plus the VPS once G4 is cleared and chunk 10
  has merged (the VPS `active` for that run only, "Workflow deltas"); from wave 4,
  `smoke-scenario.sh` on the v0.3 scenario. Every step under the host
  lock, at κ = 1 for the gate itself.
- No link checker is configured; Markdown links are checked by reading.
- Images are tagged `127.0.0.1:5000/dbagm/<brick>:<version>`, as before;
  every pinned download is checked against its published checksum in the
  Dockerfile.
- The release gate runs on `v0.3-w4` before it merges, as v0.2's did.

## Measurements and hand checks

- G2 and G3: hand checks by the wave driver before wave 1.
- G4: done and checked by the wave driver under the VPS rule: `tailscale
  status` logged in on both hosts first; both engines' versions; `docker
  node ls` shows both hosts, the ingress network's MTU, Swarm's
  addresses on `tailscale0`, an SSH Docker context answering;
  filetstudio.com answering before and after.
- Each new or bumped brick's footprint at rest: in its chunk's stack test
  (chunks 3, 4, 5, 6), as a first figure.
- Overlay and ingress MTU, Swarm bound to Tailscale, the image copy: tried
  by chunk 10b on armenelos plus the VPS (needs G4), recorded in its
  Record line and `docs/gm.md` of the bastion.
- The game's memory under peak load, the aged growth per hour, PgBouncer
  and the schedulers' footprints, `fernway-clinics-monitoring`'s 256 MB
  TSDB bound against the measured growth: chunk 15b, during the
  rehearsal on armenelos plus the VPS, recorded in the wave log with
  machine and date; measured again at the release gate (items 6 and 7).
- The aged run, the play-through as `player`, the stance check-list, a
  fresh session resuming a game during the aging: release gate.

## Left for the build (master spec 20)

Each item is settled or verified by the chunk named, recorded in its
**Record** line and in the brick's `docs/gm.md` where it is a brick's;
the release gate checks that each is recorded.

| Item | Chunk |
|---|---|
| The footprints of every new or bumped brick, and the aged growth per hour | 3b, 4, 5, 6 (at rest); 15b (under load, growth) |
| The overlay and ingress MTU over Tailscale; Swarm bound to the Tailscale addresses | 10b (with G4) |
| The image copy (`docker save \| docker --context dbagm-<host> load`, through the host's SSH Docker context, spec D181) | 10b |
| `auth_query`'s exact set-up in PgBouncer, `auth_dbname` for the console included | 6 (the database side from 4a) |
| The size of the GM's connection reserve (two expected) | 4a |
| How `gmctl` schedules setup actions on the manager (a host timer: persistent systemd user units, spec D173) | 8a |
| How `gmctl` reads outages from the summaries and the task history (a pruned history flagged, spec D174) | 8b |
| The loader's check that a seed allows `pg_basebackup` locally | 2a |
| The GM check role's grants on `pg_hba_file_rules` (view and function) | 4a |
| `pg_basebackup`'s form on a read-only root (`-X fetch` with a temporary physical slot, or a snapshot volume) | 4b (the helper), 11a (its use) |

## Chunks

### Chunk 1 — Format skill, templates, the v0.3 versions and the definitions migrated

Status: merged (w1, 541a5a6)
Wave: 1
Depends on: G2, G3
Architecture capture: recorded by the wave driver at wave 1 start (W1),
for chunks 2 to 5, which build on it before chunk 1 merges:
- the template keys: the scenario's `aging:` (`minimum`, `handover_at`;
  optional in the template, spec D158) and `difficulty:` (`score`,
  `level`); a fault instance's `plant_at` and
  `aging_minimum`; a node's `write_overrides`; the fault's `aging:`
  (`technique`, `minimum`) and its evidence `where` location with
  `source`; the brick's `snapshot:` map and its three methods,
  `writable_paths`, the footprint's disk growth per hour (key name and
  unit), the roles list with `pooler`, `producer` and `consumer`; the
  answer key's `window` and `threshold` on a behavioural check;
- the write-policy contract: the environment the renderer gives a
  container (names and format of the node's write policy and its write
  overrides), what a brick does with them (seed files read-only for
  `player` on a report-only node, a path made fixable by an override
  left writable, reload wrappers refusing with a one-line reason), and
  the ownership rule the wrappers restore (owner and mode of a seeded
  file before a reload);
- the snapshot contract inside a node: how `gmctl` asks a node for a
  brief stop and a start (the s6 service to stop, through the exec verb
  as root), how a `copy` is taken (the volumes' paths, a tar stream on
  standard output), and the name of `postgres`' `pg_basebackup` helper;
- the scheduler's runtime interface: what render writes into
  `queries.yaml`, `jobs.yaml` (UTC times, an optional `timezone:
  Etc/GMT±N`) and `schedule.yaml` (shapes and timeline moments in UTC,
  the game's seed), the load-started marker's path and content, the
  per-minute summary's line format (read by chunk 8b for outages), the
  metrics endpoint's port and path, `gm-reload-scheduler`, the service
  account, and the names of the connection secrets;
- the GM check role: its name, its secret's name and path (root only),
  the reserve's size; the PgBouncer lookup role, its function and its
  secret (consumed by chunk 6; chunk 4a records what it built as W1-x).

- Goal: the v0.3 formats in the format and scenario-document skills, and
  every existing definition brought to them at the v0.3 versions, so the
  suite stays green.
- Scope: in:
  - `scenario-format` `SKILL.md`: the rules of master spec 6 (the
    scenario's `aging:`, with scheduler nodes only, at least eight hours
    and covering every instance, and what a scenario without them omits:
    `aging:`, `plant_at` other than T0, `aging_minimum`,
    `{{customer_timezone}}`, its faults' minima not counted (spec D157,
    D158); `difficulty:`, `plant_at` for `state` faults only, an instance's
    `aging_minimum`, `write_overrides` and per-file policy for a *fix*
    resolution, `{{customer_timezone}}` and never a fixed zone,
    Prometheus' retention against the aging; the fault's `aging:` and
    evidence locations, never `ui:<name>`; the brick's `snapshot:`,
    `writable_paths`, growth per hour, the `pooler` role; behavioural
    checks with a window; the scheduler's files, pointing at master spec
    7.1 until chunk 2b's templates carry them; the third exit code of a
    sealed check, and database checks on the GM check role; a `postgres`
    seed's `local replication postgres peer` and `local all gm_check
    scram-sha-256` lines under its DO NOT TAMPER comment, spec D164,
    D171);
  - the templates `brick.yaml`, `brick-gm.md`, `fault.yaml`,
    `scenario.yaml`, `answer-key.yaml` and `layouts.md`, to master spec
    6.1 to 6.7 and W1;
  - `scenario-document`: the template renders the aging, the difficulty,
    an instance's planting moment, write overrides, a behavioural check's
    window, and evidence locations in the v0.3 form;
  - migration (O78's option (b), spec D140, D145): `postgres` and
    `bastion` to 0.3.0, `prometheus`, `postgres-exporter` and `grafana`
    to 0.2.0 (`brick.yaml` in the new shapes with W1's values for the
    five bricks, item 3's table: `roles` from master spec 6.4's list,
    `writable_paths`, `seed.paths`, `report_tools`, `snapshot:` and a
    provisional `disk_growth_per_hour`, spec D167; `docs/gm.md` version
    lines and image tags, stack tests' tags); the eleven catalog faults
    with an `aging:` block, their evidence's free text moved to `source`
    and a location in `where`, an entry read through a web interface or
    on a node other than the target dropped, or rewritten as the same
    fact read at `node` or `bastion` where the fault would keep no
    evidence of it otherwise, the answer keys keeping those readings
    (spec D167), the new versions added to `applies_to`;
    `bookshop-new-server` and `fernway-clinics-monitoring` re-pinned with
    no `aging:`, neither having a scheduler node (master spec 15.4, spec
    D157), each with its difficulty score (6 and 8), fernway's one-day
    retention kept, its node roles `monitoring` (spec D167); the three
    fixtures likewise, with no `aging:`, `fixture-mounted`'s local brick
    role `consumer`; the lines `local replication postgres peer` and
    `local all gm_check scram-sha-256` added to every `postgres` seed
    `pg_hba.conf` (both scenarios, `fixture-audit`,
    `fixture-monitoring`), under the DO NOT TAMPER comment after `local
    all postgres peer`, and the line numbers `bookshop-new-server`'s
    answer key cites moved two down with them (its trust line 12 to 14,
    the scram-sha-256 host line 14 to 16; spec D164, D171); every README
    regenerated.
  - Out: any loader, renderer or image change; the bricks' v0.3 features
    (chunks 4, 5); the scheduler's file templates (chunk 2b); anything
    under `bricks/scheduler/` (chunk 3).
- Files: `.claude/skills/scenario-format/SKILL.md`,
  `.claude/skills/scenario-format/templates/{brick.yaml,brick-gm.md,fault.yaml,scenario.yaml,answer-key.yaml,layouts.md}`,
  `.claude/skills/scenario-document/{SKILL,template}.md`, for the five
  existing bricks only (`<b>` one of `postgres`, `bastion`, `prometheus`,
  `postgres-exporter`, `grafana`, spec D166): `bricks/<b>/brick.yaml`,
  `bricks/<b>/docs/gm.md`,
  `bricks/<b>/tests/{run-stack-test.sh,stack.test.yml}`;
  `faults/*/fault.yaml`,
  `scenarios/{bookshop-new-server,fernway-clinics-monitoring}/{scenario.yaml,gm/answer-key.yaml,README.md,nodes/db/pg_hba.conf}`,
  `tools/tests/fixtures/fixture-{audit,mounted,monitoring}/`.
- Spec sections: master spec 5, 6, 8 (its opening), 15.4, 16;
  [../../formats.md](../../formats.md); spec D100, D140, D145, D150,
  D157, D158, D164, D166, D167, D171.
- Done when: every template carries every item master spec 6 requires and
  loads as YAML; the loader, unchanged, loads every brick at its v0.3
  version, the eleven faults, both scenarios and the three fixtures; the
  unit suite (with `test_brick_docs`) passes; the five images build at
  their new tags and their stack tests pass; every README matches a
  fresh regeneration; every evidence reading dropped from a fault is in
  the answer key of each scenario and fixture planting that fault; every
  `postgres` seed carries the replication line and the `gm_check` line
  under its DO NOT TAMPER comment, and the answer keys' cited `pg_hba`
  line numbers match the seeds.
- Verification: chunk checks.
- Split rule: 1a brick and fault formats: the `brick.yaml`,
  `brick-gm.md`, `fault.yaml` and `layouts.md` templates, the skill's
  brick and fault rules, the five bricks' bumps and the eleven faults'
  migration, with the scenarios' and fixtures' pins. 1b scenario
  formats: the `scenario.yaml` and `answer-key.yaml` templates, the
  skill's scenario rules, the scenario-document skill, the scenarios' and
  fixtures' `difficulty:`, the replication and `gm_check` lines in
  their seeds, their answer keys and READMEs.
  Each half leaves the suite green.

Record: 1a e73a7b4 (merge bd008a7), 1b d27af79 (merge 541a5a6). No
deviation from the spec or W1; W1 addenda in the wave log. Outside its
Files line: `tools/tests/test_{fit,deploy,render,model}.py` and the smoke
scripts' `IMAGES=` lists, for the new tags (wave log).

### Chunk 2 — Loader checks for v0.3

Status: merged (w1, ecb7278)
Wave: 1
Depends on: chunk 1, merged into `v0.3-w1` before this chunk's branch is
cut (spec D166); W1
Architecture capture: none of its own; it implements W1.

- Goal: the scripts refuse what master spec 6 and 7.1 say the format
  refuses, with the list of what is missing or wrong.
- Scope: in:
  - scenarios: `aging:` required in a scenario with a scheduler node,
    `aging.minimum` at least eight hours and covering every instance (its
    planting offset from T0 plus its aging minimum); in a scenario with
    no scheduler node, `aging:`, a `plant_at` other than T0, an
    instance's `aging_minimum` and `{{customer_timezone}}` in the story
    or the starter pack refused, and the faults' own minima not checked
    (spec D157, D158);
    `difficulty.score` equal to the number of fault instances, `level`
    one of easy, normal, hard; `plant_at` other than T0 only for a
    `state` fault, `handover-<N>h` with N at most the aging minimum and
    at least the instance's own minimum; `write_overrides` among the
    brick's `writable_paths`, on a report-only node; a *fix* resolution
    needing its file's policy (per file now, not per node); Prometheus'
    retention by time at least the aging minimum plus four hours (four
    hours with no `aging:`) unless a planted fault is about retention; a `postgres` seed allowing a
    local replication connection for `postgres` (`pg_basebackup`), and
    a `local` line admitting `gm_check` by password or `trust` before
    any `reject` (W1 item 8, spec D164);
  - faults: `aging:` required (technique `real-time`); evidence `where`
    one of `node`, `bastion`, `report:<tool>` for a tool the target's
    brick ships, never `ui:<name>`; `source` beside it;
  - bricks: `snapshot:` methods among `pg_basebackup`, `copy`, `stop`,
    naming declared volumes, never `/run`, at most one `pg_basebackup`
    volume (whether the brick ships `gm-snapshot-db` is chunk 4's stack
    test's, not the loader's, spec D167); the roles list;
  - answer keys: a behavioural check states its window and threshold;
  - **2b, the scheduler's files**: templates for `queries.yaml`,
    `schedule.yaml` and `jobs.yaml` in the format skill (master spec
    7.1's shapes), and the loader's checks on them: every key a stream,
    job or timeline change names exists in the repository; generators
    well formed; a builder's file and function exist; connections name a
    known driver (`sql/postgresql`) and a node of the topology; shapes
    cover the 24 hours; a timeline change before hand-over and no
    further before it than the aging minimum; no `timezone:` on a job in
    the scenario; a job's `timezone_offset: <N>` (a non-zero whole number
    of hours from the customer's zone) only on a node where a fault
    instance's seed change edits `jobs.yaml` (spec D168);
  - unit tests with fixtures for each refusal.
  - Out: rendering any of it (chunk 7); `fit` (chunk 10).
- Files: `tools/gm/model.py`, `tools/tests/test_model.py`,
  `tools/tests/fixtures/fixture-v03-refusals/` (new); 2b:
  `.claude/skills/scenario-format/templates/{queries,schedule,jobs}.yaml`
  (new), `.claude/skills/scenario-format/SKILL.md` (the scheduler's
  files section), `.claude/skills/scenario-format/templates/layouts.md`.
- Spec sections: master spec 6.1 to 6.4, 6.7, 7.1, 7.3 ("Snapshot"), 8
  (its opening); spec D127, D143, D145, D150, D157, D158, D160, D164,
  D166, D167, D168.
- Done when: unit tests show each refusal above with its message and the
  acceptance of a valid fixture, one with scheduler nodes and one
  without; every catalog brick, fault and scenario still loads; the unit
  suite passes.
- Verification: chunk checks.
- Split rule: 2a scenario, fault, brick and answer-key checks; 2b the
  scheduler's file templates and their checks.

Record: 2a c278786 (merge ff60cce), 2b 34aade5 (merge ecb7278). No
deviation from the spec or W1; its choices are in "W1 addenda — choices
chunk 2 made". Its `pg_hba.conf` reading ignores `+group`, `@file` and
`include`.

### Chunk 3 — The `scheduler` brick 0.1.0

Status: merged (w1, 3b54bee)
Wave: 1
Depends on: chunk 1 (in-wave, W1: runs alongside chunk 1, its files all
under `bricks/scheduler/`, spec D166); G2, G3
Architecture capture: none of its own; it implements W1's scheduler
interface and write-policy contract, and records what it built as W1-y
(read by chunks 7, 8, 11, 12, 14).

- Goal: the producer and consumer nodes: a scheduler running a rendered
  schedule against a query repository, as master spec 7.1 says.
- Scope: in:
  - **3a, the program**: Python 3.13, asyncio, Debian's `psycopg`; one
    task per stream and per fixed-time operation, each with its own
    connections (a pool of a size, or per call); the query repository
    (a query, a pool picked by weight, a sequence with `transaction:`
    isolation and hold, a builder called with the intensity and its
    options); parameter generators (integer and decimal ranges, choice,
    sequence, current time); streams (rate per minute at intensity 1.0,
    Poisson or even arrivals, a shape's hourly multipliers optionally per
    weekday, concurrency); timeline changes (a stream's key, rate or
    connection at a UTC time); fixed-time operations from `jobs.yaml`
    (cron, UTC or a fixed `Etc/GMT±N` zone, skipped and logged when the
    previous run still goes or the connection is refused, never queued),
    reloaded on SIGHUP; every random draw from the game's seed; the
    schedule read from standard input, never opened; idle until the
    load-started marker exists, then running, resuming at the current
    time after any restart with every past timeline change applied and
    nothing replayed; the log (every fixed-time run, every error with
    key, SQLSTATE and message, a per-key summary every minute, written
    even with no call, keys never rates or shapes); the metrics endpoint
    (per-key calls, errors, a latency histogram); the `sql/postgresql`
    driver behind the driver interface (connect, run one statement,
    begin, commit, roll back, close, latency and error code); unit
    tests run in the image against a throwaway PostgreSQL;
  - **3b, the brick**: the image from `debian:13-slim`, s6, `sshd`, the
    `player` account; the scheduler's s6 run script reading
    `schedule.yaml` as root and passing it on standard input before
    `s6-setuidgid`; `schedule.yaml` read in place from its seed config
    `/opt/gm/seed/schedule.yaml` (0:0 `"0400"`, `seed.modes`), never
    copied onto a volume (spec D163), `docs/player.md` saying where it
    is; the repository (`queries.yaml`, `builders/`) and `jobs.yaml`
    seed-once in the directories `/srv/scheduler/repository` and
    `/srv/scheduler/jobs`, its two configuration `writable_paths`
    (spec D170), writable by `player` only where the write
    policy or an override allows; `gm-reload-scheduler` (restores owner
    and mode, refuses on a report-only file); the validator; the
    node-health service list entry; `brick.yaml` (roles `producer` and
    `consumer`, both write policies, `writable_paths`, `seed.paths` and
    `seed.modes`, `snapshot:` every volume by `copy`, footprint at rest
    measured; no connection secret declared, render deriving one per
    role the schedule names, W1 item 7, spec D167), `docs/gm.md` and
    `docs/player.md`, the stack test (idle at
    start, running after the marker, a summary every minute with a
    stream at 2 per hour, a killed program resuming without replay, a
    job moved by `player` and reloaded, `schedule.yaml` unreadable by
    `player` and the service account, report-only refusals, an override
    of `/srv/scheduler/jobs` on a report-only node letting `player` edit
    `jobs.yaml` with `sed -i` and reload it).
  - Out: render's shifting (chunk 7); `start-load` (chunk 8); faults
    (chunk 14).
- Files: `bricks/scheduler/` (new): `program/` (the package),
  `tests/unit/`, `tests/run-unit-tests.sh`, `Dockerfile`,
  `rootfs/etc/s6-overlay/s6-rc.d/{scheduler,sshd}/`,
  `rootfs/usr/local/sbin/{gm-entrypoint,gm-reload-scheduler,gm-validate}`,
  `validator/validate.sh`, `brick.yaml`, `docs/{gm,player}.md`,
  `tests/{run-stack-test.sh,stack.test.yml}`.
- Spec sections: master spec 7, 7.1, 9; access model 5 ("Scheduler
  nodes"), 7, 8; spec D115, D116, D118, D130, D133, D136, D137, D163,
  D166, D167, D170.
- Done when: the program's unit tests cover each behaviour of 3a,
  including a seeded run giving the same draws twice; the image builds;
  the stack test passes every item of 3b; the loader accepts the brick;
  `test_brick_docs` passes.
- Verification: chunk checks, plus the program's unit tests and the
  stack test (needs G3).
- Split rule: 3a the program and its unit tests, with a complete
  `brick.yaml` and `docs/gm.md` from its first commit so the suite stays
  green; 3b the image, s6, wrappers, validator, docs and stack test.

Record: 3a f2e5781, 3b 10faa0b (merge 3b54bee). No deviation from the
spec or W1; what W1 left to it is in Capture W1-y. Its tests use Debian's
PostgreSQL 17, not the `postgres` brick's 18.

### Chunk 4 — `postgres` 0.3.0

Status: merged (w1, 913c13e)
Wave: 1
Depends on: chunk 1 (1a at least), merged into `v0.3-w1` before this
chunk's branch is cut (spec D166); W1; G2, G3
Architecture capture: none of its own; it records the GM check role, the
reserve and the PgBouncer lookup role as built as W1-x (read by chunks
6, 9, 11).

- Goal: the database brick under load: the GM's reserve and check role,
  the snapshot method, ownership restored on reload.
- Scope: in:
  - **4a**: `reserved_connections` (two, or the measured need) set on
    the server's command line by the run script; the GM check role
    created at start-up, not a superuser, member of
    `pg_use_reserved_connections`, `pg_monitor` and `pg_read_all_data`,
    with `SELECT` on the `pg_hba_file_rules` view and `EXECUTE` on the
    function, its password a generated secret readable by root only, and
    the root-only helper `check-psql` the sealed checks connect through
    (W1 item 8, spec D169); the
    PgBouncer lookup role and its lookup function (`auth_query`'s
    database side, returning superusers too, `dba` among them), created
    at start-up when the scenario has a `pooler` node, its password a
    secret shared with that node; the default `max_connections` 100,
    envelope 10 to 200; stack test: the check role connects with the
    server's slots all taken by an ordinary role, through `check-psql`,
    and reads `pg_hba_file_rules`;
  - **4b**: the snapshot helper: `pg_basebackup` over the local socket,
    tar to standard output with `-X fetch` and a temporary physical
    replication slot reserving WAL from its creation, dropped afterwards
    even on failure (or a copy into a snapshot volume, as the build
    finds), making true the `snapshot:` chunk 1 declares (`pgdata` by
    `pg_basebackup`, the other volumes by `copy`, never `/run`; W1 item
    3, kept as written unless the build finds it wrong, recorded in W1-x,
    spec D167), the helper in `protected_files`; `gm-reload-db` and
    `gm-restart-db` restore a seeded file's owner and mode before
    reloading (RG-2); stack test: a snapshot restored into a fresh
    container starts with the data, the slot gone; a `sed -i` by
    `player` then a reload leaves the file's owner as seeded.
  - Out: report-only for `postgres` (fixable only, master spec 7.3).
- Files: `bricks/postgres/{Dockerfile,brick.yaml}`,
  `bricks/postgres/rootfs/etc/s6-overlay/s6-rc.d/postgres/run`,
  `bricks/postgres/rootfs/usr/local/sbin/{gm-entrypoint,gm-reload-db,gm-restart-db,gm-snapshot-db}`,
  `bricks/postgres/rootfs/usr/local/lib/gm/check-psql` (new, spec D169),
  `bricks/postgres/docs/gm.md`,
  `bricks/postgres/tests/{run-stack-test.sh,stack.test.yml,fixtures/}`.
- Spec sections: master spec 7.3, 11 (item 5), 16; access model 5
  ("Database, its logs and PgBouncer"), 7, 8, 11; spec D138, D142,
  D144, D164, D166, D167, D169, D171.
- Done when: the stack test shows each item of 4a and 4b; the loader
  accepts the brick; `test_brick_docs` passes; `docs/gm.md` states the
  reserve, the check role and `check-psql`, the lookup role and the
  snapshot helper; the stack test's seed (`tests/fixtures/pg_hba.conf`)
  carries the replication line and the `gm_check` line under its DO NOT
  TAMPER comment, and the check role connects through it (spec D164,
  D171).
- Verification: chunk checks, plus the stack test (needs G3).
- Split rule: 4a reserve, check role, lookup role; 4b the snapshot helper
  and the ownership restore.

Record: 4a a91689b, 4b 190b374 (merge 913c13e). No deviation from the
spec or W1 (`-X fetch` with a temporary slot held, no snapshot volume);
its choices are in Capture W1-x. Outside its Files line:
`tools/tests/test_{deploy,fit,state,teardown}.py` (the two new secrets).

### Chunk 5 — The monitoring bricks 0.2.0: report-only and snapshots

Status: merged (w1, 21258a0)
Wave: 1
Depends on: chunk 1 (1a at least), merged into `v0.3-w1` before this
chunk's branch is cut (spec D166); W1; G2, G3
Architecture capture: none of its own; it implements W1's write-policy
and snapshot contracts.

- Goal: `prometheus`, `postgres-exporter` and `grafana` honour a
  report-only write policy, restore ownership on reload, and document
  the snapshot methods chunk 1 declares (spec D108, D147, D167).
- Scope: in: each entrypoint reads the node's write policy and overrides
  from its environment (W1): on a report-only node the seeded files are
  read-only for `player` except an overridden path, and the reload
  wrappers refuse with a one-line reason; the wrappers restore owner and
  mode before reloading; `report-only` added to the three bricks'
  `write_policies`; the `snapshot:` values chunk 1 writes (Prometheus'
  TSDB and Grafana's data by `stop`, the exporter by `copy`, seed volumes
  by `copy`; W1 item 3) kept as written unless the build finds them
  wrong, said in the chunk's Record line (spec D167);
  Prometheus' admin and lifecycle APIs stay off; `docs/gm.md`: the write
  policies offered (both), the Grafana interface gap, the brief stop;
  stack tests for both policies and an override.
  Out: the renderer passing the policy (chunk 7); `gmctl snapshot`
  (chunk 11).
- Files: `bricks/{prometheus,postgres-exporter,grafana}/rootfs/usr/local/sbin/*`
  (entrypoints, reload wrappers), `bricks/{prometheus,postgres-exporter,grafana}/{brick.yaml,docs/gm.md}`,
  `bricks/{prometheus,postgres-exporter,grafana}/tests/{run-stack-test.sh,stack.test.yml}`.
- Spec sections: master spec 7.4, 16; access model 5 ("Nodes",
  "Monitoring interfaces"), 7, 11; spec D108, D143, D147, D166, D167.
- Done when: each stack test shows, on a report-only node, a seed file
  unwritable by `player` and the wrapper refusing, on a fixable node the
  edit taking effect through the wrapper with the owner restored, and an
  override making one path fixable; the loader accepts the three bricks;
  `test_brick_docs` passes.
- Verification: chunk checks, plus the three stack tests (needs G3).
- Split rule: 5a `prometheus` and `postgres-exporter`; 5b `grafana`.

Record: 5a d009cb9 (merge 66b926f), 5b 5b3303f (merge 21258a0). No
deviation from the spec or W1; chunk 1's `snapshot:` values held
unchanged. The write policy is applied by a root-only Perl helper
`gm-write-policy` per brick (no Python in these images), matching the
scheduler's commands and refusal lines.

### Chunk 6 — The `pgbouncer` brick 0.1.0

Status: merged (w2, a7c9efb)
Wave: 2
Depends on: chunks 1, 4 (W1-x: the lookup role); G2, G3
Architecture capture: none.

- Goal: the optional pooler node of master spec 7.2.
- Scope: in: the image from `debian:13-slim` with `pgbouncer`
  `1.26.1-1.pgdg13+1` from the PostgreSQL apt repository (`trixie-pgdg`;
  amended by spec D177, Debian 13's 1.24.1 having open CVEs), s6, `sshd`, `player`; seed-once `pgbouncer.ini`, writable
  by `player` on a fixable node; `gm-reload-pgbouncer` (restores owner
  and mode; refuses on report-only); `auth_query` against the database
  with the lookup role's secret, `auth_dbname` set so the console
  accepts `dba`; `stats_users` naming `dba`, `admin_users` naming only
  PgBouncer's service account over the local socket; envelopes on
  `default_pool_size`, `max_client_conn`, `max_db_connections`,
  `reserve_pool_size`, `pool_mode` `session` or `transaction`; role
  `pooler`, both write policies; `snapshot:` every volume by `copy`; the
  validator; `brick.yaml`, `docs/gm.md`, `docs/player.md`; the stack test
  with a `postgres` node: an application role through the pooler, `dba`
  running `SHOW POOLS` and refused `RELOAD`, the GM's admin over the
  local socket, an edit reloaded, report-only refusals; footprint at
  rest.
  Out: a metrics exporter (master spec 2).
- Files: `bricks/pgbouncer/` (new): `Dockerfile`,
  `rootfs/etc/s6-overlay/s6-rc.d/{pgbouncer,sshd}/`,
  `rootfs/usr/local/sbin/{gm-entrypoint,gm-reload-pgbouncer,gm-validate}`,
  `validator/validate.sh`, `brick.yaml`, `docs/{gm,player}.md`,
  `tests/{run-stack-test.sh,stack.test.yml}`.
- Spec sections: master spec 7.2; access model 5 ("Database, its logs and
  PgBouncer"), 7; spec D119, D139, D177.
- Done when: the stack test shows each item above; the loader accepts
  the brick; `test_brick_docs` passes.
- Verification: chunk checks, plus the stack test (needs G3).
- Split rule: 6a image, s6, authentication, wrapper, validator; 6b
  `brick.yaml`, docs, stack test.

Record: 6a 9916b2b, 6b 6f0b0d0 (merge a7c9efb). No deviation from the
spec; the chunk's own choices (the GM's settings included after the
players' file, the reload's trial run, `auth_type = hba`, the envelopes)
are capture W2-a in the wave log. Outside its Files line: the root
`README.md`'s brick row (a shared list).

### Chunk 7 — Render for v0.3: the planned hand-over, the shift, write policies and secrets

Status: merged (w2, 386092b)
Wave: 2
Depends on: chunks 1, 2
Architecture capture: at wave 2 start (W2), for chunk 8: the local
implementation's new records (planned hand-over, shift, customer's time
zone, seed) and their keys.

- Goal: `gmctl render` produces a v0.3 game: shifted schedules, the
  customer's time zone, write policies and overrides in the containers,
  the scheduler's secrets.
- Scope: in:
  - **7a**: `render --handover <UTC date and hour>`, optional for a
    scenario with no scheduler node, which has no shift, no time zone and
    nothing to render differently (spec D158); the shift (designed hand-over hour
    minus the planned one, brought between −11 and +12); the customer's
    time zone (`Etc/GMT∓N` and its plain reading) filled into
    `{{customer_timezone}}` in the story and the starter pack; the
    scheduler's rendered files (W1): jobs in UTC, shifted; a job's
    `timezone_offset: <N>` (spec D168) written as the fixed zone
    `timezone: Etc/GMT∓M`, M the shift plus N wrapped modulo 24 into
    UTC−12..UTC+14, beside the unshifted time; shapes and timeline
    moments in UTC from the planned hand-over; the game's seed generated
    and written into each scheduler's `schedule.yaml`, a per-game seed
    config read in place (spec D163); all recorded in the local
    implementation;
  - **7b**: each node's write policy and overrides passed to its
    container (W1); each seed config mounted with its brick's
    `seed.modes` mode, `"0444"` otherwise, and a directory seed entry's
    files one config each (W1 item 3); the scheduler's connection
    secrets, the lookup role's
    and the GM check role's generated by kind and mounted where W1 says;
    `load-data` setting the application roles' passwords from their
    secrets after the data load; tests.
  - Out: placement (chunk 10); `start-load` (chunk 8).
- Files: `tools/gm/{render,localimpl,deploy,inject}.py` (`inject.py` for
  `load-data` only), `tools/gm/__init__.py` (`--handover`),
  `tools/tests/test_{render,deploy,inject}.py`,
  `.claude/skills/game-master/gmctl.md` (the `render` row).
- Spec sections: master spec 6.1, 7.1, 7.4, 8.3, 13; access model 5
  ("Nodes"); spec D129, D136, D143, D158, D163, D168.
- Done when: unit tests show the shift for several planned hours, a job's
  UTC time, a wrong-zone job wrapped across UTC+14, a timeline moment
  falling before T0, the time zone filled in the story, a report-only
  node's environment with an override, the secrets mounted and set at
  `load-data`; a scenario with no scheduler node rendered without
  `--handover`; `docker stack config` accepts a rendered stack with
  scheduler nodes; `smoke.sh` passes.
- Verification: chunk checks, plus `sh tools/tests/smoke.sh` (needs G3).
- Split rule: 7a the hand-over, shift, time zone and scheduler files; 7b
  write policies, secrets and `load-data`.

Record: 7a 9b2c945, 7b 590d225 (merge 386092b). No deviation from the
spec or W2; directory seed entries and `seed.modes` moved from 7b to 7a;
W2 addenda in the wave log. Outside its Files line: `smoke.sh` and
`tools/tests/test_{fit,state,teardown}.py`, for the secret counts
(`only_with_role`, carried from wave 1).

### Chunk 8 — The aging: `start-load`, `inject --at`, outages, the early and hand-over checks, `status`

Status: merged (w2, 4b1f85f)
Wave: 2
Depends on: chunks 3 (W1-y: marker, summaries), 7 (in-wave, W2), 9
(in-wave, W2: the "too soon to tell" verdict)
Architecture capture: at wave 2 start (W2): the stage list with
`load-started`; the records of T0, the scheduled actions and their
results, the outages, the lost time, the earliest hand-over, the early
and hand-over checks; the host timer's form (persistent systemd user
units named after the game id, spec D173) and how teardown removes it; how a check
verdict reports "too soon to tell" with its remaining window (from
chunk 9); the test-harness override's form (G6).

- Goal: the aging runs unattended between T0 and hand-over, as master
  spec 8.4, 8.5 and 8.7 say, and `status` tells where it is.
- Scope: in:
  - **8a**: the stage `load-started`; `gmctl inject` without `--at`
    planting only the instances due at T0, as today otherwise;
    `gmctl start-load` (needs
    `injected`): writes each scheduler's marker holding T0, restarts its
    s6 service, records T0 once all have started, a failure on one
    scheduler recorded without teardown, refused once handed over;
    `gmctl inject --at <UTC time>|now --instance <id>` (needs
    `load-started`): one `state` instance, scheduled on the manager by a
    host timer whose run is `inject --at now --instance <id>`, or planted
    at once; refused at or after hand-over; a failure recorded, never a
    teardown (the setup step's record-only mode); the early check
    scheduled at `start-load` (halfway through the aging minimum, or once
    every job due before the earliest hand-over has run once, and no
    later than an hour before it); the host timers persistent systemd
    user units, one pair per scheduled action, enabled, so an action due
    while the host or its user manager was down runs when it is back, a
    late run first waiting, up to a bound the chunk chooses, for the
    game's nodes to run (spec D173); teardown disabling and removing the
    game's timer units;
    `start-load` refused, with a one-line reason, in a game with no
    scheduler node, which has no aging (spec D157);
    **the test-harness override of the aging minimum** (G6, spec D156):
    for one game, a shorter aging minimum that the earliest hand-over
    counts from, each instance's own aging minimum capped at it wherever
    the earliest hand-over or the hand-over check counts it (spec D161),
    so a test run
    reaches its hand-over check, snapshot and restart in about two hours;
    set only by the harness scripts (`tools/tests/rehearsal.sh`, chunk
    11's run), in a form the chunk chooses and records in W2; recorded
    in the local implementation and shown first by `status`, above
    everything else; never named in the GM skill or `gmctl.md`, and never
    used by a GM; it shortens the wait, never a clock;
  - **8b**: outages read from the schedulers' per-minute summaries and
    the nodes' task history, a node whose kept history may have lost
    tasks since the previous reading flagged, its lost time then a
    lower bound (spec D174); the lost time; the earliest hand-over,
    computed by one function: the later of the aging minimum since T0
    and every instance's own minimum since its actual planting, the
    whole moved later by the lost time beyond thirty minutes (spec
    D175); the early check and the hand-over check (every planted
    fault present, every scheduler key running, no node unhealthy, the
    outages), recorded; `status` heading with any failure or outage,
    then the aging's progress, the lost time, the earliest hand-over,
    the shift, the snapshot and restarts; no tools-password line without
    a web front (RG-3); `status --set handed-over` refused before the
    earliest hand-over or without a passed hand-over check (its third
    condition, the snapshot, arrives with `snapshot` in chunk 11a, spec
    D172); `smoke.sh` running `check --handover-check` before it hands
    over. A game with no scheduler node (spec D157, D158) has no T0 beyond the planting, no early
    check, no outages and no earliest hand-over: its hand-over check
    reads the faults and the nodes only, `status` shows no aging lines,
    and `status --set handed-over` needs the hand-over check (and, from
    chunk 11a, the snapshot) only; a setup failure tears it down, as in v0.2.
  - Out: `snapshot` and `restart`, and `status --set handed-over`'s
    snapshot condition (chunk 11); the check role and exit 3
    themselves (chunk 9).
- Files: `tools/gm/aging.py` (new), `tools/gm/{state,inject,localimpl,teardown}.py`,
  `tools/gm/__init__.py` (verbs and options), `tools/tests/test_{aging,state,inject,teardown}.py`,
  `tools/tests/smoke.sh` (the hand-over check before the hand-over),
  `.claude/skills/game-master/gmctl.md` (the rows it changes).
- Spec sections: master spec 8 (its opening), 8.4, 8.5, 8.7, 9, 13, 16, 20;
  access model 3, 5 ("The load and the setup actions"), 6 (`aging-done`),
  7, 9; spec D117, D131, D152, D156, D157, D158, D161, D172 to D175.
- Done when: unit tests (a fake engine and a fake timer, never a fake
  clock in a running game) show each refusal; `start-load` recording T0;
  a scheduled planting and its failure recorded without teardown; the
  lost time and the earliest hand-over for no outage, twenty minutes and
  fifty minutes of outage; a low-rate stream not read as an outage; a
  pruned task history flagged and read as "at least"; a timer's units
  written, enabled and removed by teardown (a fake `systemctl`), and a
  late run waiting for the nodes;
  `status`'s head; `status --set handed-over` refused and accepted on
  its two conditions; `smoke.sh` passing with its hand-over check;
  the harness override recorded, shortening the earliest hand-over, an
  instance whose own minimum exceeds it capped at it, and heading
  `status`; a game with no scheduler node refusing `start-load`
  and handed over after `injected` with no aging; `gmctl` offers no verb
  that pauses, speeds up or triggers the load.
- Verification: chunk checks, plus `sh tools/tests/smoke.sh` (needs G3).
- Split rule: 8a stage, `start-load`, `inject --at`, the timers; 8b
  outages, lost time, earliest hand-over, the two checks, `status`.

Record: 8a 7b20533, 8b c9ddfe5 (merge 4b1f85f). No deviation from the
spec or W2; W2 addenda in the wave log (the override's form, the late
run's bound). Outside its Files line: `tools/tests/test_{checks,deploy}.py`
and a new `tools/tests/fakebin/systemctl`.

### Chunk 9 — Checks under load: exit 3 and the GM check role

Status: merged (w2, 829d1c8)
Wave: 2
Depends on: chunks 1, 2, 4 (W1-x: the check role)
Architecture capture: none of its own; it gives W2 its verdict.

- Goal: sealed checks hold on a living system (master spec 11): a third
  outcome, a connection the load cannot take.
- Scope: in: `gmctl check` reads exit 3 as "too soon to tell", printing
  the remaining window from the script's first output line, and its own
  exit code accounting for it; a behavioural check's `window` and
  `threshold` from the answer key passed to its script as
  `CHECK_WINDOW_SECONDS` (an integer) and `CHECK_THRESHOLD` (as
  written), beside its `FAULT_*` variables (W1 item 4, spec D165); the
  check scripts' database connections as the GM check role through
  `postgres`' root-only `check-psql` helper (W1 item 8, spec D169),
  inside the reserve; the seven existing database checks (`pg-*`) moved
  from `postgres` over the local socket to the check role, unchanged in
  what they judge; a check needing more than the role's privileges is a
  finding, reported; `validate` unchanged; tests.
  Out: the new faults' checks (chunk 14).
- Files: `tools/gm/checks.py`, `tools/tests/test_checks.py`,
  `faults/pg-*/checks/fixed.sh`, `.claude/skills/game-master/gmctl.md`
  (the `check` row).
- Spec sections: master spec 6.2, 6.5, 11, 16; access model 5, 8; spec
  D124, D144, D165, D169.
- Done when: unit tests show exit 0, 1, 3 and an error read as fixed,
  present, too soon and error, and a behavioural check's window and
  threshold reaching its script; on a deployment of `fixture-audit` with
  `max_connections` exhausted by an ordinary role, every `pg-*` check
  still runs as the check role and returns 1 when planted; the unit
  suite passes.
- Verification: chunk checks, plus the exhaustion run on `fixture-audit`
  (needs G3).

Record: f74b6b4 (merge 829d1c8). No deviation from the spec or W2;
W2 addenda in the wave log (the pre-0.3.0 fallback to `postgres` among
them). Outside its Files line: the `check` help text in
`tools/gm/__init__.py`.

### Chunk 10 — Multi-host: hosts, placement, `fit` per host, the image copy

Status: planned
Wave: 3
Depends on: chunk 7; G4 (10b's two-host try)
Architecture capture: at wave 3 start (W3), for chunk 11: the
playground declaration's shape (a list of hosts, the mapping from the
scenario's `designed_for` hosts), the per-host Docker contexts, and that
a node's volumes live on its placed host.

- Goal: a game placed across declared hosts, as master spec 10.2 says,
  and `fit` counting what an aged game needs.
- Scope: in:
  - **10a**: the playground declaration as a list of hosts (swarm node
    name, Docker endpoint, manager or not, capacity at available memory)
    with the mapping onto the scenario's `designed_for` hosts; a
    one-host declaration in today's form read as a list of one;
    per-node placement through the mapping, rendered as hostname
    constraints instead of `PLACEMENT_CONSTRAINT`, stateful nodes pinned
    with their volumes, the bastion pinned to its host, `fit` refusing
    a node with published ports placed on any host but the manager
    (spec D180); `fit` per host
    (limits, reservations, disk, each host's images once), counting the
    footprints' growth per hour over the scenario's aging and a
    four-hour game, and the hand-over snapshot's copies, saying when the
    snapshot does not fit;
  - **10b**: `deploy` copying to each other host the images of its
    nodes with `docker save | docker --context dbagm-<host> load`
    through the host's SSH Docker context (spec D181), skipping an image
    the host holds under the same id, never pulling; per-host SSH Docker
    contexts for the exec verb and the image copy, reached as well by a
    host timer's run (chunk 8a), which has only the user manager's
    environment (spec D173); teardown per host: the game's Swarm objects
    on the manager, its containers and volumes on every declared host
    (spec D179); the game's overlay network MTU set for
    VXLAN inside Tailscale; `bastion` 0.3.0's `docs/gm.md` stating the
    placement rule; the try on armenelos plus the VPS (needs G4): a
    two-host `fixture-monitoring` game deployed, the bastion's ports open
    on its host only, the exec verb reaching a VPS node, from a shell
    and from a run in the user manager's environment, the images
    copied once; the VPS node `active` for the try only, drained again
    after ("Workflow deltas").
  - Out: a registry (none); Kubernetes.
- Files: `tools/gm/{fit,localimpl,render,deploy,docker,execnode,teardown}.py`,
  `tools/gm/__init__.py`,
  `tools/tests/test_{fit,render,deploy,teardown}.py`,
  `tools/tests/__init__.py` and `tools/tests/fakebin/docker` (the fake
  engine answering for several hosts, W3 item 3),
  `bricks/bastion/docs/gm.md`, `.claude/skills/game-master/gmctl.md`
  (`fit`, `deploy` and `teardown` rows).
- Spec sections: master spec 6.4 (footprint), 7.5, 8.6, 10; access model
  7 (`network-visitor`); spec D125, D128, D149, D173, D179, D180, D181.
- Done when: unit tests show a two-host declaration, the mapping, the
  hostname constraints, the bastion pinned, `fit` refusing a host short
  of memory or disk and saying the snapshot does not fit, `fit` refusing
  published ports off the manager, the image copy skipped for a present
  id, teardown reaching every declared host and failing on one that does
  not answer; every existing scenario renders unchanged
  but for its constraint line on one host; `smoke.sh` and
  `smoke-monitoring.sh` pass on one host; the two-host try passes, its
  MTU and Swarm findings recorded.
- Verification: chunk checks, plus `smoke.sh`, `smoke-monitoring.sh`
  (needs G3) and the two-host try (needs G4).
- Split rule: 10a declaration, placement, `fit`; 10b image copy,
  contexts, teardown per host, MTU, the try.

### Chunk 11 — The hand-over snapshot and the restart

Status: planned
Wave: 3
Depends on: chunks 3, 4, 5, 6, 8; chunk 10 (in-wave, W3)
Architecture capture: none of its own; it uses W1's snapshot contract and
W3.

- Goal: `gmctl snapshot` and `gmctl restart`, as master spec 12 says.
- Scope: in:
  - **11a**: `gmctl snapshot` (needs `load-started`, or `injected` in a
    game with no scheduler node, which keeps its snapshot and the brief
    stops it takes, spec D162; refused before the earliest hand-over and
    once handed over): every volume of the game
    copied by its brick's method (`pg_basebackup` through `postgres`'
    helper, `copy`, a brief stop through s6 for `stop`), stored on the
    volume's own host, labelled with the game id, its location recorded;
    when `fit` said it does not fit, recorded as not fitting; teardown
    removing it; `status --set handed-over`'s third condition, the
    snapshot taken or recorded as not fitting, in both kinds of game,
    added to chunk 8b's two, and `smoke.sh` taking the snapshot before
    it hands over (spec D172);
  - **11b**: `gmctl restart --confirmation "<words>"` (refused without
    them, and before hand-over): the confirmation recorded; every node
    and volume of the game removed but the snapshot; a new game id;
    every secret's value kept under new Swarm secret objects; a new
    game seed in each scheduler's `schedule.yaml`, which is not on a
    volume and so not in the snapshot (spec D163); fresh
    nodes deployed on fresh copies of the snapshot, which carry the
    check role's `CONNECT` grants with the data, the schedulers
    resuming from their marker; or, with no snapshot, the data loaded
    with `load-data`'s grants (spec D176),
    every fault planted at once, the load, when the game has scheduler
    nodes, started with the timeline applied, inside `restart` (the after-hand-over refusals not
    applying); the rebuilt game at `handed-over`, its four hours
    counting from the first hand-over; the snapshot kept for a second
    restart; the restart recorded (old and new ids, time, from the
    snapshot or not, the words).
  - Out: the GM's statement and the confirmation dialogue (chunk 13).
- Files: `tools/gm/{snapshot,restart}.py` (new),
  `tools/gm/{teardown,deploy,localimpl,state}.py`, `tools/gm/__init__.py`,
  `tools/gm/aging.py` (the hand-over's snapshot condition),
  `tools/tests/test_{snapshot,restart,teardown,aging}.py`,
  `tools/tests/smoke.sh` (the snapshot before the hand-over),
  `.claude/skills/game-master/gmctl.md` (rows).
- Spec sections: master spec 6.4, 7.1 to 7.5 ("Snapshot"), 12, 13;
  access model 3, 5 ("The load and the setup actions", "Game control"),
  6, 7, 9; spec D123, D126, D141, D142, D147, D156, D157, D161, D162,
  D163, D172, D176.
- Done when: unit tests show each refusal, `status --set handed-over`
  refused without the snapshot taken or recorded as not fitting, in both
  kinds of game, `smoke.sh` passing with its snapshot before the
  hand-over, the secrets' values equal
  under new objects, the stage after a restart, two restarts in a row,
  teardown removing the snapshot; on a deployment of a load fixture
  (chunk 12's, or a scratch one until it merges), its hand-over reached
  early through chunk 8a's harness override (G6, spec D161), a snapshot
  taken under load with the brief stops, then a restart from it with the players'
  password still valid and the schedulers running, then a no-history
  restart, each with a new seed; a snapshot and a restart of `fixture-monitoring`, which has
  no scheduler node, its Prometheus and Grafana stopped briefly and
  started again for the snapshot (spec D162); nothing labelled left
  after teardown.
- Verification: chunk checks, plus `sh tools/tests/smoke.sh` and the
  snapshot and restart run (needs G3).
- Split rule: 11a snapshot; 11b restart.

### Chunk 12 — The load fixture and the smoke tests under load

Status: planned
Wave: 3
Depends on: chunks 2, 3, 6, 7, 8, 9; G3
Architecture capture: none.

- Goal: a short `gmctl`-driven game with load, run at every wave gate
  from here on, on one host and on armenelos plus the VPS (master spec
  11, "Smoke tests").
- Scope: in: `fixture-load` (bastion, `postgres`, `pgbouncer`, a
  producer and a consumer, the three monitoring bricks, one report-only
  monitoring node, write overrides on the producer, a scenario-local
  harmless fault, `aging:` at the floor); `smoke-load.sh <playground>`:
  `fit`, `render --handover`, `deploy`, `load-data`, `inject`,
  `start-load`, a few minutes of schedules, every scheduler key running
  in the summaries and the metrics, PgBouncer's pools in use, every
  fault present (polled, per-check timeouts), the faults due during the
  aging planted at once with `inject --at now`, a check exiting 3 read
  as too soon, the report-only node refusing, then teardown leaving
  nothing labelled (timers included); `smoke-scenario.sh` rewritten for
  load the same way, still passing on both existing scenarios, which
  have no scheduler node: rendered without `--handover`, no
  `start-load` (spec D157, D158).
- Files: `tools/tests/fixtures/fixture-load/` (new),
  `tools/tests/smoke-load.sh` (new), `tools/tests/smoke-scenario.sh`,
  `tools/tests/test_model.py` (the fixture loads).
- Spec sections: master spec 9, 11; access model 5, 7.
- Done when: `smoke-load.sh` passes on armenelos alone (its two-host
  run is the wave 3 gate's: a game reaches the VPS only through chunk
  10's placement and image copy);
  `smoke-scenario.sh` passes on `bookshop-new-server` and
  `fernway-clinics-monitoring`; the fixture's README matches a fresh
  regeneration.
- Verification: chunk checks, plus both smoke scripts on one host
  (needs G3); the VPS stays drained.

### Chunk 13 — The GM skill for v0.3

Status: planned
Wave: 4
Depends on: chunks 7, 8, 9, 10, 11
Architecture capture: none.

- Goal: the GM runs a v0.3 game as master spec 8, 9, 12 and 13 say.
- Scope: in: `SKILL.md`: the feasibility judgement for a scenario with
  scheduler nodes (its declared aging against the time the initiator
  has, declining or proposing another); a scenario with none, which has
  no aging, handed over once its faults are planted, as in v0.2, but
  after the hand-over check and the snapshot, its brief stops and the
  scrape gap told as maintenance included, with no planned hand-over
  needed and its faults' own aging minima not counted (spec D157, D158,
  D160, D162); the deployment with the planned hand-over and the shift;
  the playground's hosts; `start-load`, the scheduled plantings and the
  early check; a resumed session running `status` first and
  telling the initiator of failures or outages; the thirty-minute
  threshold and the judgement beyond it; setting a game up again (stop,
  then start); the refusal of an early hand-over; the hand-over check,
  re-planting a failed instance, the snapshot and the maintenance
  window; the customer's time zone in the starter pack; no load control,
  ever; the restart: its statement (what is lost, and without a
  snapshot which evidence), a confirmation in so many words, `restart
  --confirmation`, a passing mention or a question never restarting;
  "too soon to tell" and waiting a window. `feedback.md`: a fault
  undetermined at the final answer. `gmctl.md`: every line chunks 7 to
  11 left. Out: new scripts; the stance itself, unchanged.
- Files: `.claude/skills/game-master/{SKILL,gmctl,feedback}.md`.
- Spec sections: master spec 8, 9, 10, 11, 12, 13; access model 3, 5, 7,
  8, 9; spec D141, D150, D152, D157, D158, D160, D162.
- Done when: the skill covers each item of master spec 13's "The GM
  skill"; every `gmctl` invocation in the three files parses with
  `gmctl`'s own parser; the stance check-list items v0.2 had are
  unchanged and v0.3's (early hand-over, load control, restart
  confirmation) are added.
- Verification: chunk checks; the stance check-list runs at the release
  gate.

### Chunk 14 — The eight new catalog faults

Status: planned
Wave: 4
Depends on: chunks 2, 3, 6, 9, 12
Architecture capture: at wave 4 start (W4), for chunk 15: the eight
faults' ids, target bricks, seed changes, parameters, aging minima and
resolutions, and the scenario's choice among them and the existing
faults.

- Goal: the faults of master spec 15.3, each complete.
- Scope: in: a query with a syntax or type error; a query missing its
  `WHERE`; a reporting query reading far too much; inserts retried
  without idempotency (judged over a window, exit 3 when too soon); a
  consumer holding transactions open (schedule, report or propose only);
  a nightly batch at the daily peak; a job in the wrong time zone (its
  offset parameter, never 0, its seed change writing `timezone_offset:
  <N>` on the job, spec D168); a PgBouncer pool too small for the peak.
  Each a `seed-file` fault planted at render, with `fault.yaml` (its
  `aging:`, evidence locations), `checks/fixed.sh` judging the cause (the
  query's text, the job's time and zone, the pool's size, the
  schedule's hold) as the GM check role (its `CONNECT` on the
  scenario's databases granted by `load-data`, spec D176) or on the
  node's files,
  `checks/probe.md`, `gm.md`; the "Supported faults" sections of the
  bricks they name, folding into their versions.
  Out: the scenario (chunk 15).
- Files: `faults/<fault-id>/` for each (new),
  `bricks/{scheduler,pgbouncer,postgres}/docs/gm.md` ("Supported
  faults" only).
- Spec sections: master spec 6.3, 7.3, 11, 15.3; spec D134, D145, D168, D176.
- Done when: the loader accepts each fault; `test_brick_docs` passes; on
  a deployment of `fixture-load` with each planted, its evidence shows
  within its aging minimum, its sealed check returns 1, and 0 after its
  fix for the fixable ones (the duplicates check after its window, 3
  before it).
- Verification: chunk checks, plus the faults planted on `fixture-load`
  (needs G3).
- Split rule: 14a the four repository faults; 14b the schedule, the two
  `jobs.yaml` faults and the pool.

### Chunk 15 — The v0.3 scenario, the rehearsal and the measured figures

Status: planned
Wave: 4
Depends on: chunk 14 (in-wave, W4); chunks 5, 8 (the harness override),
10, 11, 12; G4 (15b); G7 before merge
Architecture capture: none of its own; it uses W4.

- Goal: the normal-difficulty scenario of master spec 15.2, complete,
  and the figures an aged game needs, measured on it.
- Scope: in:
  - **15a, the scenario**: the topology (bastion, one `postgres`,
    PgBouncer in front of it, a producer for orders, ingestion and a
    nightly batch, a consumer for reports and an export job, the three
    monitoring bricks); ten fault instances, six or seven of chunk 14's
    plus three or four existing ones (the missing join index planted
    during the aging by `plant_at: handover-<N>h`, autovacuum off on a
    hot table, one monitoring fault); write policies (database and
    PgBouncer fixable, the scheduler nodes report-only with the
    producer's repository and both `jobs.yaml` fixable by override, one
    monitoring node fixable, one report-only); `aging:` sixteen hours,
    hand-over at the customer's early afternoon; retention at least
    twenty hours; the story and starter pack naming
    `{{customer_timezone}}`; `scenario.yaml`, `gm/answer-key.yaml`
    (windows on behavioural checks), `gm/notes.md`, `brief.md`, seed
    files, `data/db.sql` with the application roles, `README.md`
    regenerated;
  - **15b, the rehearsal and the figures**: `tools/tests/rehearsal.sh`,
    the unattended rehearsal of master spec 11 on the scenario, its
    hand-over brought to about two hours after T0 by chunk 8a's harness
    override, which caps the instances' own minima too (G6, spec D156,
    D161), on armenelos plus the VPS: `render --handover`
    chosen so the traffic shapes' peak hours fall inside its two hours,
    `start-load`, a scheduled `inject --at` and the early check fired by
    the host timer, a scheduler container killed and resuming, an outage
    of a few minutes recorded, the hand-over check, the snapshot with its
    brief stops, a restart from it, teardown; run once, measuring every
    node's memory and CPU at peak, the volumes' growth per hour and the
    snapshot's size; the figures into the bricks' `brick.yaml` and
    `docs/gm.md` ("Footprint") and the scenario's `resources`;
    `fernway-clinics-monitoring`'s 256 MB bound checked against the
    measured TSDB growth over its four-hour game (it has no aging, spec
    D157); `fit` re-run; the figures G5 applies (the game's peak memory)
    stated in the Record line.
  - Out: the release notes (release gate).
- Files: `scenarios/<new-id>/` (all of it); 15b:
  `tools/tests/rehearsal.sh` (new), `bricks/*/brick.yaml`,
  `bricks/*/docs/gm.md` ("Footprint"),
  `scenarios/<new-id>/{scenario.yaml,README.md}`, and
  `scenarios/fernway-clinics-monitoring/` if its bound must change.
- Spec sections: master spec 8.6, 10.1, 11, 15.2, 15.4, 17 (items 4, 6);
  access model 7, 11; spec D134, D150, D153, D156, D157, D161.
- Done when: the format skill finds nothing missing; `fit` and `render`
  accept it on armenelos alone and on armenelos plus the VPS; its smoke
  deployment (`smoke-scenario.sh`) has every instance present; the
  rehearsal passes every step and its figures are recorded with machine
  and date; `fit` passes with the measured figures; G7 cleared before
  merge.
- Verification: chunk checks, plus the smoke deployment (needs G3) and
  the rehearsal (needs G4).
- Split rule: 15a the scenario folder; 15b the rehearsal script, its run
  and the figures.

## Release gate

Against master spec section 17, on `v0.3-w4` before it merges, at κ = 1
on the hosts, with v0.1's and v0.2's checks still applying. GM sessions
are fresh agents reading `.claude/skills/game-master/` as their
instructions; the driver plays the initiator; verifier agents play as
`player` through the bastion and the web front only; GM-side checks run
from the host.

1. Item 1: the `scheduler` and `pgbouncer` bricks at 0.1.0 and the
   bumped bricks pass the format skill's `docs/gm.md` check, with their
   validators and measured footprints.
2. Item 2: the templates, the loader and the format skill carry master
   spec 6; the eleven existing faults in the new evidence form, their
   database checks on the GM check role.
3. Item 3: the eight new faults complete (injection, aging minimum,
   cause-first sealed check, solvability description).
4. Item 4: the v0.3 scenario complete by the format skill, its README
   current; G7 cleared.
5. Item 5: `gmctl` as in master spec 13, 8.7 included, checked through
   items 6 to 8.
6. Item 6: `smoke-load.sh` and `smoke-scenario.sh` on the v0.3 scenario
   green on armenelos alone and on armenelos plus the VPS; the
   rehearsal (`tools/tests/rehearsal.sh`) re-run and passed on the merged
   code (spec D156), its
   peak inside the run, the game's memory within the declared figures.
7. Item 7, the aged run (G5, G8): the v0.3 scenario aged for its
   declared sixteen hours, unattended, on the hosts G5 settles, its
   `render --handover` at the customer's early afternoon: the early check
   fired by the timer and passing, the planted-during-aging instance
   planted on time, the lost time recorded; a fresh GM session resuming
   during the aging runs `status` first; the hand-over check, the
   snapshot, the hand-over with the customer's time zone in the starter
   pack; the measured footprint and aged growth within the declared
   figures (no node OOM-killed or restarted, `docker stats` at the
   peak, the volumes and the snapshot against `fit`'s figures).
8. Item 7 continued, the play-through as `player`: every fault's
   evidence reachable where the answer key says, through the bastion
   only; the sealed checks right under load before and after the fixes
   (the window check reading 3 then 0); one restart from the hand-over
   snapshot, confirmed in the GM session in so many words (G9), the
   players' credentials still valid, the schedulers resuming, the
   maintenance window told; the final answer and the feedback.
9. Item 8, the stance check-list: v0.2's items, plus an early hand-over
   refused, a request to pause or trigger the load refused, a passing
   mention and a question about restarting not restarting the game.
10. Item 9: `bookshop-new-server` and `fernway-clinics-monitoring`
    re-pinned, with no aging (no scheduler node, spec D157), each
    through its smoke deployment.
11. v0.1's and v0.2's other checks: a forced setup failure before T0
    reported, torn down and recorded; a forced failure during the aging
    recorded and the game left running.
12. The wave-gate quality command, green.
13. Every row of "Left for the build" has its finding recorded in the
    chunk's Record line and the brick's `docs/gm.md`.
14. G10: the owner's judgement of the aged game and the feedback.
15. Release notes in [README.md](README.md): the measured figures, the
    master spec 20 findings, the known gaps of the access model that
    stand.
