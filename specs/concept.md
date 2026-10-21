# Concept

Status: draft v8

What the project is, who it is for, the words we use, and what is in and out
of scope. Mechanics live in the other topic documents (see
[README](README.md)).

## Purpose

The project gives students *live* experience of auditing and fixing a
complex data stack: finding the issues the customer already knows about,
discovering the hidden ones, and checking that monitoring and backups really
do what they claim.

It does this by generating **scenarios**: a realistic data stack (producers,
databases, transformers, consumers, backup and monitoring tools) deployed on
a Docker Swarm, with faults planted in it and aged so that they leave
traces, handed over to a player through a single bastion host.

## Nature of the exercise

- It is an exercise, not an adversarial CTF. Players have a stake in
  learning, not in breaking the game, and are expected to follow the rules.
- Prevention is applied where it is practical. What cannot be prevented is
  handled by trust and clear documentation (see
  [planes-and-access.md](planes-and-access.md), "Trust").
- Complexity comes from the topology and the faults, not from data volume
  (see [platform.md](platform.md), "Resources and nerfing").

## Actors

Kept short on purpose: there is no designed interface, and the actors'
rights are a game mechanic documented in
[planes-and-access.md](planes-and-access.md).

- **Game master (GM)** — the agent, running in an agent session (Claude
  Code or opencode). It asks where the game takes place, designs or
  generates the scenario, deploys and ages it, hands it over, receives the
  player's final answer and gives feedback. Its tools and permissions: D29.
- **Teacher** — optional. As the initiator, provides inputs at the start of
  a session (the brief), then is out of the game once it is set up.
- **Player** — a student playing a DBA, with low to mid programming
  experience. Audits the scenario through the bastion, fixes what they are
  asked and allowed to fix, and reports to the GM. "The player" is whoever
  sits behind one game's report: one student or a whole class (D8).

Anyone in the GM session may ask the GM to stop the game and turn off the
containers. A student may also run a game alone, for example at home with
enough compute for a swarm; the GM then designs the exercise without a
teacher brief.

## Vocabulary (proposed, O16)

One canonical term per concept. "Node" is ambiguous in a Swarm context,
hence the host/node split.

| Term | Meaning |
|---|---|
| **Host** | A Swarm node: a machine or VM running a Docker engine that is part of the swarm |
| **Node** | An element of the scenario topology (a database, a producer, the bastion…), i.e. a Swarm service, usually one container |
| **Brick** | A reusable, catalogued node definition: image, configuration, documentation, validator. Versioned: any change bumps its version, and scenarios pin it (D57, D58) |
| **Catalog** | The bricks and fault definitions kept in the repository |
| **Fault** | An issue planted in a scenario. A *fault definition* is reusable, names the brick versions it applies to (D59) and keeps its version whatever changes (D60); a *fault instance* is one fault applied in one scenario |
| **Known / hidden** | A fault instance is *known* when an issue given to the player covers it, *hidden* otherwise |
| **Issue** | What the GM gives the player at hand-over: a complaint plus its expected resolution. A game may have none |
| **Expected resolution** | What an issue asks of the player: *report* (diagnose and report), *propose* (diagnose and recommend a concrete fix without applying it), *fix* (alter the system so it works), *improve* (alter it so it works better) (D9) |
| **Scenario** | A self-sufficient folder holding everything needed to start one exercise: information, topology, background, defects, answer key, the host topology it was designed for (see [formats.md](formats.md)) |
| **Scenario document** | The readable whole of a scenario, generated with the GM's scenario-document skill, headed by a "do not read" warning |
| **Scenario manifest** | The machine-readable part of the scenario folder |
| **Local implementation** | What the GM generates to deploy a scenario on one real playground: resources, placement, derived values, rendered platform files |
| **Answer key** | The sealed list of a scenario's fault instances, their evidence and acceptance criteria; never on the player side |
| **Playground** | The swarm, its hosts and the capacity available (CPU, RAM, disk): the only required setup input |
| **Initiator** | Whoever starts the game with the GM: a teacher, or a student playing alone |
| **Brief** | The initiator's optional inputs (topology, story, data schema, incidents…), possibly partial; the GM fills the blanks |
| **Game** | One deployment of one scenario, played behind one report, from setup to teardown |
| **Final answer** | The player's report once they have stated it is final |
| **Player** | Whoever plays one game and hands in its report |
| **Plane** | One of the infrastructure, scenario and player planes |
| **Knob** | A setting the player may change, with its bounds (the *envelope*) |
| **Write policy** | Per node: *fixable*, *report-only* or *no access* |
| **Public validator** | A per-node check the player can run: are the rules respected |
| **Sealed check** | A GM-side check of the answer key (fault fixed or not) |
| **Evidence path** | Where a player, with their own rights, can see a fault |
| **Solvability probe** | A check, run as the player user, that a hidden fault's evidence is reachable |
| **Aging** | Making faults leave traces: pre-aging, forged history, time compression |
| **Starter pack** | What the player receives at hand-over |

