# db_audit_gm v0.2 — Access model

Status: **approved by the owner on 2026-10-21** with the
[master spec](master-spec.md) it accompanies (spec D98). Revises the
[v0.1 access model](../v0.1/access-model.md), which it replaces for v0.2
games; "Changes from v0.1" at the end lists what moved.

## 1. Purpose and scope

This governs who may do what in one v0.2 game: in the GM session, on the
bastion and its web front, on every node of the topology (the database,
Prometheus, Grafana, the exporter), in the database, and in the
monitoring interfaces. It does not cover who may run the GM or read the
repository (anyone with the repository can), the security of the host
the game runs on, or the Docker engine, which the players never touch.

Enforcement is deliberately light. Rules the system enforces say so; the
rest rely on trust and on documentation in place ("DO NOT TAMPER", with
the reason).

## 2. Actors

| Actor | Definition | How acquired | Stacks? |
|---|---|---|---|
| `initiator` | Whoever starts the game with the GM: a teacher, or a student playing alone | Invokes the GM skill in an agent session | Yes: a student playing alone is also a `player` |
| `player` | A student taking part in the game; one or many sit behind one report | Receives the bastion password and the tools password from the GM at hand-over | Yes, with `initiator` (solo play) |
| `session-participant` | Anyone typing in the GM session, whatever their other role | Has the session in front of them | Yes |
| `gm` | The agent running the GM skill (non-human) | Started by the initiator invoking the GM skill | No: exclusive |
| `network-visitor` | Anyone who can reach the host's network, unauthenticated | Default state | No: exclusive |

Roles are scoped to one game. The `player` role is shared: all players of
a game use the same accounts and the same two passwords.

The monitoring tools' own service accounts (the exporter's monitoring
role in PostgreSQL, Grafana's data source connections) are not actors:
they act only as configured, and their credentials are resources below.

## 3. Role assignment and lifecycle

- The `gm` exists from the moment the initiator invokes the GM skill; a
  fresh session invoking it on a game in progress resumes that game.
- The `initiator` role ends at hand-over. After that the initiator acts
  only as a `session-participant`, or as a `player` in solo play.
- The `player` role is granted by handing over the per-game bastion
  password and tools password together; neither can be revoked or
  rotated during a game.
- Every role ends at teardown: the game's services, secrets (every
  password included) and volumes are removed, so the credentials stop
  working immediately.
- A stop request mid-game takes effect immediately; work in progress on
  the nodes and in the interfaces is lost.

## 4. Resources and operations

