# v0.4 — purposes: side usage and transformations

Status: draft. No master spec. Direction recast on 2026-10-28 (D190),
revising D47's "transformers" for this version; a first cut of data
governance added the same day (D191), and the shared business data
model made the first business domain (D192).

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
  when it runs, all run by a generic job runner, the "bit of how" (O105);
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
mail sink is ever needed is O110; the current view is no, the outbox is
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
  fixed-time operations (D116). Weekly and monthly purposes are further
  out still (O109, O22).
- A check comparing a reporting database with its source reaches both,
  as the GM check role on each (proposed), as v0.3's duplicates check
  reaches the database from the producer (D185).

## Technology

Minimal:

- **A job runner**: v0.3's `scheduler` brick (`queries.yaml`,
  `schedule.yaml`, and `jobs.yaml`'s fixed-time operations), extended or
  forked (O105).
- **A second database**: PostgreSQL by default, which reuses `gm_check`,
  the exporter, monitoring and the GM's knowledge.
  Whether it is an instance of its own or a database in the source's
  instance is O120.
- **Another engine** (columnar or other) only if a purpose truly needs
  one. In the owner's words: "we may have to introduce other database at
  this step despite what i've said. We shall see." (O106)
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
role (`ALTER DATABASE ... SET`) do not. Which a rule means, and which
D190's second database is, is O120.

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
  certificates, and the `postgres` brick configures none today (O118).
- Distinct databases on instances of their own mean more instances per
  scenario, so more memory against the playground's budget (O120).

### v0.4's first cut

Classification, plus allowed locations and flows (which checks exactly:
O116). Richer rules (settings, audit trails, retention) grow with the
regulated domains of v0.5 ([v0.5](../v0.5/README.md#domains)).

## In scope

- The purpose as a catalogue artefact, its format, template and
  completeness rules (O104).
- Two or three purposes (proposed; O107), for example a BI rollup into a
  reporting database, lead extraction, and a mailing job to an outbox.
  Reports, dashboards and finance could follow, or one of them could
  replace one of these.
- The job runner (O105).
- The second database, PostgreSQL by default (O106).
- The shared business data model as the first domain, the shop,
  structured so that more can be added (O108, O111; D192).
- Faults attached to purposes, and their checks over the trace.
- Data governance's first cut (D191): data classes, the allowed
  locations and flows of each, the policy handed to the players, and
  `gm_check` definition checks of the rules a check can verify (O115 to
  O120).

## Out of scope

- Real consumer software: a mailer, a BI tool, a dashboard application,
  a finance application (a mail sink: O110).
- Technology bricks for their own sake, dbt among them (O52).
- Database engines other than PostgreSQL stay beyond v1.0 (D47) unless a
  v0.4 purpose truly needs one (O106).
- A sped-up clock, a forged history, time compression (D114, D132; O22,
  O109).
- Domains other than the shop: v0.5 (D192).
- Governance rules beyond classification, locations and flows (required
  settings, audit trails, retention): they grow with v0.5's regulated
  domains, unless O116 and O118 bring one in.

## Depends on

- v0.1.
- v0.3: the `scheduler` brick the job runner starts from, real-time
  aging, the GM check role and its reserve, sealed checks with "too soon
  to tell", `seed-file` faults, data flowing into the source database.
- v0.2: monitoring and the exporter, for the second database and the
  jobs.

## Questions due in this version

- O107 (next): which purposes are in v0.4.
- O104: the purpose format.
- O105: the job runner, extending or forking the scheduler.
- O106: whether any engine beyond PostgreSQL is needed.
- O108: the shared business data model.
- O109: daily, weekly or monthly purposes under real time.
- O110: whether a real mail sink is ever needed.
- O111: the domain format, the part v0.4 must settle for the shop.
- O115: the governance format.
- O116: which governance rules are checked in v0.4.
- O117: how the player-facing policy is presented.
- O118: brick changes for governance (pgaudit, TLS).
- O119: what "fixed" means for a governance fault.
- O120: a distinct database, or an instance of its own.
- O11: technologies and versions, narrowed by D190.
- O22: scheduled jobs under real time; not moot, its v0.4 part is O109.
- O52: the dbt toolchain, not planned for v0.4.
- O25: promoting purposes built for one scenario into the catalog.
