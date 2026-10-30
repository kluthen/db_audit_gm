# v0.4 — purposes: side usage and transformations

Status: draft v3. No master spec. Direction recast on 2026-10-28 (D190),
revising D47's "transformers" for this version; a first cut of data
governance added the same day (D191), and the shared business data
model made the first business domain (D192). Its release gate has no
aged run (D193). Worked into draft documents on 2026-10-30 (below): no
engine beyond PostgreSQL (D194), no mail sink (D195); the owner's
veterinary clinic placed in v0.5, two of its pieces borrowed here as
test cases (D196); the pushed obligation added as a purpose kind on the
owner's word. Ruled the same day: four purposes (D197), the reporting
database an instance of its own (D198), realistic cadences under real
time (D199), the release gate's purpose cycle (D200); brick changes for
governance held for v0.5 by default (O118). The owner's technology
direction the same day: several PostgreSQL instances, data moved mainly
by Python transformer scripts the scheduler runs, `postgres_fdw` one
method among others (D202, D203), nodes sized by role (D204); then
jobs on a database node, `pg_cron` and a cron daemon in `postgres`
0.4.0, systemd timers later (D206).

## Documents

| Document | Purpose | Status |
|---|---|---|
| [purposes.md](purposes.md) | The purpose as an artefact: layout, `purpose.yaml`, how a scenario uses one, faults attached to purposes, instances and node sizing, the job runner and the transformer script, moving data between instances, cadence under real time, the customer's time zone in the data | draft v4 |
| [purpose-catalogue.md](purpose-catalogue.md) | The proposed purposes, each with its jobs, trace and invariants: sales reporting, win-back leads, customer mailing, export declarations (a pushed obligation); finance held; the clinic's reporting as a stress test | draft v4 |
| [shop-domain.md](shop-domain.md) | The shop as the first domain: the format v0.4 settles, the data-model changes the invariants need, roles, producer changes | draft v2 |
| [governance.md](governance.md) | Classes, where the rules are stated, the database-versus-instance boundary, checks G1 to G4 (G3 across instances, scripts and `pg_cron` jobs), "fixed", the policy, brick changes | draft v4 |
| [database-node-jobs.md](database-node-jobs.md) | Jobs on a database node: `pg_cron` and a cron daemon in `postgres` 0.4.0, how each runs and is enabled, what players see, scenario pins, the placement guideline, the dependency check due | draft v1 |
| [candidate-faults.md](candidate-faults.md) | Faults breaking each purpose's invariants, the movement methods (database-node jobs included), placement and the governance rules | draft v3 |
| [checks.md](checks.md) | Invariant checks judged by runs since a moment, witnesses, pushed obligations, runs of a database-node job, definition checks, `gmctl` changes, the release gate | draft v4 |
| [scenario-sketch.md](scenario-sketch.md) | A first v0.4 scenario: story, topology and sizing, ten fault instances (one through a hidden `pg_cron` job), issues | draft v4 (sketch) |

The sections below are the direction as set on 2026-10-28; where a
draft refines them, the draft is current.

## Goal

In the owner's words (D190): "what i expect from this step is to
elaborate side usage and transformations. Likely, BI settings (capturing
daily information production, transforming it into leads, etc),
computation of reports, mailing, etc. These bricks will mostly be about
purpose more than anything."

The milestone is "bricks of why and bits of hows more than true tech
bricks": what the customer's data is *for*, and as little technology as
that needs. D47 set v0.4 as transformer bricks "using various tech: plain
scripts (Python or otherwise), dbt-based, etc."; the transformations
stay, as the jobs of purposes, while the variety of technologies no
longer leads the milestone.

## The purpose

A new catalogue artefact beside bricks, faults and scenarios. "Purpose"
is a working name (O104). A purpose is:

- **its jobs**: for each, its source, its target, what it computes and
  when it runs, all run by a generic job runner, the "bit of how"
  (D203);
- **the trace** it leaves (below);
- **the invariants** that must hold between the trace and the source;
- **the faults** that break those invariants.

Faults attach to purposes as well as to bricks. The format needs a
purpose definition, with a template and completeness rules: first in
[formats.md](../../formats.md), then in the `scenario-format` skill and
the scenario document (O104).

## Consumers are modelled by their trace

