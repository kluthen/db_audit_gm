---
name: scenario-format
description: Use whenever a db_audit_gm scenario, brick or fault definition is designed, generated, edited or checked for completeness — writing scenario.yaml, gm/answer-key.yaml, brick.yaml or fault.yaml, laying out their folders, or deciding whether a scenario is complete enough to deploy. Start from the templates, fill every required item, flag every missing one; the GM refuses to deploy an incomplete scenario.
---

# Scenario format

Every scenario, brick and fault is written to one shape. This skill holds
that shape: five templates and the folder layouts. It is the **initial
version (v0.1)** and is expected to evolve as games are played; when a
game shows the format is missing something, change the template and this
skill together.

Source of the shape: the master spec (`specs/versions/v0.1/master-spec.md`,
sections 6, 7, 8 and 8.1). The top-level keys of `brick.yaml` are fixed
(capture W1-A in `specs/versions/v0.1/wave-log.md`).

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
feature.

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
  `brick.yaml` lacks (footprint: O57);
- it disagrees with the faults' `applies_to` (D59): a fault listed as
  supported whose `applies_to` does not name this brick and version, or a
  fault whose `applies_to` does that is not listed;
- it states placement or connections in a platform's own syntax rather
  than as requirements (one per node, on the same host as a given node,
  sharing a network with it).

### Fault (master spec 8)

Every key of [templates/fault.yaml](templates/fault.yaml), with
`seed_changes` for a seed-file fault and `scripts` for a state fault, and
an `acceptance` entry for each kind in `resolutions`; and the folder:
`inject/` (when it has material), `checks/fixed.sh`, `checks/probe.md`,
`gm.md`. Scripts follow the contracts in
[templates/layouts.md](templates/layouts.md); in particular a sealed check
run as root queries PostgreSQL as `postgres` (`runuser -u postgres`, or
exec as `postgres`) so that peer authentication applies.