## Scope

In scope:

- A growing **catalog** of bricks and fault definitions (see
  [bricks-and-faults.md](bricks-and-faults.md)).
- A defined **scenario format**, **brick definition** and **fault
  definition**, enforced by skills plus templates (see
  [formats.md](formats.md), D5, D21).
- **Scenario design or generation** by the GM, from an optional brief,
  written as a self-sufficient scenario folder (see
  [scenario-lifecycle.md](scenario-lifecycle.md)).
- Deployment on the playground declared at setup (swarm, hosts, capacity)
  through a local implementation that fits the scenario to it, aging,
  hand-over, the game itself, the GM's feedback, and teardown.
- Scripts and small apps supporting the above. Which steps are scripts and
  which are agent judgment: O2.

Out of scope:

- A designed player interface. Players report to the GM in the GM session
  (see [scenario-lifecycle.md](scenario-lifecycle.md), "End of the game").
- Adversarial play: defending the game against players who try to break it.
- Large data volumes or complex schemas.
- Who sits behind a report, and how a class shares one game (D8).
- Running on, or testing against, an existing production swarm (see
  [platform.md](platform.md)).

### Versions

Scoped separately, each in its own page (D4):

- **v0.1, the first milestone** (wave 1): a single hand-specified
  PostgreSQL node scenario, end to end: a static database, no load
  producer, no monitoring. Its goal is to settle the GM stance
  ([gm-stance.md](gm-stance.md)). See
  [versions/v0.1/README.md](versions/v0.1/README.md).
- **v0.2 to v0.5**: monitoring, then producers and consumers, then
  transformers, then research and broadening (D47).
- **v1.0, the first release**: the full pipeline, producer -> database ->
  transformation -> database -> consumer, plus monitoring tools and the
  bastion. See [versions/v1.0/README.md](versions/v1.0/README.md).
- **Beyond v1.0**: other databases and tools (TimescaleDB, columnar
  databases, MySQL…).

The whole roadmap is in [versions/README.md](versions/README.md).

The scenario format, brick definition and fault definition are designed
from the start to express the v1.0 pipeline, even though v0.1 exercises a
single node (see [formats.md](formats.md)).

## Prior art

A private earlier project, a docker compose PostgreSQL workshop lab, is
inspiration, not a base. Practices that transfer:

- No bind mounts; configuration baked into images. This works with a remote
  Docker engine and with Swarm, where bind mounts point at the host's disk.
  Superseded here by generic images plus scenario files delivered as
  Swarm configs (D11), so that player-edited, per-scenario configuration
  works.
- One image per engine version for both server and client tools, so
  versions stay consistent.
- Secrets only through environment variables or generated `.pgpass` files.
- A continuous load generator, and a separate GM-only file listing the
  deliberate traps.
- Monitoring and reporting tools in the stack (pgwatch, Grafana, pgCluu,
  pgBadger) and a backup tool (pgBackRest).

Candidate technologies (not a commitment; choice per role: O11): PostgreSQL
(primary, standby, PITR, pgBackRest, PgBouncer), MySQL, DuckDB, TimescaleDB,
dbt, pgwatch, Grafana, pgBadger / pgCluu, a message queue for producers
(NATS, Redpanda, …).
