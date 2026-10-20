# db_audit_gm v0.1 — Wave log

Execution record for [build-plan.md](build-plan.md). Kept by the wave
driver (the lead's top-level session).

## Wave 1 — started 2026-10-20

Chunks: 1, 2, 3. κ = 1. Branch `v0.1-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.1-w1`, cut from `main` at 33c8bef
(specs baseline).

- **Gates.** G1 cleared: plan v2 (177540b) approved by the lead under the
  owner's delegation, after an independent review (OKAY, no blocking
  issue). G2 cleared: registry pull succeeded from this host. G3 cleared:
  the owner approved `docker swarm init` on the build host; this host is
  now a single-node swarm manager (Docker 29.8.2, Debian 13).
- **Preflight.** None: no intent register, no data register (plan, "Read
  first").
- **Captures** (recorded here before any code, per the plan's "Read
  first"):

### Capture W1-A — `brick.yaml` top-level keys (chunk 1; read by 2, 3)

Every `brick.yaml` has these top-level keys. Keys marked *optional* may be
omitted in v0.1.

| Key | Shape |
|---|---|
| `id` | brick id, lowercase, hyphens (`postgres`, `bastion`) |
| `version` | semver string (`0.1.0`) |
| `roles` | list of role names (`database`, `bastion`) |
| `technology` | `{name, version}` (`{name: postgresql, version: "18"}`) |
| `image` | full image name, `127.0.0.1:5000/dbagm/<id>:<version>` |
| `footprint` | defaults `{cpu, memory, disk}` (`cpu: 0.5`, `memory: 512M`, `disk: 1G`) |
| `footprint_ranges` | *optional* |
| `stateful` | boolean |
| `parameters` | map `name -> {description, default, required}`; passed to the container as environment variables `GM_<NAME>` (upper case) |
| `knobs` | list of `{setting, file, default, envelope}`; `envelope` is `{min, max}` or `{allowed: [..]}`, values written as PostgreSQL accepts them (`128MB`, `5s`, `on`) |
| `write_policies` | list of supported policies (`report-only`, `fixable`) |
| `writable_paths` | list of in-container paths |
| `protected_files` | list of in-container paths |
| `player_access` | `{ssh_account, group, sudo_wrappers: [..]}` |
| `capabilities` | list added back after `cap_drop: ALL` |
| `healthcheck` | `{command: [..], interval, timeout, retries, start_period}` |
| `secrets` | list of `{name, path, uid, gid, mode}`; `name` is logical, the Swarm name is `<game-id>_<name>` |
| `seed` | `{dir, files: [..]}`: fixed seed directory and the seed files the scenario provides |
| `protected_configs` | list of `{name, path, uid, gid, mode}` mounted read-only from configs |
| `volumes` | list of `{name, path}`; volume names become `<game-id>_<node>_<name>` |
| `processes` | list of s6 service names |
| `compatible_faults` | list of fault ids (may be empty at first) |
| `companion` | *optional* `{path, when}` |
| `interfaces` | *optional* |
| `monitoring` | *optional* |

Brick-specific extras are allowed under a key `extra`.

### Capture W1-B — PostgreSQL brick fixed paths and names (chunk 2; read by 4, 5, 7, 8)

- Seed directory: `/opt/gm/seed/` (configs mounted read-only); seed files
  `postgresql.conf`, `pg_hba.conf`. Copied once into `/etc/postgresql/`;
  marker `/etc/postgresql/.gm-seeded`.
- Volumes: `pgdata` at `/var/lib/postgresql/18/data` (PGDATA); `pgconf` at
  `/etc/postgresql`; `home` at `/home/player`.
- Secrets directory: `/opt/gm/secrets/`. Secrets: `player_ssh_pubkey`
  (the inner-hop public key), `dba_password`.
- Envelope file: protected config `envelopes` at
  `/opt/gm/protected/envelopes.conf`, root-owned, mode 0444. Format: UTF-8
  text, one rule per line, `#` comments and blank lines ignored:
  - `<setting> range <min> <max>` — `<min>`/`<max>` in any form PostgreSQL
    accepts for that setting (`128MB`, `30s`), or `-` for unbounded;
  - `<setting> enum <v1>,<v2>,...`.

  The validator normalises values through PostgreSQL (the setting's base
  unit) and checks both the value in effect (`pg_settings`) and the value
  pending in the files (`pg_file_settings`).
- Wrappers: `/usr/local/sbin/gm-reload-db`, `/usr/local/sbin/gm-restart-db`,
  `/usr/local/sbin/gm-validate`; validator at `/opt/gm/validator/validate.sh`.
- Container port 5432 and 22; nothing published.

### Capture W1-C — bastion secrets and starter pack (chunk 3; read by 4, 5, 9)

- Secrets directory: `/opt/gm/secrets/`. Secrets: `player_password`,
  `player_ssh_key` (inner-hop private key), `dba_password` (the same Swarm
  secret as the PostgreSQL node's).
- Starter pack: configs mounted read-only under `/opt/gm/starter/`, copied
  once into `/home/player/` (volume `home`); the entrypoint also writes
  `~/.ssh/id_ed25519` and `~/.pgpass` (`*:*:*:dba:<password>`) from the
  secrets.
- Container port 22; the stack publishes it (default 2222).

### Capture W1-D — format conventions fixed by chunk 1 (read by 2, 3, 4, 7, 8)

Recorded after chunk 1 merged; chosen within its remit.

- Fault parameters reach inject and check scripts as `FAULT_<NAME>`
  environment variables (distinct from bricks' `GM_<NAME>`).
- Secret and protected-config modes in `brick.yaml` are quoted octal
  strings (`"0400"`), parsed in base 8 by the renderer.
- `scenario.yaml` nodes map each of the brick's `seed.files` to a folder
  file via `seed_files: {<seed file>: <relative path>}`; the bastion's
  starter pack is mapped the same way (`README.md: player/README.md`).
- `published_ports: [{port, default}]` (bastion default 2222);
  `resources.reservations` includes `disk`; `session_length_minutes`
  (at most 240).
- Required/optional status lives in template comments and the skill's
  checklists; chunk 4's completeness check takes its required-key list
  from the templates.

### Capture W1-E — outcomes of chunk 2 (read by 3, 4, 5, 7, 8)

Recorded after chunk 2 merged.

- **`/run` fallback (a) taken.** s6-overlay 3.2.3.2 refuses a `noexec`
  `/run` (`exec: /run/s6/basedir/bin/init: Permission denied`, exit 126),
  and a stack file cannot make a tmpfs exec-able. `/run` is a named volume
  `run`, emptied by the entrypoint before `/init`. The root filesystem stays
  read-only, so the spec's hardening is unchanged and no decision entry is
  needed. Every s6 brick (the bastion included) follows the same pattern.
- **W1-B amended:** the PostgreSQL brick's volumes are `pgdata`, `pgconf`,
  `home`, `run`. `sudo` logs to `/run/gm/sudo.log`; `/tmp` links to
  `/run/tmp`.
- **Write policy:** the PostgreSQL brick supports `fixable` only in v0.1
  (spec 14: the database node is fixable).
- **Seed requirements** (for chunk 8; in `bricks/postgres/docs/gm.md`):
  the seed `postgresql.conf` sets `listen_addresses = '*'` and
  `port = 5432` and never sets `config_file`, `hba_file` or
  `data_directory`; the seed `pg_hba.conf` holds `local all postgres peer`
  marked DO NOT TAMPER, plus scram lines for `dba`.
- **Envelope rendering** (for chunk 4): `{min, max}` becomes
  `<setting> range <min> <max>`, with `-` for an unbounded side;
  `{allowed: [..]}` becomes `<setting> enum <v1>,<v2>`. Booleans are quoted
  in YAML (`"on"`).
- **Validator output** (for chunks 5, 7, 9): `GREEN`/`RED`/`ERROR` lines,
  exit 0/1/2.
- **Inner-hop host key:** the node's sshd host key is regenerated at every
  container start, so a replaced container shows a changed host key.

### Capture W1-F — outcomes of chunk 3 (read by 4, 5, 9)

Recorded after chunk 3 merged; accepted by the wave driver.

- **Extra volume `hostkeys`** at `/var/lib/gm-sshd-keys` on the bastion:
  its sshd host key survives a container replacement, so players' own SSH
  clients see no changed key mid-game. The bastion's volumes are `home`,
  `run`, `hostkeys`.
- **Inner hop:** strict host-key checking is off for dotless in-game names
  only (`/etc/ssh/ssh_config.d/gm-game.conf`), so a replaced database node
  never locks players out.
- **Bastion `brick.yaml`:** `write_policies: [report-only]`; starter pack
  `seed: {dir: /opt/gm/starter/, files: [README.md, story.md, issues.md]}`;
  `extra.published_port_default: 2222`; secrets at mode `"0400"`.
- **For the renderer (chunk 4):** `dba_password` is one Swarm secret shared
  by both nodes; `player_ssh_key` is the private half of the database
  node's `player_ssh_pubkey`; the bastion publishes container port 22
  (host mode or routing mesh: the renderer's call).

### Dispatch

- Chunk 1: dispatched 2026-10-20; merged 165e153 (chunk commit 8892378).
  No deviation.
- Chunk 2: dispatched 2026-10-20; merged 934925f (chunk commit 8838643).
  Fallback (a) for `/run`; deviations recorded in W1-E.
- Roadmap (spec-writer, outside the chunk list): merged 45ce85c
  (commit 6abcaa8; D47, D48, O46–O54). Branch `roadmap` kept until the
  wave merges.
- Chunk 3: dispatched 2026-10-20; merged 1565cbe (chunk commit ddf2a19).
  Hand run replaced by a two-service stack test; choices in W1-F.

### Wave gate — 2026-10-20

Run by the wave driver on `v0.1-w1` (eaa5e1d), on the build host (Debian 13,
Docker 29.8.2, single-node swarm), nothing else heavy running.

- `sh -n` on every shell script under `bricks/` (with or without `.sh`):
  pass.
- PyYAML load of every YAML file (templates, both `brick.yaml`, both test
  stacks): pass.
- `docker build` of both images: pass (postgres `sha256:a55e764b…`,
  bastion `sha256:314de9c7…`).
- Stack tests: `bricks/postgres/tests/run-stack-test.sh` and
  `bricks/bastion/tests/run-stack-test.sh`, all checks passed; teardown
  left no stack, container, volume, config or secret.
- No unit suite yet (arrives in chunk 4); no smoke run (from wave 2); no
  bundle or performance figure applies.
- No post-task sync: no intent or data register.

Result: wave 1 gated. Waiting for the owner's word to merge `v0.1-w1` into
`main`. Branches kept until then: `v0.1-c1-format-skill`,
`v0.1-c2-postgres-brick`, `v0.1-c3-bastion-brick`, `roadmap`.
Open gates: G4 (the lead, chunk 8's merge, wave 3), G5 (the owner, release).

Merged into `main` on the owner's word: 80e9048 (2026-10-20). Wave 1
worktree and branches removed.

## Wave 2 — started 2026-10-20

Chunks: 4, 5, 6 (order 4 → 5 → 6, κ = 1). Branch `v0.1-w2`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.1-w2`, cut from `main` at 80e9048.
Gates: G3 done. Preflight: none (no registers).

### Capture W2-A — local implementation and render interface (chunk 4; read by 5, 7, 9)

Recorded before any code. Python module boundaries are chunk 4's choice;
the files and command lines below are fixed.

**Location.** `<scenario>/local/<playground>/`, where `<playground>` is a
slug the GM chooses at setup (`laptop`, `classroom`). `local/` is
git-ignored.

**Files.**

- `playground.yaml` — as declared: `name`, `platform: swarm`,
  `docker_endpoint` (`null` for the local engine, or `ssh://user@host`;
  never keys), `capacity: {cpu, memory, disk}`.
- `implementation.yaml` — written by `fit`: `scenario: {id, path}`,
  `game_id`, `created_at`, and per node: `brick` (id and version),
  `image`, `resources: {limits, reservations}` (copied from the scenario,
  never recomputed), `published_ports: [{target, published, mode: host}]`,
  plus the derived names below.
- `stack.yml` — written by `render`; Compose file format 3.8.
- `envelopes/<node>.conf` — written by `render`, format of capture W1-B /
  W1-E; the source of each node's `envelopes` protected config.
- `state.yaml` — `game_id`, `stage`, `history: [{stage, at}]`,
  `failure: {stage, reason, at}` or `null`. Stages, in order: `fitted`,
  `rendered`, `deployed`, `data-loaded`, `injected`, `handed-over`,
  `final-answer`, `feedback-given`, `torn-down`; or `failed`.
- `secrets/` — directory 0700, files 0600, written by `deploy`:
  `player_password`, `player_ssh_key`, `player_ssh_key.pub`,
  `dba_password`.

**Names** (game id: scenario id plus `-` plus 6 random `[a-z0-9]`, at most
63 characters, lowercase, digits and hyphens):

- stack: `<game_id>`; services `<game_id>_<node>`; network
  `<game_id>_net` (overlay, not attachable);
- volumes: `<game_id>_<node>_<volume>`, declared with an explicit `name:`;
- configs: `<game_id>_<node>_<file>` for seed and starter files (file name
  kept, `/` replaced by `-`), `<game_id>_<node>_envelopes` for the envelope
  file;
- secrets: `<game_id>_<secret>` (one `dba_password` shared by both nodes;
  `player_ssh_pubkey` is the content of `secrets/player_ssh_key.pub`);
- every config and secret carries the labels
  `com.docker.stack.namespace=<game_id>` and `dbagm.game=<game_id>`, set by
  `gmctl deploy`; volumes carry `dbagm.game=<game_id>` too. Teardown
  removes everything with either label.

**Stack file.** External configs and secrets; `read_only: true`,
`cap_drop: [ALL]`, `cap_add` from `brick.yaml`; the brick's volumes
(including `run`, W1-E, and the bastion's `hostkeys`, W1-F); no tmpfs;
health check from `brick.yaml`; resources from the implementation; every
service constrained to the single host (`node.role == manager` in v0.1);
only the bastion publishes a port, in `mode: host`; brick parameters as
`GM_<NAME>` environment variables.

**Command lines** (every subcommand prints a readable result and exits
non-zero on failure):

- `gmctl fit <scenario-dir> --playground <name> [--endpoint <url>]
  [--cpu N --memory SIZE --disk SIZE]` — loads and checks the scenario
  (refuses an incomplete one, listing what is missing), writes or reuses
  `playground.yaml`, runs the capacity check, writes `implementation.yaml`
  and `state.yaml` (stage `fitted`). Insufficient capacity: exit 1, nothing
  deployed.
- `gmctl render <scenario-dir> --playground <name>` — writes `stack.yml`
  and `envelopes/`, stage `rendered`.
- Chunk 5 adds `deploy`, `exec`, `logs`, `status`, `teardown` with the same
  `<scenario-dir> --playground <name>` pair; `exec` also takes `--node`,
  `--user`, and `--env KEY=VALUE` (repeatable), streaming stdin.

### Capture W2-B — chunk 4 outcomes and Python API (read by 5, 7, 9)

Chunk 4 merged 2026-10-20 (79fc1d3, merge d49bca6); 64 unit tests OK;
`docker stack config` accepts the rendered fixture stack file.

**Choices within the spec.**

- Headroom is 10 % of each declared dimension (`fit.HEADROOM`).
- The scenario-id part of the game id is trimmed so every derived name
  fits Swarm's limits (63 characters for services, 64 for configs and
  secrets).
- `fit` refuses what v0.1 cannot render: more than one scenario network, a
  brick secret outside the four W2-A secret files, a protected config other
  than `envelopes`.
- `implementation.yaml` also carries: top level `playground`, `stack`,
  `network`, `labels`, `secrets: [{name, secret, file}]`; per node
  `service`, `volumes`, `configs: [{kind: seed|envelopes, name, file, path,
  uid, gid, mode}]`, `secrets`. Every `file` is relative to the scenario
  folder.
- The fixture scenario (`tools/tests/fixtures/`) has one scenario-local
  hidden fault, `fixture-random-page-cost` (`random_page_cost = 4.0`), and
  seed files meeting W1-E.
- The completeness check derives required keys from the templates'
  `# optional` and "may be []" comments: changing those comments changes
  what is refused.

**Python API** (import from the repo root; `tools/gmctl` puts it on
`sys.path`).

- `tools.gm`: `main(argv)`, `build_parser()`; add a subcommand in
  `build_parser` with `_scenario_args(p)` and `p.set_defaults(func=...)`;
  raise `GmError` for a refusal (printed, exit 1).
- `tools.gm.model`: `load_scenario(dir)` → `Scenario` (`.id`, `.nodes`,
  `.node(name)`, `.bricks[node]`, `.faults[instance]`, each a `Definition`
  with `.data`, `.dir`, `.source`), or raises `IncompleteScenario`
  (`.missing`, `.report()`); also `GmError`, `parse_mode`.
- `tools.gm.localimpl`: `local_dir(scenario_dir, playground)`,
  `read_playground`, `read_implementation`, `read_state`,
  `secrets_dir(ldir)`; `require_stage(ldir, *stages)`, `set_stage(ldir,
  stage)`, `set_failed(ldir, stage, reason)`, `effective_stage(state)`,
  `STAGES`; `labels(game_id)`, `SECRET_FILES` (`player_ssh_pubkey` maps to
  `player_ssh_key.pub`), `STACK_FILE`, `write_text`.
- `tools.gm.fit.fit(...)` → `FitResult` (`.ok`, `.game_id`, `.text()`);
  `tools.gm.render.render(...)` → `RenderResult`.
- Deploy creates configs and secrets from `implementation.yaml`
  (`nodes[*].configs[*].{name,file}`, `secrets[*].{name,file}`) labelled
  with `labels(game_id)`, then runs `docker stack deploy -c
  local/<pg>/stack.yml <game_id>`.

Left for chunk 5: the first proof that Swarm applies the volume labels and
explicit `name:` on a real deploy.

### Capture W2-C — chunk 5 outcomes and API (read by 7, 9)

Chunk 5 merged 2026-10-20 (5a 54f4542, 5b fdd91ab, merge 6231044); 102
unit tests OK; `tools/tests/smoke.sh` passed 17 checks on the local
swarm; nothing labelled `dbagm.game` left afterwards (checked by the
driver too). A real deploy confirmed Swarm applies the explicit volume
`name:` and volume labels (W2-B's open item, closed).

**Choices within the spec.**

- The inner-hop ed25519 key is made with `ssh-keygen` on the GM host
  (subprocess, like `docker`); gmctl stops with a clear message without it.
- Credentials are regenerated on every deploy, no trailing newline;
  player password 16 characters without ambiguous glyphs, DBA password 32
  alphanumeric. Teardown leaves `secrets/` in place (0600, git-ignored).
- Deploy refuses without changing state when there is no swarm, the
  engine is a worker, or an image is missing. Credentials, objects, stack
  deploy and the health wait are one setup step: any failure or Ctrl-C
  tears down and records `failed`. A deploy may be retried from `failed`
  when the failure was in deploy and the last stage reached `rendered`.
- Teardown records `torn-down` (a failed game keeps its failure record),
  is idempotent, waits up to 120 s, and reports leftovers instead of
  recording `torn-down` when something won't go.
- Health wait: 300 s default (`--timeout`); fails at once when Swarm
  rejects a task.
- `exec --env` values appear in the host's process list: fine for
  `FAULT_*` and `GM_*`, never for credentials.
- Only the local engine was exercised live; `ssh://` is unit-tested only.
  `--init-swarm` passes no `--advertise-addr`.

**Python API.**

- `tools.gm.execnode.exec_node(ldir, node, user, stdin=None, env=None,
  capture=True, timeout=None, docker=None)` → `ExecResult(node, user,
  container, returncode, stdout, stderr)`, `.ok`. Runs `docker exec -i -u
  <user> -e K=V… <container> sh -s` on the container labelled
  `com.docker.swarm.service.name=<service>`. `stdin`: str, bytes, or a
  binary file object streamed as is (for `load-data`). `returncode` is the
  script's own status (validator 0/1/2 unchanged). Raises
  `execnode.ExecError` (a `GmError`) when the script cannot start: no
  game, a stage outside `state.DEPLOYED_STAGES`, unknown node, no running
  container, unknown user, Docker error (probed first with `docker exec -u
  <user> <ctr> true`).
- `tools.gm.state.setup_step(ldir, stage, undo=None)`: context manager; on
  error or interruption it calls `undo()`, records `failed` with the
  reason, raises `state.SetupFailed`. For `load-data` and `inject`: `undo=
  lambda: teardown.remove_game_objects(docker, game_id).text()`, then
  `localimpl.set_stage(ldir, stage)` on success. Also
  `state.status_text(ldir)`.
- `tools.gm.teardown`: `remove_game_objects(docker, game_id, timeout=120)`
  → `TeardownReport`; `teardown(scenario_dir, playground)`;
  `leftovers(docker, game_id)`.
- `tools.gm.docker.for_local_dir(ldir)` → `Docker` aimed at the
  playground's endpoint; `Docker.run(args, input=, stdin=, capture=,
  check=, timeout=)` raises `DockerError`. `deploy.deploy(...)` →
  `DeployResult`.
- Tests: `tools/tests/__init__.py` has `FakeDocker`, an in-memory engine.

**CLI** (each takes `<scenario-dir> --playground <name>`): `deploy
[--init-swarm] [--timeout SECONDS]`; `exec --node N --user U [--env
K=V]...` (script on stdin; exits with the script's status, or 125 when it
cannot start, reason on stderr); `logs --node N [--tail N] [--follow]`;
`status`; `teardown`.

**Smoke run.** `tools/tests/smoke.sh` has a marked section `# ---
validate and check (chunk 7) ---` between exec/logs and teardown. It needs
the swarm, both images and host port 2222 free.

### Dispatch

- Chunk 4: dispatched 2026-10-20; merged 2026-10-20 (d49bca6).
- Chunk 5: dispatched 2026-10-20. Brief reads the wave-gate delta's
  smoke run as fit, render, deploy, exec and teardown in wave 2;
  `gmctl validate` and `check` arrive with chunk 7 (wave 3), which adds
  them to `smoke.sh`. The delta's wording goes to `spec-writer` at the
  wave 2 gate.
- Chunk 5: merged 2026-10-20 (6231044).
- Chunk 6: dispatched 2026-10-20.
- Chunk 6: merged 2026-10-20 (b2d0e1d). The document is filled by the GM
  per the skill (no script, out of scope), from `scenario.yaml`,
  `gm/answer-key.yaml` and `brief.md` only; a stale README is caught by
  the skill's reading checklist only.

### Wave gate — 2026-10-20

Run by the driver on `v0.1-w2` at 902c048, on the build host (Debian 13,
Docker Engine 29.8, single-node swarm), machine otherwise idle.

- Unit suite: 102 tests OK (4.6 s).
- `sh -n` on every shell script (8 `*.sh` plus `#!/bin/sh` files): OK.
- Image builds: postgres `sha256:a55e764b…`, bastion `sha256:314de9c7…`,
  unchanged from wave 1.
- `tools/tests/smoke.sh`: all checks passed (game `fixture-audit-ts8hzq`):
  fit, render, deploy healthy, exec, logs, teardown, nothing labelled
  left, objects not belonging to the game unchanged. Driver's check after:
  no stack, 0 volumes, configs or secrets labelled `dbagm.game`.
- No bundle or performance figures apply. No intent or data register: no
  sync.
- Sent to `spec-writer`: the wave-gate delta's smoke-run wording
  (`validate` and `check` belong to chunk 7, wave 3).

Open after wave 2: G4 (the lead, before chunk 8 merges), G5 (the owner,
release close). Wave 3 captures due at its start: inject script order,
`load-data` details, gmctl argument signatures (W2-C already fixes
deploy, exec, logs, status and teardown).
- `spec-writer` applied the smoke-run wording correction: plan v3
  (fa402b3).
- Report to the owner 2026-10-20; the owner said to merge.

## Wave 3 — started 2026-10-20

Chunks: 7, 8, 9 (order 7 → 8 → 9, κ = 1). Branch `v0.1-w3`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.1-w3`, cut from `main` at d3547c3
(wave 2 merged). Gates: G3 done; G4 open (the lead, before chunk 8
merges); G5 open (the owner, release close). Preflight: none (no
registers).

### Capture W3-A — setup steps, evaluation and gmctl signatures (chunk 7; read by 8, 9)

Recorded before any code. Python module boundaries are chunk 7's choice;
the behaviour, names and command lines below are fixed.

**Fault parameters** (extends W1-D). Each parameter the fault declares
reaches its `inject/*.sh` and `checks/fixed.sh` as `FAULT_<NAME>`: the
parameter name upper-cased, `-` replaced by `_`; a name that is then not
`[A-Z][A-Z0-9_]*` is refused when the scenario loads. Value: the
instance's `parameters` entry, else the fault's `default`. A scalar is
passed as text (booleans as `true`/`false`); a list or map is refused. No
value and `default: null`: the variable is not set, unless the parameter
is `required`, which `inject` and `check` refuse before running anything.
Nothing else is added to a script's environment.

**`load-data`.** Allowed at stage `deployed`; at `data-loaded` or any
later deployed stage it changes nothing, prints that the data is already
loaded and exits 0 (idempotency is the stage, not the SQL). For every
node with a `data` entry, in `nodes` order, `data/<node>.sql` (the
entry's `file`) is streamed into `psql -X -q -v ON_ERROR_STOP=1 -d
postgres`, run as OS user `postgres` in the node's container (local peer
authentication); the file creates its own databases and roles. To stream
SQL rather than a shell script, `exec_node` gains an optional `argv`
(default `["sh", "-s"]`); `gmctl exec` keeps `sh -s`. A scenario with no
data entry loads nothing and still records `data-loaded`. The whole load
is one `state.setup_step` (any failure or Ctrl-C: teardown, `failed`).

**`inject`.** Allowed at `data-loaded` and at `injected` (a second run
replays the scripts, which are idempotent, and the stage stays
`injected`). Fault instances run in `fault_instances` order; an instance
whose fault has `injection.kind: seed-file` runs nothing; for a `state`
fault, each entry of `injection.scripts`, in the listed order, is read
from the fault's folder and streamed into `sh -s` on the instance's node,
as `injection.run_as` (default `root`), with its `FAULT_*` variables. The
first non-zero exit stops the run. The whole run is one `setup_step`;
success records `injected`. Each script's output is printed with the
instance id and script name.

**`validate`** (the official run). Allowed at every deployed stage;
changes no stage. Every node in `nodes` order runs its brick's public
validator, read from a new `brick.yaml` key `extra.validator: {path,
run_as}`: `postgres` — `{path: /opt/gm/validator/validate.sh, run_as:
postgres}` with `HOME=/var/lib/postgresql` set, as `gm-validate` does;
`bastion` — `{path: /opt/gm/validator/validate.sh, run_as: player}`.
Started through `exec_node` as `exec <path>` on `sh -s`. The validator's
lines are printed under a `<node>:` heading. Exit 0 when every node is
green, 1 when any is red and none errored, 2 when any errored or could not
be started.

**`check`.** Allowed at `injected` and every later deployed stage;
changes no stage. Every fault instance in `fault_instances` order runs its
fault's `sealed_check.script` on its node as `sealed_check.run_as`
(default `root`) with its `FAULT_*` variables, and prints one line:
`<instance> <fault-id>: fixed|present|error — <first output line>`
(error also for any exit other than 0 or 1, or a check that cannot
start). Exit 0 when every instance is fixed, 1 when any is present and
none errored, 2 when any errored.

**GM-recorded stages.** The stages no script reaches are recorded through
`status`: `gmctl status <scenario-dir> --playground <name> --set
handed-over|final-answer|feedback-given`. `handed-over` is allowed from
`injected`, `final-answer` from `handed-over`, `feedback-given` from
`final-answer`; setting the stage the game is already at is a no-op;
anything else is refused (exit 1, state unchanged). It then prints the
status as `status` does.

**Command lines** (all subcommands; each takes `<scenario-dir>
--playground <name>`, prints a readable result, exits 1 on a refusal
unless stated):

- `fit [--endpoint <url>] [--cpu N --memory SIZE --disk SIZE]` (W2-A);
- `render` (W2-A);
- `deploy [--init-swarm] [--timeout SECONDS]` (W2-C);
- `load-data [--timeout SECONDS]` (no timeout by default);
- `inject [--timeout SECONDS]` (per script; no timeout by default);
- `validate` (exit 0/1/2 as above);
- `check` (exit 0/1/2 as above);
- `exec --node N --user U [--env K=V]...` (W2-C; exit = script's, 125
  when it cannot start);
- `logs --node N [--tail N] [--follow]` (W2-C);
- `status [--set <stage>]`;
- `teardown` (W2-C).

**Smoke run.** Chunk 7 fills `smoke.sh`'s marked section: `load-data`
with fixture data, `inject` twice, `check` (1), the fix through `exec`,
`check` (0), and `validate` green then red after an out-of-envelope
change.

### Plan corrections sent to `spec-writer` (before chunk 7 starts)

Capture W3-A widens chunk 7 beyond its plan text: its **Files** also need
`tools/gm/__init__.py` (CLI wiring), `tools/gm/execnode.py` (`argv`),
`tools/gm/localimpl.py` or `state.py` (`status --set`) and
`bricks/{postgres,bastion}/brick.yaml` (`extra.validator`, no image
change), and its **Scope** the `status --set` stages. Chunk 9's scope
uses `status --set` for hand-over, final answer and feedback.
- `spec-writer` applied them: plan v4 (470c953), spec D49 (`status
  --set` records the GM-only stages; an interpretation the owner may
  overturn). Chunk 7 split into 7a (data load, injection, GM-recorded
  stages) and 7b (evaluation); also adds `model.py` (parameter-name
  refusal) and corrects the fixture path to
  `tools/tests/fixtures/fixture-audit/` (a state test fault, its data,
  the README regenerated).

### Dispatch

- Chunk 7: dispatched 2026-10-20, halves in order (7a then 7b), one owner.
