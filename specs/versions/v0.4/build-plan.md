# db_audit_gm v0.4 — Build plan

Status: v16 (2026-11-03): the owner's answer to spec O163, the smoke
run's end-of-run checks a known limit covered by the v1.0-gating smoke
run (spec D313), in release gate item 8; G11 done; v0.4 released
2026-11-03;
v15 (2026-11-03): the owner's ruling on spec O162, long-running
tests moved to v1.0 gating (spec D312): the wave 4 gate's `smoke` run
stopped at f8's wait, f8's reading there and item 9's unobserved part
moved, in the workflow deltas, chunk 17 and release gate items 8, 9 and
17; the smoke run's end-of-run checks left to the owner (spec O163);
v14 (2026-11-03): the owner's ruling on spec O161, the two-host
runs, the rehearsal (17b) and the stance check-list moved to v1.0
gating (spec D311), in the gates, the waves, chunk 17, the workflow
deltas, the measurements and the release gate; item 9's unobserved part
left to the owner (spec O162); v13 (2026-11-03): the owner's ruling on chunk 17a's runs, 17a
done with its cycles run aborted at f4's wait for the scenario's midnight
and without its two-host run (spec D310), in chunk 17; when the
remaining two-host runs happen left open (spec O161); v12 (2026-11-02): the owner's ruling on chunk 17a's finding,
the `pgbouncer` start-up DNS race fixed in v0.4 as `pgbouncer` 0.1.1 by
the inserted chunk 21 on wave 4 (spec D305), in "Read first", the waves,
chunk 17 and the release gate; v11 (2026-11-02): the owner's ruling on O146 (spec D284): f4
expected "too soon" at the hand-over check, masked by f5 at
`handover-5h`, and the hand-over check passing a "too soon" the answer
key expects, in chunks 16 and 17 (`gmctl.md`'s line in 17, chunk 18
merged) and the release gate; v10 (2026-11-02): capture W4's readings: chunk 17a's unfaulted
scenario rebuilt from `fixture-campaign`'s files, a seed change surviving
the override; the rehearsal without f7 as well as f10 (spec D283); f10's
check reading 2 once a player alters the request (spec D282), in chunks
16 and 18; f4's reading at the hand-over check left to the owner (spec
O146); v9 (2026-10-31): the owner's rulings on G10, f10's normal run
accepted at 327 MiB (spec D252), and on O140, `separation: instance` as a
rule of G1 built by the inserted chunk 20 on wave 3 (spec D253); chunk
15b's readings of f10 (spec D254 to D257) and `load-data`'s `pg_cron`
clean-up (spec D258), written into G10, chunks 15 to 18 and 20 and the
release gate; v8 chunk 14's readings of f1, f2 and f5 (spec
D244 to D247) written into chunks 14, 16 and 17; v7 chunk 15a's readings
of f7 and f9 (spec D239 to D243) written into chunks 15, 16 and 17 and
the release gate; v6
(2026-10-30) the owner's ruling on G10, `reporting`'s
memory limit raised to 640M (spec D227), written into G10, chunks 13, 15
and 16 and the release gate; v5 the owner's ruling on G12, the web front in
every game (spec D224, applied by D225), written into chunk 19, now split
19a and 19b with 19b cut after chunk 2, chunk 18 and the waves; spec D226,
a data file named in a seed change, into chunk 15a; v4 wrote `bastion`
0.4.0 (spec D221 to D223) as chunk 19; v3 capture W1's corrections (spec
D219, D220); v2 the rulings on G8 and G9 (spec D217, D218), after
approval with κ = 3 (spec D216).
Approval: **approved 2026-10-30 by the owner** (G1, spec D216).
Written from: [master-spec.md](master-spec.md) and
[access-model.md](access-model.md), approved 2026-10-30 (spec D215),
with the owner's rulings spec D211 to D214 written in.
No design set (no interface to design, spec D2).

The model is `~/.local/share/dev_team/references/build-plan-model.md`; this
plan states only its deltas. Its conventions follow v0.3's
[build plan](../../archive/v0.3/build-plan.md).

## Read first

- **Baseline.** v0.3's code on `main` (merge cba7be3; `main` at 6d6abb1
  when this plan was written): `postgres` and `bastion` at 0.3.0,
  `prometheus`, `postgres-exporter` and `grafana` at 0.2.0, `scheduler`
  and `pgbouncer` at 0.1.0, `tools/gm/`, the three skills, nineteen
  catalog faults, the scenarios `tarnbeck-outdoor-shop`,
  `bookshop-new-server` and `fernway-clinics-monitoring`, the fixtures
  `fixture-audit`, `fixture-mounted`, `fixture-monitoring`,
  `fixture-load` and `fixture-v03-refusals`. v0.3's wave-log captures W1
  to W4 ([../v0.3/wave-log.md](../v0.3/wave-log.md)) still fix the
  `gmctl` command lines, the bricks' paths and `brick.yaml` keys, the
  scheduler's runtime interface and the fixtures' shape. A chunk that
  changes one of them says so, and the wave driver records the new shape
  as a v0.4 capture.
- **No intent register and no data register** (no `.atd`, no `intent/`,
  no `data-register/`; checked 2026-10-30), and every scenario's data is
  synthetic. So there is no `documentalist` wave preflight, capture or
  sync, and no `data-steward` preflight or sync. Where a chunk names an
  **Architecture capture**, the wave driver records it in the wave log
  (`W<n>-<letter>`) on the wave branch before the chunk that depends on
  it starts, as in v0.1 to v0.3. Every chunk's **Atoms** and **Data**
  lines are therefore "none" and are left out below.
- **Dependency gating applies.** The project keeps a `.tech` file, kept
  by `security-advisor`. `postgres` 0.4.0 adds two packages, so its
  chunk waits for a dependency preflight (G5) and is followed by a
  post-change check (G6); `bastion` 0.4.0 adds one, `cmark-gfm` (G13,
  then G6); `scheduler` 0.2.0 adds none.
- **One version per brick in the catalog.** The loader refuses a pin that
  does not match the brick's `version`. Chunk 1 bumps `postgres` to
  0.4.0, `scheduler` to 0.2.0 and `bastion` to 0.4.0 (spec D221), adds
  the new version to every fault's `applies_to` that names `postgres` or
  `scheduler` (seven each; none names `bastion`), and re-pins the three
  scenarios and the four fixtures that pin any of them, in the same
  commit; every later v0.4 change to any of the three folds into that
  version, a brick version being released only by v0.4's release gate.
  `pgbouncer` takes 0.1.1 by chunk 21, which fixes its start-up race and
  re-pins it in the same commit (spec D305); `prometheus`,
  `postgres-exporter` and `grafana` are unchanged and keep their
  versions.
- **The web front runs in every game** (spec D224, replacing v0.2's
  D103): the bastion always publishes port 8080 and the tools password
  is always handed over, a web interface to publish or not; its home is
  the starter-pack page. Chunk 19 builds it. Until 19b merges, v0.3's
  rule still holds in the loader, the scenarios and `smoke.sh`'s
  `fixture-audit` assertions (port 22 only, the front down, no
  tools-password line), which 19b reverses; render is unchanged, and the
  GM skill's lines saying otherwise are chunk 18's.
- **Templates are the loader's schema**, as in v0.3: `tools/gm/model.py`
  checks every definition against the format skill's templates, and the
  unit suite loads every folder under `bricks/`, `faults/` and
  `scenarios/`; from chunk 2 also `purposes/` and `domains/`.
- **Approved with the spec, and easy to miss** (spec D211 to D215):
  - `postgres` 0.4.0 gets **no report-only write policy** and no
    `cron.allow`; every database node stays fixable, `reporting` is the
    agency's by the story and the answer key alone, and an overstep is
    judged in the feedback, never credited (master spec 7.2, 16.5);
    `bi`, a scheduler node, keeps the report-only policy its brick
    enforces;
  - `shop_etl` reads `orders` without `customer_id` (a column grant), and
    `reporting`'s foreign tables declare only the columns the close needs
    (9.6, 9.7);
  - the baseline jobs judge consent by the latest consent event, never
    the opt-in flag (9.3, 10.2, 10.3);
  - a node's crontab roles are declared in `scenario.yaml` as
    `crontab_roles`, their secrets mounted for the password file (6.1,
    7.2);
  - f9's planting is a second foreign server, a foreign table, the churn
    table and a `pg_cron` job, and its check requires all of them gone
    (16.2);
  - f10 is an order-level roll-up calling a procedure from `reporting`'s
    crontab as `bi_etl`; a failed f10 is never re-planted within the
    aging (16.3);
  - f7 is expected to stay present in a game: its job is on `bi`, which
    the players cannot move (16.1, 16.5);
  - the gateway stub never acknowledges about one declaration in fifty,
    as standing behaviour (10.4);
  - the rehearsal runs without f10, by a harness-only override (18).
