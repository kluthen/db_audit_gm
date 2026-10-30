# Formats: scenario, brick, fault

Status: draft v22

What a scenario, a brick, a fault definition and, from v0.4, a purpose
and a domain must contain, and how they are laid out, so that every scenario the GM designs or generates stays
within known boundaries. The rules these formats carry (the solvability
probe, per-brick checks, fault families) are in
[bricks-and-faults.md](bricks-and-faults.md); access and validator rules
in [planes-and-access.md](planes-and-access.md).

This page states what each format must contain. The YAML shapes of the
fields v0.3 adds (`aging:`, `difficulty:`, `plant_at`, `write_overrides`,
`snapshot:`, and a scheduler's `queries.yaml`, `schedule.yaml` and
`jobs.yaml`) are in the
[v0.3 master spec](versions/v0.3/master-spec.md), sections 6.7 and 7.1,
normative until the format skill's templates carry them (D151). Those
v0.4 adds (`purposes:`, `domain:`, `governance:`, `crontab_roles`,
`judges`, `needs_unshared_host`, `seed.optional`, `applies_to.purposes`)
are in the [v0.4 master spec](versions/v0.4/master-spec.md), section 6.9,
normative likewise (D215).

## Enforcement

Skills backed by templates enforce the formats:

- **The format skill** (D5): a template each for the scenario (manifest
  and answer key), the brick and the fault definition, from v0.4 the
  purpose and the domain (D215), and one skill the GM
  uses whenever it designs, generates or edits any of them. It starts from
  the template, fills every required item, and flags any that is missing;
  the GM refuses to deploy an incomplete scenario (D40).
- **The scenario-document skill** (D20): the GM's own skill and template for
  the scenario document (see below). The template's detailed shape is that
  skill's; what a scenario must contain is stated here.

Initial versions of both are in v0.1's scope, and both are expected to
evolve as games are played (D21). This document states what the format
skill must encode. Machine checks are per brick, not project-wide (D28);
whether the format skill itself also runs a schema check is part of the
reading to confirm under O20. As built in v0.1, the scripts check a
scenario, and the bricks and faults it uses, against the templates
whenever they load it, and refuse an incomplete one (D40); the format
skill's own check is by reading. The skills live in `.claude/skills/`,
which both Claude Code and opencode read (D29). A third skill, the GM skill,
runs the game itself ([gm-stance.md](gm-stance.md), D33).

The file names and layouts below are settled (D42). YAML for structured
content, Markdown for prose.

## Scenario

A scenario is a **self-sufficient folder** and the source of truth (D23).
With the full repository and the GM persona and skills, the folder is
enough to start the exercise: after a session restart, on another
playground, or months later. Scenarios are kept in this repository, in
bulk (D13).

The folder does not contain the shared bricks (D24). Bricks and fault
definitions shared across scenarios live in the catalog, and the scenario
references them by id and pinned version ("Versions and pins" below). A
brick or fault made solely for one scenario may live inside that
scenario's folder.

### What a scenario must contain

The owner's requirements (D23), with the earlier rulings that apply:

- **Scenario information**: id, version, title, date, origin (from a brief,
  partly or wholly, or GM-designed), session length (at most 4 hours), and
  the initiator's inputs as given.
- **A clear topology**: every node with its brick and version, its role, the
  parameters it is given, whether it is stateful, its networks and write
  policy, and its knobs' initial values (which may lie outside the
  envelope) with the envelope, tightened from the brick's default if
  needed (D32); from v0.3, its write overrides: paths among the brick's
  writable paths made fixable on a report-only node, a fault's *fix*
  resolution then needing the policy of the file it lives in (D130,
  D143); a scheduler node's seed files (`queries.yaml`, `builders/`,
  `jobs.yaml`, `schedule.yaml`; D115), from v0.4 also `scripts/`, the
  transformer scripts (D203); from v0.4, several `postgres` nodes, each an
  instance of its own with its own seed and data file (D202), every
  scheduler node on `scheduler` 0.2.0, and a `postgres` node's cron
  daemon, on when the node seeds a `crontab`, the node then naming in
  `crontab_roles` the customer roles its crontab connects as, whose
  password secrets deployment mounts into it (D206, D215); every flow between nodes (what moves, how, cadence;
  monitoring and backup relations included); the data schema each database
  holds, or what produces it.
