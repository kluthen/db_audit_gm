# db_audit_gm v0.5 — Build plan

Status: v6 (2026-11-04): the owners' traffic in
`producers/partners/owners/`, chunk 16's folder choice settled; chunk 17
refuses a `public/` `data.sql`; G16 records both (spec D369). Chunk 12's
lab stub folder is its prefix, `xlab` (spec D370).
v5 (2026-11-04): G9's text correction, pgwatch its latest
release at the build (6.1.0), not "pgwatch 3"; chunk 10 names G9's
build conditions (spec D368).
v4 (2026-11-04): capture W2's ten preflight corrections written
in before wave 2's first chunk (chunks 6 to 11, 17, 21; G16); no chunk
inserted (spec D360–D367).
v3 (2026-11-03): wave 1's chunk reports (W1-w to W1-z) written
in, wave 2's chunks read against them; no chunk inserted (spec D352–D358).
Approval: **approved 2026-11-03 by the owner** (G1, spec D342).
Written from: [master-spec.md](master-spec.md) and
[access-model.md](access-model.md), approved 2026-11-03 (spec D339,
D340), section 21 its main input; the six domain documents, approved
with it as the column-level build input
([`vet-core`](vet-core-domain.md), [`vet-lab`](vet-lab-domain.md),
[`vet-scheduling`](vet-scheduling-domain.md),
[`vet-housing`](vet-housing-domain.md),
[`vet-machinery`](vet-machinery-domain.md),
[`vet-portal`](vet-portal-domain.md));
[data-register-handout.md](data-register-handout.md) section 7;
[clinic-test-selection.md](clinic-test-selection.md),
[clinic-capacity.md](clinic-capacity.md) and
[formats.md](../../formats.md) v28. No design set (no interface to
design, spec D2). Where this plan and those documents disagree, they
win and the plan is corrected.

The model is `~/.local/share/dev_team/references/build-plan-model.md`; this
plan states only its deltas. Its conventions follow v0.4's
[build plan](../../archive/v0.4/build-plan.md).

## Read first

- **Short tests only** (spec D314, master spec 18): every chunk check
  and every item of a wave gate runs **under 30 minutes**, on a fixture
  of **eight nodes at most, the bastion included**, on one host
  (armenelos), the VPS drained. Time is placed, never waited for: a
  check needing a nightly or periodic job sets its fixture's T0 just
  before the job, or moves the job; a WAL segment is switched by the
  test. **The one exception** is the release gate's whole-clinic run on
  armenelos plus the VPS (G13): about 30 minutes of smoke, each fault
  read present only. No aged run, no overnight cadence, no rehearsal, no
  stance check-list, no two-host run at any wave gate: those are the
  roadmap's [v1.0 gating](../README.md#v10-gating) (master spec 18.4).
- **No data preflight** (spec D329, master spec 21): the repository
  keeps no data register, and every scenario's data is synthetic. The
  game's own inventory is its catalogue. The clinic scenario's data
  register is game content, built by chunks 17 and 27.
- **No intent register** (no `.atd`, no `intent/`): no `documentalist`
  wave preflight, peek or sync. As in v0.4, the wave driver records each
  wave's captures in the wave log (W1 to W5), before any chunk of the
  wave starts, and each chunk's **Architecture capture** line says what
  its wave's capture must fix.
- **A brick bump and its re-pins land in one commit.** The loader
  refuses a scenario or fixture pinning a brick version its `brick.yaml`
  no longer carries (`find_definition`, `tools/gm/model.py`), the unit
  suite loads every scenario (`test_repo_scenarios_load`), and
  `test_brick_docs.py` requires each brick's "Supported faults" to match
  the faults whose `applies_to` names its version. So chunk 1 owns every
  bumped brick's version lines, every pin, every `applies_to` and those
  lists; the brick chunks own the rest of their brick.
- **The loader refuses no unknown key today** (`check_against_schema`
  reports missing keys only). A new key (`options:`, `standby_of:`,
  `third_parties:`) can appear in a file before chunk 6's checks; chunk
  6 then refuses what is wrong in it. **Two new values are refused
  until chunk 6**: `driver: http` (`model.DRIVERS`) and the weighted
  `choice` (the generator check), in a scenario and in a domain's
  fragments alike; a chunk using either is cut after chunk 6 (spec
  D348).
