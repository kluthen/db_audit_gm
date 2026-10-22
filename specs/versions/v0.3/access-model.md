# db_audit_gm v0.3 — Access model

Status: **approved by the owner on 2026-10-22** with the
[master spec](master-spec.md) it accompanies (spec D154), as consolidated
the same day and revised after an independent review, the owner's
answers to it and its re-review's corrections; amended the same day by
the ruling that only a scenario with scheduler nodes ages (spec D157,
D158: section 6, `aging-done`). Revises the [v0.2 access model](../v0.2/access-model.md),
which it replaces for v0.3 games; "Changes from v0.2" at the end lists
what moved.

## 1. Purpose and scope

This governs who may do what in one v0.3 game: in the GM session, on the
bastion and its web front, on every node of the topology (the database,
PgBouncer, the scheduler nodes, Prometheus, Grafana, the exporter), in
the database and the PgBouncer console, over the load, and in the
monitoring interfaces. It does not cover who may run the GM or read the
repository (anyone with the repository can), the security of the hosts
the game runs on, or the Docker engine, which the players never touch.

Enforcement is deliberately light. Rules the system enforces say so; the
rest rely on trust and on documentation in place ("DO NOT TAMPER", with
the reason).

## 2. Actors

| Actor | Definition | How acquired | Stacks? |
|---|---|---|---|
| `initiator` | Whoever starts the game with the GM: a teacher, or a student playing alone | Invokes the GM skill in an agent session | Yes: a student playing alone is also a `player` |
| `player` | A student taking part in the game; one or many sit behind one report | Receives the bastion password, and the tools password when the game has a web interface, from the GM at hand-over | Yes, with `initiator` (solo play) and `session-participant` |
| `session-participant` | Anyone typing in the GM session, whatever their other role | Has the session in front of them | Yes |
| `gm` | The agent running the GM skill (non-human), with the scheduled `gmctl` runs it sets up during the aging | Started by the initiator invoking the GM skill | No: exclusive |
| `network-visitor` | Anyone who can reach the hosts' networks, unauthenticated | Default state | No: exclusive |

Roles are scoped to one game. The `player` role is shared: all players of
a game use the same accounts and the same two passwords.

Service accounts are not actors; they act only as configured, and their
credentials are resources below: the exporter's monitoring role, the
schedulers' application roles, PgBouncer's lookup role, Grafana's data
source connections, and the GM check role (which acts only for the
`gm`).

## 3. Role assignment and lifecycle

- The `gm` exists from the moment the initiator invokes the GM skill; a
  fresh session invoking it on a game in progress resumes that game.
  It starts the load in its session at T0. Between sessions, during the
  aging, it acts only through the setup actions it scheduled (planting
  the faults due during the aging, the early check), which record a
  failure and never tear the game down.
- The `initiator` role ends at hand-over. After that the initiator acts
  only as a `session-participant`, or as a `player` in solo play.
- The `player` role is granted by handing over the per-game bastion
  password and, when the topology has a web interface to publish, the
  tools password with it; neither can be revoked or rotated during a
  game. Without a web interface the web front does not run and its rows
  below do not apply.
- **A restart keeps the `player` role**: the rebuilt game keeps every
  generated secret, the players' credentials included, under a new game
  id, whose new Swarm secret objects carry the same values. It enters the
  stage `handed-over`, and the hand-over snapshot stays, so a second
  restart starts from it again.
- Every role ends at teardown: the game's services, secrets (every
  password included), volumes and hand-over snapshot are removed (the
  snapshot only then, never by a restart), so the
  credentials stop working immediately.
- A stop request mid-game takes effect immediately; work in progress on
  the nodes and in the interfaces is lost.

## 4. Resources and operations

