> **Archived 2026-11-14.** v0.5 closed (released at its release gate, G15 cleared by the owner on 2026-11-14, merged into `main`); the open-questions register's "Resolved during v0.5" paragraph and its "v0.5: domains" section's introduction and closed entries (O235, O236, O239 to O243, O247, O250), verbatim at this pass, and the entries of the seven questions raised and closed during v0.5's consolidation and build and removed from the register then (O220, O223 to O227, O229), verbatim as each last stood (taken from git: the commit before the one that removed it, named under each). Only resolved IDs are here; every question still open, O249, O251, O269 and O270 among them, stays in the live register. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; the build plan links were repaired to its archived path, still written from `specs/`.

## Resolved during v0.5

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
[archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#settled-with-the-owner).
O230 was reserved and never used (chunk 9's stop, settled as D372–D380
without a question).
O233 was reserved and never used (capture W3's corrections, settled as
D401–D407). O244 and O245 were reserved and never used (capture W4's
corrections, settled as D431–D437). O248 was reserved and never used
(wave 4's gate G18 and the owner's rulings of 2026-11-10, settled as
D443–D457 with O247).

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
likewise; O249 and O251 (raised at wave 5's gate) are open, O251 placed
in v0.6; O269 and O270, raised by G13 and placed at v0.5's close
(D476), are open:

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
  [build plan](archive/v0.5/build-plan.md) chunks 21, 25.
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
  re-pins to its commit. Refs: [build plan](archive/v0.5/build-plan.md)
  chunk 34; [master spec](versions/v0.5/master-spec.md) 6.7.
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
  [build plan](archive/v0.5/build-plan.md) chunks 27, 38.

## Entries removed during the build

O220, as it stood at `841c9f2^` (removed by `841c9f2`, the master spec's approval):

- **O220** (v0.5, before the build plan's monitoring chunk) — The
  clinic's monitoring breadth (D238): which bricks pgwatch, pgCluu and a
  Nagios-style health check become, where pgwatch writes its metrics,
  whether the `monitoring` role (`pg_monitor`) gives them what they
  need, how the health check is shown, and where the customer's
  hand-made scripts run (D248). No draft designs them; the capacity
  tally reserves two to four nodes. Recommended: pgwatch 3 as a new
  brick with its Prometheus sink, feeding v0.2's Grafana; pgCluu on
  demand as pgBadger is; a light health node running
  `check_postgres`-style checks with a status page on the web front and
  the hand-made scripts in its crontab; one collector only if capacity
  is short; the new packages through a dependency check. Refs:
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md) 7.4, 24.

O223 to O227, as they stood at `22e46cc^` (removed by `22e46cc`, the build plan's approval):

- **O223** (soon, v0.5 build) — `grafana` 0.3.0 for the seeded pgwatch
  dashboard, with the existing scenarios re-pinned to it? Recommended:
  yes, as master spec 6.7 tables it. Refs:
  [master spec](versions/v0.5/master-spec.md) 6.7, 7.4, 17.5.
- **O224** (soon, v0.5 build) — The trim order if the build measures
  the CPU short: keep the exporters and drop pgwatch, since s10 needs
  an exporter? Recommended: yes. Refs: master spec 7.4, 14.
- **O225** (soon, v0.5 build) — pgCluu's report written to the player's
  home and read with `scp`, as pgBadger's is? Recommended: yes. Refs:
  master spec 7.4.
- **O226** (soon, v0.5 build) — The health node placed on the VPS?
  Recommended: yes, off site as the standby is, armenelos' CPU kept for
  the parts. Refs: master spec 7.4, 14.
- **O227** (soon, v0.5 build) — Machine 10's telemetry (the standing
  MRI, status only: 10 or 11 machines reporting readings) settled by
  the build's measurement? Recommended: yes, in `vet-machinery`'s
  chunk. Refs: [vet-machinery](versions/v0.5/vet-machinery-domain.md)
  (key ranges, reference sizes).

O229, as it stood at `6e4a0b3^` (removed by `6e4a0b3`, plan v10, capture W3's corrections):

- **O229** (soon, v0.5; for capture W3, before chunk 16) — Where the
  messaging stub's planted notices of the last 14 days are written.
  Master spec 9.7 and vet-portal's "Loading" have the portal's
  `derive.sql` derive them, but they live in `partners` (purpose 16's
  stub, built by chunk 21), and W2 item 3 runs `derive.sql` in
  `portal`, reading its sources through `gm_check`, with no source
  written. *Recommended:* as D366 for purpose 14, purpose 16's history
  plants them, its `target` the partners' database and `portal` its
  source, after the derivation (W2 item 3's order); `derive.sql` writes
  `portal` only; capture W4 fixes where the stub's role and tables come
  from within W2's loaders. Any write path from `derive.sql` into
  `partners` is an inserted chunk. Not the owner's: T0's state is the
  same either way. Refs:
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md) 9.7,
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 16, 21.
