# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Questions resolved by the close of v0.2
(O13, O50, O51 and O56–O77) are listed in
[archive/v0.2/open-questions-resolved.md](archive/v0.2/open-questions-resolved.md).
Questions resolved by the close of v0.3 (O45, O46, O78 and O81–O103) are
listed in
[archive/v0.3/open-questions-resolved.md](archive/v0.3/open-questions-resolved.md).
Questions resolved by the close of v0.4 (O104–O110, O115–O117, O119–O125,
O129, O131–O134, O140, O146 and O161–O163, and O111's v0.4 part) are
listed in
[archive/v0.4/open-questions-resolved.md](archive/v0.4/open-questions-resolved.md).
Take the next number from `doc-ids`; no ID is reused.

On 2026-10-31 v0.5 was centred on domain definition and the clinic
(D233), and its questions retargeted: O53 and O54 to later, version not
set (D237); O21 and O135 to v0.6; O24 and O25 to v1.0+ (D248). Resolved
during v0.5's drafting: O137 and O47 (D248), O126 (D249), O139 (D260),
O118 (D261), O80 (D262), O114 (D263), O145 (D274, D275), O144 (D278),
O127 (D285), O128 (D286), O79 (D289), O112 (D292), O147 (D293–D295),
O148 (D296, D297), O113 (D298), O149 (D300), O151 (D301), O152 (D302),
O154 (D303), O153 (D304), O155 (D306),
O156 (D307), O158 (D314), O164 (D315), O165 (D316). Raised with the
four remaining parts' drafts on 2026-11-03 and resolved the same day,
the owner accepting the recommendations as a whole: O168–O179
`vet-scheduling` (D317), O180–O190 `vet-housing` (D318), O192–O203
`vet-machinery` (D319), O204–O215 `vet-portal` (D320), each question's
text on its part's page under "Questions for the owner"; with D321
(appointment reminders) and D322, D323 (the initial load and
composition, feeding O111). O166, O167, O191 and O216 were reserved and
never used. Raised with a scenario's data register, a player handout
(D329–D331), and resolved the same day, the owner accepting the
recommendations: O217 (D333), O218 (D334), O219 (D335), each
question's text on
[versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#questions-for-the-owner).
Resolved at consolidation: O111, its v0.5 part, the domain format
written into [formats.md](formats.md) v28 (D338). Resolved at the
master spec's approval: O220, the monitoring breadth (D340).
O221 and O222 were reserved and never used. Resolved at the build plan's
approval, as it recommended: O223–O227 (D343), their text in
[versions/v0.5/build-plan.md](versions/v0.5/build-plan.md#settled-with-the-owner).
O230 was reserved and never used (chunk 9's stop, settled as D372–D380
without a question).
O233 was reserved and never used (capture W3's corrections, settled as
D401–D407). O244 and O245 were reserved and never used (capture W4's
corrections, settled as D431–D437). O248 was reserved and never used
(wave 4's gate G18 and the owner's rulings of 2026-11-10, settled as
D443–D457 with O247).

v0.6's drafting opened on 2026-11-13 (branch `v0.6-spec`): O135
resolved by the owner's rulings of that day (D480, D481), O21 narrowed
(D484), O251 placed (D486); O260–O268 raised by the network overview's
draft and closed the same day as recommended (D487, D488). On
2026-11-15 the owner's direction on fake aging closed O22 (D489–D493);
O271 and O272 raised with its draft and closed the same day by the
owner (D494, D495).

Priority: **next** = shapes everything else, ask first; **soon** = needed
for the next version (v0.1 until it closed, with none left open);
**later** = can wait for v1.0 or beyond.

## Project and scope

- **O2** (later) — Scripts versus agent judgment beyond v0.1. What the GM
  must be told and what it fills in is settled (D16); v0.1's split is
  settled (D33). Still open for generated scenarios: which further steps
  (fault choice, story, solvability probe) become scripts. Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O5** (later) — ATD was removed. Is any lighter record of intent wanted
  beyond `specs/` and the bricks' GM-facing documentation, or is that
  enough?
- **O16** (later) — Confirm the vocabulary table. Refs:
  [concept.md](concept.md).

## Platform

- **O10** (later, research) — Mostly answered in
  [platform.md](platform.md). Still unverified: numeric-only uid/gid in
  config mounts, SSH
  Docker contexts into Windows or macOS machines. To test when v0.1 is
  built.
- **O11** (later) — Which technology fills each v1.0 role beyond v0.2's
  monitoring (settled: D69) and v0.3's producers and consumers (the
  scheduler brick sending SQL to PostgreSQL, D115, D118; other targets
  from v0.5). Narrowed for v0.4 by D190 and D202: transformation is
  Python transformer scripts run by the extended scheduler brick (D203),
  over several PostgreSQL instances, `postgres_fdw` one method among
  others; another engine only if a purpose needs one, which none does
  (D194). Until v1.0 each brick takes its tool's latest release; from
  v1.0 versions are handled game-wide, older ones included (D396).
  Still open: which engine versions first, and how
  upgrade scenarios (both binaries, disk space) fit the budget, which
  the direction for v1.0 to v2 makes an exercise (D272). Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [versions/README.md](versions/README.md#from-v10-versions-at-a-game-wide-scope-d396),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O12** (later) — Are network-level faults (segmentation, routing-mesh
  exposure) in scope? And the network layout itself (management network,
  zones, dual-homed nodes). v0.2 has one network and no network faults
  (D83). Separate networks for third parties wait here: v0.5 keeps one
  network, a third party's back end closed by its own access rules
  (D275). Refs: [platform.md](platform.md),
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md).

## Faults and aging

- **O20** (later) — Confirm the reading of D28: no project-wide mandatory
  machine check (no common brick lint, no schema check in the format skill),
  only the checks each brick ships. And confirm the solvability probe as a
  gate for generated scenarios, run after aging and before hand-over. As
  built in v0.1, the scripts already check every scenario, and the bricks
  and faults it uses, against the templates when they load it
  (`tools/gm/model.py`), a project-wide check the reading did not foresee,
  while the format skill says there is no schema-check script. Refs:
  [bricks-and-faults.md](bricks-and-faults.md), [formats.md](formats.md)
  "Enforcement".
- **O21** (later, v0.6) — Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario? Due with v0.6's
  documentation website; no longer v0.5's (D233). Narrowed by D330: the
  data register may carry one from v0.5 (T300–T308); and by D484: v0.6's
  network overview may too. Still open for the other starter files (the
  README, story, issues, data policy, `partners.md`).
- **O22** (**closed**, D489–D493: fake aging joins real aging as a
  second mode from v0.6, forged history and a compressed fill, never
  fake time; the volume copy no longer planned, its use O232's;
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md); kept here
  until v0.6's archive) — Aging technique. v0.3 ages in real time
  only, with no sped-up clock, no forged history and no time compression
  (D114, D132), on always-on hosts (D125). Still open: which version
  copies aged volumes to a class's hosts (D125), and whether a later
  version brings back forged history, a sped-up clock or time
  compression (generated scenarios, restarts). With the eight-hour floor
  (D150), a classroom swarm staying up for a school day may become
  enough for short-aging scenarios, which may change how much the
  volume copy is needed; noted, not reopened (D125 stands).
  Not moot: v0.4's purposes (D190) run daily, weekly or monthly jobs,
  which real time alone barely exercises; v0.4's part is settled by
  D199 (realistic cadences, none weekly or monthly); the clinic's
  weekly, monthly and yearly reports are in the game, past periods
  planted (D265, D269, D277; [producer-profiles.md](versions/v0.5/producer-profiles.md) 4).
  Refs: [scenario-lifecycle.md](scenario-lifecycle.md),
  [archive/v0.3/aging-and-timeline.md](archive/v0.3/aging-and-timeline.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O232** (later, version not set; D397) — A snapshot and restore of
  the whole game as a feature of the game itself: the owner, 2026-11-04,
  "ability to take snapshot and restore the full game at a given point
  [...] I'd love for the game to keep track of the game time and stay
  set on it", and, for now, "Full game snapshot/restoration without
  interruption of service as seen through the game will have to wait".
  The known constraint: containers share the host's clock, so the game
  cannot hold a clock of its own; a restore at a later wall-clock time
  shows as a gap in the data unless the restored data's timestamps are
  shifted forward ("age once, restore many"). Open: when, how game time
  is kept and shown, whether timestamps are shifted at restore, and how
  it meets the aging (O22) and the restart already in v1.0 gating.
  Today's restore (the hand-over snapshot, a player-confirmed restart)
  is D397's. Refs: [versions/README.md](versions/README.md#v10-gating);
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md) 15.
- **O23** (later) — Difficulty is a fault count, each fault worth 1 (easy
  5, normal 10, hard 20; D120), read for v0.3 as the number of fault
  instances, the levels being targets (D134). Ruled for the clinic's
  scenario (D290): ten faults at most, one dramatic and noticed by the
  customer, two on the verge of becoming problematic, the rest
  optimisations and minor frictions; an issue may be a false alarm.
  Still open beyond the clinic: whether that severity mix becomes the
  general rule, how many faults issues cover, and the mix of families.
  Refs: [bricks-and-faults.md](bricks-and-faults.md),
  [versions/v0.5/README.md](versions/v0.5/README.md#in-scope).
- **O24** (later, v1.0+; D248) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
- **O25** (later, v1.0+; D248) — Scenario-only bricks and faults may live in the
  scenario's folder (D24). Can they be promoted into the catalog, and
  through which review? From v0.4 the question is mostly about purposes
  (D190): a purpose built for one scenario, its jobs, invariants and
  faults, promoted into the catalog, rather than a transformer brick.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).

## Game and feedback

- **O29** (later) — Brief format: free text in the GM session, or a
  structured file (YAML?) with the optional items of D16 (topology sketch,
  story, data schema, required incidents, freedom given to the GM,
  difficulty, length)? Refs: [formats.md](formats.md)
  (`brief.md`).
- **O30** (later) — How long may design, deployment and probes take
  before a class? Aging alone takes at least eight hours, as long as the
  scenario declares (D114, D150), so it starts that long before the class
  at the latest; playgrounds that cannot stay up that long wait for a
  later version (D125).
- **O31** (later) — Are player actions on nodes recorded (shell history,
  audit trail) to help the GM's feedback?
- **O32** (later) — Language of player-facing material (story, starter
  documentation, issues, feedback).
- **O38** (later) — Is the feedback written to a file (the teacher is out
  of the game by then)? A scoring system is post-v1.0, unless research
  finds one quick to implement (D120). Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O231** (later, version not set; D395) — The starter pack hands the
  players the customer's own credentials with each partner (D365). DBAs
  are not security advisors, but they may find a company's integration
  credentials in a handout odd and report it; the owner, 2026-11-04:
  "we may need to rectify it at some point", the game keeping some
  distance from ground truth. Until then such a report is a plausible,
  reasonable finding, not a misreading. Open: whether to rectify (the
  credentials obtained another way, or kept and named a known
  practice), and how the feedback receives the report meanwhile. Refs:
  [versions/v0.5/access-model.md](versions/v0.5/access-model.md) 3, 6,
  13; [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md) 10.2.

## v0.4: data governance

Raised when the owner added a first cut of data governance to v0.4 on
2026-10-28 (D191); its questions closed by v0.4's close are archived
([archive/v0.4/open-questions-resolved.md](archive/v0.4/open-questions-resolved.md)).
O136, raised by D230, waits for a later version.

- **O136** (later, with the open `SECURITY DEFINER` candidate fault) —
  G3 judges a definer procedure by its owner (D230). Should it also
  weigh who may execute it, so a procedure owned by an allowed reader
  but executable by `PUBLIC` or a disallowed role is a path? No v0.4
  fault turns on it. Refs:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 11.6, 22.

## v0.5: domains

Raised when the owner set business domains for v0.5 on 2026-10-28
(D192). v0.4 ships the first, the shop (O108). The veterinary clinic
added on 2026-10-30 (D196). O111, the last of them, closed at
consolidation (D338); O220, raised by it, closed at the master spec's
approval (D340). O223–O227, raised with the build plan, closed at its
approval (D343). O229, raised for capture W3, closed by it as
recommended (D404). O235 and O236, raised by the documents' as-built
passes on chunks 15a and 14, closed by the driver as recommended (D418,
D419), kept here verbatim until v0.5's archive moves them. O239 to
O242, raised by the documents' as-built passes on chunks 13 and 16
(D422, D423), closed by the driver as recommended (D424–D427), are kept
likewise, and so is O243, raised by the same pass and closed by capture
W4 (D432). O247, raised by placing the owner's security rulings of
2026-11-10, closed by the owner (D458), and O250, raised by chunk 27's
stop (D469) and closed by the owner as proposed (D471), are kept
likewise; O249 and O251 (raised at wave 5's gate) are open:

- **O235** (v0.5, wave 3; **closed**, D418, as recommended; raised by D416) — The PACS cannot read
  `biomed`'s registry (another database), so as built (chunk 15)
  `pacs.worklist.schedule` takes the procedure's machine for the
  animal's section, with no fallback to another in-service machine (13
  for 12), and `pacs.study.acquire` takes any due entry, whatever the
  machine's status; the approved text schedules and acquires on
  in-service machines only. What players could see: (a) in the loaded
  history, likely studies acquired on a machine during one of its
  recorded downtimes (the quarterly services at 08:00 local, 3 to 5
  hours, on 7–10 and 16; repairs of 2 to 30 hours on 7–9 and 11–15),
  across `pacs` and `biomed`, not yet measured; (b) live, nothing at
  default (no stream sets a machine `down`), but a story taking an
  imaging machine down keeps getting studies on it, where the GM notes
  say they wait. No fault of the ten reads it; T209's witness (bookings
  and `lab_batches` against the status) and T217's (studies past the QA
  date) stand. Recommended: the `pacs` load derives the downtime
  windows by `biomed`'s formulas and keeps the history's studies out of
  them (13 for 12, else after the window), checked in `pacs` by the same
  formula; live, accepted for v0.5, the GM notes saying that a story
  taking an imaging machine down stops its acquisitions itself; a
  PACS-side modality list later if a story needs it. Refs:
  [vet-machinery](versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373),
  [wave log](versions/v0.5/wave-log.md) (chunk 15).
