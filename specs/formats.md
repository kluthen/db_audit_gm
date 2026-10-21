# Formats: scenario, brick, fault

Status: draft v8

What a scenario, a brick and a fault definition must contain, and how they
are laid out, so that every scenario the GM designs or generates stays
within known boundaries. The rules these formats carry (the solvability
probe, per-brick checks, fault families) are in
[bricks-and-faults.md](bricks-and-faults.md); access and validator rules
in [planes-and-access.md](planes-and-access.md).

## Enforcement

Skills backed by templates enforce the formats:

- **The format skill** (D5): a template each for the scenario (manifest
  and answer key), the brick and the fault definition, and one skill the GM
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
reading to confirm under O20. The skills live in `.claude/skills/`, which
both Claude Code and opencode read (D29). A third skill, the GM skill,
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
references them by id and pinned version. A brick or fault made solely for
one scenario may live inside that scenario's folder.

### What a scenario must contain

The owner's requirements (D23), with the earlier rulings that apply:

- **Scenario information**: id, version, title, date, origin (from a brief,
  partly or wholly, or GM-designed), session length (at most 4 hours), and
  the initiator's inputs as given.
- **A clear topology**: every node with its brick and version, its role, the
  parameters it is given, whether it is stateful, its networks and write
  policy, and its knobs' initial values (which may lie outside the
  envelope) with the envelope, tightened from the brick's default if
  needed (D32); every flow between nodes (what moves, how, cadence;
  monitoring and backup relations included); the data schema each database
  holds, or what produces it.
- **Background information**: the customer's story and context.
- **Incidents, flaws and defects**: every fault instance (fault definition
  and version, target nodes, parameters, known or hidden, aging technique),
  and the issues given to the players, zero or more, each with its expected
  resolution (*report*, *propose*, *fix*, *improve*) and the faults it
  covers (D9);
  the aging plan (none in v0.1).
- **The answer key**, for every fault instance: what is wrong and why, the
  evidence as the player user, what counts as an acceptable diagnosis, fix,
  improvement or recommendation, the sealed check, interactions with other
  faults, any validator the player cannot make green (D10), and, once
  solvability probes exist, their results.
- **The host topology it was designed for**: the platform (Swarm,
  Kubernetes…), the hosts, their capacity (CPU, RAM, disk), and the
  resource limits, reservations and placement the scenario was sized with.
  This is the reference the local implementation adapts from.
- **The starter pack** shipped to the bastion: topology documentation,
  node names, rules and DO NOT TAMPER list, the story, the issues.
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
  number of hosts used (one in v0.1, D35);
- the game id, which names every volume, config, secret and network of the
  game, so a redeploy never reuses a player-edited volume (D36);
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
  docs/gm.md         spoilers and operating notes, never shipped
  companion/         optional: the brick's own checks, scripts and tools (D28)
```

### `brick.yaml` must contain

Fields marked *optional in v0.1* have no use yet and may be left out
(D35).

- **Identity**: id, version, role(s), technology and engine version(s),
  image name(s).
- **Footprint**: CPU, memory and disk needs (limits and reservations) as a
  default. The allowed range is *optional in v0.1*.
- **Interfaces**: what the brick *provides* (e.g. a PostgreSQL SQL endpoint
  on a port) and what it *consumes* (e.g. an upstream SQL endpoint, a
  queue). Flows in a scenario connect a consumer interface to a matching
  provider; this is what lets a pipeline be checked. *Optional in v0.1.*
- **Parameters** the scenario sets (upstream node, schema, load rate…).
- **Knobs**: setting, file, default, and default envelope; a scenario may
  tighten the envelope (D32).
- **Write policy options** it supports (*fixable*, *report-only*).
- **Writable paths** (what the player may change) and **protected files**.
- **Player access**: the SSH account, its group, its `sudo` wrappers.
- **Capabilities** it adds back after dropping all (D41).
- **Monitoring exposure**: metrics endpoints, logs, what monitoring bricks
  can collect. *Optional in v0.1.*
- **Health check**: a command run inside the container.
- **Secrets** it needs, and the fixed paths where it reads them and its
  seed files.
- **Processes** run under s6-overlay (D30).
- **Compatible faults**: the fault definitions known to apply to it.
- **Companion material**, if any (see below).

**Companion material** (D28, D42). A brick may ship extra information,
scripts or tools that help its integration and use: its own lint or
checks, helpers for the GM (seeding, state injection, inspection), notes on
combining it with other bricks. Machine checks are per brick: whether a
brick has any depends on the brick. Such material lives in the brick's
`companion/` folder, and `brick.yaml` says what it provides and when the GM
should use it.

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

## Fault definition

Faults live beside the bricks rather than inside one, because a fault can
span several bricks (a collector pointed at the standby touches the
monitoring brick and the database brick).

```
faults/<fault-id>/
  fault.yaml
  inject/            material that plants the fault
  checks/            solvability probe and sealed fix check
  gm.md              explanation the GM uses for feedback
