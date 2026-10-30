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
drafting. Numbering continues after D205, the last; no ID is reused.

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
