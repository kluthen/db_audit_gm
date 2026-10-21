# db_audit_gm v0.1 — Master specification

Status: approved on 2026-10-20 by the project lead, under the owner's
delegation (the owner may revisit any point).
Companion: [access-model.md](access-model.md).
Build plan: [build-plan.md](build-plan.md).

---

## 1. Concept and objective

db_audit_gm generates live database audit exercises. An agent, the **game
master (GM)**, deploys a deliberately flawed data stack on a container
cluster, hands it to students (the **players**) through a single bastion
host, receives their audit report, and gives teacher-style feedback. It is
an exercise, not an adversarial game: players are expected to follow the
rules, and what cannot be prevented is documented rather than enforced.

v0.1 is the first milestone. Its goal, in the owner's words: "fix the GM
stance, set up a simple scenario (investigating a backup for specific
defects), and report, propose or enact fixes in the configuration". Here
"fix the stance" means *settle* it. Concretely:

1. **The GM stance is settled and exercised** end to end: setup questions,
   issues with an expected resolution, report intake, the final-answer
   rule, no reveals, stopping as the only action taken on request,
   positive teacher-style feedback.
2. **One simple scenario**: a single static PostgreSQL database, the
   equivalent of a snapshot or a restored backup, investigated for
   specific defects in the database and its configuration.
3. **The players' outcome**: for each issue, they report, propose a fix, or
   apply a fix in the configuration, as the issue asks.

The formats v0.1 introduces (scenario, brick, fault) are designed to
express the first release's full pipeline (producer, database,
transformation, database, consumer, with monitoring and the bastion), even
though v0.1 exercises one database node.

## 2. Scope

### In scope

- Three skills with their templates, in initial versions that are expected
  to evolve: the GM skill, the format skill, the scenario-document skill.
- A minimal set of deterministic scripts: renderer, capacity check,
  platform operations, in-node public validator, sealed-check runner,
  injection runner.
- Two bricks: PostgreSQL 18 on Debian 13 (trixie), and the bastion.
- One hand-written scenario folder, with the fault definitions it uses.
- Running on one host: the swarm manager the GM targets, with locally
  built images and no registry.

### Out of scope for v0.1 (deferred, still part of the project)

- Load producers, consumers and any other activity on the database; the
  database is static.
- Monitoring tools.
- Backup-tooling defects: a backup tool given the wrong configuration; a
  restore that succeeds while integration with the wider system fails; a
  restore that fails (the backup file must then be present and pointed out
  to the player). These need more investigation before they are specified.
- Any GM interaction with players during the game other than receiving the
  report and obeying a stop request. The GM answering in character as the
  customer is a future idea. No hints, node resets or extra time.
- Aging: no pre-aging run, no forged history beyond the scenario's data,
  no time-compressed schedules.
- Designing a scenario from a teacher's brief, or the GM filling in a
  partial brief.
- The automated solvability probe; a manual play-through stands in.
- Multi-host swarms, an image registry, per-host SSH routing, creating a
  swarm on remote hosts; envelopes computed from the playground's
  capacity; setting `no-new-privileges`; hash checks on files already
  mounted read-only; network-level faults.
- A designed player interface. Players report to the GM in its session.
- Who sits behind a report (one student or a class) is not the project's
  concern: one game, one report.

## 3. Actors

Kept short; the full rules are in the access model.

- **Initiator**: whoever starts a game with the GM (a teacher, or a student
  playing alone). Gives the setup inputs, then is out of the game.
- **Players**: one student or several, playing a DBA with low to mid
  programming experience. They reach the system only through the bastion
  and hand in one report.
- **Game master**: the agent, in a Claude Code or opencode session running
  the GM skill. It sets up, deploys, hands over, takes the report, gives
  feedback, and tears down.
- **Anyone in the GM session** may ask the GM to stop the game.

## 4. Glossary

