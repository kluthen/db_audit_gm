# v0.1 — first milestone

Status: master spec approved (D44); build plan approved (G1), now v5.

## Goal

In the owner's words: "mostly the goal of v0.1 is to fix the GM stance, set
up a simple scenario (investigating a backup for specific defects), and
report, propose or enact fixes in the configuration" (D15). "Fix" means
settle the stance, not repair it.

Three things, then:

1. **The GM stance is settled and exercised**: the setup questions, issues
   with an expected resolution, the final-answer rule, no reveals, stopping
   as the only action on request, and positive teacher-style feedback. The
   stance is stated in [gm-stance.md](../../gm-stance.md).
2. **One simple scenario**: a single static PostgreSQL database, the
   equivalent of a snapshot or a restored backup, that the player
   investigates for specific defects in the restored database and its
   configuration (D17).
3. **The player's outcome**: for each issue, the player reports, proposes a
   fix, or enacts a fix in the configuration, depending on the issue's
   expected resolution.

v0.1 is the first step towards [v1.0](../v1.0/README.md). The scenario is
written by hand, but it follows the scenario format, brick definition and
fault definition of [formats.md](../../formats.md). Those formats are
designed for v1.0's pipeline already; v0.1 uses one node of it.

## Artifacts (D33)

1. **The GM skill**: the GM persona and run skill in `.claude/skills/`,
   invoked explicitly (e.g. `/game-master`). It holds the stance, the setup
   questions, deployment, planting, hand-over, report intake, grading,
   feedback, stop and restart ([gm-stance.md](../../gm-stance.md)).
2. **The format skill** with its scenario, brick and fault templates.
3. **The scenario-document skill** with its template.
4. **A minimal script set**: the renderer (scenario plus local
   implementation to stack file), the capacity check, the platform verbs
   (deploy, exec in a node, stop and tear down, logs), the in-node public
   validator, the sealed-check runner, and idempotent injection fed on
   stdin. Host-side scripts in Python 3 (standard library plus PyYAML),
   node-side scripts in POSIX shell.
5. **The PostgreSQL brick**: PostgreSQL 18 on Debian 13 (D37), with `sshd`,
   s6-overlay and the `sudo` wrappers.
6. **The bastion brick.**
7. **The v0.1 scenario folder.**

Initial versions of the three skills and templates, expected to evolve
(D21).

## In v0.1

- A bastion and one static PostgreSQL node on one host: the manager the GM
  targets, with local images and no registry (D4, D14, D35). Swarm setup is
  limited to a local `docker swarm init`, or guiding the user.
- Defects limited to the restored database and its configuration (D17).
  The restored-backup data is streamed as SQL, then state faults are
  planted, right after deployment (D39).
- Player access as in [planes-and-access.md](../../planes-and-access.md):
  bastion password, inner key pair, `player` account, `dba` superuser role,
  editable configuration outside PGDATA, `sudo` wrappers (D31, D34).
- The content delivery of D11, the hardening of D41, s6-overlay (D30).
- Game naming, teardown and the failure rule of D36.
- Bricks that follow the Kubernetes portability rules (D22).
- The GM stance, end to end ([gm-stance.md](../../gm-stance.md)).

## Not needed for v0.1

Deferred, not removed from the spec:

- A load producer, consumers, and any other activity on the database
  (D14, D35). Monitoring tools (D15).
- Backup-tooling defects: future fault families (D17).
- Any interaction with the GM during the game other than the report and a
  stop request; customer role-play is a future idea (D18). No hints, node
  resets or extra time (D19).
- Aging: no pre-aging run and no time compression.
- Designing a scenario from a brief or filling its blanks: the v0.1
  scenario is hand-written, and the GM only checks it fits the playground
  (D16, D32).
- The solvability probe: a manual play-through stands in (D38, D42).
- Multi-host swarms, the registry, per-host SSH contexts, remote swarm
  creation, "Beyond the hedges" in [platform.md](../../platform.md),
  computed envelopes, `no-new-privileges` through the API, hash checks on
  read-only mounts (D35).
- Network faults.

## Definition of done (D14, D15, D38)

- The scenario exists as a self-sufficient scenario folder
  ([formats.md](../../formats.md)), written with the initial templates: a
  bastion and one static PostgreSQL node, with defects in the database and
  its configuration, at least one covered by an issue and at least one
  hidden. Its scenario document opens with the "do not read" warning.
- Its issues include at least one *report* or *propose* issue and at least
  one *fix* issue; an *improve* issue is optional (D9).
- The GM asks its setup questions, generates the local implementation for
  the declared playground (or says the capacity is insufficient), deploys
  it, loads the data, plants the state faults, and hands over with the
  issues and their expected resolutions.
- The player reaches the PostgreSQL node only through the bastion, with the
  node's write policy enforced and its public validator runnable.
- A manual play-through as `player` confirms that each fault's evidence is
  reachable as the answer key states (D38).
- The stance passes a scripted check-list (D38):
  - a hint request is refused;
  - a reveal request is refused;
  - a node restart or reset request is refused;
  - a report not marked final makes the GM ask whether it is final;
  - a stop request is obeyed, and the game is torn down;
  - after a final answer, the GM gives feedback covering the issues found
    against the faults present, the acceptability of each answer, and what
    could have been done better.
- Feedback tone is judged by the owner at acceptance.
- A restarted GM session picks the game up again from the scenario folder
  and its local implementation (D42).
- A setup failure, or a stop during setup, is reported, torn down, and its
  stage recorded (D36).

## Status

Master spec consolidated and approved under the owner's delegation to the
lead (D44): [master-spec.md](master-spec.md), with
[access-model.md](access-model.md). Build plan:
[build-plan.md](build-plan.md).
