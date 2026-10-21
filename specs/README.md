# Spec tree — index and status

The living specification of db_audit_gm, and the only expression of its
intent (D1). To resume cold: read this page, then
[open-questions.md](open-questions.md); look up decisions in
[decisions.md](decisions.md) by ID only.

Phase: **v0.1 released** on 2026-10-21, pending the merge of
`v0.1-release` into `main` (master spec approved under the owner's
delegation to the lead, D44); v0.2 to v1.0 in drafting. Conventions:
settled items are stated as fact, tentative ones are tagged `(proposed)`,
and every open point cites an `O` ID. Every `(proposed)` item awaits the
owner's confirmation; the register lists the ones with real alternatives.

## Documents

| Document | Purpose | Status |
|---|---|---|
| [concept.md](concept.md) | Purpose, actors, vocabulary, scope, versions, prior art | draft v5 |
| [versions/](versions/README.md) | The roadmap: v0.1 to v1.0 and beyond, one page per version; v0.1's [master spec](versions/v0.1/master-spec.md), [access model](versions/v0.1/access-model.md) and [build plan](versions/v0.1/build-plan.md) | v0.1 released, pending merge; v0.2–v1.0 draft |
| [gm-stance.md](gm-stance.md) | How the GM behaves and speaks: setup questions, issues, report-only interaction, no reveals, stop only, final answer, feedback tone, future ideas | draft v4 |
| [scenario-lifecycle.md](scenario-lifecycle.md) | The game from setup to teardown: setup inputs, scenario, local implementation, deploy, aging, hand-over, end of the game | draft v6 |
| [formats.md](formats.md) | What a scenario folder, a brick (with its companion material) and a fault definition must contain; the local implementation; the skills and templates | draft v8 |
| [bricks-and-faults.md](bricks-and-faults.md) | Catalog, per-brick checks, solvability probe, fault interactions and families, future backup-tooling faults | draft v4 |
| [planes-and-access.md](planes-and-access.md) | Bastion-only rule, planes, the GM session, trust, write policies, hardening, validators | draft v6 |
| [platform.md](platform.md) | Hosting, resources and nerfing, scenario content delivery, portability, Swarm facts and pitfalls | draft v9 |
| [open-questions.md](open-questions.md) | Open-questions register | live |
| [decisions.md](decisions.md) | Decisions log, D1–D54 | live |

History: the tree was seeded on 2026-10-20 from the owner's pre-spec notes,
which are no longer a reference (D1).

## Status snapshot — what is settled

- Purpose: live audit-and-fix practice on a complex data stack; an
  exercise, not a CTF; players are expected to follow the rules.
- The GM is an agent in a Claude Code or opencode session. The teacher only
  gives inputs at the start; anyone may ask the GM to stop the game; a
  student may play alone with the GM designing the exercise (D6).
- GM stance: no reveals before the final answer; no action on request but
  stopping; issues carry an expected resolution (report, fix, improve); an
  explicit final answer; positive teacher-style feedback (D9, D13;
  [gm-stance.md](gm-stance.md)).
- One game, one report; who sits behind it is not the project's concern
  (D8).
- v0.1 settles the GM stance on one simple scenario: a static PostgreSQL
  database investigated for defects in itself and its configuration; no
  load producer, no monitoring; the report is the players' only interaction
  with the GM; no hints, resets or extra time (D4, D14, D15, D17–D19).
  v1.0: producer -> database -> transformation -> database -> consumer,
  with monitoring and the bastion (D4).
- Swarm is the starting platform; Kubernetes portability is a requirement;
  multi-host swarms use Linux hosts only. The GM uses an existing swarm or
  sets one up (or guides the user), and reaches hosts over SSH (D12, D22,
  D26, D27).
- The only required setup input is the playground: the swarm, its hosts and
  the capacity available (CPU, RAM, disk). Topology, story, data schema and
  the like are optional and may be sketched or left out; the GM fills the
  blanks and sizes the setup to fit (D7, D16).
- Scenario content: generic brick images, scenario files as Swarm configs
  seeded once into pinned volumes, state faults planted by the GM (D11).
- Scenario format, brick and fault definitions are specified in
  [formats.md](formats.md) and will be enforced by one skill plus templates
  (D5). A scenario is a self-sufficient folder, the source of truth: with
  the full repository and the GM's skills it is enough to start the
  exercise, and it records the host
  topology it was designed for. Its readable scenario document follows the
  GM's own template and carries a prominent "do not read" warning, nothing
  heavier (D13, D20, D23). To deploy, the GM generates a local
  implementation fitting the scenario to the real playground, or says the
  capacity is insufficient (D23). Initial versions of the skills and
  templates are in v0.1 and expected to evolve (D21).
- Players reach everything through the bastion only; read access to every
  node, write access on some; limited `sudo` wrappers, so no
  `no-new-privileges` where they are needed (D25).
- Shared bricks and faults live in the catalog, referenced by id and pinned
  version; scenario-only ones may live in the scenario folder (D24).
  Machine checks are per brick, shipped as companion material (D28).
- Validators may be red from the start; they are not monitoring tools; an
  unfixable red validator is a defect to report (D10).
- Every scenario fits the playground's CPU, memory and disk; databases are
  nerfed;
  schemas simple, tables small; sessions up to 4 hours.
- Roadmap (D47): v0.2 monitoring, v0.3 producers and consumers, v0.4
  transformers, v0.5 research and broadening, then v1.0; beyond v1.0,
  other databases and tools, customer role-play and hints (D48). Gaps and
  risks: O46–O54.
- Small project: scripts and small apps, no ATD, no UI/UX tree (D2).
- v0.1 build: seven artifacts (three skills, a Python/POSIX-shell script
  set, PostgreSQL 18 on Debian 13 and bastion bricks, one scenario), one
  host, four expected resolutions (report, propose, fix, improve), players
  as `player` with a `dba` superuser role, testable stance check-list
  (D9, D33–D41); full detail in the
  [v0.1 master spec](versions/v0.1/master-spec.md).

## Next steps

1. Merge `v0.1-release` into `main` (the owner's word, after the RG-1
   fix passed the quality command).
2. After v0.1 closes: archive its working record (skill
   `milestone-archive`), then resume v1.0 scoping from the "later"
   questions.
