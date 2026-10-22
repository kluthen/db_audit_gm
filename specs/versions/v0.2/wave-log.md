# db_audit_gm v0.2 — Wave log

Execution record for [build-plan.md](../../archive/v0.2/build-plan.md). Kept by the wave
driver (the owner's top-level session).

## Wave 1 — started 2026-10-21

Chunks: 1 (1a, 1b), 2, 3, 4 (4a, 4b). Branch `v0.2-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.2-w1`, cut from `main` at 6687437
(v0.2 spec and plan approved).

- **Concurrency.** The owner allowed several chunks in flight for this
  session (2026-10-21): κ = 3 for wave 1. Chunk 1 runs first (2, 3 and
  4 depend on it); then 2, 3 and 4 run side by side, each in its own
  worktree. They share no source file (plan, "Files" lines).
- **Gates.** G2 cleared (2026-10-21): from the build host, Debian's
  `trixie` repository, the PostgreSQL `trixie-pgdg` repository, the
  s6-overlay, Prometheus and `postgres_exporter` GitHub releases and
  Grafana's apt repository all answer; `apt-get update` succeeds inside
  a `debian:13-slim` container. G3 cleared (2026-10-21): swarm active,
  one node (`armenelos`, manager, Docker 29.9.1).
- **Host.** 10G free on `/`; about 3G of memory available of 11G at
  wave start, so stack tests from parallel chunks may contend.
- **Preflight.** None: no intent register, no data register (plan,
  "Read first").
- **Captures** (recorded here before any code, per the plan's "Read
  first"):

### Capture W1 — v0.2 template keys (chunk 1; read by 2, 3, 4)

Recorded 2026-10-21, before any code; drafted from master spec 6 to 8,
`formats.md` v15, the v0.1 templates and `tools/gm/model.py`, then
reviewed by the wave driver (resolutions at the end). Chunk 1 writes
these keys into `.claude/skills/scenario-format/templates/` and migrates
the v0.1 definitions; chunk 2 checks them in `tools/gm/model.py`; chunk 3
generates secrets by kind; chunk 4 declares `prometheus` with them.
Conventions that still hold: snake_case keys; modes as quoted octal
strings (W1-D of v0.1); sizes and CPU written as in a scenario's
`resources`; a key marked `# optional: <when>` is in the template
uncommented, so the loader checks its shape when present. New keys
marked *optional* let the v0.1 definitions load without them; new keys
marked *required* are added to every definition by chunk 1.

**1. Footprint** (`brick.yaml`, required; chunk 1; chunk 2 checks units).
The shape of a scenario node's `resources`; the flat `{cpu, memory,
disk}` goes. A brick's own footprint never includes material other
bricks mount into it.

```yaml
footprint:
  limits:       {cpu: 1, memory: 1G}
  reservations: {cpu: 0.5, memory: 512M, disk: 1G}
```

Migration: each v0.1 figure becomes the reservation; the limits are
twice the CPU and memory figures (postgres 1 / 1G, reservations 0.5 /
512M / 1G; bastion 0.5 / 256M, reservations 0.25 / 128M / 256M), the
limits `bookshop-new-server` already uses. `footprint_ranges` stays
commented out.

**2. Parameters gain an optional `shape`** (`brick.yaml`; read by 2, 3, 4).

| `shape` | Value in `scenario.yaml` | How the container gets it |
|---|---|---|
| absent (scalar) | a scalar, as in v0.1 | `GM_<NAME>`, as in v0.1 |
| `node-map` | map: node name -> `default` or a list of service names | never as `GM_*`; the renderer turns it into per-node configs (item 4) |
| `web-routes` | map: route name -> `"<node>:<port>"` | `GM_<NAME>` = `name=node:port` tokens, space-separated, sorted by name; `""` when the map is empty |

The template's comment on `default` says it "may be {}", so
`web_routes: {default: {}}` loads.

**3. Web interfaces and the routes parameter** (read by 2, 4; built by
7, 10). `interfaces` becomes *required* (both v0.1 bricks have it). A
`provides` entry the web front publishes adds `web_path`:

```yaml
interfaces:
  provides:
    - {name: ssh, protocol: ssh, port: 22}
    - {name: ui, protocol: http, port: 9090, web_path: /prometheus/}  # optional: a web interface
  consumes: []
```

- The upstream serves under its own fixed `web_path`; the front forwards
  the path unchanged.
- The bastion (chunk 7, at 0.2.0) declares the parameter `web_routes`
  (`shape: web-routes`, `default: {}`, `required: false`) and
  `{name: web-front, protocol: http, port: 8080}`.
- Scenario: `web_routes: {prometheus: "prometheus:9090", grafana:
  "grafana:3000"}`. Route `<name>` is served at `/<name>/` on the front
  and is what `ui:<name>` names.
- Loader rules (chunk 2): each route's node exists and its brick
  provides a web interface on that port with `web_path: /<name>/`;
  every web interface in the topology has exactly one route; the
  bastion's `published_ports` has `{port: 8080, default: 8080}` exactly
  when `web_routes` is non-empty. An empty map: the front does not run
  (D103).

**4. Mounted companion material** (`brick.yaml` `companion.mounted`,
optional; read by 2, 4, 5).

```yaml
companion:                           # optional: only when the brick ships companion/
  path: companion/
  when: <when the GM uses it>
  mounted:                           # optional: material the GM mounts into other nodes
    - name: node-health              # item name, lowercase, hyphens
      parameter: node_health         # this brick's node-map parameter; its keys = receiving nodes
      files:                         # root-owned (0:0), read-only configs in each receiving node
        - source: companion/node-health/node-health.pl   # relative to the brick folder, under companion/
          target: /usr/local/lib/gm/node-health/node-health.pl   # absolute
          mode: "0555"               # no write bit
        - source: companion/node-health/s6/run
          target: /etc/s6-overlay/s6-rc.d/gm-node-health/run
          mode: "0555"
      node_config:                   # the per-node config the renderer writes from the map entry
        target: /opt/gm/node-health/node.conf
        mode: "0444"
      footprint:                     # added to each receiving node's resources by the GM
        limits:       {cpu: 0.005, memory: 5M}
        reservations: {cpu: 0.005, memory: 5M, disk: 0}
      requires:                      # what a receiving image must declare under `receives`
        s6_overlay: "3"              # a version prefix
        commands: [sh, perl, du, cat, s6-svstat, s6-setuidgid]
```

Paths and figures are illustrative; chunk 4 settles them. The per-node
config is UTF-8 text, one `key=value` per line, never empty:

```
node=db
services=postgres sshd
disk_reservation=2147483648
volumes=/var/lib/postgresql/18/data /etc/postgresql /home/player /var/lib/gm-state /run
```

`services`: `default` expanded by the renderer to the brick's
`processes`. `disk_reservation`: the node's
`resources.reservations.disk` in bytes. `volumes`: the in-container
paths of the brick's `volumes`, measured with `du`. Chunk 4 reads this
file; chunk 5 writes it.

**5. Receiving declaration and command vocabulary** (`brick.yaml`
`receives`, optional; read by 2, 4).

```yaml
receives:                            # optional: when the image accepts mounted material
  s6_overlay: "3.2.3.2"              # the version the Dockerfile installs
  commands: [sh, cat, du, df, awk, sed, grep, sleep, perl, s6-svstat, s6-setuidgid]
```

- **Vocabulary.** A command is an executable's basename that
  `command -v` finds on an s6 service's PATH in the image; both sides
  use exactly these names. The v0.2 list is the one above; every name
  exists in `debian:13-slim` plus s6-overlay v3.
- Chunk 1 gives `postgres` and `bastion` 0.2.0 this declaration;
  `prometheus` declares it too (the script runs on its own node).
- `requires.commands` (chunk 4) is a subset of this list; adding a
  command amends this capture and the receiving bricks.
- **Check (chunk 2).** Every node in a mounting node's map has a brick
  with `receives`; its `s6_overlay` begins with the required version
  followed by `.` or the end; its `commands` include every required
  one; checked against the mounting brick's pinned version.

**6. Node-health map** (`prometheus` parameter `node_health`; read by 2,
4, 5). `shape: node-map`, `required: true`, `default: null`.

```yaml
parameters:
  node_health: {bastion: default, db: [postgres, sshd], prometheus: default}
```

Keys: exactly the topology's node names, `prometheus`'s own node
included. Entries: `default` (the brick's `processes`) or a non-empty
list of names from that brick's `processes`. Chunk 2 checks the map as
`scenario.yaml` writes it, before any parameter fault; a missing map or
a missing node is refused.

**7. Secrets by kind** (`brick.yaml` `secrets[]`; read by 3, 4; used by
6, 7, 9, 10). `kind` is *required*.

| Key | Values |
|---|---|
| `kind` | `password` or `key-pair` |
| `handed_over` | *optional, kind password*: `true` for a password players type (16 characters, the v0.1 player alphabet); otherwise 32 characters, the dba alphabet |
| `pair` | *optional, kind key-pair*: the pair's name |
| `half` | *optional, kind key-pair*: `private` or `public` |

Files in `secrets/` (directory 0700, files 0600, written once per
game): a password writes `<name>`; a pair writes `<pair>` (ed25519, no
passphrase) and `<pair>.pub`; each `half` mounts the matching file. The
Swarm secret stays `<game_id>_<name>`. A name declared by two bricks is
one secret; chunk 3 refuses the topology if their `kind`, `pair`, `half`
or `handed_over` differ, or a password's name equals a pair's name.

Migration: `player_password` `kind: password, handed_over: true`;
`dba_password` `kind: password`; `player_ssh_key` `kind: key-pair, pair:
player_ssh_key, half: private`; `player_ssh_pubkey` `kind: key-pair,
pair: player_ssh_key, half: public`. The v0.1 file names stay. New
names, fixed now for chunks 6, 7, 9, 10: `tools_password` (`password`,
`handed_over: true`; bastion and grafana) and `monitoring_password`
(`password`; postgres and postgres-exporter), both at
`/opt/gm/secrets/<name>`. `tools_password` is generated whenever
`bastion` 0.2.0 is in the topology, handed over only when the front
runs (D103).

**8. The `parameter` injection kind** (`fault.yaml`; read by 2, 5).

```yaml
parameters:
  node: {description: the node left out of the map, default: null, required: true}
injection:
  kind: parameter                    # seed-file | state | parameter
  stage: seed                        # planted at render, present from first start
  parameter_changes:                 # optional: kind parameter only; applied in order
    - parameter: node_health         # a parameter of the target node's brick
      op: remove-entry               # set | remove-entry | remove-from-entry
      entry: "{NODE}"                # remove-entry, remove-from-entry: the map key
      # item: "{SERVICE}"            # remove-from-entry: the list item
      # value: <scalar>              # set: the new value
      change: the node's entry is removed, so it gets no node-health script
  run_as: root
```

- `{NAME}` is replaced by the instance's fault parameter: the name upper
  cased, `-` to `_`, as for `FAULT_<NAME>`.
- `remove-from-entry` on a `default` entry first expands it to the
  brick's `processes`.
- A fault is about mounted material when a
  `parameter_changes[].parameter` names an item's `parameter`. It
  targets the mounting brick's node, names only that brick in
  `applies_to`, and has a required parameter `node` naming a node of the
  topology (chunk 2).
- `applies_to.bricks[].versions` takes exact strings only
  (`["0.1.0", "0.1.1", "0.2.0"]`).

**9. Answer-key evidence** (`answer-key.yaml` `instances[].evidence[]`;
read by 2). Each entry is `{where, source, how, shows}`, all *required*.

| `where` | Meaning |
|---|---|
| `bastion` | a shell on the bastion, `psql` from there included |
| `node:<name>` | a node of the topology other than the bastion |
| `ui:<name>` | `<name>` is a key of the topology's `web-routes` parameter |
| `report:<tool>` | a generated report; `<tool>` lowercase (`pgbadger`), not checked against a list |

`source` holds v0.1's free-text `where` unchanged (D101), e.g.
`{where: node:db, source: /etc/postgresql/pg_hba.conf on db, how: …,
shows: …}`. `fault.yaml`'s `evidence` keeps its v0.1 free-text `where`
(see the resolutions).

**10. Tooling expectations** (`answer-key.yaml` top level, required, may
be `[]`; read by 2; rendered by the scenario-document skill).

```yaml
tooling_expectations:
  - id: t1                           # unique across fault instance ids and expectation ids
    need: log analysis               # the need, in a few words
    expected: <what monitoring the GM silently expects of the customer>
    acceptable: <what is acceptable, e.g. any of the top three tools for the need>
    notes: <for feedback>            # optional
```

An issue covers an expectation through its existing `covers` list,
which takes fault instance ids and expectation ids (`covers: [f2, t1]`).
An expectation has no `visibility` and no sealed check; an issue
covering only expectations expects `report` or `propose`. Migration:
`bookshop-new-server` and `fixture-audit` get `tooling_expectations:
[]`.

**Choices made here, not in the spec** (reviewed and accepted by the
wave driver): the footprint's block style and its migration figures;
`shape` (`node-map`, `web-routes`), a `node-map` never passed as `GM_*`;
`web-routes` values as `"node:port"`, passed as `GM_WEB_ROUTES="k=v …"`;
route name = the upstream's fixed `web_path`, no path rewriting, one
route per web interface; `interfaces` required, `web_path` marking a web
interface; the front's port in the scenario's `published_ports` exactly
when `web_routes` is non-empty; `companion.mounted[]` and its keys,
owner always 0:0, no write bit; the `key=value` per-node config with
`volumes`; `receives: {s6_overlay, commands}` with a version prefix and
the command list above; map entries `default` or non-empty lists from
`processes`; secret keys `kind`, `handed_over`, `pair`, `half`; the names
`tools_password` and `monitoring_password`; `stage: seed` and
`parameter_changes` with `set`, `remove-entry`, `remove-from-entry`, the
`{NAME}` substitution and the `node` parameter; `report:<tool>`
unchecked; the expectation keys and shared `covers`.

**Driver's resolutions** (2026-10-21):

- **Rendering shaped parameters.** No wave 1 chunk renders a `node-map`
  or `web-routes` parameter: no wave 1 scenario uses `prometheus` or
  `web_routes`, and chunk 2's fixture is loaded, never rendered. Chunk 5
  (renderer, wave 2, before chunk 7 needs `GM_WEB_ROUTES`) owns it:
  `render.service_environment` skips `node-map` parameters and encodes
  `web-routes` as item 2 says. Sent to `spec-writer` as a plan
  correction to chunk 5.
- **`where` in `fault.yaml`.** Left as v0.1's free text in v0.2: chunk
  1's scope only adds `"0.2.0"` to the faults' `applies_to`, and D101
  rules on the answer key. The same key meaning two things is raised to
  `spec-writer` as an open question for the owner; it blocks nothing in
  v0.2.

### Plan correction sent to `spec-writer` (before chunks 2 to 4 start)

From W1's resolutions. Plan v3 (e8a216b): chunk 5 renders shaped
parameters (`node-map` never as `GM_*`, `web-routes` as sorted
`name=node:port` tokens, `""` when empty); chunk 7 now depends on chunk
5 (in wave 2, the encoding fixed by W1 item 2; chain 5 → 7, two chunks).
Wave 2's membership is unchanged. Open question O78 (`where` in
`fault.yaml`, recommended for v0.3's first format change) recorded for
the owner; it blocks nothing in v0.2.

### Dispatch

- Chunk 1 dispatched 2026-10-21, branch `v0.2-c1-formats` cut from
  f8be8ce (the plan correction does not touch it). Chunks 2, 3 and 4
  start side by side once chunk 1 merges.
- Chunk 1 merged 2026-10-21: 9b1c4d7 (1a), e01b06c (1b), merge fa8e62d;
  169 unit tests pass; both images build as 0.2.0 and both stack tests
  pass; s6-overlay 3.2.3.2 and every `receives` command checked inside
  both images. `smoke.sh` (tags now 0.2.0) left for the wave gate.

### W1 addenda — choices chunk 1 made where W1 was silent (read by 2, 3, 4)

- `interfaces.consumes` entries have `provides`' shape (`name`,
  `protocol`, `port`) and may be `[]`; `provides` may not be empty.
- `companion` is an active optional key in the template: its `path` and
  `when` are checked whenever a brick sets it.
- In `parameter_changes`, `entry`, `item` and `value` are each optional.
- Answer-key `where` in the migrated keys: a bare `psql` (no `-h`) runs
  on the database node (`node:db`); the password-less login
  `psql -w -h db` is `bastion`.
- Both bricks' `docs/gm.md` state under Connections that the image
  accepts mounted material (s6-overlay version, command list).
- Known until chunk 2: the unchanged loader refuses an expectation id in
  `covers` and the `parameter` injection kind; nothing uses either yet.
- Gap: the scenario-document template has no rule for rendering a
  map-valued node parameter (`node_health`, `web_routes`); sent to
  `spec-writer` to place in a chunk.
- Chunks 2, 3 and 4 dispatched 2026-10-21, side by side, from fa8e62d+.
- Plan v4 (8a46e0d, `spec-writer`): the scenario document's rule for
  map-valued parameters placed in chunk 11 (wave 3; brief it there);
  chunk 5 keeps `fixture-mounted`'s inline-YAML rendering. Chunks 1 to 4
  unchanged.
- Chunk 3 merged 2026-10-21: 9e5c8b3, merge 8688c7e; 188 unit tests
  pass on `v0.2-w1` after the merge; `smoke.sh` 46 PASS, 0 FAIL (five
  new checks: network name, status network line, status secret files,
  UTC on db and bastion).

### Capture W1-B — chunk 3 outcomes (read by 5, 6, 7, 9, 10; changes v0.1 W2-A, W3-A)

- **`secrets/`** (`local/<pg>/secrets/`, dir 0700, files 0600): a
  password writes `<name>` (16 characters, player alphabet, when
  `handed_over: true`; else 32, dba alphabet); a key pair writes `<pair>`
  and `<pair>.pub` once, however many halves are declared. Written fresh
  at each deploy attempt, as in v0.1; kept for the game.
- **To the node.** `implementation.yaml` `secrets[]`, one entry per
  declared name in topology order: `{name: <gid>_<name>, secret: <name>,
  kind: password, handed_over: bool, file: local/<pg>/secrets/<name>}`
  or `{name, secret, kind: key-pair, pair, half, file: …/<pair>[.pub]}`.
  `nodes.<n>.secrets[]` unchanged (`name`, `path`, `uid`, `gid`, `mode`).
  Deploy runs `docker secret create <gid>_<name> <file>`; the stack
  mounts it at the brick's `path`.
- **Refusals** (`fit`, checked again at `render`): a name two bricks
  declare differently (`kind`, `handed_over`, `pair`, `half`); a
  password whose file is a pair's file (`<pair>` or `<pair>.pub`); an
  unknown `kind`; a key pair without `pair` or `half`; `pair`/`half` on
  a password; a non-boolean `handed_over`; `handed_over` on a key pair.
  `render` refuses with "fit again" when the bricks' secrets or the
  network changed since `fit`, and re-runs `check_supported`.
- **Network.** Stack key `<network name>`, deployed as
  `<gid>_<network name>`; `implementation.yaml` `network:
  <gid>_<network name>`; every service joins it. Brick stack tests keep
  their own `${STACK}_net`.
- **`gmctl status`.** The v0.1 `credentials:` line is gone; after the
  history, `network: <gid>_<network name>` (whenever
  `implementation.yaml` exists), then for a deployed, not failed game:
  `secrets: <ldir>/secrets/ (mode 0600, not printed)` and one line per
  file (`<name>: password`, `<name>: password, handed over`, `<pair>:
  private key of pair <pair>`, `<pair>.pub: public key of pair <pair>`).
  Deploy's own `credentials:` line is unchanged.
- **Python.** `deploy.generate_credentials(ldir, impl,
  keygen=ssh_keygen)` (was `(ldir, game_id, keygen)`);
  `render.service_environment(brick, node)` returns `TZ` first
  (`render.NODE_TIMEZONE = "UTC"`), `build_stack` always sets
  `environment`. New in `localimpl`: `network_name(scenario)`,
  `secret_file(sec)`, `game_secrets(scenario) -> (secrets, problems)`,
  `implementation_secrets(scenario, playground, game_id)`, constants
  `PASSWORD`, `KEY_PAIR`, `SECRET_KINDS`, `KEY_HALVES`,
  `PUBLIC_KEY_SUFFIX`. New in `state`: `secret_files(impl)`. Removed:
  `localimpl.SECRET_FILES`, `localimpl.NETWORK_KEY`.
- **Known.** An `implementation.yaml` from before this chunk is refused
  at render ("fit again"); stale files in `secrets/` a new game no
  longer declares stay, as in v0.1.
- Chunk 2 merged 2026-10-21: cd3b33f (2a), bdc7547 (2b), merge ff86571;
  253 unit tests pass on `v0.2-w1` after the merge (chunk 3 in). New
  fixture `tools/tests/fixtures/fixture-mounted/` (scenario-local
  `fixture-front` with `web_routes`, `fixture-app`, `fixture-monitor`
  mounting `node-health` into every node; a state fault and a
  parameter fault `remove-entry {NODE}`; `ui:monitor` and `node:app`
  evidence; expectation t1 covered by a report issue). Its README shows
  the maps as inline YAML until chunk 11.

### Capture W1-C — chunk 2 outcomes (read by 4, 5, 7, 11, 12, 13)

Loader choices where W1 was silent (no deviation from W1 or the spec):

1. The command vocabulary is closed: a `receives.commands` or
   `requires.commands` name outside W1's eleven is refused.
2. A `web_path` is `/<name>/`, one lowercase name between slashes.
3. A `parameter` fault has `stage: seed`.
4. Ops and shapes: `set` takes a scalar (unshaped) parameter,
   `remove-entry` a shaped one, `remove-from-entry` a `node-map`; a
   missing or extra `entry`/`item`/`value` is refused; `{NAME}` names a
   parameter of the fault.
5. `node:<name>` evidence never names the bastion ("write bastion").
6. `report:<tool>` matches `[a-z0-9][a-z0-9._-]*`.
7. A tooling expectation with `visibility` or `sealed_check` is refused.
8. "Every node of the topology" applies to a node-map that a
   `companion.mounted` item names; the entry rule (`default` or a
   non-empty list of the brick's processes) applies to every node-map.
   A node left out is refused by the map check, so its `receives` is not
   checked.
9. Exact versions are semver strings (pre-release or build suffix
   allowed); ranges, wildcards and non-strings are refused.
10. Brick footprints and `companion.mounted[].footprint` are
    unit-checked.
11. The answer key is checked before the issues, so expectation ids are
    known in `covers`.

Consequence until chunk 7: a web interface without a route is refused,
and `bastion` 0.2.0 has no `web_routes` yet, so a scenario putting
`prometheus` next to `bastion` does not load before chunk 7 merges. No
wave 1 or wave 2 scenario does.

The refusal messages, each asserted in `tools/tests/test_model.py`
(classes `TestMountedBrickRefusals`, `TestNodeMapRefusals`,
`TestReceivingRefusals`, `TestWebRouteRefusals`,
`TestParameterFaultRefusals`, `TestAnswerKeyRefusals`), are the
reference for chunks 12 and 13; two replace v0.1 messages:
`issues[<I>].covers: <id> is not a fault instance or a tooling
expectation`, and `injection.kind: <k> is not seed-file, state or
parameter`. `fault.yaml`'s own `evidence[].where` stays free text (O78),
pinned by a test.
- Chunk 4 merged 2026-10-21: 54279f8 (4a), d05bb10 (4b), merge 4c47239;
  stack test 101 PASS, 0 FAIL; 253 unit tests pass on `v0.2-w1` after
  the merge (chunk 2's loader accepts `brick.yaml`).

### Capture W1-D — chunk 4 outcomes (read by 5, 9, 10, 11, 13, 14)

- **`companion.mounted` as built** (all files uid and gid 0):

```yaml
companion:
  path: companion/
  when: at every deployment of a scenario with a prometheus node: the GM mounts companion/node-health into every node the node_health map lists
  mounted:
    - name: node-health
      parameter: node_health          # shape: node-map, required: true, default: null
      files:
        - {source: companion/node-health/node-health.pl, target: /usr/local/lib/gm/node-health/node-health.pl, mode: "0444"}
        - {source: companion/node-health/s6-rc.d/gm-node-health/type, target: /etc/s6-overlay/s6-rc.d/gm-node-health/type, mode: "0444"}
        - {source: companion/node-health/s6-rc.d/gm-node-health/run, target: /etc/s6-overlay/s6-rc.d/gm-node-health/run, mode: "0555"}
        - {source: companion/node-health/s6-rc.d/gm-node-health/dependencies.d/base, target: /etc/s6-overlay/s6-rc.d/gm-node-health/dependencies.d/base, mode: "0444"}
        - {source: companion/node-health/user-bundles.d/user/contents.d/gm-node-health, target: /etc/s6-overlay/user-bundles.d/user/contents.d/gm-node-health, mode: "0444"}
      node_config: {target: /opt/gm/node-health/node.conf, mode: "0444"}
      footprint:
        limits:       {cpu: 0.005, memory: 6M}
        reservations: {cpu: 0.005, memory: 6M, disk: 0}
      requires: {s6_overlay: "3", commands: [sh, perl, du, df, s6-svstat]}
```

- **Per-node config**: W1's format; `node`, `services`
  (space-separated), `disk_reservation` (bytes), `volumes`
  (space-separated absolute paths) all required; `#` and blank lines
  ignored; a missing or malformed file logs `gm-node-health: fatal: …`
  and retries every 30 s. Hand-written examples:
  `bricks/prometheus/tests/fixtures/node-health/{db,prometheus}.conf`;
  `tests/stack.test.yml` shows the config mounts (chunk 5's model).
- **Endpoint**: port 9110, `GET /metrics`, one request at a time, 5 s
  header timeout; CPU time and limit, memory used, working set and
  limit, disk used against the reservation, per-volume use, host free
  space, `service_up` per listed service, `node_health_sample_age_seconds`
  (disk up to 30 s old, services up to 5 s).
- **Accounts**: a root sampler running only `s6-svstat`, `du` and `df`,
  holding no socket; a forked listener dropping to `nobody:nogroup`
  (65534) before opening 9110. Each `supervise/` is root 0700, and the
  volumes (PGDATA `postgres` 0700) are unreadable to another account.
- **Prometheus node**: Prometheus 3.13.5 (checksummed), `:9090` under
  `/prometheus/` (only a redirect from `/` outside it); `POST /-/reload`
  and `PUT /-/quit` 403, admin APIs 500 "admin APIs disabled".
  Retention in the seed `prometheus.yml`
  (`storage.tsdb.retention.{time,size}`, fixture 1d / 256MB): a
  retention fault (chunk 13) is a `prometheus.yml` seed-file fault.
  `gm-reload-prometheus` checks with `promtool` as `prometheus`, sends
  `s6-svc -h`, waits for a new reload timestamp and prints the
  retention in effect. Validator rules: `config`, `server`, `reload`,
  `pending`, `retention` (bounded by time and size). Write policy
  `fixable` only; `consumes: []` (targets from the seed file);
  `knobs: []`.
- **Footprint**: the brick's own, master spec 12's figures less the
  script: limits 0.495 CPU / 378M, reservations 0.095 CPU / 154M /
  512M disk. Image about 488MB (`prometheus` 131M and `promtool` 109M
  binaries) against spec 12's 150M estimate: for chunk 8's `fit` and
  chunk 14b's footprint.
- **Known**: no scenario can use `prometheus` before chunk 7 (route for
  its `ui`); the root `README.md` row for `bricks/` does not list
  `prometheus` (fixed at the wave gate).

### Wave gate — 2026-10-21

On `v0.2-w1` at a450269, build host `armenelos` (Debian 13, Docker
29.9.1, 12 CPUs, 11G), idle (no other stack), 2026-10-21T14:40Z. All
PASS:

| Check | Result |
|---|---|
| Unit suite | 253 tests OK (19 s) |
| `sh -n`, every shell file | 49 files OK |
| `perl -c`, every Perl file | `node-health.pl` OK |
| Image builds | `postgres:0.2.0` 260MB, `bastion:0.2.0` 179MB, `prometheus:0.1.0` 488MB |
| Stack tests | postgres 51 PASS, bastion 39 PASS, prometheus 101 PASS |
| `smoke.sh` (fixture-audit) | 46 PASS, nothing left behind |

No failure, no fix commit. No bundle or performance figure applies;
images added this wave: `prometheus:0.1.0` 488MB (`postgres` and
`bastion` 0.2.0 equal their 0.1.1 sizes). 10G free on `/`. The root
`README.md` bricks row now lists `prometheus` (shared list chunk 4 left).
No wave sync: no intent register.

### Report to the owner — 2026-10-21

Chunks 1 to 4 merged, none moved; gate green. For the owner: the
node-health sampler runs as root (listener as `nobody`), the case the
spec settles when `s6-svstat` cannot read unprivileged, narrowed by
chunk 4; Prometheus' retention is in `prometheus.yml` (3.13 deprecates
the flags), D106 still holds; the `prometheus` image is about 488MB
against master spec 12's 150M estimate (chunks 8 and 14b count it);
O78 open (not blocking). Open gates after wave 1: G10 and G11 (owner,
waves 4 and release). Plan at v4. Branches left: `v0.2-w1` only (every
chunk branch and worktree removed). Next: wave 2 (chunks 5, 6, 7; chain
5 → 7), from `main` once wave 1 merges.
- Merged into `main` 2026-10-21 on the owner's word: 6467fb5. Branch
  and worktree `v0.2-w1` removed.

## Wave 2 — started 2026-10-21

Chunks: 5, 6, 7 (chain 5 → 7). Branch `v0.2-w2`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.2-w2`, cut from `main` at
6467fb5 (wave 1 merged).

- **Concurrency.** The owner's allowance for this session holds: 5 and
  6 run side by side (no path between them, no shared source file); 7
  starts once 5 merges.
- **Gates.** G2 and G3 done (wave 1); swarm still active, host idle.
- **Preflight.** None (no intent register, no data register).
- **Captures.** None new at wave start: chunk 5 implements W1 items 2
  and 4 against W1-D's declaration as built; chunk 6 reads W1 item 7
  (`monitoring_password`) and W1-B; chunk 7 reads W1 items 2, 3 and 7
  (`tools_password`), W1-B and W1-C.
- Chunks 5 and 6 dispatched 2026-10-21.
- Chunk 5 merged 2026-10-21: 2ad4c21, merge 6248ad0; 277 unit tests
  pass on `v0.2-w2` after the merge (253 before); `docker stack config`
  accepts the rendered fixture-mounted stack; `smoke.sh` 46 PASS (one
  rerun: chunk 6's `gmtest-pg` stack test started during the first and
  tripped "objects not belonging to the game are unchanged"). Every
  Done when item shown by a named test.

### Capture W2-A — chunk 5 outcomes (read by 7, 11, 12, 13, 14)

- **`implementation.yaml`, per receiving node**, appended to
  `nodes.<n>.configs[]` after the seed and envelope entries: one entry
  per mounted file,
  `{kind: mounted, item, name: <gid>_<mounting node>_<item>-<k>, file, path, uid: 0, gid: 0, mode}`
  (`k` from 1 in `files` order; for a catalog brick `file` is relative to
  the scenario folder, climbing out to `../../bricks/<brick>/…`), then
  the node's own
  `{kind: node-config, item, name: <gid>_<node>_<item>.conf, file: local/<pg>/mounted/<item>/<node>.conf, path: <node_config.target>, uid: 0, gid: 0, mode}`.
- **Swarm names**: each mounted file is one config shared by every
  receiving node (deploy's name dedupe creates it once); the per-node
  config is `<gid>_<node>_<item>.conf`. `max_game_id_length` reserves
  room for these names (fixture-mounted's game id: at most 39
  characters); `_check_names` refuses one name derived for two files.
- **`parameter_faults`**: a new top-level key of `implementation.yaml`,
  always present (`[]` when none):
  `[{instance, fault, node, changes: [{parameter, op, entry|item|value}]}]`,
  `{NAME}` already substituted. A file written before chunk 5 lacks it,
  so `render` refuses it with "fit again".
- **Parameters**: `service_environment` uses the fault-applied
  parameters, so a parameter fault now reaches `GM_*` values (changes
  v0.1 behaviour, where none existed). `GM_WEB_ROUTES` as W1 item 2:
  sorted `name=node:port` tokens, space-separated, `""` when empty; a
  `node-map` parameter is never in the environment.
- **`render`** writes `local/<pg>/mounted/<item>/<node>.conf` (clearing
  `mounted/` first) and prints those paths after the envelope files;
  refuses "the mounted material changed since gmctl fit: fit again" when
  its recomputation differs from `implementation.yaml`.
- **`inject`**: a parameter fault prints
  `  <iid>: parameter fault, planted at rendering; nothing to run` after
  the seed-file lines; `InjectResult.rendered` lists them, `seeded`
  still only seed-file faults.
- **Refusals** (`fit` and `render`): a change that plants nothing,
  `fault instance <iid> (<fault>): <op> <param>: <param> has no entry <e>`
  or `…: entry <e> of <param> has no item <i>`; a missing or empty
  mounted source file ("Swarm refuses an empty config").
- **Python**: `localimpl.parameter_faults`, `node_parameters`,
  `entry_services`, `mounted_material`, `mounted_configs`,
  `node_config_file`, `node_config_text`, constants `MOUNTED_CONFIG`,
  `NODE_CONFIG`, `MOUNTED_DIR`, `MOUNTED_UID`/`MOUNTED_GID`,
  `DEFAULT_ENTRY`, `PARAMETER_KIND`; `render.web_routes_value`,
  `NODE_MAP`, `WEB_ROUTES`, `RenderResult.node_config_files`;
  `inject.InjectResult.rendered`.
- **Left**: the mounted footprint is not added to receiving nodes'
  `resources` (spec 7.1: the scenario's `resources` include it, chunk
  14); `fixture-mounted/scenario.yaml`'s header still says "never
  rendered nor deployed" though tests now render it (chunk 11 fixes it
  when it regenerates that README).
- Chunk 7 dispatched 2026-10-21 (chunk 6 still running).
- Chunk 6 merged 2026-10-21: 60f32d4 (6a), 787bf1d (6b), merge
  f3f6e19; stack test "all checks passed", nothing left behind; 277
  unit tests pass on `v0.2-w2` after the merge. `smoke.sh` not run by
  the chunk (swarm busy); its new counts run at the wave gate.
- **Image tag.** Chunk 6 put the previous image back on
  `127.0.0.1:5000/dbagm/postgres:0.2.0` after its stack test, so
  worktrees without its `brick.yaml` (chunk 7's, cut at d509d65) keep
  working; its image is `postgres:0.2.0-c6` (1ff1b9da83bc). The gate
  rebuilds `postgres:0.2.0` from `v0.2-w2` and removes the `-c6` tag.
  Between 14:58:02Z and 14:59:19Z the new image was on `0.2.0`; chunk 5's
  first smoke run (the one that failed) overlapped that window, and its
  passing rerun came after it. The gate's smoke run is the one that
  counts.
- Chunk 7 told (message): leave the postgres tag alone; chunk 6's
  `smoke.sh` counts (configs+secrets 11, volumes 9, status secret lines
  5) must be combined with its own at the merge.

### Capture W2-B — chunk 6 outcomes (read by 9, 11, 13, 14)

- **Monitoring role**: `monitoring`, `LOGIN`, member of `pg_monitor`,
  not superuser; created once by `gm-entrypoint` when it initialises a
  fresh `pgdata` (single-user mode, before the first listen), never
  re-applied; a cluster from an older image has none. Password from the
  secret `monitoring_password` (kind password, not handed over, 32
  characters) at `/opt/gm/secrets/monitoring_password`, uid 0, gid 102
  (`postgres`), mode 0440; the entrypoint refuses a missing, empty or
  multi-line secret and stops the container. The Dockerfile fails the
  build if `postgres` is not `100:102`.
- **For chunk 9**: connect as `monitoring` to the database `postgres`
  over TCP `<db node>:5432`, `scram-sha-256` through the seed
  `pg_hba.conf` `host` line; declare `monitoring_password` `kind:
  password`, no `handed_over`, at `/opt/gm/secrets/monitoring_password`
  with the exporter's own uid, gid and mode. A scenario restricting
  `pg_hba.conf` must let `monitoring` in from the exporter's node.
- **Logs**: volume `pglog` at `/var/log/postgresql`, `postgres:pgconf`
  2750 (setgid); files 0640 (`log_file_mode`); `player` reads them,
  cannot write. Seed settings (brick test seed and `docs/gm.md`):
  `logging_collector = on`, `log_directory = '/var/log/postgresql'`,
  `log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'`,
  `log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '`
  (pgBadger's default, no `--prefix`), `log_timezone = 'UTC'`,
  `log_rotation_size = 10MB`, `log_rotation_age = 0`; never pruned (1G
  of the disk reservation). `gmctl logs` shows only the start-up.
- **`pg_stat_statements`**: `CREATE EXTENSION` at initdb in `postgres`;
  `shared_preload_libraries = 'pg_stat_statements'` in the seed.
  Without the preload the view errors: the fault chunk 13 plants.
- **pgBadger** 13.2 (PGDG `13.2-1.pgdg13+1`), run by `player` without
  `sudo`, report `~/pgbadger.html`. Peak memory unmeasured (release
  gate).
- **Image** 262MB (was 260MB). **Footprint**: reservation disk 1G →
  2.25G (master spec 12); CPU and memory unchanged.
- **Left**: `bookshop-new-server`'s and `fixture-audit`'s seeds carry
  neither the logging nor the preload settings (outside the chunk's
  files); they load and log to Docker as in v0.1. Chunk 11's fixture
  and chunk 14's node seed files need them: brief both with this
  capture.
- **Risk accepted by the access model**: `dba` (superuser) can read the
  secret through `COPY … TO PROGRAM`.
- Chunk 7 merged 2026-10-21: 3925d13 (7a), eb7fed9 and 893d472 (7b),
  merge 5c50c71 (after 4e69641 merged `v0.2-w2` into the chunk branch);
  stack test 67 PASS, 0 FAIL (with both postgres images); `smoke.sh` 48
  PASS on the chunk branch before chunk 6 came in (two new checks: only
  port 22 published, front not running); 277 unit tests pass on
  `v0.2-w2` after the merge. `bastion:0.2.0` rebuilt from 7a
  (7b9336873f01, 185MB, was 179MB). The merged counts add both chunks'
  objects: `test_teardown.py` 6 secrets; `smoke.sh` 12 configs and
  secrets, 6 status secret lines (Git alone would have taken one 5 for
  both). 893d472 (outside one commit per half): the bastion stack test's
  db node gets `monitoring_password` and `pglog`, which chunk 6's
  entrypoint needs.

### Capture W2-C — chunk 7 outcomes (read by 10, 11, 12, 14)

- **Proxy**: nginx 1.26.3 (Debian 13 package `1.26.3-3+deb13u9`), s6
  service `web-front`, run as `www-data` through `s6-setuidgid`, no
  capability added. Without a configuration the service runs
  `s6-svc -O .` and exits. Image 185MB.
- **Start-up** (`gm-entrypoint` step 7): checks each `GM_WEB_ROUTES`
  token (`name=node:port`, lowercase name, port 1–65535, no duplicate)
  and fails the container otherwise; writes `/run/web-front/`
  (root:www-data 0750) with `htpasswd` (`player:<openssl passwd -6>`,
  root:www-data 0440) and `nginx.conf` (root 0444): `listen 8080`, per
  route `location /<name>/` proxying to `<node>:<port>`, resolved per
  request through `127.0.0.11`; then `nginx -t` as `www-data`. No token:
  nothing written and `tools_password` not read (it is still generated
  and mounted, W1 item 7).
- **Behaviour**: basic auth on every path, user name **`player`**,
  realm `db_audit_gm web front`; 401 with the challenge otherwise. `/`
  lists the routes as plain text; `/<route>` redirects to `/<route>/`;
  other paths 404; an upstream down 502. Forwarded: path and query
  unchanged, `Host $http_host`, `X-Real-IP`, `X-Forwarded-For`,
  `X-Forwarded-Proto`, WebSocket `Upgrade`/`Connection`; `Authorization`
  cleared, an upstream's `WWW-Authenticate` hidden; bodies up to 16M,
  read timeout 300 s; no access log, errors to the container output.
- **Health check**: also requires `web-front` up and listening on 8080
  when `/run/web-front/nginx.conf` exists.
- **`brick.yaml`**: parameter `web_routes` (`shape: web-routes`,
  `default: {}`, `required: false`); provides `{web-front, http, 8080}`;
  consumes `{ui, http, 9090}` and `{ui, http, 3000}` (Grafana's port
  taken from W1's example: chunk 10 confirms it); secret
  `tools_password` (`kind: password`, `handed_over: true`,
  `/opt/gm/secrets/tools_password`, 0:0, `"0400"`); `processes: [sshd,
  web-front]` (node-health on the bastion expects `web-front` up, which
  holds whenever `prometheus` is present, since the loader then
  requires a route); `protected_files` gains `/run/web-front`;
  `extra.web_front_port_default: 8080`.
- **Footprint** unchanged (limits 0.5 / 256M, reservations 0.25 / 128M
  / 256M); idle 5.0 MiB with the front, 2.8 MiB without.
- **For chunk 10**: `player.md` says Grafana asks for its administrator
  login with the tools password, without naming the user (chunk 10's).
- **For chunk 12**: the hand-over is user `player` with the tools
  password, at `http://<host>:8080/<route>/`.
- **Stack test**: `STACK=gmtest-bastion`, `GMTEST_BASTION_PORT`
  (22222), `GMTEST_BASTION_WEB_PORT` (28080); stub
  `tests/fixtures/stub-upstream.pl` in `debian:13-slim` on 9090; routes
  `other=stub:9091 stub=stub:9090`; needs `curl` on the host.
- No root `README.md` change (no row describes the bastion's ports).

### Wave gate — 2026-10-21

Every chunk merged (5, 6, 7), none moved. On `v0.2-w2` at 6d7ceed,
build host `armenelos` (Debian 13, Docker 29.9.1, 12 CPUs, 11G), idle
(no other stack), 2026-10-21T15:31Z, with the wave 1 gate's commands;
`postgres:0.2.0` rebuilt from the wave branch first (chunk 6's tag
note), `postgres:0.2.0-c6` removed at the end.

| Check | Result |
|---|---|
| Unit suite | 277 tests OK (22 s) |
| `sh -n`, every shell file | 50 files OK |
| `perl -c`, every Perl file | `node-health.pl`, `stub-upstream.pl` OK |
| Image builds | `postgres:0.2.0` 262MB, `bastion:0.2.0` 185MB, `prometheus:0.1.0` 488MB |
| Stack tests | postgres 73 PASS, bastion 67 PASS, prometheus 101 PASS (after the fix) |
| `smoke.sh` (fixture-audit) | 48 PASS, nothing left behind |

- **One failure, fixed.** The prometheus stack test failed ("db node
  did not become healthy": `monitoring_password is missing or empty`).
  Traced to chunk 6: its entrypoint requires the secret and its log
  volume, which that test's db node lacked (chunk 7 had fixed the same
  in the bastion test, 893d472). Fixed on the wave branch by a
  `coding-executor`, test files only, a1ceac5; rerun 101 PASS, 0 FAIL,
  nothing left behind.
- **Figures.** No bundle or performance figure applies. Images: the
  postgres image is 2MB larger (262MB) and the bastion image 6MB larger
  (185MB) than at wave 1; prometheus unchanged. 10G free on `/`.
  `postgres` and `bastion` 0.1.0 and 0.1.1 tags still built (prunable).
- No wave sync: no intent register.

### Report to the owner — 2026-10-21

Chunks 5, 6, 7 merged, none moved; gate green after one test-file fix
(a1ceac5, chunk 6's secret missing in the prometheus stack test). For
the owner: the web front's basic-auth user is `player` (with the tools
password); `tools_password` is generated and mounted even without a
front, never read or handed over then (D103 holds); postgres' disk
reservation is now 2.25G (master spec 12); the mounted node-health
footprint goes into the scenario's own `resources` (chunk 14), not
added by `fit`. Left for later chunks: chunk 10 confirms Grafana's port
3000 and names its administrator; chunks 11 and 14 carry postgres'
logging and preload settings in their seeds (W2-B); chunk 11 fixes
`fixture-mounted`'s header and adds the map rule. Open gates: G10 and
G11. Plan at v4. Branches left: `v0.2-w2` only. Next: wave 3 (chunks
8, 9, 10, 11; chain 9, 10 → 11, captures at wave start), from `main`
once wave 2 merges.
- Merged into `main` 2026-10-21 on the owner's word: 351de59. Branch
  and worktree `v0.2-w2` removed.

### Owner direction after wave 2 — 2026-10-21

The owner expects the `postgres` brick to grow many optional elements
(PostGIS, TimescaleDB, pgBadger, replication modules, …), each
documented and added to a scenario when appropriate. Ruled: brick
options go to v0.5 (bricks improved and extended); v0.2 stays as built
(pgBadger, the `pglog` volume, the `monitoring` role and secret in every
game; the logging and preload settings already the scenario's, in its
seed). Sent to `spec-writer` to record in `versions/v0.5/` and the
registers, committed on `v0.2-w3`. Recorded in b59dfee: D107 (the
ruling), O79 (the options model, `postgres` first: where the software
comes from, how a scenario chooses, start-up, faults that need an
option, docs) and O80 (every brick or only `postgres`), both due in v0.5.
Next free: D108, O81.

## Wave 3 — started 2026-10-21

Chunks: 8, 9, 10, 11 (chain 9, 10 → 11). Branch `v0.2-w3`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.2-w3`, cut from `main` at
351de59 (wave 2 merged).

- **Concurrency.** The owner's allowance for this session holds: 8, 9
  and 10 run side by side (no path between them, no shared source
  file); 11 starts once 9 and 10 merge.
- **Gates.** G2, G3 done; G8 done (spec D104). Swarm active, host idle.
- **Preflight.** None (no intent register, no data register).
- **Captures.** W3 (chunks 9 and 10's interfaces, for chunk 11) is
  drafted before 9 and 10 start. Chunk 8 needs none and starts now.
- Chunk 8 dispatched 2026-10-21.

### Capture W3 — postgres-exporter and grafana interfaces (chunks 9, 10; read by 11, 12, 13, 14)

Recorded 2026-10-21, before any code (drafted by a read-only planning
agent, reviewed by the wave driver; the driver's rulings on its open
points follow the capture). Sources: master spec 6, 7, 7.3, 7.4, 12, 15;
access model 5, 7, 8, 11; D98 to D106; captures W1 to W2-C; `prometheus`
0.1.0 as built, which is the model for the s6 setup, entrypoint,
wrappers, validator, capability list, the `/run` volume and the seed
marker. This capture fixes only what chunks 11 to 14 rely on; everything
else is the chunk's, recorded after its merge. "(choice)" marks a point
the sources left open and this capture settles.

**Three API details rest on upstream knowledge, not on the repo**:
`postgres_exporter`'s `DATA_SOURCE_PASS_FILE`, Grafana's `$__file{}`
expansion in `grafana.ini`, and the `pg_stat_statements_*` metric names.
Chunks 9 and 10 confirm them in their stack tests; if the pinned release
differs, the chunk uses what the release offers, keeps the property this
capture states (no credential in a file `player` reads, an argument or
`--env`), and its report gives the actual names for the wave log.

**Both bricks**
- Each is a full node, as `prometheus` is: `debian:13-slim`, s6-overlay
  3.2.3.2, `sshd`; `player` logs in by key only (`player_ssh_pubkey`:
  `kind: key-pair`, `pair: player_ssh_key`, `half: public`, 0:0
  `"0444"`); read-only root; `/run` a named volume emptied at each start
  (D55), `/tmp` linked to `/run/tmp`; seed files copied once into an
  editable volume, marker `/var/lib/gm-state/.gm-seeded` on volume
  `gmstate`; the `sudo` log `/run/gm/sudo.log`; prometheus' capability
  list; `curl` and `jq` installed (choice: wrappers, validators and
  sealed checks parse JSON).
- `write_policies: [fixable]`, `knobs: []`, `stateful: true`,
  `extra.read_only_root: true` (see ruling 1).
- `receives: {s6_overlay: "3.2.3.2", commands: [sh, cat, du, df, awk,
  sed, grep, sleep, perl, s6-svstat, s6-setuidgid]}`, each command
  checked with `command -v` in the image, and said in `docs/gm.md`
  Connections (W1 item 5).
- Service accounts get an explicit uid and gid in the Dockerfile; the
  build fails if they differ (as postgres checks 100:102). The secret's
  `gid` in `brick.yaml` is that number. `player`'s configuration group
  is never the service account's group, so the secret stays out of
  `player`'s reach.
- Health check as prometheus': healthy while `sshd` is up, once the
  service has answered once in this container (marker
  `/run/gm/<service>-was-ready`); never depends on what the node watches.
- Validator `/opt/gm/validator/validate.sh`: exit 0 `GREEN: …`; exit 1
  one `RED <rule>: …` line per broken rule; exit 2 `ERROR: …`. It judges
  only whether the tool runs its own files as written, never what it
  watches or points at (prometheus' rule for scrape targets): a wrong
  database address or data source URL is a finding, not a red rule.
  `gm-validate` takes no arguments, runs the validator as the service
  account through `runuser`, and passes its exit code through.
- Footprint: master spec 12's node row minus the node-health script
  (0.005 CPU / 6M), as W1-D did. The scenario's `resources` take the
  full row.
- No published port. The GM works inside the node through `gmctl exec`.
  No credential ever goes in `--env` or on a command line (`docker
  exec`'s arguments show in the host's process list): a secret is read
  from its file inside the node and given to `curl` on stdin
  (`curl -K -`).

**`postgres-exporter` 0.1.0 (chunk 9)**
- Identity: `id: postgres-exporter`, image
  `127.0.0.1:5000/dbagm/postgres-exporter:0.1.0`, `roles:
  [metrics-exporter]` (choice); technology `postgres_exporter`, pinned
  with its checksum; the chunk picks the release, which must support
  PostgreSQL 18 and `--collector.stat_statements`.
- Accounts: `exporter` runs the server; `player` is in group `expconf`
  (choice). `processes: [postgres-exporter, sshd]` (the s6 services,
  which the node-health `default` entry expands to).
- Interfaces: provides `{name: metrics, protocol: http, port: 9187}`
  (no `web_path`: never routed through the web front) and `{name: ssh,
  protocol: ssh, port: 22}`; consumes `{name: sql, protocol: postgresql,
  port: 5432}`.
- `parameters: {}`. The database's address lives in the seed file, as
  Prometheus' scrape targets do (choice: a fault or a fix can live
  there, and players can see it).
- Seed `exporter.conf` (choice): `/opt/gm/seed/exporter.conf` (0:0
  `"0444"`) copied to `/etc/postgres-exporter/exporter.conf`,
  `exporter:expconf` `0664`; directory `2775`, on volume `expconf`.
  UTF-8, one `KEY=value` per line; `#` lines and blank lines ignored.
  The s6 `run` script reads it as root, so it parses the file and never
  sources or evals it. An unknown key or a missing required key: the
  service is not started and the validator's `config` rule is red.
  ```
  DATA_SOURCE_URI=db:5432/postgres?sslmode=disable   # required: <db node>:5432/postgres
  DATA_SOURCE_USER=monitoring                        # required (W2-B's role)
  COLLECTORS=--collector.stat_statements             # optional: only --collector.<x> / --no-collector.<x>
  ```
  `sslmode=disable` because postgres 0.2.0 runs with SSL off;
  authentication is `scram-sha-256` through the seed `pg_hba.conf`
  `host` line (W2-B).
- Secret `monitoring_password`: `kind: password`, no `handed_over`,
  `/opt/gm/secrets/monitoring_password`, uid 0, gid `exporter`'s,
  `"0440"`; the entrypoint refuses a missing, empty or multi-line file,
  as postgres does; it reaches the server only as
  `DATA_SOURCE_PASS_FILE=/opt/gm/secrets/monitoring_password`, set by
  the `run` script, never in `exporter.conf`, an argument or `--env`.
- Listening address `:9187` and path `/metrics` are fixed in the `run`
  script, not in the file.
- Wrapper `gm-restart-exporter` (choice: `postgres_exporter` reads its
  settings only at start): checks the file as the `run` script does and
  refuses with "NOT restarted" (exit 1) if it fails; otherwise
  `s6-svc -r`, waits up to 30 s for `/metrics`, prints `pg_up`.
- `gm-validate`; validator rules at least `config`, `server` (port 9187
  answers), `pending` (the file changed after the service started).
  `extra.validator.run_as: exporter`.
- Volumes: `expconf` `/etc/postgres-exporter`, `home` `/home/player`,
  `gmstate` `/var/lib/gm-state`, `run` `/run`.
- Footprint: limits `{cpu: 0.245, memory: 122M}`, reservations
  `{cpu: 0.045, memory: 42M, disk: 64M}`.
- Metrics other chunks rely on: `pg_up` (1 = connected);
  `pg_stat_statements_calls_total` and
  `pg_stat_statements_seconds_total` (need the collector flag and the
  database's preload; names confirmed by chunk 9);
  `pg_scrape_collector_success` (every default collector succeeds on
  PostgreSQL 18).

**`grafana` 0.1.0 (chunk 10)**
- Identity: `id: grafana`, image `127.0.0.1:5000/dbagm/grafana:0.1.0`,
  `roles: [dashboards]` (choice); Grafana OSS pinned with its checksum
  (ruling 4); the chunk picks the version and records the image size.
- Accounts: `grafana` runs the server; `player` is in group `grafconf`.
  `processes: [grafana, sshd]`.
- Interfaces: provides `{name: ui, protocol: http, port: 3000,
  web_path: /grafana/}` (confirms W2-C's 3000) and `{name: ssh,
  protocol: ssh, port: 22}`; consumes `{name: ui, protocol: http, port:
  9090}` (Prometheus).
- Route name `grafana`: `web_routes: {grafana: "grafana:3000",
  prometheus: "prometheus:9090"}`. Other node names change the values,
  never the keys (W1-C).
- `parameters: {}`. Prometheus' address is in the data source seed
  file, so master spec 11.1's "data source pointed at the wrong address"
  is a seed-file fault.
- `/etc/grafana/grafana.ini` is in the image, root `0444`, protected,
  not a seed file (choice: it holds the admin account, sub-path and
  authentication settings). It sets: `[server] http_port = 3000`,
  `root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/`,
  `serve_from_sub_path = true`; `[security] admin_user = admin`,
  `admin_password = $__file{/opt/gm/secrets/tools_password}`;
  `[date_formats] default_timezone = utc`; `[users] allow_sign_up =
  false`; `[auth.anonymous] enabled = false`; `[auth.basic] enabled =
  true` (the in-node API calls need it; the front strips
  `Authorization` anyway); `[paths] data = /var/lib/grafana`,
  `provisioning = /etc/grafana/provisioning`; `[log] mode = console`
  (to `gmctl logs`); `[smtp] enabled = false`; no outbound calls
  (analytics, update checks, news, plugin pre-install off); unified
  alerting on, no contact point provisioned.
- Administrator user `admin` (choice: Grafana's documented name; the
  front's user `player` is not a Grafana user, so a leaked front header
  can never log anyone in). Password: the tools password (ruling 8).
  `grafana`'s `docs/player.md` names the user; chunks 12 and 14 use it
  at hand-over and in the starter pack.
- Seed files, all five required in every scenario; flat names keep the
  Swarm config names short (W2-A's 64-character limit). Volume
  `grafconf` at `/etc/grafana/provisioning`; files `grafana:grafconf`
  `0664`, directories `2775`.

  | seed file (`/opt/gm/seed/`) | live path under `/etc/grafana/provisioning/` | holds |
  |---|---|---|
  | `datasources.yaml` | `datasources/datasources.yaml` | name `Prometheus`, uid `prometheus`, type `prometheus`, url `http://<prometheus node>:9090/prometheus`, default |
  | `dashboards.yaml` | `dashboards/dashboards.yaml` | the file provider, path `/etc/grafana/provisioning/dashboards` |
  | `node-health.json` | `dashboards/node-health.json` | uid `node-health`: the node-health view (D104) |
  | `postgresql.json` | `dashboards/postgresql.json` | uid `postgresql` |
  | `alert-rules.yaml` | `alerting/alert-rules.yaml` | alert rules in Grafana's file format; no contact points, no policies |

  A scenario needing another seeded dashboard bumps the brick, as
  prometheus' rule files do. On a fixable node players may add files.
- `companion/` holds those five files under the same names; its
  `when`: "when writing a scenario with a grafana node: copy companion/*
  into nodes/<node>/ as its seed files"; no `mounted` entry. Scenarios
  copy the files, never point at them (the loader's `_inside` refuses a
  path outside the scenario folder). Reference data source URL
  `http://prometheus:9090/prometheus`. Dashboards set `"timezone":
  "utc"` and the data source `{type: prometheus, uid: prometheus}`, have
  no `__inputs`, and select by metric name and the `node` label, never
  by `job`. Node-health dashboard per master spec 14 item 5: CPU,
  memory, disk against the reservation, services per node; the host's
  free space once. PostgreSQL dashboard: `pg_up`, `pg_stat_statements_*`.
  Alert rules at least: a scrape target down (`up == 0`), a node-health
  service down (`node_health_service_up == 0`), the exporter
  disconnected (`pg_up == 0`), a disk near its reservation; rule uids
  are chunk 10's, listed in `docs/gm.md`.
- Secret `tools_password`: `kind: password`, `handed_over: true` (as on
  the bastion), `/opt/gm/secrets/tools_password`, uid 0, gid
  `grafana`'s, `"0440"`. A uid, gid or mode different from the
  bastion's is allowed: W1-B compares only `kind`, `handed_over`, `pair`
  and `half`.
- Helper `/usr/local/lib/gm/grafana-api <METHOD> <path>` (choice):
  root:grafana `0750`, protected, not a `sudo` wrapper; reads the secret
  and sends `admin:<pw>` to `http://127.0.0.1:3000/grafana<path>`
  through `curl -K -`, prints the body; exit 0 on 2xx, 1 on any other
  HTTP status, 2 when Grafana does not answer. The wrapper, the
  validator, sealed checks and the GM all use it.
- Wrapper `gm-reload-grafana`: POSTs
  `/api/admin/provisioning/{datasources,dashboards,alerting}/reload`,
  prints each result; exit 1 if one is refused; if Grafana is down,
  waits up to 30 s for s6 to bring it back.
- `gm-validate`; validator rules at least `server` (`/api/health`
  reports the database ok), `files` (all five present, the JSON parses
  with `jq`), `reload` (the last start or reload provisioned without
  error), `pending` (a provisioning file changed after the last
  reload); a refused admin login is `ERROR` (exit 2): the DO NOT TAMPER
  rule was broken. `extra.validator.run_as: grafana`.
- Volumes: `grafdata` `/var/lib/grafana` (`grafana.db`; grafana:grafana
  `0750`, unreadable to `player`), `grafconf`, `home`, `gmstate`, `run`.
- Health check `start_period: 120s` (choice: first-start migrations at
  0.5 CPU; deploy waits up to 300 s).
- Footprint: limits `{cpu: 0.495, memory: 378M}`, reservations
  `{cpu: 0.095, memory: 154M, disk: 256M}`.
- Reading Grafana's live state (sealed checks with `run_as: root`, the
  GM in chunk 12, chunk 11's smoke run): `gmctl exec --node <grafana>
  --user root`, the script calling the helper on: `/api/health`;
  `/api/user` (login `admin`, `isGrafanaAdmin`); `/api/datasources`,
  `/api/datasources/uid/prometheus`,
  `/api/datasources/uid/prometheus/health`; `/api/search?type=dash-db`,
  `/api/dashboards/uid/<uid>`; `/api/v1/provisioning/alert-rules`;
  `/api/prometheus/grafana/api/v1/rules` (rule state, firing alerts);
  `/api/v1/provisioning/contact-points`; `/api/admin/settings`
  (`date_formats.default_timezone`, `server.root_url`). Never send a
  wrong admin password: Grafana's brute-force protection locks `admin`
  out.

**For chunk 11 (`fixture-monitoring`)**
- Node names (choice): `bastion`, `db`, `prometheus`, `exporter`,
  `grafana`, one network. Pins: bastion and postgres 0.2.0, the other
  three 0.1.0. Each node's `resources` is its master spec 12 row.
- bastion: `web_routes` as above, `published_ports: [{port: 22,
  default: 2222}, {port: 8080, default: 8080}]`. The loader requires
  8080 as the default, so `smoke.sh` and `smoke-monitoring.sh` never run
  at the same time.
- prometheus: `node_health: {bastion: default, db: default, prometheus:
  default, exporter: default, grafana: default}`. Seed `prometheus.yml`,
  retention 1d / 256MB, and:
  ```yaml
  scrape_configs:
    - {job_name: prometheus, metrics_path: /prometheus/metrics, static_configs: [{targets: ['localhost:9090']}]}
    - {job_name: postgres, static_configs: [{targets: ['exporter:9187']}]}
    - {job_name: node-health, static_configs: [{targets: ['bastion:9110', 'db:9110', 'prometheus:9110', 'exporter:9110', 'grafana:9110']}]}
  ```
- db: seed `postgresql.conf` with W2-B's logging settings and
  `shared_preload_libraries = 'pg_stat_statements'`; `pg_hba.conf` lets
  `monitoring` in from `exporter` with `scram-sha-256`.
- exporter: `exporter.conf` as above, with `--collector.stat_statements`.
- grafana: the five seed files copied byte for byte from
  `bricks/grafana/companion/`; a unit test compares them (choice).
- Smoke checks:
  - Prometheus, through `gmctl exec --node prometheus --user
    prometheus`: `/prometheus/api/v1/targets` shows all 7 targets up;
    `query?query=pg_up` returns 1; `count(pg_stat_statements_calls_total)
    > 0`.
  - Node health: from the bastion, `curl -s <node>:9110/metrics` for
    each node; one service stopped with `s6-svc -d` shows
    `node_health_service_up{node=…,service=…} 0`.
  - Grafana, through exec and the helper: the data source health check
    OK; both dashboard uids in the search; the alert rule count equals
    the companion's; the default time zone `utc`.
  - Web front from the host, the tools password read from
    `local/<pg>/secrets/tools_password` and given to `curl -K -`:
    without credentials 401; `/prometheus/-/ready` 200;
    `/grafana/api/health` 200; `POST /grafana/login` with
    `{"user":"admin","password":<tools>}` 200 (proves the admin
    password and the Origin/Host pass-through).
  - `Authorization` not reaching Grafana: `GET /grafana/api/user`
    through the front, carrying only the front's credentials, gets the
    same 401 body as an in-node request with no credentials, and differs
    from an in-node request sending `player:<tools>` straight to port
    3000 (`player` is no Grafana user, so no lockout).

**Driver's rulings on the draft's open points**
1. **Write policy.** Master spec 7 says every new brick is "fixable or
   report-only per scenario", but no channel passes a node's write
   policy to its container (`model.py` only checks it against
   `write_policies`), and `prometheus` 0.1.0 already shipped fixable
   only, under its `docs/gm.md` Known limits (wave 1). Both new bricks
   follow that precedent: `write_policies: [fixable]`, and each
   `docs/gm.md` Known limits says so in prometheus' wording. The access
   model's report-only Grafana gap therefore cannot arise in v0.2. This
   is a deviation from master spec 7 for all three monitoring bricks; it
   goes to the owner in the wave 3 report (and to `spec-writer` if the
   owner wants it recorded or built). It blocks nothing.
2. **`consumes`.** The new bricks list what they reach, as the bastion
   does; `prometheus` stays as built.
3. **Grafana's built-in contact point.** Chunk 10 states it under Known
   limits (never delivers with SMTP off; may log errors).
4. **Grafana's source (G2).** G2 checked Grafana's apt repository. The
   driver checked on 2026-10-21 that `dl.grafana.com` also answers from
   the build host. Either source is fine: a tarball pinned with its
   SHA-256, or the apt package pinned to an exact version (the signed
   repository carries its checksum). The chunk records which.
5. **Image sizes.** Chunks 9 and 10 record the real sizes; chunk 11's
   `fit` on 8G checks the sum; chunk 14b takes the real figures.
6. **Dashboard edits.** The Done when holds as long as an edited seed
   file takes effect through the wrapper. Whether Grafana's own file
   polling (`updateIntervalSeconds`) also applies it, and
   `allowUiUpdates`, are chunk 10's choices, recorded in `docs/gm.md`.
7. **PostgreSQL 18.** Chunk 9's stack test asserts
   `pg_scrape_collector_success == 1` for every default collector.
8. **"Always".** Floor: from the game's first start, the administrator's
   password is the tools password, and no fault ever leaves a default
   password (master spec 7.4: "always: there is no default-password
   fault"). Whether each start also re-applies it (which would let a
   restart recover the GM's checks after a tampered password) is chunk
   10's choice, recorded in `docs/gm.md`.
9. **Absolute links.** Accepted as drafted; chunk 11's login through the
   front checks it end to end.
10. **Open choices settled.** The exporter's database address in its
    seed file, not a parameter; the administrator user `admin`.

### Dispatch (chunks 9, 10)

- Chunks 9 and 10 dispatched 2026-10-21, side by side, with capture W3
  committed: branches `v0.2-c9-exporter` and `v0.2-c10-grafana` cut
  from `v0.2-w3`. Host at dispatch: 5.1G memory available of 11G, 10G
  free on `/`; chunk 8 still running.

### Capture W3-A — chunk 8 outcomes (read by 11, 12, 14 and the release gate)

Chunk 8 merged 2026-10-21: 044b882, merge 100b5a9. Unit suite 294 OK;
`smoke.sh` passed once (no other stack on the swarm, no rerun needed).

- **Report lines.** Just before the disk line: `images on <engine>:
  <image> <size>, ...; <n> layers, <k> shared, each counted once:
  <total>`. Disk line: `disk: reservations <r> + images <i> + headroom
  <h> = <total> of <disk>: ok|too much`. Headroom is still 10% of the
  declared capacity; the disk check is reservations + images + headroom
  ≤ declared disk; CPU and memory unchanged.
- **Real figures** (armenelos, 2026-10-21, fixture-audit): `bastion:0.2.0
  176.51M, postgres:0.2.0 249.71M; 13 layers, 3 shared, each counted
  once: 350.35M` (the shared layers: `debian:13-slim` and the two
  s6-overlay archives); `disk: reservations 2.25G + images 350.35M +
  headroom 2G = 4.59G of 20G: ok`.
- **Refusals** (exit 1, stderr, nothing written; a fitted game left as
  it is):
  - missing image: `image(s) not on <engine>: <image> (build it: docker
    build -t <image> bricks/<id>); ...; then gmctl fit again; nothing
    written` (on a remote engine `docker -H <endpoint> build ...`; the
    brick folder relative to the catalog root);
  - engine down: `the engine <engine> is not reachable: <Docker's
    message>. fit reads the images' sizes from the playground's engine:
    start it or correct the endpoint (--endpoint), then gmctl fit again;
    nothing written`;
  - other inspect failure: `cannot read image <image> on <engine>:
    <message>; nothing written`.
  `fit` cannot run offline any more (D102, intended).
- **Layer dedupe.** `docker image inspect` gives size and diff ids;
  `docker history --no-trunc --human=false` on the image id gives layer
  sizes; each layer keyed by its OCI chain id, counted once. An image
  whose history rows do not match its layers one for one, or do not add
  up to its size, is counted whole and shares nothing (can only
  over-count).
- **Python API.** `docker.py`: `PROBE_TIMEOUT` (60 s), `EngineUnreachable`,
  `server_version`, `Image(name, id, size, layers)`, `chain_ids`,
  `layer_sizes`, `inspect_image` (None when missing). `fit.py`:
  `ImageFootprint(...).line()`, `scenario_images`, `build_command`,
  `image_footprint`; `capacity_check(scenario, capacity, images)` needs
  the footprint; `fit(..., docker=None)` defaults to the declared
  endpoint's engine; `declare_playground` replaced by
  `playground_declaration(...)` → `(declared, existing)`, writing
  nothing; `playground.yaml` is written only after the images are read.
  Order in `fit`: load, supported check, game to keep, declaration,
  engine read, write `playground.yaml`, capacity check.
- **Tests.** `tools/tests/__init__.py`: `FakeDocker` answers images
  (default: each image a shared 78M base plus 100M of its own),
  `history`, `version`, an unreachable mode (`missing=`, `reachable=`,
  `from_environment(endpoint)`); `ScenarioCopyTest.setUp` points
  `tools.gm.fit.Docker` at it; `fake_engine(missing, unreachable)` per
  test; `run_gmctl` puts `tools/tests/fakebin/docker` first on PATH for
  its child only. A test that needs `fit` against the real engine must
  stop that patch (chunk 11: the fixture's loader-and-fit unit test runs
  on the fake engine; `smoke-monitoring.sh` runs the real one).
- **`gmctl.md`.** No command line changed; the `fit` row's Exit column
  lists the two new refusals, and "What the output looks like" shows the
  image line, the disk line and both refusals.

### Capture W3-B — chunk 9 outcomes (read by 11, 13, 14)

Chunk 9 merged 2026-10-21: 2fc4c54 (9a), ad102d8 (9b), merge f20ff5e.
Unit suite 294 OK after the merge; stack test 76 PASS, 0 FAIL; image
`postgres-exporter:0.1.0` 165MB (164,559,951 bytes, about 86MB over
`debian:13-slim`). No deviation from capture W3; its API exception was
not needed.

- **Release.** `postgres_exporter` 0.20.1 linux-amd64, sha256
  `89d4f7e7920cad48fdc3133f789556ef5253c330a9f5fdace3bdb6344c0a8b5a`
  (the release's `sha256sums.txt`); carries the PostgreSQL 17+
  `pg_stat_statements` query. Checked against PostgreSQL 18.6.
- **Accounts.** `exporter` 990:990, group `expconf` 991; the build
  fails if they differ or if `player` is in `exporter`. The secret is
  `monitoring_password` 0:990 `0440`; the server's environment holds
  only `DATA_SOURCE_PASS_FILE=/opt/gm/secrets/monitoring_password`.
- **Metrics.** `pg_up`; `pg_stat_statements_calls_total`,
  `pg_stat_statements_seconds_total`, `pg_stat_statements_rows_total`
  (labels `datname`, `queryid`, `user`); `pg_scrape_collector_success
  {collector=…}`, 1 for all 15 default collectors (database, locks,
  replication, replication_slots, roles, settings, stat_activity,
  stat_archiver, stat_bgwriter, stat_database, stat_progress_vacuum,
  stat_replication, stat_user_tables, statio_user_tables, wal) plus
  `stat_statements`.
- **Wrappers.** `gm-restart-exporter` (prints `pg_up 1: connected…` or
  `pg_up 0: NOT connected…`, exit 0 either way; refuses a bad file with
  "NOT restarted", exit 1, the old exporter running on) and
  `gm-validate`. Validator rules `config`, `server`, `pending`;
  `run_as: exporter`.
- **`exporter.conf` as built** (beyond W3): a comment may follow a
  value (whitespace then `#`); refused: a key set twice, a value with
  spaces, quotes or `` \ ` $ ; ``, a collector the release does not
  offer (list in `/usr/local/lib/gm/exporter-collectors`), a symbolic
  link. Messages give line numbers and keys, never values. One
  root-owned reader, `/usr/local/lib/gm/exporter-conf`, checks for the
  s6 `run`, the wrapper and the validator. A refused file: the service
  exits 3, a `finish` script holds it down 4 s.
- **`pending`** compares the file's mtime with the one recorded at start
  in `/run/postgres-exporter/loaded`; a file rewritten with its old
  content shows pending until the next restart (documented).
- **Health check and `server` rule** use the landing page `/`, which
  asks nothing of the database: a wrong address gives `pg_up 0` with the
  validator green and the node healthy.
- `--config.file` is a protected YAML with no auth module, so `/probe`
  holds no credential. Upstream also serves `/debug/pprof` on the game
  network (Known limits).
- **Stack test.** Stack `gmtest-pgexp`, label
  `dbagm.test=chunk9-postgres-exporter`, no published port; the db node
  reuses `bricks/postgres/tests/fixtures/{postgresql.conf,envelopes.conf}`.
- **Outside the Files line:** `bricks/postgres-exporter/tests/fixtures/
  {exporter.conf,pg_hba.conf}`; under `rootfs/`,
  `usr/local/lib/gm/postgres_exporter.yml` and the s6 `finish` file
  (added with `git add -f`: the repo's `local/` ignore rule matches
  `rootfs/usr/local/`).
- **Left for the wave:** the root `README.md` row for `bricks/` lists
  only postgres, bastion and prometheus (left to avoid a clash with
  chunk 10; chunk 11 adds both new bricks). Branch `v0.2-c9-exporter`
  kept; removed with the wave's branches.

### Capture W3-C — chunk 10 outcomes (read by 11, 12, 13, 14)

Chunk 10 merged 2026-10-21: 0d56092 (10a), 8e01f9a (10b), merge
e6707a6. Unit suite 294 OK after the merge; stack test 88 PASS, 0 FAIL
(against a real `prometheus` 0.1.0 node). `$__file{}` and every endpoint
W3 lists work as stated (`$__file{}` trims the value).

- **Grafana.** OSS 13.2.4, tarball
  `https://dl.grafana.com/grafana/release/13.2.4/grafana_13.2.4_38252365904_linux_amd64.tar.gz`,
  SHA-256 `c48765988fd88572607e4ea670251af8a8e64ab3e360d0f3cf67a6f3587b92ab`
  (the published `.sha256`), `ADD --checksum` in a separate build stage;
  only the bundled Prometheus plugin kept (13.2.3); source maps,
  Swagger UI, docs dropped; binary unmodified. **Image 866MB**
  (866181319 bytes; the binary alone 499M; master spec 12 estimated
  about 450M). Healthy in about 12 s on first start; memory at rest
  180–195M (`memory.current`, page cache included) against a 154M
  reservation (release-gate footprint measurement decides); database
  volume 1.7M.
- **Differences from W3** (its "use what the version offers"
  exception):
  1. `default_timezone = UTC`: 13.2.4 refuses `utc` (warns "unknown
     time zone utc" and keeps the browser's zone). `/api/admin/settings`
     only echoes the file's raw value; **read the zone in effect from
     `/api/frontend/settings` `.dateFormats.defaultTimezone`, expecting
     `UTC`**. Dashboards keep `"timezone": "utc"`, which Grafana accepts.
  2. `companion.when`: "copy companion/* into the node's folder
     nodes/NODE/ as its seed files (NODE: the grafana node's name);
     never mounted" (the loader reads `<node>` as an unfilled
     placeholder).
  3. The entrypoint also creates `provisioning/plugins/` (Grafana logs
     an error without it).
- **Accounts.** `grafana` 472:472, `grafconf` gid 473; `tools_password`
  0:472 `0440`.
- **Sub-path.** `root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/`,
  `serve_from_sub_path = true`; route `grafana`, port 3000. Outside the
  sub-path, `/` and `/login` answer 301 to `http://localhost:3000/grafana/…`
  (except `/api/health`). Metrics at `/grafana/metrics`.
- **Helper** `/usr/local/lib/gm/grafana-api <GET|POST|PUT|PATCH|DELETE>
  </path>`, root:grafana `0750`: `admin:<pw>` via `curl -K -` to
  `http://127.0.0.1:3000/grafana<path>`, no request body, prints the
  body; non-2xx also writes `grafana-api: HTTP <code>` to stderr; exit 0
  on 2xx, 1 any other status, 2 when Grafana does not answer or on a
  usage error; never retries.
- **Wrappers.** `/usr/local/sbin/gm-reload-grafana` (refuses broken JSON
  with "NOT reloaded") and `/usr/local/sbin/gm-validate`;
  `extra.validator.run_as: grafana`. Validator rules `files`, `server`,
  `reload`, `pending`; a refused admin login is `ERROR`, exit 2 (not
  exercised: no test sends a wrong password). Last-loaded state in
  `/run/gm-grafana/applied` (root:grafana `0440`), written by the s6
  `run` before each start and by the wrapper after each reload; shared
  functions in `/usr/local/lib/gm/grafana-files`. `pending` is
  fingerprint-based: a reload a player triggers through the API is not
  recorded and stays red until a wrapper reload or restart (documented).
- **Alert rules (5):** `gm-target-down`, `gm-service-down`,
  `gm-exporter-disconnected`, `gm-disk-near-reservation`,
  `gm-memory-near-limit`; group and folder `db_audit_gm`, interval 1m.
  `Scrape target down` reached firing after 85 s in the stack test.
- **Ruling 6.** The provider sets `updateIntervalSeconds: 86400`
  (edits apply through the wrapper), `allowUiUpdates: false`; the data
  source is `editable: false`: provisioned content changes in the files,
  not the UI.
- **Ruling 8.** The entrypoint resets the admin password from the
  secret at every container start once the database exists (`grafana
  cli admin reset-admin-password --password-from-stdin`): a restart
  undoes a changed password; it does not clear a brute-force lockout.
- **Ruling 3.** 13.2.4 has no default email contact point (receiver
  `empty`, 0 integrations); Known limits says so.
- Grafana keeps its default `secret_key`; the reference data source
  holds no secret (documented).
- **Stack test.** Stack `gmtest-grafana`, no published port; client
  container `gmtest-grafana-client` (grafana image); reuses
  `bricks/prometheus/tests/fixtures/prometheus.yml` read-only. Files
  outside the Files line: none.
- **Left for the wave:** the root `README.md` bricks row (chunk 11 adds
  `postgres-exporter` and `grafana`). Branch `v0.2-c10-grafana` kept;
  removed with the wave's branches.
- **Images now** (armenelos, 2026-10-21): postgres 0.2.0 262MB, bastion
  0.2.0 185MB, prometheus 0.1.0 488MB, postgres-exporter 0.1.0 165MB,
  grafana 0.1.0 866MB; 10G free on `/`, 5.0G memory available.

### Dispatch (chunk 11)

- Chunk 11 dispatched 2026-10-21, branch `v0.2-c11-monitoring` cut from
  `v0.2-w3` after chunks 8, 9, 10 merged, with W3-A, W3-B, W3-C
  committed. Extra notes in its brief: W2-B's logging and preload seed
  settings; the stale header comment in `fixture-mounted/scenario.yaml`;
  the root `README.md` bricks row; read Grafana's zone from
  `/api/frontend/settings` (W3-C); the fixture's unit-level `fit` runs on
  the fake engine (W3-A).

### Capture W3-D — chunk 11 outcomes (read by 12, 13, 14 and every later gate)

Chunk 11 merged 2026-10-21: 47ff165, merge 141e952. Unit suite 298 OK
after the merge. `smoke-monitoring.sh`: "all 43 checks passed in 46s
(game fixture-monitoring-um24a9)", armenelos, swarm idle (a first run
failed 3 checks on the script's own `jq` use; fixed in the script, no
brick change).

- **Real `fit` on the full five-brick game** (2 CPU / 4G / 8G):
  `cpu: reservations 0.85 + headroom 0.2 = 1.05 of 2: ok`;
  `memory: reservations 976M + headroom 409.6M = 1.35G of 4G: ok`;
  `images on local engine: bastion:0.2.0 176.51M, postgres:0.2.0 249.71M,
  prometheus:0.1.0 465.57M, postgres-exporter:0.1.0 156.94M,
  grafana:0.1.0 826.05M; 31 layers, 3 shared, each counted once: 1.53G`;
  `disk: reservations 3.31G + images 1.53G + headroom 819.2M = 5.65G of
  8G: ok`.
- **Differences from W3's chunk-11 notes** (no brick change):
  1. The fixture carries one harmless scenario-local seed-file fault,
     `fixture-random-page-cost` (copied from `fixture-audit`), because
     the loader refuses an empty `fault_instances`; never injected or
     checked.
  2. The bastion has no `curl`: node-health endpoints are read as
     `player` on the bastion with a Perl `IO::Socket::INET` GET.
  3. `prometheus` 0.1.0 has `curl` but no `jq` (W3's `jq` covered only
     the two new bricks): Prometheus' API answers come back through
     `gmctl exec` and are parsed on the host with python3.
  4. `pg_hba.conf`: `host postgres monitoring samenet scram-sha-256` (a
     host name `exporter` does not match Swarm's reverse DNS), then the
     `fixture-audit` line `host all all 0.0.0.0/0 scram-sha-256`.
     **Chunk 14's seeds**: let `monitoring` in by `samenet` or an
     address range, never by the exporter's host name.
- **Fixture** `tools/tests/fixtures/fixture-monitoring/`: `scenario.yaml`,
  `README.md`, `brief.md`, `gm/{answer-key.yaml,notes.md}`,
  `player/{README,story,issues}.md`, `data/db.sql` (fixture-audit's
  data), `faults/fixture-random-page-cost/`; `nodes/db/{postgresql.conf,
  pg_hba.conf}` (W2-B's logging block plus the preload);
  `nodes/prometheus/prometheus.yml` (W3's scrape config, retention 1d /
  256MB); `nodes/exporter/exporter.conf` (with
  `--collector.stat_statements`); `nodes/grafana/` (the five companion
  files byte for byte). Nodes `bastion`, `db`, `prometheus`, `exporter`,
  `grafana` on network `backend`, all `default` in `node_health`;
  `web_routes: {grafana: "grafana:3000", prometheus: "prometheus:9090"}`;
  ports 22→2222, 8080→8080; resources master spec 12's rows;
  `designed_for` host `laptop`, 2 / 4G / 8G.
- **Unit tests.** `TestMonitoringFixture` in `test_model.py` (4): loads
  with its pins, map, routes, ports; fits at 2 / 4G / 8G on the fake
  engine and renders one node-health config per node; Grafana seeds
  equal the companion files; scrape targets cover every node.
- **Smoke checks (43):** fit; deploy; load-data exit 0; data counts;
  Prometheus 7 targets up (polls up to 120 s), `pg_up` 1,
  `count(pg_stat_statements_calls_total) > 0` (up to 60 s); node health
  per node (CPU, memory, disk, every listed service up; 10 checks); the
  exporter's `postgres-exporter` service stopped with `s6-svc -d` shows
  `node_health_service_up{node="exporter",service="postgres-exporter"} 0`,
  then `-u` brings it back to 1; Grafana data source health OK,
  dashboards exactly `node-health` and `postgresql`, 5 alert rules,
  zone in effect `UTC`; web front on 8080: 401 without the password on
  `/prometheus/` and `/grafana/`, 200 on `/prometheus/-/ready` and
  `/grafana/api/health`, `POST /grafana/login` as admin (with an
  `Origin` header) 200; `Authorization` stripped (`/grafana/api/user`
  through the front equals an in-node request without credentials, and
  differs from `player:<tools>` sent straight to 3000); only `bastion:
  22/tcp 8080/tcp` published; SSH on 2222; `TZ=UTC` on all 5 nodes;
  every timestamped line of `/var/log/postgresql/postgresql-*.log` UTC;
  teardown, stage torn down, nothing labelled, objects outside the game
  unchanged.
- **Reading state.** Prometheus: `gmctl exec --node prometheus --user
  prometheus` running `curl` on `localhost:9090/prometheus/api/v1/...`,
  the PromQL in `--env QUERY` (not a secret). Grafana: `gmctl exec
  --node grafana --user root` running `/usr/local/lib/gm/grafana-api
  GET`, path and jq filter in `--env`. The tools password: read from
  `local/<pg>/secrets/tools_password` into a shell variable, given only
  to `curl -K -` through `printf` (a builtin), unset after use.
- **Scenario-document rule as written.** A map-valued parameter is
  rendered by its `shape` from the pinned brick's `brick.yaml` (the
  scenario's `bricks/<id>/` first, then the catalog's; the one catalog
  file the skill reads, for this alone). The Parameters line says "NAME:
  the node-health map, below" or "NAME: the web front's routes, below".
  - `node-map`: "Node-health map (`NAME`), as `scenario.yaml` states
    it:", one item per entry in YAML order, services comma-separated or
    "`default` (its brick's s6 processes)"; then "The node-health script
    is mounted into every node listed, read-only for players; its
    endpoint is readable from every node of the game, the bastion
    included." Shown before any parameter fault; such faults in section
    5 only.
  - `web-routes`: table "Route | Path on the web front | Upstream node |
    Port", one row per route in YAML order (`ui:<name>`, `/<name>/`,
    node, port); then "Published on the bastion's web front port, behind
    HTTP basic authentication on the tools password; a request without
    it is refused with HTTP 401." Empty `{}`: "Web front routes
    (`NAME`): none. The web front does not run, the bastion publishes
    SSH only and no tools password is handed over." A parameter left out
    of the scenario is not rendered.
  - Step 6 checks every map entry; template version line "Version v0.2,
    with map-valued parameters (v0.2 build plan chunk 11)".
    `fixture-mounted`'s README regenerated with the rule.
- **Outside the Files line:** `fixture-mounted/scenario.yaml` header
  comment ("loaded, fitted and rendered by the unit tests, deployed only
  on a fake engine"; 6 lines re-wrapped); root `README.md` `bricks/` row
  lists `postgres-exporter` and `grafana`.
- **Risks.** Waits of 120 s (targets) and 60 s (query statistics) are
  margins a slower host leans on. The `Authorization` check compares raw
  401 bodies; a Grafana build putting a trace id there would fail it
  falsely (empty today). Branch `v0.2-c11-monitoring` kept; removed with
  the wave's branches.

### Wave gate — 2026-10-21

All four chunks merged (8, 9, 10, 11). Gate started on `v0.2-w3` at the
commit recording chunk 11, host idle (no other stack).

| Step | Run 1 (0ad7a93, 17:31Z) | Run 2 (79144c2, 17:47Z) |
|---|---|---|
| unit suite | 298 OK | 298 OK |
| `sh -n` / `perl -c` | ok (66 files) / ok | ok (71 files) / ok |
| image builds | 4 ok; **grafana FAIL** | all 5 ok |
| stack postgres / bastion / prometheus | 73 / 67 / 101 PASS | 73 / 67 / 101 PASS |
| stack postgres-exporter / grafana | 76 / 88 PASS (grafana on chunk 10's image) | 76 / 88 PASS |
| `smoke.sh` | pass | pass |
| `smoke-monitoring.sh` | 43 passed, 46 s | 43 passed, 46 s |

- **Failure, run 1.** `docker build bricks/grafana` failed: `chmod: cannot
  access '/usr/local/lib/gm/healthcheck'`. Traced to chunk 10: the
  repo's `.gitignore` rule `local/` (local implementations in scenario
  folders) also matches `bricks/*/rootfs/usr/local/`; the other bricks'
  files there were added with `git add -f`, chunk 10's six never were,
  and its worktree had been removed. Its stack test and the run-1 smoke
  passed on the image chunk 10 built from its worktree.
- **Fix 79144c2** (coding-executor, on `v0.2-w3`): the six files
  (`usr/local/sbin/{gm-entrypoint,gm-reload-grafana,gm-validate}`,
  `usr/local/lib/gm/{grafana-api,grafana-files,healthcheck}`) restored
  from the `COPY rootfs/ /` layer of chunk 10's image (byte-identical to
  `docker cp`); the rest of that layer matches the committed `rootfs/`;
  nothing else ignored in `postgres-exporter` or `fixture-monitoring`.
  `.gitignore` gains `!bricks/*/rootfs/usr/local/`, so a brick's
  `/usr/local` is no longer ignored while scenario `local/` folders
  still are. The rebuilt image holds the same six files (checksums).
  No behaviour change.
- **Figures** (armenelos, 2026-10-21): images postgres 0.2.0 262MB,
  bastion 0.2.0 185MB, prometheus 0.1.0 488MB, postgres-exporter 0.1.0
  165MB, grafana 0.1.0 866MB; full five-brick game `fit`: images 1.53G
  after layer sharing, disk 5.65G of 8G. 10G free on `/`, 5.0G memory
  available after the gate. Untagged images from rebuilds (about 4.4G
  listed, sharing layers) left in place; prune when the disk runs short.
- **Sync.** None: no intent register, no data register.

### Report to the owner — 2026-10-21

Chunks 8, 9, 10, 11 merged; none moved. Gate passed on its second run
after one fix (grafana's uncommitted `rootfs/usr/local`, 79144c2). Asked
of the owner: (1) the monitoring bricks are fixable only (W3 ruling 1),
against master spec 7's "fixable or report-only per scenario": accept as
a v0.2 known limit, or have `spec-writer` record or plan the mechanism;
(2) the merge into `main`. Noted: images well over master spec 12's
estimates (exporter 165MB, grafana 866MB) and grafana's memory at rest
(180–195M) over its 154M reservation, both for chunk 14b's footprint
measurement and the release gate.

### Owner answers after wave 3 — 2026-10-21

- **Fixable only accepted.** The owner agreed that `prometheus`,
  `postgres-exporter` and `grafana` are fixable only in v0.2, a known
  limit (W3 ruling 1), against master spec 7's "fixable or report-only
  per scenario". Sent to `spec-writer` to record (decision and the
  spec's known limits), committed on `v0.2-w4`.
- **Images pruned.** The owner asked for the untagged images to be
  pruned: `docker image prune -f` removed every dangling image (none
  left); free space on `/` stays 10G, their layers being shared with
  the tagged images. The superseded `dbagm` 0.1.0 and 0.1.1 tags and the
  build cache were not touched.
- **Merged.** `v0.2-w3` merged into `main` as 8e17795; its worktree and
  branches (`v0.2-w3`, `v0.2-c9-exporter`, `v0.2-c10-grafana`,
  `v0.2-c11-monitoring`) removed.

## Wave 4 — started 2026-10-21

Chunks: 12, 13, 14 (chain 13 → 14). Branch `v0.2-w4`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.2-w4`, cut from `main` at 8e17795
(wave 3 merged).

- **Concurrency.** The owner's allowance for this session holds: 12
  and 13 run side by side (no path between them, no shared source
  file); 14 starts once 13 merges, and merges only once G10 clears.
- **Gates.** G2, G3, G8, G9 done; G10 (the owner's review of the v0.2
  scenario) blocks chunk 14's merge; G11 at release close.
- **Preflight.** None (no intent register, no data register).
- **Captures.** W4 (the chosen monitoring faults: ids, kinds, target
  bricks, parameters, resolutions) is drafted before chunk 13 starts.
  Chunk 12 needs none and starts now.
- Chunk 12 dispatched 2026-10-21.
- **D108** recorded by spec-writer in bed965d: the monitoring bricks
  are fixable only in v0.2 (master spec section 7, access model 6, 7,
  11, 12); report-only monitoring nodes proposed for v0.3. The build
  plan needed no change.

### Capture W4 — the v0.2 monitoring faults (chunk 13; read by 14)

Drafted 2026-10-21 by a read-only planning agent from: build plan
chunks 13 and 14; master spec 6.4 and 11.1; D92, D93, D94, D104, D106;
captures W1, W1-C, W1-D, W2-A, W2-B, W3, W3-B, W3-C, W3-D; the bricks
as built; `tools/gm/model.py` and `localimpl.py`; the six v0.1 faults.
Reviewed by the wave driver the same day; its rulings on the draft's
open points are at the end. "(choice)" marks a point the sources left
open and this capture settles. The owner sees the set at G10 (chunk
14's merge) and was told of it when chunk 13 started.

**The set: five faults, none a state fault.**

| # | Fault id | Kind | `applies_to` | Lives in | Parameters (scenario value) | Resolutions |
|---|---|---|---|---|---|---|
| 1 | `prometheus-scrape-target-missing` | seed-file | `prometheus` `["0.1.0"]` | seed `prometheus.yml`, the node-health job's `static_configs` | `node`: the node whose `<node>:9110` target is left out (`grafana`) | report, propose `[report-only, fixable]`; fix `[fixable]` |
| 2 | `prometheus-node-health-node-missing` | parameter | `prometheus` `["0.1.0"]` | `node_health` map, `remove-entry` `"{NODE}"` | `node`, required (`exporter`) | report, propose `[report-only, fixable]`; no fix |
| 3 | `prometheus-node-health-service-missing` | parameter | `prometheus` `["0.1.0"]` | `node_health` map, `remove-from-entry` entry `"{NODE}"`, item `"{SERVICE}"` | `node`, required (`db`); `service`, required: the node's main service (`postgres`) | report, propose `[report-only, fixable]`; no fix |
| 4 | `pg-stat-statements-not-preloaded` | seed-file | `postgres` `["0.2.0"]` | seed `postgresql.conf`, `shared_preload_libraries` | none (`{}`) | report, propose `[report-only, fixable]`; fix `[fixable]` |
| 5 | `grafana-alert-for-too-long` | seed-file | `grafana` `["0.1.0"]` | seed `alert-rules.yaml`, one rule's `for` | `rule`: the rule uid (`gm-service-down`); `max-for`: the longest wait that counts as fixed (`5m`) | report, propose `[report-only, fixable]`; fix `[fixable]` |

Across the set:
- **Ids**: the catalog's `<brick prefix>-<defect>`; `pg-` kept for
  postgres, the other bricks by full id (choice). Parameter names
  hyphenated, as the catalog's (`table-name`).
- **Family**: a new free-text `monitoring` (the field is free text);
  severity is chunk 13's (choice).
- **Resolutions**: report and propose under both write policies, fix
  under `fixable`, as v0.1's faults. The monitoring bricks are fixable
  only (D108), so every *fix* on 1 and 5 is possible.
- **Faults 2 and 3** are report or propose only, even on the fixable
  `prometheus` node: their material is read-only on every node (master
  spec 11.1, D92).
- **Injection** plants nothing at run time: `gmctl inject` prints
  "nothing to run" for 1, 4, 5 and "planted at rendering" for 2, 3, so
  a second run gives the same result.
- **`inject/`**: the seed-file faults carry their snippet there as
  `material`; the parameter faults have no `inject/` folder (ruling 1).
- **Validators**: none of the five turns one red (Prometheus' never
  judges targets, Grafana's only that its files load, postgres' only
  the knob envelopes): `validators_left_red: []` for each.
- **`interactions`**: `{masks: [], masked_by: [], conflicts_with: []}`
  for each. The placement rules (below) go in each fault's `gm.md`,
  since `interactions` names fault ids, not nodes (choice).

**1. `prometheus-scrape-target-missing`.** A node's node-health
endpoint missing from the scrape targets.
- Plant: the scenario's `prometheus.yml` node-health job lists every
  node's `<node>:9110` except `{NODE}`; every other job, `exporter:9187`
  included, stays.
- "With no alert on a target down" (master spec 11.1) is read as the
  consequence, not a second defect (ruling 5): `gm-target-down` stays
  in the scenario, but cannot fire for a target Prometheus does not
  know. Fault 2 needs that rule for its evidence.
- A tool starved of information: Prometheus never asks, while the node
  serves its endpoint.
- Evidence: `ui:prometheus` `/prometheus/targets` (the node-health job
  has one target fewer than the topology has nodes; `{NODE}:9110`
  absent); `ui:grafana` node-health dashboard (`/grafana/d/node-health`,
  the node absent from every panel); `ui:grafana` alerting view ("Scrape
  target down" stays Normal); `node:prometheus`
  `/etc/prometheus/prometheus.yml`; `node:prometheus` `curl -s
  {NODE}:9110/metrics` answers (the bastion has no `curl`, W3-D).
- Fix: add the target, then `sudo gm-reload-prometheus`.
- Sealed check: on `prometheus` as `root`, on Prometheus' live state,
  not the file: fixed when an instant query returns
  `node_health_sample_age_seconds{node="{NODE}"}`, through `promtool
  query instant http://127.0.0.1:9090/prometheus …` (the image has
  `curl` and `promtool`, no `jq`) (choice). Exit 2 if Prometheus is not
  ready. Chunk 13 confirms the metric and label names against the
  script as built.

**2. `prometheus-node-health-node-missing`.** A node left without the
node-health script.
- Plant: `parameter_changes: [{parameter: node_health, op:
  remove-entry, entry: "{NODE}"}]`; the renderer mounts nothing into
  that node.
- The scenario still scrapes the node: its `prometheus.yml` keeps
  `{NODE}:9110`; otherwise the fault shows only by comparing nodes.
- Evidence: `ui:prometheus` targets (`{NODE}:9110` down, connection
  refused); `ui:grafana` alerting view ("Scrape target down" fires for
  `{NODE}:9110` after about 2 minutes: `for: 1m` plus the 1-minute
  interval); `ui:grafana` node-health dashboard (no row for the node);
  `node:{NODE}` (no `/opt/gm/node-health/`).
- Sealed check: on `prometheus` as `root`, `curl -s -m 5
  http://{NODE}:9110/metrics`, on the endpoint, not Prometheus, so it
  does not depend on fault 1. Present while there is no answer or no
  sample for `node="{NODE}"`; fixed when the endpoint answers for the
  node. Exit 2 if the name does not resolve.

**3. `prometheus-node-health-service-missing`.** The node's main
service left out of its service list.
- Plant: `parameter_changes: [{parameter: node_health, op:
  remove-from-entry, entry: "{NODE}", item: "{SERVICE}"}]`. The
  scenario's `db` entry is `default`, expanding to `[postgres, sshd]`;
  the planted list is `[sshd]`.
- Constraint: `service` is never the entry's only item (the list would
  be empty); the parameter's description says so (choice).
- Effect: the node shows healthy while its database is down; at rest
  the evidence is the service missing, not down.
- Evidence: `node:db` `cat /opt/gm/node-health/node.conf` (`services=sshd`);
  `ui:grafana` node-health dashboard, "Services" panel (`db` shows
  `sshd` only, every other node its main service); `ui:prometheus`
  (`node_health_service_up{node="db"}` has no `postgres` series).
- Sealed check: on `prometheus` as `root`, `curl
  http://{NODE}:9110/metrics`: present while the endpoint answers
  without `node_health_service_up{…service="{SERVICE}"}`, fixed when
  the series is there. Exit 2 if the endpoint does not answer.

**4. `pg-stat-statements-not-preloaded`.** Query statistics never
collected.
- Plant: the scenario's `postgresql.conf` leaves `pg_stat_statements`
  out of `shared_preload_libraries` (line absent or commented out);
  the rest follows W2-B's logging block.
- The scenario's `exporter.conf` keeps
  `COLLECTORS=--collector.stat_statements`, so the collector error
  shows. The extension already exists in database `postgres` (W2-B):
  only the preload is missing.
- Visible without load: with the preload, the exporter's own queries
  fill the panels within about 60 seconds (W3-D).
- A tool starved of information.
- Evidence: `ui:grafana` PostgreSQL dashboard (the four statement
  panels "No data", "Exporter connected" at 1); `ui:prometheus`
  (`pg_scrape_collector_success{collector="stat_statements"}` 0,
  `pg_stat_statements_calls_total` empty); `bastion` (`psql -h db -c
  'SELECT * FROM pg_stat_statements LIMIT 1'` errors with "must be
  loaded via shared_preload_libraries"; `SHOW
  shared_preload_libraries` lacks it); `node:db`
  `/etc/postgresql/postgresql.conf`.
- Fix: edit the file or `ALTER SYSTEM`, then `sudo gm-restart-db`; a
  reload is not enough.
- Sealed check: on the db node as `root`, through `runuser -u postgres
  -- psql -d postgres`: fixed when the library is in effect and `SELECT
  count(*) FROM pg_stat_statements` succeeds. A file edited but not
  restarted reads present.

**5. `grafana-alert-for-too-long`.** An alert rule's pending period
longer than any incident.
- Plant: the scenario's `alert-rules.yaml` gives rule `{RULE}` a `for`
  of `2h` (the companion's is `1m`).
- The rule is `gm-service-down`, never `gm-target-down`, which would
  hide fault 2's firing alert (choice).
- The master spec's other variant, a threshold in the wrong unit, is
  set aside: a player could fix it by the threshold or by rescaling the
  expression, which a sealed check cannot judge reliably (choice).
- Evidence: `ui:grafana` `/grafana/alerting/list` ("Service down on a
  node", pending period 2h); `node:grafana`
  `/etc/grafana/provisioning/alerting/alert-rules.yaml`.
- Fix: edit the file, then `sudo gm-reload-grafana`. Provisioned rules
  are not editable in the UI; D94's API path also counts.
- Sealed check: on the grafana node as `root`,
  `/usr/local/lib/gm/grafana-api GET
  /api/v1/provisioning/alert-rules/{RULE}` and `jq`, on the live state:
  present while the rule is missing, paused, or its `for` exceeds
  `max-for`; fixed when it exists, is not paused and its `for` is at
  most `max-for`. Exit 2 when the helper exits 2. Chunk 13 confirms
  Grafana 13.2.4's duration format (`2h` or `2h0m0s`).

**The set's properties.**
- Visible without load: every fault shows in configuration, the targets
  page, dashboards or the alerting view. History is thin for the first
  10 to 15 minutes; fault 2's alert takes about 2 minutes.
- Starved tools: faults 1 and 4 (2 and 3 arguably).
- Node-health faults: only 2 and 3, parameter faults on the
  `prometheus` node naming only `prometheus`, with required `node`
  (W1-C checks this).
- No masking (placement rules, in each fault's `gm.md`):
  - faults 1, 2 and 3 sit on three different nodes; fault 1 on the db
    node would hide fault 3, faults 1 and 2 on one node would hide
    fault 2's alert;
  - fault 1 never removes `exporter:9187`, which would hide fault 4;
  - fault 5 avoids `gm-target-down`;
  - out: a data source at a wrong address (empties every panel and
    alert, hiding 1–4) and the role without `pg_monitor` (overlaps 4);
  - faults 3 and 5 both weaken "an alert when db's postgres stops"
    without hiding each other's evidence; `gm.md` says so, and one
    issue may cover both.
- Brick changes: none beyond the "Supported faults" sections:
  `prometheus` rows for 1, 2, 3 (`test_brick_docs` matches `` | `id` |
  `` rows); `grafana` a row for 5; `postgres` a row for 4 and its "all
  six also name 0.1.0 and 0.1.1" sentence updated; `postgres-exporter`
  prose only (fault 4 names `postgres`). They fold into each brick's
  version, no bump (D100).

**Chunk 13's verification.** The node names are the fixture's
(`bastion`, `db`, `prometheus`, `exporter`, `grafana`), so the values
above serve. The committed `fixture-monitoring` must carry no planted
fault (`tools/tests/test_model.py:322,331` pin its Grafana seeds and
scrape targets; `tools/tests/smoke-monitoring.sh:202,288` expect 7
targets up and 5 rules). Chunk 13 plants all five together on an
uncommitted copy of the fixture (the five instances added, the three
seed files changed per each fault's `seed_changes`; `catalog_root`
defaults to the repo) (ruling 4): fit, render, deploy, inject; every
check returns 1; fix 1, 4 and 5 as a player would; those three return
0, 2 and 3 still 1. This also shows the set does not mask itself.

**What chunk 14's scenario declares.**
- `node_health: {bastion: default, db: default, prometheus: default,
  exporter: default, grafana: default}`: every node; `db`'s entry
  contains `postgres`; `exporter` is present.
- Seed files: `prometheus.yml` (the node-health job lists `bastion`,
  `db`, `prometheus`, `exporter` on 9110, not `grafana`; the
  `prometheus` and `postgres` (`exporter:9187`) jobs and the retention
  as in the fixture); `alert-rules.yaml` (the companion's with
  `gm-service-down` `for: 2h`; the other four Grafana files byte for
  byte); `postgresql.conf` (W2-B's logging block, without the preload);
  `exporter.conf` (with `--collector.stat_statements`); `pg_hba.conf`
  (`monitoring` by `samenet`, W3-D).
- `fault_instances` (instance ids and visibility are chunk 14's,
  reviewed at G10):

  ```yaml
  - {id: f1, fault: {id: prometheus-scrape-target-missing, version: 0.1.0}, node: prometheus, parameters: {node: grafana}}
  - {id: f2, fault: {id: prometheus-node-health-node-missing, version: 0.1.0}, node: prometheus, parameters: {node: exporter}}
  - {id: f3, fault: {id: prometheus-node-health-service-missing, version: 0.1.0}, node: prometheus, parameters: {node: db, service: postgres}}
  - {id: f4, fault: {id: pg-stat-statements-not-preloaded, version: 0.1.0}, node: db, parameters: {}}
  - {id: f5, fault: {id: grafana-alert-for-too-long, version: 0.1.0}, node: grafana, parameters: {rule: gm-service-down, max-for: 5m}}
  ```

- Issues: one covering f2 or f3 expects `report` or `propose`; a *fix*
  issue on f4 needs `db` `fixable`; release gate item 6 needs at least
  one *fix* issue on a monitoring tool (f1 or f5).
- Tooling expectation: not node health (D104), and none of these five
  faults' subjects.
- Answer key: each entry's `interactions` per the notes above;
  `validators_left_red: []` except for the v0.1 fault below.
- Mixing with v0.1's faults (all on `postgres` 0.2.0, all visible
  without load):
  - suit well: `pg-hba-trust-remote` (its fix must keep the
    `monitoring` `samenet` line or the exporter disconnects; its
    `gm.md` says so, a note chunk 13 adds), `pg-memory-over-envelope`
    (shares `postgresql.conf` with f4; validator red but fixable),
    `pg-role-superuser`, `pg-table-autovacuum-off`;
  - with care: `pg-join-index-missing`, its evidence EXPLAIN and the
    index catalogue, never `pg_stat_statements` or the PostgreSQL
    dashboard, which f4 hides;
  - weak: `pg-abandoned-replication-slot` (retained WAL grows only
    with writes);
  - suggested (choice, for G10): two or three of the "suit well" ones,
    seven or eight instances in all.
- Candidates not chosen (choice): the data source at a wrong address
  (masks the others); the role without `pg_monitor` (overlaps f4);
  retention shorter than the window (the dashboards' window is 1 hour
  and Prometheus holds 2–3 hours in memory: a config-only finding with
  no symptom in a session); no slow-query log (the report looks the
  same at rest); non-English `lc_messages` (no locales in
  `debian:13-slim`); a `log_line_prefix` pgBadger cannot parse (ruling
  2).

**The wave driver's rulings on the draft's open points (2026-10-21).**
1. **No `inject/` for the parameter faults.** The format makes
   `inject/` conditional ("when it has material") and the loader
   requires it only for referenced material; git keeps no empty folder.
   Chunk 13's scope line ("each with … `inject/`") is read that way;
   spec-writer aligns its wording.
2. **No pgBadger fault.** Release gate item 4's "report evidence by
   generating the report" applies where the answer key has report
   evidence; master spec 11.1 asks for none. pgBadger is still run in
   the game (footprint, item 3). The `log_line_prefix` fault stays a
   candidate the owner can ask for at G10 (it would need pgBadger 13.2's
   at-rest behaviour confirmed first).
3. **The owner is told the set when chunk 13 starts**; G10 stays at
   chunk 14's merge as planned.
4. **The uncommitted fixture copy is accepted** for chunk 13's
   verification. From the wave 4 gate on, the smoke deployment of the
   v0.2 scenario covers the five faults at 1; release gate item 6
   covers the fixes at 0.
5. **"With no alert on a target down"** is the consequence of fault 1,
   not a second defect: the scenario keeps `gm-target-down`.

### Dispatch (chunk 13)

- Chunk 13 dispatched 2026-10-21 on branch `v0.2-c13-faults`, with
  capture W4 and its rulings, W1, W1-C, W2-A, W2-B and W3-B/C/D's
  fault-relevant items in its brief. spec-writer asked to align chunk
  13's `inject/` wording (ruling 1).

### Capture W4-A — chunk 12 outcomes (read by 14 and the release gate)

Chunk 12 merged 2026-10-21: 5b36f01, merge d0e9c53. Files:
`.claude/skills/game-master/{SKILL,gmctl,feedback}.md` only.
- **Done when**: master spec 9's items mapped to `SKILL.md` sections
  (Setup steps 2, 4–7, 9; Hand-over; "Times"; "What you may do";
  "Operating the nodes and the monitoring tools"; Evaluation steps 1,
  3, 5, 7; Setup failures); the tools password and the web address
  handed over only when the bastion's `web_routes` is not empty (D103),
  the web port being the published one whose `target` is 8080, the SSH
  port the one whose `target` is 22; `fit` needing a reachable engine
  and the images built first (Setup steps 4, 5; its two refusals write
  nothing); 39 `gmctl` invocations and 18 short mentions parse with
  `tools.gm.build_parser()`, abbreviated options refused (scratch
  script, not committed); the stance sections byte-identical. Unit
  suite 298 OK.
- **Skill shapes later work relies on**: on the host, credentials go
  through `printf 'user = "player:%s"\n' "$(cat …)" | curl -s -K -`,
  never in `--env` or an argument; the GM only reads the monitoring
  tools, never reloads or changes them; after a Grafana 401 the GM
  stops calling its API (lockout) and does not restart the node; a
  tooling expectation an issue covers is judged inside that issue's
  feedback block; at hand-over the players are told the history starts
  at deployment (dashboards thin for 10–15 minutes); the monitoring
  bricks are fixable only (D108, Setup step 2); the file log is found
  by sorting names, right for `postgresql-%Y-%m-%d_%H%M%S.log` (a
  scenario changing `log_filename` would break it: chunk 14 keeps
  W2-B's).
- **Left for the release gate**: a live run of the in-node commands
  (the Prometheus, Grafana and web-front lines mirror
  `smoke-monitoring.sh`; the log `tail` and the exporter and
  node-health `curl` lines are unrun), the stance check-list, the
  resume and the owner's judgement (items 8, 10, 12).
- **Found outside its files**: `bricks/bastion/docs/gm.md` "After
  deployment" passed the tools password in `curl -u` (visible in the
  host's process list), against the owner's standing rule. Fixed on
  the wave branch by a coding-executor (below).

### Wave-branch fixes and spec alignments (2026-10-21)

- **59186df** (coding-executor): `bricks/bastion/docs/gm.md` "After
  deployment" now hands the tools password to `curl -K -` through
  `printf`, never in an argument (found by chunk 12, W4-A). No other
  brick's `docs/gm.md` passes a credential in an argument or `--env`.
  Version unchanged (D100); docs only, no rebuild. Unit suite 298 OK.
- **b7f6c4c, 4e8bf6c, 84b9e2b** (spec-writer), after W4 ruling 1: build
  plan v5 (chunk 13's `inject/` "when it has material"); `specs/formats.md`
  v16 (the fault layout's `inject/` conditional); `specs/platform.md` v14
  (parameter faults, planted at rendering, as a third level, D92).

### Capture W4-B — chunk 13 outcomes (read by 14, the wave gate and the release gate)

Chunk 13 merged 2026-10-21: e7e5dd0, merge c698a28. Unit suite 298 OK
after the merge.
- **Files**: `faults/{prometheus-scrape-target-missing,
  prometheus-node-health-node-missing,
  prometheus-node-health-service-missing,
  pg-stat-statements-not-preloaded, grafana-alert-for-too-long}/`
  (`fault.yaml`, `checks/fixed.sh`, `checks/probe.md`, `gm.md` with
  placement rules; `inject/*.snippet` only for 1, 4, 5); "Supported
  faults" in `prometheus` (1, 2, 3), `grafana` (5), `postgres` (4; "all
  but `pg-stat-statements-not-preloaded` also name 0.1.0 and 0.1.1";
  the `samenet` note), `postgres-exporter` (prose);
  `faults/pg-hba-trust-remote/gm.md` (its fix keeps the `monitoring`
  `samenet` line). No brick version change; `fixture-monitoring`
  unchanged.
- **Versions and parameters**: every fault 0.1.0. `applies_to`: 1–3
  `prometheus` `["0.1.0"]`, 4 `postgres` `["0.2.0"]`, 5 `grafana`
  `["0.1.0"]`. Parameters, all required, default null: 1 and 2 `node`;
  3 `node`, `service`; 4 none; 5 `rule`, `max-for` (`FAULT_MAX_FOR`).
  W4's `fault_instances` block is usable as written. Severities: 1
  medium, 2 medium, 3 high, 4 medium, 5 high.
- **Names confirmed**: `node_health_sample_age_seconds{instance, job,
  node}` (e.g. `{instance="db:9110", job="node-health", node="db"}`);
  `node_health_service_up{node, service}`;
  `pg_scrape_collector_success{collector="stat_statements"}` 0 planted,
  1 fixed; `pg_stat_statements_calls_total` about 20 series 70 s after
  the restart. Grafana 13.2.4's provisioning API returns `for` as
  written (`"2h"`, `"1m"`); the check also reads `2h0m0s`. Fault 3's
  panel is "Services: up or down, per node" (the row is "Services").
- **Inject messages**: `<iid>: seed-file fault, planted by the seed
  files; nothing to run` (1, 4, 5); `<iid>: parameter fault, planted at
  rendering; nothing to run` (2, 3); a second run ends "run again
  (replay)" and "Stage injected (unchanged)".
- **Timings** from deploy's end: the exporter's node-health target down
  at the first scrape (under 30 s); "Scrape target down" pending at
  about 53 s, firing at about 1 min 54 s; the collector at 0 and `db`'s
  services `sshd` only at the first scrape. After a fix: 4 and 5 read
  fixed at once, 1 after the next scrape (15–30 s; the GM checks a
  little after the reload); statement panels fill within about 70 s of
  `gm-restart-db`.
- **Verification** (uncommitted fixture copy, game `c13-faults-9sscf7`,
  playground 2 CPU / 4G / 8G, disk 5.65G of 8G): render left
  `exporter` without a node-health config and `db.conf` at
  `services=sshd`; 5 services healthy; every check 1 before; after the
  player fixes 1, 4, 5 at 0, 2 and 3 at 1; teardown left nothing
  labelled. Error paths run by hand: unknown node 2; fault 3 on a node
  without endpoint 2; fault 5 with a missing rule 1, a bad `max-for` 2.
- **Wording rule found**: the loader reads any `<…>` in `fault.yaml` as
  an unfilled placeholder, so evidence `where` text avoids angle
  brackets.
- **Risks**: fault 5 fixed through Grafana's API is lost at the next
  restart or wrapper reload (`gm.md` says so); a fault-2/3 instance on a
  node without the endpoint makes the check exit 2 (W4's placement
  avoids it).

### Dispatch (chunk 14a)

- Chunk 14 set in progress 2026-10-21. Split per its split rule: 14a
  (the scenario folder) dispatched first, built and kept on its branch,
  for the owner's G10 review; 14b (the footprint measurement) follows on
  the same branch once 14a is built, with any G10 changes.

### Capture W4-C — chunk 14a outcomes (read by 14b, G10, the wave gate and the release gate)

14a built 2026-10-21: 5c2be8d on `v0.2-c14-scenario` (worktree
`/home/bastien/work/db_audit_gm-wt/v0.2-c14-scenario`), not merged
(G10). Scenario `fernway-clinics-monitoring`: Fernway, four veterinary
clinics, one PostgreSQL database `clinic`; monitoring set up by a
freelancer who left.
- **Instances**: f1–f5 exactly W4's block (f1, f3, f4, f5 known; f2
  hidden); f6 `pg-hba-trust-remote` (hidden), f7 `pg-role-superuser`
  on `clinic_app` (hidden), f8 `pg-table-autovacuum-off` on
  `clinic.appointments` (hidden). `pg-memory-over-envelope` left out so
  no validator starts red.
- **Issues**: I1 fix (f1; release gate item 6's monitoring fix); I2
  propose (f3 and f5, each alone explains the silent "service down"
  alert); I3 fix (f4). Tooling expectation t1, silent: PostgreSQL log
  analysis (alternative weighed: backups). Session 240 minutes.
- **Checks**: `check_scenario` `[]`; unit suite 298 OK. `fit` on
  `laptop`: CPU 1.05 of 2, memory 1.4G of 4G, images 1.53G (31 layers, 3
  shared), disk 5.65G of 8G. Smoke deployment (game
  `fernway-clinics-monitoring-day72b`): 5 services healthy, only 2222
  and 8080 published; inject ok (f7, f8 scripts; the rest "nothing to
  run"); `validate` green; all eight checks 1, three runs; teardown left
  nothing labelled. "Scrape target down" for `exporter:9110` alerting
  about 1 min 41 s after deploy.
- **Resources**: master spec 12's rows (script included); grafana
  estimated at 0.1 CPU / 208M / 256M, limit 0.5 / 384M (brick says
  154M): 14b replaces it with the measured figure.
- **For the release gate**: players get `PGUSER=dba PGDATABASE=postgres`
  from sshd's `SetEnv`; `gmctl exec` does not, so a scripted
  play-through (item 4) exports them itself. The README generator is a
  scratch script
  (`/tmp/claude-1001/-home-bastien-work-db-audit-gm/c63cb38e-ef2d-4974-87de-962eb6ea7fea/scratchpad/gen_readme.py`).
- G10 put to the owner 2026-10-21; 14b dispatched in parallel on the
  same branch (G10 changes land after it).

### Capture W4-D — chunk 14b outcomes, the measured footprint (read by the release gate)

14b built 2026-10-21: 3a4aae1 on `v0.2-c14-scenario`, over 14a's
5c2be8d; not merged (G10).
- **Machine**: armenelos, AMD Ryzen 5 PRO 8640HS (12 threads), 11.3 GiB,
  Docker 29.9.1, kernel 6.12.113, cgroup v2; 2026-10-21. Other
  projects' containers running, idle or light (recorded, not stopped);
  nothing else on the swarm.
- **Game**: `fernway-clinics-monitoring-4jsdev` on `laptop` (2 CPU / 4G
  / 8G declared, D105); deployed 19:06:31Z, handed over 19:06:47Z,
  `validate` green, 8 faults present; torn down 19:41:06Z leaving
  nothing labelled.
- **Method**: `docker stats --no-stream` back to back, cgroup files every
  0.5 s as a cross-check, maxima reported. At rest 11.5–15.5 min after
  deploy; dashboard load 6 runs × 3 browser sessions through the web
  front (504 requests a run, 0 errors); pgBadger 5 runs as `player` on
  `db` (log about 190K, report 858K); at rest again 9–13 min after the
  loads.
- **Memory (max) per node**, at rest / dashboard load / pgBadger / at
  rest after use; CPU max rest / load / pgBadger; reservation, limit:

  | Node | Memory | CPU | Reservation | Limit |
  |---|---|---|---|---|
  | bastion | 10.5 / 17.7 / 11.2 / 18.1M | 0.06 / 0.20 / 0.01 | 0.1 / 96M | 0.5 / 256M |
  | db | 59.0 / 52.2 / 81.1 / 54.2M | 0.05 / 0.06 / 0.18 (data load 0.35) | 0.5 / 512M | 1 / 1G |
  | prometheus | 56.0 / 66.4 / 59.9 / 64.0M | 0.03 / 0.07 / 0.04 | 0.1 / 160M | 0.5 / 384M |
  | exporter (no script, f2) | 24.3 / 20.1 / 19.5 / 22.2M | 0.07 / 0.01 / 0.04 | 0.05 / 48M | 0.25 / 128M |
  | grafana | 194.7 / 304.4 / 301.2 / 258.2M | 0.07 / 0.26 / 0.07 | 0.1 / 208M → 272M | 0.5 / 384M |

  No OOM kill or restart (`OOMKilled=false`, `RestartCount=0`,
  `memory.events` oom 0 everywhere). `memory.peak` with page cache:
  bastion 22M, db 134M, prometheus 85M, exporter 38M, grafana 332M.
- **Images** (`docker system df -v`, unique): grafana 786.6MB,
  prometheus 408.6MB, postgres 182.3MB, bastion 105.5MB,
  postgres-exporter 85MB, shared `debian:13-slim` 79.6MB; 1.65GB
  (1.53GiB, `fit`'s figure). **Volumes** 77.4MB after 35 minutes (db
  74.7MB, grafana 1.74MB, prometheus 0.88MB, bastion and exporter under
  0.1MB).
- **Totals**: CPU 1.05 of 2; memory 1.46G of 4G; images plus volumes
  about 1.73GB of 8G (`fit`'s accounting 5.65G of 8G). Master spec 14
  item 3 passes.
- **Reservation raised**: grafana `brick.yaml` memory 154M → 266M (272M
  as a node with the script; limit unchanged), the scenario's grafana
  node 208M → 272M. Sized for the reading after dashboard use (258M),
  not only the one after hand-over (195M): players use the dashboards
  from the start. No other reservation changed; none lowered. All five
  bricks' `docs/gm.md` "Footprint" carry the measured figures. No
  version bump (D100). D106: the scenario uses all five bricks, so no
  extra fixture game.
- **Checks**: `fit` passes for the scenario and `fixture-monitoring` on
  `laptop`, `fixture-audit` and `bookshop-new-server` on `host-1`;
  stack tests postgres 73, bastion 67, prometheus 101, exporter 76,
  grafana 88, all pass; unit suite 298 OK; README regenerated (diff:
  grafana's reservation and the memory total, 1024M → 1088M).
- **Left over, routed**:
  - Master spec 12's estimates (Grafana 160M) now differ from the
    measurement: for the release notes (release gate item 14).
  - `fixture-monitoring` keeps Grafana at 160M (it copies spec 12's
    row), below what it measures at rest: fixed on the wave branch.
  - Image builds copy `rootfs` with the checkout's directory modes
    (umask 002 gives 775 on `/usr/local/lib/gm` in the rebuilt grafana
    image): fixed on the wave branch, every brick's build normalised.
  - Grafana reaches 0.47 CPU over 0.5 s windows during a dashboard load
    (limit 0.5): slower panels, not failures. The exporter peaks at
    0.07 CPU against a 0.05 reservation (limit 0.25).
  - Scratch evidence in
    `/tmp/claude-1001/-home-bastien-work-db-audit-gm/c63cb38e-ef2d-4974-87de-962eb6ea7fea/scratchpad/c14b/`.

### Wave-branch fixes after 14b (2026-10-21)

- **37507f1** (coding-executor): every brick's Dockerfile copies
  `rootfs/` through a `rootfs-modes` stage (`chmod -R u=rwX,go=rX`), so
  the images ship 755/644 whatever the checkout's umask; the deliberate
  modes set after the copy (sudoers 0440, `grafana.ini` and
  `grafana-files` 0444, `grafana-api` 0750, the 2775 configuration
  directories) are unchanged. Before: `/etc`, `/usr/local/**`,
  `/etc/s6-overlay/**`, `/etc/ssh`, `/etc/sudoers.d` at 775 and s6 entry
  files at 664 in every image. Builds under umask 002, 022 and 077 give
  identical mode listings. All five images rebuilt (now the local tags);
  stack tests postgres 73, bastion 67, prometheus 101, exporter 76,
  grafana 88, all pass. No version bump (D100).
- **d2c8429** (coding-executor): `fixture-monitoring` reserves 272M for
  grafana (was 160M, spec 12's row), README regenerated; `fit` on
  `laptop` 1.46G of 4G; unit suite 298 OK; `smoke-monitoring.sh` 43
  checks pass in 51 s on the rebuilt images.

### G10 cleared; chunk 14 merged (2026-10-22)

- **G10** (the owner, 2026-10-22): "i approve the scenario. don't add a
  pgbadger fault, leave out the memory fault." So `fernway-clinics-monitoring`
  stands as built (5c2be8d, 3a4aae1): eight fault instances, issues
  I1–I3, tooling expectation t1 (log analysis, silent), 240 minutes;
  Grafana's reservation stays 266M (272M on the node). No sixth
  (pgBadger) fault; `pg-memory-over-envelope` stays out of the
  scenario. Capture W4 ruling 2 is closed by this answer.
- **Chunk 14 merged** by the wave driver: 76c249c (`--no-ff`, no
  conflict with the wave-branch fixes 37507f1 and d2c8429). Status and
  Record set; G10 marked done in the gates table. Worktree
  `v0.2-c14-scenario` removed; the branch is kept until the wave closes,
  with `v0.2-c12-gm-skill` and `v0.2-c13-faults`.
- The owner's word was "commit and proceed to the next wave". Wave 4 is
  the plan's last wave, so next comes the wave 4 gate, then the release
  gate on `v0.2-w4` before it merges (the model's release end). Merging
  into `main` still waits for the owner's word.

### Wave 4 gate — 2026-10-22: PASS (first run)

Run by a `coding-executor` (verification level: wave gate) on `v0.2-w4`
at 0ca6dd7, 2026-10-22T06:12:17Z, armenelos (Debian 13, Docker 29.9.1,
single-node swarm), machine otherwise idle.

- **0ca6dd7** (coding-executor): `tools/tests/smoke-scenario.sh
  <scenario>`, the plan's "smoke deployment" of a scenario. On a copy of
  the scenario, the playground taken from its single `designed_for` host
  (fernway on `laptop` 2 / 4G / 8G, bookshop on `host-1` 2 / 4G / 20G):
  fit, render, deploy, load-data, inject; `check` exits 1 with every
  instance `present`, in order (polled up to 120 s); `validate` matches
  what the answer key implies at hand-over (a node red only where an
  instance's evidence is "the public validator on <node>" with a `RED
  <rule>` line, or `validators_left_red` names it); teardown, nothing
  labelled with the game id, other objects unchanged. No credential read
  or passed. Fernway 17 checks, bookshop 18 (db red on `work_mem`, f2).
- **Steps**, all PASS: unit 298 OK (27 s); `sh -n` 77 files; `perl -c`;
  five image builds (cached: identical IDs to the engine's); stack tests
  postgres 50 s, bastion 62 s, prometheus 50 s, exporter 71 s, grafana
  163 s; `smoke.sh` 23 s; `smoke-monitoring.sh` 43 checks 51 s;
  `smoke-scenario.sh fernway-clinics-monitoring` 17 checks 29 s;
  `smoke-scenario.sh bookshop-new-server` 18 checks 20 s. No fix needed.
- **Figures**: images grafana 0.1.0 866MB, prometheus 0.1.0 488MB,
  postgres 0.2.0 262MB, bastion 0.2.0 185MB, postgres-exporter 0.1.0
  165MB (v0.1's postgres 0.1.0/0.1.1 and bastion 0.1.0/0.1.1 tags still
  on the engine, about 880MB); `/` 28G, 16G used, 10G free. No bundle or
  performance figures apply.
- No intent or data register: no wave sync.
- **For the release gate**: fernway f1's check (`prometheus-scrape-target-missing`)
  reads present right after deploy also because nothing is scraped yet,
  so the play-through re-checks a fix only after a scrape interval; the
  script's expected-validate rule depends on the answer key's evidence
  wording (a differently worded scenario fails loudly, never passes
  silently).
- Logs: `/tmp/claude-1001/-home-bastien-work-db-audit-gm/c63cb38e-ef2d-4974-87de-962eb6ea7fea/scratchpad/gate-w4/`.

Next: the release gate, on `v0.2-w4` before it merges (the model's
release end; the owner's "proceed"). Merging into `main` waits for the
owner's word.

## Release gate — 2026-10-22

Run by the driver on `v0.2-w4` (the model's release end: on the last
wave's branch before it merges; the owner's "proceed"), on armenelos
(Debian 13, Docker 29.9.1, single-node swarm). GM sessions were fresh
agents reading `.claude/skills/game-master/` as their instructions; the
driver played the initiator and the player; verifier agents worked as
`player` through the bastion and the web front only, GM-side checks from
the host. Scratch evidence:
`/tmp/claude-1001/-home-bastien-work-db-audit-gm/c63cb38e-ef2d-4974-87de-962eb6ea7fea/scratchpad/rg-*`.

1. **Item 1: PASS.** `fernway-clinics-monitoring` complete (loader's
   `check_scenario` empty; every required file; pins resolve; README
   current, "DO NOT READ" first); G10 cleared. Every brick's `docs/gm.md`
   passes the format check, `prometheus`'s covering the node-health
   script. Stale v0.1 wording found in the postgres, bastion and
   prometheus docs: fixed (5e582e0, and a follow-up).
2. **Item 2: PASS.** Game `fernway-clinics-monitoring-xk7d0d`, playground
   `laptop` declared 2 CPU / 4G / 8G (D105): `fit` 1.05 of 2 CPU, 1.46G of
   4G, 5.65G of 8G (images 1.53G); fitted 06:25:18Z, handed over
   06:28:12Z, final answer 06:48:22Z, feedback 06:49:52Z, torn down
   06:50:03Z; nothing labelled left.
3. **Item 3: PASS.** No restart, no OOM (RestartCount 0, `memory.events`
   oom 0 on every node). Memory (MiB) at rest / dashboard load / pgBadger
   run, against the reservation: bastion 10 / 11 / 15 of 96; db 59 / 61 /
   88 of 512; prometheus 50 / 51 / 51 of 160; exporter 16 / 19 / 19 of 48;
   grafana 188–197 / 218 / 200 of 272 (cgroup peak 230). CPU peaks: db
   0.19 (pgBadger), grafana 0.16 (dashboard load). Disk: images' union
   1647.6MB, the game's 23 volumes about 77MB, writable layers 0: about
   1.72GB of 8G. Footprints already carry the measured figures (chunk
   14b).
4. **Item 4: PASS.** f1–f8 evidence reachable as `player` where the answer
   key says, interface evidence checked through Prometheus' and
   Grafana's HTTP APIs, report evidence by running pgBadger.
5. **Item 5: PASS.** The node-health dashboard shows CPU, memory, disk
   against reservation and services for bastion, db and prometheus, host
   free space once; grafana, exporter and postgres-on-db missing as f1,
   f2, f3 plant; prometheus's sshd stopped by the GM shown down within
   6 s, up again within 12 s; grafana in every panel after I1's fix.
6. **Item 6: PASS.** I1 (f1) 1 → 0 at 06:39:28, I3 (f4) 1 → 0 at
   06:40:19; the others still present; validators green.
7. **Item 7: PASS on the requirement, with RG-1.** 401 with the challenge
   on `/prometheus/` and `/grafana/` without the password; only the
   bastion's 2222 and 8080 published; TZ=UTC on every node; PostgreSQL's
   419 log lines in UTC. **RG-1**: `/`, unknown paths and `/<route>` (no
   slash) answered 200 / 404 / 301 without the password, against capture
   W2-C: fixed (1fc8ded).
8. **Item 8: PASS.** The resuming GM's feedback judged t1 (log analysis)
   met, with the player's weekly-pgBadger proposal.
9. **Item 9: PASS.** Game `bookshop-new-server-b8mhk3` on `host-1`
   (2 / 4G / 20G): only 2222 → 22 published, no 8080, no tools password
   handed over (D103); the write policy holds on both nodes; `sudo
   gm-validate` red on `work_mem` at hand-over, bastion green; f1–f6
   evidence; I1 1 → 0 → 1 → 0 (file and reload, restored, `ALTER
   SYSTEM`, D53); I3 by `CREATE INDEX CONCURRENTLY` 1 → 0; feedback given,
   torn down 07:02:14Z, nothing labelled left.
10. **Item 10: PASS, one check not run.** A fresh GM session found
    fernway at `handed-over` from `local/` state and asked before picking
    it up. Stance: a hint (which file for I2) refused; a reveal (is the
    trust line planted, how many faults) refused; a report "so far" met
    with "Is this your final answer?" and no comment on content. **The
    restart/reset request was not sent**: this session's auto-mode
    permission classifier denied the driver's message ("Interfere With
    Workloads"); for the owner. Forced setup failure: a scratch copy of
    bookshop (never in the repo) with `SELECT 1/0;` appended, game
    `bookshop-new-server-k2n7ia` on `rgfail`: failed at load-data
    (`psql exit 3: ERROR: division by zero`) recorded before
    `data-loaded`, gmctl's teardown, confirming teardown recorded, nothing
    labelled left.
11. **Item 11: PASS.** The quality command (`gate-w4/gate.sh`) at 5e582e0,
    2026-10-22T07:17:39Z: unit 298 OK, `sh -n`, `perl -c`, five builds,
    stack tests (bastion now 71 PASS), `smoke.sh`, `smoke-monitoring.sh`,
    both scenario smoke deployments, all PASS.
12. **Item 12, G11: open.** Fernway's feedback is in
    `scratchpad/rg-fernway/feedback.md` for the owner.
13. **Item 13: PASS** after the driver completed the Record lines of
    chunks 5, 9, 10 and 11 (6a9a209); every finding was already in the
    bricks' `docs/gm.md`.
14. **Item 14:** release notes to `spec-writer`.

**Fixes on `v0.2-w4`** (coding-executor): 1fc8ded, RG-1, the web front
serves `/`, the 404 and `/<route>`'s redirect from static files under
`/run/web-front/www/` in the content phase, after `auth_basic` (nginx's
own prefix-location redirect also ran before auth; an exact-match
location per route replaces it); stack test asserts 401 on all three
without the password and the stated answers with it. Side effects: POST
to `/` gets 405; the 301 keeps the query string. Capture W2-C's file list
for `/run/web-front/` gains `www/`. 5e582e0, stale wording in the
postgres, bastion and prometheus docs (scratch space `/tmp` and
`/var/tmp` → `/run/tmp` now listed as writable).

**Findings for the owner** (none blocking):
- **RG-2** (low): a player's `sed -i` on a group-writable config leaves the
  file owned by `player` (group and mode kept; services and validators
  fine).
- **RG-3** (low): `gmctl status` prints `tools_password: password, handed
  over` in a game without a web front (the label comes from the
  bastion's static `handed_over: true`, `tools/gm/state.py:143`,
  `localimpl.py:408`); the skill tells the GM not to hand it over.
- **RG-4** (low–medium): `bookshop-new-server`'s seed `postgresql.conf`
  lacks the logging and preload settings `bricks/postgres/docs/gm.md`
  ("What the seed files must contain") requires (left at chunk 6), so
  that game logs to Docker, players can't run pgBadger, and the GM
  skill's "the server log is in files" does not hold there.
- **RG-5** (low): every postgres 0.2.0 game has the login role
  `monitoring` (`pg_monitor`), exporter or not; bookshop's answer key and
  notes don't mention it.
- The restart/reset stance check (item 10) is untested.
- 2672181 (coding-executor): the follow-up on the bricks' docs. postgres's
  "fixable only" now says v0.2 (D108); prometheus, postgres-exporter and
  grafana list the scratch space `/tmp` and `/var/tmp` (checked on running
  containers).

### Owner rulings — 2026-10-22 (release close)

- **G11 cleared**: "the feedback is good" (fernway's feedback, item 12).
- **The restart stance check (item 10)**: not tested. The owner rules
  that the GM may restart a game in the **next version**, tearing down
  and rebuilding the whole stack, but **only on the player's explicit
  confirmation**: a passing comment must never restart a game, because a
  restart breaks the game. For `spec-writer`: a v0.3 entry. v0.2 keeps
  the current stance (no restarts); the untested refusal is a known gap.
- **RG-4**: update both bookshop's seed `postgresql.conf` (logging and
  preload settings, as `bricks/postgres/docs/gm.md` requires) and the GM
  skill's wording on the server log. On `v0.2-w4`, before the merge.
- **RG-3** (the `gmctl status` label) and **RG-2** (`sed -i` ownership):
  accepted as known issues.
- **RG-5**: "monitoring isn't mandatory in any game (highly suspect if
  there isn't any of course, but it remains a valid game)". The role
  `monitoring` stays in every postgres game for now. Making it
  conditional moves to **v0.5** (the brick-improvement version).
- **Merge granted**: `v0.2-w4` into `main` once the RG-4 changes pass the
  quality command and the release notes are written.
- **RG-4 fixed** (coding-executor): e7c2c3e, bookshop's seed
  `postgresql.conf` gains the brick's logging and preload block
  (appended, lines 39–58, so `postgresql.conf:11` stays `work_mem`), with
  `log_line_prefix` and `log_min_duration_statement` (2s → 100ms, the
  brick's reference value) edited in place; starter pack names the log
  and pgBadger; `scenario.yaml` and the answer key unchanged (version
  0.1.0, README still current). 412f5a2: the GM skill says the server log
  is in files when the seed sets `logging_collector = on` (every v0.2
  seed) and otherwise `gmctl logs`; `gmctl.md`'s `logs` row likewise.
  Checked: a bookshop game writes `/var/log/postgresql/postgresql-*.log`,
  pgBadger runs as `player`, the six sealed checks unchanged.
- **Quality command** at 412f5a2 (2026-10-22T07:39:26Z, armenelos): every
  step PASS (unit 298 OK; stack tests postgres 54 s, bastion 64 s,
  prometheus 50 s, exporter 71 s, grafana 149 s; `smoke.sh`,
  `smoke-monitoring.sh`, both scenario smoke deployments). Logs of the
  earlier runs in `gate-w4/run1/` and `run2/`.

### Merge — 2026-10-22

- `spec-writer`: release notes and rulings D109–D113, O81 (76aae3a);
  milestone archive `specs/archive/v0.2/` (8c09430: the build plan moved,
  D55–D106 and the resolved questions archived; the v0.2 page, master spec,
  access model and this log stay in place, cited by skills and bricks).
- Merged `v0.2-w4` into `main` on the owner's word ("granted") as eedaa0d,
  with the figures in the merge message. Worktree `v0.2-w4` and branches
  `v0.2-w4`, `v0.2-c12-gm-skill`, `v0.2-c13-faults`, `v0.2-c14-scenario`
  removed. v0.2 is closed.
- Left for the owner from spec-writer's close: O81 (how a v0.3 restart
  works, and whether a whole-game restart differs from the node resets
  D19 and D48 defer); whether the v0.3 restart entry stays tagged
  "(proposed)"; the archive range ends at D106 (D107–D113 still to be
  applied in v0.3 and v0.5).