```

### `fault.yaml` must contain

- **Identity**: id, version, title, family, severity.
- **Applies to**: brick ids and version ranges, plus topology preconditions
  (e.g. needs a standby, needs a scheduled job).
- **Parameters** the scenario sets (which table, which job…).
- **Injection**: how it is planted (a change to a node's seed
  configuration, a state change run in the node by the GM, an aging step)
  and at which stage. State changes are idempotent POSIX shell scripts
  streamed over stdin, so they run the same through `docker exec` or
  `kubectl exec` (D22). Their interface is in "Script contracts" below.
- **Evidence paths** as the player user, and the **aging** technique and
  minimum duration that make them visible.
- **Solvability probe**: what it runs as the player user and what it
  expects. Descriptive only in v0.1; a manual play-through checks it
  (D38).
- **Possible resolutions**: which of *report*, *propose*, *fix*, *improve*
  make sense, and which write policy each needs.
- **Acceptance criteria**: what counts as a correct diagnosis and as an
  acceptable fix or improvement.
- **Sealed fix check**.
- **Interactions**: masks, masked by, conflicts with.
- **Complaint template**: how a customer would describe it, for when the
  fault is known.

*Known* or *hidden* is not part of the definition: it is chosen per
instance, in the scenario.

## Script contracts (D43)

Fixed at consolidation so the scripts, the faults and the GM skill agree.

- **Injection scripts** (`inject/*.sh`): POSIX shell, read from stdin by
  `sh -s` inside the target container, run as root unless the fault says
  otherwise, with fault parameters passed as environment variables.
  Idempotent: running one twice leaves the same state. Exit 0 on success;
  anything else is a failed setup (D36).
- **Sealed checks** (`checks/fixed.sh`): same delivery. Exit 0 means the
  fault is no longer present in the effective live state, 1 means it is
  still present, any other code is an error. The first line of output
  says why, in one sentence the GM can use in feedback.
- **The data load** (`data/<node>.sql`): SQL, streamed into `psql` run as
  `postgres` inside the node's container; once per game, a second load
  changes nothing; any error is a failed setup (D52).
- **Public validator**: exit 0 green, 1 red with one line per broken rule,
  any other code an error. On the database node the player runs it through
  `sudo gm-validate`; the GM's official run goes through the exec verb.

## Roles

A node's role names its place in the topology (proposed list): `bastion`,
`producer`, `queue`, `database`, `transformer`, `consumer`, `monitoring`,
`backup`. A brick may serve several roles.

## Expressing the v1.0 pipeline

Illustration only; technologies per role are O11.

| Node | Role | Consumes | Provides |
|---|---|---|---|
| `bastion` | bastion | SSH to every node | the player's entry point |
| `producer` | producer | SQL on `db-src` | — |
| `db-src` | database | — | SQL |
| `transform` | transformer | SQL on `db-src`, SQL on `db-dwh` | — |
| `db-dwh` | database | — | SQL |
| `consumer` | consumer | SQL on `db-dwh` | — |
| `pgwatch` (+ its own database) | monitoring | metrics from `db-src`, `db-dwh` | dashboards |

Flows: `producer` -> `db-src` (rows, continuously), `db-src` ->
`transform` -> `db-dwh` (batch, time-compressed "daily"), `db-dwh` ->
`consumer` (reads), `pgwatch` *monitors* both databases. v0.1 uses the same
format with `bastion` and one database node.