| Term | Meaning |
|---|---|
| Host | A machine running a Docker engine that belongs to the swarm |
| Node | An element of the scenario topology (the bastion, the database), deployed as one Swarm service and one container |
| Brick | A reusable node definition in the catalog: image, configuration, documentation, validator, compatible faults |
| Catalog | The bricks and fault definitions kept in the repository (`bricks/`, `faults/`) |
| Fault definition | A reusable defect description with its injection material and checks |
| Fault instance | One fault definition applied to one scenario, *known* or *hidden* |
| Known / hidden | Known when an issue given to the players covers the instance, hidden otherwise |
| Issue | What the GM gives the players at hand-over: a complaint plus its expected resolution |
| Expected resolution | *report* (diagnose and report), *propose* (diagnose and recommend a concrete fix without applying it), *fix* (alter the system so it works), *improve* (alter it so it works better) |
| Scenario | A self-sufficient folder holding everything needed to start one exercise |
| Scenario document | The readable whole of a scenario (`README.md`), generated from the authoritative files, headed by a "do not read" warning |
| Playground | The swarm, its hosts and the capacity available (CPU, memory, disk): the one required setup input |
| Local implementation | What the GM generates to deploy a scenario on one playground: game id, resources, placement, rendered stack file, state |
| Game | One deployment of one scenario, from setup to teardown, played behind one report; identified by a game id |
| Final answer | The players' report once they have said it is final |
| Knob / envelope | A setting the player may change / the bounds it must stay within |
| Write policy | Per node: *fixable*, *report-only* or *no access* |
| Public validator | A per-node check the player may run: are the rules respected |
| Sealed check | A GM-side check of one fault instance: is it still present |

## 5. Repository layout created by v0.1

```
.claude/skills/
  game-master/          the GM skill (invoked explicitly, e.g. /game-master)
  scenario-format/      the format skill and its templates
  scenario-document/    the scenario-document skill and its template
tools/                  host-side scripts (Python 3) and their tests
bricks/
  postgres/             the PostgreSQL brick
  bastion/              the bastion brick
faults/<fault-id>/      the catalog fault definitions v0.1 uses
scenarios/<scenario-id>/  the v0.1 scenario folder
```

`local/` directories inside scenario folders are git-ignored (the
repository's `.gitignore` gains that entry). Skills live in
`.claude/skills/`, which both Claude Code and opencode read.

## 6. The scenario folder

A scenario is a folder and the **source of truth**. With the full
repository (for the catalog) and the GM skills, the folder is enough to
start the exercise again: after a session restart, on another playground,
or later. Scenarios are kept in the repository in bulk; students may find
them there, which is accepted, the same way answers exist in textbooks.

### 6.1 Layout

```
<scenario-id>/
  README.md           the scenario document (generated)
  scenario.yaml       authoritative manifest
  brief.md            the initiator's inputs as given (may say "hand-written, no brief")
  player/             the starter pack, shipped to the bastion
    README.md         topology, node names, rules, DO NOT TAMPER list, how to run the validator
    story.md          the customer's background
    issues.md         the issues given, each with its expected resolution (may be empty)
  gm/                 sealed: never shipped to any node
    answer-key.yaml   authoritative answer key
    notes.md          explanations the GM draws on for feedback
  nodes/<node>/       scenario-specific files per node, delivered as Swarm configs
  data/<node>.sql     restored-backup data, streamed into the node
  bricks/, faults/    bricks and faults made solely for this scenario, if any
  local/<playground>/ local implementations, one per playground, git-ignored
```

`scenario.yaml` and `gm/answer-key.yaml` are authoritative. The scenario
document is generated from them by the scenario-document skill, whose
template sets its detailed shape.

### 6.2 What a scenario must contain

- **Scenario information**: id, version, title, date, origin (hand-written,
  from a brief, or GM-designed), session length (at most 4 hours), and the
  initiator's inputs as given.
- **A clear topology**: every node with its brick id and pinned version,
  its role, the parameters it is given, whether it is stateful, its
  networks, its write policy, its resource limits and reservations, its
  knobs' initial values (which may lie outside the envelope) and each
  knob's envelope (the brick's default, optionally tightened); every flow
  between nodes; the data schema each database holds.
- **Background information**: the customer's story and context.
- **Incidents, flaws and defects**: every fault instance (fault definition
  id and pinned version, target node, parameter values, known or hidden),
  and the issues, zero or more, each with an id, the complaint as the
  players read it, its expected resolution, and the fault instances it
  covers.
- **The answer key**, for every fault instance: what is wrong and why; the
  evidence as the `player` user (where to look, what shows it); what
  counts as an acceptable diagnosis, proposal, fix or improvement; the
  sealed check; interactions with other instances; and any public
  validator the players cannot make green (reporting it is then part of the
  expected answer).
- **The host topology it was designed for**: platform, hosts, capacity
  (CPU, memory, disk), and the resources and placement it was sized with.
