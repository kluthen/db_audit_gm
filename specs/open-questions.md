# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Resolved IDs are listed at the bottom.

Priority: **next** = shapes everything else, ask first; **soon** = needed
for v0.1; **later** = can wait for v1.0 or beyond. None is open for v0.1.

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
  config mounts, the cross-host `127.0.0.1:5000` registry pattern, SSH
  Docker contexts into Windows or macOS machines. To test when v0.1 is
  built.
- **O11** (later) — Which technology fills each v1.0 role (producer, the two
  databases, transformation, consumer, monitoring), which engine versions
  first, and how upgrade scenarios (both binaries, disk space) fit the
  budget. Refs: [versions/v1.0/README.md](versions/v1.0/README.md).
- **O12** (later) — Are network-level faults (segmentation, routing-mesh
  exposure) in scope? And the network layout itself (management network,
  zones, dual-homed nodes). Refs: [platform.md](platform.md).

## Player access and rules

- **O13** (later) — How does the player reach monitoring web UIs (Grafana,
  pgwatch) while only ever going through the bastion: SSH tunnel / SOCKS, a
  browser on the bastion, or ports exposed on the local network (which the
  routing mesh opens on every host)? Refs:
  [planes-and-access.md](planes-and-access.md).

## Faults and aging

- **O20** (later) — Confirm the reading of D28: no project-wide mandatory
  machine check (no common brick lint, no schema check in the format skill),
  only the checks each brick ships. And confirm the solvability probe as a
  gate for generated scenarios, run after aging and before hand-over. Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O21** (later) — Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario?
- **O22** (later) — Default aging technique per fault (pre-aging, forged
  history, time compression). Time compression is visible to the auditor
  (`*/5` on a "daily" job), collides with schedule faults, and must stay
  consistent with forged timestamps. Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O23** (later) — How many faults per scenario, how many covered by
  issues, what "difficulty" means concretely, and may an issue be a false
  alarm (a complaint with no fault behind it)? Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O24** (later) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
- **O25** (later) — Scenario-only bricks and faults may live in the
  scenario's folder (D24). Can they be promoted into the catalog, and
  through which review?

## Game and feedback

- **O29** (later) — Brief format: free text in the GM session, or a
  structured file (YAML?) with the optional items of D16 (topology sketch,
  story, data schema, required incidents, freedom given to the GM,
  difficulty, length)? Refs: [formats.md](formats.md)
  (`brief.md`).
- **O30** (later) — How long may design, deployment, aging and probes take
  before a class? Can pre-aging run the day before?
- **O31** (later) — Are player actions on nodes recorded (shell history,
  audit trail) to help the GM's feedback?
- **O32** (later) — Language of player-facing material (story, starter
  documentation, issues, feedback).
- **O38** (later) — Does the GM's feedback include a score? Is it written
  to a file (the teacher is out of the game by then)? Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).

## Resolved

| ID | Resolved by |
|---|---|
| O1 | D4 |
| O4 | D6 |
| O6 | D7 |
| O7 | D8 |
| O17, O18 | D10 |
| O26, O27 | D9 |
| O8 | D11 |
| O36 | D13 |
| O33 | D14, D15 |
| O41 | D17 |
| O42 | D18 |
| O28 | D19 |
| O39 | D20 |
| O40 | D22 |
| O43 | D23 |
| O44 | D24 |
| O15 | D25 |
| O34 | D26 |
| O35 | D27 |
| O37 | D28 |
| O3 | D29 |
| O9 | D30 |
| O14 | D31 |
| O19 | D32 |
