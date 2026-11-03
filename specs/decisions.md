# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived, verbatim, with where each one now lives in its milestone's
README:

- D1–D54 (v0.1):
  [archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md),
  mapped in [archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
- D55–D106 (v0.2):
  [archive/v0.2/decisions-D55-D106.md](archive/v0.2/decisions-D55-D106.md),
  mapped in [archive/v0.2/README.md](archive/v0.2/README.md#where-it-now-lives).
- D108–D112 and D114–D189 (v0.3):
  [archive/v0.3/decisions-D108-D112.md](archive/v0.3/decisions-D108-D112.md)
  and [archive/v0.3/decisions-D114-D189.md](archive/v0.3/decisions-D114-D189.md),
  mapped in [archive/v0.3/README.md](archive/v0.3/README.md#where-it-now-lives).
- D190–D191, D193–D195, D197–D200, D202–D231, D239–D247, D252–D258,
  D281–D284, D305 and D310–D313 (v0.4), one file per range in
  [archive/v0.4/](archive/v0.4/README.md#archived-files), mapped in
  [archive/v0.4/README.md](archive/v0.4/README.md#where-it-now-lives).

Archived IDs keep their meaning and are cited as they are. D107 and D113
stay live: rulings still to be applied in v0.5. The rest is v0.5's: D192,
D196 and D201, its scope set while v0.4 was drafted, then its drafting
from D233 on (D233–D238, D248–D251, D260–D280, D285–D304, D306–D309 and
D314 onward; the numbers between are v0.4's, archived;
D337 and D341 were reserved and never used). Take the next number from
`doc-ids`; no ID is reused.

- **D107 (2026-10-21, owner direction, relayed by the wave driver): Brick
  options are a v0.5 topic; v0.2 stays as built.** The `postgres` brick
  will offer optional elements (PostGIS, TimescaleDB, pgBadger,
  replication modules...), each documented and added to a scenario when
  appropriate; v0.5 improves and extends the bricks. Design open: O79,
  O80. Now in: [versions/v0.5/README.md](versions/v0.5/README.md).
- **D113 (2026-10-22, owner ruling at the v0.2 release close; RG-5): The
  `monitoring` role stays in every postgres game until v0.5.** The owner:
  "monitoring isn't mandatory in any game (highly suspect if there isn't
  any of course, but it remains a valid game)", then "Keep, move to
  v0.5". Making the role conditional on the game having monitoring is a
  brick improvement, with O79. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md) "In scope",
  [versions/v0.2/README.md](versions/v0.2/README.md) "Known issues".
- **D192 (2026-10-28, owner direction, relayed by the lead session): v0.5
  brings business domains:** a reusable catalogue unit (working name) of
  a business data model, producer profiles, common scheduler scripts and
  input types, and fitting purposes; a scenario is a domain, a size,
  bricks, purposes and faults. v0.4 ships one, the shop, structured so
  more can be added. Open: O111–O114; O108, O47 revised. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **D196 (2026-10-30, owner input, relayed by the wave driver): The
  veterinary clinic franchise is a v0.5 domain candidate,** the flagship
  of the regulated domains; v0.4 only borrows its strict reporting and
  its data classes as test cases, scope unchanged. Open: O126, O127;
  O112 revised. Now in: [versions/v0.5/README.md](versions/v0.5/README.md)
  "The veterinary clinic".
- **D201 (2026-10-30, owner idea, relayed by the coordinator; placed in
  v0.5 by the owner): Round trips, an acknowledgement as an inbound flow
  that the setup waits on and that drives further processes, are v0.5's;**
  v0.4's P5 only records and checks acknowledgements and opens an
  incident. Open: O128. Now in: [versions/v0.5/README.md](versions/v0.5/README.md)
  "Round trips"; [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md) P5.
- **D233 (2026-10-31, owner direction, relayed by the coordinator): v0.5
  centres on domain definition, the veterinary clinic franchise (D196)
  its worked example; tools unrelated to the clinic move later
  ("probably v1.0+"), bastion-related items unrelated to it to v0.6.**
  The owner will help define the clinic's bricks, faults, topology and
  configurations later. Every earlier v0.5 item sorted, the judgment
  calls proposed (O137). Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#sorting-d233),
  [versions/v0.6/README.md](versions/v0.6/README.md#the-setups-entry-point-d224),
  [versions/README.md](versions/README.md#deferred-from-v05-d233-d237).
- **D234 (2026-10-31, owner direction, relayed by the coordinator): A
  collection of real incident reports (post-mortems, retex) begins in
  v0.5, in `post_mortem/` at the repository's root, each entry with the
  source's stack and topology, symptoms, diagnosis, resolution and a hard
  link; not bound to faults yet.** Intended later use: an end-of-game
  handout, a replicated main culprit with the real failure's
  explanation. Open: O138. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-post-mortem-collection-d234).
- **D235 (2026-10-31, owner direction, relayed by the coordinator): A
  domain is defined through a procedure, what goes in and what does not;
  whether domains beyond the clinic's join v0.5 waits until the
  procedure shows what defining one costs.** The owner: "the clinic will
  probably spawn multiple such domain". Drafted, not approved (O139);
  O112 deferred, O126 and O127 narrowed. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md).
- **D236 (2026-10-31, owner direction, relayed by the coordinator): Brick
  options (D107; O79, O80) stay in v0.5, tied to the clinic, and are
  reviewed against what its parts need.** The owner: "brick options may
  come in with the clinic scenario honestly. We need to review this as
  well." Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md).
- **D237 (2026-10-31, owner direction, relayed by the coordinator):
  Bluebox and the other datasets (O53, O54) move to a later version, not
  set; Bluebox, "quite akin to a domain", is a later domain candidate
  brought in through the procedure, its dataset filling the data
  model.** Now in: [versions/README.md](versions/README.md#deferred-from-v05-d233-d237),
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 2.
- **D238 (2026-10-31, owner correction, relayed by the coordinator):
  pgwatch and pgCluu stay in v0.5 as the clinic's monitoring, and
  "related to the clinic" is judged against what a setting that complex
  plausibly needs, monitoring breadth included; amends D233's tool
  rule.** The owner: "they are monitoring tooling that are required in
  such complex settings." Nagios-style health tools stay with them; the
  other tools re-sorted. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#sorting-d233),
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md).
- **D248 (2026-10-31, owner ruling on spec-writer's scope review,
  relayed by the coordinator: "accept all recomendations for v0.5"):
  v0.5's sorting stands with every proposed row as proposed, and v0.5
  ships a scenario using the clinic's domains.** Scenario generation
  comes in v1.0. Closes O137 and O47. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#sorting-d233),
  [versions/README.md](versions/README.md#deferred-from-v05-d233-d237),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **D249 (2026-10-31, owner ruling, same review): The clinic splits into
  the procedure's seven domains, revised once `vet-core` is defined;
  domains compose as a core and parts one level deep, flows between
  parts as purposes, keys by id without foreign keys to the core, a part
  taken only with its core, tried first on `vet-core` and `vet-lab`.**
  The four format changes are built in one chunk; the procedure becomes
  a skill after two or three domains. Closes O126; O111 and O139
  narrowed. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 4, 6, 8.
- **D250 (2026-10-31, owner ruling, same review): For the clinic,
  `postgres` keeps plain partitioned tables before any TimescaleDB,
  offers replication as a standby mode, has TLS always available and
  turned on by the seed, and makes only the `monitoring` role an option
  of today's four elements.** O79 and O118 narrowed; pgaudit's form
  stays open. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md).
- **D251 (2026-10-31, owner ruling, same review): Post-mortems are bound
  to faults in a later version; the end-of-game handout comes after the
  final answer and summarises and links its source, never copying it.**
  O138 narrowed. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-post-mortem-collection-d234).
- **D260 (2026-10-31, owner ruling on spec-writer's recommendations,
  relayed by the coordinator: "agreed to your recomendations"): The
  domain procedure is approved as drafted: what a domain holds and
  leaves out, the steps and who takes part, done and its checklist, the
  effort estimate.** With D249, the whole procedure is settled. Closes
  O139. Now in: [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 1, 2, 3, 7.
- **D261 (2026-10-31, owner ruling, same recommendations): pgaudit is
  not an option: it is always available in `postgres` and turned on by
  the seed, as TLS is (D250), its settings in the seed so their removal
  can be a fault.** The options model is left serving the `monitoring`
  role alone. Closes O118, TLS ruled by D250; O79 narrowed. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md#the-owners-rulings-d250-d261-d262).
- **D262 (2026-10-31, owner ruling, same recommendations): Options are
  for `postgres` only, unless one of the clinic's parts calls for
  another brick.** `postgres` is the only brick the clinic is known to
  need them on; a part that calls for one raises its own question.
  Closes O80. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md#the-owners-rulings-d250-d261-d262).
- **D263 (2026-11-01, owner ruling on the lead's proposal, relayed by the
  coordinator): "Size" becomes a domain's scale, on three axes
  (population, history, throughput); one domain covers several setups
  as variants, short manifests of parts, scale, purposes and tags from a
  fixed vocabulary; large setups show through structure, not volume;
  v0.5 builds one variant per domain.** The owner: "size isnt sufficient
  to describe whatever it is." Closes O114. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 9.
- **D264 (2026-11-01, owner ruling, "agreed" to the lead's proposal,
  relayed by the coordinator): A `gmctl compose` script merges a node's
  fragments at design time, built with the format changes:** layers
  domain default < variant profile < scenario, a higher layer winning
  silently and the merge report recording it; a profile-to-profile
  conflict stops the merge, its resolution in the scenario's
  `merge.yaml`; part prefixes, provenance comments, duplicate keys
  refused. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 1.
- **D265 (2026-11-01, owner ruling, same proposal): Weekly, monthly and
  yearly reports are part of the game:** past periods planted by the
  load, unseen in logs and pgwatch; if the GM plants faults there, at
  least one shows a witness within the aging; one periodic run may be
  scheduled in the aging; every report runs on demand for a period;
  calibrated per node, never killed for memory. Replaces D199 for
  domains. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 4.
- **D266 (2026-11-01, owner ruling, same proposal): `vet-core` is the
  system of record for owners and animals,** reached through a lookup
  API or a synced reference table; natural identifiers (microchip,
  UELN and passport, ear tag) carry identity across systems and are
  fault vectors; no central id provider; an EMPI-style `vet-identity`
  part maybe later. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 7,
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md).
- **D267 (2026-11-01, owner ruling, same proposal): An `api` brick on
  FastAPI serves endpoint files the GM drops in, and the scheduler gets
  an HTTP driver as its caller;** first for the core's lookup API, the
  external labs and the machinery; FastAPI and uvicorn pass a
  security-advisor dependency check before the build; message queues
  wait for a flow that needs one. Narrows D118 and D248's targets. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D268 (2026-11-01, owner ruling, same proposal): The external lab is
  a consumer-producer round trip over APIs:** the clinic POSTs an order,
  gets "accepted" with a correlation id, and the lab's stub calls back
  hours later; its faults are lost, duplicate, late or out-of-order
  callbacks, a wrong correlation id, a retry without an idempotency key;
  SQL stubs stay where no API is needed. O128 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D269 (2026-11-01, owner ruling, relayed by the coordinator): No
  periodic report runs on demand in v0.5;** "run March's report now"
  comes later, probably v1.0+, possibly v0.6, on an instance spawned for
  the occasion. Revises D265; D117 and D131 stand. The owner: "we're
  barely begining to introduce API and stuff like that." Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 4.
- **D270 (2026-11-01, owner ruling, same message, amended the same day
  by his addendum): An `api` node in the players' scope only answers
  requests;** producers and consumers on scheduler nodes call it. The
  one exception is a third party outside the players' scope, the
  external lab, whose callbacks initiate, still driven by its hidden
  schedule. The owner: "API layer isn't a scheduler"; then "that's out
  of player's scope." Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D271 (2026-11-01, owner ruling, same message): Players read every
  endpoint file of an `api` node and, where the scenario makes it
  fixable, edit its database side only** (queries, transactional work,
  session settings), never an endpoint's route or contract; application
  roles, a reload wrapper. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D272 (2026-11-01, owner direction, same message): v1.0 to v2 leans
  to DBA work with bits of devops:** reports on a spawned instance,
  major-version upgrades, hotfixes, moving providers, setting up
  replication. v0.5 is not widened. Now in:
  [versions/README.md](versions/README.md#v10-to-v2-dba-work-with-bits-of-devops-d272).
- **D273 (2026-11-01, owner ruling, "agreed" to the lead's proposal,
  relayed by the coordinator): A third party's nodes are outside the
  players' reach:** no `player` account, no route on the bastion, not in
  the starter pack; a per-node option settled with the `api` brick.
  Hiding alone would not do: a player with a shell elsewhere finds them
  on the network. v0.4's customs gateway stays as built until the
  definition says otherwise. Raises O145. Now in:
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md) 3.
- **D274 (2026-11-01, owner ruling, "agreed with your recomendations",
  relayed by the coordinator): Third parties as the draft recommends,
  but for the network:** `no-access` made real, no new key; players may
  call a partner's public interface; `partners.md`, a fifth optional
  starter-pack file, on the bastion's page; a status page with v0.6; an
  unanswering in-world support contact; v0.4's customs gateway as
  built, a purpose's `receiver` a third party from v0.5; the centres
  abroad third parties; no fix ever on the partner's side. Closes O145
  with D275. Now in:
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md).
- **D275 (2026-11-01, owner ruling, same answer; against spec-writer's
  recommendation of a network of its own): v0.5 stays on one network;
  a third party's back end is closed by its own access rules,** its
  database's `pg_hba.conf` admitting only its own nodes, its other
  services only their callers. A real lab's API is reachable from
  outside, its database is not. Separate networks wait with O12. Now in:
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md) 3.
- **D276 (2026-11-01, owner confirmation "yes", relayed by the
  coordinator): O113's remaining recommendations are ruled as written:**
  readable profiles on the trust line, no timeline, intensity or planted
  fault in a fragment; rates the variant's throughput at intensity 1.0;
  values from SQL and domain builders; a producer node per application;
  every site in the customer's zone in v0.5; a variant's profile in
  `variants/<name>/producers/`. O113 narrowed to frictions 9 and 11. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md).
