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

Archived IDs keep their meaning and are cited as they are. D107 and D113
stay live: rulings still to be applied in v0.5. D190 onward are v0.4's
drafting and build, apart from D233–D238, D248–D251, D260–D280 and
D285–D309 and D314 onward, v0.5's drafting (D310–D313 are v0.4's, on `main`). Take the next number from `doc-ids`; no ID is reused.

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
- **D190 (2026-10-28, owner direction, relayed by the lead session): v0.4
  is "bricks of why and bits of hows", not technology bricks:** a new
  catalogue artefact, the purpose (working name: its jobs, trace,
  invariants and faults); consumers modelled by their trace, no mailer,
  BI or finance software; a generic job runner and a second database,
  PostgreSQL by default, another engine only if a purpose needs one
  (the owner: "We shall see"). Revises D47 for v0.4 only; the rest of
  D47 holds. Open: O104–O110; O11, O22, O25, O52 revised. Now in:
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **D191 (2026-10-28, owner direction, relayed by the lead session): v0.4
  brings a first cut of data governance, coupled to purposes:** data
  classes with rules (location, settings, readers, flows), handed to the
  players as the company's data policy and checked by `gm_check` as
  definition checks; the first cut is classification plus allowed
  locations and flows, richer rules growing with v0.5's regulated
  domains. Extends D190. Open: O115–O120. Now in:
  [versions/v0.4/README.md](versions/v0.4/README.md) "Data governance".