- **No fake time, and nobody triggers a job.** No chunk or test may speed
  up, freeze or forge a clock (master spec 8.4). A smoke cycle moves a
  job's time and reloads its runner, as a player may (an edit of
  `jobs.yaml`, of a crontab through `gm-crontab`), the harness doing it
  as root on a report-only node too; it never runs a job by hand (a
  `CALL`, a crontab entry's command typed in a shell).
  The rehearsal reaches its hand-over early through v0.3's test-harness
  override of the aging minimum (spec D161): it shortens the wait, never
  a clock.
- **Build host** (observed 2026-10-30): armenelos, a laptop, 12 CPUs,
  11 GiB of memory with about 3.1 GiB available, 11 GiB of swap with
  4.2 GiB in use, 10 GB free on `/`; `shellcheck` not installed. v0.3's
  build found it suspends when left idle (wave log, chunk 15b): long
  runs hold a sleep inhibitor ("Workflow deltas"). The new scenario
  reserves about 1.85 GB, and f10 deliberately exhausts a node's memory
  there (master spec 20).
- **What v0.3's build taught** ([../v0.3/wave-log.md](../v0.3/wave-log.md)):
  docker-using checks are serialized by the host lock; a fresh GM session
  reading `.claude/skills/game-master/` plays the GM at the gates,
  verifier agents play as `player` through the bastion only, GM-side
  checks run from the host; findings outside a chunk's Files line are
  fixed on the wave branch by a `coding-executor` in their own commits;
  the auto-mode classifier may refuse a step on the VPS, which the owner
  then runs.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | Plan approval | The owner | Wave 1 | done (2026-10-30, spec D216) |
| G2 | [formats.md](../../formats.md) carries master spec 6: the purpose and the domain, `governance:`, the new scenario, answer-key, fault and brick fields, the optional crontab and `crontab_roles` (section 19: the format skill is updated after it) | `spec-writer` | Chunk 1 | done (2026-10-30, cf484b9; formats.md v22) |
| G3 | Network access at image build time: Debian 13's repositories (`cron`, `cmark-gfm`), the PostgreSQL apt repository (`postgresql-18`, `postgresql-18-cron`), the s6-overlay release, as in v0.3 | Hand check by the wave driver | Chunks 1, 3, 4, 19 (image builds); every wave gate's builds | open |
| G4 | A Docker host in swarm mode: armenelos' swarm, the VPS a drained worker in it | Hand check by the wave driver | Every stack test, deployment and smoke run, chunk 9, every wave gate, the release gate | open |
| G5 | **Dependency preflight** on `postgres` 0.4.0's new packages: the candidate versions of `postgresql-18-cron` (PGDG) and of Debian's `cron` with what it pulls in, installed without recommends (master spec 7.2, 19). A finding the owner must rule on becomes a gate of its own | `security-advisor` (skill `dependency-check`), called by the wave driver at wave 1's start | Chunk 4's branch | done (2026-10-30, wave log) |
| G6 | **Dependency post-change check** on the versions chunks 4 and 19 resolved, and `.tech` updated (`postgres` 0.4.0, `scheduler` 0.2.0, `bastion` 0.4.0, the three packages), committed on `v0.4-w1` | `security-advisor`, called by the wave driver once chunks 4 and 19 have merged | Wave 1's gate | done (2026-10-30, 71ab68a) |
| G7 | The VPS ready for two-host runs, under the VPS rule ("Workflow deltas"): `tailscale status` on both hosts; the VPS still a worker of armenelos' swarm, drained; no game port published on it; at least 5G free; filetstudio.com answering before and after | Hand check by the wave driver | The two-host `smoke-load.sh` of waves 2 and 3's gates; no later v0.4 run, every two-host session being v1.0 gating (spec D311) | checked at wave 2's gate (2026-10-30, 23:11–23:20 UTC); repeated at each later two-host run |
| G8 | **The judged moment before the hand-over** (master spec 12.1): before the hand-over (the early check, the hand-over check, the smoke runs), a purpose check judges from the fault instance's planting moment, raised to the runner's last reload, as after it | The owner | Chunk 8's merge; the "Done when" of chunks 10, 11, 14, 15 as far as they read a check before a hand-over | done (2026-10-30, spec D217) |
| G9 | **f10's measurement without swap, on armenelos only** (master spec 16.3): a one-off calibration container with its swap disabled for it alone, outside Swarm; armenelos keeps its swap | The owner | Chunk 9's no-swap measurement | done (2026-10-30, spec D218) |
| G10 | **f10's calibration outcome** (spec D213): the backfill needs more than twice `reporting`'s limit and a normal run less than half of it, after `shared_buffers`, within a window the restored history allows. Ruled on chunk 9's shortfall at 512M (a normal run's `memory.peak` over half the limit): `reporting`'s limit raised to 640M, its reservation 256M; the window as designed, the thirty-day request; chunk 15b re-measures at 640M. Ruled on 15b's shortfall at 640M (a normal run 327 MiB): accepted as measured, no criterion change, no re-run (spec D252) | Chunk 9's figures, applied by the wave driver; the owner on a shortfall | Chunk 15's f10 half; chunk 16 | done (2026-10-30, spec D227; 15b's figure accepted 2026-10-31, spec D252) |
| G11 | The owner's judgement at release close: the smoke cycles as run (spec D310), f10's run, the named known limits and what moved to v1.0 gating (spec D311) | The owner | Release close | done (2026-11-03, the owner: "G11 ok") |
| G12 | **spec O134**: does the starter-pack page make the web front run in every game (master spec 7.3, 22)? Ruled yes: the front in every game, its home the page, nothing more in v0.4; chunk 19 split, 19b taking the loader's port rule and the scenarios without a web interface | The owner | Chunk 19's branch | done (2026-10-30, spec D224) |
| G13 | **Dependency preflight** on `bastion` 0.4.0's new package: the candidate version of Debian 13's `cmark-gfm` with what it pulls in, installed without recommends (spec D222). A finding the owner must rule on becomes a gate of its own | `security-advisor` (skill `dependency-check`), called by the wave driver | Chunk 19's branch | done (2026-10-30, wave log) |

G8 and G9 were questions this plan raised on the approved spec; the
owner ruled both at its approval (spec D217, D218). G12 and G13 came
with the owner's ruling of spec D221, during wave 1.

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3, 4, 5, 19 | G1 (done); G2 (chunk 1, done); G3, G4; G5 (chunk 4); G12, G13 (chunk 19); G6 before its gate | gated (2026-10-30, 4064719) |
| 2 | 6, 7, 8, 9, 10, 11 | wave 1; G8, G9 (done); G7 (the gate's two-host run) | gated (2026-10-30, f35dd40) |
| 3 | 12, 13, 14, 15, 20 | wave 2; G10 (chunk 15's f10 half, done) | merged (gate passed 2026-10-31, 5e8eb84) |
| 4 | 16, 17a, 18, 21 (17b moved to v1.0 gating, spec D311) | wave 3 | gated (2026-11-03, 59dc743; armenelos-only, D311/D312) |

```
1 ──> 2, 3, 4, 19      (in wave 1, cut once chunk 1 has merged into v0.4-w1; W1)
1 ──> 5                (in-wave: runs beside chunk 1, its files all under domains/shop/; W1)
G5 ──> 4
G12, G13 ──> 19
2 ──> 4                (in-wave, merge order only: chunk 2a merged into v0.4-w1 before chunk 4 merges; W1 items 4, 9)
2 ──> 19b              (in-wave: 19b edits tools/gm/model.py and test_model.py after chunk 2 has merged; spec D225)
1, 2 ──> 6
2, 4 ──> 7
6 ──> 7                (in-wave: render's crontab shift and crontab_roles' secrets, fixed by master spec 14; W2)
2 ──> 8
4, 5 ──> 9
3, 5 ──> 10
3, 5 ──> 11
3, 4, 7 ──> 12
5, 6, 7, 10, 11, 19 ──> 13
2, 7, 8, 10, 11 ──> 14
13 ──> 14              (in-wave: the fixture's nodes, roles and jobs, fixed by master spec 16.1; W3)
4, 6, 7, 9, 10 ──> 15
13, 12 ──> 15          (in-wave: the fixture, and the governance set's call interface; W3)
12 ──> 20              (in-wave: chunk 12 merged; chunk 20 extends its G1, spec D253)
13, 14, 15 ──> 16
16 ──> 17              (in-wave: the scenario's instances and the jobs the harness moves; W4)
21 ──> 17              (in-wave, merge order only: 17a's runs after its branch merges v0.4-w4 in, on pgbouncer 0.1.1; spec D305)
8, 9, 12, 20 ──> 17
6, 7, 8, 14, 15 ──> 18
```

Wave 1's order: chunks 1 and 5 run first, side by side; chunks 2, 3, 4
and 19 are cut from `v0.4-w1` once chunk 1 has merged (chunk 4 once G5
is cleared too, chunk 19 once G12 and G13 are), three at a time, so no
two chunks running at once share a file. Chunk 4 is built beside chunk
2 but merges only after chunk 2a has: the `crontab` entry it adds to
`seed.files` fails every scenario pinning `postgres` until 2a's
`seed.optional` check is in, so it merges `v0.4-w1` in before its final
suite run (spec D220). **Chunk 19** (spec D225): its branch is cut at the
first free slot, and 19a, the bastion, is built beside chunks 2 to 4
(no shared file); 19b starts only once chunk 2, both halves, has merged
into `v0.4-w1` and chunk 19's branch has merged `v0.4-w1` in, since it
edits chunk 2's `tools/gm/model.py` and `test_model.py`; both halves'
unit-suite runs come after that merge-in (`data-policy.md` in
`seed.files` needs 2a's `seed.optional` check, spec D223), and chunk 19
merges after 19b. The chain 1, 2, 19b is a file order, not an
interface: 19b changes v0.2's port rule, which chunk 2 leaves as it is.
Chunk 1 owns the version lines of `postgres`, `scheduler` and
`bastion`; chunks 3, 4 and 19 own the rest of their brick. Chunk 19 was
inserted after wave 1's capture; it uses W1 item 4 and needs no capture
of its own, and with no intent register there is no `documentalist`
peek to run before it.

Wave 2: chunks 9, 10 and 11 need only wave 1, and chunk 9 runs as early
in the wave as the host lock allows: it is the early calibration spec
D213 asks for, and its outcome (G10) must be known before wave 3's f10
work. Chunk 7 is cut once chunk 6 has merged.

Wave 3: chunks 12 and 13 run first; chunks 14 and 15 are cut once chunk
13 has merged (chunk 15 once chunk 12 has too). Chunk 20 was inserted
after chunk 12 merged (spec D253): fix-sized, cut from `v0.4-w3` at the
first free slot and handed by the driver to a `coding-executor`, it
shares no file with 15b and merges before wave 3's gate. With no intent
register there is no `documentalist` peek to run before it.

Wave 4: chunk 21 was inserted while 17a was paused (spec D305): fix-sized,
cut from `v0.4-w4` at the first free slot and handed by the driver to a
`coding-executor`, it shares no file with 17a and merges before wave 4's
gate. 17a's branch merges `v0.4-w4` in once chunk 21 has merged, so its
remaining runs use `pgbouncer` 0.1.1. 17b, the rehearsal and its
figures, left v0.4 for v1.0 gating (spec D311). No `documentalist`
peek, as for chunk 20.

## Workflow deltas

- **κ = 3**, confirmed by the owner for v0.4 (spec D216), as in v0.3: chunks with no path between them run side by side, each in its
  own worktree. Docker-using checks (image builds, stack tests,
  deployments, smoke runs, the calibration, the rehearsal) are serialized
  by the host lock, `flock /tmp/dbagm-docker.lock <command>`. Chunk 9,
  chunk 15's f10 run, chunk 17's runs and the release gate hold the lock
  for their whole duration and run alone on the hosts.
- **Sleep inhibitor.** armenelos is a laptop and suspended during v0.3's
  build. Every docker run longer than a few minutes (a stack test series,
  a deployment, the calibration, a smoke run, the rehearsal, a wave gate,
  the release gate) runs under `systemd-inhibit --what=sleep:idle:handle-lid-switch`,
  held by the script itself where it is committed (as `rehearsal.sh`
  does) or by the wave driver around it, and released after.
- **The VPS** (spec D159, D209): the driver and its agents may work on it
  (`ssh vps`, `ssh://dbagm-vps` for the playground), never disturbing the
  applications it already hosts; filetstudio.com stays up throughout. Its
  own documentation is read before any change there; each session
  touching it checks `tailscale status` on both hosts first. A swarm
  membership change on the VPS is a downtime scheduled with the owner,
  never done unannounced. The VPS node **stays `drain`**; only a two-host
  run (a wave gate's two-host smoke run; none after wave 3's gate in
  v0.4, every two-host session being v1.0 gating, spec D311) sets it `active`, inside that run's host lock, and
  drains it again after, pass or fail (`docker node update
  --availability active|drain vps-5718ad52`, run by the owner if the
  auto-mode classifier refuses). **Never for f10**: chunk 9's
  calibration, chunk 15's f10 run, f10's smoke run and every run moving
  f10's job happen on armenelos alone, with the VPS drained. From chunk
  8, every playground declaration naming the VPS marks it `shared`
  (`--host vps-5718ad52,shared,endpoint=ssh://dbagm-vps,…`).
- **Never `docker * prune`** (`system`, `image`, `container`, `volume`,
  `network`, `builder`) on either host: superseded `dbagm` images are
  removed by name (`docker image rm 127.0.0.1:5000/dbagm/<brick>:<old>`)
  when the disk runs short, and nothing else is removed on the VPS.
- **Branches and worktrees**: waves `v0.4-w<n>` in
  `/home/bastien/work/db_audit_gm-wt/v0.4-w<n>`; chunks
  `v0.4-c<id>-<slug>` in `/home/bastien/work/db_audit_gm-wt/v0.4-c<id>-<slug>`.
  Never in the main checkout.
- **Shared lists**, under the model's in-wave rule: `tools/gm/__init__.py`'s
  verb and option registrations, `.claude/skills/game-master/gmctl.md`'s
  verb table, the root `README.md`'s brick, fault, purpose and domain
  tables, the bricks' "Supported faults" sections in `docs/gm.md` (chunks
  14 and 15 both add to `postgres`'), and the smoke scripts' `IMAGES=`
  lists.
- **Chunk checks**, in addition to the model's:
  - Python: `python3 -m unittest discover -s tools/tests -t .`;
  - the scheduler program's unit tests, run inside its image:
    `sh bricks/scheduler/tests/run-unit-tests.sh`;
  - Python outside both suites (transformer scripts, purpose and fault
    checks written in Python): `python3 -m py_compile` on every file the
    chunk touches;
  - shell: `sh -n` on every shell file the chunk touches, those without an
    extension included (s6 `run` files, `rootfs/usr/local/sbin/*`,
    `rootfs/usr/local/lib/gm/*`, fault and purpose check scripts);
    `shellcheck` too when installed;
  - Perl: `perl -c` on every Perl file the chunk touches;
  - YAML: every YAML file the chunk touches loads with PyYAML;
  - SQL: a data file, schema or material the chunk adds runs into the
    `postgres` image at its current tag, in a throwaway container under
    the host lock;
  - a chunk touching a brick: `docker build -t
    127.0.0.1:5000/dbagm/<brick>:<version> bricks/<brick>` and its stack
    test, `sh bricks/<brick>/tests/run-stack-test.sh` (needs G4);
  - a chunk changing a scenario's or fixture's `scenario.yaml` or
    `gm/answer-key.yaml`: its `README.md` regenerated with the
    scenario-document skill in the same commit;
  - a chunk adding or changing a `gmctl` invocation in a Markdown file:
    the invocation parses with `gmctl`'s own parser.
- **Wave gate (full quality command)**, every step under the host lock and
  the sleep inhibitor, at κ = 1 for the gate itself: the full unit suite;
  the scheduler's unit tests; `sh -n` on every shell file, `perl -c` on
  every Perl file, `py_compile` on every Python file outside the suites;
  all seven bricks' image builds and stack tests; `sh tools/tests/smoke.sh`;
  `sh tools/tests/smoke-monitoring.sh`; `sh tools/tests/smoke-scenario.sh`
  on `bookshop-new-server`, `fernway-clinics-monitoring` and
  `tarnbeck-outdoor-shop`, v0.3's smoke runs unchanged on the new
  versions (master spec 16.4); `sh tools/tests/smoke-load.sh` on armenelos
  alone, and at waves 2 and 3 on armenelos plus the VPS (G7; the VPS
  `active` for that run only, declared `shared`; wave 4's two-host run
  is v1.0 gating, spec D311); from wave 3, chunk 13's
  deployment of `fixture-campaign` with every job running and G1 to G4
  passing; from wave 4, on the new scenario on armenelos alone,
  `tools/tests/smoke-purposes.sh`'s `smoke` (every fault planted at
  once, its first live run, serving release gate item 8's single-host
  half too), run up to f8's wait and stopped there, f8's reading moved
  to v1.0 gating with the rest of the long-running tests (spec D312);
  `baseline` (G1 to G4, about 31 minutes) and `f10` (about 6 minutes);
  with no pooler WORKAROUND line (spec D305); not `cycles`: its part up
  to f4's wait for the scenario's midnight is chunk 17a's run, accepted
  by spec D310, not repeated at the gate, the rest v1.0 gating (spec
  D312).
- No link checker is configured; Markdown links are checked by reading.
- Images are tagged `127.0.0.1:5000/dbagm/<brick>:<version>`, as before;
  every pinned download is checked against its published checksum in the
  Dockerfile.
- The release gate runs on `v0.4-w4` before it merges, as v0.3's did.

## Measurements and hand checks

- G3, G4 and G7: hand checks by the wave driver, G3 and G4 before wave 1,
  G7 before wave 2's gate; G7 under the VPS rule (`tailscale status` on
  both hosts first, filetstudio.com answering before and after).
- G5 and G6: `security-advisor`'s dependency checks, recorded in the wave
  log; `.tech` updated on `v0.4-w1`.
- Each bumped brick's footprint at rest: in its chunk's stack test
  (chunks 3, 4, 19), as a first figure.
- f10's calibration: chunk 9, on armenelos alone, the VPS drained, under
  the host lock: the `reporting` container's `memory.peak` around a
  normal run and around the backfill, with swap (a Swarm service at the
  scenario's limit) and without (a one-off container with its swap
  disabled, G9), with machine and date; G10 applies
  them.
- f10's incident for real: chunk 15 on `fixture-campaign`, then chunk 17
  and the release gate on the scenario, armenelos alone. Chunk 15b's run
  re-measures G10's criterion at `reporting`'s 640M limit (spec D227),
  recorded with machine and date: a normal run 327 MiB (238 without
  page cache), accepted as measured (spec D252); the backfill killed.
- Every node's memory at peak, `reporting`, `bi`, `crm` and `gateway`
  included; the trace's growth per hour, extrapolated over the
  sixteen-hour aging and stated as an extrapolation: the rehearsal's,
  v1.0 gating with it (spec D311). In v0.4, chunk 17a's per-node memory
  readings on armenelos (wave log, "Chunk 17a — merged") are one-host
  smoke readings, quoted in the release notes, not footprints.
- No aged run (spec D193): none is planned before v1.0.

## Left for the build (master spec 22)

Each item is settled by the chunk named, recorded in its **Record** line
and, where it is a brick's, in the brick's `docs/gm.md`; the release gate
checks that each is recorded.

| Item | Chunk |
|---|---|
| Every footprint, the new nodes' starting sizes, the trace's growth per hour | 3, 4 (at rest); the starting sizes as chunk 16 set them; the rehearsal's figures v1.0 gating (spec D311) |
| f10's backfill window | 9 (G10) |
| The gateway's acknowledgement delay and how the unacknowledged one in fifty is chosen | 11 |
| The gateway outage's moment, and the timeline moments of f2 and f8 within the aging | 14 (the faults' definitions), 16 (the scenario) |
| The `etl_runs` columns each job fills; the payload schemas of the two outboxes | 5 (the tables), 10, 11 (the jobs) |
| The mapping-roles function's name and the read policy's form | 7 |
| Where the governance check set lives and how a fault's check calls it | 12 |
| The scheduler-side means a purpose check uses to read runs, the last reload and the next run | 3b |
| The starter-pack page's paths and form, and how a later element joins it | 19 |

## Chunks

### Chunk 1 — Format skill, templates, the v0.4 versions and the re-pins

Status: merged (w1, 48dc5c3)
Wave: 1
Depends on: G1, G2; G3, G4 (the two images at their new tags)
Architecture capture: recorded by the wave driver at wave 1 start (W1),
for chunks 2 to 5:
- the template keys of master spec 6.9 and where each sits: `purposes:`
  with each part's mapping, `domain:`, `governance:` (`policy`,
  `classes` with `locations`, `readers`, `outbound` with `to` and
  `fields`, `separation`), a node's `crontab_roles`, the answer key's
  `judges` and `threshold`, the fault's `applies_to.purposes`,
  `sealed_check.judges` and `needs_unshared_host`, the brick's
  `seed.optional`;
