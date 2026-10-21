# db_audit_gm v0.1 — Build plan

Status: v5 (2026-10-21): chunk 10 inserted in wave 3 for the teardown
reason and a new game after a failed setup (spec D50, D51, D52).
Approval: approved 2026-10-20 by the lead under the owner's delegation (G1).
Written from: [master-spec.md](master-spec.md) and
[access-model.md](access-model.md), both approved 2026-10-20. No design set
(no interface to design).

The model is `~/.local/share/dev_team/references/build-plan-model.md`; this
plan states only its deltas.

## Read first

- The repository holds no code yet: only `README.md`, `precursor.md`, the
  `specs/` tree, and a `.gitignore` containing `*.db`. Every **Files** line
  below creates new files; chunk 4 adds `local/` to `.gitignore`.
- There is no intent register and no data register in this repository, so
  there are no wave preflights by `documentalist`, no captures by it, no
  post-task sync, and no data preflight. Where the model calls for an
  architecture capture, the wave driver records the interface in the wave
  log on the wave branch before the dependent chunk starts.
- The build host used so far: Debian 13, Docker Engine 29.8, swarm mode
  inactive, Python 3 with PyYAML 6.0.2, no `shellcheck`.
- **Tmpfs mounts under `docker stack deploy`**, confirmed on this host:
  Docker tmpfs mounts default to `noexec`, and the stack loader (CLI
  29.8.2) silently drops a tmpfs `mode` and `options: [exec]`, for file
  formats 3.8 and 3.13 alike. s6-overlay v3 very likely needs an exec-able
  `/run`. Chunk 2 proves its node under a real stack deploy for that
  reason.
- The master spec was clarified before wave 1 (spec D46): configs and
  secrets are created and labelled by `gmctl deploy` and external in the
  stack file; the validator reads a per-game envelope file; sealed checks
  query PostgreSQL as `postgres`.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | Plan approval | The lead, under the owner's delegation | Wave 1 | done (2026-10-20, plan v2 approved after review) |