- **D192 (2026-10-28, owner direction, relayed by the lead session): v0.5
  brings business domains:** a reusable catalogue unit (working name) of
  a business data model, producer profiles, common scheduler scripts and
  input types, and fitting purposes; a scenario is a domain, a size,
  bricks, purposes and faults. v0.4 ships one, the shop, structured so
  more can be added. Open: O111–O114; O108, O47 revised. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **D193 (2026-10-29, owner ruling after v0.3's release-gate aged run,
  relayed by the wave driver): An aged run, a full aging to the
  hand-over then a play-through, is a one-off check, not a standing
  item of every release gate;** none is planned before v1.0, and whether
  v1.0's gate has one is decided when that gate is planned. The owner:
  "it takes too much time." v0.3's gate ran one and it passed; D135
  holds for v0.3 only. Later gates rely on the smoke tests, the
  rehearsal and the timer-fired early check. Open: O121. Now in:
  [versions/README.md](versions/README.md#release-gates),
  [versions/v0.4/README.md](versions/v0.4/README.md#release-gate),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **D194 (2026-10-30, spec-writer, on drafting v0.4's purposes): No v0.4
  purpose needs an engine beyond PostgreSQL;** reporting, leads,
  mailing, export declarations and finance all fit PostgreSQL at
  "schemas simple, tables small", so D190's condition is not met. Closes
  O106; a later purpose needing one raises a new question. Now in:
  [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md).
- **D195 (2026-10-30, spec-writer, reading the owner's words in D190):
  No mail sink in v0.4: `mail_outbox` is the mail's whole trace,** since
  every check the owner named (duplicates, ill-appropriate sending,
  "were we truly doing this") is judged on it. Closes O110; a purpose
  needing delivery behaviour (bounces) raises a new question. Now in:
  [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md) P3.
- **D196 (2026-10-30, owner input, relayed by the wave driver): The
  veterinary clinic franchise is a v0.5 domain candidate,** the flagship
  of the regulated domains; v0.4 only borrows its strict reporting and
  its data classes as test cases, scope unchanged. Open: O126, O127;
  O112 revised. Now in: [versions/v0.5/README.md](versions/v0.5/README.md)
  "The veterinary clinic".
- **D197 (2026-10-30, owner ruling on spec-writer's recommendation,
  relayed by the coordinator): v0.4 ships four purposes on the shop:**
  P1 sales reporting, P2 win-back leads, P3 customer mailing, and P5
  export declarations, a pushed obligation; finance (P4) is held for
  v0.5. Closes O107. Now in:
  [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md).
- **D198 (2026-10-30, owner ruling, relayed by the coordinator): v0.4's
  reporting database is a PostgreSQL instance of its own,** a second
  `postgres` node of about 256 MB; governance rules name their location
  as `node/database` and may require instance separation. Closes O120.
  Now in: [versions/v0.4/governance.md](versions/v0.4/governance.md)
  "The database-versus-instance boundary".
- **D199 (2026-10-30, owner ruling, relayed by the coordinator):
  Purposes run at realistic cadences, sub-daily where a real business
  would;** players verify a daily job by moving its run time (D132); no
  weekly or monthly purpose in v0.4; the restored backup may hold past
  records computed by the data load, but no fault's evidence rests on
  them alone. Closes O109. Now in:
  [versions/v0.4/purposes.md](versions/v0.4/purposes.md) "Time".
- **D200 (2026-10-30, owner ruling, relayed by the coordinator): v0.4's
  release gate runs the checks O121 proposed (known limits named,
  rehearsal hand-over placed on the jobs, growth extrapolated) plus every
  purpose fault through its full cycle in a smoke run,** present, too
  soon after the fix, then fixed, its job moved as a player may. Closes
  O121. Now in: [versions/v0.4/checks.md](versions/v0.4/checks.md).
- **D201 (2026-10-30, owner idea, relayed by the coordinator; placed in
  v0.5 by the owner): Round trips, an acknowledgement as an inbound flow
  that the setup waits on and that drives further processes, are v0.5's;**
  v0.4's P5 only records and checks acknowledgements and opens an
  incident. Open: O128. Now in: [versions/v0.5/README.md](versions/v0.5/README.md)
  "Round trips"; [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md) P5.
- **D202 (2026-10-30, owner direction, relayed by the coordinator): A
  scenario may have several PostgreSQL instances, each a node of its
  own; data moves between them mainly by Python transformer scripts the
  scheduler runs,** and also by SQL through `postgres_fdw` or a stored
  procedure, from a producer, a transformer or a job; a scenario picks
  per flow, each method an audit surface. D198 is one case; v0.4's
  scenario keeps two (proposed). Closes O123. Open: O129. Now in:
  [versions/v0.4/purposes.md](versions/v0.4/purposes.md) "Moving data between instances".
- **D203 (2026-10-30, spec-writer, applying D202; the owner accepts the
  bump by implication): `scheduler` is extended, not forked, and ships
  0.2.0 in v0.4** with transformer scripts (a repository form, a job
  holding several connections, no password in the script) and the
  `transformer` role. Closes O105; the script's contract is proposed
  with O104. Now in: [versions/v0.4/purposes.md](versions/v0.4/purposes.md)
  "The job runner".
- **D204 (2026-10-30, owner direction, reading confirmed by the owner):
  Nodes are sized by role:** each distinct producer on a scenario node of
  its own, as small as it runs; transformer nodes larger where volume
  needs it; placement on hosts stays v0.3's (D128). An undersized
  transformer is a later fault, not v0.4's. The owner: "i meant node in
  the scenario, not swarm". In the specs a node is a scenario node; a
  swarm machine is a host. Now in:
  [versions/v0.4/purposes.md](versions/v0.4/purposes.md) "Instances and nodes".
- **D205 (2026-10-30, owner direction, relayed by the coordinator; after
  v1.0): A fictional cloud provider over the bricks:** typed nodes on a
  scaled-down cloud sizing ladder, service kinds (managed database, plain
  VM), capacity management as play, a console of our own layout (v1.0+),
  security groups and network interfaces (v2.0+); no AWS-style IAM for
  now. The owner: "fictionnal name of course". Open: O130. Now in:
  [versions/README.md](versions/README.md#beyond-v10-a-fictional-cloud-provider-d205).
- **D206 (2026-10-30, owner ruling, relayed by the coordinator): A job
  may run on a database node, as `pg_cron` or as a cron daemon beside
  PostgreSQL, both in v0.4 in `postgres` 0.4.0; systemd timers come
  later, with the virtual-machine nodes after v1.0 (D205).** The owner:
  "we could have a cron job on the same node as the postgresql, either
  as pure cron, systemd timer, or pg_cron", then chose the two lighter
  forms in a container. Closes O129. Now in:
  [versions/v0.4/database-node-jobs.md](versions/v0.4/database-node-jobs.md).
- **D207 (2026-10-30, owner ruling, relayed by the coordinator; O131
  confirmed as written): Light, well-scheduled work may run on a
  database node; heavy or row-by-row work goes to a transformer node;
  heavy work on the source instance is the worst placement.** Closes
  O131. Now in: [formats.md](formats.md) "Where a job runs";
  [versions/v0.4/database-node-jobs.md](versions/v0.4/database-node-jobs.md) "Placement".
- **D208 (2026-10-30, owner choice, relayed by the coordinator: "Add one
  crontab fault"): The first v0.4 scenario runs the cron daemon on a
  database node with one planted crontab fault,** so it is played, not
  only smoke-tested. Spec-writer picked `security-crontab-superuser` on
  `db`, a fixable node, replacing f6. Now in:
  [versions/v0.4/scenario-sketch.md](versions/v0.4/scenario-sketch.md).
- **D209 (2026-10-30, owner idea, relayed by the coordinator): An
  out-of-memory incident on a database node is a fault, happening for
  real once during the aging and recovered from by hand-over;** a
  one-off backfill drives a heavy crontab job past the node's memory.
  The players investigate and *report*, recommending the move to a
  transformer node: the fault is report only, the owner confirming "it
  means, the player can't solve the issue by himself alone, thus his
  only solution is reporting it." It replaces f10. The owner: "it
  happened "once" in the recent past". Now in:
  [versions/v0.4/database-node-jobs.md](versions/v0.4/database-node-jobs.md) "The out-of-memory incident".
- **D211 (2026-10-30, owner ruling, relayed by the coordinator; against
  spec-writer's recommendation): The agency's database is report-only by
  the story and the answer key alone;** `postgres` 0.4.0 gets no
  report-only write policy, every database node stays fixable, and the
  root-only `cron.allow` that rested on it is dropped; an overstep is
  judged in the feedback, never credited. Closes O132. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 7.2, 16.5.
- **D212 (2026-10-30, owner ruling, relayed by the coordinator): v0.4
  builds only the scenario's ten faults as catalogue faults;** the
  drafts' other candidates stay recorded for later versions. Closes
  O133. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2, 22.
- **D213 (2026-10-30, owner ruling, relayed by the coordinator): f10 is
  calibrated early in the build, on armenelos only;** if it falls short,
  it comes back to the owner before anything is reshaped, lowering
  `reporting`'s limit the likely lever, offered then. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.3, 19.
- **D214 (2026-10-30, owner ruling, relayed by the coordinator): The
  customs gateway stub loses about one acknowledgement in fifty as
  standing behaviour,** so f8's check has witnesses after the hand-over.
  Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 10.4.
- **D215 (2026-10-30, owner approval, relayed by the coordinator:
  "approved, write the build plan"): The v0.4 master spec and access
  model are approved** (23ecee0), every A and B item of its owner-review
  list still open accepted as written, and the list and its tags
  removed. Among them, B13's reading of D211: a scheduler node keeps the
  report-only policy its brick enforces (`bi`); a database node is
  report-only by the story alone. Closes O104, O108, O115, O116, O117,
  O119, O122, O124, O125 and O111's v0.4 part. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md),
  [versions/v0.4/access-model.md](versions/v0.4/access-model.md).
- **D216 (2026-10-30, owner approval, relayed by the coordinator): The
  v0.4 build plan is approved, with κ = 3 confirmed for v0.4.** Clears
  its gate G1. Now in:
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) (header,
  "Gates", "Workflow deltas").
- **D217 (2026-10-30, owner ruling on the plan's G8, relayed by the
  coordinator): Before the hand-over (the early check, the hand-over
  check, the smoke runs), a purpose check judges from the fault
  instance's planting moment, raised to the runner's last reload, the
  same rule as after it.** Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 12.1, 14;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunks 8,
  10, 11.
- **D218 (2026-10-30, owner ruling on the plan's G9, relayed by the
  coordinator): f10's "without swap" is measured in a one-off
  calibration container with its swap disabled for it alone, outside
  Swarm; armenelos keeps its swap.** Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.3;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 9.
- **D219 (2026-10-30, spec-writer, wave 1 preflight, capture W1
  corrections 1 and 2, accepted by the wave driver): The loader checks
  `jobs.yaml`'s `at`, a seeded crontab's entries and a purpose job's
  `cadence` against W1 item 0's widened cron subset (chunk 2b), and
  `schedule.yaml`'s `streams` may be `[]` (chunk 1b),** so P3's
  `*/15 8-20 * * *` (10.3) and `bi`'s and `crm`'s stream-less nodes (7.1)
  load. Now in: [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md)
  chunks 1b, 2b; [versions/v0.4/wave-log.md](versions/v0.4/wave-log.md) W1 item 0.
- **D220 (2026-10-30, spec-writer, wave 1 preflight, capture W1
  corrections 3 and 4, accepted by the wave driver): Chunk 4 merges into
  `v0.4-w1` only after chunk 2a (an in-wave edge `2 ──> 4`, merge order
  only), and records as built as W1-x, chunk 3 as W1-y,** because chunk
  4's `crontab` in `seed.files` fails the suite until 2a's
  `seed.optional` check is in (W1 item 9). Now in:
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) "Waves",
  chunks 3, 4.
- **D221 (2026-10-30, owner ruling on capture W1's question 1, relayed
  by the wave driver; refined the same day): `bastion` 0.4.0 hands the
  starter pack over both as Markdown and as a simple read-only page on
  its web front.** `data-policy.md` is a fourth, optional seed file,
  copied into `/home/player` like the others; the page shows README,
  story, issues and data policy, each only when the scenario provides
  it (no empty section, no dead link), and is built so a reporting tool
  can join it later (not in v0.4). Owner: "update bastion, it should
  allow for both the md version and a simple webpage [...] we may extend
  this with reporting tool later on"; "only if such element is
  available for the given scenario". Raises O134. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 6.4, 7.3,
  11.5, 15, 19; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md)
  chunks 1, 19.
- **D222 (2026-10-30, spec-writer, applying D221): The page is rendered
  in the bastion's image at each start by `cmark-gfm` with its table
  extension, from the starter pack as handed over,** never the players'
  home copies; raw HTML is not passed through. Every starter-pack README
  has tables, which plain `cmark` leaves as text; the GM side and its
  host gain no dependency. A new package: dependency preflight G13. Now
  in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 7.3,
  19; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 19.
- **D223 (2026-10-30, spec-writer, applying D221): `bastion` 0.4.0's
  feature is inserted as chunk 19 in wave 1,** cut after chunk 1, merged
  after chunk 2a (merge order only, as chunk 4), since wave 2 is full and
  chunk 13 in wave 3 needs it; chunk 2a's loader also requires a
  scenario with `governance:` to map the bastion's `data-policy.md` to
  `governance.policy`, and one without to map none. Now in:
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) "Waves",
  chunks 2, 19.
- **D224 (2026-10-30, owner ruling on G12, on the wave driver's
  recommendation): The web front runs in every v0.4 game, its home the
  starter-pack page; D103 no longer holds.** The bastion always
  publishes its port and the tools password is always handed over; the
  page links to the web interfaces when the scenario has any. Owner:
  "i expect a front at every game [...] Keep the setup as minimal as
  possible for now, delegate larger stuff for v0.5 and later." The rest
  of his picture (a common Caddy, a setup-wide homepage, a reporting
  tool; the provider's entry point after v1.0) is O135 and O130. Closes
  O134. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  2, 7.3, 14, 16.4, 22; [versions/v0.4/access-model.md](versions/v0.4/access-model.md) 3, 13.
- **D225 (2026-10-30, spec-writer, applying D224): Chunk 19 splits; 19b,
  the loader's port rule and the scenarios without a web interface, is
  cut after chunk 2 has merged,** since 19b edits `tools/gm/model.py`
  and `test_model.py`, chunk 2's files, while 19a, the bastion, can run
  beside chunks 2 to 4. Render needs no change (it publishes the ports
  `scenario.yaml` declares); the GM skill's hand-over lines join chunk
  18. Rejected: the port rule in wave 2's chunk 6, which would leave
  wave 1's gate with a front no scenario without routes can reach. Now
  in: [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md)
  "Waves", chunks 18, 19.
- **D226 (2026-10-30, spec-writer, applying master spec 6.3 as
  approved): A seed-file change names a database node's data file
  `data`,** the target node's `data.file`, refused on a node without
  one, since the loader admits only the brick's seed files and 6.3
  lets a purpose fault edit the data file (chunk 1's open point, wave
  log). Built by chunk 15a, its first user. Now in:
  [formats.md](formats.md) "Fault definition";
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 6.3;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 15.
- **D227 (2026-10-30, owner ruling on the plan's G10, relayed by the
  wave driver, applying D213): `reporting`'s memory limit in the v0.4
  scenario rises from 512M to 640M, its reservation staying 256M; f10's
  window stays as designed, and chunk 15's f10 run re-measures at 640M.**
  At 512M chunk 9's normal run peaked at ~300 MiB, over half the limit
  on 16.3's own measure; at 640M it is under 320, and the whole-history
  backfill (~1.55 GiB, extrapolated) stays above twice it. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.1;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) G10, chunks
  13, 15, 16, release gate.
- **D228 (2026-10-30, spec-writer, confirming chunk 11's reading of 10.4
  as approved): E4's 30 minutes are the acknowledgement's deadline; a
  missing one's incident is due by the next `escalate-customs` run (45
  minutes after sending), a rejection's one cycle after it, two minutes'
  grace each.** Read literally, 10.4's own quarter-hour job could not meet
  "an incident within 30 minutes of sending". Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 10.4, 12.4.
- **D229 (2026-10-31, owner ruling, relayed by the wave driver): A
  change confined to a brick's tests (`bricks/<brick>/tests/`) does not
  bump the brick's version; a change to any other part of its folder
  still does.** The tests are not what a scenario pins or a player
  meets. Confirms the precedents a1ceac5 (v0.2, prometheus' stack test)
  and 906c693 (v0.4 wave 1 gate, three stack tests), flagged in
  [versions/v0.4/wave-log.md](versions/v0.4/wave-log.md) "Wave 1 gate"
  and "Wave 2 report to the owner". Now in: [formats.md](formats.md)
  "Versions and pins"; the `scenario-format` skill.
- **D230 (2026-10-31, spec-writer, W3-a's question 1, reading 11.6 as
  approved): The game's own roles are skipped as readers only; a path
  acting as one (remote role, connection role, definer owner, `pg_cron`
  `username`) is judged, a superuser reaching every classed column of
  its database; the game's own schemas are left out.** 11.6's reason
  ("who may read") and its superuser clause say so; no v0.4 fix creates
  such a path. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  11.6, 11.7; [versions/v0.4/access-model.md](versions/v0.4/access-model.md) 9.3.
- **D231 (2026-10-31, spec-writer, from capture W3-a's item 4): An
  outbound flow's `fields` are the top-level keys its outbox's `payload`
  may carry, as the purpose's job writes them; G4 is unchanged.** The
  spec's `[email, name, order]`, read as keys, failed the unfaulted
  baseline (release-gate item 4); the example now carries the shop's
  keys and the flow's `outbox`, and the policy's words cover every key.
  Now in: [formats.md](formats.md) "Purposes, domain and governance";
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 6.9,
  11.3, 11.6; [versions/v0.4/access-model.md](versions/v0.4/access-model.md) 9.3.
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
- **D239 (2026-10-31, spec-writer, chunk 15a's item 1, reading 8.5 and
  16.2 as approved): f7's N is written by the scenario into its copy of
  `reporting`'s data file, the same number as the instance's `offset`,
  and `load-data` adds it to `customer_utc_offset`, wrapped as D168.**
  `render` writes no data file (8.5); the zone stays N hours off the
  customer's at any shift. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunks 15, 16.
- **D240 (2026-10-31, spec-writer, chunk 15a's item 2): f7's evidence is
  `\sf rpt.close_day`, not `\df+`.** PostgreSQL 18's `\df+` shows neither
  a procedure's source nor its `SET` clauses. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.2.
- **D241 (2026-10-31, spec-writer, chunk 15a's item 3, reading 12 as
  approved): a check on a database node judging a runner's job by a
  ledger there (f7) cannot read the runner: its judged moment is not
  raised to a reload, a fix is dated with `--since`, `remaining=` counts
  to the designed time, and a run is judged on the rows it still owns.**
  12 keeps a check on its instance's node; 18.2's f7 cycle passes
  `--since`, as f5's. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  12.1, 12.5, 18, 19; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md)
  chunk 17, release gate.
- **D242 (2026-10-31, spec-writer, chunk 15a's item 4, reading 16.2 as
  approved): f9's planting grants `bi_etl` `CREATE` on `rpt`, so its job
  recreates a dropped table.** 16.2's "dropping the table alone, which the
  job refills" needs it; the grant is the fault's, not the baseline's
  (access model 9.1), and its check does not require it revoked. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.2;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 15.
- **D243 (2026-10-31, spec-writer, chunk 15a's item 5): `dba` unschedules
  another role's `pg_cron` job by its id; by name `cron.unschedule` finds
  the caller's own jobs only.** pg_cron's behaviour, which f9's fix meets.
  Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2, 16.5; [versions/v0.4/access-model.md](versions/v0.4/access-model.md) 9.4.
- **D244 (2026-10-31, spec-writer, chunk 14's item 1, reading 16.2 as
  approved): f2's producer path is a fix only with the flags of those who
  withdrew since the release repaired too, dated with the GM's `--since`;
  the producer restored alone stops new drift and the check reads
  present. After the jobs' fix, repairing the flags stays the *improve*.**
  L2 and M2 judge consent by the latest event, so the jobs keep taking
  everyone still flagged. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.1, 16.2; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunks 14, 16.
- **D245 (2026-10-31, spec-writer, chunk 14's item 2, reading 16.2 as
  approved): f5's planting also ends `shop_etl`'s open sessions.**
  PostgreSQL checks `VALID UNTIL` at authentication only and a runner
  keeps its sessions, so without it "every run since fails" would wait
  for a reconnection; `db`'s log shows the sessions ended at the
  planting moment. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 14.
- **D246 (2026-10-31, spec-writer, chunk 14's item 3, reading 12.5 and
  D241): f5's check counts `remaining=` to the hourly job's designed
  minute read from the ledger's last start, carried forward by whole
  hours; no parameter, no code change.** A designed-time parameter would
  be as blind to a move as the ledger, and `remaining=` never changes a
  verdict; a harness that moves the job waits for the moved time. Now
  in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 12.5;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 17.
- **D247 (2026-10-31, spec-writer, chunk 14's item 4, reading 16.2): A
  five-minute job's fault needs an hour from its first run after
  planting, as quarter-hour and hourly ones do: f1's minimum is 1h.**
  Shipping ramps up after the load; f1's first duplicates came at
  T0 + 19 minutes on armenelos. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunks 14, 16.
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
- **D252 (2026-10-31, owner ruling on G10, relayed by the wave driver):
  f10's normal run at 640M is accepted as measured, 327 MiB against the
  320 MiB half; no criterion change, no re-run.** Chunk 15b's game: 238
  MiB without page cache, the thirty-day backfill killed. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.3;
  [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) G10, chunk 15, release gate.
- **D253 (2026-10-31, owner ruling on O140, "Define it now"):
  `separation: instance` is a rule of G1, every database of a node
  holding one of the class's locations, `postgres` aside, being one of
  them; refused with `locations: any`. Built by chunk 20, wave 3.**
  Option (a), recommended. Closes O140. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  6.9, 11.4, 11.6; [formats.md](formats.md); [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 20.
- **D254 (2026-10-31, spec-writer, chunk 15b's item 1, reading 16.2): A
  `state` fault may carry `seed_changes`, in the scenario's copies from
  T0, its scripts planting the rest later.** f10 is "seed-file at T0,
  state at `handover-12h`"; the fault template's comment and the
  loader's material check are widened by chunk 20. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 6.3;
  [formats.md](formats.md) "Fault definition"; [versions/v0.4/build-plan.md](versions/v0.4/build-plan.md) chunk 20.
- **D255 (2026-10-31, spec-writer, chunk 15b's item 2, reading 9.6 and
  16.3): f10's roll-up reads the orders through its own foreign table,
  `src.sales_detail_orders` (with `updated_at`, no `customer_id`), so the
  close's `src.orders` keeps only the close's columns.** 9.6 keeps each
  foreign table to its reader's needs. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 9.6, 16.3.
- **D256 (2026-10-31, spec-writer, chunk 15b's items 3 and 4, reading
  12.7, 14 and 16.3): f10's check dates the planting from the backfill
  request's `requested_at`, exits 2 when it cannot confirm the incident,
  and matches the kill line as PostgreSQL 18 writes it ("client
  backend") or as earlier releases do ("server process").** A check
  judging no runs gets no `CHECK_SINCE` (14). Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.3.
- **D257 (2026-10-31, spec-writer, chunk 15b's item 5, reading 16.3): The
  night after a killed backfill reads from the last finished run, one
  day back when the killed run was the entry's first; chunk 9's "~2
  days" holds only after an earlier normal night, and still completes.**
  Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.3 step 5.
- **D258 (2026-10-31, owner ruling relayed by the wave driver, built in
  54bc74a): `load-data`'s last step removes the `pg_cron` launcher's
  start-up failures, and only them, from the closed server-log files of
  every database node holding `pg_cron`, after the collector switches
  files; a launcher not connected within 60 s fails the step.** The
  owner: "the pg cron problem (34 error report) we need to fix this".
  Rejected: a restart after the load (the preload is needed for `CREATE
  EXTENSION`, written lines stay); `cron.database_name = 'postgres'`
  (changes the loader rule, the data file, f9 and G3); documenting the
  lines (refused). Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 7.2, 14.
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
  [versions/README.md](versions/README.md#v10-gating-v05s-additions-d314).
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
