# db_audit_gm v0.3 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

## Wave 1 — started 2026-10-23

Chunks 1, 2, 3, 4, 5 (κ = 3). Branch `v0.3-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.3-w1`, cut from `main` at 4459c50.

### Gates checked at the start

- G2 (network at build time), hand check 2026-10-23: Debian's trixie
  `Release`, the PostgreSQL apt repository, GitHub's releases and the pinned
  Grafana 13.2.4 tarball answer 200. Cleared for wave 1.
- G3 (Docker host in swarm mode), hand check 2026-10-23: armenelos, Docker
  Engine 29.9.1, swarm active, one node (leader). Cleared for wave 1.
- Host resources on 2026-10-23: about 3G of memory available (5G the day
  before), 10G free on `/`. Docker checks stay serialized under the host lock.

### Owner confirmations, 2026-10-23 (sent to `spec-writer`)

Asked at the wave's start, as spec-writer requested after the plan's merge:

1. In a static scenario (no scheduler node), the fault definitions' own aging
   minima are not counted (bookshop's `pg-join-index-missing` does not hold
   up the hand-over), as in v0.2. **Confirmed.**
2. The G6 test-harness override of the aging minimum also caps each
   instance's own aging minimum, so the two-hour rehearsal can reach its
   hand-over. **Confirmed.**
3. Static games keep the hand-over check and the snapshot, so Prometheus and
   Grafana stop briefly at hand-over on fernway. **Confirmed** (the
   alternative, skipping both in static games, declined).

### Capture W1 — v0.3 template keys and contracts (chunk 1; read by 2, 3, 4, 5 and later)

Recorded 2026-10-23, before any code; drafted for the wave driver from
the plan's chunk 1 capture line, master spec 5 to 8 and 12, access model
5, 7, 8 and 11, D140 to D162, v0.2's captures W1 to W4-D and the code on
`v0.3-w1` (`tools/gm/{model,render,localimpl,execnode,checks}.py`, the
format skill's templates, the five bricks' entrypoints, run scripts and
wrappers). Chunks 2 to 5 build on it before chunk 1 merges. Where the
spec fixes a point it is cited, not restated; **(choice)** marks a point
the sources left open, settled here with its reason. Each item names the
chunk that writes it and the chunks that read it. A chunk's own
internals stay out; it records them in its outcome capture (W1-x for
chunk 4, W1-y for chunk 3).

v0.2's W1 conventions still hold: snake_case keys, quoted octal modes,
sizes and CPU as in `resources`, `# optional: <when>` keeping a key
uncommented so its shape is checked when present, `<placeholder>` keys
as free map keys. New keys marked *optional* let the definitions that
lack them load; keys marked *required* are added by chunk 1 to every
definition, scenario-local bricks and faults of the fixtures included.

**0. Conventions used below** (read by every chunk)

