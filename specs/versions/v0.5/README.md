# v0.5 — domain definition: the veterinary clinic

Status: draft. No master spec. Business domains added on 2026-10-28
(D192); centred on 2026-10-31 on defining domains, the veterinary clinic
the worked example (D233), with a procedure for defining a domain
(D235), brick options tied to the clinic (D236, D238) and a post-mortem
collection begun beside it (D234). The owner accepted every
recommendation of the scope review on 2026-10-31 (D248–D251), then
approved the domain procedure and ruled on pgaudit and the options'
reach the same day (D260–D262). On 2026-11-01 a domain's scale, variants
and tags were settled (D263); the frictions between producer profiles
and v0.3's scheduler were drafted (O113) and partly ruled the same day:
a merge script, periodic reports, the core the system of record, an
`api` brick, the external lab's round trip (D264–D268), then on-demand
reports moved later and the `api` node's reach (D269–D271), with a
direction for v1.0 to v2 (D272), and third parties put out of the
players' reach (D273), their definition ruled (D274, D275), then O113's remaining points
and the periodic fix check (D276, D277); `vet-core`'s business sketch
ruled (D278), its split confirmed (step 3, D279), its data model
current (step 4) and its classification and governance ruled (step 5,
D280). On 2026-11-02 the owner ruled one centre per scenario, the rest
third parties (D285), round trips a purpose kind of their own and how a
cascade's fix is checked (D286), the housing displays (D287), a
direction for data growth with cold storage (D288), the options model
(D289), the clinic's fault budget (D290), the domain format's
finalisation (D291), and v0.5 clinic-only (D292); then, the same day,
what one centre changes, the portal the centre's and messaging the
franchise's, the lab billing its outside customers and `vet-core` at
one centre's scale (D293–D295), cold storage's design and when data
ships (D296, D297), and friction 11's profile (D298); then replication
and the off-site copies (D299), the reports writing to a back-office
database, `office` (D300); `vet-lab`'s business sketch ruled, every
default accepted, the lab on a node of its own (D301), its data model
and governance ruled as drafted (D302); `vet-core`'s and `vet-lab`'s
producer profiles (step 6) drafted together, then ruled as drafted
(D304), with what they need of the scheduler and the format (D303);
their purposes (step 7) drafted together, for the owner (O155), with
what the round trip and the periodic reports extend in the purpose
format (O156).

## Documents

