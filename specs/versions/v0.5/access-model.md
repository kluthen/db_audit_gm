# db_audit_gm v0.5 — Access model

Status: **draft v1, for the owner's review with the
[master spec](master-spec.md) it accompanies** (2026-11-03). Revises the
[v0.4 access model](../v0.4/access-model.md), which it replaces for v0.5
games; "Changes from v0.4" at the end lists what moved. Items decided
here for the first time are tagged (proposed) and listed in the master
spec's owner review (25) under R17 to R20.

## 1. Purpose and scope

This governs two things, kept apart:

- **The game's access** (sections 2 to 8, 11 to 13): who may do what in
  one v0.5 game: in the GM session, on the bastion and its web front, on
  every node in the players' scope (the database instances, the standby,
  the scheduler nodes, the `api` nodes, PgBouncer where present, the
  monitoring nodes), in each database, over the load and the jobs, on
  cold storage's read-only page, against the partners' public
  interfaces, and on the partners' nodes, which are out of reach.
- **The fiction's access** (sections 9 and 10): who in the clinic's
  world may do what: the centre's staff, the owners and keepers on the
  portal, the practices and the other partners, through the
  applications, database roles, credentials and row-level security of
  the system the players audit. None of them is an actor of the game.
  What a fictional role may read or write is a fact of the system under
  audit, which the players may find wrong; a breach of it is a fault the
  players find, never an access rule of the game.

It does not cover who may run the GM or read the repository (anyone
with the repository can), the security of the hosts, or the Docker
engine, which the players never touch. Enforcement is deliberately
light: rules the system enforces say so; the rest rely on trust and on
documentation in place ("DO NOT TAMPER", with the reason).

## 2. Actors

| Actor | Definition | How acquired | Stacks? |
|---|---|---|---|
| `initiator` | Whoever starts the game with the GM: a teacher, or a student playing alone | Invokes the GM skill in an agent session | Yes: a student playing alone is also a `player` |
| `player` | A student taking part in the game; one or many sit behind one report | Receives the bastion password and the tools password from the GM at hand-over | Yes, with `initiator` (solo play) and `session-participant` |
| `session-participant` | Anyone typing in the GM session, whatever their other role | Has the session in front of them | Yes |
| `gm` | The agent running the GM skill (non-human), with the scheduled `gmctl` runs it sets up during the aging and the `data-register` sub-skill it calls | Started by the initiator invoking the GM skill | No: exclusive |
| `network-visitor` | Anyone who can reach the hosts' networks, unauthenticated | Default state | No: exclusive |

Roles are scoped to one game. The `player` role is shared: all players
of a game use the same accounts and the same two passwords; the `dba`
role and its password are the same on every database instance in the
players' scope, the standby included (it is a replica of the primary's
roles). The partners' database has no `dba` for the players.

Not actors, acting only as configured, their credentials resources
below: the exporter's `monitoring` role (where the node chose the
option); the customer's application roles used by the scheduler and
`api` nodes; the cron daemons and `pg_cron` jobs; the replication role;
the archive and base-backup posting; the partners' back end and its
roles; the HTTP credentials each caller holds; the GM check role, which
acts only for the `gm` (section 8).

## 3. Role assignment and lifecycle

Unchanged from v0.4, restated:

- The `gm` exists from the moment the initiator invokes the GM skill; a
  fresh session resumes a game in progress. It composes the scenario at
  design time, runs the setup (the data load, the derivation step when
  sanctioned, the post-load coherence check, the standby's clone, the
  faults' planting, the register's generation), starts the load at T0,
  and between sessions acts only through the setup actions it
  scheduled.
- The `initiator` role ends at hand-over; the initiator then acts only
  as a `session-participant`, or as a `player` in solo play.
- The `player` role is granted by handing over the per-game bastion
  password and the tools password, in every game; neither can be
  revoked or rotated during a game. The starter pack, the data policy,
  `partners.md` and the data register included (each only when the
  scenario has it), is handed over at the same moment, with the
  partners' documented credentials.
- **A restart keeps the `player` role**: the rebuilt game keeps every
  generated secret under a new game id. A game of the whole clinic has
  no hand-over snapshot on the two hosts' declarations, so its restart
  starts from nothing, which the GM states before asking for the
  confirmation.
