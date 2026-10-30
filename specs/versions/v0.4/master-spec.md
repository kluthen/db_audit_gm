# db_audit_gm v0.4 — Master specification

Status: **approved by the owner on 2026-10-30.** Consolidated from
v0.4's eight draft documents and the owner's rulings of 2026-10-28 and
2026-10-30, and approved with every proposal as written. Companion:
[access-model.md](access-model.md). Baseline: the released
[v0.3 master spec](../v0.3/master-spec.md) and its
[access model](../v0.3/access-model.md). Everything v0.3 specifies stays
in force unless this document changes it; where they disagree, this
document wins for v0.4. Its [build plan](build-plan.md) carries
section 19.

---

## 1. Concept and objective

db_audit_gm generates live database audit exercises: an agent, the game
master (GM), deploys a deliberately flawed data stack on a container
cluster, hands it to students (the players) through a single bastion,
receives their report and gives teacher-style feedback. v0.1 settled the
GM's stance on one static PostgreSQL database, v0.2 added monitoring and
the usual tooling, v0.3 made the stack alive with producers and
consumers aging it in real time.

v0.4 is about **what the customer's data is for**. In the owner's
words: "what i expect from this step is to elaborate side usage and
transformations. Likely, BI settings (capturing daily information
production, transforming it into leads, etc), computation of reports,
mailing, etc. These bricks will mostly be about purpose more than
anything": "bricks of why and bits of hows more than true tech bricks".
Concretely:

- a new catalogue artefact, the **purpose**: its jobs, the trace they
  leave, the invariants that must hold between the trace and the source,
  and the faults that break them (section 8);
- **consumers modelled by their trace**: no mailer, no BI tool, no
  finance application; a consumer exists through the rows, results and
  definitions it leaves behind;
- four purposes on one business, the shop: sales reporting, win-back
  leads, customer mailing, and export declarations, a pushed obligation
  with a deadline and an acknowledgement (section 10);
- the shop's business data model as the first **domain**, a reusable
  catalogue unit later versions add to (section 9);
- **several PostgreSQL instances** in a scenario, data moved between them
  mainly by Python **transformer scripts** the extended scheduler runs,
  and also by SQL through `postgres_fdw` or stored procedures
  (sections 7.1, 8.6);
- **jobs on a database node**: `pg_cron` and a cron daemon beside
  PostgreSQL (section 7.2);
- a **first cut of data governance**: the customer's data classes, where
  each may live, who may read it and where it may flow, handed to the
  players as the company's data policy and checked against the live
  system (section 11);
- one new scenario of normal difficulty and ten new catalogue faults,
  among them a real out-of-memory incident on a database node, recovered
  from before the players arrive (section 16).

## 2. Scope

### In scope

- The purpose as a catalogue artefact: its format, template and
  completeness rules (6.7, 8).
- Four purposes on the shop: sales reporting, win-back leads, customer
  mailing, export declarations (10).
- `scheduler` 0.2.0: transformer scripts and the `transformer` role
  (7.1).
- `postgres` 0.4.0: `pg_cron` and a cron daemon, each optional per node;
  the out-of-memory victim set to a backend; the check helper reaching
  another instance (7.2).
- Several PostgreSQL instances per scenario, the reporting database an
  instance of its own; data moved between instances by transformer
  scripts, or by SQL or stored procedures over `postgres_fdw` (8.6, 13).
- Nodes sized by role: each producer on a small node of its own,
  transformers larger where volume needs it (13.2).
- The placement guideline for jobs (8.7), and a node needing an unshared
  host kept off shared hosts by `fit` (13.3).
- The shop as the first domain, structured so that more can be added
  (6.8, 9).
- Faults attached to purposes, and their checks over the trace (12).
- Data governance's first cut: data classes, their allowed locations,
  readers and outbound flows, the policy handed to the players, and the
  checks of the rules a check can verify (11).
- The format changes (6), the script changes (14), the GM and format
  skills' updates (14).
- One new scenario and ten new catalogue faults; the existing scenarios
  re-pinned (16).

### Out of scope (deferred, still part of the project)

- Real consumer software: a mailer, a BI tool, a dashboard application,
  a finance application, a mail sink. The mail outbox is the mail's
  whole trace; a purpose needing delivery behaviour (bounces) raises a
  new question.
- Technology bricks for their own sake, dbt among them.
- Database engines other than PostgreSQL: no v0.4 purpose needs one at
  "schemas simple, tables small"; they stay beyond v1.0.
- Finance reconciliation, the fifth purpose drafted: held for v0.5 with
  the domains, since it needs payments, refunds, invoices and accounting
  periods, about as much data-model work again, and runs daily and
  monthly, the cadences real time serves worst (10.5).
- Weekly and monthly purposes; a sped-up clock, a forged history, time
  compression.
- Round trips, an acknowledgement as an inbound flow that the system
  waits on and that drives further processes: v0.5. v0.4 records and
  checks acknowledgements and opens an incident, nothing more.
- Domains other than the shop, domain composition, producer profiles
  against the schedule, scenario size: v0.5.
- Governance rules beyond classification, locations, readers and flows:
  required settings, audit trails (pgaudit), TLS, retention, statement
  logging that writes personal data into the logs. They grow with v0.5's
  regulated domains.
- systemd timers on a database node: with the virtual-machine nodes of
  the fictional cloud provider, after v1.0.
- An undersized transformer as a fault: v0.5's catalogue and the
  capacity family after v1.0; until players may resize a node it can
  only be reported.
- Brick options (`options:` on a node): v0.5. `pg_cron` and the cron
  daemon ship in every `postgres` image and are turned on by the
  scenario's seed.
- The drafts' other candidate faults: recorded for later versions
  (16.2, 22).
- A report-only write policy for database nodes: `postgres` stays
  fixable only; a database node another party owns in the story is
  report-only by the answer key and the story (16.5).

## 3. Actors

Unchanged from v0.3: the initiator, the players, anyone in the GM
session, the GM, and the unauthenticated network visitor. v0.4 gives the
players a second database instance to reach, transformer scripts and
jobs on database nodes to read, and the company's data policy to audit.
The GM check role gains reads (the other instances, `pg_cron`'s tables,
user mappings' remote roles). The customer's own database roles are part
of the game's world, which the players audit; they are not actors. The
full rules are in the access model.

## 4. Glossary (additions and changes)

| Term | Meaning |
|---|---|
| Purpose | A catalogue unit stating what some of the customer's data is for: its jobs, the trace they leave, the invariants between the trace and the source, the faults that break them |
| Job (of a purpose) | A scheduled operation of a purpose: its source, its target, what it computes, when it runs, by which method |
| Trace | What a purpose leaves behind: outbox rows, published results, a run ledger, definitions |
| Invariant | A statement over a purpose's trace against its source that must hold for every run, judged by a sealed check |
| Witness condition | What must exist in the data for a run to be able to violate an invariant; a clean run proves a fix only if it was a witness |
| Judged moment | The moment a purpose check judges runs or triggers from: the hand-over by default, raised to the runner's last reload or by the GM |
| Pushed obligation | A purpose kind: an event in the data that creates a duty to send something to an outside receiver by a deadline, answered by an acknowledgement |
| Trigger | A source row creating a pushed obligation |
| Transformer script | A Python function in a scheduler node's repository that a job calls with several open connections |
| Transformer | A scheduler node whose role is `transformer`: it runs purpose jobs |
| Domain | A reusable catalogue unit of a business: its data model, its producer material, its classification, its GM notes; the shop is the first |
| Data class | The customer's classification of a column: `personal`, `customer-linked`, `internal` |
| Data policy | The customer's rules for its classes (locations, readers, outbound flows), handed to the players as a document |
| Location | Where a class may live, written `node/database` |
| Database-node job | A job run on a database node itself, by `pg_cron` or by the cron daemon beside PostgreSQL |
| Host (restated) | A machine of the swarm. A **node** is always a scenario node |
| Shared host | A host the playground declares as shared with other applications |

## 5. Repository changes

```
bricks/
  scheduler/            0.2.0: transformer scripts, the transformer role
  postgres/             0.4.0: pg_cron, the cron daemon, the OOM victim,
                        check-psql reaching another instance
purposes/<purpose-id>/  new: the four purposes (6.7)
domains/shop/           new: the shop domain (6.8)
faults/<fault-id>/      ten new faults; every fault applying to `postgres`
                        or `scheduler` lists the new versions
scenarios/<new-id>/     the v0.4 scenario
scenarios/tarnbeck-outdoor-shop/, bookshop-new-server/, fernway-clinics-monitoring/
                        re-pinned, otherwise unchanged
.claude/skills/scenario-format/    templates and checks for section 6, the
                                   placement guideline
.claude/skills/scenario-document/  purposes, governance, the policy,
                                   database-node jobs in the document
.claude/skills/game-master/        purposes, the judged moment, the policy,
                                   the incident fault
tools/                  the script changes of section 14
specs/formats.md        the purpose, the domain, governance, the new fields
```

## 6. Format changes

The cross-version [formats.md](../../formats.md) states the rules for
every version; this section lists what v0.4 changes. The shapes are in
6.9; they are normative until the format skill's templates carry them.

### 6.1 Scenario (`scenario.yaml`)

- **`purposes:`**: each purpose used, by id, mapping its parts to the
  scenario's nodes and databases (6.7). The loader checks every part is
  mapped and every job's key and name exist on the mapped runner.
- **`domain:`**: the domain the scenario's business comes from, for
  provenance (`shop`). A static scenario needs none.
- **`governance:`**: the policy file, and for each class its locations,
  readers and outbound flows (11.3). The loader checks every class named
  is defined, every location names a `database` node and a database its
  data file creates, every reader is a role a data file creates, and the
  policy file exists.
- **Several `postgres` nodes**: each its own instance, its own seed and
  data file (13.1).
- **A `postgres` node's cron daemon**: on when the node seeds `crontab`;
  the node then names the customer roles its crontab connects as
  (`crontab_roles:`), whose password secrets deployment mounts into it
  (7.2).
- **Every scheduler node** of a v0.4 scenario runs `scheduler` 0.2.0, a
  transformer with role `transformer`.

### 6.2 Answer key (`gm/answer-key.yaml`)

- A sealed check judging a purpose's runs or triggers states `judges:
  runs` or `judges: triggers` and a `threshold` (violations tolerated, 0
  by default), and no window (12).
- A tooling expectation may name an unmonitored instance (13.4).

### 6.3 Fault definition (`fault.yaml`)

- **`applies_to.purposes`**: the purposes a fault attaches to, beside
  `bricks:`. A purpose fault also lists the `scheduler` versions its
  runner needs, since its sealed check runs there.
- **`sealed_check.judges`**: `runs`, `triggers`, or absent for a check
  judging the live state, as in v0.3 (12).
- **`needs_unshared_host: true`**: the fault's node must never be placed
  on a shared host; `fit` refuses a mapping that does (13.3).
- Purpose faults are planted as v0.3's are: a `seed-file` change at
  render (a runner's `queries.yaml`, a script, `jobs.yaml`, a database
  node's data file, `postgresql.conf` or `crontab`), a `state` change
  during the aging, or a timeline change of a schedule for an outside
  party's behaviour.
- Families: purpose faults are `data-flow` (duplicates, dropped
  records) or `rules` (a wrong zone, a wrong segment); governance and
  credential faults join `security` (`governance-*` and `security-*`
  ids).
- A fault whose evidence shows at a job's runs counts its aging minimum
  from that job's first run after planting, as v0.3's time-of-day faults
  do.

### 6.4 Brick definition (`brick.yaml`)

- **`seed.optional`**: seed files a node may omit. Every seed file was
  required until now; `crontab` is the first optional one (7.2).
- `postgres` keeps the `fixable` write policy only (16.5).
- `scheduler` declares the `transformer` role (7.1).

### 6.5 Script contracts

- A sealed check judging runs or triggers receives `CHECK_SINCE`, the
  judged moment as a UTC timestamp (12.1). Exit codes are v0.3's: 0
  fixed, 1 present, 3 too soon to tell with `remaining=<s>` on the first
  line, anything else an error.
- A check comparing two instances reaches each as the GM check role:
  from a scheduler node through `check-sql`, from a database node
  through `check-psql` with the other node's name (7.2).

### 6.6 Versions and pins

The rules are unchanged: any change bumps a brick; faults, scenarios,
purposes and domains never bump; a brick version is released when v0.4's
release gate passes; changes to an unreleased version fold into it. The
repository holds one definition per brick and a pin must match it, so:

- every scenario with a `postgres` node pins 0.4.0: the new one,
  `tarnbeck-outdoor-shop`, `bookshop-new-server` and
  `fernway-clinics-monitoring`;
- every scenario with a scheduler node pins `scheduler` 0.2.0: the new
  one and `tarnbeck-outdoor-shop`;
- every fault applying to `postgres` adds 0.4.0, and every fault applying
  to `scheduler` adds 0.2.0, to `applies_to`.

Nothing changes in a scenario that turns neither `pg_cron` nor the cron
daemon on and uses no script: the packages sit idle, the `cron` service
stays down, v0.3's jobs run as before.

### 6.7 The purpose definition

A purpose is a catalogue unit beside bricks, faults and scenarios. Its
name stays "purpose": it says what the data is *for*, which is the
milestone's point, and collides with no existing term.

```
purposes/<purpose-id>/
  purpose.yaml   identity, parts, jobs, trace, invariants, data moved, roles
  material/      the jobs' repository entries, transformer scripts and
                 jobs.yaml lines, the target's DDL (foreign servers and
                 procedures included), as the GM copies them into a scenario
  checks/        one script per invariant
  gm.md          what the purpose is for, how it goes wrong, feedback notes