- **Scheduler node** (choice): a node whose brick id is `scheduler`, at
  any version. "A scenario with scheduler nodes" (spec D157, D158) means
  one with at least one such node. Reason: what follows a scheduler node
  (the scheduler's files, `aging:`, the shift, `start-load`) belongs to
  the scheduler program, which only that brick runs; the roles `producer`
  and `consumer` are not a test, since another brick may later fill them.
- **Durations** (choice): a string `<integer><unit>`, one unit of `s`,
  `m`, `h`, `d` (`16h`, `30m`, `2d`, `0m`). Used by `aging.minimum`, a
  fault's `aging.minimum`, an instance's `aging_minimum`, a behavioural
  check's `window`, a transaction's `hold`. Comparisons are in seconds.
- **Moments**: `T0`, or `handover-<N>h` with `<N>` a whole number of
  hours, at least 1 (master spec 6.1, 7.1). Used by `plant_at` and a
  timeline change's `at`.
- **UTC instants** in rendered files: `YYYY-MM-DDTHH:MM:SSZ`.
- In-container paths are absolute, contain no whitespace and no trailing
  `/`; chunk 2 refuses whitespace in `writable_paths` and
  `write_overrides` (the environment of item 5 is space-separated).

**1. Scenario keys** (`scenario.yaml`; chunk 1 writes the template and
migrates, chunk 2 checks; read by 7, 8, 10, 12, 15). Shapes: master spec
6.7, normative; rules: 6.1, 8 (opening), D157, D158, D160.

```yaml
aging:                       # optional: with a scheduler node only (refused otherwise)
  minimum: 16h               # a duration, at least 8h
  handover_at: "14:00"       # quoted "HH:00", 24-hour, scenario time
difficulty:                  # required
  score: 10                  # integer, equal to the number of fault_instances
  level: normal              # optional: easy | normal | hard
nodes:
  - name: producer
    write_policy: report-only
    write_overrides:         # optional: report-only node only; non-empty; each an entry of the
      - /srv/scheduler/jobs.yaml   # brick's writable_paths, exactly as written there
fault_instances:
  - id: f7
    plant_at: handover-6h    # optional: T0 (the default) | handover-<N>h; other than T0 only
                             # for an injection.kind state fault, with scheduler nodes only
    aging_minimum: 4h        # optional: with scheduler nodes only; at least the definition's
```

- `handover_at` minutes are always `00` (choice): the shift is a whole
  number of hours and `render --handover` takes a date and an hour (8.3).
- The instance's own minimum is its `aging_minimum` when set, else its
  definition's `aging.minimum`. With scheduler nodes chunk 2 checks, per
  instance, own minimum ≤ `aging.minimum` (T0) or ≤ N hours
  (`handover-<N>h`, N ≤ `aging.minimum`); these are 6.1's coverage and
  N rules, the planting offset being `aging.minimum` − N. Without
  scheduler nodes the definitions' minima are not checked (D160).
- `{{customer_timezone}}`: the literal placeholder, looked for in the
  bastion node's seed files (the starter pack, story included); refused
  there in a scenario with no scheduler node; render fills it (chunk 7).
- Roles: a node's `role` is one of its brick's roles, which are now from
  6.4's closed list (item 3).

**2. Fault keys** (`fault.yaml`; chunk 1 writes the template and
migrates the eleven faults, chunk 2 checks; read by 8, 9, 14). Spec 6.3,
6.7, D145.

```yaml
aging:                       # required
  technique: real-time       # the only value in v0.3
  minimum: 2h                # a duration; 0m when the evidence shows at once
evidence:
  - where: node              # node (the instance's target node) | bastion | report:<tool>
    source: /etc/postgresql/pg_hba.conf      # required: v0.2's free-text where, moved
    how: <command run as player>
    shows: <what reveals it>
sealed_check:
  behavioural: true          # optional (choice): the check judges behaviour over a window
```

- `report:<tool>`: `<tool>` is in the target node's brick's
  `report_tools` (item 3), checked at scenario load against the pinned
  brick (choice: the fault folder alone names no single brick version).
- An evidence entry that reads a web interface or a node other than the
  target (in `grafana-alert-for-too-long`,
  `pg-stat-statements-not-preloaded` and the three `prometheus-*`
  faults) has no v0.3 `where`: chunk 1 drops it, or rewrites it as the
  same fact read at `node` or `bastion` where the fault would otherwise
  keep no evidence of that fact; the `ui:<name>` and `node:<name>`
  readings stay in the scenarios' answer keys only.
- `behavioural` (choice): the loader needs to know which checks are
  behavioural to require their window (item 4); the script is the
  fault's, so the flag is too. No existing fault sets it.
- A fault "about retention" (spec 6.1's exception to the retention rule)
  is one with `family: retention` (choice: the existing key, no new one).
  None exists yet.

**3. Brick keys** (`brick.yaml`; chunk 1 writes the template and the five
bricks, chunk 2 checks; read by 3, 4, 5, 6, 7, 10, 11). Spec 6.4, 6.7,
7.1 to 7.5, D142, D143, D147.

```yaml
# keys from several bricks, for illustration
roles: [monitoring]          # each one of: bastion producer queue database pooler
                             #   transformer consumer monitoring backup
footprint:
  limits:       {cpu: 1, memory: 1G}
  reservations: {cpu: 0.5, memory: 512M, disk: 2.25G}   # at rest, as before
  disk_growth_per_hour: 40M  # required: a size, the volumes' growth per hour of aging and game;
                             # 0 when nothing grows
writable_paths:              # required, may be []: paths player may change on a fixable node,
  - /etc/prometheus          # and the only paths write_overrides may name; a file or a directory
seed:
  dir: /opt/gm/seed/
  files: [prometheus.yml]    # an entry ending in / is a directory (below)
  paths:                     # required, may be {}: seed file -> its live in-container path
    prometheus.yml: /etc/prometheus/prometheus.yml
  modes:                     # optional: seed file -> config mode when not "0444" (owner 0:0)
    schedule.yaml: "0400"    # the scheduler's
secrets:
  - name: pgbouncer_lookup_password
    only_with_role: pooler   # optional: generated and mounted only when a node of the
                             # topology has this role
report_tools: [pgbadger]     # optional: report generators players run on this node (report:<tool>)
snapshot:                    # optional: volume name -> pg_basebackup | copy | stop; when present,
  pgdata: pg_basebackup      # names every volume but the one at /run, once; absent: every
  pgconf: copy               # volume but /run by stop (6.4)
```

- **Roles** (contradiction resolved here): `prometheus` (`metrics-store`),
  `postgres-exporter` (`metrics-exporter`) and `grafana` (`dashboards`)
  carry roles outside 6.4's list. Chunk 1 gives the three `monitoring`
  (formats.md's roles table already names them so), and renames the
  nodes' `role` in `fernway-clinics-monitoring` and `fixture-monitoring`;
  `fixture-mounted`'s local `application` brick role becomes `consumer`.
- **`writable_paths`** keeps its v0.1 meaning and gains 6.4's. A path is
  *fixable* on a node when the node's policy is `fixable`, or it equals a
  `write_overrides` entry, or it lies under an overridden directory.
  `/home/player` stays writable under every policy; naming it in an
  override is pointless and not refused.
- **`seed.paths`** (choice): the loader's per-file check of a *fix*
  resolution (6.1, D143) needs the live path of each seed file a
  `seed-file` fault changes; `brick.yaml` had only names. A fault's *fix*
  is possible when every `seed_changes[].file` lands on a fixable path; a
  `state` or `parameter` fault keeps the node's policy.
- **`seed.modes`** (choice): seed configs are mounted 0:0 `"0444"`
  (`localimpl.SEED_CONFIG_MODE`), which would let `player` read
  `/opt/gm/seed/schedule.yaml`; the scheduler declares it `"0400"`.
  Chunk 7 mounts each seed config with its declared mode.
- **Directory seed entry** (choice): `builders/` (7.1) is a folder of
  files with names the scenario chooses. A `seed.files` entry ending in
  `/` is optional in a scenario's `seed_files`; when given it maps to a
  folder of the scenario (`builders/: nodes/producer/builders/`) holding
  at least one regular file, names `[A-Za-z0-9_][A-Za-z0-9_.-]*`, no
  subfolder. Each file becomes one seed config at
  `<seed.dir><entry><file>` (`/opt/gm/seed/builders/revenue.py`), its
  Swarm name through `config_file_part` (chunk 7); `seed.paths` maps the
  entry to a directory (`builders/: /srv/scheduler/builders`).
- **`only_with_role`** (choice): the lookup role exists only "when the
  scenario has a pooler node" (7.3) while `postgres` declares its secrets
  statically; the condition lets render (chunk 7) leave the secret out
  and the entrypoint (chunk 4) create the role only when its file is
  mounted. v0.2's "declared alike" rule (`kind`, `handed_over`, `pair`,
  `half`) is unchanged; a secret is generated when any declaration's
  condition holds or a declaration has none.
- **Snapshot**: at most one `pg_basebackup` volume per brick, and a brick
  declaring one ships `gm-snapshot-db` (item 6); `/run`'s volume is never
  named (chunk 2).
- **Values** (chunk 1 writes them; chunks 4 and 5 rely on them unchanged):

  | Brick | `snapshot:` | `writable_paths` | `seed.paths` | other |
  |---|---|---|---|---|
  | `postgres` 0.3.0 | `pgdata: pg_basebackup`, `pgconf`, `home`, `gmstate`, `pglog`: `copy` | unchanged | `postgresql.conf`, `pg_hba.conf` under `/etc/postgresql/` | `report_tools: [pgbadger]` |
  | `bastion` 0.3.0 | `home`, `hostkeys`: `copy` | unchanged | `README.md`, `story.md`, `issues.md` under `/home/player/` | |
  | `prometheus` 0.2.0 | `promdata: stop`; `promconf`, `home`, `gmstate`: `copy` | unchanged | `prometheus.yml` → `/etc/prometheus/prometheus.yml` | |
  | `postgres-exporter` 0.2.0 | `expconf`, `home`, `gmstate`: `copy` | unchanged | `exporter.conf` → `/etc/postgres-exporter/exporter.conf` | |
  | `grafana` 0.2.0 | `grafdata: stop`; `grafconf`, `home`, `gmstate`: `copy` | `/etc/grafana/provisioning` and its `alerting`, `dashboards`, `datasources` subdirectories, `/home/player` | the five files at their W3 live paths | |
  | `scheduler` 0.1.0 (chunk 3) | every volume but `run`: `copy` | `/srv/scheduler/queries.yaml`, `/srv/scheduler/builders`, `/srv/scheduler/jobs.yaml`, `/home/player` | `queries.yaml`, `builders/`, `jobs.yaml` under `/srv/scheduler/`; `schedule.yaml` → `/opt/gm/seed/schedule.yaml` | `seed.modes: {schedule.yaml: "0400"}` |
  | `pgbouncer` 0.1.0 (chunk 6) | every volume but `run`: `copy` | chunk 6's | chunk 6's | |

  `disk_growth_per_hour`: chunk 1 writes a provisional estimate, said so
  in a comment, for each of its five bricks; chunk 15b's measurement
  replaces them. `report-only` joins the three monitoring bricks'
  `write_policies` in chunk 5, the chunk that makes it true, not chunk 1.

**4. Answer-key keys** (`gm/answer-key.yaml`; chunk 1 writes the
template, chunk 2 checks; read by 9, 14, 15). Spec 6.2, 11 (rule 2),
D124.

```yaml
instances:
  - instance: f3
    sealed_check:
      script: faults/<id>/checks/fixed.sh
      at_handover: 1
      window: 30m            # optional: required exactly when the fault's
      threshold: 0           #   sealed_check.behavioural is true; a number
```

Chunk 9 passes them to the check script as `CHECK_WINDOW_SECONDS` (an
integer) and `CHECK_THRESHOLD` (as written) beside its `FAULT_*`
variables (choice: `FAULT_` names the fault's parameters); see "Needs".

**5. The write-policy contract** (renderer: chunk 7; bricks: chunks 3, 5,
6; read by 11, 12, 14, 15). Spec 6.1, 7.1 to 7.4, access model 5, 7;
D108, D143.

- **Environment** (choice), set by render on every node, after `TZ=UTC`:
  `GM_WRITE_POLICY=<fixable|report-only|no-access>` (the node's
  `write_policy`) and `GM_WRITE_OVERRIDES=<paths>` (the node's
  `write_overrides`, unique, sorted, space-separated, `""` when none).
  Chunk 2 refuses a brick parameter named `write_policy` or
  `write_overrides`. Both unset (a v0.2-style stack, a plain `docker
  run`) mean `fixable` with no override.
- **Who honours them**: the bricks offering `report-only` (`scheduler`,
  `pgbouncer`, `prometheus`, `postgres-exporter`, `grafana`).
  `postgres` (fixable only, 7.3) and `bastion` (image unchanged, 7.5)
  ignore them. `no-access` is treated as `report-only` for files
  (choice: the loader accepts it on every brick and nothing builds its
  login restriction).
- **Entrypoint**, at every start, before `/init`: refuses an unknown
  policy, or an override that is not one of its brick's `writable_paths`
  (`gm-entrypoint: fatal: …`, the container exits); writes
  `/run/gm/write-policy` (root:root `0444`, in the root-only `/run/gm`),
  read by the wrappers since `sudo` resets the environment:

  ```
  policy=report-only
  overrides=/etc/grafana/provisioning/alerting
  ```

  then applies the owner and modes below to every seeded file and every
  directory holding one (contents untouched), seeding or not.
- **Owner and modes** (the rule the wrappers restore): every seeded file
  is owned `<service account>:<configuration group>` (`postgres:pgconf`,
  `prometheus:promconf`, `exporter:expconf`, `grafana:grafconf`,
  `scheduler:schedconf`, chunk 6's pair), mode `0664` when its path is
  fixable, `0644` otherwise; a directory holding seeded files (or a
  directory in `writable_paths`) is `2775` when fixable, `2755`
  otherwise; `/home/player` keeps its v0.2 owner and mode under every
  policy, and a seed file read in place (`schedule.yaml`) is never
  touched. An overridden file inside a directory that is not fixable
  is edited in place (an editor, `cat >`); `sed -i`, which needs to
  create a file beside it, fails there, and the brick's `docs/player.md`
  says so (choice: a writable directory would let `player` replace or
  remove its other files).
- **Reload and restart wrappers** (`gm-reload-db`, `gm-restart-db`,
  `gm-reload-prometheus`, `gm-restart-exporter`, `gm-reload-grafana`,
  `gm-reload-scheduler`, `gm-reload-pgbouncer`): first restore every
  seeded file's owner and mode as above, without touching its content (a
  file `sed -i` left owned by `player` gets its owner back, RG-2); then
  refuse, when none of the files the wrapper applies is fixable, with one
  line on standard output and exit 1, nothing signalled:
  `<wrapper>: this node is report-only: its files cannot be changed, so
  nothing was reloaded.` Otherwise they reload as in v0.2. `gm-validate`
  is never refused. Files players added on a fixable path are the
  brick's to treat, stated in its `docs/gm.md`.
- `docs/gm.md` keeps the nine headings (`test_brick_docs` unchanged):
  write policies and overrides under Access; the snapshot methods and the
  brief stop as a level-3 "Snapshot" under Footprint, with the growth per
  hour (choice, so parallel chunks write matching documents).

**6. The snapshot contract inside a node** (bricks: chunks 1, 3, 4, 5, 6;
`gmctl snapshot` and `restart`: chunk 11; read by 10). Spec 6.4, 7.1 to
7.5, 12, D142, D147, D162; formats.md: a stop is s6's, never a Swarm
scale to zero.

- Everything runs through the exec verb's path (`execnode.exec_node`,
  as `gmctl exec --node <n> --user root` does): a POSIX script on `sh
  -s`, as `root`, one exec per step; nothing restarts a container or
  touches a Swarm service. Each step that produces a copy writes only the tar
  stream on standard output, diagnostics on standard error.
- **`copy`**, the node running: `tar --create --file=- --numeric-owner
  --directory=<volume path> .`, the path from `brick.yaml` `volumes`.
  Exit 0, or 1 when a file changed while read (an append-only log),
  is a copy; any other status is a failure.
- **`stop`**: the services stopped are the brick's `processes` other
  than `sshd`, in list order, each with `/command/s6-svc -wD -T 60000
  -d /run/service/<service>`; the brick's `stop` volumes are then copied
  as above (exit 0 only); the services are started again in reverse
  order with `/command/s6-svc -wu -T 60000 -u /run/service/<service>`,
  always, a failed copy included. A stop brick's `copy` volumes are taken
  before the stop, to keep it short. Health checks stay green during a
  stop (they need `sshd` and a service that answered once), and the
  node-health script shows the service down.
- **`pg_basebackup`**: `/usr/local/sbin/gm-snapshot-db`, root:root
  `0700`, in `protected_files`, not a `sudo` wrapper, no arguments.
  Standard output: a tar stream of the data directory, rooted at it,
  holding the WAL it needs (`pg_basebackup -F tar -X fetch -D -`, as
  `postgres` over the local socket), restorable by extracting it into an
  empty data volume as a `copy` is; exit 0 on success; the replication
  slot it creates is dropped on every exit. Its exact form (the slot, or
  a snapshot volume if the build finds `-X fetch` unworkable) is chunk
  4b's, recorded in W1-x.
- Every brick keeps `DAC_OVERRIDE` among its capabilities (all five do),
  so root's `tar` reads volumes their service owns `0700`.
- `/run` is never copied (D55). Where the copies live, how they are
  restored and labelled: chunks 10 and 11 (W3).

**7. The scheduler's runtime interface** (writes: chunk 3 the brick and
program, chunk 2b the templates and checks of the scenario forms, chunk
7 the rendered forms; read by 8, 11, 12, 14). Spec 7.1 (normative
shapes), 8.3, 8.7, access model 5 ("Scheduler nodes"), 7, 8.

- **Brick**: id `scheduler`, version 0.1.0, roles `[producer,
  consumer]`, `write_policies: [fixable, report-only]`; s6 services
  `scheduler` and `sshd` (`processes: [scheduler, sshd]`); service
  account `scheduler`, the players' configuration group `schedconf`
  (numeric ids chunk 3's, fixed in the Dockerfile); `curl` in the image
  (checks read the metrics inside the node). Seed and writable paths:
  item 3's table. Volume names are chunk 3's; the seed marker and the
  load marker share the root-owned `gmstate` volume at
  `/var/lib/gm-state`.
- **Scenario forms** (`nodes/<node>/`, scenario time). `queries.yaml`
  as 7.1 shows: a key (`[a-z0-9][a-z0-9._-]*`) maps to a query (`sql`,
  optional `params`, optional `transaction`), a pool (a list of queries,
  each with an optional integer `weight`, default 1), a sequence
  (`steps:` a list of `{sql, params}`, optional `transaction`) or a
  builder (`builder: builders/<file>:<function>`, a file of the node's
  `builders/` entry; optional `options` map). Generators (choice for the
  forms 7.1 leaves open): `{int: [lo, hi]}`, `{decimal: [lo, hi,
  places]}`, `{choice: [v, ...]}`, `{sequence: [start, step]}`,
  `{now: utc}`. `transaction: {isolation: read committed | repeatable
  read | serializable, hold: <duration>}`, `hold` optional.
  `schedule.yaml`: 7.1's keys; a connection is `{driver: sql/postgresql,
  target: <node>:<port>/<database>, role, pool}` with `pool: {size: N}`
  or `pool: {per-call: true}` (choice: one key `pool`, 7.1's alternative
  inside it); a role is `[a-z_][a-z0-9_]{0,40}`, never `postgres`, `dba`,
  `monitoring`, `gm_check`, `pgbouncer_lookup` or `pg_*`; a stream
  `{key, connection, rate, arrivals: poisson | even, shape, concurrency}`,
  `rate` `<number>/s|min|h`, `shape` optional (multiplier 1),
  `concurrency` optional (1); a timeline change's `stream` names a
  stream by its initial key, unique among the node's streams (choice),
  `set` takes `key`, `rate` or `connection`. A shape is
  `hours: {"HH" or "HH-HH": multiplier}` covering 00 to 23 once (ranges
  never wrap), or per weekday (choice) `days: {mon | mon-fri |
  …: {hours: …}}` covering mon to sun once, Monday first.
  `jobs.yaml`: `jobs: [{name, key, connection, at}]`, `at` a 5-field
  cron in scenario time restricted (choice, so render can shift it
  exactly) to: minute any numeric cron form; hour `*`, a number or a
  list of numbers; day of month and month `*`; day of week `*`, or a
  number or list 0–6 (0 Sunday) only with a single-number hour. No
  `timezone:` in the scenario; the wrong-time-zone fault's seed change
  writes `timezone_offset: <N>` on its job (choice: the customer's zone
  is not known at authoring, 8.3), a non-zero whole number of hours,
  allowed only when a fault instance on that node changes `jobs.yaml`.
- **Rendered forms** (the files the program reads, UTC). `queries.yaml`
  and `builders/`: copied unchanged. `jobs.yaml`: every job's hour (and
  day of week, when the hour wraps) shifted by −shift into UTC, no
  `timezone:`; a job with `timezone_offset: N` keeps its `at` as
  designed and gets the fixed zone UTC+M, M = shift + N wrapped modulo
  24 into −12..+14, written `Etc/GMT-M` for M > 0, `Etc/GMT+|M|` for
  M < 0, `Etc/GMT` for 0. `schedule.yaml`:

  ```yaml
  seed: 4815162342           # the game's seed, an integer 0 <= seed < 2**63, the same on
                             # every scheduler node (the program mixes in its hostname)
  intensity: 1.0
  connections: {...}         # as designed; passwords are never in the file
  streams: [...]             # as designed
  shapes:
    business-hours:
      utc:                   # weekday (UTC) -> 24 multipliers, hour 00 first
        mon: [0.1, 0.1, ...]
        # tue ... sun
  timeline:
    - at: "2026-10-24T08:00:00Z"   # the moment as a UTC instant from the planned hand-over
      stream: orders.insert
      set: {key: orders.insert-v2}
  ```

  The program reads only rendered forms; it accepts any numeric 5-field
  cron and any zone `tzdata` names in `jobs.yaml`, since players edit it.
- **The schedule's delivery**: the run script reads
  `/opt/gm/seed/schedule.yaml` (0:0 `"0400"`) and the connection
  passwords as root at every start of the service and passes them on
  standard input before `s6-setuidgid scheduler` (7.1); the stdin framing
  is chunk 3's. Provisional (see "Needs"): the file is read in place, not
  copied onto a volume.
- **Connection secrets** (choice): for each role a scheduler node's
  `schedule.yaml` names, a password secret `role_<role>_password` (kind
  `password`, not handed over), generated by render (chunk 7) from the
  schedules, not declared in `brick.yaml`; one secret per role, mounted
  in each scheduler node naming it at
  `/opt/gm/secrets/role_<role>_password`, 0:0 `"0400"`; set in the
  database by `load-data` (chunk 7b); kept by a restart (12). PgBouncer
  never holds them (`auth_query`, item 8).
- **Load-started marker**: `/var/lib/gm-state/load-started`, one line,
  T0 as a UTC instant, root:scheduler `0440`. `gmctl start-load` (chunk
  8a), as root on each scheduler node: writes it atomically (a
  temporary file in the same directory, then `mv`), runs `/command/s6-svc
  -r /run/service/scheduler`, then polls the status file until it reads
  `running` (60 s). T0 is the moment `start-load` began, the same on
  every node.
- **Status file** (choice: start-load needs to see the program running):
  `/run/scheduler/status`, one line, `idle <UTC instant>` or
  `running <UTC instant>` (since when), rewritten at each change,
  readable by root.
- **Log**: `/var/log/scheduler/scheduler.log`, one append-only file,
  never rotated or pruned in a game, `scheduler:schedconf` `0640` in a
  `2750` directory (players read it, as PostgreSQL's logs). Every line
  begins `<UTC instant> <event>`, then `name=value` fields, a value with
  spaces quoted (`"…"`, `\"` and `\\` escaped) and last. Fixed here,
  read by chunk 8b:

  ```
  2026-10-24T09:15:00Z summary minute=2026-10-24T09:14Z keys=2 calls=41 errors=1
  2026-10-24T09:15:00Z key minute=2026-10-24T09:14Z key=orders.insert calls=40 errors=1 p50_ms=3.1 p95_ms=7.9 p99_ms=12.0
  2026-10-24T09:15:00Z key minute=2026-10-24T09:14Z key=orders.report calls=1 errors=0 p50_ms=81 p95_ms=81 p99_ms=81
  ```

  Within ten seconds after each UTC minute boundary while running, one
  `summary` line for the minute just ended, even with no call, then
  `keys` `key` lines: one per stream key current in that minute (zeros
  included) and per job key that ran in it; latencies `-` when
  `calls=0`. A minute with no `summary` line from a scheduler is an
  outage minute (8.7). The `state`, `run`, `error` and other events are
  chunk 3's (W1-y), errors carrying `key`, `sqlstate`, `message` (7.1).
- **Metrics**: HTTP port `9120`, `GET /metrics`, Prometheus text format,
  names prefixed `scheduler_`, labelled `key`; `brick.yaml` provides
  `{name: metrics, protocol: http, port: 9120}`. Names: W1-y.
- **`gm-reload-scheduler`**: `/usr/local/sbin/gm-reload-scheduler`, a
  `sudo` wrapper, no arguments; item 5's restore and refusal; checks
  `queries.yaml`, `builders/` and `jobs.yaml` as the service account
  (and, as root, that every key the schedule names still exists, naming
  only the key) and refuses with "NOT reloaded", exit 1, when they fail;
  otherwise `/command/s6-svc -h /run/service/scheduler`. On SIGHUP the
  program reloads `jobs.yaml` and the repository (choice: 7.1 names only
  `jobs.yaml`, but a fixable repository needs its fix to take effect),
  keeping its schedule, connections and counters.

**8. The GM check role, the reserve and the PgBouncer lookup role** (chunk
4a builds and records W1-x; read by 6, 7, 9, 11, 14). Spec 6.5, 7.2,
7.3, 11 (rule 5), 12; access model 5, 7, 8, 11; D138, D144.

- **Reserve**: `-c reserved_connections=2` on the server's command line
  in `s6-rc.d/postgres/run`; chunk 4a may set the measured need instead.
  `superuser_reserved_connections` keeps its default 3, so the envelope's
  `max_connections` minimum of 10 leaves five ordinary slots.
- **Check role** `gm_check`: `LOGIN`, not superuser, no `CREATEDB`,
  `CREATEROLE` or `REPLICATION`; member of `pg_use_reserved_connections`,
  `pg_monitor`, `pg_read_all_data`; `SELECT` on
  `pg_catalog.pg_hba_file_rules`, `EXECUTE` on
  `pg_catalog.pg_hba_file_rules()`. It exists with its secret's password
  whenever the server accepts connections; when it is created is chunk
  4's (a restored cluster carries it, its secret's value being kept).