| Document | Purpose | Status |
|---|---|---|
| [domain-procedure.md](domain-procedure.md) | How a domain is defined: what it holds and leaves out, the steps from a brief, done and its checklist, composites, how a scenario names its domains, the shop against it, the effort, scale, variants and tags | approved v4 (D249, D260, D263) |
| [producer-profiles.md](producer-profiles.md) | The frictions between domains' producer profiles and v0.3's scheduler, each with its evidence, and the owner's rulings; what the first parts' profiles need of the scheduler and the format | draft v8, ruled (D264–D271, D276, D277, D287, D288, D298, D303; O113, O154 closed) |
| [cold-storage.md](cold-storage.md) | Cold storage, a generic third party for heavy data: keeping a day on site, the shipping job, the stub's manifest, endpoints and page, the faults it enables | draft v2, ruled (D288, D296, D297; O148 closed) |
| [third-parties.md](third-parties.md) | What a third party is, what it may carry, how it is built into a game, what the players are told; the repository's third parties in all but name | draft v4, ruled (D273–D275, D285, D293, D296) |
| [one-centre.md](one-centre.md) | One centre per scenario: the ruling, and what it changes for the clinic's parts, its lab's partners, the exchanges with the other centres and the partners' nodes | draft v3, ruled (D285, D293–D295, D304; O127, O147 closed) |
| [vet-core-domain.md](vet-core-domain.md) | `vet-core` through the procedure: the business sketch and the owner's answers (step 2), what the parts need of the core, the clinic's split (step 3), the data model (step 4), classification and governance (step 5), the producer profiles (step 6) | draft v8: steps 2 and 3 ruled (D266, D278, D279, D293, question 1 revised by D285), step 4 current at one centre's scale (D295), `requests` revised (D301), the lab's two load constraints applied (D302), step 5 ruled (D280), step 6 ruled (D303, D304; O153, O154 closed); step 7 in [clinic-purposes.md](clinic-purposes.md) |
| [replication.md](replication.md) | Replication and the off-site copies: a standby of the core's instance off site, WAL archiving and base backups to cold storage for the core's instance and the lab's node, their faults and cost; the back-office database the reports write to | draft v3, ruled (D299, D300, D301; O149 closed) |
| [vet-lab-domain.md](vet-lab-domain.md) | `vet-lab` through the procedure: what is settled before it, the business sketch (step 2) and the owner's answers, where the lab presses on the core, the data model (step 4), classification and governance (step 5), the producer profiles (step 6) with its partners and round trips | draft v4: step 2 ruled (D301, O151 closed); steps 4 and 5 ruled (D302, O152 closed), `lab_app`'s grants amended (D304); step 6 ruled with `vet-core`'s (D303, D304; O153, O154 closed); step 7 in [clinic-purposes.md](clinic-purposes.md) |
| [clinic-purposes.md](clinic-purposes.md) | Step 7 for `vet-core` and `vet-lab` together: the existing purposes against the clinic, the ten purposes proposed (four round trips, the notifications, the critical calls, the registers, the antimicrobial-use report, the head office's figures, the lab's statements), each with its kind, cadence, trace, invariants, runner, source and target and candidate faults; the runners; the format's extensions; what it asks of the domains | draft v1, for the owner (O155, O156) |
| [brick-options-review.md](brick-options-review.md) | The options candidates checked against the clinic, and the owner's rulings on them: what the clinic gets, as an option or otherwise, what stops mattering, the options model | draft v4, ruled (D250, D261, D262, D289) |

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
needs (one large centre with machinery servers, a lab, a portal,
redundancy, and partners around it, D285); monitoring breadth counts
(D238). Everything else in v0.5's earlier
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

A scenario then becomes one or more domains, a variant with its scale
and tags, the bricks, the purposes in use, and the faults. What a domain holds, what it leaves
out, how it is defined and how a scenario names several is the
[procedure](domain-procedure.md) (D235), approved (D260), which narrows
O111 and settles composition (D249). "Size" became **scale**, on three
axes, population, history and throughput; one domain covers several
setups as **variants**, short manifests with tags from a fixed
vocabulary; large setups show through structure, not volume; v0.5
builds one variant per domain (D263; procedure 9).

How domains meet the rest of this version (proposed):

- **Common schemas**: a domain's business data model is the common
  schema D47 asks for, so the GM does not reinvent the data each time.
- **Topology fragments** are the technical arrangement (which bricks,
  how they connect); a domain is the business side. A scenario combines
  domains with fragments; v0.5's fragments are the clinic's.
- **Producer profiles and v0.3's scheduler**
  ([producer-profiles.md](producer-profiles.md), O113): fragments are
  merged by a `gmctl compose` script (D264); weekly, monthly and yearly
  reports are in the game, their past periods planted (D265); the core
  is the system of record, natural identifiers carrying identity across
  systems (D266); an `api` brick and the scheduler's HTTP driver serve
  the flows that need an API (D267), the external lab's round trip
  first (D268); the housing displays reach the database through a ward
  service (D287); heavy continuous data keeps a day on site and ships
  the rest to [cold storage](cold-storage.md), the GM deciding per data
type, use first (D288, D296–D298).
- **Governance**: each domain classifies its data (v0.4's first cut,
  D191). The clinic, a regulated business, brings the richer rules:
  required settings, audit trails, retention, and the brick changes they
  need: TLS and pgaudit always available in `postgres` (D250, D261;
  [brick-options-review.md](brick-options-review.md)).
- **Datasets**: Bluebox and other datasets are for later, version not
  set (D237). The owner sees Bluebox as close to a domain: a later
  candidate brought in through the procedure, its dataset filling that
  domain's data model.

v0.4 ships the first domain, the shop, structured so that more can be
added (O108). v0.5 defines the clinic's domains only; other domains (a
warehouse, a factory, a lab on its own) come after v0.5 (D292). The
owner: "i belive v0.5 is already big, so they'll wait".

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
kept now and revised once `vet-core` is defined (D249); regulatory
reporting becomes purposes, inter-clinic exchange round trips. The
parts compose by the procedure's rules (D249). v0.2's
`fernway-clinics-monitoring` is a veterinary clinic too, much smaller.

