# Game lifecycle

Status: draft v9

From setup to teardown, as run by the GM in its agent session: the
scenario, its local implementation, checks, deployment, aging, hand-over,
the game, the final answer and the feedback. What the scenario files contain is in
[formats.md](formats.md); who may touch what is in
[planes-and-access.md](planes-and-access.md).

A **game** is one deployment of one scenario, played behind one report
(D8). Whether one student or a whole class sits behind that report is
outside the project's concern.

## Stages

1. **Setup** — among its first questions, the GM asks for the playground:
   the swarm, its hosts and access keys, and the capacity available (D7,
   D16; see [platform.md](platform.md)). It takes the initiator's brief if
   there is one.
2. **Scenario** — either an existing scenario folder is chosen (a
   hand-written one in v0.1, or one kept in the repository), or the GM
   designs a new one: it starts from whatever the initiator gave (see
   "Setup inputs and the brief"), fills in every blank (topology,
   background story, data schema, defects, issues), and picks bricks and
   faults from the catalog or builds new ones. A new scenario is written as
   a self-sufficient scenario folder ([formats.md](formats.md), D23).
3. **Local implementation** — the GM maps the real playground onto the
   scenario: resource limits, placement, host count, the game id, and the
   rendered platform files (in v0.1 it checks the fit without recomputing
   anything, D32). It adapts the scenario to the
   playground as long as capacity is sufficient; if it isn't, it says so
   and does not deploy (D16, D23).
4. **Pre-deployment checks** — the GM runs the checks each brick ships, if
   any (D28).
5. **Deployment** on the playground, from the local implementation. When
   the topology has monitoring, the GM configures each node's health
   script at initialisation, with the services it watches there (D66).
6. **Data and aging** — restored-backup data is loaded, then state faults
   are planted; the system runs, or is given a history, so that faults
   leave traces (see "Aging"). v0.1 has no aging: it loads the data and
   plants its state faults right after deployment (D39).
7. **Solvability probes** — every hidden fault's evidence is confirmed
   reachable as the player user (proposed for generated scenarios; not in
   v0.1, where a manual play-through stands in, D38; see
   [bricks-and-faults.md](bricks-and-faults.md)).
8. **Hand-over** — the player receives the starter pack and the issues.
9. **The game** — up to 4 hours.
10. **Final answer and feedback** — see "End of the game" and
    [gm-stance.md](gm-stance.md).
11. **Teardown** — everything carrying the game's stack label is removed:
    services, networks, configs, secrets and volumes. Images and the swarm
    stay (D36).

Every volume, config, secret and network is named after the game id, so a
redeploy never reuses a player-edited volume (D36).

Anyone in the GM session may ask the GM to stop the game at any stage; the
GM then tears the game down. If setup fails (deployment, data load or
injection, a health check that never passes) or is stopped, the GM reports
it, tears down what it deployed, and records the stage reached in the
local implementation (D36). How long stages 2 to 7 may take before a
class: O30. Which stages are scripts and which agent judgment: O2.

## Setup inputs and the brief

The only required input is the **playground**: the swarm and its hosts
(with access keys), and the capacity available on them: CPU, RAM and disk
(D16). The GM needs it to size the setup.

Everything else is the **brief**, optional, given by the initiator (the
teacher, or a student playing alone). It may broach any of: the topology,
the background story (the customer, the context), the data schema, the
incidents that must be planted and whether the GM may add more, difficulty,
session length, number of players. Each may be fully stated, only sketched,
or left out; the GM fills in the blanks (D16). Once the game is set up the
teacher is out of it (D6). Format of the brief: O29. What "difficulty"
means: O23.

## The scenario and its local implementations

The GM is non-deterministic, so a scenario is written down once as a
self-sufficient folder: the source of truth, enough with the GM persona and
skills to start the exercise again, after a session restart or on another
playground (D20, D23). Switching playgrounds does not break it: the GM
generates a new local implementation for each playground, as long as
capacity is sufficient. See [formats.md](formats.md). Whether variation
(names, values) is seeded per deployment: O24.

## Aging

Some aging is required: many faults (e.g. "a daily script never runs") have
no visible symptom on a freshly deployed system.

Techniques (proposed), complementary:

- **Pre-aging** — run the system for a while before hand-over, and/or forge
  a history: logs, a last successful backup dated days ago, accumulated
  bloat, a replication slot retaining WAL, timestamps.
- **Time compression** — schedule "daily" jobs every few minutes during the
  game, so the player can observe a fault and verify a fix within the
  session.

Each fault instance states which technique makes its evidence visible
([formats.md](formats.md)). v0.2 has no aging: with no load, history
builds during the game (D83). The default technique: O22.

Consequence to settle with O22: time compression is visible. A crontab
reading `*/5` for a "daily" backup is itself something an auditor would
flag, it collides with schedule faults (wrong time zone, job that never
runs), and a forged history dated "days ago" must stay consistent with a
compressed clock.

## Hand-over: the starter pack

The player gets:

- access to the bastion (credentials: D31);
- legal access to every node of the topology, but not write access
  everywhere (see [planes-and-access.md](planes-and-access.md));
- access to every monitoring tool in the stack (Grafana, Prometheus, …),
  which may or may not be correctly configured, with the web interfaces
  published by the bastion's web front and opened with the per-game tools
  password (D68, D77, D79). A topology may have no
  monitoring at all, and how well it is tooled can be a finding (D65);
- at the very least, a list of all node names;
- ideally, a short documentation of the topology and a rough description of
  what is going on in the system;
- zero or more **issues**, each stating its expected resolution: *report*
  (diagnose and report), *propose* (recommend a concrete fix without
  applying it), *fix* (alter the system so it works), *improve*
  (alter it so it works better).

Nodes are addressed by name, not IP: overlay IPs change on restart (see
[platform.md](platform.md)). Whether the starter documentation may itself
carry faults: O21. Language of player-facing material: O32.

## The game

Up to 4 hours. No hints, node resets or extra time for now (D19), and in
v0.1 the players' only interaction with the GM is the report (D18); see
[gm-stance.md](gm-stance.md). Whether player actions on nodes are
recorded (shell history, audit trail): O31.

## End of the game

Grading is left to the GM (D9). The players hand in a final answer, the GM
checks it against the answer key and the live system before teardown, and
gives feedback. The rules for all of this, and the tone, are in
[gm-stance.md](gm-stance.md).
