# v0.4 — archive

Status: archived 2026-11-03. v0.4 was released at its release gate on
2026-11-03 (items 1 to 11, 14, 15 and 17 passed or stand as run, items
12 and 13 moved to v1.0 gating, G11 cleared) and merged into `main` on
the owner's word ("option c, G11 ok, merge"). Live summary: the
[v0.4 page](../../versions/v0.4/README.md) and its release notes, and
the [v0.4 master spec](../../versions/v0.4/master-spec.md).

## Archived files

Kept verbatim; never edited after this pass. The moved documents keep
their names and depth (`specs/versions/v0.4/` to `specs/archive/v0.4/`);
their links to the documents that stay in `specs/versions/v0.4/` (the
page, the master spec, the access model, the wave log and the four kept
drafts) and to `../README.md` and `../v0.3/` or `../v0.5/` no longer
resolve from here, as each file's notice says. The decision and question
files' links were written from `specs/`.

| File | Purpose |
|---|---|
| [build-plan.md](build-plan.md) | The v0.4 build plan, v16: chunks 1 to 21 in four waves, the gates G1 to G13, the release gate. Fully executed; what it moved is v1.0 gating |
| [purposes.md](purposes.md) | Draft: the purpose as an artefact, instances and node sizing, the job runner and the transformer script, moving data between instances, cadence under real time, the customer's time zone |
| [database-node-jobs.md](database-node-jobs.md) | Draft: `pg_cron` and a cron daemon in `postgres` 0.4.0, the placement guideline, the out-of-memory incident |
| [checks.md](checks.md) | Draft: invariant checks judged by runs since a moment, witnesses, pushed obligations, definition checks, `gmctl` changes, the release gate |
| [scenario-sketch.md](scenario-sketch.md) | Draft: the first v0.4 scenario's story, topology and sizing, ten fault instances, issues |
| [decisions-D190-D191.md](decisions-D190-D191.md) | v0.4's direction: purposes, a first cut of data governance |
| [decisions-D193-D195.md](decisions-D193-D195.md) | Aged runs one-off; no engine beyond PostgreSQL; no mail sink |
| [decisions-D197-D200.md](decisions-D197-D200.md) | The four purposes, the reporting instance, cadences, the release gate's purpose cycle |
| [decisions-D202-D231.md](decisions-D202-D231.md) | The technology direction, jobs on a database node, the cloud provider's direction, the master spec's and build plan's approval, waves 1 to 3's rulings and readings (no D210 was issued) |
| [decisions-D239-D247.md](decisions-D239-D247.md) | Chunks 15a's and 14's readings of f7, f9, f1, f2 and f5 |
| [decisions-D252-D258.md](decisions-D252-D258.md) | G10's acceptance, `separation: instance`, chunk 15b's readings of f10, `load-data`'s `pg_cron` clean-up |
| [decisions-D281-D284.md](decisions-D281-D284.md) | Capture W4's readings and the ruling on f5 masking f4 |
| [decisions-D305.md](decisions-D305.md) | The `pgbouncer` start-up race fixed as 0.1.1 |
| [decisions-D310-D313.md](decisions-D310-D313.md) | 17a's runs, the moves to v1.0 gating, the smoke run's end-of-run checks a known limit |
| [open-questions-resolved.md](open-questions-resolved.md) | The open-questions register's "Resolved during v0.4" paragraph, its "v0.4: purposes" section and its data governance introduction at v0.4 close, and the five build questions' entries (O140, O146, O161 to O163) as they last stood |

The eight drafts were consolidated into the master spec on 2026-10-30
and kept since as the working record, stale by design where the master
spec supersedes them. Four are archived as superseded snapshots; the
other four stay in place (below).