- **v0.4's lessons, kept**:
  - a start-up race (the `pgbouncer` DNS race, spec D305, fixed in v0.4
    by `pgbouncer` 0.1.1): every new brick and every new caller waits,
    bounded, for the names it resolves at start, and its stack test
    starts it before its peer (workflow deltas). A health-checked peer
    enters Swarm's DNS only once healthy (a fresh `postgres` node about
    49 s with initdb, past the 30 s bound): the caller then starts
    anyway and fails honestly (503, an error counted) until the name
    resolves, then works (W1-z; spec D356);
  - a fix-sized finding becomes an inserted chunk, the next free
    integer, its decision first, handed by the driver to a
    `coding-executor` (v0.4's chunks 20 and 21);
  - the driver never commits in a wave worktree while a chunk owner may
    be merging into it (v0.4 wave log, chunk 15b);
  - two-host runs moved to v1.0 gating (spec D311); in v0.5 the only one
    is G13.
- **No owner checkpoint for the faults** (master spec 21): the test
  selection (17.2) is the spec's fixture; a game's faults are the GM's.
- **The existing scenarios keep their seeds** (17.5): TLS and pgaudit
  stay available and unused in them; none lists `domains:`, so none
  needs a data register.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | Plan approval, κ included (workflow deltas); `v0.5-domains` merged into `main` on the owner's word, so wave 1 is cut from `main` | The owner | Wave 1 | done (2026-11-03, spec D342; the merge into `main` by the coordinator) |
| G2 | [formats.md](../../formats.md) carries master spec 6: the domain format, composition, the data register, the purpose format's extensions (draft v28) | `spec-writer` | Chunk 2 | done (2026-11-03, spec D338) |
| G3 | Network access at image build time: Debian 13's repositories, the PostgreSQL apt repository (PGDG: pgaudit, pgCluu if taken from it), the s6-overlay release, PyPI if G6 picks it, pgwatch's latest release on GitHub | Hand check by the wave driver | Every image build: chunks 1, 3, 4, 5, 10, 17; every wave gate | done (2026-11-03, wave log) |
| G4 | A Docker host in swarm mode: armenelos' swarm, the VPS a drained worker in it | Hand check by the wave driver | Every stack test and fixture deployment, every wave gate, the release gate | done (2026-11-03, wave log) |
| G5 | **Dependency preflight** on `postgres` 0.5.0's new packages: pgaudit's package for PostgreSQL 18 (PGDG) and what TLS needs in the image, with what they pull in, installed without recommends (master spec 7.1, 21). A finding the owner must rule on becomes a gate of its own | `security-advisor` (skill `dependency-check`), called by the wave driver at wave 1's start | Chunk 3's branch | done (2026-11-03, wave log) |
| G6 | **Dependency preflight** on `api` 0.1.0: FastAPI, uvicorn and the image's other packages (Starlette, Pydantic and what they pull in, psycopg 3), the candidate versions and their source (Debian 13 or a pinned PyPI set) (master spec 7.2, 21) | `security-advisor`, called by the wave driver at wave 1's start | Chunk 5's branch | done (2026-11-03, wave log) |
| G7 | **Dependency preflight** on `scheduler` 0.3.0, only if the HTTP driver or the scripts' client takes a package beyond the standard library, psycopg 3 and PyYAML (master spec 7.2, 24: the standard library preferred). With none, the driver records "not needed" in the wave log | `security-advisor`, called by the wave driver | Chunk 4's branch, if a package is added | not needed (2026-11-03, wave log; unless chunk 4 adds a package) |
| G8 | **Dependency post-change check** on what wave 1 resolved: `postgres` 0.5.0 (chunk 3), `scheduler` 0.3.0 (chunk 4), `api` 0.1.0 (chunk 5), with the version lines chunk 1 bumped; `.tech` updated, committed on `v0.5-w1` | `security-advisor`, called by the wave driver once chunks 3 to 5 have merged | Wave 1's gate | done (2026-11-03, wave log) |
| G9 | **Dependency preflight** on the monitoring breadth (spec D340): pgwatch's latest release at the build (6.1.0 at G9; a checksum-pinned download), Prometheus 3.13 re-checked as the sink's scraper, `check_postgres` (Debian), the health node's web server, pgCluu's package (master spec 7.4, 21) | `security-advisor`, called by the wave driver at wave 2's start | Chunk 10's branch | done (2026-11-04, wave log) |
| G10 | **Dependency post-change check** on chunk 10's resolved versions (`pgwatch` 0.1.0, `health-check` 0.1.0, `grafana` 0.3.0, pgCluu in `postgres` 0.5.0); `.tech` updated, committed on `v0.5-w2` | `security-advisor`, once chunk 10 has merged | Wave 2's gate | open |
| G11 | **Any other dependency** a chunk adds or upgrades (the cold-storage page's drawing, an endpoint's or a purpose script's package, the bastion's front): a preflight before its branch and a post-change check before its wave's gate, `.tech` updated. The driver adds a row `G11.<n>` for each; none is planned | `security-advisor` | That chunk; its wave's gate | standing |
| G11.1 | **Dependency preflight** on Debian `python3-yaml` 6.0.2 in `api` 0.1.0 (to parse `api.yaml`), asked by chunk 5's owner; its post-change check folded into G8 | `security-advisor` | Chunk 5; wave 1's gate | done (2026-11-03, wave log) |
| G12 | **The VPS window** for G13, under the VPS rule (workflow deltas): the VPS's own documentation read first; `tailscale status` on both hosts; the VPS still a drained worker of armenelos' swarm; no game port published on it; free disk for its share (about 4.9G of volumes and 1.5G of images, [clinic-capacity.md](clinic-capacity.md)); filetstudio.com answering before the run | Hand check by the wave driver | G13 | open |
| G13 | **The whole clinic deployed once on armenelos plus the VPS** (master spec 18.3, release gate items 4 and 5): `fit` and the deployment; about 30 minutes of smoke, every producer, partner and purpose running, each one's first run read; the test selection planted at once, each fault read present only where it reads in the window; no fix, no aging, no hand-over snapshot. The VPS `active` only inside the run's host lock and drained after, pass or fail; filetstudio.com polled throughout and answering after | The wave driver, on the owner's time (a two-host run is announced) | Release gate items 4 and 5 | open |
| G14 | **A CPU trim, if the build measures heavier** (master spec 14): applies only when `fit` on the clinic as built (chunk 27) refuses either host, or G13's figures exceed it; the trim is the owner's call, its order settled (O224, spec D343): the exporters kept, pgwatch dropped | The owner | Chunk 27's merge and G13, only if it applies | not yet applicable |
| G15 | The owner's judgement at release close: the short tests as run, G13's run, the named known limits and what stays v1.0 gating | The owner | Release close | open |
| G16 | [formats.md](../../formats.md) and master spec 5 carry wave 2's format items as built (spec D364): the `partners/` catalogue folder (cold storage's home, the shared nodes' base); a domain's `data/keys.sql` and `data/coherence.yaml`, a partner folder's `data.sql`, in `partners/<prefix>/` only, and the owners' traffic in `producers/partners/owners/` (formats.md's "chosen at the build", spec D369); a domain's schema never creating its database (`:"DBNAME"`); formats.md's "a domain is a design-time source", corrected for composed domains, which `load-data` reads from the catalogue. Written from W2-a, W2-c and W2-f | `spec-writer`, after wave 2's gate | Release gate item 6 | open |

G5, G6, G7 and G9 are preflights on candidate versions; G8 and G10 the
post-change checks on the resolved ones (skill
`dependency-gating-protocol`). The security advisor's other open items
that bear on rebuilt bricks are listed under "Pending with the owner";
none is a gate.

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3, 4, 5 | G1; G2 (done); G3, G4; G5 (chunk 3), G6 (chunk 5), G7 (chunk 4, if a package); G8 before its gate | gated (2026-11-04, wave log); merge into `main` on the owner's word |
| 2 | 6, 7, 8, 9, 10, 11 | wave 1; G9 (chunk 10); G10 before its gate | in progress (2026-11-04) |
| 3 | 12, 13, 14, 15, 16 | wave 2 | planned |
| 4 | 17, 18, 19, 20, 21 | wave 3 | planned |
| 5 | 22, 23, 24, 25, 26, 27 | wave 4; G14 (chunk 27, only if it applies) | planned |

```
1 ──> 2, 3, 4, 5        (in wave 1: cut once chunk 1 has merged into v0.5-w1; the
                         version lines, declarations and template keys, W1)
G5 ──> 3;  G6 ──> 5;  G7 ──> 4 (if a package)
1, 2, 5 ──> 6           (model.py after chunks 1 and 2)
3, 4, 5 ──> 7
2, 3 ──> 8
6 ──> 7, 8              (in-wave, merge order: `model.node_creates`, fixed by W2
                         item 1, and the scenario-format skill, 6's then 8's;
                         spec D360)
1, 2, 3, 5 ──> 9
6 ──> 9                 (in-wave: the weighted `choice` in vet-core's fragments,
                         fixed by W1 item 3; spec D348)
7, 8 ──> 9              (in-wave, its fixture only: `clinic_lookup`'s mount and
                         the composed load, fixed by W2 items 2 to 4; spec D362)
3, 6 ──> 10 (merge order only: its fixture's options checked); G9 ──> 10
3, 4, 5 ──> 11
6, 7 ──> 11             (in-wave: from 7 the partners' network aliases and the
                         HTTP credentials' mounts, fixed by master spec 10.2, 15
                         and W2; from 6 HTTP connections loading, W1 item 3;
                         spec D348)
4, 6, 8, 9, 11 ──> 12
4, 8, 9 ──> 13
4, 9 ──> 14
4, 5, 8, 9, 11 ──> 15
5, 8, 9, 11 ──> 16
12 ──> 16               (in-wave: the lab's key ranges and functions, its released
                         results and the tables the portal copies, from vet-lab's
                         domain document; W3)
7, 11, 12, 13, 14, 15, 16 ──> 17
9, 11, 12 ──> 18
9, 11, 12 ──> 19
3, 8, 9, 12, 13, 14 ──> 20
11, 13, 15, 16 ──> 21
18 ──> 22;  11, 17 ──> 23;  20 ──> 24;  6, 14, 16 ──> 25
2, 8, 11, 17 ──> 26
17, 22, 23, 24, 25, 26 ──> 27   (in-wave: the fault ids and seed changes of
                         master spec 17.2, the skill's sections; W5)
```

Wave 1's order: chunk 1 runs alone first; chunks 2 to 5 are cut from
`v0.5-w1` once it has merged, three at a time (chunk 3 once G5 is
cleared, chunk 5 once G6 is). Chunks 2 to 5 share no source file:
chunk 2 holds `tools/gm/model.py` in wave 1, chunk 3 the standby's and
TLS's tool side and the `api` nodes' connection roles (`render.py`,
`localimpl.py`, `inject.py`; spec D345), chunks 4 and 5 their bricks.

Wave 2 (capture W2, item 7): chunks 6, 7 and 8 start first, chunk 10 at
the first free slot; chunk 6 merges before 7, 8 and 10, and 7 and 8 take
`v0.5-w2` in once it has, before their own merge (spec D360). Chunk 9 is
cut once chunk 6 has merged, its fixture run once 7 and 8 have; chunk 11
is cut once chunks 6 and 7 have (vet-core's weighted `choice`, chunk
11's HTTP connections: spec D348). Chunk 10's fixture lists `options:
[monitoring]`, which loads before chunk 6 (unknown keys pass); it
merges after chunk 6 so its fixture is checked by the option rule. Two
completion chains run three chunks long (6, 7, 11 and 6, 8, 9), past the
model's two: kept, since the merge-order edges delay no start (7 and 8
start beside 6; 9 and 11 already waited for it) and W2 fixes every
interface the chains cross (spec D361).

Wave 3: chunks 12 to 15 start as κ allows; chunk 16 is cut once chunk
12 has merged. The five domains share no file but the root `README.md`'s
domain table.

Wave 4: no in-wave edge; the five chunks run as κ allows. Chunk 17 is
the largest; it starts first.

Wave 5: chunks 22 to 26 run as κ allows; chunk 27 is cut once all five
have merged.

## Workflow deltas

- **κ = 3**, confirmed by the owner for v0.5 (spec D342), as in v0.4: chunks
  with no path between them run side by side, each in its own worktree.
  Docker-using checks (image builds, stack tests, fixture deployments)
  are serialized by the host lock, `flock /tmp/dbagm-docker.lock
  <command>`.
- **Sleep inhibitor.** armenelos is a laptop: every Docker run longer
  than a few minutes runs under `systemd-inhibit
  --what=sleep:idle:handle-lid-switch`, held by the script or by the
  driver around it.
- **The VPS** (spec D159): the driver and its agents may work on it
  (`ssh vps`, `ssh://dbagm-vps` for the playground), never disturbing
  the applications it hosts; filetstudio.com stays up throughout, and
  its Caddy is shared (the game touches none of its site files). Its
  own documentation is read before any change there; each session
  touching it checks `tailscale status` on both hosts first. The VPS
  node **stays `drain`** for the whole build; only G13 sets it `active`,
  inside that run's host lock, and drains it again after, pass or fail,
  in the run's `trap` (`docker node update --availability active|drain
  vps-5718ad52`, run by the owner if the auto-mode classifier refuses).
  Every playground declaration naming the VPS marks it `shared`. No node
  that may exhaust its memory is placed there (none of the test
  selection sets `needs_unshared_host`).
- **Never `docker * prune`** on either host: superseded `dbagm` images
  are removed by name when the disk runs short, and nothing else is
  removed on the VPS.
- **Branches and worktrees**: waves `v0.5-w<n>` in
  `/home/bastien/work/db_audit_gm-wt/v0.5-w<n>`; chunks
  `v0.5-c<id>-<slug>` in `/home/bastien/work/db_audit_gm-wt/v0.5-c<id>-<slug>`.
  Never in the main checkout. Wave 1 is cut from `main` once
  `v0.5-domains` has merged into it (G1).
- **Shared lists**, under the model's in-wave rule:
  `tools/gm/__init__.py`'s verb and option registrations,
  `.claude/skills/game-master/gmctl.md`'s verb table, the root
  `README.md`'s brick, fault, purpose and domain tables, the bricks'
  "Supported faults" sections in `docs/gm.md` (the fault chunks 22 to
  25 all add to `postgres`' and `scheduler`'s), and the smoke scripts'
  `IMAGES=` lists.
- **Chunk checks**, in addition to the model's (v0.4's, kept):
  - Python: `python3 -m unittest discover -s tools/tests -t .`;
  - the scheduler program's unit tests, inside its image: `sh
    bricks/scheduler/tests/run-unit-tests.sh`; from chunk 5, the `api`
    brick's, `sh bricks/api/tests/run-unit-tests.sh`;
  - Python outside both suites (endpoint files, transformer scripts,
    purpose and fault checks): `python3 -m py_compile` on every file the
    chunk touches;
  - shell: `sh -n` on every shell file touched, those without an
    extension included (s6 `run` files, `rootfs/usr/local/sbin/*`,
    `rootfs/usr/local/lib/gm/*`, check scripts); `shellcheck` too when
    installed;
  - Perl: `perl -c` on every Perl file touched;
  - YAML: every YAML file touched loads with PyYAML, and, from chunk 2,
    with the loader's duplicate-key refusal;
  - SQL: a schema, load, derivation, history or material file runs into
    the `postgres` image at its current tag in a throwaway container,
    under the host lock;
  - a chunk touching a brick: `docker build -t
    127.0.0.1:5000/dbagm/<brick>:<version> bricks/<brick>` and its stack
    test, `sh bricks/<brick>/tests/run-stack-test.sh` (needs G4);
  - **a new brick or a new caller** (chunks 4, 5, 10, 11): its stack
    test starts it before the node it resolves, and shows it waiting,
    bounded, then working once the name resolves (the `pgbouncer`
    lesson); when the peer is a fresh health-checked node slower than
    the bound, the test shows the wait ending within its bound, the
    requests between failing honestly (503, an error counted, never a
    hang), and the work starting once the peer resolves (W1-z; spec
    D356);
  - **a chunk adding or changing a domain**: `check_domain_dir` clean on
    it, and its load run at shift 0 and at a non-zero shift, its time
    and size recorded (master spec 18.2);
  - **a chunk running a fixture**: `gmctl fit` on it on one host first;
    its T0 placed just before the job its check needs (18.1); the run
    under 30 minutes with the deployment, its figure recorded;
  - a chunk changing a scenario's or fixture's `scenario.yaml` or
    `gm/answer-key.yaml`: its `README.md` regenerated with the
    `scenario-document` skill in the same commit;
  - a chunk adding or changing a `gmctl` invocation in a Markdown file:
    the invocation parses with `gmctl`'s own parser.
- **Wave gate (full quality command)**, every step under the host lock
  and the sleep inhibitor, on armenelos alone, the VPS drained, at κ = 1
  for the gate itself; **each item under 30 minutes**:
  - the full unit suite; the scheduler's and (from wave 1) the `api`
    brick's unit tests; `sh -n`, `perl -c` and `py_compile` over every
    file of their kind;
  - every brick's image build and stack test, one at a time (eight
    bricks at wave 1, ten from wave 2), the unchanged bricks rebuilt
    under their present versions, as v0.4's gate did (see "Pending with
    the owner", the patch-bump policy);
  - `sh tools/tests/smoke.sh`, `sh tools/tests/smoke-monitoring.sh`,
    `sh tools/tests/smoke-governance.sh`, `sh tools/tests/smoke-load.sh`
    on armenelos alone;
  - `sh tools/tests/smoke-scenario.sh` on each of the four existing
    scenarios: its short smoke (deployment, first runs, teardown), never
    `smoke-purposes.sh`'s `cycles` or `baseline`, which are v1.0 gating.
    Each scenario is judged against its own design within the smoke's
    minutes (a key the timeline renames under its current name, a slow
    key's first run and a check's `too-soon` as the design places them),
    by the harness's rules as wave 1's gate fixed them (wave log; spec
    D367);
  - every fixture short test the wave's chunks ran, rerun on the merged
    wave branch, one at a time, with its figure;
  - what each wave adds, below ("Per-wave gate contents").
  A failure is traced to its chunk and fixed on the wave branch in its
  own commit. Then the driver's report to the owner; the merge into
  `main` on the owner's word.
- No link checker is configured; Markdown links are checked by reading.
- Images are tagged `127.0.0.1:5000/dbagm/<brick>:<version>`; every
  pinned download (s6-overlay, Prometheus, `postgres_exporter`,
  pgwatch) is checked against its published checksum in the Dockerfile.
- The release gate runs on `v0.5-w5` before it merges, as v0.4's did.

### Per-wave gate contents

| Wave | Adds to the full quality command |
|---|---|
| 1 | G8 cleared; the four re-pinned scenarios through `smoke-scenario.sh`; chunk 3's standby fixture (cloned, streaming, read-only queries answered) and a segment switched and archived to a stub; chunk 2's compose tests (merge, override, conflict, `merge.yaml`); the `api` brick's stack test with two hostnames |
| 2 | G10 cleared; `pgwatch`, `health-check` and `grafana` 0.3.0 built and stack-tested; chunk 10's monitoring fixture; chunk 11's partners fixture (one partner slow, another answering) and archive fixture (a segment and a base backup in the vault, the page and `GET /manifests`); chunk 8's coherence tests (a composed load passing, a broken range failing, a partner's state loaded); chunk 6's refusal fixture; `vet-core`'s load at shift 0 and at a non-zero shift; chunk 11's `pg_hba` form written into `postgres`' `docs/gm.md` |
| 3 | `check_domain_dir` clean on all six clinic domains and the shop; each domain's load at shift 0 and a non-zero shift, its figures; the bookings, housing, imaging and portal fixtures' domain checks; the composed load of the six domains through the coherence check (load only, the database nodes and the bastion) |
| 4 | the `bastion` 0.5.0 stack test (both new seed files, the cold-storage route refusing the upload endpoint and every other partner); the register tests (generated, a stale digest refused, a declared absence passed); the orders, send-outs, exchanges, reports, bookings, imaging, vault and portal fixtures with their purposes' checks |
| 5 | every fault's short test, present and fixed (cleared, for s6 and s9), on its fixture (17.3), one at a time, each under 30 minutes; the false alarm's check; the clinic scenario's format check, register, scenario document and `fit` declaration on armenelos plus the VPS (placement only, no deployment); its load-only fixture through the coherence and governance checks, unfaulted |

## Settled with the owner

Put to the owner with the plan on 2026-11-03 and answered as
recommended (spec D343, O223–O227 closed); the chunks named are written
on these answers.

| Question | Answer | Chunks it touches |
|---|---|---|
| **O223** `grafana` 0.3.0 for the seeded pgwatch dashboard, the existing scenarios re-pinned to it | yes (master spec 6.7) | 1 (version lines, re-pins), 10 (the dashboard) |
| **O224** The trim order if CPU is short | the exporters kept, pgwatch dropped, since s10 needs an exporter | G14; 27; release gate |
| **O225** pgCluu's report | written to the player's home and read with `scp`, as pgBadger's | 10 |
| **O226** The health node's host | the VPS | 10 (its docs), 27 (placement), G13 |
| **O227** Machine 10's telemetry | settled at the build's measurement, 10 or 11 machines reporting | 15 |

## Pending with the owner

**The security advisor's items awaiting the owner**
(`SECURITY_TODO.md`'s triage of 2026-11-01, and v0.4's known issues).
None is decided here and none is a gate; where one touches a chunk:

- **`.tech` ignore entries for the triaged false positives** (Debian
  backports of nginx, sudo, OpenSSH and python3.13 that NVD reads as
  open): the post-change checks G8 and G10, and the bastion's rebuild in
  chunk 17, will see the same NVD matches on the rebuilt images; until
  the owner rules, the advisor reports them as already triaged.
- **A patch-bump policy for security-only rebuilds**: touches every wave
  gate's rebuild of an unchanged brick (`prometheus`,
  `postgres-exporter`, `pgbouncer`); until the owner rules, rebuilt
  under their present versions, as v0.4's gate rebuilt `scheduler`.
- **python3.13 on armenelos** (the host's `gmctl`): touches no chunk's
  code. The `scheduler` and `api` images take Debian's current
  python3.13 at their build; CVE-2026-15308 (`html.parser`) stays the
  advisor's watch item, read again at G6 and G8 for the `api` image's
  packages.
- **c-ares in `.tech`** (`pgbouncer`'s): touches no chunk; v0.5 changes
  no `pgbouncer` and the clinic scenario has no pooler.
- **The `api` image's source** (G6, wave log): the project's first PyPI
  set and first lockfile, `bricks/api/requirements.txt`, taken as the
  advisor recommends, as G6 allowed. Touches chunk 5; should the owner
  want Debian packages only as a policy, that is a ruling, and chunk 5
  is reworked to G6's Debian route.

## Measurements and hand checks

- G3, G4: hand checks by the wave driver before wave 1. G12, then G13:
  at the release gate, under the VPS rule.
- G5 to G11: the security advisor's checks, recorded in the wave log;
  `.tech` updated on the wave branch.
- **Each new or bumped brick's footprint at rest**, in its chunk's stack
  test, as a first figure in its `docs/gm.md`: `postgres` 0.5.0 (chunk
  3), `scheduler` 0.3.0 (4), `api` 0.1.0, one hostname and nine (5, 11),
  `pgwatch` and `health-check` (10). The starting figures are master
  spec 14's.
- **Each domain's load**, time and size, at shift 0 and a non-zero
  shift: chunks 9, 12 to 16; the composed six at wave 3's gate.
- **The partners' `pg_hba.conf` form** on one Swarm network, whose task
  addresses change: chunk 11, recorded in the partners' seed, then in
  the `postgres` brick's `docs/gm.md` at wave 2's gate.
- **One partner's slow answers never holding another's** (the `api`
  node's workers): chunk 11.
- **Machine 10's telemetry**, 10 or 11 machines (O227): chunk 15.
- **CPU against the "one collector" trim**: `pgwatch`'s and the
  exporters' measured reservations (chunk 10) and `fit` on the clinic as
  built (chunk 27), then the per-node figures of G13's run; G14 applies
  only on a shortfall.
- **Each fixture's `fit` on one host** before its test, in its chunk.
- **G13's per-node CPU and memory** on both hosts: one-host and two-host
  smoke readings, quoted in the release notes as readings, not
  footprints; the aging's figures are v1.0 gating's.

## Left for the build (master spec 24)

Each item is settled by the chunk named, recorded in its **Record** line
and, where it is a brick's or a domain's, in that `docs/gm.md`; the
release gate checks that each is recorded.

| Item | Chunk |
|---|---|
| Every footprint, the new nodes' starting sizes, each domain's load time and size | 3, 4, 5, 10, 11 (bricks); 9, 12 to 16 (domains); 27 (the scenario's reservations) |
| The core's id functions in its GM notes (names, formulas), and the referring vets' mapping to practices | 9, first deliverable; the mapping 9, read by 12 |
| The repository form of an HTTP call, and the scripts' HTTP client | 4, the form fixed by capture W1 before chunks 2 and 4 start |
| Where a purpose's `history.sql` and endpoint material sit beside v0.4's per-part material folders | 18, fixed by capture W4 for 18 to 21 |
| `producers/partners/<name>/` or `producers/public/<name>/` for the owners' traffic | settled before the build: `producers/partners/owners/` (spec D369); built by 16, recorded with G16 |
| The `api` brick's internal layout (`db/` its one writable path, routes importing only from `db/`) | 5 |
| How the partners' `pg_hba.conf` admits only their own nodes on one Swarm network | 11 |
| The portal outbox's id order across the load and the derivation | 16 |
| The booking horizon against sessions planned three months ahead | 13 |
| The timeline moments of each fault within its fixture, each before its test's reading | 22 to 25 |
| A part's schema creating a contrib extension (`btree_gist`, `pgcrypto`), run as `postgres` by `load-data` | 8, used by 13 and 16 |
| Where cold storage's stub lives (a receiver with no stream of its own, used by a purpose and by the `postgres` brick's archiving) | 11, in the catalogue's `partners/coldstore/` (W2 item 6) |

## The partners, and where each stub is built

The shared nodes (`partners-api`, `partners-backend`, `partners-db`),
cold storage and the vault are chunk 11's. Each partner's stub is built
where its material lives (formats.md: a partner with streams of its own
in its domain's `producers/partners/`, a receiver with none in its
purpose's material), by the chunk building that domain or purpose, on
chunk 11's shared nodes:

| Partner (master spec 10.2) | Its stub | Built by |
|---|---|---|
| Northfield Veterinary Laboratories, the external reference lab | `vet-lab`'s `producers/partners/` | 12; exercised by 18 (purpose 3) |
| The region's practices, the lab's outside customers (one stub, 120 accounts) | `vet-lab`'s `producers/partners/` | 12; exercised by 18 (purpose 2) |
| The two other national centres, and the centres abroad as one | `vet-core`'s `producers/partners/` | 19 (purpose 4) |
| The authority (notifiable diseases, the antimicrobial-use report) | purposes 5 and 8, each its route under the authority's hostname | 19 (5), 20 (8) |
| The franchise's head office (monthly figures) | purpose 9 | 20 |
| The franchise's messaging service | purpose 16 | 21 |
| Cold storage, with the vault | the catalogue's `partners/coldstore/`, beside the shared nodes' base in `partners/shared/` (master spec 24, W2 item 6) | 11; exercised by 21 (purpose 14) and 23 (s2, s6) |
| `owners`, the tenth hostname, no business | `vet-portal`'s `producers/partners/owners/` (spec D369) | 16 |

## Chunks

### Chunk 1 — Versions, declarations and re-pins

Status: merged (w1, 1c76772)
Record: ec32633, merge 1c76772. Twelve `postgres` faults re-versioned, not eleven (the plan's count); `fixture-v04-refusals` keeps its own local bricks, not re-pinned (v03-refusals' precedent); the root `README.md`'s bricks row updated by the driver after `main`'s 117678b was merged into `v0.5-w1` (wave log).
Wave: 1
Depends on: G1; G3, G4 (the images at their new tags)
Architecture capture: recorded by the wave driver at wave 1's start
(W1), for chunks 2 to 5 and every later chunk:
- the version lines: `postgres` 0.5.0, `scheduler` 0.3.0, `bastion`
  0.5.0, `grafana` 0.3.0 (O223), their image tags; `api`, `pgwatch` and
  `health-check` start at 0.1.0 in their own chunks;
- the declarations this chunk writes: `postgres`' `options:` entry for
  `monitoring` (its name, the `monitoring_password` secret, the role
  created at initdb, its `docs/gm.md` section), `no-access` in the
  `write_policies` of `postgres` and `scheduler`, and the role `api` in
  `model.py`'s `ROLES` (spec D349; `pgwatch` and `health-check` take
  `monitoring`);
- the template keys of master spec 6 and formats.md v28 that chunks 2
  to 5 build against (master spec 6.8's shapes), and **the HTTP call's
  repository form** (a connection `driver: http`, `target`, the
  credential secret; a key with a method, a path and a body from
  parameters or a builder), which chunk 4 implements and chunk 2's
  templates carry.

- Goal: every bumped brick at its v0.5 version, every pin, `applies_to`
  and "Supported faults" list brought to it in one commit, the
  declarations in place, the suite green.
- Scope: in:
  - `postgres`, `scheduler`, `bastion` and `grafana`: `brick.yaml`'s
    version and image lines, the Dockerfiles' build comments,
    `docs/gm.md`'s version lines and image tags, the stack tests' tags,
    the scheduler unit runner's image tag;
  - every fault whose `applies_to` names one of them given the new
    version (the twelve applying to `postgres`, those applying to
    `scheduler` and `grafana`), the fixtures' own faults likewise, and
    each brick's "Supported faults" kept equal to them;
  - the four existing scenarios and the seven fixtures pinning
    `postgres` re-pinned to every bumped brick they use; **each node an
    exporter targets given `options: [monitoring]`** (17.5); their
    READMEs regenerated;
  - **`GM_OPTIONS: monitoring`** on the `postgres` container of each
    hand-written stack file serving an exporter (`postgres-exporter`'s
    and `prometheus`' stack tests, `calibrate-f10/stack.yml`), ignored
    until chunk 3 reads it (spec D346);
  - the smoke scripts, the other bricks' stack tests and the unit tests
    naming the old tags (`smoke.sh`, `smoke-scenario.sh`,
    `smoke-load.sh`, `smoke-monitoring.sh`, `calibrate-f10.sh` and its
    `stack.yml`, `test_deploy.py`, `test_fit.py`, `test_model.py`'s
    version tuples);
  - the declarations of capture W1;
  - the root `README.md`'s tables.
  - Out: any behaviour of the bumped bricks (chunks 3, 4, 10, 17);
    `pg-abandoned-replication-slot`'s widened precondition (chunk 3);
    the option's checks (chunk 6).
- Files: `bricks/{postgres,scheduler,bastion,grafana}/brick.yaml`,
  `Dockerfile` (build comments), `docs/gm.md` (version lines, tags,
  "Supported faults"), `tests/{run-stack-test.sh,stack.test.yml}`;
  `bricks/{pgbouncer,postgres-exporter,prometheus}/tests/{run-stack-test.sh,stack.test.yml}`
  (tags; `GM_OPTIONS` in `postgres-exporter`'s and `prometheus`'
  `stack.test.yml`); `bricks/scheduler/tests/run-unit-tests.sh` (tag);
  `faults/*/fault.yaml` as the build lists them;
  `scenarios/{bookshop-new-server,fernway-clinics-monitoring,tarnbeck-outdoor-campaign,tarnbeck-outdoor-shop}/{scenario.yaml,README.md}`;
  `tools/tests/fixtures/fixture-{audit,campaign,instances,load,monitoring,v03-refusals,v04-refusals}/`
  (pins, faults, READMEs); `tools/tests/{smoke.sh,smoke-scenario.sh,smoke-load.sh,smoke-monitoring.sh,calibrate-f10.sh}`,
  `tools/tests/fixtures/calibrate-f10/stack.yml` (tags, `GM_OPTIONS`),
  `tools/tests/{test_deploy.py,test_fit.py,test_model.py}`;
  `tools/gm/model.py` (`ROLES` only: `api`); `README.md`.
- Spec sections: master spec 5, 6.5, 6.7, 7.1 (options, item 1), 7.5,
  17.5, 21; spec D339.
- Done when: the loader, otherwise unchanged, loads every brick at its
  version, every fault, the four scenarios and the fixtures; the unit
  suite, `test_brick_docs` included, passes; the images build at their
  new tags and their stack tests pass; every README matches a fresh
  regeneration.
- Verification: chunk checks.
- Split rule: none; mechanical, one commit by the model's rule above.

### Chunk 2 — The domain format: skill, templates, checks, `gmctl compose`, variants

Status: merged (w1, c9ab20c)
Record: 2a edf1dd5, 2b 2dc4267, merge c9ab20c. Done when's shop scenario read as `tarnbeck-outdoor-campaign` (the one with `domain: shop` and a classification copy); outside the Files list `tools/tests/test_aging.py`'s verb list, `domains/shop/docs/gm.md`, `fixture-v04-refusals`' own shop domain; `scenario.yaml` gains `purposes[].parts.api` and `parts.partner` (wave log, W1-w).
Wave: 1
Depends on: chunk 1, merged into `v0.5-w1` before this chunk's branch is
cut; G2 (done); W1
Architecture capture: W1 (chunk 1's), plus, for chunks 6, 8, 9 and
every domain chunk:
- the domain keys and folders as formats.md v28 lays them out
  (`requires`, `lands_with`, `databases`, `derive`, `register`,
  `policy` and its `governance` fragment; `producers/<node>/` (spec
  D344), `producers/api/<node>/` with its `api.yaml` fragment (spec
  D345), `producers/partners/<partner>/`, `variants/<variant>.yaml` and
  `variants/<variant>/producers/`), the tag vocabulary, the
  classification key without the database;
- `gmctl compose`'s interface: its arguments, the layers and their
  precedence, its report, the conflict it stops on, `merge.yaml`'s form;
  `composition.yaml`'s fields and what the loader checks against
  `domains:`.

- Goal: the domain format of master spec 6.1 and 8 in the
  `scenario-format` skill, its templates and the loader, `gmctl compose`
  and the composition record, the variants, the shop brought to it:
  master spec 21's domain-format chunk, before any domain's.
- Scope: in:
  - **2a, the skill, the templates, `check_domain_dir`, the variants and
    the shop**: the templates `scenario.yaml` (`domains:`,
    `third_parties:`, `options:`, `standby_of` with the primary's
    replication line in its seed `pg_hba.conf` (W1 item 6),
    `governance.register`),
    `answer-key.yaml` (`register_diff:`, a cascade's backlog, the
    report-only resolution), `fault.yaml` (an option required or its
    absence planted, a register fault, a partner's misbehaviour key),
    `brick.yaml` (`options:`, `no-access`, the `api` brick's seed files;
    the roles' comment with `api`, spec D349), `brick-gm.md` (an
    option's section), `purpose.yaml` (the round trip, the `api` and
    `partner` parts, HTTP connections, endpoint material,
    periodic purposes and `history.sql`, `judged:`, `classification:`,
    the `ops` schema), `domain.yaml`, `classification.yaml`,
    `queries.yaml`, `schedule.yaml` and `jobs.yaml` (the HTTP call's
    form of W1, the weighted `choice`), `layouts.md`; new templates
    `register.yaml`, `variant.yaml`, `composition.yaml`, `merge.yaml`,
    and `api.yaml`, the `api` node's file (W1 item 5, spec D345);
    the skill's completeness rules (the domain checklist, every table in
    one activity, the variant and its tags, composition, third parties
    and `partners.md`, options, the register's items, the scenario's two
    register files); `check_domain_dir` and `_check_fragments` for the
    new keys and folders, the producer folders per node
    (`producers/<node>/`, `api`, `partners` and `public` reserved; spec
    D344) and an `api.yaml` fragment's keys, the classification key without the
    database in a domain (a scenario's copy keeps it); the shop rekeyed
    mechanically, its fragments moved to `producers/producer/`, its
    register fragment and its one variant, its present setup (8.6);
  - **2b, `gmctl compose` and the composition record**: the verb,
    merging each scheduler node's fragments, and each `api` node's
    `api.yaml`, `routes/` and `db/` (a partner's onto the shared nodes),
    by layer (the domain's default profile, the variant's overrides, the
    scenario), writing ordinary files into the scenario folder, its
    report recording every override, stopping on a conflict between two
    profiles until `merge.yaml` resolves it (8.4, 15); duplicate keys refused in the
    merge's inputs; `composition.yaml` checked against `domains:` (a
    part only with its core, `lands_with`, `at:` forms, a derivation
    only when sanctioned, the order).
  - Out: the loader's checks on scenarios, bricks and purposes beyond
    domains and composition (chunk 6); the coherence check (chunk 8);
    the `scenario-document` and `game-master` skills (chunks 17, 26);
    the clinic's domains.
- Files: `.claude/skills/scenario-format/SKILL.md`,
  `.claude/skills/scenario-format/templates/{answer-key.yaml,brick-gm.md,brick.yaml,classification.yaml,domain.yaml,fault.yaml,jobs.yaml,layouts.md,purpose.yaml,queries.yaml,scenario.yaml,schedule.yaml}`,
  `.claude/skills/scenario-format/templates/{register.yaml,variant.yaml,composition.yaml,merge.yaml,api.yaml}`
  (new); `tools/gm/model.py` (`check_domain_dir`, `_check_fragments`,
  `check_classification`, the composition check, the duplicate-key
  loader); `tools/gm/compose.py` (new), `tools/gm/__init__.py`,
  `.claude/skills/game-master/gmctl.md` (the verb's line);
  `domains/shop/{domain.yaml,data/classification.yaml,data/register.yaml,variants/}`,
  `domains/shop/producers/` (moved to `producers/producer/`), and the
  path in the provenance comments of
  `tools/tests/fixtures/fixture-campaign/nodes/producer/{queries,schedule,jobs}.yaml`;
  `tools/tests/{test_model.py,test_compose.py}` (`test_compose.py` new),
  `tools/tests/fixtures/fixture-compose/` (new).
- Spec sections: master spec 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.8, 8.2 to
  8.6, 15; [formats.md](../../formats.md) "Domain", "Scenario",
  "Purpose definition"; [domain-procedure.md](domain-procedure.md)
  section 3 (the checklist) and 10.
- Done when: every template carries every item master spec 6 and
  formats.md v28 require, and loads as YAML; `check_domain_dir` passes
  the rekeyed shop and refuses, each with its message, a part without
  its core, a classification keyed with its database, a table in no
  activity, a variant tag outside the vocabulary, a fragment at
  `producers/`' root; `gmctl compose` merges two layers, records an
  override, stops on a conflict and follows `merge.yaml`, and merges an
  `api` node's `api.yaml` and endpoint files, each in a unit test; a
  duplicate key in a fragment is refused; `tarnbeck-outdoor-campaign`
  still loads with its own classification copy and `domain: shop`.
- Verification: chunk checks.
- Split rule: 2a the skill, the templates, `check_domain_dir`, the
  variants and the shop; 2b `gmctl compose`, `merge.yaml`, the
  composition record and the duplicate-key refusal. Each half leaves the
  suite green.

### Chunk 3 — `postgres` 0.5.0

Status: merged (w1, 0e152ac)
Record: 3a c0525d9, 3b bb0c43e, merge 0e152ac. pgaudit 18.0 redacts passwords itself (G5's premise; the guards kept); a restart from the hand-over snapshot cannot bring a standby back (a known limit in `docs/gm.md`, sent to `spec-writer`); outside the Files list `tools/gm/state.py` and three tests' secret lists (wave log, W1-x).
Wave: 1
Depends on: chunk 1 merged; G5; G3, G4
Architecture capture: W1, plus, for chunks 7, 8, 10, 11, 20, 23, 24:
- the standby's interface: the node key `standby_of`, the brick
  parameters and the replication secret's name, the slot's name, the
  clone step's place in `load-data` (after the data load, before the
  aging) and its command;
- the archiving interface: the posting command the `archive_command` and
  the nightly base backup call, its arguments, what it sends cold
  storage (`POST /shipments` with types `wal` and `basebackup`, master
  spec 10.4) and how it fails honestly on a refusal;
- the TLS certificate and key as per-game secrets, their names and
  paths.

- Goal: `postgres` 0.5.0 as master spec 7.1 states it, with its tool
  side, its documentation and its footprint at rest.
- Scope: in:
  - **3a, TLS, pgaudit, the option, `no-access`**: the image carrying
    what TLS needs and pgaudit's package, with G5's conditions (wave
    log: pgaudit pinned exactly and asserted, the `libssl3t64` floor
    asserted; its advised hardening, the snakeoil key deleted, taken;
    no password set while statement logging could write it; pgaudit
    18.0 redacts role passwords itself, its sessions' `pgaudit.log =
    'none'` kept as a guard, spec D357);
    the seed turning each on
    (`ssl = on`, `hostssl` lines; `shared_preload_libraries` and
    pgaudit's classes), neither an option; the `monitoring` role and its
    secret created at initdb only when the node chooses the option;
    `no-access` made real (no `player` account, no `sudo` wrappers; the
    entrypoint's steps 6 and 8 and the sudoers file); the TLS
    certificates generated per game as secrets (`localimpl.py`,
    `deploy.generate_credentials`); **the `api` nodes' connection
    roles**: `localimpl.connection_roles` and `inject.password_plan`
    read an `api` node's `api.yaml` connections beside a scheduler
    node's `schedule.yaml`, and skip a `driver: http` connection in both
    (spec D345); `docs/gm.md`'s TLS, pgaudit and option sections,
    `docs/player.md` mentioning the role only when the option is on;
  - **3b, the standby, archiving and base backups**: the standby mode (a
    readable asynchronous replica: the slot named for the standby, the
    replication role whose password is a secret, `hot_standby` and
    `hot_standby_feedback` on); the clone step in `load-data`
    (`pg_basebackup` from the primary after the load, then streaming),
    the standby's parameter and secret rendered; the hand-over
    snapshot's temporary slot still removed; `archive_mode`,
    `archive_command` through the brick's posting command `vault-post`,
    in Perl with core `HTTP::Tiny`, no package added (G5; the build
    asserting `perl -MHTTP::Tiny -e 1`), `archive_timeout = 1h`; the
    nightly `pg_basebackup` job in the cron daemon, posted whole; `pg-abandoned-replication-slot`'s precondition
    widened to "an orphan slot beside the standby's" (6.4);
    `docs/gm.md`'s standby, archiving and base-backup sections.
  - Out: several databases created for a part, `CONNECT` revoked from
    `PUBLIC`, and contrib extensions (chunk 8, in `load-data`); pgCluu
    (chunk 10); cold storage's stub (chunk 11; this chunk's stack test
    posts to a stand-in); the loader's checks on `options:` and
    `standby_of` (chunk 6).
- Files: `bricks/postgres/{Dockerfile,brick.yaml,docs/gm.md,docs/player.md}`,
  `bricks/postgres/rootfs/usr/local/sbin/gm-entrypoint`,
  `bricks/postgres/rootfs/etc/sudoers.d/gm-player`,
  `bricks/postgres/rootfs/usr/local/bin/vault-post` and
  `bricks/postgres/rootfs/usr/local/lib/gm/clone-standby` (new), the
  base-backup job's line (W1 item 6),
  `bricks/postgres/tests/{run-stack-test.sh,stack.test.yml,fixtures/}`;
  `tools/gm/{inject.py,render.py,localimpl.py,deploy.py}`,
  `tools/tests/{test_inject.py,test_render.py,test_deploy.py}`;
  `faults/pg-abandoned-replication-slot/`.
- Spec sections: master spec 7.1, 10.2 (`no-access`), 11.1, 11.2, 15
  (the standby's clone, `render`'s TLS secrets), 6.4; access model 5
  (the standby, `no-access`).
- Done when: the stack test shows TLS on with the seed's certificate and
  pgaudit writing its classes; `monitoring` present only with the
  option; a `no-access` node with no `player` account and no wrapper; a
  standby cloned and streaming, answering read-only queries, its slot
  in `pg_stat_replication` on the primary; a switched segment posted by
  `archive_command` to a stand-in, a refusal failing honestly; the
  base-backup job posting once when moved to the next minute; the
  image build asserting G5's conditions; the brick's footprint at rest
  recorded; unit tests show an `api` node's `api.yaml` connection roles
  given their secrets and passwords, and an `http` connection giving
  none; the unit suite passes.
- Verification: chunk checks; the stack test is this chunk's point,
  each run under 30 minutes.
- Split rule: 3a TLS, pgaudit, the option, `no-access`, the TLS
  secrets and the `api` nodes' roles; 3b the standby, its clone step,
  archiving, the base backup and the fault's precondition.

### Chunk 4 — `scheduler` 0.3.0: the HTTP driver

Status: merged (w1, 99d5398)
Record: 4a 3316e42, 4b 48a2224, merge 99d5398. `no-access` through account files linked into `/run/gm-accounts` (the read-only root filesystem); outside the Files list `repository.py`, `runner.py`, `__main__.py`, the s6 `run` script (wave log, W1-y).
Wave: 1
Depends on: chunk 1 merged; G7 (only if a package is added); G3, G4
Architecture capture: W1's HTTP call form; for chunks 7, 11, 12 and
every chunk with HTTP flows: the scripts' HTTP client (`get`, `post`),
its timeout, how a call's status and latency are logged and counted.

- Goal: the scheduler's HTTP driver, HTTP connections in script jobs,
  the weighted `choice` and `no-access` made real, as master spec 7.2
  states them.
- Scope: in: the driver `http` (a connection `driver: http`, `target:
  <node>:<port>`, the caller's credential a secret, read from its
  mounted `http_<credential>` (W1 items 0 and 4); one request per
  call, a method, a path, a JSON body from the parameters or a builder;
  its status and latency recorded as a statement's; a non-2xx answer or
  a timeout an error; `pool` meaning kept-alive connections); streams
  holding an HTTP connection; a script job's `connections:` naming an
  HTTP connection, the script given the small client beside its psycopg
  connections, each call logged; the weighted `{choice: {a: 45, ...}}`
  beside the uniform list; `no-access` (no `player` account, no
  wrappers); `replicator` in the program's `FORBIDDEN_ROLES` (spec
  D350); a bounded wait for the target's name at start; the brick's
  `docs/gm.md` and `docs/player.md`. The client in the standard library
  unless G7 clears a package.
  - Out: the loader's checks on HTTP connections and the weighted
    `choice` (chunk 6); the HTTP credentials' generation and mounts in
    render (chunk 7).
- Files: `bricks/scheduler/program/gm_scheduler/{drivers/__init__.py,drivers/http.py,scripts.py,jobs.py,generators.py,streams.py,schedule.py}`
  (`drivers/http.py` new), `bricks/scheduler/{Dockerfile,brick.yaml,docs/gm.md,docs/player.md}`,
  `bricks/scheduler/rootfs/` (the entrypoint's `no-access` path),
  `bricks/scheduler/tests/unit/{test_parts.py,test_program.py}`,
  `bricks/scheduler/tests/{run-stack-test.sh,stack.test.yml,fixtures/}`.
- Spec sections: master spec 7.2 ("The scheduler's HTTP driver",
  "Gates and versions"), 10.2, 24 (the call's form, the client).
- Done when: unit tests show a call's method, path and body built from
  parameters and from a builder, a non-2xx answer and a timeout counted
  as errors, a weighted draw within tolerance over a seeded run; the
  stack test drives a stub HTTP server from a stream and from a script
  job, started before the stub and waiting for it; a `no-access` node
  has no `player` account; the footprint at rest recorded.
- Verification: chunk checks; the scheduler's unit tests.
- Split rule: 4a the driver, streams and the weighted `choice`; 4b
  script jobs' HTTP client and `no-access`.

### Chunk 5 — `api` 0.1.0

Status: merged (w1, c888d18)
Record: 5a 1f744d1, 5b a259052, merge c888d18. Debian `python3-yaml` added beyond G6's set after a `security-advisor` preflight (G11.1); `no-access` as chunk 3's; a fresh `postgres` node resolves only once healthy, beyond the 30 s bound (wave log, W1-z).
Wave: 1
Depends on: chunk 1 merged; G6; G3, G4
Architecture capture: W1; for chunks 9, 11, 12, 15, 16 and every
endpoint: the endpoint layout (`routes/<name>.py`, `db/<name>.py`, a
route importing only from `db/`), how hostnames are dispatched on one
node, the reload wrapper, how an endpoint gets its application role's
credential, the transaction-local setting per request.

- Goal: the new `api` brick: FastAPI on uvicorn serving the endpoint
  files the GM drops in, answering only, as master spec 7.2 states it.
- Scope: in: the image from G6's hash-pinned PyPI set,
  `bricks/api/requirements.txt`, under G6's conditions (wave log: plain
  `uvicorn` and `psycopg`, installed with `--require-hashes` in a
  throwaway build stage, no pip in the final image, the build
  assertions); the brick's seed files, `api.yaml` (W1 item 5, spec
  D345), the endpoint files as configs and its application roles'
  secrets (6.5);
  dispatch by hostname, so one node serves several partners under
  network aliases; the write policy per directory, `db/` the one
  writable path, a reload wrapper; `no-access`; endpoints connecting
  with application roles, never superusers; `SECURITY DEFINER` calls and
  a transaction-local setting per request allowed on the `db/` side; a
  bounded wait for its database's name; the node-health script; the
  brick's build checks on the `db/` side; `docs/gm.md`, `docs/player.md`;
  its footprint at rest, one hostname and nine.
  - Out: any domain's or partner's endpoints (chunks 9, 11, 12, 15, 16);
    the network aliases in render (chunk 7).
- Files: `bricks/api/` (new): `brick.yaml`, `Dockerfile`,
  `requirements.txt` (G6's set, as the advisor gave it), `rootfs/`
  (entrypoint, s6 services, the reload wrapper, sudoers),
  `docs/{gm.md,player.md}`, `tests/{run-unit-tests.sh,run-stack-test.sh,stack.test.yml,unit/,fixtures/}`;
  the root `README.md`'s brick table.
- Spec sections: master spec 6.5, 7.2 ("The `api` brick"), 10.2, 24
  (its layout); access model 4, 5 (the `api` nodes).
- Done when: the stack test serves a sample endpoint pair under two
  hostnames, each answering only its own routes, a request without the
  endpoint's credential answered 401; `player` may edit
  `db/` and reload, and may not edit `routes/`; a `no-access` node has
  no `player` account; the endpoint connects as its application role;
  started before its database, it waits and then answers; the image
  build asserting G6's pins and no pip; the brick's unit tests pass;
  the footprint at rest recorded.
- Verification: chunk checks.
- Split rule: 5a the image, the endpoint layout, the reload and the
  write policy; 5b hostnames, `no-access` and the build checks.

### Chunk 6 — Loader checks for v0.5

Status: merged (w2, f3eb50d)
Record: 6a dde1a14, 6b 2052e6f, merge f3eb50d. Outside the Files list `tools/tests/test_render.py` (chunk 3's standby test made valid); the split not exact (skill lines in 6b, four purpose constants in 6a) (wave log, W2-a).
Wave: 2
Depends on: chunks 1, 2 and 5 (wave 1; 5 for the `api` brick its
fixtures name)
Architecture capture: none of its own; it implements W1, chunk 2's
W1-w and W2 item 1, its outcomes recorded as W2-a.

- Goal: the loader refuses what master spec 6, 10.2 and 15 say it
  refuses, with what is missing or wrong.
- Scope: in:
  - **6a, scenarios, bricks and faults**: `options:` against the
    brick's declaration; a monitoring node (the exporter, `pgwatch`,
    `health-check`) targeting a `postgres` node without `monitoring`
    refused unless a fault instance plants the gap (7.1 item 3);
    `no-access` accepted only on a brick declaring it; `standby_of`
    naming a `postgres` node; `third_parties:` (each node exists with
    `write_policy: no-access`; no third-party node and no alias in the
    bastion's `web_routes`, cold storage's exception being chunk 17's
    (spec D363); none among the starter pack's nodes;
    no fault instance's expected fix naming one; a third-party
    `postgres` node's seed `pg_hba.conf` admitting no role but the
    partners' own on their database); HTTP connections in a schedule
    (`driver: http`, the target a node, a `third_parties:` hostname or
    `owners` (an alias on the partners' node, W1-w's template), the credential a
    secret, named
    `[a-z][a-z0-9_]{0,62}` and never `public`, `timeout` 1–60 s, no
    `role`; a job's one `connection:` never an HTTP connection nor a
    call key: the program's own refusals, W1-y) and the weighted
    `choice`; an `api` node's `api.yaml` (each endpoint's two files,
    its hosts, its credentials, its connections, a connection's role
    reserved as a schedule's; W1 item 5, spec D345; the keys a
    fragment may hold are chunk 2's check, reused, W1-w; on the
    partners' node the hosts and the `third_parties:` hostnames agree,
    with `owners`); `postgres`' `vault_target` and `vault_credential`
    checked as an HTTP connection's target and credential are (W1-x);
    a fault requiring an option; an answer key's `register_diff:`
    (6.3, 6.8), its key `true` read as PyYAML gives it, boolean `True`,
    or quoted `"true"`, never both in one item, through one model
    accessor its later readers share (spec D353); `options` and
    `standby_of` in `RESERVED_PARAMETERS`, `replicator` in
    `RESERVED_DB_ROLES`, a primary with a standby carrying the
    replication line in its seed `pg_hba.conf` (W1 items 0 and 6, spec
    D350); `model.node_creates`, what a `postgres` node's data file and
    the domains placed on it create, read by the location, crontab-role
    and governance checks and by chunks 7 and 8 (W2 item 1, spec D360);
  - **6b, purposes and domains**: the purpose format's extensions (6.6:
    `kind: round-trip` and `round_trips:`, the `api` and `partner`
    parts, HTTP connections in jobs, each mapped in the purpose's
    `connections:` to the credential its job's connection names, or
    `public` when that connection has none (spec D354), endpoint
    material, a periodic job
    naming its feeder and `material/history.sql`, `judged:` with one
    `end-to-end` invariant per round trip, the purpose's
    `classification:`, the `ops` schema); a receiver a declared third
    party; the `SECURITY DEFINER` check at a domain's build (15); a
    partner folder's one `data.sql` beside its fragments (W2 item 1,
    spec D360);
  - the scenario-format skill's checklist for these checks;
  - refusal fixtures and unit tests for each.
  - Out: the data register's digests and coverage (chunk 17); rendering
    (chunk 7); `load-data` (chunk 8); `domains:` entries and the
    composition record, already `check_domains_entries` and
    `check_composition` (chunk 2, W1-w), not re-added; cold storage's
    `web_routes` exception (chunk 17).
- Files: `tools/gm/model.py`, `tools/tests/test_model.py`,
  `tools/tests/fixtures/fixture-v05-refusals/` (new);
  `.claude/skills/scenario-format/` (before chunk 8, spec D362).
- Spec sections: master spec 6.2 to 6.6, 7.1, 7.2, 10.2, 12.1, 15.
- Done when: unit tests show each refusal with its message and the
  acceptance of a valid fixture; a location in a database a composed
  domain creates is accepted through `model.node_creates`; the four
  existing scenarios, the fixtures and every catalogue definition still
  load; the unit suite passes.
- Verification: chunk checks.
- Split rule: 6a scenario, brick and fault checks; 6b purpose and domain
  checks.

### Chunk 7 — Render for v0.5: aliases and HTTP credentials

Status: merged (w2, a7b76ff)
Record: built 430c1a6, merge of v0.5-w2 9c9155a, 2411424, merge a7b76ff. Outside the Files list `tools/tests/test_inject.py` (mocks); two tests' vault target moved to `bastion:8000` (wave log, W2-b).
Wave: 2
Depends on: chunks 3, 4 and 5 (wave 1); chunk 6, merge order: merged
into `v0.5-w2` before this chunk merges, its `model.node_creates` taken
in first (spec D360)
Architecture capture: W2, for chunk 11 and every chunk deploying a
partner or an HTTP caller: how a `third_parties:` hostname becomes a
network alias on the partners' `api` node; which nodes mount which
`http_<credential>` secret. The secret's name and path, and where the
caller and the endpoint read it, are W1's (items 0, 3 to 6; spec D347).

- Goal: `render` gives the partners' `api` node its network aliases and
  every HTTP connection its credential, as master spec 15 states.
- Scope: in: per-service network aliases on the one network (none exist
  today), one per hostname of `third_parties:` and for `owners`; the
  HTTP credentials generated per game, one `http_<credential>` each, and
  mounted on each scheduler node whose connections name it, on each
  `api` node whose `api.yaml` accepts or uses it, and on each `postgres`
  node whose `vault_credential` names it (spec D347); the login roles a
  composed domain creates given their passwords, `data_login_roles`
  reading `model.node_creates` (W2 items 1 and 2, spec D360); unit
  tests.
  - Out: the bastion's route to cold storage (chunk 17); the partners'
    nodes themselves (chunk 11); handing documented credentials over
    (chunk 17).
- Files: `tools/gm/{render.py,localimpl.py,deploy.py}`,
  `tools/tests/{test_render.py,test_deploy.py}`, and the secret lists
  `test_fit.py`, `test_state.py` and `test_teardown.py` expect, where
  the new secrets change them (chunk 3's precedent, W1-x);
  `tools/tests/fixtures/fixture-alias/` (new: the two-node fixture, its
  `api` node declared under `third_parties:`; spec D362).
- Spec sections: master spec 10.2, 15 ("`render`").
- Done when: unit tests show a rendered stack giving the partners' node
  each alias and each HTTP caller, `api` node and archiving `postgres`
  node its secret; a two-node fixture shows a
  call by alias answered, the caller started before the `api` node,
  waiting, bounded, and calling once the alias resolves (an alias
  enters DNS only once its task is healthy; workflow deltas, spec
  D356).
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 8 — `load-data` for v0.5 and the coherence check

Status: merged (w2, 4b22401)
Record: built fab4f5f, merges of v0.5-w2 7da2e45 and 6432c6d, 61b1b90, 1a7f1ab, merge 4b22401. Two code commits on top, not one (chunk 7 merged mid-way); the password step sets the domains' and partner's login roles (wave log, W2-c).
Wave: 2
Depends on: chunks 2 and 3 (wave 1); chunk 6, merge order: merged into
`v0.5-w2` before this chunk merges, its `model.node_creates` and its
scenario-format skill lines taken in first (spec D360, D362)
Architecture capture: W2, for the domain chunks 9 and 12 to 16 and the
purpose chunks: **where a part's coherence queries live and their
contract** (a part's references to its core, and the histories that
must agree, 8.5), the derivation step's and `history.sql`'s run (the
temporary foreign server, the sessions unseen), the load order from
`composition.yaml`.

- Goal: `load-data` loads composed domains in order, runs a sanctioned
  derivation and the purposes' planted history, then the post-load
  coherence check, as master spec 8.5 and 15 state.
- Scope: in: a part's load after its core's, in the same database or
  another; several databases created for a part, `CONNECT` revoked from
  `PUBLIC`; a part's schema creating a contrib extension (`btree_gist`,
  `pgcrypto`), run as `postgres`; a sanctioned `derive.sql` and every
  purpose's `history.sql` run after the loads they read, through a
  temporary foreign server dropped afterwards, statement logging,
  `pg_stat_statements` and pgaudit off for their sessions (pgaudit
  through chunk 3's `inject.NO_AUDIT_SQL`, W1-x); the coherence
  check once on the loaded system before any fault is planted, its
  failure stopping the setup as a design error; the result written to
  the composition record's `coherence:`; unit tests and a composed test
  load. Every new load step skips the standbys as chunk 3's
  `standby_plan` does (W1-x). **A partner's state** (W2 items 1 and 3,
  spec D360): each composed domain's partner `data.sql` run into the
  partners' database after that domain's load; a core's `data/keys.sql`
  streamed ahead of every part's load, each partner file and
  `derive.sql`, in the same session; `load_epoch` passed to every file
  it runs; `password_plan` reading `model.node_creates`. The
  scenario-format skill's lines and templates for `data/keys.sql`,
  `data/coherence.yaml`, a partner's `data.sql` and the database
  convention (after chunk 6's).
  - Out: the domains' own coherence queries (each domain chunk); the
    standby's clone (chunk 3, after the loads, where it stays).
- Files: `tools/gm/inject.py`, `tools/gm/coherence.py` (new),
  `tools/tests/{test_inject.py,test_coherence.py}` (`test_coherence.py`
  new), `tools/tests/fixtures/fixture-composed/` (new: a two-part test
  composition with a derivation, a core's `data/keys.sql` and a partner
  folder's `data.sql`); `.claude/skills/scenario-format/` (after chunk
  6, spec D362).
- Spec sections: master spec 8.5, 15 ("`load-data`"), 24 (contrib
  extensions); formats.md "Composing domains".
- Done when: on a composed test load, the order follows
  `composition.yaml`, a second database has `CONNECT` revoked from
  `PUBLIC`, a derivation runs unseen (nothing in the log,
  `pg_stat_statements` or pgaudit's trail) and its foreign server is
  gone; the partner's `data.sql` has created its role, schema and
  planted state in `partners` after its domain's load; the core's key
  functions served every part's load and the partner file and are
  absent from the catalog after; the coherence check passes, and fails
  with the offending ids on a broken range; the unit suite passes.
- Verification: chunk checks.
- Split rule: 8a the load order, several databases, contrib extensions,
  `data/keys.sql`, `load_epoch`, a partner's state, derivation and
  history; 8b the coherence check and its record.

### Chunk 9 — `vet-core`, the medical record

Status: blocked (on spec-writer: the core's code catalogues, its further key functions, three spec conflicts; WIP 0a3e43b)
Wave: 2
Depends on: chunks 1, 2, 3 and 5 (wave 1); chunk 6, merged into
`v0.5-w2` before this chunk's branch is cut (its fragments' weighted
`choice`; spec D348); chunks 7 and 8, merged into this branch before
its fixture runs (`clinic_lookup`'s mount, the composed load; spec
D362)
Architecture capture: W2, for every part and purpose: **the core's key
ranges and id functions, names and formulas**, written into its GM notes
as this chunk's first deliverable (master spec 21), with the referring
vets' mapping to practices; the clinic-api endpoints' contract (9.2).

- Goal: `domains/vet-core/` as [vet-core-domain.md](vet-core-domain.md)
  and master spec 9.2 state it, passing the domain checklist.
- Scope: in: its GM notes first ("Core keys used" for every part: the
  ranges, the functions, the staff layout, growth an hour, its traps);
  `data/schema.sql`, `load.sql` (the regional-franchise history, at a
  shift), `classification.yaml`, `register.yaml`, `docs/policy.md` and
  `data/governance.yaml` (its eleven rules); its producer fragments for
  `pms` in `producers/pms/` (no HTTP connection: the portal's desk
  stream is `vet-portal`'s) and its builders; `clinic-api`'s lookup
  endpoints with their `api.yaml` fragment (`producers/api/clinic-api/`:
  animals by id and natural identifier, the current owner,
  `GET /stays?current=true`); its variant manifest;
  its purposes' ids; `data/keys.sql`, the core's key functions as its
  GM notes give them (W2 items 3 and 4). A fixture of `records` and
  `clinic-api` with the bastion, for the lookup API, deployed through
  chunk 8's `load-data`; `clinic-api`'s `api.yaml` names `clinic_lookup`
  (W2 item 4), which only chunk 7 mounts, and a credential named but not
  mounted stops the server (W1-z).
  - Out: purpose 4's exchange endpoints and the centres' stubs (chunk
    19); the parts' fragments on `pms` (their chunks).
- Files: `domains/vet-core/` (new): `domain.yaml`,
  `data/{schema.sql,load.sql,keys.sql,classification.yaml,register.yaml,governance.yaml}`,
  `producers/pms/{queries.yaml,schedule.yaml,jobs.yaml,builders/}`,
  `producers/api/clinic-api/{api.yaml,routes/,db/}`,
  `variants/regional-franchise.yaml`, `docs/{gm.md,policy.md}`;
  `tools/tests/fixtures/fixture-core/` (new); the root `README.md`'s
  domain table.
- Spec sections: master spec 9.1, 9.2, 13.1; vet-core-domain.md whole.
- Done when: `check_domain_dir` passes; the load runs at shift 0 and a
  non-zero shift, its time and size recorded; every column classed and
  every table in one register activity; the fragments parse, each
  statement running as its role; on the fixture, the lookup endpoints
  answer for loaded animals and never return a contact; the GM notes
  carry every function and range the parts' documents name, and
  `data/keys.sql` defines each function as they give it.
- Verification: chunk checks.
- Split rule: 9a the GM notes' ranges and functions with
  `data/keys.sql`, the schema, the load, classification, register and
  policy; 9b the producer fragments,
  `clinic-api`'s endpoints, the variant and the fixture.

### Chunk 10 — The monitoring breadth: `pgwatch`, `health-check`, `grafana` 0.3.0, pgCluu

Status: planned
Wave: 2
Depends on: chunk 3 (wave 1); G9; chunk 6, merge order only
Architecture capture: W2, for chunk 27: the `pgwatch` sources file and
Prometheus' target for its sink; the `health` node's crontab, its status
page and its `web_routes` entry.

- Goal: master spec 7.4's three pieces, each reading what `postgres`
  already provides through the `monitoring` role.
- Scope: in:
  - **10a, `pgwatch` 0.1.0 and `grafana` 0.3.0**: pgwatch, its latest
    release at the build (6.1.0, cleared by G9; checksum-pinned), one
    collector, its sources a seeded file, no configuration database,
    its web interface off, a metric set needing no helper function, its Prometheus sink scraped by v0.2's
    Prometheus (a seed target); `grafana` 0.3.0's seeded pgwatch
    dashboard (O223); its footprint at rest;
  - **10b, `health-check` 0.1.0 and pgCluu**: `check_postgres`
    (Debian) every five minutes as `monitoring` against each instance
    in scope (the exact set the build's, within `pg_monitor`), the
    status page rewritten each run and served, routed as `health`; the
    customer's two scripts (the disk alarm; the nightly "is the backup
    there" asking cold storage's `GET /manifests`, answered in the stack
    test by a stand-in, as chunk 3's test answered `POST /shipments`;
    spec D362); pgCluu in `postgres`
    0.5.0, run on demand, its report in the player's home, read with
    `scp` (O225); their documentation; footprints.
  - Out: the option's loader check (chunk 6); placing them in the
    clinic (chunk 27, O226).
- Files: `bricks/pgwatch/` (new), `bricks/health-check/` (new), each
  `brick.yaml`, `Dockerfile`, `rootfs/`, `docs/{gm.md,player.md}`,
  `tests/`; `bricks/grafana/{companion/,docs/gm.md,tests/}` (the
  dashboard); `bricks/postgres/{Dockerfile,docs/gm.md,docs/player.md}`
  (pgCluu); `tools/tests/fixtures/fixture-monitoring-v05/` (new:
  `records` with the option, `pgwatch`, `prometheus`, `grafana`,
  `health`, the bastion); the root `README.md`'s brick table.
- Spec sections: master spec 7.4, 7.5, 14; spec D340.
- Build conditions: G9's, in the wave log ("### G9"): for `pgwatch`
  the binary only, `--web-disable=all`, a metric set with no
  `init_sql`, `PGPASSFILE`; for `health`, nginx serving static files
  only and `check_postgres` through `PGPASSFILE`; pgCluu 5.0 from PGDG,
  pinned, its CGI removed (spec D368).
- Done when: on the fixture, Prometheus scrapes pgwatch's sink, the
  dashboard shows its series, the status page lists each check's line
  with its time through the bastion, a pgCluu report lands in the
  player's home; a node without the option is refused for each monitor
  (after chunk 6); each new brick, started before `records`, waits,
  bounded, fails its readings honestly while `records` is not yet in
  DNS (a fresh node is past the bound), and works once it resolves
  (workflow deltas, spec D356); `health-check`'s stack test shows the
  backup script reading the stand-in's `GET /manifests` answer, found
  and missing, on the page (its first read against cold storage itself
  is G13's); the footprints at rest recorded.
- Verification: chunk checks; G10 before the wave's gate.
- Split rule: 10a `pgwatch` and `grafana` 0.3.0; 10b `health-check` and
  pgCluu.

### Chunk 11 — The partners' shared nodes, cold storage and the vault

Status: planned
Wave: 2
Depends on: chunks 3, 4 and 5 (wave 1); chunks 6 and 7, merged into
`v0.5-w2` before this chunk's branch is cut (6: its fixtures' HTTP
connections load; spec D348); W2
Architecture capture: W2, for chunks 12, 16, 18 to 21 and 23: how a
partner's fragments and routes join the shared nodes (each partner's
prefix, its own tables and role on `partners-db`), a misbehaviour key's
form, cold storage's three endpoints and its manifest, where its stub
lives.

- Goal: the three shared partner nodes as master spec 10.2 builds them,
  and cold storage with the vault (10.4, 11.2), so every partner's stub
  has a place to run.
- Scope: in: `partners-api` (one `api` node, a hostname per partner),
  `partners-backend` (one scheduler node, the merged back end, its
  hidden schedule), `partners-db` (a small `postgres` database, each
  partner's tables and role its own, `no-access`, its `pg_hba.conf`
  admitting only the partners' roles on their database, every other
  line a `reject`, **its form on one Swarm network measured and
  recorded**); a misbehaviour key switching one partner's state, read by
  its own routes; **one partner's slow answers never holding another's**,
  measured; cold storage's stub (`POST /shipments`, `GET /manifests`,
  `GET /` drawn on the server) and its manifests in `partners-db`, the
  planted history's manifests, the vault's `wal` and `basebackup` types
  fed by `postgres` 0.5.0's posting command; the home of cold storage's
  stub, `partners/coldstore/`, recorded; a partners fixture and an
  archive fixture.
  - Out: each partner's own stub (the table "The partners, and where
    each stub is built"); `partners.md` (chunk 27); the bastion's route
    (chunk 17); purpose 14's shipping job (chunk 21).
- Files: `partners/` (new catalogue folder, W2 item 6): `shared/`, the
  three shared nodes' base, and `coldstore/`, cold storage's stub, its
  manifests' DDL and the planted `wal` and `basebackup` snippet, each
  laid out as a domain's partner folder; `tools/tests/fixtures/fixture-partners/`
  and `tools/tests/fixtures/fixture-archive/` (new: `records`, the
  partners' `api` node and database, the bastion); the root
  `README.md`'s layout row for `partners/` (spec D362). The `pg_hba` form is
  recorded in the partners' seed and the chunk's Record line; chunk 10
  holds `bricks/postgres/docs/gm.md` in this wave, so the form joins it
  at wave 2's gate, in its own commit.
- Spec sections: master spec 10.1 to 10.4, 11.2, 14; access model 10;
  [cold-storage.md](cold-storage.md), [third-parties.md](third-parties.md).
- Done when: on the partners fixture, two sample partners answer under
  their hostnames, one made slow by its key while the other answers in
  time, and `partners-db` refuses every role but the partners'; on the
  archive fixture, a switched segment and a base backup each yield a
  manifest naming `records`, `GET /` graphs declared against received,
  `GET /manifests` filters by type and date; the planted manifests show
  the weeks before T0.
- Verification: chunk checks.
- Split rule: 11a the shared nodes, the `pg_hba` form and the slow
  partner; 11b cold storage, the vault and the archive fixture.

### Chunk 12 — `vet-lab`, the centre's laboratory

Status: planned
Wave: 3
Depends on: chunks 4, 6, 8, 9 and 11 (waves 1 and 2)
Architecture capture: W3, for chunks 16, 18, 19 and 20: the lab's key
ranges and functions, the core keys it computes, its released-results
tables and the feed's contract (`GET /orders?account=&released_since=`),
the partners' stubs' tables on `partners-db`.

- Goal: `domains/vet-lab/` as [vet-lab-domain.md](vet-lab-domain.md)
  and master spec 9.3 state it, on the `lab` node, passing the domain
  checklist, with its two partners' stubs.
- Scope: in: its GM notes ("Core keys used", its ranges and functions,
  growth an hour, traps); `data/schema.sql`, `load.sql` computing the
  core's ids by the core's functions without reading `clinic`,
  `classification.yaml`, `register.yaml`, `docs/policy.md` and
  `data/governance.yaml` (its thirteen rules); its fragments for `lis`
  (the information system and the middleware, `clinic-api` by HTTP);
  `lab-api`'s endpoints (`POST /orders` idempotent on the account and
  its `client_ref`, `GET /orders/{accession}`, the released-results
  feed, `POST /send-outs/{send_key}/result`); the external lab's and the
  practices' stubs under `producers/partners/`, planted from the same
  functions so the stubs know every send-out and order the history left
  open; its coherence queries (W2's contract); its variant manifest;
  a fixture `lab` with `lis`, `lab-api`, `clinic-api` and `records`.
  - Out: purposes 1 to 3, 5, 6 and 10 (chunks 18 to 20); s10 (chunk 25).
- Files: `domains/vet-lab/` (new), as chunk 9's layout, with
  `producers/lis/`, `producers/api/lab-api/` and
  `producers/partners/{xlab,practices}/` (each folder its prefix, W2
  item 0; `xlab` serves the hostname `northfield-lab`, spec D370);
  `tools/tests/fixtures/fixture-lab-core/` (new); the root `README.md`'s
  domain table.
- Spec sections: master spec 9.1, 9.3, 10.2; vet-lab-domain.md whole.
- Done when: `check_domain_dir` passes; the load at shift 0 and a
  non-zero shift, its time and size recorded, and the composed core and
  lab through the coherence check; on the fixture, `lis` accessions and
  releases, an order posted twice with one `client_ref` answered with
  one accession, the feed returning released, not performed and
  cancelled tests since a time; the stubs' fragments parse on the
  shared back end.
- Verification: chunk checks.
- Split rule: 12a the GM notes, the schema, the load, classification,
  register and policy; 12b `lis`, `lab-api`, the two stubs and the
  fixture.

### Chunk 13 — `vet-scheduling`, bookings, rota and the training centre

Status: planned
Wave: 3
Depends on: chunks 4, 8 and 9 (waves 1 and 2)
Architecture capture: W3, for chunks 20 and 21: the bookings' tables
and the slot function's signature; the rota's published weeks.

- Goal: `domains/vet-scheduling/` as
  [vet-scheduling-domain.md](vet-scheduling-domain.md) and master spec
  9.4 state it, in `records/clinic`, passing the domain checklist.
- Scope: in: its GM notes, schema (exclusion constraints, `btree_gist`
  through chunk 8), load, classification, register fragment, policy and
  rules; its fragments on `pms` (connection `sched`, `sched_app`); the
  slot function; its coherence queries; its variant manifest; **the
  booking horizon against sessions planned three months ahead**,
  settled and recorded; the `bookings` fixture (`records`, `pms`,
  `interfaces`, the bastion; T0 a weekday at 09:50).
  - Out: purposes 11 and 12 (chunks 21, 20).
- Files: `domains/vet-scheduling/` (new); `tools/tests/fixtures/fixture-bookings/`
  (new); the root `README.md`'s domain table.
- Spec sections: master spec 9.4; vet-scheduling-domain.md whole, its
  "Tests in v0.5".
- Done when: `check_domain_dir` passes; the core's and the part's loads
  agree (every attended booking's consultation by id, no overlap, every
  vet of the history on shift); on the fixture an overlapping allocation
  is refused (`23P01`), bookings made through the slot function, a
  cancellation releasing its slot, `sched.rota.publish` moved to the
  next minute publishing the week after next, rerun without a
  duplicate; load figures recorded.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 14 — `vet-housing`, the wards and their displays

Status: planned
Wave: 3
Depends on: chunks 4 and 9 (waves 1 and 2)
Architecture capture: W3, for chunks 20 and 25: the board's statement
and the display's key in `ward`'s profile layer; the occupancy measure
purpose 9 reads.

- Goal: `domains/vet-housing/` as
  [vet-housing-domain.md](vet-housing-domain.md) and master spec 9.5
  state it, `lands_with: vet-core`, passing the domain checklist.
- Scope: in: its GM notes, schema, load (placements on the core's
  stays), classification, register fragment, policy and rules; its
  fragments on `pms` (connection `housing`) and on the ward service
  `ward` (the displays reading the board as `vet_display`, the pools
  per call); its coherence queries (placements on real stays, every
  current stay placed); its variant manifest; the `housing` fixture
  (`records`, `pms`, `ward`, the bastion).
  - Out: s9, the faulty display (chunk 25); purpose 9's occupancy
    (chunk 20).
- Files: `domains/vet-housing/` (new); `tools/tests/fixtures/fixture-housing/`
  (new); the root `README.md`'s domain table.
- Spec sections: master spec 9.5; vet-housing-domain.md whole, its
  "Testing".
- Done when: `check_domain_dir` passes, `lands_with` refusing another
  database; on the fixture, the load's placements check (every current
  stay placed once, none open on an ended stay, no unit holding two),
  the board's calls about 64 a minute from `ward`, placement and release
  with T0 at 10:00, the care log with T0 just before 17:00, each under
  30 minutes; load figures recorded.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 15 — `vet-machinery`, the machines and their databases

Status: planned
Wave: 3
Depends on: chunks 4, 5, 8, 9 and 11 (waves 1 and 2)
Architecture capture: W3, for chunk 21: the three databases' tables
purposes 13 and 14 use, the daily partitions and the summaries kept on
site.

- Goal: `domains/vet-machinery/` as
  [vet-machinery-domain.md](vet-machinery-domain.md) and master spec 9.6
  state it, its three databases on `machines`, passing the domain
  checklist.
- Scope: in: `databases: [pacs, vitals, biomed]` with a schema and load
  each; its GM notes, classification keyed unique across the part,
  register fragment, policy and its own rules; its fragments on
  `equipment` (the identity and census jobs on `clinic-api` by HTTP);
  plain partitioned tables, a partition a day created ahead; its
  coherence queries (monitoring sessions on stays); its variant
  manifest; **machine 10's telemetry measured and settled** (O227: 10
  or 11 machines reporting), the reference sizes and the growth an hour
  following; the `imaging` fixture (`records`, `clinic-api`, `pms`,
  `machines`, `equipment`, `interfaces`, the bastion; T0 a weekday at
  08:50) for the part's own checks.
  - Out: purposes 13 and 14 and the `vault` fixture (chunk 21).
- Files: `domains/vet-machinery/` (new) with `data/{pacs,vitals,biomed}/`;
  `tools/tests/fixtures/fixture-imaging/` (new); the root `README.md`'s
  domain table.
- Spec sections: master spec 9.6, 10.4 (the site's side), 14 (its
  trims); vet-machinery-domain.md whole, its "Testing in v0.5".
- Done when: `check_domain_dir` passes; three databases created, each
  with `CONNECT` revoked from `PUBLIC`; the loads at shift 0 and a
  non-zero shift, figures recorded; on the fixture, the identity and
  census jobs answered by `clinic-api`, partitions ahead present;
  machine 10's reading recorded in the GM notes.
- Verification: chunk checks.
- Split rule: 15a the three databases, their loads, classification,
  register and rules; 15b the fragments on `equipment`, the partitions,
  the fixture and machine 10's measurement.

### Chunk 16 — `vet-portal`, the owners' portal

Status: planned
Wave: 3
Depends on: chunks 5, 8, 9 and 11 (waves 1 and 2); chunk 12, merged
into `v0.5-w3` before this chunk's branch is cut; W3
Architecture capture: W3, for chunk 21 and 25: the copies' tables, the
row-level security policies and the transaction-local `portal.owner_id`,
`portal-api`'s endpoints, the outbox; and O229 first (the messaging
stub's planted notices, which W2 item 3's `derive.sql` cannot write into
`partners`).

- Goal: `domains/vet-portal/` as
  [vet-portal-domain.md](vet-portal-domain.md) and master spec 9.7
  state it, in `records/portal`, passing the domain checklist.
- Scope: in: its GM notes, schema (`pgcrypto` through chunk 8; the
  row-level security policies), load, `data/derive.sql` copying the
  record and the lab's released content field by field (sanctioned in a
  composition record), classification, register fragment, policy and
  rules; `portal-api`'s endpoints (`producers/api/portal-api/`: login,
  accounts, animals and documents under owner scope, `SECURITY DEFINER`
  pre-login calls); the desk's consent stream on `pms` (an HTTP
  connection); **the owners' traffic source in
  `producers/partners/owners/`** (spec D369): prefix `owners`, its
  `data.sql` creating the role and schema `owners` and the route's record
  of visits in `partners` (W2 item 3), with no `partners.md` entry, no
  contract and no misbehaviour key (no `owners.state`, no
  `owners.normal` stream; master spec 10.2); **the outbox's id order across the load and the
  derivation**, settled; its coherence queries (published documents
  matching signed consultations and released results); its variant
  manifest; the `portal` fixture's base (`records`, `lab`,
  `interfaces`, `portal-api`, the partners' three nodes, the bastion:
  eight nodes).
  - Out: purposes 15 and 16 (chunk 21); s5 (chunk 25).
- Files: `domains/vet-portal/` (new) with `data/derive.sql`,
  `producers/api/portal-api/` and `producers/partners/owners/`;
  `tools/tests/fixtures/fixture-portal/` (new); the root `README.md`'s
  domain table.
- Spec sections: master spec 9.7, 13.1 (owner-scoped access), 8.5 (the
  derivation); access model 9.3; vet-portal-domain.md whole.
- Done when: `check_domain_dir` passes; the load and the derivation run
  in order, the derivation unseen; on the fixture, as a planted owner, a
  former owner, a buyer and a keeper with and without consent, each
  `GET /animals` and document list as the rules say, another owner's
  document refused; activation, login, the lock after five failures, an
  old token refused, each visit in the owners' record in `partners`;
  load figures recorded.
- Verification: chunk checks.
- Split rule: 16a the schema, the policies, the load, the derivation,
  classification, register and rules; 16b `portal-api`, the desk stream,
  the owners' traffic and the fixture.

### Chunk 17 — `bastion` 0.5.0 and the data register

Status: planned
Wave: 4
Depends on: chunks 7, 11 and 12 to 16 (waves 2 and 3)
Architecture capture: W4, for chunks 23, 26 and 27: the skill's inputs
and outputs (`gm/data-register.yaml` with `generated_from:`, the
handout, `register_diff:`), how a register fault's change is applied,
the loader's digest and coverage checks; how a scenario names the
credentials `partners.md` documents, and where the players read their
values (spec D365).

- Goal: master spec 21's data-register chunk: the skill, the GM's Setup
  step 2, the scenario document's section, the loader's checks and the
  bastion's seed files, with `bastion` 0.5.0 whole.
- Scope: in:
  - **17a, `bastion` 0.5.0**: `seed.optional` gaining `partners.md` and
    `data-register.md`, each copied into `/home/player` and shown on the
    page only when present, "Partners" then "Data register" after the
    data policy; the web front proxying cold storage's `GET /` and
    `GET /manifests` under its hostname, never its upload endpoint and
    never another partner (the entrypoint's routes and
    `render.web_routes_value`), and the loader's one exception for that
    route in `model._check_web_routes`, every other third-party node and
    alias still refused (spec D363); the loader refusing a `data.sql` in
    `producers/public/<name>/`, naming the file and `partners/<prefix>/`
    as its home (`_check_fragments`; `model._partner_data_files`, and so
    `node_creates`, reading `partners/` only), the folder's fragments
    still accepted (spec D369); **the partners' documented
    credentials handed over with the starter pack** (access model 3 and
    6, master spec 10.2; spec D365): each credential `partners.md`
    documents, the customer's own with that partner, its game value
    marked handed over and given with `partners.md`, never
    `cold_storage`; its docs; its stack test;
  - **17b, the data register**: the `data-register` GM sub-skill and its
    template (13.3): generated from the composed domains' classification
    copies and register fragments, `governance:`, the composition
    record, `scenario.yaml` and the answer key; the true register
    sealed, the handout as is or with a register fault applied, or
    absent; `register_diff:` for each register fault; the loader's
    checks (the digests recomputed and a stale register refused;
    coverage; the handout present unless the answer key declares its
    absence; a scenario listing `domains:` refused without one, the
    released shop scenario exempt); `game-master`'s Setup step 2 (the
    format check, the register, the scenario document);
    `scenario-document`'s "Data register" section; formats.md's lines
    carried into the skill's checklist.
  - Out: s6 (chunk 23); the clinic scenario's register (chunk 27).
- Files: `bricks/bastion/{brick.yaml,docs/gm.md,docs/player.md}`,
  `bricks/bastion/rootfs/usr/local/sbin/gm-entrypoint`,
  `bricks/bastion/tests/{run-stack-test.sh,stack.test.yml,fixtures/starter/}`;
  `tools/gm/{render.py,localimpl.py}`, `tools/tests/test_render.py`
  (the handed-over credentials);
  `.claude/skills/data-register/{SKILL.md,template.md}` (new);
  `.claude/skills/game-master/SKILL.md` (Setup step 2),
  `.claude/skills/scenario-document/{SKILL.md,template.md}`,
  `.claude/skills/scenario-format/{SKILL.md,templates/layouts.md}` (the
  register's items; the `public/` folder without `data.sql`);
  `tools/gm/model.py`, `tools/tests/test_model.py`;
  `tools/tests/fixtures/fixture-register/` (new: the six domains
  composed, no deployment).
- Spec sections: master spec 7.3, 13.2, 13.3, 6.2, 6.3;
  [data-register-handout.md](data-register-handout.md) sections 1 to 3,
  6, 7.
- Done when: the bastion's stack test shows both files on the page when
  present and absent otherwise, and the route answering `GET /` and
  `GET /manifests` while refusing `POST /shipments` and every other
  partner's hostname; the loader accepting that route and refusing any
  other third-party node or alias in `web_routes`; a `public/`
  `data.sql` refused; a documented
  credential's value given with `partners.md` and accepted by its
  partner's endpoint, `cold_storage` never given; on the register fixture, the true register and the
  handout generated, about twenty entries and the internal table, the
  coverage checks passing, a stale digest refused, a declared absence
  passed; the unit suite passes.
- Verification: chunk checks; G11 if the front needs a package.
- Split rule: 17a `bastion` 0.5.0; 17b the skill, the loader's checks
  and the two skills' sections.

### Chunk 18 — The lab's round trips: purposes 1, 2, 3 and 6

Status: planned
Wave: 4
Depends on: chunks 9, 11 and 12 (waves 2 and 3)
Architecture capture: W4, for chunks 19 to 22: **where a purpose's
`history.sql` and endpoint material sit** beside v0.4's per-part
folders, and the `ops` tables every purpose writes (`ops.runs`,
`ops.incidents`, `ops.watermarks`).

- Goal: `vet-lab-centre-orders`, `vet-lab-practice-results`,
  `vet-lab-send-outs` and `vet-lab-critical-calls` in `purposes/`,
  complete by the format skill (12.2).
- Scope: in: each `purpose.yaml` (the round-trip blocks, `judged:`, the
  roles), `material/` (`interfaces`' script jobs, the `pg_cron` watch on
  `lab`), `checks/` (LO1 to LO4, PR1 to PR5, SO1 to SO4, CC1 and CC2),
  `gm.md`; the `orders` fixture (`records`, `lab`, `clinic-api`,
  `lab-api`, `pms`, `lis`, `interfaces`, the bastion; T0 a weekday at
  10:00) and the `send-outs` fixture (`lab`, `interfaces`, the
  partners' three nodes, the bastion; T0 a weekday at 15:50).
  - Out: s1, s4 and the false alarm (chunk 22).
- Files: `purposes/{vet-lab-centre-orders,vet-lab-practice-results,vet-lab-send-outs,vet-lab-critical-calls}/`
  (new); `tools/tests/fixtures/fixture-{orders,send-outs}/` (new); the
  root `README.md`'s purpose table.
- Spec sections: master spec 12, 12.1, 12.2 (purposes 1, 2, 3, 6);
  [clinic-purposes.md](clinic-purposes.md).
- Done when: each purpose passes the format skill; on the orders
  fixture, an urgent request posted within two minutes and its release
  `resulted` within ten, every check passing unfaulted; the practices'
  deliveries acknowledged on a fixture run; on the send-outs fixture,
  the 16:00 send-out accepted and an answer recorded; the critical-call
  watch writing one incident for an unread result; each run under 30
  minutes.
- Verification: chunk checks.
- Split rule: 18a purposes 1 and 6 on the orders fixture; 18b purposes
  2 and 3 and the send-outs fixture.

### Chunk 19 — The exchanges and the notifications: purposes 4 and 5

Status: planned
Wave: 4
Depends on: chunks 9, 11 and 12 (waves 2 and 3)
Architecture capture: W4.

- Goal: `vet-centre-exchanges` and `vet-notifiable-diseases` in
  `purposes/`, with the centres' and the authority's stubs.
- Scope: in: each `purpose.yaml`, `material/`, `checks/` (EX1 to EX5,
  ND1 to ND5), `gm.md`; purpose 4's endpoints on `clinic-api` (`POST
  /exchanges`, `.../answer`, `.../report`, as `vet_exchange`); the three
  centres' stubs in `vet-core`'s `producers/partners/`; the authority's
  stub in purpose 5's material, answering with a reference, 503 to one
  call in fifty; the 02:15 copy into `office`; an `exchanges` fixture
  (`records`, `lab`, `clinic-api`, `interfaces`, the partners' three
  nodes, the bastion).
- Files: `purposes/{vet-centre-exchanges,vet-notifiable-diseases}/`
  (new); `domains/vet-core/producers/partners/` (the centres);
  `tools/tests/fixtures/fixture-exchanges/` (new); the root `README.md`'s
  purpose table.
- Spec sections: master spec 12.2 (purposes 4, 5), 10.2.
- Done when: each purpose passes the format skill; on the fixture, an
  outbound exchange posted and answered, an inbound one answered within
  ten minutes, a vet's notifiable diagnosis and a lab notification each
  notified within their deadlines and referenced, a 503 retried; every
  check passing unfaulted.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 20 — The periodic reports: purposes 7, 8, 9, 10 and 12

Status: planned
Wave: 4
Depends on: chunks 3, 8, 9, 12, 13 and 14 (waves 1 to 3)
Architecture capture: W4, for chunk 24: the feeders' times and queries,
`office`'s tables and roles, the planted periods.

- Goal: `vet-medicines-registers`, `vet-antimicrobial-use`,
  `vet-head-office-figures`, `vet-lab-statements` and
  `vet-working-time` in `purposes/`, on `backoffice`, reading the
  standby (the lab's node for purpose 10) and writing `office`.
- Scope: in: each `purpose.yaml` (periodic, its feeder named),
  `material/` (the feeders and the periodic jobs; `office`'s DDL, its
  roles `office_jobs`, `office_reader`, `vet_reports`, `sched_reports`,
  `lab_reports`; `history.sql` planting the past periods), `checks/`
  (MR1 to MR4, AM1 to AM4, HO1 to HO3, ST1 to ST3, WT1 to WT3), the
  purpose's `classification:` for `office`, `gm.md`; the head office's
  stub (purpose 9) and the authority's yearly-report route (purpose 8);
  the `reports` fixture (`records` with `clinic` and `office`, the
  standby, `backoffice`, the bastion; T0 a Friday at 01:20), with `lab`
  added for purposes 9 and 10 (seven nodes and the bastion at most).
- Files: `purposes/{vet-medicines-registers,vet-antimicrobial-use,vet-head-office-figures,vet-lab-statements,vet-working-time}/`
  (new); `tools/tests/fixtures/fixture-reports/` (new); the root
  `README.md`'s purpose table.
- Spec sections: master spec 11.1, 11.3, 12.1 (periodic purposes),
  12.2 (purposes 7 to 10, 12); vet-scheduling-domain.md ("Tests in
  v0.5", `vet-working-time`).
- Done when: each purpose passes the format skill; the planted periods
  present after `load-data`; on the fixture, each feeder moved to the
  next minute writing its day once, as the source's, from the standby;
  a month's report on a planted month summing its days; every check
  passing unfaulted; each run under 30 minutes.
- Verification: chunk checks.
- Split rule: 20a purposes 7, 8 and 12 (the core's, on the standby);
  20b purposes 9 and 10 (the head office and the lab's statements).

### Chunk 21 — The parts' flows: purposes 11, 13, 14, 15 and 16

Status: planned
Wave: 4
Depends on: chunks 11, 13, 15 and 16 (waves 2 and 3)
Architecture capture: W4, which keeps purpose 14's planted manifests
(cold-storage.md 2) within W2 item 3's history rule, its `target` the
partners' database: no chunk after 8 holds `inject.py`, so another form
is an inserted chunk, its decision first (spec D366).

- Goal: `vet-bookings-sync`, `vet-imaging-orders`,
  `cold-storage-archive`, `vet-portal-release` and `vet-portal-messages`
  in `purposes/`, complete by the format skill.
- Scope: in: each `purpose.yaml`, `material/` (`interfaces`' script
  jobs; check-in opening the core's scheduled consultations, the core's
  own opening stream removed; the shipping job on `vitals` and
  `biomed`; the copies and the release gate; the outbox's dispatch),
  `checks/` (BS1 to BS5, IO1 to IO4, CA1 to CA4, RL1 to RL6, MS1 to
  MS6), `gm.md`; the messaging service's stub (purpose 16); the
  `bookings`, `imaging` and `portal` fixtures extended with their
  purposes; the `vault` fixture (`machines`, `equipment`, `interfaces`,
  the partners' `api` node and database, the bastion; T0 21:55, the
  shipping moved to the next minute).
- Files: `purposes/{vet-bookings-sync,vet-imaging-orders,cold-storage-archive,vet-portal-release,vet-portal-messages}/`
  (new); `tools/tests/fixtures/fixture-{bookings,imaging,portal}/`,
  `tools/tests/fixtures/fixture-vault/` (new); the root `README.md`'s
  purpose table.
- Spec sections: master spec 10.4, 12.2 (purposes 11, 13 to 16);
  the parts' "Testing" sections.
- Done when: each purpose passes the format skill; on the bookings
  fixture, an arrival's consultation within two minutes, an imaging
  request booked, a death cancelling future bookings; on the imaging
  fixture, an urgent request sent, acquired and resulted; on the vault
  fixture, the day shipped, received, dropped after its aggregate and
  shown on the vault's page; on the portal fixture, the copies, the
  release gate, the owners' visits (RL6) and the messages as its page
  lists them; each run under 30 minutes.
- Verification: chunk checks.
- Split rule: 21a purposes 11, 13 and 14 (bookings, imaging, vault);
  21b purposes 15 and 16 (portal).

### Chunk 22 — The orders faults: s1, s4 and the false alarm

Status: planned
Wave: 5
Depends on: chunk 18 (wave 4)
Architecture capture: W5, for chunk 27: each fault's id, its seed
changes and its timeline moment in the fixture; the answer key's
backlog entry for s1.

- Goal: s1 (T40, the urgent priority dropped) and s4 (T41, a retry under
  a new `client_ref`, the held `purpose-retry-without-key` built) as
  fault definitions, and the false alarm's material, each passing its
  short test (17.3).
- Scope: in: each `fault.yaml` (injection, `applies_to` with the new
  versions, the aging minimum, the sealed check, the solvability
  description), its material (the mapping in `post-lab-orders`; the
  retry without the key) and its check; s1's end-to-end judgement on
  the urgent orders posted after the fix, the routine-posted ones a
  credited backlog; fa's issue for the starter pack and the planted PCR
  send-out answered on its fourth day; **each fault's timeline moment**
  in its fixture, before its test's reading. On the orders fixture
  (s1, s4: the emergencies raised in its profile layer; one post
  delayed past the runner's ten-second timeout by a lock held on
  `lab_orders`) and the send-outs fixture (fa).
  - Out: the clinic scenario's selection (chunk 27).
- Files: `faults/<s1's id>/`, `faults/<s4's id>/` (new, ids by the
  catalogue's naming: s4 `purpose-retry-without-key`); the false alarm's
  material in the send-outs fixture; `tools/tests/fixtures/fixture-{orders,send-outs}/`
  (their fault instances and answer keys);
  `bricks/scheduler/docs/gm.md` ("Supported faults", a shared list).
- Spec sections: master spec 17.2, 17.3 (s1, s4, fa), 12 (a cascade's
  fix), 6.3, 6.4; [clinic-test-selection.md](clinic-test-selection.md).
- Done when: s1 read present (a `routine` order whose request is
  `urgent`, within ten minutes) and fixed (the next urgent order
  `urgent`, released at once, resulted within ten minutes), about 25
  minutes; s4 present (two orders, two `client_ref`s, for one
  consultation) and fixed (one order, the second post answered with the
  first accession), about 15 minutes; fa's check reading the due date
  against the answer within turnaround, about 5 minutes; each fault
  complete by the format skill.
- Verification: chunk checks; each short test is this chunk's point.
- Split rule: none expected.

### Chunk 23 — The archive faults: s2 and s6

Status: planned
Wave: 5
Depends on: chunks 11 and 17 (waves 2 and 4)
Architecture capture: W5; s2 and s6 planted together on the archive
fixture, the answer key noting the interaction (17.2).

- Goal: s2 (T35, `archive_command` failing silently) and s6 (T307, the
  vault declared nowhere in the data register, `governance-register-flow-undeclared`),
  each passing its short test.
- Scope: in: each `fault.yaml` and material: s2's `postgresql.conf`
  change on `records`; s6 a `seed-file` change on the bastion
  (`data-register.md`), its handout written by the `data-register`
  skill, its `register_diff:`, resolved by *propose*, cleared by the
  handout regenerated without the fault; on the archive fixture, s2's
  segment switched by the test (`pg_switch_wal()`), s6's witness the
  vault's planted manifests and base backups.
- Files: `faults/<s2's id>/`, `faults/governance-register-flow-undeclared/`
  (new); `tools/tests/fixtures/fixture-archive/` (its fault instances,
  answer key and register); `bricks/postgres/docs/gm.md`,
  `bricks/bastion/docs/gm.md` ("Supported faults").
- Spec sections: master spec 13.4, 17.2, 17.3 (s2, s6), 6.3, 6.4;
  [data-register-handout.md](data-register-handout.md) 4, 5.
- Done when: s2 present (`pg_stat_archiver` reporting the segment
  archived, no `wal` manifest naming it, the vault's page showing the
  gap) and fixed (the next switched segment's manifest present, the gap
  staying a finding), about 10 minutes; s6 present (the bastion serving
  `data-register.md` in `/home/player` and on the page with cold storage
  among no entry's recipients, the true register naming it, the vault's
  page listing `records`' manifests), cleared, and its *propose* judged
  against `register_diff:`, about 10 minutes; both complete by the
  format skill.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 24 — The reports faults: s3, s7 and s8

Status: planned
Wave: 5
Depends on: chunk 20 (wave 4)
Architecture capture: W5.

- Goal: s3 (T69, herd prescriptions dropped from the antimicrobial use),
  s7 (T1, statement logging on `records`, the held
  `governance-statement-log-personal` built) and s8 (T33, the standby an
  hour behind), each passing its short test.
- Scope: in: each `fault.yaml` and material: s3 the feeder's query on
  `backoffice` and last year's planted report short of the cattle's use;
  s7 `records`' `postgresql.conf`; s8 the standby's
  `recovery_min_apply_delay`; on the reports fixture (T0 a Friday at
  01:20, Thursday's herd visits held), each feeder moved as a player
  may.
- Files: `faults/<s3's id>/`, `faults/governance-statement-log-personal/`,
  `faults/<s8's id>/` (new); `tools/tests/fixtures/fixture-reports/`
  (fault instances, answer key); `bricks/postgres/docs/gm.md`,
  `bricks/scheduler/docs/gm.md` ("Supported faults").
- Spec sections: master spec 17.2, 17.3 (s3, s7, s8), 11.1, 12.1
  (periodic purposes, a planted report).
- Done when: s3 present (the 02:00 feeder's day short of the herd
  treatments, last year's report short) and fixed (after the query's
  fix, the feeder moved and its day complete; the planted report still
  wrong, its rerun recommended), about 20 minutes; s7 present (an
  owner's name and phone in `records`' log after the test's writes as
  `vet_app`) and fixed (none after a reload), about 10 minutes; s8
  present (the replay lag at an hour, the 01:30 feeder's day missing the
  evening's last hour) and fixed (the lag near zero, the feeder's day
  complete), about 20 minutes; each complete by the format skill.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 25 — The scope faults: s5, s9 and s10

Status: planned
Wave: 5
Depends on: chunks 6, 14 and 16 (waves 2 and 3)
Architecture capture: W5; s9 a report-only fault on a component no
layer of the players' (6.3).

- Goal: s5 (T270, the portal's animals policy ignoring an ownership's
  end), s9 (T150, a faulty display reading its board in a loop) and
  s10 (T10, `monitoring` not chosen on `lab`), each passing its short
  test.
- Scope: in: each `fault.yaml` and material: s5 the policy on `portal`
  (DDL) planted a few hours before T0, with a sale in that window, on a
  `portal-scope` fixture (`records` with `clinic` and `portal`,
  `portal-api`, the bastion); s9 the display's key in `ward`'s profile
  layer, its resolution *report*, judged at the final answer, never
  cleared in play, on the housing fixture; s10 the topology's `options`
  planting the option's absence (the loader's exception), on a `lab`
  fixture (`lab`, its exporter, the bastion).
- Files: `faults/<s5's id>/`, `faults/<s9's id>/`, `faults/<s10's id>/`
  (new); `tools/tests/fixtures/fixture-portal-scope/`,
  `tools/tests/fixtures/fixture-lab/` (new),
  `tools/tests/fixtures/fixture-housing/` (fault instance, answer key);
  `bricks/postgres/docs/gm.md`, `bricks/scheduler/docs/gm.md`
  ("Supported faults").
- Spec sections: master spec 17.2, 17.3 (s5, s9, s10), 6.3, 6.4, 7.1,
  9.5 ("Finding a faulty display"), 9.7.
- Done when: s5 present (as the former owner, `GET /animals` on
  `portal-api` returns the horse they sold) and fixed (it does not, and
  the buyer still sees it), about 10 minutes; s9 present (the board
  statement's calls well above 64 a minute from `ward`, the unit's
  parameter logged for `vet_display`), reported (the chain to the
  display's serial and the animal) and cleared by the test only (the
  key off, the calls back to 64 a minute), about 15 minutes; s10 present
  (the exporter's login errors against `lab`) and fixed (the option
  chosen, the node redeployed, the metrics present), about 15 minutes;
  each complete by the format skill.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 26 — The GM skill and the scenario document for v0.5

Status: planned
Wave: 5
Depends on: chunks 2, 8, 11 and 17 (waves 1 to 4)
Architecture capture: W5, for chunk 27: the composition steps at design
time and the coherence check at setup, as the GM runs them.

- Goal: the `game-master` and `scenario-document` skills carry master
  spec 15's items not yet written.
- Scope: in: `game-master`: composition and its record at design time
  (`gmctl compose`, `merge.yaml`, `composition.yaml`); the coherence
  check at setup, a failure a design error fixed and reloaded, never a
  fault; third parties played by no one, their support never answering,
  an overstep on a third party's node refused; a report-only fault on a
  display judged at the final answer, never cleared in play; a register
  fault judged on *propose*; `gmctl.md`'s v0.5 verbs and stages;
  `scenario-document`: the "Third parties" and "Composition" sections.
  - Out: Setup step 2 and the "Data register" section (chunk 17).
- Files: `.claude/skills/game-master/{SKILL.md,gmctl.md,feedback.md}`,
  `.claude/skills/scenario-document/{SKILL.md,template.md}`.
- Spec sections: master spec 10.3, 13.3, 13.4, 15, 16; access model 7,
  10; [gm-stance.md](../../gm-stance.md).
- Done when: each item above is in the skills; every `gmctl` invocation
  in them parses; a regenerated README of the archive fixture shows the
  three sections.
- Verification: chunk checks.
- Split rule: none expected.

### Chunk 27 — The clinic scenario, `aldermoor-centre`

Status: planned
Wave: 5
Depends on: chunk 17 (wave 4); chunks 22 to 26, merged into `v0.5-w5`
before this chunk's branch is cut; G14 (its merge, only if it applies);
W5
Architecture capture: none of its own; it reads W1 to W5.

- Goal: the clinic scenario of master spec 17, complete by the format
  skill, composed and recorded, ready for G13.
- Scope: in: `scenario.yaml` (the 25 nodes of section 14 with their
  hosts, the monitoring breadth, `health` on the VPS by O226, `domains:`
  in the `regional-franchise` variant, `third_parties:` with the nine
  partners and the `owners` hostname, `options:`, the standby, the
  purposes in use, the faults: the test selection, s1 to s10 and fa);
  `gmctl compose` run, `merge.yaml` and `composition.yaml` written; the
  story, naming the centre, the off-site room and the partners by their
  in-world names; the data policy adapted from the domains' default
  policies; `player/partners.md`, with the credentials it documents
  named as W4 fixes (spec D365); the register generated with s6
  planted and the true register beside it; the answer key; the scenario
  document generated; **`fit` on armenelos plus the VPS with the
  measured reservations and real image sizes** (placement only, the
  VPS declared `shared`), the CPU read against O224's trim; a load-only
  fixture of its four database nodes and the bastion, through the
  coherence check and the governance checks unfaulted.
  - Out: the deployment and the smoke (G13, the release gate).
- Files: `scenarios/aldermoor-centre/` (new): `scenario.yaml`,
  `composition.yaml`, `merge.yaml`, `brief.md`, `README.md`, `data/`,
  `nodes/`, `player/{data-policy.md,partners.md,data-register.md}`,
  `gm/{answer-key.yaml,data-register.yaml}`;
  `tools/tests/fixtures/fixture-clinic-load/` (new); the root
  `README.md`'s scenario table.
- Spec sections: master spec 14, 17.1 to 17.4, 19 item 10, 20 items 3
  and 4; [clinic-capacity.md](clinic-capacity.md).
- Done when: the scenario passes the format skill and the loader; the
  register passes the coverage checks and its digests are current; the
  README matches a fresh regeneration; `fit` accepts the placement on
  armenelos plus the VPS (or G14 is raised with the figures); the
  load-only fixture passes the coherence check and the governance
  checks unfaulted.
- Verification: chunk checks.
- Split rule: 27a the composition, the topology, the policy, the
  register and the document; 27b `fit`, the load-only fixture and its
  checks.

## Release gate

Against master spec sections 19 and 20, on `v0.5-w5` before it merges,
alone on the hosts, under the host lock and a sleep inhibitor, with
v0.1's to v0.4's checks still applying except those spec D311, D312 and
D314 move. **No aged run, no long run** (spec D314): every item below
runs under 30 minutes on its least environment, but item 5, the one
exception. GM-side checks run from the host.

1. **Every short test of 17.3 and 18.2** green on the built versions,
   each under 30 minutes: the ten faults present and fixed (s6 and s9
   cleared), the false alarm's check, every fixture's checks, each
   brick's own short tests (the `api` brick's build checks; the HTTP
   driver against one stub; the partners' node with one partner slow;
   the standby cloned and streaming; a segment and a base backup in the
   vault; the options refused and accepted; `gmctl compose`'s four
   cases; the coherence check passing and failing; the register
   generated, a stale digest refused, a declared absence passed; each
   domain's load at shift 0 and a non-zero shift) (DoD items 1 to 9).
2. **The existing scenarios' short smoke tests** on the re-pinned
   versions, each through `smoke-scenario.sh`; every existing fault's
   `applies_to` carrying the new versions (DoD 11).
3. **The unfaulted clinic scenario** passes the governance checks and
   the coherence check, and its true register the loader's coverage
   checks (chunk 27's load-only fixture, rerun) (DoD 10).
4. **`fit` on the clinic as built**, on armenelos plus the VPS, with
   the measured reservations (G14 applied first if it applies).
5. **The whole clinic deployed once** on armenelos plus the VPS: G12,
   then G13, about 30 minutes, every fault read present only where it
   reads within the window (s2, s5, s6, s7, s8, s9 and s10 at once; s1
   at the first urgent order, if one comes; s3 resting on its fixture),
   no fault fixed; the VPS drained after and filetstudio.com answering.
6. **The format, the loader and the skills**: formats.md v28's items in
   the templates, the loader and the `scenario-format` skill, with
   wave 2's as-built items written into formats.md (G16); the
   `data-register` skill, the GM's Setup step 2, the scenario
   document's sections (DoD 3, 4, 8).
7. **The bricks**: `postgres` 0.5.0, `scheduler` 0.3.0, `api` 0.1.0,
   `bastion` 0.5.0, `pgwatch` 0.1.0, `health-check` 0.1.0 and `grafana`
   0.3.0 pass the format skill's `docs/gm.md` check, with GM and player
   documentation, validators and measured footprints; G5 to G10 (and
   any G11) cleared, `.tech` current (DoD 1, 2).
8. **The domains and purposes**: the six clinic domains each passing
   the domain checklist with its register fragment, variant manifest
   and GM notes, the shop's folder in the new format; the sixteen
   purposes complete by the format skill; the partners' stubs, cold
   storage and the vault (DoD 5 to 7).
9. **The wave-gate quality command**, green.
10. **Every row of "Left for the build"** has its finding recorded in
    its chunk's Record line and, for a brick or a domain, its
    `docs/gm.md`.
11. G15: the owner's judgement.
12. **Release notes** in [README.md](README.md): the measured figures
    (footprints at rest, each domain's load, G13's per-node readings on
    both hosts as smoke readings, not footprints); the known limits
    named by master spec 18.4, all of it v1.0 gating (the clinic aged
    and played, the overnight and periodic cadences in scenario time,
    growth and footprints over an aging, the clinic's rehearsal, the
    stance check-list, the parts' long views); no hand-over snapshot for
    the whole clinic on these declarations; a restart from a hand-over
    snapshot not bringing a standby back as one (`postgres` 0.5.0's
    known limit, spec D352); the access model's known
    gaps that stand; the security advisor's items still with the owner.
