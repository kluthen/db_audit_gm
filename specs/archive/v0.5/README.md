# v0.5 — archive

Status: archived 2026-11-14. v0.5 was released: its release gate passed
on 2026-11-13 (items 1 to 10 passed or cited, the whole clinic deployed
once on armenelos plus the VPS), G15 was cleared by the owner on
2026-11-14 ("ok"; D475), and `v0.5-g13` was merged into `main`
(`a56e5ac`). Live summary: the [v0.5 page](../../versions/v0.5/README.md)
and its release notes, the [v0.5 master spec](../../versions/v0.5/master-spec.md)
and its [access model](../../versions/v0.5/access-model.md).

## Archived files

Kept verbatim; never edited after this pass. The build plan keeps its
name and depth (`specs/versions/v0.5/` to `specs/archive/v0.5/`); its
links to the documents that stay in `specs/versions/v0.5/` and to
`../README.md` no longer resolve from here, as its notice says. The
decision and question files' links were written from `specs/`; their
links to the build plan were repaired to its archived path.

| File | Purpose |
|---|---|
| [build-plan.md](build-plan.md) | The v0.5 build plan, v21: 38 chunks in five waves, the gates G1 to G19, the release gate. Fully executed; what it leaves is v1.0 gating's |
| [decisions-D107.md](decisions-D107.md) | Brick options a v0.5 topic (v0.2's ruling, applied in v0.5) |
| [decisions-D113.md](decisions-D113.md) | The `monitoring` role in every postgres game until v0.5 (v0.2's ruling, applied in v0.5) |
| [decisions-D192.md](decisions-D192.md) | v0.5 brings business domains |
| [decisions-D196.md](decisions-D196.md) | The veterinary clinic franchise a v0.5 domain |
| [decisions-D201.md](decisions-D201.md) | Round trips are v0.5's |
| [decisions-D233-D238.md](decisions-D233-D238.md) | v0.5 centred on domain definition and the clinic; the post-mortems; the procedure; options; datasets later; monitoring breadth |
| [decisions-D248-D251.md](decisions-D248-D251.md) | The scope review: the sorting, the clinic's split, `postgres` for the clinic, the post-mortems' binding |
| [decisions-D260-D280.md](decisions-D260-D280.md) | The procedure approved, pgaudit and options, scale and variants, the producer-profile frictions, third parties, `vet-core`'s sketch, split and governance |
| [decisions-D285-D304.md](decisions-D285-D304.md) | One centre, round trips, the ward service, cold storage, the options model, the fault budget, the parts, replication, `office`, `vet-lab`, the profiles |
| [decisions-D306-D309.md](decisions-D306-D309.md) | The purposes and their format extensions, the partners on one node, fault selection the GM's |
| [decisions-D314-D476.md](decisions-D314-D476.md) | Short tests (D314), the parts' drafts, the data register, the consolidation and approvals, the build's corrections and readings in five waves, the owner's security rulings, the release close (D474–D476); D337, D341, D359, D371, D392, D429, D430 and D470 never issued |
| [open-questions-resolved.md](open-questions-resolved.md) | The register's "Resolved during v0.5" paragraph and its "v0.5: domains" introduction and closed entries at v0.5's close, and the entries of O220, O223–O227 and O229 as they last stood |

The decision ranges stop around v0.4's archived entries (D193–D195,
D197–D200, D202–D231, D239–D247, D252–D258, D281–D284, D305,
D310–D313). D477–D479, set aside for v0.5's close, were unused at this
pass; the numbers after them are v0.6's drafting's.

## Where it now lives

Every archived decision is stated as fact in a live document, or marked
as history or a build record. Paths are relative to `specs/`. "MS" is
`versions/v0.5/master-spec.md` and "AM" `versions/v0.5/access-model.md`,
followed by their section numbers; "page" is `versions/v0.5/README.md`;
"roadmap" is `versions/README.md`; "register" is `open-questions.md`; a
document in backticks without a folder is in `versions/v0.5/` (left in
place, below); "build plan (archived)" is `archive/v0.5/build-plan.md`
and "wave log" `versions/v0.5/wave-log.md`. "History" marks a process
or build-sequencing ruling with no standing content, or a ruling a
later one replaced; "build record" points to the archived plan and the
wave log, and through them to the code, skill or fixture that now
carries a build ruling. Where a draft left in place and the master spec
disagree, the master spec is current.

| ID | Ruling | Now lives in |
|---|---|---|
| D107 | Brick options are a v0.5 topic; v0.2 stays as built | page "In scope"; MS 7.1 |
| D113 | The `monitoring` role stays in every postgres game until v0.5 | MS 7.1 (the `monitoring` option); page "In scope" |
| D192 | v0.5 brings business domains | page "Domains"; MS 1, 8 |
| D196 | The veterinary clinic franchise is a v0.5 domain candidate | page "The veterinary clinic"; MS 9 |
| D201 | Round trips, an acknowledgement as an inbound flow that the setup waits on and that drives further processes, are v0.5's | page "Round trips"; MS 12.1 |
| D233 | v0.5 centres on domain definition, the veterinary clinic franchise (D196) its worked example | page "Goal", "Sorting"; roadmap "Deferred from v0.5"; v0.6 page |
| D234 | A collection of real incident reports (post-mortems, retex) begins in v0.5, in `post_mortem/` at the repository's root | page "The post-mortem collection"; `post_mortem/README.md` |
| D235 | A domain is defined through a procedure, what goes in and what does not | `domain-procedure.md`; MS 8.1 |
| D236 | Brick options (D107; O79, O80) stay in v0.5, tied to the clinic, and are reviewed against what its parts need | `brick-options-review.md`; MS 7.1 |
| D237 | Bluebox and the other datasets (O53, O54) move to a later version, not set; Bluebox, "quite akin to a domain" | roadmap "Deferred from v0.5"; register O53, O54 |
| D238 | pgwatch and pgCluu stay in v0.5 as the clinic's monitoring | page, `brick-options-review.md`; MS 7.4 |
| D248 | v0.5's sorting stands with every proposed row as proposed, and v0.5 ships a scenario using the clinic's domains | page, roadmap, v1.0 page |
| D249 | The clinic splits into the procedure's seven domains, revised once `vet-core` is defined | `domain-procedure.md` 4, 6, 8; MS 8.2, 9.1 |
| D250 | For the clinic, `postgres` keeps plain partitioned tables before any TimescaleDB, offers replication as a standby mode | `brick-options-review.md`; MS 7.1 |
| D251 | Post-mortems are bound to faults in a later version | page "The post-mortem collection"; register O138 |
| D260 | The domain procedure is approved as drafted: what a domain holds and leaves out, the steps and who takes part | `domain-procedure.md` 1, 2, 3, 7; MS 8.1 |
| D261 | pgaudit is not an option: it is always available in `postgres` and turned on by the seed, as TLS is (D250) | `brick-options-review.md`; MS 7.1 |
| D262 | Options are for `postgres` only, unless one of the clinic's parts calls for another brick | `brick-options-review.md`; MS 7.1 |
| D263 | "Size" becomes a domain's scale, on three axes (population, history, throughput) | `domain-procedure.md` 9; MS 8.3 |
| D264 | A `gmctl compose` script merges a node's fragments at design time, built with the format changes | `producer-profiles.md` 1; MS 8.4 |
| D265 | Weekly, monthly and yearly reports are part of the game | `producer-profiles.md` 4 |
| D266 | `vet-core` is the system of record for owners and animals | `producer-profiles.md` 7, `vet-core-domain.md`; MS 9.2 |
| D267 | An `api` brick on FastAPI serves endpoint files the GM drops in, and the scheduler gets an HTTP driver as its caller | `producer-profiles.md` 8; MS 7.2 |
| D268 | The external lab is a consumer-producer round trip over APIs | `producer-profiles.md` 8; MS 9.3 |
| D269 | No periodic report runs on demand in v0.5 | `producer-profiles.md` 4 |
| D270 | An `api` node in the players' scope only answers requests | `producer-profiles.md` 8; MS 7.2 |
| D271 | Players read every endpoint file of an `api` node and, where the scenario makes it fixable, edit its database side only | `producer-profiles.md` 8; MS 7.2 |
| D272 | v1.0 to v2 leans to DBA work with bits of devops | roadmap "v1.0 to v2: DBA work with bits of devops" |
| D273 | A third party's nodes are outside the players' reach | `third-parties.md` 3; MS 10.2 |
| D274 | Third parties as the draft recommends, but for the network | `third-parties.md`; MS 10.1, 10.2 |
| D275 | v0.5 stays on one network; a third party's back end is closed by its own access rules | `third-parties.md` 3; MS 10.2 |
| D276 | O113's remaining recommendations are ruled as written | `producer-profiles.md` |
| D277 | A fix to a periodic report's fault is checked without a run on demand | `producer-profiles.md` 4 |
| D278 | `vet-core`'s business sketch is ruled with all fourteen answers as proposed | `vet-core-domain.md`; MS 9.2 |
| D279 | The clinic's split is confirmed as revised, lab and imaging requests and alerts in the core | `vet-core-domain.md`; MS 9.2 |
| D280 | `vet-core`'s step 5 is ruled | `vet-core-domain.md`; MS 9.2 |
| D285 | A clinic scenario deploys one centre; the rest are third parties | `one-centre.md`; MS 9.1 |
| D286 | A round trip is a purpose kind of its own | page "Round trips"; MS 12.1 |
| D287 | The housing displays talk to a ward service holding a pool | `producer-profiles.md` 9; MS 9.5 |
| D288 | Heavy continuous data keeps a day on site and ships the rest to cold storage | `producer-profiles.md` 11, `cold-storage.md`; MS 10.4 |
| D289 | The options model as proposed | `brick-options-review.md`; MS 7.1 |
| D290 | The clinic's scenario has ten faults at most | page, `bricks-and-faults.md`; MS 17.2 |
| D291 | The domain format is finalised in v0.5's master spec | page; MS 6.1; `formats.md` |
| D292 | v0.5 is the clinic only; other domains come after it | page, roadmap |
| D293 | One centre's parts and partners as proposed | `one-centre.md`; MS 9.1 |
| D294 | The lab bills its outside customers | `one-centre.md`; MS 9.1 |
| D295 | `vet-core` is rescaled to one centre, a third of each figure | `vet-core-domain.md`; MS 9.2 |
| D296 | Cold storage's design as drafted | `cold-storage.md`; MS 10.4 |
| D297 | The GM decides per data type what ships, use first, volume second | `cold-storage.md`; MS 10.4 |
| D298 | Friction 11's profile as drafted | `producer-profiles.md` 11 |
| D299 | Replication as proposed | `replication.md`; MS 11.1, 11.2 |
| D300 | The periodic reports write to a back-office database, `office`, on the primary's instance | `replication.md`; MS 11.3 |
| D301 | `vet-lab`'s business sketch is ruled with all fifteen answers as proposed | `vet-lab-domain.md`; MS 9.3 |
| D302 | `vet-lab`'s steps 4 and 5 are ruled as drafted | `vet-lab-domain.md`; MS 9.3 |
| D303 | What the clinic's first profiles need of the scheduler and the format, as recommended | `producer-profiles.md`; MS 7.2 |
| D304 | `vet-core`'s and `vet-lab`'s producer profiles (step 6) are ruled as drafted, all fifteen points | `vet-core-domain.md`, `vet-lab-domain.md`, `one-centre.md`; MS 9.2, 9.3 |
| D306 | `vet-core`'s and `vet-lab`'s purposes (step 7) are ruled as drafted, all eight points | `clinic-purposes.md`; MS 12 |
| D307 | The purpose format's extensions are accepted as listed | `clinic-purposes.md`; MS 12.1 |
| D308 | The partners' stubs are grouped on one `api` node | `one-centre.md`, `third-parties.md` 3; MS 10.2 |
| D309 | Selecting a scenario's faults is the GM's role | `domain-procedure.md`, `bricks-and-faults.md` |
| D314 | v0.5 tests short tests only, under 30 minutes each on the least environment that proves its brick or feature | page "Testing in v0.5"; roadmap "v1.0 gating"; MS 18 |
| D315 | A request the centre has sent to its lab is not cancelled from the clinic | `vet-core-domain.md`, `vet-lab-domain.md`, `clinic-purposes.md` 5; MS 9.2, 9.3 |
| D316 | v0.5 builds the test selection's ten faults and its false alarm's material | `clinic-test-selection.md`, `clinic-traps.md`; MS 17.2 |
| D317 | `vet-scheduling`'s draft accepted as recommended | `vet-scheduling-domain.md`; MS 9.4 |
| D318 | `vet-housing`'s draft accepted as recommended | `vet-housing-domain.md`; MS 9.5 |
| D319 | `vet-machinery`'s draft accepted as recommended | `vet-machinery-domain.md`; MS 9.6 |
| D320 | `vet-portal`'s draft accepted as recommended | `vet-portal-domain.md`; MS 9.7 |
| D321 | No appointment reminders in v0.5 | `vet-scheduling-domain.md`; MS 9.4 |
| D322 | The initial load is a step the GM adjudicates for the whole system; D249's deterministic keys stay the default | `domain-procedure.md`; MS 8.5 |
| D323 | The parts' format changes join O111 as proposed format text | `domain-procedure.md`; MS 8.5 |
| D324 | The parts' overlaps settled in one layout | `vet-core-domain.md`, `clinic-purposes.md`; MS 9.1, 12.2 |
| D325 | The test selection takes T270 for s5 and T150 for s9 | `clinic-test-selection.md`; MS 17.2 |
| D326 | The composition mechanism and the parts' format text for O111 confirmed as written | `domain-procedure.md`; MS 8.5 |
| D327 | Domestic vets go from 11 to 8 | `vet-core-domain.md`; MS 9.2 |
| D328 | No fault of the ten sits on an `api` node's `db/` side (D271) | `clinic-test-selection.md`; MS 17.2 |
| D329 | No data register for this repository, and no data preflight in v0.5's consolidation or build plan | `data-register-handout.md`; MS 13 |
| D330 | A scenario's data register is game content | `data-register-handout.md`, `clinic-traps.md`; MS 13.2 |
| D331 | A GM sub-skill, `data-register`, generates each scenario's register | `data-register-handout.md`; MS 13.3 |
| D332 | The test selection's s6 is T307, the vault not declared in the register | `clinic-test-selection.md`; MS 17.2 |
| D333 | A register fault is resolved by *propose* | `data-register-handout.md`; MS 13.4 |
| D334 | The register's format additions go into the master spec with O111's text | `data-register-handout.md`; MS 13 |
| D335 | Every scenario listing `domains:` must have a register | `data-register-handout.md`; MS 13.2 |
| D336 | The handout page's other "(proposed)" details stand as written | `data-register-handout.md`; MS 13 |
| D338 | O111 closed: the domain format is written into formats.md v28 | `formats.md` |
| D339 | v0.5's master spec and access model are approved, with the review's R1–R3 and R5–R20 as recommended | MS and AM status lines |
| D340 | The monitoring breadth is a `pgwatch` brick (pgwatch 3, its Prometheus sink feeding v0.2's Grafana) | MS 7.4, 14 |
| D342 | v0.5's build plan v1 is approved, with κ = 3 and its four plan choices as recommended | History (process): build plan (archived), its approval |
| D343 | O223–O227 as the plan recommends | History (process): build plan (archived) "Settled with the owner" |
| D344 | A domain's producer fragments sit in one folder per scheduler node they target, `producers/<node>/`; `api` | `formats.md`, MS 6.1, 8.4, build plan (archived) chunks 2, 9, 12 |
| D345 | An `api` node's `api.yaml` names each endpoint's hostnames and accepted credentials and the node's connections | MS 6.5, 6.8; `formats.md`; build plan (archived) chunks 2, 3, 5, 6 |
| D346 | Chunk 1 writes `GM_OPTIONS: monitoring` into the hand-written stack files whose `postgres` serves an exporter | Build record: build plan (archived); wave log |
| D347 | The HTTP credential's secret, name and readers are W1's, since chunks 4 and 5 read them in wave 1 | Build record: build plan (archived); wave log |
| D348 | Chunks 9 and 11 are cut once chunk 6 has merged (in-wave edges `6 ──> 9`, `6 ──> 11`), not merge order only as proposed | History (build sequencing): build plan (archived) ("Read first", "Waves") |
| D349 | `api` joins the node roles, the `api` brick's; `pgwatch` and `health-check` take `monitoring` | `formats.md`; build plan (archived) chunks 1, 2 |
| D350 | Chunk 6 reserves `options` and `standby_of` as parameters and `replicator` as a role | Build record: build plan (archived) chunks 4, 6; wave log |
| D351 | Chunk 3 builds under G5's conditions, `vault-post` in Perl with core `HTTP::Tiny`, the snakeoil key deleted as advised | Build record: build plan (archived) chunks 3, 5, "Pending with the owner"; wave log |
| D352 | A restart from the hand-over snapshot not bringing a standby back as one is a named known limit of v0.5 | History: superseded by D397 |
| D353 | `register_diff`'s key stays `true:` as master spec 6.8 writes it; the loader reads it as PyYAML gives it | Build record: build plan (archived) chunk 6; wave log |
| D354 | `public` confirmed as a purpose's `connections:` value for an HTTP connection to a public endpoint | `formats.md`; build plan (archived) chunk 6 |
| D355 | The two `no-access` mechanisms stay as built; no chunk unifies them | Build record: each brick's `docs/gm.md` (`no-access`); AM 5 |
| D356 | A caller's bounded wait promises an honest failure past its bound, not resolution within it | Build record: build plan (archived) ("Read first", workflow deltas, chunks 7, 10); wave log |
| D357 | Text corrections | Build record: build plan (archived) chunks 1, 2, 3; wave log |
| D358 | Wave 2's chunks read against W1-w to W1-z | Build record: build plan (archived) chunks 6 to 9; wave log |
| D360 | Chunk 6 adds `model.node_creates` and a partner folder's `data.sql`; chunk 8 runs that file into `partners` | Build record: build plan (archived) chunks 6 to 8, wave 2; wave log |
| D361 | Wave 2 keeps two three-chunk completion chains (6, 7, 11 and 6, 8, 9), past the model's two | History (build sequencing): build plan (archived) ("Wave 2") |
| D362 | Chunk 9's fixture waits for chunks 7 and 8; chunk 7 gains `fixture-alias/`, chunks 6 then 8 the scenario-format skill | Build record: build plan (archived) chunks 6 to 11; wave log |
| D363 | Chunk 6 refuses every third-party node and alias in `web_routes` | Build record: build plan (archived) chunks 6, 17; wave log |
| D364 | formats.md and master spec 5 take wave 2's format items as built, after its gate, as G16 | `formats.md` (G16); MS 5, 6.1. History: build plan (archived) G16 |
| D365 | Chunk 17 hands the players the credentials `partners.md` documents with the starter pack | AM 3, 6, 13; MS 10.2; `formats.md` "Partners" |
| D366 | Purpose 14's planted manifests must fit W2 item 3's history rule; another form is an inserted chunk | Build record: build plan (archived) chunk 21; wave log |
| D367 | The full quality command judges each existing scenario's smoke against its own design | Build record: build plan (archived); wave log |
| D368 | Text correction: pgwatch is its latest release at the build (6.1.0 at G9), not "pgwatch 3" | MS 7.4, 21; build plan (archived) G3, G9, chunk 10 |
| D369 | The owners' traffic takes `producers/partners/owners/`; no v0.5 folder uses `public/` | MS 9.7; `formats.md` (G16) |
| D370 | Text correction: chunk 12's lab stub folder is `producers/partners/xlab/`, not `northfield-lab/` | Build record: build plan (archived) chunk 12; wave log |
| D372 | The code catalogues live in their parts' domain documents: the lab's layout, named codes and the centre's draw | `vet-lab-domain.md`, `vet-machinery-domain.md`, `vet-scheduling-domain.md` (`sched_types`) |
| D373 | MR and NM codes on large animals are horses only: codes 26 and 27 and machines 10 and 16 take `species_group` `horse` | `vet-machinery-domain.md`; MS 9.2, 9.6 |
| D374 | The core's key functions are eighteen: W2 item 4's thirteen plus `core_animal`, `core_owner`, `core_ownership` | `vet-core-domain.md`; `vet-scheduling-domain.md` ("What the load needs of the core's") |
| D375 | `core_request` returns the request's state at T0 with its times (`resulted` or `cancelled`, the last 24 hours' `sent` | `vet-core-domain.md` |
| D376 | Routine imaging is booked and scheduled within two working days, the final report within one more | MS 9.4; `vet-scheduling-domain.md` (`book-requests`) |
| D377 | An intensive-care session covers one domestic stay in two and one horse stay in four, never a farm stay | `vet-machinery-domain.md` answer 7, `mach.census`; MS 9.6 |
| D378 | Text correction: the referring vets' mapping (`core_referring_practice`) is read by `vet-scheduling`'s `sched_trainees` | `vet-core-domain.md` |
| D379 | Chunk 9's identifier and signature choices stand: chips on every dog, cat, horse and ferret | `vet-core-domain.md` and its "Natural identifiers" |
| D380 | Plan correction: `vet-core`'s variant holds `parts: []`; chunks 12 to 16 each add their id to it | Build record: build plan (archived) chunks 9, 12 to 16, workflow deltas; wave log |
| D381 | Cold storage's manifest is keyed `(source, shipment_id)`, its source the node holding the data | MS 10.4; `cold-storage.md` 3; build plan (archived) gate, chunk 21 |
| D382 | The planted `wal` names sorting above the live ones stay a known limit | Build record: build plan (archived) chunk 23; wave log |
| D383 | `partners-db` gets no `gm_check` host line; a coherence check whose `reads` names `partners` runs in the partners' | AM 8; build plan (archived) gate, chunk 12 |
| D384 | Each section has a duty vet on Saturday and on Sunday, 08:00–20:00, by rotation over its vets | `vet-scheduling-domain.md` (the rota's pattern); `vet-core-domain.md` (`core_shifts`) |
| D385 | About four in ten consultations make requests, 0.65 on average | `vet-core-domain.md` (`core_request`'s `kind`), `consultations.close`, point 3; `vet-lab-domain.md` (the two constraints) |
| D386 | No history draw repeats with a fixed period in id order: fixed counts per block of ids may stay | `vet-core-domain.md` ("Draws from an id") |
| D387 | Text correction: the core's load is expected at one to two minutes, not "a few seconds"; it matters for nothing | `vet-core-domain.md` (Loading); MS 9.2 |
| D388 | Chunk 9's nurses' four-week cycle stands, each section's every shift held, no rest, weekly-rest or 48-hour breach | `vet-scheduling-domain.md` (the rota's pattern, the history's absences); `vet-core-domain.md` (`core_shifts`) |
| D389 | `MINH`'s checked line is on the herd's latest earlier consultation early enough for its withdrawal to end before the | `vet-core-domain.md` (`withdrawal_ends_on`); `vet-lab-domain.md` |
| D390 | The history's inbound exchanges are examinations of unregistered animals (`partner_patient` kept), no inbound transfer | `vet-core-domain.md` (`core_exchange`) |
| D391 | An administration's `given_by` is a nurse of the stay's section, not matched against the rota | `vet-core-domain.md` (Loading) |
| D393 | The history's administrations stand at the build's 61 241, about 60 000, the range 1–70 000 and the load's cap kept | `vet-core-domain.md` (volumes, jobs); MR1, T65 |
| D394 | D388's every-shift rule binds each section's nurses and technicians; the carers keep the same cycle, 57–60 horse | `vet-scheduling-domain.md` (the rota's pattern); `vet-housing-domain.md` |
| D395 | D365 stays, tracked: the starter pack keeps handing the players the customer's own partner credentials | register O231; AM 13 |
| D396 | Until v1.0 each brick takes its tool's latest available version | roadmap "From v1.0: versions at a game-wide scope"; register O11 |
| D397 | A restart from the hand-over snapshot gives back every node as it was meant to run, replication included | MS 7.1, 15, 18.2; roadmap; build plan (archived) chunk 28, release gate |
| D398 | Chunk 28 is inserted into wave 2, gated but not merged, so the fix merges with it | History (build sequencing): build plan (archived) (waves, per-wave gate contents) |
| D399 | `check_postgres` stays the health node's checker for now; a switch is expected some day | roadmap "From v1.0: versions at a game-wide scope" |
| D400 | pgBadger stays unpinned, as is | roadmap "From v1.0: versions at a game-wide scope" |
| D401 | Chunk 29 is inserted into wave 3, for a `coding-executor` | History (build sequencing): build plan (archived) chunk 29, G17, waves, chunks 12, 15, 16, 18 to 21, release gate item 6 |
| D402 | Wave 3 keeps a three-chunk completion chain (29, 12, 16), past the model's two | History (build sequencing): build plan (archived) ("Waves", wave 3) |
| D403 | The fixtures meet compose's rule: chunks 13 and 14 add `clinic-api`, chunks 12 and 16 use `left_out | History (build sequencing): build plan (archived) chunks 12 to 14, 16, 18 to 21 |
| D404 | `derive.sql` writes `portal` only; purpose 16's `history` plants the messaging stub's messages | MS 9.7; `vet-portal-domain.md` ("Loading", "The history before T0", `vet-portal-messages`); build plan (archived) chunks 16, 21 |
| D405 | A composed domain's `pg_cron` jobs go in its `data/cron.sql` | `vet-machinery-domain.md` and `vet-portal-domain.md` "Loading"; build plan (archived) chunks 15, 16, 29 |
| D406 | Text correction: the portal's passwords and tokens use a key computed from the load's `load_epoch` | MS 9.7 "Keys and scale"; `vet-portal-domain.md`; build plan (archived) chunk 16 |
| D407 | Wave 3's gate loads the six domains on `fixture-clinic-load`, uncomposed | History (build sequencing): build plan (archived) ("Per-wave gate contents", wave 3), chunk 27 |
| D408 | The history's scheduled consultations follow the agenda: on half-hour slots | `vet-core-domain.md`; `vet-scheduling-domain.md` ("The history on the agenda", T100); MS 9.4; wave log "W3 item 2, revised" (a), (b) |
| D409 | Chunk 30 inserted into wave 3 for a `coding-executor`, ahead of chunk 13 (`30 ──> 13`, in-wave) | History (build sequencing): build plan (archived) ("Waves", chunks 13, 30) |
| D410 | Consultation types take 30 minutes on their room's half-hour grid | `vet-scheduling-domain.md` (`sched_types`, Cadences) |
| D411 | Shifts are planned to the horizon ahead of their publication | `vet-scheduling-domain.md` (lifecycle, ranges, `sched.rota.publish`); MS 9.4; wave log "W3 item 2, revised" (d) |
| D412 | `sched_free_slots` copies the core's staff layout into its text, one formula with `core_staff` | `vet-scheduling-domain.md` ("Logic in the database") |
| D413 | `core_exchange` returns the reason and the partner patient's species its load writes | `vet-core-domain.md`; `vet-scheduling-domain.md` ("An inbound examination's booking"); build plan chunks 21, 30 |
| D414 | Scheduling's schema grants `vet_reports` every `sched_` table, guarded on the role existing; W3 item 0 stands | `vet-scheduling-domain.md` |
| D415 | `vet-lab`'s figures and grants are the build's: `lab_samples` as loaded, about 20 800 (one a container | `vet-lab-domain.md` (the variant, ranges, grants, sizes, T0); MS 9.3 |
| D416 | `vet-machinery` as built: a settings row per database; `mach_worklist.cancelled_at`, read by `mach_orders` | `vet-machinery-domain.md`; MS 9.6, 10.4; `clinic-purposes.md` |
| D417 | `vet-housing` as built: `housing` reads `stays.reason`, `animals.born_on` and `business_settings` for the board | `vet-housing-domain.md`; MS 9.5 |
| D418 | The `pacs` load keeps the history's studies out of `biomed`'s downtime windows, derived by its formulas (salts 502, 505 | `vet-machinery-domain.md`; build plan (archived) chunk 21 (`mach_archive`'s settings reads, for W4) |
| D419 | T163's witness is an infectious animal outside isolation while an isolation unit of its section has stood clean and | `vet-housing-domain.md` (T163, false alarms) |
| D420 | `vet-lab` as built: `lab_instruments` reads `lab_results (order_test_id)` (the driver's ruling) | `vet-lab-domain.md` (grants, jobs, the practices); MS 9.3; `clinic-purposes.md` (SO4) |
| D421 | Chunk 31 inserted into wave 3, ahead of 16b's restart | History (build sequencing): build plan (archived) ("Waves", chunks 16, 31) |
| D422 | `vet-scheduling` as built: W3-b's columns (`sched_rooms.consultation_space`, `sched_types.staff` and `course_id` | `vet-scheduling-domain.md` (entities, ranges, placement, grants, sizes); MS 9.4 |
| D423 | `vet-portal` as built: the keeper's clause and the documents' start through two `SECURITY DEFINER` helpers the policies | `vet-portal-domain.md` (policies, endpoints, ranges, sizes, loading); MS 9.7 |
| D424 | An urgent imaging request is booked at its machine's first free slot: the same day around the clock | `vet-scheduling-domain.md` (BS3, T113); MS 9.4; build plan (archived) chunk 21 |
| D425 | The load's absences that start after T0, `absent` ones included, stay recorded before T0 | `vet-scheduling-domain.md` |
| D426 | The desk's 422 for a closed account's owner is kept, about one desk call in thirty | `vet-portal-domain.md` |
| D427 | T274's witness is about one withdrawal every five or six days, the rate as built | `vet-portal-domain.md` (T274) |
| D428 | The access model's closed account: login `401`; a reset asked for its address `202`, as any address's | AM 9.3 |
| D431 | Chunk 32 is inserted into wave 4, for a `coding-executor`: a purpose's `source_<w>` and `runner_<w>` parts | History (build sequencing): build plan (archived) chunk 32, waves, chunks 17 to 21 |
| D432 | `gm_check` reads a table with row security through a `gm_check_read` policy (`FOR SELECT TO gm_check USING (true)` | AM 8; `vet-portal-domain.md`; build plan (archived) chunk 32 |
| D433 | Chunk 17 also refuses a domain's `cron.sql` job naming a database its entry's `at:` does not place | `formats.md` "Domain", "Scenario", "Partners" (G18) |
| D434 | D335's register requirement binds played scenarios: a scenario whose id starts `fixture-` is exempt | MS 13.2; `data-register-handout.md`; formats.md "Scenario" with G18; build plan (archived) chunk 17 |
| D435 | Wave 4's fixtures and shared material: chunk 19 adds vet-core's `partners/centres` to every composed fixture's | History (build sequencing): build plan (archived) chunks 18 to 21, "Workflow deltas" |
| D436 | A monthly, yearly or windowed job runs daily, or every 15 minutes, at its hour and acts only on its own date or window | MS 12.2 ("Cadences", purposes 3, 7 to 10, 12) |
| D437 | Gate G18: after wave 4's gate, `spec-writer` writes wave 4's format items as built into formats.md and master spec 5 | `formats.md` v32 (G18); MS 5, 6, 12.1. History: build plan (archived) G18 |
| D438 | The purpose loader takes four forms the spec already uses: invariant ids `[A-Z]{1,2}[0-9]+` (12.2's LO1 to MS6 | MS 12.1; build plan (archived) chunk 33; formats.md with G18 |
| D439 | Chunk 33 is inserted into wave 4, for a `coding-executor`, building D438 in `model.py`'s purpose checks | History (build sequencing): build plan (archived) chunk 33, waves, chunks 17 to 21 |
| D440 | Purpose 4's inbound trip is judged end to end by EX2, reworded from the centre's side (each request recorded at once | MS 12.1, 12.2 purpose 4; `clinic-purposes.md` 8; `clinic-traps.md` T54 |
| D441 | The roles table lists each purpose's column grants by number, a shared role holding their union, and defines `ops.*` | `clinic-purposes.md` "The roles the purposes add" |
| D442 | The roles table gains chunk 21's four grants (the slot function's and release trigger's reads and writes as invoker | `clinic-purposes.md` "The roles the purposes add"; vet-scheduling 11, vet-machinery 13 and Testing, MS 9.4, 9.6; build plan (archived) chunk 21 |
| D443 | Debian `curl` 8.14.1-2+deb13u7 goes into `bastion` 0.5.0 without a version bump (0.5.0 is unreleased) | MS 5, 6.7, 7.3; build plan (archived) G11.2; `.tech` (the advisor's); page "Accepted risks and items with the owner" |
| D444 | the 50 `.tech` `[[ignore]]` entries hold until 2027-05-01; python3.13 is upgraded on armenelos (the owner's command) | page "Accepted risks and items with the owner"; `.tech` |
| D445 | A brick's tag names one Debian package list: a rebuild that changes an image's content (a Debian package version | MS 6.7, 7.5; build plan (archived) "Workflow deltas"; `.tech`'s header |
| D446 | Prometheus moves to its 3.16.x line in a later wave of v0.5, never wave 4 | MS 6.7, 7.5 |
| D447 | `pms`'s `sched.bookings.arrive` stamps an arrival when it records it | `vet-scheduling-domain.md` (`sched.bookings.arrive`); MS 9.4 |
| D448 | Chunk 34 is inserted into wave 5, not the release gate | build plan (archived) chunk 34, "Gates", "Waves"; MS 5, 6.7, 7.5 |
| D449 | T115's variant holds `sched.bookings.arrive`'s transaction 30 to 90 seconds after its stamp (the desk printing its | `vet-scheduling-domain.md` T115 |
| D450 | On-call shifts take no part in the 11 hours' rest comparison (WT2, `feed-working-time`) | `vet-scheduling-domain.md` (WT2, false alarms); MS 9.4, 12.2 |
| D451 | Chunk 35 is inserted into wave 5 for a `coding-executor` | `vet-core-domain.md`; `clinic-purposes.md` 11 to 13; build plan (archived) chunk 35 |
| D452 | `lab_dispatch` also reads `lab_settings (utc_offset_hours)`; PR1 judges each delivery a release made due (an interim | `clinic-purposes.md` 6, 7 and the roles table; `clinic-traps.md` T49; MS 12.2 |
| D453 | ND3's keeper, from the lab, is the keeper's name and the practice's account (vet-lab holds no address) | `clinic-purposes.md` 8, 9 |
| D454 | a `code` check runs the job's loaded SQL on the last planted period; AM4's run tries three times | `clinic-purposes.md` 11 to 14, "`office` at T0"; `formats.md` "Purpose definition" |
| D455 | `vet_portal_sync` reads `animals.registered_at`, `consultations.state` and `sections (id, kind)` | `vet-portal-domain.md` 15, 16 and its roles; `clinic-purposes.md`; `vet-machinery-domain.md` |
| D456 | chunk 22's fixed s1 reading releases the urgent test itself when `lis` has not within 5 minutes | Build record: build plan (archived) chunks 22, 24, 26, 27; wave log |
| D457 | Wave 5 holds eight chunks, 22 to 27, 34 and 35, two past the model's six; 34 and 35 start first | History (build sequencing): build plan (archived) "Waves", chunks 34, 35 |
| D458 | O247 closed: `grafana` 0.3.0 is rebuilt for the plugin update, not bumped to 0.3.1 | MS 6.7; `.tech`; build plan (archived) chunk 34 |
| D459 | chunk 36 builds three fault forms: a `state` script run on another node (`{script, on: <parameter>}`), `injection.kind | `formats.md` "Fault definition" (G19); MS 6.3, 6.4 |
| D460 | wave 5 holds nine chunks; 36 takes the first free slot, and only 22's fa issue, 24's s3 | History (build sequencing): build plan (archived) "Waves", workflow deltas |
| D461 | s8's witness in a game is the 00:30 feeder; its short test reads the delay in effect, WAL received and not replayed | MS 17.2, 17.3, 18.3; `clinic-test-selection.md`; build plan chunk 24 |
| D462 | s10 is resolved by *report* or *propose*; fixed, the option's role created on `lab` with the game's monitoring password | MS 17.3; `clinic-test-selection.md`; build plan chunk 25 |
| D463 | s5 is planted a few hours before T0, so former owners have had hours, not days, to look; class M unchanged | MS 17.2; `clinic-test-selection.md`; `vet-portal-domain.md` |
| D464 | chunks 22 to 26 and the reports fixture's texts to the code and capture W5: T0 about 00:10 any day | build plan (archived) chunks 22 to 26; MS 17.3, 18.2; `clinic-test-selection.md` |
| D465 | the true register digests `composition.yaml` without its top-level `coherence:` key and the indented lines under it | `formats.md` "Scenario" (G19); MS 6.2 |
| D466 | `aldermoor-centre` leaves s4 out, nine faults and the false alarm within the owner's budget (one dramatic | MS 18.3, 18.4; `clinic-test-selection.md`; build plan (archived) chunk 27, G13 |
| D467 | the partner stubs' references restarting at 0001 after the planted AMU and HO series are accepted in v0.5 | page "Known limits"; register O249 |
| D468 | the scenario document never shows the coherence result: setup state, as for the register's digest (D465) | `formats.md` "Composing domains" (G19) |
| D469 | the customer's governance judges its own estate: no `governance:` location or outbox on a third party's node (refused) | MS 10.1, 10.2, 13.2; build plan (archived) chunks 27, 38, G19 |
| D471 | the governance check set's gaps on the whole clinic are a v0.5 known limit | MS 18.4, 20.3; build plan (archived) release gate items 3, 12; page "Known limits" |
| D472 | the scenario document shows a round-trip fault instance's `backlog:` (`what`, `cleanup`) with that instance's answer | `formats.md` "Scenario"; MS 6.3, 15; build plan (archived) release gate item 6 |
| D473 | the portal's messages carry the address, template, the recipient's name, the animal's name | MS 9.7 rule 7, 12.2; `vet-portal-domain.md` |
| D474 | The partners' database admits by role and password, not by address; the access model's gap is verified | AM 13; MS 10.2 |
| D475 | G15 cleared; v0.5 released | page "Release notes"; build plan (archived) G15 |
| D476 | G13's findings 1 and 4 are v0.5 known limits, filed as ISS-001 and ISS-002 | page "Known limits"; roadmap "v1.0 gating"; register O269, O270 |

Resolved questions, each living where its deciding decision lives (row
above):

| Questions | Resolved by |
|---|---|
| O47, O137 | D248 |
| O126 | D249 |
| O139 | D260 |
| O118 | D261 |
| O80 | D262 |
| O114 | D263 |
| O145 | D274, D275 |
| O144 | D278 |
| O127 | D285 |
| O128 | D286 |
| O79 | D289 |
| O112 | D292 |
| O147 | D293–D295 |
| O148 | D296, D297 |
| O113 | D298 |
| O149 | D300 |
| O151 | D301 |
| O152 | D302 |
| O154 | D303 |
| O153 | D304 |
| O155 | D306 |
| O156 | D307 |
| O158 | D314 |
| O164 | D315 |
| O165 | D316 |
| O168–O179 | D317 |
| O180–O190 | D318 |
| O192–O203 | D319 |
| O204–O215 | D320 |
| O217 | D333 |
| O218 | D334 |
| O219 | D335 |
| O111 (its v0.5 part) | D338 |
| O220 | D340 |
| O223–O227 | D343 |
| O229 | D404 |
| O235 | D418 |
| O236 | D419 |
| O239 | D424 |
| O240 | D425 |
| O241 | D426 |
| O242 | D427 |
| O243 | D432 |
| O247 | D458 |
| O250 | D471 |

O166, O167, O191, O216, O221, O222, O228, O230, O233, O244, O245 and
O248 were reserved during v0.5 and never used.

## Left in place

| Document | Role | Referrers |
|---|---|---|
| `specs/versions/v0.5/README.md` | The version's page: scope, sorting, testing, release notes, known limits, accepted risks | `specs/README.md`, `specs/versions/README.md`, `specs/open-questions.md`, the archived decisions |
| `specs/versions/v0.5/master-spec.md` | The contract for what v0.5 built | `specs/README.md`, `specs/versions/README.md`, `specs/formats.md`, `specs/open-questions.md`, bricks', domains', purposes' and partners' files (comments, `docs/gm.md`) |
| `specs/versions/v0.5/access-model.md` | The master spec's companion; in force for v0.5 games | `specs/README.md`, `specs/versions/v0.5/README.md`, `bricks/postgres/docs/gm.md` |
| `specs/versions/v0.5/wave-log.md` | Execution record, but its captures fix brick keys, the loader's rules and fixtures' forms that code comments cite ("capture W1 item 6", "W2-f") | bricks, `partners/`, `purposes/`, `domains/`, `scenarios/aldermoor-centre/`, `tools/tests/fixtures/` |
| `specs/versions/v0.5/vet-core-domain.md`, `vet-lab-domain.md`, `vet-scheduling-domain.md`, `vet-housing-domain.md`, `vet-machinery-domain.md`, `vet-portal-domain.md` | The six domain documents, approved with the master spec as its column-level companions | the `domains/` folders, `purposes/`, the master spec |
| `specs/versions/v0.5/domain-procedure.md` | The approved procedure for defining a domain, standing beyond v0.5 | `.claude/skills/scenario-format/SKILL.md`, `specs/formats.md`, `specs/versions/README.md` |
| `specs/versions/v0.5/clinic-purposes.md`, `clinic-traps.md` | The clinic's purposes (step 7) and its trap catalogue (step 8), from which a scenario's faults are picked (D309) | `purposes/`, `faults/`, `domains/`, `scenarios/aldermoor-centre/`, `tools/tests/fixtures/` |
| `specs/versions/v0.5/cold-storage.md` | Cold storage's design | `partners/coldstore/`, `purposes/cold-storage-archive/`, the scenario and fixtures' copies, `issues/ISS-002_…` |
| `specs/versions/v0.5/data-register-handout.md` | A scenario's data register, the handout's design | `.claude/skills/data-register/SKILL.md`, the format skill's `register.yaml` template, `faults/governance-register-flow-undeclared/`, `tools/tests/fixtures/fixture-archive/` |
| `specs/versions/v0.5/third-parties.md` | What a third party is | `specs/versions/v0.6/README.md`, the domain documents |
| `specs/versions/v0.5/producer-profiles.md`, `one-centre.md`, `replication.md`, `brick-options-review.md`, `clinic-test-selection.md`, `clinic-capacity.md` | Ruled drafts, consolidated into the master spec; the homes the decisions above name, cited section by section by the domain documents | the domain documents and drafts above, `specs/README.md` |

The drafts stay in place this time, unlike v0.4's four: the approved
domain documents and the code cite them section by section, and the
decisions' rows above name them. A later pass may archive the last row's
drafts once their rulings are mapped to master spec sections.

## Carried forward

- Every open question stays live in
  [open-questions.md](../../open-questions.md) with its ID: O2, O5, O10
  to O12, O16, O20 to O25, O29 to O32, O38, O48, O49, O52 to O54, O130,
  O135, O136, O138, O231, O232, O249, O251, O269 and O270. None was
  resolved by this pass; O269 and O270 were raised by D476 just before
  it, O251 marked placed in v0.6.
- v1.0 gating, in the [roadmap](../../versions/README.md#v10-gating):
  v0.5's long-running checks (D314), with the stance check-list's v0.5
  items, the parts' long views and the clinic's setup (O270) and stub
  counters (O249) added at the close.
- Known limits and accepted risks in the [v0.5 page](../../versions/v0.5/README.md#release-notes):
  the governance checks on the whole clinic (D471), no whole-clinic
  hand-over snapshot, what a restore does not give back (D397), the
  stub counters (D467), ISS-001 and ISS-002 (D476); `curl` until
  2027-02-01 (D443), `.tech`'s ignores until 2027-05-01 (D444); the
  security advisor's items with the owner.