- **The starter pack**, the **node files**, and the **restored-backup
  data**.
- **The scenario document**, opening with a prominent warning that students
  and players should not read it. Enforcement goes no further. The starter
  pack does not carry the warning.

A scenario is complete or it is not deployed: the format skill flags any
missing item, and the GM refuses to deploy an incomplete scenario.

### 6.3 Catalog references

Bricks and fault definitions shared across scenarios live in the catalog
and are referenced by id and pinned version. A brick or fault made solely
for one scenario may live in that scenario's `bricks/` or `faults/`.

## 7. Brick definition

```
bricks/<brick-id>/
  brick.yaml
  Dockerfile and build context
  validator/          the public validator (POSIX shell)
  docs/player.md      what the player may read about this kind of node
  docs/gm.md          spoilers and operating notes, never shipped
  companion/          optional: the brick's own checks, scripts and tools
```

`brick.yaml` contains: identity (id, version, roles, technology and engine
version, image name); default footprint (CPU, memory, disk); parameters the
scenario sets; knobs (setting, file, default, default envelope); write
policy options; writable paths and protected files; player access (SSH
account, group, `sudo` wrappers); the capabilities added back after
dropping all; the health check (a command run in the container); the
secrets it needs and the fixed in-container paths where it reads secrets
and seed files; the processes run under s6-overlay; compatible faults;
companion material, if any, and when the GM should use it. Optional in
v0.1 because nothing uses them yet: footprint ranges, interfaces
(provided and consumed endpoints), monitoring exposure.

**Machine checks are per brick.** A brick may ship its own checks and
helpers as companion material, and the GM runs them before deploying a
scenario that uses it. There is no project-wide mandatory lint.

**Bricks are platform-neutral**, so the same brick can later run on
Kubernetes: seeds and secrets come from fixed paths the brick declares,
never Swarm's default mount locations; the health check is a command;
interfaces are container ports, and no brick relies on the routing mesh;
statefulness is declared, and pinning is the renderer's business; peers
are reached by node name only, never `tasks.<service>`; hardening needs
are declared and mapped by the renderer.

**Image names** carry a registry host that is not Docker Hub (for example
`127.0.0.1:5000/dbagm/<brick>:<version>`, where a registry will later
live). In v0.1 the images are built locally on the host and deployed
without resolving them against a registry.

## 8. Fault definition

```
faults/<fault-id>/
  fault.yaml
  inject/             material that plants the fault
  checks/             the sealed check (fixed.sh) and the probe description
  gm.md               explanation the GM uses for feedback
```

`fault.yaml` contains: identity (id, version, title, family, severity);
the bricks and versions it applies to and any topology precondition;
parameters; how it is planted (a change to a node's seed files, or a state
change the GM runs in the node) and when; evidence paths as the player;
the solvability probe, which is descriptive only in v0.1; the possible
resolutions and the write policy each needs; acceptance criteria; the
sealed check; interactions (masks, masked by, conflicts with); a complaint
template for when the fault is known.

### 8.1 Script contracts

- **Injection scripts** (each `inject/*.sh`): POSIX shell, fed on stdin
  to `sh -s` inside the target container, run as root unless the fault
  says otherwise, with parameters as environment variables. Idempotent:
  running one twice leaves the same state. Exit 0 on success; any other
  code fails the setup.
- **Sealed checks** (`checks/fixed.sh`): same delivery. Exit 0 means the
  fault is no longer present in the **effective live state**, 1 means it is
  still present, any other code is an error. The first output line says
  why, in one sentence the GM can reuse in feedback. A fix counts when it
  is in effect, whichever path the player took (editing a file and
  reloading, or `ALTER SYSTEM`). A check that queries PostgreSQL runs its
  query as `postgres` (through `runuser -u postgres`, or by being executed
  as `postgres`), so that local peer authentication applies.
- **The data load** (`data/<node>.sql`): SQL, not shell, streamed on
  stdin into `psql -X -q -v ON_ERROR_STOP=1 -d postgres` run as `postgres`
  inside the node's container (local peer authentication); the file
  creates its own databases and roles. It runs once per game: loading
  again once the data is in changes nothing. Any error fails the setup.
- **Public validator**: exit 0 green; 1 red, with one line per broken
  rule; any other code is an error.

These contracts were fixed at consolidation so the scripts, the faults and
the GM skill agree; the lead may revisit them.

