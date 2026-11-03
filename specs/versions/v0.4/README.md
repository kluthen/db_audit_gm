# v0.4 — purposes: side usage and transformations

Status: **released 2026-11-03**: release gate passed on 2026-11-03,
G11 cleared and the smoke run's end-of-run checks left a known limit on
the owner's word ("option c, G11 ok, merge"; D313), `v0.4-w4` merged
into `main` ([release notes](#release-notes)). Master spec and access
model approved by the owner on 2026-10-30 (D215): the [master spec](master-spec.md) and its
[access model](access-model.md), consolidated from the eight drafts
below on the owner's word that v0.4 was ready, approved with every
proposal of its owner-review list as written, the list then removed.
The owner had ruled the same day on four points the consolidation
raised: the agency's database report-only by the story alone, no
report-only policy in `postgres` (D211, closing O132); the scenario's
ten faults only (D212, closing O133); f10 calibrated early, on
armenelos only (D213); the gateway's lost acknowledgements (D214).
The [build plan](../../archive/v0.4/build-plan.md), written from the master spec's
section 19, was approved the same day with κ = 3 (D216), with the
owner's rulings on the judged moment before the hand-over (D217) and on
f10's measurement without swap (D218). During wave 1 the plan took
capture W1's corrections (D219, D220), and the owner's ruling on the
data policy's way to the players amended the master spec after its
approval: `bastion` 0.4.0, the starter pack as Markdown and as a page
(D221–D223, chunk 19); then his ruling on G12 made the web front run
in every game, its home the starter-pack page (D224, D225; O134 closed,
the setup's entry point O135 for v0.6, D248), and a data file named in a seed
change was settled (D226). During wave 2 his ruling on G10 raised
`reporting`'s memory limit to 640M (D227), and chunk 11's reading of
E4's deadline was written into the master spec (D228). After wave 2
the owner ruled that a change confined to a brick's tests bumps nothing
(D229, in formats.md), settling wave 1's gate fix. In wave 3,
readings of the governance checks (D230, D231), of f7 and f9
(D239–D243) and of f1, f2 and f5 (D244–D247) were written into the
master spec, the access model and the plan. The owner then accepted
f10's normal run at 640M as measured, 327 MiB (D252, G10), and had
`separation: instance` defined now as a rule of G1 (D253, closing O140),
built by the inserted chunk 20; chunk 15b's readings of f10 (D254–D257)
and `load-data`'s last step removing the `pg_cron` launcher's start-up
failures from the server log (D258) were written into the master spec,
formats.md and the plan (v9).
At v0.4's close (2026-11-03) the build plan and four of the drafts
were archived in [archive/v0.4/](../../archive/v0.4/README.md); the
other four drafts stay here, cited by v0.5's work and holding the later
versions' candidate faults. Where a draft and the master spec disagree,
the master spec is current. Page v13.

History: direction recast on 2026-10-28 (D190),
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
0.4.0, systemd timers later (D206); the placement guideline (D207); the
first scenario given a crontab fault (D208) and an out-of-memory
incident on a database node (D209).

## Documents

| Document | Purpose | Status |
|---|---|---|
| [master-spec.md](master-spec.md) | The consolidated v0.4 specification | approved 2026-10-30 (D215); amended by D221 (`bastion` 0.4.0), D224 (the web front in every game), D226 (a data file in a seed change), D227 (`reporting`'s limit at 640M), D228 (E4's deadline clarified), then by the build's rulings (its status note), last D311–D313 (18); the contract for what v0.4 built |
| [access-model.md](access-model.md) | Who may do what in a v0.4 game; the customer's roles and data policy in the game's world | approved 2026-10-30 (D215); amended by D224 (the web front in every game) |
| [build-plan.md](../../archive/v0.4/build-plan.md) | The build: nineteen chunks in four waves, the gates G1 to G13, the release gate | v16, approved 2026-10-30 (D216–D218); built, release gate passed 2026-11-03; archived |
| [purposes.md](../../archive/v0.4/purposes.md) | The purpose as an artefact: layout, `purpose.yaml`, how a scenario uses one, faults attached to purposes, instances and node sizing, the job runner and the transformer script, moving data between instances, cadence under real time, the customer's time zone in the data | draft v4; archived |
| [purpose-catalogue.md](purpose-catalogue.md) | The proposed purposes, each with its jobs, trace and invariants: sales reporting, win-back leads, customer mailing, export declarations (a pushed obligation); finance held; the clinic's reporting as a stress test | draft v5; kept (cited by v0.5) |
| [shop-domain.md](shop-domain.md) | The shop as the first domain: the format v0.4 settles, the data-model changes the invariants need, roles, producer changes | draft v3; kept (v0.5's domain procedure's model) |
| [governance.md](governance.md) | Classes, where the rules are stated, the database-versus-instance boundary, checks G1 to G4 (G3 across instances, scripts and `pg_cron` jobs), "fixed", the policy, brick changes | draft v5; kept (cited by v0.5) |
| [database-node-jobs.md](../../archive/v0.4/database-node-jobs.md) | Jobs on a database node: `pg_cron` and a cron daemon in `postgres` 0.4.0, how each runs and is enabled, what players see, scenario pins, the placement guideline, the out-of-memory incident, the dependency check due | draft v4; archived |
| [candidate-faults.md](candidate-faults.md) | Faults breaking each purpose's invariants, the movement methods (database-node jobs included), placement (the out-of-memory incident) and the governance rules | draft v5; kept (the later versions' candidates, master spec 22) |
| [checks.md](../../archive/v0.4/checks.md) | Invariant checks judged by runs since a moment, witnesses, pushed obligations, runs of a database-node job, definition checks, `gmctl` changes, the release gate | draft v4; archived |
| [scenario-sketch.md](../../archive/v0.4/scenario-sketch.md) | A first v0.4 scenario: story, topology and sizing, ten fault instances (a hidden `pg_cron` job, a crontab fault, an out-of-memory incident), issues | draft v6 (sketch); archived |

The sections below are the direction as set on 2026-10-28; where a
draft refines them, the draft is current, and where the master spec
does, the master spec.

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
  [purposes.md](../../archive/v0.4/purposes.md#the-job-runner-d203)).
- **Several PostgreSQL instances**, each a `postgres` node of its own
  (D202), which reuses `gm_check`, the exporter, monitoring and the GM's
  knowledge; v0.4's scenario has two, the shop and reporting (D198).
- **Moving data between instances**: mainly a transformer script; also
  SQL through `postgres_fdw` foreign tables, or a stored procedure doing
  it, run from a producer, a transformer, or a job; a scenario picks per
  flow, and each method is an audit surface of its own (D202;
  [purposes.md](../../archive/v0.4/purposes.md#moving-data-between-instances-d202)).
- **Jobs on a database node** (D206): `pg_cron`, and a cron daemon
  beside PostgreSQL in the container, both optional per node in
  `postgres` 0.4.0; systemd timers later, with the virtual-machine nodes
  after v1.0 (D205). Light, well-scheduled work may run there; heavy or
  row-by-row work goes to a transformer node; heavy work on the source
  instance is the worst placement (D207;
  [database-node-jobs.md](../../archive/v0.4/database-node-jobs.md)). An out-of-memory
  incident on a database node, real and once during the aging, is a
  fault (D209).
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

v0.4's definition of done is in its [master spec](master-spec.md#17-definition-of-done), section 17, its release gate in section 18. Its release
gate has no aged run (D193): it relies on the smoke tests, the
rehearsal and the early check fired by the host's timer
([roadmap](../README.md#release-gates)). On 2026-11-03 its two-host
runs, its rehearsal and its stance check-list moved to
[v1.0 gating](../README.md#v10-gating) (D311), then its long-running
tests (D312). For purposes this means:

- Every purpose fault is taken through its whole cycle in a smoke run:
  present, then too soon after the fix, then fixed, its job moved as a
  player may (D116) (D200).
- The rehearsal's planned hand-over puts the hourly and quarter-hour
  jobs inside its two hours; the trace's growth over a full aging is
  extrapolated from its per-hour figures and stated as such; what no
  gate shows is named as a known limit (D200;
  [checks.md](../../archive/v0.4/checks.md)).

## For the build plan

Gathered, with the rest, in the [master spec](master-spec.md#19-for-the-build-plan),
section 19, and carried by the [build plan](../../archive/v0.4/build-plan.md). Items
noted as they arose:

- A security-advisor dependency check for `postgres` 0.4.0's new
  packages, `postgresql-18-cron` (PGDG) and Debian's `cron`: preflight
  before the chunk that changes the image, post-change after, `.tech`
  updated (D206; [database-node-jobs.md](../../archive/v0.4/database-node-jobs.md)).
- Every scenario with a `postgres` node re-pinned to 0.4.0, and every
  fault applying to `postgres` given 0.4.0 in `applies_to` (D206).
- The placement guideline (D207) written into the `scenario-format`
  skill, after formats.md.
- `PG_OOM_ADJUST_*` in `postgres` 0.4.0's run script, and the
  out-of-memory incident calibrated in a smoke run: the cgroup's
  `memory.peak` around a normal run and around the backfill, on a host
  with swap and one without, before the scenario's window is set
  (D209). These smoke runs run on armenelos only, never on the VPS.
- `fit` refusing to place a node whose fault needs an unshared host on a
  host the playground marks `shared` (the VPS), and the playground
  declarations marking it (D209, D159).

## Questions due in this version

Every one below except O118 and the later ones is settled by the
master spec, approved on 2026-10-30 (D215); O132 and O133, raised by
the consolidation, were ruled the same day (D211, D212).

- O104: the purpose format; closed by D215.
- O108: the shared business data model; closed by D215.
- O111: the domain format, the part v0.4 must settle for the shop;
  that part closed by D215, the rest open for v0.5.
- O115: the governance format; closed by D215.
- O116: which governance rules are checked in v0.4; closed by D215.
- O117: how the player-facing policy is presented; closed by D215.
- O118: brick changes for governance (pgaudit, TLS); defaulted to none
  in v0.4, held for v0.5; closed for v0.5 by D250 and D261 (both always
  available in `postgres`).
- O119: what "fixed" means for a governance fault; closed by D215.
- O122: the customer's time zone in the data and the jobs; closed by D215.
- O124: the moment a purpose check judges from; closed by D215.
- O125: monitoring the second database, and any further instance; closed by D215.
- O132: a report-only database node; closed by D211 (story only).
- O133: which catalogue faults v0.4 builds; closed by D212 (the ten).
- O11: technologies and versions, narrowed by D190.
- O22: scheduled jobs under real time; its v0.4 part settled by D199.
- O52: the dbt toolchain, not planned for v0.4.
- O25: promoting purposes built for one scenario into the catalog.

## Release notes

v0.4, release gate run on `v0.4-w4` on 2026-11-03, on armenelos alone,
the VPS drained throughout (D311): items 1 to 11, 14, 15 and 17 passed
or stand as run, items 12 and 13 moved to [v1.0
gating](../README.md#v10-gating) (D311), item 16 (G11) cleared by
the owner on 2026-11-03 ("G11 ok"). One fix at the gate, documentation
only (below). Released on 2026-11-03, `v0.4-w4` merged into `main` (56b7471) on
the owner's word (D100): `postgres` 0.4.0, `bastion` 0.4.0, `scheduler` 0.2.0 and
`pgbouncer` 0.1.1; `prometheus`, `postgres-exporter` and `grafana` stay
at 0.2.0, unchanged.

### What v0.4 delivers

- **Purposes**, the side uses of a business's data, each a definition
  in `purposes/` (`purpose.yaml`, material copied into a scenario at
  design time, a check per invariant, GM notes): `shop-sales-reporting`
  (pulled: an hourly Python roll-up and a nightly close into another
  instance, R1 to R5), `shop-winback-leads` (transformed in place, L1 to
  L3), `shop-customer-mailing` (pushed to a mail provider through an
  outbox, M1 to M5), `shop-export-declarations` (a pushed obligation to
  a customs gateway, acknowledged or escalated, E1 to E4). Checks judge
  a purpose's runs or triggers since a moment (`judges:`, `--since`,
  the judged moment raised to the runner's last reload, D217).
- **The shop domain** in `domains/shop/`: schema, load, producer
  fragments and a classification of its 99 columns (17 personal, 5
  customer-linked, 77 internal, the materialized view included).
- **Data governance**: `governance:` in `scenario.yaml` (classes,
  locations, readers, outbound flows, `separation: instance`), the data
  policy handed to the players as `player/data-policy.md`, and the
  governance check set G1 to G4 (`tools/gm/governance.sh`), G1 judging
  `separation: instance` (D253).
- **`scheduler` 0.2.0**: the transformer role, Python scripts as jobs
  with several connections (`scripts/`), `check-runs` for the checks
  (runs since a moment, the last reload, the next run), TCP keepalives on
  every session.
- **`postgres` 0.4.0**: `pg_cron` 1.6.8 (PGDG) and Debian's cron daemon
  on a database node, an optional seeded `crontab` with its roles'
  passwords mounted (`crontab_roles`), `gm-crontab` for the players, a
  backend as the out-of-memory victim (`oom_score_adj` +300, the
  postmaster, s6, `sshd` and `cron` at 0), `check-psql <node>` reaching
  another instance.
- **`bastion` 0.4.0**: the starter pack rendered as one page by
  `cmark-gfm` (README, story, issues, data policy, the web interfaces),
  the web front running in every game, its home that page, the tools
  password always handed over (D221–D224).
- **`pgbouncer` 0.1.1**: waits up to 30 s for its servers' names to
  resolve before starting, fixing the start-up DNS race (D305).
- **`gmctl`**: hosts declared `shared` and a fault's
  `needs_unshared_host` refused on them by `fit`; `check --since` and
  `--instance`; render shifting a database node's crontab and writing
  `cron.timezone`; `load-data`'s new steps (the roles' and user
  mappings' passwords, the GM check role's read policy and mapping-roles
  function, `pg_cron`'s start-up failures removed from the server log,
  D258).
- **The formats** (formats.md v22, the templates, the loader, the
  `scenario-format` skill): purposes, domains, `governance:`,
  `crontab_roles`, `judges:`, `needs_unshared_host`, `seed.optional`,
  the placement guideline for jobs (D207).
- **Ten new catalogue faults**: the purpose faults
  `purpose-mail-overlapping-window`, `purpose-leads-stale-consent`,
  `purpose-mail-outside-hours`, `purpose-watermark-misses-updates`,
  `purpose-etl-role-expired`, `purpose-day-boundary-wrong-zone`,
  `purpose-receiver-down-unnoticed`, the database-node incident
  `purpose-heavy-job-on-database-node` (f10, an out-of-memory kill), and
  `security-crontab-superuser` and `governance-personal-copied`; the
  nineteen earlier faults' `applies_to` carrying the new versions where
  they apply.
- **The scenario `tarnbeck-outdoor-campaign`**: the outdoor gear shop
  six months on, its data's uses gone wrong and an agency's reporting
  database: twelve nodes (two PostgreSQL instances, `db` and
  `reporting`; transformers `bi` and `crm`; the customs gateway; the
  producer, consumer, pooler and monitoring), the four purposes, the
  shop domain, a data policy; ten fault instances (four hidden; f5
  planted at `handover-5h`, f10 at `handover-12h`), issues I1 to I6
  (four fix, one propose, one report), sixteen hours of aging, 240
  minutes of play, designed for two hosts, `reporting` on host-1.
- **The existing scenarios** `bookshop-new-server`,
  `fernway-clinics-monitoring` and `tarnbeck-outdoor-shop` re-pinned;
  `bookshop-new-server`'s bastion serves the starter-pack page alone.
- **The skills**: `game-master` (purposes, governance, `--since`, the
  overstep on another party's database, f10 never re-planted),
  `scenario-format`, `scenario-document`.
- **Tests**: unit tests (854), the scheduler's own (72), seven stack
  tests, the fixtures `fixture-campaign`, `fixture-instances` and
  `fixture-v04-refusals`, `smoke-purposes.sh` (modes `smoke`, `cycles`,
  `baseline`, `f10`), `smoke-governance.sh`, `calibrate-f10.sh`.

### Release gate results

Run on `v0.4-w4` on 2026-11-03 on armenelos, the VPS `vps-5718ad52`
drained throughout and never set `active`, every Docker step under the
host lock and a sleep inhibitor. No GM session, no two-host run, no
long-running test (D311, D312). The runs counted are the wave 4 gate's
(07:35–11:19 UTC, on tree cd4bbd4; after it only specs and the gate's
documentation fix changed) and chunk
17a's (2026-11-02 to 03); the release gate added reading checks, `fit`
and short page renders.

1. **Bricks: PASS.** `scheduler` 0.2.0, `postgres` 0.4.0, `bastion`
   0.4.0 and `pgbouncer` 0.1.1: each `docs/gm.md` has the nine sections
   in order, its figures (limits, reservations, disk growth), knobs,
   parameters, interfaces and image tag as `brick.yaml` declares them,
   its supported faults as the faults' `applies_to` (the unit suite's
   `test_brick_docs`); validators present; footprints measured at rest
   by their chunks' stack tests. `postgres` 0.4.0's job-kind sections
   were not where the format skill puts them: fixed (below). G5, G6 and
   G13 cleared; `.tech` current (0b9e906: every brick at its catalogue
   version). The scenario's starter-pack page, rendered by the bastion
   image's own code from its files: README, story, issues, data policy,
   then the web interfaces.
2. **Formats: PASS.** formats.md (G2), the templates, the loader and the
   format skill carry master spec 6 and the placement guideline; the
   loader checks every definition: 7 bricks, 29 faults, 4 purposes, 1
   domain and the 4 scenarios complete, the fixtures too
   (`fixture-v04-refusals` refused by design).
3. **Purposes and domain: PASS.** The four purposes complete; every
   column of the shop's schema classed.
4. **Faults and governance: PASS.** The ten faults complete (injection,
   aging minimum, sealed check, probe); G1 to G4, G1 judging
   `separation: instance` (chunk 20's `smoke-governance.sh`, 121/0).
5. **Scenario: PASS.** `tarnbeck-outdoor-campaign` complete by the
   format skill and the loader; its data policy written from
   `governance:`, mapped on the bastion; its README matching
   `scenario.yaml` and `gm/answer-key.yaml` value for value (619 values
   read against the files, none differing; every path it names exists).
6. **`gmctl`, the loader and render: PASS**, through items 7 to 11.
7. **Existing scenarios: PASS**, at the wave 4 gate: bookshop 19/19,
   fernway 18/18, tarnbeck-outdoor-shop 26/26, unchanged smoke tests;
   every bastion healthy with its front on 8080; each scenario's page
   rendered at the release gate by the bastion image's own code,
   bookshop's with no web-interface section (D224); every
   existing fault's `applies_to` carrying the new versions.
8. **The smoke run: as run, PASS up to f8's wait.** The wave 4 gate's
   `smoke` (09:19–10:40 UTC): every fault planted at once, f1 to f7 and
   f9 present, f10 an error as designed, every moved job `ok`, every `jobs.yaml` restored byte for byte, 25 PASS 0 FAIL,
   stopped in f8's wait (D312); f8 read present with every fault
   planted in 17a's cycles run. **`fit` refuses the VPS for
   `reporting`** on the two-host declaration (armenelos, manager, 4 CPU
   / 4G / 12G; the VPS `shared`, 2 CPU / 2G / 8G): mapping host-1 onto
   the VPS is refused, "node reporting carries fault instance f10
   (purpose-heavy-job-on-database-node), which needs an unshared host,
   and would be placed on vps-5718ad52, a shared host", nothing
   written, no engine contacted; the designed mapping fits, `reporting`
   on armenelos. The two-host run: v1.0 gating (D311).
9. **The cycles: as run.** Chunk 17a's cycles run (cycles 2, 02:25–07:26
   UTC): 54 passed, 0 failed; f1 to f9 present, f10 an error as
   designed; f6, f9, f1, f2, f3, f5 and f7 (`--since`) cycled to fixed;
   f4 and f8 fixed in place, too soon; stopped at f4's wait for the
   scenario's midnight (D310). The rest: v1.0 gating (D312).
10. **Baseline: PASS.** The unfaulted scenario 32/32, G1 to G4 holding;
    `fixture-campaign` 84/84, G1 to G4 exit 0 twice, every job run.
11. **f10: PASS.** Calibrated (G10, D227, D252) and run on armenelos
    alone, the VPS drained: 23/23, present after 154 s, the backend
    killed, PostgreSQL ready again, s6-svscan, `sshd` and `cron` kept
    their pids.
12. **The rehearsal**: v1.0 gating (D311), not run in v0.4.
13. **The stance check-list**: v1.0 gating (D311), not played in v0.4.
14. **Quality command: PASS**, the wave 4 gate's run, without its
    two-host run (D311): unit 854, the scheduler's 72, syntax 165 shell,
    7 Perl, 46 Python files, seven builds, seven stack tests (below),
    `smoke.sh` 61, `smoke-monitoring.sh` 43, `smoke-scenario.sh` 19, 18
    and 26, `smoke-load.sh` on armenelos 73. The unit suite again after
    the gate's fix: 854 OK.
15. **Left for the build: PASS** (below).
16. **G11: cleared** by the owner on 2026-11-03 ("G11 ok").
17. **Release notes**: these.

### Measured figures

On armenelos (AMD Ryzen 5 PRO 8640HS, 11.3 GiB, Debian 13, Docker
29.9.1), 2026-11-02 and 03, every run single-host.

- **Per-node memory**, one-host smoke readings, within the declared
  limits. Chunk 17a's cycles run (MiB of the limit): db 221.8/1024,
  grafana 190.1/384, reporting 70.6/640, prometheus 61.7/384, bi
  33.3/384, producer 31.7/96, crm 30.6/128, consumer 30.2/128, gateway
  30.0/96, exporter 20.9/128, pooler 16.3/64, bastion 10.1/256 (cycles
  1: grafana 270.2, prometheus 136.8). The wave 4 gate's peaks: in
  `fixture-campaign` db 217M, grafana 253M, reporting 80M, crm 50M; in
  `smoke` db 203M, grafana 305M, reporting 73M, prometheus 98M; in
  `baseline` db 218M, grafana 240M. Grafana's 305M is above its 272M
  reservation, within its 384M limit.
- **f10**: chunk 9 at 512M: a normal run's `memory.peak` 299–300 MiB,
  backfills of 2 to 8 days completed, 10 days and the 30-day request
  killed; about 5.2 KB per order. Chunk 15b at 640M with 640M of swap:
  the 30-day backfill killed after 11 s (1258 of 1280 MiB), recovery in
  1 s; a normal run 327 MiB against the 320 MiB half, accepted as
  measured (D252). In the runs: `reporting`'s `memory.peak` 671092736 B
  (the 640M limit) and `oom_kill` 0 → 1 each time, present after 123 s
  (17a) and 154 s (the gate).
- **Run times**: `fixture-campaign` 2743 s, `baseline` 1664 s, `f10`
  425 s, the seven stack tests 1575 s (bastion 90, postgres 211,
  pgbouncer 120, scheduler 133, prometheus 131, postgres-exporter 103,
  grafana 119, 0 FAIL). PgBouncer resolved `db` after 5 to 7 s in every
  run, `pooler workarounds: 0` (D305).
- **`fit`** on the two-host declaration: armenelos 1.45 CPU and 1.52G
  reserved, disk 9.38G of 12G; the VPS 0.15 CPU, 240M, 1.25G of 8G. At
  12G the hand-over snapshot does not fit (15.74G); on armenelos' real
  41G it does (18.76G of 41G for `fixture-campaign`, the same
  topology).
- **Images** (`127.0.0.1:5000/dbagm/`, the gate's builds): bastion:0.4.0
  8ffc0bf43d36 185.6 MB, postgres:0.4.0 2d4f82a98130 262.3 MB,
  pgbouncer:0.1.1 137b342a9b34 182.4 MB, scheduler:0.2.0 c1ef5309474e
  170.6 MB (rebuilt at the gate on current Debian packages, no
  `bricks/scheduler` change), prometheus:0.2.0 e0bad6332958 488.2 MB,
  postgres-exporter:0.2.0 b8c644f1c94d 164.6 MB, grafana:0.2.0
  b53a718ae5c0 866.2 MB.
- **Footprints, as built**, standing until the rehearsal's figures
  (v1.0 gating, D311): each brick's `brick.yaml` and `docs/gm.md`,
  measured at rest by the stack tests (scheduler idle 17M, a transformer
  after its run 27M; postgres with `pg_cron` and cron 28.8 to 30.9MiB;
  bastion 4.9 to 5.1 MiB with the front; PgBouncer 11.2 MiB); the
  scenario's `resources` as chunk 16 set them (`reporting` 640M limit,
  256M reserved; 1.45 CPU, 1552M and 6080M reserved on host-1).

### Left for the build (master spec 22), as found

Each in its chunk's Record line, directly or by the capture it names,
and for a brick in its `docs/gm.md`:

- **Footprints and the new nodes' starting sizes**: chunks 3 and 4 (W1-y,
  W1-x; the scheduler's and postgres' "Footprint"), chunk 16 (the
  scenario's `resources`, W4); the trace's growth per hour: the
  rehearsal's, v1.0 gating.
- **f10's backfill window**: chunk 9 and G10, the thirty-day request.
- **The gateway's acknowledgement delay and its one in fifty**: chunk 11,
  `shop-export-declarations`' `gm.md` (5 to 35 s; the declarations whose
  idempotency key hashes to 0 modulo 50).
- **The gateway outage's moment, f2's and f8's timeline moments**:
  chunks 14 and 16 (the faults' `gm.md`, the scenario's schedules: the
  gateway's outage from `handover-6h` to `handover-4h`, f2's producer
  release at T0; both instances' aging minimum 11h).
- **`etl_runs`' columns and the outboxes' payloads**: chunks 5, 10 and
  11, the purposes' `gm.md`.
- **The mapping-roles function and the read policy**: chunk 7, W2-x:
  `gm_check.user_mapping_roles()`, policy `gm_check_read`.
- **The governance check set**: chunk 12, W3-a: `tools/gm/governance.sh`,
  called by a fault's check as `check_governance G1 G3`.
- **The scheduler-side means**: chunk 3b, W1-y: `check-runs` (`runs`,
  `last-reload`, `next`, `since`), in the scheduler's `docs/gm.md`.
- **The starter-pack page**: chunk 19, W1-z: `/run/web-front/www/`,
  `PAGE_ELEMENTS` in `gm-entrypoint`, a later element joining by one
  line; the bastion's `docs/gm.md`.

### Known limits

Named by master spec 18 item 7:

- **The nightly close at its story's time** (`rollup-close` at
  01:30, scenario time; f10's roll-up at 03:00): the gate's runs move a job to run
  within minutes, as a player may; a run at its own hour is not checked.
- **The trace's growth over a full aging**: neither observed nor, without
  the rehearsal, extrapolated.
- **Hosts and timers through a night**: not proven. Chunk 17a's cycles
  runs kept a smoke deployment up overnight on armenelos, under a sleep
  inhibitor, but no game aged through a night, and the early check
  fired by the host's timer is the rehearsal's (v1.0 gating).
- **f10 within a real aging**: run in its own smoke mode, not inside an
  aged game.

**Moved to v1.0 gating** ([roadmap](../README.md#v10-gating)):

- by D311: every two-host run (the scenario's smoke run on armenelos
  plus the VPS, 17a's skipped run, the wave 4 gate's two-host
  `smoke-load.sh`); the rehearsal, with its timer-fired early check and
  its figures (every node's memory, the trace's growth per hour); the
  stance check-list;
- by D312: item 9's unobserved part (f4's steps after the scenario's
  midnight, f8's fixed reading and the cycles run's clean verdict, about
  nine hours), and f8's reading in the smoke run.

Also known:

- **The smoke run's end-of-run checks** (D313): every job of every
  runner and `db`'s and `reporting`'s jobs since T0 with every fault
  planted, `reporting`'s `pg_cron` job among them, every scheduler key
  called, the full `gmctl check`, the teardown leaving nothing: not run
  in v0.4; the v1.0-gating smoke run covers it. The unfaulted `baseline`
  passes them all but `reporting`'s `pg_cron` job, which it does not
  read.
- **Two of wave 3's readings in the `fixture-campaign` run**, not
  checked by the wave 4 gate, read from its log at the release gate:
  every job's runs were all `ok` and `load-data` found `reporting`'s
  `pg_cron` launcher running, as at wave 3; the count of `08006` over
  the schedulers' logs was not taken (`bi`'s log counted 0
  connection-class errors in 17a's cycles runs).
- **f10's normal run at 327 MiB**, above the 320 MiB half of
  `reporting`'s 640M limit, accepted as measured (D252, G10).
- **`load-data`'s `pg_cron` clean-up** (master spec 14, D258): it relies
  on `[%p]` in `log_line_prefix`; a `log_filename` without a time in it
  leaves the lines, with a warning; the players see a second log file
  starting at `load-data`.

### Known gaps of the access model

All stand as [access-model.md](access-model.md) section 12 states them:

- when the players own the host, the bastion-only rule and the answer
  key's secrecy rest on trust;
- a player in the GM session can see the setup dialogue;
- credentials are shared by all players and cannot be rotated during a
  game, a restart included;
- another party's database (`reporting`) is report-only by the story
  alone: an overstep is judged in the feedback, never credited;
- customer roles' passwords are within `dba`'s reach (user mappings, a
  crontab's password file);
- the GM's connection reserve can be used up by `dba`;
- Grafana's write policy cannot be enforced, and Grafana administration
  is forbidden by rule, not prevented;
- Prometheus has no login of its own, reachable from every node;
- a fixable builder or transformer script is code run as the
  scheduler's account, and can print the schedule or its connections'
  passwords;
- the traffic can be inferred from the logs and statistics;
- the web front uses plain HTTP.

### Fixes made at the release gate

- **5120e36**: `postgres` 0.4.0's "`pg_cron`" and "The cron daemon"
  moved to their own sections after Known limits in `docs/gm.md`, and
  given sections of the same names in `docs/player.md`, as the format
  skill places a job kind's documentation; text unchanged, the image
  untouched, folded into the unreleased 0.4.0.

### Known issues

- **c-ares in `pgbouncer`** (security-advisor, 0b9e906): Debian's
  tracker lists CVE-2026-33630, -69184, -69186 open in trixie, no DSA
  yet; exposure low (names resolved on the internal overlay only).
  Proposed: watch, a rebuild picks up Debian's fix; adding c-ares to
  `.tech` awaits the owner.
- **`pgbouncer` 0.1.1's limits** (its `docs/gm.md`): a `db` replaced
  mid-game is served again about 600 s after it is healthy (the swarm
  DNS's answer lifetime), and a `db` slower than 30 s to health starts
  PgBouncer early, as 0.1.0 did.
- **The scheduler image** was rebuilt at the wave 4 gate on current
  Debian packages (c1ef5309474e, replacing 1ad76b563f81): the same
  Dockerfile, no brick change; `.tech`'s package versions were read on
  the 2026-10-30 build.