- Every role ends at teardown: services, secrets, volumes and snapshot
  removed; credentials stop working immediately.
- A stop request takes effect immediately; work in progress is lost.

## 4. Resources and operations

v0.4's resources stand; v0.5 adds the rows marked *new*.

| Resource | Operations |
|---|---|
| Game control (the GM session) | `start`, `stop`, `restart`, `report`, `request-help` (hint, reveal, node reset, extra time) |
| The load | `start-load`, `control-load` (pause, speed up, trigger, run now, any job included) |
| Setup actions | `schedule` (plant a fault at a moment, the early check), `hand-over` |
| *new* Composition and the initial load | `compose` (placement, `merge.yaml`, `composition.yaml`), `derive` (the sanctioned derivation step), `check-coherence` |
| Hand-over snapshot | `take`, `restore` |
| Scenario folder (repository), purposes and domains | `read`, `edit` |
| Answer key, GM notes and *new* the true data register (`gm/data-register.yaml`) | `read` |
| *new* The data register handout | `generate`, `read` |
| Starter pack (story, issues, data policy, *new* `partners.md`, *new* data register) | `read` |
| Bastion | `login`, `use` (shell, `ssh`, `scp`, `sftp`, `psql`, HTTP clients) |
| Web front (the starter-pack page, the web interfaces' routes, *new* cold storage's read-only page) | `reach` |
| Node shell (any node in the players' scope but the bastion) | `login`, `read-files`, `run-wrapper` (reload, restart, validate) |
| Node configuration files | `read`, `edit` |
| Node protected files | `read`, `edit` |
| Scheduler query repository, fixed-time operations, schedule, log | as v0.4: `read`, `edit` |
| *new* `api` node endpoint files: `routes/` (the contract) and `db/` (queries, transactional work, session settings) | `read`, `edit` |
| Database (PostgreSQL), each instance in the players' scope | `connect`, `read`, `write`, `alter-system` |
| *new* The standby | `connect`, `read`, `alter-system` (its own settings), `promote` |
| `pg_cron` jobs, a database node's crontab, logs and pgBadger | as v0.4 |
| The GM's connection reserve | `connect-reserved` |
| Service credentials (monitoring role, application roles' passwords and HTTP credentials wherever held, replication role, GM check role) | `read` |
| *new* A partner's public interface (its routes on the partners' `api` node, by hostname) | `call` |
| *new* Cold storage's endpoints | `view` (`GET /`, `GET /manifests`), `upload` (`POST /shipments`) |
| *new* The partners' nodes (the `api` node, the back end, the database) | `login`, `connect`, `any` |
| PgBouncer console, Prometheus, Grafana | as v0.4 |
| *new* The monitoring breadth (pgwatch, pgCluu, the health check), as ruled | `view`, `edit-content` |
| Swarm and Docker engine | `any` |

Listing and reading one item do not differ for any resource of the
game. In the fiction they do: row-level security on the portal filters
lists and single rows alike (section 9.3), and `pg_cron` shows a
non-superuser role only its own jobs.

## 5. Permission matrix (the game)

**Game control, the load and the setup**: unchanged from v0.4. `start`
the initiator and the GM; `stop` anyone in the session; `restart`
`confirmed-in-session` for a player, `players-confirmed` for the GM;
`report` `in-session`; `request-help` denied to all; `start-load`,
`schedule` and snapshot `take` the GM's only, `before-hand-over` (the
snapshot `at-hand-over`); `hand-over` `aging-done`; `control-load`
denied to all.

**Composition and the data register**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| composition `compose` | deny | deny | deny | `at-design` | deny |
| composition `derive` | deny | deny | deny | `sanctioned` | deny |
| composition `check-coherence` | deny | deny | deny | `before-hand-over` | deny |
| register `generate` | deny | deny | deny | `before-hand-over` | deny |
| true register `read` | `has-repository` | `has-repository` | `has-repository` | allow | deny |
| register handout `read` | `has-repository` | `handed-over` | `has-repository` | allow | deny |