## 9. The v0.1 bricks

### 9.1 PostgreSQL brick

- PostgreSQL 18 on Debian 13 (trixie), server and client tools in the same
  image.
- **s6-overlay** supervises PostgreSQL and `sshd`, with
  `S6_READ_ONLY_ROOT` set and a tmpfs on `/run`, so the database can be
  restarted without killing the container.
- **Read-only root filesystem.** Writable: a named volume for PGDATA, a
  named volume for `/etc/postgresql`, a named volume for
  `/var/lib/gm-state` (the seed marker, root-owned), the tmpfs `/run`, and
  a writable target for `sudo`'s log.
- **Configuration outside PGDATA**: `postgresql.conf` and `pg_hba.conf` in
  `/etc/postgresql/`, used through `config_file` and `hba_file`, owned by
  `postgres` with a group the `player` account belongs to, group-writable
  when the node is fixable.
- **Seed once**: on first start the entrypoint copies the scenario's seed
  files (delivered as Swarm configs to a fixed seed directory) into
  `/etc/postgresql/`, and initialises the cluster if PGDATA is empty. It
  marks the node as seeded with the marker `/var/lib/gm-state/.gm-seeded`
  (directory root-owned, mode 0755; marker root-owned, mode 0444), kept
  out of the group-writable `/etc/postgresql`, and never overwrites the
  seeded files afterwards.
- **Accounts**: OS account `player` (SSH, public key from a Swarm secret);
  PostgreSQL superuser role `dba` for the players, with a per-game
  password from a Swarm secret written to the player's `.pgpass`. The GM
  uses the `postgres` OS user over the local socket. `pg_hba.conf` carries
  a `local all postgres peer` line marked DO NOT TAMPER; the validator
  flags its absence.
- **Superuser is accepted**: the `dba` role also gives operating-system
  access as `postgres` (for example `COPY ... TO PROGRAM`). Protected
  files and validators are root-owned and read-only, so this cannot alter
  them.
- **`sudo` wrappers** for `player`: `gm-reload-db`, `gm-restart-db`,
  `gm-validate`. `sudoers` lists only these, by absolute path, with no
  arguments or a fixed set; no shell, editor or interpreter; `env_reset`
  and a fixed `secure_path` on. Wrappers run as `postgres` where that is
  enough.
- **Capabilities**: drop all, add back only what `sshd`, s6, `sudo` and the
  entrypoint need (more than `SETUID` and `SETGID`), listed in
  `brick.yaml`. `no-new-privileges` is not set, because `sudo` needs
  setuid.
- **Public validator** (`gm-validate`, runs as `postgres`): every knob
  within its envelope, both the value in effect and the value pending in
  the configuration files. The envelopes come from a per-game envelope
  file, rendered from the scenario and delivered as a protected, read-only
  config at a fixed path the brick declares; the GM's `pg_hba.conf` line present; the server
  accepting connections. Run by the GM too, through the exec operation,
  for the official result.