- the purpose and domain layouts (6.7, 6.8), the keys of `purpose.yaml`
  and `domain.yaml`, and the shape of `classification.yaml`;
- the transformer script's repository entry and a script job's
  `connections:` (7.1), the `scripts/` seed entry;
- `postgres` 0.4.0's new `brick.yaml` entries as chunk 4 is to build
  them: the optional seed `crontab` and its live path, the volume
  `cronspool` (snapshot `copy`), `gm-crontab` in the sudoers, the crontab
  roles' secrets (`role_<role>_password`) and the password file's path,
  the cron log directory on `pglog`.

- Goal: v0.4's formats in the format and scenario-document skills, the
  three bumped bricks at their v0.4 versions, every pin and `applies_to`
  brought to them, the suite green.
- Scope: in:
  - **1a, versions and the brick and fault formats**: `postgres` 0.4.0,
    `scheduler` 0.2.0 and `bastion` 0.4.0 (`brick.yaml`'s version and
    image lines, the Dockerfile's build comment, `docs/gm.md`'s version
    lines and image tags, the stack tests' tags); the seven faults
    applying to `postgres` and the seven applying to `scheduler` given
    the new version in `applies_to`; `tarnbeck-outdoor-shop` re-pinned
    to all three, `bookshop-new-server` and `fernway-clinics-monitoring`
    to `postgres` 0.4.0 and `bastion` 0.4.0, the fixtures
    `fixture-audit`, `fixture-load`, `fixture-monitoring` and
    `fixture-v03-refusals` likewise, otherwise unchanged; their READMEs
    regenerated; the templates `brick.yaml` (`seed.optional`, the
    `transformer` role), `fault.yaml` (`applies_to.purposes`,
    `sealed_check.judges`, `needs_unshared_host`, the `governance-*` and
    `security-*` ids in the Security family, `data-flow` and `rules` for
    purpose faults, the aging minimum counted from the job's first run
    after planting), `brick-gm.md` (a section per database-node job
    kind), `layouts.md` (`purposes/`, `domains/`, `scripts/`, the
    crontab); the skill's brick and fault rules;
  - **1b, the scenario, purpose and domain formats**: the templates
    `scenario.yaml` (`purposes:`, `domain:`, `governance:`, several
    `postgres` nodes, `crontab_roles`), `answer-key.yaml` (`judges`,
    `threshold`, no window; a tooling expectation naming an unmonitored
    instance), `queries.yaml` and `jobs.yaml` (the script entry,
    `connections:`, `at`'s comment stating W1 item 0's cron subset),
    `schedule.yaml` (`streams` may be `[]`: a node with fixed-time
    operations only), and new templates `purpose.yaml`, `domain.yaml` and
    `classification.yaml`; the skill's completeness rules for a purpose
    and a domain, for `governance:` and the policy file (written by the
    GM from `governance:`, in the story's voice, correct, unchecked rules
    stated unmarked, mapped to the bastion's optional seed file
    `data-policy.md`), every `database` node of a scenario with
    `governance:` admitting the GM check role from the game network in
    its seed `pg_hba.conf` under the DO NOT TAMPER comment, the optional
    crontab with its `crontab_roles`, `pg_cron` turned on by the seed
    and the data file, `{{customer_timezone}}` in scheduler seed files
    and `cron.timezone`, the crontab written in scenario time, the
    placement guideline (8.7), a second instance's exporter (13.4), the
    starter pack naming every job the players may move; the
    scenario-document skill: the purposes a scenario uses, its governance
    and policy file, its database-node jobs.
  - Out: any loader, renderer or image change (chunks 2, 4, 6); the
    bricks' features (chunks 3, 4).
- Files: `.claude/skills/scenario-format/SKILL.md`,
  `.claude/skills/scenario-format/templates/{brick.yaml,brick-gm.md,fault.yaml,layouts.md,scenario.yaml,answer-key.yaml,queries.yaml,jobs.yaml,schedule.yaml}`,
  `.claude/skills/scenario-format/templates/{purpose.yaml,domain.yaml,classification.yaml}`
  (new), `.claude/skills/scenario-document/{SKILL,template}.md`;
  `bricks/{postgres,scheduler,bastion}/brick.yaml` and `docs/gm.md`
  (version lines and tags only), `bricks/bastion/Dockerfile` (its build
  comment only), `bricks/{postgres,scheduler,bastion}/tests/{run-stack-test.sh,stack.test.yml}`
  (tags only); the fourteen `faults/*/fault.yaml`;
  `scenarios/{tarnbeck-outdoor-shop,bookshop-new-server,fernway-clinics-monitoring}/{scenario.yaml,README.md}`;
  `tools/tests/fixtures/fixture-{audit,load,monitoring,v03-refusals}/`
  (pins and READMEs); the unit tests and smoke scripts naming the old
  tags, as the build finds them; the root `README.md`'s tables.
- Spec sections: master spec 5, 6, 7.1 (the repository entry), 7.2 (the
  seed and the crontab), 7.3 (the bastion's version), 8.5, 8.7, 11.3, 11.5, 13.4, 14 ("The format
  skill", "The scenario document skill"), 16.4, 19;
  [formats.md](../../formats.md) after G2; spec D206, D207, D211, D215.
- Done when: every template carries every item master spec 6 requires
  and loads as YAML; the loader, unchanged, loads every brick at its
  version, every fault, the three scenarios and the fixtures; the unit
  suite (with `test_brick_docs`) passes; the three images build at their
  new tags and their stack tests pass; every README matches a fresh
  regeneration.
- Verification: chunk checks.
- Split rule: 1a versions, re-pins and the brick and fault formats; 1b
  the scenario, answer-key, purpose and domain formats and the
  scenario-document skill. Each half leaves the suite green.

Record: 1a fb61d48, 1b 667ded1, merge 48dc5c3. No departure from the spec; choices logged as "W1 addenda — choices chunk 1 made" in the wave log. A purpose fault editing a data file (6.3) left open, sent to `spec-writer`.

### Chunk 2 — Loader checks for v0.4

Status: merged (w1, 5767878)
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; W1
Architecture capture: none of its own; it implements W1.

- Goal: the scripts refuse what master spec 6 and 14 say the loader
  refuses, with the list of what is missing or wrong.
- Scope: in:
  - **2a**: scenarios: `purposes:` (each purpose exists under
    `purposes/`; every part mapped to a node of the right role and, for
    `source` and `target`, a database its data file creates; every job's
    key and name existing on the mapped runner); `domain:` naming a
    domain under `domains/`; `governance:` (every class named defined,
    every location a `database` node and a database its data file
    creates, every reader a role a data file creates, the policy file
    present and mapped to the bastion's `data-policy.md` seed file, a
    scenario without `governance:` mapping none, spec D223); faults: `applies_to.purposes` naming existing purposes,
    `sealed_check.judges` one of `runs`, `triggers` or absent,
    `needs_unshared_host` a boolean; answer keys: `judges` with a
    `threshold` and no window; bricks: `seed.optional` among the seed
    files; the unit suite loading `purposes/` and `domains/` as it loads
    bricks and faults;
  - **2b**: `scheduler` 0.2.0's files: a script key's file and function
    existing, a stream naming a script key refused, a script key's job
    naming `connections:` (each a connection of the schedule) and no
    `connection:`, any other job the reverse; `postgres` 0.4.0's
    optional `crontab`, a seeded crontab requiring `crontab_roles`, each
    a role a data file of the node creates, `crontab_roles` without a
    crontab refused; a data file creating `pg_cron` only on a node whose
    seed `postgresql.conf` preloads it, `cron.database_name` naming a
    database that data file creates; `jobs.yaml`'s `at`, a seeded
    crontab's entries and a purpose job's `cadence` in W1 item 0's
    subset;
  - refusal fixtures and unit tests for each.
  - Out: rendering any of it (chunk 6); `fit` (chunk 8).
- Files: `tools/gm/model.py`, `tools/tests/test_model.py`,
  `tools/tests/fixtures/fixture-v04-refusals/` (new).
- Spec sections: master spec 6.1 to 6.4, 6.9, 7.1, 7.2, 7.3, 10.3 (P3's
  cadence), 11.5, 14 ("The loader"), 20; spec D219, D223.
- Done when: unit tests show each refusal with its message, and the
  acceptance of a valid fixture; every catalog definition still loads;
  the unit suite passes.
- Verification: chunk checks.
- Split rule: 2a scenario, fault, answer-key and brick checks with
  purposes, domains and governance; 2b the scheduler's script keys and
  the `postgres` crontab and `pg_cron` checks, and the cron subset.

Record: 2a adaa457 (merge 6e50d70), 2b 8630345 (merge 5767878). No departure from the spec; one loader fix outside the listed checks (`_inline_comment` and apostrophes, only `purpose.yaml` `parts.consumer` changed, to optional); choices logged as "W1 addenda — choices chunk 2 made".

### Chunk 3 — `scheduler` 0.2.0

Status: merged (w1, b34d375)
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; W1; G3, G4
Architecture capture: none of its own; it records as built, as W1-y
(read by chunks 10, 11, 12, 14): the script call and its log lines, the
scripts' digests in `/run/scheduler/loaded`, and the means a purpose
check uses on the node.

- Goal: the job runner of master spec 7.1, extended, not forked:
  transformer scripts and the `transformer` role, and what a purpose
  check reads on a scheduler node.
- Scope: in:
  - **3a, the transformer script**: the fifth repository form
    `{script: scripts/<file>:<function>, options}`; the optional seed
    entry `scripts/`, read by the players and fixable where the
    repository is, as `builders/` are; a script key's job naming
    `connections:`, checked by the program and its `check` verb; the
    call `<function>(conns, options, log)`, each connection open as the
    schedule's role for it, autocommit off, the script committing and
    returning the rows it wrote; `script job=<name> <text>` lines; the
    run in a worker thread, the next skipped while one is going; an
    exception ending the run with `status=error` (`sqlstate=` or
    `error=`); the scripts' digests in `/run/scheduler/loaded` and in
    `pending`; the `transformer` role in `brick.yaml`; unit tests (rows
    moved between two databases as two roles, an exception, a skipped
    run, a stream refused on a script key);
  - **3b, what the checks read, the documentation and the stack test**:
    a root-only means beside `check-sql` (its form the chunk's, recorded
    in W1-y) giving a job's completed runs since a moment from the log,
    the runner's last `reload status=ok`, and a job's next run in the
    loaded `jobs.yaml` by the program's own cron parser (12.1, 12.2);
    `docs/player.md` (scripts, connections, moving a job to verify a
    fix) and `docs/gm.md` (the script contract, the role, the means
    above, footprint); the stack test: a transformer node running a
    script job between two databases, its run lines, the means' answers;
    the footprint at rest.
  - Out: any package (none added, master spec 19); the purposes'
    material (chunks 10, 11).
- Files: `bricks/scheduler/program/gm_scheduler/{repository,jobs,runner,policy,textlog,__main__}.py`
  and a new module for scripts if the build wants one,
  `bricks/scheduler/{brick.yaml,docs/gm.md,docs/player.md}`, a new
  helper under `bricks/scheduler/rootfs/usr/local/lib/gm/`,
  `bricks/scheduler/tests/unit/{test_program,test_parts}.py`,
  `bricks/scheduler/tests/fixtures/scripts/` (new),
  `bricks/scheduler/tests/{run-stack-test.sh,stack.test.yml}`.
- Spec sections: master spec 6.5, 7.1, 12.1, 12.2, 20; access model 4,
  5, 8, 12.
- Done when: the unit tests show each item of 3a; the image builds and
  its stack test passes; the loader accepts the brick; `test_brick_docs`
  passes; v0.3's schedulers behave as before (tarnbeck's smoke run at the
  wave gate).
- Verification: chunk checks, plus the scheduler's unit tests and its
  stack test (needs G4).
- Split rule: 3a the script form, the call and the run; 3b the checks'
  means, the documentation and the stack test.

Record: 3a 7536550, 3b 1b5d7ba, merge b34d375. No departure from the spec; outcome recorded as capture W1-y in the wave log (the `script` log line free text after `job=`, a fourth `check-runs` verb `since`). Tarnbeck's smoke run left for the wave gate.

### Chunk 4 — `postgres` 0.4.0

Status: merged (w1, da6d300)
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; chunk 2a, merged into `v0.4-w1` before this chunk merges (in-wave,
W1 item 9: this chunk takes `v0.4-w1` in before its final suite run);
W1; G5 cleared before the branch is cut; G3, G4
Architecture capture: none of its own; it records as built, as W1-x
(read by chunks 6, 7, 9, 12, 15): the cron service, the crontab's and the
password file's paths, `gm-crontab`'s form, `check-psql`'s other-node
form.

- Goal: the database brick of master spec 7.2: jobs on a database node,
  the out-of-memory victim, the check helper reaching another instance.
- Scope: in:
  - **4a, `pg_cron` and the cron daemon**: the Dockerfile installing
    `postgresql-18-cron` and Debian's `cron` without recommends, at the
    versions G5 cleared; the s6 longrun `cron` (`cron -f`, after
    `postgres`; marked down and exiting when the node seeds no crontab);
    shutdown stopping `cron` before `postgres`; the optional seed
    `crontab`, installed once into `postgres`'s spool on the volume
    `cronspool` (snapshot `copy`), a player's replacement surviving a
    restart; `gm-crontab -l` and `gm-crontab <file>` through `sudo`;
    `gm-entrypoint` writing the password file of the node's
    `crontab_roles` from their mounted secrets, readable by OS user
    `postgres` only; `/var/log/postgresql/cron/` on `pglog`, readable by
    the players' group; `brick.yaml` (`seed.optional: [crontab]`, the
    volume, the secrets, the protected files); stack test: a crontab
    entry connecting as a customer role through `PGPASSFILE`, the daemon
    down without a crontab, `gm-crontab` listing and replacing,
    `pg_cron` preloaded with a job scheduled by
    `cron.schedule_in_database(…, username => <role>)` running as that
    role and filling `cron.job_run_details`;
  - **4b, the victim, `check-psql` and the documentation**: the run
    script exporting `PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj` and
    `PG_OOM_ADJUST_VALUE=300`, a backend at +300 and the postmaster, s6,
    `sshd` and `cron` at 0 in the stack test; `check-psql <node>`
    reaching another database node's instance as the GM check role over
    the game network (two containers in the stack test); `docs/player.md`
    and `docs/gm.md` sections for `pg_cron` and the cron daemon (what
    each is, how a scenario turns it on, its cost, the faults it
    allows), the victim, `check-psql`'s other-node form; the footprint at
    rest.
  - Out: a report-only write policy and `cron.allow` (none, spec D211);
    `load-data`'s read policy and mapping-roles function (chunk 7).