| G2 | Network access at image build time (Debian and PostgreSQL apt repositories, the s6-overlay release download) | Hand check by the wave driver | Chunks 2, 3 | done (2026-10-20, wave driver's hand check: registry pull succeeded) |
| G3 | A Docker host in swarm mode (`docker swarm init` on the build host is enough) | Hand check by the wave driver | Chunk 2, wave 2 gate, wave 3 gate, release gate | done (2026-10-20, `docker swarm init` on the build host, owner-approved) |
| G4 | Review of the v0.1 scenario's defects, issues and answer key | The lead | Chunk 8's merge | done (2026-10-21, the owner after an independent review, OKAY) |
| G5 | Feedback tone judged acceptable | The owner | Release close | open |

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3 | G1, G2, G3 (chunk 2) | merged (80e9048) |
| 2 | 4, 5, 6 | wave 1 | merged (d3547c3) |
| 3 | 7, 8, 9, 10 | wave 2, G4 (for chunk 8's merge) | in progress |

```
1 ──> 2, 3            (in-wave: brick.yaml keys captured at wave start)
1 ──> 6
4 ──> 5               (in-wave: local implementation files and render interface captured at wave start)
2, 3, 4, 5 ──> 7
1, 2, 6, 7 ──> 8      (in-wave 7 -> 8: injection rules captured at wave 3 start; exit codes fixed by master spec 8.1)
5, 6, 7 ──> 9         (in-wave 7 -> 9: gmctl signatures captured at wave 3 start)
5, 7, 9 ──> 10        (in-wave 7, 9 -> 10: inserted after both merged; it builds on merged code)
```

## Workflow deltas

- κ = 1 (default).
- Branches: `v0.1-w<n>` for waves, `v0.1-c<id>-<slug>` for chunks.
- **Chunk checks**, in addition to the model's:
  - Python: `python3 -m unittest discover -s tools/tests -t .`
    (tests related to the files touched, or all of them; the suite is
    small). It needs `tools/__init__.py` and `tools/tests/__init__.py`,
    which chunk 4 creates; no earlier chunk adds Python tests, so in wave 1
    YAML files are checked with a one-line PyYAML load instead;
  - shell: `sh -n` on every `*.sh` the chunk touches (`shellcheck` too when
    installed);
  - YAML: every YAML file the chunk touches loads with PyYAML (from chunk
    4 on, the unit suite includes a test loading all templates, bricks,
    faults and scenarios);
  - image chunks: `docker build` of the brick.
- **Wave gate (full quality command)**: the full unit suite, `sh -n` on
  every shell script, both image builds, and from wave 2 the smoke run
  `tools/tests/smoke.sh` on the local single-node swarm (needs G3). As
  chunk 5 built it: fit, render, deploy (waiting for health), `exec`,
  `logs`, `status`, teardown, then asserts nothing labelled with the game
  id is left and objects not belonging to the game are unchanged. Chunk 7
  adds `load-data`, `inject`, `check` and `validate` in the script's
  marked section (capture W3-A), so the wave gate runs them from wave 3.
- No link checker is configured; Markdown links are checked by reading.

## Measurements and hand checks

- G2 and G3: hand checks by the wave driver before wave 1 (G3 before
  chunk 2).
- The play-through as `player` and the stance check-list: release gate.

## Chunks

### Chunk 1 — Format skill and templates

Status: merged (w1, 165e153)
Record: chunk commit 8892378; no deviation from the spec; conventions
recorded as wave-log capture W1-D.
Wave: 1
Depends on: G1
Architecture capture: the top-level keys of `brick.yaml`, recorded by the
wave driver at wave start so chunks 2 and 3 can write theirs.

- Goal: the format skill and its four templates, so every scenario, brick
  and fault is written to one shape.
- Scope: in: `SKILL.md` (start from the template, fill every required
  item, flag any missing one; the GM refuses to deploy an incomplete
  scenario), templates for `scenario.yaml`, `answer-key.yaml`,
  `brick.yaml`, `fault.yaml`, and the folder layouts; marked as initial and
  expected to evolve. The fault template states that a sealed check run as
  root queries PostgreSQL as `postgres` (`runuser -u postgres`, or exec as
  `postgres`) so that peer authentication applies. Out: no schema-check
  script.
- Files: `.claude/skills/scenario-format/SKILL.md`,
  `.claude/skills/scenario-format/templates/{scenario,answer-key,brick,fault}.yaml`,
  `.claude/skills/scenario-format/templates/layouts.md`.
- Spec sections: master spec 6, 7, 8.
- Atoms: none (no intent register).
- Done when: each template carries every item the master spec requires,
  with optional-in-v0.1 fields marked; the skill states the flag-and-refuse
  rule; every template loads as YAML.
- Verification: chunk checks.

### Chunk 2 — PostgreSQL brick

Status: merged (w1, 934925f)
Record: chunk commit 8838643; `/run` fallback (a), a named volume emptied
by the entrypoint (read-only root kept, spec unchanged); a fourth volume
`run`; `fixable` only; see wave-log capture W1-E.
Wave: 1
Depends on: chunk 1 (captured `brick.yaml` keys), G2, G3
Architecture capture: the brick's fixed in-container paths (seed
directory, secrets, `/etc/postgresql`, PGDATA), its secret names, and the
per-game envelope file's in-container path and format (read by the
validator, delivered as a protected config), recorded at wave start
(chunks 4, 5, 7 and 8 rely on them).

