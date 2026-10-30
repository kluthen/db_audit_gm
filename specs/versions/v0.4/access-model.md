# db_audit_gm v0.4 — Access model

Status: **approved by the owner on 2026-10-30 with the
[master spec](master-spec.md) it accompanies.** Revises the
[v0.3 access model](../v0.3/access-model.md), which it replaces for v0.4
games; "Changes from v0.3" at the end lists what moved.

## 1. Purpose and scope

This governs who may do what in one v0.4 game: in the GM session, on the
bastion and its web front, on every node of the topology (the database
instances, PgBouncer, the scheduler nodes, Prometheus, Grafana, the
exporter), in each database and the PgBouncer console, over the load and
the jobs, and in the monitoring interfaces. It does not cover who may
run the GM or read the repository (anyone with the repository can), the
security of the hosts the game runs on, or the Docker engine, which the
players never touch.

It also states, in section 9, the **customer's database roles and data
policy**: part of the game's world, which the players audit, not part
of their own access. A customer role is not an actor; what it may read
is a fact of the system under audit, which the players may find wrong.

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
a game use the same accounts and the same two passwords; the `dba` role
and its password are the same on every database instance of the game.

Service accounts are not actors; they act only as configured, and their
credentials are resources below: the exporter's monitoring role, the
customer's roles (section 9) used by the scheduler nodes, the cron
daemons, the user mappings and the gateway stub, PgBouncer's lookup
role, Grafana's data source connections, and the GM check role, which
acts only for the `gm` (section 8).

## 3. Role assignment and lifecycle

- The `gm` exists from the moment the initiator invokes the GM skill; a
  fresh session invoking it on a game in progress resumes that game. It
  starts the load in its session at T0. Between sessions, during the
  aging, it acts only through the setup actions it scheduled (planting
  the faults due during the aging, among them the out-of-memory
  incident's backfill request, and the early check), which record a
  failure and never tear the game down.
- The `initiator` role ends at hand-over. After that the initiator acts
  only as a `session-participant`, or as a `player` in solo play.
- The `player` role is granted by handing over the per-game bastion
  password and, when the topology has a web interface to publish, the
  tools password with it; neither can be revoked or rotated during a
  game. Without a web interface the web front does not run and its rows
  below do not apply. The starter pack, the data policy included, is
  handed over at the same moment.
- **A restart keeps the `player` role**: the rebuilt game keeps every
  generated secret, the players' credentials and every customer role's
  password included, under a new game id. It enters the stage
  `handed-over`; the hand-over snapshot, which holds the `pg_cron` jobs
  in each instance's data and each crontab on its `cronspool` volume,
  stays, so a second restart starts from it again.
- Every role ends at teardown: the game's services, secrets (every
  password included), volumes and hand-over snapshot are removed, so the
  credentials stop working immediately.
- A stop request mid-game takes effect immediately; work in progress on
  the nodes and in the interfaces is lost.

## 4. Resources and operations

