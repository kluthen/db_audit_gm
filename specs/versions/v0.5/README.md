# v0.5 — research and broadening

Status: draft. No master spec. Business domains added on 2026-10-28
(D192).

## Goal

In the owner's words, three things (D47):

- broaden the scope of known issues to fill in the catalogue;
- pre-plan the most common parts of topology;
- gather common schemas for databases, "so that the GM doesn't have to
  reinvent everything every time". Data could also come from an external
  dataset: Bluebox, a PostgreSQL sample database (a Pagila-derived
  DVD-rental dataset), or truly external, internet-based open-source data
  sources.

On 2026-10-28 the owner added business domains (D192), in the vein of
v0.4's purposes: "we may see this for producers as well, this will
mostly assist in having common scheduler scripts, input types etc. A
shopping website will have specific data profile, whereas a warehouse
management system will have another, a factory yet another than a bio
lab." On placing them here: "v0.5 already is on expansion of
capabilities so that's okay." Domains are how the third goal, common
schemas, is delivered (below).

## Domains

A **domain** (D192; working name) is a reusable catalogue unit made of:

- **a business data model**: the schema and the data load of a kind of
  business;
- **producer profiles**: how data arrives. A shop is bursty, with daily
  peaks and promotions; a warehouse has scan events around shifts; a
  factory has continuous, high-frequency time series; a lab has
  instrument batch uploads and a strict audit trail;
- **common scheduler scripts and input types**: the queries, builders,
  traffic shapes and parameter generators the domain's producers and
  consumers share;
- **the purposes that fit the domain** ([v0.4](../v0.4/README.md)).

A scenario then becomes a domain, a size, the bricks, the purposes in
use, and the faults. What a domain holds and how a scenario names it is
O111; what "size" scales, O114.

How domains meet the rest of this version (proposed):

- **Common schemas**: a domain's business data model is the common
  schema D47 asks for, so the GM does not reinvent the data each time.
- **Datasets**: Bluebox and internet sources fill a domain's data model,
  or stand as a domain's model of their own (Bluebox is a rental shop);
  their requirements stay O53 and O54.
- **Topology fragments** are the technical arrangement (which bricks,
  how they connect); a domain is the business side. A scenario combines
  one domain with fragments.
- **Producer profiles and v0.3's scheduler**: a profile's relation to
  the query repository (`queries.yaml`, `builders/`) and the hidden
  schedule (`schedule.yaml`) is O113. A factory's stream or a lab's
  instrument uploads may want the scheduler's other targets (D118),
  message queues and APIs, below.
- **Governance**: each domain classifies its data (v0.4's first cut,
  D191). The regulated domains, a lab's records or health data, bring
  the richer rules: required settings, audit trails, retention, and the
  brick changes they need (O118).
- **Scenario generation** (O47): a brief naming a domain and a size is
  most of a scenario's business side.

v0.4 ships the first domain, the shop, structured so that more can be
added (O108). v0.5 adds the others; which come first is O112.

### The veterinary clinic (D196)

The owner described a domain on 2026-10-30, placed here, the flagship
of the regulated domains: "we have a veterinary clinic franchise. It's a
big clinic: horse section (housing, dedicated machinerie, multiple
specialists); farm section (same); domestic section; biology (lab, blood
analysis machinerie, etc); formation center (rooms, instructors, canine
and horse dedicated training). this clinic drains animal from all over
the region, there are only 3 such in the country, and several outside.
they have an heavy need on scheduling, data management and redundancy,
but also quite strict reporting needs. they are also heavily connected
both inside and outside: machinerie require dedicated servers and
databases, housing have their own dedicated display for each animal,
access to their file, inter clinic communication happen regularily (as
specific machineries may not be available at each center), external lab
also come into play regularily. internal mailing, messaging and machine
logs, have also their own governance and needs. customers have a
dedicated portal to access their animals informations." He judged it
"may be more v0.5 than v0.4".

It is a composite of parts, each close to a domain of its own:

