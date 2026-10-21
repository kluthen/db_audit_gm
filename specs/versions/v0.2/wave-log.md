# db_audit_gm v0.2 — Wave log

Execution record for [build-plan.md](build-plan.md). Kept by the wave
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
registers, committed on `v0.2-w3`.

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