| Resource | Operations |
|---|---|
| Game control (the GM session) | `start`, `stop`, `restart`, `report`, `request-help` (hint, reveal, node reset, extra time) |
| The load | `start-load`, `control-load` (pause, speed up, trigger, run now, any job included) |
| Setup actions during the aging | `schedule` (plant a fault at a moment, the early check), `hand-over` |
| Hand-over snapshot | `take`, `restore` |
| Scenario folder (repository), purposes and domains | `read`, `edit` |
| Answer key and GM notes | `read` |
| Starter pack (story, issues, data policy) | `read` |
| Bastion | `login`, `use` (shell, `ssh`, `scp`, `sftp`, `psql`) |
| Web front | `reach` |
| Node shell (any node but the bastion) | `login`, `read-files`, `run-wrapper` (reload, restart, validate) |
| Node configuration files (seed-once copies) | `read`, `edit` |
| Node protected files (including the node-health script and `check-psql`) | `read`, `edit` |
| Scheduler query repository (`queries.yaml`, `builders/`, `scripts/`) | `read`, `edit` |
| Scheduler fixed-time operations (`jobs.yaml`) | `read`, `edit` |
| Scheduler schedule (`schedule.yaml`) | `read`, `edit` |
| Scheduler log and other configuration | `read` |
| Scheduler metrics endpoint, node-health endpoint | `read` |
| Database (PostgreSQL), each instance | `connect`, `read` (queries that change nothing), `write` (data changes and DDL, roles and grants included), `alter-system` |
| `pg_cron` jobs (`cron.job`) and their runs (`cron.job_run_details`) | `list`, `change` (schedule, unschedule, alter) |
| A database node's crontab | `list`, `install` |
| PostgreSQL log files, the cron jobs' logs, and pgBadger | `read-logs`, `run-pgbadger` |
| The GM's connection reserve | `connect-reserved` |
| Service credentials (monitoring role, customer roles' passwords wherever they are held: the schedule, a crontab's password file, a user mapping; PgBouncer lookup role, GM check role) | `read` |
| PgBouncer console | `show` (pools, stats, clients), `admin` (set, reload, pause, kill, shutdown) |
| Prometheus interface | `view` (query, targets, alerts), `admin` (admin and lifecycle endpoints) |
| Grafana interface | `view`, `edit-content` (dashboards, data sources, alert rules), `administer` (users, the administrator's password, organisation settings) |
| Swarm and Docker engine | `any` |

Listing and reading one item do not differ for any resource of the
game: whoever may list a node's files, the jobs or the crontab may read
each of them. The one listing that differs is in the game's world:
`pg_cron` shows a non-superuser customer role only its own jobs (9.4).

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

**Scenario folder, answer key and starter pack**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| scenario folder `read` | `has-repository` | `has-repository` | `has-repository` | allow | deny |
| scenario folder `edit` | `has-repository` | deny | deny | allow | deny |
| answer key `read` | `has-repository` | `has-repository` | `has-repository` | allow | deny |
| starter pack `read` | `has-repository` | `handed-over` | `has-repository` | allow | deny |

**Bastion and web front**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| bastion `login` | `holds-password` | allow | `holds-password` | allow | deny |
| bastion `use` | `holds-password` | allow | `holds-password` | allow | deny |
| web front `reach` | `holds-tools-password` | allow | `holds-tools-password` | allow | deny |

**Nodes** (every node but the bastion: the database instances,
PgBouncer, the scheduler nodes, Prometheus, Grafana, the exporter)

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

`run-wrapper` covers the validator on every node; the reload and
restart wrappers act only under `fixable-node` (section 7). Every
database node is fixable in v0.4: `postgres` has no other write policy.

**Scheduler nodes** (producers, consumers, transformers, the gateway
stub)

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| query repository `read` (scripts included) | deny | `from-bastion` | deny | allow | deny |
| query repository `edit` (scripts included) | deny | `fixable-file` | deny | allow | deny |
| fixed-time operations `read` | deny | `from-bastion` | deny | allow | deny |
| fixed-time operations `edit` | deny | `fixable-file` | deny | allow | deny |
| schedule `read` | deny | deny | deny | allow | deny |
| schedule `edit` | deny | deny | deny | deny | deny |
| log and other configuration `read` | deny | `from-bastion` | deny | allow | deny |
| metrics endpoint `read` | deny | `in-game-network` | deny | allow | deny |

**Databases** (each instance: `db`, `reporting` and any other), **their
jobs, logs and PgBouncer**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| database `connect` | deny | `from-bastion` | deny | allow | deny |
| database `read` | deny | `from-bastion` | deny | allow | deny |
| database `write` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| database `alter-system` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| `pg_cron` jobs `list` | deny | `from-bastion` | deny | allow | deny |
| `pg_cron` jobs `change` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| crontab `list` | deny | `from-bastion` | deny | allow | deny |
| crontab `install` | deny | `fixable-node` | deny | `before-hand-over` | deny |
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
| `before-hand-over` | The game has not been handed over yet: from deployment to the end of the aging, or to the hand-over in a game with no aging. For the database and job rows, the GM acts only through the setup: the data load, the faults' planting, and render's seed files; a confirmed restart's own setup, inside `gmctl restart`, counts as before hand-over |
| `aging-done` | The earliest hand-over is reached: the later of the scenario's aging minimum since T0 and every fault instance's own minimum since its planting, moved later by the lost time beyond thirty minutes. In a game with no scheduler node, which has no aging, it holds once the faults are planted |
| `at-hand-over` | `aging-done` holds and the starter pack is not yet handed over |
| `handed-over` | The game has been handed over: the starter pack, the data policy included, is in the players' hands |
| `has-repository` | The actor has a copy of the repository. Not enforced: students are asked not to read scenarios, and a warning heads each scenario document |
| `holds-password` | The actor knows the game's bastion password (a teacher who also plays, for example) |
| `holds-tools-password` | The actor knows the game's tools password and reaches the bastion's web front port with it |
| `from-bastion` | The connection comes from the bastion, as user `player`, with the game's key (SSH) or the `dba` password (PostgreSQL on any instance, and the PgBouncer console, where `dba` is the players' console role) |
| `fixable-node` | `from-bastion` holds and the node's write policy is *fixable*. It holds on every database node, `postgres` having no other policy, the agency's `reporting` included: a node the story gives another party is report-only by the answer key and the story alone (section 7, "Known gaps") |
| `fixable-file` | `from-bastion` holds and the file is fixable: the node's write policy is *fixable*, or the scenario's write overrides make that path fixable on a report-only node |
| `in-game-network` | The request comes from a node of the game (the bastion or any other node), where only players and the GM have a shell |
| `through-web-front` | The request passes the web front with the tools password; from inside the game network, Prometheus' `view` is also reachable directly, since it has no login of its own |
| `fixable-grafana` | `through-web-front` holds and the Grafana node's write policy is *fixable*. On a report-only Grafana node it is not enforced: see "Known gaps" |
| `owns-host` | The initiator controls the Docker hosts (it gave the GM their endpoints). Players must not use them; not enforced when they own them |