| Part | What it brings |
|---|---|
| Lab (biology) | D192's bio lab: instrument batch uploads, results, validation before release, an audit trail |
| Bookings and scheduling | the sections' and the training centre's rooms, specialists, machines and instructors |
| Housing | one display per animal: many small read-only consumers of one animal's file |
| Machinery | dedicated servers and databases per machine, possibly engines beyond PostgreSQL (beyond v1.0 by D47) |
| Customer portal | owner-scoped access from outside: each owner sees only their animals |
| Messaging and machine logs | internal mail, messages and logs with governance of their own |
| Regulatory reporting | medicines and antimicrobial-use registers, notifiable disease reports (a pushed obligation, [v0.4](../v0.4/purpose-catalogue.md#p5--export-declarations-a-pushed-obligation)), lab results released to owners |

The same round-trip shape as export declarations' acknowledgements
(below) runs through the clinic: results coming back from external
labs, requests and answers between clinics.

Open: whether a domain may be composed of smaller domains (O126); where
the franchise's several sites and the exchange between clinics sit
(O127). v0.2's `fernway-clinics-monitoring` is a veterinary clinic too,
much smaller (O112).

v0.4 borrows two pieces of it as test cases, without widening its scope:
its strict reporting tests the purpose model
([v0.4 purpose catalogue](../v0.4/purpose-catalogue.md), "Stress test"),
and its data classes test the governance first cut
([v0.4 governance](../v0.4/governance.md), "The database-versus-instance
boundary").

### Round trips: acknowledgements as inputs (D201)

The owner, on 2026-10-30: "Another idea that poped into mind, especially
with export declaration, we could have outgoing flow of data
(declarations, as such), but expect to receive "acknowledgement"
(success or failures, whichever) and await them. It's a side input but
may trigger several other process inside the setup. That's probably
more v0.5 anyway."

v0.4's export declarations push and check: an acknowledgement is part of
the trace, and at most opens an incident
([v0.4 P5](../v0.4/purpose-catalogue.md#p5--export-declarations-a-pushed-obligation)).
A **round trip** makes it an inbound flow the setup waits on and reacts
to: an acceptance or a rejection starts other processes, such as a
correction and resubmission, holding or releasing a shipment, notifying
the customer, a refund or cancellation, or a status change other
purposes read. It brings:

- correlation: matching each acknowledgement to what it answers;
- waiting with a timeout, and resending on one;
- acknowledgements late, out of order, duplicated or unmatched;
- cascades whose faults show downstream of the acknowledgement.

The clinic has the same shape: external labs' results coming back,
exchanges between clinics. How a round trip is modelled is O128.

## In scope

- Other tools and hand-made scripts beyond v0.2's one default brick per
  need (D70): other monitoring tools (among them the research's other
  top-three picks and the reference setup's pgwatch and pgCluu), other
  open-source health solutions such as Nagios (D66), and hand-made scripts
  as the customer's own tooling.
- More fault definitions in the catalog, across the families already
  listed. A candidate recorded in v0.4 (D204): an **undersized
  transformer**, a transformer script whose run outgrows its node's
  memory (the runner restarted, runs missed, reporting stale). Until
  players may resize a node it is *report* or *propose* only; it heads
  the capacity family of the cloud provider layer after v1.0 (D205).
- The scheduler's other targets (D118): other database types, message
  queues, APIs, and tools that trigger transformation layers, as drivers
  of v0.3's scheduler brick
  ([v0.3 master spec](../v0.3/master-spec.md) 7.1).
- Adjusting v0.3's defaults after use (D146): the formats, brick
  interfaces, scenario, aging, scheduler behaviour, tooling and figures
  the owner accepted as proposed in v0.3's review list
  ([v0.3/review-list.md](../../archive/v0.3/review-list.md), archived), revisited once games
  have run on them.
- Reusable topology fragments for the most common arrangements.
- Domains beyond v0.4's shop (D192; O112), each with its business data
  model, producer profiles, common scheduler scripts and input types,
  and fitting purposes: the library of common schemas, and the datasets
  the GM can draw on, including Bluebox and selected external sources.
- Governance rules beyond v0.4's first cut, with the regulated domains
  (D191).
- Brick options (D107): optional elements a brick offers and a scenario
  chooses, each documented in the brick's GM documentation and added to
  a scenario when appropriate, `postgres` first: for that brick in
  particular, the owner expects "many 'optional' elements".
  First candidates: pgBadger, file logging, `pg_stat_statements` and the
  monitoring role (all present in every game in `postgres` 0.2.0), then
  PostGIS, TimescaleDB and the replication modules; `pg_cron` and the
  cron daemon, which `postgres` 0.4.0 already ships, enabled by the seed
  (D206), and `pg_cron` for Bluebox (O53). systemd timers wait for the
  virtual-machine nodes after v1.0 (D205, D206). The model (where an
  option's software comes from, how a scenario chooses, what start-up
  does, faults that need an option, documentation) is O79; whether it is
  meant for every brick or only `postgres`, O80.
- The `monitoring` role made conditional on the game having monitoring
  (D113; v0.2's RG-5). In `postgres` 0.2.0 every game has the login role
  `monitoring` (`pg_monitor`), exporter or not. The owner: "monitoring
  isn't mandatory in any game (highly suspect if there isn't any of
  course, but it remains a valid game)". Until then the role stays in
  every postgres game. The role is among the first candidate options
  above (O79).

## Out of scope

- New database engines (beyond v1.0).

## Depends on

- v0.2 to v0.4: the bricks the topology fragments are made of; v0.2's
  monitoring bricks, which v0.5's other tools extend.
- v0.4: the shop domain and the shape it gives domains, purposes, and
  data governance's first cut (D190 to D192).
- v0.2's `postgres` 0.2.0, whose built-in pgBadger, file logging,
  `pg_stat_statements` and monitoring role are the first candidate
  options, and v0.2's declare/choose/check pattern for mounted material
  and `receives` (D97), which the options model is akin to.

## Questions due in this version

- O79: the brick options model (images, choice, start-up, faults,
  documentation).
- O80: options for every brick, or `postgres` only.
- O53: Bluebox's requirements (PostGIS and other extensions, an 88 MB
  compressed dump, `pg_cron` for ongoing data, data licensing).
- O54: internet-sourced data (availability at setup, licensing,
  reproducibility).
- O23: number and mix of faults, difficulty.
- O25: promoting scenario-only bricks and faults into the catalog.
- O21: whether starter documentation may itself carry faults.
- O112: which domains come first after the shop (the clinic, D196).
- O126: whether a domain may be composed of smaller domains.
- O127: where several sites and inter-site exchange sit.
- O128: how a round trip (an acknowledgement driving further processes)
  is modelled.
- O24: seeded variation per deployment.
- O47: whether generating scenarios from a brief belongs here or in v1.0.
- O111: the domain format (its v0.4 part settled with the shop).
- O112: which domains come first.
- O113: producer profiles against v0.3's query repository and schedule.
- O114: what a scenario's size scales.
