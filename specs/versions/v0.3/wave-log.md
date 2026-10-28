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
      - /srv/scheduler/jobs  # brick's writable_paths, exactly as written there (amended by spec D170)
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
  entry to a directory (`builders/: /srv/scheduler/repository/builders`,
  amended by spec D170).
- **`only_with_role`** (choice): the lookup role exists only "when the
  scenario has a pooler node" (7.3) while `postgres` declares its secrets
  statically; the condition lets render (chunk 7) leave the secret out
  and the entrypoint (chunk 4) create the role only when its file is
  mounted. v0.2's "declared alike" rule (`kind`, `handed_over`, `pair`,
  `half`) is unchanged; a secret is generated when any declaration's
  condition holds or a declaration has none.
- **Snapshot**: at most one `pg_basebackup` volume per brick, and a brick
  declaring one ships `gm-snapshot-db` (item 6); `/run`'s volume is never
  named (chunk 2). Chunk 2 checks the first and the last; that the helper
  ships is chunk 4's stack test's, since chunk 1 declares `pg_basebackup`
  before chunk 4 builds it (amended by spec D167).
- **Values** (chunk 1 writes them; chunks 4 and 5 rely on them unchanged):

  | Brick | `snapshot:` | `writable_paths` | `seed.paths` | other |
  |---|---|---|---|---|
  | `postgres` 0.3.0 | `pgdata: pg_basebackup`, `pgconf`, `home`, `gmstate`, `pglog`: `copy` | unchanged | `postgresql.conf`, `pg_hba.conf` under `/etc/postgresql/` | `report_tools: [pgbadger]` |
  | `bastion` 0.3.0 | `home`, `hostkeys`: `copy` | unchanged | `README.md`, `story.md`, `issues.md` under `/home/player/` | |
  | `prometheus` 0.2.0 | `promdata: stop`; `promconf`, `home`, `gmstate`: `copy` | unchanged | `prometheus.yml` → `/etc/prometheus/prometheus.yml` | |
  | `postgres-exporter` 0.2.0 | `expconf`, `home`, `gmstate`: `copy` | unchanged | `exporter.conf` → `/etc/postgres-exporter/exporter.conf` | |
  | `grafana` 0.2.0 | `grafdata: stop`; `grafconf`, `home`, `gmstate`: `copy` | `/etc/grafana/provisioning` and its `alerting`, `dashboards`, `datasources` subdirectories, `/home/player` | the five files at their W3 live paths | |
  | `scheduler` 0.1.0 (chunk 3) | every volume but `run`: `copy` | `/srv/scheduler/repository`, `/srv/scheduler/jobs`, `/home/player` (amended by spec D170) | `queries.yaml`, `builders/` under `/srv/scheduler/repository/`, `jobs.yaml` under `/srv/scheduler/jobs/` (amended by spec D170); `schedule.yaml` → `/opt/gm/seed/schedule.yaml` | `seed.modes: {schedule.yaml: "0400"}` |
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
variables (choice: `FAULT_` names the fault's parameters); written into
chunk 9 (amended by spec D165).

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
  remove its other files). No v0.3 brick has such a path: every
  `writable_paths` entry is a directory, the scheduler's included, so
  `sed -i` works on every fixable path (amended by spec D170).
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
  is chunk 3's. The file is read in place, never copied onto a volume, so
  it is not in the snapshot and a restart's re-render brings the new seed
  (amended by spec D163, which settles it).
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
  `local all all scram-sha-256` line lets `gm_check` in; every `postgres`
  seed also names it on its own line, `local all gm_check scram-sha-256`,
  under the DO NOT TAMPER comment beside the replication line, so a
  player tightening the general line keeps the checks working (amended
  by spec D171); chunk 2a's seed
  check (7.3) also confirms a `local` line admits `gm_check` by password
  or `trust` before any `reject` (choice, the same check as the
  replication line; `trust` added, amended by spec D164).
  The file is outside chunk 4's Files line; `git add -f` it (the
  `local/` ignore rule matches `rootfs/usr/local/`, W3-B). Now in chunk
  4's Files line; `.gitignore`'s `!bricks/*/rootfs/usr/local/` keeps it
  tracked, so no `-f` is needed (`git check-ignore` is silent on it,
  2026-10-23) (amended by spec D169).
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
  wrappers, footprint at rest, test bodies). Chunks 2, 4 and 5 are cut
  from `v0.3-w1` once chunk 1 has merged (4 and 5 once 1a has, at least),
  so they hold it from their start; only chunk 3 runs beside chunk 1
  (amended by spec D166).
- **Images** (choice, from v0.2's tag lesson): a plain v0.3 tag
  (`postgres:0.3.0`, `bastion:0.3.0`, `prometheus:0.2.0`,
  `postgres-exporter:0.2.0`, `grafana:0.2.0`, `scheduler:0.1.0`) is built
  only from a branch holding chunk 1 (the scheduler's from chunk 3's).
  Every stack test is one host-locked command that first builds, from
  its own worktree, every image it uses; nothing relies on what a tag
  held before the lock. (The `-c4`, `-c5a`, `-c5b` tags for chunks 4 and
  5 before they take chunk 1 in are moot: they start holding it, amended
  by spec D166.)
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
   its seed. Settled: read in place, master spec 7.1 amended (amended by
   spec D163).
2. **The replication line in the scenarios' seeds** (spec-writer, plan
   correction). Chunk 2a's check (7.3) needs a `local replication
   postgres` line; `local all postgres peer` does not match replication
   connections, so `bookshop-new-server`, `fernway-clinics-monitoring`,
   `fixture-audit` and `fixture-monitoring` fail it. W1 gives the addition of
   `local replication postgres peer` to chunk 1 (and to the postgres
   stack test's fixture, chunk 4); the scenarios' `nodes/db/pg_hba.conf`
   are in no chunk's Files line. Settled: chunk 1b adds it, the two files
   in chunk 1's Files line, under the DO NOT TAMPER comment (amended by
   spec D164).
3. **Window and threshold reaching a check** (spec-writer, plan
   correction): no chunk passes them; W1 gives it to chunk 9 (item 4).
   Settled: written into chunk 9 (amended by spec D165).
4. **Overlapping files in wave 1** (spec-writer, plan correction):
   item 9's files are not shared lists, so under chunk mode a merge
   conflict in them stops the chunk; the plan should list them as shared
   for wave 1, or order chunk 1 first. Settled: chunk 1 first, chunks 2,
   4 and 5 after its merge, no shared list (amended by spec D166).

**For the driver**: merge chunk 1 as early as it is green (1a carries the
bricks' bumps, so 1a's merge ahead of 1b would unblock chunks 4 and 5
soonest); brief chunk 2 with item 9's fixture note. (Briefing chunks 4
and 5 to take `v0.3-w1` in is moot: they are cut after chunk 1's merge,
amended by spec D166.)

### Capture W1-x — chunk 4 outcomes

Recorded by chunk 4 (`v0.3-c4-postgres`), 2026-10-23, from the code as
built and its stack test (`bricks/postgres/tests/run-stack-test.sh`, all
checks passed on armenelos, Docker 29.9.1). Read by chunks 6, 7, 9, 11
and 14. W1 items 6 and 8 hold as written; what follows is what they left
to the build, and the additions.

- **Reserve**: `-c reserved_connections=2` in
  `s6-rc.d/postgres/run`; `superuser_reserved_connections` stays 3.
  `pg_settings.source` reads `command line`, and an `ALTER SYSTEM SET
  reserved_connections = 0` followed by a restart leaves it at 2.
  Measured with `max_connections = 10`: an ordinary role gets five
  sessions and a sixth is refused ("reserved for roles with privileges
  of the pg_use_reserved_connections role"); two `gm_check` sessions get
  in beside them, a third is refused ("reserved for roles with the
  SUPERUSER attribute"); `dba` still connects. Kept at 2: `gmctl` runs
  checks one at a time, and a timer-fired early check may overlap one
  run by hand. The server does not start with `max_connections` ≤ 5;
  `gm-restart-db` now refuses such a value ("max_connections (N) must
  be more than superuser_reserved_connections (3) plus the GM's
  reserved_connections (2); PostgreSQL was NOT restarted.", exit 1).
- **`gm_check`**: as item 8, plus `NOBYPASSRLS`, `INHERIT`, `CONNECTION
  LIMIT -1`, `VALID UNTIL 'infinity'`; the three memberships granted
  `WITH INHERIT TRUE`. Created at the first start and re-applied at
  **every container start** (attributes, memberships, the two grants,
  the password) by `gm-entrypoint` in single-user mode before `/init`,
  so it exists with its secret's password whenever the server accepts
  connections, a restored cluster and a `dba` who altered it included.
  Single-user mode runs with `config_file=/dev/null`, no preload
  library and `log_min_error_statement=panic` (no password in a log). A
  failure is fatal on a fresh cluster, a warning otherwise (the roles
  stay as they were, the node still starts). `gm-restart-db` does not
  re-apply it. Without `gm_check_password` mounted the entrypoint only
  warns and creates no check role (choice: the bastion, prometheus and
  postgres-exporter stack tests deploy this image without it; a game
  always mounts it). Log line: `gm-entrypoint: GM roles up to date:
  gm_check[ pgbouncer_lookup]`.
- **`gm_check_password`**: kind `password`, not handed over,
  `/opt/gm/secrets/gm_check_password`, 0:0 `"0400"`, declared by
  `postgres` only.
- **`check-psql`**: `/usr/local/lib/gm/check-psql`, root:root `0700`,
  in `protected_files`. Usage, as root in the node: `check-psql -d <db>
  -Atq -v ON_ERROR_STOP=1 <<'SQL' … SQL` (any psql arguments). It runs
  `/usr/lib/postgresql/18/bin/psql -X -w -h /run/postgresql -p 5432 -U
  gm_check "$@"`, standard streams passed through, `PGHOST`, `PGPORT`,
  `PGUSER`, `PGPASSWORD`, `PGSERVICE` and the other connection variables
  cleared, the password in `/run/gm/check-psql.XXXXXX` (`0600`), removed
  on exit (also on INT, TERM, HUP). Exit codes: psql's (0 done, 1 psql
  error, 2 connection failed or lost, 3 script error under
  `ON_ERROR_STOP`); 2 with one `check-psql: …` line on standard error
  when it cannot run (not root, secret missing or empty, no password
  file). It needs the seed's `local all gm_check scram-sha-256` line.
  Players see `gm_check` connections in the server log
  (`log_connections`) and in `pg_stat_activity` while they run.
- **`pgbouncer_lookup`**: `LOGIN`, `NOSUPERUSER`, `NOINHERIT`, no
  `CREATEDB`, `CREATEROLE`, `REPLICATION`, `BYPASSRLS`, `VALID UNTIL
  'infinity'`, no membership. Created and re-applied at every container
  start, as `gm_check`, when `/opt/gm/secrets/pgbouncer_lookup_password`
  exists (present but empty is fatal). The function, in database
  `postgres`, exactly:
  `gm_pgbouncer.lookup(p_usename text) RETURNS TABLE (usename name,
  passwd text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path =
  pg_catalog, pg_temp`, body `SELECT a.rolname, a.rolpassword FROM
  pg_catalog.pg_authid a WHERE a.rolname = p_usename AND a.rolcanlogin
  AND (a.rolvaliduntil IS NULL OR a.rolvaliduntil > now())`, owned by
  `postgres`; schema `gm_pgbouncer` owned by `postgres`; every right
  revoked from `PUBLIC` on both; `USAGE` on the schema and `EXECUTE` on
  the function granted to `pgbouncer_lookup` only. Shown: `dba`
  (superuser) returned with its `SCRAM-SHA-256$…` verifier, an ordinary
  role returned, an expired one and an unknown name not, `monitoring`
  refused, `pgbouncer_lookup` unable to read `pg_authid`. For chunk 6:
  the role connects over TCP, so the scenario's `pg_hba.conf` must admit
  it from the pooler node by password; it holds no reserve
  (`pg_use_reserved_connections` is not granted, item 8's "no
  membership"), so under an exhaustion fault PgBouncer's lookups compete
  for the ordinary slots. Until chunk 7 honours `only_with_role`, render
  mounts `pgbouncer_lookup_password` on every `postgres` node, so the
  role exists in every game; `tools/tests/test_{deploy,fit,state,teardown}.py`
  list both new secrets for the catalog `postgres` (chunk 7 drops the
  lookup one where no pooler node exists).
- **`gm-snapshot-db`** (item 6 kept as written: `-X fetch` with a
  temporary slot works; no snapshot volume): `/usr/local/sbin/gm-snapshot-db`,
  root:root `0700`, in `protected_files`, no arguments, standard input
  ignored. Steps: a `psql` session as `postgres`, reading commands from a
  FIFO in `/run/gm/snapshot-db.XXXXXX/`, runs
  `pg_create_physical_replication_slot('gm_snapshot', true, true)` and
  holds the temporary slot; then `pg_basebackup -h /run/postgresql -p
  5432 -U postgres -w -D - -F tar -X fetch --checkpoint=fast
  --no-manifest -l "gm-snapshot-db <UTC instant>"` as `postgres` writes
  the tar on standard output; closing the FIFO ends the session and
  drops the slot. No child holds the FIFO's write end, so the slot goes
  on any exit, SIGKILL included (shown: the slot present during a stalled
  backup, gone 1 s after a `kill -9`). Standard error: `gm-snapshot-db:
  temporary replication slot gm_snapshot reserving WAL from <lsn>`, then
  `gm-snapshot-db: snapshot written; slot gm_snapshot dropped`, or the
  failure. Exit: 0; pg_basebackup's status on its failure (141 when the
  reader stops early, shown); 1 when the slot cannot be created or does
  not appear within 30 s, or is still there 10 s after the backup; 2 for
  arguments or a non-root caller. One run at a time (the slot name is
  fixed; a second concurrent run exits 1). The tar is rooted at the data
  directory (`PG_VERSION`, `backup_label`, `pg_wal/<segment>`, owners
  `100:102`), no manifest. **Restore** (chunk 11): extract into an empty
  `pgdata` volume with `tar --extract --numeric-owner --same-permissions`,
  beside the other volumes' `copy` tars; the next start runs the role
  sync (single-user mode completes the recovery), then the server; shown
  in a fresh container of a second stack: the data there, no slot, no
  `backup_label` left, `gm_check` connecting, the copied configuration
  not re-seeded. Needs `local replication postgres peer`, `wal_level`
  `replica` or `logical`, `max_wal_senders` and `max_replication_slots`
  ≥ 1. Size: 41MB for the stack test's small cluster (one 16MB WAL
  segment). A SIGKILL leaves the helper's work directory in `/run/gm`
  (emptied at the next container start).
- **Ownership restore** (RG-2): `gm-reload-db`, `gm-restart-db` (first
  thing, before any check, so also when they refuse) and `gm-entrypoint`
  (every start) give `postgresql.conf` and `pg_hba.conf`
  `postgres:pgconf` `0664`; the file is opened `O_NOFOLLOW|O_NONBLOCK`
  and changed with `fchown`/`fchmod` (Perl), so a symlink a player put in
  its place is never followed (shown with a symlink to
  `/run/gm/sudo.log`) and a non-regular file is skipped. Files players
  add to `/etc/postgresql` are left as they made them. The directory's
  `2775` is put back at a container start only. `postgres` stays
  fixable only, so neither wrapper ever refuses as report-only.
- **Footprint**: unchanged in `brick.yaml`. At rest in the stack test,
  under a 512M limit: 27 to 31MiB, CPU 0.03 % (`docker stats`, after the
  test's checks). The reserve costs nothing until used.
- **Stack-test seed**: `max_connections = 10` (the envelope's minimum);
  `pg_hba.conf` carries `local replication postgres peer` and `local all
  gm_check scram-sha-256` under its DO NOT TAMPER comment (D164, D171);
  the lookup secret is mounted, as with a pooler node.
- **Different from W1**: nothing in its contracts. Additions where it
  was silent: the per-start role sync and its failure rule, the
  entrypoint tolerating a missing `gm_check_password`, `gm-restart-db`'s
  `max_connections` refusal, the per-start owner restore in the
  entrypoint, `check-psql`'s exit 2 for its own failures,
  `gm-snapshot-db`'s exit 1 and 2.

### Capture W1-y — chunk 3 outcomes (the `scheduler` brick 0.1.0; read by 7, 8, 11, 12, 14)

Recorded 2026-10-23 by chunk 3's owner, from the code on
`v0.3-c3-scheduler` (`bricks/scheduler/`). What W1 item 7 left to the
brick, as built and tested (unit tests in the image, the stack test).
Nothing in it differs from W1; the points W1 did not fix are below, with
the choices made.

**Image, accounts, paths**

- Image `127.0.0.1:5000/dbagm/scheduler:0.1.0` from `debian:13-slim`,
  172MB; Python 3.13.5, psycopg 3.2.6, s6-overlay 3.2.3.2. The program is
  the package `gm_scheduler` in `/usr/local/lib/python3.13/dist-packages`,
  always run as `python3 -I -m gm_scheduler <command>`.
- Accounts (fixed in the Dockerfile): `scheduler` uid/gid 993:993 (the
  service account, not in `schedconf`), group `schedconf` gid 994
  (`player` is in it).
- Volumes and paths (`brick.yaml` `volumes`):

  | Volume | Path | Holds |
  |---|---|---|
  | `repository` | `/srv/scheduler/repository` | `queries.yaml`, `builders/` |
  | `jobs` | `/srv/scheduler/jobs` | `jobs.yaml` |
  | `schedlog` | `/var/log/scheduler` | `scheduler.log` |
  | `schedstate` | `/var/lib/scheduler` | `sequences.json` (below) |
  | `home` | `/home/player` | |
  | `gmstate` | `/var/lib/gm-state` | `.gm-seeded`, `load-started` |
  | `run` | `/run` | emptied at every start; `/run/scheduler/{status,loaded}`, `/run/gm/write-policy` |

  `snapshot:` names the six first, all `copy`. The program's own
  configuration is `/etc/scheduler/scheduler.yaml` (protected, players
  read it: log, status, marker, paths, the endpoint).

**The schedule's delivery** (W1 item 7 left the framing to chunk 3). The
s6 run script reads, as root, `/opt/gm/seed/schedule.yaml` and every
`/opt/gm/secrets/role_<role>_password` mounted, and passes on standard
input, through a dash here-document (a pipe, never a file):

```
gm-scheduler-input 1
password <role> <password>          one line per mounted role secret
schedule
<schedule.yaml to the end of input>
```

then `exec /command/s6-setuidgid scheduler /usr/bin/python3 -I -m
gm_scheduler run`. A role the schedule names with no password line is
refused at start (exit 2). The entrypoint fails the container on a role
secret that is empty, holds a space or more than one line, and on a
missing `schedule.yaml`. Rendered `schedule.yaml` (chunk 7) is W1 item
7's shape exactly; the shapes must give all seven weekdays (`mon`..`sun`)
under `utc:`, 24 numbers each; unknown keys are refused.

**Exit codes**

- `run` (the s6 service): 0 stopped (SIGTERM); 2 the input, the schedule
  or the load-started marker is not valid (the reason on the container's
  output only, a value-free `fatal` line in the log); 3 `queries.yaml`,
  a builder or `jobs.yaml` is not valid, or a key or connection they or
  the schedule name is missing (`fatal message="not started: ..."`). The
  `finish` script sleeps 4 s after 2 and 3.
- The checks (`check`, `check-keys`, `pending`, `reloadable`): 0 fine, 1
  problems (one line each), 2 error. `gm-reload-scheduler`: 0 reloaded
  (or the program down and s6 restarting it), 1 refused (report-only, or
  "NOT reloaded"), 2 usage or the policy unreadable.

**Status and what was loaded** (root reads them; the directory is
`scheduler:scheduler 0750`, the files `0640` and `0644`):

- `/run/scheduler/status`: `idle <UTC instant>` or `running <UTC
  instant>`, the instant being when the program entered the state;
  rewritten atomically; the run script removes it before each start, so
  it never shows a stopped program's state. `start-load` (chunk 8a) polls
  it for `running `.
- `/run/scheduler/loaded`, rewritten at start and at each successful
  reload: `generation=<n>` (1 at start, +1 per reload),
  `loaded=<instant>`, one `file <sha256 or a reason> <path>` per file
  read, one `job <name> next=<instant or never>` per job.

**The load-started marker** (W1 item 7, as written there): the program
reads it at start only; the entrypoint re-asserts root:scheduler `0440`
when it exists. Its T0 appears in the log's `state state=running
t0=<T0>` line.

**The log** (`/var/log/scheduler/scheduler.log`, W1's line grammar; a
quoted value is always the last field). The `summary` and `key` lines
are W1's; latencies are milliseconds with one decimal (`81.0`, not `81`),
`-` when `calls=0`; a call counts in the minute it ends in; the lines are
written about one second after the boundary. The other events:

```
<t> state state=idle
<t> state state=running t0=<T0>
<t> state state=stopping
<t> run job=<name> key=<k> phase=start
<t> run job=<name> key=<k> phase=end status=ok rows=<n> ms=<x>
<t> run job=<name> key=<k> phase=end status=error sqlstate=<S> ms=<x>
<t> skip job=<name> key=<k> at=<due instant> reason=still-running|connection-refused
<t> error key=<k> [job=<name>] sqlstate=<S or -> message="<text>"
<t> reload status=ok keys=<n> jobs=<n>
<t> reload status=refused message="<problems; joined>"
<t> job job=<name> key=<k> next=never
<t> fatal message="<text>"
```

`sqlstate=-` for a builder's failure (`message="builder: <Type>:
<text>"`). A refused connection has no SQLSTATE from libpq: the driver
takes it from the server's message (`53300` too many clients or too many
connections for a role, `28P01` password, `28000` pg_hba or unknown role,
`3D000` unknown database, `57P03` starting or shutting down), `08001`
otherwise; a session lost mid-call is `08006`. A job whose connection is
refused logs its `error` line and a `skip`, never a `run`.

**Metrics** (port 9120, `GET /metrics`, text format 0.0.4):