- **Its secret** `gm_check_password`: kind `password`, not handed over,
  declared by `postgres` only, `/opt/gm/secrets/gm_check_password`, 0:0
  `"0400"` (root only).
- **How a check connects** (choice): as root inside the database node,
  through the helper `/usr/local/lib/gm/check-psql`, root:root `0700`,
  in `protected_files` (choice: the secret is handled in one root-only
  file, not in every check). It runs `psql -X -w -h /run/postgresql -p
  5432 -U gm_check "$@"` with the password in a `0600` `PGPASSFILE`
  under `/run/gm`, removed on exit; its status is psql's. A check reads
  `check-psql -d <db> -Atq -v ON_ERROR_STOP=1 <<'SQL' … SQL`. The seeds'
  `local all all scram-sha-256` line lets `gm_check` in; chunk 2a's seed
  check (7.3) also confirms a `local` line admits `gm_check` by password
  before any `reject` (choice, the same check as the replication line).
  The file is outside chunk 4's Files line; `git add -f` it (the
  `local/` ignore rule matches `rootfs/usr/local/`, W3-B).
- **Lookup role** `pgbouncer_lookup`: `LOGIN`, not superuser, no
  membership, `EXECUTE` on the lookup function only; created when
  `/opt/gm/secrets/pgbouncer_lookup_password` is mounted. The function,
  in database `postgres`: `gm_pgbouncer.lookup(p_usename text) RETURNS
  TABLE (usename name, passwd text)`, `SECURITY DEFINER`, owned by
  `postgres`, `SET search_path = pg_catalog, pg_temp`, returning
  `rolname` and `rolpassword` from `pg_authid` for a login role whose
  password has not expired, superusers included (7.2); `EXECUTE` revoked
  from `PUBLIC`, schema usage granted to the lookup role only. PgBouncer
  (chunk 6): `auth_user = pgbouncer_lookup`, `auth_dbname = postgres`,
  `auth_query = SELECT usename, passwd FROM gm_pgbouncer.lookup($1)`.