- **O236** (v0.5, wave 3; **closed**, D419, as recommended; raised by D417) — T163's witness
  ("open placements outside isolation whose animal has a current
  `infectious` alert") has a baseline in the clean data as built
  (chunk 14): with two, one and two isolation units against up to four,
  three and six infectious animals at once, 47 of the year's 249
  infectious stays waited in an ordinary unit, up to three days on the
  farm, and 5 never got in; live, `housing.move` takes them in at a
  poisson 0.08/h. The witness therefore fires without the fault, and
  the policy's "an isolation unit's occupant never shares the ward's
  ordinary units" reads against those waits. T163 is not among the ten.
  Recommended: its witness becomes an infectious animal outside
  isolation while an isolation unit of its section has stood clean and
  free for more than a day, which the baseline never shows; the policy's
  rule 2 kept, "as soon as one is free" covering the waits. Refs:
  [vet-housing](versions/v0.5/vet-housing-domain.md#3-care-feeding-and-biosecurity)
  (T163), [wave log](versions/v0.5/wave-log.md) (chunk 14).
- **O239** (v0.5, wave 3; **closed**, D424, as recommended; raised by D422) — An urgent imaging request
  on a machine not around the clock (the MRIs 9 and 10, the gamma camera
  16: Monday to Friday 08:00–18:00) made after the imaging day can only
  be booked at the next one: the load does so (chunk 13), and purpose
  11's `book-requests`, calling `sched_free_slots`, will too. BS3 ("an
  urgent one starting the same day") and T113's witness ("urgent
  requests whose booking is not today") then fire without the fault, and
  `book-requests`' text ("an urgent one at the first slot today (the CT
  around the clock)") says nothing for them. T113 is not among the ten;
  chunk 21 builds BS3. Recommended: BS3 and `book-requests` read "an
  urgent one at its machine's first free slot from the request: the same
  day on a machine around the clock, the next imaging day's opening
  otherwise", T113's witness "urgent requests booked after their
  machine's first free slot". Refs:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#11-vet-bookings-sync-the-agenda-and-the-record)
  (BS3, T113), [wave log](versions/v0.5/wave-log.md) (chunk 13).
- **O240** (v0.5, wave 3; **closed**, D425, as recommended; raised by D422) — The load records the
  history's absences that start after T0 (the seven planned weeks')
  before T0, `absent` ones too, the core's draw knowing no future:
  players reading `sched_absences` find unplanned absences known weeks
  ahead, which reads as pre-booked sick leave, a health inference about
  a named staff member near rule 4 and T120. Not counted at the build
  (a few periods). No fault of the ten reads it. Recommended: kept for
  v0.5, with a false-alarm line ("sick leave booked weeks ahead": an
  `absent` period ahead is an absence the rota manager knew of, recorded
  by its kind only); the alternative, an `absent` period starting after
  T0 written as `leave`, is one expression in `load.sql` (the core's
  history never reads the future). Refs:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#deterministic-key-ranges-d249-d266)
  ("As built"), [wave log](versions/v0.5/wave-log.md) (chunk 13).