**One centre per scenario (D285).** The owner, on 2026-11-02: "the
scenario should be centered only on one such center (not all 3, nor
those beyond)". Each national centre is independent, with its own
records, and has its own lab, which the region's other clinics pay to
use. A scenario deploys one centre; the other national centres, the
centres abroad and the franchise's central systems are third parties,
stub `api` nodes only, sharing one back end. The clinic is the core
and five parts, the portal the centre's and messaging the franchise's;
the lab bills its outside customers ([one-centre.md](one-centre.md),
D293–D295).

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

**How it is modelled (D286).** A round trip is a **purpose kind of its
own**, beside v0.4's four (pulled, transformed in place, pushed, pushed
obligation). Its definition states:

- the **request**: what is sent, by which job, to which partner;
- the **correlation key**: what an answer carries to name its request;
- the **expected answer**: its forms (accepted, rejected, a result);
- a **timeout**: how long the setup waits before it resends or
  escalates;
- the **reactions**: the processes the answer starts inside the setup.

v0.4's pushed obligation (P5, export declarations) stays as built.

**Checking a cascade (D286).** A fix check judges the end-to-end
invariant on the trace produced after the fix (for the lab: each new
order gets its result released), wherever the player fixed it. Fixing
a symptom alone earns nothing. The backlog the fault left behind (the
orders stuck before the fix) is listed in the answer key as a
consequence the GM may credit the players for cleaning up: not a fault,
and not counted toward the fault cap (D290).

The clinic's round trips: the external lab's results (D268), the
region's clinics ordering from the centre's lab, the exchanges with the
other centres, all with third parties (D285, D293;
[one-centre.md](one-centre.md)), and cold storage's receipts
([cold-storage.md](cold-storage.md), D296).

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
  the final answer. Settled (D251): the binding comes in a later
  version; the handout is given after the final answer, and it
  summarises its source and links to it, never copying it. Which
  version, how a fault cites an entry, and the handout's form stay
  O138.

The collection was gathered on a branch of its own (`v0.5-post-mortem`),
merged into `main` on 2026-10-31 (8f772ef); its folder's layout, entry
template and index are in [`post_mortem/`](../../../post_mortem/README.md).

## In scope

- **Domain definition**: the [procedure](domain-procedure.md) (D235),
  approved (D260), the domain format beyond the shop with its four changes, built in one
  chunk (D249), finalised in the master spec when v0.5 consolidates
  (D291; O111), producer profiles against the schedule (ruled,
O113 closed by D298),
  scale, variants and tags, one variant per domain (D263), composition
  as a core and parts (D249), tried first on
  `vet-core` and `vet-lab`.
- **The veterinary clinic's domains** (D196, D233), only those (D292):
  the split confirmed after `vet-core` (D279), one centre's own parts
  (D285): the core and five parts, `vet-lab`, `vet-scheduling`,
  `vet-housing`, `vet-machinery` and `vet-portal` (D293), defined with
  the owner: their data
  models, producer profiles, scheduler scripts and input types,
  classification and governance, and their purposes, regulatory
  reporting among them.
- **A scenario using the clinic's domains** (D248), proving them in play
  as v0.4's scenario proved the shop, deploying one centre (D285). Its
  faults (D290): ten at most, the owner judging it "one of the most
  complex scenario that we will propose": one dramatic and already
  noticed by the customer, two on the verge of becoming problematic,
  the rest good optimisations and minor frictions; an issue may be a
  false alarm, a complaint with no fault behind it.
- **The clinic's bricks, faults, topology and configurations**, which
  the owner will help define (D233): its faults are the catalogue's
  growth, its topology fragments the pre-planned parts (D47). Among the
  candidate faults: v0.4's `governance-statement-log-personal`, held for
  the regulated domains (D191), and `purpose-retry-without-key`, held
  for round trips (D201).
- **Round trips** (D201), a purpose kind of their own, a cascade's fix
  judged end to end (D286), on the clinic's cases: external labs'
  results over API nodes, a consumer-producer with a correlation id and
  its callback faults (D268); the lab's outside customers and the
  exchanges with the other centres (D285, D293).
