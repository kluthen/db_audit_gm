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
