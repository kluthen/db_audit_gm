# v0.1 — first milestone

Status: released 2026-10-21 and merged into `main` (3c852e1); archived
2026-10-21. Master spec approved (D44); built from build plan v6 in three
waves; release gate passed, G5 cleared and RG-1 fixed (see "Release
notes"). The build plan, decisions D1–D54 and the resolved questions are
in [archive/v0.1/](../../archive/v0.1/README.md). This page, the master
spec, its access model and the wave log stay here: they are what the
skills, bricks and `gmctl` cite as the contract for what v0.1 built.

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
[access-model.md](access-model.md). Build plan (archived):
[build-plan.md](../../archive/v0.1/build-plan.md). Built in three waves,
merged into `main` at 763694c; the release gate's run is in
[wave-log.md](wave-log.md), "Release gate — 2026-10-21", and the owner's
release-close rulings after it. The release gate's commits, the RG-1 fix
included, were merged from `v0.1-release` into `main` at 3c852e1.

## Release notes

v0.1, released on 2026-10-21: release gate passed, G5 cleared by the
owner, RG-1 fixed; merged into `main` at 3c852e1.

### What v0.1 delivers

- **`gmctl`** (`tools/gmctl`, Python 3 with PyYAML): the GM's one
  host-side command. `fit` (capacity check against a declared
  playground), `render` (the stack file), `deploy` (credentials, labelled
  configs and secrets, the stack, health), `exec`, `load-data`, `inject`,
  `validate`, `check` (the sealed checks), `logs`, `status` (with `--set`
  for the stages only the GM reaches, spec D49), `teardown` (with
  `--reason` for a stop, spec D50). After a failed setup and its
  teardown, `fit` starts a new game on the same playground (spec D51).
- **Two bricks**: `bricks/postgres` (PostgreSQL 18 on Debian 13, `sshd`,
  s6-overlay, the `sudo` wrappers `gm-reload-db`, `gm-restart-db` and
  `gm-validate`) and `bricks/bastion`.
- **Six catalog faults** in `faults/`: `pg-hba-trust-remote`,
  `pg-role-superuser`, `pg-memory-over-envelope`, `pg-join-index-missing`,
  `pg-table-autovacuum-off`, `pg-abandoned-replication-slot`.
- **The scenario `bookshop-new-server`**: a bastion and one static
  PostgreSQL node holding a restored backup, with known and hidden
  defects in the database and its configuration, and issues to report,
  propose or fix. Reviewed under G4. Its `README.md` is the scenario
  document, GM-only.
- **Three skills** in `.claude/skills/`: `game-master` (invoked
  explicitly, e.g. `/game-master`), `scenario-format` with its scenario,
  brick and fault templates, and `scenario-document` with its template.

### Per-game credentials

The per-game credentials are kept in the git-ignored
`local/<playground>/secrets/` of the scenario folder, mode 0600 (the
directory 0700), so that a restarted GM can hand them over again. Spec
D45 narrows spec D31's "nothing written to the repository": nothing is
committed.

### Release gate results

Run on branch `v0.1-release` (from `main` at 763694c) on the build host:
Debian 13, Docker Engine 29.9.1, single-node swarm. All six run items
passed.

- Full game `bookshop-new-server-pwbho8` on playground `laptop`
  (declared CPU 2, memory 4G, disk 8G): setup through hand-over, every
  step exit 0, 5 injection scripts.
- Play-through as `player` through the bastion only: evidence of all six
  fault instances reachable as the answer key states; each *fix* issue
  fixed two ways, sealed check 1 → 0 → 1 → 0.
- Stance check-list passed item by item; a stop after hand-over obeyed at
  once, with its reason recorded.
- A fresh GM session resumed the game at `handed-over`.
- Forced setup failure (at `load-data`): reported, torn down, stage
  recorded, nothing labelled left; then a new game on the same
  playground, stopped during setup with its reason recorded.
- Quality command: 165 unit tests OK (13.7 s), `sh -n` OK on 32 shell
  scripts, both images built unchanged (postgres `sha256:a55e764b…`,
  bastion `sha256:314de9c7…`), `smoke.sh` green, 0 objects labelled
  `dbagm.game` left.

Re-run after the RG-1 fix, on `v0.1-release` at 1969011:

- Quality command: 165 unit tests OK (14.8 s), `sh -n` OK on 32 shell
  scripts, postgres image rebuilt as `sha256:a4c91c7f…`, bastion
  `sha256:314de9c7…` unchanged, `smoke.sh` all checks passed, with 8
  volumes per game.
- `bookshop-new-server` on the new image (playground `rgcheck`): `fit`,
  `render`, `deploy`, `load-data` and `inject` exit 0; `validate` 1 (db
  red on `work_mem`, as the answer key says); `check` 1 (faults present);
  `teardown` with a reason, 0 labelled objects left. As expected.

### Known issues

Found by the release gate; none blocked it.

- **RG-1 (low–medium): fixed (spec D54).** On the database node
  `/etc/postgresql` is group-writable by `pgconf` without the sticky bit,
  so `player` could delete or replace the root-owned seed marker kept
  there, where the access model says protected files cannot be edited,
  enforced by the system. The owner ruled that the brick changes and the
  access model stays as written. The marker is now
  `/var/lib/gm-state/.gm-seeded` (directory root-owned, 0755; marker
  root-owned, 0444) on a new named volume `gmstate`, declared in
  `bricks/postgres/brick.yaml` and listed there under protected files;
  `/etc/postgresql` is unchanged. Each game now has 8 volumes. The
  postgres stack test checks that `player`, `postgres` and `COPY ... TO
  PROGRAM` cannot remove the marker, and the marker left the starter
  packs' DO NOT TAMPER lists. Fix fd1c8a9, merged 1969011.
- **RG-2 (low): wording, clarified (spec D53, accepted by the owner).** Master spec 17 item 4
  asked for every *fix* issue to be fixed by file and reload or restart
  and by `ALTER SYSTEM`, which cannot apply to a fix made by DDL. The
  item now asks it of configuration settings only; schema and index
  fixes are made by their DDL. The answer key, the scenario and the code
  are unchanged.
- **RG-3 (cosmetic), known issue, kept open by the owner.** The answer key's bare `psql -c` evidence
  commands work on the database node, not on the bastion (no `PGHOST`
  there), and the key does not say where to run them.
- **RG-4 (cosmetic), known issue, kept open by the owner.** GM sessions state times in different time
  zones (one in CEST, another in UTC).

### Feedback tone (G5)

The feedback of game `bookshop-new-server-pwbho8` was sent to the owner
for judgement.

- G5: acceptable, 2026-10-21, the owner.
