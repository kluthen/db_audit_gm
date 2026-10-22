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

Archived IDs keep their meaning and are cited as they are. D107 onward
stay live: rulings still to be applied in a later version (D107, D108,
D110, D113), the v0.2 release close, and v0.3's drafting from D114.
Numbering continues from D124; no ID is reused.

- **D107 (2026-10-21, owner direction, relayed by the wave driver): Brick
  options are a v0.5 topic; v0.2 stays as built.** The `postgres` brick
  will offer optional elements (PostGIS, TimescaleDB, pgBadger,
  replication modules...), each documented and added to a scenario when
  appropriate; v0.5 improves and extends the bricks. Design open: O79,
  O80. Now in: [versions/v0.5/README.md](versions/v0.5/README.md).
- **D108 (2026-10-21, owner ruling after the v0.2 wave 3 gate): The
  monitoring bricks are fixable only in v0.2**, a known limit: nothing
  passes a node's write policy to its container, so the report-only
  Grafana gap cannot arise. Report-only monitoring nodes are later work
  (proposed: v0.3). Now in: master spec 7, 7.4, 10, 16;
  [versions/v0.2/access-model.md](versions/v0.2/access-model.md) 6, 7,
  11, 12; [versions/v0.3/README.md](versions/v0.3/README.md).
- **D109 (2026-10-22, owner ruling at the v0.2 release close; clears
  G11): The tooling and the feedback are judged good.** The owner, on
  fernway's feedback (release gate item 12): "the feedback is good".
  Now in: [versions/v0.2/README.md](versions/v0.2/README.md) "Release
  notes".
- **D110 (2026-10-22, owner ruling at the v0.2 release close): The GM may
  restart a game from the next version, on explicit confirmation only.**
  A restart tears down and rebuilds the whole stack. The owner: "next
  version is okay, annotate that it need an explicit confirmation (we
  can't have a passing comment just restart the game, as it's highly
  breaking change)". v0.2 keeps no restarts; its restart refusal check
  went untested at the release gate, a known gap. Mechanics open: O81.
  Now in: [versions/v0.3/README.md](versions/v0.3/README.md) "In scope",
  [gm-stance.md](gm-stance.md), [versions/v0.2/README.md](versions/v0.2/README.md)
  "Known issues".
- **D111 (2026-10-22, owner ruling at the v0.2 release close; RG-4):
  `bookshop-new-server`'s seed meets the `postgres` 0.2.0 requirement.**
  Its seed `postgresql.conf` gains the brick's logging and preload
  settings (e7c2c3e), and the GM skill says where the server log is in
  each case (412f5a2); scenario version and answer key unchanged (D75).
  Now in: master spec 11.2, [versions/v0.2/README.md](versions/v0.2/README.md)
  "Release notes".
- **D112 (2026-10-22, owner ruling at the v0.2 release close): RG-2 and
  RG-3 are accepted as known issues.** A player's `sed -i` leaves a
  config owned by `player`; `gmctl status` labels the tools password
  "handed over" in a game without a web front. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Known issues".
- **D113 (2026-10-22, owner ruling at the v0.2 release close; RG-5): The
  `monitoring` role stays in every postgres game until v0.5.** The owner:
  "monitoring isn't mandatory in any game (highly suspect if there isn't
  any of course, but it remains a valid game)", then "Keep, move to
  v0.5". Making the role conditional on the game having monitoring is a
  brick improvement, with O79. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md) "In scope",
  [versions/v0.2/README.md](versions/v0.2/README.md) "Known issues".
- **D114 (2026-10-22, owner ruling after the aging research, relayed by
  the wave driver): Aging is real time in v0.3.** The stack runs in the
  background, at least two full, meaningful days, until hand-over; no
  sped-up clock and no forged history in v0.3. The owner preferred the
  sped-up clock but accepted its caveats (query durations inflated by the
  speed-up, Go binaries not fakeable, Prometheus history to forge); he
  does not trust forging. Narrows O22, O30, O48. Now in:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md),
  [scenario-lifecycle.md](scenario-lifecycle.md) "Aging".
- **D115 (2026-10-22, owner design, relayed by the wave driver): Producers
  and consumers are scheduler nodes running a GM-written query
  repository.** A key maps to a query, a list of queries, or a builder of
  the intensity and options; schedules set intensity, pool selection,
  fixed-time queries, randomisation, traffic shapes, transactions or not.
  Now in: [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md).
- **D116 (2026-10-22, owner ruling, relayed): Players read the query
  repository and may edit it where the scenario allows; of the scheduling
  they read and change only the batch and fixed-time operations.** Now
  in: [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "What the
  players reach", [planes-and-access.md](planes-and-access.md).
- **D117 (2026-10-22, owner ruling, relayed): No events outside the
  schedule.** No random GM events; producers and consumers follow their
  schedules from the start of aging. Now in:
  [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md),
  [gm-stance.md](gm-stance.md) "During the game".
- **D118 (2026-10-22, owner ruling, relayed): v0.3 is SQL against
  PostgreSQL.** Other database types, message queues, APIs and
  transformation triggers from v0.5 on; the scheduler is designed for
  extension. Narrows O11. Now in:
  [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "Drivers",
  [versions/v0.5/README.md](versions/v0.5/README.md).
- **D119 (2026-10-22, owner ruling, relayed): A PgBouncer brick in v0.3,
  optional in any scenario.** Now in:
  [versions/v0.3/pgbouncer.md](versions/v0.3/pgbouncer.md).
- **D120 (2026-10-22, owner ruling, relayed): Difficulty is a fault
  count.** Each fault is worth 1: easy 5, normal 10, hard 20. A scoring
  system is post-v1.0; scoring research is allowed, added only if quick
  to implement. Narrows O23 and O38. Now in:
  [versions/v0.3/faults-with-activity.md](versions/v0.3/faults-with-activity.md),
  [bricks-and-faults.md](bricks-and-faults.md) "Faults".
- **D121 (2026-10-22, owner ruling, relayed): `ALTER SYSTEM` on a
  report-only database node is accepted on the trust line** (light
  enforcement, D13). Closes O45. Now in:
  [planes-and-access.md](planes-and-access.md) "The database node".
- **D122 (2026-10-22, owner ruling, relayed): Capacity is for the GM and
  the initiator to discuss; Swarm is the platform.** A game lasts at most
  four hours; the minimum capacity may rise; Kubernetes is future work;
  Tailscale links armenelos and the VPS, so multi-host is available. Bears
  on O46. Now in: [platform.md](platform.md) "Hosting",
  [versions/v0.3/load-and-capacity.md](versions/v0.3/load-and-capacity.md).
- **D123 (2026-10-22, owner ruling, relayed): A restart rebuilds the game
  from scratch.** Every node shut down, the game data destroyed, fresh
  nodes started, the game set up again; the replayed game may differ. The
  explicit confirmation of D110 stays. Narrows O81. Now in:
  [gm-stance.md](gm-stance.md) "During the game",
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md)
  "Restart".
