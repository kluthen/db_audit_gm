# v0.6 — archive

Status: archived 2026-11-20. v0.6 was released: its release gate passed
on 2026-11-20 on `v0.6-rg` (items 1 to 7 passed, run or cited), G11 was
cleared by the owner the same day ("Release v0.6"; D599), with the
OpenSSL and nginx calls (D600) and wave 4's items ruled as proposed
(D601), and `v0.6-rg` was merged into `main` (`fceda75`). Live summary:
the [v0.6 page](../../versions/v0.6/README.md) and its release notes,
the [v0.6 master spec](../../versions/v0.6/master-spec.md) and its
[access model](../../versions/v0.6/access-model.md).

## Archived files

Kept verbatim; never edited after this pass. The build plan and the two
drafts keep their names and depth (`specs/versions/v0.6/` to
`specs/archive/v0.6/`); their links to the documents that stay in
`specs/versions/v0.6/` and to `../README.md` no longer resolve from
here, as their notices say. The decision and question files' links were
written from `specs/`; their links to the build plan and the drafts
were repaired to their archived paths.

| File | Purpose |
|---|---|
| [build-plan.md](build-plan.md) | The v0.6 build plan, v21: 22 chunks in four waves, the gates G1 to G15, the release gate. Fully executed; what it leaves is v1.0 gating's |
| [network-overview.md](network-overview.md) | The network overview's draft v4, with the text of O260–O268; consolidated into master spec 8 (D514) |
| [fake-aging.md](fake-aging.md) | Fake aging's draft v5, with the text of O271 and O272; consolidated into master spec 9 (D514) |
| [decisions-D480-D544.md](decisions-D480-D544.md) | v0.6's drafting (the owner's rulings of 2026-11-13, fake aging's direction, the pending points and the review's closures), consolidation and approval, and its build through wave 3's captures; D526 and D531 never issued |
| [decisions-D548.md](decisions-D548.md) | Chunk 11a's measured deviation: the shop's f9 carries no `suppressed_by` |
| [decisions-D578-D600.md](decisions-D578-D600.md) | Chunk 11b, G10.3 and wave 4 (`gauge_before`, the M1 comparison, PostgreSQL 19, O294 and O295, the forged past's counters), G10.4, the release gate and G11's first two rulings; D579 never issued |
| [decisions-D602.md](decisions-D602.md) | O251 and O269 closed at this pass: both loader refusals built |
| [open-questions-resolved.md](open-questions-resolved.md) | The register's paragraph on v0.6's drafting, its closed entries O21, O22 and O32, O251 and O269, its three v0.6 sections (the network overview, fake aging, PostgreSQL 19) at v0.6's close, and O135 with its section as it last stood |

The decision ranges stop around the entries left live: v0.7's D545–D547
and D549–D577, and D601 (v0.6's last, carried forward below).

## Where it now lives

Every archived decision is stated as fact in a live document, or marked
as history or a build record. Paths are relative to `specs/`. "MS" is
`versions/v0.6/master-spec.md` and "AM" `versions/v0.6/access-model.md`,
followed by their section numbers; "page" is `versions/v0.6/README.md`;
"roadmap" is `versions/README.md`; "register" is `open-questions.md`;
"build plan (archived)" is `archive/v0.6/build-plan.md` and "wave log"
`versions/v0.6/wave-log.md`. "History" marks a process or
build-sequencing ruling with no standing content, or a ruling a later
one replaced; "build record" points to the archived plan and the wave
log, and through them to the code, skill or fixture that now carries a
build ruling. Where the page and the master spec disagree, the master
spec is current.

| ID | Ruling | Now lives in |
|---|---|---|
| D480 | The entry point is one game's web front, a home page linking every site; nginx kept; no front above several games | page "The game's home page"; MS 7.2; `planes-and-access.md` "Bastion only" |
| D481 | No reporting tool | page "Out of scope"; MS 2, 7.5; roadmap |
| D482 | No network map or diagram for now | MS 2; roadmap "Beyond v1.0: a fictional cloud provider" |
| D483 | A network overview page, extracted from the player README, linked from the home page | MS 8.1, 8.6, 8.7 |
| D484 | The network overview is customer documentation that may be incomplete or wrong | MS 7.4, 8.1, 8.5 |
| D485 | What a node's entry holds | MS 8.2 |
| D486 | O251's loader refusal in v0.6's first chunk touching `model.py` | MS 6.10. History: built, O251 closed by D602 |
| D487 | O260–O267 closed as recommended | MS 7.2, 8.1 to 8.7; `formats.md` |
| D488 | O268: a handout describes the design; every handout a static snapshot of the mission's start | MS 7.4; `scenario-lifecycle.md` "Hand-over" |
| D489 | Two aging modes: real for extended games, fake for quick ones | MS 9.1; `scenario-lifecycle.md` "Aging"; `gm-stance.md` |
| D490 | Every fixable caveat of fake aging fixed, the rest documented | MS 9.9, 9.10 |
| D491 | A fake-aged game curates its faults; each declares its support | MS 9.5; `formats.md` "`fault.yaml`" |
| D492 | The bar: a student doing the audit doesn't stumble on the fake | MS 1, 9.10 |
| D493 | O22 closed: forged history and a compressed fill, never fake time | MS 9.13; `scenario-lifecycle.md` "Aging" |
| D494 | The players are never told about the aging process | MS 9.11. History: refined by D496 |
| D495 | v0.6 makes the shop and the campaign fake-ageable, the campaign's f10 `real-only` | MS 9.8 |
| D496 | Never during the game; once concluded, a reported tell may be explained | MS 9.11; `gm-stance.md` "During the game", "Feedback" |
| D497 | The GM's appreciation in two parts: the customer side, then a teaching moment | MS 10; `gm-stance.md` "Feedback"; page "The GM's feedback" |
| D498 | Fake aging's proposals accepted as written | MS 9, 12 |
| D499 | The feedback's customer side first, in the GM's voice from the customer's view | MS 10; `gm-stance.md` "Feedback" |
| D500 | The network overview's remaining details accepted as written | MS 8.1, 8.3 to 8.5 |
| D501 | The page's scope items: the website, `jq` and `tmux`, Reports, the partners' status pages | MS 7.1, 7.3, 7.5 to 7.7 |
| D502 | Only the data register and the network overview may carry a planted inaccuracy | MS 7.4; `scenario-lifecycle.md` "Hand-over" |
| D503 | Player-facing material in English | MS 11 |
| D504 | The GM asks once whether the initiator will play; a quick or extended game by duration only | MS 9.1, 9.2; `gm-stance.md` "At setup" |
| D505 | N9, the overview's absence, dropped | MS 8.5 |
| D506 | A fake game's restart record, `local/<playground>/fake-aging.yaml` | MS 6.7, 6.9; `formats.md` "A fake game's records" |
| D507 | The monitoring starts in the maintenance restart; the early check halfway through the tail | MS 9.4 |
| D508 | P0 binds the virtual instant in the fill's SQL; `pg_cron` off in the fill | MS 9.4, 9.8 |
| D509 | The blind reads and the GM-behaviour checks join v1.0 gating | roadmap "v1.0 gating"; MS 12.2 |
| D510 | O269 settled as the loader refusal | MS 6.10. History: built, O269 closed by D602 |
| D511 | Reports a `~/reports/` folder served sandboxed; the bastion's short tests | MS 7.5, 12.1; page "Short tests" |
| D512 | The drafts' text corrections | History: the drafts (archived) |
| D513 | The partners' status pages: `admitted:`, a root-only status file, no route to a partner | MS 7.6; `formats.md` "Scenario", "Partners" |
| D514 | v0.6 consolidated into its master spec and access model | History (process): MS and AM status lines |
| D515 | Every brick takes a new version in v0.6 | MS 6.8 |
| D516 | D504 confirmed | MS 9.2 |
| D517 | The master spec and access model approved | MS and AM status lines |
| D518 | The build plan approved, κ = 2 | History (process): build plan (archived) header, "Gates" |
| D519 | No reference data in git; `results/` archived outside it | MS 5, 12.3 |
| D520 | `fa-real` torn down once chunk 1 merged | History (build sequencing): build plan (archived) G12 |
| D521 | O269's lines declared as `seed_changes[].lines` | MS 6.3, 6.9, 6.10; `formats.md` "Injection" |
| D522 | `admitted.from` is `T0` or `handover-<N>h` | MS 6.9 |
| D523 | A routine pinning its own `search_path` is covered for the fill's span | MS 9.4, 9.8, 9.10, 18 |
| D524 | Chunk 15 inserted in wave 2 to build the cover | History (build sequencing): build plan (archived) chunk 15 |
| D525 | In a fake game `load-data` and the T0 plantings run on the virtual T0's clock | MS 9.4, 9.9 |
| D527 | The fill's pause plantings run at the pause's virtual instant | MS 9.4, 9.9 |
| D528 | In a fake game an ineligible instance is refused, not the game | AM 7 |
| D529 | In DDL under fix 11's means, `now()` and its kin are written `pg_catalog.` | MS 9.9 |
| D530 | `gm_vclock` right before `pg_catalog` on every path P0 sets | MS 9.4, 9.9 |
| D532 | A `tail_covers` instant counts from one floor before it | MS 9.6 |
| D533 | `fixture-fill`'s f8 a scenario-local fixture fault | Build record: build plan (archived) chunk 9; wave log |
| D534 | Waves 1 and 2's forms written as built (G10.1, G10.2) | `formats.md` (v36); MS 6.7, 6.9, 9.4, 9.9 |
| D535 | `gmctl clean-restart` refused before the planned anchor | MS 6.9, 9.4 |
| D536 | The statistics reset is the maintenance's step before the stop | MS 9.4, 9.9, 9.10 |
| D537 | The scenario document shows each instance's `admitted:` | MS 7.6; build plan (archived) chunk 12 |
| D538 | Every fixture's scenario document regenerated in v0.6 | Build record: build plan (archived) chunk 16; wave log; ISS-009 |
| D539 | `postgres` 0.5.1 re-pins `pg_cron` and `pgaudit` against 18.7; pgAudit 18.1 deferred | History: superseded by D587 (PostgreSQL 19, pgAudit 19.0); page "PostgreSQL 19 everywhere" |
| D540 | The players keep their shell on the Prometheus node; the TSDB folder keeps the blocks from it | MS 9.10, 18 |
| D541 | Prometheus' own series showing the import are a documented limit | MS 9.10 |
| D542 | A GM-run game never leaves refused an instance a handout names | MS 9.1, 9.8, 12.2; AM 7 |
| D543 | `suppressed_by` drops an entry from the hiding instance's planting onward | MS 6.3, 9.5; `formats.md` |
| D544 | The "Fake aging" section carries the setup's measured time | MS 9.2, 9.10 |
| D548 | The shop's f9 carries no `suppressed_by` over f4; its f5 no `daily_spike` | MS 6.9, 9.8 |
| D578 | The campaign's f5 carries no `suppressed_by`; no covered fault uses D543's rule | MS 6.9, 9.5, 9.7, 9.8; ISS-007 |
| D580 | Wave 3's forms written as built (G10.3) | `formats.md` (v39); MS 6.3, 6.7, 6.9, 9.5, 9.7, 9.8, 12.1, 18 |
| D581 | The seam's join checked on size gauges only | `formats.md` (v39); MS 9.4, 12.1 |
| D582 | A fake game's restart with no history rebuilds on the real clock | MS 9.4; `formats.md` (v39) |
| D583 | One history import at a time; once `ok`, no run imports again | MS 9.4; `formats.md` (v39) |
| D584 | The shop's f8 gains a measured `gauge_before`, its form O292 | `faults/pg-join-index-missing/` (`history:`). History: its form ruled by D585; build plan (archived) chunk 12 |
| D585 | A `gauge_before` adds its value to the level drawn before the planting | `formats.md` (v40) "Fault definition" |
| D586 | The shop's M1 comparison scales run R to the short game's span | MS 12.1 |
| D587 | PostgreSQL 19 in every brick and scenario of v0.6 | MS 6.8, 7.7; page "PostgreSQL 19 everywhere" |
| D588 | zlib1g's DSA-6613-1 handled at the release gate | page "Fixes made at the release gate", "Security, accepted risks and the owner's rulings" |
| D589 | Chunk 17 inserted in wave 4, split 17a to 17c | History (build sequencing): build plan (archived) chunks 17a to 17c |
| D590 | Fake aging's numbers measured on 18 stand, one size re-measured | page "PostgreSQL 19 everywhere"; roadmap "v1.0 gating" |
| D591 | O294: pgBadger's empty checkpoint section on 19 a known limit | page "Known limits"; `bricks/postgres/docs/gm.md` |
| D592 | O295: `log_autoanalyze_min_duration = 0` beside every `log_autovacuum_min_duration = 0` | page "PostgreSQL 19 everywhere"; the seeds' `postgresql.conf` |
| D593 | `n_live_tup` leaves the shop's M1 judged set | MS 12.1 |
| D594 | The forged past's counters follow what drives them | MS 9.9 (fix 12) |
| D595 | Chunk 18 inserted in wave 4; D594's reading | MS 9.9. History (build sequencing): build plan (archived) chunk 18 |
| D596 | Capture W4's items 1 to 5 as chunk 12b built them | MS 12.1. Build record: wave log, capture W4 |
| D597 | Wave 4's forms written as built (G10.4) | `formats.md` (v41); MS 9.7, 9.9, 9.10, 12.1, 18; roadmap "v1.0 gating" |
| D598 | Prometheus' retention after a compaction read in v1.0 gating | roadmap "v1.0 gating"; MS 18 |
| D599 | G11 cleared; v0.6 released | page "Release notes"; build plan (archived) G11 |
| D600 | OpenSSL's 10 CVEs open at the release; nginx's 14 NVD matches ignored | page "Security, accepted risks and the owner's rulings"; `.tech` |
| D602 | O251 and O269 closed: both loader refusals built | MS 6.10; page "What v0.6 delivers", "Questions due in this version" |

Resolved questions, each living where its deciding decision lives (row
above):

| Questions | Resolved by |
|---|---|
| O135 | D480, D481 |
| O21 | D484 (narrowed), D502 |
| O22 | D489–D493 |
| O32 | D503 |
| O260–O267 | D487 |
| O268 | D488 |
| O271 | D494, refined by D496 |
| O272 | D495 |
| O292 | D585 |
| O294 | D591 |
| O295 | D592 |
| O251 | D486 (placed), D602 (built) |
| O269 | D510 (settled), D602 (built) |

O273, O293, O296 and O297 were never used (O296 and O297 reserved
during v0.6's build).

## Left in place

| Document | Role | Referrers |
|---|---|---|
| `specs/versions/v0.6/README.md` | The version's page: scope, the rulings, short tests, release notes, known limits, accepted risks | `specs/README.md`, `specs/versions/README.md`, `specs/open-questions.md`, `specs/versions/v1.0/README.md`, the archived decisions |
| `specs/versions/v0.6/master-spec.md` | The contract for what v0.6 built, and v0.7's baseline | `specs/versions/v0.7/master-spec.md`, `specs/formats.md`, `specs/gm-stance.md`, `specs/scenario-lifecycle.md`, `specs/planes-and-access.md`, `specs/bricks-and-faults.md`, `.claude/skills/`, `issues/ISS-007`, `issues/ISS-008` |
| `specs/versions/v0.6/access-model.md` | The master spec's companion, a delta on v0.5's; in force for v0.6 and v0.7 games | `specs/README.md`, `specs/versions/v0.7/access-model.md`, the page |
| `specs/versions/v0.6/wave-log.md` | Execution record, but its captures fix forms that code comments and skills cite ("capture W1 item 5") | bricks (`bastion`, `grafana`, `postgres`, `scheduler`), `.claude/skills/`, `faults/docs-overview-backup-claimed/`, `tools/fake_aging/`, `issues/ISS-007` to `ISS-009` |

The wave log stays live, as v0.3's, v0.4's and v0.5's do. Its line 3
link to the build plan was repaired to the archived path; its later
mentions of `build-plan.md` with line numbers, and the `doc-get --plan
specs/versions/v0.6/build-plan.md` usage line, record what was true when
written and are left as they are.

## Carried forward

- Every open question stays live in
  [open-questions.md](../../open-questions.md) with its ID: O2, O5, O10
  to O12, O16, O20, O23 to O25, O29 to O31, O38, O48, O49, O52 to O54,
  O130, O136, O138, O231, O232, O249, O270, O291, O298 and O299. O298
  and O299 were ruled at G11 (D601) and stay open until done; O291 is
  v0.7's. The closed game-assistant entries (O274–O290) stay in the
  register until v0.7's archive.
- D601 stays live in [decisions.md](../../decisions.md) until what it
  rules is done: O298 (pgaudit loaded in `lab` and `portal` in a later
  build touching the clinic), O299 (the owner's amended grid copied
  in), ISS-009 (fixed in v0.7).
- Open issues: ISS-006 (in progress), ISS-007, ISS-008, ISS-009, and
  v0.5's ISS-002 (O270).
- v1.0 gating, in the [roadmap](../../versions/README.md#v10-gating):
  v0.6's additions (D509, D597, D598): fake aging's full selections
  with their real tails, Prometheus' retention after a compaction, the
  blind reads, the stance check-list's v0.6 items, fake aging's figures
  on 19.
- Known limits and accepted risks in the
  [v0.6 page](../../versions/v0.6/README.md#release-notes): pgBadger's
  checkpoint section on 19 (D591), fake aging's documented limits, its
  coverage (the shop and the campaign), the short games' margin;
  OpenSSL's CVEs until a trixie DSA or 2027-02-01, nginx's ignores until
  2027-05-01 (D600); v0.5's standing ones.