| Name | Labels | |
|---|---|---|
| `scheduler_calls_total` | `key` | calls ended, failed ones included |
| `scheduler_errors_total` | `key` | |
| `scheduler_call_duration_seconds` | `key` (`le`) | histogram, buckets 0.001 to 60 s |
| `scheduler_job_runs_total` | `key`, `job` | runs started |
| `scheduler_job_skips_total` | `key`, `job`, `reason` | |
| `scheduler_running` | | 1 running, 0 idle |
| `scheduler_start_time_seconds` | | |

Every key the schedule or `jobs.yaml` names has its `calls`, `errors`
and histogram series from the start, at 0. A call's latency runs from
its arrival to its end: waiting for a pool slot, connecting and a
transaction's hold included.

**Behaviour W1 left open**

- Randomness: each task's generator is seeded from
  `sha256("gm-scheduler|<seed>|<hostname>|<task>|<second it started running>")`,
  the task `stream:<index>:<initial key>` or `job:<name>:<due second>`:
  the same inputs draw alike; a resumed program does not repeat its
  draws.
- `{sequence: [start, step]}` never reuses a value: positions are
  reserved in blocks of 1000 in `/var/lib/scheduler/sequences.json`; a
  restart starts at the next block.
- A stream whose concurrency slots are all busy delays its next call
  until one frees; no backlog is kept.
- Pools are per task and per connection: `pool: {size: N}` opens up to N
  sessions when first needed and keeps them; `per-call` opens one per
  call. Sessions run in autocommit, transactions as explicit `BEGIN
  ISOLATION LEVEL ...`, no server-side prepared statements
  (`prepare_threshold=None`: any PgBouncer pool mode works, chunk 6);
  `application_name` is the node's hostname.
- Builders: `<function>(intensity, options)`, plus `rng=` when the
  signature names it; returns `(statements, transaction)` or
  `{"statements", "transaction"}`, a statement `(sql, params)` or
  `{"sql", "params"}`, `transaction` false, true (read committed) or
  `{isolation, hold}`. Only the files `queries.yaml` names are imported.
- `jobs.yaml`'s zone key, as the program reads it: `timezone:`, any zone
  tzdata names (render writes `Etc/GMT-M`, `Etc/GMT+M`, `Etc/GMT`,
  chunk 7a; chunk 14's checks read the same key).
- Rendered timeline changes apply at their instant; at a (re)start every
  change at or before the current time is applied before the first call.

**The write policy on the node** (W1 item 5, as built): the entrypoint
runs `python3 -I -m gm_scheduler write-policy` (refusal text
`GM_WRITE_POLICY='<v>' is not one of fixable, report-only, no-access` or
`GM_WRITE_OVERRIDES: '<p>' is not one of this brick's writable_paths
(...)`, after `gm-entrypoint: fatal: `), then `restore`. `restore` (root)
opens every directory and file with `O_NOFOLLOW` and changes it through
its descriptor; a symbolic link, a non-regular file or a file with other
hard links is left alone and named. Files players add in a fixable
directory get the seeded files' owner and mode at the next restore; the
program ignores them unless `queries.yaml` names them as a builder.

**For chunks 8, 11, 12, 14**

- `start-load` (8a): the marker as W1 item 7 says, then `s6-svc -r
  /run/service/scheduler`, then `/run/scheduler/status` until `running `
  (the stack test does exactly this; under a second here).
- Outages (8b): a minute with no `summary` line; the program writes none
  while stopped, the first summary after a start covers the partial
  minute it started in.
- Sealed checks (14): read the counters with `curl -s
  localhost:9120/metrics` inside the node, the log at its path, the files
  at their paths; `jobs.yaml`'s `at` and `timezone`.
- Snapshot (11): every volume but `run` by `copy` while running; tar sees
  the log grow (exit 1 accepted, W1 item 6).

**Footprint at rest** (stack test, armenelos, 2026-10-23): idle (no marker), cgroup memory 17M to 26M of the 128M limit over two
runs (page cache included), the program's RSS 24M to 25M (shared library
pages included); running two streams at 30 calls a minute and 2 an hour,
27M to 41M, RSS 35M. Disk at rest 56K across the
volumes; the log grew 3966 bytes (45 lines) in 12 minutes at two keys,
about 20K an hour; `disk_growth_per_hour: 2M` stays provisional for
error floods until chunk 15b measures a game. Within master spec 7.1's
figures (limits 0.25 CPU / 128M, reservations 0.1 CPU / 64M), kept in
`brick.yaml` unchanged.

**Tests**: `sh bricks/scheduler/tests/run-unit-tests.sh` (the Dockerfile's
`unit-test` stage: the program as installed, Debian's PostgreSQL 17 in
the same container; 60 tests, none skipped, a skip fails the run) and
`sh bricks/scheduler/tests/run-stack-test.sh` (about 15 minutes; its
database is the same unit-test stage, so it does not depend on the
`postgres` brick chunks 1 and 4 change). Both under the host lock.

### Preflight corrections sent to `spec-writer` (before any chunk starts)

- The owner's three confirmations recorded as spec D160–D162 (3b03db2; plan
  v3): chunks 8a, 11, 13 and 15b revised.
- Capture W1's open points and contradictions settled as spec D163–D170
  (55bf028; plan v4): `schedule.yaml` read in place (D163); the replication
  line added by chunk 1b (D164); window and threshold passed by chunk 9
  (D165); wave 1's order, chunk 1 first with chunk 3 beside it, chunks 2, 4
  and 5 cut after chunk 1's merge (4 and 5 after 1a's at least) (D166);
  W1's readings on roles, `seed.paths`, `seed.modes`, secrets, `snapshot:`
  and the five faults' evidence kept (D167); `timezone_offset` (D168);
  `check-psql` in chunk 4a (D169); the scheduler's writable paths made
  directories (D170). W1's text amended in place, each change marked.
- O102, asked of the owner 2026-10-23: every `postgres` seed carries its own
  DO NOT TAMPER line `local all gm_check scram-sha-256`. **Yes**, as
  recommended; recorded as spec D171 (d124b42), chunks 1 and 4 and W1 item
  8 revised.

### Dispatch

- Chunk 3 (`v0.3-c3-scheduler`): dispatched 2026-10-23, beside chunk 1
  (D166). Told to take `v0.3-w1` in once chunk 1 has merged, before its
  final loader check, or else report as waiting on chunk 1.
- Chunk 1 (`v0.3-c1-formats`): dispatched 2026-10-23, after D171; 1a to
  merge into `v0.3-w1` as soon as it is green, so chunks 4 and 5 can start.

### W1 addenda — choices chunk 2 made

Where W1 was silent, recorded by chunk 2 (`v0.3-c2-loader`), 2026-10-23.

- **Retention**: the exception counts a `family: retention` fault planted on
  that `prometheus` node, not elsewhere; a seed with no
  `storage.tsdb.retention.time` is refused (the brick's validator wants a
  time bound anyway); Prometheus' own duration grammar (`1d`, `1h30m`, `2w`).
- **`pg_hba.conf`**, read with PostgreSQL's first-match rule: the first
  `local` line whose databases hold `replication` and whose users hold
  `postgres` or `all` decides pg_basebackup's access, by `peer` or `trust`
  only; for `gm_check`, `local` lines whose users hold `gm_check` or `all`
  (not `replication` alone) are read in order, and any method other than
  `scram-sha-256`, `md5`, `password` or `trust` (`reject`, `peer`, `ident`)
  before a line admitting it for `all` databases is refused. `+group` and
  `@file` entries are not expanded. `max_wal_senders = 0` and
  `wal_level = minimal` in the seed's `postgresql.conf` are refused (7.3's
  "and settings").
- **`{{customer_timezone}}`** is looked for in the seed files of the node
  whose `role` is `bastion`.
- **Per-file fix** also decides when an answer key needs `acceptable.fix`
  for a fault no issue covers: when the fault lists `fix` and its files are
  fixable on the node (overrides included).
- **`write_overrides`** on a `no-access` node is refused, as on a `fixable`
  one (W1 item 1: report-only only).
- **Folder seed entries** (W1 item 3) are checked by the loader: optional
  in `seed_files`, a folder of the scenario, at least one file, no
  subfolder, file names `[A-Za-z0-9_][A-Za-z0-9_.-]*`. Every `seed.files`
  entry needs a `seed.paths` entry; `seed.paths` values are absolute paths.
- **The scheduler's files**: unknown keys are refused in every form (a
  query, a pool's query, a step, a sequence, a builder, a transaction, a
  connection, a stream, a timeline change and its `set`, a job), and a
  top-level key other than `intensity`, `connections`, `streams`, `shapes`
  and `timeline` in `schedule.yaml` (so no `seed:`); `shapes` and `timeline`
  are optional, `jobs` may be `[]`. Parameters are generators only (a
  constant is `{choice: [v]}`): `int` and `sequence` take integers, `int`
  lo ≤ hi, `sequence` step ≠ 0, `decimal` lo ≤ hi and places ≥ 0, `choice`
  a non-empty list of scalars. A shape's hours are quoted strings (an
  unquoted `12` is refused). A timeline change at `T0` is accepted (exactly
  the aging minimum before hand-over). A job's `connection` names one of the
  node's `schedule.yaml` connections; job names are unique on the node; a
  `timezone_offset` is any non-zero integer (render wraps it). The
  connection target's database name is `[A-Za-z_][A-Za-z0-9_$-]*` and its
  port a port number. Cron minute forms are `*`, `n`, `a-b`, `*/n`, `a-b/n`
  and lists of them (`a/n` refused). A builder file is parsed with `ast`,
  never imported, and must define the function at its top level.
- **Templates**: `queries.yaml`, `schedule.yaml` and `jobs.yaml` join the
  format skill's templates and are the loader's schema for their required
  keys; `queries`, `pool` and `shapes` are checked by code (their forms vary
  per entry). `sql` values are not searched for placeholders (`<` and `>`
  are operators). List items are labelled by `key` when they have no
  `name`, `id`, `setting` or `instance` (`streams[orders.insert]`).
- **Fixture**: `tools/tests/fixtures/fixture-v03-refusals` (with a
  scheduler node, a scenario-local `scheduler` brick copied from chunk 3a's
  `brick.yaml` with its image renamed) is the valid one with scheduler
  nodes; `fixture-audit` the valid one without.
- Chunk 2a merged 2026-10-23: c278786, merge ff60cce.

### W1 addenda — choices chunk 1 made

Where W1 was silent, recorded by chunk 1 (`v0.3-c1-formats`), 2026-10-23.

- **The existing faults' aging minimum**: every catalog fault and every
  fixture fault takes `aging: {technique: real-time, minimum: 0m}`: their
  evidence was written for a restored state and shows at once. A v0.3
  scenario that needs more for an instance sets its `aging_minimum`.
- **Evidence without a stated place**: a `psql` or SQL reading whose v0.2
  text names no place reads `where: node`; one the text reads "from the
  bastion" reads `bastion`.