- **Purposes, domain and governance** (from v0.4, D190–D192, D215):
  `purposes:`, each purpose used by id, its parts mapped to the
  scenario's nodes and databases ("Purpose definition" below), the loader
  checking every part is mapped and every job's key and name exist on
  the mapped runner; `domain:`, the domain the scenario's business comes
  from, for provenance only, none in a static scenario ("Domain" below);
  `governance:`, the policy file and, for each data class, its locations
  (`node/database`, with `separation: instance` when the policy demands
  an instance of its own), its readers (customer roles) and its outbound
  flows with their allowed fields, the loader checking every class named
  is defined, every location names a `database` node and a database its
  data file creates, every reader is a role a data file creates, and
  the policy file exists.
- **Background information**: the customer's story and context.
- **Incidents, flaws and defects**: every fault instance (fault definition
  and version, target nodes, parameters, known or hidden; from v0.3 its
  planting moment, `T0` by default or, for a `state` fault only, a moment
  before hand-over written relative to it, within the scenario's aging
  minimum and never at or after hand-over (D127, D151), and its aging
  minimum when it needs more than its definition's),
  and the issues given to the players, zero or more, each with its expected
  resolution (*report*, *propose*, *fix*, *improve*) and the faults it
  covers (D9);
  the aging plan: none in v0.1 or v0.2; from v0.3, in a scenario with
  scheduler nodes, a required `aging:` block with the aging minimum, at
  least eight hours and as long as the scenario's evidence needs, and the
  hand-over time of day the scenario was designed for, in scenario time
  (D114, D129, D150). A scenario with no scheduler node has no aging
  (D157) and omits `aging:`, which the loader refuses there, as it
  refuses a planting moment other than T0, an instance's aging minimum
  and the customer's time zone placeholder, none of which means anything
  without an aging or a shift; its fault definitions' aging minima,
  times under the load, are not counted, and `render --handover` is
  optional for it (D158); and its
  difficulty score, the number of fault instances, checked by the
  loader, with optionally the level it targets (D120, D134). An issue may also cover a
  tooling expectation, which is not a fault (D65, D76).
- **The answer key**, for every fault instance: what is wrong and why, the
  evidence as the player user and where it is run (a required `where`
  from v0.2: `bastion`, `node:<name>`, `ui:<name>`, `report:<tool>`;
  D81), with the file, view or output looked at under a required
  `source`, which held v0.1's free-text `where` (D101), what counts as an
  acceptable diagnosis, fix, improvement or recommendation, the sealed
  check, interactions with other faults, any validator the player cannot make green (D10), and, once
  solvability probes exist, their results. From v0.3 a behavioural
  sealed check (one judging behaviour over time, not a cause) states its
  window and threshold (D124). From v0.4 a sealed check judging a
  purpose's runs or triggers states `judges: runs` or `judges: triggers`
  and a `threshold` (violations tolerated, 0 by default), and no window
  (D215). The GM's silent tooling
  expectations (D65) are a list of their own, outside the fault
  instances: each says what is expected and what is acceptable (any of
  the research's top three tools for a need, say), has no sealed check,
  and is judged in feedback (D76); from v0.4 one may name an unmonitored
  instance (D215).
- **The host topology it was designed for**: the platform (Swarm,
  Kubernetes…), the hosts, their capacity (CPU, RAM, disk), and the
  resource limits, reservations and placement the scenario was sized with.
  This is the reference the local implementation adapts from.
- **The starter pack** shipped to the bastion: topology documentation,
  node names, rules and DO NOT TAMPER list, the story, the issues. From
  v0.3 the story and the starter pack name the customer's time zone
  through a placeholder render fills from the shift, never a fixed zone
  (D129, D151), a scenario with no scheduler node having neither shift
  nor placeholder, its times UTC (D158); and a scenario's Prometheus
  retention covers its aging minimum (none without an aging) plus four
  hours by time unless a planted fault is about
  retention, which the loader checks, a size bound staying above the
  measured growth (D140, D151). From v0.4, a scenario with `governance:`
  hands the players the company's data policy, `player/data-policy.md`
  (D191, D215).
- **The files each node needs**, delivered as Swarm configs (D11).
- **The scenario document**, generated with the GM's scenario-document
  skill (D20), opening with a prominent warning that students and players
  should not read it. Enforcement goes no further (D13). The starter pack
  does not carry the warning; repeating it at the top of the other GM-side
  files is (proposed).

A scenario is complete whatever the initiator sketched or left out at
setup: the GM fills the blanks (D16). Recording which items came from the
initiator and which the GM filled in is (proposed).

### Layout (D42)

The readable document and the machine files live together in the folder.
`scenario.yaml` and `gm/answer-key.yaml` are authoritative; the scenario
document (`README.md`) is generated from them by the scenario-document
skill (D40).

```
<scenario-id>/
  README.md           the scenario document (template: the GM's scenario-document skill)
  scenario.yaml       the machine-readable manifest: information, topology, defects, issues, host topology
  brief.md            the initiator's inputs as given (possibly partial or empty)
  player/             the starter pack, shipped to the bastion
    README.md         topology, node names, rules and DO NOT TAMPER list
    story.md          the customer's background
    issues.md         the issues given, each with its expected resolution (may be empty)
    data-policy.md    from v0.4, with `governance:`: the company's data policy
  gm/                 sealed: never shipped to any node
    answer-key.yaml
    notes.md          explanations the GM draws on for feedback
  nodes/<node>/       files per node, delivered as Swarm configs (D11)
  data/<node>.sql     restored-backup data, streamed into the node through the injection path (D39)
  bricks/, faults/    bricks and faults made solely for this scenario, if any (D24)
  local/<playground>/ local implementations, one per playground, git-ignored (D40)
```

## Local implementation

At deployment the GM generates a **local implementation** of the scenario
for the real playground (D23). It maps the playground's true resources onto
what the scenario expects:

- resource limits and reservations per node, placement and pinning, and the
  number of hosts used (one in v0.1 and v0.2, D35; from v0.3 nodes are
  placed on the playground's declared hosts and rendered as hostname
  constraints, the bastion pinned to its own host, and the images copied
  to each host over SSH, with no registry, D128, D149);
- from v0.3, the planned hand-over and the shift in whole hours mapping
  scenario time onto UTC, T0, the aging minimum, the outages and the
  lost time (D152), the earliest hand-over and the hand-over, the game's seed, the
  scheduled setup actions and their results, the early and hand-over
  checks' results, the hand-over snapshot's location, and each restart
  (old and new game ids, time, from the snapshot or not, the player's
  confirmation) (D126, D129, D136, D141, D151);
- the game id, which names every volume, config, secret and network of the
  game, so a redeploy never reuses a player-edited volume (D36); each
  network the scenario declares renders as one network named
  `<game_id>_<network name>` (D85; v0.1 rendered one `<game_id>_net`);
- the rendered platform files: the Swarm stack file today, Kubernetes
  manifests later. They are always rendered, never written by hand (D22).

In v0.1 the scenario's resource limits and envelopes are absolute: the
local implementation only checks that they fit the playground and never
recomputes them, since recomputing could turn a planted out-of-bounds
value into an in-bounds one (D32).

The GM adapts the scenario to the playground as long as capacity is
sufficient. If it is not, the GM says so and does not deploy (D23). The
scenario itself is not changed by a new playground; only a new local
implementation is generated.

Where it lives (D42): in `local/<playground>/` inside the scenario folder.
It is kept out of version control (D40), because it describes one particular
set of machines. It never holds host access keys; it does keep the game's
own credentials in `secrets/` (mode 0600), so a restarted GM can hand them
over again (D45). Besides the mapping and the rendered files, it records the
playground as declared at setup (platform, hosts, capacity) and the current
game's id and progress (stage reached, including where a failed setup
stopped, D36), so a restarted GM can find where it was.

## Brick definition

```
bricks/<brick-id>/
  brick.yaml
  Dockerfile         and its build context
  validator/         the public validator
  docs/player.md     what the player may read about this kind of node
  docs/gm.md         the GM documentation (required sections below), never shipped
  companion/         optional: the brick's own checks, scripts and tools (D28),
                     and material the GM mounts into other nodes (D89)
```

### `brick.yaml` must contain

Fields marked *optional in v0.1* have no use yet and may be left out
(D35).

- **Identity**: id, version ("Versions and pins" below), role(s),
  technology and engine version(s), image name(s).
- **Footprint** (D84): the shape of a scenario's `resources`, limits for
  CPU and memory and reservations for CPU, memory and disk, as the
  default the GM starts from when it sizes a scenario; `gmctl fit` and
  the renderer read the scenario's own `resources`. The v0.1 bricks' one
  figure per dimension takes this shape at their 0.2.0 (D72). The allowed
  range is *optional in v0.1*.
- **Interfaces**: what the brick *provides* (e.g. a PostgreSQL SQL endpoint
  on a port) and what it *consumes* (e.g. an upstream SQL endpoint, a
  queue). Flows in a scenario connect a consumer interface to a matching
  provider; this is what lets a pipeline be checked. *Optional in v0.1.*
- **Parameters** the scenario sets (upstream node, schema, load rate…).
- **Knobs**: setting, file, default, and default envelope; a scenario may
  tighten the envelope (D32).
- **Write policy options** it supports (*fixable*, *report-only*).
  `postgres` supports *fixable* only, from v0.4 too: a database node
  another party owns in the story is report-only by the story and the
  answer key alone (D211).
- **Writable paths** (what the player may change; from v0.3 also the
  paths a scenario's write overrides may name, D143) and **protected
  files**.
- **Snapshot** (from v0.3, D142, D147): per volume, how it is copied at
  hand-over: `pg_basebackup` for a database's data, `copy` (a plain copy
  while the node runs) for a volume holding only seeded, append-only or
  whole-file-rewritten files, or `stop`, a brief stop of the brick's
  service inside its running container (s6, never a Swarm scale to zero)
  while the volume is copied. Prometheus and Grafana use `stop`. A volume
  the brick empties at every start is not copied; a brick that declares
  nothing gets `stop`. The footprint's disk includes the volumes' growth
  over an aging and a four-hour game, as measured, per hour.
- **Player access**: the SSH account, its group, its `sudo` wrappers.
- **Capabilities** it adds back after dropping all (D41).
- **Monitoring exposure**: metrics endpoints, logs, what monitoring bricks
  can collect. *Optional in v0.1.*
- **Health check**: a command run inside the container.
- **Secrets** it needs, and the fixed paths where it reads them and its
  seed files. Every seed file a brick declares is required of every node
  using it, except those it lists under `seed.optional` (from v0.4;
  `postgres`' `crontab` the first, D206, D215).
- **Processes** run under s6-overlay (D30).
- **Companion material**, if any (see below).

**Companion material** (D28, D42). A brick may ship extra information,
scripts or tools that help its integration and use: its own lint or
checks, helpers for the GM (seeding, state injection, inspection), notes on
combining it with other bricks. Machine checks are per brick: whether a
brick has any depends on the brick. Such material lives in the brick's
`companion/` folder, and `brick.yaml` says what it provides and when the GM
should use it.

**Companion material mounted into other nodes** (D88, D89, D97). Some
companion material does not stay with the brick's own node: the GM
mounts it into other nodes of the topology at deploy, as configs, as
`prometheus` does with the node-health script. For each such item,
`brick.yaml`'s companion declaration states:

- the files, and for each its target path and mode in the receiving
  node (root-owned and read-only there, so a protected file);
- which nodes receive it: those the brick's parameter for it lists;
- the parameter that configures it per node, set on the brick's own
  node in the scenario;
- what it adds to each receiving node's footprint;
- what a receiving image must provide (for the node-health script:
  s6-overlay v3 and the commands the script uses, by name).

For the node-health script the parameter is a map from node name to that
node's entry, and it is explicit (D97): whenever the topology has a
`prometheus` node, the map is required and lists every node of the
topology, `prometheus`'s own included; an entry is either a list of
services or `default`, which stands for that node's brick's s6
`processes`. The format skill and the loader refuse a missing map or a
node missing from it. In the scenario the map is always complete: a node
left out exists only as a fault planted through the parameter (D92).
The renderer writes each node's entry, with the node's declared disk
reservation (D96), into that node's own config.

A receiving brick declares in `brick.yaml` what it provides to mounted
material (its s6-overlay version, the commands available), and its
`docs/gm.md` says so under Connections (D97). The loader checks each
receiving node's declaration against the requirements of the mounting
brick's pinned version and refuses a topology where one is not met.

Footprints do not double count (D97): a brick's own `brick.yaml`
footprint excludes material other bricks mount into it; the mounting
brick's `docs/gm.md` states what that material adds per node, and the
GM adds it to each receiving node's `resources` in the scenario.

The renderer adds the configs to every receiving node's service, so the
material changes no image and no other brick's folder, and bumps only the
brick that ships it (D57). A fault about it targets the mounting brick's
node, names only that brick in `applies_to`, and takes the affected node
as a parameter (D92).

**Platform-neutral bricks** (D22, D42). A brick definition names no
Swarm-only feature, so the same brick runs under Kubernetes:

- seeds and secrets are read from fixed paths inside the container,
  declared in the brick, never from Swarm's default mount locations;
- the health check is a command run inside the container;
- interfaces are container ports; publishing ports on hosts is the
  renderer's business, and no brick relies on the routing mesh;
- a brick says whether it is stateful; how it gets pinned (placement
  constraints, a StatefulSet) is the renderer's business;
- peers are reached by node name only, never `tasks.<service>`;
- hardening needs (read-only root, capabilities, `sudo` wrappers) are
  declared in the brick and mapped by the renderer to each platform's
  settings.

### `docs/gm.md` must contain (D56)

The GM documentation tells the GM how to use the brick in a scenario: what
to install where, how to configure it and wire it to the other bricks, what
it costs, which faults it can host and how to check it. `brick.yaml`
declares; `docs/gm.md` explains. It holds spoilers and is never shipped to
the player side.

The rule applies from v0.2. Every brick added from v0.2 on meets it, and
the two v0.1 bricks (`postgres`, `bastion`) are brought up to it within
v0.2; that change bumps their version, to 0.1.1 (D57). The format skill
refuses a brick whose `docs/gm.md` lacks one of the required
sections, so the GM refuses to deploy a scenario that uses it (D40).

Rules for the whole file:

- One level-2 heading per required section, with the exact names below,
  in this order. A brick may add its own sections, as subsections of a
  required one or after the last.
- No required section is empty. One that does not apply says so in a
  sentence, with the reason (a brick that consumes nothing says so under
  Connections).
- It agrees with `brick.yaml`: every parameter, knob, interface or
  footprint figure it mentions matches the declaration, and it introduces
  none that `brick.yaml` lacks.
- It agrees with the catalog faults' `applies_to` (D59, D62): every fault
  it lists as supported names this brick and version in its `applies_to`,
  and every catalog fault that does is listed.
- A disagreement with either is a defect of the brick.
- Placement and connections are stated as requirements (one per node,
  on the same host as a given node, sharing a network with it), never in a
  platform's own syntax ("Platform-neutral bricks" above).

The required sections:

1. **Purpose**: what the brick is (technology, engine or tool version,
   image), the role or roles it fills in a scenario, and when the GM
   picks it.
2. **Placement**: what gets installed (a node of its own from the brick's
   image, and any companion material the GM mounts into other nodes at
   deploy, such as `prometheus`'s node-health script, D88, D89), how to
   build it, how many per scenario (one per scenario, one per node, one per
   node of a given brick), next to which node (same host as a given node,
   or any host), whether it is stateful, and which networks it joins.
3. **Configuration**: every parameter the scenario sets and every value
   the GM sets per scenario or per node at initialisation (the per-node
   values of mounted companion material included, D89), each with its
   meaning, default, valid values and where it lands (seed file, secret,
   fixed path); the knobs and their default envelopes; the secrets and seed
   files and what they must contain; and what start-up does (what is seeded
   once, what is rewritten at each start).
4. **Connections**: for each interface it provides or consumes, the bricks
   on the other side, the port and protocol, what the GM wires and where (a
   scrape target, an exporter's connection, a datasource, a dashboard), the
   account or role the other side must provide and which parameter supplies
   it, and what must exist before the wiring works; what it exposes to
   monitoring bricks (metrics endpoints, logs); and whether its image
   accepts another brick's mounted companion material, such as the
   node-health script (D89).
5. **Access**: how the player reaches it (account, group, `sudo` wrappers,
   any web interface and the path to it through the bastion), its writable
   and protected paths, the write policies it supports, the capabilities it
   adds back and why each is needed, and what the GM itself uses to operate
   it.
6. **Footprint**: the default CPU, memory and disk, limits and
   reservations, as `brick.yaml` declares them (D84);
   what makes it grow (nodes watched, scrape targets, retention, log
   volume, data size) and how the GM sizes it for the capacity check;
   what its mounted companion material adds to each node it lands on
   (D89); and the levers that shrink it.
7. **Supported faults**: the catalog fault definitions (`faults/`) whose
   `applies_to` names this brick and version (D59), and what each needs
   from it (a parameter, a peer, aging). Catalog faults only: a fault
   defined in a scenario's own `faults/` folder belongs to that scenario
   and is not listed (D62). Then the faults it lends itself to that have no
   definition yet; its known interactions (a monitoring brick that can
   mask a fault elsewhere, a fault elsewhere it would reveal); and, where
   not obvious, the faults it cannot host and why.
8. **Checks**: its validator (what it checks; it may be red from the
   start), its health check, its companion checks and when the GM runs
   them, how the GM confirms after deployment that it works and is wired
   (every scrape target up, the exporter connected), and its stack test if
   it has one.
9. **Known limits**: what it does not do, or does surprisingly, in this
   version; "none known" when so.

## Fault definition

Faults live beside the bricks rather than inside one, because a fault can
span several bricks (a collector pointed at the standby touches the
monitoring brick and the database brick).

```
faults/<fault-id>/
  fault.yaml
  inject/            material that plants the fault, when it has any
  checks/            solvability probe and sealed fix check
  gm.md              explanation the GM uses for feedback
```

### `fault.yaml` must contain

- **Identity**: id, version, title, family, severity. From v0.4, purpose
  faults are `data-flow` (duplicates, dropped records) or `rules` (a
  wrong zone, a wrong segment); governance and credential faults join
  `security`, with `governance-*` and `security-*` ids (D215).
- **Applies to**: brick ids and, for each, the brick versions the fault
  applies to, plus topology preconditions (e.g. needs a standby, needs a
  scheduled job). This is the only statement of which faults a brick
  hosts (D59). Versions are listed one by one, never as ranges (D86), so
  each brick bump adds its version to every fault that still applies.
  From v0.4, `applies_to.purposes` names the purposes a fault attaches to,
  beside `bricks:`, and a purpose fault also lists the `scheduler`
  versions its runner needs, since its sealed check runs there (D215).
- **Parameters** the scenario sets (which table, which job…).
- **Injection**: how it is planted, and at which stage. Kinds: a change
  to a node's seed configuration; a change to a parameter of the target
  node, applied when the local implementation is rendered (D92: for
  example leaving the affected node out of the node-health map, or a
  service out of its entry); a state change run in the node by the GM;
  an aging step. State changes are idempotent POSIX shell scripts
  streamed over stdin, so they run the same through `docker exec` or
  `kubectl exec` (D22). Their interface is in "Script contracts" below.
  In the format these kinds are `seed-file` (with `seed_changes`),
  `parameter` and `state`; from v0.3 only a `state` fault may be planted
  later than T0, the other two being planted at render (D151). From
  v0.4 a purpose fault is planted as these are: a `seed-file` change (a
  runner's `queries.yaml`, a script, `jobs.yaml`, a database node's data
  file, `postgresql.conf` or `crontab`), a `state` change during the
  aging, or a timeline change of a schedule for an outside party's
  behaviour, which the definition states and the scenario writes (D215).
- **Evidence paths** as the player user. From v0.3 each evidence's
  free text is its `source`, and its `where` is `node` (the fault's
  target node), `bastion`, or `report:<tool>` for a tool the target's
  brick ships; never `ui:<name>`, whose routes only the scenario knows
  and which the answer key adds (D140, D145). And the **aging** technique
  (`real-time`, the only one from v0.3, D114) and
  minimum duration that make them visible. From v0.4, a fault whose
  evidence shows at a job's runs counts its aging minimum from that job's
  first run after planting, as v0.3's time-of-day faults do (D189, D215).
- **Solvability probe**: what it runs as the player user and what it
  expects. Descriptive only in v0.1; a manual play-through checks it
  (D38).
- **Possible resolutions**: which of *report*, *propose*, *fix*, *improve*
  make sense, and which write policy each needs.
- **Acceptance criteria**: what counts as a correct diagnosis and as an
  acceptable fix or improvement.
- **Sealed fix check**. From v0.4 it states `sealed_check.judges`:
  `runs`, `triggers`, or absent for a check judging the live state
  (D215).
- **Host needs** (from v0.4): `needs_unshared_host: true` when the
  fault's node must never be placed on a shared host; `gmctl fit`
  refuses a mapping that does (D209, D215).
- **Interactions**: masks, masked by, conflicts with.
- **Complaint template**: how a customer would describe it, for when the
  fault is known.

*Known* or *hidden* is not part of the definition: it is chosen per
instance, in the scenario.

## Purpose definition (from v0.4)

A purpose is a catalogue unit beside bricks, faults and scenarios: what
some of the customer's data is *for* (D190, D215). Its jobs are run by a
scheduler node or a database node; faults attach to it as to bricks.

```
purposes/<purpose-id>/
  purpose.yaml   identity, parts, jobs, trace, invariants, data moved, roles
  material/      the jobs' repository entries, transformer scripts and
                 jobs.yaml lines, the target's DDL (foreign servers and
                 procedures included), as the GM copies them into a scenario
  checks/        one script per invariant
  gm.md          what the purpose is for, how it goes wrong, feedback notes
```

`purpose.yaml` must contain:

- **Identity**: id, title, the domains it fits, its kind (pulled,
  transformed in place, pushed, pushed obligation).
- **Parts**: the roles the scenario fills with its own nodes and
  databases: `source` and `target` (databases, of one instance or two),
  `runner` (a scheduler node, role `transformer`), optionally `consumer`
  (a scheduler node reading published results) and `receiver` (a stub
  node, for a pushed obligation).
- **Jobs**: for each, its name, its repository key, its runner, its
  source and target, its movement method, what it computes in one
  sentence, its cadence in scenario time, and the customer role of each
  connection it holds.
- **Trace**: each place it leaves something, with its kind (outbox rows,
  published results, run ledger, definitions), its table or file, and
  the column that ties a row to the run that wrote it.
- **Invariants**: for each, an id, a one-sentence statement against the
  source, the check script judging it, its parameters, and its witness
  condition (what must exist in the data for a run to be able to violate
  it).
- **Data moved**: which classed columns each job reads and where it
  writes them, so governance can be checked against it.
- **Customer roles** the purpose needs, with their grants.

The GM copies a purpose's material into the scenario at design time, as
it writes a scheduler's repository: the jobs into the runner's
`queries.yaml`, `scripts/` and `jobs.yaml`, the target's DDL into the
target node's data file. The scenario folder stays self-sufficient
(D23), and `purposes:` names the purpose for provenance and for the
faults attached to it.

## Domain (from v0.4)

A domain is a reusable catalogue unit of a business: its data model, its
producer material, its classification, its GM notes; the shop is the
first (D192, D215).

```
domains/<domain-id>/
  domain.yaml           identity, the parts below, the purposes that fit
  data/
    schema.sql          the business tables, roles and grants
    load.sql            the generated history ("last night's backup")
    classification.yaml every classed column
  producers/            the business's producer repository and schedule fragments
  docs/gm.md            the business, its rules, its traps
```

A domain is a design-time source: the GM copies its files into the
scenario, adapting them, and `scenario.yaml`'s `domain:` names it for
provenance. A static scenario needs none. `classification.yaml` classes
every column (`personal`, `customer-linked` or `internal`), a column with
no entry being `internal`; the scenario's `governance:` states the rules
for each class. How producer material meets a schedule, what a
scenario's size scales, and whether a domain may be composed of smaller
ones are v0.5's (O111, O113, O114, O126).

## Versions and pins (D57–D62, D72, D75, D86, D100)

A scenario pins every brick and fault it uses by id and version: each
node's brick, each fault instance's fault definition. The scripts refuse a
pin that does not match the definition's `version`.

- **Bricks.** Any change to a brick bumps its version, whatever part of
  its folder the change touches: the image and its build context,
  `brick.yaml`, the validator, the documentation (`docs/player.md`,
  `docs/gm.md`) or the companion material. That includes a change that
  leaves the image byte-identical (D57, D58). A change made while a
  brick's new version is still unreleased folds into that version with no
  further bump (D61). A brick version is released when the release gate
  of the version that builds it passes; a build wave merging into `main`
  releases nothing (D100). New bricks
  start at 0.1.0 (from v0.3, `scheduler` and `pgbouncer`; `postgres` and
  `bastion` then take 0.3.0, the monitoring bricks 0.2.0); v0.2's changes
  to a v0.1 brick take 0.2.0, since 0.1.1
  was released with `main` at 5c16d06 (D72). v0.4 bumps `postgres` to
  0.4.0 and `scheduler` to 0.2.0: every scenario with a `postgres` node
  pins 0.4.0, every scenario with a scheduler node 0.2.0, and every fault
  applying to either adds the new version to `applies_to` (D206, D215).
- **Faults never bump** (D60). A fault keeps its version whatever changes
  in its folder (injection, sealed check, acceptance criteria,
  `applies_to`); git history is the record. A fault pin therefore names
  the fault, not a state of it.
- **Scenarios never bump** (D58, D75). A scenario keeps its version
  whatever changes (pins, answer key, issues, story, topology); git
  history is the record, and nothing pins a scenario.
- **Purposes and domains never bump** (from v0.4, D215): their material
  is copied into a scenario at design time, so nothing pins a state of
  them.
- **Which faults a brick hosts** is stated only by each fault's
  `applies_to` (D59); `brick.yaml` lists no faults. A new brick version
  hosts no fault until the faults that still apply to it add that version
  to their `applies_to`.

## Script contracts (D43)

Fixed at consolidation so the scripts, the faults and the GM skill agree.

- **Injection scripts** (`inject/*.sh`): POSIX shell, read from stdin by
  `sh -s` inside the target container, run as root unless the fault says
  otherwise, with fault parameters passed as environment variables.
  Idempotent: running one twice leaves the same state. Exit 0 on success;
  anything else is a failed setup (D36).
- **Sealed checks** (`checks/fixed.sh`): same delivery. Exit 0 means the
  fault is no longer present in the effective live state, 1 means it is
  still present, from v0.3 3 means "too soon to tell", with the remaining
  window on the first output line (D124); any other code is an error. The
  first line of output says why, in one sentence the GM can use in
  feedback. From v0.3 a sealed check on a database connects as the GM
  check role, inside the GM's connection reserve (D144). From v0.4 a
  sealed check judging runs or triggers receives `CHECK_SINCE`, the
  judged moment as a UTC timestamp, the exit codes unchanged; a check
  comparing two instances reaches each as the GM check role, from a
  scheduler node through `check-sql`, from a database node through
  `check-psql` with the other node's name (D215).
- **The data load** (`data/<node>.sql`): SQL, streamed into `psql` run as
  `postgres` inside the node's container; once per game, a second load
  changes nothing; any error is a failed setup (D52).
- **Public validator**: exit 0 green, 1 red with one line per broken rule,
  any other code an error. On the database node the player runs it through
  `sudo gm-validate`; the GM's official run goes through the exec verb.

## Roles

A node's role names its place in the topology (proposed list): `bastion`,
`producer`, `queue`, `database`, `pooler` (from v0.3, PgBouncer),
`transformer` (from v0.4, a `scheduler` 0.2.0 node running purpose jobs,
D203), `consumer`, `monitoring`, `backup`. A brick may serve several
roles.

### Where a job runs (D207)

Guidance for designing a scenario, from v0.4. A scheduled job may run on
a scheduler node or, with `postgres` 0.4.0, on a database node, through
`pg_cron` or the cron daemon (D206):

- **Light, well-scheduled work may run on a database node**: creating
  partitions, small cleanups, refreshing a small materialized view,
  calling a set-based procedure off-peak.
- **Heavy or row-by-row work goes to a transformer node** sized for it
  (D204).
- **Heavy work on the source instance is the worst placement**: it
  competes with the customers.

Where the computation runs matters more than where the scheduler lives:
a database-node job calling a set-based procedure and a transformer's
job running the same statement load the database alike. A scenario
departs from this guidance only to plant a fault, which its answer key
names.

## Expressing the v1.0 pipeline

Illustration only; v0.2's monitoring tools are D69, the other roles' O11.

| Node | Role | Consumes | Provides |
|---|---|---|---|
| `bastion` | bastion | SSH to every node | the player's entry point |
| `producer` | producer | SQL on `db-src` | — |
| `db-src` | database | — | SQL |
| `transform` | transformer | SQL on `db-src`, SQL on `db-dwh` | — |
| `db-dwh` | database | — | SQL |
| `consumer` | consumer | SQL on `db-dwh` | — |
| `prometheus`, `pg-exporter`, `grafana` | monitoring | metrics from `db-src`, `db-dwh`, and every node's health script | dashboards, alerts |

Flows: `producer` -> `db-src` (rows, continuously), `db-src` ->
`transform` -> `db-dwh` (batch, nightly), `db-dwh` ->
`consumer` (reads), the monitoring nodes *monitor* both databases and
every node. v0.1 uses the same
format with `bastion` and one database node.