- Goal: the PostgreSQL 18 node image and its brick definition.
- Scope: in: Debian 13 image with PostgreSQL 18 server and client;
  s6-overlay running PostgreSQL and `sshd` (`S6_READ_ONLY_ROOT`, tmpfs
  `/run`); entrypoint seeding `/etc/postgresql` once from the seed
  directory and initialising PGDATA if empty; `config_file` and `hba_file`
  outside PGDATA; accounts `player` (key from a secret) and role `dba`
  (password from a secret, `.pgpass`); the GM's `local all postgres peer`
  line; `sudo` wrappers `gm-reload-db`, `gm-restart-db`, `gm-validate` and
  a restricted `sudoers`; the public validator; read-only root with its
  writable targets; capabilities listed in `brick.yaml`; health check;
  player and GM docs. Out: any scenario content or fault.
- Files: `bricks/postgres/Dockerfile`, `bricks/postgres/brick.yaml`,
  `bricks/postgres/rootfs/` (s6 service definitions, entrypoint, wrappers,
  `sudoers.d` file), `bricks/postgres/validator/validate.sh`,
  `bricks/postgres/docs/{player,gm}.md`.
- Spec sections: master spec 9.1, 7, 8.1, 14.
- Atoms: none.
- Done when: the image builds; a **one-service `docker stack deploy`** of
  the brick, using only the mounts, capabilities and `read_only` setting a
  rendered stack file can express (no tmpfs `mode` or `exec` option, which
  the stack loader drops), with seed files, the envelope file and secrets
  as configs and secrets, serves PostgreSQL, accepts SSH as `player`, lets
  `player` run exactly the three wrappers, keeps edits to
  `/etc/postgresql` across a restart through `gm-restart-db`, and the
  validator exits 0 on an in-envelope configuration and 1 on an
  out-of-envelope one. A `docker run` with `--tmpfs /run:exec` does not
  count: it would hide the problem.
- Fallback, if s6-overlay cannot run on the stack-deployable `/run`: the
  chunk owner chooses from evidence and reports which, and why:
  (a) a named volume for `/run`, cleared by the entrypoint at start; or
  (b) no read-only root on this node, with the protected files still
  read-only mounts. Choice (b) changes the master spec's hardening; it
  gets a decision entry from spec-writer when the chunk reports.
- Build hints (not new scope): `sudo` needs a log file, since there is no
  syslog; `sshd` host keys need a home on a read-only root; the player's
  home must be writable for `.pgpass` and `report.md`; `/run/postgresql`
  must be created at boot, owned by `postgres`.
- Verification: chunk checks, plus the stack deploy above (needs G3).
- Split rule: 2a image, s6, `sshd`, entrypoint and accounts; 2b wrappers,
  `sudoers`, validator, `brick.yaml`, docs.

### Chunk 3 — Bastion brick

Status: merged (w1, 1565cbe)
Record: chunk commit ddf2a19; extra `hostkeys` volume, `/run` as a volume
(W1-E), no strict host-key checking for in-game names; see wave-log
capture W1-F.
Wave: 1
Depends on: chunk 1 (captured `brick.yaml` keys), G2
Architecture capture: the bastion's secret names and starter-pack path,
recorded at wave start.

- Goal: the bastion image and its brick definition.
- Scope: in: Debian 13, `sshd` under s6-overlay, read-only root,
  PostgreSQL 18 client tools, SSH client; account `player` with password
  from a secret, private key and `.pgpass` from secrets, starter pack from
  configs, a writable home for `~/report.md`; health check; docs. Out:
  anything on the database side.
- Files: `bricks/bastion/Dockerfile`, `bricks/bastion/brick.yaml`,
  `bricks/bastion/rootfs/`, `bricks/bastion/validator/validate.sh`,
  `bricks/bastion/docs/{player,gm}.md`.
- Spec sections: master spec 9.2, 14.
- Atoms: none.
- Done when: the image builds; a container started by hand with secrets
  accepts the password login and reaches a database container by name with
  the key and `psql`.
- Verification: chunk checks, plus the hand run above.

### Chunk 4 — Scenario model, capacity check and renderer