- **Protected files**: `sshd_config`, `sudoers`, the wrappers, the
  validator, the entrypoint and s6 service definitions, root-owned and
  read-only (on the image's read-only root, or mounted from Swarm configs),
  and the seed marker, root-owned on its own volume.
- No port is published.

### 9.2 Bastion brick

- Debian 13, `sshd` under s6-overlay, read-only root with the same tmpfs
  and log targets, capabilities dropped and added back as listed.
- PostgreSQL 18 client tools and a plain SSH client.
- Account `player`, logging in with the per-game password from a Swarm
  secret. Its home holds the private key for the inner hop (from a Swarm
  secret), a `.pgpass` for `dba`, the starter pack (`player/` from the
  scenario, delivered as configs), and a writable place for `~/report.md`.
- Its SSH port is the only port published by the game (default 2222; the
  local implementation records the port actually used).

## 10. Content delivery and the local implementation

### 10.1 How scenario content reaches nodes

- **Brick images are generic**: built once per brick version, carrying no
  scenario content and no spoilers.
- **Scenario files travel as Swarm configs**, named after the game id (so
  they are versioned per game; configs are immutable). `gmctl deploy`
  creates every config and secret itself, labels it with the game id so
  that teardown finds it, and the stack file refers to it as external.
  Configs are mounted read-only
  under the brick's fixed seed directory, and copied once into the node's
  volume by the entrypoint. Players edit the copy.
- **Protected files** are mounted directly from configs or come from the
  image, read-only.
- **Credentials** travel as Swarm secrets.
- **Restored-backup data** (`data/<node>.sql`) is streamed into the node by
  the GM through the injection path, after deployment and before any fault
  is planted. It does not go through configs, so its size is not limited
  by them.
- **Configuration faults** are the content of the seed files. **State
  faults** are planted by the GM right after the data load, by streaming
  the fault's injection scripts into the container. Nothing used for
  injection is left on a node.

### 10.2 The playground in v0.1

One host: the swarm manager the GM targets, either the local Docker engine
or one reached over SSH (a Docker endpoint such as `ssh://user@host`). If
that engine is not part of a swarm, the GM runs `docker swarm init` on it,
or guides the user to. All nodes are placed on that host. Images are built
there and deployed without a registry.

### 10.3 The local implementation

At deployment the GM generates a local implementation in
`local/<playground>/` inside the scenario folder (git-ignored). It holds:

- the playground as declared: platform, Docker endpoint (never keys),
  capacity;
- the game id (derived from the scenario id plus a short random suffix,
  lowercase letters, digits and hyphens, at most 63 characters), which
  names the stack and therefore every service, network, config, secret and
  volume of the game;
- per-node resources and placement, and the published bastion port;
- the rendered Swarm stack file (Compose file format 3.8), always produced
  by the renderer, never written by hand;
- the per-game credentials, in a `secrets/` subfolder with mode 0600, so a
  restarted GM can hand them over again; never committed;
- the game's state: the stage reached, timestamps, and the reason of any
  failure.

**Capacity check.** In v0.1 the scenario's resource limits and envelopes
are absolute. The capacity check verifies that the sum of reservations
plus headroom fits the declared CPU, memory and disk, and that every
node's limits fit the host. It never recomputes limits or envelopes:
recomputing could turn a deliberately planted out-of-bounds value into an
in-bounds one. If capacity is insufficient, the GM says so and does not
deploy.

## 11. Scripts and platform operations

Host-side scripts are Python 3, standard library plus PyYAML, in
`tools/`, with one command-line entry point (`gmctl`) whose subcommands
the GM skill calls:

| Subcommand | Does |
|---|---|
| `fit` | Capacity check of a scenario against a declared playground |
| `render` | Writes the local implementation's stack file from `scenario.yaml` and the local implementation |
| `deploy` | Ensures the swarm exists (or reports that it does not), generates the per-game credentials, creates configs and secrets named after and labelled with the game id (external in the stack file), deploys the stack, waits for health checks |
| `exec` | Streams stdin into `sh -s` in a node's container, with environment variables, as a given user |
| `load-data` | Streams `data/<node>.sql` into the node |
| `inject` | Runs every state fault's injection scripts for the game |
| `validate` | The official run of every node's public validator |
| `check` | Runs every sealed check and prints one line per fault instance |
| `logs` | A node's service logs |
| `status` | The game's recorded state |
| `teardown` | Removes everything carrying the game's stack label, volumes included; leaves images and the swarm; records the reason of a stop when given one (section 12, "Failures") |

Every subcommand prints a readable result and exits non-zero on failure.
`exec` finds the node's container on the targeted engine by its Swarm
service label. In-node scripts are POSIX shell.

**Division of labour in v0.1.** Scripts do the rendering, the capacity
check, the platform operations, the validators, the sealed checks and the
injection. The agent does the setup dialogue, the local-implementation
choices within what the scripts accept, the evaluation of the report, and
the feedback.

## 12. The game in v0.1

1. **Setup.** The initiator invokes the GM skill. The GM asks for the
   playground: where the Docker engine is (local or an SSH endpoint), and
   the capacity available (it may propose figures read from `docker
   info`). It confirms the scenario (the v0.1 scenario folder) and refuses
   to go on if the scenario is incomplete.
2. **Local implementation**: the capacity check, the game id, the rendered
   stack file, the state file.
3. **Brick checks**: the companion checks each brick ships, if any.
4. **Deployment**, then health checks.
5. **Data load**, then **state faults planted**.
6. **Hand-over**: the GM gives the players the bastion address and port,
   the password, the starter pack's location, and the issues with their
   expected resolutions.
7. **The game**, up to 4 hours. The players' only interaction with the GM
   is handing in the report, and asking to stop.
8. **Final answer and feedback** (section 13).
9. **Teardown.**

**Failures.** If any setup step fails (deployment, data load, injection, a
health check that never passes), or anyone asks to stop during setup, the
GM reports it, tears down what it deployed, and records the stage reached
and the reason in the local implementation's state.

**Restart.** When the GM skill starts and finds a local implementation
with a game in progress, it offers to pick it up, grounding itself from
the scenario folder and that state. Recommended practice, not enforced:
the setup session ends at hand-over, and the report is taken in a fresh GM
session. This keeps the setup dialogue, full of spoilers, out of the
players' sight and exercises the restart path.

## 13. The GM stance

- **No reveals.** The GM reveals no answer, hidden fault or GM-side
  document before the players give their final answer.
- **Stop only.** On the players' request, the GM takes no action other
  than stopping the game and tearing it down. It refuses hints, node
  restarts and resets, and extra time, politely and briefly, pointing the
  players back to the system.
- **The final answer.** The players report in the session, by pasting it,
  by leaving it in `~/report.md` on the bastion (which the GM fetches
  through the exec operation), or by discussion. They state that it is
  their final answer; if they have not, the GM asks whether it is.
- **Evaluation.** The GM compares the final answer with the answer key and
  the live system: the official validator run and the sealed checks,
  before teardown.
- **Feedback.** For the issues given and the faults present: which were
  found, which were missed, and whether each answer is acceptable against
  its expected resolution and the answer key's criteria; then what could
  have been done better. The tone is a teacher's: it helps the students
  see where they succeeded and how to improve, and it stays positive. A
  validator the players could not make green counts as a finding to
  report, not as a failure.
- **On the infrastructure side** the GM reads and writes scenario folders,
  uses the Docker CLI, and reaches the host over SSH with the keys given at
  setup. Nothing else, by trust rather than enforcement.
- The GM skill is invoked explicitly, so developer sessions in this
  repository are not GM sessions.

## 14. Player access and rules

- The players use only the bastion and never touch the swarm; no Docker
  socket or manager credential is ever on the player side.
- From the bastion they reach the database node by SSH as `player` and by
  `psql` as `dba`.
- **Write policies**: a *fixable* node expects configuration changes, a
  *report-only* node is read-only for the players (findings go in the
  report), a *no access* node is part of the game's own infrastructure. In
  v0.1 the database node is fixable.
- Changing database configuration is expected; changing SSH or anything
  marked DO NOT TAMPER is not. Whatever cannot be prevented is documented
  in place and in the starter pack, with the reason.
- **Envelopes**: knob values must stay within their envelopes. An initial
  value may lie outside its envelope; the validator is then red from the
  start, and that is a finding. Validators are not monitoring tools:
  players may run them to make sure they have not broken the game.
- A validator the players cannot make green is itself a defect to report.

## 15. The v0.1 scenario

- Topology: `bastion` and one static PostgreSQL node, on one overlay
  network; only the bastion's SSH port is published.
- Data: a small, simple schema loaded from `data/<node>.sql`, standing for
  a restored backup.
- Defects: only in the database and its configuration, visible without any
  activity (configuration, schema and indexes, roles and security, state
  frozen into the data). At least one known and one hidden.
- Issues: at least one *report* or *propose* issue and at least one *fix*
  issue; an *improve* issue is optional.
- Candidate defects, to be chosen when the folder is written: `trust`
  authentication for remote connections in `pg_hba.conf`; an application
  role with superuser rights; a memory setting outside its envelope; a
  missing index on a frequently joined column; autovacuum disabled on a
  table; a bloated table; an abandoned replication slot.
- The project lead reviews the chosen defects, issues and answer key
  before the scenario is accepted.

## 16. Architectural decisions and their reasons

- **Generic images, scenario files as Swarm configs copied once into a
  volume, state faults planted by the GM.** Configs need no registry and
  carry per-scenario content; they are read-only, hence the one-time copy
  that players can edit. Images stay free of spoilers. Rejected:
  per-scenario images (slow builds, spoilers inside images), configs as
  live files (not editable), bind mounts, nodes fetching files from a GM
  service.
- **The scenario folder is the source of truth, deployed through a
  per-playground local implementation**, so one scenario can be replayed
  on another playground and a restarted GM can ground itself.
- **Absolute limits and envelopes in v0.1**, because recomputing them per
  playground could silently undo a planted out-of-bounds value.
- **Limited `sudo` instead of `no-new-privileges`.** Reload and restart
  need privileges; a few fixed wrappers are the realistic DBA experience,
  and `no-new-privileges` would break setuid `sudo`.
- **s6-overlay** so that restarting PostgreSQL does not kill the container
  (Swarm has no pods or sidecars).
- **A `dba` superuser role**: realistic for a DBA audit; the light
  enforcement model accepts the operating-system access it implies.
- **Light enforcement of secrecy**: a "do not read" warning and the GM's
  own rules, nothing more; answers in the repository are like answers in a
  textbook.
- **Swarm first, Kubernetes portability required.** Cheap hedges are
  adopted now: stack files are always rendered from the scenario, platform
  operations live in one place (`gmctl`), bricks know nothing about Swarm,
  node names are valid Kubernetes names, injection scripts are idempotent
  and fed on stdin, image names are registry-qualified, and no mechanic
  relies on the routing mesh.
- **Explicitly invoked GM skill**, so the repository can be developed
  without every session becoming a game.
- **Python with the standard library and PyYAML, POSIX shell in nodes**:
  minimal dependencies for a small project.

## 17. Definition of done

1. The v0.1 scenario exists as a complete scenario folder written with the
   initial templates: bastion and one static PostgreSQL node, defects in
   the database and its configuration, at least one known and one hidden,
   at least one *report* or *propose* issue and at least one *fix* issue.
   Its scenario document opens with the "do not read" warning. The lead has
   reviewed its defects, issues and answer key.
2. In a GM session, the GM asks its setup questions, generates the local
   implementation (or says the capacity is insufficient), deploys, loads
   the data, plants the state faults, and hands over with the issues and
   their expected resolutions.
3. The players reach the database node only through the bastion; the
   write policy holds; the public validator runs through `sudo
   gm-validate`.
4. A manual play-through as `player` confirms that each fault's evidence is
   reachable as the answer key states, and that each *fix* issue can be
   fixed with the sealed check turning from 1 to 0: a *fix* issue on a
   configuration setting both by file and reload or restart and by `ALTER
   SYSTEM`, one on the schema or its indexes by the DDL statement that
   repairs it.
5. The stance passes this check-list:
   - a hint request is refused;
   - a reveal request is refused;
   - a node restart or reset request is refused;
   - a report not marked final makes the GM ask whether it is final;
   - a stop request is obeyed, and the game is torn down;
   - after a final answer, the feedback covers the issues found against
     the faults present, the acceptability of each answer, and what could
     have been done better.
6. A fresh GM session picks up a game in progress from the scenario folder
   and its local implementation.
7. A forced setup failure is reported, torn down, and its stage recorded;
   teardown leaves no service, network, config, secret or volume carrying
   the game's label.
8. Unit tests for the scripts pass, both images build, and every shell
   script passes a syntax check.
9. The owner judges the feedback tone at acceptance.

## 18. Deferred items and remaining questions

Consciously left open; none blocks v0.1.

- Which further steps become scripts once the GM generates scenarios (the
  choice of faults, the story, the solvability probe).
- Whether there is no project-wide mandatory machine check at all
  (no common lint, no schema check in the format skill), as currently
  read, and the solvability probe as a gate for generated scenarios.
- Promoting scenario-only bricks and faults into the catalog, and the
  review for it.
- How players reach monitoring web interfaces through the bastion (when
  monitoring arrives).
- Network layout and network-level faults; the technologies of each
  first-release role; aging defaults; the number and mix of faults and
  what difficulty means; whether starter documentation may itself carry
  faults; seeded variation per deployment; the brief's format; preparation
  time before a class; recording player actions; the language of
  player-facing material; whether feedback carries a score or is saved to
  a file; whether a lighter record of intent is wanted.
- Unverified platform details, to test while building: numeric-only
  owner ids in config mounts; the cross-host registry pattern; SSH Docker
  endpoints on Windows or macOS machines.
- The `sudo` hardening details (wrappers running as `postgres`, logging)
  and the capability list are set here for the build; the Kubernetes
  consequences (Pod Security "baseline", root supervisor) are for later
  versions to verify.
- Fixed at consolidation by the spec writer, for the lead to revisit: the
  script contracts (section 8.1), the `gmctl` subcommand set, the bastion's
  default port, storing per-game credentials in the git-ignored local
  implementation, the GM's `pg_hba.conf` line, and the candidate defect
  list.
