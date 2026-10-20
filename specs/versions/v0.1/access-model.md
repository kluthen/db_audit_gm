# db_audit_gm v0.1 — Access model

Status: final, companion to [master-spec.md](master-spec.md); approved
with it on 2026-10-20 by the project lead under the owner's delegation.

## 1. Purpose and scope

This governs who may do what in one v0.1 game: in the GM session, on the
bastion, on the database node, and in the database. It does not cover who
may run the GM or read the repository (anyone with the repository can), the
security of the host the game runs on, or the Docker engine itself, which
the players never touch.

Enforcement is deliberately light. Rules that the system enforces say so;
the rest rely on trust and on documentation in place ("DO NOT TAMPER", with
the reason).

## 2. Actors

| Actor | Definition | How acquired | Stacks? |
|---|---|---|---|
| `initiator` | Whoever starts the game with the GM: a teacher, or a student playing alone | Invokes the GM skill in an agent session | Yes: a student playing alone is also a `player` |
| `player` | A student taking part in the game; one or many sit behind one report | Receives the bastion password from the GM at hand-over | Yes, with `initiator` (solo play) |
| `session-participant` | Anyone typing in the GM session, whatever their other role | Has the session in front of them | Yes |
| `gm` | The agent running the GM skill (non-human) | Started by the initiator invoking the GM skill | No: exclusive |
| `network-visitor` | Anyone who can reach the host's network, unauthenticated | Default state | No: exclusive |

Roles are scoped to one game. The `player` role is shared: all players of
a game use the same accounts.

## 3. Role assignment and lifecycle

- The `gm` exists from the moment the initiator invokes the GM skill; a
  fresh session invoking it on a game in progress resumes that game.
- The `initiator` role ends once the game is set up (hand-over). After
  that the initiator acts only as a `session-participant`, or as a
  `player` in solo play.
- The `player` role is granted by handing over the per-game bastion
  password; it cannot be revoked during a game (a password change is not
  offered).
- Every role ends at teardown: the game's services, secrets (credentials
  included) and volumes are removed, so the credentials stop working
  immediately.
- A stop request mid-game takes effect immediately; work in progress on the
  nodes is lost.

## 4. Resources and operations

| Resource | Operations |
|---|---|
| Game control (the GM session) | `start`, `stop`, `report` (hand in an answer), `request-help` (hint, reveal, reset, restart, extra time) |
| Scenario folder (repository) | `read`, `edit` |
| Answer key and GM notes | `read` |
| Bastion | `login`, `use` (shell, `ssh`, `psql`) |
| Database node: shell | `login`, `read-files`, `run-wrapper` (reload, restart, validate) |
| Database node: configuration files | `read`, `edit` |
| Database node: protected files | `read`, `edit` |
| Database (PostgreSQL) | `connect`, `query`, `alter-system`, `ddl` |
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

**Bastion**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| `login` | `holds-password` | allow | `holds-password` | allow | deny |
| `use` | `holds-password` | allow | `holds-password` | allow | deny |

**Database node and database**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| shell `login` | deny | `from-bastion` | deny | allow | deny |
| shell `read-files` | deny | `from-bastion` | deny | allow | deny |
| shell `run-wrapper` | deny | `from-bastion` | deny | allow | deny |
| configuration `read` | deny | `from-bastion` | deny | allow | deny |
| configuration `edit` | deny | `fixable-node` | deny | allow | deny |
| protected files `read` | deny | `from-bastion` | deny | allow | deny |
| protected files `edit` | deny | deny | deny | allow | deny |
| database `connect` | deny | `from-bastion` | deny | allow | deny |
| database `query` | deny | `from-bastion` | deny | allow | deny |
| database `alter-system` | deny | `fixable-node` | deny | allow | deny |
| database `ddl` | deny | `from-bastion` | deny | allow | deny |

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
| `from-bastion` | The connection comes from the bastion, as user `player`, with the game's key (SSH) or the `dba` password (PostgreSQL) |
| `fixable-node` | `from-bastion` holds and the node's write policy is *fixable* (the v0.1 database node is) |
| `owns-host` | The initiator controls the Docker host (it gave the GM its endpoint). Players must not use it; not enforced when they own it |

## 7. Denial behaviour

| Operation class | Behaviour | Rationale |
|---|---|---|
| `request-help` in the GM session | Visible refusal: the GM declines briefly and politely and points back to the system | The stance is part of the exercise; the refusal itself teaches |
| Questions that would reveal answers, before the final answer | Visible refusal, as above | No reveals before the final answer |
| `report` not stated as final | Not refused: the GM asks whether it is the final answer | The final-answer rule |
| `start` by a non-initiator mid-game | The GM explains a game is in progress and offers to resume it | One game per local implementation |
| Bastion or node login without valid credentials | Ordinary SSH refusal | Standard behaviour, nothing to design |
| Editing protected files | Ordinary filesystem "permission denied" (read-only, root-owned) | Enforced by the system |
| Editing configuration on a report-only node | Ordinary "permission denied" | Enforced by the system |
| `network-visitor` reaching anything but the bastion's SSH port | Nothing listens: no other port is published | Bastion-only rule |
| Docker engine use by players | Not reachable from the bastion or nodes; on a host the players own, documented as forbidden | Trust where it cannot be enforced |

Denials are not logged by the game, except `sudo` uses, which `sudo`
logs on the node. Repeated denials have no effect.

## 8. Elevation, delegation and non-human actors

- The `gm` is the only non-human actor. It acts with the infrastructure
  access the initiator gives it at setup (the Docker endpoint, SSH keys)
  and nothing else, by trust rather than enforcement. On a player's
  request it performs no infrastructure action other than stopping the
  game.
- **Elevation on the node** is limited to three `sudo` wrappers for
  `player`: reload the database, restart it, run the validator. Nothing
  else can be run through `sudo`.
- **The `dba` role is a PostgreSQL superuser**, which also gives
  operating-system access as the `postgres` user (for example through
  `COPY ... TO PROGRAM`). This is accepted: protected files and validators
  are root-owned and read-only, and the answer key is never on a node.
- There is no break-glass path and no delegation: credentials are shared by
  all players of a game.

## 9. Audited and confirmed operations

- `sudo` wrapper use is logged on the node.
- The GM records the game's stage and any failure in the local
  implementation.
- `stop` needs no confirmation: it is obeyed at once and the game torn
  down.
- The final answer needs an explicit statement that it is final; the GM
  asks if it was not given.

## 10. Out of scope

- Who may run the GM, and access to the repository: anyone with the
  repository.
- The security of the host machine and its Docker engine, beyond keeping
  the engine out of the players' reach.
- Monitoring tools and their web interfaces (no monitoring in v0.1).
- Multi-host swarms, where each student may own a host (later versions).

## 11. Known gaps

- When the players own the host (solo play at home, or later a classroom
  swarm of student laptops), the bastion-only rule and the secrecy of the
  answer key rest entirely on trust.
- A player who is also in the GM session can see the setup dialogue, which
  contains spoilers. Taking the report in a fresh session is recommended,
  not enforced.
- Credentials are shared by all players of a game and cannot be rotated
  during a game.