- **Periodic reports** (D265, D269): weekly, monthly and yearly, their
  past periods planted by the load, calibrated per node; no run on
  demand in v0.5, which comes later on an instance spawned for it.
- **`gmctl compose`** (D264), built with the domain format's changes.
- **Third parties** (D273–D275): the external lab first; the other
  national centres, the centres abroad, the franchise's central systems
  and the region's clinics using the lab (D285); the franchise's
  messaging service (D293); cold storage (D288, D296);
  their nodes outside the players' reach (`no-access` made real, their
  back end closed by its own access rules on the one network), stub
  `api` nodes only with one back end shared by all (D293), the bastion
  routing the players to cold storage's read-only page alone (D296),
  their description in `partners.md`, a fifth
  optional starter-pack file ([third-parties.md](third-parties.md)).
- **Governance beyond v0.4's first cut** (D191), the clinic being the
  regulated domain, with the brick changes it needs: TLS and pgaudit
  always available in `postgres`, turned on by the seed (D250, D261).
- **`postgres` for the clinic** (D236, D250;
  [brick-options-review.md](brick-options-review.md)): replication as a
  standby mode of the brick, for redundancy: a readable standby of the
  core's instance off site, the reports reading there, WAL archiving
  and nightly base backups to cold storage ([replication.md](replication.md),
  D299), the reports' outputs in a back-office database, `office`, on
  the primary's instance (D300); plain partitioned tables
  for the machinery's time series, before any TimescaleDB; the
  `monitoring` role the only element of today's four to become an
  option, made conditional on the game having monitoring (D113; v0.2's
  RG-5), by the options model (D289): `options: [monitoring]` per node,
  off unless chosen. Options are for `postgres` only, unless one of the
  clinic's parts calls for another brick (D262).
- **Monitoring breadth for a setting as complex as the clinic** (D238):
  pgwatch and pgCluu, both in the reference setup (D70), and
  Nagios-style health solutions (D66), beyond v0.2's one default brick
  per need; hand-made scripts as the customer's own tooling (D70, D248).
- **The scheduler's other targets the clinic's flows need** (D118,
  D248): an `api` brick on FastAPI serving the GM's endpoint files and
  an HTTP driver in the scheduler (D267); an `api` node only answers,
  scheduler nodes calling it (D270), and players edit only its
  database side, never its endpoints (D271); for the core's lookup API, the
  external labs and the machinery; FastAPI and uvicorn pass a
  security-advisor dependency check before the build, a gate of the
  build plan. Message queues only if a flow needs one.
- **v0.3's defaults revisited** where the clinic's work meets one
  (D146, D248).
- **The post-mortem collection**, a side track (D234, above).

## Sorting (D233)

Every item of v0.5's earlier scope, sorted on 2026-10-31: kept when it
serves the clinic or domain definition, moved to v0.6 when it is
bastion-related, moved later otherwise. "v1.0+" is the owner's
"probably v1.0+", no version set; "later" has no version at all.
The owner accepted every row proposed here on 2026-10-31 (D248, closing
O137); one row stays deferred.