## 7. Denial behaviour

Every forbidden resource in a game stays visible: nothing is hidden from
listings, a denied action is refused where it is attempted, or, where
the system cannot refuse it, forbidden by the rules in place.

| Operation class | Behaviour | Rationale |
|---|---|---|
| `request-help` in the GM session | Visible refusal: the GM declines briefly and politely and points back to the system | The stance is part of the exercise; the refusal itself teaches |
| Questions that would reveal answers, before the final answer | Visible refusal, as above | No reveals before the final answer |
| `restart` without a confirmation | Not refused outright: the GM states what a restart loses (and, without a snapshot, which evidence) and asks for a confirmation in so many words; anything less leaves the game running | A restart is highly breaking; a passing comment must never trigger it |
| `restart` asked by someone who is not a player | Visible refusal: the GM says only a player of the game may confirm a restart | The players' work is what is lost |
| `control-load` (pause, speed up, trigger, run now), any job included, by anyone | Visible refusal in the session; on the nodes no tool or wrapper offers it. A player verifies a fix by moving a job's time where the job is fixable, never by running it | The evidence must come from the schedule, never from an intervention |
| `start-load`, a setup action, `hand-over` or a snapshot, asked by anyone but the GM | Visible refusal in the session: the GM runs the setup itself; on the nodes no tool or wrapper offers them | The setup is the GM's |
| `start-load` or a setup action `schedule` after hand-over | Refused by `gmctl`; a restart's own setup, inside `gmctl restart`, is not affected | The schedule is fixed once the game starts |
| Schedule `edit` on a node, by anyone | No `gmctl` verb or wrapper edits it; for players, ordinary "permission denied". The GM changes a schedule only in the scenario folder, for the next game | No events outside the schedule, during the aging included |
| Database `write`, `alter-system`, `pg_cron` `change` or crontab `install` by the GM after hand-over | Never done: the GM's checks only read, and the GM acts on the system only by stopping or, once confirmed, restarting the game | The system after hand-over is the players' |
| `hand-over` before the earliest hand-over | The GM refuses and says when the game can be handed over | Faults need their history |
| `hand-over` with the hand-over check failing | The GM does not hand over: it re-plants a fault whose planting failed when its aging minimum can still be reached, otherwise offers the initiator to set the game up again (stop, then start). A failed out-of-memory incident cannot be re-planted inside the same aging, its job running nightly | A game missing its evidence is not playable |
| Snapshot `take` outside `at-hand-over` | Refused by `gmctl snapshot` | One snapshot, of the system as handed over |
| `report` not stated as final | Not refused: the GM asks whether it is the final answer | The final-answer rule |
| `start` by a non-initiator mid-game | The GM explains a game is in progress and offers to resume it | One game per local implementation |
| Starter pack `read` before hand-over, by a player | Not available: the GM hands it over at hand-over, the data policy with it | The policy belongs to the game's start |
| Bastion or node login without valid credentials | Ordinary SSH refusal | Standard behaviour |
| Web front without the tools password | HTTP 401 with a basic-authentication challenge | Standard behaviour |
| Editing protected files, the node-health script or `check-psql` | Ordinary filesystem "permission denied" (read-only, root-owned) | Enforced by the system |
| Editing a configuration file, repository (scripts included) or `jobs.yaml` that is not fixable | Ordinary "permission denied"; the reload wrapper of a report-only node refuses with a one-line reason | Enforced by the system |
| Any change on a database node the story gives another party (the agency's `reporting`): its data, DDL, roles, settings, `pg_cron` jobs, crontab, a reload or a restart | Not refused: the node is fixable. The story says whose node it is and its issues ask for a report or a proposal. The answer key judges that report or proposal; a sealed check reading fixed after such a change is not the resolution, and the feedback names the overstep, judges whether the change would have been right as a proposal and what it cost (master spec 16.5) | Report-only by the story and the answer key, not by the brick: a write policy could not have protected the database's contents from the superuser `dba` anyway |
| Running a job by hand (a `CALL` of a job's procedure, a `cron.alter_job` or crontab entry set to run at once), on any node | Not refused where the node is fixable; it is a run outside the schedule, which the rules forbid as `control-load`. The GM does not take a check reading fixed through such a run as the resolution | The evidence must come from the schedule; moving a fixable job's time is the players' lever |
| Reading `schedule.yaml` | Ordinary "permission denied" (root-owned, mode 0400); visible in listings. The scheduler's root run script passes it to the program on standard input, so the service account cannot read it either | Visible but blocked, as a real customer's traffic would be |
| `connect-reserved` and service credentials | Ordinary "permission denied" on the secret files (root or the service's account only) and on a crontab's password file (OS user `postgres` only); without the check role's password the reserve is out of reach. The superuser `dba` can still reach some of them: see "Known gaps" | Enforced by the system where it can be |
| PgBouncer console `admin` | Refused by PgBouncer: the players' console role is not in `admin_users` | Enforced by the system |
| Prometheus `admin`, through the web front or from inside the game network | Refused by Prometheus: its admin and lifecycle endpoints are disabled | Reloads go through the node's `sudo` wrapper, under the write policy |
| Grafana `edit-content` on a report-only Grafana node | Not refused: Grafana lets an administrator edit | Known gap, accepted |
| Grafana `administer` | Not refused by Grafana; forbidden by the rules and marked DO NOT TAMPER | Trust where it cannot be enforced |
| `network-visitor` reaching anything but the bastion's ports | Nothing listens: no other port is published, on a multi-host playground the bastion publishes on its own host only, and no registry runs | Bastion-only rule |
| Docker engine use by players | Not reachable from the bastion or nodes; on a host the players own, documented as forbidden | Trust where it cannot be enforced |

Denials are not logged by the game, except `sudo` uses, which `sudo`
logs on each node. Repeated denials have no effect.

## 8. Elevation, delegation and non-human actors

- The `gm` is the only non-human actor. It acts with the infrastructure
  access the initiator gives it at setup (the Docker endpoints, SSH keys)
  and nothing else, by trust rather than enforcement. During the aging
  it acts through `gmctl` runs it scheduled on the manager. It operates
  the tools from inside their nodes through the exec operation, and its
  database checks connect as the GM check role inside its reserve. On a
  player's request it performs no infrastructure action other than
  stopping the game or, once confirmed, restarting it.
- **The GM check role** (`gm_check`, one password per game, the same on
  every instance) acts only for the `gm`'s sealed checks, the early check
  and the hand-over check. Its reads:

  | Read | Since | How |
  |---|---|---|
  | settings, statistics, activity; all data; `pg_hba_file_rules` | v0.3 | `pg_monitor`, `pg_read_all_data`, the grants on the view and its function |
  | every database of its instance | v0.3, now on every instance | `CONNECT` granted by `load-data` |
  | the other instances of the game | v0.4 | over the game network: from a scheduler node through `check-sql`, from a database node through `check-psql` with the other node's name; every database node of a scenario with a data policy admits it from the game network |
  | `cron.job` and `cron.job_run_details` | v0.4 | a read policy `load-data` adds on both tables where `pg_cron` exists, narrower than bypassing row-level security |
  | each user mapping's server, local role and remote role, never its password | v0.4 | a function owned by `postgres`, `SECURITY DEFINER`, executable by the GM check role only, created by `load-data` where a foreign server exists |
  | the customer's zone and sending hours | v0.4 | `business_settings`, within `pg_read_all_data` |

  Checks run as root through the exec operation may also read, on their
  own node: a runner's `jobs.yaml` and the connections' role names in its
  schedule (the governance reach check), a database node's crontab, its
  PostgreSQL log, and the cgroup's `memory.events` (the out-of-memory
  incident's check). None of it changes anything.
- **Elevation on a node** is limited to that node's `sudo` wrappers for
  `player`: reload or restart the service and run the validator (the
  reload and restart wrappers refusing on a report-only node, which a
  database node never is), reload a scheduler's fixed-time operations,
  list or install a database node's crontab (`gm-crontab`). Nothing else
  runs through `sudo`.
- **The `dba` role is a PostgreSQL superuser** on every instance, which
  also gives operating-system access as `postgres`, the power to alter
  the monitoring, customer and GM roles, the power to use the GM's
  connection reserve. Accepted: protected files and validators are root-owned and
  read-only, the answer key is never on a node, and breaking a service
  role only breaks the players' own system.
- **A fixable builder or transformer script is code.** Where the
  scenario makes a scheduler's repository fixable, a player editing a
  builder or a script runs Python as the scheduler's service account,
  inside the process that holds the schedule; a script also holds open
  connections as the schedule's roles. That account holds nothing beyond
  the node and its customer roles, but the code can print the schedule,
  and a script its connections' passwords, to the log. Accepted on the
  trust line; neither is isolated.
- **Jobs on a database node run as configured**: a `pg_cron` job as its
  `username`, a crontab entry as OS user `postgres` connecting as the
  role its entry names. Neither acts for any actor.
- **The tools password makes the players Grafana administrators**; its
  consequences are in "Known gaps".
- There is no break-glass path and no delegation: credentials are shared
  by all players of a game.

## 9. The customer's roles and data policy (the game's world)

Not the game's access rules: the state of the system the players audit.
On a fixable instance the players, as `dba`, may change any of it; the
checks judge what is live. Section 11.6 of the master spec states which
of it the checks verify.

### 9.1 The customer's database roles

| Role | Instance and database | Used by | Reads | Writes |
|---|---|---|---|---|
| `shop` | `db`, `shop` | none (owner, no login) | owns the business tables | |
| `shop_app` | `db`, `shop` | the web shop (producer, through PgBouncer) | the shop's operational tables, `consent_events`, `popular_products` | orders and their lines, the new order columns, `consent_events`, `customers.marketing_opt_in` |
| `shop_reports` | `db`, `shop` | the back office | every business table, names and e-mail addresses included | none |
| `shop_etl` | `db`, `shop` | the source connection of the hourly transformer script; the remote role of `reporting`'s user mapping | `orders` without `customer_id`, `order_lines`, `products` | none |
| `shop_crm` | `db`, `shop` | the win-back and mailing jobs on `crm` | `customers`, `consent_events`, `orders`, `campaigns`, `leads`, `mail_outbox`, `business_settings` | `leads`, `mail_outbox`, `etl_runs` |
| `shop_customs` | `db`, `shop` | the declaration jobs on `crm` | `orders`, `order_lines`, `customers` (name, address, country), `export_countries`, the customs tables, `incidents` | `customs_outbox`, `incidents`, `etl_runs` |
| `customs_gw` | `db`, `shop` | the customs gateway stub | `customs_outbox` | `customs_acks` |
| `shop_refresh` | `db`, `shop` | `db`'s crontab entry refreshing `popular_products` | the view's inputs | `MAINTAIN` on `popular_products` |
| `bi_etl` | `reporting`, `reporting` | the target connection of the hourly script; the nightly close's `CALL`; `reporting`'s crontab entry; `pg_cron` jobs on `reporting` | `src.*` (foreign tables, through its user mapping to `shop_etl`), `rpt.*` | `rpt.*` |
| `bi_reader` | `reporting`, `reporting` | the dashboards (consumer) | `rpt.*` | none |

Each login role's password is a generated secret. The roles never see
it: the schedule (hidden) holds it for the scheduler nodes, a password
file only OS user `postgres` reads holds it for a crontab, and the user
mapping holds `shop_etl`'s, set by `load-data`. The foreign server is
owned by `postgres`. Every planted fault changes some of this table; the
table above is the baseline.

### 9.2 A transformer script's roles

A transformer script reaches each instance only through the connections
its job names, each as the schedule's role for it: the hourly roll-up's
`source` as `shop_etl` on `db`, its `target` as `bi_etl` on `reporting`.
What it can read is what its source role may read, whatever its code
selects; which roles those are is visible to the players in `jobs.yaml`
(the connection names) and in `pg_stat_activity` while it runs, never in
a catalog.

### 9.3 The data policy's readers

The policy names, per class, where it may live and which customer roles
may read it:

| Class | May live in | May read it | May leave, and with which fields |
|---|---|---|---|
| `personal` | `db/shop` | `shop_app`, `shop_reports`, `shop_crm`, `shop_customs`, `customs_gw` | to the mail provider (`mail_outbox`): e-mail, name, order; to the customs gateway (`customs_outbox`): consignee name and address, country |
| `customer-linked` | `db/shop` | `shop_app`, `shop_reports`, `shop_crm`, `shop_customs` | nowhere |
| `internal` | anywhere | any customer role | not restricted |

`shop_etl`, `shop_refresh`, `bi_etl` and `bi_reader` read no classed
column in the baseline. The game's own roles (`dba`, `postgres`, the GM
check role, `monitoring`, PgBouncer's lookup role) are outside every
rule of the policy, which speaks of "application and staff accounts".

### 9.4 Jobs on a database node: who sees and changes them

| | `pg_cron` jobs | A crontab |
|---|---|---|
| Listed to | the players' `dba` (all jobs); a non-superuser customer role, its own jobs only; the GM check role, all, through its read policy | the players, through `sudo gm-crontab -l`; root |
| Changed by | the players' `dba` (`cron.schedule`, `cron.unschedule`, `cron.alter_job`, the settings), on every instance | the players, through `sudo gm-crontab <file>`, on every database node; also OS user `postgres` with `crontab` itself, which `dba` reaches through programs run as `postgres`: the same crontab, on a node the players may change anyway |
| Run as | the job's `username`, through a background worker, with no password | OS user `postgres`, connecting as the role the entry names through the password file, or as `postgres` by peer if it names none (a superuser: a fault) |
| Seeded by | the instance's data file | the node's seed `crontab`, installed once |

## 10. Audited and confirmed operations

- `restart` is the one confirmed operation: a player's confirmation in
  so many words, after the GM's statement, recorded in the local
  implementation with the player's words, the old and new game ids, the
  time, and whether it started from the snapshot.
- `stop` needs no confirmation: it is obeyed at once and the game torn
  down.
- The final answer needs an explicit statement that it is final; the GM
  asks if it was not given. When the report dates a fix made outside a
  runner, the GM passes that time to its checks (`gmctl check --since`).
- `sudo` wrapper use is logged on each node, `gm-crontab` included.
- The GM records the game's stage, the aging's start and progress, the
  outages and the lost time, the scheduled setup actions and their
  results (the out-of-memory incident's verification among them), the
  early check's and the hand-over check's results, and any failure, in
  the local implementation. A failure during the aging is recorded and
  never tears the game down; `gmctl status` shows it first.
- Sealed checks judge the effective live state: for the databases, what
  is in effect on each instance, whichever file, statement or player
  changed it.

## 11. Out of scope

- Who may run the GM, and access to the repository: anyone with the
  repository.
- The security of the hosts and their Docker engines, beyond keeping the
  engines out of the players' reach; the Tailscale network between
  hosts; which hosts are shared with other applications, which the
  playground's declaration states and `gmctl fit` enforces for
  placement.
- Alert notification channels and HTTPS on the web front.
- Classroom swarms of student laptops.
- The governance of this project's own data: every scenario's data is
  synthetic.

## 12. Known gaps

- When the players own the host (solo play at home), the bastion-only
  rule and the secrecy of the answer key rest entirely on trust.
- A player who is also in the GM session can see the setup dialogue,
  which contains spoilers. Taking the report in a fresh session is
  recommended, not enforced.
- Credentials are shared by all players of a game and cannot be rotated
  during a game, a restart included.
- **Another party's database is report-only by the story alone.** The
  agency's `reporting` is technically fixable: an overstepping player
  can change its data, DDL, roles, settings, `pg_cron` jobs and crontab
  (moving or deleting f10's heavy entry, unscheduling f9's job, editing
  the close's procedure), reload or restart it, and run a job by hand.
  Nothing prevents it. The answer key judges the report or proposal the
  issue asked for; a check reading fixed after such a change is not the
  resolution; the feedback names the overstep and what it cost, and
  judges the change as a proposal (master spec 16.5). Accepted: the
  owner's choice over a write policy that could not have protected the
  database's contents from `dba` anyway.
- **Customer roles' passwords are within `dba`'s reach**: as a
  superuser, `dba` reads a user mapping's password, and, running
  programs as OS user `postgres`, a crontab's password file. Accepted:
  `dba` can already change any of those roles.
- **The GM's connection reserve** can be used up by `dba`, a superuser;
  accepted on the trust line.
- **Grafana's write policy cannot be enforced.** On a report-only Grafana
  node, players can still change dashboards, data sources and alert rules
  through the interface, since the tools password makes them
  administrators. Accepted; sealed checks judge the live state.
- **Grafana administration is forbidden but not prevented.**
- **Prometheus has no login of its own**: from any node of the game it is
  reachable directly, without the tools password. This adds read access
  only.
- **A fixable builder or transformer script is code** run as the
  scheduler's service account (section 8): it can print the schedule,
  and a script its open connections' passwords, to the log. Accepted on
  the trust line; no isolation.
- **The traffic can be inferred.** The schedule is hidden, but a patient
  reader can infer it from the schedulers' logs and the databases' own
  logs and statistics, as in a real system.
- **The web front uses plain HTTP**: the tools password crosses the
  network base64-encoded. Accepted.
- **Questions still open about access**: none. The policy the players
  audit is correct by design in v0.4; whether a policy may itself be
  wrong, as a planted fault in the starter documentation, is undecided
  and does not arise.

## 13. Changes from v0.3

- **Actors**: unchanged. The GM check role gains reads (section 8).
- **New resources**: the starter pack, the data policy in it; each
  database instance; `pg_cron` jobs and their runs; a database node's
  crontab; transformer scripts within the scheduler's repository; the
  customer roles' passwords wherever held, among the service
  credentials.
- **Database operations** split into `read` and `write`: `write`, DDL
  included, follows `fixable-node`, which holds on every database node,
  so nothing changes in practice.
- **No new write policy**: `postgres` stays fixable only. A database
  node another party owns in the story is report-only by the answer key
  and the story.
- **New condition**: `handed-over`. `before-hand-over` now also covers
  the GM's setup writes to the databases and jobs.
- **Denial behaviour**: a change on another party's database not
  refused, judged in the feedback as overstepping; a job run by hand
  treated as `control-load`; a failed out-of-memory incident not
  re-planted.
- **New section**: the customer's roles and data policy (section 9),
  the game's world rather than the game's access.
- **Known gaps**: another party's database report-only by the story
  alone; customer roles' passwords within `dba`'s reach; a fixable script
  able to print its connections' passwords.
