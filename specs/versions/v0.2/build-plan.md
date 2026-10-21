# db_audit_gm v0.2 — Build plan

Status: v4 (2026-10-21): the scenario document's rule for map-valued
parameters placed in chunk 11 (gap found by chunk 1, wave log).
Approval: approved 2026-10-21 by the owner (G1, spec D99).
Written from: [master-spec.md](master-spec.md) and
[access-model.md](access-model.md), approved 2026-10-21 (spec D98) and
amended the same day by spec D100 to D106.
No design set (no interface to design, D2).

The model is `~/.local/share/dev_team/references/build-plan-model.md`; this
plan states only its deltas.

## Read first

- **Baseline.** v0.1's code on `main` (5c16d06): `postgres` and `bastion`
  at 0.1.1, `tools/gm/`, the three skills, six catalog faults,
  `bookshop-new-server`. v0.1's wave-log captures W1-A to W3-C
  ([../v0.1/wave-log.md](../v0.1/wave-log.md)) still fix the `gmctl`
  command lines, the bricks' paths and the `brick.yaml` keys. A chunk
  that changes one of them says so, and the wave driver records the new
  shape as a v0.2 capture.
- **No intent register and no data register** (no `.atd`, no `intent/`,
  no `data-register/`; checked 2026-10-21). So there is no
  `documentalist` wave preflight, capture or sync, and no `data-steward`
  preflight or sync. Where a chunk names an **Architecture capture**, the
  wave driver records it in the wave log (`W<n>-<letter>`) on the wave
  branch before the chunk that depends on it starts, as in v0.1.
- **One version per brick in the catalog.** The loader refuses a pin
  that does not match the brick's `version`
  (`tools/gm/model.py`, `find_definition`), so bumping a brick breaks
  every scenario and fixture that pins the old version. The chunk that
  bumps a brick re-pins `scenarios/bookshop-new-server/` and
  `tools/tests/fixtures/fixture-audit/` in the same commit. Chunk 1 bumps
  `postgres` and `bastion` to 0.2.0; every later v0.2 change to a brick
  folds into the version it already has, since a brick version is
  released only when the v0.2 release gate passes, not when a wave
  merges into `main` (spec D61, D100).
- **Templates are the loader's schema.** `tools/gm/model.py` checks every
  brick, fault and scenario against the format skill's templates
  (`template_schema`), and the unit suite loads every folder under
  `bricks/`, `faults/` and `scenarios/`. A template change therefore
  fails every existing definition that lacks the new shape, and a folder
  under `bricks/` without a complete `brick.yaml` fails the suite. Hence
  chunk 1 migrates the v0.1 definitions itself, and the node-health
  script is built inside chunk 4 with its brick.
- **Approved with the spec** (D98): the web front's default port is 8080;
  Prometheus' admin and lifecycle endpoints stay disabled and reloads go
  through the node's `sudo` wrapper; players must not change Grafana's
  users or the administrator's password (DO NOT TAMPER, not enforced).
- **Build host** (2026-10-21): Debian 13, Docker Engine 29.9.1, swarm
  active (one node), cgroup v2, Python 3 with PyYAML 6.0.2, no
  `shellcheck`; 12 CPUs, 11G of memory, about 10G free on `/`. The
  images `dbagm/postgres` and `dbagm/bastion` 0.1.0 and 0.1.1 are built.
  v0.2 adds about 1.25G of images: prune superseded `dbagm` tags after a
  wave gate when the disk runs short.
- `/run` is a named volume, not a tmpfs (D55); every new brick follows the
  v0.1 bricks' pattern for it, for `sshd` host keys, the `sudo` log and
  the seed marker.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | Plan approval | The owner | Wave 1 | done (2026-10-21, spec D99) |