- **Its secret** `pgbouncer_lookup_password`: kind `password`, not handed
  over; `postgres` declares it at
  `/opt/gm/secrets/pgbouncer_lookup_password`, 0:0 `"0400"`, with
  `only_with_role: pooler`; `pgbouncer` declares the same name at its own
  path, uid, gid and mode (chunk 6).

**9. Wave 1 coordination** (for the driver and chunks 1 to 5)

- **Overlapping files**: chunk 1 changes the files chunks 4 and 5 also
  change (`bricks/{postgres,prometheus,postgres-exporter,grafana}/`
  `brick.yaml`, `docs/gm.md`, `tests/{run-stack-test.sh,stack.test.yml}`),
  and chunk 2b the format skill's `SKILL.md` and `layouts.md`. Chunk 1
  owns the version and image lines, the header comments, the image tags
  in the stack tests and `docs/gm.md`, the Supported faults tables,
  `roles`, `disk_growth_per_hour`, `writable_paths`, `seed.paths`,
  `report_tools` and `snapshot:`; chunks 4 and 5 own every other line
  their scopes name (secrets, `protected_files`, `write_policies`,
  wrappers, footprint at rest, test bodies). Chunks 4 and 5 take chunk 1
  in (merging `v0.3-w1` into their branch) once it has merged, before
  their own merge; see "For the driver".