| Resource | Operations |
|---|---|
| Game control (the GM session) | `start`, `stop`, `restart`, `report`, `request-help` (hint, reveal, node reset, extra time) |
| The load | `start-load`, `control-load` (pause, speed up, trigger, run now) |
| Setup actions during the aging | `schedule` (plant a fault at a moment, the early check), `hand-over` |
| Hand-over snapshot | `take`, `restore` |
| Scenario folder (repository) | `read`, `edit` |
| Answer key and GM notes | `read` |
| Bastion | `login`, `use` (shell, `ssh`, `scp`, `sftp`, `psql`) |
| Web front | `reach` |
| Node shell (any node but the bastion) | `login`, `read-files`, `run-wrapper` (reload, restart, validate) |
| Node configuration files (seed-once copies) | `read`, `edit` |
| Node protected files (including the node-health script and its service list) | `read`, `edit` |
| Scheduler query repository (`queries.yaml`, `builders/`) | `read`, `edit` |
| Scheduler fixed-time operations (`jobs.yaml`) | `read`, `edit` |
| Scheduler schedule (`schedule.yaml`) | `read`, `edit` |
| Scheduler log and other configuration | `read` |
| Scheduler metrics endpoint, node-health endpoint | `read` |
| Database (PostgreSQL) | `connect`, `query`, `alter-system`, `ddl` |
| PostgreSQL log files and pgBadger | `read-logs`, `run-pgbadger` |
| The GM's connection reserve | `connect-reserved` |
| Service credentials (monitoring role, application roles, PgBouncer lookup role, GM check role) | `read` |
| PgBouncer console | `show` (pools, stats, clients), `admin` (set, reload, pause, kill, shutdown) |
| Prometheus interface | `view` (query, targets, alerts), `admin` (admin and lifecycle endpoints) |
| Grafana interface | `view`, `edit-content` (dashboards, data sources, alert rules), `administer` (users, the administrator's password, organisation settings) |
| Swarm and Docker engine | `any` |

## 5. Permission matrix

**Game control**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| `start` | allow | deny | deny | allow | deny |
| `stop` | allow | allow | allow | allow | deny |
| `restart` | deny | `confirmed-in-session` | deny | `players-confirmed` | deny |
| `report` | deny | `in-session` | `in-session` | deny | deny |
| `request-help` | deny | deny | deny | deny | deny |

**The load and the setup actions**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| `start-load` | deny | deny | deny | `before-hand-over` | deny |
| `control-load` | deny | deny | deny | deny | deny |
| setup action `schedule` | deny | deny | deny | `before-hand-over` | deny |
| `hand-over` | deny | deny | deny | `aging-done` | deny |
| snapshot `take` | deny | deny | deny | `at-hand-over` | deny |
| snapshot `restore` | deny | deny | deny | `players-confirmed` | deny |

**Scenario folder and answer key**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| scenario folder `read` | `has-repository` | `has-repository` | `has-repository` | allow | deny |
| scenario folder `edit` | `has-repository` | deny | deny | allow | deny |
| answer key `read` | `has-repository` | `has-repository` | `has-repository` | allow | deny |

**Bastion and web front**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| bastion `login` | `holds-password` | allow | `holds-password` | allow | deny |
| bastion `use` | `holds-password` | allow | `holds-password` | allow | deny |
| web front `reach` | `holds-tools-password` | allow | `holds-tools-password` | allow | deny |

**Nodes** (every node but the bastion: the database, PgBouncer, the
scheduler nodes, Prometheus, Grafana, the exporter)

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| shell `login` | deny | `from-bastion` | deny | allow | deny |
| shell `read-files` | deny | `from-bastion` | deny | allow | deny |
| shell `run-wrapper` | deny | `from-bastion` | deny | allow | deny |
| configuration `read` | deny | `from-bastion` | deny | allow | deny |
| configuration `edit` | deny | `fixable-file` | deny | allow | deny |
| protected files `read` | deny | `from-bastion` | deny | allow | deny |
| protected files `edit` | deny | deny | deny | allow | deny |
| node-health endpoint `read` | deny | `in-game-network` | deny | allow | deny |

**Scheduler nodes**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| query repository `read` | deny | `from-bastion` | deny | allow | deny |
| query repository `edit` | deny | `fixable-file` | deny | allow | deny |
| fixed-time operations `read` | deny | `from-bastion` | deny | allow | deny |
| fixed-time operations `edit` | deny | `fixable-file` | deny | allow | deny |
| schedule `read` | deny | deny | deny | allow | deny |
| schedule `edit` | deny | deny | deny | deny | deny |
| log and other configuration `read` | deny | `from-bastion` | deny | allow | deny |
| metrics endpoint `read` | deny | `in-game-network` | deny | allow | deny |

**Database, its logs and PgBouncer**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| database `connect` | deny | `from-bastion` | deny | allow | deny |
| database `query` | deny | `from-bastion` | deny | allow | deny |
| database `alter-system` | deny | `fixable-node` | deny | allow | deny |
| database `ddl` | deny | `from-bastion` | deny | allow | deny |
| `read-logs` | deny | `from-bastion` | deny | allow | deny |
| `run-pgbadger` | deny | `from-bastion` | deny | allow | deny |
| `connect-reserved` | deny | deny | deny | allow | deny |
| service credentials `read` | deny | deny | deny | allow | deny |
| PgBouncer console `show` | deny | `from-bastion` | deny | allow | deny |
| PgBouncer console `admin` | deny | deny | deny | allow | deny |

**Monitoring interfaces**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| Prometheus `view` | `holds-tools-password` | `through-web-front` | `holds-tools-password` | allow | deny |
| Prometheus `admin` | deny | deny | deny | deny | deny |
| Grafana `view` | `holds-tools-password` | `through-web-front` | `holds-tools-password` | allow | deny |
| Grafana `edit-content` | deny | `fixable-grafana` | deny | allow | deny |
| Grafana `administer` | deny | deny | deny | allow | deny |

**Swarm and Docker engine**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| `any` | `owns-host` | deny | deny | allow | deny |

## 6. Conditions

| Condition | Holds when |
|---|---|
| `in-session` | The answer is handed in within the GM session (pasted, by discussion, or by pointing the GM at `~/report.md` on the bastion) |
| `confirmed-in-session` | A player in the GM session confirms the restart in so many words, after the GM has stated that the game's state and the players' changes are lost and, when the game has no hand-over snapshot, which evidence goes with them. A passing mention or a question about restarting is not a confirmation |
| `players-confirmed` | A player's confirmation under `confirmed-in-session` has been given and recorded by the GM in the local implementation, with the player's words (`gmctl restart --confirmation`) |
| `before-hand-over` | The game has not been handed over yet: from deployment to the end of the aging, or to the hand-over in a game with no aging |
| `aging-done` | The earliest hand-over is reached: the scenario's aging minimum since T0, moved later by the lost time beyond thirty minutes (outage minutes up to thirty in all do not move it), and every fault instance's own minimum since its planting. In a game with no scheduler node, which has no aging (spec D157), it holds once the faults are planted |
| `at-hand-over` | `aging-done` holds and the starter pack is not yet handed over |
| `has-repository` | The actor has a copy of the repository. Not enforced: students are asked not to read scenarios, and a warning heads each scenario document |
| `holds-password` | The actor knows the game's bastion password (a teacher who also plays, for example) |
| `holds-tools-password` | The actor knows the game's tools password and reaches the bastion's web front port with it |
| `from-bastion` | The connection comes from the bastion, as user `player`, with the game's key (SSH) or the `dba` password (PostgreSQL, and the PgBouncer console, where `dba` is the players' console role) |
| `fixable-node` | `from-bastion` holds and the node's write policy is *fixable* |
| `fixable-file` | `from-bastion` holds and the file is fixable: the node's write policy is *fixable*, or the scenario's write overrides make that path fixable on a report-only node |
| `in-game-network` | The request comes from a node of the game (the bastion or any other node), where only players and the GM have a shell |
| `through-web-front` | The request passes the web front with the tools password; from inside the game network, Prometheus' `view` is also reachable directly, since it has no login of its own |
| `fixable-grafana` | `through-web-front` holds and the Grafana node's write policy is *fixable*. On a report-only Grafana node it is not enforced: see "Known gaps" |
| `owns-host` | The initiator controls the Docker hosts (it gave the GM their endpoints). Players must not use them; not enforced when they own them |