| Resource | Operations |
|---|---|
| Game control (the GM session) | `start`, `stop`, `report`, `request-help` (hint, reveal, reset, restart, extra time) |
| Scenario folder (repository) | `read`, `edit` |
| Answer key and GM notes | `read` |
| Bastion | `login`, `use` (shell, `ssh`, `scp`, `sftp`, `psql`) |
| Web front | `reach` |
| Node shell (any node but the bastion) | `login`, `read-files`, `run-wrapper` (reload, restart, validate) |
| Node configuration files (seed-once copies) | `read`, `edit` |
| Node protected files (including the node-health script and its service list) | `read`, `edit` |
| Node-health endpoint | `read` |
| Database (PostgreSQL) | `connect`, `query`, `alter-system`, `ddl` |
| PostgreSQL log files and pgBadger | `read-logs`, `run-pgbadger` |
| Monitoring role credentials (the exporter's password) | `read` |
| Prometheus interface | `view` (query, targets, alerts), `admin` (admin and lifecycle endpoints) |
| Grafana interface | `view`, `edit-content` (dashboards, data sources, alert rules), `administer` (users, the administrator's password, organisation settings) |
| Swarm and Docker engine | `any` |

## 5. Permission matrix

**Game control**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| `start` | allow | deny | deny | allow | deny |
| `stop` | allow | allow | allow | allow | deny |
| `report` | deny | `in-session` | `in-session` | deny | deny |
| `request-help` | deny | deny | deny | deny | deny |

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

**Nodes** (the database, Prometheus, Grafana and exporter nodes alike)

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| shell `login` | deny | `from-bastion` | deny | allow | deny |
| shell `read-files` | deny | `from-bastion` | deny | allow | deny |
| shell `run-wrapper` | deny | `from-bastion` | deny | allow | deny |
| configuration `read` | deny | `from-bastion` | deny | allow | deny |
| configuration `edit` | deny | `fixable-node` | deny | allow | deny |
| protected files `read` | deny | `from-bastion` | deny | allow | deny |
| protected files `edit` | deny | deny | deny | allow | deny |
| node-health endpoint `read` | deny | `in-game-network` | deny | allow | deny |

**Database and its logs**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| database `connect` | deny | `from-bastion` | deny | allow | deny |
| database `query` | deny | `from-bastion` | deny | allow | deny |
| database `alter-system` | deny | `fixable-node` | deny | allow | deny |
| database `ddl` | deny | `from-bastion` | deny | allow | deny |
| `read-logs` | deny | `from-bastion` | deny | allow | deny |
| `run-pgbadger` | deny | `from-bastion` | deny | allow | deny |
| monitoring role credentials `read` | deny | deny | deny | allow | deny |

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
| `has-repository` | The actor has a copy of the repository. Not enforced: students are asked not to read scenarios, and a warning heads each scenario document |
| `holds-password` | The actor knows the game's bastion password (a teacher who also plays, for example) |
| `holds-tools-password` | The actor knows the game's tools password and reaches the bastion's web front port with it |
| `from-bastion` | The connection comes from the bastion, as user `player`, with the game's key (SSH) or the `dba` password (PostgreSQL) |
| `fixable-node` | `from-bastion` holds and the node's write policy is *fixable* |
| `in-game-network` | The request comes from a node of the game (the bastion or any other node), where only players and the GM have a shell |
| `through-web-front` | The request passes the web front with the tools password; from inside the game network, Prometheus is also reachable directly, since it has no login of its own |
| `fixable-grafana` | `through-web-front` holds and the Grafana node's write policy is *fixable*. Not enforced on a report-only Grafana node: see "Known gaps" |
| `owns-host` | The initiator controls the Docker host (it gave the GM its endpoint). Players must not use it; not enforced when they own it |

## 7. Denial behaviour

| Operation class | Behaviour | Rationale |
|---|---|---|
| `request-help` in the GM session | Visible refusal: the GM declines briefly and politely and points back to the system | The stance is part of the exercise; the refusal itself teaches |
| Questions that would reveal answers, before the final answer | Visible refusal, as above | No reveals before the final answer |
| `report` not stated as final | Not refused: the GM asks whether it is the final answer | The final-answer rule |
| `start` by a non-initiator mid-game | The GM explains a game is in progress and offers to resume it | One game per local implementation |
| Bastion or node login without valid credentials | Ordinary SSH refusal | Standard behaviour |
| Web front without the tools password | HTTP 401 with a basic-authentication challenge | Standard behaviour; the browser asks for the password |
| Editing protected files, the node-health script or its service list | Ordinary filesystem "permission denied" (read-only, root-owned) | Enforced by the system |
| Editing configuration on a report-only node | Ordinary "permission denied" | Enforced by the system |
| Prometheus `admin` | Refused by Prometheus: those endpoints are disabled | Reloads go through the node's `sudo` wrapper, under the write policy |
| Grafana `edit-content` on a report-only Grafana node | Not refused: Grafana lets an administrator edit | Known gap, accepted |
| Grafana `administer` | Not refused by Grafana; forbidden by the rules and marked DO NOT TAMPER in the starter pack, since changing the administrator's password would lock the GM's own checks out | Trust where it cannot be enforced |
| Monitoring role credentials | Ordinary "permission denied": the secret is readable by the exporter's account only | Enforced by the system |
| `network-visitor` reaching anything but the bastion's two ports | Nothing listens: no other port is published | Bastion-only rule |
| Docker engine use by players | Not reachable from the bastion or nodes; on a host the players own, documented as forbidden | Trust where it cannot be enforced |

Denials are not logged by the game, except `sudo` uses, which `sudo` logs
on each node. Repeated denials have no effect.

## 8. Elevation, delegation and non-human actors

- The `gm` is the only non-human actor. It acts with the infrastructure
  access the initiator gives it at setup (the Docker endpoint, SSH keys)
  and nothing else, by trust rather than enforcement. It operates the
  monitoring tools from inside their nodes through the exec operation
  (Grafana's API with the administrator's password, Prometheus' API). On
  a player's request it performs no infrastructure action other than
  stopping the game.
- **Elevation on a node** is limited to that node's `sudo` wrappers for
  `player`: reload or restart the service, run the validator. Nothing
  else runs through `sudo`. pgBadger needs no elevation: the log files
  are readable by the players' group.
- **The `dba` role is a PostgreSQL superuser**, which also gives
  operating-system access as `postgres` (for example `COPY ... TO
  PROGRAM`) and the power to alter the monitoring role. This is accepted:
  protected files and validators are root-owned and read-only, the answer
  key is never on a node, and breaking the exporter's role only breaks
  the players' own monitoring.
- **The tools password makes the players Grafana administrators.** That
  is what lets them fix Grafana on a fixable node; its consequences are
  in "Known gaps".
- There is no break-glass path and no delegation: credentials are shared
  by all players of a game.

## 9. Audited and confirmed operations

- `sudo` wrapper use is logged on each node.
- The GM records the game's stage and any failure in the local
  implementation.
- `stop` needs no confirmation: it is obeyed at once and the game torn
  down.
- The final answer needs an explicit statement that it is final; the GM
  asks if it was not given.
- Sealed checks judge the effective live state: for Grafana, what its API
  reports, not only its provisioned files.

## 10. Out of scope

- Who may run the GM, and access to the repository: anyone with the
  repository.
- The security of the host machine and its Docker engine, beyond keeping
  the engine out of the players' reach.
- Alert notification channels (none in v0.2) and HTTPS on the web front.
- Multi-host swarms, where each student may own a host (later versions).

## 11. Known gaps

- When the players own the host (solo play at home, or later a classroom
  swarm of student laptops), the bastion-only rule and the secrecy of the
  answer key rest entirely on trust.
- A player who is also in the GM session can see the setup dialogue,
  which contains spoilers. Taking the report in a fresh session is
  recommended, not enforced.
- Credentials are shared by all players of a game and cannot be rotated
  during a game.
- The rule that `alter-system` needs a fixable node cannot be enforced
  for a PostgreSQL superuser: on a report-only database node, `dba`
  could still run `ALTER SYSTEM`. v0.2's database nodes are fixable; to
  revisit when report-only database nodes arrive.
- **Grafana's write policy cannot be enforced.** On a report-only Grafana
  node, players can still change dashboards, data sources and alert rules
  through the UI, since the tools password makes them administrators.
  Accepted under light enforcement; sealed checks judge the live state.
- **Grafana administration is forbidden but not prevented.** Players can
  technically change Grafana's users or the administrator's password,
  which would lock the GM's checks out; the rule is documented, not
  enforced.
- **The web front uses plain HTTP.** The tools password crosses the
  network base64-encoded, readable by anyone on the path between the
  players and the host. Accepted for v0.2's single host.
- **Prometheus has no login of its own**: from any node of the game it is
  reachable directly, without the tools password. Only players and the GM
  have a shell there, so this adds no reach.

## 12. Changes from v0.1

- **Actors**: unchanged; the `player` now also receives the tools
  password.
- **New resources**: the web front; the Prometheus and Grafana
  interfaces; the node-health endpoint; the PostgreSQL log files and
  pgBadger; the monitoring role's credentials.
- **Nodes**: the node rules, written for the database node in v0.1, now
  apply to every node but the bastion: the Prometheus, Grafana and
  exporter nodes have the same shell, configuration and protected-file
  rules, each under its own write policy. The node-health script and its
  service list join the protected files.
- **New conditions**: `holds-tools-password`, `in-game-network`,
  `through-web-front`, `fixable-grafana`.
- **Published ports**: two on the bastion (SSH and the web front)
  instead of one; the network visitor's denial row changes accordingly.
- **Denial behaviour**: HTTP 401 at the web front; Prometheus' admin
  endpoints disabled; Grafana editing on a report-only node not refused;
  Grafana administration forbidden by rule.
- **Known gaps added**: Grafana's write policy, Grafana administration,
  plain HTTP, Prometheus without a login.
- **Out of scope**: monitoring is now covered; alert notification and
  HTTPS are not.