- **D277 (2026-11-01, same confirmation): A fix to a periodic report's
  fault is checked without a run on demand:** inputs or feeder on the
  feeder's next run; the report's code by the sealed check reading it,
  and against the scheduled run's output if the GM placed one; planted
  past outputs stay wrong, the players recommending the rerun. Completes
  D269. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 4.
- **D278 (2026-11-01, owner answer "agreed" to the defaults the lead
  listed, relayed by the coordinator): `vet-core`'s business sketch is
  ruled with all fourteen answers as proposed:** one shared record for
  the three national centres; Aldermoor Veterinary Hospitals in an
  unnamed EU state; hospital stays, medicines and referrals in the
  core; no billing or pharmacy part in v0.5; the scale figures; the
  variant `regional-franchise`; the identifiers and a dozen mistyped
  chips. Closes O144. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-owners-answers-d278).
- **D279 (2026-11-01, owner confirmation "ok understood and agreed",
  relayed by the coordinator): The clinic's split is confirmed as
  revised, lab and imaging requests and alerts in the core;** and the
  history shows the clinic's growth, its daily volumes ramping up to
  today's live rates, not a busy season (the shop's). `clinic` holds
  `vet-core` only; the parts land where `domains:` `at:` places them.
  Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-split-step-3-confirmed-d279).
