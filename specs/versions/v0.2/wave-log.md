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