```

`purpose.yaml` must contain:

- **Identity**: id, title, the domains it fits (`shop`), its kind
  (pulled, transformed in place, pushed, pushed obligation; 8.2).
- **Parts**: the roles the scenario fills with its own nodes and
  databases: `source` and `target` (databases), `runner` (a scheduler
  node, role `transformer`), optionally `consumer` (a scheduler node
  reading published results) and `receiver` (a stub node, for a pushed
  obligation). Source and target may be databases of one instance or of
  two.
- **Jobs**: for each, its name, its repository key, its part (which
  runner), its source and target, its movement method (8.6), what it
  computes in one sentence, its cadence in scenario time, and the
  customer role of each connection it holds.
- **Trace**: each place it leaves something, with its kind (outbox
  rows, published results, run ledger, definitions), its table or file,
  and the column that ties a row to the run that wrote it.
- **Invariants**: for each, an id, a one-sentence statement against the
  source, the check script judging it, its parameters, and its witness
  condition (12.3).
- **Data moved**: which classed columns each job reads and where it
  writes them, so governance can be checked against it.
- **Customer roles** the purpose needs, with their grants.

**How a scenario uses one.** The GM copies the purpose's material into
the scenario at design time, as it writes a scheduler's repository
today: the jobs into the runner's `queries.yaml`, `scripts/` and
`jobs.yaml`, the target's DDL into the target node's data file. The
scenario folder stays self-sufficient. Since the material is copied, a
purpose never bumps; `purposes:` names it for provenance and for the
faults attached to it.

The four purpose ids are `shop-sales-reporting`, `shop-winback-leads`,
`shop-customer-mailing` and `shop-export-declarations`; this document
calls them P1, P2, P3 and P5 (P4, finance, is held).

### 6.8 The domain

The least that keeps v0.5 from restructuring the shop:

```
domains/shop/
  domain.yaml           identity, the parts below, the purposes that fit
  data/
    schema.sql          the business tables, roles and grants
    load.sql            the generated history ("last night's backup")
    classification.yaml every classed column (11.3)
  producers/            the web shop's repository and schedule fragments
  docs/gm.md            the business, its rules, its traps
```

- A **design-time source**: the GM copies a domain's files into the
  scenario, adapting them; `scenario.yaml` names the domain for
  provenance; a domain never bumps.
- **Static scenarios** need no domain.
- The domain is derived from `tarnbeck-outdoor-shop`'s data file;
  tarnbeck keeps its own, re-pinned and otherwise unchanged.
- How producer material meets a schedule, what a scenario's size
  scales, and whether a domain may be composed of smaller ones are
  v0.5's.

### 6.9 Shapes of the new fields

```yaml
# scenario.yaml
domain: shop                              # provenance only
purposes:
  - id: shop-sales-reporting
    parts:
      source: db/shop                     # node/database
      target: reporting/reporting
      runner: bi
      consumer: consumer
governance:
  policy: player/data-policy.md
  classes:
    personal:
      locations: [db/shop]
      readers: [shop_app, shop_reports, shop_crm, shop_customs, customs_gw]
      outbound:
        - to: mail-provider               # mail_outbox
          fields: [email, name, order]
        - to: customs-gateway             # customs_outbox
          fields: [consignee_name, consignee_address, country]
    customer-linked:
      locations: [db/shop]
      readers: [shop_app, shop_reports, shop_crm, shop_customs]
    internal:
      locations: any
nodes:
  - name: db
    brick: {id: postgres, version: 0.4.0}
    role: database
    crontab_roles: [shop_refresh]         # with a seeded crontab only
  - name: reporting
    brick: {id: postgres, version: 0.4.0}
    role: database                        # fixable: the agency's by the story only (16.5)
    crontab_roles: [bi_etl]

# fault.yaml
applies_to:
  bricks:
    - {id: scheduler, versions: [0.2.0]}
  purposes: [shop-customer-mailing]
sealed_check:
  judges: runs                            # runs | triggers | absent
needs_unshared_host: true                 # the out-of-memory incident only

# answer-key.yaml, a fault instance's check
sealed_check:
  judges: runs
  threshold: 0

# brick.yaml (postgres)
seed:
  optional: [crontab]
