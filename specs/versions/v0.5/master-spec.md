# db_audit_gm v0.5 — Master specification

Status: **approved by the owner on 2026-11-03.** Consolidated on the
owner's word ("yes, start the master spec") from v0.5's draft documents
and the owner's rulings of 2026-10-31 to 2026-11-03, and approved with
every point of its review as recommended, the monitoring breadth
written in (7.4, 14) and the domain documents brought into line with
it. Companions: [access-model.md](access-model.md), and the six domain
documents, approved with this spec as the domain procedure's step 9
requires and the detailed build input of each domain's folder:
[`vet-core`](vet-core-domain.md), [`vet-lab`](vet-lab-domain.md),
[`vet-scheduling`](vet-scheduling-domain.md),
[`vet-housing`](vet-housing-domain.md),
[`vet-machinery`](vet-machinery-domain.md) and
[`vet-portal`](vet-portal-domain.md). This spec states each domain's
essentials and contracts; the domain document carries its column-level
model, every grant, every classed column and every trap. Where the two
disagree, this spec wins.

Amended after approval, on 2026-11-03, by wave 1's preflight
corrections, settling what the approved text left to the build: a
domain's producer fragments in one folder per scheduler node they target
(6.1, 8.4; spec D344), and the `api` node's `api.yaml`, the file naming
each endpoint's hostnames and credentials and its connections (6.5,
6.8; spec D345). On 2026-11-04, a text correction: pgwatch is its
latest release at the build, not a 3.x one, a line that ended at 3.7.0
(7.4, 21; spec D368).

Baseline: the released [v0.4 master spec](../v0.4/master-spec.md) and
its [access model](../v0.4/access-model.md). Everything v0.4 specifies
stays in force unless this document changes it; where they disagree,
this document wins for v0.5. The cross-version format rules are in
[formats.md](../../formats.md), which v0.5's consolidation brought to
draft v28 with the domain format (section 6.1).

---

## 1. Concept and objective

db_audit_gm generates live database audit exercises: an agent, the game
master (GM), deploys a deliberately flawed data stack on a container
cluster, hands it to students (the players) through a single bastion,
receives their report and gives teacher-style feedback. v0.1 settled the
GM's stance on one static PostgreSQL database, v0.2 added monitoring and
the usual tooling, v0.3 made the stack alive with producers and
consumers aging it in real time, v0.4 added what the customer's data is
for: purposes, several instances, a first cut of data governance and the
first business domain, the shop.

v0.5 is about **defining business domains**, with a large veterinary
clinic as the worked example. In the owner's words: "we will then focus
on domain definition and the veterinary clinic franchise as a good
example, which will require us to add a few items in the project. We
will move all tools not related to the clinic use case for a later
date." The clinic, as he described it: "a big clinic: horse section
(housing, dedicated machinerie, multiple specialists); farm section
(same); domestic section; biology (lab, blood analysis machinerie,
etc); formation center (rooms, instructors, canine and horse dedicated
training) ... they have an heavy need on scheduling, data management
and redundancy, but also quite strict reporting needs. they are also
heavily connected both inside and outside". Concretely:

- a **procedure for defining a domain**, what goes in and what does
  not, from a brief to a built and proven folder (section 8);
- the **domain format** finished: composite domains as a core and
  parts, a domain's scale, variants and tags, its producer material
  merged by a design-time script, its business rules and register
  fragment, and the composition of several domains into one scenario,
  with an initial load the GM adjudicates for coherence (sections 6, 8);
- the **clinic's six domains**, one centre of a regional veterinary
  hospital franchise: the medical record (`vet-core`), its laboratory,
  bookings and the training centre, the wards and their displays, the
  machines and their databases, the owners' portal (section 9);
- **third parties** made a defined thing: the partners a business
  depends on, out of the players' reach, stubbed on shared nodes, with
  **cold storage** as a generic partner for heavy data and the off-site
  vault (section 10);
- **round trips** as a purpose kind of their own, and **periodic
  reports**, among the clinic's sixteen purposes (section 12);
- **redundancy**: a readable standby off site, WAL archiving and nightly
  base backups to the vault, a back-office database the reports write to
  (section 11);
- **governance beyond the first cut**: TLS and pgaudit always available,
  the clinic's own rules, row-level security on the portal, and a
  scenario's **data register** handed to the players, itself able to
  carry a fault (section 13);
- the bricks the clinic needs: a new **`api`** brick, the scheduler's
  **HTTP driver**, `postgres`' standby mode, archiving and its first
  **option**, and the monitoring breadth a setting this complex needs
  (section 7);
- one **clinic scenario**, deployed whole once as the proof in play,
  with a test selection of ten faults and a false alarm (section 17);
- **short tests only**: every check under 30 minutes on a minimal
  fixture; long runs wait for the major test before v1.0 (section 18).

## 2. Scope

### In scope

- The domain procedure (8.1) and the domain format beyond v0.4: parts,
  placement constraints, several databases, the derivation step,
  classification keys without the database, the business's own rules,
  the register fragment, variants, scale and tags, the producer
  material's layout (6.1, 8).
- `gmctl compose` and `merge.yaml`; the composition record
  `composition.yaml` and the post-load coherence check (8.4, 8.5, 15).
- The clinic's six domains, one centre of the franchise, each built in
  `domains/<id>/` with one variant, `regional-franchise` (9).
- Third parties: what they are, how a game builds them, what the
  players are told (`partners.md`); `no-access` made real; one shared
  back end and one `api` node for every partner of a scenario (10).
- Cold storage, a generic partner for heavy data, and the vault for WAL
  and base backups (10.4, 11).
- Replication: a readable standby of the core's instance off site, WAL
  archiving, nightly base backups; the back-office database `office` (11).
- The purpose format's extensions: the round-trip kind, the `api` and
  `partner` parts, HTTP connections, endpoint material, periodic
  purposes with planted history, how an invariant is judged, a
  purpose's own classes, the `ops` schema (6.6, 12.1).
- The clinic's purposes: sixteen defined, those built in v0.5 listed in
  12.2.
- Periodic reports (weekly, monthly, yearly), their past periods
  planted; no run on demand (8.4, 12).
- Governance: TLS and pgaudit always available in `postgres`, turned on
  by the seed; the clinic's default policies; row-level security on the
  portal; a scenario's data register as a player handout, generated by
  a new GM sub-skill, `data-register`, with its own trap family (13).
- Bricks: `postgres` 0.5.0, `scheduler` 0.3.0, `api` 0.1.0 (new),
  `bastion` 0.5.0, `grafana` 0.3.0 (a pgwatch dashboard); the monitoring
  breadth for the clinic: a `pgwatch` brick, pgCluu in `postgres`, and a
  `health-check` brick with a status page and the customer's hand-made
  scripts (7.4).
- The options model, with one option: the `monitoring` role on
  `postgres`, chosen per node (7.1).
- The clinic scenario, its test selection of ten faults and a false
  alarm, built with their fixtures; its data register (17).
- Short tests only, and one whole-clinic deployment on two hosts (18).
- The post-mortem collection, begun in v0.5 as a side track, already
  merged: `post_mortem/` at the repository's root, not bound to any
  fault, brick, domain or scenario (2, out of scope, for its binding).

### Out of scope (deferred, still part of the project)

- Domains other than the clinic's: a warehouse, a factory, a lab on its
  own, the shop's other variants. In the owner's words: "i belive v0.5
  is already big, so they'll wait". A domain-definition skill comes
  once the procedure has served two or three domains.
- The franchise's messaging service as a domain: it is the franchise's,
  a third party the centre's outbox traces.
- Billing beyond the lab's outside customers: invoices to animal
  owners, payments, insurers.
- Appointment reminders: the portal reminds owners of vaccinations
  only, with their consent.
- Running a periodic report on demand ("run March's report now"):
  later, probably v1.0 or after, on an instance spawned for it.
- Restores, point-in-time recovery, restore drills, pgBackRest and its
  kind: v1.0 or after, with backup tooling; the vault keeps manifests,
  not data.
- TimescaleDB and engines other than PostgreSQL: beyond v1.0; the
  machinery's readings use plain partitioned tables.
- Other brick options than `monitoring`, image variants, options on
  bricks other than `postgres`.
- Message queues: none, no flow needs one.
- Separate networks for third parties (one network stays), network
  faults.
- A status page for partners, a reporting tool, the setup's common
  entry point: v0.6, with the bastion's overhaul.
- Handing back a corrected data register as a file: v0.6's reporting
  tool. A register fault is resolved by *propose* in v0.5.
- Starter documentation other than the register carrying faults: v0.6.
- The undersized transformer as a fault: after v1.0, with the provider's
  capacity family.
- Scenario generation (v1.0); seeded variation per deployment and
  promoting scenario-only bricks and faults (after v1.0); datasets such
  as Bluebox, later candidates for domains (version not set).
- Binding the post-mortems to faults, and their end-of-game handout: a
  later version; the handout, when it comes, follows the final answer
  and summarises and links its source, never copying it.
- Every long-running test: the clinic aged and played, its overnight
  and periodic cadences in scenario time, growth over an aging, the
  rehearsal, the stance check-list; the major test before the v1.0 tag
  (18.4).
- A data register for this repository, and a data preflight: every
  scenario's data is synthetic; the game's own inventory is its
  catalogue (21).

## 3. Actors

Unchanged from v0.4: the initiator, the players, anyone in the GM
session, the GM, and the unauthenticated network visitor. v0.5 adds no
game actor. It gives the players more to reach (the clinic's nodes, a
standby, `api` nodes they read and partly edit, cold storage's read-only
page through the bastion, the partners' public interfaces) and two more
handouts (`partners.md`, the data register); and it places the
partners' nodes out of their reach. The clinic's staff, owners, keepers,
practices and partners are the fiction's people and businesses: they
exist as database roles, application credentials and rows, which the
players audit; they are not actors of the game. The full rules, the
game's access and the fiction's apart, are in the
[access model](access-model.md).

## 4. Glossary (additions and changes)

| Term | Meaning |
|---|---|
| Domain (restated) | A reusable catalogue unit of one kind of business: its data model and history, producer material, classification, own rules, register fragment, the purposes that fit, its GM notes with its traps |
| Core, part | A composite domain's core holds the keys every part shares; a part names its core (`requires`), never another part, refers to the core's keys by id without foreign keys, and is taken only with its core |
| Scale | A domain's size on three axes: population, history, throughput |
| Variant | A short manifest naming a setup a domain covers: its parts, scale, purposes and tags |
| Tag | A word from a fixed vocabulary stating a variant's maturity, reach or traits |
| Fragment | A piece of a scheduler node's seed files (`queries.yaml`, `schedule.yaml`, `jobs.yaml`) that a domain, a variant or a partner contributes |
| Merge | `gmctl compose` combining a node's fragments, layer by layer, into the scenario's files |
| Composition | Placing a scenario's domains, feeding their keys, choosing their cross-part purposes and checking their initial load; recorded in `composition.yaml` |
| Coherence check | The post-load check that every part's references resolve in its core and the histories agree; a failure is a design error, never a fault |
| Derivation step | An ordered post-load step, sanctioned by the GM, deriving a part's content from loaded sources |
| Trap | A place in a domain where a fault can bite, with its class; not a fault definition |
| Test selection | The spec's own pick of faults from the traps, for the build's tests and the proof in play; it binds no game |
| Third party | A business the customer depends on but does not own or operate, present only through its interface, out of the players' reach |
| Partner | A third party of a scenario, with its `partners.md` entry, its routes and its misbehaviour keys |
| Round trip | A purpose kind: a request sent to (or received from) a partner, its correlation key, the expected answer, a timeout, and the reactions the answer starts |
| Periodic report | A weekly, monthly or yearly purpose job whose past periods are planted by the load, with a daily feeder as its witness within the aging |
| Cold storage | A generic third party, S3-like, that receives heavy data and backups, keeps manifests and shows them on a read-only page |
| Vault | Cold storage holding the WAL archive and the nightly base backups |
| Standby | A `postgres` node in standby mode, a readable asynchronous replica |
| Option | An element a brick declares and a node chooses (`options: [monitoring]`), off unless chosen |
| `api` node | A node of the new `api` brick, serving endpoint files; in the players' scope it only answers |
| Data register | A scenario's record of processing, by department and activity, generated from the ground truth: the true register sealed in `gm/`, a handout on the bastion |
| Register fault | A fault planted in the data register handout only, resolved by *propose* |
| Fixture | A short test's minimal deployment: the nodes a check touches and those it cannot run without |
| Proof in play | The domain procedure's last step: a scenario running with the domain; for v0.5, the whole clinic deployed once |

## 5. Repository changes

```
bricks/
  postgres/             0.5.0: TLS and pgaudit always available, the standby
                        mode, WAL archiving and base backups, the `monitoring`
                        option, `no-access`, pgCluu beside pgBadger
  scheduler/            0.3.0: the HTTP driver, script jobs with HTTP
                        connections, the weighted `choice`, `no-access`
  api/                  0.1.0, new: FastAPI and uvicorn serving endpoint files
  bastion/              0.5.0: `partners.md` and `data-register.md`, optional
                        seed files on the page; the route to cold storage's page
  pgwatch/              0.1.0, new: pgwatch, its Prometheus sink (7.4)
  health-check/         0.1.0, new: `check_postgres`, the status page, the
                        customer's scripts (7.4)
  grafana/              0.3.0: a seeded pgwatch dashboard (7.4)
domains/vet-core/, vet-lab/, vet-scheduling/, vet-housing/, vet-machinery/,
  vet-portal/           new: the clinic's six domains (9)
domains/shop/           its classification rekeyed, its register fragment, its
                        one variant (8.6), its fragments in producers/producer/
purposes/<purpose-id>/  new: the clinic's purposes built in v0.5 (12.2)
faults/<fault-id>/      new: the test selection's ten (17.2); every fault applying
                        to a bumped brick lists its new version; one fault's
                        precondition widened (17.2)
scenarios/<clinic-id>/  new: the clinic scenario (17)
scenarios/*             the existing four re-pinned (17.5)
tools/                  `gmctl compose`, the loader's checks, the coherence
                        check (15)
tools/tests/fixtures/   the fixtures of the short tests (18)
.claude/skills/scenario-format/    templates and checks for section 6
.claude/skills/scenario-document/  third parties, composition, the data register
.claude/skills/game-master/        composition, the coherence check, third
                                   parties, the register in Setup step 2
.claude/skills/data-register/      new: the GM sub-skill generating a
                                   scenario's data register (13.3)
specs/formats.md        draft v28: the domain format, composition, the register
```

## 6. Format changes

The cross-version [formats.md](../../formats.md) states the rules for
every version. Its draft v28 states v0.5's domain format, the
composition of domains, the data register's files and the purpose
format's extensions in full; this section lists what v0.5 changes and
gives the shapes of the rest, normative until the `scenario-format`
skill's templates carry them. The skill, its templates and the loader
change together in the build, as in v0.4.

### 6.1 The domain format

As [formats.md](../../formats.md) "Domain" states it:

- **The folder** gains `data/register.yaml` (every domain), and
  optionally `data/<database>/` for a part with several databases,
  `data/derive.sql`, a `governance:` fragment with `docs/policy.md`,
  `producers/<node>/` (the fragments for each scheduler node the domain
  targets), `producers/api/<node>/` and `producers/partners/<partner>/`,
  `variants/<variant>.yaml` and `variants/<variant>/producers/`.
- **`domain.yaml`** gains `register`, and for a part `requires`,
  optionally `lands_with`, `databases` and
  `derive: {after: [...]}`.
- **Classification keys** drop the database (`<table>.<column>`); the
  scenario's copy adds it. The shop's file is rewritten mechanically.
- **The GM notes** gain "Core keys used" for a part, each producer's
  growth an hour, and the traps with their classes.
- **A domain is done** when it passes the checklist, which gains two
  items: every table belongs to one activity of the register fragment,
  and every `SECURITY DEFINER` function carries a fixed `search_path`.

### 6.2 Scenario (`scenario.yaml` and the folder)

- **`domains:`**, the domains a scenario is composed of, each with its
  `id`, its `at:` (a `node/database`, or a map for a part with several
  databases) and, beside the core, its `variant:`; `domain:
  <id>` stays the one-domain form. Checked as 8.5 says.
- **`composition.yaml`**, the composition record, and **`merge.yaml`**,
  the merge's resolutions, beside `scenario.yaml` (8.4, 8.5).
- **The data register**: `governance.register: player/data-register.md`,
  the handout, mapped to the bastion's optional seed file
  `data-register.md`; `gm/data-register.yaml`, the true register; both
  generated (13.3). Required of every scenario listing `domains:`.
- **`third_parties:`**, one entry per partner, and
  **`partners.md`**, the fifth optional starter-pack file, mapped to the
  bastion's optional seed file `partners.md` (10.2, 10.3):

  ```yaml
  third_parties:
    - id: northfield-lab
      name: Northfield Veterinary Laboratories   # its in-world name
      stands_for: a regional reference laboratory
      role: round-trip                           # inbound | outbound | round-trip
      nodes: [partners-api, partners-backend, partners-db]  # shared nodes; none for a party without a node
      hostname: northfield-lab                   # its alias on the partners' api node
      player_doc: player/partners.md#northfield-veterinary-laboratories
  ```

- **`options:`** on a `postgres` node, the options it chooses
  (`[monitoring]`), off unless listed (7.1).
- **`write_policy: no-access`** on a third party's nodes, now real (10.2).
- **A standby**: a `postgres` node with `standby_of: <node>`, cloned
  from its primary after the load (7.1, 11.1).
- The starter pack gains `partners.md` and `data-register.md`, each only
  when the scenario has it; the story names the centre, its partners by
  their in-world names, and the off-site room.

### 6.3 Answer key (`gm/answer-key.yaml`)

- **`register_diff:`** on a register fault instance: the entry, the
  field, the true value and the value handed out (`absent: true` for a
  register left out). Its resolution is *propose*.
- **A cascade's backlog**: for a round-trip fault, the requests the
  fault left stuck before the fix are listed as a consequence the GM may
  credit the players for cleaning up; not a fault, never counted toward
  the fault cap.
- **A third party's evidence**: a sealed check may read a partner's side
  as evidence (callbacks sent against callbacks received, a vault's
  manifests); it judges the customer's side only. No expected *fix*
  names a third-party node.
- A report-only fault on a component that is no layer of the players'
  (a ward display's firmware) states *report* as its resolution, judged
  at the final answer; the GM never clears it during play.

### 6.4 Fault definition (`fault.yaml`)

- A register fault is a `seed-file` change on the bastion
  (`seed_changes: data-register.md`), its fault id
  `governance-register-*`, in the `security` family; the
  `data-register` skill writes the changed handout.
- A fault may **require an option** (a lost `pg_monitor` grant on the
  `monitoring` role) or plant its absence (17.2, s10).
- A partner's misbehaviour (an outage, slow answers, a lost or
  duplicated callback) is a key switching that partner's state on the
  shared nodes, placed as a timeline change or as standing behaviour;
  its material comes with the fault.
- Every fault applying to a bumped brick adds the new version to its
  `applies_to`; `pg-abandoned-replication-slot` widens its precondition
  from "no standby in the topology" to "an orphan slot beside the
  standby's".

### 6.5 Brick definition (`brick.yaml`)

- **`options:`**, declared by the brick: each option's name, what it
  brings (secrets, roles created at initdb) and its documentation
  section. `postgres` declares one, `monitoring`.
- **`write_policies`** lists `no-access` on every brick that may serve a
  third party (`api`, `scheduler`, `postgres`); its entrypoint then
  creates no `player` account and no `sudo` wrappers.
- **The `api` brick's** seed files: its endpoint files (`routes/`, `db/`)
  as configs, and `api.yaml`, naming each endpoint's hostnames and the
  HTTP credentials it accepts, and the node's connections (6.8's shape),
  from which render derives its application roles' secrets and the
  credentials it mounts (7.2).
- **`seed.optional`** on `bastion` gains `partners.md` and
  `data-register.md`.

### 6.6 Purpose definition

As [formats.md](../../formats.md) "Purpose definition" states it: the
round-trip kind and its `round_trips:` block; the `api` and `partner`
parts; HTTP connections; endpoint material; periodic purposes with a
feeder and `material/history.sql`; `judged:` (`runs`, `triggers`,
`end-to-end`, `code`, `definition`); a purpose's own `classification:`;
the `ops` schema and `ops.runs` (12.1).

### 6.7 Versions and pins

Any change to a brick bumps it; a change confined to its tests bumps
nothing; a change made while a new version is unreleased folds into it;
a brick version is released when v0.5's release gate passes. Faults,
scenarios, purposes and domains never bump. v0.5's bumps:

| Brick | From | To | Why |
|---|---|---|---|
| `postgres` | 0.4.0 | **0.5.0** | TLS and pgaudit always available; the standby mode; WAL archiving and the base-backup job; the `monitoring` option; `no-access`; pgCluu; its documentation |
| `scheduler` | 0.2.0 | **0.3.0** | the HTTP driver; HTTP connections in script jobs; the weighted `choice`; `no-access` |
| `api` | — | **0.1.0** | new |
| `bastion` | 0.4.0 | **0.5.0** | `partners.md` and `data-register.md` on the page; the route to cold storage's read-only page |
| `pgwatch` | — | **0.1.0** | new (7.4) |
| `health-check` | — | **0.1.0** | new (7.4) |
| `grafana` | 0.2.0 | **0.3.0** | a seeded pgwatch dashboard over pgwatch's Prometheus metrics (7.4), as another seeded dashboard bumps the brick |

`prometheus`, `postgres-exporter` and `pgbouncer` bump only if the build
changes them (a documentation change included); none is planned:
Prometheus scrapes pgwatch from the scenario's seed file. Every
scenario with a `postgres` node pins 0.5.0, with a scheduler node 0.3.0,
with a bastion 0.5.0, with a `grafana` node 0.3.0 (17.5).

### 6.8 Shapes of the new fields

```yaml
# scenario.yaml, a node choosing an option, a standby, a third party's node
nodes:
  - name: lab
    brick: postgres@0.5.0
    options: [monitoring]
  - name: standby
    brick: postgres@0.5.0
    standby_of: records
  - name: partners-api
    brick: api@0.1.0
    write_policy: no-access

# a scheduler connection, the HTTP driver (schedule.yaml)
connections:
  lab-api:
    driver: http
    target: lab-api:8000
    credential: interfaces_lab_api   # a secret
    pool: 2                          # kept-alive connections

# an api node's api.yaml (the brick's seed file; a domain's fragment in producers/api/<node>/)
endpoints:                           # name -> routes/<name>.py and db/<name>.py
  orders:
    hosts: [lab-api]                 # its own name on a node in the players' scope;
                                     # on the partners' node a third party's hostname, or owners
    credentials: [interfaces_lab_api]   # optional: those it accepts; absent: public
connections:                         # optional: schedule.yaml's two drivers
  lab: {driver: sql/postgresql, target: lab:5432/lab, role: lab_api, pool: {size: 4}}

# a weighted choice, as a parameter generator
params:
  species: {choice: {dog: 45, cat: 25, horse: 15, cattle: 10, other: 5}}

# brick.yaml (postgres)
options:
  - name: monitoring
    brings:
      secrets: [monitoring_password]
      roles: [monitoring]            # created at initdb, member of pg_monitor
    docs: docs/gm.md#option-monitoring

# answer-key.yaml, a register fault instance
register_diff:
  - entry: core-owners
    field: shared_with
    true: [the portal, the back office, the messaging service, cold storage]
    handed_out: [the portal, the back office, the messaging service]
```

## 7. The bricks

### 7.1 `postgres` 0.5.0

Built on 0.4.0 (PostgreSQL 18 on Debian 13, s6, `pg_cron` and the cron
daemon, the GM check role). It adds:

- **TLS, always available, turned on by the seed.** The image carries
  what TLS needs; the seed's `postgresql.conf` sets `ssl = on` with the
  certificate and key, generated per game as secrets, and `pg_hba.conf`
  may use `hostssl` lines (the portal's API reaching `records`). Not an
  option: a scenario's seed turning it off, or a `host` line where the
  policy demands `hostssl`, is a fault.
- **pgaudit, always available, turned on by the seed.** The package is
  in the image; the seed preloads it (`shared_preload_libraries`) and
  sets its classes, so removing those settings can be a fault. Its log
  weighs on the disk budget, which the domains' GM notes count. Not an
  option.
- **The standby mode.** A node in standby mode is a readable,
  asynchronous replica of a primary named in the scenario (6.2): a
  physical replication slot named for the standby, a replication role
  whose password is a secret, `hot_standby` on and, for the reports
  reading there, `hot_standby_feedback` on. The standby is cloned from
  its primary with `pg_basebackup` after the data load and before the
  aging, by a `gmctl` setup step; it then streams. Every seed already
  carries the replication line in `pg_hba.conf`. The hand-over snapshot
  keeps working: its temporary slot is removed as today.
- **WAL archiving and the nightly base backup.** The seed sets
  `archive_mode = on`, an `archive_command` that posts each segment to
  the vault (cold storage's `wal` type) and fails honestly on a refusal,
  and `archive_timeout = 1h`, so a quiet night still ships. A cron-daemon
  job runs `pg_basebackup` each night in the low hours and posts it whole
  (type `basebackup`). Both are plain PostgreSQL tools; the brick ships
  the small posting command they call, on the same trust line as every
  seed script. The payload is discarded by the vault (10.4); nothing is
  restored in v0.5.
- **Options** (the options model, as the owner ruled it: "ok for now, if
  it needs upgrading we'll handle it then"):
  1. declared by the brick in `brick.yaml`'s `options:`; `postgres`
     offers one, `monitoring`, which brings the `monitoring_password`
     secret and the `monitoring` role (a member of `pg_monitor`) created
     at initdb;
  2. chosen per node with `options: [monitoring]`, off unless chosen;
     the role and its secret exist only when it is on;
  3. checked by `gmctl`: a monitoring node (the exporter, pgwatch, the
     health check) targeting a `postgres` node without the option is refused,
     unless a fault plants that gap (s10, 17.2);
  4. no software, so one image; image variants wait for the first option
     that brings software, after v0.5;
  5. one section per option in the brick's `docs/gm.md`; the player
     documentation and the starter pack mention the role only when the
     option is on.

  `pg_stat_statements`, file logging and pgBadger stay in every game,
  and pgCluu joins pgBadger (7.4); only the `monitoring` role became an
  option. Options are for
  `postgres` only.
- **`no-access`**, for the partners' shared database (10.2): no `player`
  account, no `sudo` wrappers, its `pg_hba.conf` admitting only the
  partners' own roles on their database (10.2).
- **Several databases created by the loader** for a part with several
  databases, each with `CONNECT` revoked from `PUBLIC` (6.1).
- **`pgcrypto`** is PostgreSQL's contrib, already in the image's
  packages; the portal's schema creates it in its own database. Not an
  option.

The brick's `docs/gm.md` gains the standby mode, archiving and base
backups, TLS, pgaudit and the option's section; its footprint is
re-measured on short runs (the aging's figures wait for the major test).
Plain partitioned tables serve the machinery's readings; no TimescaleDB.

### 7.2 `scheduler` 0.3.0 and `api` 0.1.0: the HTTP driver and the API brick

v0.4's scheduler has one driver, `sql/postgresql`; no repository entry
passes one call's result to the next, and transformer scripts are jobs
only, PostgreSQL only. No API brick exists. The clinic receives and
sends over APIs (external labs, other centres, the portal, machines), so
v0.5 adds an `api` brick and an HTTP driver in the scheduler, the
"APIs" promised among the scheduler's other targets. Message queues wait
until a flow needs one.

#### The `api` brick

- **What it is**: FastAPI on uvicorn, Python as the GM's other code. The
  GM drops endpoint files into a folder and the brick serves them; the
  image is generic, holding no scenario content.
- **It only answers.** An `api` node in the players' scope never acts
  on its own and has no timer: producers and consumers on scheduler
  nodes call it whenever appropriate.
- **The exception, a third party out of the players' scope.** The
  partners' stubs share one `api` node, each partner under its own
  hostname through network aliases, so players still see distinct
  partners, with one shared scheduler back end and one small database.
  A partner's side initiates (the external lab calls the clinic back
  with results), but always from the back end's hidden schedule: its
  stream ticks the partner's route, whose endpoint reads, calls and
  writes. Every event stays scheduled and reproducible, and a partner's
  misbehaviour (an outage, a lost, duplicated, late or out-of-order
  callback) is a stream key the timeline switches. Out of reach means no
  `player` account, no route on the bastion, no place in the starter
  pack: the `no-access` write policy made real, creating neither the
  account nor its `sudo` wrappers.
- **What the players reach.** They read every endpoint file. Where the
  scenario makes the node fixable, they edit its **database side only**:
  the queries, how the transactional work is organised, session-level
  database settings. They never change an endpoint itself, its route or
  its request and response contract. Endpoints connect with application
  roles, never superusers; a change takes effect through a reload
  wrapper, as on a scheduler node.
- **Layout.** Each endpoint is two files of the same name:
  `routes/<name>.py` (the route, its request and response models, calls
  into its database module; protected) and `db/<name>.py` (its SQL, its
  transactions, its session settings, the functions the route calls). A
  domain's and a purpose's material use this layout. Inside the brick,
  write policy is per directory, so `db/` is the one
  writable path, and a route importing only from `db/` keeps the
  contract out of the players' reach.
- **Endpoint conventions** allow `SECURITY DEFINER` functions on the
  `db/` side for pre-login calls and a transaction-local setting per
  request (`portal.owner_id`, for row-level security), which
  `portal-api` uses; nothing more is asked of the brick.
- **The `db/` side is covered by the brick's own build checks**; no
  fault of the test selection sits on it.
- **Footprint**, starting figures to be measured in short runs: 0.1 CPU
  and 96M; 128M for the partners' node serving nine hostnames.
- **Its nodes in the clinic**: `clinic-api` (the core's lookup API and
  the exchange endpoints), `lab-api` (the lab's order API, its released
  results feed, the external lab's answers), `portal-api`, and the
  partners' node.

#### The scheduler's HTTP driver

- **The driver's least**: a connection `driver: http`, `target:
  <node>:<port>`, the caller's credential a secret; one request per call
  (a method, a path, a JSON body from the parameters or a builder); its
  status and latency recorded as a statement's, in the log and the
  counters; a non-2xx answer or a timeout an error; `pool` meaning
  kept-alive connections. The clinic's profiles need nothing more.
- **Streams** may hold an HTTP connection: `pms`'s desk consent stream to
  `portal-api`, the partners' back end ticking their routes.
- **Script jobs with an HTTP connection.** Nearly every flow around the
  lab reads a database, calls an API with what it read and writes the
  answer back (orders posted and the accession written back, results
  delivered, send-outs, the identity job, cold storage's shipping). A
  script job's `connections:` may name an HTTP connection: the script
  gets a small client (`get`, `post`) beside its psycopg connections,
  each call's status and latency logged as a call's. On the customer's
  side such flows run every minute at most, as middleware polling its
  outbox does. Rejected: a sequence passing one step's rows to the next
  (a new repository form, less readable), and an `api` node doing the
  work while answering a tick, which only a third party may do.
- **A weighted `choice`**, in the same bump: `{choice: {dog: 45, cat:
  25, horse: 15, ...}}`, beside the uniform list form. The `int`-and-
  `CASE` trick recurs about a dozen times in the core's and the lab's
  profiles (species mixes, outcomes, a sample's condition, the urgent
  shares), the condition set for adding it.

#### Gates and versions

FastAPI and uvicorn are new dependencies: **a dependency check by
security-advisor gates the build**, a gate of the build plan. A
transformer script may import only the standard library, psycopg 3 and
PyYAML; anything more is an image change with its own dependency check.

Versions, under "Versions and pins" (any brick change bumps; new bricks
start at 0.1.0):

- **`scheduler` 0.3.0.** 0.2.0 was released with v0.4. The HTTP driver,
  the scripts' HTTP client, the weighted `choice` and `no-access` made
  real are one bump. Every fault applying to the scheduler adds 0.3.0 to
  its `applies_to` before it hosts on it.
- **`api` 0.1.0**, a new brick; every change before its release folds
  into 0.1.0.

### 7.3 `bastion` 0.5.0

- **Two more optional seed files**, `partners.md` and
  `data-register.md`, beside v0.4's `data-policy.md`: each copied into
  `/home/player` and shown on the starter-pack page only when the
  scenario has it, "Partners" and then "Data register" placed after the
  data policy.
- **The route to cold storage**: the web front proxies the players to
  cold storage's read-only page and read endpoint (`GET /`,
  `GET /manifests`) under its partner hostname, never to its upload
  endpoint and never to another partner. It is the one stated exception
  to a third party's absence from the bastion's routes, as a provider's
  console the customer logs into. In the owner's words: "yes the bastion
  must be able to route the player to this coldstorage. keep it simple
  for now."
- Nothing else changes: the page, the tools password and the web front
  in every game are v0.4's.

### 7.4 The monitoring breadth

The owner kept pgwatch and pgCluu in v0.5, with Nagios-style health
tools, as "monitoring tooling that are required in such complex
settings", and the clinic's own IT runs hand-made scripts beside them.
Three pieces, each reading what `postgres` already provides
(`pg_stat_statements`, the file logs) through the `monitoring` role
(`pg_monitor`), and nothing more of the brick:

- **`pgwatch` 0.1.0, a new brick, the node `pgwatch`**: pgwatch, one
  collector for every instance in the players' scope (`records`, the
  standby, `lab`, `machines`; never the partners' database), its
  sources a file the scenario seeds, no configuration database, its own
  web interface off. It connects as `monitoring`, so every node it
  targets chooses the option (7.1's check). Its metric set is one that
  needs no helper function, so nothing is created in the customer's
  databases and `pg_monitor` suffices. It keeps no store: its
  Prometheus sink serves the metrics on its endpoint, v0.2's Prometheus
  scrapes it beside the exporters (its seed file's targets), and
  Grafana shows them in a seeded pgwatch dashboard (`grafana` 0.3.0).
  The version is pgwatch's latest release at the build (6.1.0 at the
  dependency check of 2026-11-04), a checksum-pinned release download
  as v0.2's Prometheus and `postgres_exporter` are, once the dependency
  check has cleared it (21). Starting footprint 0.1 CPU and 96M, no
  volume; on armenelos, beside Prometheus.
- **pgCluu, in `postgres` 0.5.0**, from the same package source as
  pgBadger and a report tool beside it: run on demand by the players on
  the node, its collector sampling for the window they choose, its
  report written to their home and read as pgBadger's are (`scp`,
  `sftp`). No daemon, no node, no footprint beyond the image.
- **`health-check` 0.1.0, a new brick, the node `health`**, standing for
  the clinic's Nagios-style health tooling. Its crontab runs
  `check_postgres` (Debian's package) every five minutes as
  `monitoring` against each instance in scope: connections, backends,
  locks, wraparound, the last autovacuum and analyze, database sizes,
  the standby's replay delay (the exact set the build's, within
  `pg_monitor`). Each run rewrites a status page, every check's OK,
  WARNING or CRITICAL line with its time, which the node serves as a
  web interface, routed by the bastion's `web_routes` as `health`. The
  same crontab holds the customer's hand-made scripts, on the same trust
  line as every seed script: a disk alarm on the database sizes against
  the IT's threshold, and a nightly "is the backup there" asking cold
  storage's `GET /manifests` for last night's `basebackup` (10.4); their
  results land on the same page. Starting footprint 0.1 CPU and 64M, no
  volume; on the VPS, off site as the standby is, which keeps
  armenelos' CPU for the parts.
- **No fault of the test selection** needs any of them (s10 uses v0.2's
  exporter). The health node's checks and scripts and pgwatch's sources
  are fault surface a later game's GM may pick; v0.5 builds none there.
- **If CPU is short**, the first trim of 14: one collector only, the
  exporters, which s10 needs, with pgwatch left out; the owner's call
  when it comes.

### 7.5 The other bricks

`prometheus`, `postgres-exporter` and `pgbouncer` are unchanged, unless
the build changes their documentation, which bumps them; `grafana`
0.3.0 gains the pgwatch dashboard only. A pooler in front of `records` stays the scenario's choice. The
`monitoring` option's check (7.1) is `gmctl`'s, not the exporter's.
Every new `api`, scheduler, `pgwatch` and `health` node takes the
node-health script as every node does, the GM listing its services.

## 8. Domains: defining and composing them

### 8.1 The procedure

A domain answers four questions about one kind of business: what it
holds, how its data arrives, what the data is for, and how sensitive it
is. Anything about the machines it runs on, how they are wired, or what
goes wrong belongs elsewhere: topology and IT maturity are the
scenario's or a topology fragment's; bricks and options the catalogue's;
faults the catalogue's or a scenario's (a domain lists its **traps**,
never fault definitions); the story the scenario's (a domain may carry a
default company, which a scenario may rename). The procedure, approved
by the owner, takes a domain from a brief to a built and proven folder:

| # | Step | Output | The owner |
|---|---|---|---|
| 1 | Brief | the owner's description of the business | writes it |
| 2 | Business sketch | actors, activities, the variant's scale and tags, cadences, regulations, the questions left open | answers the questions |
| 3 | Split (composites only) | a core and its parts | confirms the split |
| 4 | Data model | entities, keys, states, roles and grants, within "schemas simple, tables small" | checks plausibility, optional |
| 5 | Classification and governance | every column classed; the business's own rules | confirms the rules are realistic |
| 6 | Producer profiles | traffic shapes and rates, fixed-time operations, input types; cadences real time cannot age flagged | only for a flagged cadence |
| 7 | Purposes | which existing purposes fit; new ones drafted | chooses the purposes |
| 8 | Traps | where faults can bite, each with its class | none: a scenario's faults are the GM's to select at deploy, with whoever sets up the game |
| 9 | Draft document | `specs/versions/<version>/<domain>-domain.md` | approves it, with the version's master spec |
| 10 | Build | `domains/<id>/`, verified by the checklist | none: a build-plan chunk |
| 11 | Proof in play | a smoke run with the domain's data, producers and purposes running | none, unless the run shows a design gap |

A domain is **done** when its draft is approved and its folder passes
the checklist ([formats.md](../../formats.md) "A domain is done"); it is
**proven** once a scenario has run with it. In v0.5 step 10's
verification is short tests, and step 11 is the whole clinic deployed
once (18). A domain fed by an external dataset changes steps 4 and 10;
none is planned. The procedure becomes a skill once it has served two or
three domains; not in v0.5.

Effort, the one data point being the shop (about 1 100 lines, a day's
spec session and one build chunk): a domain designed from a brief costs
the owner one or two sessions, the spec about twice the shop's, the
build one chunk per domain of the shop's size and half of one for a
smaller part. The clinic alone is several shops' worth of work, which is
why v0.5 is the clinic only.

### 8.2 Composite domains

The clinic is one business made of parts close to domains of their own.
A **core** holds the keys every part shares (for the clinic: owners,
animals, sites, staff, and the requests and stays the parts answer); a
**part** names its core and never another part, one level only. Flows
between parts are purposes, never dependencies between parts. A part
refers to the core's keys by id, without foreign keys, as separate
systems do: the same schema then runs in the core's database or an
instance of its own, integrity becomes an invariant and an orphan a
fault vector. Keys are deterministic: the core's load generates them in
documented ranges and functions, and a part's load computes the core
keys it uses from them, never reading the core. A part's tables and
roles carry its prefix (`lab_`, `sched_`, `housing_`, `mach_`,
`portal_`). A part is taken only with its core; the core may be taken
alone. A site is a core entity; for the clinic each centre keeps its
own record, a scenario deploys one, and the other sites are rows naming
third parties.

### 8.3 Scale, variants and tags

"Size" became **scale**, on three axes: population, history, throughput.
In the owner's words: "size isnt sufficient to describe whatever it
is." One domain covers several setups as **variants**, short manifests
of parts, scale, purposes and tags from a fixed vocabulary (maturity
`homebrewed`, `managed`, `industrial`; reach `local`, `regional`,
`national`, `global`; traits `regulated`, `multi-site`, `24/7`,
`seasonal`). Large setups show through structure, not volume: "it isn't
because we work at world scale that we need to spawn hundreds of nodes
in our topology, it's more a question of robustness and tool used". A
part writes its own axes in a manifest of its core variant's name. v0.5
builds one variant per domain: the shop's present setup, and the
clinic's `regional-franchise`, a large regional veterinary hospital
(`managed`, `regional`, `regulated`, `24/7`). Where the variants'
material is built is the domain-format chunk, with the other format
changes.

### 8.4 Producer profiles and the merge

A domain's **producer profile** is how its data arrives: the repository
fragments (`queries.yaml`, `builders/`), the schedule fragment
(`schedule.yaml`: connections, streams, shapes) and the fixed-time
operations (`jobs.yaml`), under its `producers/<node>/`, one folder per
scheduler node it targets. The GM copies them
into a scheduler node's seed files at design time, adapting them; the
scenario folder stays self-sufficient.

**The merge: `gmctl compose`.** v0.4 merged fragments by hand, and
PyYAML keeps the last of two equal keys without a word (two fragments'
connection `app` give one); the scheduler refuses only two streams with
one key. `gmctl compose`, a design-time script built with the format
changes, writes ordinary files into the scenario folder:

- **Layers**, lowest first: the domain's default profile, the variant's
  profile (overrides in `variants/<name>/producers/`, holding only what
  they change), the scenario. A higher layer wins silently; the merge
  report records every override. Identical entries merge silently.
- **A real conflict between two profiles** (two parts on one node) stops
  the merge, naming both sides; the GM writes the resolution into the
  scenario's `merge.yaml`, so the merge is reproducible.
- **Prefixes**: a part prefixes its query keys, connections and shapes
  (`lab.batch.upload`, connection `lab`, shape `lab-runs`), as its roles
  and tables; so does a partner (`practices.`, `xlab.`). What still
  conflicts is what a node genuinely shares: its pool, its intensity.
- **Provenance**: every output entry carries a comment naming its source
  (`# from vet-lab@regional-franchise`). **The loader refuses duplicate
  keys** in the merge's inputs.

A library resolved at render, or a layer the scheduler reads, was
rejected: either undoes the self-sufficient folder and, domains never
bumping, would let a catalogue change alter released scenarios.

**Readable profiles.** `schedule.yaml` stays root-only on the node and
out of the snapshot, but a domain's fragment is readable in the
repository, as a scenario's own schedule already is. Accepted on the
trust line: the repository is a textbook, and a profile shows only base
traffic the players could infer from the logs. The rule: **a fragment
never carries a timeline, an intensity or a planted fault**; a partner's
misbehaviour comes with its fault's material.

**Rates at intensity 1.0.** The intensity is one per node and absolute,
never rescaled to the playground. A domain's rates are its variant's
`throughput` at intensity 1.0, before the shape; the scenario sets each
node's intensity at design time; a part needing another throughput goes
on its own node or has its rates adapted at copy. The GM notes state the
daily volume the rates give against the history's (the shop's live 30 000
orders a day against a history of 20 000, explained as the busy season):
an unexplained gap reads as a fault. A fault on a rare flow (a few
notifiable diseases a month, one exchange a day) is planted only with a
story raising the rate from T0 for the whole game, in the scenario's
profile layer, never a timeline change after the hand-over.

**Values from SQL and builders.** The generators stay `int`, `decimal`,
`choice`, `sequence` and `now`, plus a weighted `choice`. Other values
come from SQL (an `int` and a `CASE`; `INSERT ... SELECT` for work on the
database's state, such as an instrument run over pending samples) or
from domain builders in `producers/<node>/builders/`, for values with structure
(identifiers with check digits, readings drifting around a baseline).
Builders get the intensity, options and seeded `rng` and cannot read.

**A producer node per application** of the business, as a real clinic
has: it keeps the node count to the applications and puts every
cross-instance flow in a purpose's transformer job; the GM notes say
which application each fragment belongs to. The clinic's: `pms`, the
practice software, carrying the core's fragments and `vet-scheduling`'s
(connection `sched`), `vet-housing`'s screens (`housing`) and
`vet-portal`'s desk consent (an HTTP stream to `portal-api`); `lis`, the
lab's information system and analysers' middleware; `ward`, the housing
displays' ward service holding a pool (four for the board reads, about
64 a minute, two for the carers' actions: a hundred direct displays
would all carry one `application_name`; the faulty one is found by the
ward service's redundant query, whose parameters name the box, and the
box → stay → animal relation the placements and stays hold); `equipment`,
the machines'. `vet-core` is the system of record for owners and
animals, reached through `clinic-api`'s lookup or a synced table;
natural identifiers (microchip, UELN, ear tag) carry identity across
systems and are fault vectors.

**Every site in the customer's zone**: one fixed offset, a job's
`timezone:` still the wrong-time-zone fault's marker; the other centres
are third parties whose stubs keep that zone.

**API and partner material**: `producers/api/<node>/`, its `api.yaml`
fragment, `routes/` and `db/`, for an `api` node the domain owns
(`clinic-api`, `lab-api`);
`producers/partners/<partner>/` for its partners' fragments and endpoint
files, merged by `gmctl compose` onto the back end all partners share.

#### Periodic reports

Weekly, monthly and yearly duties (the medicines registers' extracts,
the statements, the antimicrobial-use report) **are part of the game**:
heavy crunching on a node kept weak, and an investigation. Real time
cannot age a month, so:

- **Past periods are planted** by the load before T0, inputs and
  outputs, unseen: no statement logging, `pg_stat_statements` and
  pgaudit off for its sessions, nothing in the logs or pgwatch.
- **Faults there are the GM's choice**; if any is planted, at least one
  shows a witness within the aging (a daily feeder carrying it forward,
  a check, or a scheduled run); the others may rest on planted data. One
  periodic run in the aging is the GM's option; none is expected during
  the session.
- **No run on demand in v0.5**: nobody triggers the load, the scheduler
  has no "run now"; "run March's report now", on an instance spawned for
  it, comes later (v0.6 at the earliest, probably v1.0 or after).
- **A fix checked without one**: to the inputs or the feeder, on the
  feeder's next run, which the players may move to verify it; to the
  report's own code, by the sealed check reading the code and, if the GM
  placed a periodic run, against its output. The planted past outputs
  stay wrong; the players recommend the rerun in their report.
- **Heavy, never killed**: calibrated per node so a normal run never
  runs out of memory on a shared host or a laptop; one that does is a
  planted fault. Tested short: T0 just before the feeder, or the feeder
  moved.

For domains this replaces v0.4's rule (no weekly or monthly purpose, no
evidence on past records alone); v0.4's purposes keep it.

**Heavy continuous data** keeps a day on site and ships the rest to
**cold storage**, a generic third party that keeps a manifest (data
type, rows, dates) and discards the payload. The GM decides per type,
use first, volume second (about 50 000 rows a day at intensity 1.0 only
marks a candidate). The housing displays log action events only, about
520 a day, kept all game; the machines read every ten seconds while
running, about 68 500 rows a day, `vitals` and `machine-readings`
shipped nightly, the last full day kept in daily partitions. **Every
domain's GM notes state each producer's growth an hour at intensity
1.0**, rows and megabytes, and for each shipped type its retention on
site and the consumers it waits for, so the disk is sized for the
window plus the aging's slack, never the whole game.

### 8.5 Composing domains and the initial load

The owner ruled that the deterministic keys stay the default and that
"initial load is a major step and will need to be adjudicated by the gm
for coherence across the system"; the mechanism was then confirmed as
written ("ok agreed"). [formats.md](../../formats.md) "Composing
domains" states it in full. In short:

- **The format fixes** the rules of 8.2, the placement constraints a
  domain may declare, the composition record's fields and the loader's
  checks. **The domain declares** the core keys it relies on ("Core
  keys used" in its notes, by the names the core gives its ranges and
  functions), its placement constraints (`lands_with`), its databases,
  its fragments and their nodes, its scale per variant, its purposes,
  and a derivation step when it needs one. **The GM adjudicates** and
  records: placement within the constraints; key feeding when a part
  sits apart from its core; colliding profiles (`merge.yaml`); which
  cross-part purposes run (only those whose domains are all composed);
  the initial load's coherence; capacity, by `gmctl fit`.
- **The initial load**, checked and recorded at composition: the ranges
  and functions each part relies on against the core's notes; the
  combined scale (a part sized for 40 current stays on a core holding 60
  is incoherent); the load order (a part needs only its core's schema in
  the same database; a derivation step runs after the loads it reads);
  then **the post-load coherence check**, once, on the loaded system,
  before any fault is planted: every part's references resolve in its
  core, and the histories agree (placements on real stays and every
  current stay placed, monitoring sessions on stays, published
  documents matching signed consultations, released results and ended
  stays). A failure is a design error the GM fixes and reloads, never a
  fault handed over; faults against the same relations are planted
  after the check, from the answer key.
- **The derivation step**, `data/derive.sql`, only where formulas would
  be unreasonably costly and only when the composition record
  sanctions it: run as `postgres` after every load it reads, through a
  temporary foreign server it drops, its sessions unseen; content only,
  never keys. The clinic's one case is the portal, whose documents copy
  the record field by field (9.7).
- **The composition record**, `composition.yaml`, beside `merge.yaml`,
  so the composition is reproducible and the scenario folder stays
  self-sufficient.

The clinic's composition: `vet-core`, `vet-scheduling` and `vet-housing`
in `records/clinic` (housing `lands_with: vet-core`); `vet-portal` in
`records/portal`; `vet-lab` in `lab/lab`, an instance of its own, its
core keys computed at load and fed in play by purposes; `vet-machinery`
in `machines/pacs`, `machines/vitals` and `machines/biomed`; the order
core, lab, scheduling, housing, machinery, portal, the portal's
derivation after the core and the lab.

### 8.6 The shop against the new format

v0.4's shop fits as built for its layout, its keys, its design-time copy
and its notes. The domain-format chunk rewrites its classification keys
without the database (mechanically), writes its register fragment and
its one variant (its present setup as a manifest). v0.4's scenario keeps
its own copies and its `domain: shop` line.

## 9. The clinic's domains

### 9.1 One centre, a core and five parts

The business is **Aldermoor Veterinary Hospitals**, a franchise of large
veterinary hospitals in an unnamed EU member state: three national
centres and several abroad, each draining animals from its whole
region. **A scenario deploys one centre** (the owner: "the scenario
should be centered only on one such center (not all 3, nor those
beyond)"). Each national centre is independent, with its own record and
its own laboratory, which the region's other clinics pay to use. The
other national centres, the centres abroad and the franchise's central
systems are third parties, present only as stub interfaces ("We don't
need the full setup started for other clinic and franchise, just third
party api nodes"). Exchanges between centres are **privileged flows**:
trusted flows inside the franchise, carrying more of the record than an
outside partner gets (an animal's history, its owner's contact) under
the franchise's agreement, the data policy stating what may go.

The clinic is **the core and five parts**, all the centre's own:

| Domain | What it holds | Lands in |
|---|---|---|
| `vet-core` | the medical record: owners and keepers, animals and herds, sites and sections (horse, farm, domestic), staff, consultations, treatments and prescriptions, medicines, hospital stays, referrals, lab and imaging requests, alerts, exchanges with the other centres | `records/clinic` |
| `vet-lab` | samples, orders, analysers' batches, results per analyte, validation and release, the external lab's send-outs, the outside customers and their billing | `lab/lab`, a node of its own |
| `vet-scheduling` | rooms, machines, staff, bookings and allocations, the rota and working time, the training centre | `records/clinic` |
| `vet-housing` | 64 boxes, stalls and kennels, placements on the core's stays, plans, the care log, the displays' board | `records/clinic`, `lands_with: vet-core` |
| `vet-machinery` | 28 machines, the imaging archive, the monitors' readings, the biomedical register, in three databases | `machines/pacs`, `machines/vitals`, `machines/biomed` |
| `vet-portal` | owners' accounts, consents, the documents released to them behind row-level security, notices and vaccination reminders | `records/portal` |

Not domains: **regulatory reporting** (the medicines registers, the
antimicrobial-use report, notifiable diseases) is purposes fitting the
core and the lab; **inter-centre exchange** is round trips with third
parties; **messaging** is the franchise's, a third party the centre's
outbox traces (its governance on the centre's side is what goes out);
the **back-office database** `office` is topology, the target of the
reports' purposes (11.3). No billing or pharmacy part: the lab bills its
outside customers only.

The core is the **system of record** for owners and animals, reached by
the parts through a lookup API or their own synced copies; natural
identifiers (microchip, UELN and passport, ear tag) carry identity
across systems and are fault vectors; there is no central id provider.
The history shows the clinic's **growth**, its daily volumes ramping up
over the year to today's live rates, not a busy season. Every site is
in the customer's zone.

Each domain below states its essentials; its domain document holds the
column-level detail and its traps. Purpose numbers refer to 12.2.

### 9.2 `vet-core`, the medical record

`vet-core` is the core of the veterinary clinic: a composite domain with no
`requires`, its parts `vet-lab`, `vet-scheduling`, `vet-housing`,
`vet-machinery` and `vet-portal`. It holds the keys every part shares (sites,
sections, staff, owners, animals) and the medical record, and is the **system
of record for owners and animals**: a part reaches them through the core's
lookup API or a reference table the core syncs to it, never a central identity
service. Its database `clinic` holds `vet-core` only; each part lands where the
scenario's `domains:` `at:` places it. Column-level detail is in
`specs/versions/v0.5/vet-core-domain.md`, the build input for
`domains/vet-core/`.

#### The business and its variant

"Aldermoor Veterinary Hospitals", a fictional franchise in an unnamed EU member
state (a scenario may rename it): three large hospitals in the country and
several abroad, each drawing animals from its region. Each centre has three
clinical sections (horse, farm, domestic), a biology lab, and a training centre
that trains people with the clinic's own teaching animals. The farm section
treats cattle, sheep and goats, each ear-tagged and in a herd (a holding with
its keeper); no pigs or poultry. **Each centre is independent, with its own
record and its own lab, and a scenario deploys one centre**: the other two
national centres, the centres abroad and the franchise's central systems (head
office, messaging service) are third parties, listed in `sites` so transfers
name them; exchanges with them are round trips over their stubs. Billing is out
of v0.5 but for the lab's outside customers; so is pharmacy stock.

v0.5 builds one variant, `regional-franchise`: maturity `managed` (an IT team
running its own scripts beside the tools), reach `regional`, traits
`regulated`, `multi-site` (the franchise reached through its partners) and
`24/7`; not `seasonal`. Its scale is one centre's, a third of the figures first
sized for three, every ratio kept:

| Axis | `regional-franchise` |
|---|---|
| Population at load | 6 sites, 3 sections, 85 staff (30 vets and specialists), 10 000 owners (200 holdings, 700 horse owners or stables), 400 referring practices with two vets each, 17 000 animals (14 600 domestic, 1 400 horses, 1 000 farm animals in 200 herds), about 40 in hospital |
| History | one year: about 25 000 consultations, 15 000 prescriptions (37 000 lines), 70 000 administrations, 17 000 requests, 2 500 stays, 700 exchanges; about 0.28 million rows |
| Throughput | about 85 consultations a day (60 scheduled, 12 in hospital, 10 emergencies, 3 herd visits on average), 13 new owners and 20 new animals, 240 administrations, 50 prescriptions, 55 requests; about 760 new rows and 450 updates a day |

**The growth curve.** Every daily volume of the history ramps linearly from
about 60 % of today's live rate a year ago to today's, the weekday and hour
shapes on top; reference tables and staff do not grow. The history ends at
intensity 1.0's rates, so the curve runs on into the aging; another intensity
shows a step at T0 the story must explain. One intensity for the clinic's nodes
(`pms`, the lab's `lis`, the partners' back end), or the lab's share drifts.

#### What the core holds

| Group | Tables, and what they settle |
|---|---|
| Places and people | `business_settings` (the customer's zone and offset, retention 5 years); `sites` (`kind` `own`, `centre`, `abroad`); `sections`; `staff` (`kind` `vet`, `nurse`, `technician`, `lab`, `carer`, `reception`, `instructor`); `owners` (`kind` `person`, `stable`, `holding`, `clinic`); `herds`; `animals` (species, `food_chain` `food-producing`, `excluded` or `not-applicable`, an exclusion dated and signed, one-way; the natural identifiers); `ownerships` (dated, `role` `owner` or `keeper`, one current owner per animal by a partial unique index); `referring_practices`, `referring_vets` |
| The record | `referrals`; `consultations` (an animal or a herd, `kind` `scheduled`, `emergency`, `herd-visit`, `in-hospital`, `booking_id` unique when present); `diagnosis_codes` (`notifiable` `none`, `A`, `other`), `diagnoses`, `procedures`; `requests` (`kind` `analysis` or `imaging`, test or study code, `priority` `routine` or `urgent`; in house or out is the lab's routing); `stays`; `alerts` (`allergy`, `dangerous`, `infectious`, `other`); `exchanges` (`direction` `out`/`in`, `kind` `transfer`/`examination`, partner site, the animal or an inbound `partner_patient` summary, `exchange_key` a UUID, answer, report) |
| Medicines | `medicines` (ATCvet, authorisation number, `antimicrobial`, `controlled`, meat and milk withdrawal days, allowed for a food-chain horse); `medicine_batches` (at load only); `prescriptions`; `prescription_lines` (`cascade`, withdrawal end); `administrations`; `dispensings` |
| Lifecycles | consultation `open` → `closed` → `signed` within a day; request `requested` → `sent` → `resulted`, or `cancelled` (by the vet while `requested`; once `sent` by the lab only, or the imaging team for imaging, copied back); stay `admitted` → `discharged`, `transferred` or `died`; exchange `requested` (out) or `received` (in) → `accepted`/`declined` → `reported`; prescription `issued` → `dispensed`, `expired` or `cancelled`; administration `scheduled` → `given`, `missed` or `cancelled`. `resulted` is the lab's fact copied back by a purpose: two places for one fact, a deliberate fault vector |

#### Key ranges and the functions the parts rely on

The load writes explicit ids and sets each sequence after its range, so an id
created in play never meets a part's load. **A part's load computes the core's
keys from these ranges and functions and never reads `clinic`.** The core's
`docs/gm.md` documents each function under the name the parts' "Core keys used"
cite; the GM checks the composed load's coherence.

| Key | Range and layout |
|---|---|
| `sites.id` | 1–6: 1 the centre (`own`), 2–3 the other national centres, 4–6 abroad |
| `sections.id` | 1–3: 1 horse, 2 farm, 3 domestic |
| `staff.id` | 1–85, the layout below |
| `owners.id` | 1–10 000: 1 the clinic; 2–201 holdings; 202–901 horse owners and stables; 902–10 000 pet owners |
| `herds.id` | 1–200: herd `h` kept by owner `h + 1` |
| `animals.id` | 1–17 000: 1–14 600 domestic, 14 601–16 000 horses, 16 001–17 000 farm animals in herd `1 + (id − 16 001) mod 200`; teaching animals 1–12 (dogs) and 14 601–14 608 (horses), owned by owner 1 from before the history, never patients |
| `referring_practices.id`, `referring_vets.id` | 1–400; 1–800, two per practice |
| `medicines.id` | 1–400 |
| History | `consultations` 1–25 000, `prescriptions` 1–15 000, `administrations` 1–70 000, `exchanges` 1–700, `stays` 1–2 500, `requests` 1–17 000, in time order; the others as loaded |

| Function of the id | Computes | Relied on by |
|---|---|---|
| staff layout | each staff id's kind, section and specialty | every part |
| species | each animal's species within its range | housing, machinery, lab |
| natural identifiers | microchip, UELN, passport number, ear tag | lab, machinery, portal |
| deaths | which history animals died, and when | scheduling |
| consultations | each history consultation's kind, section, vet and start; a scheduled one's `booking_id` its own id, its vet one the rota's pattern puts on shift | scheduling, portal |
| stays | each stay's animal, section, admission, end and outcome; the `infectious` alert current on it (from, until) | housing, machinery, portal |
| requests | each request's kind (about one in five imaging), test or study code, priority, consultation, animal and time | lab (analysis, a consultation's grouped into one order), machinery and scheduling (imaging) |

The functions must give about 40 stays current at T0 (14 horses, 6 farm
animals, 20 domestic), never more current stays in a section than housing's
units in service (21 horse, 10 farm, 31 domestic, species fitting); an imaging
request's study code one of `vet-machinery`'s 30 codes valid for the animal's
group (1–12 domestic, 13–27 horses and farm, 28–30 any) at that part's
modality shares. Their formulas are written into the GM notes at the build.

#### The staff layout

85 staff, all the centre's, 30 of them vets (1–28, 79–80):

| Ids | Who | `kind` |
|---|---|---|
| 1–25 | the sections' vets: 1–10 horse, 11–17 farm, 18–25 domestic; specialties by id | `vet` |
| 26–28 | vets, specialty diagnostic imaging (`vet-machinery`'s reporters) | `vet` |
| 29–51 | the sections' nurses and technicians, kind and section by id | `nurse`, `technician` |
| 52–55, 56 | radiographers; the biomedical engineer | `technician` |
| 57–66 | carers and grooms | `carer` |
| 67–70 | receptionists | `reception` |
| 71–78 | the lab's technicians | `lab` |
| 79–80 | the lab's clinical pathologists | `vet`, specialty clinical pathology |
| 81–85 | the training centre's instructors | `instructor` |

#### Natural identifiers

Columns of `animals`, unique when present, each a function of the animal's id
so a part's load writes the same value without reading the core (a live
animal's from the same functions of its new id): a **microchip** of 15 digits
(ISO 11784/11785, the country or maker's 3 then 12) on every dog, cat and horse
and some other pets, missing on about 2 % of domestic animals; a **UELN** (15
characters) and a **passport number** on every horse; an **ear tag** (country
code and 12 digits) on every farm animal; a **holding number** on every herd.
**A dozen mistyped chips** are planted at load, two digits swapped against the
value the parts' loads hold, so a lab result or a portal record matches no
animal: a trap by design.

#### Application roles and classification

| Role | May (login roles get their passwords from `load-data`'s secrets) |
|---|---|
| `vet` | own everything; no login |
| `vet_app` | the practice software: read every table; write the record and the people (owners, ownerships, animals, herds, referrals, consultations, diagnoses, procedures, requests, stays, alerts, exchanges, prescriptions and lines, administrations, dispensings); never the reference tables |
| `vet_lookup` | the lookup API: read `animals` without the death columns, `ownerships`, `owners`' id, kind and name (no address, no phone), `stays`' id, animal, section, admitted and discharged at; write nothing |
| `vet_display` | read the view `animal_board` (identity, current stay, alerts, the day's administrations) and, where `vet-housing` lands in `clinic`, its `housing_unit_board`, granted by that part's schema |
| `vet_reports` | read every table, contacts included, and the tables of parts landing in `clinic`, granted by their schemas; write nothing |

The purposes add `vet_interfaces` (request states, exchanges' sent columns,
`INSERT` on `consultations`' open columns for the check-in, `SELECT` on
`animals`' id, species, status, died at), `vet_exchange` and `vet_portal_sync`.
**`CONNECT` on `clinic` and on `office` is granted by name** and revoked from
`PUBLIC`, so the portal's role on the same instance cannot open the record.

Classification (v0.4's three classes): the customer is the owner, so an
animal's or herd's id alone is `customer-linked`; a natural identifier leads to
the owner through national registries, so it is `personal`, and the id beside
it too. **Personal**: `owners`' identity and contacts; `staff` and
`referring_vets` id, name, e-mail; `animals`' id and identifiers; `herds`' id
and holding number; `exchanges.partner_patient`. **Customer-linked**: every
other `animal_id` and `herd_id`, `ownerships`' keys, `dispensings.owner_id`,
`herds.keeper_owner_id`. The rest is `internal`, medical content included
(animal health is no special category). Free text may name the owner.

#### The default policy: eleven rules

Built as `docs/policy.md` and a `governance:` fragment the GM copies. EU law as
written, a national figure one member state's, a *game value* a choice.

1. **Prescriptions** carry Regulation (EU) 2019/6 Art 105(5)'s contents; an
   antimicrobial one is valid five days; under the cascade the minimum
   withdrawal is the product's longest × 1.5, or 28 days meat and 7 milk.
2. **Medicines register**: every supply with its batch, kept five years (France
   keeps ten).
3. **Controlled-drugs register**: every movement, a monthly signed balance, a
   yearly inventory, kept ten years (*game value*, France's; Germany three).
4. **Antimicrobial use** recorded for every species; the yearly report covers
   the species due: cattle now, sheep, goats, horses from mid-2027, dogs and
   cats from mid-2030.
5. **Horses**: in the food chain unless excluded, irreversibly; an essential
   substance imposes six months' withdrawal.
6. **Food-producing animals**: every treatment records its withdrawal end.
7. **Notifiable diseases**: by the vet who records the diagnosis, category A
   within the hour, other listed diseases within the day (*game values*).
8. **Records signed within a day** of closing: the clinic's own rule.
9. **Retention**: clinical records five years from the last entry, medicines
   five, controlled drugs ten (*game values*); then erased or anonymised.
10. **Owners' data** is personal, an animal's record its owner's personal data,
    no special category; least data per reader, none in the logs, erasure
    bounded by the legal retention.
11. **The portal**: an owner sees their current animals and their own
    ownership's records, results once validated, consultations once signed,
    never a former owner's identity.

#### The producer profiles

| Node | Kind | Connection, role | What |
|---|---|---|---|
| `pms` | scheduler | `records:5432/clinic` (or the pooler), `vet_app` | the practice software; it also carries `vet-scheduling`'s and `vet-housing`'s fragments and the portal's desk fragment |
| `clinic-api` | `api`, players' scope, only answers | `vet_lookup`; `vet_exchange` | `GET /animals/{id}`, `GET /animals?microchip=` (or `ueln`, `ear_tag`), `GET /animals/{id}/owner` (id, kind, name), `GET /stays?current=true` (the census); `POST /exchanges`, `POST /exchanges/{key}/answer`, `/report` |

| Streams, jobs at 1.0 | What (a day, the week's average) |
|---|---|
| Volume streams | `owners.register` 1.6/h (13; 86 % domestic, 8 % horses, 6 % farm), `animals.register` 0.86/h (7), `referrals.receive` 1.82/h (13), `consultations.emergency` 0.42/h (10, a third at night), `consultations.herd-visit` 2.1/h Tuesday and Thursday mornings (3), `consultations.ward` 3/h (12), `stays.admit` 0.34/h (8), `stays.discharge` 2.67/h late mornings (8: 90 % discharged, 4 % transferred with an outbound exchange, 6 % died), `alerts.record` 0.6/h, `ownerships.transfer` 0.37/h, `requests.cancel` 0.12/h (`requested` only), `exchanges.request` 0.1/h; scheduled consultations have no stream, the bookings purpose's check-in opening them (about 60) |
| Work streams (capacities) | `consultations.close` 40/h (1.2 diagnoses, a procedure in three in ten, 0.65 requests, a prescription in six in ten), `consultations.sign` 20/h, `referrals.accept` 6/h, `referrals.close` 4/h, `exchanges.decide` 2/h, `exchanges.report` 2/h |
| Jobs | `administrations.round` `0 2,6,10,14,18,22 * * *` (about 40 doses, one in a hundred missed by a hash of its id); `prescriptions.expire` `15 0 * * *` (the GM may move it to `pg_cron`) |
| Shapes | `clinic-day` (weekdays 08:00–20:00, peak late afternoon; Saturday mornings), `office`, `herd-days`, `ward-rounds`, `around-the-clock`, `discharges`, `signing`, `flat`; variation by a hash of the row's id, never `random()` |

**In flight at T0**: about 40 current stays, their next round planned; the
evening's emergencies unsigned; a few exchanges either way, the partners'
database planted from the same functions; every request `resulted` or
`cancelled` but the last day's, `sent`. Nothing ships to cold storage; the
instance ships its WAL (`archive_timeout` an hour) and a nightly base backup.

#### Purposes, loading, and what the build verifies

Purposes that fit: 1 `vet-lab-centre-orders`, 4 `vet-centre-exchanges`, 5
`vet-notifiable-diseases`, 7 `vet-medicines-registers`, 8
`vet-antimicrobial-use`, 9 `vet-head-office-figures`, 11 `vet-bookings-sync`,
12 `vet-working-time`, 13 `vet-imaging-orders`, 15 `vet-portal-release`; the
referral's electronic report is named for later. Periodic ones read the standby
and write `office`, never `clinic`.

`gmctl load-data` runs `schema.sql` then `load.sql` into `clinic` as
`postgres`, unseen (no statement logging, `pg_stat_statements` and pgaudit
off). The parts' loads and the partners' database compute the core's keys by
its functions; only `vet-portal`'s copied content comes from a derivation step
the GM sanctions after this load; the purposes then plant `office`'s past
periods. The build verifies: load time and size (about 0.28 million rows, a few
seconds by the shop's measure); every function a part cites documented in the
GM notes; the post-load coherence check on the composed clinic (no part's
`animal_id`, `stay_id`, `request_id` or staff id beyond the core's, every
current stay placed, published documents matching signed consultations and
ended stays), a failure being a design error the GM fixes, never a fault.

### 9.3 `vet-lab`, the centre's laboratory

`vet-lab` is the deployed centre's clinical pathology lab and the clinic's
first **part**: `requires: [vet-core]`, tables and roles prefixed `lab_`, every
core key a plain integer with no foreign key. **It runs on a separate
`postgres` node, `lab`**, database `lab` (`at: lab/lab`), never a database on
the core's instance, the owner asking for "a separate node for the lab (not
just a separate database)": the lab's own information system, its keys coming
from the core through the lookup API, so orphans and mistyped chips are real.
The node has no standby; its WAL and a nightly base backup go to the vault as
the core's do, so a lab left out of the archive is a fault, not the design.
Column-level detail is in `specs/versions/v0.5/vet-lab-domain.md`.

#### The business and its scale

Analysers (haematology, biochemistry, blood gas and electrolytes,
coagulation), urinalysis, microscopy and cytology, microbiology (cultures,
sensitivities), serology and rapid tests, and a milk residue screening. Two
kinds of customer: **the centre**, its vets ordering in consultations and stays
around the clock, and **the region's practices**, the core's referring
practices by id, sending samples by the lab's courier and paying per test. What
it cannot run (histopathology, most PCR, endocrinology, toxicology: a fifth of
the catalogue, 8 % of the tests ordered) goes to **one external reference
lab**, a third party, the answer reported as the lab's own naming the lab that
performed it. The other national centres order nothing: each has its own lab.

The lab takes `regional-franchise` and adds no tag. **A part writes its own
axes in a manifest of the core variant's name**, here
`vet-lab/variants/regional-franchise.yaml` (`vet-lab@regional-franchise`); the
loader checks that the core's variant names the part.

| Axis | `regional-franchise` |
|---|---|
| Population | 6 analysers (`vet-machinery`'s machines 1–6), about 150 tests and 30 panels over 70 analytes, about 400 reference intervals in force (dog, cat, horse, cattle, sheep, goat; adults), 10 lab staff, 120 customer accounts, one price list revised each 1 January |
| History | one year on the core's growth curve: 14 000 orders (7 700 the centre's, 6 300 the practices'), 18 000 samples, 24 000 tests, 192 000 results (one per analyte, a thousand amendments), 22 000 batches, 7 000 QC runs, 2 000 send-outs, 10 000 callbacks, 17 000 charge rows; about 0.36 million rows |
| Throughput | about 85 tests a day (45 the centre's, around the clock; 25 practice orders a working day at 1.6 tests), 700 results, 75 batch uploads, 20 QC runs, 7 send-outs (Monday to Friday), two or three critical calls; about 1 300 rows and 400 updates a day |

The lab outweighs the core, the results more than half of it; nothing ships to
cold storage. The bench works 07:00–21:00 Monday to Saturday, an on-call
technician running the centre's urgent haematology, biochemistry and blood
gases otherwise; the courier returns at about 10:45 and 16:45; the
pathologist's rounds are at 11:00, 14:00 and 18:00 (11:00 on Sundays).

#### What the lab holds

| Group | Tables, and what they settle |
|---|---|
| Reference | `lab_settings` (zone and offset, its own copy; handling fee, urgent surcharge 50 %, critical call limit 60 minutes); `lab_analytes`; `lab_tests` (discipline, sample type, turnaround, `performed` `in-house` or `sent-out`, `external_code`, `diagnosis_code` the core's when the test detects a listed disease); `lab_test_analytes`; `lab_reference_intervals` and `lab_prices`, dated; `lab_accounts` (`internal` or `practice`, callback URL) |
| Orders and samples | `lab_orders` (the accession; `client_ref` unique per account, the idempotency key; `priority`; the centre's `animal_id`, consultation, requesting staff, or a practice's `patient_ref` and `client_surname`; species, sex, age, identifiers as given; `withdrawal_ends_on`); `lab_samples` (barcode label, condition at receipt, custody flag, keep until); `lab_order_tests` (`request_id` for the centre's, routing, `add_on`, both validations by and at); `lab_sample_events` |
| Work | `lab_qc_runs` (machine, level, outcome, control rule broken, action); `lab_batches` (machine, the QC run in force); `lab_results` (value, flag against the interval in force, `supersedes_id`: an amendment is a new row); `lab_critical_calls`; `lab_notifications` |
| Round trips, billing | `lab_send_outs` (`send_key`, due by); `lab_callbacks` (`delivery_key`, attempt, HTTP status); `lab_charges` (`test`, `handling`, `urgent`; billable on, voided at) |
| Lifecycles | order `ordered` → `received` → `completed` or `cancelled`, its report interim until every test is final; order test `ordered` → `in-progress` (or `sent-out`) → `technical` → `released`, or `not-performed`, `cancelled`; result current → superseded, both kept; send-out `packed` → `sent` → `accepted` → `resulted`; callback `pending` → `acknowledged`; charge pending → billable → `void` |

#### Key ranges and the core keys it uses

| Key | Range and layout |
|---|---|
| `lab_analytes.id`, `lab_tests.id` | 1–70; 1–180: 1–150 tests, 151–180 panels, about 36 sent out |
| `lab_reference_intervals.id` | 1–460: 1–60 replaced by the January review, 61–460 in force |
| `lab_prices.id` | 1–360: test `t`'s price `t` until 1 January, `180 + t` from it |
| `lab_accounts.id` | 1–121: 1 the centre (`internal`); account `a` (2–121) is referring practice `3 × (a − 1)` (3, 6, … 360) |
| History | `lab_orders` 1–14 000, `lab_samples` 1–18 000, `lab_order_tests` 1–24 000, `lab_results` 1–192 000, in time order |
| Machines | `machine_id` 1–6: 1–2 haematology, 3–4 biochemistry, 5 blood gas and electrolytes, 6 coagulation; 1, 3 and 5 on call at night |
| Core keys used | analysis `request_id`s among 1–17 000 by the core's requests function, a consultation's grouped into one order (1.8 tests); `animal_id` 1–17 000 and its identifiers by the core's functions; lab staff 71–80 |

The history holds each animal's correct chip; the core's dozen mistyped ones
reach the lab's live orders through the identity job. The analysers' readings
and run logs are `vet-machinery`'s, with no row-level match to `lab_batches`.

#### Application roles and classification

| Role | May |
|---|---|
| `lab` | own everything; no login |
| `lab_app` | the information system: read every table; write orders, samples, order tests, sample events, results (bench, amendments), critical calls, notifications, QC runs, charges; never the reference tables |
| `lab_api` | the order API: read the catalogue, accounts, orders, tests, results; write orders, samples and order tests at intake, send-outs' answers and their results |
| `lab_instruments` | the analysers' middleware: read samples, tests, analytes, intervals, QC runs; write batches and results |
| `lab_dispatch` | the dispatch jobs: read orders, tests, results, accounts, samples; write callbacks, send-outs, `sent-out` events, notifications' sent columns |
| `lab_reports` | the reports and statements: read every table, write nothing |

The purposes add `lab_watch` (the critical calls' `pg_cron` job) and
`lab_release` (account 1's released results for the portal, no identifiers or
notes). **Personal**: `lab_orders`' `animal_id`, `microchip`, `ueln`, `ear_tag`,
`patient_ref` (the practice's key to its client), `client_surname`;
`lab_sample_events.other_party`; `lab_critical_calls.called_person`. No column
is customer-linked; practices, accounts, staff ids, `request_id` and child rows
are `internal`. Free text (notes, comments, cytology) may name a person.

#### The order API and the results feed

`lab-api`, an `api` node in the players' scope that only answers, as
`lab_api`; players edit its `db/` side only.

| Endpoint | What |
|---|---|
| `POST /orders` | any account's order, the centre's included; idempotent on the account and its `client_ref`: the same accession answered twice |
| `GET /orders/{accession}` | an order's state, interim or final |
| `GET /orders?account=<id>&released_since=<time>` | **the results feed**: one account's tests released, not performed or cancelled since a time |
| `POST /send-outs/{send_key}/result` | the external lab's answer |

**The centre's orders** (purpose 1, `vet-lab-centre-orders`, on `interfaces` as
`vet_interfaces`, with account 1's credential): every minute `post-lab-orders`
posts a closed consultation's analysis requests as one order per consultation
and priority, `client_ref` `C-<consultation id>-<priority>`, with request ids,
test codes, priority, animal, consultation, vet and, for a residue screening,
the withdrawal end; no name, contact or identifier leaves the core. On the
accession the requests become `sent`, in one `clinic` transaction after the
call returns; no answer in ten seconds is retried with the same `client_ref`.
Every five minutes `fetch-lab-results` reads the feed from a watermark: a
released test's request becomes `resulted`, a not-performed or cancelled one
`cancelled` with its reason. **The lab never writes `clinic`.** A sent request
is cancelled by the lab only: the vet phones, `lab.orders.cancel` cancels it,
the feed carries it back; no endpoint is added. End to end, every order gets
each test released or not performed within its turnaround plus the next round.

**Identity from the core.** `lab.identity`, a job on `lis` every minute with a
`lab` connection and an HTTP one to `clinic-api`, reads each new centre order's
animal (`GET /animals/{id}`, `/owner`) and writes species, sex, birth date,
identifiers, food-chain status and the owner's surname on the order: the
lookup API's first traffic, a producer's job, not a purpose.

#### The outside customers and billing

The region's practices are one stub on the partners' shared back end, for
accounts 2–121. Its stream `practices.order` (2.9/h, `practice-hours`: 28 a
weekday, 12 on Saturday) builds an order (patient reference, client surname,
70 % dogs and cats, 15 % horses, 15 % farm animals, one in twenty urgent, a
fresh `client_ref`), posts it to `POST /orders` and keeps the accession; the
sample comes by the story's courier. An outside patient is never a core animal,
never matched to one even on a shared chip. Results go back through purpose 2,
`vet-lab-practice-results`: the dispatch posts each interim, final or amended
delivery to the practice's `POST /results` under a `delivery_key`, an
acknowledgement due within 30 seconds, retried 5 minutes after the last
attempt, at most six attempts; the stub
acknowledges a repeat without a second record. The half that can go wrong is
the centre's.

**Billing**, the lab's alone (no owner billed, no payments): one price list
revised each 1 January; a handling fee per order; an urgent surcharge of half
the price; each outside test charged at accession at the price of its order's
day, billable on release, voided on a cancellation or an unfit sample; a
send-out re-billed at the lab's price; an add-on billed to whoever paid for the
first report; the centre's account never charged. Purpose 10,
`vet-lab-statements`, gathers each practice's month into `office` on the 1st at
04:00 (feeder 02:30; every full month of the year planted), reading the lab's
node at night since it has no standby, writing as `office_jobs`.

#### The external lab round trip

Purpose 3, `vet-lab-send-outs`: at 16:00 Monday to Friday the day's send-out
tests are posted to the external lab's stub `POST /orders` with the accession,
label, species, sex and age, never an owner, client or identifier, under a
`send_key` UUID kept on every retry. The stub answers `accepted` with its
accession (the same `send_key`, the same accession) and a due time of one to
five days; its stream `xlab.answer` (6/h, Monday to Saturday 08:00–20:00) posts
each result when due to `lab-api`'s `POST /send-outs/{send_key}/result`. Past
`due_by` by a working day, a send-out is chased every 15 minutes through
`POST /orders/{send_key}/resend` (the stub posts its answer again), then becomes
an incident. The test is validated and released as the lab's own. The partners'
database is planted from the lab's functions, so the stub knows every send-out
the history left open (about twenty).

#### The default policy: thirteen rules

1. **Release** by a clinical pathologist only; inside the centre an urgent,
   technically validated result is shown marked unvalidated.
2. **Traceability**: every result names its batch or bench, the QC run in
   force, the technician and the vet, with times (ISO/IEC 17025 7.5.1).
3. **Amendments** are new rows superseding the first, never updates.
4. **Quality control** on every analyser daily and before a night run; a failed
   run holds the analyser's results since its last good run.
5. **Unfit samples** recorded at receipt, the test not performed, the customer
   told why.
6. **Critical values** phoned within 60 minutes, read back, recorded (*game
   value*).
7. **Notifiable diseases**: the lab notifies the authority itself, as national
   law requires of labs, for every customer, within an hour of technical
   validation for category A and a day for the others (*game values*);
   category A samples forwarded to an official lab under custody.
8. **Chain of custody** for samples with legal weight: both parties, time,
   condition, seal number.
9. **Residue screening** is an own check for the keeper, never official, never
   reported.
10. **The practices' clients**: the lab a processor (GDPR Art 28), each
    practice seeing only its own orders.
11. **Least data**: send-outs without owner, client or identifier; pgaudit on
    `lab` logging `write, ddl, role`, `log_parameter` off.
12. **Retention** (*game values*): lab records five years, samples a week
    (whole blood, urine) or two (serum), custody samples 60 days at most,
    charges ten years.
13. **Billing** as above, the centre never charged.

#### The producer profiles

| Node | Kind | Connections | What |
|---|---|---|---|
| `lis` | scheduler | `lab:5432/lab` as `lab_app`; `lab-instruments`, the same target, as `lab_instruments`; HTTP to `clinic-api` | the information system and, on the same node, the analysers' middleware |
| `lab-api` | `api` | `lab_api` | the order API above |

The lab's volume arrives from outside its node, so its streams are nearly all
work streams, their rates capacities:

| Streams, jobs at 1.0 | What |
|---|---|
| Work streams | `lab.samples.receive` 15/h (about 97 % fit by a hash of the sample's id), `lab.courier.receive` 40/h in `courier-waves`, `lab.analyser.run` 5.7/h as `lab_instruments` (nothing while the analyser's last QC failed), `lab.bench.result` 8/h, `lab.validate.technical` 30/h, `lab.release.urgent` 10/h, `lab.critical.call` 6/h, `lab.notify` 2/h, `lab.qc.rerun` 4/h |
| Volume streams | `lab.amend` 0.25/h, `lab.orders.cancel` 0.08/h, `lab.add-on` 0.1/h |
| Jobs | `lab.qc.morning` `45 6 * * *` (one in fifty fails), `lab.qc.night` `15 21 * * *` (machines 1, 3, 5), `lab.release.round` `0 11,14,18 * * 1-6` and `0 11 * * 0`, `lab.samples.dispose` `0 6 * * *` (may go to `pg_cron`), `lab.identity` every minute |
| Shapes | `bench` (Monday–Saturday 07:00–21:00 at 1.0, 0.1 otherwise), `courier-waves` (11:00–12:00, 17:00–18:00), `flat`; the stubs' `practice-hours` and `xlab-hours` |

**In flight at T0**: the night's urgent orders, the practices' late orders not
yet received, about fifteen cultures, 600 stored samples, twenty open
send-outs, outside tests not yet released with their charges pending.

#### Purposes, loading, and what the build verifies

Purposes that fit: 1 `vet-lab-centre-orders`, 2 `vet-lab-practice-results`, 3
`vet-lab-send-outs`, 5 `vet-notifiable-diseases`, 6 `vet-lab-critical-calls`
(on the lab's `pg_cron`), 9 `vet-head-office-figures`, 10 `vet-lab-statements`,
and 15 `vet-portal-release` with the portal. `gmctl load-data` runs the lab's
`schema.sql` and `load.sql` into `lab` on its node as `postgres`, the core's
ids computed without reading `clinic`, so the two loads are independent; the
partners' database is planted from the same functions. The build verifies: load
time and size within the brick's reservation (0.5 CPU, 512M, 2.25G of disk);
the loader's check that the core's variant names the part; the post-load
coherence check (every `request_id`, `animal_id` and staff id within the
core's, the stubs' open send-outs and orders matching the lab's).

### 9.4 `vet-scheduling`, bookings, rota and the training centre

`vet-scheduling` is the centre's agenda: the slots of its rooms and
machines, the bookings that take staff, rooms and machines, the staff
rota with its clocked hours, and the training centre. It is a part:
`requires: [vet-core]`, tables and roles prefixed `sched_`, the core's
keys and `vet-machinery`'s machines held by id with no foreign key. It
lands in the core's database, `records/clinic`, as the practice
software's scheduling module: no node of its own, riding the core's
standby and archive; its schema also runs in a database of its own,
every flow with the core being a purpose. `vet-scheduling-domain.md`
holds the column-level detail.

#### What it holds

- **Reference**: `sched_settings` (the customer's zone, a 42-day
  horizon, the 30-minute no-show delay, the teaching animals' limits,
  80 % attendance for a certificate, 11 hours' minimum rest); 16 rooms;
  `sched_hours` (local opening times per room and machine); about 45
  appointment types; 16 courses; `sched_machines`, the ten bookable
  machines keyed by `vet-machinery`'s ids 7–16: 7 CT small animal, 8 CT
  large bore, 9 MRI 1.5 T, 10 standing MRI, 11 and 12 the domestic and
  horse radiography rooms, 13 portable radiography, 14 domestic
  ultrasound, 15 portable ultrasound, 16 gamma camera. The analysers
  (1–6) and monitors (17–28) are never booked.
- **Booked**: consultations, imaging studies (one per core imaging
  request), theatre plans (the plan only; the procedure stays the
  core's record, unlinked, which the GM notes say so that a plan with
  no procedure is never read as a fault), maintenance blocks, session
  days. Not booked: emergencies, herd visits, ward rounds, housing's
  units. No appointment reminders in v0.5: the owner ruled that the
  portal reminds owners of vaccinations only (`sched_upcoming` unbuilt).

#### Bookings, allocations and the slot function

`sched_bookings` (the core's `animal_id`, `request_id` or
`exchange_id` by id, times, state, source, free `notes`, a cancel
reason `owner`, `clinic`, `deceased` or `moved`) and
`sched_allocations`, one row per resource taken (exactly one of
`staff_id`, `room_id`, `machine_id` or a teaching animal's `animal_id`;
`during tstzrange(starts_at, ends_at, '[)')`; `released_at`): about two
per booking, four for a theatre plan. Four exclusion constraints refuse
a double booking (`btree_gist`, created by `schema.sql` as `postgres`):

```sql
EXCLUDE USING gist (staff_id WITH =, during WITH &&)
  WHERE (staff_id IS NOT NULL AND released_at IS NULL)  -- likewise room, machine, animal
```

Slots are computed, never stored. `sched_free_slots(type_id, after,
how_many)`, a `STABLE` SQL function, security invoker, returns the next
free slots within the horizon with the staff, room and machine each
would take: the resource's hours in the customer's zone, a staff member
of the type's section on a covering shift and no absence, no live
allocation overlapping, the teaching animals within their limits.
Reception's search, the booking stream and the purposes all call it.
The trigger `sched_release` (after `UPDATE OF state`, `WHEN (NEW.state
= 'cancelled')`) releases the allocations, so the slot frees at once. A
booking goes `booked` → `arrived`, `no-show` (30 minutes past its start)
or `cancelled`; a block or session day → `held`. The consultation's
close is the core's fact, not a booking state. Game values: 10 %
cancelled ahead, 5 % of the rest not attended.

#### The rota and the training centre

`sched_shifts` (kind `day`, `late`, `night`, `on-call`; planned and
clocked times; unique on staff and start) and `sched_absences` (kind
`leave`, `training`, `absent`; a `note` never holding a reason). The
rota is a pattern of the staff id and the week, the same in the load,
the weekly job and the core's history (one vet a night by rotation over
the 25 section vets, 1–25, the imaging vets 26–28 keeping their own
on-call among the three; a surgeon and an anaesthetist on call, nurses and carers in
three shifts around the clock), leaving 11 hours' rest everywhere,
published each Friday at 12:00 for the week after next. On call means
at home, counted only for the time clocked on a call-out (game value).

The training centre trains people, never staff: courses for vets,
nurses, students, owners and handlers, one to three days, 8 to 14 seats,
a waiting list, a certificate for 80 % attendance, no fees; sessions
(`open` eight weeks ahead), trainees, enrolments. The teaching animals
are core animals 1–12 (dogs) and 14 601–14 608 (horses), owned by the
clinic, never patients: handling and examination only, nothing above a
needle's insertion, at most two sessions and four hours a day, a rest
day after two (game values).

#### Keys

| Key | Range, layout |
|---|---|
| `sched_rooms.id` | 1–16: 1–7 domestic, 8–11 horse (10 the arena), 12–13 farm, 14–16 training |
| `sched_bookings.id` | 1–25 000 an attended history consultation booking, taking its core consultation's id (about 17 600, gaps elsewhere); 25 001–28 000 cancelled and no-show ones; 30 001–47 000 imaging, `30 000 + request id`; 47 001–48 300 theatre plans; 48 301–48 700 blocks; 48 701–49 000 session days; 49 001–50 000 the agenda ahead at T0 |
| others | types 1–45, courses 1–16, allocations 1–60 000, shifts 1–21 000, sessions 1–125 (101–125 planned), trainees 1–750, enrolments 1–1 250 |

Of the core it computes, never reads: the staff layout within the 85;
each history consultation's kind, section, vet and start as functions
of its id, a scheduled one's `booking_id` its own id, its vet on shift
by the rota's pattern; the teaching animals; the history's deaths by
animal id; the imaging requests' study code and priority by request
id. The core gains a partial unique index on `consultations.booking_id`
and loses its `consultations.open` stream: scheduled consultations open
from bookings checked in.

#### Scale, roles, classification, rules

One variant, `regional-franchise`, no tag added. A year growing from
about 60 % of today's rate: 20 600 consultation bookings (17 600
attended, 2 100 cancelled, 900 no-shows), 3 400 imaging, 1 250 theatre
plans, 360 blocks, 100 sessions, 1 000 enrolments, 20 600 shifts, 600
absences; about 0.11 million rows and 30 MB, 330 new rows and 200
updates a day.

| Role | May |
|---|---|
| `sched` | own everything; no login |
| `sched_app` | the module on `pms`: read all, execute the slot function, write bookings, allocations, shifts, absences, sessions, trainees, enrolments; never the reference tables |
| `sched_reports` | purpose 12, on the standby: read every `sched_` table |
| `sched_interfaces` | purpose 11: read bookings, allocations, types, machines, hours, shifts, absences, settings; execute the slot function; write bookings and allocations |

`customer-linked`: a booking's `animal_id`, an enrolment's
`trainee_id`. `personal`: an absence's `note` (it may reveal health,
special-category data), a trainee's id, name, contacts and referring
vet, a certificate number. A teaching animal's id and staff ids are
`internal`; a booking's notes are `internal` and may name the owner (a
trap). The rules, beside those above: working time per Directive
2003/88/EC (11 hours' rest, 24 weekly, 48 a week averaged over four
months, nights 8 on average, a night shift 12 at most, every shift
clocked); absences without a reason; no owner's name or contact in a
booking; trainees' contacts kept three years, records five; bookings
five years, working time two (game values).

#### The producer, on `pms`

No new node: `pms` gains a connection `sched` (`records:5432/clinic`,
`sched_app`) and the part's fragments, merged by `gmctl compose` under
`sched.`, at the core's one intensity. At 1.0: `sched.bookings.make`
8.4/h on `reception` (weekdays 08:00–19:00, Saturday to 12:00): 92 a
weekday, 34 on Saturday, 75 % domestic, 18 % horse, 7 % farm, lead
times 30 % within two days, 50 % within two weeks, 20 % to six weeks,
one statement calling the slot function; cancellations 0.85/h, theatre
plans 0.6/h, enrolments 0.38/h. Work streams check arrivals in (about
75 a day, one in twenty left a no-show by a hash), mark no-shows, move
bookings under a new absence, clock shifts (about 110 clockings a day),
and run sessions. `sched.rota.publish` at `0 12 * * 5` writes the week
after next's shifts and the machines' weekly blocks, idempotent on
staff and start (movable to `pg_cron`). Variation is by a hash of the
row's id. Arrivals lag bookings by ten days, so another intensity shows
in arrivals only over two weeks, which the story says.

#### Purposes 11 and 12

**11, `vet-bookings-sync`**, transformed in place, the clinic's first:
every minute on `interfaces`, holding `clinic` as `vet_interfaces` and
`sched_interfaces`. `check-in` opens a core consultation (`scheduled`,
the allocated vet, started at the arrival, `booking_id`) for each
arrived booking, once, its ledger row (`ops.booking_consultations`) in
the same transaction; `book-requests` books each new imaging request on
its study's machine (an urgent one today, a routine one within three
working days) and each accepted inbound examination on its date, or the
next free slot with an incident; `cancel-deceased` cancels a dead
animal's future bookings. `vet_interfaces` gains `INSERT` on
`consultations`' open columns and `SELECT` on `animals`' `id`, `status`,
`died_at`. Invariants within 2 minutes: every arrived booking has its
consultation (BS1), never two (BS2); every imaging request one live
booking, urgent ones today (BS3); no dead animal's booking left (BS4);
every accepted examination booked or an incident (BS5).

**12, `vet-working-time`**, pulled, periodic: on `backoffice`, the
standby's `clinic` as `sched_reports` and `vet_reports` → `office` as
`office_jobs`. The feeder at `30 9 * * *` (after every night shift ends)
takes yesterday's started shifts: planned and worked hours, nights,
call-outs, rests, a breach under 11 hours; the monthly job sums the
month and the four-month average. About 21 000 rows planted. Invariants:
worked hours equal clocked ones (WT1), every short rest a breach (WT2),
a month the sum of its days (WT3).

#### Traps, tests, loading

Traps T100–T128 (none in the test selection) include staff
double-booked (the constraint re-addable only once overlaps are moved),
urgent imaging booked routine, and a health reason in absences. The `bookings`
fixture (`records`, `pms`, `interfaces`, bastion; T0 a weekday 09:50)
proves in under 30 minutes that the loads agree, an overlap is refused
(`23P01`), BS1–BS4 hold, a cancellation releases, and the rota
publication reruns without a duplicate; purpose 12 runs on the reports
fixture's nodes. `load-data` runs `schema.sql` then `load.sql` into
`clinic` after the core's, the core's ids computed, each sequence set
after its range, the load unseen. Capacity: no node; `pms` 64M → 96M.

### 9.5 `vet-housing`, the wards and their displays

`vet-housing` holds the centre's 64 units, which of the core's hospital
stays is placed in which, each stay's feeding plans and care log, and
the display on each unit with the ward service behind it. It is a part:
`requires: [vet-core]`, prefix `housing_`, the core's keys by id with
no foreign key. The stay (admission, discharge, outcome) stays the
core's; housing refers to it by id. `vet-housing-domain.md` holds the
column-level detail.

#### Units, placements, plans, care log

Units 1–22 the horse barn (1–2 isolation, 3–4 intensive care, 5–22
boxes), 23–32 the farm barn (23 isolation pen, 24–28 stalls, 29–32
pens), 33–64 the domestic wards (33 isolation kennel, 34 isolation
cage, 35–40 intensive-care cages, 41–54 kennels, 55–64 cages); 15 and
50 out of service. One animal per unit, fitting its species (a box a
horse, a stall cattle, a pen sheep or goats, a kennel a dog, a cage a
cat or small animal). About 40 in hospital at any time (14 horses, 6
farm, 20 domestic; the core documents its stays never to exceed a
section's units in service), so about 62 % occupancy.

- **`housing_units`**: section, code (`H-01`), kind, `isolation`,
  `intensive`, `state` `clean` → `to-clean` at release → `clean` after
  disinfection, or `out-of-service`. Occupancy is no state: the
  placements say who is there.
- **`housing_displays`**: display `u` on unit `u`; 65 and 66 replaced
  units 7's and 41's mid-year, so unit → display goes through the table.
- **`housing_placements`**: unit, the core's `stay_id`, from, until
  (open while placed), reason, placed by; partial unique indexes on
  `unit_id` and on `stay_id` where open: one animal per unit, one unit
  per stay. A move ends one and opens the next at one instant, in one
  transaction; one stay in five moves once. About 3 000 a year.
- **`housing_feeding_plans`**: a diet per species list or a
  `nil-by-mouth` order overriding it, from, until. About 2 900.
- **`housing_care_events`**: unit, the occupant's `stay_id` (none for
  an emptied unit), kind (`feeding` with `eaten` all, part or none,
  `water`, `mucking-out`, `bedding`, `walk`, `grooming`, `check`,
  `disinfection`), at, by; written once. Never a dose: medicines are the
  core's `administrations`. About 150 000 a year, 520 a day.

**`housing_unit_board`**, a view owned by `housing`, one row per unit,
is what a display shows: the unit, its open placement, the stay and its
animal, from the core's `animal_board` the animal's name, species, sex,
age, alerts, the stay's reason and the day's doses, the plan in force,
the day's feedings and last check ("today" from `business_settings`).
Its join, unit → open placement → stay → animal, is the relation the
faulty display's diagnosis needs.

#### Landing, and a load on computed keys

Housing lands in `clinic`, never in an instance of its own: each board
read is one statement joining its units to the core's board.
`domain.yaml` declares `lands_with: vet-core`, and the loader refuses an
`at:` elsewhere. While running, housing's roles read the core's columns
in place by column grants its own schema gives; nothing is copied, no
purpose moves them. Its load never reads them: the owner ruled that a
part's load computes the core's keys from its documented ranges and
functions, the initial load being a step the GM adjudicates for the
whole system. Housing computes the stays (1–2 500: animal, section,
admission, end, outcome by id), the species, the infectious alert
current on each stay, and the staff layout (nurses among 29–51, carers
57–66); the composition record lists these keys and the scale check, 64
units against 40 current stays.

The history follows the core's year: each stay placed ten minutes after
admission in the lowest-id free unit that fits (isolation when
infectious), one in five moved, released at its end, disinfected 30 to
90 minutes later; diets, a nil-by-mouth order for one stay in six, the
care log day by day, times and carers by hashes. At T0, as a night
leaves the wards: 40 stays placed once each, the night's checks done,
units released in the last hour `to-clean`. The build fails if a stay
finds no fitting unit; the GM's post-load coherence check then reads
every placement on a real stay and every current stay placed, a
mismatch being a design error caught before hand-over, never a fault.
About 0.16 million rows and 50 MB; 540 a day; nothing ships to cold
storage.

#### Roles, classification, rules

| Role | May |
|---|---|
| `housing` | own the tables and the view; no login |
| `housing_app` | the housing screens on `pms`: read housing's tables and the core's `stays`, `animals` (species), `alerts`, `staff` (kind) by column; write placements, plans, and units' `state` only |
| `housing_ward` | the ward service's writes: insert care events, set units' `state`; nothing else |
| `vet_display` (core's) | the displays' reads: `animal_board` and `housing_unit_board` only |
| `vet_reports` (core's) | the back office on the standby: every housing table |

A display can neither move an animal nor touch the record. No housing
table holds personal data; the board's `animal_id` is
`customer-linked`; notes are `internal` and may name the owner (a
trap). Rules (game values): the board shows no owner, contact or
natural identifier; an animal with a current `infectious` alert is in
isolation, every emptied unit disinfected before the next, isolation
always (Regulation (EU) 2016/429, Art 10); nil by mouth shown from its
start, no feeding while in force (eight hours before an anaesthetic,
twelve for horses and ruminants); checks every four hours, feeding at
the species' rounds (horses 06, 12, 17, 21; ruminants 07, 16; dogs 08,
17; cats 08, 13, 18); no dose in the care log; **actions, not
accesses**: a display's reads are logged nowhere, not in a table, a
heartbeat or the audit log; records kept five years from the stay's
end.

#### The producers: `pms` and the ward service

On `pms`, connection `housing` (as `housing_app`): `housing.place`
(work, 6/h, about 8 a day: the oldest unplaced current stay into the
lowest-id clean fitting unit, with its diet), `housing.release` (work:
a placement whose stay ended by discharge, transfer or death),
`housing.move` (about 2 a day), `housing.fast` (about 3 nil-by-mouth
orders a weekday); two reads for the nurses. A new stay's placement is
the practice software's own work, not a flow between parts.

The displays talk to a **ward service holding a pool**, as real ones
do, with no scheduler change: `ward`, a scheduler node of its own in
the players' scope, so its sessions show `ward` as `application_name`,
apart from `pms`. Connections `ward-board` (`vet_display`, `pool:
{size: 4}`) and `ward-care` (`housing_ward`, `pool: {size: 2}`): sixty
consumers in six sessions against `max_connections`' 100.

| Key | What | Rate at 1.0 |
|---|---|---|
| `ward.board` | a display's refresh, `SELECT ... FROM housing_unit_board WHERE unit_id = %(unit)s`, `{int: [1, 64]}`; no row written | 3 840/h, even, concurrency 4: 92 000 a day |
| `ward.feed` | work: an occupant behind its meals and not nil by mouth, read off the board | 60/h on `feeding-rounds`, about 110 a day |
| `ward.check`, `ward.care` | a check; water, mucking out, bedding, walk or grooming | 10/h each, about 240 and 160 a day |
| `ward.disinfect` | work: a unit `to-clean` for 30 minutes, made `clean` | 4/h on `care-day`, about 8 a day |

At another intensity the displays refresh faster or slower (one
intensity a node); the GM notes say so.

#### Finding a faulty display

T150, a display's refresh stuck in a loop, is test-selection fault s9,
class M. The players' way: (1) the querier, the board statement run by
`vet_display` from `ward`; (2) the redundant query, its calls per minute
above 64; (3) the box: `pg_stat_statements` normalises the parameter
and the driver binds it server-side, so it shows only when the
statement is logged with its parameters for `vet_display` alone (a role
setting, the ward's pooled sessions terminated to reconnect); an
instance-wide setting would log owners' names and phones from `pms`;
(4) the chain unit → display → open placement → stay → animal. A
display's firmware is no player layer: T150 is reported, never fixed,
and judged at the final answer on the report alone (the unit, the
display's serial and the animal named, the excess shown, no
instance-wide logging left behind). The GM never switches the display
off during play; the feedback says the technician would replace it.

#### Purposes, traps, tests, capacity

No purpose of its own; housing joins purpose 9, `vet-head-office-figures`,
whose 00:30 feeder adds the units occupied and in service per section
at midnight. The catalogue, T150–T171, covers the ward service (a
snapshot held open, connections per call, a heartbeat or a per-access
log, missing indexes), the chain (releases on discharge only, a
two-transaction move, two animals in a unit, care on the stay that
left), care and biosecurity (the latest plan hiding nil by mouth,
infectious animals outside isolation) and governance (the owner's
contact on the board, read auditing on). The `housing` fixture
(`records`, `pms`, `ward`, bastion; about 0.8 CPU and 0.75G) proves in
under 30 minutes each the load's placements, the board (64 calls a
minute, no owner), placement and release (T0 10:00), the care log (T0
before 17:00), and T150 present, reported, cleared by the test turning
the display's key off. Loading: into `clinic` as `postgres` after the
core's schema, every time following the core's shifted stays. Capacity:
`ward` (`scheduler`, 0.1 CPU, 64M, 128M disk, armenelos); a few
hundredths of `records`' CPU.

### 9.6 `vet-machinery`, the machines and their databases

`vet-machinery` holds the centre's machines: the three sections'
imaging (CT, MRI, radiography, ultrasound, the horses' scintigraphy),
the theatres' and intensive care's monitors, and the lab's analysers.
It is a part: `requires: [vet-core]`, tables and roles prefixed `mach_`,
core keys by id with no foreign key. Each machine system keeps its own
database. A vet orders an imaging study in a consultation (the request
stays in the core); it is scheduled, performed, reported by an imaging
specialist, and the report goes back to the record. Monitors and
machines produce readings, a day kept on site, the rest shipped to
cold storage, in plain partitioned tables (TimescaleDB stays beyond
v1.0). Detail: `vet-machinery-domain.md`.

#### Nodes and placement

| Node | Brick | Scope | CPU | Memory | Disk |
|---|---|---|---|---|---|
| `machines`: databases `pacs` (imaging archive and worklist), `vitals` (the monitors' central station), `biomed` (biomedical engineering: registry, logs, readings) | `postgres` | players' | 0.5 | 512M | 2.25G |
| `equipment`: every machine and its system as one producer | `scheduler` | players' | 0.1 | 64M | 128M |
| `machines`' exporter (`options: [monitoring]` on `machines`) | `postgres-exporter` | monitoring | 0.05 | 48M | 64M |

0.65 CPU and 624M, all on armenelos (the VPS has no room for a database
node). The vault is cold storage's hostname on the partners' shared
`api` node; both flows run on `interfaces`. Trims, in order, each the
owner's call: `machines` at 0.25 CPU and 384M; the fragments on `pms`
(no `equipment`; a fault on `pms`'s schedule then stops the machines);
no exporter; at all three, two nodes and about 0.25 CPU. Three vendors'
systems share one configuration, superuser and failure domain
(plausible at `managed` maturity, the consolidation traps' source).

The several-database shape is domain-format text: the scenario's `at:`
is a map, `{pacs: machines/pacs, vitals: machines/vitals, biomed:
machines/biomed}`; the folder holds `data/<database>/schema.sql` and
`load.sql`; classification keys stay `<table>.<column>`, unique across
the part, the scenario's copy adding the database; the loader creates
the databases and revokes `CONNECT` from `PUBLIC`.

#### What it holds

- **`biomed`**: the registry `mach_machines` (kind, DICOM modality,
  section, species group, `bookable`, `ionising`, `telemetry`, `status`
  `in-service`/`down`/`retired`, `qa_due_on`); maintenance (service,
  repair, QA test, calibration, update), downtimes; `mach_events` (the
  logs, info to critical, an operator by staff id, critical ones
  acknowledged), partitioned monthly; `mach_readings` (a row a minute
  per machine, channels in `jsonb`), partitioned daily and shipped;
  `mach_readings_daily`, the kept aggregate.
- **`pacs`**: 30 procedures (study codes by modality and species
  group); `mach_worklist` (accession `I-<request id>`, unique, the
  idempotency key; the identity the lookup API answered, in DICOM's
  form: `patient_id` `A-<animal id>`, `patient_name` "owner's
  surname^animal's name", the owner as Responsible Person); studies
  (operator, restrainer, companion present, images, size, exposure),
  series; reports, `preliminary` or `final`, an addendum a new row
  superseding the final, which is kept.
- **`vitals`**: the census of the core's current stays; monitor
  sessions on a stay (`anaesthesia` or `icu`); `mach_vitals`, a row
  every 10 seconds per open session, partitioned daily and shipped; the
  chart (5-minute under anaesthesia, hourly in intensive care, the
  clinical record, kept); alarms.

Each partitioned table has a default partition, empty by design, and
its indexes on the parent; partitions are created ahead (three days;
next month's on the 25th); a shipped partition is detached and dropped,
never deleted from. Lifecycles: a worklist entry `new` → `scheduled` →
`in-progress` → `completed`, or `cancelled` by the imaging team once
sent (the vet cancels in the core while `requested`); a study
`acquired` → `reported`, an unscheduled one (typed on the modality at
night) `reconciled` within the day or `unmatched`; a session ends by
the census or by staff; a machine `in-service` ⇄ `down` → `retired`.

#### Keys and scale

| Key | Range, layout |
|---|---|
| `mach_machines.id` | 1–28: 1–6 the lab's analysers (1–2 haematology, 3–4 biochemistry, 5 blood gas, 6 coagulation; on call at night 1, 3, 5); 7–16 imaging (7 CT small animal, 8 CT large bore, 9 MRI 1.5 T, 10 standing MRI with no helium, 11–13 DR, 14–15 ultrasound, 16 gamma camera), bookable by `vet-scheduling`; 17–20 anaesthesia monitors, 21–28 intensive-care monitors; telemetry 1–9 and 16 |
| `mach_procedures.id` | 1–30: 1–12 small animal, 13–27 large animal, 28–30 any; DX 45 % of studies, US 30, CT 15, MR 7, NM 3 |
| History | worklist 1–3 400 (the k-th imaging request of the core, in time order), studies 1–3 470, series 1–8 000, reports 1–3 450, sessions 1–3 800, functions of their ids in the GM notes; studies 3 465–3 470 six unmatched ones (a typed patient id naming no animal), the PACS's mistyped chips |
| Core keys used | imaging requests by the core's request function (study code drawn among these 30 by species group); animals 1–17 000; stays 1–2 500 by the stay function; staff 26–28 imaging specialists, 52–55 radiographers, 56 the biomedical engineer |

About 0.34 million rows at load, the raw window a third of it. Live, about 68 500 rows a day: 52 000 raw vitals
(about five animals in intensive care around the clock, up to four
under anaesthesia on weekdays), 15 800 readings, about 700 that stay;
about 11 studies a day (13 a weekday, 6 Saturday, 3 Sunday).

#### Roles

| Role | Database | May |
|---|---|---|
| `mach` | each | own everything; no login |
| `mach_pacs_app` | `pacs` | write worklist scheduling, identity and state, studies, series, reports; never the procedures |
| `mach_vitals_app` | `vitals` | write census, sessions, vitals, chart, alarms |
| `mach_biomed_app` | `biomed` | write events, readings, maintenance, downtimes, the machines' `status` and `qa_due_on` only |
| `mach_maint` | `vitals`, `biomed` | `EXECUTE` on `mach_create_partitions(days)` only |
| `mach_service` | `biomed` | the vendors' remote service (no producer in v0.5): read machines, events, readings, maintenance; write maintenance |
| `mach_orders` | `pacs` | purpose 13: insert worklist entries, read their states and the reports |
| `mach_archive` | `vitals`, `biomed` | purpose 14: read raw rows, write aggregates, `EXECUTE` on `mach_drop_shipped`; no ownership |

`CONNECT` on each database goes to its own roles only. The two
partition functions, `mach_create_partitions` and
`mach_drop_shipped(day)`, are `SECURITY DEFINER`, owned by `mach`, with
a fixed `search_path`, so the jobs create and drop partitions without
owning the tables.

**Classification.** `personal`: the worklist's animal id, patient id
and name, natural identifiers and Responsible Person (DICOM puts the
owner's surname in Patient's Name); a study's as-acquired patient id
and name; a vendor engineer's name. `customer-linked`: a session's and
the census's animal id. Everything else is `internal`, the shipped rows
included as long as they carry a session's id only.

#### The business's own rules (*gv*: game value)

1. A report leaves the PACS only once the final is signed; a
   preliminary is visible inside, marked.
2. A signed final is never updated; an addendum supersedes it.
3. A study carries the owner's surname and the animal's name from the
   lookup API, never a contact.
4. Logs name operators by staff id only; kept twelve months (*gv*);
   pgaudit logs writes, DDL and roles without parameters.
5. Each ionising study records its radiographer, who restrained the
   animal, and whether a companion was present (Euratom standards).
6. A yearly QA test per ionising machine (*gv*), an expert check every
   five years; a machine past its QA date is not used.
7. Critical alerts (helium, a quench) acknowledged by the biomedical
   engineer within four hours (*gv*).
8. Images, reports and the chart kept five years; raw rows the window,
   then the vault; maintenance the machine's life and five years (*gv*).
9. A vendor's account reaches `biomed` only, never as a superuser.
10. A shipment carries `internal` columns only, never the animal; cold
    storage is the clinic's processor.
11. No day ships before its chart or daily aggregate exists on site.

#### Producer profiles

`equipment` holds three connections (each database as its `_app` role)
and an HTTP one to `clinic-api`; the partition jobs run on `machines`'
`pg_cron` as `mach_maint`. At intensity 1.0: `vitals.sample` 360/h
(set-based, about 52 000 rows a day), `biomed.readings` 60/h (15 800),
`biomed.events` 10.4/h, `vitals.alarm` 3/h, `vitals.anaesthesia.start`
1/h on `theatre`; rare flows (unscheduled studies and cancellations
weekly, addenda every three days); work streams, at capacities, schedule, acquire,
reconcile and report studies. Fixed-time: `mach.identity` every minute
(identities from `GET /animals/{id}` and `/owner`, a script job with a
`pacs` and an HTTP connection); `mach.census` every 5 minutes (`GET
/stays?current=true`, an intensive-care session opened for about one
new stay in three by a hash, ended when the stay leaves);
`vitals.chart` every 5 minutes; partitions at 22:00 and 22:05, the
events' on the 25th. Shapes: `imaging-day` (weekdays 08:00–18:00,
Saturday morning at 0.6, else 0.1), `reporting` (weekdays 08:30–18:00,
Saturday 09:00–12:00), `theatre` (weekdays 08:00–18:00, else 0.1).

**Cold storage and backup.** `vitals` (above the threshold) and
`machine-readings` (below it, shipped by the owner's direction for lab
machinery) ship nightly at 00:40, the last full day and today kept;
both are the GM's call per scenario; nothing else ships. `machines` has
no standby and no WAL archive: a nightly base backup to the vault, so
recovery goes back to last night. A stalled shipping grows the disk by
10 MB a day, never a problem within an aging; it shows on the vault's
graph and the partition count.

#### Purposes 13 and 14

**13, `vet-imaging-orders`**, a round trip inside the centre on
`interfaces`, as purpose 1, `vet-lab-centre-orders`: the integration
engine writes the PACS's worklist and reads the reports back.
`post-imaging-orders` (every minute) inserts an entry for each
`requested` imaging request of a closed consultation (`ON CONFLICT
(accession) DO NOTHING`), then marks the request `sent`, the `pacs`
commit first; no identity leaves the core. `fetch-imaging-reports`
(every 5 minutes) marks requests `resulted` on a signed final (never a
preliminary) or `cancelled` on the imaging team's cancellation; past
the turnaround (urgent 18 hours, routine three working days) one
incident. Invariants IO1–IO4: posted within 5 minutes (2 urgent), never
two entries, `resulted` within 10 minutes, end to end in turnaround.

**14, `cold-storage-archive`**, the generic round trip of cold storage,
this part its first user. `ship-partitions` (`40 0-5 * * *`, as
`mach_archive`) posts each daily partition older than the window, its
readings' aggregate computed first, as NDJSON of `internal` columns to
the vault's `POST /shipments` under `<type>-<day>` (a resend replaces
its manifest); a receipt whose count matches lets `mach_drop_shipped`
detach and drop it; otherwise it is resent next run, an incident at
06:00. Invariants CA1–CA4: no drop without a matching receipt, one
manifest per type and day, the aggregate first, every day in the vault
by 06:00. Its `history.sql` plants the history days' manifests.

#### Traps, loading and the build

The catalogue (T200–T237, in the domain document) covers the shared
instance, identity, governance, partitions and cold storage, the round
trip and performance. None is in v0.5's ten; T208 (no partition created
ahead, rows from midnight stuck in the default partition) stays a trap
for the GM, its short test kept.

**Loading.** `gmctl load-data` creates the databases, revokes `CONNECT`
from `PUBLIC`, runs each `schema.sql` and `load.sql` as `postgres`
(explicit ids, sequences after their ranges, the core's ids computed
without reading `clinic`, partitions for the window and ahead, sessions
unseen), then purpose 14's manifests. **The build verifies** the
partition functions' fixed `search_path` and, after load, sessions on
core stays and entries on imaging requests. Two fixtures under 30
minutes: *imaging* (7 nodes, T0 a weekday 08:50), a request through to
`resulted`; *vault* (6 nodes, T0 21:55), a night's shipment to the drop.

### 9.7 `vet-portal`, the owners' portal

`vet-portal` is the centre's owners' portal, a part: `requires:
[vet-core]`, tables and roles prefixed `portal_`, the core's and the
lab's keys by id with no foreign key. Every owner of the record has an
account showing the animals they own now and what the centre released
about them: signed consultations, released lab results, discharge
summaries. It notifies them of each new document, reminds them of
vaccinations if they consented, through the franchise's messaging
service, and keeps every consent event and what was released, notified
and opened. It is information only: no booking, no appointment
reminders (none in v0.5), no payment, no messages to vets, no imaging
(later, a fourth document kind), no treatment consent (the core's,
later). Detail: `vet-portal-domain.md`.

#### Placement and nodes

A database `portal` on the core's instance (`at: records/portal`),
separated from `clinic` and `office` by roles, `pg_hba.conf` and its own
settings; it rides `records`' standby and backups; `pgcrypto` is
created in it. One node, `portal-api` (`api`, players' scope, 0.1 CPU,
96M, armenelos); `interfaces` grows to 96M. The owners' traffic runs
out of reach on the partners' shared `api` node under a tenth hostname,
`owners`: owners are people, not a third party, so it has no
`partners.md` entry. It is a traffic source that is no business, under
`producers/partners/owners/` or `producers/public/owners/` (chosen at
the build).

#### What it holds

- **Accounts and sessions**: one account per core owner but the clinic
  (name, e-mail as login, phone, `status`, hashes, `failed_logins`,
  `locked_until`, `notify_by` `email`/`sms`/`none`, the `reminders`
  flag); sessions by a SHA-256 token hash.
- **Copies of the core**, written by purpose 15 only: animals,
  ownerships (`role` `owner` or `keeper`, `from_at`, `until_at`), herds;
  no address, no natural identifier; two places for one fact by design.
- **Documents** (`consultation`, `result`, `discharge`; a `source_ref`
  unique with its `version`; `record_at`, the record's own time;
  `gated_at`; the vet's name; a `jsonb` body; `supersedes_id`) and
  views (account, document, time).
- **Consent events** (owner, `reminders` or `keeper-access` with animal
  and keeper, granted or withdrawn, source) and **the outbox** (a
  `message_key` kept on retries; one notice per document and account,
  one reminder per animal and due day).

An account goes `invited` → `active` → `closed` (or `invited` →
`closed`), never reopened; locked is a time, not a state; an expired
invitation is renewed by a reset. A message is sent or, after six
attempts, failed; a consent is the latest event.

#### Keys and scale

Account `o` belongs to owner `o` (2–10 000, migrated from an old
portal); the sequence is set at 20 000, so accounts created in play
take 20 001 on, and joining an account's id to an owner's id is right
for every loaded account and wrong for every new one (trap T261). At
load about 65 % active, 32 % invited, 3 % closed, by a hash of the id;
5 200 owners with the reminders' consent, 250 keeper grants; documents
1–41 600 and the other history in time order. A vaccination is
due on day `1 + (animal_id × 211) mod 365`, for domestic animals and
horses only. Passwords and tokens are HMACs of the account's id and the
game's seed, so the owners' route logs in without the partners'
database storing one; the load stores bcrypt (cost 6, *gv*) and SHA-256
hashes. About 0.21 million rows at load; live about 720 a day: 140
documents, 150 visits (mostly 18:00–22:00), 120 messages.

#### Who may do what, and how a session is scoped

Every table has row-level security enabled and forced; the tables
belong to `portal`, a role with no login; `portal_api` owns nothing and
has no `BYPASSRLS`. Each API request is one transaction. After login,
the API first calls `portal_session(token)`, which returns the account
only if its session is open, seen within 30 minutes and under 12 hours
old, then runs `set_config('portal.owner_id', <that account's
owner_id>, true)`, local to the transaction. Its queries carry no owner
filter: the policies scope everything to that owner id (never the
account's id).

| Table | `portal_api` sees or writes |
|---|---|
| animals | the asker's current `owner` ownership (`until_at` open); or the asker is its current `keeper` and the current owner's latest `keeper-access` event for that keeper and animal is a grant |
| ownerships, herds | the asker's own rows (a herd: its keeper's) |
| documents | the animal visible as above (a herd's: its keeper), and `record_at` on or after the current owner's ownership start, so never a record from before the sale |
| accounts | the asker's own row, without the hashes; writes `notify_by` and `reminders` only |
| consent events | the asker's own; insert only as the asker |
| views | insert only, as the asker's account |
| sessions, outbox | no grant: through the functions only |

Before anyone is known, the API calls `SECURITY DEFINER` functions
owned by `portal`, `search_path` pinned: `portal_login(email,
password)`, `portal_session(token)`, `portal_activate(token, password,
reminders)`, `portal_request_reset(email)`, `portal_reset(token,
password)`, `portal_unsubscribe(message_key)`, `portal_close()`,
`portal_desk_consent(owner_id, purpose, granted)`. They and the queries
are the API's `db/` side, which players may fix; never the routes.

- **An owner** activates from the invitation's one-time link (sets a
  password, is offered the reminders' consent), logs in and out, lists
  their animals, lists an animal's documents (newest first, 50 at
  most), opens one (a view recorded in the same transaction), changes
  their channel, grants or withdraws the reminders' consent or a named
  keeper's access to one animal, unsubscribes from a reminder's link
  without logging in, resets the password, closes the account (personal
  columns erased, sessions ended, consent events kept, never reopened).
  Contacts change only at the core's desk, copied in.
- **A keeper** (a core owner with a current `keeper` ownership: a
  stable, a livery yard, a holding) has an account like any owner and
  sees a kept animal, as its owner does, only while keeping it and
  while the owner's latest `keeper-access` event for them is a grant.
  A herd's documents go to its keeper. Owner 1, the clinic, has no
  account.
- **The desk**, a receptionist through `pms` with the desk's credential
  (a secret), records an owner's reminders' consent (source `desk`).
  Vets and pathologists never use the portal.

Refusals: a wrong password answers `401`, a locked account (five
failures, 30 minutes) `423`, success `201` with a token. Out of scope
is absent, not forbidden: the policies return no row, so a list is
shorter or empty and another owner's document is not returned. An
insert outside the asker's scope fails the policy's check with an
error. An expired, idle or ended token yields no account.

Other roles: `portal_housekeeping` purges sessions ended 30 days ago
(03:30, `records`' `pg_cron` via `cron.schedule_in_database`); purpose
15's `portal_sync` (accounts, never a closed one's; copies; documents)
reading `clinic` as `vet_portal_sync` and `lab` as `lab_release`, both
read-only by column grants that leave out addresses, identifiers and
notes; purpose 16's `portal_dispatch` (the outbox). The purposes' roles see
every row. `pg_hba.conf` admits `portal_api` to `portal` only, over
`hostssl`; `CONNECT` on `clinic` and `office` is revoked from `PUBLIC`.

**Classification.** `personal`: accounts' identity and hashes, token
hashes, a document's vet's name, the outbox's address and payload.
`customer-linked`: the ids elsewhere. A document's body is `internal`.

#### The business's own rules (*gv*: game value)

1. **Owner scope** as above, enforced by row-level security.
2. **Release gate**: a result once released by a clinical pathologist,
   never on technical validation; a consultation once signed; a
   discharge once the stay ended; an amendment a new version; each
   within 15 minutes (*gv*).
3. **Least data**: no address or identifier in the copies; no free
   text, alert or staff contact in a document; no practice's patient.
4. **Accounts**: invitation valid 14 days, bcrypt cost 6, five failures
   lock for 30 minutes, sessions 30 minutes idle and 12 hours at most,
   tokens hashed (*gv*).
5. **Closing** erases at once and keeps the consent proof (GDPR Art 17).
6. **Consents**: the latest event is the truth, the flag a convenience
   no job reads; a withdrawal counts from the next message; reminders
   on opt-in (*gv*).
7. **Messages** via the messaging service only: address, template, the
   animal's name, a link; never a result, diagnosis, identifier or
   password; reminders 08:00–20:00, never for a dead animal, a former
   owner or a closed account, each with a withdrawal link.
8. **Audit**: every opening recorded; pgaudit without parameters.
9. **Logs**: `log_statement = none` on `portal`.
10. **Reach**: the API on `portal` only, over TLS.
11. **Retention** (*gv*): documents five years, views and messages two,
    sessions 30 days, consent events five years after the account.

#### Producer profiles

`portal-api` writes nothing on its own. The owners' route (`owners-day`:
1.6 at 18:00–22:00, 0.8 by day, 0.1 at night) drives it with
`owners.visit` 9.3/h (one in 300 locks itself out, one in 50 tries an
old token, every result recorded for RL6), activations, resets,
unsubscribes, keeper grants and closures; `pms` adds
`portal.desk-consent` 0.28/h. Nothing ships to cold storage.

#### Purposes 15 and 16

**15, `vet-portal-release`**, pulled with a release gate (core, lab,
portal), every 5 minutes on `interfaces`: `sync-portal-identity`
invites new owners and copies animals, ownerships and deaths, never
touching a closed account; `publish-records` publishes signed
consultations and ended stays; `publish-results` the lab's tests of
account 1 released since its watermark, and amendments as new versions,
from the lab's release, never the core's request state; each run
writes documents and watermark in one transaction. Invariants RL1–RL6: none
before its gate; each once within 15 minutes; no forbidden content;
copies within 10 minutes; and RL6, judged on the owners' recorded
visits against the core's ownerships, the owner scope end to end.

**16, `vet-portal-messages`**, pushed to the messaging stub (202 with
an id, idempotent on the key, a 503 one call in fifty; no receipts or
bounces): `queue-notices` every 5 minutes (transactional, no consent);
`queue-reminders` at 09:00 (14 days ahead, consent by the latest
event); `send-messages` every minute (reminders 08:00–20:00, consent
checked again, the same key on retry, an incident after six attempts).
Invariants MS1–MS6; the outbound flow `to: messaging` carries
`address`, `template`, `animal_name`, `link`.

#### Loading and the build

**The load** runs `schema.sql` and `load.sql` into `portal`, never
reading the core or the lab: accounts, consents, reminders, sessions
and tokens by documented functions, the sources' keys by their ranges
and functions. **The derivation step**, sanctioned by the GM in the
composition record (`derive: {after: [vet-core, vet-lab]}`), exists
because documents copy the record field by field and formulas would
regenerate it a third time: `data/derive.sql` runs after those loads as
`postgres` through a temporary foreign server it then drops, sessions
unseen, and derives content only: the copies at T0, the year's
documents in order of gate and reference, their versions, views and
notices, and the stub's notices of the last 14 days. The post-load
coherence check reads every document against its gate; the pre-login
functions' `search_path` is checked at the build. The `portal` fixture
(eight nodes, T0 a weekday 08:50, the test writing the gates as
`vet_app` and `lab_app`) proves copies, gate, owner scope, accounts
and messages, each under 30 minutes. T270, the animals' policy without
the ownership's end, replaces s5 in v0.5's test selection: a planted
former owner's `GET /animals` returns the horse they sold; once fixed,
only the buyer sees it (`records`, `portal-api`, the bastion, about 10
minutes).

## 10. Third parties, the partners' nodes and cold storage

### 10.1 What a third party is

A **third party** is a business the customer depends on but does not own
or operate: an external lab, a carrier, a customs gateway, a payment or
mail provider, a regulator receiving reports, the franchise's other
centres and central systems. The customer has a contract with it and an
interface to it, never its internals. It is not a system of the
customer's that the players are not asked to fix (a report-only node, a
contractor inside the customer's estate, as v0.4's BI agency), and not a
person (referring vets, owners: actors of the story). Its role in a
scenario: a source of inbound flows, a target of outbound ones, or a
round-trip partner, either side asking.

- **Faults it may carry**: behaviour seen at its interface, as a
  timeline change of its schedule or as standing behaviour: an outage,
  slow answers, errors, a lost, late, duplicated or out-of-order
  callback, a wrong correlation id, a payload changed without notice, a
  maintenance window.
- **Faults it may not carry**: a root cause inside it; the players cannot
  reach it, so such a fault is unsolvable.
- **Every fix is on the customer's side**: retries with a backoff, an
  idempotency key, a timeout, a reconciliation, monitoring the partner.
  No fix ever requires the third party to change. Telling the partner,
  with the evidence, is a finding the answer key may credit, never a
  fix.
- **The GM's checks** may read a third party's side as evidence; they
  judge the customer's side.
- v0.4's customs gateway stays as built; from v0.5's scenarios on, a
  pushed obligation's `receiver` is a declared third party.

### 10.2 How a game builds them: out of reach, on shared nodes

- **Out of reach**: a third party's nodes have no `player` account, are
  not on the bastion's routes and are not among the starter pack's
  nodes. Hiding alone would not do: a player with a shell elsewhere
  finds them on the network. The per-node option is the existing
  `no-access` write policy **made real**, no new key: on a brick that
  implements it, the entrypoint creates neither the `player` account nor
  its `sudo` wrappers (`api`, `scheduler`, `postgres`).
- **One network**, as `gmctl` renders it; a third party's back end is
  closed by its own access rules: its database's `pg_hba.conf` admits
  only the partners' own roles on their database, every other line for
  that database a `reject`, the roles' passwords secrets mounted on the
  partners' nodes only (how that form holds on one Swarm network, whose
  task addresses change, is the build's to verify). As
  with a real lab, its API is reachable from outside, its database is
  not. Separate networks wait for later.
- **Its interface stays callable**: a player may call a partner's public
  API from a node, as the customer's staff could, with the credentials
  the starter pack gives.
- **Three partner nodes for every partner of a scenario** (the owner:
  "Indeed partners can be grouped for ease of usage"): one `api` node
  serving every partner, each under its own hostname through network
  aliases, so the players still see distinct partners; one scheduler
  node, the **back end**, driving their calls from its hidden schedule;
  one small `postgres` database holding their state, each partner's
  tables and role its own. Per partner stay its routes (dispatched by
  hostname), its `partners.md` entry, its misbehaviour keys (a key
  switching that partner's state, read by its own routes, never a stop
  of the shared node), and, for cold storage alone, the bastion's route.
  The build verifies that one partner's slow answers never hold
  another's (the node's workers).
- **The clinic's nine partners**: the external reference lab (Northfield
  Veterinary Laboratories), the two other national centres, the centres
  abroad as one, the franchise's head office (monthly figures), the
  franchise's messaging service, cold storage, the region's practices
  (the lab's outside customers, as one), and the authority
  (notifiable diseases, the antimicrobial-use report). A **tenth
  hostname, `owners`**, stands for the owners' browsers calling the
  portal: ticked by the same back end, out of reach like the partners,
  but no business: no `partners.md` entry, no contract, no misbehaviour
  keys of a partner's.
- **Placement**: as any node, counted by `fit`; with several hosts the
  GM may place them on the host the players do not own, a preference.
- **Declared** in `scenario.yaml`'s `third_parties:` (6.2). **What the
  loader checks**: each node listed exists
  and has `write_policy: no-access` on a brick that implements it; no
  third-party node is in the bastion's `web_routes`, but for cold
  storage's read-only paths, or among the starter pack's nodes; no fault
  instance's expected *fix* names a third-party node; a third-party
  `postgres` node's seed `pg_hba.conf` admits no role but the partners'
  own on their database.

### 10.3 What the players are told

Each partner is described as a real company knows its partner, in
**`partners.md`**, the fifth optional starter-pack file, shown on the
bastion's page: its name and what it does for the business; the
contract (what it promises: a result within so many hours, an
acknowledgement within a minute, its support hours); the interface (its
endpoints and formats, the authentication, the customer's callback URL,
the retries it makes or expects); and an in-world **support contact that
never answers during the game**, since the GM plays no partner: the
players write in their report the message they would send, and the
answer key may credit it. Never its internals: no node names to audit,
no schedule, no code. No status page in v0.5 (v0.6). The GM side has the
`third_parties:` entries, the hidden schedules, the faults it carries,
and a "Third parties" section in the scenario document.

### 10.4 Cold storage and the vault

The owner: "the rest get shipped to cold storage (S3 like, and more to
the point, out of the game). We may need a "cold storage interface" in
whatever maner, that allows us to "control" what's been stored but
keeping it soft". Cold storage is a **generic third party** for heavy
data, any domain's, the clinic's machinery first, declared with the role
`round-trip`, its stub under the hostname `cold-storage` on the
partners' `api` node. What is shipped leaves the game: nothing reads it
back.

- **The customer's side** (in the players' scope): heavy data lives in
  plain partitioned tables, a partition a day, created ahead; the site
  keeps the current day and the last full day by default, longer for a
  type the exercise reads. A **shipping job** runs each night after
  midnight, customer time: for each type, each partition older than the
  window is one shipment; on a receipt whose rows received equal the
  rows sent, it detaches and drops the partition; on a mismatch or a
  timeout it keeps it and resends under the same shipment id. It is the
  generic round-trip purpose `cold-storage-archive` (purpose 14). Whatever
  a periodic report needs from shipped rows is aggregated on site first,
  in a daily summary kept for the whole game.
- **The stub's side**, three endpoints: `POST /shipments` (a header with
  shipment id, data type, rows declared and date range, and the rows as
  NDJSON; counts the rows, discards the payload, writes a manifest,
  answers a receipt; the same shipment id again replaces its manifest, a
  new id for a day already shipped adds a second one); `GET /manifests`
  (JSON, filtered by type and dates); `GET /` (a page graphing rows
  shipped per day per type, declared against received, drawn on the
  server). **A manifest** holds the type, rows declared and received,
  the date range, the shipment's time and id, and for `wal` and
  `basebackup` the segment's or backup's name and size; kept in the
  partners' database. The load plants the history's manifests, so the
  graph shows the weeks before the hand-over.
- **Who reads it**: the players, through the bastion (`GET /` and
  `GET /manifests` only, 7.3); the GM, whose checks read the manifests as
  evidence.
- **When a type ships is the GM's call, use first, volume second** (the
  owner: "data that are needed for transformation, reporting, etc that
  IS used for the exercice may not be cold storaged, or may be storaged
  with an appropriate scheduling"): data a purpose, transformation or
  report reads stays on site or ships only after its consumers' cadence
  and a margin (a daily consumer: after two days); about 50 000 rows a
  day at intensity 1.0 only marks a candidate; every domain's notes give
  each producer's growth an hour and, per shipped type, its retention
  on site and the consumers it waits for; the node is sized for the
  retention on site plus the aging's slack.
- **The clinic's types**: `vitals` (the monitors' readings, about 52 000
  rows a day) and `machine-readings` (the machines' telemetry, shipped by
  the owner's direction), the last full day kept on site, shipped nightly
  at 00:40; and the vault's `wal` and `basebackup` (11.2).
- **Shipped data is gone**: a fault whose evidence lies only in shipped
  rows is unsolvable, and is not planted. Its customer-side faults are
  traps (deleting before the receipt, a stalled job, duplicate
  shipments, a wrong window, `DELETE` instead of dropping the partition,
  no partition ahead, aggregates after the shipment, a window shorter
  than a consumer needs).

## 11. Replication, the vault and the back office

The owner: "we could have probably one off site (but still within
network) replication set up, and another (cold storage like) set as
well". Redundancy stays inside the one centre a scenario deploys.

### 11.1 A standby off site

- **Which**: the instance holding `vet-core`, `records`, the system of
  record every part and the portal reads around the clock; the only
  standby in v0.5. What lands in that instance rides along: scheduling's
  and housing's tables in `clinic`, `office`, and the portal's database
  `portal` (so its password and token hashes are off site too, under
  the record's access). `lab` and `machines` have none.
- **Where**: a `postgres` node in standby mode, `standby`, the centre's
  **off-site room** (a second building, a rented rack), in the players'
  scope, on the one network; on the other host where there are two, a
  preference.
- **How**: asynchronous streaming replication; a physical slot named for
  the standby; a replication role whose password is a secret;
  `hot_standby` on; cloned after the data load, before the aging (7.1).
- **Reports read there**, `hot_standby_feedback` on so long report
  queries are not cancelled, its cost (vacuum held back on the primary)
  a thing to watch; the standby being read-only, a report job holds a
  second connection, to `office` on the primary.
- **Observed** in `pg_stat_replication` on the primary, and in the
  monitoring the scenario has.

### 11.2 The vault: WAL archive and nightly base backups

- **WAL archiving**: `archive_mode` on, an `archive_command` sending each
  segment to the vault, `archive_timeout` an hour.
- **Base backups**: `pg_basebackup` each night in the low hours, sent
  whole, from the node's cron daemon.
- **Which instances**: `records` and `lab` archive their WAL and send a
  nightly base backup; `machines` sends a nightly base backup only (it
  recovers to last night; its readings ship anyway); each manifest names
  its node.
- **The vault is cold storage itself**, with the types `wal` and
  `basebackup`: one stub, one page, one manifest model.
- **Plain PostgreSQL tools**, no pgBackRest. Restores, point-in-time
  recovery and restore drills wait for v1.0 or after, since they need a
  vault that keeps the data.

### 11.3 The back-office database `office`

The reports read on the standby and write their outputs to a database
of the business's office, `office`, on the primary's instance (the
owner: "agreed for the office database", after "I'm on the fence to
have a dedicated database for administrative purpose (separation of
concern, etc)").

- **It holds** what the office produces, not the operational record: the
  periodic reports' outputs, the lab's monthly statements to its outside
  customers, copies of the regulatory submissions sent.
- **Its roles**: `office_jobs` writes `office` and reads nothing of the
  record; the reports read the standby as `vet_reports` (and
  scheduling's report as `sched_reports`) and the lab's node as
  `lab_reports`, none with a write grant; `office_reader` reads `office`
  for the back office's staff. The operational record carries no report
  table.
- **Placement**: no new node; it rides the standby and the archive; the
  separation is by database and roles. A variant may move it to an
  instance of its own.
- **Not a domain part**: its tables are the purposes' targets (each
  purpose carries its target's DDL and plants its past outputs, 12.1);
  a part would hold no data of its own and no producer.

### 11.4 Fault candidates

Traps for the GM (the test selection takes two, 17.2): a
`synchronous_standby_names` naming an absent standby (every commit
waits; a candidate for the dramatic fault); an abandoned slot filling
`pg_wal`; replication lag (the reports stale); query conflicts on the
standby (reports cancelled, or the primary bloated); `archive_command`
failing silently (segments recycled unsent, gaps in the vault); gaps in
the WAL sequence; base backups older than the retention; `pg_wal`
filling the disk when archiving fails honestly; the lab left out of the
archive; and, for `office`, a report job writing to the old target, the
office role holding writes on the record, a report reading the primary,
an `office` moved to its own instance and left out of the copies.

## 12. Purposes

v0.4's purpose model stands: a purpose's jobs, trace, invariants and the
faults that break them, consumers modelled by their trace, checks
judging runs since a moment with witnesses. v0.5 adds a fifth kind, the
**round trip**, beside pulled, transformed in place, pushed and pushed
obligation (v0.4's export declarations stay as built), and **periodic
purposes** whose past periods the load plants (8.4). A round trip's
definition states the request (what is sent, by which job, to which
partner), the correlation key, the expected answer, a timeout, and the
reactions the answer starts. **A cascade's fix** is judged end to end,
on the trace produced after the fix, wherever the player fixed it (for
the lab: each new order gets its result released); fixing a symptom
alone earns nothing; the backlog the fault left (the orders stuck before
the fix) is listed in the answer key as a consequence the GM may credit,
not a fault and not counted toward the cap. The clinic's round trips:
the external lab's results, the region's practices ordering from the
centre's lab, the exchanges with the other centres, cold storage's
receipts, the machines' imaging orders.

### 12.1 The purpose format's extensions

Each clinic purpose is stated in v0.4's format (identity, parts, jobs,
trace, invariants, data moved, roles) and becomes
`purposes/<id>/purpose.yaml`, `material/`, `checks/` and `gm.md`. The
format gains:

1. **The round-trip kind**: `kind: round-trip`, beside pulled,
   transformed in place, pushed and pushed obligation (v0.4's export
   declarations stay a pushed obligation, as built), and a
   `round_trips:` block, one entry per exchange the purpose carries (the
   centres' exchanges carry two, one each way): who asks (the customer
   or the partner); the request (its job, its counterpart, what it
   sends); the correlation key; the expected answers (each form, when it
   comes, what it carries); the timeout and what follows it (resend with
   the same key, escalate); the reactions (the processes an answer
   starts, the purpose's jobs or a domain's streams, named).
2. **Two parts**: `api`, a customer's `api` node the purpose calls or
   brings endpoints to (`lab-api`, `clinic-api`); `partner`, a declared
   third party's node. From v0.5 a pushed obligation's `receiver` is a
   declared third party too.
3. **HTTP connections** in a job's `connections:`, named for the part
   they reach.
4. **Endpoint and receiver material**: `material/api/<node>/routes/` and
   `db/` for the endpoints a purpose brings to a customer's `api` node,
   the layout of a domain's `producers/api/`. A receiver with no stream
   of its own (the authority, the head office) keeps its stub in the
   purpose, as v0.4's export declarations keep `material/receiver/`; a
   partner with streams of its own (the practices, the external lab, the
   centres) stays in its domain's `producers/partners/`.
5. **Periodic jobs**: a periodic job names its daily feeder, the witness
   within the aging; `material/history.sql` plants the past periods'
   outputs before T0. `office` belongs to no domain, so the purpose
   plants it: `load-data` runs the file in the target after the sources'
   loads, as the superuser, reading the sources through a temporary
   foreign server it drops afterwards, every session unseen (no
   statement logging, `pg_stat_statements` and pgaudit off).
6. **`judged:`** on each invariant, one of `runs` (verdicts by runs, as
   v0.4), `triggers` (pushed obligations' deadlines), `end-to-end`,
   `code` (the sealed check reading the code, for a periodic report's
   own logic) or `definition`. A round trip names exactly one
   `end-to-end` invariant.
7. **The classes of its tables**: a purpose whose target belongs to no
   domain (`office`), or which adds tables to a domain's database,
   classes their columns in its own `classification:` entry, as a domain
   does, so governance's checks read them.

**The `ops` schema.** The purposes' own tables in a domain's database
(their ledgers, incidents, watermarks) live in a schema `ops`, in
`clinic`, `lab` and the parts' databases the purposes write (`pacs`,
`vitals`, `biomed`, `portal`), never in `public`, where the domains'
tables and a part's prefixed ones live: no purpose's table ever clashes
with a part landing in the same database. `office`'s tables are the
purposes' own, in `public`. **Every run** writes one `ops.runs` row (in
`office`, `runs`) in the same transaction as its output, as v0.4's
`etl_runs`, beside the runner's log; the checks tie trace rows to runs
by it.

**A cascade judged end to end.** A round trip's faults often show
downstream of the acknowledgement: requests marked sent with no order
behind them, results that never come. A fix check judges the
`end-to-end` invariant on the trace produced after the fix (for the lab:
each new order gets its result released), wherever the players fixed
it; fixing a symptom alone earns nothing. The **backlog** the fault left
(the orders stuck before the fix) is listed in the answer key, never in
the purpose, as a consequence the GM may credit the players for cleaning
up: not a fault, and not counted toward the fault cap. Where a request's
leg is longer than a session (send-outs answered days later), the
purpose judges its two ends, and a fault between them leaves its backlog
in the answer key.

### 12.2 The clinic's sixteen purposes

**Existing purposes.** None fits as built: v0.4's four declare
`domains: [shop]`. Their shapes recur: the sales reporting's database of
its own is the office's reports, the export declarations' pushed
obligation the notifications, the customer mailing the portal's
vaccination reminders. The generic `cold-storage-archive` fits
`vet-machinery`, its first user (purpose 14); nothing of the core's or
the lab's ships, and the WAL and base backups the vault receives are the
`postgres` brick's, not a purpose.

**Built and waiting.** The ten purposes of `vet-core` and `vet-lab`
(1–10) are all built in v0.5. The release to the portal, which waited
for `vet-portal`, is purpose 15, defined with that part; the parts' six
(11–16) were ruled with their pages and numbered after the ten. The
**referral's report back to the referring vet**, as an electronic flow,
comes later: in v0.5 the vet's letter closes a referral. No appointment
reminders in v0.5. `vet-housing` has no purpose of its own: its
occupancy joins purpose 9. Each purpose's candidate faults are traps;
a scenario's faults are the GM's to select.

**The runners.**

- **`interfaces`**, the centre's integration engine, a scheduler node,
  role `transformer`, 96M: every flow between the centre's systems and
  out to its partners, light and frequent. Each job holding an HTTP
  connection is a script job (read, call, write), none more often than
  every minute.
- **`backoffice`**, the report runner, role `transformer`: the periodic
  reports and feeders, heavy at night, reading the standby's `clinic`
  and `lab`, writing `office`. Two runners because the engine is
  latency-bound (an urgent order within a minute) and the reports heavy:
  a report placed on `interfaces` is a fault candidate, not the design.
- **The lab's `pg_cron`**: the critical calls' watch, set-based.
- **The partners' back end**, out of reach; the authority and the head
  office answer only, with no stream.

**`office`**, the back office's database, belongs to no domain; on the
primary's instance beside `clinic`, it rides the standby and the
archive, about 0.16 million planted rows, 500 more a night.

**Roles.** In `clinic`: `vet_interfaces` (the engine's jobs: requests'
state, exchanges' sent columns, check-in's consultations, `ops.*`),
`sched_interfaces` (bookings and their links), `vet_portal_sync` (reads
owners without address, animals without identifiers; writes nothing),
`vet_exchange` (`clinic-api`'s exchange endpoints), `vet_reports` (the
standby, read only). In `lab`: `lab_dispatch` (the engine's lab jobs),
`lab_watch` (the `pg_cron` watch, `ops.incidents` only), `lab_reports`
and `lab_release` (read only). `mach_orders` on `pacs`, `mach_archive`
on `vitals` and `biomed` (no table owned), `portal_sync` and
`portal_dispatch` on `portal`. In `office`: `office` (owner, no login),
`office_jobs` (writes `office` only, reads nothing of the record),
`office_reader` (staff and dashboards). A report job holds two
connections, reading as a `*_reports` role, writing as `office_jobs`.

**1. `vet-lab-centre-orders`**, round trip inside the centre, the core
asking; fits `vet-core`, `vet-lab`. On `interfaces`, `clinic` →
`lab-api` as the centre's account 1 (never charged): `post-lab-orders`
every minute posts closed consultations' requests, keyed `client_ref`
`C-<consultation>-<priority>`, `sent` once the call returns;
`fetch-lab-results` every 5 minutes polls the released-results feed
with a watermark (the lab never writes `clinic`). A sent request is
cancelled by the lab only. Trace: `requests`, `ops.lab_orders_sent`,
`ops.request_results`, `ops.watermarks`, `ops.incidents`, `ops.runs`.
- LO1 (triggers): each closed consultation's request `sent` within 5 minutes, 2 if urgent, or `cancelled`.
- LO2 (runs): each request id on one lab order test only.
- LO3 (runs): each release `resulted` within 10 minutes; nothing `resulted` unreleased.
- LO4 (end-to-end): each order's tests released or not performed within turnaround plus the next round.

**2. `vet-lab-practice-results`**, round trip the partner asks; fits
`vet-lab`. The region's practices (one stub, 120 accounts) order at
`lab-api`; on `interfaces` as `lab_dispatch`, `deliver-practice-results`
every minute posts interim, final and amended deliveries to each
account's callback, keyed `delivery_key`, four in parallel, an
acknowledgement due within 30 seconds, retried 5 minutes after the last
attempt, six attempts then an incident. Trace: `lab_callbacks`,
`ops.incidents`, `ops.runs`.
- PR1 (triggers): each released test acknowledged in a final within 15 minutes, or an incident.
- PR2 (runs): one `delivery_key` per order, kind and revision, kept across attempts.
- PR3 (runs): no unreleased result delivered. PR4 (runs): each delivery to its own account only.
- PR5 (end-to-end): each order's released results acknowledged within turnaround, round and 15 minutes.

**3. `vet-lab-send-outs`**, round trip the lab asks, the
consumer-producer; fits `vet-lab`. On `interfaces` as `lab_dispatch`:
`send-outs` at 16:00 Monday to Friday posts the day's send-outs to the
external lab's stub, keyed `send_key`, catalogue fields only; the answer
comes one to five days later at `lab-api`; `chase-send-outs` every 15
minutes, 08:00–19:00 Monday to Saturday, retries, asks a resend, then
escalates. Trace: `lab_send_outs`, sample events, `ops.incidents`,
`ops.runs`.
- SO1 (triggers): each send-out received by 15:30 on a working day accepted that day, or an incident.
- SO2 (runs): one `send_key` per send-out. SO3 (runs): no owner, client, identifier or note sent.
- SO4 (end-to-end, the answer's leg): each answer recorded, its test released by the next round.

**4. `vet-centre-exchanges`**, round trip both ways; fits `vet-core`.
The core records transfers and examinations in `exchanges`; on
`interfaces`, `sync-exchanges` every 5 minutes posts requests, answers
and reports to the three centres' stubs; `chase-exchanges` at 09:00 on
working days resends with the same `exchange_key`, then escalates. The
purpose's endpoints on `clinic-api` (`POST /exchanges`, `.../answer`,
`.../report`) only answer. Trace: `exchanges`, `ops.exchange_messages`,
`ops.incidents`, `ops.runs`.
- EX1, EX2 (triggers): outbound received, inbound answers and reports posted, within 10 minutes.
- EX3 (runs): one key per exchange, each answer on its own exchange.
- EX4 (runs): only this animal's record and its owner's contact.
- EX5 (end-to-end): each outbound exchange answered within a working day, or chased then escalated.

**5. `vet-notifiable-diseases`**, pushed obligation; fits `vet-core`,
`vet-lab`. Triggers: a lab notification (any customer's) and a vet's
notifiable diagnosis, suspected or confirmed; deadline an hour for
category A, a day otherwise (`diagnosis_codes.notifiable`: `none`, `A`,
`other`). On `interfaces`: `notify-lab`, `notify-vet` every 5 minutes,
`escalate-notifications` every 15; on `backoffice`, the 02:15 copy into
`office.regulatory_submissions`. The authority's stub, in the purpose,
answers with a reference, 503 to one call in fifty.
- ND1 (triggers): each trigger notified within its deadline. ND2 (runs): one accepted per trigger.
- ND3 (runs): disease, species, holding or keeper, notifier, date; never clinical notes.
- ND4 (triggers): each referenced, or an incident by the next escalation. ND5 (runs): copied once.

**6. `vet-lab-critical-calls`**, pushed obligation, the receiver the
person owed the call; fits `vet-lab`. The watch only (the call is the
staff's): a `pg_cron` job on `lab` every 10 minutes as `lab_watch`, one
statement writing an incident for each critical result over 60 minutes
old with no read-back, `cron.log_run` on. Trace: `lab_results`,
`lab_critical_calls`, `ops.incidents`, `cron.job_run_details`.
- CC1 (triggers): each critical result read back within 60 minutes, or an incident. CC2 (runs): one incident each.

**7. `vet-medicines-registers`**, pulled, periodic; fits `vet-core`;
both registers in one purpose. On `backoffice`, standby → `office`:
feeders at 01:30 (supplies, with the legal fields) and 01:45
(controlled movements); extract and balances on the 1st; the inventory
on 1 January. Planted: the year's lines, every month, last January's
inventory.
- MR1 (runs): each day's supplies once, as the source's. MR2 (runs): legal fields only, no e-mail or phone.
- MR3 (runs): each day's controlled movements once. MR4 (code): balance = previous closing less movements, per batch.

**8. `vet-antimicrobial-use`**, pushed obligation, periodic; fits
`vet-core`. On `backoffice`: the 02:00 feeder (use per species and
medicine, herd treatments through their herd); on 15 January last year's
report for the species due (cattle now, more from 2027 and 2030) to the
authority, due 31 January. Planted: the year's rows, last year's report.
- AM1 (runs): each day's use as the source's. AM2 (runs): every use traces to a species.
- AM3 (code): the report covers the species due and sums its days. AM4 (triggers): acknowledged by its deadline.

**9. `vet-head-office-figures`**, pushed obligation, periodic; fits
`vet-core`, `vet-lab`, `vet-housing`. On `backoffice`: the 00:30 feeder
(consultations, admissions, the midnight census, housing units occupied
and in service, the lab's tests and median turnaround); the month posted
to the head office's stub on the 1st, retried to the 5th, then
escalated. Planted: the year's days, every month.
- HO1 (runs): each local day's counts as the sources'. HO2 (runs): one row per day, section, measure.
- HO3 (code): a month sums its days, sent by the 5th and acknowledged, or escalated.

**10. `vet-lab-statements`**, pulled, periodic; fits `vet-lab`. On
`backoffice`, reading `lab` at night (no standby): the 02:30 feeder of
billable and voided practice charges; each account's statement on the
1st with its discount bracket (3 to 15 %). Planted: the year's lines and
statements.
- ST1 (runs): each day's charges once. ST2 (runs): the centre's account never charged.
- ST3 (code): a statement = billable less voids, with its bracket's discount.

**11. `vet-bookings-sync`**, transformed in place, the clinic's first;
fits `vet-core`, `vet-scheduling`. Script jobs every minute on
`interfaces` as `vet_interfaces` and `sched_interfaces`: check-in opens
the core's scheduled consultations (the core's own opening stream
removed), imaging requests and accepted examinations booked, a dead
animal's bookings cancelled. Trace: `sched_bookings`,
`ops.booking_consultations`, `ops.watermarks`, `ops.runs`.
- BS1 (triggers): each arrival has its consultation within 2 minutes. BS2 (runs): one consultation per booking.
- BS3 (triggers): each imaging request booked within 2 minutes. BS4 (triggers): no booking left for a dead animal.
- BS5 (triggers): each accepted examination booked on its date, or an incident.

**12. `vet-working-time`**, pulled, periodic; fits `vet-core`,
`vet-scheduling`. On `backoffice`, standby → `office`: the 09:30
feeder (after the night shifts end) of worked hours and rests under 11
hours; the month on the 1st. Planted: the year.
- WT1 (runs): each shift as clocked. WT2 (runs): each short rest a breach. WT3 (code): a month sums its days.

**13. `vet-imaging-orders`**, round trip inside the centre, as purpose
1; fits `vet-core`, `vet-machinery`. On `interfaces`:
`post-imaging-orders` every minute writes worklist entries into `pacs`
as `mach_orders` (accession `I-<request>`); reports and cancellations
fetched every 5 minutes; a sent request cancelled by the imaging team
only. Trace: `requests`, `mach_worklist`, `ops.imaging_results`,
`ops.watermarks`, `ops.runs`.
- IO1 (triggers): each request `sent` within 5 minutes, 2 if urgent. IO2 (runs): one worklist entry each.
- IO3 (runs): each final copied within 10 minutes, never a preliminary. IO4 (end-to-end): final within turnaround, or cancelled.

**14. `cold-storage-archive`**, the generic round trip; fits
`vet-machinery` first. `ship-partitions` at 00:40, resends hourly to
05:40, on `interfaces`, `vitals` and `biomed` as `mach_archive` → cold
storage's stub; a partition dropped only on a matching receipt, the last
full day kept. Trace: `ops.shipments`, `ops.runs`, the vault's manifests.
- CA1 (runs): no drop without a matching receipt. CA2 (runs): one manifest per type and day.
- CA3 (runs): the day's aggregate before the drop. CA4 (end-to-end): every day in the vault by 06:00, none older left.

**15. `vet-portal-release`**, pulled, with v0.4's release gate; fits
`vet-core`, `vet-lab`, `vet-portal`. Every 5 minutes on `interfaces`,
`clinic` and `lab` → `portal` as `portal_sync`: accounts invited,
ownerships and deaths copied, documents published only past their gate
(signed, released, ended), about 140 a day. Trace: `portal_accounts`,
the copies, `portal_documents`, `ops.watermarks`, `ops.runs`.
- RL1 (runs): no document before its gate. RL2 (triggers): each gate's document within 15 minutes, once.
- RL3 (triggers): amendments as new versions within 15 minutes. RL4 (runs): no address, identifier, free text.
- RL5 (triggers): owners invited, ownerships and deaths copied within 10 minutes; no closed account reopened.
- RL6 (runs, on the owners' visits): each account sees exactly the animals it owns or keeps now.

**16. `vet-portal-messages`**, pushed; fits `vet-portal`. On
`interfaces` as `portal_dispatch` → the messaging service's stub:
notices queued every 5 minutes, vaccination reminders daily at 09:00
with consent, `send-messages` every minute (reminders 08:00–20:00, keyed
`message_key`, six attempts then an incident). Trace: `portal_outbox`,
`ops.incidents`, `ops.runs`.
- MS1 (runs): one notice, reminder, message per key. MS2 (runs): consent held at sending.
- MS3 (runs): reminders 08:00–20:00. MS4 (runs): template, name, link; a token, never a password.
- MS5 (triggers): each notice accepted within 15 minutes, or an incident. MS6 (runs): no reminder for a dead animal or to a former owner.

## 13. Governance and the data register

### 13.1 Beyond v0.4's first cut

v0.4's governance stands: data classes, locations, readers, outbound
flows, the policy handed to the players, the checks on the live catalog.
The clinic, a regulated business, brings the richer rules:

- **Its own rules, as default policies**: each domain carries the
  business's rules (`docs/policy.md` and a `governance:` fragment) with
  their game values, which the GM copies into the scenario's data policy
  and adapts: eleven for the core, thirteen for the lab, and the parts'
  (9.2 to 9.7). Where a rule is national, the policy takes one member
  state's reading and says so; every period and deadline is a game
  value, stated as one.
- **Required settings**: TLS on, pgaudit loaded with its classes,
  statement logging that never writes personal data, `CONNECT` granted
  by name and revoked from `PUBLIC`.
- **Audit trails**: pgaudit on the record and the lab; the lab's
  validation and release, the controlled-drugs register.
- **Retention**: each activity's period, then erased or anonymised.
- **Owner-scoped access**: the portal's row-level security, an owner
  seeing only the animals they own or keep, and only what has been
  released (9.7); the clinic's richest governance case.
- **What goes out**: the least data per recipient (catalogue fields only
  to the external lab; no clinical notes to the authority; no owner's
  data in a message to the franchise's messaging service); privileged
  flows to the other centres under the franchise's agreement.

### 13.2 What a register is, and why the players get one

The owner: "Scenarios may/should have data registries (as handout) to
the players(could also be some fault here: desync from the ground
truth, entierely absent, ill documented, etc)". A scenario's **data
register** is game content: a player handout listing the business's
data, in the shape of a record of processing (GDPR Art 30), with two
departures: it covers **all** the business's data, internal included
(activities holding internal data only in a closing table, one line
each), and its "where" goes down to **tables and columns**, since the
players compare it with the databases.

- **Grouped by department, then by activity**: a department is a domain
  under a business name (the record, the lab, scheduling, housing,
  machinery, the portal); an entry is one activity. An index at the end
  lists each `node/database` and its entries. The clinic comes to about
  twenty entries and the internal table, about 150 lines.
- **One entry**: the activity (a name and a stable id, `core-owners`);
  its purpose; the people concerned; the data held, by class; where
  (`node/database`, the tables, the copies: the standby, the vault);
  shared with (each recipient inside or a third party by its
  `partners.md` name, with the fields it receives, processors marked,
  transfers outside the EU marked); kept for (the period, then erased or
  anonymised). Security measures are left out: the policy states them.
  The header names the controller (the centre) and a data-protection
  contact, and points to the policy.
- **Two handouts**: the policy states the rules (written by the GM), the
  register the inventory (generated). A register fault never touches the
  policy, and the policy stays the reference the register is read
  against: a retention or a class breaking it is a finding. The policy
  says the register exists ("what we hold, where and for how long: our
  register of processing"), even when a fault leaves the register out.
- **Delivery**: `player/data-register.md`, the bastion's sixth optional
  seed file, copied into `/home/player` and shown on the page as "Data
  register" after the data policy, only when the scenario has one.
- **Which scenarios**: every scenario listing `domains:` must have one,
  the deploy refusing it otherwise; v0.4's released shop scenario is
  exempt until it is next revised; a scenario with `governance:` alone
  may have one. This repository itself keeps no data register: every
  scenario's data is synthetic, and the game's own inventory is its
  catalogue.

### 13.3 The `data-register` skill

A GM sub-skill, `.claude/skills/data-register/` (the owner: "it should
probably be added as a subskill to the GM ensuring such registries get
generated with the appropriate informations (with fault planted or
not)"), on the `scenario-document` model: generated from the
authoritative files, never edited by hand, regenerated rather than
reconciled.

- **Inputs**: the composed domains' classification copies and register
  fragments; `governance:` and the policy's retention values; the
  composition record; `scenario.yaml` (topology, `third_parties:`, the
  purposes in use, the register faults); the answer key.
- **Outputs**: `gm/data-register.yaml`, the true register, sealed, opening
  with `generated_from:` (each input's digest); `player/data-register.md`,
  the true register rendered as is or with a planted register fault's
  change applied, and absent when that fault is the register's absence;
  for each register fault, the answer key's `register_diff:`, which the
  scenario document shows in a "Data register" section.
- **Triggers**: when a scenario is composed or regenerated; after any
  change to its domains, classification, governance, composition,
  purposes, topology or register faults; before deploy, at setup step 2.
- **Completeness**, by the loader (formats.md "Scenario"): the digests
  recomputed, a stale register refused; coverage (every `personal` and
  `customer-linked` column in exactly one entry under its class, every
  location and outbound flow present, every database with business
  tables in an entry), a miss a generation error caught before the
  hand-over, never a fault; the handout present unless the answer key
  declares its absence.
- **In the GM's flow**: Setup step 2 runs the format check, then the
  register, then the scenario document. On a restart the GM reads the
  true register with the scenario document; during the game it never
  shows or quotes it.
- **Where the true register stops**: it describes the system as designed
  and composed, before any fault is planted. A fault planted in the
  system leaves both registers unchanged: the register is a reference
  the players read the system against.
- `gmctl` gains no generator: the skill writes, the loader checks.

### 13.4 Register faults

Planted in the handout only, nothing in the system changing: a
`seed-file` change on the bastion, fault ids `governance-register-*` in
the `security` family. The players cannot edit the customer's register,
so the resolution is ***propose***: the corrected entry goes in their
report, judged at the final answer against `register_diff:`; the sealed
check reads only that the change is present in the bastion's copy. A
register fault counts as a minor friction by default; a dramatic one
needs a story the customer noticed. The family (traps for the GM): an
entry out of date, a column missing, a store missing, a wrong class, a
wrong retention, the register absent, the register vague, a flow to a
processor not declared (cold storage, the vault; the messaging service).
v0.5 builds one (s6, 17.2); the skill can apply any of them. False-alarm
material: "five years for clinical records, France keeps ten" (a game
value, the policy says so); "no recipient for the results coming back"
(an inbound flow is a source).

## 14. Topology and capacity

The clinic is a two-host scenario, armenelos plus the VPS. Nodes are
sized by role as v0.4's were: a `postgres` node at 0.5 CPU and 512M, a
producer or light transformer at 0.1 CPU and 64M, a heavy transformer at
192M; the `api` brick estimated at 0.1 CPU and 96M, 128M for the
partners' node. These are starting figures, measured by the build in
short runs; the aging's figures wait for the major test.

| Node | Brick | Scope | CPU | Memory | Host |
|---|---|---|---|---|---|
| `bastion` | `bastion` | the players' | 0.1 | 96M | armenelos |
| `records` (`clinic`, `office`, `portal`) | `postgres` | the players' | 0.5 | 512M | armenelos |
| `standby`, off site | `postgres` | the players' | 0.5 | 512M | VPS |
| `lab` | `postgres` | the players' | 0.5 | 512M | armenelos |
| `machines` (`pacs`, `vitals`, `biomed`) | `postgres` | the players' | 0.5 | 512M | armenelos |
| `pms`, the practice software (with scheduling's and housing's screens, the portal's desk) | `scheduler` | the players' | 0.1 | 96M | armenelos |
| `lis`, the lab's software | `scheduler` | the players' | 0.1 | 64M | armenelos |
| `ward`, the ward service | `scheduler` | the players' | 0.1 | 64M | armenelos |
| `equipment`, the machines' producer | `scheduler` | the players' | 0.1 | 64M | armenelos |
| `interfaces`, the integration jobs | `scheduler` | the players' | 0.1 | 96M | armenelos |
| `backoffice`, the reports | `scheduler` | the players' | 0.1 | 192M | VPS |
| `clinic-api`, `lab-api`, `portal-api` | `api` | the players' | 0.1 each | 96M each | armenelos |
| `prometheus`, `grafana` | v0.2's | monitoring | 0.1 each | 160M, 272M | armenelos, VPS |
| four exporters (`records`, `standby`, `lab`, `machines`) | `postgres-exporter` | monitoring | 0.2 | 192M | three on armenelos, one on the VPS |
| `pgwatch` (7.4) | `pgwatch` | monitoring | 0.1 | 96M | armenelos |
| `health` (7.4) | `health-check` | monitoring | 0.1 | 64M | VPS |
| the partners' `api` node, back end, database (`partners-api`, `partners-backend`, `partners-db`) | `api`, `scheduler`, `postgres` | out of reach | 0.45 | 448M | VPS |

**The clinic: 25 nodes, 4.05 CPU, about 4.15G of memory (4 240M),
about 13.6G of volumes**: the six domains' 23 nodes (3.85 CPU, 4 080M)
and the monitoring breadth's two (0.2 CPU, 160M; pgCluu has no node),
at the low end of the 25 to 27 nodes, 4.0 to 4.25 CPU, the drafts
estimated. Against the pair's 5.4 CPU and 7.2G once `fit`'s 10 %
headroom is taken (armenelos 4 CPU, 4G, 20G; the VPS 2 CPU, 4G, 10G,
shared), memory has room and **CPU is the tight dimension**, at 75 %.
Placed: armenelos 17 nodes, about 2.75 CPU and 2.65G (76 % and 74 % of
its 3.6 CPU and 3.6G); the VPS 8 nodes, 1.3 CPU and about 1.45G (72 %
and 41 %). Neither new node has a volume. The VPS's disk is its second
limit: no other `postgres` node fits there, so `machines` and the
parts' nodes go to armenelos; the health node adds an image of about a
tenth of a gigabyte there.

- **No hand-over snapshot** fits either host at this size: a game of the
  whole clinic has none on these declarations (a warning, not a
  refusal). The proof in play does not need one; whether v1.0's major
  test does is that test's to settle.
- **The shared VPS** takes no node that may exhaust its memory; none of
  the test selection's faults sets `needs_unshared_host`.
- **Trims, if the build measures heavier**, in this order, each the
  owner's call when it comes: the monitoring to one collector, the
  exporters, pgwatch left out (7.4);
  `vet-machinery`'s trims (its producer's fragments on `pms`, no
  exporter, `machines` at 0.25 CPU); the partners' database on
  `records`' instance, out of reach by its access rules.
- **Checked at the build**: `gmctl fit` on the scenario as built, with
  measured reservations and real image sizes (Prometheus' among them,
  with pgwatch's series added), on armenelos plus the VPS
  before the proof in play; each fixture's `fit` on one host before its
  test.
- A pooler in front of `records` stays the scenario's choice (0.05 CPU,
  32M).

## 15. The local implementation and the scripts

- **`gmctl compose`** (new, design time): merges each scheduler node's
  fragments (8.4), writes ordinary files into the scenario folder, its
  report recording every override, stopping on a conflict between two
  profiles until `merge.yaml` resolves it.
- **The loader** (`tools/gm/model.py`): `domains:` and its checks; a
  domain's new keys and folders (`check_domain_dir`); duplicate keys
  refused in the merge's inputs; `composition.yaml` against
  `domains:`; the data register's digests and coverage; `options:`
  against the brick's declaration, and a monitoring node refused against
  a node without `monitoring` unless a fault plants the gap;
  `third_parties:` (10.2); `no-access` accepted only on a brick
  declaring it; the `SECURITY DEFINER` check at a domain's build.
- **`load-data`**: a part's load after its core's; several databases
  created for a part, `CONNECT` revoked from `PUBLIC`; a sanctioned
  `derive.sql` and every purpose's `history.sql` run after the loads
  they read, through a temporary foreign server dropped afterwards,
  their sessions unseen (statement logging, `pg_stat_statements` and
  pgaudit off); then **the coherence check** (8.5), whose failure stops
  the setup as a design error.
- **The standby's clone**: after the data load and before the aging, a
  setup step cloning the standby from its primary (7.1).
- **`render`**: the network aliases of the partners' `api` node; the
  bastion's route to cold storage's read-only paths; the HTTP
  connections' credentials as secrets; the TLS certificates generated
  per game as secrets.
- **The GM skill** (`game-master`): composition and its record at
  design time; the coherence check at setup; the `data-register` skill
  in Setup step 2; third parties played by no one (their support never
  answers); a report-only fault on a display judged at the final answer,
  never cleared in play.
- **The `scenario-document` skill**: "Third parties", "Composition" and
  "Data register" sections.

## 16. Player access and rules

The game's access and the fiction's are kept apart; the
[access model](access-model.md) states both in full.

- **The game's access** is v0.4's: the players enter through the bastion
  only, as `player`, reaching the nodes in their scope with the write
  policies the scenario sets; the GM acts in its own plane. v0.5 adds:
  the standby, the `api` nodes (the players read every endpoint file and,
  where the scenario makes it fixable, edit the database side only,
  never a route or a contract, through a reload wrapper), cold storage's
  read-only page through the bastion, the partners' public interfaces
  callable with the credentials the starter pack gives; and the
  partners' nodes out of reach (`no-access`), with no account, no route
  and no listing.
- **The fiction's access**: the clinic's staff, owners, keepers,
  practices and partners act through database roles, application
  credentials and row-level security, which the players audit. A player
  who reaches a database as `dba` is not an owner on the portal; what an
  owner may see is a rule of the data, and its breach a fault the
  players find.

## 17. The clinic scenario and its faults

### 17.1 The scenario

One new scenario, `aldermoor-centre`, proving the clinic's
six domains in play as v0.4's scenario proved the shop: one centre of
Aldermoor Veterinary Hospitals, composed of the six domains in the
`regional-franchise` variant (8.5), the 25 nodes of section 14 with
the monitoring breadth of 7.4, its nine partners and the owners' traffic
on the shared partners' nodes, its purposes (12.2), its data policy
adapted from the domains' default policies, `partners.md`, and its data
register handed to the players. The owner judged it "one of the most
complex scenario that we will propose". Its story names the centre, the
off-site room and the partners by their in-world names.

**Its faults, the owner's budget**: ten at most, one dramatic and
already noticed by the customer, two on the verge of becoming
problematic, the rest good optimisations and minor frictions; an issue
may be a false alarm, a complaint with no fault behind it. Selecting a
game's faults is the GM's role (the owner: "selecting the faults is the
GM's role (with the assistance of the person that setup the game)"), at
deploy, among the domains' traps, the budget binding any selection.

### 17.2 The test selection

The spec's own pick, for the build's tests and the proof in play: a
fixture, not the canonical scenario; it binds no game. v0.5 builds these
ten faults and the false alarm's material; every other trap stays listed
for the GM, to write as a scenario's own fault when a game selects it.
The mix: one dramatic, two on the verge, seven minor, and the false
alarm.

| # | The fault | Class | What it proves | Planted |
|---|---|---|---|---|
| s1 | **Urgent priority dropped** in the centre's lab orders: urgent tests posted routine, waiting for the pathologist's next round; the emergency team's blood gases hours late, the customer's complaint | dramatic | a round-trip cascade, its fix judged end to end | `interfaces`' order-posting script's mapping (seed file) |
| s2 | **`archive_command` failing silently**: segments reported archived, none in the vault | on the verge | replication's archive; the vault's `wal` manifests and its page | `records`' `postgresql.conf` |
| s3 | **Herd prescriptions dropped from the antimicrobial use**: the daily feeder misses treatments given through a herd; last year's planted report short of the cattle's use, with the next yearly report due in January | on the verge | a periodic report and its daily feeder as witness | the feeder's query on `backoffice`, and the planted report |
| s4 | **A retry under a new `client_ref`**: a timed-out order post retried with a new key, a duplicate order now and then | minor | a round trip's correlation key; the catalogue's held retry-without-key fault built | `interfaces`' script |
| s5 | **The portal's animals policy ignores an ownership's end**: former owners still see the animals they sold; planted a few hours before T0, so only the day's sales are exposed | minor | row-level security and owner-scoped access | the policy on `portal` (DDL) |
| s6 | **Cold storage, the vault, declared nowhere in the data register**: a flow to a processor missing from the handout | minor | the data register and its skill: a planted deviation, the two registers, the diff; resolved by *propose* | the bastion's `data-register.md`, written by the skill |
| s7 | **Statement logging on `records`**: owners' names and phone numbers in the server log | minor | governance in the logs; the catalogue's held statement-logging fault built | `records`' `postgresql.conf` |
| s8 | **The standby an hour behind** (`recovery_min_apply_delay`, "for safety"): the night's feeders miss the evening | minor | the reporting standby | the standby's `postgresql.conf` |
| s9 | **A faulty display reading its board in a loop**, about once a second, below what saturates the ward's pool: found through the ward service's redundant statement and the box, stay and animal chain; reported, never fixed, a display's firmware being no layer of the players' | minor | many small consumers behind one service | the display's key in `ward`'s profile layer |
| s10 | **`monitoring` not chosen on `lab`**: the exporter cannot log in | minor | the options model | the topology's `options` |
| fa | **"The external lab is slow"**: a PCR answered on its fourth day, within its one-to-five-day turnaround | false alarm | an issue with no fault behind it | an issue in the starter pack |

No fault of the ten sits on an `api` node's database side (the `api`
brick's own build checks cover it), none tests the displays' own
service, and none may exhaust a node's memory (none sets
`needs_unshared_host`). s9 is judged on the report at the final answer:
the GM never switches the display off during play. s2 and s6 share the
archive fixture: planted together, the archive fails silently while the
vault still holds the planted manifests and base backups, so s6's
witness stands; the answer key notes the interaction. The faults
re-used from the catalogue add the new brick versions to `applies_to`;
`pg-abandoned-replication-slot`'s precondition widens (6.4).

### 17.3 Each fault's short test

Present, fixed and the time each takes, every one under 30 minutes with
the deployment, on the fixtures of 18.2:

- **s1**: the fixture raises the rate of emergency consultations on
  `pms` (its profile layer) so an urgent request closes within minutes.
  Present: a lab order `routine` whose request is `urgent`, within ten
  minutes. Fixed: after the mapping's fix, the next urgent order is
  `urgent`, released at once, its request resulted within ten minutes;
  the routine-posted ones left waiting are the backlog, a creditable
  consequence; the end-to-end invariant for the urgent orders posted
  after the fix. About 25 minutes.
- **s2**: the test switches a segment (`pg_switch_wal()`); present:
  `pg_stat_archiver` reports it archived, no `wal` manifest names it, the
  vault's page shows the gap; fixed: the next switched segment's
  manifest present, the gap staying a finding. About 10 minutes.
- **s3**: present: the 02:00 feeder's day (a Thursday, herd visits)
  short of the herd treatments the source holds; last year's planted
  report short. Fixed: after the query's fix, the feeder moved to the
  next minute and its day complete; the planted report stays wrong, its
  rerun recommended. About 20 minutes.
- **s4**: the test delays one post past the runner's ten-second timeout
  (a lock held on `lab_orders`). Present: two lab orders for one
  consultation, two `client_ref`s. Fixed: the same delay gives one
  order, the second post answered with the first accession. About 15
  minutes.
- **s5**: the fixture plants the policy a few hours before T0 and a sale
  in that window. Present: as the former owner, `GET /animals` on
  `portal-api` returns the horse they sold. Fixed: it does not, and the
  buyer still sees it. About 10 minutes.
- **s6**: present: the bastion serves `data-register.md` (in
  `/home/player` and on the page) with cold storage among no entry's
  recipients, the true register names it on every entry it holds, the
  vault's page lists `records`' `wal` and `basebackup` manifests.
  Cleared: the handout regenerated without the fault names it (the
  change is reversible). Proposed: the corrected entries, judged at the
  final answer against `register_diff:`. About 10 minutes.
- **s7**: present: an owner's name and phone in `records`' log after a
  few practice-software writes the test runs as `vet_app`. Fixed: after
  the fix and a reload, the same writes leave no personal data. About 10
  minutes.
- **s8**: present: the replay lag at an hour; the 01:30 feeder's day
  missing the evening's last hour of supplies. Fixed: the delay removed,
  the lag near zero, the feeder moved and its day complete. About 20
  minutes.
- **s9**: present: the board statement's calls well above 64 a minute in
  `pg_stat_statements`, from `ward`, the unit's parameter logged for
  `vet_display` alone. Reported: the chain from the parameter to the
  unit, its display's serial and the animal. Cleared, by the test only:
  the display's key switched off, the calls back to 64 a minute. About
  15 minutes.
- **s10**: present: the exporter's login errors against `lab`. Fixed:
  the option chosen and the node redeployed, the exporter's metrics
  present. About 15 minutes.
- **fa**: the fixture plants a PCR send-out answered on its fourth day;
  the check reads its due date against its answer, within turnaround.
  About 5 minutes.

### 17.4 The scenario's register

The clinic scenario's `player/data-register.md` is generated with s6
planted, its `gm/data-register.yaml` beside it, both from the six
domains' register fragments; the loader's coverage checks pass on the
true register.

### 17.5 Existing scenarios

`tarnbeck-outdoor-shop`, `tarnbeck-outdoor-campaign`,
`bookshop-new-server` and `fernway-clinics-monitoring` are re-pinned to
`postgres` 0.5.0, `scheduler` 0.3.0, `bastion` 0.5.0 and `grafana`
0.3.0 where they use them, and each node an exporter targets gains
`options: [monitoring]`. They keep their seeds otherwise: TLS and
pgaudit stay available and unused, since only a seed turns them on.
None lists `domains:`, so none needs a data register; the shop scenario
keeps `domain: shop` and its own classification copy. Each still
deploys and passes its short smoke test; its long-running checks are
v1.0 gating's.

## 18. Testing in v0.5

The owner: "we must restrict testing to short tests (validate that new
bricks/features works simply with minimal environment) we will do a
major test prior taging v1.0, any long running (>30m) will be done
there"; then "i'll accept an exception for deploying the whole clinic on
this milestone", and "yes, two hosts are covered by the exception".

### 18.1 Short tests only

- Every chunk check, wave gate and release-gate item runs **under 30
  minutes**, on the least environment that proves the new brick or
  feature: the nodes it touches and those it cannot run without, never
  the full scenario. A fault is proven on a fixture of its own.
- **Time is placed, never waited for**: a check that needs a nightly or
  periodic job, a base backup, the 16:00 send-outs or a release round
  sets its fixture's T0 just before the job's time, or moves the job as
  a player may; a WAL segment is switched by the test, not waited for an
  hour. No aging: the hand-over follows the load.
- The VPS rules stand for any run that uses it: filetstudio.com stays
  up, the VPS is `active` for the run only and drained after, no node
  that may exhaust its memory is placed there.

### 18.2 The fixtures

Each holds the nodes its checks touch, with the bastion every deployment
has; seven nodes at most beside the bastion, eight with it, every one
fitting one host.

| Fixture | Nodes | T0 | Proves |
|---|---|---|---|
| orders | `records` (`clinic`), `lab`, `clinic-api`, `lab-api`, `pms`, `lis`, `interfaces` | a weekday, 10:00 | s1, s4; the centre's orders round trip |
| archive | `records`, the partners' `api` node and database | any | s2, s6; archiving, the vault's page, the register |
| reports | `records` (`clinic`, `office`), `standby`, `backoffice` | a Friday, 01:20 | s3, s7, s8; the standby, the feeders |
| send-outs | `lab`, `interfaces`, the partners' three nodes | a weekday, 15:50 | fa; the external lab's round trip |
| lab | `lab`, its exporter | any | s10; the options model |
| portal-scope | `records` (`clinic`, `portal`), `portal-api` | a weekday, hours after the planting | s5 |
| housing | `records` (the core and housing), `pms`, `ward` | any, or 10:00 and just before 17:00 | s9; placements, the board, the care log |
| bookings | `records`, `pms`, `interfaces` | a weekday, 09:50 | the exclusion constraints, the slot function, the bookings sync |
| imaging | `records`, `clinic-api`, `pms`, `machines`, `equipment`, `interfaces` | a weekday, 08:50 | the three databases and loads, the imaging round trip |
| vault | `machines`, `equipment`, `interfaces`, the partners' `api` node and database | 21:55 | partitions ahead, the nightly shipping and its receipt |
| portal | `records`, `lab`, `interfaces`, `portal-api`, the partners' three nodes | a weekday | the copies, the release gate, owner scope, accounts, messages |

Beside them, each brick's own short tests: the `api` brick's build
checks on its database side; the HTTP driver against one stub; the
partners' node with one partner slow and another answering; the standby
cloned and streaming; a segment and a base backup reaching the vault;
the options refused and accepted by `gmctl`; `gmctl compose` merging,
overriding, stopping on a conflict and following `merge.yaml`; the
coherence check passing on a composed load and failing on a broken
range; the data register generated, a stale digest refused, a declared
absence passed; each domain's load measured, at shift 0 and a non-zero
shift.

### 18.3 The one exception: the whole clinic, once

The whole clinic deployed once on **armenelos plus the VPS**, every part
built, as the procedure's proof in play for all six domains, for this
milestone only. Its checks:

- the deployment and `fit`;
- a short smoke, **about 30 minutes**, with every producer,
  partner and purpose running and each one's first run read;
- **the test selection planted at once**, **each fault read present
  only**, where it reads within the window: s2, s5,
  s6, s7, s8, s9 and s10 at once (s5 as a planted former owner's visit,
  s6 the handout against the vault's page, s9 the display's excess
  calls); s1 at the first urgent order, if one comes; s3 resting on its
  fixture, since its feeder runs at 02:00. No fault is fixed there;
- **its place: the release gate**, once every part is built;
- no aging, no overnight cadence, no fault taken through its cycle, no
  hand-over snapshot.

### 18.4 Unproven until v1.0 gating

Moved to the major test before the v1.0 tag, and listed in the
roadmap's v1.0 gating so none is lost:

- **the clinic aged and played**: a full aging and a session, the ten
  faults at once through their cycles; the classes as the hand-over
  finds them (s1 already noticed, s2 and s3 on the verge); s5's exposure
  over days of sales; s9 found across a hand-over;
- **the overnight and periodic cadences in scenario time**: the feeders
  at night, the base backups, the 16:00 send-outs, the pathologist's
  rounds, a periodic run placed in the aging; that a planted
  periodic-data fault's witness surfaces within the aging, which v0.5
  proves only on a short fixture;
- **growth and footprints over an aging**: every node's memory, the
  trace's growth, `pg_wal` growing when archiving fails, into the
  bricks' footprints and the scenario's `resources`, `fit` re-run;
  whether a hand-over snapshot is needed and fits;
- **the clinic's rehearsal**: unattended, the early check, a scheduler
  killed and resuming, a restart, on two hosts;
- **the stance check-list**, a GM session played with verifier agents as
  `player`, v0.5's items with v0.3's and v0.4's: a register fault's
  *propose* judged against its diff, a display fault judged on the
  report and never cleared in play, a partner's support never answering,
  an overstep on a third party's node refused;
- the parts' long views: the rota's weekly cycle and a month's close,
  the agenda turning over, a session's certificates, the care log and
  the board's cost over days, the night checks over a night.

## 19. Definition of done

1. `postgres` 0.5.0 (7.1), `scheduler` 0.3.0 and `api` 0.1.0 (7.2),
   `bastion` 0.5.0 (7.3), with GM and player documentation, validators
   and measured footprints; their new packages through the dependency
   checks, the project's technology record up to date.
2. The monitoring breadth (7.4): `pgwatch` 0.1.0 and `health-check`
   0.1.0, pgCluu in `postgres` 0.5.0, `grafana` 0.3.0's pgwatch
   dashboard, with their documentation and measured footprints.
3. The domain format and the rest of section 6 in `formats.md`, the
   templates, the loader and the `scenario-format` skill.
4. `gmctl compose`, the composition record, the coherence check and the
   loader's checks (15).
5. The six clinic domains in `domains/`, each passing the domain
   checklist, with its register fragment, its variant manifest and its
   GM notes ("Core keys used", growth an hour, traps); the shop's
   folder brought to the new format (8.6).
6. The clinic's purposes in `purposes/`, complete by the format skill
   (12.2), `cold-storage-archive` among them.
7. The partners' stubs, cold storage and the vault, `partners.md`'s
   material (10).
8. The `data-register` skill, the GM skill's Setup step 2, the
   scenario-document skill's sections (13, 15).
9. The test selection's ten faults and the false alarm's material, each
   with injection, sealed check and solvability description, each passing
   its short test (17.2, 17.3).
10. The clinic scenario, complete by the format skill, composed and
    recorded, its data policy, `partners.md` and register written, its
    scenario document generated (17).
11. The existing scenarios re-pinned and deploying, every existing
    fault's `applies_to` carrying the new versions (17.5).
12. The release gate of section 20 passed.

## 20. The release gate

No aged run, no long run: v0.5's gate keeps short tests and the one
exception.

1. **Every short test** of 17.3 and 18.2 green on the built versions,
   each under 30 minutes.
2. **The existing scenarios' short smoke tests** on the re-pinned
   versions.
3. **The unfaulted clinic scenario passes the governance checks** and
   the coherence check, and its true register passes the loader's
   coverage checks.
4. **`fit`** on the clinic as built, on armenelos plus the VPS.
5. **The whole clinic deployed once** on armenelos plus the VPS (18.3).
6. **Known limits, named** in the release notes: everything of 18.4.

## 21. For the build plan

- **Brick bumps**: `postgres` 0.5.0, `scheduler` 0.3.0, `api` 0.1.0,
  `bastion` 0.5.0, `pgwatch` 0.1.0, `health-check` 0.1.0, `grafana`
  0.3.0; every change folding into its unreleased version.
- **Re-pins** (17.5): every scenario and fixture to the new versions;
  every fault applying to a bumped brick given its new version.
- **Dependency checks** by the security advisor: FastAPI and uvicorn
  (and the `api` image's other packages) before the `api` chunk;
  pgaudit's package for `postgres` 0.5.0; for the monitoring breadth
  (7.4), pgwatch's latest release, Prometheus as the sink's scraper,
  `check_postgres` and the health node's web server, and pgCluu's
  package, a gate on the monitoring chunk, so each joins `.tech`; each
  as a preflight on the candidate versions and a post-change check on
  the resolved ones, `.tech` updated.
- **The domain-format chunk first**: the format changes, the templates,
  `check_domain_dir`, `gmctl compose`, the composition record and the
  variants, in one chunk, before any domain's chunk.
- **`vet-core` early**: its GM notes' ranges and functions are every
  part's contract; no formula or function name is written in the drafts
  yet, so writing them is the core chunk's first deliverable, before
  the parts' loads.
- **One chunk per domain**, a smaller part half of one; each with its
  register fragment and its fixture.
- **The data register**: the fragments in each domain's chunk; the skill,
  the GM's Setup step 2, the scenario-document section, the loader's
  checks and the bastion's seed files in one chunk, after the domain
  format and the fragments; s6 with the other faults; the clinic
  scenario's register last.
- **The partners**: the shared nodes, the stubs per partner, cold
  storage and the vault, with the `api` brick.
- **The proof in play** last, at the release gate.
- **No data preflight**: the repository keeps no data register, and every
  scenario's data is synthetic.
- **No owner checkpoint for the faults**: the test selection is the
  spec's; a game's faults are the GM's.

## 22. Grounding: what exists and what is at risk

Read on `v0.5-domains` after `main` (v0.4's release, 7fc2477) was merged
into it, and in the drafts' grounding:

- **Bricks today**: `postgres` 0.4.0, `scheduler` 0.2.0, `bastion` 0.4.0,
  `pgbouncer` 0.1.1, `prometheus`, `grafana` and `postgres-exporter`
  0.2.0. No `api` brick. `postgres` declares the `monitoring_password`
  secret for every node; `bastion`'s only optional seed file is
  `data-policy.md`.
- **`no-access` exists in name only**: `WRITE_POLICIES` in
  `tools/gm/model.py` lists it and the loader accepts it on any brick,
  but every brick reads it as `report-only`, the `player` account and
  its wrappers still created.
- **One network** is rendered per game (`tools/gm/localimpl.py`); the
  partners stay on it.
- **The scheduler** has one driver, `sql/postgresql`; a stream holds one
  connection and a builder cannot read; a script holds several
  connections, PostgreSQL ones only, and imports only the standard
  library, psycopg 3 and PyYAML; the timeline switches a stream's key,
  rate or connection, never a job. The ward service's pools need no
  change (`pool: {size: N}`, per-call connections exist).
- **Fragments**: `_check_fragments` checks a fragment's top-level keys
  and queries; nothing checks a merge, and PyYAML keeps the last of two
  equal keys silently.
- **Domains**: `domains/shop/` only; `check_domain_dir` and the
  template carry v0.4's keys; the shop's classification is keyed
  `shop.<table>.<column>`.
- **`fit`** counts reservations plus 10 % headroom per host, disk with
  images, growth and the hand-over snapshot's copies (a warning when
  they do not fit), and refuses a `needs_unshared_host` fault's node on
  a shared host.

At risk of disruption:

- the `postgres` image and start-up (pgaudit, TLS, archiving, the
  standby mode, options), under every scenario;
- the scheduler program (the HTTP driver, script HTTP calls), under
  every scenario with scheduler nodes;
- the loader (domains, composition, the register's checks, options,
  `no-access`), under every scenario; the shop's domain and its
  classification keys;
- the bastion's start-up and page (two more optional files, a proxied
  route to a partner), under every scenario;
- capacity: the clinic uses 74 % to 79 % of the two hosts' CPU, and the
  shared VPS carries seven of its nodes during the one whole run.

## 23. Architectural decisions and their reasoning

- **A procedure before domains**: "the clinic will probably spawn
  multiple such domain"; writing down what goes in and what does not
  showed what defining one costs, and kept topology, faults and story
  out of domains.
- **A core and parts, keys by id without foreign keys**: parts are
  separate systems in a real clinic, and a part must land in the core's
  database or an instance of its own with the same schema; integrity
  across systems becomes an invariant and an orphan a fault vector,
  which is audit surface.
- **Deterministic keys, with the initial load adjudicated**: a part's
  load computing the core's keys keeps each domain loadable alone and
  reproducible; the GM's coherence check catches what formulas get wrong
  before the hand-over, so an incoherence is never handed over as a
  fault. A derivation step only where formulas would duplicate another
  domain's generation (the portal's copies).
- **Scale on three axes, variants as manifests, structure not volume**:
  a size could not tell a village shop from a hypermarket; manifests
  keep one domain's material in one place, and the playground's budget
  holds at every scale.
- **A design-time merge, `gmctl compose`, not a library resolved at
  render**: the scenario folder stays self-sufficient, and since domains
  never bump, a catalogue change can never alter a released scenario.
- **One centre per scenario, the rest third parties**: the owner's
  ruling; it keeps one centre's record whole and the exchanges as round
  trips, at a capacity two hosts hold.
- **Third parties out of reach, on one network**: a fault the players
  cannot reach is unsolvable, so partners carry only behaviour at their
  interface and every fix is the customer's; one network keeps
  rendering unchanged, the back end closed by its own access rules as a
  real lab's database is.
- **Partners grouped on three shared nodes**: eleven partner nodes would
  cost more than the clinic's CPU allows; hostnames keep them distinct
  to the players, and per-partner keys keep one partner's fault from
  spreading to all.
- **An `api` node only answers**: "API layer isn't a scheduler"; callers
  live on scheduler nodes, whose hidden schedules drive every flow, and
  the players edit an endpoint's database side only, never its contract.
- **Round trips a purpose kind, cascades judged end to end**: an answer
  that starts processes needs correlation, a timeout and reactions;
  fixing a symptom alone earns nothing, and the backlog left is a
  consequence to credit, not a fault.
- **Periodic reports planted, never run on demand**: real time cannot
  age a month; past periods are planted and a daily feeder is the
  witness, and on-demand runs wait for an instance spawned for them.
- **Cold storage out of the game, shown minimally**: heavy continuous
  data would outgrow the playground; a day on site and a manifest page
  keep it auditable at the scale of an aging, use first, volume second.
- **A standby, an archive and a back-office database, plain PostgreSQL
  tools**: redundancy the owner asked for, auditable with the catalogue's
  knowledge; restores need a vault that keeps data, later.
- **TLS and pgaudit always available, not options**: their settings live
  in the seed, so their absence can be a fault; only the `monitoring`
  role became an option, with one image.
- **The data register a generated handout, its faults in the handout
  only**: generated from the ground truth it cannot drift by accident, so
  any drift is a planted fault; the players read the system against it,
  and propose the correction.
- **Short tests, one whole run**: the owner's rule; every brick and
  feature proven on the least environment, the whole clinic deployed
  once to show the parts work together, and everything long kept for the
  major test before v1.0.

## 24. Deferred items, open questions and points left to the build

**Deferred**: as section 2 lists (other domains and variants, billing
beyond the lab, appointment reminders, on-demand reports, restores and
backup tooling, other engines and options, queues, separate networks, a
partner status page and the reporting tool, the undersized transformer,
scenario generation, datasets, the post-mortems' binding, every long
test).

**The domains' other traps**: about 229 across the clinic, each with
where it bites, its witness and its class, in the domain documents and
the trap catalogue; v0.5 builds the test selection's ten only. Among
those once picked and swapped out: a natural identifier copied into the
send-outs (adapting v0.4's personal-copied fault), the lab API's
idempotency lookup unindexed, the critical calls' watch run as
superuser, no partition created ahead on the machines' readings.

**Open questions carried**, the owner's:

- Binding the post-mortems to faults (later, version not set).
- Network-level faults and separate networks (later).
- Backup tooling's version (soon, on the roadmap).
- A definer procedure judged by who may execute it, beside its owner
  (later, with the open `SECURITY DEFINER` candidate fault).
- The setup's common entry point and the reporting tool (v0.6).

**Left to the build**, to settle without changing behaviour:

- every footprint, the new nodes' starting sizes, each domain's load
  time and size, by measurement;
- the core's id functions written into its GM notes (names, formulas),
  and the referring vets' mapping to practices;
- the repository form of an HTTP call (a key with a method, a path and a
  body from parameters or a builder) and the scripts' HTTP client
  (standard library preferred, any package through a dependency check);
- where a purpose's `history.sql` and endpoint material sit beside v0.4's
  per-part material folders;
- `producers/partners/<name>/` or `producers/public/<name>/` for the
  owners' traffic;
- the `api` brick's internal layout: `db/` its one writable path, routes
  importing only from `db/` (as drafted);
- how the partners' `pg_hba.conf` admits only their own nodes on one
  Swarm network;
- the portal outbox's id order across the load and the derivation;
- the booking horizon against sessions planned three months ahead;
- the timeline moments of each fault within a fixture, each before its
  test's reading;
- a part's schema creating a contrib extension (`btree_gist`,
  `pgcrypto`), run as `postgres` by `load-data`.