## 7. Denial behaviour

Every forbidden resource in a game stays visible: nothing is hidden from
listings, a denied action is refused where it is attempted.

| Operation class | Behaviour | Rationale |
|---|---|---|
| `request-help` in the GM session | Visible refusal: the GM declines briefly and politely and points back to the system | The stance is part of the exercise; the refusal itself teaches |
| Questions that would reveal answers, before the final answer | Visible refusal, as above | No reveals before the final answer |
| `restart` without a confirmation | Not refused outright: the GM states what a restart loses (and, without a snapshot, which evidence) and asks for a confirmation in so many words; anything less leaves the game running | A restart is highly breaking; a passing comment must never trigger it |
| `restart` asked by someone who is not a player | Visible refusal: the GM says only a player of the game may confirm a restart | The players' work is what is lost |
| `control-load` (pause, speed up, trigger, run now), by anyone | Visible refusal in the session; on the nodes no tool or wrapper offers it | The evidence must come from the schedule, never from an intervention |
| `start-load`, a setup action, `hand-over` or a snapshot, asked by anyone but the GM | Visible refusal in the session: the GM runs the setup itself; on the nodes no tool or wrapper offers them | The setup is the GM's |
| `start-load` or a setup action `schedule` after hand-over | Refused by `gmctl`; a restart's own setup, inside `gmctl restart`, is not affected | The schedule is fixed once the game starts |
| Schedule `edit` on a node, by anyone | No `gmctl` verb or wrapper edits it; for players, ordinary "permission denied". The GM changes a schedule only in the scenario folder, for the next game | No events outside the schedule, during the aging included |
| `hand-over` before the earliest hand-over | The GM refuses and says when the game can be handed over | Faults need their history |
| `hand-over` with the hand-over check failing | The GM does not hand over: it re-plants a fault whose planting failed when its aging minimum can still be reached, otherwise offers the initiator to set the game up again (stop, then start) | A game missing its evidence is not playable |
| Snapshot `take` outside `at-hand-over` | Refused by `gmctl snapshot`: before the earliest hand-over, or once the game is handed over, when it would capture the players' changes | One snapshot, of the system as handed over |
| `report` not stated as final | Not refused: the GM asks whether it is the final answer | The final-answer rule |
| `start` by a non-initiator mid-game | The GM explains a game is in progress and offers to resume it | One game per local implementation |
| Bastion or node login without valid credentials | Ordinary SSH refusal | Standard behaviour |
| Web front without the tools password | HTTP 401 with a basic-authentication challenge | Standard behaviour |
| Editing protected files, the node-health script or its service list | Ordinary filesystem "permission denied" (read-only, root-owned) | Enforced by the system |
| Editing a configuration file, repository or `jobs.yaml` that is not fixable | Ordinary "permission denied"; the reload wrapper of a report-only node refuses with a one-line reason | Enforced by the system |
| Reading `schedule.yaml` | Ordinary "permission denied" (root-owned, mode 0400); the file is visible in listings. The scheduler's root run script passes it to the program on standard input, so the service account cannot read it either | Visible but blocked, as a real customer's traffic would be |
| `connect-reserved` and service credentials | Ordinary "permission denied" on the secret files (root or the service's account only); without the check role's password the reserve is out of reach | Enforced by the system |
| PgBouncer console `admin` | Refused by PgBouncer: the players' console role is not in `admin_users` | Enforced by the system |
| Prometheus `admin`, through the web front or from inside the game network | Refused by Prometheus: its admin and lifecycle endpoints are disabled, as in v0.2; the hand-over snapshot stops it briefly instead | Reloads go through the node's `sudo` wrapper, under the write policy |
| Grafana `edit-content` on a report-only Grafana node | Not refused: Grafana lets an administrator edit | Known gap, accepted |
| Grafana `administer` | Not refused by Grafana; forbidden by the rules and marked DO NOT TAMPER, since changing the administrator's password would lock the GM's checks out | Trust where it cannot be enforced |
| `alter-system` on a report-only database node | Would not be refused, the `dba` role being a superuser; does not arise in v0.3, where `postgres` is fixable only | Accepted on the trust line |
| `network-visitor` reaching anything but the bastion's ports | Nothing listens: no other port is published, on a multi-host playground the bastion publishes on its own host only, and no registry runs (images are copied between hosts over SSH) | Bastion-only rule |
| Docker engine use by players | Not reachable from the bastion or nodes; on a host the players own, documented as forbidden | Trust where it cannot be enforced |

Denials are not logged by the game, except `sudo` uses, which `sudo`
logs on each node. Repeated denials have no effect.

## 8. Elevation, delegation and non-human actors

- The `gm` is the only non-human actor. It acts with the infrastructure
  access the initiator gives it at setup (the Docker endpoints, SSH keys)
  and nothing else, by trust rather than enforcement. During the aging it
  acts through `gmctl` runs it scheduled on the manager; they do only the
  setup actions recorded in the local implementation. It operates the
  tools from inside their nodes through the exec operation, and its
  database checks connect as the GM check role inside its reserve. On a
  player's request it performs no infrastructure action other than
  stopping the game or, once confirmed, restarting it.
- **Elevation on a node** is limited to that node's `sudo` wrappers for
  `player`: reload or restart the service, run the validator, reload a
  scheduler's fixed-time operations. Nothing else runs through `sudo`.
- **The `dba` role is a PostgreSQL superuser**, which also gives
  operating-system access as `postgres`, the power to alter the
  monitoring and application roles, and the power to use the GM's
  connection reserve. This is accepted: protected files and validators
  are root-owned and read-only, the answer key is never on a node, and
  breaking a service role only breaks the players' own system.
- **A fixable builder is code.** Where the scenario makes a scheduler's
  repository fixable, a player editing a builder runs Python as the
  scheduler's service account, inside the process that holds the
  schedule. That account holds nothing beyond the node and its
  application roles, but the builder can print the schedule to the log.
  Both are accepted on the trust line; builders are not isolated.
- **The tools password makes the players Grafana administrators**; its
  consequences are in "Known gaps".
- There is no break-glass path and no delegation: credentials are shared
  by all players of a game.

## 9. Audited and confirmed operations

- `restart` is the one confirmed operation: a player's confirmation in
  so many words, after the GM's statement, recorded in the local
  implementation with the player's words, the old and new game ids, the
  time, and whether it started from the snapshot.
- `stop` needs no confirmation: it is obeyed at once and the game torn
  down.
- The final answer needs an explicit statement that it is final; the GM
  asks if it was not given.
- `sudo` wrapper use is logged on each node.
- The GM records the game's stage, the aging's start and progress, the
  outages and the lost time, the scheduled setup actions and their
  results, the early check's and the hand-over check's results, and any
  failure, in the local implementation. A failure during the aging is
  recorded and never tears the game down; `gmctl status` shows it
  first.
- Sealed checks judge the effective live state: for Grafana, what its API
  reports; for the database, what is in effect, whichever file or
  `ALTER SYSTEM` changed it.

## 10. Out of scope

- Who may run the GM, and access to the repository: anyone with the
  repository.
- The security of the hosts and their Docker engines, beyond keeping the
  engines out of the players' reach; the Tailscale network between hosts.
- Alert notification channels and HTTPS on the web front.
- Classroom swarms of student laptops, which v0.3 does not support.

## 11. Known gaps

- When the players own the host (solo play at home), the bastion-only
  rule and the secrecy of the answer key rest entirely on trust.
- A player who is also in the GM session can see the setup dialogue,
  which contains spoilers. Taking the report in a fresh session is
  recommended, not enforced.
- Credentials are shared by all players of a game and cannot be rotated
  during a game, a restart included.
- **`ALTER SYSTEM` on a report-only database node** could not be
  prevented for the superuser `dba`; accepted on the trust line. It does
  not arise in v0.3, where `postgres` is fixable only. Sealed
  checks judge the effective state, whatever changed it.
- **The GM's connection reserve** can be used up by `dba`, a superuser;
  accepted on the trust line.
- **Grafana's write policy cannot be enforced.** On a report-only Grafana
  node, players can still change dashboards, data sources and alert rules
  through the interface, since the tools password makes them
  administrators. Accepted; sealed checks judge the live state.
- **Grafana administration is forbidden but not prevented.**
- **Prometheus has no login of its own**: from any node of the game it is
  reachable directly, without the tools password. Only players and the GM
  have a shell there, and its admin and lifecycle endpoints are off, so
  this adds read access only.
- **A fixable builder is code** run as the scheduler's service account
  (section 8). Accepted on the trust line.
- **A fixable builder can leak the schedule.** It runs inside the
  process holding the schedule and can print it to the log, defeating
  the schedule's secrecy on that node. Accepted on the trust line, like
  editable builders; no isolation.
- **The traffic can be inferred.** The schedule is hidden, but a patient
  reader can infer it from the schedulers' logs and the database's own
  logs and statistics, as in a real system.
- **The web front uses plain HTTP**: the tools password crosses the
  network base64-encoded. Accepted; on a multi-host playground the
  players reach the bastion's own host directly.

## 12. Changes from v0.2

- **Actors**: unchanged. The `gm` also acts through scheduled `gmctl`
  runs during the aging, which never tear the game down; the GM check
  role acts for it.
- **New resources**: the load; the setup actions during the aging; the
  hand-over snapshot; the scheduler's repository, fixed-time operations,
  schedule, log and metrics endpoint; the GM's connection reserve; the
  PgBouncer console; the service credentials grouped (the schedulers'
  roles, PgBouncer's lookup role and the GM check role join the
  monitoring role).
- **Game control**: `restart` leaves `request-help` and becomes the one
  confirmed operation, open to the players only. Node resets, hints and
  extra time stay refused.
- **Nodes**: configuration editing now follows `fixable-file`, so write
  overrides can make a path fixable on a report-only node; report-only is
  now enforced on the monitoring nodes' files.
- **New conditions**: `confirmed-in-session`, `players-confirmed`,
  `before-hand-over`, `aging-done`, `at-hand-over`, `fixable-file`.
- **Prometheus `admin`**: unchanged, refused to everyone; the hand-over
  snapshot stops Prometheus briefly instead of using its admin API.
- **Denial behaviour**: the restart's confirmation dialogue; load
  control refused to everyone; `schedule.yaml` visible but blocked, and
  edited by no one on a node; PgBouncer's console admin refused; an early
  hand-over, or one whose hand-over check fails, refused; a snapshot
  outside the hand-over refused.
- **Known gaps**: `ALTER SYSTEM` on report-only databases accepted on the
  trust line (not arising in v0.3); the GM's reserve usable by `dba`;
  Grafana's write policy gap now reachable; fixable builders running
  code and able to leak the schedule; the inferable traffic.
- **Out of scope**: multi-host is now covered; classroom swarms of
  student laptops are out.