There is no mailer, BI tool or finance application. In the owner's
words: "mailing is but a specific consummer in a way. we may not need a
complete mailer in the end", and the "same with dashboards and more
admin / finance oriented side of a business". A consumer exists only
through what it leaves behind:

| Trace kind | Examples |
|---|---|
| Outbox rows | mail, exports, webhooks, lead pushes |
| Published results | KPI tables, report files, period figures |
| Definitions | a dashboard's query, a job's configuration |

Definitions are checked like v0.3's `seed-file` faults. Whether a real
mail sink is ever needed was O110, closed by D195: the outbox is
enough.

## Checks

A purpose's checks are `gm_check` invariants over the trace against the
source. Examples:

- duplicates per (recipient, campaign);
- sending to opted-out or out-of-segment recipients, or someone else's
  data in a payload;
- `sent_at` outside the allowed hours in the recipient's local time;
- stale input, or zero rows processed;
- double counting, or a day boundary in the wrong time zone;
- finance reconciliation: invoices against orders and payments, a
  balanced ledger, a closed period left unmodified, refunds in the right
  period, operational totals equal to reporting totals.

**"Fixed" means no new violation since the fix.** Past violations stay
in the trace as evidence. A check exits 3, "too soon to tell", until the
job has run again since the fix, then 0 or 1, as v0.3's sealed checks
do. How a check learns when the fix happened is part of O104: v0.3's
behavioural checks judge a trailing window and are never told.

Two consequences of real time:

- A daily job runs once or twice in a sixteen-hour aging, and nobody
  triggers the load or a job during a game (D131). A fix to a daily job
  can stay "too soon to tell" past the end of a four-hour session,
  unless the players move the job's run, as they may move v0.3's
  fixed-time operations (D116). Weekly and monthly purposes are out of
  v0.4 (D199; O22).
- A check comparing a reporting database with its source reaches both,
  as the GM check role on each (proposed), as v0.3's duplicates check
  reaches the database from the producer (D185).

## Technology

Minimal (D190), as the owner set it on 2026-10-30 (D202): "there may be
multiple postgresql instance, on mulitple distinct machine (node in the
swarm). data transit between those instance may occurs through fdw, but
more honestly i expect independent python script with a scheduler (so
we may probably reuse the scheduling block we have already, just attach
the script in there)."