- **O241** (v0.5, wave 3; **closed**, D426, as recommended; raised by D423) — The desk's stream
  `portal.desk-consent` draws an owner from 2 to 10 000 without knowing
  the accounts (`pms` cannot read `portal`), so about one call in thirty
  names a closed account's owner and `portal_desk_consent` refuses it: a
  422, an error in `pms`' log, about one every ten weekdays at intensity
  1.0, which players can read as a fault. Recommended: kept as the
  desk's real behaviour (a receptionist trying a client who left), with
  a false-alarm line in the portal's traps ("the desk's consent call
  fails now and then": a closed account, answered by its `status`); the
  alternative, the stream skipping the loaded closed accounts by
  `portal_account`'s formula, still meets those closed in play. Refs:
  [vet-portal](versions/v0.5/vet-portal-domain.md#the-applications-and-their-nodes-d276),
  [wave log](versions/v0.5/wave-log.md) (chunk 16b).
- **O242** (v0.5, wave 3; **closed**, D427, as recommended; raised by D423) — T274's witness quotes
  "about one withdrawal every three days" and its fix "the policy"; as
  built (chunk 16) about half the `owners.keeper` ticks find a consent
  to change (222 of the 414 active horse owners hold one), so
  withdrawals come about every five or six days, and the withdrawal is
  tested in the helper `portal_keeper_granted`, the keeping's end in
  `portal_animals_scope`. T274 is not among the ten. Recommended: its
  witness "about one withdrawal every five or six days; the planted
  history", fixed on "the helper or the policy"; the traffic unchanged.
  Refs: [vet-portal](versions/v0.5/vet-portal-domain.md#3-who-sees-what-the-policies)
  (T274), [wave log](versions/v0.5/wave-log.md) (chunk 16).
- **O243** (v0.5, wave 4; **closed**, D432, option A, a `gm_check_read` policy per table with row security; raised by D423) —
  `gm_check` reads no row of a `portal` table: `pg_read_all_data` does
  not bypass row-level security, which is forced on all ten (chunk 16).
  Purpose 16's history (`portal_outbox`'s sent rows through `gm_src_*`,
  D404) and every GM check reading `portal` as `gm_check` (RL1 to RL6,
  MS1 to MS6, s5's) need a way in, while the access model keeps
  `gm_check`'s v0.4 reads on every instance in scope. A policy for
  `gm_check` (through a purpose's `ddl:`, say) is in players' sight in
  `pg_policies` and theirs to drop; other ways (the reads as another
  role, or on the GM's own plane) change the checks' mechanism. Only the
  coherence check, as `postgres`, is unaffected. Open: no
  recommendation here; W4 weighs it with chunk 21's purposes. Refs:
  [vet-portal](versions/v0.5/vet-portal-domain.md#who-sees-what-row-level-security-ruled-d320),
  [access model](versions/v0.5/access-model.md),
  [build plan](versions/v0.5/build-plan.md) chunks 21, 25.
- **O247** (v0.5, wave 5; **closed** by D458, 2026-11-10: rebuild 0.3.0; raised by D448) —
  `grafana`'s data-source plugin update (brotli GO-2026-6888, chunk 34):
  `grafana` 0.3.0 rebuilt, or 0.3.1? The advisor's triage, accepted on
  2026-11-10, names 0.3.1, and the patch-bump rule (D445) gives a
  changed image the next patch version; but the same day the owner kept
  `bastion` 0.5.0 for `curl` because 0.5.0 is unreleased (D443), and
  master spec 6.7 folds a change into an unreleased version. `grafana`
  0.3.0 is v0.5's own bump, unreleased like `bastion` 0.5.0. 0.3.1 means a
  version never released replaced before release, every `grafana` pin
  re-pinned (the existing monitoring scenarios and the fixtures with a
  `grafana` node) and the faults applying to it listing 0.3.1.
  Recommended: rebuild 0.3.0 (its tag moved, as `bastion` 0.5.0's), D445
  binding released versions; chunk 34 is written so, 0.3.1 adding the
  re-pins to its commit. Refs: [build plan](versions/v0.5/build-plan.md)
  chunk 34; [master spec](versions/v0.5/master-spec.md) 6.7.
- **O249** (later, before the clinic is first played, v1.0 gating;
  raised by D467) — The partner stubs' reference counters: the
  authority's `AMU<year>-NNNN` and the head office's `HO<YYYYMM>-NNNN`
  count the stub's own rows (`count(*) + 1`), empty at the load, so the
  first live reference restarts at 0001 after the series the purposes'
  histories plant on the customer's side (chunk 35, D451). No repeat
  (the year or month is in the reference), but a player may read the
  count not continuing as a fault. Proposed: each stub's `data.sql`
  seeds its rows (or an offset) to continue the planted series, from the
  history's own `load_epoch` derivation, a test reading the first live
  reference. Refs: `purposes/vet-antimicrobial-use/` and
  `purposes/vet-head-office-figures/` (`material/receiver/`);
  [build plan](versions/v0.5/build-plan.md) release gate item 12.
- **O250** (v0.5 release; **closed** by D471, 2026-11-12: a v0.5 known limit, as proposed; raised by D469) — The governance
  check set on the whole clinic: G1 walks the standby as a location of
  its own (a standby is no location, so its every classed column would
  read a breach), and G3's transformer path stops at the first job with
  an HTTP connection ("not a database node's database"), so
  `check-governance.sh` on `interfaces` and `backoffice` reads 2. Neither
  touches a v0.5 gate run (the load-only fixture has no standby and no
  transformer) nor a clinic check in play (none calls the set).
  Proposed: name it a v0.5 known limit (master spec 18.4, release gate
  item 6), fixed when a scenario first calls the set there (the walk
  judging a standby's databases at its primary's location, a non-SQL
  connection no database path). Refs: `tools/gm/governance.sh`;
  [build plan](versions/v0.5/build-plan.md) chunks 27, 38.
- **O251** (soon, v0.6; raised at wave 5's gate, 2026-11-12; **placed**,
  D486: v0.6's first chunk touching `tools/gm/model.py`) — The
  loader does not enforce the format rule that a bastion maps
  `partners.md: player/partners.md` exactly when the scenario's
  `third_parties:` carry a `player_doc` (formats.md "Partners"). It
  catches the omission only through `credentials:` (a listed credential
  the unmapped page cannot name), so five fixtures whose partners list
  none passed without the page until gate fix `026e023` mapped it by
  hand. No v0.5 scenario or fixture breaks the rule now, and the players'
  page is the only loss (no check reads it). Proposed: a loader refusal
  in v0.6's first chunk touching `tools/gm/model.py` ("third parties
  carry a `player_doc`, but the bastion maps no `partners.md`", and the
  converse), with a unit test; no v0.5 chunk. Refs: `tools/gm/model.py`
  (`PARTNERS_SEED_FILE`); `.claude/skills/scenario-format/SKILL.md`
  (third parties); [formats.md](formats.md) "Partners".


## v0.6: the network overview

O260–O268, raised by the network overview's first draft (D483–D485),
closed on 2026-11-13 as recommended (D487, D488); each question's text
is on
[versions/v0.6/network-overview.md](versions/v0.6/network-overview.md#questions-for-the-owner).
O135, the setup's entry point, closed by D480 (one game's front, no
front above several games) and D481 (no reporting tool). None open;
the closed entries are kept here until v0.6's archive moves them:

- **O260** (v0.6; **closed**, D487, as recommended) — Is the page's "Your access" column the game's
  rule, always exact and never a planted deviation? Recommended: yes,
  marked as such on the page, the README pointing to it.
- **O261** (v0.6; **closed**, D487, as recommended) — The bastion on the page: a node entry, or a
  fixed note? Recommended: a fixed note at the top (the players' kit,
  D65, D87), never a deviation, with its Node health link.
- **O262** (v0.6; **closed**, D487, as recommended) — Third parties on the page. Recommended: a
  closing table, one row per partner with a `player_doc`, by its
  hostname, access none; the partners' shared nodes never named (D469).
- **O263** (v0.6; **closed**, D487, as recommended) — The format additions for the fields with no
  source today (a node's `description`, `site`, `users`; a brick's
  `base`; a domain's `data/overview.yaml`; the crontab comment rule).
  Recommended: accept, into v0.6's master spec.
- **O264** (v0.6; **closed**, D487, as recommended) — A `node` variable on the Node health
  dashboard, each entry linking its own node. Recommended: yes.
- **O265** (v0.6; **closed**, D487, as recommended) — The overview and the data register planted
  independently, so one may give away a fault of the other.
  Recommended: independent; the answer key notes the interaction.
- **O266** (v0.6; **closed**, D487, as recommended) — Resolving and classing an overview fault.
  Recommended: *propose*, M by default, family `documentation`, ids
  `docs-overview-*`, as the register's.
- **O267** (v0.6; **closed**, D487, as recommended) — The home page's shape and what leaves the
  README. Recommended: two lists (sites, documents), one page per
  handout; the node table and the network paragraph leave the README.
- **O268** (v0.6; **closed**, D488, as recommended, with the owner's clarification) — The true overview read from seed files a
  system fault may have changed. Recommended: the skill states the
  design, the value before the fault's change.

## v0.6: fake aging

Raised by the fake aging draft (D489–D493) and closed by the owner on
2026-11-15; none open; the closed entries are kept here until v0.6's
archive moves them. Text on
[versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#questions-for-the-owner).

- **O271** (v0.6; **closed**, D494, against the recommendation) — Are
  the players ever told their game was fake-aged? Never: not during
  the game, not in the feedback, not after the final answer.
  Recommended had been: the feedback says so after the final answer.
  Refined by D496 (2026-11-16): never during the game; once it is
  concluded, a tell the report names may be explained.
- **O272** (v0.6; **closed**, D495, as recommended) — Which scenarios
  does v0.6 make fake-ageable? The shop and the campaign (its f10
  `real-only`); the clinic later.

## v0.5: scope, the domain procedure, post-mortems

Raised on 2026-10-31, when the owner centred v0.5 on domain definition
and the clinic (D233), asked for a procedure for defining a domain
(D235) and began a post-mortem collection (D234). O139, approving the
rest of the procedure, closed by D260.

- **O138** (later, version not set) — Binding post-mortems to the game
  (D234). Settled (D251): the binding comes in a later version; the
  handout is given after the final answer, keeping no reveals before it
  ([gm-stance.md](gm-stance.md)), and it summarises its source and links
  to it rather than copying it. Still open: which version; how a fault
  or a scenario cites an entry (a field of `fault.yaml`, the answer
  key); the handout's form; how close a replication must stay to the
  real failure when the stack differs. Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-post-mortem-collection-d234).

## Beyond v1.0: the cloud provider

Raised when the owner set a fictional cloud provider after v1.0
(D205). Settled there: a fictional name, the console's layout our own,
no AWS-style IAM.

- **O130** (later, after v1.0) — The provider layer's design: the type
  ladder and how a type maps onto limits, reservations and `fit`; the
  service kinds and what each denies (a managed database with no shell
  on its host, proposed, against the players' `dba` today); which
  capacity actions players get and what a resize does mid-game (a
  service update restarts the node); the console's relation to v0.6's
  bastion, a site on the game's home page (D480); the network map it
  makes mandatory (D482); the in-world name. Refs:
  [versions/README.md](versions/README.md#beyond-v10-a-fictional-cloud-provider-d205).

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47); O121, raised by the owner's ruling on
release gates (D193), was resolved for v0.4 by D200; O47 by D248
(scenario generation in v1.0). The tag after the priority is the version
the question concerns.

- **O48** (later, v0.3 → v1.0) — Aging enters in v0.3, in real time
  (D114). Where does the solvability probe as a gate (O20) enter the
  roadmap? With an aging of eight hours or more (D150), a probe failing at
  hand-over costs the class; v0.3's master spec has an early check during
  aging and a hand-over check. A fake-aged game (D489) reaches its
  hand-over about one real tail after setup, so there a failing probe
  costs a tail, not a day. Refs:
  [archive/v0.3/aging-and-timeline.md](archive/v0.3/aging-and-timeline.md),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O49** (soon, roadmap) — Backup tools (pgBackRest and the like) and the
  backup-tooling fault families (D17) are in no version, although backups
  were a founding example and the v0.1 goal speaks of "investigating a
  backup". Which version? WAL archiving and base backups with plain
  PostgreSQL tools are in v0.5 (D299); left here: pgBackRest and the
  like, restores, point-in-time recovery and restore drills, for
  v1.0+'s DBA work (D272). Refs:
  [bricks-and-faults.md](bricks-and-faults.md), "Future ideas: backup
  tooling".
- **O52** (later, after v0.4) — dbt adds a Python toolchain and adapters
  to a node image: image size and build time, one image per adapter
  (Postgres, DuckDB), versions to pin. One transformer brick per
  technology? v0.4 plans no dbt: its jobs run on one generic job runner
  (D190, D203). Stands for whichever later version or purpose wants dbt.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
- **O53** (later, version not set; D237) — Bluebox as a dataset. The
  owner sees it as "quite akin to a domain": a later domain candidate,
  brought in through the domain procedure, its dataset filling that
  domain's data model
  ([versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 2):
  - its schema needs PostGIS, `pg_stat_statements` (a preloaded library)
    and `pg_trgm`, so a PostgreSQL 18 brick with those extensions;
  - its dump is about 88 MB compressed and larger restored, against the
    disk budget and the time to load it at setup;
  - a file that size should not live in the repository, yet a scenario
    folder plus the repository is meant to be self-sufficient (D23);
  - its code is MIT-licensed, but part of its data comes from TMDB and
    other sources whose redistribution terms need checking;
  - its ongoing data generation relies on `pg_cron`.

  Refs: [versions/README.md](versions/README.md#deferred-from-v05-d233-d237).
- **O54** (later, version not set; D237) — Internet-sourced datasets:
  availability at setup time, licensing, and reproducibility against the
  self-sufficient scenario folder (D23). Pin by address and checksum and
  cache locally? Refs:
  [versions/README.md](versions/README.md#deferred-from-v05-d233-d237).