- **D280 (2026-11-01, owner confirmation "they're great", relayed by
  the coordinator): `vet-core`'s step 5 is ruled:** the classification
  as drafted and the eleven rules of its default policy, with their
  game values; the lower year totals the growth curve gives (about
  73 000 consultations, 44 000 prescriptions, 0.82 million rows) are
  accepted. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-rules-as-the-owner-confirmed-them-d280).
- **D285 (2026-11-02, owner ruling, relayed by the coordinator): A
  clinic scenario deploys one centre; the rest are third parties.** Each
  national centre is independent with its own records, the exchanges
  between centres privileged flows; this replaces D278's first answer
  (one shared record for the three). The other centres, those abroad and
  the franchise's central systems are stub `api` nodes only (D273–D275).
  Each centre has its own lab, which the region's clinics pay to use.
  Closes O127; raises O147. Now in:
  [versions/v0.5/one-centre.md](versions/v0.5/one-centre.md).
- **D286 (2026-11-02, owner ruling, same message): A round trip is a
  purpose kind of its own:** request, correlation key, expected answer,
  timeout, reactions; P5 stays as built. A cascade's fix is judged end to
  end on the trace after the fix; a symptom fixed alone earns nothing;
  the backlog left is a creditable consequence, no fault. Closes O128.
  Now in: [versions/v0.5/README.md](versions/v0.5/README.md#round-trips-acknowledgements-as-inputs-d201).
- **D287 (2026-11-02, owner ruling, same message): The housing displays
  talk to a ward service holding a pool,** no scheduler change; a faulty
  display is found through the ward service's redundant query and the
  box→stay→animal relation the housing data holds. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 9.
- **D288 (2026-11-02, owner direction, same message): Heavy continuous
  data keeps a day on site and ships the rest to cold storage,** out of
  the game, shown minimally (type, rows, date); the housing displays log
  action events only, small. The design is proposed; raises O148. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 11,
  [versions/v0.5/cold-storage.md](versions/v0.5/cold-storage.md).
- **D289 (2026-11-02, owner ruling "ok for now, if it needs upgrading
  we'll handle it then", same message): The options model as proposed,**
  one option, `monitoring` on `postgres`, chosen per node, off unless
  chosen, one image. Closes O79. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md#the-options-model-d289).
- **D290 (2026-11-02, owner ruling, same message): The clinic's scenario
  has ten faults at most:** one dramatic, noticed by the customer; two on
  the verge; the rest optimisations and minor frictions. An issue may be a
  false alarm. O23 narrowed to the general rule. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#in-scope),
  [bricks-and-faults.md](bricks-and-faults.md).
- **D291 (2026-11-02, owner answer "ok", same message): The domain format
  is finalised in v0.5's master spec,** when the version consolidates;
  O111 closes then. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#in-scope).
- **D292 (2026-11-02, owner ruling, same message): v0.5 is the clinic
  only; other domains come after it.** The owner: "i belive v0.5 is
  already big, so they'll wait". Closes O112. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains),
  [versions/README.md](versions/README.md).
- **D293 (2026-11-02, owner ruling "agreed with all your
  recommendations", relayed by the coordinator): One centre's parts and
  partners as proposed:** `vet-portal` the centre's; `vet-messaging` the
  franchise's, a third party traced by the outbox, so the clinic is the
  core and five parts; the external lab kept; the exchanges with the
  other centres round trips over their stubs, replacing D268's
  transformer job; one back end, a scheduler node and a database, shared
  by every partner; "privileged flows" read as trusted intra-franchise
  flows. Closes O147 with D294, D295. Now in:
  [versions/v0.5/one-centre.md](versions/v0.5/one-centre.md).
- **D294 (2026-11-02, owner ruling "billing: do bill external lab", same
  message): The lab bills its outside customers,** inside `vet-lab`:
  prices, each outside order's charge, a monthly statement per customer
  clinic as a periodic report; nothing for animal owners. Narrows D278's
  eighth answer. Now in:
  [versions/v0.5/one-centre.md](versions/v0.5/one-centre.md#2-the-labs-partners-d293-d294).
- **D295 (2026-11-02, same message): `vet-core` is rescaled to one
  centre, a third of each figure** (about 0.28 million rows), its ratios
  and growth curve kept; `staff_sites` and the staff's home site go. Now
  in: [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-variant-its-scale-and-its-tags).
- **D296 (2026-11-02, same message): Cold storage's design as drafted,**
  the threshold about 50 000 rows a day, its manifests in the partners'
  shared database (from D293); the bastion routes the players to its
  read-only page and endpoints, a stated exception to third parties'
  rule. The owner: "yes the bastion must be able to route the player to
  this coldstorage. keep it simple for now." Closes O148 with D297. Now
  in: [versions/v0.5/cold-storage.md](versions/v0.5/cold-storage.md).
- **D297 (2026-11-02, owner ruling, same message): The GM decides per
  data type what ships, use first, volume second:** data the exercise's
  purposes, transformations or reports read stays on site or ships only
  after its consumers' cadence and a margin; the threshold only marks a
  candidate. Now in:
  [versions/v0.5/cold-storage.md](versions/v0.5/cold-storage.md#6-when-a-data-type-ships-d297).
- **D298 (2026-11-02, same message): Friction 11's profile as drafted:**
  the displays' action events, the machines' moderate readings with a
  day on site, every domain's growth an hour in its GM notes. Closes
  O113. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 11.
- **D299 (2026-11-02, owner answers "ok", relayed by the coordinator):
  Replication as proposed:** an asynchronous, readable standby of the
  instance holding `vet-core`, with a slot, on an off-site node in the
  players' scope, the only one in v0.5; WAL archiving (`archive_timeout`
  1h) and a nightly base backup to cold storage as types `wal` and
  `basebackup`; every fault candidate. The periodic reports read on the
  standby; where they write stays O149, narrowed. O49 keeps pgBackRest,
  restores and PITR for v1.0+. Now in:
  [versions/v0.5/replication.md](versions/v0.5/replication.md).
- **D300 (2026-11-02, owner ruling "agreed for the office database",
  relayed by the coordinator): The periodic reports write to a
  back-office database, `office`, on the primary's instance,** holding
  the reports' outputs, the lab's monthly statements and copies of the
  regulatory submissions; an office role reads the standby, writes
  `office`, never the clinic's record; no domain part, D293 standing; a
  variant may move it; its fault candidates accepted. Closes O149. Now
  in: [versions/v0.5/replication.md](versions/v0.5/replication.md#3-where-the-reports-write-a-back-office-database-d300).
- **D301 (2026-11-02, owner answer accepting every default, relayed by
  the coordinator): `vet-lab`'s business sketch is ruled with all
  fifteen answers as proposed:** the lab on a separate `postgres` node,
  "not just a separate database", its WAL and base backups to the vault
  (extending D299); one order API; `requests` gains `priority` and loses
  `external`; outside patients never core animals; a result per analyte;
  milk residue screening only; the lab itself notifies, as national law
  requires of labs; a part's scale in a manifest of the core variant's
  name (feeds O111). Closes O151. Now in:
  [versions/v0.5/vet-lab-domain.md](versions/v0.5/vet-lab-domain.md#the-owners-answers-d301).
- **D302 (2026-11-02, owner confirmation "agreed", relayed by the
  coordinator): `vet-lab`'s steps 4 and 5 are ruled as drafted:** the
  eight plausibility points (the two constraints on `vet-core`'s load
  among them, now applied there) and the thirteen rules of its default
  policy, with their game values. Closes O152. Now in:
  [versions/v0.5/vet-lab-domain.md](versions/v0.5/vet-lab-domain.md#the-rules-as-the-owner-confirmed-them-d302).
- **D303 (2026-11-02, owner answer "agreed", relayed by the coordinator):
  What the clinic's first profiles need of the scheduler and the format,
  as recommended:** script jobs with an HTTP connection, built with the
  HTTP driver, partners ticking their own `api` node; the driver's
  least; a weighted `choice` in the same bump; `producers/api/<node>/`
  and `producers/partners/<partner>/` (feeds O111). Closes O154. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md#12-what-the-clinics-first-profiles-need-ruled-d303).
- **D304 (2026-11-02, same answer): `vet-core`'s and `vet-lab`'s producer
  profiles (step 6) are ruled as drafted, all fifteen points;** among
  them `lab_app` writes `lab_charges`, amending D302's grants, and the
  other centres order nothing from the lab. Closes O153. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#points-for-the-owner-ruled-d304),
  [versions/v0.5/vet-lab-domain.md](versions/v0.5/vet-lab-domain.md#points-for-the-owner-ruled-d304),
  [versions/v0.5/one-centre.md](versions/v0.5/one-centre.md).
- **D306 (2026-11-02, owner answer "agreed", relayed by the coordinator):
  `vet-core`'s and `vet-lab`'s purposes (step 7) are ruled as drafted,
  all eight points:** the ten purposes built in v0.5 (the release to the
  portal waits for `vet-portal`, the electronic referral report later);
  the `interfaces` and `backoffice` scheduler nodes and the critical
  calls on the lab's `pg_cron`; results polled from a released-results
  feed on `lab-api` every 5 minutes with a watermark, the lab never
  writing `clinic`; `office_jobs` writing `office` only, the reports
  reading as `vet_reports` and `lab_reports` (settling replication.md's
  name); `exchanges` and its streams and endpoints under `vet_exchange`,
  amending vet-core steps 4 and 6; rare-flow faults only with a story
  raising the rate from T0 in the profile layer; one notification
  purpose, `diagnosis_codes.notifiable` none/A/other, the lab's
  deadlines for the vet's; the game values; and vet-lab's two asks (the
  feed on `lab-api`, `resend` on the external lab's stub). Closes O155.
  Now in: [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md#points-for-the-owner-ruled-d306).
- **D307 (2026-11-02, same answer): The purpose format's extensions are
  accepted as listed** in clinic-purposes.md section 4 (the round-trip
  block, the `api` and `partner` parts, HTTP connections, endpoint and
  receiver material, periodic jobs with feeder and planted history,
  `judged:`, the classes of a purpose's tables, the `ops` schema); they
  feed O111. Closes O156. Now in:
  [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md#4-the-format-and-what-the-round-trip-extends-ruled-d307).
- **D308 (2026-11-02, owner ruling, relayed by the coordinator): The
  partners' stubs are grouped on one `api` node,** each partner under
  its own hostname through network aliases, so players still see
  distinct partners; with the shared scheduler and database, three
  partner nodes instead of eleven. Per partner still: its routes, its
  `partners.md` entry, its misbehaviour keys, and for cold storage alone
  the bastion's route to its page (D296). The owner: "Indeed partners
  can be grouped for ease of usage." Amends D293's node count. Now in:
  [versions/v0.5/one-centre.md](versions/v0.5/one-centre.md#4-the-partners-nodes-d293-d308),
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md) 3.
- **D309 (2026-11-02, owner ruling, relayed by the coordinator):
  Selecting a scenario's faults is the GM's role,** at deploy, with
  whoever sets up the game; a domain's step 8 lists the traps with their
  D290 classes and stops there. Amends D233's "the owner joins when he
  defines faults" and the procedure's step 8 owner column; D290's cap
  and mix still bind any selection. The spec picks a test selection for
  the build's smoke run and the proof in play, a fixture, not the
  canonical scenario. The owner: "selecting the faults is the GM's role
  (with the assistance of the person that setup the game)". Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#2-the-steps-from-a-brief-to-a-finished-domain),
  [bricks-and-faults.md](bricks-and-faults.md).
- **D314 (2026-11-03, owner rulings, relayed by the coordinator): v0.5
  tests short tests only, under 30 minutes each on the least environment
  that proves its brick or feature; one exception, the whole clinic
  deployed once, on armenelos plus the VPS, as step 11's proof in play.**
  Sharpens D311 and D312. Every longer run (aging, overnight cadences,
  the rehearsal, the stance check) goes to the major test before the
  v1.0 tag. The VPS rules stand (D159). Closes O158. The owner: "we must
  restrict testing to short tests (validate that new bricks/features
  works simply with minimal environment) we will do a major test prior
  taging v1.0, any long running (>30m) will be done there"; "i'll accept
  an exception for deploying the whole clinic on this milestone"; "yes,
  two hosts are covered by the exception." Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#testing-in-v05-d314),
  [versions/README.md](versions/README.md#v10-gating).
- **D315 (2026-11-03, owner answer "i accept recomendations", relayed by
  the coordinator): A request the centre has sent to its lab is not
  cancelled from the clinic:** the vet phones, the lab cancels the test,
  and the results feed brings the cancellation back, as a test not
  performed; `requests.cancel` takes `requested` requests only; no new
  endpoint. Closes O164. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#rates-at-intensity-10),
  [versions/v0.5/vet-lab-domain.md](versions/v0.5/vet-lab-domain.md#rates-at-intensity-10),
  [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md) 5.
- **D316 (2026-11-03, same answer): v0.5 builds the test selection's ten
  faults and its false alarm's material;** every other trap stays listed
  for the GM, to write as a scenario's own fault when a game selects it
  (D309). Closes O165. Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md),
  [versions/v0.5/clinic-traps.md](versions/v0.5/clinic-traps.md).
- **D317 (2026-11-03, owner answer, relayed by the coordinator):
  `vet-scheduling`'s draft accepted as recommended.** The owner: "i
  agree with the recommendations as a whole". O168–O179 closed as the
  page recommends, but for the fold-in's changes: ten bookable machines,
  the core's staff layout and the purposes' numbers (D324), no
  appointment reminders (D321). Now in:
  [versions/v0.5/vet-scheduling-domain.md](versions/v0.5/vet-scheduling-domain.md#questions-for-the-owner).
- **D318 (2026-11-03, same answer): `vet-housing`'s draft accepted as
  recommended,** O180–O190 closed, but for O184's load: the tables stay
  in `clinic`, declared `lands_with: vet-core`, and the load computes
  the core's stays by functions instead of reading them (D322). Now in:
  [versions/v0.5/vet-housing-domain.md](versions/v0.5/vet-housing-domain.md#questions-for-the-owner).
- **D319 (2026-11-03, same answer): `vet-machinery`'s draft accepted as
  recommended,** O192–O203 closed, but for O203 (T208 stays a trap, s9
  going to T150, D325) and O198's staff ids (D324); O195's several
  databases are proposed format text for O111 (D323). Now in:
  [versions/v0.5/vet-machinery-domain.md](versions/v0.5/vet-machinery-domain.md#questions-for-the-owner).
- **D320 (2026-11-03, same answer): `vet-portal`'s draft accepted as
  recommended,** O204–O215 closed, but for O213: the load computes the
  sources' keys by functions, and only the copied content comes from a
  derivation step the GM sanctions (D322). Now in:
  [versions/v0.5/vet-portal-domain.md](versions/v0.5/vet-portal-domain.md#loading).
- **D321 (2026-11-03, owner ruling, relayed by the coordinator): No
  appointment reminders in v0.5;** the portal reminds owners of
  vaccinations only, with their consent. Scheduling had left them to the
  portal, the portal had left them out. `sched_upcoming` is not built.
  Now in:
  [versions/v0.5/vet-scheduling-domain.md](versions/v0.5/vet-scheduling-domain.md#no-appointment-reminders-in-v05-d321).
- **D322 (2026-11-03, owner ruling, relayed by the coordinator): The
  initial load is a step the GM adjudicates for the whole system; D249's
  deterministic keys stay the default.** The owner, after the
  coordinator recommended keeping D249: "although you are also right,
  initial load is a major step and will need to be adjudicated by the gm
  for coherence across the system." A part's load computes the core's
  keys from its documented ranges and functions (housing and the portal
  move to it); the GM checks and records cross-domain coherence at
  composition, may sanction an ordered derivation step, and placement
  constraints are declared (`lands_with`). The mechanism's details are
  (proposed), confirmed with the master spec (O111). Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#10-composing-domains-d322).
- **D323 (2026-11-03, same ruling): The parts' format changes join
  O111 as proposed format text:** a several-database part (O195),
  `lands_with`, the derivation step, a traffic source that is no
  business, the composition record, the `SECURITY DEFINER` check. Now
  in: [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#the-format-changes-the-parts-propose-for-o111).
- **D324 (2026-11-03, spec choice at the fold-in): The parts' overlaps
  settled in one layout.** Purposes renumbered 11–16 (scheduling,
  machinery, portal), housing's occupancy in purpose 9; machine ids are
  `vet-machinery`'s, ten bookable (7–16); one staff layout in the core
  within D295's 85; the imaging team cancels a sent imaging request, as
  D315 for the lab. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#deterministic-key-ranges-d249-d266),
  [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md#16-the-parts-purposes-11-to-16).
- **D325 (2026-11-03, spec choice, the GM's under D309): The test
  selection takes T270 for s5 and T150 for s9;** nothing of the ten
  tested row-level security, owner-scoped access or D287's display.
  T208 stays a trap; D290's mix holds (1 D, 2 V, 7 M). T150 is judged on
  the report at the final answer: the GM never switches the display off
  during play ("Stop only", no events outside the schedule). Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md).
- **D326 (2026-11-03, owner answer, relayed by the coordinator): The
  composition mechanism and the parts' format text for O111 confirmed
  as written:** `lands_with`, a several-database part, `derive:` and
  `data/derive.sql`, the traffic source that is no business,
  `composition.yaml`, the post-load coherence check, the `SECURITY
  DEFINER` `search_path` check (D322, D323). The owner: "ok agreed".
  O111 settled in substance; the master spec carries it at
  consolidation (D291), which closes it. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#10-composing-domains-d322).
- **D327 (2026-11-03, same answer): Domestic vets go from 11 to 8**
  (staff 18–25), so the imaging staff fit D295's 85 in D324's layout;
  the total stays 85 and scheduling's shifts are unchanged. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#deterministic-key-ranges-d249-d266).
- **D328 (2026-11-03, same answer): No fault of the ten sits on an `api`
  node's `db/` side (D271)** now that T78 has left; the `api` brick's
  own build checks cover that side. Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md#the-selection).
- **D329 (2026-11-03, owner ruling, relayed by the coordinator): No data
  register for this repository, and no data preflight in v0.5's
  consolidation or build plan:** all data is synthetic. The game's own
  inventory is its catalogue. Replaces the README's "(proposed)" default
  on the data preflight. The owner: "this repo doesn't "need" to have a
  data register (the only data register the game itself would have will
  focus on bricks, faults, domains, etc)". Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#the-ruling-d329d331).
- **D330 (2026-11-03, same ruling): A scenario's data register is game
  content:** a player handout generated from the ground truth. It may
  carry a fault (out of step, absent, badly documented), a trap family
  (T300–T308). The clinic's test scenario gets one. Narrows O21 to the
  other starter files. The owner: "Scenarios may/should have data
  registries (as handout) to the players(could also be some fault here:
  desync from the ground truth, entierely absent, ill documented, etc)".
  Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md),
  [versions/v0.5/clinic-traps.md](versions/v0.5/clinic-traps.md#11-the-data-register-t300t308-d330).
- **D331 (2026-11-03, owner addition, relayed by the coordinator): A GM
  sub-skill, `data-register`, generates each scenario's register,**
  with a fault planted or not: the true register in `gm/` and the
  handout. Its details are (proposed). The owner: "it should probably be
  added as a subskill to the GM ensuring such registries get generated
  with the appropriate informations (with fault planted or not)." Now
  in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#3-generation-the-gms-data-register-skill-d331).
- **D332 (2026-11-03, spec choice, the GM's under D309): The test
  selection's s6 is T307, the vault not declared in the register,**
  replacing T49, which goes back to the traps; D290's mix holds (1 D,
  2 V, 7 M). Reason: T307 is the only fault that proves the register's
  planted deviation, and T49's mechanism was already proved in v0.4.
  Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md#the-selection).
- **D333 (2026-11-03, owner answer, relayed by the coordinator): A
  register fault is resolved by *propose*:** the corrected entry goes in
  the players' report, and the GM judges it against the answer key's
  `register_diff:`. A corrected file handed back waits for v0.6's
  reporting tool (O135). Closes O217. The owner: "i accept
  recommendations." Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#4-the-trap-family-the-register-itself-t300t308).
- **D334 (2026-11-03, same answer): The register's format additions go
  into the master spec with O111's text:** a domain's
  `data/register.yaml`, `governance.register`, `gm/data-register.yaml`,
  `register_diff:`, the loader's digest and coverage checks. Closes
  O218. Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#6-format-impact-o111-d334).
- **D335 (2026-11-03, same answer): Every scenario listing `domains:`
  must have a register,** and the deploy refuses one without it; v0.4's
  released shop scenario is exempt until next revised; optional with
  `governance:` alone. Closes O219. Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#3-generation-the-gms-data-register-skill-d331).
- **D336 (2026-11-03, same answer): The handout page's other
  "(proposed)" details stand as written,** D331's skill details
  included: the entry and its grouping, the two handouts, the skill's
  inputs, outputs, triggers and checks, the trap family, the chunks.
  Reason: the page went to the owner whole, and no question but
  O217–O219 was left on it. Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md).
- **D338 (2026-11-03, spec action at consolidation, on the owner's "yes,
  start the master spec"): O111 closed: the domain format is written
  into formats.md v28** ("Domain", "Scenario", "Purpose definition"):
  D326's composition items, the procedure's format changes, the variant
  and producer layout, the purpose format's extensions (D307) and the
  data register's additions (D334), as D291 set. Closes O111. Now in:
  [formats.md](formats.md#domain-from-v04-composed-domains-from-v05).
- **D339 (2026-11-03, owner approval, relayed by the coordinator): v0.5's
  master spec and access model are approved, with the review's R1–R3 and
  R5–R20 as recommended,** and the six domain documents with them
  (procedure step 9), corrected to the spec first (R16); purpose 2's
  30-second acknowledgement (R13), the night rota over the 25 section
  vets (R15). The owner: "agreed." Now in:
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md),
  [versions/v0.5/access-model.md](versions/v0.5/access-model.md).
- **D340 (2026-11-03, same answer, R4): The monitoring breadth is a
  `pgwatch` brick (pgwatch 3, its Prometheus sink feeding v0.2's
  Grafana), pgCluu in `postgres` run on demand as pgBadger is, and a
  light `health-check` node running `check_postgres` with a status page
  and the customer's scripts; one collector only if CPU is short.**
  Closes O220. The owner: "agreed." Now in:
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md#74-the-monitoring-breadth) 7.4, 14.
- **D342 (2026-11-03, owner approval, relayed by the coordinator): v0.5's
  build plan v1 is approved, with κ = 3 and its four plan choices as
  recommended:** the bumps and re-pins a chunk of their own (chunk 1),
  `bastion` 0.5.0 whole in the data-register chunk (17), each partner
  stub built by its domain's or purpose's chunk, the standby tooling in
  the `postgres` chunk (3). Clears G1, `v0.5-domains` merged into
  `main` by the coordinator. The owner: "agreed. merge. i'll clean after
  and start wave 1". Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md) (header,
  "Gates", "Workflow deltas").
- **D343 (2026-11-03, same answer): O223–O227 as the plan recommends:**
  `grafana` 0.3.0, the existing scenarios re-pinned (O223); if CPU is
  short, the exporters kept and pgwatch dropped (O224); pgCluu's report
  in the player's home, read with `scp` (O225); the health node on the
  VPS (O226); machine 10's telemetry settled by measurement in chunk 15
  (O227). Closes O223–O227. Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md#settled-with-the-owner).
- **D344 (2026-11-03, wave 1 preflight correction 1): A domain's
  producer fragments sit in one folder per scheduler node they target,
  `producers/<node>/`; `api`, `partners` and `public` are reserved; the
  shop's move to `producers/producer/`.** The approved format said a
  domain declares the nodes its fragments target, but not how;
  `vet-housing` feeds `pms` and `ward`. Now in:
  [formats.md](formats.md#producer-material),
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md#61-the-domain-format) 6.1, 8.4,
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md) chunks 2, 9, 12.
- **D345 (2026-11-03, correction 2): An `api` node's `api.yaml` names
  each endpoint's hostnames and accepted credentials and the node's
  connections; chunk 3 derives its roles' secrets and passwords from
  it, skipping `driver: http` connections.** 6.5 named the roles'
  secrets but nothing derived them; chunk 3 holds `localimpl.py` and
  `inject.py` in wave 1, so chunks 7 and 8 never share `inject.py`.
  Now in: [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md#65-brick-definition-brickyaml)
  6.5, 6.8; [formats.md](formats.md#producer-material);
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md) chunks 2, 3, 5, 6.
- **D346 (2026-11-03, correction 3): Chunk 1 writes `GM_OPTIONS:
  monitoring` into the hand-written stack files whose `postgres` serves
  an exporter.** Once chunk 3 creates `monitoring` only with the
  option, they would fail at wave 1's gate. Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md#chunk-1--versions-declarations-and-re-pins).
- **D347 (2026-11-03, correction 4): The HTTP credential's secret, name
  and readers are W1's, since chunks 4 and 5 read them in wave 1; W2
  keeps which nodes mount which, and chunk 7 mounts them on callers,
  `api` nodes and archiving `postgres` nodes.** Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md#chunk-7--render-for-v05-aliases-and-http-credentials).
- **D348 (2026-11-03, correction 5): Chunks 9 and 11 are cut once chunk
  6 has merged (in-wave edges `6 ──> 9`, `6 ──> 11`), not merge order
  only as proposed.** Until chunk 6 the loader refuses `driver: http`
  and the weighted `choice`, so vet-core's `check_domain_dir` and
  chunk 11's fixtures could not pass on a branch without it; chunk 10's
  edge stays merge order only (its key passes as unknown). Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md#waves) ("Read first", "Waves").
- **D349 (2026-11-03, correction 6): `api` joins the node roles, the
  `api` brick's; `pgwatch` and `health-check` take `monitoring`.** Now
  in: [formats.md](formats.md#roles);
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md) chunks 1, 2.
- **D350 (2026-11-03, correction 7): Chunk 6 reserves `options` and
  `standby_of` as parameters and `replicator` as a role, and checks a
  primary's replication line; chunk 4 forbids `replicator`.** Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md) chunks 4, 6.
- **D351 (2026-11-03, G5 and G6 cleared): Chunk 3 builds under G5's
  conditions, `vault-post` in Perl with core `HTTP::Tiny`, the snakeoil
  key deleted as advised; chunk 5 under G6's, from the hash-pinned
  `bricks/api/requirements.txt`; the PyPI source is listed as pending
  with the owner.** Now in:
  [versions/v0.5/build-plan.md](versions/v0.5/build-plan.md) chunks 3, 5,
  "Pending with the owner".