**Scenario folder, answer key and starter pack**: as v0.4 (`read` and
`edit` the scenario folder `has-repository` for the initiator, the
answer key `has-repository` for anyone, never shown in play; the starter
pack `handed-over` for a player). `partners.md` follows the starter
pack.

**Bastion and web front**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| bastion `login` | `holds-password` | allow | `holds-password` | allow | deny |
| bastion `use` | `holds-password` | allow | `holds-password` | allow | deny |
| web front `reach` | `holds-tools-password` | allow | `holds-tools-password` | allow | deny |

**Nodes in the players' scope** (the database instances, the standby,
the scheduler nodes, the `api` nodes, PgBouncer, the monitoring nodes)

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

**Scheduler nodes**: as v0.4 (repository, `jobs.yaml` and log `read`
`from-bastion`, `edit` `fixable-file`; the schedule `read` the GM's
only, `edit` denied to all; metrics `in-game-network`). The ward service
`ward` and the lab's `lis`, `pms`, `equipment`, `interfaces` and
`backoffice` are scheduler nodes.

**`api` nodes** (`clinic-api`, `lab-api`, `portal-api`)

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| `routes/` `read` | deny | `from-bastion` | deny | allow | deny |
| `routes/` `edit` | deny | deny | deny | allow | deny |
| `db/` `read` | deny | `from-bastion` | deny | allow | deny |
| `db/` `edit` | deny | `fixable-file` | deny | allow | deny |
| reload wrapper | deny | `fixable-node` | deny | allow | deny |
| call its endpoints | deny | `in-game-network` | deny | allow | deny |

**Databases** (`records`, `lab`, `machines` and any other in scope),
**the standby, their jobs and logs**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| database `connect` | deny | `from-bastion` | deny | allow | deny |
| database `read` | deny | `from-bastion` | deny | allow | deny |
| database `write` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| database `alter-system` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| standby `connect`, `read` | deny | `from-bastion` | deny | allow | deny |
| standby `alter-system` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| standby `promote` | deny | deny | deny | deny | deny |
| `pg_cron` jobs `list` | deny | `from-bastion` | deny | allow | deny |
| `pg_cron` jobs `change` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| crontab `list` | deny | `from-bastion` | deny | allow | deny |
| crontab `install` | deny | `fixable-node` | deny | `before-hand-over` | deny |
| `read-logs`, `run-pgbadger` | deny | `from-bastion` | deny | allow | deny |
| `connect-reserved` | deny | deny | deny | allow | deny |
| service credentials `read` | deny | deny | deny | allow | deny |

**The partners and cold storage**

| Operation | `initiator` | `player` | `session-participant` | `gm` | `network-visitor` |
|---|---|---|---|---|---|
| a partner's public interface `call` | deny | `documented-call` | deny | allow | deny |
| cold storage `view` | `holds-tools-password` | `through-web-front` | `holds-tools-password` | allow | deny |
| cold storage `upload` | deny | deny | deny | deny | deny |
| partners' nodes `login` | deny | deny | deny | allow | deny |
| partners' database `connect` | deny | deny | deny | allow | deny |
| partners' nodes `any` other | deny | deny | deny | `before-hand-over` | deny |

