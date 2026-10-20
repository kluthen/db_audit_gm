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

### Dispatch

- Chunk 1: dispatched 2026-10-20.
