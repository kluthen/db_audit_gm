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
| [v0.5](v0.5/README.md) | Research and broadening: more known issues, pre-planned topology parts, common schemas and datasets as business domains (data model, producer profiles, scheduler scripts, purposes; D192) with richer governance for the regulated ones; other tools and hand-made scripts | draft |
| [v0.6](v0.6/README.md) | The bastion as the players' main activity point: web interfaces, a documentation website, general-use tooling | draft |
| [v1.0](v1.0/README.md) | First release: the full pipeline scenario, reached through v0.2–v0.6 | draft |

**Beyond v1.0**:

- integrating other tools and databases, such as TimescaleDB, columnar
  databases, MySQL and others (D47);
- the GM playing the customer during the game, and the GM giving hints,
  node resets or extra time (D48).
- a fictional cloud provider over the bricks, with capacity management
  and a console (D205; below).

Questions about the roadmap as a whole (gaps between v0.5 and v1.0,
risks across versions) are in [open-questions.md](../open-questions.md),
O47 to O49 and O52 to O54 (O46, multi-host, resolved by D128 for v0.3;
O121 by D200).

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
