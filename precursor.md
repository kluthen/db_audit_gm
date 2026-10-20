# Precursor — what we know before writing the spec

This document gathers everything discussed before the project started: the
goal, the decisions already taken, the design proposals that still need
validation, the known technical pitfalls, and the open questions. It is the
input for the specification work, not a specification itself.

Markers used below:

- **[Decided]** — stated by the project owner; treat as a requirement.
- **[Proposed]** — suggested during the discussion, not yet validated.
- **[Open]** — needs a decision (also listed in the
  [Open questions](#14-open-questions) section).

---

## 1. Purpose and stakes

**[Decided]** The goal is to give students (and the teacher) *live*
experience of auditing and fixing a complex data stack: finding known
issues, discovering hidden ones, checking that monitoring and backups really
do what they claim.

**[Decided]** It is an exercise, not an adversarial CTF. Players have a
stake in learning, not in breaking the game. Prevention is applied where it
is practical; the rest is handled by trust and clear documentation.

---

## 2. Vocabulary

"Node" is ambiguous in a Swarm context. Proposed terms:

| Term | Meaning |
|---|---|
| **Host** | A Swarm node: a machine or VM running a Docker engine that is part of the swarm |
| **Node** | An element of the scenario topology (a database, a producer, the bastion…), i.e. a Swarm service, usually one container |
| **Brick** | A reusable, catalogued node definition: image, configuration, documentation, faults, validator |
| **Fault** | An issue planted in a scenario, either *known* (declared to the player as a customer complaint) or *hidden* |
| **Game master (GM)** | The agent (and the teacher) generating, deploying, aging and grading a scenario |
| **Player** | The student doing the audit |
| **Scenario** | One generated topology + faults + background, frozen into a manifest and an answer key |

---

## 3. Roles and planes

**[Decided]** The player only ever accesses the system through a bastion.
They must not interact with the swarm itself; doing so defeats the purpose
of the game.

**[Proposed]** Three separate planes:

| Plane | Who | Has access to |
|---|---|---|
| Infrastructure | Game master only | Swarm managers, Docker API, stack files, registry, answer key |
| Scenario | Frozen artifact | Topology, resource budgets, declared and hidden faults, aging plan |
| Player | Student | Bastion, SSH to nodes with restricted rights, monitoring UIs |

Notes:

- Access to a Swarm manager's API is effectively root on every host. No
  Docker socket, no manager credentials, ever, on the player side.
- The bastion itself is a node of the topology (a Swarm service), on a
  management network.

---

## 4. Scenario lifecycle

**[Decided]** Generation is fully automated by the agent, with optional
inputs from the teacher:

- the scenario's background (the customer's story, context);
- the list of incidents that must be found;
- whether the agent is allowed to add more incidents of its own.

**[Proposed]** Lifecycle stages:

1. **Brief** — teacher input (background, required incidents, freedom given
   to the agent, difficulty, session length, number of players).
2. **Generation** — the agent picks bricks (or builds new ones), lays out the
   topology, assigns resources, chooses faults.
3. **Freeze** — output is written as a versioned *scenario manifest* (stack
   file, image references, configuration) plus a *sealed answer key*. An
   agent is non-deterministic: freezing makes a scenario redeployable,
   comparable between students, and reviewable.
4. **Checks before deployment** — budget fits, bricks pass the lint, every
   hidden fault passes the solvability probe (see §9).
5. **Deployment** on the swarm.
6. **Aging** — the system runs, or is given a history, so that faults leave
   traces (see §10).
7. **Hand-over** — the player receives the starter pack (see §5).
8. **Session** — up to 4 hours.
9. **Grading** — sealed checks run from the infrastructure plane, plus review
   of the audit report (see §12).
10. **Teardown** (possibly after snapshotting the final state for grading).

**[Decided]** Usually one scenario per class; sometimes one per student.
**[Open]** Whether "one scenario per class" means one shared deployment or
one deployment of the same scenario per student (big resource implications,
see §6).

---

## 5. Player experience

**[Decided]** At the start, the player gets:

- access to the bastion;
- legal access to every node of the topology, but **not necessarily write
  access everywhere**: on some nodes (e.g. producers and consumers) they can
  only observe and report findings;
- access to every monitoring tool included in the stack (pgwatch, Grafana,
  …), which may or may not be correctly configured;
- at the very least, a list of all node addresses (worst case);
- ideally, a short documentation of the topology and a rough description of
  what is going on in the system.
- players are incarnating DBA, with low/mid programming experience.

**[Proposed]**

- Each node has a **write policy**: *fixable* (configuration changes
  expected), *report-only* (read access, findings go in the report), or
  *no access* (e.g. the game's own infrastructure).
- The starter documentation could itself be a vector for faults (stale or
  partly wrong documentation is a classic audit finding). To be decided per
  scenario.
- Provide names rather than raw IPs where possible: in Swarm, container IPs
  on overlay networks change on restart and static addresses are not
  supported by `docker stack deploy` (to be verified). DNS names are stable.

---

## 6. Resources and nerfing

**[Decided]**

- Every scenario must fit in the swarm's CPU and memory capacity.
- Databases are deliberately nerfed: limited CPU, low memory, small
  `work_mem`/buffers, etc.
- The data schema stays simple and the tables small. Complexity comes from
  the topology and the faults, not from data volume.
- Each scenario includes a few producers and consumers generating activity.

**[Proposed]**

- Choosing bricks is a knapsack problem: sum of reservations ≤ capacity minus
  headroom. Monitoring is not free (Grafana, pgwatch and its own database
  count in the budget).
- Producer load must be calibrated **against the nerfed databases**: enough
  to show contention and symptoms, not enough to saturate the host.
- Distinguish:
  - **hard limits** — cgroup limits set by Swarm (`deploy.resources`). Not
    changeable by the player. Exceeding them self-punishes (OOM kill), which
    is realistic.
  - **soft settings** — engine configuration (`postgresql.conf`, `my.cnf`, …)
    the player may edit within bounds checked by the validator.

**[Open]** Target hosting capacity. The only machine identified so far is a
Windows workstation running Docker Desktop with a WSL2 VM of 10 CPU / 11 GB,
which is a poor Swarm host (see §11).

---

## 7. Rules and validators

**[Decided]**

- Some settings cannot be altered beyond certain thresholds, so that the
  system keeps working within limited CPU and memory.
- This does **not** mean the fix can't be to raise a setting: the native
  configuration may have been set badly to begin with. Bounds are an
  envelope, not the initial value. The initial value may even lie outside
  the envelope; that is then a finding in itself.
- Every node has a way to check that the player's changes are within bounds
  (a local validator). A full clear of the exercise requires every local
  validator to be green.
- Access is limited: the default configuration (SSH etc.) gives access to the
  information needed, but does not allow the system's behaviour to be altered
  beyond what is acceptable. Changing a database's configuration files is
  expected; changing SSH behaviour is not.

**[Decided]** Trust model: some tampering cannot be prevented in practice.
Those cases must at the very least be heavily documented, in place and in
the player documentation (`DO NOT TAMPER WITH THIS`, with the reason).

**[Proposed]** Split checks in two to avoid the validator becoming an oracle
(a player running every validator would otherwise locate the hidden faults
without auditing anything):

1. **Public validators** (on each node, runnable by the player): check the
   *rules* — values within bounds, protected files unchanged (hash check,
   tamper-evident rather than tamper-proof), service healthy. They reveal
   nothing about the scenario's faults.
2. **Sealed checks** (run by the GM from the infrastructure plane): check the
   *answer key* — fault X detected / fixed.

The official grading run of the public validators should also come from the
infrastructure plane, so that a locally modified validator does not matter.

**[Open]** Whether a red public validator at the start of a session is
acceptable (it hints that the node's initial configuration is out of bounds).

---

## 8. Access control on nodes

**[Proposed]**

- Read-only root filesystem where Swarm supports it; writable volumes only
  where changes are legitimate (database configuration, a crontab, backup
  tool configuration). "What may change = what is writable" is clear and
  enforceable. (Swarm support for each option to be verified.)
- A non-root player account, `no-new-privileges`, no extra capabilities.
- `sudo` limited to a few wrappers (e.g. `gm-reload-db`, `gm-restart-db`).
- **Restart problem**: some settings (e.g. PostgreSQL `shared_buffers`)
  require a restart. If the database is PID 1, restarting it kills the
  container. Nodes therefore need a process supervisor (e.g. s6-overlay)
  running the service and `sshd`. Swarm has no pods or sidecars, so
  multi-process containers are hard to avoid.
- Protected files (`sshd_config`, validators, the game's own cron jobs and
  scripts) belong to root, are read-only for the player, and are listed in
  the public validator's hash check.
- Secrets are distributed through Swarm secrets, environment variables, or
  generated `.pgpass`-style files. Never a connection string with an embedded
  password.

---

## 9. Faults

**[Decided]**

- The agent builds the full topology, declares several issues (known to the
  customer) and hides a few. Examples given: a pgBackRest stanza that doesn't
  actually work; a daily script that never runs (badly configured cron job or
  similar).
- The teacher may impose a list of incidents and decide whether the agent may
  add more.

**[Proposed]** Each fault declares:

- the brick(s) it applies to and its preconditions;
- *known* or *hidden*;
- severity;
- an **evidence path**: where a player with *their* rights can see it (log,
  system view, tool output, dashboard);
- a **fix check** (sealed), or "report-only" if the node is not fixable;
- interactions with other faults.

**Solvability probe** (the most important automated check): for every hidden
fault, the generator runs a probe *as the player user* confirming the
evidence is actually reachable. Without this, the agent will eventually plant
a fault that is undetectable and the scenario becomes unfair without anyone
noticing.

**Interactions**: monitoring that lies can hide a performance fault. That is
a good layered trap when intended, an unfair one when accidental. The
generator must declare such dependencies explicitly.

Example families (non-exhaustive):

| Family | Examples |
|---|---|
| Backups | stanza mismatch; `archive_command` failing but returning 0; retention purging too early; restore never tested |
| Scheduled jobs | unescaped `%` in crontab; missing final newline; wrong `PATH`; wrong time zone; script not executable |
| Monitoring that lies | collector pointed at the standby; alert threshold in the wrong unit; one host not collected |
| Security | `trust` in `pg_hba.conf`; application role with superuser; secrets readable by everyone |
| Performance | missing index; autovacuum disabled on a hot table; bloat; bad memory settings |
| Replication | lag; abandoned replication slot filling the disk |
| Data flow | consumer producing duplicates; producer silently dropping records; transformer running on stale input |
| Versions | outdated engine needing a minor hotfix or a major upgrade |

---

## 10. Aging

**[Decided]** Some aging is required: many faults (e.g. "a daily script
never runs") have no visible symptom on a freshly deployed system.

**[Proposed]** Two complementary techniques:

- **Pre-aging**: run the system for a while before hand-over, and/or forge a
  history (logs, a last successful backup dated days ago, accumulated bloat,
  a slot retaining WAL, timestamps).
- **Time compression**: schedule "daily" jobs every few minutes during the
  session, so the player can observe and verify a fix within a 4-hour
  session.

Each fault should state which technique makes its evidence visible.

---

## 11. Docker Swarm notes and pitfalls

What Swarm provides:

- Managers (cluster state, API) and workers; services whose tasks are
  scheduled on hosts; placement constraints and host labels.
- Overlay networks spanning all hosts (VXLAN); a service can join several
  networks, which makes dual-homed nodes natural pivots between zones.
  Overlays can be encrypted (`--opt encrypted`). Standalone containers need
  `--attachable` networks.
- Embedded DNS: `service` resolves to a virtual IP, `tasks.service` to the
  individual tasks.
- Swarm secrets and configs, mounted into containers.

Pitfalls:

- **Docker Desktop is a poor Swarm host**: the engine runs inside a NAT'd
  WSL2 VM; Swarm ports (2377/tcp, 7946/tcp+udp, 4789/udp) and
  `--advertise-addr` are hard to get right, and overlays between it and other
  machines are unreliable. Alternatives: several `docker:dind` containers
  forming a swarm on one machine (cheap, disposable), or real Linux VMs
  (more realistic, heavier).
- **Never use an existing production swarm** to host or test scenarios.
- **Compose vs. stack**: `build:` is ignored by `docker stack deploy` (images
  must come from a registry reachable by every host, e.g. a local
  `registry:2` service); `depends_on` is ignored; named volumes are local to
  each host, so stateful nodes must be pinned with placement constraints.
- **Routing mesh**: a published port is open on *every* host, even those not
  running the service. Can be used deliberately as an exposure fault.
- **Overlay overhead**: VXLAN adds latency and jitter; performance numbers
  measured in the game are not comparable with bare-metal measurements.

---

## 12. Grading and deliverables

**[Proposed]**

- Full clear = every public validator green (official run from the
  infrastructure plane) + sealed checks + the **audit report**.
- The report follows a template (to be written, in English); it is graded
  against the answer key, possibly by an agent with a rubric.
- Partial credit per fault: detected / correctly diagnosed / fixed (or
  correctly recommended when the node is report-only).

---

## 13. The catalog (repository growth)

**[Decided]** The repository hosts a growing database of Dockerfiles,
configurations and documentation for clean and faulty nodes, expected to
grow over time: older database versions (requiring upgrades or hotfixes),
new technologies (e.g. dbt + DuckDB), etc. The agent can pick bricks from it
but is also allowed to build its own, following a few guidelines.

**[Proposed]** Brick contract — each brick declares:

- image(s) and supported versions;
- footprint: CPU / memory limits and reservations;
- **knobs**: settings the player may change, with their bounds;
- injectable faults (see §9);
- its public validator;
- what it exposes to monitoring;
- its write policy options (fixable / report-only);
- player-facing documentation and GM-facing documentation (kept apart, so
  spoilers never ship to the player side).

**[Proposed]** A **brick lint** that any brick (catalogued or agent-built)
must pass: footprint declared, validator present, no privileges, no Docker
socket, protected files listed, documentation present. **[Open]** Whether an
agent-built brick stays scenario-local or can be promoted into the catalog,
and through which review.

Initial technology scope mentioned: PostgreSQL (primary, standby, PITR,
pgBackRest, PgBouncer), MySQL, DuckDB, TimescaleDB, dbt, pgwatch, Grafana,
pgBadger / pgCluu, a message queue for producers (NATS, Redpanda, …).

---

## 14. Prior art: the earlier PostgreSQL lab

A private earlier project (a docker compose PostgreSQL workshop lab) serves
as inspiration, not as a base. Practices that transfer:

- No bind mounts; configuration baked into images (works well with a remote
  Docker engine and with Swarm, where bind mounts point at the host's disk).
- One image per engine version for both server and client tools, so versions
  stay consistent.
- Secrets only through environment variables or generated `.pgpass` files.
- A continuous load generator, and a separate GM-only file listing the
  deliberate traps (spoilers kept away from players).
- Monitoring and reporting tools included in the stack (pgwatch, Grafana,
  pgCluu, pgBadger) and a backup tool (pgBackRest).

---

## 15. Open questions

1. **Hosting**: which machines host the swarm? `dind` hosts on one machine,
   VMs, or several physical machines? How many hosts per scenario?
2. **Capacity vs. class size**: for a class, one shared deployment or one
   deployment per student? With ~10 CPU / 11 GB, per-student deployments
   limit either class size or scenario size.
3. **Validators**: are red public validators at the start acceptable? How
   much do they reveal?
4. **Fix vs. report**: beyond per-node write policy, is fixing graded at all,
   or is the report the main deliverable?
5. **Grading**: rubric, partial credit, who grades the report (teacher,
   agent, both)? Snapshot of the final state before teardown?
6. **Teacher brief format**: a structured file (YAML?) with background,
   required incidents, freedom given to the agent, difficulty, length?
7. **Agent-built bricks**: scenario-local only, or promotable to the catalog?
   Review gate?
8. **Determinism**: seeds per student to vary details (names, values) within
   the same scenario, to discourage copying?
9. **Starter documentation**: always accurate, or can it contain deliberate
   inaccuracies as faults?
10. **During the session**: hints, reset of a broken node, extra time? Who
    can trigger them?
11. **Aging strategy per fault**: pre-aging, forged history, time
    compression — what's the default?
12. **Process supervision**: s6-overlay or another supervisor as a standard
    base for every node image?
13. **Version matrix**: which engines and versions first; how are upgrade
    scenarios (both binaries, disk space) handled under the resource budget?
14. **Player credentials**: how are they generated and distributed?
15. **Where the generator agent runs** and which tools and permissions it
    has on the infrastructure plane.
16. **Network faults**: are network-level issues (wrong segmentation,
    exposed ports through the routing mesh) in scope?



