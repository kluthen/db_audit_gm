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
Numbering continues from D181; no ID is reused.

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
- **D124 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): Checks judge a living system by its cause first.** The
  cause where it is checkable; otherwise a trailing window from stable
  counters, the scheduler's per-key counters among them; a new
  "too soon to tell" exit code; the GM's checks never pause the load and
  keep a connection (clients as ordinary roles). Closes O82. Now in:
  [versions/v0.3/checks-under-load.md](versions/v0.3/checks-under-load.md).
- **D125 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): v0.3 games run on always-on hosts only.** Classroom
  swarms of student laptops wait for a later version that copies aged
  volumes to the class's hosts (O22). Closes O83. Now in:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md) "Playgrounds that are not up for two days",
  [platform.md](platform.md) "Hosting".
- **D126 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): A restart restores a hand-over snapshot where the disk
  allows.** Otherwise the restarted game has only the history since the
  restart, the GM naming the lost evidence before confirmation. The
  players' credentials are kept; the game id is renewed. Closes O84;
  narrows O81. Now in: [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md) "Restart".
- **D127 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): A timeline may change things at fixed moments during
  aging only.** Planting a fault, switching a key, changing a rate,
  written at design time; never during the game (D117). Closes O85. Now
  in: [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md) "Faults and changes during aging",
  [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "The schedule".
- **D128 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): Multi-host is in v0.3.** Per-node placement, a
  registry every host reaches, `fit` per host, tested on armenelos and
  the VPS over Tailscale; the default game stays single-host; the MTU and
  routing-mesh risks checked. Closes O46. Now in:
  [versions/v0.3/load-and-capacity.md](versions/v0.3/load-and-capacity.md) "Several hosts".
- **D129 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): The local implementation shifts the schedule by whole
  hours.** The game window gets the designed load; every clock stays real
  UTC; the story names the customer's time zone. Closes O86. Now in:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md) "Time of day".
- **D130 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): Players see the scheduler's log and configuration,
  except `schedule.yaml`; write policy becomes per file.** Closes O87. Now
  in: [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "What the players reach",
  [planes-and-access.md](planes-and-access.md).
- **D131 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): Nobody pauses, speeds up or triggers the load during a
  game**, not even for the final checks; moving a fixed-time job is the
  players' only lever; no "run now". Closes O88. Now in:
  [versions/v0.3/load-and-capacity.md](versions/v0.3/load-and-capacity.md) "Load control".
- **D132 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): No time compression in v0.3.** Players verify a fix to a
  job by moving its time. Closes O89; narrows O22. Now in:
  [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "Fixed-time operations".
- **D133 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): A repository list is a pool.** One query per call,
  optional weights; `steps:` for sequences, with `transaction:`;
  player-editable builders accepted on the trust line. Closes O90. Now
  in: [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "The query repository".
- **D134 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): v0.3 ships one new normal scenario and six to eight new
  catalog faults.** Ten faults, with producers, consumers, monitoring and
  PgBouncer; a score is the number of fault instances, tooling
  expectations not counted, the named levels targets. Closes O91. Now in:
  [versions/v0.3/faults-with-activity.md](versions/v0.3/faults-with-activity.md).
- **D135 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): The release gate includes one full aged run** (at least
  48 h) of the v0.3 scenario, played as `player`; smoke tests stay short.
  Closes O92. Now in: [versions/v0.3/checks-under-load.md](versions/v0.3/checks-under-load.md) "The smoke tests",
  [versions/v0.3/README.md](versions/v0.3/README.md) "Definition of done".
- **D136 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): Randomness is seeded per game.** The seed is recorded
  in the local implementation; a restart takes a new one. Closes O93. Now
  in: [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "The schedule".
- **D137 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): The scheduler's driver is pluggable, SQL on PostgreSQL
  first.** Closes O94. Now in: [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md) "Drivers".