The decision ranges stop around the entries still live: D192, D196 and
D201 (v0.5's scope, set while v0.4 was drafted) and v0.5's own drafting,
D233 to D238, D248 to D251 and D260 to D262 on this branch, D263 to D280,
D285 to D304 and D306 to D309 on `v0.5-domains`. D232 and D259 were
never issued as entries (the wave log notes D259 reserved, unused).

## Where it now lives

Every archived decision is stated as fact in a live document, or marked
as history. Paths are relative to `specs/`. "MS" is
`versions/v0.4/master-spec.md` and "AM" `versions/v0.4/access-model.md`,
followed by their section numbers; "page" is `versions/v0.4/README.md`;
"roadmap" is `versions/README.md`. "History" marks a process or
build-sequencing ruling with no standing content, or wording a later
decision replaced; "build record" points to the code, skill or wave log
that now carries a build ruling.

| ID | Ruling | Now lives in |
|---|---|---|
| D190 | v0.4 is purposes, "bricks of why and bits of hows"; a generic job runner and a second database | MS 1, 2, 8; page "Goal" |
| D191 | A first cut of data governance, coupled to purposes | MS 11.1, 11.8; page "Data governance" |
| D193 | An aged run is a one-off check, none before v1.0 | roadmap "Release gates", "v1.0 gating"; MS 18 |
| D194 | No v0.4 purpose needs an engine beyond PostgreSQL | MS 2, 22; O11 |
| D195 | No mail sink: `mail_outbox` is the mail's trace | MS 2, 10.3 |
| D197 | Four purposes on the shop; finance held for v0.5 | MS 10, 10.5 |
| D198 | The reporting database an instance of its own | MS 11.4, 13.1 |
| D199 | Realistic cadences; no weekly or monthly purpose | MS 8.4 |
| D200 | The release gate's purpose cycle and named known limits | MS 18 |
| D202 | Several PostgreSQL instances; data moved mainly by transformer scripts | MS 8.6, 13.1 |
| D203 | `scheduler` extended to 0.2.0 with transformer scripts and the `transformer` role | MS 7.1 |
| D204 | Nodes sized by role; a node is a scenario node | MS 13.2 |
| D205 | A fictional cloud provider after v1.0 | roadmap "Beyond v1.0: a fictional cloud provider"; open part in O130 |
| D206 | Jobs on a database node: `pg_cron` and a cron daemon in `postgres` 0.4.0 | MS 7.2, 8.7; systemd timers: MS 2 "Out of scope" |
| D207 | The placement guideline | MS 8.7; `formats.md` "Where a job runs" |
| D208 | One planted crontab fault on `db` | MS 16.1, 16.2 |
| D209 | The out-of-memory incident, report only | MS 16.3 |
| D211 | The agency's database report-only by the story alone | MS 7.2, 16.5; AM |
| D212 | v0.4 builds the scenario's ten faults only | MS 16.2, 22; the other candidates: `versions/v0.4/candidate-faults.md` (left in place) |
| D213 | f10 calibrated early, on armenelos only | MS 16.3, 19 |
| D214 | The gateway loses one acknowledgement in fifty | MS 10.4 |
| D215 | The master spec and access model approved | MS status line; AM |
| D216 | The build plan approved, κ = 3 | History (process): `archive/v0.4/build-plan.md` (archived) |
| D217 | The judged moment before the hand-over | MS 12.1, 14 |
| D218 | f10's "without swap" measured in a one-off container | MS 16.3 |
| D219 | The loader's widened cron subset; `streams` may be `[]` | Build record: `versions/v0.4/wave-log.md` W1 item 0 (left in place); `tools/gm/model.py` |
| D220 | Chunk 4 merged after chunk 2a | History (build sequencing) |
| D221 | `bastion` 0.4.0: the starter pack as Markdown and as a page | MS 6.4, 7.3, 11.5, 15 |
| D222 | The page rendered by `cmark-gfm` at each start | MS 7.3 |
| D223 | `bastion` 0.4.0 inserted as chunk 19 | History (build sequencing) |
| D224 | The web front in every game, its home the starter-pack page | MS 2, 7.3, 14, 16.4, 22; AM 3, 13 |
| D225 | Chunk 19 split | History (build sequencing) |
| D226 | A seed-file change names a database node's data file `data` | MS 6.3; `formats.md` "Fault definition" |
| D227 | `reporting`'s limit at 640M | MS 16.1 |
| D228 | E4's 30 minutes are the acknowledgement's deadline | MS 10.4, 12.4 |
| D229 | A test-only brick change bumps nothing | `formats.md` "Versions and pins"; the `scenario-format` skill |
| D230 | The game's own roles skipped as readers only | MS 11.6, 11.7; AM 9.3 |
| D231 | An outbound flow's `fields` are its payload keys | MS 6.9, 11.3, 11.6; AM 9.3; `formats.md` "Purposes, domain and governance" |
| D239 | f7's N written into `reporting`'s data file | MS 16.2 |
| D240 | f7's evidence is `\sf rpt.close_day` | MS 16.2 |
| D241 | A check on a database node judging a runner's job by a ledger there | MS 12.1, 12.5, 18 |
| D242 | f9's planting grants `bi_etl` `CREATE` on `rpt` | MS 16.2 |
| D243 | `dba` unschedules another role's `pg_cron` job by its id | MS 16.2, 16.5; AM 9.4 |
| D244 | f2's producer path a fix only with the drifted flags repaired | MS 16.1, 16.2 |
| D245 | f5's planting ends `shop_etl`'s open sessions | MS 16.2 |
| D246 | f5's `remaining=` counted to the designed minute from the ledger | MS 12.5 |
| D247 | A five-minute job's fault needs an hour: f1's minimum 1h | MS 16.2 |
| D252 | f10's normal run at 327 MiB accepted | MS 16.3; page "Known limits" |
| D253 | `separation: instance` a rule of G1 | MS 6.9, 11.4, 11.6; `formats.md` |
| D254 | A `state` fault may carry `seed_changes` | MS 6.3; `formats.md` "Fault definition" |
| D255 | f10's roll-up reads through its own foreign table | MS 9.6, 16.3 |
| D256 | f10's check dates the planting from `requested_at` | MS 16.3 |
| D257 | The night after a killed backfill | MS 16.3 |
| D258 | `load-data` removes the `pg_cron` launcher's start-up failures | MS 7.2, 14; page "Known limits" |
| D281 | A G1 breach of `separation: instance` names the whole database | MS 11.6 |
| D282 | f10's check reads 2 once a player alters the request | MS 16.5 |
| D283 | The rehearsal runs without f7 as well as f10 | MS 18 item 6; roadmap "v1.0 gating" |
| D284 | f4 expected "too soon" at the hand-over check, masked by f5 | MS 6.2, 12.2, 16.1 |
| D305 | The `pgbouncer` start-up race fixed as 0.1.1 | MS 7.3, 16.1, 16.4, 17; `bricks/pgbouncer/docs/gm.md` |
| D310 | 17a done without f4's after-midnight steps and its two-host run | page "Release gate results" item 9. History: what it left open moved by D311 and D312 |
| D311 | The two-host runs, the rehearsal and the stance check-list to v1.0 gating | roadmap "v1.0 gating"; MS 18 |
| D312 | Long-running tests to v1.0 gating | roadmap "v1.0 gating"; MS 18 |
| D313 | The smoke run's end-of-run checks a known limit, covered by v1.0 gating | page "Known limits"; roadmap "v1.0 gating"; MS 18 |

Resolved questions, each living where its deciding decision lives (row
above). O118, held for v0.5, was closed by its rulings D250 and D261,
which stay live:

| Questions | Resolved by |
|---|---|
| O104, O108, O115, O116, O117, O119, O122, O124, O125 | D215 (O111's v0.4 part too; O111 stays open for v0.5) |
| O105 | D203 |
| O106 | D194 |
| O107 | D197 |
| O109 | D199 |
| O110 | D195 |
| O120 | D198 |
| O121 | D200 |
| O123 | D202 |
| O129 | D206 |
| O131 | D207 |
| O132 | D211 |
| O133 | D212 |
| O134 | D224 |
| O140 | D253 |
| O146 | D284 |
| O161 | D311 |
| O162 | D312 |
| O163 | D313 |

## Left in place

| Document | Role | Referrers |
|---|---|---|
| `specs/versions/v0.4/README.md` | The version's page: scope, status, release notes, known limits, known issues (the c-ares advisories in `pgbouncer`, `.tech` awaiting the owner) | `specs/README.md`, `specs/versions/README.md`, `specs/decisions.md`, `specs/open-questions.md`, `specs/versions/v0.5/README.md`, `specs/versions/v1.0/README.md`, `specs/planes-and-access.md` |
| `specs/versions/v0.4/master-spec.md` | The contract for what v0.4 built; the skills' stated source | `.claude/skills/game-master/SKILL.md`, `.claude/skills/scenario-format/SKILL.md`, `.claude/skills/scenario-document/SKILL.md`, `specs/formats.md`, `specs/open-questions.md`, `specs/README.md`, `specs/versions/README.md` |
| `specs/versions/v0.4/access-model.md` | The master spec's companion; in force for v0.4 games | `.claude/skills/game-master/SKILL.md`, `specs/README.md`, `specs/versions/README.md` |
| `specs/versions/v0.4/wave-log.md` | Execution record, but its captures fix brick keys, templates, the loader's rules and `gmctl`'s forms; moving it would change released bricks (a brick changes version with any change, its comments included) and the generated scenario documents | `bricks/postgres/` (`brick.yaml`, `Dockerfile`), `bricks/scheduler/` (`brick.yaml`, `docs/gm.md`, `program/gm_scheduler/__init__.py`), `.claude/skills/game-master/SKILL.md` and `gmctl.md`, `.claude/skills/scenario-format/SKILL.md` and its templates, `scenarios/tarnbeck-outdoor-campaign/`, `tools/gm/governance.py`, `governance.sh`, `inject.py`, `model.py`, `render.py`, `tools/tests/test_model.py`, `tools/tests/fixtures/fixture-campaign/`, `fixture-v04-refusals/` |
| `specs/versions/v0.4/purpose-catalogue.md` | Draft: the shop's purposes; P5 and the clinic's stress test, cited by v0.5's scope | `specs/versions/v0.5/README.md` (here and on `v0.5-domains`), `specs/decisions.md` (D201), `specs/versions/v0.4/README.md` |
| `specs/versions/v0.4/shop-domain.md` | Draft: the shop as the first domain, the model v0.5's domain procedure names for a domain's draft document | `specs/versions/v0.5/domain-procedure.md` (here and on `v0.5-domains`), `specs/versions/v0.4/README.md` |
| `specs/versions/v0.4/governance.md` | Draft: the governance first cut; its database-versus-instance boundary cited by v0.5's scope | `specs/versions/v0.5/README.md`, `specs/versions/v0.5/brick-options-review.md` (here and on `v0.5-domains`), `specs/open-questions.md`, `specs/versions/v0.4/README.md` |
| `specs/versions/v0.4/candidate-faults.md` | Draft: the candidate faults v0.4 did not build, recorded for later versions (D212; MS 22 names them), their injection and evidence; v0.5's clinic draws on them | `specs/versions/v0.4/README.md`, the kept drafts |

## Carried forward

- Every open question stays live in
  [open-questions.md](../../open-questions.md) with its ID: O2, O5, O10
  to O12, O16, O20 to O25, O29 to O32, O38, O48, O49, O52 to O54, O79,
  O111 to O114, O127, O128, O130, O135, O136 and O138. None was raised
  or resolved by this pass (O163 was closed by D313 just before it).
- Decisions D107 and D113 stay live (to be applied in v0.5), and v0.5's:
  D192, D196, D201, D233 to D238, D248 to D251, D260 to D262.
- v1.0 gating, in the [roadmap](../../versions/README.md#v10-gating):
  the stance check-list, every two-host session, v0.4's rehearsal and
  its figures, the long-running tests, the smoke run's end-of-run checks
  (D311 to D313).
- Known issues in the [v0.4 page](../../versions/v0.4/README.md), "Known
  issues": the c-ares advisories in `pgbouncer` (adding c-ares to
  `.tech` awaits the owner), `pgbouncer` 0.1.1's limits, the scheduler
  image rebuilt at the wave 4 gate.