Status: merged (w2, d49bca6)
Record: chunk commit 79fc1d3, merged d49bca6; built as one commit, not
split (fit writes the local implementation, so 4a/4b would cut one module).
Choices within the spec, logged as W2-B: headroom 10 % per dimension;
the scenario-id part of the game id is trimmed so every derived name fits
Swarm's limits; fit refuses more than one network, brick secrets outside
the four W2-A files, and protected configs other than `envelopes`;
`implementation.yaml` carries extra derived names.
Wave: 2
Depends on: chunk 1
Architecture capture, recorded at wave start for chunk 5: the local
implementation's files (`playground.yaml`, `implementation.yaml`,
`state.yaml`, `secrets/`); the `render` interface; that configs and
secrets are created by `gmctl deploy`, labelled with the game id by
`gmctl` itself, and referenced as external in the stack file; the
per-game envelope file as captured in wave 1 (chunk 2).

- Goal: `gmctl fit` and `gmctl render`, on a loaded and checked scenario.
- Scope: in: the `gmctl` entry point; loading `scenario.yaml`,
  `brick.yaml` and `fault.yaml` with catalog references by id and pinned
  version (scenario-local bricks and faults first); refusing an incomplete
  scenario; the capacity check (no recomputation); game id generation;
  writing the local implementation; rendering the stack file (Compose file
  format 3.8, game-id names, external configs and secrets, volumes,
  capabilities, `read_only`, the mounts chunk 2 proved, single-host
  placement, only the bastion port published) and the per-game envelope
  file; `local/` in `.gitignore`; unit tests with a fixture scenario. Out:
  talking to Docker.
- Files: `tools/__init__.py`, `tools/gmctl`,
  `tools/gm/{__init__,model,fit,render,localimpl}.py`,
  `tools/tests/__init__.py`, `tools/tests/test_{model,fit,render}.py`,
  `tools/tests/fixtures/`, `.gitignore`.
- Spec sections: master spec 6, 10.3, 11.
- Atoms: none.
- Done when: `fit` accepts the fixture on a sufficient playground and
  refuses it on an insufficient one; `render` produces a stack file whose
  names all carry the game id and that `docker stack config` accepts, and
  an envelope file in the captured format; an incomplete scenario is
  refused with the missing items listed;
  `python3 -m unittest discover -s tools/tests -t .` runs.
- Verification: chunk checks.
- Split rule: 4a model, loading and `fit`; 4b local implementation and
  `render`.

### Chunk 5 — Platform operations

Status: merged (w2, 6231044)
Record: split per its rule: 5a 54f4542, 5b fdd91ab, merged 6231044. No
deviation from the spec or captures; choices within the spec logged as
W2-C (`ssh-keygen` on the GM host, credentials regenerated per deploy and
kept after teardown, deploy retry from a failed deploy, 300 s health
wait). Smoke run: 17 checks passed on the local swarm.
Wave: 2
Depends on: chunk 4 (captured interface)
Architecture capture: none beyond chunk 4's.

- Goal: `gmctl deploy`, `exec`, `logs`, `status`, `teardown`.
- Scope: in: targeting the local engine or an `ssh://` endpoint; checking
  for a swarm and reporting when there is none (or running `docker swarm
  init` when asked); generating per-game credentials into
  `local/<playground>/secrets/` (mode 0600); creating configs and secrets
  named after the game id and labelled with it by `gmctl` (they are
  external in the stack file, so the stack does not label them); `docker stack deploy --resolve-image never`;
  waiting for health checks; `exec` (find the container by service label,
  stream stdin to `sh -s` with environment variables, as a given user);
  label-based teardown including volumes; recording the stage and any
  failure in `state.yaml`, and tearing down on a failed setup; the smoke
  script. Out: data load, injection, checks.
- Files: `tools/gm/{docker,deploy,execnode,teardown,state}.py`,
  `tools/tests/test_{deploy,teardown,state}.py`, `tools/tests/smoke.sh`.