- **The job runner**: v0.3's `scheduler` brick, extended, no fork:
  fixed-time jobs as today, plus **transformer scripts**, Python files
  in the repository a job calls with several connections, and the
  `transformer` role; `scheduler` 0.2.0 (D203;
  [purposes.md](purposes.md#the-job-runner-d203)).
- **Several PostgreSQL instances**, each a `postgres` node of its own
  (D202), which reuses `gm_check`, the exporter, monitoring and the GM's
  knowledge; v0.4's scenario has two, the shop and reporting (D198).
- **Moving data between instances**: mainly a transformer script; also
  SQL through `postgres_fdw` foreign tables, or a stored procedure doing
  it, run from a producer, a transformer, or a job; a scenario picks per
  flow, and each method is an audit surface of its own (D202;
  [purposes.md](purposes.md#moving-data-between-instances-d202)).
- **Jobs on a database node** (D206): `pg_cron`, and a cron daemon
  beside PostgreSQL in the container, both optional per node in
  `postgres` 0.4.0; systemd timers later, with the virtual-machine nodes
  after v1.0 (D205). Light, well-scheduled work belongs there, heavy or
  procedural work on a transformer node (proposed; O131;
  [database-node-jobs.md](database-node-jobs.md)).
- **Nodes sized by role**: each distinct producer on a node of its own,
  as small as it runs; transformer nodes larger where volume needs it
  (D204). An undersized transformer is a later fault (D204, D205).
- **Another engine** (columnar or other) only if a purpose truly needs
  one. In the owner's words: "we may have to introduce other database at
  this step despite what i've said. We shall see." None does: D194.
- No dbt or second transformation technology is planned (O52).

## The shared business data model: the shop domain

The business data the source database holds, and the data load and the
producers write (orders, customers, payments, refunds, consent, time
zones), becomes shared infrastructure: every purpose reads it, and its
invariants are stated against it. It is probably v0.4's main technical
work (O108).

It is the first **domain** (D192; working name): a reusable catalogue
unit made of a business data model, producer profiles, common scheduler
scripts and input types, and the purposes that fit it
([v0.5](../v0.5/README.md#domains)). v0.4 ships one domain, the shop,
structured so that more can be added; v0.5 adds the others. The shop
starts from v0.3's `tarnbeck-outdoor-shop`, which already is one: its
data load creates customers, products, orders, order lines, delivery
events and a daily sales roll-up, with a web-shop role and a back-office
role, and its producer and consumer carry a shop's traffic. v0.1's
`bookshop-new-server` has a shop's schema too, with no traffic.

How much of the domain format v0.4 must settle, so that v0.5 adds
domains without restructuring the shop, is O111. The shop's data model
also carries the classification of its data (below, O115).

## Data governance (D191)

In the owner's words: "It might also be a good opportunity to introduce
data governance rules as well (some data NEED to be in distinct
database, with distinct settings, etc)." A first cut sits in v0.4
because it is coupled to purposes.

This is the customer's governance, part of the game's world: the rules
the fictional company states for its own data and its own database
roles. It is not the game's access model, which says who plays and what
the players may reach ([planes-and-access.md](../../planes-and-access.md)),
and not a governance of this project's data: every scenario's data is
synthetic.

### Classification and rules

The scenario declares data classes, for example personal, payment,
health or other special category, and regulated lab records. Each class
has rules:

- the database it must live in;
- required settings: TLS, audit logging, statement-log redaction,
  retention;
- the roles that may read it;
- where it may flow.

Where the classes and rules are stated (the domain classifying its data
model, the scenario stating the rules, proposed) is O115.

"Distinct database" has two readings in PostgreSQL: another database in
the same instance, or an instance of its own. Instance-wide settings
(TLS, the logging collector, preloaded libraries such as pgaudit) need
an instance of its own; settings PostgreSQL accepts per database or per
role (`ALTER DATABASE ... SET`) do not. Rules name `node/database` and
may demand instance separation; D190's second database is an instance
of its own (D198).

### The policy the players audit

The rules are handed to the players as the company's data policy, so
they audit the system against a stated policy. How it is presented (a
document in the starter pack, in the story's voice, proposed) is O117.

### Governance checks

`gm_check` verifies the rules against the live system: the catalog,
settings, roles and grants, and where a class's columns are present.
These are definition checks, judged on the effective live state as
sealed checks are, the same model as a purpose's definitions.

The rules govern the customer's roles. The game's own roles (the
players' superuser `dba`, `postgres`, the GM check role with
`pg_read_all_data`, the exporter's `monitoring` role) would break any
"who may read" rule, and are outside the policy (proposed; O116).

### The coupling to purposes

Purposes move data; governance says where it may go. The most realistic
governance fault is a transformation that copies personal or payment
data into the BI database, or an outbox that carries health data. A
purpose fault and a governance fault can be one event seen from two
angles: the copied column is a definition a governance check sees, the
payload in the outbox a trace a purpose check sees.

Which angle judges "fixed" matters. A purpose is fixed when there is no
new violation since the fix, past violations staying as evidence; a
definition check fails until the live state complies, so fixing a
copied column means removing what was copied as well as stopping the
flow. What "fixed" means for a governance fault is O119.

The shop's own grants show the coupling already: `tarnbeck`'s
back-office role reads the customers' names and e-mail addresses. A
policy that keeps personal data out of reporting makes that a finding,
unless the policy allows the back office to read it.

### Caveats

- Only rules a check can verify are enforced. Others, such as encryption
  at rest, may be stated in the policy but not checked (O116).
- Some rules need new brick capabilities: pgaudit changes the
  `postgres` image, a dependency change with its own check; TLS needs
  certificates, and the `postgres` brick configures none today: none in
  v0.4, by default (O118).
- Distinct databases on instances of their own mean more instances per
  scenario, so more memory against the playground's budget: about
  256 MB for v0.4's reporting instance (D198).

### v0.4's first cut

Classification, plus allowed locations and flows (which checks exactly:
O116). Richer rules (settings, audit trails, retention) grow with the
regulated domains of v0.5 ([v0.5](../v0.5/README.md#domains)).

## In scope

- The purpose as a catalogue artefact, its format, template and
  completeness rules (O104).
- Four purposes (D197): P1 sales reporting, P2 win-back leads, P3
  customer mailing, P5 export declarations (a pushed obligation);
  finance (P4) held for v0.5
  ([purpose-catalogue.md](purpose-catalogue.md)).
- The job runner: v0.3's `scheduler` extended with transformer scripts
  and the `transformer` role, `scheduler` 0.2.0 (D203).
- Several PostgreSQL instances (D194, D202), the reporting database an
  instance of its own (D198); data moved between them by transformer
  scripts, or by SQL or stored procedures over `postgres_fdw` (D202).
- Nodes sized by role: each producer on its own small node, transformers
  larger where volume needs it (D204).
- Jobs on a database node: `postgres` 0.4.0 with `pg_cron` and a cron
  daemon, each optional per node; every scenario with a `postgres` node
  re-pinned to 0.4.0 (D206).
- The shared business data model as the first domain, the shop,
  structured so that more can be added (O108, O111; D192).
- Faults attached to purposes, and their checks over the trace.
- Data governance's first cut (D191): data classes, the allowed
  locations and flows of each, the policy handed to the players, and
  `gm_check` definition checks of the rules a check can verify (O115 to
  O119; D198).

## Out of scope

- Real consumer software: a mailer, a BI tool, a dashboard application,
  a finance application, a mail sink (D195).
- Technology bricks for their own sake, dbt among them (O52).
- Database engines other than PostgreSQL stay beyond v1.0 (D47) unless a
  v0.4 purpose truly needs one; none does (D194).
- A sped-up clock, a forged history, time compression (D114, D132; O22);
  weekly and monthly purposes (D199).
- Domains other than the shop: v0.5 (D192).
- systemd timers on a database node: with the virtual-machine nodes
  after v1.0 (D205, D206).
- Governance rules beyond classification, locations and flows (required
  settings, audit trails, retention): they grow with v0.5's regulated
  domains (O118, defaulted).

## Depends on

- v0.1.
- v0.3: the `scheduler` brick the job runner starts from, real-time
  aging, the GM check role and its reserve, sealed checks with "too soon
  to tell", `seed-file` faults, data flowing into the source database.
- v0.2: monitoring and the exporter, for the second database and the
  jobs.

## Release gate

v0.4's definition of done is written with its master spec. Its release
gate has no aged run (D193): it relies on the smoke tests, the
rehearsal and the early check fired by the host's timer
([roadmap](../README.md#release-gates)). For purposes this means:

- Every purpose fault is taken through its whole cycle in a smoke run:
  present, then too soon after the fix, then fixed, its job moved as a
  player may (D116) (D200).
- The rehearsal's planned hand-over puts the hourly and quarter-hour
  jobs inside its two hours; the trace's growth over a full aging is
  extrapolated from its per-hour figures and stated as such; what no
  gate shows is named as a known limit (D200;
  [checks.md](checks.md)).

## For the build plan

Items the build plan must carry when it is written, noted as they
arise:

- A security-advisor dependency check for `postgres` 0.4.0's new
  packages, `postgresql-18-cron` (PGDG) and Debian's `cron`: preflight
  before the chunk that changes the image, post-change after, `.tech`
  updated (D206; [database-node-jobs.md](database-node-jobs.md)).
- Every scenario with a `postgres` node re-pinned to 0.4.0, and every
  fault applying to `postgres` given 0.4.0 in `applies_to` (D206).
- The cron daemon's faults taken through their cycle in a smoke run,
  since the first scenario uses none (proposed).

## Questions due in this version

- O104: the purpose format.
- O108: the shared business data model.
- O111: the domain format, the part v0.4 must settle for the shop.
- O115: the governance format.
- O116: which governance rules are checked in v0.4.
- O117: how the player-facing policy is presented.
- O118: brick changes for governance (pgaudit, TLS); defaulted to none
  in v0.4, held for v0.5 unless the owner objects.
- O119: what "fixed" means for a governance fault.
- O122: the customer's time zone in the data and the jobs.
- O124: the moment a purpose check judges from.
- O125: monitoring the second database, and any further instance.
- O131: the placement guideline for jobs on a database node.
- O11: technologies and versions, narrowed by D190.
- O22: scheduled jobs under real time; its v0.4 part settled by D199.
- O52: the dbt toolchain, not planned for v0.4.
- O25: promoting purposes built for one scenario into the catalog.