- **D138 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): `max_connections` keeps its brick default of 100;
  scenarios set low values.** Closes O95. Now in:
  [versions/v0.3/load-and-capacity.md](versions/v0.3/load-and-capacity.md).
- **D139 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): No PgBouncer metrics brick in v0.3.** Players use the
  admin console, their role in `stats_users` only. Closes O96. Now in:
  [versions/v0.3/pgbouncer.md](versions/v0.3/pgbouncer.md).
- **D140 (2026-10-22, owner's answer "agreed" to spec-writer's recommendation, relayed by the wave driver): v0.3 takes every carried item.** Report-only
  monitoring nodes (D108), O78's option (b), RG-2, RG-3, Prometheus
  retention of at least the aging plus four hours, the format's aging
  items. Closes O97 and O78 (its `ui:`/`report:` detail: O101). Now in:
  [versions/v0.3/carried-items.md](versions/v0.3/carried-items.md).
- **D141 (2026-10-22, owner's answer "agreed with your propositions", relayed by the wave driver): Any player in the GM session confirms a restart, in so
  many words, once the GM has stated what is lost.** The game's state, the
  players' changes and, without a snapshot, the evidence named. The local
  implementation records each restart; the access model lists it as a
  confirmed operation beside `stop`. Closes O81. Now in:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md) "Restart",
  [gm-stance.md](gm-stance.md) "During the game".
- **D142 (2026-10-22, owner's answer "agreed with your propositions", relayed by the wave driver): The hand-over snapshot is taken online, per brick.** Each
  brick declares a `snapshot:` method (`pg_basebackup`, Prometheus'
  snapshot API, a plain copy for seed-only volumes); a brief stop for a
  brick that declares none; `fit` counts the copies, and a restart falls
  back to no history when they do not fit. Closes O98. Now in:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md) "Restart",
  [versions/v0.3/format-changes.md](versions/v0.3/format-changes.md).