- Spec sections: master spec 10, 11, 12 ("Failures").
- Atoms: none.
- Done when: unit tests cover naming, credential generation and the
  failure path (with Docker calls stubbed); the smoke run deploys the
  fixture on a single-node swarm, `exec` returns a command's output, and
  teardown leaves nothing labelled with the game id.
- Verification: chunk checks, plus `tools/tests/smoke.sh` (needs G3).
- Split rule: 5a deploy, credentials, state; 5b exec, logs, teardown,
  smoke script.

### Chunk 6 — Scenario-document skill

Status: merged (w2, b2d0e1d)
Record: chunk commit d5bc485, merged b2d0e1d. No deviation; the "answer
key summary" renders every answer-key field (6.2 lists each as required
content), and a section lists starter pack, node files and data as paths.
Wave: 2
Depends on: chunk 1
Architecture capture: none.

- Goal: the skill and template that generate a scenario's `README.md` from
  `scenario.yaml` and `gm/answer-key.yaml`.
- Scope: in: `SKILL.md` (when to regenerate, never edit by hand), the
  template with the prominent "do not read" warning first, then scenario
  information, background, topology, host topology, defects and issues,
  answer key summary; marked initial and expected to evolve. Out: any
  script.
- Files: `.claude/skills/scenario-document/SKILL.md`,
  `.claude/skills/scenario-document/template.md`.
- Spec sections: master spec 6.
- Atoms: none.
- Done when: the template covers every content item of master spec 6.2
  and opens with the warning.
- Verification: chunk checks.

### Chunk 7 — Data load, injection, validator run and sealed checks

Status: merged (w3, cb19992)
Record: chunk commits 8269558 (7a), d9b8560 (7b); no deviation from W3-A or
D49; `validate` and `check` exit 2 on a refusal (wave-log capture W3-B);
master spec 8.1's "fed to `sh -s`" wording for the data load sent to
`spec-writer` at the wave gate.
Wave: 3
Depends on: chunks 2, 3, 5
Architecture capture: recorded by the wave driver at wave 3 start as
wave-log capture W3-A (chunks 8 and 9 rely on it): fault-parameter
environment variables, the `load-data`, `inject`, `validate` and `check`
rules, the GM-recorded stages, and the argument signatures of every
`gmctl` subcommand. The exit-code contracts are fixed by master spec 8.1.

- Goal: `gmctl load-data`, `inject`, `validate`, `check`, and `status
  --set` for the stages only the GM can record.
- Scope: in: streaming `data/<node>.sql` into a node; running each state
  fault's `inject/*.sh` with its parameters; refusing, when the scenario
  loads, a fault parameter whose environment name is invalid; the
  official validator run on every node, from the bricks' new
  `extra.validator`; running every sealed check and printing one line per
  fault instance; exit codes per the contracts; marking a failed data load
  or injection as a failed setup; `gmctl status --set
  handed-over|final-answer|feedback-given` with its allowed transitions
  (spec D49); a test fault and fixture data to exercise them; the smoke
  script extended to these steps. Out: the v0.1 faults; any brick image
  change.
