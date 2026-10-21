---
name: scenario-format
description: Use whenever a db_audit_gm scenario, brick or fault definition is designed, generated, edited or checked for completeness — writing scenario.yaml, gm/answer-key.yaml, brick.yaml or fault.yaml, laying out their folders, or deciding whether a scenario is complete enough to deploy. Start from the templates, fill every required item, flag every missing one; the GM refuses to deploy an incomplete scenario.
---

# Scenario format

Every scenario, brick and fault is written to one shape. This skill holds
that shape: five templates and the folder layouts. This is its **v0.2
version**, expected to evolve as games are played; when a game shows the
format is missing something, change the template and this skill together.

Source of the shape: v0.1's master spec (`specs/versions/v0.1/master-spec.md`,
sections 6, 7, 8 and 8.1) and v0.2's format changes
(`specs/versions/v0.2/master-spec.md`, section 6), with `specs/formats.md`.
The top-level keys of `brick.yaml` are fixed (capture W1-A in
`specs/versions/v0.1/wave-log.md`); v0.2's keys are capture W1 in
`specs/versions/v0.2/wave-log.md`.

## Templates

| Template | Becomes | Shape of |
|---|---|---|
| [templates/scenario.yaml](templates/scenario.yaml) | `scenarios/<id>/scenario.yaml` | the scenario manifest (authoritative) |
| [templates/answer-key.yaml](templates/answer-key.yaml) | `scenarios/<id>/gm/answer-key.yaml` | the answer key (authoritative, sealed) |
| [templates/brick.yaml](templates/brick.yaml) | `bricks/<id>/brick.yaml` | a brick definition |
| [templates/fault.yaml](templates/fault.yaml) | `faults/<id>/fault.yaml` | a fault definition |
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

### Scenario (master spec 6.2)

- **Scenario information**: `id`, `version`, `title`, `date`, `origin`,
  `session_length_minutes` (at most 240), `brief` and `brief.md`.
- **Topology**: `networks`; for every node: `name`, `brick` (id, pinned
  version), `role`, `stateful`, `networks`, `write_policy`, `parameters`,
  `resources` (limits and reservations, disk included), `published_ports`,
  `seed_files`, `knobs` (initial value and envelope for every knob the
  brick declares), and `data` (file and schema) for a node holding data;
  `flows` (every flow between nodes).
- **Background**: `background`, and `player/story.md`.
- **Incidents, flaws and defects**: `fault_instances` (fault id and pinned
  version, `node`, `parameters`, `visibility`); `issues` (zero or more,
  each with `id`, `complaint`, `expected_resolution`, `covers`).
- **Answer key** (`gm/answer-key.yaml`), for every fault instance: `what`,
  `why`, `evidence` as `player`, `acceptable` (diagnosis, and proposal,
  fix or improvement as they apply), `sealed_check`, `interactions`,
  `validators_left_red`; and `gm/notes.md`.
- **Host topology it was designed for**: `designed_for` (platform, hosts
  with CPU, memory, disk, placement of every node).
- **Starter pack** (`player/README.md`, `story.md`, `issues.md`), **node
  files** (`nodes/<node>/`), **restored-backup data** (`data/<node>.sql`).
- **Scenario document** (`README.md`), generated, opening with the "do not
  read" warning.

Consistency rules (a failure is a missing item):

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
  id exists;
- an issue's `expected_resolution` is one the covered faults list, under a
  write policy the target node has;
- `gm/answer-key.yaml` has exactly one entry per fault instance;
- `player/issues.md` states the same issues as `issues`; nothing under
  `player/` names a hidden fault or an answer;
- `designed_for.placement` places every node, and the summed reservations
  fit the hosts.

### Brick (master spec 7)

Every key of [templates/brick.yaml](templates/brick.yaml) except the
commented-out ones; and the folder: `Dockerfile`, `validator/`,
`docs/player.md`, `docs/gm.md`, and `companion/` when `companion` is set.
The image name is registry-qualified; the brick names no Swarm-only
feature. In particular (v0.2 master spec 6.1):

- **Footprint**: the shape of a scenario node's `resources`, `limits`
  (`cpu`, `memory`) and `reservations` (`cpu`, `memory`, `disk`), the
  default the GM starts from when it sizes a scenario. It excludes any
  material other bricks mount into this one.
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
  `private` or `public`, mounted). A name two bricks declare is one
  secret and both declare it alike.
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
  `brick.yaml` lacks (footprint: limits and reservations, D84);
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
the contracts in [templates/layouts.md](templates/layouts.md); in
particular a sealed check run as root queries PostgreSQL as `postgres`
(`runuser -u postgres`, or exec as `postgres`) so that peer
authentication applies. In particular (v0.2 master spec 6.4):

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
- A fault's own `evidence[].where` stays v0.1's free text; the answer
  key's evidence is the one split into `where` and `source`.

## Versions and pins (v0.2 master spec 6.5)

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