- **D143 (2026-10-22, owner's answer "agreed with your propositions", relayed by the wave driver): Write policy per file through `write_overrides`.** The node's
  `write_policy` is the default; overrides make brick-listed writable
  paths fixable; a `fix` resolution needs its file's policy, checked by
  the loader; every brick. Closes O99. Now in:
  [versions/v0.3/format-changes.md](versions/v0.3/format-changes.md),
  [planes-and-access.md](planes-and-access.md).
- **D144 (2026-10-22, owner's answer "agreed with your propositions", relayed by the wave driver): The GM has a connection reserve of its own.** `postgres`'s
  v0.3 bump sets `reserved_connections` on the server command line, with
  a GM check role holding `pg_use_reserved_connections`. Closes O100. Now
  in: [versions/v0.3/checks-under-load.md](versions/v0.3/checks-under-load.md) "Principles".
- **D145 (2026-10-22, owner's answer "agreed with your propositions", relayed by the wave driver): A fault definition's evidence names `node`, `report:<tool>`
  or `bastion`.** `report:` only for a tool the target's brick ships; no
  `ui:<name>`, the answer key adds routes. Closes O101. Now in:
  [versions/v0.3/format-changes.md](versions/v0.3/format-changes.md),
  [versions/v0.3/carried-items.md](versions/v0.3/carried-items.md).
- **D146 (2026-10-22, owner ruling on the v0.3 review list, relayed by
  the wave driver): Every item of the review list, R1–R46, is accepted as
  proposed; v0.5 adjusts them after use.** The owner: "globally i'm okay
  with what's proposed, we shall see in v0.5 if adjustment need to be
  made". Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md),
  [versions/v0.3/review-list.md](versions/v0.3/review-list.md),
  [versions/v0.5/README.md](versions/v0.5/README.md).
- **D147 (2026-10-22, owner's answer to the independent review, relayed
  by the wave driver): Prometheus is snapshotted by a brief stop.** Its
  admin API stays off and the bastion image unchanged; the scrape gap at
  hand-over is told as maintenance. Replaces D142's Prometheus method.
  Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md)
  7.4, 6.4; [formats.md](formats.md) "Brick definition".
- **D148 (2026-10-22, owner's answer to the review, relayed): A fixable
  builder can leak the schedule; accepted on the trust line**, like
  editable builders (D133), with no isolation; a known gap. Now in:
  [versions/v0.3/access-model.md](versions/v0.3/access-model.md) 8, 11;
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 7.1, 20.
- **D149 (2026-10-22, owner's answer to the review, relayed): Multi-host
  copies images, no registry.** `docker save | ssh <host> docker load`
  over Tailscale, deployed with `--resolve-image never`; nothing listens.
  Amends D128's registry; narrows O10. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 10.2;
  [platform.md](platform.md) "Image distribution".
- **D150 (2026-10-22, owner ruling, relayed): The aging minimum is eight
  hours, a floor; each scenario declares the aging it needs** and the GM
  judges per game whether the time available is enough, declining or
  replacing a scenario otherwise. Amends D114's two days; D135's run is at
  the scenario's declared aging. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 8.2, 11;
  [gm-stance.md](gm-stance.md).
- **D151 (2026-10-22, spec-writer, process): The independent review's
  REJECT is applied to the consolidation.** Its seven blocking issues and
  its findings are fixed in the master spec, the access model and
  formats.md; where a fix needed a choice the owner had not made, it is
  tagged `(proposed)` and listed for his approval in
  [versions/v0.3/review-list.md](versions/v0.3/review-list.md) "Second
  round", awaiting him with the master spec.
- **D152 (2026-10-22, owner's answer on R47, option (a), relayed by the
  wave driver): Lost time up to thirty minutes does not move the earliest
  hand-over; only the lost time beyond it does, and the GM judges those
  outages at hand-over.** An outage is a minute with a node down or a
  scheduler writing no per-minute summary, which it writes every minute,
  even with no call (the re-review's first correction). The earliest
  hand-over moves later by the excess beyond thirty minutes. Amends the
  running-time rule of D151. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 4, 7.1, 8.7;
  [versions/v0.3/access-model.md](versions/v0.3/access-model.md) 6;
  [concept.md](concept.md) "Vocabulary".
- **D153 (2026-10-22, owner's answer, relayed by the wave driver): The
  review list's second round, R48–R62, is accepted as proposed**; their
  `(proposed)` tags are dropped. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md),
  [versions/v0.3/access-model.md](versions/v0.3/access-model.md),
  [versions/v0.3/review-list.md](versions/v0.3/review-list.md).
- **D154 (2026-10-22, owner approval, relayed by the wave driver): The
  v0.3 master spec and access model are approved** (d3a3dc5), with the
  re-review's nine corrections folded in (D155), D152 and D153. The known
  gaps stay gaps. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md),
  [versions/v0.3/access-model.md](versions/v0.3/access-model.md).
- **D155 (2026-10-22, spec-writer, process): The re-review's nine
  corrections are applied**: outages read from the per-minute summaries
  (D152); one instance re-planted by `inject --at now --instance <id>`; a
  restart's game at `handed-over`, the snapshot kept until teardown, new
  Swarm secret objects with the same values; 6.7's nodes as a list; a
  wrong-time-zone offset wrapping modulo 24; the rehearsal's `--handover`
  placing the peak inside it; `EXECUTE` on `pg_hba_file_rules()`; the
  index's D114 line. Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md)
  6.7, 7.1, 7.3, 8.3, 8.7, 11–13, 20; [versions/v0.3/access-model.md](versions/v0.3/access-model.md) 3.
- **D156 (2026-10-22, owner approval, relayed by the wave driver; clears
  G1): The v0.3 build plan is approved** (v1, ff92e85), its nine
  recommendations accepted as given (G4, G5, G6, G8, G9, κ = 3, the
  rehearsal re-run on the merged code, the plan's reading of R47 (a)).
  The owner: "agreed [...] otherwise everything is approved". Wave 1
  opens on 2026-10-23. Now in: [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md).
- **D157 (2026-10-22, owner ruling, relayed by the wave driver): Only a
  scenario with scheduler nodes ages.** A scenario with no producer or
  consumer (a static database investigated as a restored backup) has no
  aging; the eight-hour floor and `aging:` apply only with scheduler
  nodes. The owner: "aging is mostly required when there are producers".
  Amends D150. Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 8, 15.4.
- **D158 (2026-10-22, spec-writer, format; follows D157): A scenario with
  no scheduler node omits `aging:`, which the loader refuses there,** with
  `{{customer_timezone}}`, a `plant_at` other than T0 and an instance's
  `aging_minimum`; `render --handover` is optional and the game skips
  `load-started`. The topology already says it; `none` or 0 would be a
  second way to say it. Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 6.1, 8, 13.
- **D159 (2026-10-22, owner direction, relayed by the wave driver): The
  driver may work on the VPS but never disturbs its existing apps:**
  filetstudio.com stays up, and a change that needs it down (a Docker
  upgrade) waits for a downtime scheduled with the owner beforehand; the
  VPS's Caddy may change if filetstudio.com stays up; the VPS's own
  documentation is read before any change. Now in: [platform.md](platform.md) "Hosting".
- **D160 (2026-10-23, owner confirmation at wave 1's start, relayed by
  the wave driver): In a scenario with no scheduler node, the fault
  definitions' own aging minima are not counted,** as in v0.2:
  `bookshop-new-server`'s `pg-join-index-missing` does not hold up its
  hand-over. Confirms the reading of D157 the spec states. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 8, 15.4;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunk 2.
- **D161 (2026-10-23, owner confirmation at wave 1's start, relayed by
  the wave driver; settles D156's override): The test-harness override
  of the aging minimum (G6) also caps each fault instance's own aging
  minimum,** so the two-hour rehearsal reaches its hand-over. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 11;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) G6, chunks
  8a, 11, 15b.
- **D162 (2026-10-23, owner confirmation at wave 1's start, relayed by
  the wave driver): A game with no scheduler node keeps the hand-over
  check and the hand-over snapshot,** so Prometheus and Grafana stop
  briefly at `fernway-clinics-monitoring`'s hand-over. Declined: skipping
  both in such games. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 8, 15.4;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 11, 13.
- **D163 (2026-10-23, spec-writer, wave 1 preflight, capture W1 "Needs" 1):
  A scheduler's `schedule.yaml` is read in place from the game's seed
  config, never copied onto a volume,** so a restart's new game brings
  its new seed (12) instead of the snapshot's old one. Players never see
  it; the file never changes in a game. Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 7.1;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 3b, 7a, 11b.
- **D164 (2026-10-23, spec-writer, wave 1 preflight, W1 "Needs" 2): Every
  `postgres` seed `pg_hba.conf` carries `local replication postgres peer`
  under its DO NOT TAMPER comment,** the GM's access that 7.3's snapshot
  requires (and D162 keeps for static games); chunk 1b adds it to both
  scenarios and two fixtures. Chunk 2a's `gm_check` check accepts `trust`
  too. Now in: [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 1, 2a, 4.
- **D165 (2026-10-23, spec-writer, wave 1 preflight, W1 "Needs" 3): Chunk 9
  passes a behavioural check's window and threshold to its script** as
  `CHECK_WINDOW_SECONDS` and `CHECK_THRESHOLD` (W1 item 4); no chunk did.
  Now in: [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunk 9.
- **D166 (2026-10-23, spec-writer, wave 1 preflight, W1 "Needs" 4): Wave 1
  runs chunk 1 first, chunk 3 beside it, and cuts chunks 2, 4 and 5 after
  chunk 1's merge** (4 and 5 after 1a's at least), so no two running
  chunks share a file and no shared list is needed; chunk 1's Files name
  the five existing bricks, never `bricks/scheduler/`. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) "Waves", chunks 1 to 5.
- **D167 (2026-10-23, spec-writer, wave 1 preflight, W1 items 2, 3 and 7):
  Chunk 1 writes W1's brick keys and values for the five bricks**
  (6.4's roles, `writable_paths`, `seed.paths`, `report_tools`,
  `snapshot:`, a provisional growth), which chunks 4 and 5 keep; that
  `postgres` ships `gm-snapshot-db` is chunk 4's stack test's, not the
  loader's; the scheduler declares no connection secret, render deriving
  one per role; fault evidence read through a web interface or on
  another node leaves `fault.yaml`, the answer keys keeping it. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 1, 2, 3b, 4b, 5.
- **D168 (2026-10-23, spec-writer, wave 1 preflight, W1 item 7): A
  scenario's job never carries `timezone:`; the wrong-time-zone fault's
  seed change writes `timezone_offset: <N>`,** the customer's zone being
  unknown at authoring (8.3); render turns it into `Etc/GMT∓M`. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 2b, 7a, 14.
- **D169 (2026-10-23, spec-writer, wave 1 preflight, W1 item 8): `postgres`'
  root-only `check-psql` helper is chunk 4a's,** in its Files line, and
  chunk 9's checks connect through it. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 4, 9.
- **D170 (2026-10-23, spec-writer, wave 1 preflight, W1 item 5): The
  scheduler's configuration `writable_paths` are two directories,
  `/srv/scheduler/repository` (`queries.yaml`, `builders/`) and
  `/srv/scheduler/jobs` (`jobs.yaml`),** so an override makes its
  directory fixable and `sed -i` works there, as on every other brick;
  W1's file paths inside a read-only directory would have broken `sed -i`
  on the v0.3 scenario's report-only scheduler nodes. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 6.7;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunk 3b.
- **D171 (2026-10-23, owner ruling, relayed by the coordinator; resolves
  O102): Every `postgres` seed names the GM check role's access under its
  DO NOT TAMPER comment, `local all gm_check scram-sha-256`,** beside the
  replication line (D164), added by chunk 1b, so a player tightening the
  general `local all all` line does not lock the sealed checks out. Now
  in: [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 1, 4.
- **D172 (2026-10-26, spec-writer, wave 2 preflight, capture W2 open point
  1): `status --set handed-over`'s snapshot condition arrives with
  `snapshot`, in chunk 11a;** chunk 8b enforces the earliest hand-over and
  the hand-over check, and `smoke.sh` gains the hand-over check (chunk 8)
  then the snapshot (11a) before it hands over, so each condition comes
  with what satisfies it and every wave gate still tests the hand-over.
  Rejected: wave 2's `smoke.sh` without the hand-over; a provisional
  snapshot record. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 8, 11.
- **D173 (2026-10-26, spec-writer, wave 2 preflight, capture W2 open point
  2): The host timers are persistent systemd user units,** enabled and
  removed by teardown, so a setup action due while the host was down runs
  when it is back, as 8.7's resume after a host restart needs; a late run
  waits for the game's nodes first; a run reaching another host's node is
  chunk 10b's. Rejected: transient `systemd-run --user` units, lost at a
  reboot. Now in: [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md)
  "Read first" (build host), chunks 8, 10.
- **D174 (2026-10-26, spec-writer, wave 2 preflight, capture W2 open point
  3): Outages read from Swarm's pruned task history are a lower bound,
  flagged,** `status` reading "at least" for a node whose kept tasks may
  have lost some since the previous reading; the schedulers' summaries
  stay exact, and a node restarting that often reads unhealthy at the
  next check. Rejected: raising the swarm-wide `--task-history-limit`
  (the hosts' other stacks, the VPS); a per-minute sampling timer. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunk 8.
- **D175 (2026-10-26, owner ruling, relayed by the coordinator; resolves
  O103, clears G11): The lost time beyond thirty minutes moves the whole
  earliest hand-over,** the later of the aging minimum since T0 and every
  fault instance's own minimum since its planting, as master spec 8.7 and
  D152 say. Now in:
  [versions/v0.3/access-model.md](versions/v0.3/access-model.md) 6
  (`aging-done`); [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md)
  G11, chunk 8.
- **D176 (2026-10-26, owner ruling at wave 2's gate, relayed by the
  coordinator): `gmctl load-data` grants the GM check role `CONNECT` on
  every non-template database after the data load,** since both catalog
  scenarios' data revoke it from `PUBLIC` and chunk 9's checks connecting
  to `$FAULT_DATABASE` read `error`. Declined: the scenarios' data
  granting it; those checks staying on `postgres`. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 7.3;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 11, 14.
- **D177 (2026-10-26, owner ruling on security-advisor's post-change
  check of wave 2): The `pgbouncer` brick takes PgBouncer from the
  PostgreSQL apt repository (`trixie-pgdg`), pinned at
  `1.26.1-1.pgdg13+1`,** since Debian 13's 1.24.1-1+deb13u2 has six open
  CVEs with no trixie fix (CVE-2026-6668, -19888, -6669, -107348, -107349,
  -107350; Debian bug 1148946). Declined: Debian's 1.24.1 with an accepted
  risk. 1.25/1.26's behaviour changes touch no brick, fault or scenario;
  tracking `search_path` by default matters only to a future
  transaction-pooling fault relying on leaked session settings. Now in:
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 7.2;
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) G2, chunk 6.
- **D178 (2026-10-26, owner ruling at wave 3's start, relayed by the wave
  driver; clears G4's stop): The VPS's engine may leave its own empty
  single-node swarm and join armenelos' as a worker.** Lesson of the
  join: a swarm membership change on the VPS wiped its containers'
  embedded DNS (filetstudio.com 502 for about six minutes), so it is a
  downtime, like a Docker upgrade. Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) G4,
  "Workflow deltas" (the VPS).
- **D179 (2026-10-26, spec-writer, wave 3 preflight, capture W3 item 4
  and its closing point 3): Teardown per host is chunk 10b's,** the
  game's Swarm objects on the manager, its containers and volumes on
  every declared host; chunk 10 gains `teardown.py`, `test_teardown.py`
  and the fake engine's files, which pass to chunk 11 at 10's merge (the
  in-wave edge 10 ──> 11, still two chunks). Now in:
  [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunk 10, the waves' edges.
- **D180 (2026-10-26, spec-writer, wave 3 preflight, W3 item 2): A node
  that publishes ports is placed on the manager only, `gmctl fit`
  refusing a mapping that puts one elsewhere,** since a host-mode port
  opens on every address of its host and the VPS has a public one; G4's
  "no game port published on the VPS" made a rule of the product, not of
  this build's hosts. The plan alone was not enough: it is a refusal the
  GM meets. Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md)
  7.5, 10.2; [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunk 10a.
- **D181 (2026-10-26, spec-writer, wave 3 preflight, W3 item 6): The image
  copy is `docker save | docker --context dbagm-<host> load`, through the
  host's SSH Docker context,** the same SSH as `ssh <host> docker load`
  with no second destination to declare; master spec 20 left the form to
  the build. Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md)
  10.2, 20; [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md)
  chunk 10b, "Left for the build"; [platform.md](platform.md) "Image distribution".
- **D182 (2026-10-27, owner ruling on chunk 10's first two-host try,
  relayed by the wave driver; capture W3-a): A game spanning several
  hosts gets its overlay's /24 from a range reserved for `gmctl`,
  `10.20.0.0/16`,** the first free on the swarm and every placed host,
  picked by `deploy` at the first deployment and kept on a restart,
  since Swarm's default pool gave the overlay subnets the VPS's local
  networks hold. Rejected: the VPS daemon's address pools (a
  filetstudio.com downtime); Swarm's pool at `swarm init` (a membership
  change). Now in: [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md)
  10.2; [versions/v0.3/build-plan.md](versions/v0.3/build-plan.md) chunks 10b, 11, 15.