| Item | Goes to | State |
|---|---|---|
| Domain definition: the procedure, the format beyond the shop, profiles, scale, composition (O111, O113; O126 closed by D249, O114 by D263) | v0.5 | settled (D233, D235, D249); the procedure approved (D260); scale, variants and tags (D263); the format finalised at consolidation (D291) |
| The clinic's domains (D196) | v0.5 | settled (D233) |
| The clinic's bricks, faults, topology fragments and configurations | v0.5, defined with the owner | settled (D233) |
| A scenario using the clinic's domains, so they are proven in play as v0.4's scenario proved the shop | v0.5 | settled (D248) |
| Round trips (D201; O128 closed by D286), on the clinic's cases | v0.5 | settled (D233): the clinic's lab results and inter-clinic exchanges have their shape; a purpose kind of its own (D286) |
| Governance beyond the first cut, its brick changes, the held statement-logging fault (D191; O118 closed by D261) | v0.5 | settled (D233): the clinic is the regulated domain; TLS and pgaudit always available (D250, D261) |
| Brick options (D107; O79 closed by D289, O80 by D262), tied to the clinic, with a review | v0.5 | settled (D236); ruled on by D250, D261, D262, D289 |
| The `monitoring` role made conditional (D113) | v0.5, with the options | settled (D236) |
| pgwatch and pgCluu | v0.5 | settled (D238) |
| Nagios-style health solutions (D66) | v0.5 | settled (D238): monitoring breadth across sites and machinery servers |
| The research's other top-three picks per need, alternatives to v0.2's bricks (VictoriaMetrics for Prometheus, for one) | v1.0+ | settled (D248): alternatives, not breadth |
| Hand-made scripts as the customer's own tooling (D70) | v0.5 | settled (D248): a clinic's own IT runs its scripts beside the tools |
| The scheduler's other targets (D118): the message queues and APIs the clinic's flows need (external labs, machinery, messaging) | v0.5 | settled (D248): an `api` brick and an HTTP driver (D267); queues only if a flow needs one |
| The scheduler's other targets: other database types, tools triggering transformation layers | v1.0+ | settled (D248) |
| Fault definitions beyond the clinic's, across the families | v1.0+ | settled (D248) |
| The undersized transformer (D204) | after v1.0, heading the provider's capacity family (D205) | settled (D248): only reportable until players may resize a node |
| A general library of topology fragments for the most common arrangements | v1.0+ | settled (D248) |
| Revisiting v0.3's defaults after use (D146) | v0.5 where the clinic's work meets a default; a general review pass v1.0+ | settled (D248) |
| Other domains: a warehouse, a factory, a lab on its own (D192; O112 closed by D292) | after v0.5 | settled (D292): v0.5 is the clinic only |
| Bluebox (O53) and the other datasets, internet-sourced data included (O54) | later, version not set | settled (D237): Bluebox a later domain candidate, through the procedure |
| Finance reconciliation, the shop's P4 held for v0.5 (D197) | v1.0+, with the shop | settled (D248); a billing purpose the clinic's definition calls for is the clinic's |
| The setup's entry point: a common Caddy and a homepage for the whole setup (D224; O135) | [v0.6](../v0.6/README.md#the-setups-entry-point-d224) | settled (D248): the out-of-game side of v0.6's landing page |
| A reporting tool joining a game's starter-pack page (D221, D224) | [v0.6](../v0.6/README.md#the-setups-entry-point-d224) | settled (D233): the page is the bastion's web front |
| O21, starter documentation carrying faults | v0.6, already due there | settled (D233) |
| O47, scenario generation | v1.0 | settled (D248, closing O47) |
| O24, seeded variation per deployment | v1.0+ | settled (D248) |
| O25, promoting scenario-only bricks and faults | v1.0+ | settled (D248) |
| O23, number and mix of faults | v0.5, for the clinic's scenario | settled (D248); ruled for the clinic (D290), the general mix left open |
| The post-mortem collection | v0.5, a side track | settled (D234); binding later, the handout after the final answer (D251; O138) |

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

- O111: the domain format, beyond its v0.4 part and D249's four
  changes; finalised in the master spec when v0.5 consolidates (D291).
- O155: `vet-core`'s and `vet-lab`'s purposes (step 7), the owner to
  choose them ([clinic-purposes.md](clinic-purposes.md#points-for-the-owner-o155)).
- O156: what the round trip and the periodic reports extend in the
  purpose format ([clinic-purposes.md](clinic-purposes.md#4-the-format-and-what-the-round-trip-extends-o156)),
  feeding O111.

Moved out of this list on 2026-10-31: O53 and O54 (later, D237); O21
and O135 (v0.6, D233, D248); O24 and O25 (v1.0+, D248). Closed: O47
(v1.0) and O137 (D248), O126 (D249), O139 (D260), O118 (D261), O80
(D262), O114 (D263), O145 (D274, D275), O144 (D278), O127 (D285), O128
(D286), O79 (D289), O112 (D292), O147 (D293–D295), O148 (D296, D297),
O113 (D298), O149 (D300), O151 (D301), O152 (D302), O154 (D303), O153
(D304). O23 ruled for the clinic (D290), its
general part left for later. Not due here: O138, the post-mortems'
binding.