| G2 | Network access at image build time: Debian's apt repositories (pgBadger, Perl, the proxy), the PostgreSQL apt repository, the s6-overlay, Prometheus and `postgres_exporter` release downloads, Grafana's package source | Hand check by the wave driver | Chunks 1, 4, 6, 7, 9, 10 (every image build) | done (2026-10-21, hand check, wave log) |
| G3 | A Docker host in swarm mode (swarm active on the build host, 2026-10-21) | Hand check by the wave driver | Every stack test and smoke run, every wave gate, the release gate | done (2026-10-21, hand check, wave log) |
| G4 | O72: brick versions across wave merges | The owner | Wave 1's merge into `main`; the plan's shape | done (2026-10-21, spec D100: released at the release gate) |
| G5 | O73: what happens to v0.1's free-text evidence `where` | The owner | Chunk 1 | done (2026-10-21, spec D101: moved to `source`) |
| G6 | O74: where `gmctl fit` takes image sizes from | The owner | Chunk 8 | done (2026-10-21, spec D102: from the engine) |
| G7 | O75: the web front in a game with no monitoring interface | The owner | Chunk 7 | done (2026-10-21, spec D103: only with an interface) |
| G8 | O76: where Grafana's dashboards and the node-health view come from | The owner | Chunks 10, 14 | done (2026-10-21, spec D104: `grafana`'s reference dashboards) |
| G9 | O77: the `laptop` playground, declared on the build host or a real 2 CPU / 4G / 8G machine | The owner | Chunk 14b, release gate items 2 and 3 | done (2026-10-21, spec D105: declared on the build host) |
| G10 | Review of the v0.2 scenario: its faults (chunk 13's among them), issues, tooling expectation and answer key (master spec 11.1) | The owner | Chunk 14's merge | open |
| G11 | The tooling's usefulness and the feedback's tone (master spec 14, item 12) | The owner | Release close | open |

G4 to G9 were questions O72 to O77, ruled by the owner as proposed
(spec D100 to D105). Waves merge into `main` after their gates as the
model says (D100).

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3, 4 | G2 (chunks 1, 4); G3 (chunks 1, 3, 4) | merged (2026-10-21, 6467fb5) |
| 2 | 5, 6, 7 | wave 1; G2, G3 | in progress |
| 3 | 8, 9, 10, 11 | wave 2 | planned |
| 4 | 12, 13, 14 | wave 3; G10 (chunk 14's merge) | planned |

```
1 ──> 2, 3, 4          (in-wave: the v0.2 template keys captured at wave 1 start, W1)
2, 3 ──> 5
1, 3 ──> 6, 7
5 ──> 7                (in-wave: `GM_WEB_ROUTES`'s encoding, fixed by capture W1 item 2)
1 ──> 8
3, 6 ──> 9
3, 7 ──> 10
4, 5, 6, 7 ──> 11
9, 10 ──> 11           (in-wave: the two bricks' interfaces captured at wave 3 start)
3, 5, 7, 8, 10 ──> 12
2, 4, 5, 6, 9, 10, 11 ──> 13
13 ──> 14              (in-wave: the chosen faults captured at wave 4 start)
4, 5, 6, 7, 9, 10, 11 ──> 14
```

Chunk 8 has slack (only chunk 12 needs it); it sits in wave 3 to fill it.

## Workflow deltas

- κ = 1 (default).
- **Branches and worktrees**: waves `v0.2-w<n>` in
  `/home/bastien/work/db_audit_gm-wt/v0.2-w<n>`; chunks
  `v0.2-c<id>-<slug>` in `/home/bastien/work/db_audit_gm-wt/v0.2-c<id>-<slug>`.
  Never in the main checkout.
- **Chunk checks**, in addition to the model's:
  - Python: `python3 -m unittest discover -s tools/tests -t .` (the
    related tests, or all of them: the suite is small);
  - shell: `sh -n` on every shell file the chunk touches, those without
    an extension included (s6 `run` files, `rootfs/usr/local/sbin/*`,
    `rootfs/usr/local/lib/gm/*`, companion scripts); `shellcheck` too
    when installed;
  - Perl: `perl -c` on every Perl file the chunk touches (the
    node-health listener);
  - YAML: every YAML file the chunk touches loads with PyYAML (the unit
    suite also loads every template, brick, fault and scenario);
  - a chunk touching a brick: `docker build -t
    127.0.0.1:5000/dbagm/<brick>:<version> bricks/<brick>` and the
    brick's stack test, `sh bricks/<brick>/tests/run-stack-test.sh`
    (needs G3);
  - a chunk changing a scenario's `scenario.yaml` or
    `gm/answer-key.yaml`: its `README.md` regenerated with the
    scenario-document skill in the same commit.
- **Wave gate (full quality command)**: the full unit suite; `sh -n` on
  every shell file and `perl -c` on every Perl file; every brick's image
  build and stack test; `sh tools/tests/smoke.sh` (the fixture-audit
  game); from wave 3, `sh tools/tests/smoke-monitoring.sh` (chunk 11);
  from wave 4, a smoke deployment of the v0.2 scenario and of
  `bookshop-new-server` (`fit`, `render`, `deploy`, `load-data`,
  `inject`, `check` with every sealed check at 1, `validate`, teardown
  leaving nothing labelled with the game id).
- No link checker is configured; Markdown links are checked by reading.
- Images are tagged `127.0.0.1:5000/dbagm/<brick>:<version>`, as in v0.1;
  every pinned download (s6-overlay, Prometheus, `postgres_exporter`,
  Grafana) is checked against its published checksum in the Dockerfile.

## Measurements and hand checks

- G2 and G3: hand checks by the wave driver before wave 1 (chunk 1
  already builds both v0.1 images as 0.2.0).
- Node-health readings, scrape targets, the web front's 401 and routes,
  UTC on the nodes: automated in chunk 11's smoke run, from wave 3's gate.
- The footprint: measured in chunk 14b on a full game, recorded in the
  wave log with machine and date; measured again at the release gate
  (item 3).
- The play-through as `player`, the stance check-list, a fresh session
  resuming a game, a forced setup failure: release gate.

## Left for the build (master spec 15)

Each item is settled or verified by the chunk named, recorded in its
**Record** line and in the brick's `docs/gm.md`; the release gate checks
that each is recorded.

| Item | Chunk |
|---|---|
| Swarm refuses an empty config; the s6 files that are empty in an image need content when mounted | 4b (the material), 5 (the renderer never writes an empty config) |
| Mounting configs into an s6 service folder the read-only image lacks | 4b |
| Reading the node's cgroup v2 files inside a Swarm container | 4b |
| The node-health script's unprivileged account, and `s6-svstat` as that account | 4b |
| The node-health listener's fixed port | 4b |
| The web front's reverse proxy; not passing `Authorization` on to Grafana | 7 (checked end to end in 11) |
| Prometheus' sub-path setting | 4a |
| Grafana's sub-path setting | 10 |
| Who creates the exporter's monitoring role, and how its password reaches the database | 6 (consumed by 9) |
| The `prometheus`, `postgres-exporter` and `grafana` validators and `sudo` wrapper names | 4a, 9, 10 |

## Chunks

### Chunk 1 — Format skill, templates and the v0.1 definitions migrated

Status: merged (w1, fa8e62d)
Record: 9b1c4d7 (1a), e01b06c (1b), merge fa8e62d. Tests outside Files kept
green after the bump (`test_model`, `test_fit`, `test_deploy`, `smoke.sh`
tags); Dockerfiles' build comments still say 0.1.1 (chunks 6, 7). Choices
where W1 was silent: wave log, "W1 addenda".
Wave: 1
Depends on: G2, G3 (G1, G5 done)
Architecture capture: recorded by the wave driver at wave 1 start (W1),
for chunks 2, 3 and 4, which build on the keys before chunk 1 merges:
the `brick.yaml` footprint shape (limits and reservations); the mounted
companion material declaration (files with target path and mode, the
parameter listing the receiving nodes, the footprint added per node, the
requirements); the receiving brick's declaration (s6-overlay version,
commands provided) and the command vocabulary both sides use; the secret
`kind` values (password, key pair) and the files each kind generates;
how a brick declares a web interface, and the bastion parameter that
lists the web front's routes, whose keys `ui:<name>` names; the
`parameter` injection kind; the node-health map parameter (name, shape,
`default`); the answer key's `where` values and the `source` key (spec
D101); the
`tooling_expectations` list and how an issue covers one.

- Goal: the v0.2 formats in the format and scenario-document skills, and
  every existing definition brought to them, so the suite stays green.