**Monitoring interfaces**: as v0.4 (Prometheus and Grafana `view`
`through-web-front`, Grafana `edit-content` `fixable-grafana`, the
administration and Prometheus' admin denied). The monitoring breadth's
interfaces follow Grafana's rows, `view` `through-web-front` and
`edit-content` `fixable-grafana` read for that node, once their design
is ruled.

**Swarm and Docker engine**: `owns-host` for the initiator, allow for
the GM, deny otherwise.

## 6. Conditions

v0.4's conditions stand: `in-session`, `confirmed-in-session`,
`players-confirmed`, `before-hand-over`, `aging-done`, `at-hand-over`,
`handed-over`, `has-repository`, `holds-password`,
`holds-tools-password`, `from-bastion`, `fixable-node`, `fixable-file`,
`in-game-network`, `through-web-front`, `fixable-grafana`, `owns-host`,
each as defined there. Restated where v0.5 reaches them, and added:

| Condition | Holds when |
|---|---|
| `before-hand-over` | As v0.4: from deployment to the hand-over. For the partners' nodes, the GM acts only through the setup and their hidden schedule, which keeps running after the hand-over as every schedule does |
| `fixable-node` | `from-bastion` holds and the node's write policy is *fixable*. Every database node in the players' scope, the standby included, is fixable; an `api` node may be fixable or report-only, per scenario |
| `fixable-file` | `from-bastion` holds and the file is fixable: the node is *fixable*, or the scenario's write overrides make that path fixable on a report-only node. On an `api` node only paths under `db/` can be fixable; `routes/` never is |
| `at-design` (new) | The GM is designing or regenerating the scenario, before deployment: placement within the domains' declared constraints, the merge's resolutions, the composition record |
| `sanctioned` (new) | `before-hand-over` holds and the scenario's composition record lists the derivation step, after the loads it reads |
| `documented-call` (new) | `in-game-network` holds and the call uses the endpoints and credentials `partners.md` documents for that partner, as the customer's staff could; never another partner's credentials, never the partners' back end |
| `through-web-front` | As v0.4, and for cold storage: the request passes the bastion's web front with the tools password, to `GET /` or `GET /manifests` under cold storage's hostname only |

## 7. Denial behaviour

Every forbidden resource in the players' scope stays visible: a denied
action is refused where it is attempted, or, where the system cannot
refuse it, forbidden by the rules in place. **The partners' nodes are
the exception: they are hidden** (no account, not listed in the starter
pack, not on the bastion's routes), since a third party's internals are
not the customer's to know; only their public interfaces, by hostname,
are documented. v0.4's rows stand (help refused politely, no reveals, a
restart only on a confirmation in so many words, `control-load` refused,
the setup the GM's, schedule edits impossible, SSH and HTTP refusals,
permission denied on protected and non-fixable files, PgBouncer's
`admin`, Prometheus' admin and Grafana's administration). Added:

| Operation class | Behaviour | Rationale |
|---|---|---|
| Login to a partners' node, or a connection to the partners' database | Nothing to log in as: no `player` account exists there (`no-access`); the database's `pg_hba.conf` rejects every role but the partners' own; the players are not told the nodes' names | A real partner's internals are not reachable; hiding alone would not do on one network |
| A fix needing a partner to change | Never expected: no answer key's *fix* names a partner. Telling the partner, with the evidence, is written in the report and may be credited | Every fix is the customer's |
| Writing to the partner's support contact | Not answered during the game; the players write in their report the message they would send | The GM plays no partner |
| A call to a partner's interface with another partner's credentials, or to its undocumented routes | Refused by the stub as the real service would (401 without a valid credential, 404 for an unknown route) (proposed) | A partner's interface, not its internals |
| Forging a partner's traffic (posting results, shipments or acknowledgements as the partner, from a node) | Not refused: reachable on the one network. Forbidden by the rules; the GM's checks read the partner's side as evidence and judge the customer's, so forged traffic is named in the feedback as an overstep and earns nothing | Trust where it cannot be enforced (Known gaps) |
| Cold storage's upload endpoint through the bastion | Not routed: the bastion proxies `GET /` and `GET /manifests` only; any other path answers 404 | The one exception to third parties' absence is read-only |
| Editing an `api` node's `routes/` | Ordinary "permission denied" (read-only, root-owned); the reload wrapper reloads the `db/` side only | The contract is the application's, the database side the DBA's |
| `promote` on the standby | No wrapper offers it; `pg_ctl promote` as `postgres` is reachable to `dba`'s programs but forbidden by the rules and marked DO NOT TAMPER | Redundancy is audited, not exercised; restores wait for v1.0 or after |
| Editing the data register handout in `/home/player` | Not refused (it is the players' home copy); it changes nothing: the GM judges the corrected entry in the report against the answer key, and the sealed check reads the bastion's seed copy | A register fault is resolved by *propose* |
| Asking the GM for the true register | Refused like any reveal before the final answer | No reveals |
| Asking the GM to switch a faulty display off | Refused: the GM never changes the load during play; a display fault is judged on the report | No events outside the schedule |
| The coherence check failing at setup | The GM does not hand over: it fixes the composition and reloads, never handing an incoherence over as something to find | A design error is not a fault |
| A deploy of a scenario listing `domains:` without a register, or with a stale one | Refused by the loader, with the reason | The register is part of a complete scenario |

Denials are not logged by the game, except `sudo` uses and the partners'
stubs' own request logs, which the GM may read as evidence. Repeated
denials have no effect.

## 8. Elevation, delegation and non-human actors

- The `gm` is the only non-human actor, as in v0.4. It also runs the
  composition, the derivation step when sanctioned, the coherence check
  and the standby's clone at setup, and calls the `data-register`
  sub-skill; during play it never shows or quotes the true register.
- **The GM check role** (`gm_check`) keeps v0.4's reads, on every
  instance in the players' scope, the standby (by replication) and
  `machines`' three databases included (`CONNECT` granted by
  `load-data`). It is not admitted to the partners' database; the GM's
  checks read the partners' side through the GM's own plane (the exec
  operation on the partners' nodes, cold storage's manifests), as
  evidence only.
- **Elevation on a node** is v0.4's: the `sudo` wrappers for `player`
  (reload, restart, validate, `gm-crontab`), and on an `api` node a
  reload of the `db/` side. None exists on the partners' nodes.
- **`dba` is a PostgreSQL superuser** on every instance in scope, the
  standby included for reads; it can therefore bypass any fictional
  rule: read past the portal's row-level security, read every role's
  grants, change any policy. Accepted: that is the players' power as the
  customer's DBAs, and what a planted fault breaks they find through it.
- **A fixable `db/` side is code**: a player editing it runs SQL as the
  API's application role; a fixable builder or script runs Python as
  the scheduler's account, which may print the HTTP credentials it
  holds. Accepted on the trust line.
- No break-glass path and no delegation; credentials are shared by all
  players of a game.

## 9. The fiction's access: the clinic's people and roles

Not the game's access: the state of the system the players audit. The
fiction's people never appear as logins: each acts through an
application, and each application connects as a database role or an
HTTP credential. The producers model only what each person may do, so
**a forbidden action in the fiction is never attempted by the load; it
appears only as a planted fault**, which the players find in the data,
the grants or the logs. Each domain's grants are listed role by role in
the master spec (9.2 to 9.7) and in full in the domain documents; this
section states who stands behind them.

### 9.1 The centre's staff

85 staff, all the centre's, identified by staff id; no person has a
database login of their own.

| Who | Ids | Works through | May | May not |
|---|---|---|---|---|
| **Vets** of the horse, farm and domestic sections | 1–25 | the practice software on `pms` (`vet_app`; scheduling's module as `sched_app`) | consult, diagnose, prescribe, administer and dispense, admit and discharge, request lab tests and imaging, sign consultations (what the portal may then release), refer, record exchanges with other centres, notify a notifiable disease | release a lab result; change the reference tables (species, medicines, diagnosis codes); cancel a request once sent to the lab or to imaging (they phone; the lab or the imaging team cancels) |
| **Imaging vets** | 26–28 | the imaging archive on `machines` (`pacs`, `mach_pacs_app`), the practice software | report studies, which close the core's imaging requests | the sections' record beyond their requests |
| **Nurses and technicians** | 29–51 | `pms` (`vet_app`), housing's screens | record administrations, observations, admissions' details, place animals in units | sign a consultation; prescribe |
| **Radiographers** | 52–55 | `pacs` (`mach_pacs_app`), the worklist | acquire studies, cancel a sent imaging request on the vet's call | report a study |
| **The biomedical engineer** | 56 | `biomed` (`mach_biomed_app`) | record maintenance, calibrations, QA, downtimes, set a machine's status | the clinical record; the vendors' remote service is a separate role, `mach_service` |
| **Carers and grooms** | 57–66 | housing's screens on `pms` (`housing_app`) and the ward service (`housing_ward`, through the displays' actions) | log care and feeding, set a unit's state | place or release an animal; read owners' contacts |
| **Receptionists** | 67–70 | `pms` (`vet_app`), and the portal's desk (the desk's credential on `portal-api`) | register owners, keepers, animals and herds, change contacts, book and check in, record an owner's reminders' consent at the desk | sign, prescribe, see the portal's documents as an owner |
| **The lab's technicians** | 71–78 | the lab's information system on `lis` (`lab_app`; the analysers' middleware `lab_instruments`) | receive samples, run analyses, validate technically, record critical calls, cancel a test on a vet's call | release a result |
| **The lab's clinical pathologists** | 79–80 | `lis` (`lab_app`) | release results (the release rounds), amend, notify the authority for the lab | the clinical record beyond the lab's |
| **Instructors** of the training centre | 81–85 | scheduling's module on `pms` (`sched_app`) | plan sessions, enrol trainees, record attendance and certificates, book the training rooms and teaching animals | the clinical record |
| **The back office's staff** | (no staff id) | `office` (`office_reader`) | read the reports' outputs, the statements, the submissions' copies | the clinical record; any write |

Every display in the wards is a device, not a person: it reads its
unit's board as `vet_display` through the ward service, nothing else.

### 9.2 The applications' roles, by node

| Node | Application | Roles |
|---|---|---|
| `pms` | the practice software, its scheduling module, housing's screens, the portal's desk | `vet_app`, `sched_app`, `housing_app`; the desk's HTTP credential |
| `lis` | the lab's information system, the analysers' middleware | `lab_app`, `lab_instruments` |
| `ward` | the ward service | `vet_display` (pool of four), `housing_ward` (pool of two) |
| `equipment` | the machines' software | `mach_pacs_app`, `mach_vitals_app`, `mach_biomed_app` |
| `interfaces` | the integration jobs | `vet_interfaces`, `vet_exchange`, `sched_interfaces`, `vet_portal_sync`, `lab_dispatch`, `portal_sync`, `portal_dispatch`, `mach_orders`, `mach_archive`; account 1's credential on `lab-api` |
| `backoffice` | the reports | `vet_reports`, `sched_reports`, `lab_reports` (reading the standby and `lab`), `office_jobs` (writing `office`) |
| `clinic-api` | the core's lookup and exchange API | `vet_lookup`, `vet_exchange` |
| `lab-api` | the lab's order API | `lab_api` |
| `portal-api` | the owners' portal API | `portal_api` |
| `lab` (`pg_cron`) | the critical calls' watch | `lab_watch` |
| `records` (`pg_cron`) | the portal's housekeeping | `portal_housekeeping` |
| `machines` (`pg_cron`) | partitions ahead | `mach_maint` |

Owner roles (`vet`, `lab`, `sched`, `housing`, `mach`, `portal`) own
their tables and cannot log in. `CONNECT` on `clinic`, `office`,
`portal` and each of `machines`' databases is granted by name and
revoked from `PUBLIC`; `pg_hba.conf` admits `portal_api` to `portal`
only, over `hostssl`. Every login role's password, and every HTTP
credential, is a generated secret the players never see in a catalog.

### 9.3 Owners and keepers, on the portal

The portal shows each owner what the centre released about the animals
they own now. Every portal table has row-level security enabled and
forced; `portal_api` owns nothing and cannot bypass it. A request is one
transaction: after login, the API checks the session (`portal_session`:
open, seen within 30 minutes, under 12 hours old), then sets
`portal.owner_id` to that account's owner for that transaction only;
every policy scopes to it.

| Operation | An owner | A keeper | The desk | Anyone not logged in |
|---|---|---|---|---|
| activate an account (invitation link, 14 days) | `own-invitation` | `own-invitation` | deny | `own-invitation` |
| log in, log out | allow | allow | deny | log in only |
| request or perform a password reset | allow | allow | deny | `own-email` |
| list animals | `current-owner` | `current-keeper-granted` | deny | deny |
| list an animal's documents (newest first, 50 at most) | `current-owner` and `since-ownership` | `current-keeper-granted` and `since-ownership` | deny | deny |
| open a document (the opening recorded) | `current-owner` and `since-ownership` | `current-keeper-granted` and `since-ownership` | deny | deny |
| change the notification channel | own account | own account | deny | deny |
| grant or withdraw the reminders' consent | own account | own account | `at-desk` | deny |
| grant or withdraw a named keeper's access to one animal | `current-owner` | deny | deny | deny |
| unsubscribe from a reminder | allow | allow | deny | `own-message-link` |
| close the account | own account | own account | deny | deny |
| change contacts (name, e-mail, phone) | deny: at the core's desk, copied in | deny | allow, through `pms` | deny |
| book, pay, message a vet, see imaging | deny | deny | deny | deny |

Conditions (the fiction's): `current-owner`, the account's owner holds
the animal's current `owner` ownership (no end); `current-keeper-granted`,
the account's owner holds its current `keeper` ownership and the
current owner's latest `keeper-access` event for that keeper and animal
is a grant (a herd's documents go to its keeper); `since-ownership`,
the document's record time is on or after the current ownership's
start, so a buyer never sees the record from before the sale and a
seller nothing after it; `own-invitation`, the link's one-time token is
the account's and unexpired; `own-email`, the reset goes to the
account's own e-mail whatever was typed; `own-message-link`, the
message key is the reminder's; `at-desk`, a receptionist records it
through `pms` with the desk's credential, source `desk`.

**Denial behaviour on the portal: out of scope is hidden, never
blocked.** A list returns fewer rows or none; a document out of scope is
not returned (`404`, proposed), so an owner cannot learn that another
owner's animal or document exists. A wrong password answers `401`; five
failures lock the account for 30 minutes (`423`); success `201` with a
token. An expired, idle or ended token yields no account (`401`,
proposed). An insert outside the asker's scope fails the policy's check
and answers an error (`403`, proposed). A keeper-access grant by an
account that is not the animal's current owner is refused the same way,
not stored (proposed). A closed account cannot log in, reset or
unsubscribe (`401`, as for no account, proposed); an `invited` account
logs in only after activation. A reset for an unknown e-mail answers as
for a known one, so the portal never confirms an address (proposed).

Owner 1, the clinic itself, has no account. Vets and pathologists never
use the portal.

### 9.4 Where the fiction's rules are enforced, and where they are not

- **Enforced by the database**: the grants per role, `CONNECT` by name,
  `pg_hba.conf`'s lines, the portal's row-level security, the
  `SECURITY DEFINER` functions with a fixed `search_path`, the exclusion
  constraints on bookings.
- **Enforced by the applications, and checked as invariants**: which
  staff kind may release, sign, cancel or place (a result released only
  by a pathologist; a sent request cancelled only by the lab or the
  imaging team; a document published only once signed, released or the
  stay ended). The roles are per application, not per person, so the
  database cannot tell a technician from a pathologist; the purposes'
  checks and the audit trail (pgaudit, the release records) can.
- **Policy only**: what may leave (the data policy's outbound fields),
  retention, statement logging free of personal data. The players audit
  these against the system.

## 10. The partners, in the fiction

Each partner reaches the customer only through the customer's API
nodes, or is reached by the customer's jobs; none reaches a database of
the customer's. Its credential is a secret on the partners' back end.

| Partner | Reaches the customer | Is reached by | May | Refused when |
|---|---|---|---|---|
| The external reference lab | `lab-api` `POST /send-outs/{send_key}/result` | `interfaces`' send-outs (catalogue fields only) and chases | answer a send-out, resend on request | its credential is wrong (401) or the send key unknown (404) (proposed) |
| The region's practices (the lab's outside customers) | `lab-api` `POST /orders`, `GET /orders/...`, the results feed, each as its own account | `interfaces`' deliveries to each account's callback | order, follow its own orders and results | another account's order or feed: hidden, 404 (proposed) |
| The two other national centres, the centres abroad | `clinic-api` `POST /exchanges`, `/answer`, `/report` | `interfaces`' exchanges (the animal's record and its owner's contact, under the franchise's agreement) | request a transfer or examination, answer, report back | another exchange's key (404, proposed) |
| The authority | no route to the customer | `interfaces`' notifications, `backoffice`'s yearly antimicrobial-use report | acknowledge with a reference | — (it calls nothing) |
| The franchise's head office | no route to the customer | `backoffice`'s monthly figures | acknowledge | — |
| The franchise's messaging service (a processor) | no route to the customer | `portal_dispatch` and the core's outbox | deliver | — |
| Cold storage, the vault (a processor) | no route to the customer | the shipping job, `archive_command`, the nightly base backups | answer receipts; show its page and manifests to the players | — |
| The owners' browsers (`owners`, no business) | `portal-api`, as each owner's session | — | as 9.3 | as 9.3 |

## 11. Audited and confirmed operations

v0.4's stand: `restart` the one confirmed operation; `stop` obeyed at
once; the final answer stated as final; `sudo` wrapper use logged; the
GM recording the game's stage and its setup's results; sealed checks
judging the live state. Added: the composition record and the coherence
check's result kept in the scenario folder and the local implementation;
the true register's digests recomputed by the loader before deploy; the
partners' stubs logging every call they receive, which the GM reads as
evidence. In the fiction: pgaudit on the record, the lab and the portal
(writes, DDL and roles, without parameters); every portal opening
recorded; the release and validation records; the consent events.

## 12. Out of scope

- Who may run the GM, and access to the repository: anyone with it.
- The hosts' security and their Docker engines; the network between
  hosts; which hosts are shared, which the playground's declaration
  states and `fit` enforces.
- Alert notification channels and HTTPS on the web front.
- Classroom swarms of student laptops.
- Separate networks for third parties.
- The governance of this project's own data: every scenario's data is
  synthetic, and the repository keeps no data register.
- The fiction's people as logins: no staff member, owner or partner has
  an account of the game.

## 13. Known gaps

v0.4's stand: solo play on owned hosts rests on trust; a player in the
GM session can see the setup's spoilers; credentials are shared and not
rotated; customer roles' passwords and the GM's reserve within `dba`'s
reach; Grafana's write policy and administration not enforced;
Prometheus without a login; a fixable script is code; the traffic can
be inferred; the web front on plain HTTP. Added:

- **The partners are out of reach by `no-access` and their own access
  rules, not by a network.** On the one network, a player with a shell
  on a node reaches the partners' `api` node and could forge a partner's
  traffic or post to cold storage's upload endpoint. Forbidden by the
  rules, not prevented; the checks judge the customer's side, and the
  feedback names the overstep.
- **How the partners' database admits only their own nodes** on one
  Swarm network, whose task addresses change, is the build's to verify;
  until then the guarantee rests on the roles' passwords being mounted
  on the partners' nodes only.
- **The partners' stubs are in the repository**: reading them there is
  the trust the repository already accepts.
- **`dba` bypasses every fictional rule**, the portal's row-level
  security included. Accepted: the players are the customer's DBAs.
- **The standby can be promoted** by `dba` through programs run as
  `postgres`; forbidden by the rules, not prevented.
- **A whole-clinic game has no hand-over snapshot** on the two hosts'
  declarations: a restart starts from nothing.
- **The portal's answers beyond login's** (a document out of scope, an
  ended token, an insert out of scope, a closed account, an unknown
  e-mail's reset, a non-owner's keeper grant) and the partners' refusals
  are decided here as proposals; the build writes them into the
  endpoints, and the owner's review confirms them.
- **The monitoring breadth's interfaces** follow Grafana's rules once
  their design is ruled; until then they are not in the matrix beyond
  that sentence.

## 14. Changes from v0.4

- **Actors**: unchanged. The GM gains the composition, the coherence
  check, the standby's clone and the register's generation; the GM check
  role reaches every instance in scope, not the partners'.
- **New resources**: composition and the register; the `api` nodes'
  `routes/` and `db/`; the standby; partners' public interfaces, cold
  storage's endpoints, the partners' nodes; `partners.md` and the data
  register in the starter pack; the monitoring breadth.
- **Hidden, for the first time**: the partners' nodes, by `no-access`
  made real; their interfaces documented, cold storage's page routed by
  the bastion, the one exception.
- **New conditions**: `at-design`, `sanctioned`, `documented-call`;
  `fixable-file` on an `api` node limited to `db/`.
- **Denial behaviour**: partners' logins impossible, forged partner
  traffic an overstep, the standby not promoted, a register fault
  proposed and never edited into the system, a display never switched
  off, an incoherent load never handed over.
- **The fiction's access** (sections 9 and 10): the clinic's staff by
  kind, the applications' roles by node, the owners' and keepers'
  portal with row-level security, the partners' reach, and where each
  rule is enforced.
