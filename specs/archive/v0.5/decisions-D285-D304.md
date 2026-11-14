> **Archived 2026-11-14.** v0.5 closed (released at its release gate, G15 cleared by the owner on 2026-11-14, merged into `main`); entries D285 to D304 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan archived in the same pass were repaired to its archived path (`archive/v0.5/build-plan.md`), still written from `specs/`.

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