- Scope: in:
  - `scenario-format` `SKILL.md`: the v0.2 rules of master spec 6 (the
    footprint shape; no fault list; mounted companion material and
    receiving bricks; the node-health map required with a `prometheus`
    node, every node listed; parameter faults; faults about mounted
    material; `where`, `source` and tooling expectations; `applies_to`
    version lists; the version rules, with a version released only by
    its version's release gate (D100), faults and scenarios never
    bumping). The
    pending fix of D62: the refusal rule reads "a **catalog** fault whose
    `applies_to` does that is not listed", and the stale "(footprint:
    O57)" points at D84;
  - the templates `brick.yaml`, `brick-gm.md`, `fault.yaml`,
    `scenario.yaml`, `answer-key.yaml` and `layouts.md`, to master spec
    6.1 to 6.5 and the W1 capture;
  - `scenario-document`: the template renders `source` (the column v0.1
    called `where`), `where` with its v0.2 meaning, and the tooling
    expectations;
  - migration: `postgres` and `bastion` to 0.2.0 (`brick.yaml` in the new
    shapes, their v0.1 figures as their own footprint, secrets with their
    kind, the receiving declaration; `docs/gm.md` to match, including the
    image tag and Connections saying the image accepts mounted material;
    their stack tests' image tags); the six catalog faults add `"0.2.0"`
    to `applies_to`; `bookshop-new-server` and `fixture-audit` re-pinned
    (keeping their own versions), their answer keys' v0.1 `where` text
    moved to `source` and a `where` location added to every evidence
    entry (D101), and an empty `tooling_expectations`, the fixture's
    scenario-local
    faults' `applies_to` extended, both READMEs regenerated.
  - Out: any loader, renderer or image change; the bricks' v0.2 features
    (chunks 6, 7).
- Files: `.claude/skills/scenario-format/SKILL.md`,
  `.claude/skills/scenario-format/templates/{brick.yaml,brick-gm.md,fault.yaml,scenario.yaml,answer-key.yaml,layouts.md}`,
  `.claude/skills/scenario-document/{SKILL,template}.md`,
  `bricks/{postgres,bastion}/brick.yaml`,
  `bricks/{postgres,bastion}/docs/gm.md`,
  `bricks/{postgres,bastion}/tests/{run-stack-test.sh,stack.test.yml}`,
  `faults/pg-*/fault.yaml`,
  `scenarios/bookshop-new-server/{scenario.yaml,gm/answer-key.yaml,README.md}`,
  `tools/tests/fixtures/fixture-audit/` (`scenario.yaml`, answer key,
  faults' `fault.yaml`, `README.md`).
- Spec sections: master spec 6, 11.2; [../../formats.md](../../formats.md);
  spec D62, D84, D100, D101.
- Atoms: none (no intent register).
- Done when: every template carries every item master spec 6 requires
  and loads as YAML; the format skill states the "catalog fault" rule;
  the loader, unchanged, loads both v0.1 bricks at 0.2.0, the six faults,
  `bookshop-new-server` and the fixture; the unit suite (with
  `test_brick_docs`) passes; both images build as 0.2.0 and their stack
  tests pass; both READMEs match a fresh regeneration.
- Verification: chunk checks.
- Split rule: 1a brick and fault formats: the `brick.yaml`,
  `brick-gm.md`, `fault.yaml` and `layouts.md` templates, the skill's
  brick and fault rules (D62 fix included), and their migration (both
  bricks, the six faults, the fixture's faults, the two scenarios'
  pins). 1b scenario formats: the `scenario.yaml` and `answer-key.yaml`
  templates, the skill's scenario rules, the scenario-document skill,
  and the two answer keys and READMEs. Each half leaves the suite green.

### Chunk 2 — Loader checks for v0.2

Status: merged (w1, ff86571)
Record: cd3b33f (2a), bdc7547 (2b), merge ff86571. Choices where W1 was
silent and the refusal messages: wave log, capture W1-C. No deviation.
Wave: 1
Depends on: chunk 1 (W1 capture)
Architecture capture: none of its own; it implements W1.

- Goal: the scripts refuse what master spec 6 says the format refuses,
  with the list of what is missing or wrong.
- Scope: in:
  - bricks: a mounted-material declaration whose files are missing from
    `companion/`, whose target is not absolute, or whose receiving
    parameter the brick does not declare; a receiving declaration in the
    W1 shape;
  - scenarios: with a node whose brick mounts material, the parameter
    (the node-health map) is required and lists every node of the
    topology, each entry `default` or a list of services; every
    receiving node's brick provides the mounting brick's requirements
    (s6-overlay version, commands), checked against the mounting brick's
    pinned version; the map is checked as the scenario states it,
    before any parameter fault applies;
  - faults: `injection.kind: parameter`, validated as seed changes are
    (the target node's brick has the parameter; the change is well
    formed); a fault about mounted material targets the mounting brick's
    node, names only that brick in `applies_to`, and its affected-node
    parameter names a node of the topology; `applies_to` versions are
    exact version strings, never ranges;
  - answer keys: `where` required on every evidence entry, one of
    `bastion`, `node:<name>` (a node), `ui:<name>` (a route of the
    bastion's web front), `report:<tool>`, and `source` required beside
    it (spec D101); `tooling_expectations` in the
    W1 shape; an issue may cover a tooling expectation;
  - unit tests with a fixture using scenario-local bricks that mount and
    receive material.
  - Out: rendering and deploying any of it (chunk 5); `fit` (chunk 8);
    the single-network refusal stays as it is (D83, spec D106).
- Files: `tools/gm/model.py`, `tools/tests/test_model.py`,
  `tools/tests/fixtures/fixture-mounted/` (new).
- Spec sections: master spec 6.1, 6.3, 6.4, 7.1 ("Configuration");
  spec D101, D106.
- Atoms: none.
- Done when: unit tests show each refusal above with its message, and
  acceptance of the fixture; every catalog brick, fault and scenario
  still loads; the unit suite passes.
- Verification: chunk checks.
- Split rule: 2a brick side (mounted material, receiving declarations,
  the map and the requirements check); 2b fault and answer-key side
  (parameter kind, mounted-material faults, version lists, `where`,
  tooling expectations).

### Chunk 3 — Secrets by kind, network names and UTC

Status: merged (w1, 8688c7e)
Record: 9e5c8b3, merge 8688c7e. Changes v0.1 captures W2-A and W3-A (secrets
layout, network, `gmctl status`): wave log, capture W1-B. Tests outside
Files: `test_state`, `test_teardown`. Key comment now `<gid>-<pair>`.
Wave: 1
Depends on: chunk 1 (W1 capture: secret kinds); G3
Architecture capture: none of its own; it implements W1's secret kinds.

- Goal: `gmctl deploy` generates the secrets the bricks declare, by kind;
  networks render under their own names; every node runs in UTC.
- Scope: in: `localimpl`'s fixed `SECRET_FILES` replaced by the secrets
  the topology's bricks declare, each generated once per game by kind
  (password; key pair, giving the private and public files), into
  `secrets/` (mode 0600), so the tools password and the monitoring
  role's password are generated with the others and kept for a restarted
  GM; each declared network rendered as `<game_id>_<network name>`
  (master spec 6.3) instead of `<game_id>_net`; `TZ=UTC` in every
  service's environment; `gmctl status` and `gmctl.md` updated for the
  secrets and network lines; tests. Out: mounted material (chunk 5).
- Files: `tools/gm/{localimpl,render,deploy,state}.py`,
  `tools/tests/test_{render,deploy,fit}.py`, `tools/tests/smoke.sh`
  (network name), `.claude/skills/game-master/gmctl.md`.
- Spec sections: master spec 6.3 ("Networks"), 8.
- Atoms: none.
- Done when: unit tests show a brick declaring a new password secret and
  a key pair gets them generated (mode 0600) and mounted, the v0.1
  secrets keep their file names, the network is named after the
  scenario's network, and every service has `TZ=UTC`; `docker stack
  config` accepts the rendered stack; `smoke.sh` passes.
- Verification: chunk checks, plus `sh tools/tests/smoke.sh` (needs G3).

### Chunk 4 — `prometheus` brick and the node-health script

Status: merged (w1, 4c47239)
Record: 54279f8 (4a), d05bb10 (4b), merge 4c47239. Prometheus 3.13.5;
sub-path `--web.external-url=/prometheus/ --web.route-prefix=/prometheus/`
on :9090, admin and lifecycle flags not passed; retention as
`storage.tsdb.retention.{time,size}` in the seed `prometheus.yml` (3.13
deprecates the flags), applied by SIGHUP; wrappers `gm-reload-prometheus`,
`gm-validate` (`/etc/sudoers.d/gm-player`); validator
`/opt/gm/validator/validate.sh`. Node-health: port 9110 (`GET /metrics`);
listener as `nobody:nogroup`, sampler as root (`s6-svstat` and `du` cannot
read as an unprivileged account; reported to the owner, wave 1 report);
cgroup v2 files readable in the container's own namespace; empty s6 files
carry a comment line; configs mount into folders the image lacks. Image
about 488MB against master spec 12's 150M estimate; script 6M per node.
Details: wave log, capture W1-D.
Wave: 1
Depends on: chunk 1 (W1 capture), G2, G3
Architecture capture: none beyond W1. The commands the node-health
script uses are W1's command vocabulary; the files, port and account
it settles are recorded in its Record line and `docs/gm.md`.

- Goal: the metrics store as a full node, and the per-node health script
  it ships as mounted companion material.
- Scope: in:
  - **the node** (`prometheus` 0.1.0): `debian:13-slim`, s6-overlay v3,
    `sshd` and `player`, read-only root, seed-once entrypoint, Prometheus
    pinned with its checksum; scrape targets in the seed configuration;
    retention bounded by time and by size, about a day, its flags read
    from a seed file, so a retention fault is a seed-file fault, fixable
    on a fixable node (spec D106); admin and
    lifecycle endpoints disabled; served under the web front's sub-path;
    a reload wrapper and `gm-validate` with a restricted `sudoers`; the
    validator; `brick.yaml` with the footprint estimate (master spec 12,
    without the script); `docs/gm.md` (nine sections) and
    `docs/player.md`; a stack test;
  - **the node-health script** (`companion/`): CPU and memory from the
    node's cgroup v2 files, disk as its volumes' use (`du`) against its
    declared reservation, the host's free space, the services' status
    through `s6-svstat`, in Prometheus' text format on a fixed port,
    through a minimal Perl listener; its s6 service files with non-empty
    content; an unprivileged account unless `s6-svstat` cannot read as
    one; `brick.yaml`'s mounted-material declaration, the node-health map
    parameter and the requirements; `docs/gm.md`'s Placement,
    Configuration, Footprint (its per-node cost) and Supported faults
    cover it; the stack test mounts it as configs into a `postgres` 0.2.0
    node and the `prometheus` node, and Prometheus scrapes both.
  - Out: rendering the mounts through `gmctl` (chunk 5); faults (chunk 13).
- Files: `bricks/prometheus/{Dockerfile,brick.yaml}`,
  `bricks/prometheus/rootfs/` (s6 services, entrypoint, wrappers,
  `sudoers.d`), `bricks/prometheus/validator/validate.sh`,
  `bricks/prometheus/companion/` (the script, the listener, the s6
  service files), `bricks/prometheus/docs/{gm,player}.md`,
  `bricks/prometheus/tests/{stack.test.yml,run-stack-test.sh}`.
- Spec sections: master spec 7, 7.1, 7.2, 12, 15; access model 5
  ("Nodes", "Monitoring interfaces"), 7; spec D106.
- Atoms: none.
- Done when: the image builds; the stack test shows the node healthy,
  SSH as `player` with exactly its wrappers, edits to the seed copy
  surviving a reload, a retention change in its seed file taking effect
  through the wrapper, the admin and lifecycle endpoints refused, the UI
  answering under its sub-path, the validator 0 then 1; and, with the
  script mounted, each node's endpoint readable from the other node,
  showing CPU, memory, disk against the reservation, the host's free
  space and each listed service, a service stopped with `s6-svc -d`
  shown as down, and the files read-only for `player`; the loader
  accepts `brick.yaml`; `test_brick_docs` passes; each master spec 15
  item of chunk 4 in "Left for the build" is recorded.
- Verification: chunk checks, plus the stack test (needs G3).
- Split rule: 4a the node (image, s6, entrypoint, wrappers, validator,
  `brick.yaml` without the mounted material, docs, stack test); 4b the
  node-health script (`companion/`, the declaration and map in
  `brick.yaml`, its `docs/gm.md` parts, the stack test's mounted part).

### Chunk 5 — Mounted material and parameter faults in the local implementation

Status: in progress
Record: (after merge)
Wave: 2
Depends on: chunks 2, 3
Architecture capture: none of its own; it implements capture W1 items 2
(shaped parameters) and 4 (the per-node config) and reads the merged
loader.

- Goal: `gmctl` renders mounted companion material into every receiving
  node, passes shaped parameters as W1 says, and plants parameter faults
  at rendering.
- Scope: in: `implementation.yaml` gains, for each receiving node, the
  mounting brick's files as root-owned read-only configs at their target
  paths and modes, plus that node's own config with its map entry and its
  disk reservation; the configs are created by `deploy` like the others
  and never empty; parameter faults applied to the target node's
  parameters before the mounted material is derived, so a node left out
  of the map gets no script; `gmctl inject` reports a parameter fault as
  planted at rendering, as it does a seed-file fault; `gmctl.md`'s
  render and inject lines; tests on the chunk 2 fixture;
  `render.service_environment` (as chunk 3 leaves it, with `TZ=UTC`)
  following the parameter's `shape` (W1 item 2): a `node-map` parameter
  is never passed as `GM_*`, a `web-routes` parameter is passed as
  `GM_<NAME>` holding `name=node:port` tokens, space-separated, sorted by
  name, `""` when the map is empty, and a scalar parameter as in v0.1;
  its unit tests; `fixture-mounted`'s `README.md`, when regenerated,
  keeps chunk 2's rendering of a map-valued parameter (inline YAML;
  the template's rule is chunk 11's). Out: any brick.
- Files: `tools/gm/{localimpl,render,inject}.py`,
  `tools/tests/test_{render,inject,fit}.py`,
  `tools/tests/fixtures/fixture-mounted/`,
  `.claude/skills/game-master/gmctl.md`.
- Spec sections: master spec 6.1, 6.4, 7.1 ("Delivery", "Where"), 8;
  capture W1 items 2 and 4 ([wave-log.md](wave-log.md)).
- Atoms: none.
- Done when: unit tests show the configs added to every node of the map
  and only to them, the per-node config carrying the entry and the disk
  reservation, a parameter fault removing a node (no configs on it) or a
  service (its entry without it), no config empty, `inject` reporting a
  parameter fault without running anything; unit tests on
  `service_environment` show a `node-map` parameter absent from the
  environment, a `web-routes` map written out of order passed as its
  tokens sorted by name (`{prometheus: "prometheus:9090", grafana:
  "grafana:3000"}` gives `GM_WEB_ROUTES` =
  `grafana=grafana:3000 prometheus=prometheus:9090`), an empty map
  passed as `""`, and scalar parameters unchanged; `docker stack config` accepts the rendered stack;
  `smoke.sh` passes unchanged.
- Verification: chunk checks, plus `sh tools/tests/smoke.sh` (needs G3).

### Chunk 6 — `postgres` 0.2.0

Status: in progress
Record: (after merge)
Wave: 2
Depends on: chunks 1, 3; G2, G3
Architecture capture: none (chunk 9 reads the merged brick).

- Goal: PostgreSQL's file logs for pgBadger, `pg_stat_statements`, and
  the exporter's monitoring role.
- Scope: in: logs to files on a new log volume, rotated by size, with a
  `log_line_prefix` pgBadger parses and `log_timezone = UTC`, these
  settings in the seed `postgresql.conf` (the brick's test seed and its
  documentation); log files readable by the players' group; pgBadger
  installed, run by `player` as a one-shot job, its HTML report in the
  player's home; `pg_stat_statements` available, its preloading in the
  seed configuration; the monitoring role holding `pg_monitor`, its
  password from a per-game secret (kind password, readable by root and
  `postgres` only on this node), created by a start-up step or the data
  load as the chunk settles (master spec 15); `brick.yaml` (log volume,
  secret, footprint); `docs/gm.md` (Configuration, Access, Footprint,
  Known limits: `gmctl logs` shows only the start-up) and
  `docs/player.md` (pgBadger, `scp` and `sftp`); the stack test. Out:
  the exporter (chunk 9); faults (chunk 13).
- Files: `bricks/postgres/Dockerfile`, `bricks/postgres/rootfs/`
  (entrypoint, s6 `postgres` service), `bricks/postgres/brick.yaml`,
  `bricks/postgres/docs/{gm,player}.md`,
  `bricks/postgres/tests/{stack.test.yml,run-stack-test.sh,fixtures/postgresql.conf}`,
  `bricks/postgres/validator/validate.sh` (only if the envelope changes).
- Spec sections: master spec 7.5, 7.3, 15; access model 5 ("Database
  and its logs"), 8.
- Atoms: none.
- Done when: the image builds; the stack test shows the log file written
  in UTC on the log volume and readable by `player`, a pgBadger run as
  `player` producing an HTML report in its home, `pg_stat_statements`
  queryable when preloaded, the monitoring role present with
  `pg_monitor` and the secret's password, the secret unreadable by
  `player`, and the v0.1 checks of the stack test still passing; the
  version stays 0.2.0; `test_brick_docs` passes.
- Verification: chunk checks, plus the stack test (needs G3).
- Split rule: 6a image and start-up (pgBadger, the log directory and
  volume, the monitoring role step); 6b `brick.yaml`, docs, stack test.

### Chunk 7 — `bastion` 0.2.0: the web front

Status: planned
Record: (after merge)
Wave: 2
Depends on: chunks 1, 3, 5 (in wave 2: the routes parameter rendered
as `GM_WEB_ROUTES`); G2, G3 (G7 done)
Architecture capture: none (chunk 10 reads the merged brick); the
routes parameter and its `GM_WEB_ROUTES` encoding are W1's (items 2, 3).

- Goal: every monitoring web interface published through the bastion,
  behind the tools password.
- Scope: in: a reverse proxy (chosen by the chunk, about 10–20M of
  memory) under s6 on the bastion's second port, default 8080, in host
  mode, published as the scenario's `published_ports` state; one path
  per route of the routes parameter; HTTP basic authentication on the
  tools password (a per-game secret, kind password), plain HTTP, 401
  without it; the `Authorization` header not passed on to Grafana; with
  no route (no web interface in the topology) the front does not run,
  the second port is not published and the tools password is not handed
  over, so a `bookshop-new-server` game looks as in v0.1 (spec D103);
  `brick.yaml` (interface, secret, parameter, footprint) and docs
  (Access: the web interfaces and their paths, and the case without
  any; the player's documentation on reaching them); the stack test with
  a stub upstream. Out: the upstreams themselves (chunks 4, 10); any
  change to the two v0.1-shaped scenarios.
- Files: `bricks/bastion/Dockerfile`, `bricks/bastion/rootfs/` (s6
  service, start-up), `bricks/bastion/brick.yaml`,
  `bricks/bastion/docs/{gm,player}.md`,
  `bricks/bastion/tests/{stack.test.yml,run-stack-test.sh}`.
- Spec sections: master spec 7.6, 15; access model 3, 5 ("Bastion and
  web front"), 6, 7, 12; spec D103.
- Atoms: none.
- Done when: the image builds; the stack test shows a request without
  the password refused with 401 and a challenge, a request with it
  reaching the stub under its path, the `Authorization` header absent
  upstream, SSH unchanged; with an empty routes parameter the front does
  not run and only SSH answers; the version stays 0.2.0; `smoke.sh`
  passes (the fixture-audit game, SSH only); `test_brick_docs` passes.
- Verification: chunk checks, plus the stack test and `smoke.sh` (need
  G3).
- Split rule: 7a the proxy (image, s6 service, configuration from the
  routes parameter, the password file at start-up, the case without
  routes); 7b `brick.yaml`, docs, stack test.

### Chunk 8 — `gmctl fit` counts the images

Status: planned
Record: (after merge)
Wave: 3
Depends on: chunk 1 (G6 done)
Architecture capture: none.

- Goal: the capacity check counts the images' sizes against the declared
  disk (master spec 8).
- Scope: in: image sizes read from the playground's engine (`docker
  image inspect` through the endpoint), each image layer counted once
  (the shared `debian:13-slim` layer once), a missing image refused with
  its build command (spec D102); `fit` now needs the engine reachable;
  the report line for images; `gmctl.md`'s `fit` line; tests. Out: any
  other capacity rule.
- Files: `tools/gm/fit.py`, `tools/gm/docker.py`,
  `tools/tests/test_fit.py`, `.claude/skills/game-master/gmctl.md`.
- Spec sections: master spec 8, 12; spec D83, D102.
- Atoms: none.
- Done when: unit tests (engine stubbed) show fit passing with images
  counted, refusing when reservations plus images plus headroom exceed
  the declared disk, a shared layer counted once, a missing image refused
  with its build command and an unreachable engine reported; `smoke.sh`
  passes.
- Verification: chunk checks, plus `sh tools/tests/smoke.sh` (needs G3).

### Chunk 9 — `postgres-exporter` brick

Status: planned
Record: (after merge)
Wave: 3
Depends on: chunks 3, 6; G2, G3
Architecture capture: at wave 3 start, for chunk 11: its seed files,
parameters, metrics port, secret name and wrapper names.

- Goal: PostgreSQL's metrics, from `postgres_exporter` on a full node.
- Scope: in: `postgres-exporter` 0.1.0 on `debian:13-slim` with
  s6-overlay, `sshd`, `player`, read-only root, seed-once entrypoint,
  `postgres_exporter` pinned with its checksum; connecting with chunk 6's
  monitoring role, its password from the per-game secret readable by the
  exporter's account only; wrappers and validator as the chunk settles
  (master spec 15); `brick.yaml` (footprint estimate, receiving
  declaration), `docs/gm.md` and `docs/player.md`; a stack test against
  a `postgres` 0.2.0 node. Out: faults (chunk 13).
- Files: `bricks/postgres-exporter/{Dockerfile,brick.yaml}`,
  `bricks/postgres-exporter/rootfs/`,
  `bricks/postgres-exporter/validator/validate.sh`,
  `bricks/postgres-exporter/docs/{gm,player}.md`,
  `bricks/postgres-exporter/tests/{stack.test.yml,run-stack-test.sh}`.
- Spec sections: master spec 7, 7.3, 15; access model 5, 7, 8.
- Atoms: none.
- Done when: the image builds; the stack test shows `pg_up 1`, the
  `pg_stat_statements` metrics when preloaded, the secret unreadable by
  `player`, `player`'s wrappers, the validator 0 then 1; the loader
  accepts it; `test_brick_docs` passes.
- Verification: chunk checks, plus the stack test (needs G3).
- Split rule: 9a image, s6, entrypoint, wrappers, validator; 9b
  `brick.yaml`, docs, stack test.

### Chunk 10 — `grafana` brick

Status: planned
Record: (after merge)
Wave: 3
Depends on: chunks 3, 7; G2, G3 (G8 done)
Architecture capture: at wave 3 start, for chunk 11: its seed files
(provisioning), parameters, port and sub-path, the secret it reads, how
a check reads its live state through its API, and wrapper names.

- Goal: dashboards and alerting, on a full node behind the web front.
- Scope: in: `grafana` 0.1.0 on `debian:13-slim` with s6-overlay,
  `sshd`, `player`, read-only root, seed-once entrypoint, Grafana pinned;
  data sources, dashboards and alert rules provisioned from seed files
  `player` can edit on a fixable node; its own alerting, no contact point
  configured, alerts read in the alerting view; default time zone UTC;
  the administrator's password from the tools password secret, always;
  served under the web front's sub-path (master spec 15); a reload or
  restart wrapper and validator as the chunk settles; reference
  dashboards and alert rules (node health, PostgreSQL) in `companion/`,
  which scenarios copy into their seed files, never mounted; the
  node-health dashboard is the node-health view (spec D104);
  `docs/player.md` with the DO NOT TAMPER rule on users and the
  administrator's password; `docs/gm.md` (Checks: sealed checks judge the
  live state through the API); a stack test. Out: faults (chunk 13).
- Files: `bricks/grafana/{Dockerfile,brick.yaml}`,
  `bricks/grafana/rootfs/`, `bricks/grafana/validator/validate.sh`,
  `bricks/grafana/docs/{gm,player}.md`, `bricks/grafana/companion/`,
  `bricks/grafana/tests/{stack.test.yml,run-stack-test.sh}`.
- Spec sections: master spec 7, 7.4, 15; access model 5 ("Monitoring
  interfaces"), 7, 8, 11; spec D104.
- Atoms: none.
- Done when: the image builds; the stack test, with the reference
  dashboards and alert rules copied in as seed files, shows the
  provisioned data source, dashboards and alert rules present through
  the API, the
  administrator logging in with the secret's password, the time zone
  UTC, the UI answering under its sub-path, an edited seed file taking
  effect through the wrapper, the validator 0 then 1; the loader accepts
  it; `test_brick_docs` passes.
- Verification: chunk checks, plus the stack test (needs G3).
- Split rule: 10a image, s6, entrypoint, provisioning, wrappers,
  validator; 10b `brick.yaml`, docs, reference dashboards, stack test.

### Chunk 11 — Monitoring integration fixture and smoke run

Status: planned
Record: (after merge)
Wave: 3
Depends on: chunks 4, 5, 6, 7 (merged); chunks 9, 10 (in-wave, wave 3
capture)
Architecture capture: none of its own; it uses chunks 9 and 10's
captured interfaces.

- Goal: one `gmctl`-driven game with all five bricks, run at every wave
  gate from here on; the scenario document's rule for map-valued
  parameters, first needed by this fixture.
- Scope: in:
  - a fixture scenario with `bastion`, `postgres`, `prometheus`,
    `postgres-exporter` and `grafana` at their v0.2 versions, the
    node-health map, scrape targets, Grafana provisioning copied from
    `grafana`'s reference dashboards and alert rules (spec D104), and
    web front routes; `smoke-monitoring.sh` running `fit`, `render`,
    `deploy`, `load-data`, then checking: every scrape target up and the
    exporter connected (Prometheus' API, through `exec`); every node's
    health endpoint with CPU, memory, disk and services, a service
    stopped by the script shown as down; the web front refusing without
    the password (401) and reaching Prometheus and Grafana under their
    paths with it, `Authorization` not reaching Grafana; only the
    bastion's two ports published; `TZ=UTC` on the nodes and UTC in
    PostgreSQL's log; then teardown leaving nothing labelled with the
    game id;
  - the scenario-document skill and template: a rule for a map-valued
    node parameter, keyed on the parameter's `shape` in the pinned
    brick's `brick.yaml` (the one catalog file the skill reads, for this
    alone, so a scenario-local brick's map is covered too), rendered
    under the node's **Parameters**:
    - `node-map` (`prometheus`'s `node_health`): one item per entry, in
      YAML order, the node and its services, `default` kept as written
      and glossed as the brick's s6 processes; then one line in master
      spec 7.1's and the access model's wording: the node-health script
      is mounted into every node listed, read-only for players, its
      endpoint readable from every node of the game. The map is shown
      as `scenario.yaml` states it, before any parameter fault; a fault
      leaving a node or a service out is listed in section 5;
    - `web-routes` (the bastion's `web_routes`): one row per route, in
      YAML order: the route as `ui:<name>` (the name the answer key's
      evidence uses), its path `/<name>/` on the web front, the upstream
      node and port; then one line in master spec 7.6's and access model
      5 and 7's wording: published on the bastion's web front port,
      behind the tools password, HTTP 401 without it. An empty map: the
      web front does not run, the bastion publishes SSH only and no
      tools password is handed over;
    - the skill's step 6 check lists every map entry; the template's
      version line; every README with a map-valued parameter regenerated
      with the rule: the fixture's and `fixture-mounted`'s (inline YAML
      until now, chunks 2 and 5).
  - Out: faults.
- Files: `tools/tests/fixtures/fixture-monitoring/` (new),
  `tools/tests/smoke-monitoring.sh` (new), `tools/tests/test_model.py`
  (the fixture loads), `.claude/skills/scenario-document/{SKILL,template}.md`,
  `tools/tests/fixtures/fixture-mounted/README.md`.
- Spec sections: master spec 6.3, 7, 7.1, 7.6, 9, 14 (items 5, 7);
  access model 5 ("Bastion and web front", "Nodes"), 7; spec D103,
  D104; capture W1 items 2, 3, 6 ([wave-log.md](wave-log.md)).
- Atoms: none.
- Done when: `smoke-monitoring.sh` passes on the build host; the fixture
  passes the loader and `fit` on a playground declared at
  2 CPU / 4G / 8G; the fixture's README lists every `node_health` entry
  and every route as the rule says, and it and `fixture-mounted`'s match
  a fresh regeneration.
- Verification: chunk checks, plus `sh tools/tests/smoke-monitoring.sh`
  (needs G3).

### Chunk 12 — GM skill for v0.2

Status: planned
Record: (after merge)
Wave: 4
Depends on: chunks 3, 5, 7, 8, 10
Architecture capture: none.

- Goal: the GM runs a v0.2 game as master spec 9 says.
- Scope: in: `SKILL.md`: building the new images from the bricks'
  `docs/gm.md`; `fit` counting images; deployment mounting the
  node-health script when there is a `prometheus` node; hand-over adding
  the tools password and the web front's address and port (from the
  local implementation) when the topology has a web interface, and
  neither otherwise (spec D103); every time stated in UTC; the file log read
  through `exec`, since `gmctl logs` shows only PostgreSQL's start-up;
  operating the monitoring tools from inside their nodes through `exec`
  (Grafana's API with the administrator's password, Prometheus' API);
  the DO NOT TAMPER rule at hand-over; evaluation with sealed checks
  that judge Grafana's live state. `feedback.md`: tooling expectations
  judged in feedback, under-tooling and overkill as findings. `gmctl.md`:
  the lines chunks 3, 5 and 8 did not change. Out: new scripts; the
  stance itself, unchanged.
- Files: `.claude/skills/game-master/{SKILL,gmctl,feedback}.md`.
- Spec sections: master spec 8, 9, 10; access model 3, 7, 8, 9; spec
  D102, D103.
- Atoms: none.
- Done when: the skill covers each item of master spec 9, the
  hand-over of the tools password only with a web interface, and `fit`
  needing the engine and the images built; every `gmctl` invocation in the three
  files parses with `gmctl`'s own parser; the stance check-list items
  are unchanged.
- Verification: chunk checks; the stance check-list runs at the release
  gate.

### Chunk 13 — Monitoring faults

Status: planned
Record: (after merge)
Wave: 4
Depends on: chunks 2, 4, 5, 6, 9, 10, 11
Architecture capture: at wave 4 start, for chunk 14: the chosen faults,
their ids, kinds, target bricks, parameters and resolutions.

- Goal: four to six catalog monitoring faults for the v0.2 scenario.
- Scope: in: faults chosen from master spec 11.1's candidates, all
  visible without load, at least one a tool starved of information; the
  node-health ones as parameter faults on the `prometheus` node, naming
  only `prometheus` in `applies_to`, with the affected node as a
  parameter, *report* or *propose* only; each with `fault.yaml`,
  `inject/`, `checks/fixed.sh` (Grafana's through its API, on its live
  state), `checks/probe.md`, `gm.md`; the "Supported faults" sections of
  every brick they name, folding into the brick's version. Out: the
  scenario (chunk 14); a default-password fault (D93); a masking pair.
- Files: `faults/<fault-id>/` for each, `bricks/{prometheus,grafana,postgres,postgres-exporter}/docs/gm.md`
  ("Supported faults" only).
- Spec sections: master spec 6.4, 11.1; spec D92, D93.
- Atoms: none.
- Done when: the loader accepts each fault; `test_brick_docs` passes; on
  the integration fixture's deployment each injection succeeds (twice
  with the same result for a state fault), each sealed check returns 1,
  and 0 after its fix for the fixable ones.
- Verification: chunk checks, plus the faults planted on a deployment of
  the integration fixture (needs G3).

### Chunk 14 — The v0.2 scenario and the measured footprint

Status: planned
Record: (after merge)
Wave: 4
Depends on: chunk 13 (in-wave, wave 4 capture); chunks 4, 5, 6, 7, 9,
10, 11; G10 before merge (G8, G9 done)
Architecture capture: none of its own; it uses wave 4's fault capture.

- Goal: the partly tooled v0.2 scenario, complete, and the footprint
  measured on its game.
- Scope: in:
  - **14a, the scenario**: one database, a small or mid-size customer,
    some monitoring present and ill-configured, one need left uncovered
    as an under-tooling issue or tooling expectation; it has Grafana, so
    the node-health view exists, and the uncovered need is another one
    (master spec 11.1, spec D104); its Grafana seed files start from
    `grafana`'s reference dashboards and alert rules; chunk 13's faults mixed with v0.1 database
    faults; `scenario.yaml` (the node-health map, the web front routes,
    per-node `resources` including the script), `gm/answer-key.yaml`
    with `where` and `source` on every evidence entry and the tooling
    expectation, `gm/notes.md`,
    `brief.md`, the starter pack (DO NOT TAMPER on Grafana's users and
    password), node seed files, `data/db.sql`, `README.md` regenerated;
  - **14b, the footprint**: a full game on the `laptop` playground,
    declared at 2 CPU / 4G / 8G on the build host (spec D105), `docker
    stats` at rest after hand-over, during a Grafana
    dashboard load and during a pgBadger run, `docker system df -v` for
    images and volumes, figures in the wave log with machine and date; a
    brick the scenario does not use measured on the integration
    fixture's game (spec D106); reservations raised where a node at rest exceeds
    its reservation; the bricks' `brick.yaml` and `docs/gm.md` footprints
    and the scenario's `resources` carrying the measured figures; `fit`
    re-run, passing on `laptop`.
  - Out: the release notes (release gate).
- Files: `scenarios/<new-id>/` (all of it); 14b:
  `bricks/*/brick.yaml`, `bricks/*/docs/gm.md` ("Footprint"),
  `scenarios/<new-id>/{scenario.yaml,README.md}`.
- Spec sections: master spec 11.1, 12, 14 (items 1–3); access model 7,
  11; spec D101, D104, D105, D106.
- Atoms: none.
- Done when: the format skill finds nothing missing; `fit` (images
  counted) and `render` accept it on `laptop`; on its smoke deployment
  every injection succeeds and every sealed check returns 1; the
  footprint passes master spec 14 item 3; G10 cleared.
- Verification: chunk checks, plus the smoke deployment and the
  footprint measurement (needs G3).
- Split rule: 14a the scenario folder; 14b the measurement and the
  footprint figures.

## Release gate

Against master spec section 14, on the merged code, on the build host's
single-node swarm, with v0.1's checks still applying:

1. Item 1: the v0.2 scenario's folder is complete (the format skill
   finds nothing missing) and G10 is cleared; every brick it uses passes
   the format skill's `docs/gm.md` check, `prometheus`'s covering the
   node-health script.
2. Item 2: a full game of the v0.2 scenario in a GM session, on the
   `laptop` playground, declared at 2 CPU / 4G / 8G on the build host
   (spec D105), from setup through hand-over, with `gmctl fit` passing,
   images counted.
3. Item 3, the footprint check against 2 CPU / 4G / 8G: during that game,
   `docker stats` on every node at rest after hand-over, during a Grafana
   dashboard load and during a pgBadger run; `docker system df -v` for
   the images and each volume. Passing: no node OOM-killed or restarted
   during the game; each node's memory at rest within its reservation
   (or the reservation raised in `brick.yaml` and `docs/gm.md` and `fit`
   re-run, still passing on `laptop`); the reservations, with `fit`'s
   10 % headroom, within 2 CPU and 4G; images plus volumes in use within
   the declared 8G; the bricks' footprints carrying the measured figures
   in place of the estimates, a brick the scenario does not use measured
   on a game of the integration fixture (spec D106). The figures go next to the estimate in
   [README.md](README.md) "Footprint", with machine and date.
4. Item 4: the play-through as `player`, through the bastion only: each
   fault's evidence where the answer key says, interface evidence through
   the web front, checked through the interfaces' HTTP APIs, report
   evidence by generating the report.
5. Item 5: the node-health view (`grafana`'s reference dashboard, spec
   D104) shows every node's CPU, memory, disk (its volumes' use against
   its reservation) and services, with the host's free space once, and a
   service the GM stops shows as down.
6. Item 6: each *fix* issue on a monitoring tool fixed, its sealed check
   going from 1 to 0.
7. Item 7: the web front refuses a request without the tools password
   with HTTP 401; the game publishes only the bastion's SSH and web
   front ports; nodes and PostgreSQL's logs carry UTC times.
8. Item 8: the tooling expectation judged in the feedback.
9. Item 9: `bookshop-new-server`, re-pinned, passes its v0.1 checks: a
   full game publishing SSH only, with no tools password handed over
   (spec D103), the write policy, `sudo gm-validate`, each fault's
   evidence, each *fix* issue fixed with its sealed check from 1 to 0.
10. Item 10: the stance check-list, item by item; and v0.1's other
    checks: a fresh GM session resuming the game in progress, and a
    forced setup failure reported, torn down and recorded, leaving
    nothing labelled with the game id.
11. Item 11: the wave-gate quality command, green (unit tests, every
    image built, every shell script through `sh -n`).
12. Item 12, G11: the owner's judgement of the tooling's usefulness and
    the feedback's tone.
13. Every row of "Left for the build" has its finding recorded in the
    chunk's Record line and the brick's `docs/gm.md`.
14. Release notes in [README.md](README.md): the measured footprint, the
    master spec 15 findings, the known gaps of the access model that
    stand.