- **Images** (choice, from v0.2's tag lesson): a plain v0.3 tag
  (`postgres:0.3.0`, `bastion:0.3.0`, `prometheus:0.2.0`,
  `postgres-exporter:0.2.0`, `grafana:0.2.0`, `scheduler:0.1.0`) is built
  only from a branch holding chunk 1 (the scheduler's from chunk 3's).
  Every stack test is one host-locked command that first builds, from
  its own worktree, every image it uses; nothing relies on what a tag
  held before the lock. Before taking chunk 1 in, chunks 4 and 5 build
  only under `<tag>-c4`, `-c5a`, `-c5b` and run no stack test.
- **Chunk 2's fixtures** with scheduler nodes use a scenario-local
  `bricks/scheduler/` (id `scheduler`, version 0.1.0) carrying item 3's
  and item 7's facts, since chunk 3's brick is not merged.

**Choices made here, not in the spec** (for the driver's review): the
scheduler-node test by brick id; the duration grammar and `"HH:00"`;
`behavioural` on a fault's sealed check; `family: retention`; the three
monitoring bricks' role `monitoring` and fixture-mounted's `consumer`;
`seed.paths`, `seed.modes`, directory seed entries and `only_with_role`;
`report_tools` checked against the target's pinned brick; the per-brick
values of item 3, Grafana's three subdirectories included;
`GM_WRITE_POLICY`, `GM_WRITE_OVERRIDES` and `/run/gm/write-policy`;
`no-access` read as report-only; the owner and modes rule and in-place
edits under a non-fixable directory; the refusal line; the docs/gm.md
placement; the snapshot command lines, the stop's service set and order,
`tar`'s exit 1 accepted for `copy`; `CHECK_WINDOW_SECONDS` and
`CHECK_THRESHOLD`; the generator, pool, shape, cron and stream-identity
forms; `timezone_offset`; the rendered `schedule.yaml` shape and the
shared seed; the `role_<role>_password` secrets; the marker's mode, the
status file, the log path and its `summary` and `key` lines; port 9120;
the repository reloaded on SIGHUP; `gm_check`, `check-psql` and its
`local` line check; `pgbouncer_lookup` and `gm_pgbouncer.lookup`; the
file ownership split and the image rule of item 9.

**Needs the owner or spec-writer**

1. **Where `schedule.yaml` lives** (spec-writer). 7.1 says every
   scheduler file is seed-once on the node's volumes; 7.1 and 12 also say
   a restart takes a new seed, and a seed-once copy restored from the
   hand-over snapshot would keep the old one. W1 provisionally reads it
   in place from its per-game seed config (item 7), which delivers a
   restart's new seed and changes nothing else (the file never changes
   in a game). To confirm, or rule that a restart from the snapshot keeps
   its seed.
2. **The replication line in the scenarios' seeds** (spec-writer, plan
   correction). Chunk 2a's check (7.3) needs a `local replication
   postgres` line; `local all postgres peer` does not match replication
   connections, so `bookshop-new-server`, `fernway-clinics-monitoring`,
   `fixture-audit` and `fixture-monitoring` fail it. W1 gives the addition of
   `local replication postgres peer` to chunk 1 (and to the postgres
   stack test's fixture, chunk 4); the scenarios' `nodes/db/pg_hba.conf`
   are in no chunk's Files line.
3. **Window and threshold reaching a check** (spec-writer, plan
   correction): no chunk passes them; W1 gives it to chunk 9 (item 4).
4. **Overlapping files in wave 1** (spec-writer, plan correction):
   item 9's files are not shared lists, so under chunk mode a merge
   conflict in them stops the chunk; the plan should list them as shared
   for wave 1, or order chunk 1 first.

**For the driver**: merge chunk 1 as early as it is green (1a carries the
bricks' bumps, so 1a's merge ahead of 1b would unblock chunks 4 and 5
soonest); brief chunks 4 and 5 to take `v0.3-w1` in before their first
plain-tag build; brief chunk 2 with item 9's fixture note.