- **Readings rewritten rather than dropped** (W1 item 2's rule): where a
  `prometheus-*` fault would keep no reading of a fact once its web
  readings left, the fact is read on the prometheus node itself, through
  Prometheus' API (`curl -s http://127.0.0.1:9090/prometheus/api/v1/targets`)
  or `promtool query instant http://127.0.0.1:9090/prometheus '<expr>'`:
  the target down (`node-missing`), the node's absent series
  (`node-missing`, `service-missing`), the absent target
  (`scrape-target-missing`). Grafana's alert state and its provisioning
  API are dropped (no node reading of them on the target but the rule
  file, kept). `fixture-node-left-out`'s web reading becomes the same view
  read with `curl` on the monitor node.
- **Answer keys keeping the dropped readings**: two dropped readings were
  in no answer key; `fernway-clinics-monitoring`'s answer key gains them
  in 1a, beside the fault change: f1's Grafana alert staying Normal and
  f5's provisioning API reading, both `ui:grafana`.
- **Provisional growth per hour**: `postgres` 32M, `bastion` 1M,
  `prometheus` 4M, `postgres-exporter` 1M, `grafana` 2M, each marked
  provisional in `brick.yaml` and `docs/gm.md` until chunk 15b measures
  it; the fixtures' local bricks `0`.
- **Fixture-local bricks** keep their version (scenario-local, pinned
  only by their fixture); they gain the required keys
  (`disk_growth_per_hour`, `seed.paths`) and closed-list roles.
- **Template markers**: `seed.paths` is required and "may be {}";
  `seed.modes`, `snapshot:`, `report_tools`, `only_with_role` and
  `sealed_check.behavioural` are `# optional`, so the unchanged loader
  loads every definition; `writable_paths` keeps "may be []".
  `brick-gm.md` carries the level-3 `### Snapshot` under Footprint (W1
  item 5).
- **1b, scenario template**: `aging:` and `difficulty:` sit in their own
  section between `background` and the topology; `aging:` itself,
  `difficulty.level`, `write_overrides`, `plant_at`, `aging_minimum`,
  `window` and `threshold` are `# optional`, so the unchanged loader
  requires only `difficulty.score` and checks the others' shapes when
  present (a present `aging:` needs both its keys; a present
  `write_overrides` is non-empty). The `{{customer_timezone}}`, scheduler
  seed-file, `pg_hba` and retention rules are comments on `seed_files`,
  the skill's consistency rules stating them in full.
- **1b, difficulty levels**: the two scenarios and the three fixtures
  carry `difficulty.score` only (6, 8; 2, 2, 1): master spec 15.1 gives
  the scores, not the levels, so none is written.
- **1b, the seed lines**: in the order `local all postgres peer`, `local
  replication postgres peer`, `local all gm_check scram-sha-256`, right
  under the DO NOT TAMPER comment, whose wording is kept. The fixtures'
  starter packs (`fixture-audit`, `fixture-monitoring`) name the three
  lines in their DO NOT TAMPER line; the two scenarios' `player/README.md`
  are outside chunk 1's Files line and still name only the peer line
  (reported to the driver).
- **1b, answer-key evidence**: the grammar is unchanged (`bastion`,
  `node:<name>`, `ui:<name>`, `report:<tool>`); a fault definition's
  `node` reading is written `node:<its target>` there, as the existing
  keys do. `threshold` is required exactly with `window`.
- **1b, scenario document**: section 1 gains a Difficulty row (the score,
  the instance count beside it, the level when given) and an Aging row
  (the minimum and the designed hand-over, or "none: no scheduler
  node ..."); the fault-instance table gains a "Planted at" column (`T0`
  when absent) with a gloss line under it, and an "Aging minimum" column
  only in a scenario that ages; a node with overrides gets a "Write
  overrides" bullet; the sealed-check line reads "(0: fixed, 1: present,
  3: too soon to tell)", and a behavioural check adds its window and
  threshold. The document never reads a fault definition for these.
- Chunk 1a merged 2026-10-23: e73a7b4, merge bd008a7. Unit suite 298 OK;
  the five images built at their v0.3 tags and their stack tests passed.
  Outside chunk 1's Files line, needed to keep the suite and smoke runs on
  the new pins: `tools/tests/test_{fit,deploy,render,model}.py` (tags and
  pins; v0.2's free-text `where` test rewritten as
  `test_fault_evidence_where_is_a_location`), and the `IMAGES=` lists of
  `tools/tests/smoke{,-scenario,-monitoring}.sh` (not run: wave gate). Two
  readings dropped from fernway's faults were missing from its answer key
  (f1's Grafana alert state, f5's provisioning API) and were added there as
  `ui:grafana`. The five Dockerfiles' "Build:" comments still name the old
  tags (chunks 4 and 5 touch those files). Its owner paused at its context
  threshold before 1b; its addenda are in "W1 addenda" above.
- Chunk 1b: a fresh owner dispatched 2026-10-23 on `v0.3-c1-formats` from
  e73a7b4.
- Chunk 4 (`v0.3-c4-postgres`): dispatched 2026-10-23, cut after 1a's merge.
  Chunk 5 waits for a free slot (κ = 3: chunks 1b, 3, 4 in flight).
- Chunk 1b merged 2026-10-23: d27af79, merge 541a5a6; chunk 1 complete.
  Unit suite 298 OK on `v0.3-w1`. `difficulty.score` 6, 8 and 2, 2, 1 for the
  fixtures; the two `pg_hba` lines in the four seeds; bookshop's answer key
  cites lines 14 and 16; five READMEs regenerated. **For the wave gate**
  (outside every wave-1 chunk's Files line): the two scenarios'
  `player/README.md` DO NOT TAMPER lists still name only `local all postgres
  peer`, not the replication and `gm_check` lines; a `coding-executor` fixes
  them on the wave branch at the gate.
- Chunk 2 (`v0.3-c2-loader`): dispatched 2026-10-23 after chunk 1's merge.
  Chunk 5 waits for a free slot (in flight: 2, 3, 4).
- Chunk 2a merged on `v0.3-w1` (ff60cce) while chunk 3 finished; chunk 2b
  still building.
- Chunk 3 merged 2026-10-23: 3a f2e5781, 3b 10faa0b, merge 3b54bee. Program
  unit tests 60 OK (in the image, Debian PostgreSQL 17.11, psycopg 3.2.6,
  Python 3.13.5); stack test 95 PASS, 0 FAIL (about 17 minutes); loader
  accepts the brick after chunk 2a's checks; unit suite 376 OK on
  `v0.3-w1`. Image `scheduler:0.1.0` 172MB. Footprint at rest (armenelos,
  2026-10-23): 17–26M idle, 27–41M at 30 calls a minute; disk about 56K,
  log about 20K an hour at two keys; `disk_growth_per_hour: 2M`
  provisional. Capture W1-y recorded right after Capture W1. Risks carried
  forward: error lines are not rate-limited (a long target outage fills the
  log at the streams' rates; for chunk 12 or 15b to measure); a blocking
  builder stalls the node (one process); the stack test uses PostgreSQL 17,
  not the brick's 18.
- Chunk 5 (`v0.3-c5-monitoring`): dispatched 2026-10-23 (in flight: 2b, 4, 5).
- Chunk 2 merged 2026-10-23: 2a c278786 (merge ff60cce), 2b 34aade5 (merge
  ecb7278). 117 refusal tests added; unit suite 415 OK on `v0.3-w1`. It
  loaded chunk 4's `postgres` brick as committed on its branch (a91689b)
  with no problems; chunk 4's final `brick.yaml` is loaded again at the
  gate. Its first 2b merge conflicted with the driver's lines at the end of
  this log: it aborted, moved its addenda before "W1 addenda — choices
  chunk 1 made", and merged cleanly. Risk carried forward: the
  `pg_hba.conf` check ignores `+group`, `@file` and `include`.
- In flight: chunks 4 and 5.
- Chunk 4 merged 2026-10-23: 4a a91689b, 4b 190b374, merge 913c13e. Stack
  test 131 checks passed (armenelos); unit suite 415 OK; loader clean on the
  brick and both scenarios. Reserve 2 (measured); at rest 27–31 MiB of 512M;
  a test cluster's snapshot 41 MB. Capture W1-x recorded (placed before
  "Preflight corrections"). Its merge met an additions-only conflict in this
  log with W1-y; it kept both, and the driver checked that nothing was
  removed (accepted: the wave log is append-only). Carried forward: until
  chunk 7 honours `only_with_role`, render mounts `pgbouncer_lookup_password`
  on every postgres node (chunk 7 changes the test secret lists again);
  `pgbouncer_lookup` holds no reserve (chunk 6); a dropped `gm_check` comes
  back only at the next container start.
- In flight: chunk 5.
- Chunk 5 merged 2026-10-23: 5a d009cb9 (merge 66b926f), 5b 5b3303f (merge
  21258a0). Stack tests: prometheus 131, postgres-exporter 103 (twice, the
  second against postgres 0.3.0), grafana 119, all PASS; unit suite 415 OK.
  `snapshot:` values from chunk 1 held. Brief stop measured in the stack
  tests (armenelos, 2026-10-23): Prometheus (90K TSDB) down 11 ms, ready
  about 1 s later; Grafana (1.6M) down 30 ms, API about 2 s later; an aged
  TSDB is chunk 15b's to measure. `GM_WRITE_POLICY=no-access` not run
  (treated as report-only). **For the wave gate** (outside its Files line):
  the three monitoring bricks' `docs/player.md` say "you can edit" with no
  word on report-only; their Dockerfiles' "Build:" comments still name the
  old tags.
- Every chunk of wave 1 merged; wave gate next.

### Wave gate — 2026-10-23

Run on `v0.3-w1` on armenelos (Debian 13, Docker 29.9.1, single-node swarm),
idle apart from other projects' long-running containers (`llmward-*`,
`ollama`, an exited `magical_jones` dev container: none of the game's). A
`coding-executor` ran most of it and was cut off by a session limit before
reporting; its step logs survived and the driver finished the gate itself.

Fixes on the wave branch, one commit each (findings outside the chunks' Files
lines):
- 0628c4b: both scenarios' starter packs list all three DO NOT TAMPER
  `pg_hba` lines (D164, D171).
- 1e89cfb: the monitoring bricks' `docs/player.md` say the files can be
  read-only (chunk 5's finding).
- fd6b2fc: the five Dockerfiles' "Build:" comments name the v0.3 tags.
- 0d81f5a: `tools/tests/smoke.sh` counts postgres' two new secrets (14
  labelled configs and secrets, 8 secret files; traced to chunk 4). The
  lookup secret will drop off non-pooler games when chunk 7 honours
  `only_with_role`, so chunk 7 changes these counts again.

| Step | Result | Duration |
|---|---|---|
| Unit suite | 415 OK | 38 s |
| Scheduler unit tests (in its image) | 60 OK | 47 s |
| `sh -n` on every shell file | 97 files, 0 failed | — |
| `perl -c` on every Perl file | 5 files, 0 failed | — |
| Loader: every brick, fault, scenario and fixture | 23 definitions, 0 with problems | — |
| Stack test `postgres` 0.3.0 | all checks passed | 74 s |
| Stack test `bastion` 0.3.0 | all checks passed | 63 s |
| Stack test `prometheus` 0.2.0 | all checks passed | 88 s |
| Stack test `postgres-exporter` 0.2.0 | all checks passed | 99 s |
| Stack test `grafana` 0.2.0 | all checks passed | 170 s |
| Stack test `scheduler` 0.1.0 | all checks passed | 752 s |
| `smoke.sh` | 2 failed, then all passed after 0d81f5a | 24 s |
| `smoke-monitoring.sh` | 43 passed | 46 s |
| `smoke-scenario.sh bookshop-new-server` | 18 passed | 21 s |
| `smoke-scenario.sh fernway-clinics-monitoring` | 17 passed | 29 s |

`pgbouncer` is not built yet (chunk 6, wave 2), so six bricks, not seven.
Every stack and smoke run tore down with nothing left. Image sizes
(armenelos, 2026-10-23): postgres 0.3.0 262MB, bastion 0.3.0 185MB,
prometheus 0.2.0 488MB, postgres-exporter 0.2.0 165MB, grafana 0.2.0 866MB,
scheduler 0.1.0 172MB. No intent register, so there is no wave sync.

### State at the end of 2026-10-23 (for the next driver)

- **Wave 1 is gated** and waits only for the owner's word to merge
  `v0.3-w1` into `main` (`--no-ff`, with the gate's figures in the message).
  Not merged yet.
- After the merge, remove the wave worktree
  `/home/bastien/work/db_audit_gm-wt/v0.3-w1` and the branches `v0.3-w1`,
  `v0.3-c1-formats`, `v0.3-c2-loader`, `v0.3-c3-scheduler`,
  `v0.3-c4-postgres` and `v0.3-c5-monitoring` (all merged; no chunk
  worktree is left).
- Owner decisions taken in wave 1: D160–D162 (three confirmations) and D171
  (O102). Nothing is pending with the owner except the merge.
- Gates: G2 and G3 cleared for wave 1 (re-check at wave 2's start: the
  memory available was about 3–4G). G4 (VPS) is untouched; wave 3 needs it,
  under the VPS rule.
- Carried into wave 2:
  - chunk 6: `pgbouncer_lookup` holds no reserve (W1-x);
  - chunk 7: honour `only_with_role` (the lookup secret on pooler games only)
    and update the secret counts in `smoke.sh` and
    `tools/tests/test_{deploy,fit,state,teardown}.py`;
  - chunk 12 or 15b: the scheduler's error lines are not rate-limited.
- Lesson for briefs: append-only conflicts in this log between chunk merges
  are expected; a chunk owner keeps both sides and checks that nothing was
  removed.
- Next: wave 2 (chunks 6, 7, 8, 9), from `main` once wave 1 has merged.
  The wave 2 start needs capture W2 (the stages and records, and the "too
  soon to tell" verdict) before chunks 8 and 9.

## Wave 1 — merged 2026-10-26

Merged into `main` on the owner's word, `--no-ff`, as 5faff6c, with the
gate's figures in the message. The wave worktree and the branches
`v0.3-w1`, `v0.3-c1-formats` to `v0.3-c5-monitoring` removed.

## Wave 2 — started 2026-10-26

Chunks 6, 7, 8, 9 (κ = 3). Branch `v0.3-w2`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.3-w2`, cut from `main` at 5faff6c.
No rulings since the plan's v5 (D171 is the last; numbering continues
from D172).

### Gates checked at the start

- G2 (network at build time), hand check 2026-10-26: Debian's trixie
  `Release`, the PostgreSQL apt repository's `trixie-pgdg` `Release`,
  GitHub's s6-overlay releases and the pinned Grafana 13.2.4 tarball
  answer 200. Cleared for wave 2.
- G3 (Docker host in swarm mode), hand check 2026-10-26: armenelos, Docker
  Engine 29.9.1, swarm active, one node. Cleared for wave 2.
- Host resources on 2026-10-26: 4.9G of memory available (3G of swap in
  use), 10G free on `/`; other projects' containers running (`llmward-*`,
  `ollama`). Docker checks stay serialized under the host lock.

### Order

- Chunk 6 reads nothing W2 records (its interface is W1 item 8 and
  W1-x): dispatched at once, beside W2's drafting.
- Capture W2 is drafted and committed before chunks 7 and 9 start (7
  writes W2's records, 9 its verdict) and before chunk 8.
- Then chunks 7 and 9 side by side (no path between them; shared lists
  only: `gmctl.md`'s rows); chunk 8 once 7 and 9 have merged.

### Capture W2 — the aging's records and stages (chunks 7, 8, 9; read by 11, 13 and later)

Recorded 2026-10-26, before any code; drafted for the wave driver from
the plan's "Read first" and chunks 7 to 9 (their capture lines), master
spec 6.1, 7.1, 7.4, 8 (its opening, 8.1, 8.3, 8.4, 8.5, 8.7), 9, 11, 12,
13, 16 and 20, access model 3, 5, 6, 7, 9, D117, D124, D129, D131, D136,
D143, D144, D152, D156 to D158, D160 to D163, D165, D168, D169, v0.1's
captures W2-A, W3-A and W3-C (the local implementation's files,
`state.yaml`, the teardown record), W1 items 0, 1, 4, 7 and 8, W1-x
(the check role) and W1-y (the scheduler's marker, status file and log),
and the code on `v0.3-w2` at 301063f (`tools/gm/{localimpl,state,inject,
teardown,checks,render,deploy}.py`, `tools/gm/__init__.py`,
`tools/tests/smoke.sh`). W1's method holds: where a source fixes a point
it is cited, not restated; **(choice)** marks a point the sources left
open, settled here with its reason; each item names the chunk that
writes it and the chunks that read it; a chunk's internals stay out and
go into its outcome capture. Points not mine to settle are at the end.

**0. Conventions used below** (read by 7, 8, 9, 11, 12, 13)

- **Where the records live** (choice: by writer and lifetime): what
  render fixes for the game, in `implementation.yaml` under one new
  top-level key, `timeline` (item 1); what changes during the game, in
  `state.yaml` under new top-level keys (items 3 to 8, 11). v0.1 W2-A's
  files and W3-C's record are otherwise unchanged; an absent key reads as
  none (as W3-C's `teardown`), so v0.2 states and static games read as
  before.
- **One writer at a time** (choice: timer runs and the GM's commands
  write `state.yaml` at the same moments): every read-modify-write of it
  holds an exclusive `flock` on `local/<playground>/.state.lock`, only
  around the read and the write, never across a Docker call or a script;
  `localimpl`'s existing writers take it too.
- **Instants** `YYYY-MM-DDTHH:MM:SSZ` (`localimpl.now_iso`); **minutes**
  `YYYY-MM-DDTHH:MMZ`, the scheduler's `minute=` form (W1 item 7);
  **durations** W1 item 0's strings (`16h`) for minima; seconds as
  integers for a check's remaining window; minutes as integers for lost
  time.
- **Failures from `start-load` on never set `failed`** (8.7).
  `failure:` and `failed` stay the record of a setup step before T0 that
  tore the game down (v0.1 W3-A). A failing `start-load`, planting or
  early check is recorded in its own record (items 3, 4, 8) and leaves
  the stage; `status` computes its head from those records (item 11)
  (choice: a re-planting that succeeds must stop the earlier failure
  heading `status`).
- **Scheduler game** and **static game**: a game whose scenario has, or
  has not, a scheduler node (W1 item 0; D157, D158).

**1. Render's records: the planned hand-over, the shift, the customer's
time zone, the seed** (writes: chunk 7a; read by 8, 11, 12, 13). Master
spec 6.1, 7.1, 8.3, 13; D129, D136, D163, D168; W1 items 1 and 7.

```yaml
# implementation.yaml, written by render, rewritten by a re-render at `rendered`
timeline:
  planned_handover: "2026-10-27T14:00:00Z"    # render --handover, UTC
  designed_handover: "16:00"                  # the scenario's aging.handover_at
  shift: 2                                    # integer hours, -11..+12 (8.3)
  customer_timezone: {zone: Etc/GMT-2, reading: UTC+2}
  seed: 4815162342                            # 0 <= seed < 2**63 (W1 item 7)
  aging_minimum: 16h                          # the scenario's aging.minimum
  instances:                                  # every fault instance, fault_instances order
    f1: {plant_at: T0, planned_at: null, aging_minimum: 2h}
    f7: {plant_at: handover-6h, planned_at: "2026-10-27T08:00:00Z", aging_minimum: 4h}
  rendered_at: "2026-10-26T19:40:12Z"
```

- **`--handover`** (choice: one form, the instant form the records use):
  `render <dir> --playground <pg> --handover 2026-10-27T14:00Z` (or
  `…T14:00:00Z`); minutes and seconds must be 0 (W1 item 1). Required in
  a scheduler game. Refused when not in the future. A planned hand-over
  earlier than now plus the aging minimum is not refused: render prints
  one warning line with the earliest hand-over the game could have if
  the load started at once (choice: the feasibility judgement is the
  GM's, 8.2, and the test harness renders before its override applies,
  item 10).
- **Shift**: `((designed hour − planned hour + 11) mod 24) − 11`, so
  −12 reads +12 (8.3). **Zone**: UTC plus the shift; `zone` is
  `Etc/GMT-N` for UTC+N, `Etc/GMT+N` for UTC−N, `Etc/GMT` for 0;
  `reading` is `UTC+N`, `UTC-N` or `UTC+0`. `{{customer_timezone}}` is
  replaced by `<reading> (<zone>)`, `UTC+2 (Etc/GMT-2)` (choice: the
  prose reads the offset, a player's tool takes the zone, and 8.3 asks
  for both).
- **`instances`**: `aging_minimum` is the instance's own minimum (its
  `aging_minimum`, else its definition's `aging.minimum`, W1 item 1);
  `planned_at` is the planned hand-over minus N hours for
  `handover-<N>h`, `null` for T0. Recorded so the earliest hand-over
  (item 7) is reproducible from the records alone.
- **The seed** is drawn once per game id (`secrets.randbelow(2**63)`) and
  kept by a re-render of the same game (choice: re-rendering before
  deploy changes the planned hand-over, not the game); it is written
  into every scheduler node's rendered `schedule.yaml` (W1 item 7).
  A restart's new game id takes a new one (12).
- **Rendered files** (choice: deploy creates configs from `file:` paths,
  so render's output needs a place): every seed file render rewrites (a
  scheduler node's `schedule.yaml` and `jobs.yaml`, a bastion seed file
  holding `{{customer_timezone}}`) is written to
  `local/<playground>/rendered/<node>/<seed file name>`, and that node's
  config in `implementation.yaml` names it as its `file:` from fit on;
  other seed files keep naming the scenario's. Chunk 8 reads the
  rendered `jobs.yaml` for the early check's time (item 8).
- **A static game** has no `timeline` (render without `--handover`). With
  `--handover`, which 13 allows, `timeline` holds `planned_handover`
  alone, and nothing is shifted (choice: an accepted option is recorded,
  and only `status` reads it there).
- **Read by 11**: the restart's re-render keeps `planned_handover`,
  `shift` and `customer_timezone` and takes a new seed (12, D136)
  (choice: the players were told that zone at hand-over).

**2. Stages** (writes: chunk 8a, `localimpl.STAGES` and
`state.DEPLOYED_STAGES`; read by 9, 11, 12, 13). Master spec 13; access
model 3, 5, 6, 7.

`fitted`, `rendered`, `deployed`, `data-loaded`, `injected`,
`load-started`, `handed-over`, `final-answer`, `feedback-given`,
`torn-down`; or `failed`. `load-started` joins `DEPLOYED_STAGES` (so
`check`'s and `validate`'s stages include it). A scheduler game never
reaches `failed` from `load-started` on (item 0).

| Verb | Allowed at | Records |
|---|---|---|
| `render [--handover <instant>]` | `fitted`, `rendered` | `rendered`, `timeline` |
| `inject` | `data-loaded`, `injected` (a replay) | `injected`; the T0 instances' plantings (item 4) |
| `start-load` | `injected`, scheduler game | `load` (item 3); `load-started` once every scheduler runs |
| `inject --at <instant>\|now --instance <id>` | `load-started` | `plantings.<id>` (item 4) |
| `check` | `injected` and every later deployed stage | nothing |
| `check --early-check` | `load-started` | `early_check.result` (item 8) |
| `check --handover-check` | `load-started`; `injected` in a static game | `handover_checks` (item 8) |
| `status --set handed-over` | `load-started`; `injected` in a static game; item 11's conditions (the snapshot's from chunk 11a on, amended by spec D172) | `handed-over` |
| `snapshot` (chunk 11) | `load-started`; `injected` in a static game | `snapshot` (item 11) |

- `inject` without `--at` plants only the T0 instances; at
  `load-started` it is refused (choice: replaying under the load would
  re-plant into a running system; `--at now --instance` re-plants one).
- `start-load` in a static game: refused with one line,
  `start-load: game <id> has no scheduler node, so it has no aging and no
  load to start (D157)`. At `load-started`: refused, T0 named. At
  `handed-over` and later: refused, "once handed over" (13; access model
  7). A restart's own setup (chunk 11) calls the steps beneath the verbs,
  so these refusals do not reach it (choice: 12 exempts it).
- The `load-started` history entry is written when T0 is recorded, its
  `at` that moment; T0 itself is `load.t0` (item 3).

**3. `start-load` and T0** (writes: chunk 8a; read by 8b, 11, 13).
Master spec 7.1, 8.4, 8.7; W1 item 7 and W1-y (the marker, `s6-svc -r`,
the status file polled for `running ` within 60 s).

```yaml
# state.yaml
load:
  t0: "2026-10-26T20:00:07Z"          # null until every scheduler node runs
  attempts:                            # one per start-load run, last last
    - began: "2026-10-26T20:00:07Z"    # the T0 its markers hold
      nodes:
        producer: {outcome: ok, running_at: "2026-10-26T20:00:08Z"}
        consumer: {outcome: failed, reason: "status did not read running within 60 s"}
```

- Every scheduler node is started in one run, each marker holding that
  run's `began`. `t0` is set to `began`, and the stage to
  `load-started`, only when every node reads running (8.4). A node that
  fails is recorded, nothing is torn down, the exit is 1 and the stage
  stays `injected`; the GM fixes it or stops the game (8.7). A later run
  writes every marker again with its own `began` and restarts every
  scheduler (choice: one T0 for all, as W1 item 7 says; a restart of a
  running scheduler before T0 costs nothing, since outages count from T0).
- Once T0 is recorded, `start-load` schedules the early check (item 5)
  and prints, for each instance with a `planned_at`, the `inject --at`
  command that plants it (`--at now` when `planned_at` is already
  past) (choice: 8.7 and 13 make plantings the GM's own `inject --at`
  calls, not `start-load`'s; printing them, and item 11's head, keep one
  from being forgotten).

**4. Plantings and `inject --at`** (writes: chunk 8a; `inject` for T0;
read by 8b, 11, 12, 13). Master spec 8.4, 8.5, 8.7, 13; access model 5,
7.

```yaml
plantings:                             # every fault instance, fault_instances order
  f1: {plant_at: T0, planted_at: "2026-10-26T19:58:40Z", by: inject}
  f7:
    plant_at: handover-6h
    planned_at: "2026-10-27T08:00:00Z" # from timeline.instances
    timer: {unit: dbagm-fernway-k3x9qa_plant-f7, due: "2026-10-27T08:00:00Z",
            created_at: "2026-10-26T20:01:30Z"}   # null: not scheduled, or replaced by now
    attempts:                          # every run that tried, last last
      - {at: "2026-10-27T08:00:03Z", by: timer, outcome: failed, reason: "<first line>"}
      - {at: "2026-10-27T09:12:44Z", by: gmctl, outcome: ok}
    planted_at: "2026-10-27T09:12:44Z" # the last successful attempt; null until then
```

- `inject` writes every instance's entry when it records `injected`; a
  T0 instance's `planted_at` is that moment, `by: inject` (seed-file and
  parameter instances too: their faults are in place by then).
- `inject <dir> --playground <pg> --at <instant>|now --instance <id>`:
  `--at` and `--instance` go together; `<instant>` as in item 0, or
  `…THH:MMZ`. Refused (exit 1, nothing recorded): a stage other than
  `load-started`; an instance whose fault is not `state` (seed-file and
  parameter faults are planted at render, 6.1); an instant not in the
  future (the hint says `--at now`) or at or after the planned hand-over
  (choice: the loader's "never at or after hand-over" is measured from
  the planned hand-over, 6.1); an instant for an instance already
  planted (re-planting is `--at now`); a T0 instance, the refusal naming
  master spec 8.5: the GM re-plants only a fault whose planting failed,
  and a T0 planting never fails without a teardown (amended 2026-10-26,
  spec-writer's review of W2). `--at now` is bounded only by the
  stage, and the planned-hand-over refusal's hint names it (amended
  2026-10-26, spec-writer's review of W2).
- With an instant: creates the instance's timer (item 5), replacing a
  live one, and records `timer`. With `now`: stops a live timer, runs the
  instance's scripts as `inject` does, records the attempt (`by: timer`
  when run by its timer, item 5; `by: gmctl` otherwise) and, on success,
  `planted_at`. A failing attempt is recorded with the first line of the
  failing output, exits 1, tears nothing down and leaves the stage (8.7;
  the plan's "record-only mode" of `setup_step`).
- **A missed planting** (choice: a safety net beside the persistent
  timers of item 5, D173, should a run still not happen): an instance whose `timer.due`
  (or, with no timer, `planned_at`) is more than 15 minutes past with no
  attempt since is read as missed by `status` and by the checks (items 8,
  11).

**5. The host timer** (writes: chunk 8a, with teardown's removal; read by
11, 12, 13, 15). Master spec 8.4, 8.7, 20; access model 3, 8; the plan's
build-host note (lingering on).

- **Form** (amended by spec D173): one persistent systemd user unit
  pair per scheduled action, written on the host where `gmctl` runs (the
  manager) as `~/.config/systemd/user/dbagm-<game_id>_<action>.timer` and
  `.service`, then `systemctl --user daemon-reload` and `systemctl --user
  enable --now <unit>.timer`:

  ```
  # dbagm-<game_id>_<action>.timer
  [Unit]
  Description=db_audit_gm game <game_id>: <action>
  [Timer]
  OnCalendar=YYYY-MM-DD HH:MM:SS UTC
  Persistent=true
  AccuracySec=1s
  [Install]
  WantedBy=timers.target

  # dbagm-<game_id>_<action>.service
  [Service]
  Type=oneshot
  Environment=DBAGM_GAME=<game_id>
  ExecStart=<python3> <repo>/tools/gmctl <verb> <absolute scenario dir> --playground <pg> <options>
  ```

  `inject --at` replacing a live timer rewrites its two units. A late
  run (`Persistent=true` firing at boot for an action due while the host
  was down) first waits for the game's nodes to run, up to a limit chunk
  8a chooses, then acts or records its failure (D173); a run reaching
  another host's node is chunk 10b's. `<action>` is `plant-<instance>` (run: `inject … --at now --instance
  <id>`) or `early-check` (run: `check … --early-check`). `<python3>`
  and `<repo>` are those of the `gmctl` that created the timer (choice:
  the run must be the same code, from any working directory).
- **Names** (choice): `dbagm-<game_id>_` prefixes every unit of a game;
  game ids never hold `_` (v0.1 W2-A), so `dbagm-<game_id>_*` matches
  that game's units and no other's.
- **The guard** (choice: a stale timer must never act on another game):
  a run with `DBAGM_GAME` set refuses, exit 1, recording nothing, when
  the playground's game id differs or the game is torn down; otherwise
  it records `by: timer`. A timer run refused by the stage (handed over)
  records an attempt `outcome: refused`.
- **Recorded** in `plantings.<id>.timer` and `early_check` (items 4, 8):
  unit, due instant, creation instant.
- **Teardown** (chunk 8a in `teardown.py`), before any Docker object
  (amended by spec D173): stops and disables every
  `dbagm-<game_id>_*` timer and service, removes their unit files and
  their `stamp-` files (`~/.local/share/systemd/timers/stamp-dbagm-<game_id>_*`),
  `systemctl --user reset-failed 'dbagm-<game_id>_*'`, `systemctl --user
  daemon-reload`, then neither `systemctl --user list-units --all` nor
  `systemctl --user list-unit-files` lists `dbagm-<game_id>_*`; a unit left fails the teardown as a labelled object
  does (exit 1, nothing recorded, W3-C) (choice: "nothing of the game
  left" covers its timers, as chunk 12's "nothing labelled (timers
  included)" reads). Without a reachable user manager, a game whose state
  records no timer is torn down with a note; one that records any fails.
- The environment of a run is the user manager's plus `DBAGM_GAME`; a
  playground whose Docker endpoint needs an SSH agent is not supported
  for timer runs in wave 2 (chunk 10 settles the hosts, W3).

**6. Outages and the lost time** (writes: chunk 8b; read by 11, 13).
Master spec 7.1, 8.7, 20; D152; W1 item 7, W1-y ("For chunks 8…").

```yaml
outages:
  read_at: "2026-10-27T09:15:20Z"
  through: "2026-10-27T09:13Z"         # the last minute judged
  lost_minutes: 23
  periods:                             # runs of outage minutes, merged, oldest first
    - {from: "2026-10-27T03:02Z", to: "2026-10-27T03:21Z", minutes: 20,
       causes: ["producer: no summary", "db: no running task"]}
  incomplete: []                       # nodes whose task history may be pruned (D174)
```

- **Span** (choice: the minute T0 falls in is partial on every node, and
  a summary is written within about a second of the boundary, W1-y):
  from the first whole minute after T0 to the last minute M with
  M + 1 min + 15 s at or before the reading, and never past the
  hand-over: the aging ends at `handed-over` (13), so the last hand-over
  check's reading is the last.
- **Outage minute** (8.7): any scheduler node has no `summary
  minute=<M>` line in its log, or any node of the game had no running
  task during part of M by its Swarm task history (how the task history
  is read is chunk 8b's, master spec 20).
- **Readings**: at the early check, at each hand-over check and on
  `status` (8.7). Each reading recomputes from the sources and keeps the
  union with the recorded `periods` (choice: a minute once seen is never
  forgotten, the task history being pruned by Swarm). A reading that
  cannot reach a node leaves the record as it was, and `status` says so.
  `incomplete` lists the nodes whose oldest kept task started after the
  previous reading; `status` reads "at least" for their outages (amended
  by spec D174).
- **Lost time**: `lost_minutes`, the outage minutes in all. It moves the
  earliest hand-over by `max(0, lost_minutes − 30)` minutes (8.7, D152).
  The running time `status` shows is computed (elapsed since T0 less the
  lost time), never stored.

**7. The earliest hand-over** (writes: chunk 8b; read by 8b's refusals,
11's `snapshot` refusal, 13). Master spec 8.4, 8.7, 13; access model 6
(`aging-done`, `at-hand-over`); D152, D161, D175.

```
earliest = max( T0 + M,
                max over instances i of ( max(P_i, T0) + m_i ) )
           + max(0, lost − 30 min)
```

The lost time's excess moves the whole maximum (amended by spec D175,
O103 (a), owner ruling 2026-10-26).

M is `timeline.aging_minimum`, m_i an instance's `aging_minimum`, P_i
its `planted_at`; under the harness override (item 10) M and every m_i
are capped at the override (D161). An instance not yet planted counts
its `timer.due`, else its `planned_at`, and is listed in `waiting_for`;
while `waiting_for` is not empty the earliest hand-over is provisional
and not reached (choice: `aging-done` needs every instance's own minimum
since its actual planting, access model 6). A T0 instance counts from T0
(its evidence needs the load; kept by D175).

```yaml
earliest_handover:
  at: "2026-10-27T12:00:07Z"
  waiting_for: [f7]
  computed_at: "2026-10-27T09:15:20Z"
```

Recomputed from the records at every `status`, check, `inject --at`
and `status --set handed-over`, and written back (13 lists it as
recorded); a stored value is never trusted over a recomputation. A
static game has none: `aging-done` holds from `injected` on (access
model 6).

**8. The early check and the hand-over check** (writes: chunk 8b, the
early check's scheduling chunk 8a; read by 11, 12, 13). Master spec 8.5,
8.7, 11, 13; access model 3, 7.

- **Verbs** (choice: 13 gives both to `check`; chunk 9 owns
  `checks.py` and chunk 8 its own module, so the options are parsed in
  `__init__.py` and run by chunk 8's code, which calls chunk 9's
  `checks.check`, item 9): `gmctl check <dir> --playground <pg>
  --early-check` (the timer's run, which the GM may repeat) and `--handover-check`
  (the GM's, at hand-over). Exit 0 passed, 1 failed, 2 could not run or
  refused; `--handover-check` exits 3 when it failed only on "too soon"
  readings (wait the longest remaining window and run it again).
- **When the early check runs** (scheduled by `start-load` once T0 is
  recorded; 8.5): E = the later of T0 + M/2 and, for every job of the
  rendered `jobs.yaml` files whose first due instant after T0 falls
  before the earliest hand-over, that instant plus 10 minutes; then at
  most the earliest hand-over minus one hour, and at least T0 + 5
  minutes. M and the earliest hand-over are as item 7 computes them at
  `start-load` (the override's cap included); E is not moved later
  (choices: 10 minutes lets a job's run start and log). When an `inject
  --at` brings the earliest hand-over earlier, the early check's timer
  moves earlier so E stays no later than the earliest hand-over minus one
  hour; the T0 + 5 min floor may beat that bound only under the
  test-harness override (amended 2026-10-26, spec-writer's review of
  W2).
- **What both judge** (8.5): (a) every planted instance (`planted_at`
  set) by its sealed check (item 9): it passes when the exit equals the
  answer key's `at_handover` (1, present) (choice: the answer key states
  what "present" exits); (b) in a scheduler game, every scheduler node's
  `/run/scheduler/status` reads `running `, every stream key current in
  its schedule has a `key` line in the scheduler's last complete minute
  (W1 item 7: one per current stream key, zeros included), and every job
  whose first due instant since T0 is more than 10 minutes past has a
  `run … phase=start` or `skip` line at or after it and no `job …
  next=never` line (choice: "running" means the program runs the key,
  not that its calls succeed, since errors, refused connections and low
  rates can be the evidence); (c) every node healthy as
  `deploy.service_health` reads it (choice: the validators judge
  envelopes, and under an exhaustion fault one may read red, 11 rule 6);
  (d) the outages so far (item 6), recorded, never a failure on their
  own: the GM judges them (8.7). A static game's hand-over check judges
  (a) and (c) only.
- **Failures**: a planted instance not passing, a missed planting (item
  4), a scheduler or key not running, a node not healthy. At the early
  check a "too soon" reading is recorded and is not a failure; at the
  hand-over check it fails the check (choice: 8.5 hands over only a game
  whose planted faults read present; 11 rule 3, the GM waits the window).
- **Record**, both kinds alike:

  ```yaml
  early_check:
    timer: {unit: dbagm-fernway-k3x9qa_early-check, due: "2026-10-27T04:00:07Z",
            created_at: "2026-10-26T20:00:09Z"}
    result: <check record>              # the last run's; null until it runs
  handover_checks: [<check record>, …]  # every run, last last; static games too
  # <check record>:
  at: "2026-10-27T12:05:00Z"
  passed: false
  faults:                               # planted instances, fault_instances order
    - {instance: f3, fault: <id>, verdict: too-soon, exit: 3, remaining: 600, line: "<first line>"}
  not_planted: [f7]                     # due later (early check only)
  schedulers: [{node: producer, running: true, keys: {orders.insert: true}, jobs: {close-day: not-due}}]
  nodes: {db: healthy, producer: healthy}
  lost_minutes: 23
  failures: ["f3 <id>: too soon to tell, 600 s of its window remain"]
  ```

  A check run under the harness override carries `override: <duration>`
  (item 10).

**9. "Too soon to tell"** (writes: chunk 9; read by 8b, 12, 13, 14).
Master spec 11 (rule 3), 13; D124, D165; W1 item 4; the answer-key
template's `at_handover` comment.

- **Script contract** (choice: one parseable form for chunk 9 to read
  and chunk 14's scripts to print): exit 3, the first output line
  `remaining=<N>` then optionally a space and free text, N an integer
  number of seconds, at least 1. An exit 3 whose first line does not
  match is read as an error (choice: a wait with no length gives the GM
  nothing to act on).
- **`gmctl check`'s line**: `<instance> <fault-id>: too-soon — <N> s of
  the window remain: <free text>` beside the `fixed`, `present` and
  `error` lines of v0.1 W3-A.
- **`gmctl check`'s exit** (choice: a definite answer outranks an
  undetermined one): 2 when any errored, else 1 when any is present, else
  3 when any is too soon, else 0. A refusal still exits 2.
- **What chunk 8 calls** (choice: chunk 8 judges a subset against
  `at_handover`, so it needs the raw exit): `checks.check(scenario_dir,
  playground, docker=None, instances=None)`, `instances` a list of
  instance ids to run (in `fault_instances` order; `None` all);
  `CheckLine` gains `returncode` (int, `None` when the check could not
  start) and `remaining` (int seconds, for `too-soon` only); its
  `verdict` is one of `fixed`, `present`, `too-soon`, `error`;
  `checks.TOO_SOON = 3`.
- The checks connect as the GM check role through `check-psql` (W1 item
  8, W1-x), one at a time; the reserve of two leaves room for a timer's
  early check beside a run by hand (W1-x).

**10. The test-harness override of the aging minimum** (G6; writes:
chunk 8a; read by 8b, 11, 15b). Master spec 11 ("The rehearsal"); spec
D156, D161; plan "Read first" ("No fake time anywhere") and chunk 8a.

Fixed by the sources:

- It is for one game, set only by the harness scripts
  (`tools/tests/rehearsal.sh`, chunk 11's snapshot and restart run),
  never by a GM, and never named in the GM skill or `gmctl.md`.
- It gives a shorter aging minimum that the earliest hand-over counts
  from, and caps each instance's own aging minimum at it wherever the
  earliest hand-over or the hand-over check counts it (D161; item 7).
- It is recorded in the local implementation and shown first by
  `status`, above everything else, the failure head included.
- It shortens the wait, never a clock: no timestamp, marker, rendered
  instant or planting time changes.

Following from those (choices, so the form can be checked against them):
it is in place before `start-load`, which computes the early check's time
from the capped minimum (item 8); `gmctl --help` and the verbs' help do
not show it, since a GM reads them; every record computed under it
(`earliest_handover`, each check record) carries `override: <duration>`,
so a record read later is never mistaken for a game's.

**The form** — how the harness sets it, where it is recorded, its key —
is **chunk 8a's choice, recorded as a W2 addendum** before chunk 11
starts.

**11. `status` and `status --set handed-over`** (writes: chunk 8b; read
by 11, 13). Master spec 8.5, 13, 16; access model 7, 9.

- **Order**: the override line (item 10); then the head, every
  unresolved failure and the outages: a `start-load` attempt failed with
  T0 unrecorded; an instance with its last attempt failed, missed, or
  `planned_at` past with no timer and no planting; the early check
  failed (until a hand-over check passes); the last hand-over check
  failed; `lost_minutes` above 0; then the game's lines as today, and
  the aging's progress, the lost time, the earliest hand-over (with
  `waiting_for`), the planned hand-over, the shift and the customer's
  zone, the plantings and timers, the snapshot and the restarts (13). A
  static game shows no aging lines. Its words are chunk 8b's.
- **`status --set handed-over`** (13), in a scheduler game: the earliest
  hand-over reached (not provisional, now at or after `at`); the last
  `handover_checks` entry passed and was run at or after the earliest
  hand-over (choice: a check before it judges a younger system than the
  one handed over); from chunk 11a on, `snapshot.status` is `taken` or
  `not-fitting`. In a static game: the last hand-over check passed, and,
  from chunk 11a on, the snapshot. Until chunk 11a, chunk 8b enforces the
  first two conditions only (amended by spec D172). Each
  refusal says which condition and, for the first, when (access model 7).
- **The snapshot record** (choice: chunk 8b reads it before chunk 11
  writes it): `state.yaml` `snapshot: {status: taken | not-fitting, at:
  <instant>, …}`; chunk 8b reads `status` only, chunk 11 owns the rest.
  The snapshot condition takes effect with chunk 11a (amended by spec
  D172).

**12. Wave 2 coordination** (for the driver and chunks 7, 8, 9)

- Chunks 7 and 9 side by side: 7 writes item 1 and the `render` row of
  `gmctl.md`, 9 item 9 and the `check` row. Chunk 8, once both have
  merged, owns items 2 to 8, 10, 11 and the rows of `start-load`,
  `inject --at`, `check --early-check`, `check --handover-check` and
  `status --set handed-over`. `localimpl.py` and `inject.py` pass from 7
  to 8; `checks.py` stays 9's (8 calls it). `checks.CHECK_STAGES`
  follows `state.DEPLOYED_STAGES` once 8 adds `load-started`.
- Chunk 8's tests use a fake timer (the plan's); no smoke run creates a
  real one before chunk 12's `smoke-load.sh`.
- Chunk 8's Files gain `tools/tests/smoke.sh`: it runs `check
  --handover-check` before `status --set handed-over`; chunk 11a adds the
  snapshot before it (amended by spec D172).

**Open points for spec-writer** (settled 2026-10-26: 1 by D172, 2 by
D173, 3 by D174; the owner's O103 ruling on item 7 by D175; the text
below kept as sent)

1. **`smoke.sh`'s hand-over across waves 2 and 3.** `smoke.sh` runs
   `status --set handed-over` straight after `inject` (line 198). After
   chunk 8b that needs a passed hand-over check and the snapshot taken or
   recorded as not fitting (13), but nothing writes a snapshot record
   before chunk 11 (wave 3), and `smoke.sh`, which chunk 8 must pass, is
   outside chunk 8's Files. Options: (a) chunk 8b enforces the earliest
   hand-over and the hand-over check, chunk 11a adds the snapshot
   condition with its verb, and chunk 8's Files gain
   `tools/tests/smoke.sh` to run `check --handover-check` before `--set
   handed-over`; (b) chunk 8b enforces all three and wave 2's gate runs
   `smoke.sh` without the hand-over; (c) chunk 8 writes a provisional
   snapshot record. Recommend (a): each condition arrives with what
   satisfies it, and the gate keeps testing the hand-over.
2. **Transient timers do not survive a host reboot.** The plan fixes
   `systemd-run --user`; its units live under `/run` and vanish when the
   host or the user manager restarts, while 8.7 has the aging resume after
   a host restart: a planting or early check due then never runs.
   Options: (a) keep them and rely on item 4's "missed" reading, the GM
   re-planting at hand-over when the instance's minimum can still be
   reached (8.5); (b) persistent user units of the same names
   (`~/.config/systemd/user/dbagm-<game_id>_*.{timer,service}`,
   `Persistent=true`, enabled; teardown disables and removes them), so a
   missed action runs at boot. Master spec 20 leaves the timer's form to
   the build, so (b) changes only the plan's line. Recommend (b), keeping
   (a)'s reading as the safety net.
3. **Swarm keeps five tasks per slot.** The task history outages are read
   from (8.7) is pruned to `task-history-limit` (5 by default) per slot,
   so a node restarting more than five times between two readings loses
   outage minutes. Options: (a) accept: readings keep the union (item 6),
   a node whose oldest kept task started after the previous reading is
   listed in `incomplete`, and `status` reads "at least"; (b) raise the
   swarm's `--task-history-limit`, a swarm-wide setting touching the
   host's other stacks and the VPS, for the owner; (c) a per-minute host
   timer sampling task states. Recommend (a): every aged game's
   schedulers record their own outages exactly in their summaries, and a
   node crash-looping that often fails the next check as unhealthy.

### Dispatch

- Chunk 6 (`v0.3-c6-pgbouncer`): dispatched 2026-10-26, before W2 (reads
  only W1 items 3, 5, 6, 8 and W1-x).
- Capture W2 committed 2026-10-26 (43d8ecd), drafted for the driver.
- W2's three open points sent to `spec-writer` 2026-10-26 (all three
  touch chunk 8 only, which waits on 7 and 9), with a review of W2's
  (choice)s for any that changes stated behaviour.
- Chunks 7 (`v0.3-c7-render`) and 9 (`v0.3-c9-checks`): dispatched
  2026-10-26, side by side, after W2's commit; a `spec-writer` revision
  touching W2 items 0, 1 or 9 is passed to them while they run.

### W2 addenda — choices chunk 9 made

Where W2 item 9 was silent, recorded from chunk 9 (`v0.3-c9-checks`,
merged as 829d1c8), 2026-10-26.

- **Too-soon line with no free text**: `<instance> <fault-id>: too-soon —
  <N> s of the window remain`, with no trailing `: `.
- **"First output line"** is the first non-empty line, standard output
  first, then standard error, as v0.1 W3-A's reason line; the text after
  `remaining=<N> ` is what the line shows.
- **Exit 3 without a valid `remaining=` line** is an error, reason
  `exit status 3 (too soon) without a first line remaining=<N> (N
  seconds, at least 1): <first line>` (or `, no output`).
- **`checks.check(..., instances=)`**: an id that is not a fault instance
  is refused as a `GmError` `not a fault instance of the scenario: <ids>`
  before anything runs; an empty list runs nothing and exits 0.
- **`CHECK_THRESHOLD` "as written"** is the text of the loaded YAML
  number (`0.50` passes as `0.5`); an invalid window duration is refused
  (the loader rejects it already).
- **Bricks without the check role** (`postgres` before 0.3.0, still in
  the `pg-*` faults' `applies_to`): when `/usr/local/lib/gm/check-psql` is
  absent the scripts connect as `postgres` over the local socket, as in
  v0.2 (faults never bump, master spec 6.6); on 0.3.0 that path is never
  taken.
- **`pg-hba-trust-remote`'s live probe** stays a TCP login as `dba` with
  no password (the probe is what is judged), using
  `superuser_reserved_connections`; if players' superuser sessions fill
  those, the probe fails and the `pg_hba_file_rules` read as `gm_check`
  decides (the script's header says so). Accepted by the driver.
- **`checks.CHECK_STAGES`** is unchanged; it must follow
  `state.DEPLOYED_STAGES` once chunk 8 adds `load-started` (W2 item 12).
- **Outside its Files**: the `check` help string in `tools/gm/__init__.py`
  mentions exit 3.
- **Left**: the fixtures' own `fixed.sh` scripts under
  `tools/tests/fixtures/` still connect as `postgres` (outside chunk 9's
  scope).

### Capture W2-a — chunk 6 outcomes (the `pgbouncer` brick 0.1.0; read by 11, 12, 14, 15)

Recorded 2026-10-26 from chunk 6 (`v0.3-c6-pgbouncer`, merged as
a7c9efb: 9916b2b 6a, 6f0b0d0 6b), `bricks/pgbouncer/brick.yaml` and
`docs/gm.md`. W1 items 3, 5, 6, 8 and W1-x hold; what they left open:

- **The GM's settings win.** PgBouncer reads
  `/run/pgbouncer-conf/pgbouncer.ini`, written by
  `/usr/local/lib/gm/pgbouncer-conf` (as `pgbouncer`) at every start and
  reload: the players' `/etc/pgbouncer/pgbouncer.ini` line for line, plus
  `%include /usr/local/lib/gm/pgbouncer-gm.ini` at the end of each
  `[pgbouncer]` section (listener `*:6432`, socket `/run/pgbouncer`,
  `logfile`, `auth_*`, `admin_users = pgbouncer`, `stats_users = dba`).
  `%include` lines in the players' file are commented out (line count
  kept) and the validator is red on them. Seeds (scenario authors, chunk
  15) must not carry these settings: they never take effect.
- **Reload**: `gm-reload-pgbouncer` tries the files on a throwaway
  PgBouncer (`/usr/local/lib/gm/pgbouncer-check`, no TCP listener, a
  private socket) before `RELOAD`, and refuses, "NOT reloaded", exit 1,
  with PgBouncer's errors at the players' line numbers (a `RELOAD` of a
  broken file resets every setting, the GM's included); the validator
  runs the same check.
- **Authentication**: `auth_type = hba` with the protected
  `/usr/local/lib/gm/pgbouncer_hba.conf`: `pgbouncer` by `peer` over the
  local socket to the console only, every other role by
  `scram-sha-256`. So a database node's `pg_hba.conf` must admit the
  roles coming through the pooler (and `pgbouncer_lookup` to `postgres`)
  by `scram-sha-256`, never `md5` or `password` (scenario and fault
  authors, chunks 12, 14, 15).
- **Log** `/var/log/pgbouncer/pgbouncer.log` on volume `pgblog`
  (`pgbouncer:pgbconf` `2750`, the file `0640`), readable by players
  through group `pgbconf`. The health check stops connecting once
  PgBouncer has answered once in the container, so the log carries no
  probe lines.
- **Envelopes** (chunk's choice): `max_db_connections` default 0 (no
  limit of PgBouncer's own), envelope 0..200; `default_pool_size` 1..50,
  `max_client_conn` 10..500, `reserve_pool_size` 0..20, `pool_mode`
  `session` or `transaction` (`brick.yaml`). Disk reservation 256M,
  growth 4M an hour, provisional until chunk 15b.
- **No `dba_password` on the pooler node**: players use `dba`'s password
  from the bastion's `~/.pgpass`.
- **Stop signal** SIGQUIT (s6 `down-signal`): 1.24's SIGTERM waits for
  every client.
- **Image and footprint**: 182 MB; at rest 4.7 MiB of its 64M limit, CPU
  0.01 %; Debian's PgBouncer 1.24.1-1+deb13u2, s6-overlay 3.2.3.2; runs
  as `pgbouncer` 991:991, group `pgbconf` 992.
- **Known limits** (`docs/gm.md`): `pgbouncer_lookup` holds no reserve,
  so a pooled login needing a lookup fails when the server's ordinary
  slots are full, `dba`'s console included (sessions already open carry
  on; the sealed checks, as `gm_check` on the database node, are not
  affected); `[users]` settings are not held to an envelope; no TLS; a
  small race between the wrapper's check and `RELOAD`. No catalog fault
  names `pgbouncer` yet (chunk 14).

### W2 addenda — choices chunk 7 made

Where W2 item 1 was silent, recorded by chunk 7 (`v0.3-c7-render`; 7a
9b2c945, 7b 590d225, merge 386092b), 2026-10-26. Accepted by the driver.

- A timeline change `at: T0` is rendered as the render's own instant
  (`rendered_at`): the load starts only after render, and the program
  applies at start every change at or before now.
- The seed survives a re-render but not a refit: `fit` rewrites
  `implementation.yaml` without `timeline:`, so the next render draws a
  new seed. Accepted: nothing is deployed before render, so no player has
  seen the old seed.
- The bastion files render rewrites are the seed files of the `bastion`
  node holding `{{customer_timezone}}`, found at fit from their content; a
  file gaining the placeholder later makes render refuse ("seed files
  changed since gmctl fit: fit again").
- The rendered `jobs.yaml` has no header and no comments (players read
  it); the rendered `schedule.yaml` has a two-line GM header, its lists in
  flow style.
- Render prints `planned hand-over <instant>, shift <+N>, customer's time
  zone UTC+N (Etc/GMT-N)` (a static game: `… (no scheduler node: nothing
  shifted)`), and `  warning: …` when the planned hand-over is earlier
  than now plus item 7's formula with no time lost.
- Directory seed entries and `seed.modes` landed in 7a, not 7b (the
  fixture's scheduler cannot be fitted without its `builders/` entry).
  A directory entry's files take that entry's `seed.modes` mode; render
  refuses when the seed configs differ from what it would derive.
- Write policy: every node gets `GM_WRITE_POLICY` and
  `GM_WRITE_OVERRIDES` after `TZ`; a node with no `write_policy` is
  `fixable`.
- Role secrets come from each scheduler's `schedule.yaml`
  `connections[].role`, in first-use order; a role named by two
  schedulers is one secret, mounted on each. `only_with_role` honoured:
  the lookup secret only on games with a `pooler` node (fixture-audit: 7
  secret files, 13 configs and secrets; counts updated in `smoke.sh` and
  `test_{deploy,fit,state,teardown}.py`).
- `load-data` sets each role's password on the node its connection
  targets when that node's role is `database`, otherwise (a pooler) on
  every `database` node, as a SCRAM-SHA-256 verifier with
  `log_statement`, `log_min_duration_statement` and
  `log_min_error_statement` off for the session. It only sets the
  password: the data must create the role (a missing role fails the step
  and tears the game down); it never makes a role `LOGIN`.
- Left: no catalog scenario has a scheduler node yet, so role secrets and
  `load-data` on a real scheduler game are first exercised by chunk 12 or
  15; `fixture-v03-refusals`' `data/db.sql` creates neither `shop_app`
  nor `shop_reports` (unit tests only); the GM skill's `SKILL.md` step 6
  still shows `render` without `--handover` (chunk 13).

### W2 addenda — choices chunk 8 made

Where W2 was silent, recorded by chunk 8 (`v0.3-c8-aging`; 8a 7b20533,
8b c9ddfe5, merge 4b1f85f), 2026-10-26. Accepted by the driver.

- **The override's form (item 10, G6):** `gmctl start-load <dir>
  --playground <pg> --test-aging-minimum <duration>`, hidden from
  `--help`, accepted from 1m up to (not including) the scenario's aging
  minimum; recorded in `state.yaml` as `test_harness_override:
  {aging_minimum, set_at}` (a later `start-load` before T0 replaces it
  when given the option, keeps it otherwise); every `earliest_handover`
  and check record carries `override: <duration>`; `status`'s first line
  reads `TEST HARNESS OVERRIDE: this game's aging minimum is shortened to
  <d> (a test run of the tools, never a game for players)`.
- **The late run's bound (item 5, D173):** 600 s (`aging.LATE_RUN_WAIT`),
  polled every 10 s until every node has a running container (running,
  not healthy: an exhaustion fault may read unhealthy); applied to every
  timer run (an on-time run returns at once); past the bound it acts and
  records the outcome. `gmctl.md` says "up to 10 minutes".
- `start-load`'s in-node script waits up to 60 s for `running <instant>`
  at or after T0 (a re-run does not read the old process's status); exec
  timeout 150 s.
- Task history: `docker service ps -q --no-trunc`, `docker inspect --type
  task`, then the container's StartedAt/FinishedAt; a task whose
  container is gone counts from its creation, a dead one ends at its
  status timestamp; minutes before a node's oldest kept task are not
  judged by its history (lower bound, D174); `incomplete` is sticky.
- A reading that cannot reach a node leaves the record unchanged and adds
  `outages.unread: {at, reason}`; `status` heads `OUTAGES NOT READ`.
- The early check's timer not created: `early_check.scheduling_failed`
  recorded, T0 kept, `start-load` exits 1, `status` heads it.
- Moving the early check: the new due is the latest of (the current due
  capped at the earliest hand-over minus 1 h), T0 + 5 min and now + 1 min;
  it moves only before its first result, and also after an `--at now`
  planting. An early-check timer run refused at hand-over records
  nothing (refused attempts are kept for plantings only).
- An `inject` replay at `injected` does not rewrite `plantings` (a T0
  `planted_at` is the first `inject`).
- A stale timer's run exits 1 for `inject` and `check` (item 5); other
  `check` refusals exit 2.
- Units: the `.service` has `[Unit] Description=`; replacing a live timer
  rewrites both units, then `daemon-reload`, `enable --now`, `restart`;
  ExecStart doubles `%` and `$` and double-quotes a word with a space.
  Teardown runs `reset-failed` and `daemon-reload` only when the game has
  units; `list-unit-files` exiting 1 with no match reads as none; unit
  files in the unit directory count too.
- An unscheduled planting (no timer, planned instant past) heads `status`
  and fails both checks at once; a missed one (timer due) after 15 min.
- Checks: `at_handover` defaults to 1; a stream's current key is its
  initial key changed by every timeline `set: {key}` at or before the
  minute's start; a job has "run" once a `run … phase=start` or `skip`
  line is stamped at or after its first due instant.
- `status`: the aging lines follow the secrets block; the hand-over check
  line shows in every game; snapshot and restart lines only once chunk
  11's records exist; `smoke.sh`'s secrets count stops at the next
  two-space line.
- The state lock (item 0) is `localimpl.state_lock`, `update_state`,
  `enter_stage`; every `state.yaml` writer takes it.
- Outside its Files: `tools/tests/test_checks.py` (one regex:
  `load-started` joins `CHECK_STAGES`, item 12), `tools/tests/test_deploy.py`
  (no `tools_password` in fixture-audit's status, RG-3), a new
  `tools/tests/fakebin/systemctl`.
- Left: no real systemd timer created yet (real unit semantics and
  `restart` re-arming a changed `OnCalendar`: chunk 12's
  `smoke-load.sh`); the start script, the scheduler log reading and real
  Swarm task JSON have met only the fake engine (first real scheduler
  game: chunk 12 or 15); a task on another host falls back to its
  creation time (wave 3); `status` at `load-started` runs one exec per
  scheduler plus inspects; the GM skill's `SKILL.md` (chunk 13).

### Wave gate — 2026-10-26

Run on `v0.3-w2` (head e896697, then 44227a3) on armenelos (Debian 13,
Docker 29.9.1, single-node swarm), idle apart from other projects'
long-running containers (`llmward-*`, `ollama`: none of the game's), by
a `coding-executor`; every docker step under the host lock, one at a
time. Step logs: the driver's scratchpad, `gate-w2/`.

| Step | Result | Duration |
|---|---|---|
| Unit suite | 533 OK; 537 OK after 44227a3 | 71 s |
| Scheduler unit tests (in its image) | 60 OK | 75 s |
| `sh -n` on every shell file | 108 files, 0 failed | — |
| `perl -c` on every Perl file | 7 files, 0 failed | — |
| Loader: every brick, fault, scenario and fixture | 24 definitions (the new one: `pgbouncer`), plus 12 inside fixtures; 0 with problems | 1 s |
| Stack test `postgres` 0.3.0 | all checks passed (131) | 74 s |
| Stack test `bastion` 0.3.0 | all checks passed (71) | 62 s |
| Stack test `prometheus` 0.2.0 | all checks passed (131) | 78 s |
| Stack test `postgres-exporter` 0.2.0 | all checks passed (103) | 99 s |
| Stack test `grafana` 0.2.0 | all checks passed (119) | 140 s |
| Stack test `scheduler` 0.1.0 | all checks passed (95) | 778 s |
| Stack test `pgbouncer` 0.1.0 | all checks passed (103) | 97 s |
| `smoke.sh` | 52 passed (and after 44227a3) | 25 s |
| `smoke-monitoring.sh` | 43 passed (and after 44227a3) | 47 s |
| `smoke-scenario.sh bookshop-new-server` | 16 passed, 2 failed; 18 passed after 44227a3 | 21 s |
| `smoke-scenario.sh fernway-clinics-monitoring` | 15 passed, 2 failed; 17 passed after 44227a3 | 29 s |

`sh -n` counted 97 files in wave 1: the new ones are chunk 6's and chunk
8's (`fakebin/systemctl`), plus `grafana-files`, a sourced file without a
shebang now counted. Every stack and smoke run tore down with nothing
left, and no `dbagm-*` user unit or unit file. Image sizes (armenelos,
2026-10-26): postgres 0.3.0 262MB, bastion 0.3.0 185MB, prometheus 0.2.0
488MB, postgres-exporter 0.2.0 165MB, grafana 0.2.0 866MB, scheduler 0.1.0
172MB, pgbouncer 0.1.0 182MB (new).

Finding, traced to chunk 9: `pg-join-index-missing` and
`pg-table-autovacuum-off` connect to the scenario's database as
`gm_check`, which had no `CONNECT` there (both scenarios' data revoke it
from `PUBLIC`); the checks read `error`. A check needing more than the
role's privileges is a build finding (master spec 7.3), so it went to the
owner: **`gmctl load-data` grants the check role `CONNECT` on every
non-template database after the load** (spec D176, 58063a0; plan v8;
master spec 7.3 amended; the scenarios' data granting it, and those
checks staying on `postgres`, declined). Fix 44227a3 (`tools/gm/inject.py`,
`tools/tests/test_inject.py`; chunk 7's step), then the four smoke runs
re-run green. No intent register, so there is no wave sync.

### Dependency check and PgBouncer's source — 2026-10-26

`security-advisor`'s post-change check over the wave's diff (only
`bricks/pgbouncer/Dockerfile` changed among the Dockerfiles): Debian 13's
`pgbouncer` 1.24.1-1+deb13u2 has six open CVEs with no trixie fix
(CVE-2026-6668, -19888, -6669, -107349, -107348, -107350; Debian bug
1148946), fixed upstream in 1.26.0/1.26.1; as configured, reachable only
as a player's denial of service on their own pooler (port 6432 never
published, CPU capped at 0.25), CVE-2026-107350 not reachable (the lookup
secret is root-only). s6-overlay 3.2.3.2 clean; openssh and sudo are the
same versions as in bastion and postgres (their `no-dsa` items go to a
later triage). No `.tech` existed, so nothing checked the platforms.

Owner's rulings, 2026-10-26:
- **PgBouncer from the PostgreSQL apt repository, `1.26.1-1.pgdg13+1`**
  (spec D177, 85848ed; plan v9; master spec 7.2 amended). Declined:
  keeping 1.24.1 with an accepted risk. Fix c43fbc9 by a
  `coding-executor` (chunk 6's brick, still 0.1.0): PGDG source as in
  the postgres and bastion bricks, the build asserting the upstream and
  package versions and no PostgreSQL server; `postgresql-client` now
  PGDG's 18; accounts unchanged (pgbouncer 991:991, pgbconf 992).
  1.25/1.26's changes checked against the brick: `RELOAD` now reports
  failure on the console, so `gm-reload-pgbouncer` prints PgBouncer's
  logged reasons on that path; SIGQUIT is still the immediate shutdown;
  `KILL_CLIENT` admin-only (gm.md's `admin_users` row); nothing uses
  `-R`, `SUSPEND`, `SHOW FDS` or a leaking `search_path`. Re-run under the
  host lock: build, stack test 103 passed (98 s), unit suite 537 OK,
  `smoke.sh` 52 passed, nothing left. Image 182 MB; at rest 11.1 MiB of
  64M (was 4.7 MiB; 1.26 or run-to-run, not established).
- **A `.tech` written now**, on the wave branch, covering the seven
  bricks' platforms (`security-advisor`, cold start).
- **Merge wave 2 into `main`** once both are in.
- `.tech` written ff01696 (`security-advisor`, cold start): Docker
  Engine (armenelos 29.9.1, the VPS 28.5.1), debian:13-slim 13.7,
  s6-overlay 3.2.3.2, OpenSSH 10.0, sudo 1.9.16p2, PostgreSQL 18.6 (PGDG;
  the minor floats), libpq 17.11 (scheduler), PgBouncer 1.26.1, nginx
  1.26.3, Prometheus 3.13.5, postgres_exporter 0.20.1, Grafana 13.2.4,
  Python 3.13.5; no lockfiles. `cve-watch check`: PgBouncer 1.26.1,
  PostgreSQL, Prometheus, Grafana, Docker 29.9.1 clean; 46 findings at or
  above medium on Debian's OpenSSH, sudo, nginx and Python (mostly fixed
  by Debian's backports, which NVD cannot see; a few `no-dsa`) and on the
  VPS's Docker 28.5.1 (real: CVE-2026-34040 8.8, CVE-2026-42306,
  CVE-2026-33997, CVE-2026-41568; fixed by 29.9.1). Nothing accepted, no
  `SECURITY_TODO.md`.

### State at the end of 2026-10-26 (for the next driver)

- **Wave 2 gated and merged into `main`** on the owner's word (merge
  commit named in the waves table's next update). Chunks 6, 7, 8, 9
  merged; gate fixes 44227a3 (D176) and c43fbc9 (D177); `.tech` ff01696.
  After the merge: worktree `/home/bastien/work/db_audit_gm-wt/v0.3-w2`
  and branches `v0.3-w2`, `v0.3-c6-pgbouncer`, `v0.3-c7-render`,
  `v0.3-c8-aging`, `v0.3-c9-checks` removed.
- Owner decisions taken in wave 2: D175 (O103, the lost time moving the
  whole maximum), D176 (the check role's `CONNECT`, granted by
  `load-data`), D177 (PgBouncer 1.26.1 from PGDG); the `.tech` written.
  D172–D174 (spec-writer, W2's open points). Plan v9. Nothing pending with
  the owner except what wave 3 needs below.
- **For wave 3** (chunks 10, 11, 12): G4 (the VPS) is open. Before the
  VPS joins the swarm, its Docker Engine 28.5.1 has real CVEs (above):
  `security-advisor` recommends upgrading it to 29.9.1, which per G4 and
  the VPS rule waits for a filetstudio.com downtime scheduled with the
  owner beforehand. Ask the owner at wave 3's start. Re-check G2 and G3
  then too.
- Carried into wave 3 and later:
  - chunk 12's `smoke-load.sh` is the first real systemd timer and the
    first real scheduler game: it exercises chunk 8's units on the real
    user manager, `restart` re-arming a changed `OnCalendar`, the start
    script, the scheduler log reading and real Swarm task JSON, and chunk
    7's role secrets and `load-data` on a scheduler game;
  - chunk 10: a task on another host falls back to its creation time in
    the outage reading (chunk 8); a timer's run must reach the exec
    verb's per-host contexts (D173, in its plan text);
  - chunk 11a: the snapshot condition of `status --set handed-over`, and
    `smoke.sh` taking the snapshot before it hands over (D172);
  - chunk 12 or 15b: the scheduler's error lines are not rate-limited
    (from wave 1);
  - chunk 13: the GM skill's `SKILL.md` step 6 shows `render` without
    `--handover`; the test-harness override is never named there;
  - chunk 14: new faults' checks may rely on the check role's `CONNECT`
    (D176); no PgBouncer fault may rely on a leaking `search_path` (D177);
  - a later triage of the `.tech` findings on Debian's packages.
- Next: wave 3 from `main`, in a fresh session (the log's last section
  is what it needs).

## Wave 2 — merged 2026-10-26

Merged into `main` on the owner's word, `--no-ff`, as 22ff556, with the
gate's figures in the message. The wave worktree and the branches
`v0.3-w2`, `v0.3-c6-pgbouncer` to `v0.3-c9-checks` removed.

## Wave 3 — started 2026-10-26

Chunks 10, 11, 12 (κ = 3). Branch `v0.3-w3`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.3-w3`, cut from `main` at 22ff556.
Rulings since the plan's v9: none from the spec (D177 is the last); the
owner's word on the VPS's own swarm (below) goes to `spec-writer` as
D178.

### Gates checked at the start

- G2 (network at build time), hand check 2026-10-26: Debian's trixie
  `Release`, the PostgreSQL apt repository's `trixie-pgdg` `Release`,
  GitHub's s6-overlay, Prometheus and `postgres_exporter` releases and
  `dl.grafana.com` answer 200. Cleared for wave 3.
- G3 (Docker host in swarm mode), hand check 2026-10-26: armenelos,
  Docker Engine 29.9.1, swarm active. Cleared for wave 3.
- Host resources on 2026-10-26: 5.5G of memory available on armenelos,
  10G free on `/`; 26G free on the VPS.
- G4 (the VPS), done by the driver on 2026-10-26, under the VPS rule:
  - the owner upgraded the VPS's Docker Engine to 29.9.2 beforehand
    (28.5.1 until then; `security-advisor`'s CVEs, wave 2's `.tech`), and
    made its Caddy a service shared by every app on the VPS
    (`~/README_SHARED_CADDY.md` there, read before any change: one site
    file per app, validate then graceful reload, never a restart);
  - `tailscale status` logged in on both hosts (armenelos 100.78.85.1,
    the VPS `vps-5718ad52` 100.126.172.117); the VPS's ufw allows all of
    `tailscale0`;
  - the VPS's engine was in its own single-node swarm (bound to
    127.0.0.1; no services, secrets or configs; overlay networks
    `ingress` and `easypanel`, an Easypanel leftover). G4 says to stop and
    ask: the owner allowed it to leave (2026-10-26);
  - armenelos' swarm, bound to its Wi-Fi address 192.168.1.32 and empty,
    re-created on Tailscale (`--advertise-addr`, `--listen-addr`,
    `--data-path-addr` 100.78.85.1); the ingress network re-created with
    MTU 1230 (1280 less VXLAN's 50 bytes), no game running;
  - the VPS left its swarm and joined armenelos' as a worker, bound to
    100.126.172.117: `docker node ls` shows armenelos (leader, 29.9.1)
    and `vps-5718ad52` (worker, 29.9.2); `docker -H ssh://vps version`
    answers (29.9.2); 26G free there;
  - **incident**: the swarm leave and join wiped Docker's embedded DNS
    records for every running container on the VPS. Caddy could no longer
    resolve `crochethub-filetstudio`, and filetstudio.com answered 502
    from about 15:28 to 15:34 UTC. The auto-mode classifier refused the
    driver's container restarts, so the owner restarted `caddy`,
    `crochethub-filetstudio` and `infinite-flow-web` (the sites back),
    then `crochethub-mongodb` and the app again (its compose alias
    `mongodb` unresolved until then); checked afterwards: both names
    answer 200, the app logs no MongoDB error. Lesson (in the driver's
    memory, offered for the VPS's host notes): a swarm membership change on
    the VPS is a downtime, like a Docker upgrade, followed by restarting
    every container and checking the app reaches its database;
  - the VPS node set to `drain` by the owner (the classifier refused the
    driver): the bricks' stack tests carry no placement constraint and
    would otherwise schedule tasks there, opening a host-mode port on the
    VPS's public address. **Rule for this wave**: the VPS stays drained;
    only chunk 10b's two-host try and the wave gate's two-host smoke run
    set it `active`, for their run only, and drain it again after
    (`docker node update --availability active|drain vps-5718ad52`, run
    by the owner if the classifier refuses it);
  - G4 cleared 2026-10-26.
- Out of date in the plan and `.tech`: the VPS's engine version (28.5.1
  there, 29.9.2 now). Sent to `spec-writer` (G4's text, D178) and
  `security-advisor` (`.tech`).

### Order

- Chunk 12 reads no W3 item and depends only on merged chunks: dispatched
  at once.
- Capture W3 (hosts, per-host contexts, where volumes live) is drafted
  and committed before chunk 10 starts; chunk 11 once chunk 10 has
  merged (in-wave edge 10 ──> 11).

### Capture W3 — hosts, placement and per-host contexts (chunk 10; read by 11, 12, 13, 15)

Recorded 2026-10-26, before any code; drafted for the wave driver from
the plan's (v10) chunks 10 and 11, "Read first", G4, G5 and "Workflow
deltas", master spec 6.4, 7.5, 8.6, 10, 12, 13, access model 7, D125,
D128, D149, D156, D159, D173, v0.1's W2-A, W2-B and W3-C
(`playground.yaml`, `implementation.yaml`, the names and labels,
`docker.for_local_dir`, the teardown record), v0.2's W3-A (`fit` reading
the images from the engine, D102), this version's W1 items 3 and 6 (the
growth per hour, the snapshot contract inside a node) and W2 items 0
and 5 (the records' homes, the host timer), G4's facts (wave 3's start,
above), and the code on `v0.3-w3` at 4e0b01b
(`tools/gm/{localimpl,render,deploy,docker,execnode,fit,state,teardown,
aging}.py`, `tools/gm/__init__.py`). Checked on armenelos the same day:
`docker info` names each engine as its swarm node (`armenelos`,
`vps-5718ad52`), both on `overlay2`; `DOCKER_CONFIG` is unset in the
shell and the user manager; `ssh vps` reaches the VPS only through the
desktop session's SSH agent, and at its public address (closing list).
W1's method holds: a source that fixes a point is cited, not restated;
**(choice)** marks a point the sources left open, settled with its
reason; each item names the chunk that writes it and those that read
it; a chunk's internals stay out.

**0. Conventions** (read by 10, 11, 12, 13, 15)

- A **host** is one entry of the playground's declaration, named by its
  swarm node name; the **manager** is the host flagged so, where `gmctl`
  and the host timers run (W2 item 5); a **designed host** is a name in
  the scenario's `designed_for.hosts`.
- **Two kinds of Docker call** (choice: Swarm answers the first kind
  from its manager for every node, the second only on the engine that
  holds the object): Swarm-scoped calls (`stack`, `service`, `service
  ps`, `service logs`, `node`, `network`, `config`, `secret`, `inspect
  --type task`) go to the manager; node-local calls (`ps`, `exec`,
  `inspect` of a container, `volume`, `image`, `save`/`load`, a helper
  `run`) go to the host the node is placed on. On one host both are the
  same engine, as today.

**1. The playground declaration** (writes: chunk 10a; read by 10b, 11,
12, 13, 15). Master spec 10.1, 10.2; W2-A.

```yaml
# playground.yaml, written by gmctl fit
name: duo
platform: swarm
hosts:                                  # exactly one with manager: true
  - name: armenelos                     # the swarm node name
    docker_endpoint: null               # null: the local engine
    manager: true
    capacity: {cpu: 4, memory: 5G, disk: 10G}    # memory available (10.1)
  - name: vps-5718ad52
    docker_endpoint: ssh://<user>@<its Tailscale address>
    manager: false
    capacity: {cpu: 2, memory: 4G, disk: 20G}
mapping:                                # designed host -> host
  host-1: armenelos
  host-2: vps-5718ad52
```

- **Today's form** (`docker_endpoint` and `capacity` at the top, no
  `hosts`) reads as a list of one, its `name` the engine's (`docker info
  --format '{{.Name}}'`, read by `fit`, which already reaches it), its
  `manager` true; it is never rewritten into the list form (choice:
  existing local implementations and `fit --cpu …` stay as they are).
- **The mapping**: on one host, implied (every designed host onto it);
  on several, required for every designed host, onto a declared host;
  several designed hosts may share a host, and a host may get none
  (master spec 10.2: the default game stays single-host).
- **Command line** (choice: written by `gmctl`, as W2-A has it, never
  by hand): `gmctl fit <dir> --playground <pg> --host
  armenelos,manager,cpu=4,memory=5G,disk=10G --host
  vps-5718ad52,endpoint=ssh://…,cpu=2,memory=4G,disk=20G --map
  host-1=armenelos --map host-2=vps-5718ad52`. `--host` (repeatable)
  replaces the whole host list, `--map` the whole mapping; a host with no
  `endpoint=` is the local engine. `--endpoint`, `--cpu`, `--memory` and
  `--disk` stay the one-host form's, refused with `--host` or on a
  playground of several hosts.
- **`fit` refuses** (exit 1, nothing written): no or two managers, an
  unmapped or unknown designed host, a mapping onto an undeclared host;
  on several hosts, a host the manager's `docker node ls` does not list
  under that name, or the manager not listed as a manager.
- A remote host's endpoint is an SSH destination reaching its Tailscale
  address (master spec 10.2); `gmctl` does not check the route (choice:
  the route is the host's SSH configuration, which `gmctl` does not own).

**2. Placement** (writes: chunk 10a in `implementation.yaml` and the
stack file; read by 10b, 11, 13). Master spec 7.5, 10.2; access model 7
(`network-visitor`).

- Each node of `implementation.yaml` gains `host: <host>`, its designed
  host through the mapping. `render` writes one constraint per service,
  `node.hostname == <host>`, in place of `PLACEMENT_CONSTRAINT`, every
  node pinned, stateful or not (choice: a node is given its image only on
  its host, item 5, so it can run nowhere else; on one host the
  constraint line is the only change). A one-host game is thereby kept
  off the VPS even while the VPS is `active`.
- **Published ports only on the manager** (choice, from G4's "no game
  port published on the VPS"): `fit` refuses a node with
  `published_ports` placed on any other host, naming the mapping to
  change. A host-mode port on a worker opens on every address it has, a
  public one included, ahead of its firewall.
- **A restart keeps every node's host**: it reads the same
  `playground.yaml`, which `fit` cannot change while a game is deployed
  (`fit._game_to_keep` refuses), so a snapshot taken on a host is
  restored on it.

**3. Per-host Docker contexts and how `gmctl` reaches a host** (writes:
chunk 10b in `docker.py`, `execnode.py`, `deploy.py`; read by 11, 12, 13,
15). Master spec 10.2; D173; W2 item 5.

- Each host with an endpoint has a context `dbagm-<host>` (choice: named
  by the swarm node, unique in the swarm, shared by every playground
  declaring it), in the default store of the host where `gmctl` runs
  (`$HOME/.docker`, which a timer run's environment has). Every `gmctl`
  run that reaches a host first ensures its context from
  `playground.yaml`: created when missing, refused when one of that name
  names another endpoint (the command to update it in the message). Each
  call names it (`docker --context dbagm-<host> …`); `gmctl` never runs
  `docker context use` (choice: the GM's own `docker` commands stay
  aimed where they were). Contexts are client-side and outlive a game;
  teardown leaves them (choice: the next game on the same hosts reuses
  them; nothing is created on the remote host).
- **API**: `docker.for_local_dir(ldir)` keeps returning the manager's
  `Docker`; it reaches any host with `.on_host(<host>)` (itself for the
  manager, and on one host). `running_containers`, `exec_node` and its
  `node_container`, and deploy's health poll find the node's host
  themselves, so their callers in `aging.py`, `checks.py` and
  `inject.py`, which pass the manager's `Docker`, stay unchanged
  (choice: those files are not in chunk 10's). `aging.task_history`'s
  container inspect on another host fails and falls back, as coded, to
  the task's own timestamps (choice: an outage's edge read a few seconds
  off, against touching chunk 8's file). The tests' `FakeDocker` models
  several hosts behind `.on_host`.
- **A timer run reaches the hosts as the shell does** (D173): the
  context store under `$HOME` and the SSH client configuration are the
  same for both; the session's SSH agent is not (it is gone after a
  reboot under lingering). `deploy` therefore probes each remote host as
  a timer run would, with no SSH agent and no terminal, and refuses,
  before creating anything, when it does not answer (choice: in every
  game, one rule, since `snapshot` and `restart` may run from anywhere
  too). W2 item 5's "not supported for timer runs" is thereby closed.
- **`deploy` refuses** a host that the manager's `docker node ls` shows
  not `Ready` or not `active`, naming `docker node update --availability
  active <host>`; on several hosts it refuses `--init-swarm`. `gmctl`
  never changes a node's availability or the swarm's membership (choice:
  on the VPS a membership change is a downtime, G4's incident; both stay
  the owner's and the driver's).

**4. Where a node's volumes, and everything else of the game, live on a
host** (writes: chunk 10b, teardown included; chunk 11 the snapshot's;
read by 11, 13, 15). Master spec 6.4, 12; W2-A's names and labels; W1
item 6 ("where the copies live, how they are restored and labelled").

- A node's volumes keep W2-A's names and labels; Swarm creates them on
  the node's host when its task first starts there, with the stack
  file's labels, so they live on `nodes.<n>.host` for the whole game.
  The game's overlay network reaches a worker the same way (the stack's
  own, labelled).
- **Nothing else of the game is created on a remote host but these and
  what follows, each labelled `dbagm.game=<game_id>` or by its snapshot
  label** (the VPS rule, D159): no context, network, file or directory
  there (choice: everything `gmctl` leaves on a host is then a Docker
  object its label finds). Helper containers (chunk 11's copies and
  restores) run with `--rm`, `--pull never`, the label, and an image of
  the game the host already holds (choice: no registry, nothing pulled).
- **The snapshot's copies** (chunk 11): one Docker volume per copied
  volume, on that volume's host, holding the tar stream of W1 item 6
  (choice: the stream as produced, restored by extraction as W1 item 6
  says), labelled `dbagm.snapshot=<id of the game that took it>` and not
  `dbagm.game` (choice: so a restart's removal of the game's objects
  leaves it, and the restarted game's teardown removes it by the id
  recorded with the snapshot's location). A stream from a node on
  another host crosses the link twice (back to `gmctl`, then into the
  volume) (choice: W1 item 6's exec path kept; a restore runs on the
  host, from volume to volume). A restart's fresh volumes are created on
  the node's host under the new game id, labelled as Swarm would label
  them, before the stack is deployed (choice: a volume is node-local, so
  only one made on that host is found there; Swarm uses an existing
  volume of the stack's name, which chunk 11's run confirms).
- **Teardown per host** (chunk 10b; amends v0.1 W2-B's
  `remove_game_objects` and `leftovers`): Swarm-scoped objects on the
  manager, then containers and volumes on every declared host; a host
  that does not answer fails the teardown as a labelled object left
  (exit 1, nothing recorded, W3-C). Images stay (as today), copied ones
  included.

**5. `fit` per host and the snapshot's verdict** (writes: chunk 10a in
`implementation.yaml`; read by 11, 13). Master spec 6.4, 8.6, 10.2, 12;
W1 item 3 (`disk_growth_per_hour`).

- Per host, the nodes placed there against its capacity (limits,
  reservations, disk with each of its images counted once and the
  growth over the scenario's aging plus four hours); the game fits only
  when every host does.
- The snapshot's copies are counted on each volume's host, after the
  game's own disk; the verdict is one for the game (choice: a restart
  needs every volume, so a snapshot short on one host is no snapshot):
  `implementation.yaml` top-level `snapshot_fit: {fits: true|false, why:
  <the line of the host short of disk, or null>}`. A game that fits
  with no room for the snapshot is fitted, and says so (master spec 12,
  "Otherwise, no history"); chunk 11 records "not fitting" from `fits:
  false` and takes nothing.

**6. The image copy** (writes: chunk 10b; read by 11, 15). Master spec
10.2; D149.

- The manager holds every image of the game (`fit` reads them there, as
  today, and `deploy` refuses one missing there); each other host gets
  the images of the nodes placed on it, skipped when it holds the same
  name under the same id (`docker image inspect --format '{{.Id}}'`;
  both engines on `overlay2`, where the id survives a save and load).
- Form (choice: one route per host, its context): `docker save <image>
  | docker --context dbagm-<host> load`, the same SSH as `docker save |
  ssh <host> docker load`, with no second destination to declare.
- Recorded by `deploy` in `state.yaml` (W2 item 0), top-level
  `images: {<host>: [{image, id, copied: true|false, at}]}`, the last
  deployment's; a restart's deployment finds every image present.

**7. Wave 3 coordination** (for the driver and chunks 10, 11, 12)

- Chunk 10's Files gain `tools/gm/teardown.py` (item 4) and
  `tools/tests/test_teardown.py`; both pass to chunk 11 at chunk 10's
  merge (in-wave edge 10 ──> 11).
- Chunk 10b's try runs on a scratch copy of `fixture-monitoring` whose
  `designed_for` names two hosts, `bastion` and `db` on one and
  `prometheus`, `exporter` and `grafana` on the other, mapped onto
  armenelos and the VPS (choice: the fixture's own declaration, and so
  its one-host rendering, stays unchanged; the split puts a database
  connection, a scrape and the web front across the link).
- **To relay to chunk 12** (running): `fixture-load`'s `designed_for`
  names two hosts with the bastion's on the first, both mapped onto one
  host for the one-host run; `smoke-load.sh <playground>` passes any
  further arguments to `gmctl fit`, so the wave gate's two-host run gives
  item 1's `--host` and `--map` there.
- The VPS's `active` window ("Workflow deltas", D178) opens before a
  two-host run's `deploy` (item 3 refuses a drained host) and closes
  after its teardown, never before it (choice: draining stops the VPS's
  tasks but leaves their volumes, which teardown must still reach).

**Points not mine to settle**

1. **SSH to the VPS for a timer run** (owner): `ssh vps` succeeds only
   with the session's agent (refused with `SSH_AUTH_SOCK` unset; no key
   at a default path), so item 3's probe refuses today. A key that works
   without an agent, held on armenelos and authorised on the VPS for
   `debian`, is a credential decision.
2. **G4's "SSH over Tailscale"** (driver, then `spec-writer` for G4's
   text): `ssh vps` is `debian@51.210.178.153`, the VPS's public
   address, so `docker -H ssh://vps` and an image copy through it cross
   the internet; `ssh debian@100.126.172.117` fails host-key
   verification (that address is not in `known_hosts`). Needed before
   chunk 10b's try: an SSH destination at the Tailscale address with a
   verified host key.
3. **For `spec-writer`**: chunk 10's Files (item 7); item 2's refusal of
   published ports off the manager, if master spec 7.5 or 10.2 should
   state it; item 6's copy through the context, if 10.2's literal command
   should follow.

### Dispatch and settlements

- `spec-writer`: plan v10 (c0f8abc, D178: G4 cleared, the VPS's
  swarm membership change a downtime, the drain rule made standing,
  through wave 4); plan v11 (f355502, D179 teardown per host in chunk
  10, D180 published ports on the manager only, D181 the image copy
  through the host's SSH Docker context; W3's other (choice)s change no
  stated behaviour).
- `security-advisor`: `.tech` e9631bc. The VPS's Docker Engine 29.9.2 is
  clear (past CVE-2026-34040, -33997, -42306, -41568, -41567, -92542,
  -92543 and GO-2026-6809). Optional, for the owner: armenelos' 29.9.1
  is built with Go 1.26.9 (GO-2026-6809, low risk here); upgrading it to
  29.9.2 at the next maintenance would align the two nodes.
- Capture W3 committed 4c53cf1 (drafted for the driver). Its closing
  list found G4's "SSH over Tailscale with a key" not met: `ssh vps`
  went to the public address, and its key was reachable only through the
  desktop keyring's agent, which a timer run after a reboot lacks.
- Chunk 12 (`v0.3-c12-load`): dispatched at the wave's start; merged
  c0875f6 (chunk commit 4f261d2). Chunk 10 (`v0.3-c10-multihost`):
  dispatched after W3; built (768bc36 10a, 530b3e1 10b), waiting on its
  merge gate, the two-host try.

### The SSH route and key to the VPS — owner's ruling, 2026-10-26

The owner followed the driver's recommendation, **for testing and private
runs only; no secret in git**:
- a new alias `dbagm-vps` in `~/.ssh/config` on armenelos (backup
  `~/.ssh/config.bak_20261026`): HostName 100.126.172.117 (Tailscale),
  User `debian`, `HostKeyAlias 51.210.178.153` (the VPS shows the same
  ed25519 host key on both addresses, SHA256:LBwBb7KT…, already in
  `known_hosts`), `IdentitiesOnly yes`; `ssh vps` unchanged for the
  owner's other projects;
- a dedicated passphrase-less key `~/.ssh/dbagm_vps_ed25519` (mode 600,
  outside every repository), authorised on the VPS's `debian` account
  with `from="100.78.85.1",no-agent-forwarding,no-X11-forwarding,
  no-port-forwarding` (backup `~/.ssh/authorized_keys.bak_20261026`
  there). The owner accepted that this key gives root on the VPS to
  whoever can read it on armenelos;
- checked: with `SSH_AUTH_SOCK` unset, `ssh -o BatchMode=yes dbagm-vps
  docker version` answers 29.9.2; the same key on the public address is
  refused; filetstudio.com 200.
- A playground names the VPS with endpoint `ssh://dbagm-vps`. G4's SSH
  item is met from here.

### Chunk 10's two-host try, first attempt — 2026-10-26 evening

The owner set the VPS `active` for the try. Run with
`VPS_SSH=ssh://dbagm-vps` (scratch `fixture-monitoring` over two designed
hosts: bastion and db on armenelos; Prometheus, the exporter and Grafana
on the VPS).
- **Failed at deploy**: Swarm rejected the exporter's task on the VPS,
  `invalid pool request: Pool overlaps with other one on this address
  space`. Swarm's default pool (10.0.0.0/8 in /24s; the ingress has
  10.0.0.0/24) hands the game's overlay 10.0.1.0/24 and up, which the
  VPS's local networks already hold (10.0.0.0/24 to 10.0.5.0/24:
  `bridge`, `maintenant_default`, `crochethub_net`, `caddy_filetstudio`,
  `docker_gwbridge`, `caddy_infinite-flow`). Every game spanning both
  hosts hits it; one-host games don't. Setup rolled back and teardown
  left nothing of the game on either host.
- **Proved**: `deploy`'s agent-less probe through `ssh://dbagm-vps`; the
  image copy (three images loaded on the VPS under the manager's ids,
  recorded `copied: true`, a second pass copying none); teardown per host
  through context `dbagm-vps-5718ad52`; Swarm on Tailscale (VPS
  100.126.172.117, manager 100.78.85.1, direct over IPv6).
- **Not reached**: the bastion's ports on armenelos only, `gmctl exec`
  on a VPS node (shell and user-manager run), traffic across the link,
  the MTU inside a node.
- filetstudio.com 200 before, after the failed deploy and after
  teardown; the app logged no MongoDB line.
- **An architectural decision nobody captured** (chunk 10 stopped per
  its brief). Options from chunk 10's owner:
  - **A (recommended by the chunk owner and the driver)**: gmctl gives a
    multi-host game's overlay an explicit subnet, the first free /24 in a
    range reserved for gmctl (e.g. 10.20.0.0/16), avoiding every swarm
    network and every local network on the placed hosts; code in render
    and deploy only, nothing changed on the VPS. To capture as W3-a:
    where it is chosen, the range, recorded in `implementation.yaml` so a
    restart reuses it;
  - B: the VPS daemon's `default-address-pools` (a dockerd restart, a
    filetstudio.com downtime);
  - C: Swarm's default address pool (only at `swarm init`, a membership
    change): ruled out.