- Files: `tools/gm/{inject,checks}.py` (new; module boundaries are the
  chunk's choice, W3-A), `tools/gm/__init__.py` (CLI wiring),
  `tools/gm/execnode.py` (optional `argv`), `tools/gm/model.py`
  (parameter-name refusal), `tools/gm/state.py` (`status --set`, on
  `localimpl`'s existing stage functions; `tools/gm/localimpl.py` only if
  they need a change), `bricks/postgres/brick.yaml`,
  `bricks/bastion/brick.yaml` (`extra.validator`),
  `tools/tests/test_{inject,checks,state,model}.py`,
  `tools/tests/fixtures/fixture-audit/` (a state test fault under
  `faults/`, its instance and answer-key entry, `data/<node>.sql`, README
  regenerated), `tools/tests/smoke.sh`.
- Spec sections: master spec 8.1, 10.1, 11, 12, 13 ("Evaluation");
  wave-log capture W3-A.
- Atoms: none.
- Done when: on the smoke deployment, the fixture data loads, the test
  fault plants twice with the same result, its sealed check returns 1,
  then 0 after the fix is applied through `exec`, and `validate` reports
  green and red correctly; unit tests show `status --set` taking
  `injected` to `handed-over`, `final-answer` and `feedback-given` in turn,
  changing nothing when set to the current stage, and refusing any other
  transition with exit 1 and `state.yaml` unchanged.
- Verification: chunk checks, plus the smoke run `tools/tests/smoke.sh`,
  extended in its marked section as W3-A's "Smoke run" states (needs G3).
- Split rule: 7a data load, injection and GM-recorded stages: `execnode`
  `argv`, the parameter-name refusal and `FAULT_*` environment,
  `load-data`, `inject`, `status --set` and their CLI wiring, the fixture
  test fault and data, their tests, and the smoke steps `load-data` and
  `inject` twice. 7b evaluation: `validate` with `extra.validator` in both
  `brick.yaml`, `check`, their CLI wiring and tests, and the remaining
  smoke steps (`check`, the fix through `exec`, `check`, `validate` green
  then red).

### Chunk 8 — v0.1 faults and scenario folder

Status: merged (w3, fcfaeb1)
Record: chunk commit cf1457c; no deviation from the spec; G4 review's
non-blocking points in the wave log; `bricks/postgres/brick.yaml` keeps
`compatible_faults: []` (a brick change, outside the chunk).
Wave: 3
Depends on: chunks 1, 2, 6, 7; G4 before merge
Architecture capture: none of its own; it uses the parameter naming rule,
the injection order and the `load-data` rules captured at wave 3 start.

- Goal: the v0.1 scenario, complete, and the catalog faults it uses.
- Scope: in: the chosen defects (from master spec 15's candidates, within
  the database and its configuration, statically visible), each as a
  fault definition with `inject/` and `checks/fixed.sh`; `scenario.yaml`,
  `gm/answer-key.yaml`, `gm/notes.md`, `brief.md`, the starter pack, node
  seed files, `data/<node>.sql`; `README.md` generated with the
  scenario-document skill. At least one known and one hidden fault; at
  least one *report* or *propose* issue and one *fix* issue. Out: monitoring,
  load, backup-tooling defects.
- Files: `faults/<fault-id>/` for each chosen defect,
  `scenarios/<scenario-id>/` (all of it).
- Spec sections: master spec 6, 8, 15.
- Atoms: none.
- Done when: the format skill finds nothing missing; `gmctl fit` and
  `render` accept it; on the smoke deployment every injection succeeds and
  every sealed check returns 1; the lead has cleared G4.
- Verification: chunk checks, plus a smoke deployment of this scenario.

### Chunk 9 — GM skill

Status: merged (w3, d6a9d96)
Record: chunk commit 1b42aa3; master spec 12's stop reason between setup
steps not recordable by gmctl: the skill states it in the session until
chunk 10 adds `teardown --reason` (owner ruling 2026-10-21).
Wave: 3
Depends on: chunks 5, 6, 7
Architecture capture: none of its own; it uses the `gmctl` argument
signatures captured at wave 3 start (the subcommand set is fixed by master
spec 11).

- Goal: the GM persona and run skill.
- Scope: in: explicit invocation (`/game-master`); the setup questions
  (Docker endpoint, capacity, scenario choice); the setup sequence through
  `gmctl` with the failure rule; hand-over (address, port, password,
  starter pack, issues with expected resolutions); the stance (no reveals,
  stop only, polite refusals of hints, resets, restarts and extra time);
  report intake (pasted, `~/report.md` through `exec`, or discussion) and
  the final-answer question; evaluation with `validate` and `check`;
  feedback structure and tone; recording hand-over, final answer and
  feedback with `gmctl status --set` (W3-A); teardown; restart from a local
  implementation in progress, and the recommended fresh session for the
  report. Marked initial and expected to evolve. Out: new scripts.
- Files: `.claude/skills/game-master/SKILL.md`,
  `.claude/skills/game-master/` reference notes as needed.
- Spec sections: master spec 12, 13, 14, access model.
- Atoms: none.
- Done when: the skill text covers every item of the stance check-list
  (master spec 17, item 5) and the restart path, and calls only existing
  `gmctl` subcommands; it records each of the three GM stages with
  `status --set` at the step that reaches it.
- Verification: chunk checks; the stance check-list itself runs at the
  release gate.

### Chunk 10 — Teardown reason, and a new game after a failed setup

Status: planned
Wave: 3
Depends on: chunks 5, 7, 9 (all merged)
Architecture capture: none; the `teardown` record's shape in `state.yaml`
is fixed below, and only this chunk's code and the GM skill read it.

- Goal: a stop during setup records its reason (spec D50), and a
  playground whose failed game was torn down takes a new game (spec D51).
- Scope: in:
  - **The teardown record.** `state.yaml` gains a top-level key
    `teardown: {stage, reason, at}`: `stage` is the last stage reached
    (`localimpl.effective_stage`), `reason` the text given or `null`, `at`
    the time. A `gmctl teardown` that leaves nothing labelled with the game
    id writes it when the state has none and the game is not already at
    `torn-down`; a teardown that leaves objects (exit 1) writes nothing; a
    later teardown leaves the record unchanged (and says so when given a
    reason). Stages are recorded as now (W2-C): `torn-down` with its
    history entry; for a failed game, stage `failed` and its `failure`
    kept, no history entry. A new game's `state.yaml` has no record; a
    state file without the key reads as having none.
  - **`gmctl teardown [--reason TEXT]`.** The reason, whitespace collapsed
    to one line, goes into the record; an empty reason is refused (exit 1)
    before anything is removed. Without `--reason` the record carries
    `reason: null`.
  - **`status`** prints the record when there is one: `  torn down: at
    <at>, from stage <stage>: <reason>` (`no reason given` when `null`).
  - **`fit` after a torn-down failed game.** On a `failed` game whose
    failure came after deployment (failure stage `deployed`, `data-loaded`
    or `injected`) and that has a teardown record, `fit` starts a new game
    (new game id, `implementation.yaml` and `state.yaml` written afresh,
    stage `fitted`), as it does after `torn-down`. Unchanged: a refit
    before deployment keeps the game id; `deploy` still retries a failed
    deploy (W2-C).
  - **`fit`'s remaining refusals** (exit 1, nothing written): a game at a
    deployed stage, and a game failed after deployment with no teardown
    record. The message names the game id and its stage (for a failed
    game, the stage it failed before) and what unblocks it: `gmctl
    teardown`, then `fit` again; for a failed deploy, also `gmctl deploy`
    to retry it.
  - **GM skill.** `SKILL.md` "Setup failures": the stop bullet runs
    `teardown --reason` at whatever setup stage the game is (it removes
    nothing when nothing was deployed) and no longer says `gmctl` cannot
    record the reason; the "Trying again" bullet fits a new game on the
    same playground after the confirming teardown, instead of a new
    playground slug; the bullet on a failed `deploy`, `load-data` or
    `inject` says the confirming teardown also records the teardown. The
    in-progress rule in "Start: is a game in progress?", the restart
    table's `failed` row and the "Teardown" section say that a failed game
    with its teardown recorded is over, like `torn-down`. `gmctl.md`: the
    "Stages" paragraph (the record), the `fit` and `teardown` rows, and
    the `status` and `teardown` output lines.
  - **Format skill.** `templates/layouts.md` "Script contracts" states the
    data load as master spec 8.1 now does (spec D52).
  - Out: the teardown a failed step runs itself (`state.setup_step`)
    writes no record, the GM's confirming `gmctl teardown` does; `deploy`;
    `smoke.sh` (unchanged).
- Files: `tools/gm/teardown.py` (the record, `--reason`),
  `tools/gm/localimpl.py` (the record's writer beside `set_stage` and
  `set_failed`, if it goes there), `tools/gm/state.py` (`status` line),
  `tools/gm/fit.py` (`_game_to_keep`, messages), `tools/gm/__init__.py`
  (`--reason`), `tools/tests/test_{teardown,fit,state}.py`,
  `.claude/skills/game-master/{SKILL,gmctl}.md`,
  `.claude/skills/scenario-format/templates/layouts.md`.
- Spec sections: master spec 8.1 (the data load), 11 (`teardown`), 12
  ("Failures"); spec D50, D51, D52; wave-log captures W2-A (`state.yaml`),
  W2-C (teardown, deploy retry), W3-B.
- Atoms: none.
- Done when:
  - (D50) a unit test: on a game at `injected` (Docker stubbed), `teardown
    --reason "stopped on request"` leaves nothing labelled, records
    `torn-down`, and `state.yaml` holds `teardown: {stage: injected,
    reason: stopped on request, at: ...}`, which `status` prints; the same
    at `fitted`, with nothing to remove, gives `stage: fitted`;
  - unit tests: without `--reason` the record has `reason: null`; an empty
    reason is refused with exit 1, nothing removed, `state.yaml`
    unchanged; a teardown that leaves objects writes no record; a second
    teardown leaves the record unchanged; on a failed game, stage `failed`
    and its `failure` stay and the record's `stage` is the last stage
    reached;
  - (D51) a unit test: a game failed in `load-data`, then torn down: `fit`
    exits 0 with a new game id at stage `fitted`; the same after a failure
    in `inject`;
  - unit tests: `fit` refuses with exit 1, nothing written and the
    corrected message, a game at a deployed stage and a game failed in
    `inject` without a teardown record; the existing `fit` tests (a refit
    before deployment keeps the game id) pass;
  - the two GM skill files keep no new-slug workaround, the stop bullet
    uses `--reason`, and every `gmctl` invocation in them parses with
    `gmctl`'s own parser;
  - the unit suite passes, and `tools/tests/smoke.sh` passes unchanged.
- Verification: chunk checks, plus the smoke run `tools/tests/smoke.sh`
  (it runs `fit` and `teardown`; needs G3).
- Split rule: 10a the teardown record, `--reason`, the `status` line,
  their tests, the skill's stop bullet and `gmctl.md`'s teardown lines;
  10b `fit` after a torn-down failed game and its messages, their tests,
  the other skill lines and `layouts.md`. 10b reads 10a's record.

## Release gate

Against master spec section 17, on the merged code, on a single-node swarm:

1. A full game with the v0.1 scenario in a GM session: setup, local
   implementation, deployment, data load, planting, hand-over.
2. Master spec section 17, item 3: the players reach the database node only
   through the bastion, the write policy holds, and `sudo gm-validate`
   runs. Then the manual play-through as `player`: each fault's evidence
   reachable as the answer key states; each *fix* issue fixed both by file
   and reload or restart and by `ALTER SYSTEM`, with its sealed check
   turning from 1 to 0.
3. The stance check-list, item by item.
4. A fresh GM session resuming the game in progress.
5. A forced setup failure: reported, torn down, stage recorded; teardown
   leaves nothing labelled with the game id.
6. The wave-gate quality command, green.
7. G5: the owner's judgement of the feedback tone.
8. Release notes in `specs/versions/v0.1/README.md`. They state that the
   per-game credentials are kept in the git-ignored
   `local/<playground>/secrets/`, mode 0600 (spec D45 narrows spec D31's
   "nothing written to the repository": nothing is committed).
