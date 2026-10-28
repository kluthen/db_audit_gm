# v0.4 — purposes: side usage and transformations

Status: draft. No master spec. Direction recast on 2026-10-28 (D190),
revising D47's "transformers" for this version.

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
- **Another engine** (columnar or other) only if a purpose truly needs
  one. In the owner's words: "we may have to introduce other database at
  this step despite what i've said. We shall see." (O106)
- No dbt or second transformation technology is planned (O52).

## The shared business data model

The business data the source database holds, and the data load and the
producers write (orders, customers, payments, refunds, consent, time
zones), becomes shared infrastructure: every purpose reads it, and its
invariants are stated against it. It is probably v0.4's main technical
work (O108). It overlaps v0.5's library of common schemas
([v0.5](../v0.5/README.md)).

## In scope

- The purpose as a catalogue artefact, its format, template and
  completeness rules (O104).
- Two or three purposes (proposed; O107), for example a BI rollup into a
  reporting database, lead extraction, and a mailing job to an outbox.
  Reports, dashboards and finance could follow, or one of them could
  replace one of these.
- The job runner (O105).
- The second database, PostgreSQL by default (O106).
- The shared business data model (O108).
- Faults attached to purposes, and their checks over the trace.

## Out of scope

- Real consumer software: a mailer, a BI tool, a dashboard application,
  a finance application (a mail sink: O110).
- Technology bricks for their own sake, dbt among them (O52).
- Database engines other than PostgreSQL stay beyond v1.0 (D47) unless a
  v0.4 purpose truly needs one (O106).
- A sped-up clock, a forged history, time compression (D114, D132; O22,
  O109).

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
- O11: technologies and versions, narrowed by D190.
- O22: scheduled jobs under real time; not moot, its v0.4 part is O109.
- O52: the dbt toolchain, not planned for v0.4.
- O25: promoting purposes built for one scenario into the catalog.