- Files: `bricks/postgres/{Dockerfile,brick.yaml}`,
  `bricks/postgres/rootfs/etc/s6-overlay/s6-rc.d/cron/` (new),
  `bricks/postgres/rootfs/etc/s6-overlay/user-bundles.d/user/contents.d/cron`
  (new), `bricks/postgres/rootfs/etc/s6-overlay/s6-rc.d/postgres/run`,
  `bricks/postgres/rootfs/usr/local/sbin/{gm-entrypoint,gm-crontab}`
  (`gm-crontab` new), `bricks/postgres/rootfs/etc/sudoers.d/gm-player`,
  `bricks/postgres/rootfs/usr/local/lib/gm/check-psql`,
  `bricks/postgres/docs/{gm,player}.md`,
  `bricks/postgres/tests/{run-stack-test.sh,stack.test.yml,fixtures/}`.
- Spec sections: master spec 6.4, 6.5, 7.2, 12.5, 16.3 (the victim), 19,
  20; access model 5, 8, 9.4, 12; spec D206, D209, D211.
- Done when: the stack test shows each item of 4a and 4b; the loader
  accepts the brick; `test_brick_docs` passes; a node seeding neither
  `pg_cron` nor a crontab behaves as 0.3.0 (v0.3's scenarios at the wave
  gate); G6 run once merged.
- Verification: chunk checks, plus the stack test (needs G4); G6 after
  its merge.
- Split rule: 4a the packages, `pg_cron` and the cron daemon; 4b the
  victim, `check-psql` and the documentation.