### State at the end of 2026-10-26 (for the next driver)

- Wave 3 on `v0.3-w3` (worktree `/home/bastien/work/db_audit_gm-wt/v0.3-w3`).
  Plan v11. G4 cleared (D178), with the SSH route `dbagm-vps` and its
  dedicated key (owner's ruling above: testing and private runs only, no
  secret in git).
- Chunk 12 merged (c0875f6). Chunk 10 built, not merged: branch
  `v0.3-c10-multihost` at 530b3e1 (10a 768bc36), worktree
  `/home/bastien/work/db_audit_gm-wt/v0.3-c10-multihost` kept; the try
  script and logs in the driver's scratchpad (`two-host-try.sh`,
  `try.log`, `try2.log`). Chunk 11 not started (needs 10).
- The VPS: the owner drains it at the day's close (nothing of a game on
  it, only the three copied images, about 1.45 GB). Context
  `dbagm-vps-5718ad52` on armenelos.
- Next:
  1. The owner's word on option A (above), then capture W3-a and
     `spec-writer` if master spec 10.2 needs a line;
  2. a fresh `coding-leader` resumes chunk 10 from 530b3e1 with W3-a:
     the subnet fix, then the try again (the owner sets the VPS
     `active`, and drains it after);
  3. chunk 11 once 10 has merged; then the wave gate, its two-host
     `smoke-load.sh` run included.
