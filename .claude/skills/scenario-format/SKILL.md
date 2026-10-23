---
name: scenario-format
description: Use whenever a db_audit_gm scenario, brick or fault definition is designed, generated, edited or checked for completeness — writing scenario.yaml, gm/answer-key.yaml, brick.yaml or fault.yaml, laying out their folders, or deciding whether a scenario is complete enough to deploy. Start from the templates, fill every required item, flag every missing one; the GM refuses to deploy an incomplete scenario.
---

# Scenario format

Every scenario, brick and fault is written to one shape. This skill holds
that shape: eight templates and the folder layouts. This is its **v0.3
version**, expected to evolve as games are played; when a game shows the
format is missing something, change the template and this skill together.

Source of the shape: v0.1's master spec (`specs/versions/v0.1/master-spec.md`,
sections 6, 7, 8 and 8.1), v0.2's format changes
(`specs/versions/v0.2/master-spec.md`, section 6) and v0.3's
(`specs/versions/v0.3/master-spec.md`, section 6, with 7.1 for a
scheduler's files), with `specs/formats.md`. The top-level keys of
`brick.yaml` are fixed (capture W1-A in `specs/versions/v0.1/wave-log.md`);
v0.2's keys are capture W1 in `specs/versions/v0.2/wave-log.md`, v0.3's
capture W1 in `specs/versions/v0.3/wave-log.md`.

## Templates

| Template | Becomes | Shape of |
|---|---|---|
| [templates/scenario.yaml](templates/scenario.yaml) | `scenarios/<id>/scenario.yaml` | the scenario manifest (authoritative) |
| [templates/answer-key.yaml](templates/answer-key.yaml) | `scenarios/<id>/gm/answer-key.yaml` | the answer key (authoritative, sealed) |
| [templates/brick.yaml](templates/brick.yaml) | `bricks/<id>/brick.yaml` | a brick definition |
| [templates/fault.yaml](templates/fault.yaml) | `faults/<id>/fault.yaml` | a fault definition |
| [templates/queries.yaml](templates/queries.yaml) | `scenarios/<id>/nodes/<node>/queries.yaml` | a scheduler node's query repository |
| [templates/schedule.yaml](templates/schedule.yaml) | `scenarios/<id>/nodes/<node>/schedule.yaml` | a scheduler node's schedule (scenario time) |
| [templates/jobs.yaml](templates/jobs.yaml) | `scenarios/<id>/nodes/<node>/jobs.yaml` | a scheduler node's fixed-time operations (scenario time) |
| [templates/brick-gm.md](templates/brick-gm.md) | `bricks/<id>/docs/gm.md` | a brick's GM documentation (D56): the nine required sections |
| [templates/layouts.md](templates/layouts.md) | — | the scenario, brick and fault folders, and the script contracts |

Markers used in every template:

- every key is **required** unless marked otherwise;
- `# optional in v0.1`: no use yet; left commented out, may be omitted;
- `# optional: <when>`: present only when `<when>` holds (a node holding
  data, a brick with companion material, a seed-file fault);
- an empty list or map is a valid value only where the comment says
  "may be `[]`" or "may be `{}`"; an absent required key is a missing item;
- `<placeholder>`: a value to write. A filled file keeps none.

## Writing one

1. **Start from the template.** Copy it to its place (see the layouts) and
   keep its key order and comments' meaning; drop the template comments
   you no longer need.
2. **Fill every required item.** When designing or generating, the GM
   fills the blanks the initiator left; record what came from the
   initiator in `brief.md` as given.
3. **Fill the folder**, not only the YAML: every file the layout requires
   (starter pack, `gm/notes.md`, node seed files, data files, `inject/`,
   `checks/`, docs).
4. **Check completeness** against the checklists below, by reading. The
   scripts check too: whenever a `gmctl` command loads a scenario, it
   checks the scenario, and every brick and fault it uses, against these
   templates (`model.check_scenario`, `check_brick_dir`,
   `check_fault_dir`), and refuses an incomplete one with the list of its
   missing items (D40). Whether this skill must also run a check of its
   own is open (O20). Beyond that, machine checks are per brick (a
   brick's `companion/`), run by the GM before deploying a scenario that
   uses it.
5. **Flag every missing item** (next section). Do not guess a value to make
   an item disappear.
6. Generate `README.md` with the scenario-document skill once
   `scenario.yaml` and `gm/answer-key.yaml` are complete.

## Flag and refuse

A scenario is complete or it is not deployed.

- **Flag.** For every missing or unfilled item, name it: the file, the key
  path (`nodes[db].knobs[shared_buffers].envelope`) or the missing file
  (`player/story.md`), and what is missing. List them all, not just the
  first. A leftover `<placeholder>`, an absent required key, a missing
  required file and a failed consistency rule are all missing items.
- **Refuse.** The GM refuses to deploy an incomplete scenario: it does not
  generate a local implementation, render, or run `gmctl deploy`. It tells
  the initiator which items are missing, and either fills them (a scenario
  it designs) or asks for them. It deploys only once the list is empty.
- The same holds for a brick or fault the scenario references: an
  incomplete one makes the scenario incomplete.

## Completeness checklists

### Scenario (v0.1 master spec 6.2, v0.2 master spec 6.3, v0.3 master spec 6.1, 6.2)

- **Scenario information**: `id`, `version`, `title`, `date`, `origin`,
  `session_length_minutes` (at most 240), `brief` and `brief.md`.
- **Difficulty** (`difficulty`): its `score`, and optionally the `level`
  it targets (`easy`, `normal`, `hard`; master spec 15.1).
- **Aging** (`aging`), in a scenario with scheduler nodes only: its
  `minimum` and its `handover_at`.
- **Topology**: `networks` (one in v0.2); for every node: `name`, `brick`
  (id, pinned version), `role`, `stateful`, `networks`, `write_policy`
  (and `write_overrides` where a report-only node needs fixable paths),
  `parameters`, `resources` (limits and reservations, disk included, and
  what mounted companion material adds to the node), `published_ports`,
  `seed_files`, `knobs` (initial value and envelope for every knob the
  brick declares), and `data` (file and schema) for a node holding data;
  `flows` (every flow between nodes). With a `prometheus` node, its
  `node_health` map.
- **Background**: `background`, and `player/story.md`.
- **Incidents, flaws and defects**: `fault_instances` (fault id and pinned
  version, `node`, `parameters`, `visibility`, and with scheduler nodes
  `plant_at` and `aging_minimum` where they differ from the defaults);
  `issues` (zero or more, each with `id`, `complaint`,
  `expected_resolution`, `covers`: fault instances and tooling
  expectations).
- **Answer key** (`gm/answer-key.yaml`), for every fault instance: `what`,
  `why`, `evidence` as `player` (each entry with `where`, `source`, `how`,
  `shows`), `acceptable` (diagnosis, and proposal, fix or improvement as
  they apply), `sealed_check` (with its `window` and `threshold` for a
  behavioural check), `interactions`, `validators_left_red`;
  `tooling_expectations` (may be `[]`: each with `id`, `need`,
  `expected`, `acceptable`, optional `notes`); and `gm/notes.md`.
- **Host topology it was designed for**: `designed_for` (platform, hosts
  with CPU, memory, disk, placement of every node).
- **Starter pack** (`player/README.md`, `story.md`, `issues.md`), **node
  files** (`nodes/<node>/`), **restored-backup data** (`data/<node>.sql`).
- **Scenario document** (`README.md`), generated, opening with the "do not
  read" warning.

Consistency rules (a failure is a missing item). Those v0.3 adds (master
spec 6.1, 6.2, 7.3, 8; capture W1 items 0 to 4 and 8) are checked by the
loader too:

- **Scheduler nodes**: a node whose brick id is `scheduler` (capture W1
  item 0), role `producer` or `consumer`. Its seed files are under
  `nodes/<node>/`: `queries.yaml`, an optional `builders/` folder of
  files, `jobs.yaml` and `schedule.yaml`, in scenario time, written from
  the scheduler's templates (master spec 7.1); their rules are under
  "The scheduler's files" below.
- **Aging** (D157, D158): `aging:` is present exactly when the scenario
  has a scheduler node. `minimum` is a duration (`<integer><s|m|h|d>`)
  of at least `8h` and as long as the evidence needs (master spec 8.2);
  `handover_at` is a quoted `"HH:00"`, 24-hour, in scenario time. A
  scenario with no scheduler node does not age: it omits `aging:`, has no
  `plant_at` other than `T0`, no instance `aging_minimum` and no
  `{{customer_timezone}}`, and its fault definitions' aging minima are not
  counted (D160); its times stay UTC, as in v0.2.
- **Difficulty**: `score` equals the number of fault instances (each
  fault is worth 1; tooling expectations do not count); `level`, when
  given, is `easy`, `normal` or `hard`.
- **Planting moment** (`plant_at`): `T0` (the default: right after the
  data load, before the load starts) or `handover-<N>h`, N a whole number
  of hours, at least 1, so never at or after hand-over. A moment other
  than `T0` only for a fault whose `injection.kind` is `state`
  (`seed-file` and `parameter` faults are planted at render), and N is at
  most `aging.minimum` and at least the instance's own aging minimum.
- **Instance aging minimum**: the instance's own minimum is its
  `aging_minimum` when set, at least its definition's `aging.minimum`,
  else the definition's. `aging.minimum` covers every instance: its
  planting offset (`aging.minimum` − N, or 0 at `T0`) plus its own
  minimum.
- **Write overrides** (`write_overrides`): on a `report-only` node only,
  non-empty, each entry one of its brick's `writable_paths` exactly as
  written there; the node's `write_policy` stays as written. A path is
  fixable on a node when the policy is `fixable`, or it equals an
  override, or it lies under an overridden directory.
- **A *fix* resolution's per-file policy**: an issue expecting `fix` of a
  `seed-file` fault needs every file its `seed_changes` edit to land (by
  the brick's `seed.paths`) on a fixable path of the target node; a
  `state` or `parameter` fault needs the node's policy to be `fixable`.
- **The customer's time zone**: the story and the starter pack (the
  bastion's seed files) write it as `{{customer_timezone}}`, which render
  fills from the shift (master spec 8.3), and never name a fixed zone;
  only a scenario with scheduler nodes has one.
- **Prometheus' retention**: the time bound of a `prometheus` node's seed
  (`storage.tsdb.retention.time`) covers `aging.minimum` plus four hours
  (four hours with no aging), unless a planted fault is about retention
  (`family: retention`); a size bound, when set, stays above the TSDB's
  measured growth over the same span, against the brick's footprint.
- **A `postgres` seed's `pg_hba.conf`** keeps, under its DO NOT TAMPER
  comment, right after `local all postgres peer`, the lines `local
  replication postgres peer` (the hand-over snapshot's `pg_basebackup`,
  master spec 7.3, D164) and `local all gm_check scram-sha-256` (the GM
  check role's access, so tightening the general `local` line keeps the
  sealed checks working, D171). An answer key citing the seed's line
  numbers counts them.
- **Behavioural checks**: an answer-key instance has `window` (a
  duration) and `threshold` (a number) exactly when its fault's
  `sealed_check.behavioural` is true.

The rules from v0.2:

- every referenced brick and fault exists at the pinned version (the
  scenario's own `bricks/`, `faults/` first, then the catalog);
- a node's `role` is one of its brick's roles, its `write_policy` is one
  its brick supports (or `no-access`), and every required brick parameter
  is set;
- `seed_files` covers exactly the brick's `seed.files`, and every file
  exists;
- each knob's envelope equals or tightens the brick's default envelope;
  the `initial` value matches the seed file (it may lie outside the
  envelope: the validator is then red from the start, and the answer key
  lists it under `validators_left_red` if the players cannot fix it);
- each fault instance's `node` runs a brick in the fault's `applies_to`;
  every required fault parameter is set;
- an instance is `known` exactly when an issue `covers` it; every `covers`
  id is a fault instance or a tooling expectation; an issue covering only
  expectations expects `report` or `propose`; expectation ids are unique
  across fault instance ids and expectation ids;
- an issue's `expected_resolution` is one the covered faults list, under a
  write policy the target node has (for *fix*, the per-file policy above);
- `gm/answer-key.yaml` has exactly one entry per fault instance;
- every answer-key evidence `where` is `bastion` (a shell on the bastion,
  `psql` from there included), `node:<name>` (a node of the topology
  other than the bastion), `ui:<name>` (`<name>` a route of the bastion's
  `web_routes`) or `report:<tool>` (a generated report, `<tool>`
  lowercase, such as `report:pgbadger`); `source` names the file, view or
  output looked at (v0.1's free-text `where`, D101). The readings a fault
  definition cannot carry (through a web interface, or on a node other
  than its target, D167) live here; every reading dropped from a fault
  stays in the answer key of each scenario planting it;
- **the node-health map** (D97): whenever the topology has a `prometheus`
  node, its `node_health` parameter is set and lists every node of the
  topology by name, `prometheus`'s own included; each entry is `default`
  (that node's brick's `processes`) or a non-empty list of names from
  them. A missing map, or a node missing from it, is a missing item; a
  node left out exists only as a parameter fault planted through the map;
- **mounted material**: every node a mounting brick's map lists runs a
  brick that declares `receives` meeting the item's `requires` (the
  s6-overlay version begins with the required prefix; every required
  command is listed), checked against the mounting brick's pinned version;
- **web routes**: each route of the bastion's `web_routes` names a node
  whose brick provides a web interface on that port with `web_path:
  /<route>/`; every web interface of the topology has exactly one route;
  the bastion publishes `{port: 8080, default: 8080}` exactly when
  `web_routes` is non-empty (an empty map: the web front does not run);
- `player/issues.md` states the same issues as `issues`; nothing under
  `player/` names a hidden fault or an answer;
- `designed_for.placement` places every node, and the summed reservations
  fit the hosts.

### The scheduler's files (v0.3 master spec 7.1)

A scheduler node's `queries.yaml`, `builders/`, `schedule.yaml` and
`jobs.yaml`, under `nodes/<node>/`, in scenario time. Start from
[templates/queries.yaml](templates/queries.yaml),
[templates/schedule.yaml](templates/schedule.yaml) and
[templates/jobs.yaml](templates/jobs.yaml); the forms 7.1 leaves open are
capture W1's (item 7) and spec D168. The loader checks, and a failure is a
missing item:

- **Every key named exists**: each stream's `key`, each job's `key` and
  each timeline change's `set.key` is a key of the node's `queries.yaml`.
- **The repository**: a key is `[a-z0-9][a-z0-9._-]*` and maps to one
  form: a query (`sql`, optional `params`, optional `transaction`), a pool
  (a non-empty list of queries, each with an optional positive `weight`),
  a sequence (`steps`, a non-empty list of `{sql, params}`, optional
  `transaction`) or a builder (`builder: builders/<file>:<function>`,
  optional `options` map). Parameters come from generators, one key each:
  `{int: [lo, hi]}`, `{decimal: [lo, hi, places]}`, `{choice: [..]}`,
  `{sequence: [start, step]}`, `{now: utc}`. A `transaction` has an
  `isolation` (`read committed`, `repeatable read`, `serializable`) and an
  optional `hold` (a duration).
- **Builders**: the file is in the node's `builders/` seed folder (files
  only, named `[A-Za-z0-9_][A-Za-z0-9_.-]*`) and defines the function at
  its top level; the loader parses it, never runs it.
- **Connections**: the driver is a known one (`sql/postgresql`); the
  target is `<node>:<port>/<database>` on a node of the topology; the role
  is an application role (`[a-z_][a-z0-9_]{0,40}`, never `postgres`,
  `dba`, `monitoring`, `gm_check`, `pgbouncer_lookup` or `pg_*`); the pool
  is `{size: N}` or `{per-call: true}`. No password is ever written: render
  generates one secret per role.
- **Streams**: a `rate` `<number>/s|min|h`, `arrivals` `poisson` or
  `even`, an optional `shape` of the schedule, an optional `concurrency`;
  a stream is known by its initial key, unique on the node.
- **Shapes cover the 24 hours**: `hours` maps quoted `"HH"` or `"HH-HH"`
  (never wrapping) to a multiplier at least 0, covering 00 to 23 exactly
  once; a weekly shape's `days` (`mon` to `sun`, alone or as ranges, never
  wrapping) cover the week exactly once, each with its `hours`.
- **Timeline changes**: `at` is `T0` or `handover-<N>h`, before hand-over
  and no further before it than `aging.minimum`; `stream` names a stream
  by its initial key; `set` changes its `key`, `rate` or `connection`.
- **Jobs**: a unique `name`, a `key`, a `connection` of the node's
  schedule, and `at`, a quoted 5-field cron in the subset render can shift
  (minute any numeric form; hour `*`, a number or a list; day of month and
  month `*`; day of week `*` or a number or list 0-6, only with a
  single-number hour). Never `timezone:`. A `timezone_offset: <N>`, a
  non-zero whole number of hours from the customer's zone, only on a node
  where a fault instance's seed change edits `jobs.yaml` (the
  wrong-time-zone fault, D168).
- No other key in `schedule.yaml`: the game's seed is render's.

### Brick (master spec 7)

Every key of [templates/brick.yaml](templates/brick.yaml) except the
commented-out ones; and the folder: `Dockerfile`, `validator/`,
`docs/player.md`, `docs/gm.md`, and `companion/` when `companion` is set.
The image name is registry-qualified; the brick names no Swarm-only
feature. In particular (v0.2 master spec 6.1, v0.3 master spec 6.4):

- **Roles**: each one of the closed list `bastion`, `producer`, `queue`,
  `database`, `pooler` (PgBouncer), `transformer`, `consumer`,
  `monitoring`, `backup`. A scenario node's `role` is one of its brick's.
- **Footprint**: the shape of a scenario node's `resources`, `limits`
  (`cpu`, `memory`) and `reservations` (`cpu`, `memory`, `disk`, at rest),
  the default the GM starts from when it sizes a scenario, plus
  `disk_growth_per_hour`: the volumes' growth per hour of aging and of
  game, as measured (a provisional estimate says so in a comment until it
  is measured), `0` when nothing grows, so `fit` scales the disk to the
  scenario's aging. It excludes any material other bricks mount into this
  one.
- **Writable paths** (`writable_paths`): the paths `player` may change on
  a fixable node, and the only paths a report-only node's
  `write_overrides` may name, each written exactly as there. A path is
  fixable on a node when the node's policy is `fixable`, or it equals an
  override, or it lies under an overridden directory. `/home/player`
  stays writable under every policy.
- **Seed paths** (`seed.paths`): every `seed.files` entry mapped to its
  live in-container path, so a *fix* resolution of a seed-file fault can
  be checked against the policy of the file it changes. An entry ending
  in `/` (`builders/`) is a directory: optional in a scenario's
  `seed_files`, mapped to a folder of files there, and to a directory in
  `seed.paths`. `seed.modes` gives a seed file a config mode other than
  `"0444"` (the scheduler's `schedule.yaml`, `"0400"`).
- **Report tools** (`report_tools`, optional): the report generators
  players run on the node (`pgbadger` on `postgres`); a fault's evidence
  may name `report:<tool>` only for one of the target brick's.
- **Snapshot** (`snapshot:`, optional): per volume, how the hand-over
  snapshot copies it: `pg_basebackup` (the database's data, online; at
  most one per brick, which then ships `gm-snapshot-db`), `copy` (a plain
  copy while the node runs, for seeded, append-only or whole-file-rewritten
  files) or `stop` (a brief s6 stop of the brick's services, never a
  Swarm scale to zero). When present it names every volume but the one at
  `/run`, once; absent, every volume but `/run` is copied by `stop`. `/run`
  is never copied.
- **No fault list**: `brick.yaml` names no fault; which faults a brick
  hosts is stated only by each fault's `applies_to` (D59).
- **Interfaces**: `provides` and `consumes`, each entry with `name`,
  `protocol` and `port`. A provided interface with `web_path` is a web
  interface the bastion's web front publishes, at `/<route>/`, its fixed
  path.
- **Parameters**: a scalar unless `shape` says `node-map` (node name to
  `default` or a list of the node's brick's `processes`) or `web-routes`
  (route name to `"node:port"`).
- **Secrets**: each with its `kind`, `password` (with `handed_over: true`
  for one players type) or `key-pair` (with its `pair` and the `half`,
  `private` or `public`, mounted), and optionally `only_with_role`
  (generated and mounted only when a node of the topology has that role).
  A name two bricks declare is one secret and both declare it alike
  (`kind`, `handed_over`, `pair`, `half`).
- **Mounted companion material** (`companion.mounted`), for each item: its
  `files` (each `source` under `companion/`, an absolute `target` in the
  receiving node, a `mode` with no write bit: root-owned, read-only); the
  `parameter` listing the receiving nodes (a `node-map` parameter of this
  brick, set on its own node in the scenario); the `node_config` the
  renderer writes per node; the `footprint` it adds to each receiving
  node; what a receiving image must provide (`requires`: an s6-overlay
  version prefix and the commands used, by name).
- **Receiving bricks** (`receives`): an image that accepts mounted
  material declares the s6-overlay version its Dockerfile installs and
  the commands available, from the vocabulary in the template; its
  `docs/gm.md` says so under Connections. A topology is refused when a
  receiving node's brick does not meet the `requires` of the mounting
  brick's pinned version.

`docs/gm.md` (D56; `specs/formats.md`, "`docs/gm.md` must contain";
template [templates/brick-gm.md](templates/brick-gm.md)) has one level-2
heading per required section, with these exact names, in this order:
`## Purpose`, `## Placement`, `## Configuration`, `## Connections`,
`## Access`, `## Footprint`, `## Supported faults`, `## Checks`,
`## Known limits`. A brick may add its own sections, as subsections of a
required one or after `## Known limits`. Refuse the brick, and so every
scenario that uses it, when:

- one of the nine headings is missing, renamed or out of order;
- one of them is empty (a section that does not apply says so in a
  sentence, with the reason);
- it disagrees with `brick.yaml`: a parameter, knob, interface or
  footprint figure that does not match the declaration, or one that
  `brick.yaml` lacks (footprint: limits and reservations, D84, and the
  growth per hour); the write policies (and, under report-only, what
  `write_overrides` may make fixable) belong under Access, and the
  snapshot methods, with the brief stop where the brick has one, in a
  level-3 `### Snapshot` under Footprint (capture W1 item 5);
- it disagrees with the faults' `applies_to` (D59, D62): a fault listed as
  supported whose `applies_to` does not name this brick and version, or a
  **catalog** fault whose `applies_to` does that is not listed (a fault
  in a scenario's own `faults/` is the scenario's and is not listed);
- it states placement or connections in a platform's own syntax rather
  than as requirements (one per node, on the same host as a given node,
  sharing a network with it).

### Fault (master spec 8)

Every key of [templates/fault.yaml](templates/fault.yaml), with
`seed_changes` for a seed-file fault, `scripts` for a state fault and
`parameter_changes` for a parameter fault, and an `acceptance` entry for
each kind in `resolutions`; and the folder: `inject/` (when it has
material), `checks/fixed.sh`, `checks/probe.md`, `gm.md`. Scripts follow
the contracts in [templates/layouts.md](templates/layouts.md). In
particular (v0.2 master spec 6.4, v0.3 master spec 6.3 and 6.5):

- **Aging** (`aging:`): the technique, `real-time` (the only one in
  v0.3), and the minimum duration before the evidence shows under the
  load (`0m` when it shows at once), a duration `<integer><s|m|h|d>`. It
  is counted only in a scenario with scheduler nodes (master spec 8,
  D160).
- **Evidence locations**: each entry's `where` is `node` (a shell on the
  fault's target node), `bastion` (a shell on the bastion, `psql` from
  there included) or `report:<tool>` (`<tool>` one of the target brick's
  `report_tools`), and its `source` names the file, view or output looked
  at (v0.2's free text). A fault never names `ui:<name>` nor
  `node:<name>`: a reading through a web interface, or on a node other
  than the target, is the scenario's, and its answer key carries it.
- **Sealed checks** exit 0 (fixed), 1 (present), 3 (too soon to tell, the
  remaining window on the first output line) or any other code (error).
  A check judging behaviour over a window sets
  `sealed_check.behavioural: true`; the answer key then gives each
  instance's `window` and `threshold`. A check that queries PostgreSQL
  connects as the GM check role `gm_check`, inside the GM's reserve,
  through `postgres`' root-only `check-psql` helper (master spec 6.5,
  capture W1 item 8); never as `dba` or an application role.
- **Faults in a scheduler's files** are `seed-file` faults whose
  `seed_changes` edit `queries.yaml`, `jobs.yaml` or `schedule.yaml`, at
  render.

- **`applies_to`** lists each brick's versions one by one, as exact
  strings (`["0.1.0", "0.1.1", "0.2.0"]`), never a range: a fault never
  claims a brick version nobody tried it on.
- **Parameter faults** (`injection.kind: parameter`, `stage: seed`): a
  change to a parameter of the target node, applied by the renderer when
  it writes the local implementation. Each `parameter_changes` entry names
  a parameter of the target node's brick and an `op`: `set` (with
  `value`), `remove-entry` (with `entry`, the map key) or
  `remove-from-entry` (with `entry` and `item`; a `default` entry is first
  expanded to the brick's `processes`). `{NAME}` in `entry`, `item` or
  `value` is replaced by the instance's fault parameter `NAME`.
- **Faults about mounted material** (a `parameter_changes` entry naming a
  `companion.mounted` item's `parameter`) target the node of the brick
  that ships the material, name only that brick in `applies_to`, and have
  a required parameter `node` naming the affected node. For the
  node-health script: the `prometheus` node, through its `node_health`
  map (a node left out, or a service left out of a node's entry).

## Versions and pins (v0.2 master spec 6.5, v0.3 master spec 6.6)

- **Bricks.** Any change to a brick bumps its version, whatever part of
  its folder changes (image, `brick.yaml`, validator, documentation,
  companion material), even with a byte-identical image. A change made
  while the new version is unreleased folds into it. A brick version is
  released only when the release gate of the version that builds it
  passes; a build wave merging into `main` releases nothing (D100). New
  bricks start at 0.1.0.
- **One version per brick in the catalog.** The scripts refuse a pin that
  does not match the brick's `version`, so bumping a brick re-pins every
  scenario and fixture that uses it in the same change, adds the new
  version to the `applies_to` of every fault that still applies, and
  brings its `docs/gm.md` (image tag, Supported faults) to the new
  version.
- **Faults and scenarios never bump.** They keep their version whatever
  changes; git history is the record. A pin to a fault names the fault,
  not a state of it; nothing pins a scenario.
- **Companion material** has no version of its own: it is versioned with
  the brick that ships it (the node-health script with `prometheus`).
