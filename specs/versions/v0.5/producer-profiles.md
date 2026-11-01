# v0.5 — producer profiles against v0.3's scheduler (O113)

Status: draft v1. Nothing here is ruled: every recommendation is
(proposed) until the owner rules on the [questions](#rulings-for-the-owner).

The owner, on 2026-11-01: "Let's begin working on the clinic domains and
the frictions points between producer profiles and v0.3."

A domain's **producer profile** is how its data arrives: the repository
fragments (`queries.yaml`, `builders/`), the schedule fragment
(`schedule.yaml`: connections, streams, shapes) and the fixed-time
operations (`jobs.yaml`) under `producers/`
([procedure](domain-procedure.md) 1). This document lists the places
where profiles, as the shop built them and as the clinic will need them,
meet v0.3's scheduler badly. Each friction has the evidence that it is
real, the options and a recommendation.

Read for it: the shop as built (`domains/shop/`, its `producers/` and
`docs/gm.md`), the v0.4 fixture that consumed it
(`tools/tests/fixtures/fixture-campaign/`, the shape chunk 16's scenario
copies; the scenario itself is built in v0.4's wave 4), the scheduler
0.2.0's program (`bricks/scheduler/program/gm_scheduler/`), the loader
(`tools/gm/model.py`, `tools/gm/render.py`, `tools/gm/aging.py`),
[v0.3's master spec](../v0.3/master-spec.md) 7.1 and 8, and the archived
[scheduler](../../archive/v0.3/scheduler.md) and
[load and capacity](../../archive/v0.3/load-and-capacity.md) drafts.

## Summary

| # | Friction | Ruling |
|---|---|---|
| 1 | Fragments are merged into a node's files by hand; collisions are lost silently | 1 |
| 2 | The hidden `schedule.yaml` (D130) against a profile readable in the catalogue (D13) | 2 |
| 3 | Absolute intensity (D32) against rates the domain states | 3 |
| 4 | Monthly and yearly cadences real time cannot age (O22) | 4 |
| 5 | Richer input types than v0.3's generators | 5 |
| 6 | Composites: a core and parts onto one producer node or several | 6 |
| 7 | Key ranges shared between the core's load and the parts' producers | 7 |
| 8 | Inbound flows: round trips (O128) and the scheduler's other targets (D118) | 8 |
| 9 | Many small consumers that all look alike (the housing displays) | carried to `vet-housing` |
| 10 | Several sites in different time zones | 9 |
| 11 | Data growth over the aging (the machinery's readings) | carried to `vet-machinery` |

## 1. Merging fragments

**What.** A domain's fragments are not used in place: the GM copies them
into a scheduler node's seed files at design time and adapts them (D23,
D215). Where several sources feed one node, the GM merges them by hand.

**Evidence.**

- `fixture-campaign`'s `crm` node merges three purposes' runner
  fragments; its `schedule.yaml` header records the hand merge: "the two
  fragments' shop_crm connection kept once; the scenario's intensity
  added". The producer node copies the shop's fragments "unchanged",
  adding `intensity: 1.0`.
- The shop's fragments are "written for the node names `pooler` and `db`
  and the database `shop`; rename them as the scenario does"
  (`docs/gm.md`, "The producer"): every target is rewritten by hand.
- A merged file can lose an entry without a word. The loader and the
  scheduler read YAML with PyYAML, whose mappings keep the last of two
  equal keys: two fragments both defining a query key, a connection
  `app` or a shape `business-hours` give one, the other gone (checked:
  `yaml.safe_load` of a mapping with `a: 1` and `a: 2` returns `a: 2`).
  The scheduler refuses two streams with the same key (it is a list),
  nothing else.
- `_check_fragments` (`tools/gm/model.py`) checks a fragment's top-level
  keys (no `intensity`, no `timeline`) and its queries; nothing checks a
  merge.

The clinic multiplies this: a core, up to six parts, each part's
purposes, several sites.

**Options.**

- **a. Hand merge, with naming rules and a duplicate check.** A part
  prefixes its query keys, connection names and shape names with its
  prefix (`lab.batch.upload`, connection `lab`, shape `lab-runs`), as
  the procedure already prefixes its roles and tables (section 4); the
  loader refuses a duplicate key in a scenario's scheduler files.
- **b. A design-time compose helper.** A `gmctl` command copies a
  scenario's domains' and purposes' fragments onto the nodes `domains:`
  and `purposes:` name, rewrites targets from each domain's `at:`
  (procedure 5), merges, refuses collisions, and writes ordinary files
  into the scenario folder, which stays self-sufficient.
- **c. A library the scenario references**, resolved at render. Breaks
  D23's self-sufficient folder, and since domains never bump (D215), a
  change to the library would change every scenario using it.
- **d. A layer the scheduler reads**, the catalogue on the node. The same
  breakage, and the brick tied to the catalogue's state.

**Recommendation.** a now, b decided when the clinic's scenario is
built, if the hand merge proves error-prone there. c and d rejected: they
undo D23 and D215.

## 2. A readable profile and the hidden schedule

**What.** `schedule.yaml` is root-only on the node, never on a volume,
never in the hand-over snapshot (D130, master spec 7.1). A domain's
schedule fragment, its rates and shapes, sits in the repository for
anyone to read.

**Evidence.**

- The scenario folders already hold their own `nodes/<node>/schedule.yaml`
  in the repository, as readable as a domain's fragment. D13 makes the
  repository a textbook: reading it is trust, not enforcement. D130 hides
  the schedule on the node, in the game, not in the catalogue.
- What a fragment can hold is narrow: `_check_fragments` refuses
  `intensity` and `timeline` in a schedule fragment ("intensity and
  timeline are the scenario's"). v0.4's faults that ride the schedule do
  so through the scenario's timeline (f2's release, f8's gateway outage,
  build plan chunk 16), never through a fragment.
- The shop keeps planted faults out of its fragments ("Tarnbeck's planted
  faults are not in the domain", `docs/gm.md`).

**Options.** a. Accept on the trust line. b. Keep profiles out of the
readable catalogue: impossible while scenarios themselves are readable.

**Recommendation.** a: a profile reveals a business's base traffic, which
the players could infer from the logs anyway (archived scheduler draft,
"What the players reach"). The rule worth writing down: a fragment never
carries a timeline, an intensity or a planted fault; the shop's practice
made general.

## 3. Absolute intensity and the domain's rates

**What.** The intensity multiplies every stream of a schedule and is
absolute, never rescaled to the playground (scheduler draft, "The
schedule", after D32). A domain states rates "at intensity 1.0, before
the shape".

**Evidence.**

- One intensity per schedule (`schedule.py`: one `intensity` key), so one
  per node: a core and a part merged onto one node share it.
- The rates are tied to the load: the shop's history holds 300 000 orders
  over fifteen days, 20 000 a day, while its `orders.place` at 40 a
  minute through `business-hours` gives about 30 000 a day; `docs/gm.md`
  explains the gap as the busy season. A clinic part whose live rate and
  history disagree with no such sentence reads as a fault.
- D32 forbids the local implementation rescaling, not the GM choosing an
  intensity at design time.

- Scale is settled (D263, [procedure](domain-procedure.md) 9): a
  variant sets a `throughput` axis, in real-world rates, absolute as
  D32 makes the intensity, beside `population` and `history`.

**Options.** a. A domain's rates are its variant's throughput at
intensity 1.0; the scenario sets each node's intensity at design time;
the GM notes state the daily volume the rates give against the
history's. b. Rates recomputed at render from the variant's axes:
against D32's rule that nothing is recomputed per playground, and
needless while each domain has one variant in v0.5.

**Recommendation.** a. Parts needing a different throughput from the
core's go on their own node (6) or have their rates adapted at copy.

## 4. Cadences real time cannot age

**What.** The clinic has monthly and yearly duties: the antimicrobial-use
report to the authority each year, monthly statements and register
extracts, weekly herd visits and rotas ([vet-core](vet-core-domain.md),
"Cadences"). A game ages in real time, eight hours at the least (master
spec 8.1, 8.2); no fake time, no time compression (D114, D132; O22).

**Evidence.**

- Shapes are 24 hourly multipliers, optionally per weekday (`days:`); the
  render (`_scenario_week`, `render_shape`) knows a week and nothing
  longer. No day-of-month or season shape exists.
- A monthly cron is valid (`cron.py` takes any five-field expression) and
  the loader finds its first run up to 400 days ahead
  (`cron_first_due`), but the early check counts only the jobs first due
  before the earliest hand-over (`early_check_due`): a monthly job
  outside the aging is silently idle evidence.
- D199 settled it for v0.4: realistic cadences, no weekly or monthly
  purpose; the restored backup may hold past records computed by the
  data load, but no fault's evidence rests on them alone. D193: no aged
  run before v1.0.

**Options.**

- **a. Extend D199 to domains.** A monthly or yearly output exists in the
  game as history the load computes (last month's statement, last
  year's report), and live through its sub-daily feeders: the daily
  extract the yearly report sums, the register rows each administration
  writes. A fault bites the feeder; its trace reaches the history's next
  period only in the story.
- **b. A period close at a timeline moment**: a one-shot job at
  `handover-<N>h` ("the month was closed last night"). Honest about time,
  but a scheduler and render change, and `jobs.yaml` would show players a
  run no cron line explains.
- **c. Choose the game's dates** so the first of a month falls within the
  aging. Works for a monthly job, never a yearly one, and ties a game to
  the calendar rather than to the class.

**Recommendation.** a. b and c rejected for v0.5. The procedure's step 6
already flags such cadences for the owner: each flagged cadence is marked
"history" or "live feeder" in the domain's GM notes.

## 5. Richer input types

**What.** The clinic's producers need values v0.3's generators do not
make: a species mix, names of new owners and animals, identifiers
(15-digit microchips, horse and cattle identifiers), sensor readings
with noise and alarms, instrument batches of many results.

**Evidence.**

- The generators are `int`, `decimal`, a uniform `choice`, `sequence` and
  `now` (`generators.py`). No weighted choice, no distribution, no text.
- The shop works around it in SQL: `elsewhere: {int: [1, 100]}` and a
  `CASE` in the statement give its 95/5 split of destinations; names come
  from the load's lists, never from the producer.
- Builders are Python, called with the intensity, the options and the
  task's seeded `rng` (`repository.py`; `carrier_feed.py` uses it), and
  return statements: anything computable without reading the database.
  They cannot read a result.
- A change to the generators is a change to the brick: a `scheduler`
  bump. A domain's builders are its own files, copied with it.

**Options.** a. SQL-side generation, as the shop. b. Domain builders in
`producers/builders/`, for values with structure (identifiers with check
digits, readings drifting around a baseline). c. New generators: a
weighted choice first, then distributions.

**Recommendation.** a and b. c only if the clinic's fragments need the
same `int`-and-`CASE` trick over and over; a weighted `choice` would then
be the one generator to add. Work that depends on the database's state
(an instrument run over the pending samples) is SQL (`INSERT ... SELECT`),
not a builder, since builders cannot read.

## 6. Composites: one producer node or several

**What.** A core and its parts each bring fragments. They can land on one
scheduler node or several; a part in an instance of its own needs its own
connection.

**Evidence.**

- One node runs one schedule against one repository, with one intensity,
  one seed, one log (master spec 7.1). A stream holds exactly one
  connection (`schedule.py`): a single call never touches two instances.
- Only a script reaches several connections in one run (`scripts.py`),
  and a script is a job's, never a stream's, fired by cron at most once a
  minute, PostgreSQL only.
- A node costs 128M at its limit; `fixture-campaign`'s twelve nodes fit
  1.6 CPU and 1.75G (build plan chunk 13's record). Seven clinic domains
  on seven producer nodes, with their purposes' runners, cost several
  hundred megabytes before any database.
- The procedure's rule already places flows between parts in purposes
  (section 4), which run on transformer nodes.

**Options.** a. A producer node stands for **one application** of the
business: the practice-management software that writes the core,
bookings and housing is one node; the lab's information system another;
the portal another. A domain's GM notes say which application each
fragment belongs to. b. One node per domain. c. One node for the whole
clinic.

**Recommendation.** a. It is what the players would find in a real
clinic, it keeps the node count to the applications, and it puts every
cross-instance flow where the procedure puts it, in a purpose's
transformer job.

## 7. Key ranges shared by the core's load and the parts' producers

**What.** A part refers to core keys by id, with no foreign key, and the
core's load generates its keys in documented ranges (procedure 4). The
producers draw ids from those ranges.

**Evidence.**

- The shop's fragments hard-code its load's sizes: `customer_id: {int:
  [1, 20000]}`; `product_id: {int: [1, 1996]}`, so that `product_id +
  extra` (up to 4) stays within 2 000 products; the carriers' builder
  takes `orders: 300000` as an option. The load sets the sequences after
  its explicit ids (`setval(... 'orders' ..., 300000)`).
- Where the shop needs ids that grow, it reads them: `orders.detail` and
  `orders.status` pick `max(id) - back`. A part in an instance of its own
  cannot read the core's `max(id)`.
- The shop's producer never creates customers. The clinic's core creates
  owners and animals every day: ids beyond the loaded range that a part's
  producer, drawing from the range, never meets.
- A variant's `population` (D263) sets the loaded ranges: a second
  variant of the same domain would change every range in every
  fragment.

**Options.** a. The core's GM notes state each key's loaded range and
where its sequence resumes; a part's fragments draw only from loaded
ranges; an entity created during the game reaches a part only through a
purpose, as the procedure's flows do. b. Parts read the core's ids over a
second connection: one more cross-instance link, against the separation
the procedure keeps. c. Ranges as placeholders the render fills from the
variant's population: a render change.

**Recommendation.** a, the ranges a required part of the GM notes' "the
data" section; c only once a domain builds a second variant, which v0.5
does not (D263).

## 8. Inbound flows: round trips and the scheduler's other targets

**What.** The clinic receives: external labs' results, other clinics'
requests and answers, machine uploads and logs, messages. Round trips
(D201; O128) make an acknowledgement an input the setup waits on. D118
promised message queues and APIs from v0.5, and D248 kept those the
clinic's flows need.

**Evidence.**

- v0.4's outside party is a scheduler node with the SQL driver:
  `fixture-campaign`'s `gateway` runs the customs stub as `customs_gw`,
  reading `customs_outbox` and writing `customs_acks` straight into the
  shop's database every 15 seconds, losing one acknowledgement in fifty
  by a hash (D214); its outages are timeline changes of its key. That
  pattern already gives late (slots), missing and rejected
  acknowledgements; duplicates and out-of-order ones are more SQL.
- The scheduler has one driver, `sql/postgresql` (`schedule.py`:
  `DRIVERS`). The driver interface runs statements (`drivers/__init__.py`);
  a queue's consume or an API's response is a result, and no repository
  entry passes one call's result to the next: builders cannot read, and
  scripts are jobs only, PostgreSQL only.
- No broker brick and no API brick exist. An API target needs a server
  for the scheduler to call; a queue needs a broker and something that
  moves messages into a database.
- The exchange between two clinics is two instances (O127): a stub per
  side, each on its own database, with our transformer job moving the
  rows between them, needs nothing new.

**Options.** a. SQL stubs for every inbound flow in v0.5, the v0.4
pattern; a round trip's repertoire (late, duplicated, out of order,
unmatched) as stub keys switched by timeline changes (D127). b. An API
target: an `http` driver and a small API brick, the clinic's integration
endpoint, writing into its database; its retries and idempotency become
the players' to audit. c. A queue: a broker brick, a queue driver and a
new entry kind that consumes and writes. d. Scripts allowed on streams,
as a general bridge.

**Recommendation.** a as O128's baseline. Which flow, if any, earns b or
c is decided once `vet-lab` and `vet-machinery` are defined, against the
faults it would carry; until then their fragments use SQL. d not needed
for the exchange between clinics.

## 9. Many small consumers that all look alike

**What.** Housing has one display per animal reading its file (D196):
some hundred consumers.

**Evidence.** Every session a scheduler node opens carries the node's
hostname as `application_name` (`pools.py`, `scripts.py`): in
`pg_stat_activity` one display cannot be told from another. A hundred
direct connections would also meet `max_connections`' default of 100
(D138).

**Options.** a. The displays talk to a display service holding a pool,
as real ones do: one stream, its concurrency the service's. b.
Connections per call, for the churn. c. A per-session `application_name`
pattern: a scheduler change.

**Recommendation.** a, unless a `vet-housing` fault needs to tell one
display from another; decided at `vet-housing`'s profile step (step 6).

## 10. Several sites in different time zones

**What.** The franchise has three centres in the country and several
abroad (D196).

**Evidence.** The customer's zone is one fixed offset, UTC plus the
shift; shapes and jobs are in scenario time, rendered with that one shift
(master spec 8.3). A job's `timezone:` is reserved for the
wrong-time-zone fault (7.1). The shop handles other zones only as
recipients' offsets in its data.

**Options.** a. Every site in the customer's zone in v0.5 (the centres
abroad in neighbouring countries of the same zone). b. Per-site offsets,
each site's schedule rendered with an extra fixed offset: a render
change, and `timezone:` no longer a fault's marker.

**Recommendation.** a, with O127's topology side.

## 11. Data growth over the aging

**What.** The machinery's readings are a time series ([brick options
review](brick-options-review.md): plain partitioned tables, D250).

**Evidence.** One row a second is about 170 000 rows over two days
([load and capacity](../../archive/v0.3/load-and-capacity.md),
"Calibrating the load"); twenty machines at one reading a second are
1.7 million rows a day, against "the data schema stays simple and the
tables small" ([platform.md](../../platform.md)) and the database's disk
reservation.

**Options.** a. Readings at a coarser grain (every ten seconds to a
minute), or one row a minute holding a batch. b. Sub-second readings with
a larger disk. Either way the profile states its growth an hour at
intensity 1.0, so the GM sizes the disk.

**Recommendation.** a, and every domain's GM notes state the growth an
hour of its producers; decided at `vet-machinery`'s profile step.

## Rulings for the owner

Each with its recommendation; "agreed" accepts it.

1. **Merging (1).** Keep the hand merge at design time, add the naming
   rule (a part's query keys, connections and shapes carry its prefix)
   and a loader check refusing duplicate keys in a scenario's scheduler
   files; decide a `gmctl` compose helper when the clinic's scenario is
   built. Recommended.
2. **Readable profiles (2).** Accept them on the trust line (D13); a
   fragment never carries a timeline, an intensity or a planted fault.
   Recommended.
3. **Rates (3).** A domain's rates are its variant's throughput at
   intensity 1.0 (D263); the scenario sets each node's intensity at
   design time; the GM notes compare the rates' daily volume with the
   history's. Recommended.
4. **Long cadences (4).** Extend D199 to domains: monthly and yearly
   outputs exist as history the load computes and live through their
   sub-daily feeders; no fault's evidence rests on a monthly or yearly
   run. Recommended.
5. **Input types (5).** SQL-side generation and domain builders; no new
   generator in v0.5 unless the clinic's fragments keep needing a
   weighted choice. Recommended.
6. **Producer nodes (6).** A producer node is one application of the
   business; cross-instance flows are purposes' transformer jobs.
   Recommended.
7. **Key ranges (7).** The core's GM notes state each key's loaded range;
   parts draw only from loaded ranges; entities created during the game
   reach parts through purposes; placeholders filled from a variant's
   population wait for a domain's second variant. Recommended.
8. **Inbound flows (8).** SQL stubs as the round trips' baseline (O128);
   which flow earns an API or queue target is decided once `vet-lab` and
   `vet-machinery` are defined. Recommended.
9. **Time zones (10).** Every site in the customer's zone in v0.5.
   Recommended.

Frictions 9 and 11 are decided at `vet-housing`'s and `vet-machinery`'s
profile steps.