```

A class may add `separation: instance` when the policy demands an
instance of its own; the check then verifies it by node (11.4).

## 7. The bricks

### 7.1 `scheduler` 0.2.0

**Extended, not forked.** In the owner's words: "independent python
script with a scheduler (so we may probably reuse the scheduling block
we have already, just attach the script in there)". A purpose's jobs are
fixed-time operations in a scheduler node's `jobs.yaml`, run as v0.3
runs them; what is new is the **transformer script**, a Python function
attached to the node's repository, which may hold several connections.

| Need | Change |
|---|---|
| Jobs on a node with no stream | none: `streams` may already be empty |
| A job moving rows between instances | a transformer script: a fifth repository form and a job naming several connections |
| The `transformer` role | added to `brick.yaml`'s roles; the loader already lists it |
| A SQL job through `postgres_fdw`, or calling a procedure | none: one statement on one connection, as today |
| A run's start, end, rows, status | none: a script's run logs the same lines |
| When the runner's files last changed | none: the `reload status=ok` lines and `/run/scheduler/loaded`, which gains the scripts' digests |

**The transformer script contract**:

- **Where it lives**: `scripts/<file>.py` in the repository
  (`/srv/scheduler/repository/scripts/`), seeded once, read by the
  players and fixable where the repository is, as `builders/` are. A new
  optional seed entry `scripts/`.
- **The repository entry**: `{script: scripts/<file>:<function>,
  options: {…}}`, beside the query, pool, sequence and builder forms. A
  script key runs only as a job; the loader refuses a stream naming one.
- **The job**: a script key's job names `connections: {<name>:
  <connection>, …}` instead of `connection:`, each a connection of the
  schedule; `source` and `target` by convention. The loader and the
  program check every name exists, as they check `connection:` today.
- **The call**: `<function>(conns, options, log)`. `conns` maps each
  name to an open psycopg connection as the schedule's role for it,
  autocommit off; the script commits what it means to commit and returns
  the number of rows it wrote. `log(text)` appends a `script job=<name>
  <text>` line to the scheduler log.
- **No password in a script.** The runner opens and closes the
  connections from the schedule, which the players never see.
- **Its run**: in a worker thread of the program; the next run is
  skipped while one is going, as for every job. An exception ends the run
  with `status=error` (`sqlstate=<code>` for a database error,
  `error=<class>` otherwise); nothing else stops. A script exhausting its
  node's memory takes the program down with it and s6 restarts it: why a
  transformer sits on a node of its own.
- **What it may import**: the standard library, psycopg 3 and PyYAML,
  which the image already has. Anything more is an image change with its
  dependency check.
- **PostgreSQL only**: a script talks psycopg, outside the driver
  interface; later targets stay drivers.

**What the players reach** is v0.3's: they read the repository, the
scripts, `jobs.yaml` and the log, edit them where the scenario allows,
move a job's time, and never see `schedule.yaml`. Moving a job is how
they verify a fix to it, and the starter pack says so for every job they
may edit. A fixable script sits on the trust line a fixable builder sits
on, with live connections beside: the access model's known gaps.

**Footprint** unchanged by default; a scenario sizes each node by role
(13.2).

### 7.2 `postgres` 0.4.0

| Part | Change |
|---|---|
| Image | `postgresql-18-cron` from the PostgreSQL apt repository; Debian's `cron`, installed without recommends (so no mail transfer agent); both idle unless used |
| `pg_cron` | turned on by the scenario: the seed preloads it, the data file creates it |
| Cron daemon | an s6 longrun `cron`; the optional seed file `crontab`; a volume `cronspool`; the sudo wrapper `gm-crontab`; a password file for the crontab's roles |
| Out-of-memory victim | the run script exports `PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj` and `PG_OOM_ADJUST_VALUE=300`: each backend raises its own score, so the kernel kills a backend before the postmaster, s6, `sshd` or `cron` |
| `check-psql` | takes another database node's name to reach that instance as the GM check role over the game network |
| Documentation | a section each in `docs/player.md` and `docs/gm.md` for `pg_cron` and the cron daemon: what it is, how a scenario turns it on, its cost, the faults it allows |
| Footprint | the default unchanged: the `pg_cron` launcher is one background worker, `cron` a few MB; measured at the rehearsal |

**`pg_cron`.**

- Settings in the seed `postgresql.conf`: `shared_preload_libraries`
  gains `pg_cron`; `cron.database_name` names the database holding its
  metadata; `cron.use_background_workers = on`, so a job runs as its
  role with no password and no `pg_hba.conf` line; `cron.timezone` is
  `{{customer_timezone}}`, filled by render (8.5). At most eight jobs run
  at once under the default `max_worker_processes`, which a scenario
  raises if it needs more.
- The data file, the restored backup, creates the extension in
  `cron.database_name` as superuser and schedules each job with
  `cron.schedule_in_database(…, username => <role>)`. Jobs are rows, so
  the backup carries them, and the hand-over snapshot with them.
- The loader checks that a data file creating `pg_cron` belongs to a node
  whose seed preloads it, and that `cron.database_name` names a database
  that data file creates. A fault may still remove the preload.
- `cron.job` and `cron.job_run_details` show each role its own jobs
  only, unless it is a superuser or bypasses row-level security. The
  players' `dba` sees every job. `load-data` gives the GM check role a
  read policy on both tables where the extension exists, narrower than
  `BYPASSRLS` (14).
- Its trace: `cron.job_run_details` (start, end, status, message) while
  `cron.log_run` is on, and a log line per statement while
  `cron.log_statement` is on.

**The cron daemon.**

- Debian's `cron`: apt-verified from the image's own distribution, and
  what an administrator meets on a Debian database host. Rejected:
  supercronic (a separate binary to pin and check outside Debian, which
  `crontab` does not drive) and busybox `crond` (it runs a crontab as the
  user its file is named after, unsafe if its directory ever became
  writable by players).
- A third s6 longrun beside `postgres` and `sshd`, running `cron -f`,
  started after `postgres`. When the node seeds no `crontab`, its run
  script marks the service down and exits: no daemon runs.
- Shutdown stops `cron` (SIGTERM) before `postgres` (fast shutdown); a
  job running then is not waited for, and is a failed run, as on a host.
  The hand-over snapshot never stops `cron`.
- The crontab is `postgres`'s, in the spool on the volume `cronspool`
  (snapshot `copy`), installed once from the seed, so a player's
  replacement survives a restart. The daemon runs as root and switches
  to `postgres` for its jobs. Debian's default lets OS user `postgres`
  run `crontab` too, which the players' `dba` reaches through programs
  run as `postgres`; that changes the same crontab `gm-crontab` does,
  on a node the players may change anyway, so it is left as it is.
- `gm-crontab -l` lists the crontab; `gm-crontab <file>` installs a
  replacement, read by cron within the minute. Every database node is
  fixable, so both work on every node with a cron daemon.
- Connections go over the local socket. As `postgres` by peer an entry
  is a superuser, which is a fault. The baseline connects as a customer
  role: `gm-entrypoint` writes the passwords of the node's
  `crontab_roles` (their `role_<role>_password` secrets, mounted by
  deployment) into a password file only OS user `postgres` reads, named
  by `PGPASSFILE` in the crontab. No entry holds a password.
- No mail transfer agent and no syslog: cron's lines and a job's output
  go nowhere unless the entry redirects them. The baseline appends to a
  log under `/var/log/postgresql/cron/` on `pglog`, readable by the
  players' group.
- Cron reads the node's clock, UTC: render shifts each entry's hours from
  scenario time, as it shifts `jobs.yaml` (8.5).
- A job shares the container's memory limit with PostgreSQL, so a heavy
  one can exhaust it (16.3).
- No new escalation: whatever a crontab runs as OS user `postgres`, the
  players' `dba` can already run.

**What players see** of either kind of job:

| | `pg_cron` | Cron daemon |
|---|---|---|
| That it exists | the preload in `postgresql.conf`; `\dx` | `cron` in `ps`; the brick's player documentation |
| The jobs | `cron.job` as `dba` | `sudo gm-crontab -l` |
| The runs | `cron.job_run_details`; `cron.log_statement` lines in the log and pgBadger | the job's own log, if its entry writes one |
| Fixing | `cron.unschedule`, `cron.alter_job`, the settings | `sudo gm-crontab <file>` |

On a database node the story gives another party, the agency's
`reporting`, the same works; the issues ask for reports or proposals
there (16.5).

Neither appears in a runner's `jobs.yaml`. The starter pack names
neither unless the story does: a job nobody lists is a finding.

**How a node enables each.** `pg_cron` is on when the seed preloads it
and the data file creates it, as `pg_stat_statements` is today. The cron
daemon is on when the node seeds `crontab`. There is no `options:` key;
v0.5's options model takes both as its first options.

**The out-of-memory victim.** The kernel's out-of-memory killer picks
the process of the container's cgroup with the highest score: its
memory plus `oom_score_adj` in thousandths of the cgroup's limit. A
process may raise its own score without a capability; lowering one
needs `CAP_SYS_RESOURCE`, which the brick does not get. With every
backend at +300, a backend outranks any process at 0 unless that
process holds 30 % of the limit more: among backends the largest dies.
This changes nothing in a game where memory never runs out.

**No report-only write policy.** `postgres` stays fixable only, as in
v0.3. A policy could have protected the node's files and wrappers but
never its contents against the superuser `dba`; the owner chose to rest
another party's database on the story and the answer key instead
(16.5).

**Unchanged, relied on**: the container survives PostgreSQL (s6 is PID 1
and restarts a dead postmaster; the health check needs only `sshd` once
PostgreSQL has accepted connections), so recovery from a killed backend
happens in place, with no Swarm replacement.

### 7.3 The other bricks

Unchanged: `pgbouncer` 0.1.0, `prometheus`, `postgres-exporter` and
`grafana` 0.2.0, `bastion` 0.3.0. The bastion's password file already
holds `dba`'s password for any host, so the players reach a second
instance with `psql -h <node>`.

## 8. Purposes

### 8.1 What a purpose is

A purpose is its jobs, the trace they leave, the invariants that must
hold between the trace and the source, and the faults that break them.
Its jobs are run by a generic job runner, the scheduler (7.1), and
sometimes from a database node (7.2): the "bits of how". Faults attach
to purposes as well as to bricks.

### 8.2 Kinds

| Kind | What | v0.4's instance |
|---|---|---|
| Pulled | results published for readers who query them when they like | P1 sales reporting |
| Transformed in place | the source's own data turned into another table of it | P2 win-back leads |
| Pushed | something sent out, owing nobody anything, with no answer | P3 customer mailing |
| Pushed obligation | an event in the data creating a duty to send something to an outside receiver by a deadline, which answers with an acknowledgement | P5 export declarations |

A pushed obligation has a **trigger** (a source row matching a rule),
a **deadline** counted from it, an **outside receiver** the company does
not run, and an **acknowledgement** from the receiver, or an escalation
when none comes. It is the consumer the trace models best: everything it
owes is checkable in the outbox, the acknowledgements and the triggers.
The owner singled it out, from the veterinary clinic's notifiable
disease reports: "a really good not really consummer (it's on the output
of the system, but need to be pushed, quite different from our usual
consumer)". The clinic is v0.5's; v0.4 uses the shop's instance.

### 8.3 Consumers are modelled by their trace

There is no mailer, BI tool or finance application. In the owner's
words: "mailing is but a specific consummer in a way. we may not need a
complete mailer in the end", and the "same with dashboards and more
admin / finance oriented side of a business".

| Trace kind | Examples |
|---|---|
| Outbox rows | mail, declarations |
| Published results | KPI tables, period figures, leads |
| Run ledger | `etl_runs` rows, the scheduler's run lines, `cron.job_run_details` |
| Definitions | a dashboard's query, a job's configuration, a copied table |

Definitions are checked like v0.3's configuration faults, on the live
state.

### 8.4 Cadence under real time

No sped-up clock, no forged history, no time compression; nobody
triggers a job during a game, not even for the final checks.

1. **Each purpose runs at the cadence a real business would give it,
   chosen sub-daily where a business would**: transactional mail every
   five minutes, a campaign batch every quarter hour in its sending
   hours, lead extraction hourly, an hourly incremental reporting load.
   These run many times in a four-hour game, so a fix shows within it.
2. **A daily job stays daily** where the business closes a day (the
   reporting close at 01:30). Its fix is verified by moving its time, as
   players may move fixed-time operations; a smoke test does the same.
3. **No weekly or monthly purpose** in v0.4: a monthly close cannot run
   inside a game, and moving it proves a single run.
4. **Past trace in the restored backup.** The data file is "last
   night's backup" and may hold a purpose's past trace computed
   consistently with its rules, but **a fault's evidence never rests on
   it alone**: it is produced live during the aging, and its aging
   minimum counts from that.
5. **A pushed obligation with frequent triggers** fits real time well:
   a fix shows within minutes whatever the deadline's length, as long as
   triggers are frequent and the deadline is short or the dispatch
   frequent (12.4). Shortening a legal deadline in the story is a story
   choice, not a clock change.

### 8.5 The customer's time zone in the data

Purposes reason in local time: a business day, a recipient's sending
hours. The customer's time zone is UTC plus the game's shift, known only
at render, and UTC itself at a shift of 0.

- `render` substitutes `{{customer_timezone}}` (as `Etc/GMT∓N`) in the
  scheduler nodes' seed files and in a `postgres` node's seed
  `postgresql.conf` (`cron.timezone`), as it does in the starter pack.
  `pg_cron` schedules are therefore written in scenario time, unshifted.
- `render` shifts a seeded `crontab`'s hour fields from scenario time to
  UTC, as it shifts `jobs.yaml`.
- `load-data` passes the zone and its offset to `psql` as variables
  (`-v customer_timezone=… -v customer_utc_offset=…`), which the data
  file writes into `business_settings`.
- Databases stay in UTC; logs and clocks are untouched.
- **Shift invariance**: no fault may vanish at a shift of 0. Recipients'
  zones are stored as fixed offsets relative to the customer's (computed
  at load: the customer's offset plus a designed delta), and a
  day-boundary fault takes its wrong zone as an offset from the
  customer's, never 0, as v0.3's wrong-time-zone fault does. No fault
  relies on `cron.timezone`'s default, GMT, which is right at a shift of
  0.

Rejected: `ALTER DATABASE … SET timezone` to the customer's zone, which
changes every session's `current_date` and the reading of the logs.

### 8.6 Moving data between instances

PostgreSQL cannot query across databases, even within one instance,
without an extension. A scenario picks per flow among these methods,
each an audit surface of its own:

| Method | Runs from | Audit surface it brings |
|---|---|---|
| **A transformer script** (the main way) | a transformer's job | the script's code; the roles of its connections, which no catalog shows; non-atomic writes across two connections; errors swallowed into a clean-looking run |
| **SQL through foreign tables** (`postgres_fdw`) | a producer's key, a transformer's job or script, a job on a database node | the foreign server and its owner; user mappings holding passwords, a mapping for `PUBLIC`; the remote role's reach; imported foreign tables |
| **A stored procedure** doing either SQL movement | called from the same places | `SECURITY DEFINER` and its owner, `search_path`, `EXECUTE` left to `PUBLIC` |
| **A `pg_cron` job** on a database node | `cron.job`, run as its `username` | a job no runner lists; its `username` (a superuser by default when the superuser schedules it); its database; `cron.timezone`; `cron.log_run` |
| **A cron daemon's entry** on a database node | `postgres`'s crontab | a job no runner lists; the role it connects as (`postgres` by peer is a superuser); credentials or a stale target in the entry; output lost |

`postgres_fdw` ships in the server package the brick installs; the data
file creates it as superuser. Where a scenario uses it, `load-data` sets
each user mapping's password from its remote role's secret (14).

### 8.7 Where a job runs

The owner: "instinctually i'm not convinced having heavy transformation
on the same node as a receiving database to be a good move. for low
computation stuff, why not, especially if it's well scheduled." The
guideline, stated in the scenario format's guidance:

- A database node's cron, `pg_cron` or the daemon, may run **light,
  well-scheduled work**: creating partitions, small cleanups, refreshing
  a small materialized view, calling a set-based procedure off-peak.
- **Heavy or row-by-row transformation** goes to a transformer node
  sized for it.
- **Heavy work on the source instance** is the worst placement: it
  competes with the customers.

Where the computation runs matters more than where the scheduler lives:
a `pg_cron` job calling a set-based procedure and a transformer's job
running the same statement load the database alike. A scenario departs
from the guidance only to plant a fault, which its answer key names.

## 9. The shop domain

### 9.1 What tarnbeck already has

`tarnbeck-outdoor-shop`'s data file, run by `gmctl load-data` as
`postgres`: roles `shop` (owner, no login), `shop_app` (the web shop,
through PgBouncer), `shop_reports` (the back office, direct);
`customers` (20 000), `products` (2 000), `orders` (300 000 over fifteen
days, status paid → packed → shipped → invoiced, `updated_at`),
`order_lines` (900 000), `delivery_events`, `daily_sales`;
`shop_reports` reads every table, customers' names and e-mail addresses
included. The producer places orders (40 a minute at the noon peak, a
tenth at night), moves them to packed and shipped, ingests carrier
events, and invoices shipped orders at the 12:00 close-of-day. Every
clock and the database's `timezone` are UTC. None of it says who may be
mailed, where a customer lives, when an order was shipped, or where it
goes: the truth the purposes' invariants need.

### 9.2 Business settings

```sql
CREATE TABLE business_settings (
    timezone          text NOT NULL,   -- the customer's zone, Etc/GMT∓N, from load-data
    utc_offset_hours  integer NOT NULL,
    mail_window_start time NOT NULL DEFAULT '08:00',
    mail_window_end   time NOT NULL DEFAULT '21:00'
);
```

One row, written by the data file from `load-data`'s variables. The
jobs and the checks read it.

### 9.3 Customers: address, country, time zone, consent

- `customers.address`, `customers.country` (ISO 3166 alpha-2),
  `customers.timezone` (`Etc/GMT∓N`).
- `consent_events (id, customer_id, purpose, granted, at, source)`:
  every grant and withdrawal (`purpose` is `marketing-email`; `source`
  is `checkout`, `unsubscribe-link` or `support`). The truth consent
  invariants judge against: a customer has marketing consent at a moment
  when their latest `marketing-email` event at or before it is a grant.
- `customers.marketing_opt_in`: the current state, kept by the web shop
  beside the history. Two places for one fact is realistic, and a fault
  vector. **The baseline jobs read the latest consent event, never the
  flag.**
- **Recipients' time zones**, relative to the customer's: 80 % at its
  offset, 5 % at −1 h, 5 % at +1 h, 5 % at −8 h, 5 % at +5 h. With
  sending hours 08:00 to 21:00 and the campaign job running 08:00 to
  20:45 customer time, recipients at −8 h are outside their hours before
  16:00 and those at +5 h from 16:00: every campaign batch has a witness
  for the sending-hours invariant.

### 9.4 Orders: shipping time, destination

- `orders.packed_at`, `orders.shipped_at`, set by the warehouse's status
  update.
- `orders.ship_country`: the customer's country by default, sometimes
  another.
- `export_countries (country)`: the destinations outside the customs
  union. About 10 % of orders ship to one, so a few export orders are
  packed every five minutes at the peak, one every quarter hour at night.

### 9.5 Longer history for the segment

Orders cover fifteen days; a win-back segment needs customers who last
ordered 60 to 365 days ago. The data file sets `last_order_at` from an
older, archived history (older orders archived away) for customers with
no recent order: about a third lapsed.

### 9.6 The purposes' tables

| Table | Database | Purpose | Notes |
|---|---|---|---|
| `campaigns (id, code, segment, starts_on, ends_on, active)` | `shop` | P2, P3 | one active `winback` campaign |
| `leads (campaign_id, customer_id, score, extracted_at)` | `shop` | P2 | unique (campaign, customer) by design |
| `mail_outbox (id, customer_id, email, template, campaign_id, order_id, payload jsonb, sent_at)` | `shop` | P3 | "handed to the provider" |
| `customs_outbox (id, order_id, payload jsonb, sent_at, idempotency_key)` | `shop` | P5 | unique `idempotency_key` by design |
| `customs_acks (outbox_id, status, reference, reason, received_at)` | `shop` | P5 | written by the gateway stub |
| `incidents (id, source, ref, opened_at, reason)` | `shop` | P5 | escalations |
| `etl_runs (id, job, started_at, finished_at, rows_read, rows_written, watermark)` | `shop`, and `rpt.etl_runs` in `reporting` | P1, P2, P5 | the run ledger the jobs write themselves |
| `rpt.sales_hourly (hour_local, category, orders, units, revenue)` | `reporting` | P1 | aggregates only, no customer id |
| `rpt.sales_daily (day_local, orders, revenue, invoiced_revenue, closed)` | `reporting` | P1 | |
| `src.orders`, `src.order_lines`, `src.products` (foreign tables) | `reporting` | P1 | over `postgres_fdw`, read by the nightly close only; each declares only the columns the close needs, `src.orders` without `customer_id` |
| `popular_products` (materialized view) | `shop` | the web shop | refreshed hourly by `db`'s crontab (16.1) |

`daily_sales` leaves the shop's database: the reporting database holds
the figures now.

### 9.7 Roles

| Role | Instance and database | Reads | Writes |
|---|---|---|---|
| `shop_app` | `db`, `shop` | as in tarnbeck, plus `consent_events`, `popular_products` | as in tarnbeck, plus `consent_events`, `customers.marketing_opt_in`, the new order columns |
| `shop_reports` | `db`, `shop` | every business table, new ones included (names and e-mails included) | none (the roll-up moved) |
| `shop_etl` | `db`, `shop` | `orders` without `customer_id` (a column grant), `order_lines`, `products` | none: the hourly script's source role and the user mapping's remote role |
| `shop_crm` | `db`, `shop` | `customers`, `consent_events`, `orders`, `campaigns`, `leads`, `mail_outbox`, `business_settings` | `leads`, `mail_outbox`, `etl_runs` |
| `shop_customs` | `db`, `shop` | `orders`, `order_lines`, `customers` (name, address, country), `export_countries`, `customs_outbox`, `customs_acks`, `incidents` | `customs_outbox`, `incidents`, `etl_runs` |
| `customs_gw` | `db`, `shop` | `customs_outbox` | `customs_acks` |
| `shop_refresh` | `db`, `shop` | none beyond the view's inputs | `MAINTAIN` on `popular_products` (PostgreSQL 17 and later), so it may refresh it |
| `bi_etl` | `reporting`, `reporting` | `src.*`, `rpt.*` | `rpt.*` |
| `bi_reader` | `reporting`, `reporting` | `rpt.*` | none |

Each login role's password is a generated secret, set by `load-data`, as
v0.3 does for the roles a schedule names; a user mapping's password and
a crontab's password file use the same secrets. The foreign server is
owned by `postgres`, which creates it; the baseline's only user mapping
is `bi_etl`'s, to `shop_etl`.

### 9.8 Producer changes

New keys in the web shop's repository and streams in its schedule:

- `consent.unsubscribe` (the unsubscribe link: a withdrawal event and
  the flag), about 20 an hour, weighted to lapsed customers, so the
  consent invariants have witnesses every hour;
- `consent.subscribe` (a grant at checkout), about 30 an hour;
- `orders.status` sets `packed_at` and `shipped_at`; `orders.place` sets
  `ship_country`.

The purposes' jobs add load, small beside the checkout; measured at the
rehearsal.

### 9.9 Classification

Every column carries a class in `data/classification.yaml` (11.2):
`personal` for names, e-mail and postal addresses, a customer's country
and time zone, consent events, the outboxes' e-mails and payloads;
`customer-linked` for a customer id with no direct identifier beside it
(`orders.customer_id`, `leads`); everything else `internal`.

## 10. The four purposes

Four purposes on the shop, one more than "two or three", the owner's
choice. P1 to P3 chain (reporting is the BI side, leads come from the
shop's own data, mailing consumes the leads) and cover every trace kind
with one second database; P5 is the kind the owner singled out, the only
one with a deadline and an acknowledgement. Only P1 moves data between
instances; P2, P3 and P5 are plain SQL jobs on the shop's own database,
run by the `crm` transformer, and need no script.

### 10.1 P1 — sales reporting

The back office's figures move out of the shop's database into a
reporting instance the BI agency runs.

**Jobs** (runner `bi`). The two use two methods, as an agency's newer
loader beside its older nightly procedure would:

| Job | Cadence (scenario time) | Method | What it computes |
|---|---|---|---|
| `rollup-hourly` | `5 * * * *` | transformer script `scripts/rollup.py:hourly`, connections `source` (`shop` as `shop_etl`) and `target` (`reporting` as `bi_etl`) | the orders changed since the watermark (`updated_at`), read from the source; their hours and days recomputed in `rpt.sales_hourly` and `rpt.sales_daily` (delete and re-insert the affected hours, one target transaction holding the watermark too); one `rpt.etl_runs` row |
| `rollup-close` | `30 1 * * *` | `CALL rpt.close_day()` on `reporting` as `bi_etl`: a `SECURITY INVOKER` procedure reading `src.orders`, `src.order_lines`, `src.products` over `postgres_fdw` (the mapping to `shop_etl`) | yesterday, in the customer's time zone, recomputed whole and marked `closed`; one `rpt.etl_runs` row |

Both fit the placement guideline: the hourly script's row-by-row work
runs on `bi`, sized for it; the close is scheduled on `bi` but computes
on `reporting`, the receiving instance, as one set-based procedure at
01:30, off-peak, the shop's instance serving only the remote scan.

**Consumer**: the back office's dashboards (the `consumer` node) read
`reporting` as `bi_reader`; their queries are definitions.

**Trace**: `rpt.sales_hourly`, `rpt.sales_daily` (published results);
`rpt.etl_runs` and the scheduler log (run ledger); the dashboards'
queries (definitions).

**Invariants**:

- **R1 reconciled.** For every hour and day a run since the judged
  moment wrote, its orders, units and revenue equal the source's for
  that local hour or day, counting the source's orders as they stood at
  the run's start (`updated_at` before it). Witness: orders arrive every
  hour, night included, and the 12:00 close-of-day invoicing updates
  past orders daily.
- **R2 counted once.** Each (hour, category) has one row; a day's row
  equals the sum of its hours.
- **R3 local days.** Hours and days are the customer's local hours and
  days. Witness: orders placed between local midnight and the offset's
  hour exist every night.
- **R4 fresh.** The latest successful `rollup-hourly` started within 70
  minutes and processed rows; no run since the judged moment ended in
  error or read no row in business hours.
- **R5 dashboard faithful** (a definition). The dashboards' revenue
  query returns what `rpt.sales_daily` holds for the same day.

### 10.2 P2 — win-back leads

The marketing team extracts, every hour, the customers to win back for
the active campaign.

**Job** (runner `crm`, as `shop_crm`): `leads-extract`, `20 * * * *`:
for the active `winback` campaign, customers whose last order is between
60 and 365 days old, with marketing consent by their latest consent
event, not yet a lead of the campaign, into `leads` with a score; one
`etl_runs` row.

**Trace**: `leads` (published results), `etl_runs` and the log (run
ledger).

**Invariants**:

- **L1 in segment.** Every lead extracted since the judged moment had,
  at its `extracted_at`, no order in the previous 60 days and one within
  365. Witness: lapsed customers order again every day.
- **L2 consented.** Every lead extracted since had marketing consent at
  its `extracted_at`. Witness: the unsubscribe stream withdraws consent
  from lapsed customers every hour.
- **L3 once per campaign.** At most one lead per (campaign, customer).

### 10.3 P3 — customer mailing

Mail is "handed to the provider" by inserting into `mail_outbox`; the
outbox is the whole trace.

**Jobs** (runner `crm`, as `shop_crm`):

| Job | Cadence (scenario time) | What it sends |
|---|---|---|
| `mail-shipped` | `*/5 * * * *` | Transactional: one `order-shipped` notice per order shipped since the last run, to its customer; no marketing consent needed |
| `mail-campaign` | `*/15 8-20 * * *` | Marketing: up to a batch of the active campaign's leads not yet mailed, with marketing consent at sending time by their latest consent event, whose local time is within the sending hours |

**Invariants**:

- **M1 no duplicate.** At most one `order-shipped` mail per order; at
  most one campaign mail per (campaign, customer).
- **M2 consent.** Every marketing mail sent since the judged moment had
  marketing consent at its `sent_at`. Transactional mail is exempt.
  Witness: unsubscribes arrive every hour among leads.
- **M3 sending hours.** Every marketing mail's `sent_at`, in the
  recipient's local time, falls within the sending hours. Witness: the
  recipients' zones (9.3).
- **M4 own data.** Every mail's payload names its recipient only: its
  e-mail and name are the recipient's, any order in it is the
  recipient's.
- **M5 truly sent.** Every order shipped since the judged moment, more
  than fifteen minutes ago, has its `order-shipped` mail: the owner's
  "were we truly doing this".

### 10.4 P5 — export declarations: a pushed obligation

Every order shipped to a country outside the customs union must be
declared to the customs gateway within two hours of being packed; the
gateway answers with a movement reference (accepted) or a rejection.
Other shop instances were considered and dropped: a product recall or a
personal-data breach notification (rare triggers, which would have to be
timeline changes) and a VAT filing (monthly).

**Jobs** (runner `crm`, as `shop_customs`):

| Job | Cadence | What it does |
|---|---|---|
| `declare-exports` | `*/5 * * * *` | Packed orders whose `ship_country` is in `export_countries` with no declaration yet: one `customs_outbox` row each, keyed by the order (the idempotency key), with the declared content |
| `escalate-customs` | `*/15 * * * *` | Declarations unacknowledged 30 minutes after sending, or rejected: one `incidents` row each |

**The receiver** is a stub, a scheduler node of its own (`gateway`,
role `producer`, report-only), standing for the customs authority and
the shop's callback endpoint: a stream reads new `customs_outbox` rows
as `customs_gw` and writes `customs_acks` within a minute. It accepts
every well-formed declaration, so two declarations of one order get two
references. **It never acknowledges about one declaration in fifty**, as
standing behaviour of its schedule, so the escalation of missing
acknowledgements has work every hour, before and after the hand-over.
Its outages and rejections are timeline changes of its
schedule, never events outside it. No real external service.

**Trace**: the triggers (orders, `export_countries`), `customs_outbox`,
`customs_acks`, `incidents`, the runner's log.

**What v0.4 does with an acknowledgement**: it records it and checks
it; the only process it starts is an `incidents` row for a rejection or
a missing acknowledgement. Nothing waits on it, nothing is resubmitted,
held, released or cancelled because of it.

**Invariants**:

- **E1 every trigger declared in time.** Every order packed since the
  judged moment with an export destination has a declaration sent within
  two hours of `packed_at`. Witness: export orders are packed every few
  minutes.
- **E2 declared once.** At most one accepted declaration per order.
- **E3 minimum content.** A declaration carries the fields the gateway's
  schema lists and nothing else: no e-mail, no customer id, no other
  order's lines.
- **E4 acknowledged or escalated.** Every declaration sent since the
  judged moment has an acknowledgement, or an `incidents` row within 30
  minutes of sending; every rejection has an `incidents` row. Witness:
  the stub's unacknowledged declarations.

### 10.5 Finance, held for v0.5

Listed so the swap is costed: a nightly invoicing and a period close;
`payments`, `refunds`, `invoices`, `ledger_entries`, `periods`;
invariants that every invoiced order has one invoice equal to its total
and a payment covering it, the ledger balances per period, a closed
period is never modified, a refund lands in the period it happened in,
reporting revenue equals ledger revenue.

**Stress test.** The veterinary clinic's strict reporting, a v0.5
domain, was used to test the purpose model: a deadline (a notifiable
disease reported within hours of the confirming result) is a pushed
obligation; a release gate (no lab result on the owner's portal before a
vet validated it) is an invariant over the trace against the source; a
register (the antimicrobial-use register) is completeness plus
reconciliation. No new artefact or check form is needed. Regulatory
reports are monthly or yearly in reality, which real time cannot age.

## 11. Data governance

### 11.1 The customer's governance, a first cut

In the owner's words: "It might also be a good opportunity to introduce
data governance rules as well (some data NEED to be in distinct
database, with distinct settings, etc)." It is the customer's
governance, part of the game's world: the rules the fictional company
states for its own data and its own database roles. It is not the
game's access model, which says who plays and what the players may
reach, and not a governance of this project's data: every scenario's
data is synthetic. The first cut is classification, allowed locations,
readers and outbound flows; it sits in v0.4 because purposes move data
and governance says where it may go.

### 11.2 Classes

| Class | What | In the shop |
|---|---|---|
| `personal` | a direct identifier, or anything stored with one | names, e-mail and postal addresses, country, time zone, consent events, the outboxes' e-mails and payloads |
| `customer-linked` | a customer id with no direct identifier beside it | `orders.customer_id`, `leads` |
| `internal` | everything else | products, order totals, aggregates |

A `payment` class arrives with finance, the special categories with the
regulated domains.

### 11.3 Where the rules are stated

**The domain classifies, the scenario rules.** The domain's
`data/classification.yaml`, copied into the scenario, classes every
column (`shop.customers.email: personal`); a column with no entry is
`internal`. `scenario.yaml`'s `governance:` (6.9) states, per class, its
locations, its readers (customer roles) and its outbound flows with
their allowed fields, and names the policy file. The loader checks the
references (6.1).

### 11.4 Locations: a database or an instance

"Distinct database" reads two ways in PostgreSQL: another database in
the same instance, or an instance of its own. Locations, readers, flows
and statement-log settings are per database or role; audit logging (a
preloaded library), TLS, the logging collector, a separate superuser,
separate backups and separate failure need an instance. So:

- **A location is `node/database`**: `db/shop` and `db/reporting` would
  be two databases of one instance, `db/shop` and `reporting/reporting`
  two instances. A class's rule may add `separation: instance`, which
  the check verifies by node.
- **v0.4's reporting database is an instance of its own**, a second
  `postgres` node: the owner's words point at settings, which only an
  instance separates; v1.0's pipeline already draws two database nodes;
  and v0.5's regulated domains will need it. Its cost: about 256 MB
  reserved, and a second exporter or the instance left unscraped (13.4).

### 11.5 The policy the players audit

`player/data-policy.md`: the company's data policy in the story's voice,
in the starter pack beside the story: what the company holds, the
classes in plain words, where each may live, who may read it, what may
leave and to whom. The GM writes it from `governance:`; the scenario
document lists it.

- It may state rules no check verifies (encryption at rest, retention),
  unmarked, as a real policy does not say which of its rules are
  audited. The answer key lists only checked ones.
- It is correct in v0.4. A policy that is itself wrong or ambiguous
  would be starter documentation carrying a fault, which the project has
  not decided to allow.

The v0.4 policy allows the back office to read customers' names and
e-mail addresses (it answers customers), so `shop_reports`' grants are
no finding in `shop`; the policy keeps personal and customer-linked data
out of `reporting`.

### 11.6 The checks

Definition checks, judged on the live state, exit 0 or 1, never 3. They
cover every database of every `database` node. They are implemented
once, as a shared governance check set reading `governance:` and the
classification, and a governance fault's sealed check runs the rules it
breaks.

| Check | Rule | How |
|---|---|---|
| G1 location | a classed column exists only in its allowed locations | the catalog of every database on every `database` node: tables, views, materialized views and foreign tables. A foreign table's column takes the class of the remote column it maps; a table's or view's column takes the class of a classified column with the same table and column name; and for `personal`, a content probe on the text columns of disallowed databases finds values shaped like an e-mail address, so a renamed copy is caught |
| G2 readers | only allowed customer roles may read a classed column | `has_column_privilege` for every customer login role, through membership and `PUBLIC` |
| G3 reach | no path lets a disallowed location read a class | every foreign table, and every user mapping's remote role checked with G2 on the source (a mapping whose remote role may read `personal`, or a mapping for `PUBLIC`, makes the mapping's database a reader); every transformer job whose connections join a source role to another database, the source role checked with G2 (read from the runner's `jobs.yaml` and schedule, on the runner node); a `SECURITY DEFINER` procedure reaching as its owner; every `pg_cron` job, its `username` checked with G2 in the database it runs in, a superuser reaching everything |
| G4 outbound | what leaves carries only the listed fields | the outboxes' payload keys against `outbound.fields`, on rows written since the judged moment, as a purpose invariant is |

- A transformer script's reach is the one path no catalog shows: G3
  judges the roles of its connections, G1 what actually landed; the
  script's code is the players' evidence, not the check's. A cron
  daemon's entry is the same: G3 does not parse shell lines.
- The GM check role cannot read a user mapping's options, where its
  remote role is written (PostgreSQL shows them only to a superuser, the
  mapped role or the server's owner, to protect the password beside it).
  `load-data` creates, where a data file creates a foreign server, a
  function owned by `postgres`, `SECURITY DEFINER`, executable by the
  GM check role only, returning each mapping's server, local role and
  remote role, never its password.
- The checks reach the other instances as the GM check role over the
  game network (7.2): every `database` node of a scenario with
  `governance:` admits the GM check role from the game network in its
  seed `pg_hba.conf`, under the DO NOT TAMPER comment.
- **The game's own roles are outside every rule**: `dba` (the
  players' superuser), `postgres`, the GM check role, `monitoring`, and
  PgBouncer's lookup role. Each would break "who may read"; the policy
  says "application and staff accounts", and the checks skip them by
  name.
- **Not checked**: encryption at rest, retention, purposes of
  processing. The policy may state them; the checks do not judge them.

### 11.7 What "fixed" means for a governance fault

A definition (a classed column where it may not be, a grant, a mapping,
a job copying data) is fixed when the live state complies: removing what
was copied is part of the fix, not only stopping the flow. Content
already sent (outbox payloads) is judged as a purpose is: no new
violation since the judged moment. G1 to G3 are the first kind, G4 the
second.

### 11.8 The coupling to purposes

A purpose fault and a governance fault can be one event seen from two
angles: a copied column is a definition a governance check sees, the
payload in the outbox a trace a purpose check sees. The most realistic
governance fault is a transformation copying personal data into the
reporting database, or an outbox carrying more than it should.

## 12. Checks on purposes

v0.3's rules stand: exit 0 fixed, 1 present, 3 too soon to tell; a check
runs on its fault instance's node only; from a scheduler node it reaches
any database as the GM check role through `check-sql`; the final checks
run with the load still running and trigger nothing. A daily job breaks
v0.3's trailing-window model: no window short enough to judge a fix is
long enough to contain a run. So a purpose fault's sealed check judges
**the job's runs since a moment**.

### 12.1 The judged moment

`CHECK_SINCE`, which `gmctl check` passes:

- the hand-over, by default;
- raised by the check itself to the runner's last successful reload
  (`reload status=ok` in its log) when that is later, since a fix to a
  job's SQL or time takes effect only through a reload;
- raised by the GM with `gmctl check --since <time>` when the players'
  report says they fixed something outside the runner (a constraint, a
  grant, a role) at a given time.

Rejected: running the job, or its query, in a rolled-back transaction to
predict the next run. It would answer at once, but it triggers a job
during the game, and it would need the job role's password on the check
side.

### 12.2 Verdicts by runs

The runs are the job's `run … phase=end status=ok` lines in the
runner's log after the judged moment; trace rows are tied to a run by
their time (written inside the run's transaction) or by their
`etl_runs` id.

- No completed run since the judged moment: **exit 3**, `remaining=` the
  seconds to the job's next run in the loaded `jobs.yaml`, read with the
  program's own cron parser.
- A run since the judged moment that violates the invariant: **exit 1**,
  naming the run and one violating row.
- Every run since clean, at least one a witness: **exit 0**.
- Runs since, all clean, none a witness: **exit 3**, `remaining=` to the
  next run.

**Past violations never count**; they stay in the trace as evidence.
"Fixed" means no new violation since the fix.

### 12.3 Witnesses

A clean run proves a fix only if it could have violated. Each invariant
states its witness condition, and the check counts the material where it
can: customers without consent among the campaign's pending leads at
the run's time, recipients outside their sending hours among those
pending, orders crossing a local midnight in the day the run closed.
Where the check cannot count it, the purpose's design guarantees it (the
producer's streams, the recipients' zones, the stub's unacknowledged
declarations) and the fault's notes say so.

### 12.4 Pushed obligations

A deadline invariant judges **triggers** rather than runs:

- a trigger since the judged moment past its deadline with no
  declaration (or, for E4, no acknowledgement and no incident): **exit
  1**;
- every trigger since the judged moment older than two dispatch cycles
  handled in time, at least one such trigger: **exit 0**;
- otherwise: **exit 3**, `remaining=` until the oldest pending trigger
  reaches two cycles or its deadline.

A fix to the dispatcher shows within ten or fifteen minutes whatever the
deadline's length, while a miss is called only once its deadline has
passed.

### 12.5 Runs of a job on a database node

- **A `pg_cron` job**: its rows in `cron.job_run_details` (`status =
  'succeeded'`, `end_time` after the judged moment), read as the GM
  check role through its read policy; the next run from
  `cron.job.schedule` and `cron.timezone`. The judged moment is raised
  to the job's last change only by the GM, since `cron.job` keeps no
  change time. A scenario using such a job keeps `cron.log_run` on in
  its baseline; a fault turning it off makes the check answer 3.
- **A cron daemon's entry**: it has no ledger of its own, so a purpose
  job run this way writes the purpose's run ledger in the same
  transaction as its output, and the check judges those rows; the next
  run is read from the crontab with the program's own cron parser.

The check runs on the database node through `check-psql`.

### 12.6 Definition checks

A purpose's definitions (a dashboard's query, a job's configuration, a
crontab entry's role) and governance's G1 to G3 are judged on the live
state, as v0.3's configuration checks are: exit 0 or 1, never 3. A
definition check may run a dashboard's `SELECT` read-only as the GM
check role to compare its result with the published table: it reads, it
runs no job.

### 12.7 An incident check

A fault judged on an incident in the recent past rather than a live
state (16.3) exits 1 while the incident's evidence is there, and never
0 or 3: it proves the incident happened, nothing more. Its resolution is
the players' report.

### 12.8 At the final answer

An exit 3 is reported as undetermined in the feedback. The players'
lever is moving the job's time, which the starter pack states for every
purpose job they may edit. The GM passes `--since` when the report dates
a fix made outside the runner.

## 13. Instances, nodes and hosts

### 13.1 Several instances

A scenario may have several PostgreSQL instances, each a `postgres`
node of its own, reusing the GM check role, the exporter, monitoring and
the GM's knowledge. The first v0.4 scenario has two, `db` (the shop) and
`reporting`: the four purposes need no third, and each instance costs
about 256 MB.

### 13.2 Nodes sized by role

- **Each distinct producer runs on a node of its own**, sized as small
  as it runs: its scenario `resources` set from its measured peak, below
  the `scheduler` brick's default where the measurement allows
  (tarnbeck's producer peaked at 39 MB against 64 MB reserved).
- **A transformer node may be sized larger**, to hold the volume its
  scripts move in one run.
- "Its own machine", in the owner's words, is a scenario node with its
  own reservation, placed on a host by `fit` and the designed placement
  as in v0.3, never a host per producer: one-host games and classroom
  swarms keep working.

The first scenario's starting figures are in 16.1, set from v0.3's
rehearsal peaks and measured at v0.4's.

### 13.3 Shared hosts

A host shared with other applications must never carry a node that may
exhaust its memory: the VPS hosts filetstudio.com, which must stay up
and never be disturbed.

- The playground's host declaration may mark a host `shared` (`--host
  vps,shared,…`); the VPS is declared so.
- A fault declaring `needs_unshared_host` puts its instance's node under
  the rule. `gmctl fit` refuses a mapping that places such a node on a
  shared host and names the mapping to change, as it refuses a node
  publishing ports off the manager. A playground whose only hosts are
  shared cannot take the scenario.
- The first scenario's designed placement puts that node on the first
  host, the manager.
- Smoke runs of such a fault, its calibration included, run on armenelos
  only, never on the VPS.

### 13.4 Monitoring a second instance

A second instance is monitored by a `postgres-exporter` node of its own
(about 42 MB reserved), which the scenario format's guidance names; the
exporter brick is not changed. The first scenario leaves `reporting`
unscraped by design, the agency's instance: a silent tooling
expectation in the answer key (a finding the players may make, judged in
the feedback, not a fault instance), as v0.2's tooling expectations are.
`reporting` still has the `monitoring` role, as every `postgres` node
does until v0.5.

## 14. The local implementation and the scripts

**`gmctl`**:

| Verb | Change |
|---|---|
| `fit` | reads a host's `shared` mark; refuses a node carrying a fault that needs an unshared host on a shared host (13.3) |
| `render` | substitutes `{{customer_timezone}}` in scheduler seed files and in a `postgres` node's seed `postgresql.conf`; shifts a seeded `crontab`'s hours; mounts the secrets of a node's `crontab_roles` (8.5, 7.2) |
| `load-data` | passes `customer_timezone` and `customer_utc_offset` to `psql`; sets each user mapping's password from its remote role's secret; gives the GM check role a read policy on `cron.job` and `cron.job_run_details` where `pg_cron` exists; creates the mapping-roles function where a foreign server exists; grants the GM check role `CONNECT` on every database, as today, on every instance (8.5, 7.2, 11.6) |
| `check` | passes `CHECK_SINCE` (the hand-over, from the state) to checks judging runs or triggers; takes `--since <time>`, per instance with `--instance <id>` (12.1) |

The other verbs are unchanged. Nobody triggers a job: no verb runs one.

**The loader**: `purposes:`, `domain:` and `governance:` in
`scenario.yaml`; `judges:` and `needs_unshared_host` in `fault.yaml`;
`seed.optional` in `brick.yaml`; for `scheduler` 0.2.0 a script key's
file and function and a job's `connections:`; for `postgres` 0.4.0 the
optional `crontab` with its `crontab_roles`, and a data file creating
`pg_cron` only on a node whose seed preloads it, `cron.database_name`
naming a database it creates (6, 7).

**The format skill** (`scenario-format`): templates and completeness
rules for the purpose and the domain, `governance:` and the policy,
the new fault fields, the optional crontab; the placement guideline
(8.7); a second instance's exporter (13.4).

**The scenario document skill**: the purposes a scenario uses, its
governance and policy file, its database-node jobs.

**The GM skill**: designing with purposes and a domain; writing the data
policy from `governance:`; telling the players in the starter pack which
jobs they may move; the judged moment and `--since` from the players'
report; feedback on governance faults ("fixed" as 11.7) and on a report
judged against an incident (16.3); a failed incident's handling (16.3);
a change the players made where the issue asked for a report or a
proposal (16.5); a shared host refused by `fit`.

## 15. Player access and rules

The full rules are in the [access model](access-model.md). In short:

- The players reach both instances from the bastion as `dba`.
- On a transformer node they read the repository with its scripts,
  `jobs.yaml` and the log, and edit them where the scenario makes them
  fixable; `schedule.yaml` stays hidden.
- On a database node they read `pg_cron`'s jobs and runs as `dba`, list
  the crontab with `sudo gm-crontab -l`, and may change either; every
  database node is fixable.
- The agency's `reporting` is technically fixable too. The story makes
  it the agency's and its issues ask for reports or proposals; a change
  there is judged in the feedback as overstepping, never credited as the
  resolution (16.5).
- They read the company's data policy in the starter pack; the
  customer's roles and grants are part of the system they audit, not of
  their own access.

## 16. Scenario and faults

### 16.1 The new scenario

Working id `tarnbeck-outdoor-campaign`, normal difficulty, ten fault
instances.

**Story.** Tarnbeck Outdoor, six months after the v0.3 audit. The shop
now sells abroad, including outside the customs union. Lumen Analytics,
a BI agency, moved the back office's figures to a reporting database and
runs the nightly and hourly roll-ups; it also built a churn table for a
dashboard, refreshed by a job inside the reporting database, and a
nightly sales-detail roll-up run from the reporting server's own
crontab. The marketing team, in-house, runs a win-back
campaign by e-mail and the shop's shipping notices; the shipping manager
runs the export declarations to the customs gateway. Ines Varga asks for
an audit after complaints: customers who unsubscribed still get mail,
some get every shipping notice twice, a customer abroad got a promotion
at 3 a.m., the accountant's revenue never matches the dashboard, and the
dashboards froze this morning. Lumen also mentions that the reporting
database "restarted itself" one night this week and says it is fine now.
She hands over the company's data policy with the story.

**Topology** (limits / reservations are starting figures, measured at
the rehearsal):

| Node | Brick | Role | Write policy | Limit / reservation |
|---|---|---|---|---|
| `bastion` | `bastion` 0.3.0 | bastion | report-only | as v0.3 |
| `db` | `postgres` 0.4.0 | database (`shop`) | fixable | 1G / 512M |
| `pooler` | `pgbouncer` 0.1.0 | pooler | fixable | as v0.3 |
| `producer` | `scheduler` 0.2.0 | producer (the web shop) | report-only, repository and `jobs.yaml` fixable | 96M / 48M |
| `consumer` | `scheduler` 0.2.0 | consumer (the back office's dashboards, reading `reporting`) | report-only, `jobs.yaml` fixable | 128M / 64M |
| `reporting` | `postgres` 0.4.0 | database (`reporting`), the agency's | fixable; the agency's by the story, its faults *propose* or *report* | 512M / 256M |
| `bi` | `scheduler` 0.2.0 | transformer: P1, the agency's | report-only | 384M / 192M |
| `crm` | `scheduler` 0.2.0 | transformer: P2, P3, P5 | report-only, repository and `jobs.yaml` fixable | 128M / 64M |
| `gateway` | `scheduler` 0.2.0 | producer: the customs gateway stub | report-only | 96M / 48M |
| `prometheus`, `exporter`, `grafana` | as v0.3 | monitoring of `db` | as v0.3 | as v0.3 |

- `db` runs the cron daemon with one light hourly entry, the web shop's
  refresh of `popular_products` (f6). `reporting` runs `pg_cron`
  (holding f9's job) and the cron daemon (the agency's nightly
  sales-detail roll-up at 03:00, f10).
- About 600 MB of reservations more than tarnbeck's 1.25 GB.
- On two designed hosts: `reporting` on host 1, the manager, since it
  carries f10; `bi` and `gateway` on host 2. On a one-host playground
  every node on that host. `reporting` is never placed on a shared host
  (13.3).
- The agency's nodes: `bi` is report-only, which the scheduler brick
  enforces; `reporting` is fixable, as every database node is, and only
  the story and the answer key make it the agency's. Both nodes' faults
  are *report* or *propose* (16.5).

**Time.** As tarnbeck: T0 22:00, hand-over 14:00, sixteen hours of
aging, four hours of play. During the aging: one nightly close (01:30),
sixteen hourly roll-ups and extractions, the campaign from 08:00, the
notices and declarations all along, the producer's 12:00 invoicing.
During the game: the hourly and quarter-hour runs; the nightly close
only if the players moved it, which they cannot on `bi`. f10's backfill
request is planted at `handover-12h` (02:00), the roll-up runs at 03:00
and is killed, `reporting` recovers within seconds, the next night runs
normally; at hand-over the incident is eleven hours old. The early check
and the nightly close stay clear of it.

**Fault instances**:

| # | Fault | Node | Purpose | Planted | Visibility, resolution |
|---|---|---|---|---|---|
| f1 | `purpose-mail-overlapping-window` | `crm` | P3 | seed-file | known (I1), fix |
| f2 | `purpose-leads-stale-consent` | `crm` | P2, P3 | seed-file, and the producer's timeline change at T0 | known (I2), fix |
| f3 | `purpose-mail-outside-hours` | `crm` | P3 | seed-file | known (I3), fix |
| f4 | `purpose-watermark-misses-updates` | `bi` | P1 | seed-file | known (I4), propose |
| f5 | `purpose-etl-role-expired` | `db` | P1 | state, `handover-5h` | known (I5), fix |
| f6 | `security-crontab-superuser` | `db` | the web shop's job | seed-file | hidden, fix |
| f7 | `purpose-day-boundary-wrong-zone` | `reporting` | P1 | seed-file (the close's procedure) | hidden, propose |
| f8 | `purpose-receiver-down-unnoticed` | `crm` | P5 | seed-file, and the gateway's two-hour outage as a timeline change | hidden, fix |
| f9 | `governance-personal-copied` | `reporting` | P1, the policy | seed-file | hidden, propose |
| f10 | `purpose-heavy-job-on-database-node` | `reporting` | the agency's roll-up | seed-file at T0, state at `handover-12h` | known (I6), report |

**Issues**:

- **I1** (fix): "Customers say they get every shipping notice twice."
- **I2** (fix): "People who unsubscribed since last night still get our
  win-back e-mails. That is exactly what the data policy forbids."
- **I3** (fix): "A customer abroad, eight hours behind us, complained
  about a promotion at 3 a.m. his time." Relative, never a city: the
  customer's zone moves with the shift.
- **I4** (propose): "The accountant's invoiced revenue never matches the
  dashboard's, and the gap grows. The figures are Lumen's: tell us what
  they should change."
- **I5** (fix): "The dashboards stopped updating this morning."
- **I6** (report): "Lumen says the reporting database restarted itself
  one night this week and that it is fine now. Is it? Tell us what
  happened and what should change."

**What it tests**:

- every trace kind: outbox rows (f1, f3), published results (f4, f7), a
  run ledger (f5), triggers and acknowledgements (f8), a definition (f9);
- four places jobs run from: a transformer script (f4, f5), a stored
  procedure over `postgres_fdw` (f5, f7), a `pg_cron` job (f9), a cron
  daemon (f6, f10); f9 is fixed only when the job is found too;
- placement: `db`'s light entry well placed and wrongly privileged (f6,
  a fix); `reporting`'s heavy roll-up wrongly placed, and showing it once
  (f10, a report);
- an incident in the recent past, real and recovered from, judged by the
  players' report (f10);
- the judged moment: f1 to f3 and f8 fixed and confirmed within the game
  by their frequent runs; f5 confirmed with the GM's `--since`; f7's fix
  is the agency's, its job on `bi`, a report-only node the players cannot
  move it on, so its check is expected to stay present and the players'
  proposal is what the feedback judges; a player overstepping could edit
  the procedure on `reporting` and run it by hand, which 16.5 covers;
- governance against a stated policy (I2 cites it; f9 is found only by
  reading it);
- shift invariance: f3 and f7 hold at any shift.

### 16.2 The new catalogue faults

v0.4 builds the scenario's ten faults as catalogue faults, each with its
injection, aging minimum, sealed check and solvability description. The
drafts' other candidates stay recorded for later versions (22).

| Fault | Breaks | What is wrong | Evidence | Expected resolution and fix |
|---|---|---|---|---|
| `purpose-mail-overlapping-window` (`data-flow`) | M1 | the shipped-notice job, every five minutes, picks orders shipped in the last ten: every notice sent twice | two `order-shipped` rows per order, ten minutes apart | fix: select since the last run or `NOT EXISTS`; a unique (order, template) |
| `purpose-leads-stale-consent` (`rules`) | L2, M2 | the extraction and the campaign job read `customers.marketing_opt_in`, which the unsubscribe link no longer updates since a release (a timeline change of the producer at T0): withdrawn customers stay leads and get mail | leads and mails whose latest consent event is a withdrawal; the producer's unsubscribe entry; the jobs' SQL | fix: read the latest consent event in both jobs (or restore the flag's update in the producer's repository); repairing the flag is an *improve* |
| `purpose-mail-outside-hours` (`rules`) | M3 | the campaign job's hours are the company's, not the recipient's | marketing mail at night in the recipient's zone | fix: filter recipients by their local hour |
| `purpose-watermark-misses-updates` (`data-flow`) | R1 | the hourly script picks rows by `placed_at` past the watermark, so an order invoiced at the noon close never reaches reporting: invoiced revenue lags the source, more each day | the script's query; `rpt.sales_daily.invoiced_revenue` against the source's | propose: watermark on `updated_at`; restating the affected days is an *improve* |
| `purpose-etl-role-expired` (`data-flow`) | R4 | `shop_etl`, the hourly script's source role and the mapping's remote role, is given `VALID UNTIL` the planting moment: every run of either job since fails with an authentication error, the dashboards freeze | the runner's log; `rpt.etl_runs` stops; `\du` on `db` | fix: `ALTER ROLE shop_etl VALID UNTIL 'infinity'` |
| `security-crontab-superuser` (`security`) | a credential and privilege rule | `db`'s hourly `REFRESH MATERIALIZED VIEW popular_products` runs `psql` with no user, so as `postgres` by peer: a superuser for a job `shop_refresh` could run (the role, its `MAINTAIN` grant and its password file exist, never switched to) | `gm-crontab -l`; `pg_stat_activity` during a run; the role prepared and unused | fix: connect as `shop_refresh` (`-U`, the password file); its check reads the live crontab and requires every entry's role to be no superuser (exit 0 or 1) |
| `purpose-day-boundary-wrong-zone` (`rules`) | R3, R2 | `rpt.close_day()` cuts the day in a zone N hours off the customer's (a parameter, never 0, which render writes), so every night it rewrites yesterday on the wrong boundary; its check judges the close's runs from `rpt.etl_runs` | closed days shifted against the source's local days, and no longer the sum of their hours; the zone in `\df+` | propose: the customer's zone from `business_settings` |
| `purpose-receiver-down-unnoticed` (`data-flow`) | E4 | the escalation job has no rule for missing acknowledgements; the gateway stopped acknowledging for two hours during the aging (a timeline change of its schedule), and still never acknowledges about one declaration in fifty | declarations with neither acknowledgement nor incident, the two-hour gap foremost | fix: escalate missing acknowledgements |
| `governance-personal-copied` (`security`) | G1, G3 | the agency's churn dashboard keeps `rpt.customer_activity` with names and e-mail addresses: `reporting`'s data file adds a second foreign server mapped, for `bi_etl`, to the back office's login `shop_reports`, a foreign table over `customers`, the table, and a `pg_cron` job as `bi_etl` refilling it every thirty minutes, which no runner lists | the table and the foreign table in `reporting`; `\des+`, `\deu+`; `cron.job`; the policy | propose: unschedule the job, drop the table, the foreign table and the server; its check requires all of them gone, so dropping the table alone, which the job refills, is not fixed |
| `purpose-heavy-job-on-database-node` (`data-flow`) | placement | a heavy transformation from a database node's crontab, which a one-off backfill drove past the node's memory once during the aging (16.3) | the kill and the recovery in the log; `oom_kill` in `memory.events`; the statistics' reset time; the job's log and ledger; the backfill request | report only, whatever the write policy (16.3) |

A fault's seed changes target its own node only. Where it needs an
outside party's behaviour (f2's web-shop release, f8's gateway outage),
its definition says so and the scenario writes that behaviour as a
timeline change of the party's schedule, as v0.3 writes a release that
broke a query.

Each fault's evidence shows at its job's runs; its aging minimum counts
from the first run after planting, and the scenario raises each
instance's minimum to that offset. Quarter-hour and hourly jobs need an
hour; the nightly close needs T0 to 01:30 plus one run; a timeline
change counts from its moment.

### 16.3 The out-of-memory incident

The owner: "It is to my mind a good fault to identify but maybe not as
is: more like, it happened "once" in the recent past, (maybe a larger
than usual peak in the data to be transformed) and it need to be
investigated and decided to move the transformation outside (reporting
only)", and on "reporting only": "it means, the player can't solve the
issue by himself alone, thus his only solution is reporting it". So the
incident happens **for real, once, during the aging**, never forged; at
hand-over it lies in the recent past and the system has recovered; the
players investigate; the fault is **report only**, whatever the node's
write policy.

**What happens.**

1. From T0, `reporting`'s crontab runs the agency's nightly sales-detail
   roll-up at 03:00 as `bi_etl`: `psql` calling a procedure,
   `rpt.sales_detail_rollup()`, which builds the agency's document for
   the order lines changed since its last run in one aggregate
   (`jsonb_agg` over the window) and inserts it. `psql` receives no
   result set. On a normal night it fits.
2. At `handover-12h` a one-off **backfill request** arrives, a `state`
   change planted by `gmctl inject --at`: a row asking the job to
   recompute the last thirty days (in the story, the agency changed its
   formula). The procedure marks the request taken and commits before it
   starts.
3. The run reads thirty days instead of one. The backend computing it
   grows past the node's memory and the kernel kills it.
4. The postmaster ends every other backend and recovers by itself:
   "server process … was terminated by signal 9: Killed", "terminating
   any other active server processes", "all server processes terminated;
   reinitializing", "database system was not properly shut down;
   automatic recovery in progress". It accepts connections again within
   seconds; s6, `sshd` and the cron daemon are untouched.
5. The request stays taken, never done, so the next night runs normally.

The aggregate is what makes it deterministic: its memory sits in the
backend and grows with its input, unbounded by `work_mem`, while sorts
and hash aggregates spill to disk and cannot carry this fault. Docker
allows a container swap equal to its memory limit and Swarm cannot say
otherwise, so the backfill must need more than twice the node's limit
and a normal run less than half of it, after `shared_buffers`. Both are
measured before the scenario's window is set: the cgroup's
`memory.peak` around a normal run and around the backfill, on a host
with swap and one without, on armenelos only, early in the build. If no
window the restored history allows reaches twice the limit, the fault
comes back to the owner before anything is reshaped; lowering
`reporting`'s memory limit is the likely lever, offered to him then.

**Evidence**, all of it on the node: the four log lines at the
incident's time, in the file log and pgBadger; `oom_kill 1` in
`/sys/fs/cgroup/memory.events` and `memory.peak` near the limit; the
statistics' reset times (a crash discards cumulative statistics,
`pg_stat_statements` included); `server closed the connection
unexpectedly` in the job's log at that run and a run with no end in its
ledger; the backfill request, taken and never done; the heavy entry in
the crontab.

**The check** exits 1 while the kill and the recovery are in the log
since the planting moment, whatever the crontab holds since; it never
answers 0 or 3, and no in-game fix is expected. What the players changed
on `reporting`, if anything, the GM reads from the node itself (16.5). The answer key
judges the report: the incident named (when, which process, killed for
memory, the recovery that followed), its cause (the backfill on the
database node at its memory limit), and the recommendation: **move the
transformation's computation off the database node**, to a transformer
node sized for it that reads the window in batches, and bound
backfills. Moving only the schedule (the same `CALL` from `bi`) would
not help, since the procedure would still compute in `reporting`'s
backend; the feedback says so when a report proposes it.

**When it did not happen.** The setup is verified: after the job's
planned run, the fault's check must find the kill and the recovery by
the early check. A failure is recorded, as a failed planting is. The
job runs nightly, so the incident cannot be re-planted inside the same
aging: the hand-over check fails and, as for any planting whose aging
minimum can no longer be reached, the GM offers the initiator to set
the game up again.

**Risks, accepted.** Recovery ends every session on `reporting` (the
transformer's, the consumer's, a `pg_cron` job running then, any GM
check session): acceptable during the aging, with no player connected,
and the moment is away from the early check and the nightly close. Every
cumulative statistic on `reporting` restarts at the incident, so no
other fault's evidence there rests on statistics. If the host swaps,
every node on it slows for minutes before the kill: hence 03:00, alone,
and never a shared host (13.3).

### 16.4 Existing scenarios

`tarnbeck-outdoor-shop`, `bookshop-new-server` and
`fernway-clinics-monitoring` are re-pinned to `postgres` 0.4.0, and
tarnbeck to `scheduler` 0.2.0; none turns on `pg_cron` or the cron
daemon, and each still deploys and passes its v0.3 smoke test
unchanged.

### 16.5 Report-only by the story: overstepping

`reporting` is the agency's in the story, and nothing else makes it so:
`postgres` has no report-only write policy, so the players, as `dba` and
through the node's wrappers, can change its data, DDL, roles, settings,
`pg_cron` jobs and crontab, and reload or restart it. `bi`, a scheduler
node, stays report-only as the scheduler brick enforces it. What an
overstepping player can do, and how it is treated:

- **What the starter pack says.** The story names the agency's nodes,
  and the issues on them ask for a report or a proposal (I4, I6). The
  brick's player documentation is unchanged: nothing on the node claims
  a protection it does not have.
- **The answer key judges the expected resolution.** For a *report* or
  *propose* fault the players' report or proposal is the resolution. A
  sealed check reading fixed after a player's change tells the GM what
  changed on the system; it is not the resolution, and the feedback does
  not count it as one.
- **The feedback names the overstep.** Positively, as a teacher would:
  the change was outside the mandate the issue gave (the agency's
  system, a report was asked for), whether the change itself would have
  been right as a proposal, and what it cost (a roll-up stopped, an
  agency's job edited behind its back). A change that is right and comes
  with the report still gets the report's credit; a change without the
  report leaves the issue unresolved as asked.
- **f10.** A player who moves the heavy entry to another hour, deletes
  it, or moves the same `CALL` to another node, has not moved the
  computation (or has stopped the agency's roll-up); the feedback says
  so. The incident check is unaffected (16.3). The report is judged as
  if nothing had changed.
- **f9.** Unscheduling the job and dropping the copies makes its check
  read fixed; the GM judges the proposal, and names the unrequested
  change.
- **f7.** Editing `rpt.close_day()` on `reporting` is possible, and so is
  running it by hand with `CALL`, a run outside the schedule, which the
  rules forbid as they forbid triggering any job; a run so made can
  make the check read fixed, which the GM does not take as the
  resolution.
- **Running any job by hand** (a `CALL`, a `cron.alter_job` to the next
  minute, a crontab entry rescheduled to run now) is the same overstep on
  any node: moving a fixable job's time is the players' lever, running
  one outside its schedule is not.

The access model lists this as a known gap.

## 17. Definition of done

1. `scheduler` 0.2.0 as in 7.1 and `postgres` 0.4.0 as in 7.2, with GM
   and player documentation, validators and measured footprints;
   `postgres` 0.4.0's new packages through the dependency checks, the
   project's technology record up to date.
2. The format changes of section 6 in `formats.md`, the templates, the
   loader and the `scenario-format` skill, the placement guideline
   included.
3. The four purposes in `purposes/`, complete by the format skill:
   `purpose.yaml`, material, a check per invariant, GM notes.
4. The shop domain in `domains/shop/`, its classification complete.
5. The ten new catalogue faults of 16.2, each with injection, aging
   minimum, sealed check and solvability description; the governance
   check set G1 to G4.
6. The new scenario, complete by the format skill, its data policy
   written, its scenario document generated.
7. `gmctl`, the loader and render as in section 14.
8. The existing scenarios re-pinned and deploying (16.4); every
   existing fault's `applies_to` carrying the new versions.
9. The GM skill and the scenario document skill updated as in section
   14.
10. The release gate of section 18 passed.

## 18. The release gate

No aged run: an aged run is a one-off check, none is planned before
v1.0 ("it takes too much time"). v0.4's gate has the smoke tests, the
rehearsal and the timer-fired early check, and adds:

1. **Smoke tests** on one host and on armenelos plus the VPS, every
   fault planted at once (a test harness, never a game), every scheduler
   key and job running. On the two hosts, `reporting` is mapped to
   armenelos; `fit` refuses the VPS for it.
2. **Every purpose fault through its whole cycle** in a smoke run: the
   fault planted; its job moved to run within two minutes (an edit of
   `jobs.yaml` and a reload, as a player may; the harness does it on a
   report-only node too); the check read present; the acceptance fix
   applied, the check read too soon; the job moved again, the check read
   fixed. Frequent jobs need no move. f4's cycle also moves the
   producer's invoicing, its witness; f5's passes `--since`.
3. **Every definition fault** (f6, f9) read present, then fixed after
   its acceptance fix.
4. **The unfaulted scenario passes G1 to G4**, proving the baseline
   obeys its own policy.
5. **f10 calibrated and run on armenelos only, never on a shared host**:
   the calibration of 16.3, then a smoke run planting the incident, its
   check reading present, PostgreSQL recovered, s6, `sshd` and `cron`
   untouched.
6. **The rehearsal**, about two hours unattended on armenelos plus the
   VPS with the aging minimum capped by the harness: its planned
   hand-over chosen so the hourly and quarter-hour jobs, with the peak,
   run inside its two hours; `start-load`, a scheduled `inject --at`, the
   early check fired by the host's timer, a scheduler killed and
   resuming, the hand-over check and snapshot, a restart; the memory of
   every node measured, `reporting`, `bi`, `crm` and `gateway` included;
   the trace's growth per hour measured and extrapolated over the
   sixteen-hour aging, stated as an extrapolation. It runs without f10,
   by a harness-only override, since f10's job runs at 03:00, outside
   the rehearsal's window; item 5 proves it.
7. **Known limits, named** in the release notes: the nightly close
   running at its story's time; the trace's growth over a full aging
   (extrapolated, not observed); hosts and timers through a night; f10
   within a real aging.

## 19. For the build plan

What the build plan must carry, so it can be written without
rediscovery:

- **Brick bumps**: `scheduler` 0.2.0 (7.1) and `postgres` 0.4.0 (7.2),
  every change to either folding into its unreleased version.
- **Re-pins**: `tarnbeck-outdoor-shop` to `postgres` 0.4.0 and
  `scheduler` 0.2.0; `bookshop-new-server` and
  `fernway-clinics-monitoring` to `postgres` 0.4.0; every fault applying
  to `postgres` given 0.4.0, every fault applying to `scheduler` given
  0.2.0, in `applies_to`; v0.3's smoke tests rerun unchanged on the new
  versions.
- **Dependency checks** by the security advisor for `postgres` 0.4.0's
  new packages, `postgresql-18-cron` from the PostgreSQL apt repository
  and Debian's `cron` with what it pulls in: a preflight on the
  candidate versions before the chunk that changes the image, a
  post-change check on the resolved versions after it lands, `.tech`
  updated. `scheduler` 0.2.0 adds no package.
- **The `scenario-format` skill** updated after `formats.md`: the
  purpose and domain templates and completeness rules, `governance:`,
  the new fault fields, `seed.optional` and `crontab_roles`, the
  placement guideline, a second instance's exporter. Then the scenario
  document skill and the GM skill.
- **`gmctl fit` refusing shared hosts**: the `shared` mark in the
  playground's host declaration, the VPS declared so, the fault field,
  the refusal naming the mapping to change.
- **`load-data` steps**: the customer's zone and offset as `psql`
  variables; each user mapping's password from its remote role's
  secret; the GM check role's read policy on `pg_cron`'s two tables; the
  mapping-roles function; `CONNECT` for the GM check role on every
  instance's databases.
- **`render`**: `{{customer_timezone}}` in scheduler seed files and the
  seed `postgresql.conf`; a crontab's hours shifted; `crontab_roles`'
  secrets mounted.
- **`check-psql`** reaching another instance; every database node of a
  scenario with `governance:` admitting the GM check role from the game
  network.
- **The governance check set** G1 to G4, shared by the governance
  faults' checks.
- **The harness**: moving a job in a smoke cycle (on report-only nodes
  too); `--since` in f5's cycle; f10's calibration and smoke run on
  armenelos only; the rehearsal's override leaving f10 out.
- **The out-of-memory victim** (`PG_OOM_ADJUST_*` in the run script)
  before f10's calibration, which runs early in the build, on armenelos
  only; a shortfall goes back to the owner before anything is reshaped
  (16.3).
- **No data preflight**: the project keeps no data register, and every
  scenario's data is synthetic.

## 20. Grounding: what exists and what is at risk

Read on `main` after v0.3's release (6d6abb1), and in the drafts'
grounding on v0.3's last wave:

- **The scheduler runs fixed-time jobs** from `jobs.yaml`, one key on one
  connection; a run still going when the next is due is skipped, and
  nothing missed is replayed. Its log already records `run job=… key=…
  phase=start` and `phase=end status=ok rows=… ms=…` (or `status=error
  sqlstate=…`), `skip` lines and `reload status=ok`, which the
  wrong-time-zone check reads; `/run/scheduler/loaded` holds the digest
  of every file the program loaded. A node may have jobs and no stream.
  A builder only returns statements; nothing moves rows between
  databases.
- **Roles**: the `scheduler` brick declares `producer` and `consumer`;
  the loader's role list already has `transformer`.
- **`check-sql`** (scheduler) reaches any database node over the
  network; **`check-psql`** (postgres) connects over the local socket
  only. Governance checks across instances need the change of 7.2.
- **`postgres` is fixable only** (`bricks/postgres/brick.yaml`), and
  stays so: the agency's instance is report-only by the story (16.5).
- **Every seed file a brick declares is required** of every node using
  it: the optional `crontab` is a loader change.
- **One definition per brick**, a pin must match it: hence every re-pin.
- **The `postgres` container survives PostgreSQL**: s6 is PID 1 and
  restarts a dead postmaster; the health check needs only `sshd` once
  PostgreSQL has accepted connections. No out-of-memory tuning today; the
  capabilities exclude `SYS_RESOURCE`.
- **The customer's time zone** reaches only the bastion's seed files
  today (`render`); databases run in UTC.
- **The bastion's password file** holds `dba`'s password for any host,
  so a second instance needs no bastion change.
- **`fit`'s hosts** are declared as `--host <name>[,manager],…`, with no
  shared mark today.
- **PostgreSQL hides user mappings' options** from a non-superuser that
  is neither the mapped role nor the server's owner: hence the function
  of 11.6.

At risk of disruption:

- the scheduler program (script runs in worker threads beside v0.3's
  tasks), under every v0.3 scenario with scheduler nodes;
- the `postgres` image and start-up (two packages, a third s6 service,
  the run script's environment), under every scenario;
- the loader (optional seed files, new sections), under every scenario;
- render's shifting, extended to a crontab;
- memory on armenelos: the new scenario reserves about 1.85 GB, and
  f10 deliberately exhausts a node's memory there.

## 21. Architectural decisions and their reasoning

- **Purposes, not technology bricks**: the milestone's value is what the
  data is for and how that goes wrong; technologies multiply bricks
  without adding audit surface a purpose does not already bring.
- **Consumers modelled by their trace**: every check the owner named
  (duplicates, ill-appropriate sending, "were we truly doing this") is
  judged on the trace, so consumer software would add footprint and no
  evidence.
- **The scheduler extended, not forked**: one runner keeps one log
  format, one reload, one way to move a job, and the players' existing
  knowledge; the script is a fifth repository form beside the builder,
  on the same trust line.
- **No password in a script**: the runner opens the connections from the
  hidden schedule, so the players see roles, not secrets, as they do
  for every other job.
- **Several instances, each a `postgres` node**: reuses the GM check
  role, the exporter, monitoring and the GM's knowledge; the reporting
  database an instance because governance's real separations (settings,
  audit, failure) are per instance.
- **A scenario picks the movement method per flow**: each method is an
  audit surface of its own, and real companies mix them.
- **Jobs on a database node in the container, systemd later**:
  `pg_cron` and Debian's `cron` fit the brick's s6 model; systemd needs
  a full init, which only the virtual-machine nodes of the later
  provider layer bring.
- **Placement judged by where the computation runs**: a procedure
  computes where it is called, whoever schedules it; the guideline and
  f10's expected recommendation follow from it.
- **Real time only, realistic cadences**: the only consistent clock;
  sub-daily jobs make fixes visible within a game, daily ones are moved
  by the players, weekly and monthly ones wait.
- **Checks judge runs since a moment, with witnesses**: a daily job
  cannot be judged by a trailing window, and a clean run proves nothing
  unless it could have failed; triggering a job to predict would break
  "nobody touches the load".
- **The customer's zone in a settings row, databases in UTC**: every
  timestamp stays real and the logs read as they always have; faults are
  written relative to the customer's zone so none vanishes at a shift of
  0.
- **Governance checked on the live catalog, the game's roles outside
  it**: the checks verify what is enforceable, and the policy may say
  more, as a real policy does.
- **Another party's database report-only by the story, not the brick**:
  a write policy could protect a database node's files and wrappers but
  never its contents against the players' superuser; the answer key and
  the feedback carry the mandate, as they would for a real auditor told
  whose system is whose, at no brick cost.
- **A real incident, never forged**: the evidence must come from the
  system; an out-of-memory kill placed at night, verified after it
  happens, and kept off shared hosts.
- **No aged run at the gate**: it costs a day; the smoke cycles, the
  rehearsal and named limits cover what an aged run would show, except
  what the limits say.

## 22. Deferred items, open questions and points left to the build

**Deferred** (section 2 lists the scope): finance; round trips; domains
beyond the shop, their composition, producer profiles and size; the
governance brick changes (pgaudit, TLS) and richer rules; systemd timers
and the provider layer; the undersized transformer; brick options;
weekly and monthly purposes.

**The drafts' other candidate faults**, recorded for later versions
(v0.4 builds the scenario's ten only):
the rerun double count, the script's non-atomic watermark, the script
swallowing errors, the foreign-data mapping for `PUBLIC`, the foreign
server owned by a reader, the open `SECURITY DEFINER` procedure, the
hidden `pg_cron` job on its own, the `pg_cron` job running as superuser,
credentials in a crontab entry, a stale crontab target, lost cron
output, a database-node job at the peak, the dashboard's fan-out, the
wrong lead segment, the duplicated leads, consent ignored at sending,
another customer's order in a mail, the silently disabled shipped-notice
job, an unmapped trigger code, an overlapping declaration window, a
deadline in the wrong zone, an oversharing declaration, the foreign
schema imported with personal data, a script's source role too broad,
a reader allowed through `PUBLIC`, statement logging writing personal
data. Credentials written by render into a seed file, which two of them
need, are not built.

**Open questions carried**, still the owner's:

- Brick changes for governance (pgaudit, TLS): none in v0.4 by default,
  to be ruled with v0.5's regulated domains.
- Whether a policy may itself be wrong, as starter documentation
  carrying a fault.
- Which engine versions come first beyond PostgreSQL, and how upgrade
  scenarios fit the budget; whether dbt ever comes.
- Promoting a purpose built for one scenario into the catalogue, and
  through which review.
- The aging technique beyond real time, which a monthly purpose would
  need.

**Left to the build**, to settle without changing behaviour:

- every footprint, the new nodes' starting sizes, and the trace's growth
  per hour, by measurement;
- f10's backfill window, set from the calibration of 16.3;
- the exact gateway schedule (its acknowledgement delay, its outage's
  moment, how the unacknowledged one in fifty is chosen);
- the timeline moments of f2 and f8 within the aging, each before the
  hand-over and covered by the instance's aging minimum;
- the `etl_runs` columns each job fills, and the payload schemas of the
  two outboxes;
- the mapping-roles function's name and the read policy's form;
- where the governance check set lives and how a fault's check calls it.
