# v0.5 — domain definition: the veterinary clinic

Status: draft. No master spec. Business domains added on 2026-10-28
(D192); centred on 2026-10-31 on defining domains, the veterinary clinic
the worked example (D233), with a procedure for defining a domain
(D235), brick options tied to the clinic (D236, D238) and a post-mortem
collection begun beside it (D234).

## Documents

| Document | Purpose | Status |
|---|---|---|
| [domain-procedure.md](domain-procedure.md) | How a domain is defined: what it holds and leaves out, the steps from a brief, done and its checklist, composites, how a scenario names its domains, the shop against it, the effort | draft v1, not approved (D235; O139) |
| [brick-options-review.md](brick-options-review.md) | The options candidates checked against the clinic: what it plausibly needs, what stops mattering, what O79 and O80 must answer | draft v1 (D236, D238) |

## Goal

The owner, on 2026-10-31: "ok we will then focus on domain definition
and the veterinary clinic franchise as a good example, which will
require us to add a few items in the project. We will move all tools not
related to the clinic use case for a later date (probably v1.0+)." And:
"I see that v0.6 is bastion overhaul, so bastion related stuff (that are
unrelated to the clinic) should move to v0.6 as well." (D233)

v0.5 therefore defines domains, the [veterinary clinic](#the-veterinary-clinic-d196)
(D196) first, and adds to the project the items the clinic needs. The
owner will help define the clinic's bricks, faults, topology and
configurations later; none is designed yet. Whether a tool is "related
to the clinic" is judged against what a setting that complex plausibly
needs (several sites, machinery servers, a lab, a portal, redundancy);
monitoring breadth counts (D238). Everything else in v0.5's earlier
scope is sorted below ([Sorting](#sorting-d233)).

D47's three goals for this version, in the owner's words "broaden the
scope of known issues", "pre-plan the most common parts of topology" and
"gather common schemas for databases", are met through the clinic: its
faults grow the catalogue, its topology is the pre-planned part, its
domains are the common schemas. The rest of each is sorted below.

Business domains came on 2026-10-28 (D192), in the vein of v0.4's
purposes: "we may see this for producers as well, this will mostly
assist in having common scheduler scripts, input types etc. A shopping
website will have specific data profile, whereas a warehouse management
system will have another, a factory yet another than a bio lab."

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

A scenario then becomes one or more domains, a size, the bricks, the
purposes in use, and the faults. What a domain holds, what it leaves
out, how it is defined and how a scenario names several is the
[procedure](domain-procedure.md) (D235), which narrows O111 and O126;
what "size" scales is O114.

How domains meet the rest of this version (proposed):

- **Common schemas**: a domain's business data model is the common
  schema D47 asks for, so the GM does not reinvent the data each time.
- **Topology fragments** are the technical arrangement (which bricks,
  how they connect); a domain is the business side. A scenario combines
  domains with fragments; v0.5's fragments are the clinic's.
- **Producer profiles and v0.3's scheduler**: a profile's relation to
  the query repository (`queries.yaml`, `builders/`) and the hidden
  schedule (`schedule.yaml`) is O113. The lab's instrument uploads or the
  machinery's readings may want the scheduler's other targets (D118),
  message queues and APIs ([Sorting](#sorting-d233)).
- **Governance**: each domain classifies its data (v0.4's first cut,
  D191). The clinic, a regulated business, brings the richer rules:
  required settings, audit trails, retention, and the brick changes they
  need (O118; [brick-options-review.md](brick-options-review.md)).
- **Datasets**: Bluebox and other datasets are for later, version not
  set (D237). The owner sees Bluebox as close to a domain: a later
  candidate brought in through the procedure, its dataset filling that
  domain's data model.

v0.4 ships the first domain, the shop, structured so that more can be
added (O108). v0.5 defines the clinic's domains first (D233). Whether
other domains (a warehouse, a factory, a lab on its own) join v0.5 is
deferred until the procedure's cost is known: the owner decides once
defining a domain has shown how long and complex it is (D235; O112).

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

The owner, on 2026-10-31: "the clinic will probably spawn multiple such
domain". The procedure's first cut splits it into a core and six parts
([domain-procedure.md](domain-procedure.md), "The clinic, a first cut"),
proposed; regulatory reporting becomes purposes, inter-clinic exchange
topology and round trips. Open: the composition rules (O126, narrowed by
the procedure); where the franchise's several sites and the exchange
between clinics sit (O127, narrowed to its topology side). v0.2's
`fernway-clinics-monitoring` is a veterinary clinic too, much smaller.

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

## The post-mortem collection (D234)

A side track, begun in v0.5. The owner, on 2026-10-31: "as a side dish
for v0.5 i'd like that we begin to look for true use case: i mean by
that retex from failures on the net to document our games. We don't
need to exactly match the setting provided of course, but if we can
replicate the main culprits and have them documented, it would be a
good handout at the end of the game along with a concrete explanation of
the failures." And: "store those in a side folder (post_mortem) we won't
directly bind our fault to them quite yet or anything, that'll probably
be done in a later version. But i belive it's a good investment to begin
now."

- **What**: real incident reports found on the internet (post-mortems,
  retex), one entry each, in `post_mortem/` at the repository's root,
  outside the spec tree. Each entry records the source's tech stack and
  topology, the symptoms, the diagnosis and the resolution, with a hard
  link to the source.
- **Not bound yet**: no fault, brick, domain or scenario cites an entry
  in v0.5. The owner will help define more bricks, faults, topologies
  and configurations from them later.
- **The intended later use**: an end-of-game handout, a scenario
  replicating a report's main culprit, not its exact setting, and
  handing the players the real failure's concrete explanation after
  the final answer. Which version binds faults to entries, how a fault
  cites one, and the handout's form are O138.

The collection is gathered on a branch of its own (`v0.5-post-mortem`);
its folder's layout is that branch's.

## In scope

- **Domain definition**: the [procedure](domain-procedure.md) (D235),
  the domain format beyond the shop (O111), producer profiles against
  the schedule (O113), size (O114), composition (O126).
- **The veterinary clinic's domains** (D196, D233), defined with the
  owner: their data models, producer profiles, scheduler scripts and
  input types, classification and governance, and their purposes,
  regulatory reporting among them.
- **The clinic's bricks, faults, topology and configurations**, which
  the owner will help define (D233): its faults are the catalogue's
  growth, its topology fragments the pre-planned parts (D47). Among the
  candidate faults: v0.4's `governance-statement-log-personal`, held for
  the regulated domains (O118), and `purpose-retry-without-key`, held
  for round trips (D201).
- **Round trips** (D201; O128), on the clinic's cases: external labs'
  results, exchanges between clinics.
- **Governance beyond v0.4's first cut** (D191), the clinic being the
  regulated domain, with the brick changes it needs (O118).
- **Brick options** (D107; O79, O80), tied to the clinic and reviewed
  against it ([brick-options-review.md](brick-options-review.md), D236),
  the `monitoring` role made conditional on the game having monitoring
  among them (D113; v0.2's RG-5). Until then the role stays in every
  postgres game.
- **Monitoring breadth for a setting as complex as the clinic** (D238):
  pgwatch and pgCluu, both in the reference setup (D70), and
  Nagios-style health solutions (D66), beyond v0.2's one default brick
  per need.
- **The post-mortem collection**, a side track (D234, above).
- The rest of the earlier scope as sorted below, where it is marked
  v0.5.

## Sorting (D233)

Every item of v0.5's earlier scope, sorted on 2026-10-31: kept when it
serves the clinic or domain definition, moved to v0.6 when it is
bastion-related, moved later otherwise. "v1.0+" is the owner's
"probably v1.0+", no version set; "later" has no version at all.
**Proposed** rows wait for the owner's confirmation (O137).

| Item | Goes to | State |
|---|---|---|
| Domain definition: the procedure, the format beyond the shop, profiles, size, composition (O111, O113, O114, O126) | v0.5 | settled (D233, D235) |
| The clinic's domains (D196) | v0.5 | settled (D233) |
| The clinic's bricks, faults, topology fragments and configurations | v0.5, defined with the owner | settled (D233) |
| A scenario using the clinic's domains, so they are proven in play as v0.4's scenario proved the shop | v0.5 | proposed |
| Round trips (D201; O128), on the clinic's cases | v0.5 | settled (D233): the clinic's lab results and inter-clinic exchanges have their shape |
| Governance beyond the first cut, its brick changes, the held statement-logging fault (D191; O118) | v0.5 | settled (D233): the clinic is the regulated domain |
| Brick options (D107; O79, O80), tied to the clinic, with a review | v0.5 | settled (D236) |
| The `monitoring` role made conditional (D113) | v0.5, with the options | settled (D236) |
| pgwatch and pgCluu | v0.5 | settled (D238) |
| Nagios-style health solutions (D66) | v0.5 | settled (D238): monitoring breadth across sites and machinery servers |
| The research's other top-three picks per need, alternatives to v0.2's bricks (VictoriaMetrics for Prometheus, for one) | v1.0+ | proposed: alternatives, not breadth |
| Hand-made scripts as the customer's own tooling (D70) | v0.5 | proposed: a clinic's own IT plausibly runs its scripts beside the tools |
| The scheduler's other targets (D118): the message queues and APIs the clinic's flows need (external labs, machinery, messaging) | v0.5 | proposed |
| The scheduler's other targets: other database types, tools triggering transformation layers | v1.0+ | proposed |
| Fault definitions beyond the clinic's, across the families | v1.0+ | proposed |
| The undersized transformer (D204) | after v1.0, heading the provider's capacity family (D205) | proposed: only reportable until players may resize a node |
| A general library of topology fragments for the most common arrangements | v1.0+ | proposed |
| Revisiting v0.3's defaults after use (D146) | v0.5 where the clinic's work meets a default; a general review pass v1.0+ | proposed |
| Other domains: a warehouse, a factory, a lab on its own (D192; O112) | decided once the procedure's cost is known | **deferred** (D235) |
| Bluebox (O53) and the other datasets, internet-sourced data included (O54) | later, version not set | settled (D237): Bluebox a later domain candidate, through the procedure |
| Finance reconciliation, the shop's P4 held for v0.5 (D197) | v1.0+, with the shop | proposed; a billing purpose the clinic's definition calls for is the clinic's |
| The setup's entry point: a common Caddy and a homepage for the whole setup (D224; O135) | [v0.6](../v0.6/README.md#the-setups-entry-point-d224) | proposed: the out-of-game side of v0.6's landing page |
| A reporting tool joining a game's starter-pack page (D221, D224) | [v0.6](../v0.6/README.md#the-setups-entry-point-d224) | settled (D233): the page is the bastion's web front |
| O21, starter documentation carrying faults | v0.6, already due there | settled (D233) |
| O47, scenario generation | v1.0 | proposed |
| O24, seeded variation per deployment | v1.0+ | proposed |
| O25, promoting scenario-only bricks and faults | v1.0+ | proposed |
| O23, number and mix of faults | v0.5, for the clinic's scenario | proposed |
| The post-mortem collection | v0.5, a side track | settled (D234); binding later (O138) |

The items moved later are listed in the roadmap
([versions/README.md](../README.md#deferred-from-v05-d233-d237)).

## Out of scope

- New database engines (beyond v1.0). The clinic's machinery may want
  them (D47); in v0.5 it runs on PostgreSQL.
- Everything the sorting above moves to v0.6 or later.

## Depends on

- v0.2 to v0.4: the bricks the clinic's topology is made of; v0.2's
  monitoring bricks, which pgwatch, pgCluu and the health solutions
  extend.
- v0.4: the shop domain and the shape it gives domains, purposes, and
  data governance's first cut (D190 to D192); P5's pushed obligation,
  which the clinic's regulatory reports and round trips build on.
- v0.2's `postgres` 0.2.0, whose built-in pgBadger, file logging,
  `pg_stat_statements` and monitoring role are the first candidate
  options, and v0.2's declare/choose/check pattern for mounted material
  and `receives` (D97), which the options model is akin to.

## Questions due in this version

- O111: the domain format (its v0.4 part settled with the shop),
  narrowed by the procedure.
- O112: which other domains join v0.5, deferred until the procedure's
  cost is known (D235).
- O113: producer profiles against v0.3's query repository and schedule.
- O114: what a scenario's size scales.
- O126: domain composition, narrowed by the procedure.
- O127: where several sites and inter-site exchange sit, its topology
  side.
- O128: how a round trip (an acknowledgement driving further processes)
  is modelled.
- O118: the brick changes for governance (pgaudit, TLS).
- O79: the brick options model, for the clinic's options.
- O80: options for every brick, or `postgres` only.
- O23: number and mix of faults, difficulty, for the clinic's scenario
  (proposed).
- O137: confirming the sorting's proposed rows.
- O139: approving the domain procedure.

Moved out of this list on 2026-10-31: O53 and O54 (later, D237); O21
(v0.6, D233); O135 (v0.6, proposed); O47 (v1.0, proposed); O24 and O25
(v1.0+, proposed). Not due here: O138, the post-mortems' binding.