- Gate-fix list so far: `tools/gm/state.py` `status` shows a several-host
  playground as "local engine" (cosmetic, chunk 10's report).
- For the owner, optional: armenelos' Docker 29.9.1 → 29.9.2 at the next
  maintenance (security-advisor).

### Capture W3-a — the game's overlay subnet on several hosts (chunk 10; read by 11, 15) — 2026-10-27

Owner's word, 2026-10-27: option A of chunk 10's first try ("gmctl
picks the subnet, from a range reserved for it, 10.x.0.0/16"). Recorded
by the driver before chunk 10 resumes, from that try (above), capture W3
items 2, 3 and 7, and the networks read the same day on both hosts:
armenelos holds `ingress` 10.0.0.0/24 and local networks in
172.17–172.23; the VPS holds local networks 10.0.0.0/24 to 10.0.5.0/24
(`bridge`, `maintenant_default`, `crochethub_net`, `caddy_filetstudio`,
`docker_gwbridge`, `caddy_infinite-flow`); neither has a route or a
network in 10.20.0.0/16.

1. **The range**: `10.20.0.0/16`, reserved for the overlays of `gmctl`'s
   games (256 /24s), one constant in the code. Nothing changes on the
   VPS or in either daemon's configuration (options B and C dropped).
2. **Which games** (choice: one-host games work today and keep their
   stack file unchanged, as with the MTU of W3 item 2): a game whose
   nodes span more than one host gets an explicit subnet; a one-host
   game keeps Swarm's default allocation.
3. **The pick**: the first /24 of the range that overlaps no subnet of
   (a) every swarm-scoped network the manager lists (the ingress, other
   games' overlays) and (b) every network on each host the game is
   placed on, the manager included, read through the host's context
   (W3 item 3). A full range refuses the deployment, naming the range.
   Overlap is a prefix overlap, not equality.
4. **Where and when** (choice: only `deploy` reaches every placed host,
   through the probe of W3 item 3; `fit` stays off the workers): at the
   game's first deployment, before the stack is rendered for it.
   Recorded in `implementation.yaml`, top-level `network: {subnet:
   <10.20.N.0/24>}`, and rendered by `render` as the overlay's `ipam:
   {config: [{subnet: ...}]}` beside its MTU option.
5. **A restart reuses it**: a recorded subnet is kept, not picked again
   (a restored game keeps its addresses); `deploy` re-checks it against
   item 3's lists and refuses, naming the network that now overlaps,
   rather than move the game silently. `fit` cannot rewrite
   `implementation.yaml` while the game is deployed (W3 item 2); a new
   `fit` after teardown drops the record and the next deployment picks
   again.
6. **Checks** (chunk 10): unit tests over given network lists (first
   free /24, skipping both kinds of overlap, a full range, a recorded
   subnet kept, a recorded one now taken); a one-host render unchanged;
   then chunk 10b's two-host try again, with the VPS `active` for it
   (the owner sets it, and drains it after teardown).

### Chunk 10 resumed, the try passed, merged — 2026-10-27

- `spec-writer`: D182 and plan v12 (efaa0aa): master spec 10.2's risks
  list names the overlay's range; D182 in chunks 10, 11, 15. Its point
  for chunk 11: on a restart, Swarm removes the old overlay
  asynchronously, so the re-check must not count the game's own
  network (relayed to chunk 10, which leaves it out by name; the
  restart's ordering stays chunk 11's).
- **W3-a item 4, amended by the driver** (chunk 10's stop, no stated
  behaviour changed): `render` writes `stack.yml` before `deploy` runs,
  so `deploy` picks or re-checks the subnet after its host checks,
  before anything is created, and writes it into the rendered stack's
  network `ipam` (`render.set_subnet`); `render` writes the same `ipam`
  whenever a subnet is recorded. The record is `implementation.yaml`'s
  top-level `overlay: {subnet: <10.20.N.0/24>}` (`localimpl.OVERLAY`),
  since `network` already holds the network's name.
- Chunk 10: 6146893 on 530b3e1, merged 6b6cceb; worktree removed,
  branch kept. Unit suite 582 OK (rerun by the driver). The two-host try
  (`two-host-try-w3a.sh` under `try-wrapper-w3a.sh`, log `try3.log`, the
  driver's scratchpad; VPS active inside the lock, drained after) passed
  with 0 failures, game `fixture-monitoring-6cwdd0`: bastion and db on
  armenelos, exporter, Prometheus and Grafana on the VPS; overlay
  10.20.0.0/24 recorded, in the stack and on both hosts (vxlanid 4106);
  2222 and 8080 on armenelos only; `gmctl exec` on VPS nodes from a
  shell and from `systemd-run --user` with no agent; `pg_up` 1 across
  the link, a 26 kB Prometheus page through the web front; images 0
  copied, 3 held under the same id; teardown left nothing of the game on
  either host. filetstudio.com 200 throughout; VPS `Drain` after.
- **Finding, for `spec-writer`** (not blocking): the overlay's MTU
  option 1230 gives an interface of 1180 inside a node: Docker takes
  VXLAN's 50 bytes off the option itself, so 1280 would give 1230.
  Safe as it is; changing it needs another two-host run.
- Gate-fix list: `tools/gm/state.py` `status` shows a several-host
  playground as "local engine" (cosmetic).

### Capture W3-b — the overlay's range is the GM's to choose (amends W3-a; chunk 10's follow-up, read by 11, 13, 15) — 2026-10-27

Owner's word, 2026-10-27: "the network selection should probably remain
in the GM agent hands (as it may need to be selected according to the
execution environment). Meaning we propose 10.20... but if it isn't
available, it shouldn't be too troublesome for the GM to select
another." W3-a holds, but for:

1. **The range is the playground's** (choice: the execution environment
   is what the playground declares): `playground.yaml` gains
   `overlay_range: <IPv4 CIDR>`, written by `gmctl fit --overlay-range
   <cidr>`; absent, `10.20.0.0/16`, the proposed default. A prefix of
   /24 or longer than /16 is fine; a /24 names that one subnet. `fit`
   refuses a range that is not IPv4, is wider than /8 or narrower than
   /24, or lies outside the private ranges (10/8, 172.16/12,
   192.168/16).
2. **One run's override**: `gmctl deploy` and `gmctl restart` take
   `--overlay-range <cidr>` too, used for that run in place of the
   playground's (choice: `fit` refuses while a game is deployed, and a
   restart must not need a teardown to change the range).
3. **A recorded subnet** (W3-a item 5) is kept while it lies inside the
   range in force and overlaps nothing; one outside the range in force
   is picked again from it (the GM changed the range: an explicit
   word, not a silent move); one inside it that now overlaps is still
   refused.
4. **Every refusal says how to choose**: a full range, or a recorded
   subnet now overlapping, names what is taken (the network and its
   host) and the way out: `--overlay-range <cidr>` on `deploy` or
   `restart`, or `gmctl fit --overlay-range <cidr>` for the playground.
   `deploy` prints the subnet it uses and the range it came from.
5. **Who builds it**: a `coding-executor` on the wave branch once chunk
   11 has merged (chunk 11 is in `deploy.py` now), before the wave
   gate: `tools/gm/{fit,localimpl,deploy,restart}.py`,
   `tools/gm/__init__.py` (options, a shared list), the tests,
   `.claude/skills/game-master/gmctl.md` (`fit`, `deploy`, `restart`
   rows). Chunk 13's GM skill states the GM's choice. Unit tests: a
   playground's range used, the default when absent, `fit`'s refusals,
   the override, a record outside the range re-picked, the refusals'
   wording. The wave gate's two-host `smoke-load.sh` run checks it on
   both hosts.

### Chunk 11, first owner paused after 11a — 2026-10-27

- `spec-writer`: D183 and plan v13 (b1438df): the overlay's range is the
  GM's (master spec 10.2, 13; chunks 13, 15). For W3-b's
  `coding-executor`: `gmctl.md`'s `status` overlay line too, not only
  the `fit`, `deploy`, `restart` rows. Still open for `spec-writer`:
  chunk 10's MTU finding.
- Chunk 11 (`v0.3-c11-snapshot`): 11a committed 998a4c3 (`gmctl
  snapshot`, the hand-over's third condition, teardown of the copies,
  `smoke.sh`'s snapshot); 607 unit tests OK; `smoke.sh` passed on
  armenelos (7 copies); `fixture-monitoring`'s snapshot with Prometheus
  and Grafana stopped briefly (18 copies, both up after). Paused at its
  context threshold before 11b; worktree kept. Its 11b design is in its
  report, relayed to the resuming owner; it leaves the outgoing game's
  network out of `deploy`'s re-check by name (D182's point), with no
  wait.

### Chunk 11 merged — 2026-10-27

- 11b f0ffff8 (merge dd9377f, by its second owner); worktree removed,
  branch kept. Unit suite 628; `smoke.sh` passed with its snapshot;
  `fixture-load` snapshot under load, two restarts from it and a
  no-history restart (64/65, the one fail the run script's own count,
  fixed); `fixture-monitoring` snapshot and restart 16/16; nothing
  labelled left; VPS `Drain`, untouched.
- Chunk's choices: `restart` from `failed` only after a failed restart
  (the spec's refusals ask only for the confirmation and a handed-over
  game); the outgoing network left out of the subnet re-check by name;
  the subnet choice in one place, `deploy.game_subnet(docker, impl)`,
  where W3-b threads `--overlay-range`.
- For the wave gate: the restart not run across two hosts (unit tests
  only); Swarm reusing a pre-created volume confirmed on one host.
- Gate-fix list: `state.py` `status` shows a several-host playground as
  "local engine"; after a no-history restart `status`'s aging line reads
  "ran 0s" (cosmetic, both).

### W3-b built; MTU settled; gate fixes — 2026-10-27

- `spec-writer`: D184 (ac80c9e, plan v14): the overlay's and the
  ingress's MTU option 1230 kept; Docker reads it as the outer MTU, so a
  node's interface is 1180; 1280 declined (another two-host run and the
  ingress re-created for 50 bytes). Master spec 10.2, 20; the plan's
  "Left for the build" row.
- `coding-executor` (branch `v0.3-w3-overlay-range`, kept): 37e0a48
  W3-b, 2a7f54a the gate fixes (`status`'s hosts on several hosts, the
  aging line after a no-history restart) and D184's wording in
  `render.py` and `gmctl.md`; merged 4af0895. Unit suite 651 OK. W3-b
  as captured, plus: a re-fit without `--overlay-range` keeps the
  declared range; a range with host bits set is refused too; a range
  edited by hand into `playground.yaml` is checked on read. Left as
  chunk 11 wrote it: after a no-history restart, the "earliest
  hand-over" line counts from the new T0.

### Wave gate — 2026-10-27

Run on `v0.3-w3` (head d2dab75) on armenelos (Debian 13, Docker 29.9.1,
swarm leader; `vps-5718ad52`, Docker 29.9.2, drained but for the last
step), 10:58–11:43 CET, by a `coding-executor`; every docker step under
the host lock, one at a time. Step logs: the driver's scratchpad,
`gate-w3/` (`summary.txt`, `two-host-wrapper.sh`, `leftovers.sh`). All
passed; no fix needed.

| Step | Result | Duration |
|---|---|---|
| Unit suite | 651 OK | 104 s |
| Scheduler unit tests (in its image) | 60 OK | 66 s |
| `sh -n` on every shell file | 110 files, 0 failed | — |
| `perl -c` on every Perl file | 7 files, 0 failed | — |
| Loader: every brick, fault, scenario and fixture | 25 definitions (new: `fixture-load`), plus 13 inside fixtures; 0 with problems | <1 s |
| Stack test `postgres` 0.3.0 | all checks passed (131) | 73 s |
| Stack test `bastion` 0.3.0 | all checks passed (71) | 62 s |
| Stack test `prometheus` 0.2.0 | all checks passed (131) | 78 s |
| Stack test `postgres-exporter` 0.2.0 | all checks passed (103) | 98 s |
| Stack test `grafana` 0.2.0 | all checks passed (119) | 165 s |
| Stack test `scheduler` 0.1.0 | all checks passed (95) | 728 s |
| Stack test `pgbouncer` 0.1.0 | all checks passed (103) | 98 s |
| `smoke.sh` | 60 passed (with the snapshot) | 30 s |
| `smoke-monitoring.sh` | 43 passed | 47 s |
| `smoke-scenario.sh bookshop-new-server` | 19 passed | 22 s |
| `smoke-scenario.sh fernway-clinics-monitoring` | 18 passed | 30 s |
| `smoke-load.sh armenelos` (one host) | 73 passed | 399 s |
| `smoke-load.sh duo` (armenelos + the VPS) | 73 passed | 499 s |

- Image sizes unchanged from wave 2 (postgres 262MB, bastion 185MB,
  prometheus 488MB, postgres-exporter 165MB, grafana 866MB, scheduler
  172MB, pgbouncer 182MB).
- Two-host run: `--host armenelos,manager,cpu=4,memory=4G,disk=20G
  --host vps-5718ad52,endpoint=ssh://dbagm-vps,cpu=2,memory=4G,disk=10G
  --map host-1=armenelos --map host-2=vps-5718ad52`, no SSH agent.
  bastion, db, pooler, producer on armenelos; consumer, Prometheus,
  exporter, Grafana on the VPS. Overlay 10.20.0.0/24 (the default
  range), MTU option 1230; images: scheduler 0.1.0 copied, 3 held; ports
  on armenelos only; Prometheus's 12 targets up across the link; 316
  transactions through PgBouncer. VPS `active` inside the lock, `Drain`
  after (trap). filetstudio.com 200 before, 16/16 during, after; no
  MongoDB line. Nothing of a game left on either host; no `dbagm-*`
  unit.
- The VPS holds four game images (~1.69 GB): scheduler, grafana,
  prometheus 0.2.0, postgres-exporter 0.2.0. `infinite-flow-web` there
  had restarted around 10:09 CET, before the gate touched the VPS
  (drained, nothing of the game's running there); healthy throughout.
- Carried to wave 4 (cosmetic): `deploy`'s first line reads "deployed on
  local engine" on a several-host game (`tools/gm/deploy.py`
  `DeployResult.text`), as `status` did before 2a7f54a.
- No dependency changed in wave 3 (no `security-advisor` check); no
  intent register (no wave sync).

## Wave 3 — merged 2026-10-27

Merged into `main` on the owner's word, `--no-ff`, as be857ff, with the
gate's figures in the message. The wave worktree and the branches
`v0.3-w3`, `v0.3-w3-overlay-range` and the chunk branches removed.

## Wave 4 — started 2026-10-28

Chunks 13, 14, 15 (κ = 3; 15b at κ = 1, alone on the hosts). Branch
`v0.3-w4`, worktree `/home/bastien/work/db_audit_gm-wt/v0.3-w4`, cut from
`main` at be857ff. Rulings since the plan's v14: none (D184 is the last).
No intent register and no data register: no `documentalist` preflight or
sync; capture W4 drafted for the driver, as W1 to W3 were.

### Gates checked at the start

- G2 (network at build time), hand check 2026-10-28: Debian's trixie
  `Release`, the PostgreSQL apt repository's `trixie-pgdg` `Release`,
  GitHub's s6-overlay releases and the pinned Grafana 13.2.4 tarball
  answer 200. Cleared for wave 4.
- G3 (Docker host in swarm mode), hand check 2026-10-28: armenelos,
  Docker Engine 29.9.1, swarm leader; `vps-5718ad52` (29.9.2) Ready,
  `Drain`.
- G4 still holds: `tailscale status` shows both hosts (the VPS active,
  direct); `ssh dbagm-vps` answers with no agent (Docker 29.9.2, 24G
  free on `/`). The VPS stays drained except inside chunk 15b's run and
  the release gate's two-host runs.
- Host resources on 2026-10-28: 4.4G of memory available on armenelos
  (3.8G of swap in use), 10G free on `/`.
- G7 (the owner's review of the v0.3 scenario) open: blocks chunk 15's
  merge only.

### Order

- Chunk 13 reads no W4 item and depends only on merged chunks:
  dispatched at once.
- Capture W4 (the eight faults and the scenario's choice) is drafted and
  committed before chunk 14 starts; chunk 15 once chunk 14 has merged
  (in-wave edge 14 ──> 15). 15a may start once 14 has merged; 15b runs
  alone on the hosts.
- Carried from wave 3 (cosmetic): `deploy`'s first line on a
  several-host game; fixed on the wave branch before the gate, in no
  chunk.

### Carry-over fixed — 2026-10-28

- `coding-executor` (branch `v0.3-w4-deploy-line`, removed): 53692ee,
  merged ea3de4a. On a several-host game, `deploy`'s first line now reads
  `Game <id>: deployed on <playground>, <n> hosts:` with one line per
  host, through `state.host_lines`, which `status` shares; one host
  unchanged. Unit suite 653 OK. `gmctl.md`'s deploy entry passed to
  chunk 13's owner to match.

### Capture W4 — the eight faults and the scenario's choice (chunks 14, 15) — 2026-10-28

Recorded 2026-10-28, before any code; drafted for the wave driver from
the plan's (v14) chunks 14 and 15 and G7, master spec 6.1 to 6.3, 6.5,
6.7, 7.1 to 7.3, 8 (8.2 to 8.5), 11 and 15.1 to 15.4, D134, D145,
D157, D160, D161, D163, D167, D168, D170, D171, D176, the working
records `faults-with-activity.md`, `scheduler.md` and
`checks-under-load.md`, this version's W1 items 2 to 4 (the fault, brick
and answer-key keys), W1-y (the scheduler as built), W2 items 1, 8 and 9
(render's records, the early and hand-over checks, "too soon to tell")
and W2-a (PgBouncer as built), the format skill's templates
(`fault.yaml`, `scenario.yaml`, `answer-key.yaml`, `queries.yaml`,
`jobs.yaml`, `schedule.yaml`), and the code on `v0.3-w4` at 088e41b:
`tools/gm/{model,render,inject,checks}.py`, `bricks/{scheduler,
pgbouncer,postgres}/` (`brick.yaml`, `docs/gm.md`, the scheduler's
program and `check-psql`), the existing catalog faults
(`pg-join-index-missing`, `pg-table-autovacuum-off` and the monitoring
ones), and `tools/tests/fixtures/fixture-load/` (its nodes'
files, its data, and its fault `fixture-job-every-minute`, whose check
is the precedent for a check on a scheduler's files). W1's method holds:
a source that fixes a point is cited, not restated; **(choice)** marks a
point the sources left open, settled here with its reason; **open —
proposed** marks a point that is not the driver's to settle, with the
proposal chunks 14 and 15 build on until it is ruled (item 12). Each item
names who writes it and who reads it; a chunk's internals (the scripts'
code, the wording of `gm.md` and `probe.md`) stay out.

**0. What the eight share** (writes: chunk 14; read by 15).

- **Ids and folders.** `faults/<id>/` with `fault.yaml`,
  `checks/fixed.sh`, `checks/probe.md`, `gm.md`, and `inject/` only for
  a fault with material; version `0.1.0`. The id opens with its target
  brick's id, as the existing faults do (`pg-` for `postgres`):
  `scheduler-…` for the seven living in a scheduler's files,
  `pgbouncer-…` for the pool. Title, family, severity and complaint
  template are chunk 14's.
- **`applies_to`**: `scheduler` `["0.1.0"]` for the seven, `pgbouncer`
  `["0.1.0"]` for the pool, and no other brick, although much of the
  evidence is read on the database (the loader matches the instance's
  node's brick). Preconditions as each item says.
- **Injection**: `kind: seed-file`, `stage: seed`, `run_as: root`,
  `seed_changes` naming the files of each item. The scenario writes the
  planted state into `nodes/<node>/` at authoring; render copies
  `queries.yaml` and `builders/` as they are, writes `jobs.yaml` in UTC
  (a job with `timezone_offset` keeps its `at` and gains `timezone:
  Etc/GMT∓M`, D168) and `schedule.yaml` rendered (W2 item 1); `inject`
  runs nothing for them; `plant_at` is T0 only (6.1). That is what
  "planted at render" means for the eight.
- **The planted baseline** (choice: a check needs the planted form
  without a parameter repeating the scenario's text): every seed file
  stays on the node, as rendered, at `/opt/gm/seed/<file>` (a config,
  0:0, `0444`; `schedule.yaml` `0400`) for the whole game, beside its
  live copy at its `seed.paths` path. A check may read it as the
  fault's planted form.
- **Checks on a scheduler node** (the seven): root, on the instance's
  node (`checks.py` runs a fault's check there and nowhere else). They
  read the node's files, `/run/scheduler/loaded`, the log, the metrics
  endpoint and the rendered `schedule.yaml`, and open no database
  connection (the duplicates' check aside, item 12 point 1). They judge
  what the program runs (choice, as `fixture-job-every-minute` does): a
  live file whose sha256 differs from its `file` line in
  `/run/scheduler/loaded` reads present, the first line saying the file
  is fixed but not reloaded (`sudo gm-reload-scheduler`). They may import
  the program's own package (`python3 -I`, `gm_scheduler`: its loaders,
  its cron) to read the files and compute run instants as the program
  does; whether they do is chunk 14's.
- **The pool's check**: root on the pooler node, the console over the
  local socket as `pgbouncer`, its only admin (W2-a): the values in
  effect, so a file edited but not reloaded reads present.
- **Exit codes**: 0 fixed, 1 present, 2 error; 3 only where an item
  says so, its first line `remaining=<N>[ text]` (W2 item 9). Only the
  duplicates fault is `behavioural: true` (15.3).
- **Evidence locations** (6.3, D145, D167, W1 item 2): `node` is the
  target node (the scheduler's files, its log, `curl -s
  localhost:9120/metrics`; the pooler's console and log); `bastion` is a
  shell or `psql` there as `dba` (`pg_stat_statements`,
  `pg_stat_activity`, `pg_stat_user_tables`, `\d`; the story's customer
  time zone). The PostgreSQL log on the database node, pgBadger
  (`postgres`'s tool, so never a scheduler fault's `report:`), another
  node's log and Prometheus or Grafana readings are the scenario's, in
  its answer key only (`node:<name>`, `report:pgbadger`, `ui:<name>`).
- **Resolutions**: `report` and `propose` under `[report-only,
  fixable]` for all eight; `fix` under `[fixable]` for all but the held
  transactions. On a scheduler node a fix is reachable only through the
  overrides `/srv/scheduler/repository` (`queries.yaml`, `builders/`) and
  `/srv/scheduler/jobs` (`jobs.yaml`) (D170); `schedule.yaml` is never
  fixable, so the loader's per-file check (`model.fix_policy`) refuses a
  *fix* for any fault whose seed changes name it.
- **Aging minima of the time-of-day faults** (choice: a definition
  cannot know when the scenario's day brings its evidence, and a minimum
  longer than the scenario's aging would make the scenario unloadable):
  the batch at the peak and the job in the wrong time zone show at the
  job's run, so their `aging.minimum` counts from the job's first run at
  its planted time; the pool's counts business hours under load; their
  `gm.md` says so. A scenario places that moment inside its aging and
  raises the instance's `aging_minimum` to the moment's offset from its
  designed T0 plus the definition's minimum, so the loader's coverage
  check (6.1) holds the design. The other five count from planting, as
  6.3 reads.
- **Times**: the scheduler's log and the rendered `jobs.yaml` are UTC;
  the scenario's jobs and shapes are scenario time. No check takes the
  shift as an input: those that need the customer's day derive it from
  the rendered files (items 7 and 8).
- **Docs**: the "Supported faults" sections of
  `bricks/scheduler/docs/gm.md` (the seven) and
  `bricks/pgbouncer/docs/gm.md` (the pool). `bricks/postgres/docs/gm.md`'s
  section lists no new fault (none applies to `postgres`), but says what
  their evidence needs from a `postgres` seed (the logging block and the
  `pg_stat_statements` preload it already recommends: `log_lock_waits`,
  `log_temp_files = 0`, `log_min_duration_statement`,
  `log_autovacuum_min_duration = 0`), and its "cannot host anything
  visible only under load" sentence points to them. No version changes:
  the three bricks are unreleased.

**1. The eight at a glance** (writes: chunk 14; read by 15).

| Id | Seed change in | Parameters | `aging.minimum` | Fix | The check reads |
|---|---|---|---|---|---|
| `scheduler-query-error` | `queries.yaml` | `key` | 10m | yes | files and log (3 for at most a minute) |
| `scheduler-update-without-where` | `queries.yaml` | `key` | 1h | yes | files |
| `scheduler-report-unbounded` | `queries.yaml` | `key`, `date-column` | 30m | yes | files |
| `scheduler-insert-retry-duplicates` | `queries.yaml`, `builders/` | `database`, `table-name`, `id-column`, `time-column` | 1h | yes | the data over a window (behavioural; item 12 point 1) |
| `scheduler-transaction-held-open` | `queries.yaml`, `schedule.yaml` | `key` | 2h | no | files |
| `scheduler-batch-at-peak` | `jobs.yaml` | `job`, `shape`, `quiet-below` | 1h from its first run | yes | files |
| `scheduler-job-wrong-timezone` | `jobs.yaml` | `job`, `offset` | 1h from its first run | yes | files |
| `pgbouncer-pool-too-small` | `pgbouncer.ini` | `database`, `min-pool-size` | 30m of business hours | yes | the console |

Parameters are scalars (`FAULT_<NAME>`, `-` read as `_`), each
`required: true` with `default: null` unless its item says otherwise.

**2. `scheduler-query-error`: a query fails on a syntax or type error**
(14a).

- **Seed change**, `queries.yaml`: the entry of `{KEY}` (a query, one
  entry of a pool, or one step of a sequence) carries an error
  PostgreSQL rejects at every call, of SQLSTATE class 42 (a syntax error
  42601, an operator or function that does not exist for the types
  42883, a datatype mismatch 42804) or 22 (an invalid input, 22P02). The
  program loads it (it never checks SQL), so the key keeps running and
  failing. No material: the SQL is the scenario's.
- **Parameter** `key`: the repository key holding the error; a key a
  stream runs, never one whose calls another instance's evidence needs.
- **Aging** 10m: errors from the first call; ten minutes give ten `key`
  lines with `errors=` above 0 and their `error` lines.
- **Evidence**: `node`, the log's `error key={KEY} sqlstate=<S>
  message="…"` lines and the `key` lines' `errors=`, the counter
  `scheduler_errors_total{key="{KEY}"}`, the entry in `queries.yaml`.
  Answer key: the PostgreSQL log's `ERROR` and `STATEMENT` lines
  (`node:<db>`), the error rate in Grafana.
- **Fixed**: the entry corrected in the loaded repository, and the
  key's calls since that reload ending without a class 42 or 22 error.
- **Check** (choice: a changed text proves nothing until the key has
  run, and a key runs within a minute): 1 while the loaded entry equals
  the seed copy's, the file is not loaded, or an `error key={KEY}` line
  of class 42 or 22 follows the last reload (`loaded=`); 0 once a call of
  the key has ended after the reload (its `key` lines) with no such
  error; 3, `remaining=` the seconds to the next minute's `key` line (at
  most 70), when the entry changed and is loaded but no call has ended
  since. No answer-key window: it is not behavioural.

**3. `scheduler-update-without-where`: an update missing its `WHERE`**
(14a; left out of the scenario, item 10).

- **Seed change**, `queries.yaml`: `{KEY}`'s `UPDATE` lacks its row
  filter (and the filter's parameter), so every call updates every row
  of its table.
- **Parameter** `key`.
- **Aging** 1h: rows per call show in `pg_stat_statements` from the
  first calls; dead rows and lock waits need an hour of calls under load.
- **Evidence**: `node`, the entry, the key's latency in the log;
  `bastion`, `pg_stat_statements` (`rows / calls` for the statement),
  `pg_stat_user_tables` (`n_tup_upd`, `n_dead_tup`) on the table.
  Answer key: the PostgreSQL log's lock waits (`node:<db>`), pgBadger.
- **Fixed**: every `UPDATE` of the key's loaded entry has a `WHERE`.
  Check on the files; 0, 1, 2.
- **A scenario using it** keeps the table small (a few thousand rows),
  apart from `pg-table-autovacuum-off`'s table, runs the key with a
  concurrency of 2 or more (lock waits), and sizes its rate against the
  WAL and dead rows it makes over the whole aging.

**4. `scheduler-report-unbounded`: a report reading far too much** (14a).

- **Seed change**, `queries.yaml`: `{KEY}` reads a large table with
  `SELECT *` and no bound on `{DATE_COLUMN}` (the report's period
  dropped), sorted or grouped, so each run reads the whole table and
  spills to temporary files at the seed's `work_mem`.
- **Parameters**: `key`; `date-column`, the column whose bound is
  missing.
- **Aging** 30m: temporary files and slow statements at every run; half
  an hour holds several runs of a reporting stream (a scenario running
  it as a job raises the instance's minimum, item 0).
- **Evidence**: `node`, the entry, the key's latency (seconds) in the
  log; `bastion`, `pg_stat_statements` (`temp_blks_written`,
  `mean_exec_time`, `rows`) for the statement. Answer key: the
  PostgreSQL log's `temporary file` and duration lines (`node:<db>`),
  pgBadger (`report:pgbadger`).
- **Fixed**: the key's loaded SQL bounds `{DATE_COLUMN}` in its `WHERE`
  (a comparison or `BETWEEN` on it). `SELECT *` alone is not judged; the
  acceptance's proposal names both. Check on the files; 0, 1, 2.
- **A scenario using it**: the table large enough for the unbounded
  sort to spill at the seed's `work_mem` (a few hundred thousand rows at
  4MB), small enough for the database's disk reservation.

**5. `scheduler-insert-retry-duplicates`: inserts resent without
idempotency** (14a; its check's connection is item 12 point 1).

- **Seed change**, `queries.yaml` and `builders/`: `{KEY}` maps to a
  builder that inserts one row into `{TABLE_NAME}` carrying the client's
  own id in `{ID_COLUMN}` and, for a share of the calls (an option of
  the entry in `queries.yaml`), sends the same insert again with the same
  values: the client resending when its acknowledgement is late. The
  data gives `{ID_COLUMN}` no unique constraint. Material: a builder
  under `inject/` that the scenario copies into `nodes/<node>/builders/`
  and adapts (its form is chunk 14's). Both files lie under
  `/srv/scheduler/repository`, so the repository's override makes the
  fix reachable.
- **Parameters**: `database`; `table-name`; `id-column`, the client's
  id, duplicated; `time-column`, the insert time the window counts by (a
  column the insert fills with the current time).
- **Aging** 1h, and the answer key's window is at most that, so the
  first full window after planting holds the fault's behaviour.
- **Evidence**: `node`, the builder's resend and its option; `bastion`,
  `SELECT {ID_COLUMN}, count(*) FROM {TABLE_NAME} GROUP BY 1 HAVING
  count(*) > 1` in `{DATABASE}`, and `\d {TABLE_NAME}` showing no unique
  constraint on the column.
- **Behavioural**: the answer key gives `window` W and `threshold` T,
  the most duplicate rows a fixed producer may leave in W (0 as a rule).
- **Check** (choice: one reading for a fix on either side, with no
  record of when it happened): d is the number of rows with
  `{TIME_COLUMN}` in the trailing W whose `{ID_COLUMN}` occurs more than
  once; 0 when d ≤ T; else 1 when the newest such row is younger than
  W/2; else 3, `remaining=` W minus its age. A fix in the repository
  (`ON CONFLICT DO NOTHING` behind a unique constraint, or the resend
  gone) and a fix on the database alone (a unique constraint: the resends
  then fail with 23505 in the producer's log, which the GM weighs) read
  alike. Before the load starts the table has no recent rows and the
  check reads 0.
- **Fixed**: at most T duplicate rows inserted in the trailing W.
- **A scenario using it** runs the key so that, present, any window W at
  the stream's lowest multiplier is expected to hold at least 20 × (T+1)
  duplicates, so a half-window without one never happens by chance and
  the early check at night reads present.

**6. `scheduler-transaction-held-open`: a consumer holding transactions
open** (14b).

- **Seed change**, `queries.yaml` and `schedule.yaml` (open — proposed,
  item 12 point 2): `{KEY}`'s entry carries `transaction: {isolation:
  repeatable read, hold: <duration>}`, and a stream of the schedule runs
  `{KEY}` at a rate and concurrency giving rate × hold ≥ 1, so one such
  transaction is always open. Repeatable read (or a write inside the
  transaction) is required: a read-committed, read-only transaction
  keeps no snapshot between its statements and holds back no vacuum.
- **Parameter** `key`.
- **Aging** 2h: `idle in transaction` at once; "dead but not yet
  removable" needs the updated tables to reach their autovacuum
  thresholds.
- **Evidence**: `node`, the entry's hold, the key's `p50_ms` near the
  hold (a call's latency includes it, W1-y); `bastion`,
  `pg_stat_activity` (`state = 'idle in transaction'`, `now() -
  xact_start`, `backend_xmin`, `application_name` the node's hostname),
  `n_dead_tup` rising in `pg_stat_user_tables`. Answer key: the
  PostgreSQL log's autovacuum lines naming dead rows not yet removable
  and the oldest xmin (`node:<db>`).
- **Resolutions**: report and propose only (15.3); the loader refuses
  a fix (item 0). The proposal: the client commits as soon as its
  statements are done; `idle_in_transaction_session_timeout` on the
  database is a guard, not the fix.
- **Check** on the files: 1 while the key's loaded entry carries a
  hold, 0 once it carries none; reachable only where a scenario makes
  the repository editable anyway.

**7. `scheduler-batch-at-peak`: a nightly batch at the daily peak**
(14b).

- **Seed change**, `jobs.yaml`: `{JOB}`'s `at` puts it in the daily
  peak instead of the night.
- **Parameters**: `job`; `shape`, the shape of the node's
  `schedule.yaml` whose busy hours the job must avoid; `quiet-below`, a
  number, default `0.5`, the multiplier at or below which an hour counts
  as quiet.
- **Aging** 1h from the job's first run at its planted time (item 0).
- **Evidence**: `node`, the job's `at` (UTC) in `jobs.yaml`, the log's
  `run job={JOB}` lines at that time with their `ms=`, the other keys'
  `p95_ms` in the same minutes; `bastion`, `pg_stat_activity` and
  `pg_locks` during a run. Answer key: the PostgreSQL log's lock waits at
  the job's time (`node:<db>`), latency in Grafana.
- **Fixed**: every run of the job, as loaded, falls in an hour where the
  shape's multiplier is at most `quiet-below`, on each weekday it runs.
- **Check** (choice: the rendered shape is already in UTC per weekday,
  so the check needs no shift): it reads the shape from
  `/opt/gm/seed/schedule.yaml` (root) and the loaded job's `at` and
  `timezone`; 0, 1, 2.
- **A scenario using it**: the job's key is a transaction updating rows
  the daytime streams update (lock waits at the peak); `quiet-below`
  lies below every business hour's multiplier and at or above the
  night's.

**8. `scheduler-job-wrong-timezone`: a job in the wrong time zone** (14b).

- **Seed change**, `jobs.yaml`: `{JOB}` carries `timezone_offset:
  {OFFSET}`, its `at` as designed (D168); render writes `timezone:
  Etc/GMT∓M`, M the shift plus `{OFFSET}` wrapped into UTC−12..UTC+14
  (8.3, `render.render_jobs`).
- **Parameters**: `job`; `offset`, an integer, never 0, equal to the
  `timezone_offset` the scenario writes on the job (the loader checks
  neither the equality nor the job; chunk 15 keeps them equal).
- **Aging** 1h from the first run at the wrong time (item 0).
- **Evidence**: `node`, the job's `timezone:` beside its `at` in
  `jobs.yaml`, the log's `run job={JOB}` lines; `bastion`, the story's
  customer time zone (`{{customer_timezone}}`, filled by render).
- **Fixed**: the job, as loaded, runs at its designed time of day in
  the customer's zone, whatever the form (the customer's zone beside the
  `at`, the `at` in UTC with no zone, any zone giving those instants).
- **Check** (choice: the only inputs a check has are its parameters and
  the node's files): from the seed copy of `jobs.yaml` it reads the `at`
  as designed and the zone M, takes the customer's offset as M minus
  `{OFFSET}` brought into −11..+12 (the shift's range, so the answer is
  unique), and compares the loaded job's run times with that `at` read
  in the customer's zone; 0, 1, 2.

**9. `pgbouncer-pool-too-small`: a pool too small for the peak** (14b).

- **Seed change**, `pgbouncer.ini`: the pool for `{DATABASE}`
  (`default_pool_size`, or the `[databases]` entry's `pool_size`) set
  below what the clients' peak needs, under `pool_mode = transaction`.
- **Precondition** (choice, from W1-y and 7.2): `pool_mode =
  transaction` in effect. A scheduler keeps its sessions for the whole
  game, so in session mode each pins a server connection and the
  shortfall is constant from the first minute, not the peak's.
- **Parameters**: `database`, the `[databases]` entry; `min-pool-size`,
  an integer, the smallest pool that serves the peak, inside the
  scenario's `default_pool_size` envelope and below the database's
  `max_connections` less its other clients.
- **Aging** 30m of business-hours load (item 0).
- **Evidence**: `node`, `SHOW POOLS` (`cl_waiting`, `maxwait`) and
  `SHOW DATABASES` (`pool_size`) on the console as `dba`,
  `pgbouncer.ini`, the log's per-period `stats:` lines with their wait
  times (`stats_period` set in the seed). Answer key: the clients'
  `p95_ms` at the peak (`node:<producer>`), Grafana.
- **Fixed**: the database's pool size in effect (`SHOW DATABASES`) at
  least `min-pool-size`, and `max_db_connections` in effect 0 or at least
  `min-pool-size`. The pool mode is not judged. Check on the console;
  0, 1, 2.
- **A scenario using it** gives the knob `default_pool_size` the seed's
  small value as `initial` and an envelope reaching `min-pool-size`, and
  sizes the clients so waits show in business hours and most at the
  peak.

**10. The scenario's choice** (writes: chunk 15a; read by 15b; proposed
for G7, which reviews the faults, write policies and aging, item 12
point 3).

Ten instances: seven of the eight and the three existing faults 15.2
names. Every one is planted at T0 but `f8`; aging 16h, `handover_at:
"14:00"`, so the designed T0 is 22:00 the evening before and the peak
hour is 12; the instance minima below count from that T0. Table and key
names are proposed; 15a's data and repositories fix them, and the
parameters follow.

| Inst. | Fault | Node | Parameters (proposed) | `plant_at` | Instance `aging_minimum` | Expected |
|---|---|---|---|---|---|---|
| f1 | `scheduler-query-error` | producer | `key` a lookup pool entry (a type error, about one call in ten) | T0 | — | fix |
| f2 | `scheduler-report-unbounded` | consumer | `key` a sales report, `date-column` `placed_at` | T0 | — | propose |
| f3 | `scheduler-insert-retry-duplicates` | producer | `database` `shop`, `table-name` `delivery_events`, `id-column` `event_id`, `time-column` `received_at`; window 30m, threshold 0 | T0 | — | fix |
| f4 | `scheduler-transaction-held-open` | consumer | `key` a dashboard read, repeatable read, hold of minutes | T0 | — | propose |
| f5 | `scheduler-batch-at-peak` | producer | `job` the nightly close-day batch, `at` "0 12 * * *", `shape` `business-hours`, `quiet-below` 0.5 | T0 | 15h (first run at T0 + 14h) | fix |
| f6 | `scheduler-job-wrong-timezone` | consumer | `job` the export, `at` "0 2 * * *", `offset` −8 (runs at 10:00 the customer's time) | T0 | 13h (first run at T0 + 12h) | fix |
| f7 | `pgbouncer-pool-too-small` | pooler | `database` `shop`, `min-pool-size` from 15b's measurement, seed `default_pool_size` below it | T0 | 10h (the morning's business hours) | fix |
| f8 | `pg-join-index-missing` | db | `database` `shop`, `table-name` `order_lines`, `column` `order_id` | `handover-6h` (08:00) | 4h | fix |
| f9 | `pg-table-autovacuum-off` | db | `database` `shop`, `table-name` `orders` | T0 | 12h | fix |
| f10 | `prometheus-scrape-target-missing` | prometheus | `node` `pooler` | T0 | — | propose |

- **Left out: `scheduler-update-without-where`.** Of the eight it
  alone adds a write load that grows with its table and runs at every
  call for sixteen hours (WAL, dead rows and CPU on the database's one
  CPU, on armenelos' 4.4G available and 10G free), and its evidence
  families are carried here by others: dead rows by f9, lock waits by
  f5, rows per call in `pg_stat_statements` by f2. The duplicates fault
  stays: it is the only behavioural check, which 15a's answer-key
  windows and the release gate's "sealed checks right under load before
  and after fixes" need. Chunk 14 builds and verifies the left-out fault
  all the same.
- **Why these existing ones**: f8 is the `state` fault planted during
  the aging that 15.2 asks for (the index dropped "this morning");
  `handover-6h` is at least its minimum 4h and at most the aging (6.1).
  f9's table is the hot one: the producer's order updates (a stream
  marking orders shipped) and f5's batch make its dead rows. f10 leaves out the pooler, the one node whose only
  metrics are node health (D139), so its CPU at the peak shows nowhere;
  it sits on the report-only Prometheus, so it is a proposal.
  `pg-stat-statements-not-preloaded` is not taken: it would hide f2's,
  f3's and f4's statistics.
- **Write policies**: `db` and `pooler` fixable; `producer` report-only
  with `write_overrides` `/srv/scheduler/repository` and
  `/srv/scheduler/jobs`; `consumer` report-only with
  `/srv/scheduler/jobs`; `prometheus` report-only; `grafana` fixable;
  `exporter` fixable (choice, as `fixture-load`; item 12 point 4);
  `bastion` report-only.
- **What the topology, data and schedules give the faults**: the
  producer connects through the pooler (`pooler:6432/shop`), the
  consumer directly to the database (f4's held transactions then pin no
  pooled connection, and f7 starves the producer only); `pgbouncer.ini`
  in transaction mode; the ingestion stream (f3) unshaped, since
  deliveries arrive at night too; one job on the consumer left right
  (a nightly roll-up) as the reference beside f6's export; the seed
  `postgresql.conf` with `fixture-load`'s logging block and preload;
  `orders` and `order_lines` large enough for f2's spill and f8's slow
  lookups, inside the database's disk reservation; `delivery_events`
  with no unique constraint on `event_id`; Prometheus' retention at least
  20h (f10's material keeps the retention as written).
- **Interactions** the answer key records: from 08:00 f8's slow lookups
  hold pooled connections longer and deepen f7's waits at the peak; f4
  holds back vacuum on every table but `orders`, which autovacuum never
  visits (f9); f5's batch at noon adds dead rows to `orders`; f10 hides
  the pooler's node health, not f7's evidence (the console and the log).
  f1's key is neither f8's lookup nor f3's ingestion.
- **Score**: `difficulty: {score: 10, level: normal}`.
- **The smoke deployment** (`smoke-scenario.sh`, 15a's done-when): f3
  reads present only once the ingestion has run a few minutes after
  `start-load`, so its polling must allow for that.

**11. Chunk 14's verification on `fixture-load`** (read by 14).

The plan plants each fault on a deployment of `fixture-load`, which
chunk 14 does not own (chunk 12's, deployed at every wave gate). As it
stands it can carry f1's, the time-of-day faults' and the held
transactions' plantings (its producer's `orders.lookup` pool, its jobs
`refresh-stats` and `nightly-rollup`, the shape `business-hours` with
its night at 0.5, the consumer's repeatable-read `reports.top-customers`),
but not the others: the unbounded report needs a table that spills (its
`orders` holds 20 000 rows), the duplicates need a client id column and
a builder, the pool needs transaction mode, and the update needs a small
table. Chunk 14 plants on its own copies of `fixture-load` outside the
repository, with what each fault needs added, and leaves
`tools/tests/fixtures/fixture-load/` as it is.

**12. Points not the driver's to settle** (for `spec-writer`, the owner
or G7; chunks 14 and 15 build on the proposals).

1. **open — proposed: where the duplicates check reads the data.** 15.3
   and the plan judge the duplicates over a window from the data; 6.5
   says a check on a database connects as the GM check role; but a
   check runs only on its instance's node (`checks.py`), here the
   producer, which holds no GM check role password and no `check-psql`.
   Proposed (A): the scheduler brick declares `gm_check_password`
   alike (one secret, both nodes, as `pgbouncer_lookup_password` is),
   root-only on the scheduler node, and a scenario with the duplicates
   fault admits `gm_check` from the game network by `scram-sha-256`
   under its DO NOT TAMPER comment (D171's `local` line covers only the
   socket); the check connects straight to the database's port 5432
   (never the pooler), inside the reserve, with the `database` parameter
   and a `db-node` parameter naming the database node. Its cost: chunk
   3's `brick.yaml` and `docs/gm.md` (unreleased), outside chunk 14's
   Files; the plan's "as the GM check role (its `CONNECT` … D176)" reads
   as if it expected this. Alternative (B), inside chunk 14: the check
   connects as the producer's own role (its root-only
   `role_<role>_password`), straight to port 5432; it breaks 6.5 and has
   no reserve. Rejected: a cause-only check of the repository's text,
   which 15.3 and chunk 14's done-when exclude. Blocks only that check;
   14a's three others and 14b go ahead.
2. **open — proposed: the held transactions' home.** 15.3 places the
   fault in "schedule (hold)" and makes it report or propose only, but
   7.1 (and the brick as built) puts the hold on a repository entry's
   `transaction:`, a file a scenario may make fixable. Proposed (item 6):
   the seed changes name both `queries.yaml` (the hold) and
   `schedule.yaml` (the stream keeping one open), so the loader refuses a
   fix anywhere; 15.3's wording to say the hold is the repository's and
   its frequency the schedule's.
3. **open — proposed (G7): the scenario's choice**, item 10: the
   left-out fault, the names, the offset and the times.
4. **open — proposed (G7): the monitoring nodes' policies.** 15.2 and
   the plan say "one monitoring node fixable, one report-only"; the
   topology has three. Proposed: Prometheus report-only, Grafana and the
   exporter fixable, as `fixture-load`.
5. **A reading for `spec-writer` to confirm**: the time-of-day faults'
   minima count from their first run (item 0), where 6.3 reads "once
   planted".

### Chunk 13 merged — 2026-10-28

- 3b9be51 (merge 5f51422), `coding-leader` in chunk mode. Every item of
  master spec 13's "The GM skill" mapped to `SKILL.md`; 106 `gmctl`
  invocations (variants included) parse with `gmctl`'s parser; unit
  suite 653 OK; links checked by script. v0.2's stance items kept;
  v0.3's three added. `gmctl.md`'s deploy entry matches ea3de4a.
- Readings, beyond the spec's words: without a snapshot, the restart's
  statement names the lost evidence by place and time span, never by
  fault (master spec 12 against the no-reveals rule; ruled below);
  v0.2's "restart or reset" refusal now reads "of a node or a service";
  the bastion's new host key after a restart with no snapshot; at
  hand-over in a game that ages, nobody touches the load; the rules at
  hand-over include asking for a restart. `SKILL.md` grew from 628 to
  1207 lines (a GM session loads about twice as much).

### Capture W4's open items and chunk 13's reading — owner's rulings, 2026-10-28

1. W4 item 12.1, the duplicates check's access: **(A)**. The scheduler
   brick declares `gm_check_password`, shared as
   `pgbouncer_lookup_password` is, and the scenario's `pg_hba.conf`
   carries a do-not-tamper `host` line for `gm_check`; the check
   connects to db:5432 as the GM check role (master spec 6.5). This
   adds the scheduler brick's files to chunk 14 (its 0.1.0 version).
2. W4 item 12.2, held transactions: the fault's seed changes name both
   `queries.yaml` and `schedule.yaml`, so it is report or propose only on
   every node; master spec 15.3's "lives in the schedule" to be
   corrected.
3. Chunk 13's reading of master spec 12: the restart's statement
   without a snapshot names the lost evidence by place and time span,
   never a fault; spec 12's wording to follow.
4. W4 items 12.3 and 12.4: chunk 15a builds the scenario as W4 proposes
   (`scheduler-update-without-where` left out; Prometheus report-only,
   Grafana and the exporter fixable); the owner reviews it at G7, before
   chunk 15 merges.
5. W4 item 12.5 (the time-of-day faults' minima counted from the first
   run) goes to `spec-writer` to confirm against master spec 6.3.

Sent to `spec-writer`: record 1 to 3 (and 5) as decisions, revise
master spec 6.5/15.2/15.3/12 as needed and the plan (chunk 14's Files
and Scope), before chunk 14's branch is cut.

### Rulings recorded; plan v15 — 2026-10-28

- `spec-writer`, eea1e20: D185 (the duplicates check as `gm_check`,
  straight to db:5432; the scheduler brick declares `gm_check_password`;
  the scenario's `pg_hba.conf` `host` line), D186 (held transactions on
  both files, report or propose only), D187 (the restart's statement by
  place and time span), D188 (the scenario as W4 item 10, three
  monitoring policies; G7), D189 (a reading of 6.3, not a change: the
  instance's own minimum counts from planting, the scenario raising it
  for time-of-day faults; nothing for the owner). Master spec 6.3, 6.5,
  7.1, 12, 15.2, 15.3; plan v15 (chunk 14's Scope, Files, split rule;
  15a's Scope; G7).
- No loader check for D185's `pg_hba.conf` line or D189's raised
  minima (both carried by the faults' `gm.md`); the owner may ask for
  them later. The working records `aging-and-timeline.md` and
  `faults-with-activity.md` keep the old wording (the master spec wins).
- Chunk 14 dispatched from eea1e20 and this entry.