Record: 4a 449f4ec, 4b 606cee0, wave branch taken in b44a0e5, merge da6d300 (after 2a). Outside its Files line: a two-line fix in `tools/gm/localimpl.py` `seed_entries` (an optional seed file the node leaves out is skipped, as W1 item 4 states; chunk 6's file), and four unit tests updated for the `cronspool` volume; logged in the wave log. Outcome recorded as capture W1-x.

### Chunk 5 — The shop domain

Status: merged (w1, f172a0e)
Wave: 1
Depends on: chunk 1 (in-wave, W1: runs beside chunk 1, its files all
under `domains/shop/`)
Architecture capture: none of its own; it uses W1.

- Goal: the shop as the first domain, `domains/shop/`, derived from
  `tarnbeck-outdoor-shop`'s data file, which stays as it is.
- Scope: in:
  - **5a, the data model**: `domain.yaml` (identity, parts, the four
    purposes that fit); `data/schema.sql`: tarnbeck's business tables
    plus `business_settings`, customers' address, country and time zone,
    `consent_events` beside `marketing_opt_in`, `orders.packed_at`,
    `shipped_at` and `ship_country`, `export_countries`, `last_order_at`
    from an archived history, the purposes' tables in `shop`
    (`campaigns`, `leads`, `mail_outbox`, `customs_outbox`,
    `customs_acks`, `incidents`, `etl_runs`), the materialized view
    `popular_products`, `daily_sales` gone; the roles and grants of
    master spec 9.7 (`shop_etl` without `orders.customer_id`,
    `shop_refresh` with `MAINTAIN`); `data/load.sql`: the generated
    history at tarnbeck's sizes, recipients' zones relative to the
    customer's as 9.3 distributes them, the consent history, about a
    third lapsed, one active `winback` campaign, `business_settings`
    written from the `psql` variables `customer_timezone` and
    `customer_utc_offset`; `data/classification.yaml` classing every
    column as 9.9 does;
  - **5b, the producer and the notes**: `producers/`, the web shop's
    repository and schedule fragments from tarnbeck's producer plus
    `consent.unsubscribe` (about 20 an hour, weighted to lapsed
    customers), `consent.subscribe` (about 30 an hour), `orders.status`
    setting `packed_at` and `shipped_at`, `orders.place` setting
    `ship_country`; `docs/gm.md` (the business, its rules, its traps).
  - Out: the reporting instance's tables (chunk 10); any scenario.
- Files: `domains/shop/{domain.yaml,data/schema.sql,data/load.sql,data/classification.yaml,docs/gm.md}`
  and `domains/shop/producers/` (all new); the root `README.md`'s table.
- Spec sections: master spec 6.8, 8.5, 9, 11.2, 11.3; access model 9.1.
- Done when: the format skill (1b's rules) finds nothing missing; the
  schema and the load run into the `postgres` image with both variables
  set, a shift of 0 and a non-zero one; every role holds exactly the
  grants of 9.7 (`shop_etl` refused `orders.customer_id`); every column
  is classed; the producer fragments parse as `queries.yaml` and
  `schedule.yaml` fragments; the unit suite loads the domain once chunk 2
  has merged.
- Verification: chunk checks.
- Split rule: 5a the data model and the classification; 5b the producer
  fragments and the notes.

Record: 5a 5ff4cef, 5b 17a45d4, merge f172a0e. No departure from the spec; choices (tarnbeck's planted producer faults left out, `lifetime_value` added to, `producers/jobs.yaml` and `builders/`, classification and grant readings) logged as "W1 addenda — choices chunk 5 made"; the unit suite's load of the domain is left for the wave gate.

### Chunk 6 — Render for v0.4

Status: merged (w2, 30e8c59)
Wave: 2
Depends on: chunks 1, 2
Architecture capture: none.

- Goal: render as master spec 8.5 and 14 say: the customer's zone in the
  new seed files, a crontab's hours shifted, the crontab roles' secrets
  mounted.
- Scope: in: `{{customer_timezone}}` (as `Etc/GMT∓N`) substituted in
  every scheduler node's seed files and in a `postgres` node's seed
  `postgresql.conf` (`cron.timezone`); a seeded crontab's hour fields
  shifted from scenario time to UTC as `jobs.yaml`'s are (lists, ranges
  and steps, wrapping modulo 24); the secrets of a node's
  `crontab_roles` (`role_<role>_password`, the ones `load-data` sets)
  declared for that node and mounted into it; the loader's
  `{{customer_timezone}}` rule widened to the files render now fills.
  Out: `pg_cron` schedules (written in scenario time, unshifted, 8.5).
- Files: `tools/gm/{render,localimpl,deploy}.py`, `tools/gm/model.py`
  (the placeholder rule only), `tools/tests/{test_render,test_deploy}.py`.
- Spec sections: master spec 7.2, 8.5, 14 (`render`); access model 8.
- Done when: unit tests show the zone substituted, crontab entries with
  ranges and lists shifted at shifts of 0 and non-zero, the crontab
  roles' secrets declared and mounted; v0.3's scenarios and fixtures
  render as before.
- Verification: chunk checks.

Record: 639e08c, merge 30e8c59. No departure from the spec; every v0.3 scenario and fixture renders byte-identical at shifts −2, 0, +5. Choices: the bare zone substituted in a scheduler's YAML before parsing; the rendered crontab carries no header; `{{customer_timezone}}` not substituted in a crontab or `pg_hba.conf`. `gmctl.md`'s `render` paragraph left for chunk 18.

### Chunk 7 — `load-data` for v0.4

Status: merged (w2, 38ef427)
Wave: 2
Depends on: chunks 2, 4; chunk 6 (in-wave, W2: its fixture's crontab
role needs render's mount), merged into `v0.4-w2` before this chunk's
branch is cut
Architecture capture: none of its own; it records as built, as W2-x
(read by chunks 12, 15): the mapping-roles function's name and signature
and the read policy's form.

- Goal: `load-data` as master spec 14 says, and a small two-instance
  fixture to prove it on.
- Scope: in: the zone and its offset passed to `psql` as
  `-v customer_timezone=… -v customer_utc_offset=…` for every data file;
  each user mapping's password set from its remote role's secret, where a
  data file creates a foreign server; the GM check role's read policy on
  `cron.job` and `cron.job_run_details` where `pg_cron` exists, narrower
  than `BYPASSRLS`; the mapping-roles function (owned by `postgres`,
  `SECURITY DEFINER`, executable by the GM check role only, returning
  each mapping's server, local role and remote role, never its password)
  where a foreign server exists; `CONNECT` for the GM check role on every
  database of every instance; `fixture-instances` (new: two `postgres`
  0.4.0 nodes, `pg_cron` on one, a foreign server and a user mapping
  between them, a seeded crontab with a crontab role, no scheduler node).
- Files: `tools/gm/inject.py`, `tools/gm/localimpl.py` if the secret
  names need it, `tools/tests/test_inject.py`,
  `tools/tests/fixtures/fixture-instances/` (new).
- Spec sections: master spec 7.2, 8.5, 8.6, 11.6, 14 (`load-data`);
  access model 8.
- Done when: unit tests show each step and its order; on a deployment of
  `fixture-instances` on armenelos, the GM check role reads both `pg_cron`
  tables and every job in them, calls the function and sees no password,
  the user mapping connects, the crontab entry runs as its role; the
  fixture's README matches a fresh regeneration.
- Verification: chunk checks, plus the deployment (needs G4).

Record: 7d2c72e, merge 38ef427, capture W2-x 80f9c9d. No departure from the spec; deployment of `fixture-instances` on armenelos passed every Done when item and was torn down. Outside its Files line: two lines in `tools/tests/__init__.py` (`FakeDocker` answers the new survey), and the fixture carries a copy of `fixture-audit`'s seed-file fault as `f1` (the loader needs a fault instance). `localimpl.py` unchanged. Outcome recorded as capture W2-x (`gm_check.user_mapping_roles()`, policy `gm_check_read`).

### Chunk 8 — `fit` and `check`: shared hosts, the judged moment

Status: merged (w2, 6d88c58)
Wave: 2
Depends on: chunk 2; G8 (done, spec D217)
Architecture capture: none.

- Goal: `fit` keeps a node that may exhaust its memory off shared hosts;
  `check` gives a purpose check its judged moment.
- Scope: in:
  - **8a, `fit`**: the host declaration `--host <name>[,manager][,shared],…`;
    a node carrying a fault instance whose fault declares
    `needs_unshared_host` refused on a shared host, naming the mapping
    to change, as a node publishing ports off the manager is; a
    playground whose only hosts are shared refused for such a scenario;
    the VPS declared `shared` in the harness's committed playground
    declarations and usage comments (`rehearsal.sh`, `smoke-load.sh`);
  - **8b, `check`**: `CHECK_SINCE` (UTC) passed to a check whose answer
    key says `judges: runs` or `triggers`, with `CHECK_THRESHOLD`: the
    hand-over from the state, and before it (the early check, the
    hand-over check, the smoke runs) the fault instance's planting
    moment (spec D217), the check raising either to the runner's last
    reload; `--since <time>`, per instance with `--instance <id>`; the result line for an
    exit 3 naming the time to the next run.
  - Out: the checks themselves (chunks 10 to 15).
- Files: `tools/gm/{fit,checks,__init__}.py`,
  `tools/tests/{test_fit,test_checks}.py`,
  `tools/tests/{rehearsal,smoke-load}.sh` (the declarations only).
- Spec sections: master spec 6.3, 6.5, 12.1, 12.8, 13.3, 14 (`fit`,
  `check`); access model 6, 7; spec D159, D209, D217.
- Done when: unit tests show the shared mark parsed, the refusal with its
  message, the only-shared playground refused, `CHECK_SINCE` passed as
  the planting moment before the hand-over, as the hand-over after it,
  and by `--since` per instance; a v0.3 scenario fits and checks as
  before.
- Verification: chunk checks.
- Split rule: 8a `fit`; 8b `check`.

Record: 8a bde3c70, 8b 33bfb36, merge 6d88c58. No departure from the spec; outside its Files line, `test_render.py`'s `two_hosts()` helper gained a `worker_shared` option, and `smoke-load.sh` gained a two-host usage example marking the VPS `shared`. Choices: an unplanted judging instance is refused before anything runs; `--since` only raises the moment and is refused in the future or with no judging instance; gmctl passes `CHECK_SINCE` and the check raises it to the runner's last reload. `gmctl.md` lines left for chunk 18; `aging.run_check`'s too-soon wording left for the wave gate.

### Chunk 9 — f10's early calibration

Status: merged (w2, 17be068)
Wave: 2
Depends on: chunks 4, 5; G9 (done, spec D218); G4
Architecture capture: none of its own; its figures feed G10 and chunk 15.

- Goal: measure, early and on armenelos only, whether the out-of-memory
  incident can be had as master spec 16.3 designs it (spec D213).
- Scope: in: a calibration fixture standing for `db` and `reporting`
  (two `postgres` 0.4.0 instances, the shop's data from chunk 5,
  `reporting` at the scenario's starting limit and reservation,
  512M / 256M), the foreign server and the foreign tables the roll-up
  reads, the draft of `rpt.sales_detail_rollup()` (the order lines
  changed since its last run, in one `jsonb_agg` over the window), its
  backfill request table and the crontab entry calling it as `bi_etl`;
  a script, under the host lock and a sleep inhibitor, the VPS drained,
  reading the container's `memory.peak` around a normal run and around
  backfills of growing windows, as a Swarm service (swap equal to the
  limit) and without swap, in a one-off calibration container with its
  swap disabled for it alone, outside Swarm (`docker run
  --memory=<limit> --memory-swap=<limit>`), armenelos keeping its swap
  (spec D218); the figures (machine, date, limit,
  `shared_buffers`, window, peak, whether the kill happened) recorded in
  the Record line and the wave log; whether the history allows a window
  reaching twice the limit while a normal run stays under half.
  Out: the catalog fault (chunk 15); reshaping anything on a shortfall
  (G10, the owner).
- Files: `tools/tests/calibrate-f10.sh` (new),
  `tools/tests/fixtures/calibrate-f10/` (new).
- Spec sections: master spec 13.3, 16.3, 18 (item 5), 19; spec D209,
  D213.
- Done when: the figures are recorded for both swap settings; G10's
  question is answered yes or no from them; the host's other games and
  the VPS untouched.
- Verification: chunk checks, plus the calibration run (needs G4).

Record: 396f4be, merge 17be068. armenelos (Docker 29.9.1), 2026-10-30, limit 512M, `shared_buffers` 128MB. With swap (Swarm, swap = limit): normal run (1 day, ~35.8k orders) `memory.peak` 299–300 MiB, non-reclaimable need 252 MiB; backfills of 2, 4, 6, 8 days completed (need 355, 549, 826, 946 MiB); 10 days and the whole history (30-day request, 14.9 days, 300k orders) killed. Without swap (`docker run --memory=512M --memory-swap=512M`): normal 301 / 250 MiB; 2 days completed; 4 days killed. ~5.2 KB per order. Every kill: `oom_kill` +1, the four recovery lines, connections back within 1 s, postmaster, s6, sshd, cron untouched. G10: the backfill side holds; the normal-run side passes only on the non-reclaimable reading (252 < 256), not on raw `memory.peak` (300 > 256): taken to the owner (wave log). No departure from the spec; nothing reshaped.

### Chunk 10 — P1, sales reporting

Status: merged (w2, 1414e3c)
Wave: 2
Depends on: chunks 3, 5; G8 (done, spec D217)
Architecture capture: none.

- Goal: `purposes/shop-sales-reporting/`, complete by the format skill.
- Scope: in: `purpose.yaml` (identity, parts `source`, `target`,
  `runner`, `consumer`; the jobs `rollup-hourly` and `rollup-close`;
  trace, invariants R1 to R5 with witnesses, data moved, roles);
  material: `scripts/rollup.py:hourly` (watermark on `updated_at`, one
  target transaction holding the watermark, one `rpt.etl_runs` row), the
  repository entries and `jobs.yaml` lines, `reporting`'s DDL (`rpt.*`,
  `rpt.etl_runs`, the foreign server owned by `postgres`, `bi_etl`'s
  user mapping to `shop_etl`, the foreign tables `src.orders` without
  `customer_id`, `src.order_lines`, `src.products`, the `SECURITY
  INVOKER` procedure `rpt.close_day()` cutting yesterday in the
  customer's zone from `business_settings`, the roles `bi_etl` and
  `bi_reader`), the consumer's dashboard queries; `checks/` (one per
  invariant, judging runs since `CHECK_SINCE` through chunk 3's means and
  `check-sql`, raised to the runner's last reload, the same before and
  after the hand-over (spec D217), exit 3 with `remaining=`, R5 a
  definition check running
  the dashboard's `SELECT` read-only); `gm.md`.
- Files: `purposes/shop-sales-reporting/` (new); the root `README.md`'s
  table.
- Spec sections: master spec 6.7, 8.2, 8.6, 8.7, 9.6, 9.7, 10.1, 12.1 to
  12.3, 12.6; access model 9.1, 9.2.
- Done when: the format skill finds nothing missing; the loader accepts
  it; the script, called in the scheduler's unit-test harness on two
  databases loaded with the shop's data, moves the right rows; the
  procedure closes a day right at a non-zero shift; each check reads 1
  on a crafted violation, 0 on clean runs with a witness, 3 with no run
  since `CHECK_SINCE`.
- Verification: chunk checks.
- Split rule: 10a `purpose.yaml` and the material; 10b the checks and
  `gm.md`.

Record: 10a 2ecf66a, 10b 68b2675, merge 1414e3c. No departure from the spec; choices logged in the wave log (`rpt.business_settings` in `reporting`; a `run_id` column on `rpt.sales_hourly` and `rpt.sales_daily`, not in 9.6's column list; `close_day()` recomputes yesterday's hours too; R2 on revenue only; the purpose's own `tests/` folder). For chunks 13 to 15: where R1 to R5 run, the `pg_hba` lines the scenario must give, R1 and R3 reading 3 after a 14:00 hand-over.

### Chunk 11 — P2, P3 and P5: leads, mailing, export declarations

Status: merged (w2, d41032c)
Wave: 2
Depends on: chunks 3, 5; G8 (done, spec D217)
Architecture capture: none.

- Goal: `purposes/shop-winback-leads/`, `purposes/shop-customer-mailing/`
  and `purposes/shop-export-declarations/`, complete by the format
  skill, with the customs gateway stub.
- Scope: in: each `purpose.yaml`; material: the jobs `leads-extract`,
  `mail-shipped`, `mail-campaign`, `declare-exports` and
  `escalate-customs` as SQL on the shop's database (the latest consent
  event, never the flag; sending hours in the recipient's local time),
  their repository entries and `jobs.yaml` lines, the payload schemas of
  the two outboxes; the receiver: the gateway stub's repository and
  schedule (a stream reading new `customs_outbox` rows as `customs_gw`,
  writing `customs_acks` within a minute, accepting every well-formed
  declaration, never acknowledging about one in fifty as standing
  behaviour, spec D214); `checks/` for L1 to L3, M1 to M5 and E1 to E4
  (runs, or triggers for E1 and E4, since `CHECK_SINCE`, raised to the
  runner's last reload, the same before and after the hand-over, spec
  D217); each `gm.md`.
- Files: `purposes/{shop-winback-leads,shop-customer-mailing,shop-export-declarations}/`
  (new); the root `README.md`'s table.
- Spec sections: master spec 6.7, 8.2, 9.3, 9.6, 9.7, 10.2 to 10.4, 12.1
  to 12.4; access model 9.1; spec D214.
- Done when: the format skill finds nothing missing; the loader accepts
  each; every job's SQL runs on the shop's data at a shift of 0 and a
  non-zero one; the stub leaves about one declaration in fifty
  unacknowledged; each check reads 1 on a crafted violation, 0 on clean
  runs or triggers with a witness, 3 otherwise.
- Verification: chunk checks.
- Split rule: 11a P2 and P3; 11b P5 and the gateway stub.

Record: 11a 2fda6c4, 11b 1ae95e6, merge d41032c (README purpose row merged with chunk 10's). E4's deadline read as the acknowledgement's 30 minutes plus one escalation cycle (master spec 10.4), sent to `spec-writer`; the stub answers by 15-second slots (`customs_gw` cannot read `customs_acks`). Found outside its Files line: the shop domain's consent buckets leave M3 without a witness from 16:00 to 20:45 company time, fixed on the wave branch (wave log). Choices logged in the wave log and each `gm.md`.

### Chunk 12 — The governance check set G1 to G4

Status: merged (w3, 21790ca)
Wave: 3
Depends on: chunks 3, 4, 7
Architecture capture: recorded at wave 3 start (W3-a), for chunk 15's
f9: where the set lives, how a fault's sealed check calls it and the
rules it names, and what it reads (`governance:` and the classification,
on which node).

- Goal: G1 to G4 implemented once, as master spec 11.6 says, for the
  governance faults' checks and the baseline's proof.
- Scope: in: G1 (classed columns only in their allowed locations, over
  every database of every `database` node: tables, views, materialized
  views and foreign tables; a foreign table's column by the remote column
  it maps, a copy by table and column name, the `personal` content probe
  for e-mail addresses); G2 (`has_column_privilege` for every customer
  login role, through membership and `PUBLIC`); G3 (foreign tables, user
  mappings' remote roles through the mapping-roles function, a mapping
  for `PUBLIC`, transformer jobs' source roles read from the runner's
  `jobs.yaml` and schedule, `SECURITY DEFINER` owners, `pg_cron` jobs'
  `username` in their database, a superuser reaching everything); G4
  (the outboxes' payload keys against `outbound.fields` on rows written
  since `CHECK_SINCE`); the game's own roles skipped by name; exit 0 or
  1 for G1 to G3; tests on `fixture-instances` with each rule broken and
  kept.
- Files: the set's home as W3-a records it (under `tools/` or a shared
  check library mounted with the checks), its tests, and
  `tools/tests/fixtures/fixture-instances/` (a governance section and
  the breaches its tests plant).
- Spec sections: master spec 7.2 (`check-psql`), 11.4 to 11.7, 12.6, 14;
  access model 8, 9.3.
- Done when: each rule reads 1 on its planted breach and 0 on the
  compliant fixture, a renamed copy of personal data included; the
  game's own roles never flagged; the fixture's README current.
- Verification: chunk checks, plus a deployment of `fixture-instances`
  (needs G4).
- Split rule: 12a G1 and G2; 12b G3 and G4.

Record: 9d172b0, merge 21790ca (one commit, not split: built in one pass). Differs from W3-a: D230 applied (the game's own roles skipped in G2 only, every G3 path judged whoever it acts as; `gm_pgbouncer` out of the walk); G2's "may read" also requires CONNECT and USAGE; a transformer connection to a non-database node exits 2; `separation: instance` not judged (to `spec-writer`). Wave log.

### Chunk 13 — `fixture-campaign`: the v0.4 topology, unfaulted

Status: merged (w3, a550257)
Wave: 3
Depends on: chunks 5, 6, 7, 10, 11, 19
Architecture capture: recorded at wave 3 start (W3-b), for chunks 14 and
15: the fixture's node names, roles, job names and keys, databases and
data files, as master spec 16.1 sets them.

- Goal: a deployable copy of the new scenario's system with no fault
  instance, to plant and check the faults on, and the shape chunk 16
  copies.
- Scope: in: the topology of master spec 16.1 (`db` with its crontab
  refreshing `popular_products` as `shop_refresh`, `pooler`, `producer`
  with the domain's fragments, `consumer` with the dashboards,
  `reporting` with `pg_cron` and its cron daemon, `bi`, `crm`, `gateway`,
  the monitoring of `db`), the starting limits and reservations
  (`reporting` 640M / 256M, spec D227), the
  designed placement on two hosts (`reporting` on the first);
  `purposes:` mapping the four purposes, `domain: shop`, `governance:`
  and `player/data-policy.md` (personal and customer-linked data kept out
  of `reporting`, the back office allowed to read names and e-mails),
  mapped to the bastion's `data-policy.md`;
  every database node's seed `pg_hba.conf` admitting the GM check role
  from the game network; both data files; `aging:` at the floor.
  Out: fault instances, the story and issues (chunk 16).
- Files: `tools/tests/fixtures/fixture-campaign/` (new),
  `tools/tests/test_model.py` (the fixture loads).
- Spec sections: master spec 9, 10, 11.5, 13.1, 13.2, 13.4, 16.1;
  access model 9.
- Done when: the format skill finds nothing missing; `fit` and `render`
  accept it on armenelos alone and on two declared hosts; deployed on
  armenelos with the load started, every job of the four purposes, the
  `pg_cron` job and both crontabs run in their logs and ledgers; every
  purpose check reads 0 or 3, none 1. It places at wave 3's gate:
  G1 to G4 passing on it (chunk 12 merged).
- Verification: chunk checks, plus the deployment (needs G4).

Record: dc21692, merge a550257 (one commit). Deployed on armenelos at shift +3 with no patch, after the `load-data` secrets fix: every job, both crontabs and the `pg_cron` launcher ran; every purpose check 0 or 3, none 1. `fit` 1.6 CPU, 1.75G memory, 6.19G disk. Choices: tooling expectation `t1`; Prometheus scrapes all 12 nodes; `reporting`'s `max_connections` 100 (chunk 9's calibration ran at 20). Found: a scheduler session idle over ~15 min is dropped (08006), one run lost (to a `coding-executor`); `reporting`'s `pg_cron` launcher exits until `load-data` creates its database. Wave log.

### Chunk 14 — The purpose faults f1 to f5 and f8

Status: merged (w3, 3cc4a32)
Wave: 3
Depends on: chunks 2, 7, 8, 10, 11; chunk 13 (in-wave, W3-b), merged into
`v0.4-w3` before this chunk's branch is cut
Architecture capture: none of its own; its fault ids, seed changes,
parameters, aging minima and timeline needs are recorded at its merge as
W3-c, for chunk 16.

- Goal: six catalog faults of master spec 16.2, each with injection,
  aging minimum, sealed check and solvability description.
- Scope: in: `purpose-mail-overlapping-window` (f1),
  `purpose-leads-stale-consent` (f2, its producer release written as a
  timeline need its definition states; its producer path a fix only with
  the drifted flags repaired, dated with `--since` (spec D244)),
  `purpose-mail-outside-hours` (f3), `purpose-watermark-misses-updates`
  (f4), `purpose-etl-role-expired` (f5, a `state` change: `VALID UNTIL`
  the planting moment and the role's open sessions ended (spec D245); its
  `remaining=` to the hourly job's minute read from the ledger (spec
  D246)), and
  `purpose-receiver-down-unnoticed` (f8, the gateway's two-hour outage as
  a timeline need); each with `fault.yaml` (`applies_to.bricks` with the
  `scheduler` 0.2.0 or `postgres` 0.4.0 it needs, `applies_to.purposes`,
  `sealed_check.judges`, the aging minimum from the job's first run after
  planting, an hour for a five-minute job too (spec D247)), its seed
  changes or injection, `checks/fixed.sh` (judging runs or triggers
  since `CHECK_SINCE`), `checks/probe.md`, `gm.md`; the
  bricks' "Supported faults" sections, folding into their versions.
- Files: `faults/<fault-id>/` for each (new),
  `bricks/{scheduler,postgres}/docs/gm.md` ("Supported faults" only).
- Spec sections: master spec 6.3, 12, 16.2; access model 7; spec D244
  to D247.
- Done when: the loader accepts each; on a deployment of
  `fixture-campaign` with each planted, its evidence shows within its
  aging minimum and its check reads 1; after its acceptance fix and its
  job moved, 3 then 0 (f5 with `--since`).
- Verification: chunk checks, plus the faults planted on
  `fixture-campaign` (needs G4).
- Split rule: 14a f1, f2, f3 (`crm`'s mail and leads); 14b f4, f5, f8.

Record: 14a cd7daed, 14b 8fceabb, merge 3cc4a32 (the `postgres` Supported-faults list merged with 15a's rows). Planted on armenelos (shift −3; f4's 0 on a second game at +9, a past local day needing a local midnight): each fault's evidence within its aging minimum, then 1, 3, 0. Differs from the text: f1's aging minimum 1h (shipping ramps after the load); f5's injection also ends `shop_etl`'s open sessions (VALID UNTIL is checked at login; the scheduler now keeps its sessions); f5's `remaining=` counts from the ledger's last start; f2 restored in the producer alone still reads 1 until the flags are repaired (to `spec-writer`). Wave log, W3-c.

### Chunk 15 — The database-node faults f6, f7, f9 and f10

Status: merged (w3; 15a e901230, 15b b744cca)
Wave: 3
Depends on: chunks 4, 6, 7, 9, 10; chunks 12 and 13 (in-wave, W3-a,
W3-b), merged into `v0.4-w3` before this chunk's branch is cut; G10 for
15b (done, spec D227)
Architecture capture: none of its own; recorded at its merge as W3-d,
for chunk 16.

- Goal: the four catalog faults of master spec 16.2 on database nodes,
  each complete.
- Scope: in:
  - **15a**: `security-crontab-superuser` (f6: `db`'s hourly refresh
    connecting as `postgres` by peer, `shop_refresh` prepared and unused;
    its check requiring every live crontab entry's role to be no
    superuser); `purpose-day-boundary-wrong-zone` (f7: `rpt.close_day()`
    cutting the day N hours off the customer's zone, N a non-zero
    parameter written into the data file's copy and added to the
    customer's offset at load (spec D239); its check judging the close's
    runs from `rpt.etl_runs`, a fix dated with `--since` (spec D241));
    `governance-personal-copied` (f9: the second foreign
    server mapped for `bi_etl` to `shop_reports`, the foreign table over
    `customers`, `rpt.customer_activity`, `CREATE` on `rpt` for `bi_etl`,
    the `pg_cron` job as `bi_etl` recreating and refilling it every
    thirty minutes (spec D242); its check calling G1 and G3 and
    requiring the job, the table, the foreign table and the server gone);
    the loader admitting `data` in a seed change, the target node's
    `data.file`, and refusing it on a node without one (spec D226), with
    its unit tests and the fault template's `seed_changes.file` comment,
    for f9's planting and any other change these faults make to a data
    file;
  - **15b**: `purpose-heavy-job-on-database-node` (f10: chunk 9's
    procedure and crontab entry as its seed at T0, the backfill request
    as a `state` change at `handover-12h`, the window as designed (the
    thirty-day request, G10),
    `needs_unshared_host: true`; its incident check exiting 1 while the
    kill and the recovery are in the log since the planting moment,
    never 0 or 3; its notes for a failed planting, never re-planted
    within the aging; report only); f10 planted for real on
    `fixture-campaign` on armenelos alone, the VPS drained, its entry
    moved to run within two minutes through `gm-crontab`, `reporting`
    at its 640M limit (spec D227); that run re-measuring G10's criterion
    at 640M: the `reporting` container's `memory.peak` around a normal
    run under half the limit (320 MiB), and the thirty-day backfill
    killed with swap (Swarm), so needing more than twice it (master spec
    16.3), the figures (machine, date, limit, `shared_buffers`, peaks)
    in the Record line and the wave log; measured once, the normal run
    at 327 MiB, accepted as measured, no re-run (spec D252); f10 a
    `state` fault carrying `seed_changes` (`data` and `crontab`, spec
    D254; the fault template's comment is chunk 20's), the roll-up
    reading the orders through its own `src.sales_detail_orders` (spec
    D255), its check dating the planting from the request's
    `requested_at`, exiting 2 when it cannot confirm the incident and
    matching either wording of the kill line (spec D256), the night
    after the kill reading one day back (spec D257);
  - each with `fault.yaml`, its seed changes or injection, its check,
    `checks/probe.md`, `gm.md`; `postgres`' "Supported faults".
- Files: `faults/<fault-id>/` for each (new),
  `bricks/postgres/docs/gm.md` ("Supported faults" only); 15a also
  `tools/gm/model.py` (the seed-change file check only),
  `tools/tests/test_model.py`,
  `.claude/skills/scenario-format/templates/fault.yaml` (the comment).
- Spec sections: master spec 6.3, 7.2, 11.6, 11.7, 12.5 to 12.7, 13.3,
  16.2, 16.3, 16.5; access model 7, 9.4, 12; spec D209, D211, D213,
  D226, D227, D239 to D243; 15b also D252, D254 to D257.
- Done when: the loader accepts each, and refuses a `data` seed change
  on a node without a data file; on `fixture-campaign` f6 and f9
  read 1, then 0 after their acceptance fix (f9 still 1 with only the
  table dropped); f7 reads 1 after the close runs (its job moved), 3
  then 0 after the fix, dated with `--since`, and a move; f10's run kills a backend, PostgreSQL
  recovers by itself, s6, `sshd` and `cron` untouched, its check reads
  1, the next run normal; at 640M a normal run's `memory.peak` under
  320 MiB and the thirty-day backfill killed with swap, or, on a
  shortfall on either side, the figures back to the owner before
  anything is reshaped (spec D213; ruled on 327 MiB, spec D252); `fit` refuses a mapping placing
  f10's node on a shared host.
- Verification: chunk checks, plus the faults planted on
  `fixture-campaign` (needs G4), f10's run alone on armenelos under the
  host lock.
- Split rule: 15a f6, f7, f9; 15b f10.

Record: 15a 0ddfa5d, merge e901230. Differs from the text: f7's N is written at load into the data file's copy from `load-data`'s offset, not by render (render writes no data file); f7's evidence is `\sf`, not `\df+` (PostgreSQL 18); f9's planting also grants CREATE on `rpt` to `bi_etl` so the job recreates a dropped table (to `spec-writer`). Planted on armenelos (shift −8, f7 offset 3): f6, f9 1 then 0 (f9 still 1 with the table only dropped); f7 3, 1, 3, 0. 15b: Record below once run.
Record: 15b 6149311 (f10), b5f4557 (f2's fix path, D244), merge b744cca (its message names the pg_cron fix's log entry: the driver's log commit took the staged merge). Run on armenelos alone, 2026-10-31, `reporting` 640M + swap 640M: the 30-day backfill killed after 11 s (1258 of 1280 MiB, `oom_kill` 0 → 1), recovery in 1 s, postmaster pid unchanged, check 2 → 1, next run normal, `fit` refused a shared host; a normal run's `memory.peak` 327 MiB (238 without page cache), above the half, accepted as measured by the owner (2026-10-31). f10 is a `state` fault with `seed_changes`; the roll-up reads its own foreign table `src.sales_detail_orders`; the check dates the planting from `requested_at`; PG 18's "client backend" matched; the night after a killed backfill reads 1 day (to `spec-writer`). Unit suite 846 OK merged.

### Chunk 16 — The v0.4 scenario

Status: merged (w4, a3383d2)
Wave: 4
Depends on: chunks 13, 14, 15
Architecture capture: recorded at wave 4 start (W4), for chunk 17: the
scenario's id, its ten instances, which jobs a smoke cycle moves on which
node, and each acceptance fix.
Record: 8563c90, merged a3383d2 (2026-11-02), built on O146 (a) (spec D284). Differs from W4 as first drafted, with the driver's amendments (wave log): player-readable comments rewritten in the story's voice (behaviour byte-identical to `fixture-campaign`, W4 item 2); a "Marketing e-mail" section in `player/data-policy.md` stating the rules I2 and f3 read (unchecked, 11.5). `fit`/`render` on armenelos alone and with the VPS `shared` (declaration only); `fit` refuses the VPS for `reporting` (f10).

- Goal: `tarnbeck-outdoor-campaign` (working id) of master spec 16.1,
  complete by the format skill.
- Scope: in: `fixture-campaign`'s system copied into
  `scenarios/<id>/` at the starting sizes (`reporting` 640M / 256M,
  spec D227); `difficulty:` normal, ten;
  the ten instances of 16.1 with their nodes, plantings and visibility,
  each instance's aging minimum raised to its job's first run after
  planting (f1's the hour from its first five-minute run, `65m` from T0,
  spec D247); f2's expected fix naming both paths, the producer's with
  the drifted flags repaired and dated with `--since` (spec D244); the
  producer's release at T0 (f2) and the gateway's two-hour outage (f8)
  as timeline changes of their schedules; the story (Tarnbeck six months
  on, Lumen Analytics, Ines Varga), the issues I1
  to I6, the starter pack naming every job the players may move and the
  agency's nodes, `player/data-policy.md` mapped to the bastion's
  `data-policy.md`; `reporting` unscraped, a
  silent tooling expectation; `gm/answer-key.yaml` with each instance's
  expected resolution, and the overstep notes of 16.5 for f7, f9 and
  f10 (a change on the agency's system judged, never credited), and
  f10's check reading 2 once a player alters the request (spec D282); f7
  expected to stay present, its `offset` the same number in its instance
  and in `reporting`'s data file (spec D239); `gm/notes.md`, `brief.md`, `README.md`
  regenerated. Its files, instances, interactions and acceptance fixes as
  capture W4 sets them; f5 planted at `handover-5h`, masking f4, whose
  answer key expects `at_handover: 3` and names f5 in its interactions
  (spec D284).
- Files: `scenarios/<id>/` (new); the root `README.md`'s table.
- Spec sections: master spec 6.2, 11.5, 12.2, 12.5, 13.2, 13.4, 16.1,
  16.2, 16.3, 16.5; access model 7, 9.4, 12; spec D227, D239 to D247; D252
  (`reporting` stays at 640M), D253 (16.1's `governance:` has no
  `separation:`, so chunk 20's rule changes nothing here), D254 to D257
  (f10's instance as 15b built it); D282; D284.
- Done when: the format skill finds nothing missing; `fit` and `render`
  accept it on armenelos alone and on armenelos plus the VPS declared
  `shared`, `fit` refusing the VPS for `reporting`; its README matches a
  fresh regeneration.
- Verification: chunk checks.

### Chunk 17 — Smoke cycles, f10's run and the rehearsal

Status: merged (w4, edc3457: 17a); 17b moved (to v1.0 gating, spec D311)
Record: 17a 398f09b, merged edc3457 (2026-11-03), closed under D310. armenelos, `--cpu 4 --memory 5G --disk 10G`: baseline 01:47–02:18Z 32/32; f10 02:19–02:25Z 23/23 (backend killed by signal 9, ready 1 s later, s6-svscan/sshd/cron pids kept, reporting `memory.peak` 671092736 B, `oom_kill` 1); cycles 2 02:25–07:26Z 54 passed 0 failed, aborted at f4's midnight wait (D310); pooler workarounds 0 in every run, `db` resolving after 5–6 s; no two-host run (D310, O161). Harness only: cycles' default `SMOKE_LOCAL_AT` 18:00 (21:00 put f3 outside its mail window and f7's day unfinished), per-instance crm rounds, f2 may rest on an earlier present reading of the same planting. The untested two-host wrapper not committed. No spec deviation. Wave log "Chunk 17a — merged".
Wave: 4
Depends on: chunks 8, 9, 12, 20; chunk 16 (in-wave, W4), merged into `v0.4-w4`
before this chunk's branch is cut; chunk 21 (in-wave, spec D305): 17a's
runs after its branch has merged `v0.4-w4` in once chunk 21 has merged,
a 17a run before that relying on its harness's counted WORKAROUND; G4
Architecture capture: none of its own; it uses W4.
Moved: 17b, the rehearsal and its figures, left v0.4 for v1.0 gating by
the owner's ruling (spec D311), listed in the roadmap's
[v1.0 gating](../README.md#v10-gating); the chunk is 17a in v0.4.

- Goal: the harness and the runs master spec 18 asks for, run once on the
  merged scenario.
- Scope: in:
  - **17a, the smoke cycles**: on the scenario, every fault planted at
    once and every scheduler key and job running, on armenelos alone
    (its run on armenelos plus the VPS not run by 17a, spec D310, and
    v1.0 gating, spec D311); every purpose fault
    through its whole cycle
    (planted; its job moved to run within two minutes by an edit of
    `jobs.yaml` and a reload, done as root on a report-only node; present;
    its acceptance fix; too soon; moved again; fixed), f4's cycle moving
    the producer's invoicing, f5's and f7's passing `--since` (spec
    D241), their `remaining=` blind to a move, so the harness waits for
    the moved time (spec D246), f5's cycle ending before f4's and f7's
    (W4 item 4), the cycles run counted as it stood when aborted at f4's
    wait for the scenario's midnight, f4's steps after it not run (spec
    D310), v1.0 gating with f8's fixed reading (spec D312); f6 and f9 present
    then fixed after their acceptance fix; the unfaulted scenario (a
    scratch copy whose seed-changed files are `fixture-campaign`'s, every
    instance left out by the harness-only override, W4 item 8),
    passing G1 to G4; the hand-over check passing a "too soon" reading
    where the answer key's `at_handover` is 3 (f4's, masked by f5) and
    failing any other reading of that instance, a 1 included, every
    other instance's "too soon" still failing it (master spec 12.2, spec
    D284), with its unit test in `aging.py`'s tests; `gmctl.md`'s
    hand-over check line ("as the answer key's `at_handover` says (1,
    present)") given the sentence saying so, and the answer-key
    template's `at_handover` comment likewise; f10's own run on
    armenelos alone, the VPS drained,
    its check present, PostgreSQL recovered, s6, `sshd` and `cron`
    untouched;
  - **17b, the rehearsal and the figures**: moved to v1.0 gating (spec
    D311), as master spec 18 item 6 describes it; the bricks' "Footprint"
    and the scenario's `resources` stand as built.
  - Out: the release notes (release gate).
- Files: `tools/tests/smoke-purposes.sh` (new; or `smoke-scenario.sh`
  extended, as the build finds), `tools/tests/{smoke-scenario,rehearsal}.sh`,
  the harness override where `render` and `inject` read the instance
  list (`tools/gm/{render,inject,aging}.py` as the build finds) and its
  unit tests; the hand-over check in `tools/gm/aging.py` and its unit
  test (spec D284); `.claude/skills/game-master/gmctl.md` (its hand-over
  check line only; chunk 18 merged) and
  `.claude/skills/scenario-format/templates/answer-key.yaml` (the
  `at_handover` comment only).
- Spec sections: master spec 6.2, 11.6, 12.1, 12.2, 12.5, 13.3, 16.1,
  16.3, 18 (items 1 to 6); access model 6, 7; spec D241, D246; D253 (the
  baseline's G1), D256, D257 (f10's check and the night after); D283;
  D284 (f4's 3 at the hand-over check); D310 (17a's runs as run); D311
  (17b moved).
- Done when: 17a's runs pass as spec D310 accepts them (its cycles run
  passing up to f4's wait for the scenario's midnight, no two-host run),
  its figures recorded with machine and date in the Record line and the
  wave log; the VPS never active during f10's run.
- Verification: chunk checks, plus the runs (needs G4), each under
  the host lock and a sleep inhibitor, alone on the hosts.
- Split rule: 17a the smoke cycles, the baseline's G1 to G4 and f10's
  run; 17b the rehearsal and the figures, moved to v1.0 gating (spec
  D311).

### Chunk 18 — The GM skill for v0.4

Status: merged (w4, 98c2123)
Wave: 4
Depends on: chunks 6, 7, 8, 14, 15, 19
Architecture capture: none.
Record: b19b978, merged 98c2123 (2026-11-02); no deviation from the spec. Its readings: the GM asks at report time for the time of every fix made outside a runner (12.1's `--since`); an incident fault whose planting failed is never re-planted within the aging, even with its run still ahead (16.3, access model 7). The stance check-list runs at the release gate (item 13).

- Goal: the GM designs and runs a v0.4 game as master spec 14 says.
- Scope: in: `SKILL.md`: designing with purposes and a domain (copying
  the material, the placement guideline, a second instance's exporter);
  writing the data policy from `governance:`; the starter pack telling
  which jobs the players may move; the judged moment and `--since` from
  the players' report; a shared host refused by `fit`; a failed
  incident's handling (the hand-over check failing, the offer to set the
  game up again); a job run by hand refused as load control; the web
  front in every game (spec D224): the hand-over always giving the tools
  password and naming the starter-pack page (W1-z), and v0.3's lines
  saying a topology without a web interface has no front, publishes SSH
  only and hands over no tools password rewritten, wherever `SKILL.md`
  and `gmctl.md` say so (today in `SKILL.md`'s topology notes and
  hand-over, `gmctl.md`'s `deploy` and `status` lines).
  `feedback.md`: governance faults ("fixed" as 11.7), a report judged
  against an incident, an overstep on the agency's system (16.5), an
  exit 3 at the final answer; f10's check reading 2 until the incident
  is in the log, and on a failed planting (spec D256), and after the
  hand-over once a player alters the request, an overstep (spec D282). Designing
  governance: `separation: instance` only where the story's policy
  demands an instance of its own, judged by G1 (spec D253). `gmctl.md`:
  every line chunks 6 to 8 left, and those chunk 19 changed;
  `load-data`'s `pg_cron` clean-up lines, already written (spec D258),
  kept. Out: new scripts; the stance itself.
- Files: `.claude/skills/game-master/{SKILL,gmctl,feedback}.md`.
- Spec sections: master spec 7.3, 12.8, 13.3, 14 ("The GM skill"),
  16.3, 16.5; access model 3, 7, 10, 12; spec D224, D253, D256, D258,
  D282.
- Done when: the skill covers each item of master spec 14's "The GM
  skill"; every `gmctl` invocation in the three files parses with
  `gmctl`'s own parser; v0.3's stance check-list items are unchanged and
  v0.4's are added (an overstep judged, never credited; a job run by hand
  refused; `--since` from the report).
- Verification: chunk checks; the stance check-list runs at the release
  gate.

### Chunk 19 — `bastion` 0.4.0: the data policy, the starter-pack page, the web front in every game

Status: merged (w1, c15ff5b)
Wave: 1
Depends on: chunk 1, merged into `v0.4-w1` before this chunk's branch is
cut; G12 and G13 cleared before the branch is cut; for **19b**, chunk 2
(2a and 2b) merged into `v0.4-w1` and `v0.4-w1` merged into this chunk's
branch before 19b starts (in-wave: 19b edits chunk 2's files; both
halves' unit-suite runs after that merge-in); W1 item 4
(`seed.optional`); G3, G4. Inserted by spec D223; split by spec D225.
Architecture capture: none of its own; it records as built, as W1-z
(read by chunks 13, 16, 18): the page's paths, its form and section
order, the front's home with and without web interfaces, and how a later
element joins it.

- Goal: the bastion of master spec 7.3: the starter pack handed over as
  Markdown in the player's home and as a simple read-only page, the home
  of a web front that runs in every game, the data policy among them
  when the scenario has one.
- Scope: in:
  - **19a, the bastion**:
    - the Dockerfile installing Debian's `cmark-gfm` without
      recommends, at the version G13 cleared, with G13's build
      assertions (it runs; a table renders `<table>` with `-e table`;
      raw HTML is omitted, never `--unsafe`);
    - `brick.yaml`: `data-policy.md` in `seed.files`, `seed.optional`
      and `seed.paths` (`/home/player/data-policy.md`); the header and
      field comments saying the web front runs, port 8080 is published
      and `tools_password` is read in every game;
    - `gm-entrypoint`: a missing required starter file still refused,
      an absent optional one skipped; `data-policy.md` copied once like
      the others, never over an existing file; at every start, routes
      or none, the web front's configuration and password file written
      under `/run/web-front` and the page under `/run/web-front/www`
      from `/opt/gm/starter` (the starter pack as handed over, never
      the players' copies), each Markdown file rendered by `cmark-gfm`
      with the table extension, raw HTML not passed through; the page
      the front's home, one section per element present, in the order
      README, story, issues, data policy, then the links to the web
      interfaces when `GM_WEB_ROUTES` has any, and no such section or
      link when it has none; nothing for an absent element (no empty
      section, no link to it); the elements taken from one list, so a
      later one (a reporting tool) joins by an entry; behind the tools
      password like the rest of the front;
    - the comments of the `web-front` s6 `run` file and of
      `rootfs/usr/local/lib/gm/healthcheck`, which describe the front
      as down without a route (their behaviour, keyed on the
      configuration file, is unchanged);
    - `docs/player.md` (the page, always there; the Markdown copies in
      the home) and `docs/gm.md` (the optional seed file, the page, the
      front in every game, the package, the footprint at rest);
    - the stack test: with routes and a data policy, the four files in
      the home and the page answering 401 without the password, with it
      four sections, a README table rendered as an HTML table and the
      links to the routes; without a data policy, no such file, section
      or link; a player's edit of `~/story.md` absent from the page
      after a restart; with no route, the front up on port 8080, 401
      without the password, the page alone with no web-interface section
      or link, the health check green, the data policy still copied;
      the validator green throughout;
  - **19b, the loader and the scenarios without a web interface** (cut
    condition above):
    - `tools/gm/model.py`'s `_check_web_routes`: a node whose brick has
      a `web-routes` parameter (the bastion) publishes `{port: 8080,
      default: 8080}` whatever its routes, refused without it; the
      refusal of the port published with empty routes removed;
      `tools/tests/test_model.py`'s two port tests turned accordingly;
    - `{port: 8080, default: 8080}` added to the bastion of
      `scenarios/bookshop-new-server`, `tools/tests/fixtures/fixture-audit`,
      `fixture-v03-refusals` and any fixture chunk 2 added without it
      (`fixture-v04-refusals`), each `README.md` regenerated with the
      scenario-document skill;
    - `tools/tests/smoke.sh`: its `fixture-audit` assertions of v0.3's
      rule reversed: ports 22 and 8080 published, the web front up, the
      tools password among the status's secret files (seven) and its
      line present;
    - the format skill's web-routes rule (`SKILL.md`) and
      `templates/scenario.yaml`'s `published_ports` comment: 8080 always
      on the bastion; the scenario-document skill's empty-routes line
      (`template.md`, and `SKILL.md` where it says the same): no web
      interface, the front serving the starter pack alone, the tools
      password handed over;
  - Out: render (it publishes the ports `scenario.yaml` declares;
    unchanged); `tools/gm/state.py` (its tools-password line follows the
    published port, now always there; unchanged); the GM skill's
    hand-over lines (chunk 18); a common entry point for several games,
    a setup-wide homepage, a reporting tool (spec O135, v0.6); the
    scenarios' and fixtures' `data-policy.md` mappings (chunks 13, 16;
    the three v0.3 scenarios have no `governance:`).
- Files: 19a: `bricks/bastion/{Dockerfile,brick.yaml}`,
  `bricks/bastion/rootfs/usr/local/sbin/gm-entrypoint`,
  `bricks/bastion/rootfs/etc/s6-overlay/s6-rc.d/web-front/run`,
  `bricks/bastion/rootfs/usr/local/lib/gm/healthcheck` (comments only),
  `bricks/bastion/docs/{gm,player}.md`,
  `bricks/bastion/tests/{run-stack-test.sh,stack.test.yml,fixtures/}`;
  19b: `tools/gm/model.py` (`_check_web_routes` only),
  `tools/tests/test_model.py`, `tools/tests/smoke.sh`,
  `scenarios/bookshop-new-server/{scenario.yaml,README.md}`,
  `tools/tests/fixtures/{fixture-audit,fixture-v03-refusals,fixture-v04-refusals}/{scenario.yaml,README.md}`
  (where each has them),
  `.claude/skills/scenario-format/{SKILL.md,templates/scenario.yaml}`,
  `.claude/skills/scenario-document/{SKILL.md,template.md}`.
- Spec sections: master spec 6.4, 7.3, 11.5, 14 ("The loader"), 15,
  16.4, 19; access model 3, 5, 7 (the web front's 401), 13; spec D221,
  D222, D223, D224, D225.
- Done when: the stack test shows each 19a item above, among them every
  element shown only when the scenario provides it, an absent one
  leaving neither an empty section nor a dead link, and the front up
  without a route; the loader accepts the brick and refuses a bastion
  without port 8080, routes or not; every catalog scenario and fixture
  loads; each changed `README.md` matches a fresh regeneration;
  `test_brick_docs` and the unit suite pass; at the wave gate v0.3's
  scenarios pass their smoke runs, `bookshop-new-server` now with its
  front and page, tarnbeck's and fernway's bastion serving the page,
  and `smoke.sh` passes its reversed assertions; G6 run once merged.
- Verification: chunk checks, plus the stack test (needs G4); the smoke
  runs at the wave gate; G6 after its merge.
- Split rule: 19a the bastion brick (its image, start-up, documents and
  stack test); 19b the loader's port rule, the scenarios and fixtures
  without a web interface, `smoke.sh`, the format and scenario-document
  skills. Two commits, in that order.

Record: 19a 4a6f936, 19b cb82f3b, merge c15ff5b. No departure from the spec; outside its Files lines, 19b turned `test_fit`, `test_render`, `test_deploy`, `test_state` to `fixture-audit`'s new shape, and 19a's stack file gives `db` postgres 0.4.0's `cronspool` volume; `fixture-v04-refusals` keeps its local bastion copy. Outcome recorded as capture W1-z.

### Chunk 20 — `separation: instance` in G1, and the format's widenings

Status: merged (w3, 6b4ad78)
Wave: 3
Depends on: chunk 12 (merged), cut from `v0.4-w3`
Architecture capture: none: the set's call interface and breach lines
are W3-a's, and `CHECK_GOVERNANCE` already carries a class's
`separation` as written.
Owner: a `coding-executor` on the wave branch, briefed by the driver
(inserted by spec D253; fix-sized, no chunk-mode leader).

- Goal: the rule of master spec 11.6 for `separation: instance` (spec
  D253), and the fault format's reading of spec D254.
- Scope: in: G1 in `tools/gm/governance.sh` extended, for each class
  with `separation: instance`, over the databases the set already
  lists: on each node holding one of the class's locations, every
  database but `postgres` not among them is a G1 breach in the set's
  breach line, `G1 <node>/<database>` and why (it shares the instance
  of the class's location); the loader refusing `separation` with
  `locations: any` (`model._check_class_rules`), with its unit test;
  `fixture-instances` with `separation: instance` on `personal` (its
  `db` holds `shop` and `postgres` only, so the baseline holds), its
  policy saying so in plain words, and a breach planting a second
  database on `db`, expecting G1=1 G2=0 G3=0 G4=0, and dropping it on
  revert (as `smoke-governance.sh` runs breaches, `CREATE DATABASE`
  outside a transaction), its README regenerated; the format skill's
  `SKILL.md` line and `templates/scenario.yaml` comment (refused with
  `any`); for D254, `templates/fault.yaml`'s `seed_changes` comment
  widened to kinds `seed-file` and `state`, and `check_fault_dir`
  checking a `state` fault's `seed_changes` materials as it checks a
  `seed-file` fault's. Out: any scenario under `scenarios/`; G2 to G4.
- Files: `tools/gm/governance.sh`, `tools/gm/model.py`,
  `tools/tests/{test_model.py,smoke-governance.sh}`,
  `tools/tests/fixtures/fixture-instances/{scenario.yaml,player/data-policy.md,breaches/,README.md}`,
  `.claude/skills/scenario-format/{SKILL.md,templates/scenario.yaml,templates/fault.yaml}`.
- Spec sections: master spec 6.3, 6.9, 11.4, 11.6; [formats.md](../../formats.md)
  "Purposes, domain and governance", "Fault definition"; spec D253,
  D254.
- Done when: G1 reads 1 on the planted database, from `db` and from
  `reporting`, and 0 after its revert and on the compliant fixture; a
  scenario without `separation:` reads as before (every other breach's
  `expect:` unchanged, f9's check untouched); the loader refuses
  `separation` with `locations: any`; `check_fault_dir` reports a
  missing `seed_changes` material on a `state` fault; the fixture's
  README matches a fresh regeneration; the unit suite passes.
- Verification: chunk checks, plus `smoke-governance.sh` on armenelos
  (needs G4), under the host lock and a sleep inhibitor.
- Split rule: none; each file's change is a few lines.
Record: cf9d0a4, merge 6b4ad78. Unit suite 848 OK; `smoke-governance.sh` on armenelos 121/0 (the new breach `g1-separation-database.sql`, a database `scratch` on `db`: G1=1 from `db` and `reporting`, 0 after its drop). Differs from the text: `smoke-governance.sh` accepts an optional `-- first:` line in a breach file; the breach line's object for a whole database is the word `database` (`G1 db/scratch database: shares the instance of db/shop, …`); SKILL.md's fault paragraph left as is (still true for what is required). Risk: a planted database without CONNECT for PUBLIC reads 2, as the existing walk does.

### Chunk 21 — `pgbouncer` 0.1.1: the start-up DNS race

Status: merged (w4, ee6edc7)
Record: 63c6111, merged ee6edc7 (2026-11-02). The wait as written, no equivalent: `getent ahosts` once a second, bound 30 s, PgBouncer started after it either way, lines prefixed `pgbouncer-run:`. A swarm name resolves only once its container is healthy, so the bound covers the database node's time to healthy (5–8 s in the stack test); the 25-minute stuck lookup did not reproduce in the stack fixture, so 17a's `pooler workarounds: 0` is the proof. `docs/gm.md`'s Known limits: a database node replaced mid-game (served again ~600 s after, the swarm DNS lifetime) and one slower than 30 s; the cure `s6-svc -r`. Stack test 120 PASS twice; unit suite 848 OK. Wave log "Chunk 21 — merged".
Wave: 4
Depends on: nothing in the wave; cut from `v0.4-w4`; G3, G4.
Architecture capture: none: no interface changes (the brick's paths,
`brick.yaml` keys and runtime interface stay as v0.3's capture W1 set
them).
Owner: a `coding-executor` on the wave branch, briefed by the driver
(inserted by spec D305; fix-sized, no chunk-mode leader).

- Goal: a pooler started before its database node serves through it
  once the node is up (master spec 7.3, spec D305): the race the wave
  log's "Finding — the `pgbouncer` brick's start-up DNS race" records
  (the pooler ~50 ms before `db`; "DNS lookup failed: db: result=0 …
  (bad-af)" on every lookup for 25 minutes or more while `getent hosts
  db` resolves in the same container; 4 of 5 deploys; `s6-svc -r` of
  the service curing it at once) no longer reproduces.
- Scope: in:
  - the `pgbouncer` s6 service's `run`: before it execs PgBouncer, a
    bounded wait until every host a `host=` of the `[databases]`
    section of `/run/pgbouncer-conf/pgbouncer.ini` names resolves (a
    socket path and an entry without `host=` skipped), then PgBouncer
    started whether they resolve or not, so a name that never resolves
    (a player's edit, a fault) never keeps the node down; the wait and
    its outcome written to the service's log. The bound covers a
    database node starting seconds after the pooler, and stays well
    inside the health check's 60 s `start_period`. Or an equivalent the
    builder finds that meets "Done when", recorded in the Record line
    with why (master spec 7.3 then follows it). The evidence shows
    c-ares failing while `getent` resolves, so the proof is the
    stack-test case below, not a lookup answering;
  - the version: `brick.yaml`'s `version` and `image` 0.1.1 and its
    header comment; every `pgbouncer:0.1.0` tag in the brick (the
    Dockerfile's build comment, `docs/gm.md`, `tests/run-stack-test.sh`,
    `tests/stack.test.yml`);
  - `docs/gm.md`: the wait in "Start-up" (after `gm-entrypoint`, in the
    service's `run`) with its bound; "Supported faults" naming 0.1.1;
    "Known limits" saying so if the stack test shows the stuck lookup can
    still follow a good start (the database node replaced mid-game),
    curing that being out; footprint as measured;
  - the stack test: a case where the pooler starts before `db` resolves
    (for instance the pooler restarted while `db` is scaled to 0, `db`
    then scaled back up), then a query through the pooler to `db`
    succeeding within a bound and no `DNS lookup failed` line once `db`
    resolves; a case where a `[databases]` host never resolves, the
    pooler still healthy and its console answering after the bound; the
    existing cases passing;
  - the re-pins, in the same commit: `faults/pgbouncer-pool-too-small/fault.yaml`'s
    `applies_to` adding "0.1.1" (0.1.0 kept); `scenarios/tarnbeck-outdoor-shop`,
    `scenarios/tarnbeck-outdoor-campaign`, `tools/tests/fixtures/fixture-campaign`
    and `fixture-load` pinning `pgbouncer` 0.1.1, each `README.md`
    regenerated with the scenario-document skill; `tools/tests/test_model.py`'s
    two expected pins (`fixture-load`'s, `fixture-campaign`'s); the
    build comments of `tools/tests/{smoke-scenario,smoke-load}.sh`;
    `bricks/postgres/docs/gm.md`'s line on the fault applying to
    `pgbouncer` 0.1.0, now "0.1.1 and 0.1.0" as its scheduler line reads
    (folds into the unreleased `postgres` 0.4.0, no bump);
  - Out: `tools/tests/smoke-purposes.sh`'s WORKAROUND (chunk 17a's):
    it stays as a safety net that counts its uses, and the wave gate
    expects zero WORKAROUND lines; `.tech`'s two `pgbouncer 0.1.0`
    mentions, brought to 0.1.1 by `security-advisor` at the driver's
    call once merged (no package changes, so no dependency preflight;
    if the fix needs a package, the executor stops and the driver gets
    one); PgBouncer's own settings, unless they are the equivalent
    found; every other brick.
- Files: `bricks/pgbouncer/rootfs/etc/s6-overlay/s6-rc.d/pgbouncer/run`,
  `bricks/pgbouncer/{brick.yaml,Dockerfile,docs/gm.md}`,
  `bricks/pgbouncer/tests/{run-stack-test.sh,stack.test.yml}`,
  `faults/pgbouncer-pool-too-small/fault.yaml`,
  `scenarios/{tarnbeck-outdoor-shop,tarnbeck-outdoor-campaign}/{scenario.yaml,README.md}`,
  `tools/tests/fixtures/{fixture-campaign,fixture-load}/{scenario.yaml,README.md}`,
  `tools/tests/test_model.py` (the two pins),
  `tools/tests/{smoke-scenario,smoke-load}.sh` (build comments),
  `bricks/postgres/docs/gm.md` (the one line).
- Spec sections: master spec 7.3, 16.1, 16.4, 17 (item 1);
  [formats.md](../../formats.md) "Versions and pins"; spec D305.
- Done when: the stack test's new cases pass: the pooler, started
  before `db` resolves, serves a query through `db` once `db` is up,
  with no `DNS lookup failed` line after that; a pooler whose host never
  resolves starts after the bound; the existing cases pass; the image
  builds as `127.0.0.1:5000/dbagm/pgbouncer:0.1.1`; every catalog
  scenario and fixture loads, no pin naming `pgbouncer` 0.1.0 left; each
  changed `README.md` matches a fresh regeneration; `test_brick_docs`
  and the unit suite pass. At the wave gate, 17a's runs report
  `pooler workarounds: 0`.
- Verification: chunk checks, plus the brick's image build and stack
  test (needs G3, G4), under the host lock and a sleep inhibitor; 17a's
  runs hold the lock for hours, so these wait for a gap between them.
- Split rule: none; the fix is one script, the rest version lines.
- Note for 17a: its branch merges `v0.4-w4` in once this chunk has
  merged, so its remaining runs pin `pgbouncer` 0.1.1 (the image built
  on armenelos); its WORKAROUND stays, counted in each run's last line.

## Release gate

Against master spec sections 17 and 18, on `v0.4-w4` before it merges,
alone on the hosts, under the host lock and a sleep inhibitor, with
v0.1's to v0.3's checks still applying except those spec D311 moves.
**No aged run** (spec D193): an aged run is a one-off check, none before
v1.0. **No GM session and no run on the VPS** (spec D311): the stance
check-list, every two-host run and the rehearsal are v1.0 gating, listed
in the roadmap's [v1.0 gating](../README.md#v10-gating); the VPS stays
drained throughout. **No long-running test** (spec D312): those are v1.0
gating too, and every run left here is short. GM-side checks run from
the host.

1. Item 1: `scheduler` 0.2.0, `postgres` 0.4.0, `bastion` 0.4.0 and
   `pgbouncer` 0.1.1 pass the format skill's `docs/gm.md` check, with their validators and
   measured footprints (their chunks' stack tests at rest; the
   rehearsal's figures v1.0 gating, spec D311); G5, G6 and G13 cleared, `.tech` current; the
   scenario's starter-pack page showing its four elements.
2. Item 2: `formats.md`, the templates, the loader and the format skill
   carry master spec 6, the placement guideline included.
3. Items 3 and 4: the four purposes and the shop domain complete by the
   format skill, every column classed.
4. Item 5: the ten faults complete (injection, aging minimum, sealed
   check, solvability description); the governance check set G1 to G4,
   G1 judging `separation: instance` (spec D253, chunk 20).
5. Item 6: the scenario complete by the format skill, its data policy
   written, its README current.
6. Item 7: `gmctl`, the loader and render as in master spec 14, checked
   through items 8 to 11.
7. Item 8: the three existing scenarios re-pinned, each deploying and
   passing its v0.3 smoke test unchanged, every bastion serving the
   starter-pack page, `bookshop-new-server`'s with no web interface
   (spec D224); every existing fault's `applies_to` carrying the new
   versions.
8. Master spec 18.1: the scenario's smoke run on armenelos alone, every
   fault planted at once, every key and job running, run as the wave 4
   gate's `smoke` up to f8's wait and stopped there; f8's reading in it
   v1.0 gating (spec D312), f8 read present with every fault planted in
   chunk 17a's cycles run; the run's checks after that wait (every job
   and key since T0, `reporting`'s `pg_cron` job among them, the full
   `check`, the teardown) never reached in v0.4: a known limit, covered
   by the v1.0-gating smoke run (spec D313). `fit` refusing the VPS for `reporting` on the two-host
   playground declaration (the VPS declared `shared`, never set
   `active`: a placement check, no deployment). The run on armenelos
   plus the VPS: v1.0 gating (spec D311).
9. Master spec 18.2 and 18.3: every purpose fault's full cycle (f1 to f5,
   f7, f8), f4's moving the producer's invoicing, f5's and f7's with
   `--since`;
   f6 and f9 present, then fixed after their acceptance fix: chunk 17a's
   cycles run, passed up to f4's wait for the scenario's midnight (spec
   D310), not repeated. What it left unobserved, f4's steps after that
   midnight, f8's fixed reading and a clean end-to-end verdict (about
   nine hours): v1.0 gating (spec D312), not run in v0.4.
10. Master spec 18.4: the unfaulted scenario passing G1 to G4, rebuilt
    from `fixture-campaign`'s files (capture W4 item 8).
11. Master spec 18.5: f10 calibrated (G10 done, re-measured at 640M by
    chunk 15b, its 327 MiB normal run accepted as measured, spec D252)
    and run on armenelos
    alone, the VPS drained: its check present, PostgreSQL recovered, s6,
    `sshd` and `cron` untouched.
12. Master spec 18.6, the rehearsal: v1.0 gating (spec D311), not run
    in v0.4.
13. The stance check-list (v0.3's items, plus an overstep on
    `reporting` judged and not credited, a request to run a job by hand
    refused, `--since` taken from a report dating a fix outside the
    runner, the feedback on a report about f10 judged against the
    incident): v1.0 gating (spec D311), not played in v0.4.
14. The wave-gate quality command, green, without its two-host run
    (spec D311).
15. Every row of "Left for the build" has its finding recorded in the
    chunk's Record line and, for a brick, its `docs/gm.md`; the
    rehearsal's part of the footprint row is v1.0 gating (spec D311).
16. G11: the owner's judgement.
17. Release notes in [README.md](README.md): the measured figures, chunk
    17a's per-node memory on armenelos quoted as one-host smoke readings
    within the declared limits, the bricks' footprints and the scenario's
    `resources` standing as built; the known limits named by master spec
    18.7 (the nightly close running at its story's time; the trace's
    growth over a full aging, neither observed nor, without the
    rehearsal, extrapolated; hosts and timers through a night; f10
    within a real aging), what moved to v1.0 gating (spec D311: every
    two-host run, the rehearsal with its timer-fired early check and its
    figures, the stance check-list; spec D312: item 9's unobserved part,
    f4 after the scenario's midnight, f8's fixed reading and the cycles
    run's clean verdict, and f8's reading in the smoke run), f10's normal run at 327 MiB against the 320 MiB half (spec
    D252), the limits of `load-data`'s `pg_cron` clean-up (master spec
    14, spec D258), and the access model's known gaps that stand.
