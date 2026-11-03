# Roadmap

The versions from the first milestone to the first release and beyond, as
set out by the owner (D47), with v0.6 added on 2026-10-21 (D71). Each version has its own page; a version's
master spec lands in its folder when it is consolidated, and its page
says when the owner approves it. Everything after
v0.1 is draft.

| Version | Theme | Status |
|---|---|---|
| [v0.1](v0.1/README.md) | Settle the GM stance on one simple scenario: a static PostgreSQL database investigated for specific defects | released 2026-10-21, merged into `main` (3c852e1); working record archived in [archive/v0.1/](../archive/v0.1/README.md) |
| [v0.2](v0.2/README.md) | Monitoring and usual tooling: per-node health, PostgreSQL metrics, dashboards and alerting, log analysis; one free brick per need, chosen by footprint | released 2026-10-22: release gate passed, G10 and G11 cleared; [release notes](v0.2/README.md#release-notes); working record archived in [archive/v0.2/](../archive/v0.2/README.md) |
| [v0.3](v0.3/README.md) | Producers and consumers: ingestion, load spikes, misbehaving requests, broad queries | released 2026-10-30: release gate passed, G9 and G10 cleared; merged into `main` (cba7be3); [master spec](v0.3/master-spec.md) and [access model](v0.3/access-model.md); [release notes](v0.3/README.md#release-notes); working record archived in [archive/v0.3/](../archive/v0.3/README.md) |
| [v0.4](v0.4/README.md) | Purposes, "bricks of why and bits of hows": side usage and transformations (BI, leads, reports, mailing) modelled by their jobs, trace and invariants; a generic job runner, a second database (D190, revising D47); the shop as the first business domain (D192); a first cut of data governance: data classes, allowed locations and flows, a policy the players audit (D191) | master spec and access model approved 2026-10-30 (D215); [master spec](v0.4/master-spec.md), [access model](v0.4/access-model.md); [build plan](v0.4/build-plan.md) approved 2026-10-30 (D216) |
| [v0.5](v0.5/README.md) | Domain definition, the veterinary clinic franchise the worked example (D233): a procedure for defining a domain (D235), the clinic's domains (data models, producer profiles, scheduler scripts, purposes; D192) with its richer governance, round trips, and the bricks, faults, topology and monitoring it needs (D238), brick options among them, for `postgres` only (D236, D262); a post-mortem collection begun beside it (D234) | draft |
| [v0.6](v0.6/README.md) | The bastion as the players' main activity point: web interfaces, a documentation website, general-use tooling; the setup's entry point and a reporting tool, moved from v0.5 (D233) | draft |
| [v1.0](v1.0/README.md) | First release: the full pipeline scenario, reached through v0.2–v0.6 | draft |

**Beyond v1.0**:

- integrating other tools and databases, such as TimescaleDB, columnar
  databases, MySQL and others (D47);
- the GM playing the customer during the game, and the GM giving hints,
  node resets or extra time (D48).
- a fictional cloud provider over the bricks, with capacity management
  and a console (D205; below).
- what v0.5 moved later (D233, D237; below).
- from v1.0 to v2, DBA work with bits of devops: reports run on a
  spawned instance, migrations, replication set up by the players
  (D272; below).

Questions about the roadmap as a whole (gaps between v0.5 and v1.0,
risks across versions) are in [open-questions.md](../open-questions.md),
O48, O49 and O52 to O54 (O46, multi-host, resolved by D128 for v0.3;
O121 by D200; O47, scenario generation, by D248 for v1.0).

## Beyond v1.0: a fictional cloud provider (D205)

In the owner's words (2026-10-30): "i want a fake "aws" and capacity
management ( we type our docker in the swarm as having custom size
(follow the sizing standard of aws, scalled down to our need of course),
technology( rds, aurora, ec2, etc) , with a dedicated web interface
(eventually v2.0+, it would be nice to be able to work on security
group, network interface, etc)." Then: "yes fictionnal name of course,
the website layout doesn't have to follow aws', nor do we yet want the
same iam complexity."

| Part | What | When |
|---|---|---|
| **Typed nodes** | a node's instance type, on a sizing ladder like a cloud provider's (micro, small, medium, large…) scaled down to what the hosts run, sets its limits and reservations | after v1.0 |
| **Service kinds** | a node presented as a managed database, a plain VM and so on: a presentation and constraint layer over the existing bricks (a managed database gives no shell on its host, proposed); a VM node with a full init is where systemd timers come in (D206) | after v1.0 |
| **Capacity management** | choosing, resizing and right-sizing types is part of play; its faults a family, the undersized transformer first (D204) | after v1.0 |
| **A console** | a web interface of our own layout for the above, continuing v0.6's bastion as the players' main activity point | v1.0+ |
| **Networking** | security groups, network interfaces, editable in the console, over the swarm's overlay networks and firewall rules (O12) | v2.0+ |

The console has its own entry point beside the setup's homepage, which
v0.6 may bring (owner, 2026-10-30, D224; moved from v0.5, D233, D248;
O130, O135).

Settled: the provider is **fictional**, with an in-world name of its
own; the console's layout is ours, not a copy of AWS's; **no AWS-style
IAM**: access stays as simple as the game's access model is today, and
anything richer is a later question, if ever.

What earlier versions already give it:

- per-node `resources` in `scenario.yaml` (D84), the shape a type would
  set, and `fit` per host (D128), the capacity a type ladder draws on;
- nodes sized by role from v0.4 (D204): each producer small, transformers
  larger, the first sizing that means something in the story;
- the undersized transformer, recorded as a later fault (D204): today
  only reportable, since hard limits are the platform's (platform.md),
  playable as a fix once resizing is a player action;
- v0.6's bastion web interfaces, which the console continues;
- jobs on a database node from v0.4, `pg_cron` and a cron daemon in the
  container (D206): systemd timers, the third form the owner named, need
  a VM node's init and wait for this layer.

Open: O130.

## v1.0 to v2: DBA work with bits of devops (D272)

The owner, on 2026-11-01: "the work on v1.0+ till v2 will be more active
on the DBA part (with bits of devops)." And: "What i expect from v1.0+
will be also exercices on migration (pg from one version to another,
applying hotfixes, migrating from one db provider to another, setting up
replications, etc)."

| Exercise | What the players do | Builds on |
|---|---|---|
| **A report on a spawned instance** | "run March's report now" on an instance spawned for the occasion, so the live setup is barely disturbed; possibly in v0.6, more probably v1.0 or after (D269) | v0.5's periodic reports, their past periods planted (D265) |
| **Major-version upgrades** | PostgreSQL from one major version to the next | O11's upgrade scenarios: both binaries, the disk space, within the budget |
| **Hotfixes** | applying a minor release or a patch to a running setup | the bricks' pinned versions (formats.md, "Versions and pins") |
| **Moving providers** | migrating a database from one provider to another | the fictional cloud provider (D205, above): its managed database one end of a move, a self-hosted `postgres` node the other |
| **Setting up replication** | building a standby and its replication themselves | v0.5's replication, a standby mode of `postgres` the seed sets up (D250); setting it up becomes the exercise |

The spawned instance and the provider meet: once a node's type and
service kind are the provider's (D205), spawning one for a report or a
migration is a player action. None of this widens v0.5: its replication
stays a mode the seed configures, and its periodic reports run only as
the schedule says.

## Deferred from v0.5 (D233, D237)

On 2026-10-31 the owner centred v0.5 on domain definition and the
veterinary clinic, moving later what does not serve it: "We will move
all tools not related to the clinic use case for a later date (probably
v1.0+)." The full sorting is in
[v0.5's page](v0.5/README.md#sorting-d233); the owner accepted every
proposed row the same day (D248).

**Probably v1.0+**, no version set (D233, D248):

- the research's other top-three picks per need, alternatives to v0.2's
  bricks;
- the scheduler's other targets beyond the clinic's queues and APIs:
  other database types, tools triggering transformation layers (D118);
- fault definitions beyond the clinic's, across the families;
- a general library of topology fragments;
- a general review of v0.3's defaults (D146), beyond what the clinic's
  work meets;
- finance reconciliation, the shop's P4 (D197);
- seeded variation (O24), promoting scenario-only bricks and faults
  (O25);
- the undersized transformer, after v1.0 with the provider's capacity
  family (D204, D205).

**v1.0**: scenario generation (O47, closed by D248;
[v1.0](v1.0/README.md)).

**After v0.5** (settled, D292): other domains (a warehouse, a factory,
a lab on its own); v0.5 is the clinic only.

**Later, version not set** (settled, D237): Bluebox (O53) and the other
datasets, internet-sourced data included (O54). The owner: "bluebox and
other dataset are moved to later date (unspecified...). Bluebox is quite
akin to a domain in my opinion": a later domain candidate, brought in
through the [domain procedure](v0.5/domain-procedure.md), its dataset
filling that domain's data model.

## Release gates

An aged run (a scenario aged for its full declared minimum to the
hand-over, then played through as `player`) is a one-off check, not a
standing item of every release gate (D193). v0.3's gate ran one, and it
passed. None is planned before v1.0; whether v1.0's gate has one is
decided when that gate is planned. In the owner's words: "it need to
stay ponctual and not a regular thing. it takes too much time."

The gates of v0.4, v0.5 and v0.6 rely on the shorter checks, as v0.3
defines them ([master spec](v0.3/master-spec.md) 11 and 8.5): the smoke
tests, short deployments with every fault planted at once; the
rehearsal, about two hours unattended with the aging minimum capped
(D161); and the early check fired by the host's timer. v0.4's gate
adds every purpose fault taken through its full cycle in a smoke run,
its job moved as a player may, and names what no gate shows (a nightly
job at its story's time, growth over a full aging, a night unattended)
as known limits (D200).

### v1.0 gating: v0.5's additions (D314)

`main` holds the v1.0 gating list (D311–D313), which this branch
predates; at the merge these items join it. The owner's rule for v0.5
(D314): "we must restrict testing to short tests (validate that new
bricks/features works simply with minimal environment) we will do a
major test prior taging v1.0, any long running (>30m) will be done
there." v0.5's gates hold short tests only, each under 30 minutes on the
least environment that proves its brick or feature, and one exception:
the whole clinic deployed once, on armenelos plus the VPS, as the proof
in play ([v0.5](v0.5/README.md#testing-in-v05-d314)). The rehearsal
named above is not run in v0.5. Moved to the major test before the v1.0
tag:

- **The clinic aged**: a full aging and a session on the whole clinic,
  every selected fault planted at once and read through its cycle;
  whether the two faults "on the verge" are on the verge at the
  hand-over, and the dramatic one already noticed (D290).
- **The clinic's overnight and periodic cadences in scenario time**: the
  feeders at night, the base backups, the 16:00 send-outs, the
  pathologist's rounds, a periodic run the GM places in the aging; that
  a planted periodic-data fault's witness surfaces within the aging
  (D265), which v0.5 proves only on a short fixture.
- **The clinic's growth and footprints**: every node's memory and the
  trace's growth over the aging, `pg_wal` growing when archiving fails,
  into the bricks' "Footprint" and the scenario's `resources`, `fit`
  re-run.
- **The clinic's rehearsal**: unattended, with the early check, a
  scheduler killed and resuming, a restart, on two hosts.
