> **Archived 2026-11-14.** v0.5 closed (released at its release gate, G15 cleared by the owner on 2026-11-14, merged into `main`); entries D314 to D476 (D337, D341, D359, D371, D392, D429, D430 and D470 reserved and never used) of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan archived in the same pass were repaired to its archived path (`archive/v0.5/build-plan.md`), still written from `specs/`.

- **D314 (2026-11-03, owner rulings, relayed by the coordinator): v0.5
  tests short tests only, under 30 minutes each on the least environment
  that proves its brick or feature; one exception, the whole clinic
  deployed once, on armenelos plus the VPS, as step 11's proof in play.**
  Sharpens D311 and D312. Every longer run (aging, overnight cadences,
  the rehearsal, the stance check) goes to the major test before the
  v1.0 tag. The VPS rules stand (D159). Closes O158. The owner: "we must
  restrict testing to short tests (validate that new bricks/features
  works simply with minimal environment) we will do a major test prior
  taging v1.0, any long running (>30m) will be done there"; "i'll accept
  an exception for deploying the whole clinic on this milestone"; "yes,
  two hosts are covered by the exception." Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#testing-in-v05-d314),
  [versions/README.md](versions/README.md#v10-gating).
- **D315 (2026-11-03, owner answer "i accept recomendations", relayed by
  the coordinator): A request the centre has sent to its lab is not
  cancelled from the clinic:** the vet phones, the lab cancels the test,
  and the results feed brings the cancellation back, as a test not
  performed; `requests.cancel` takes `requested` requests only; no new
  endpoint. Closes O164. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#rates-at-intensity-10),
  [versions/v0.5/vet-lab-domain.md](versions/v0.5/vet-lab-domain.md#rates-at-intensity-10),
  [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md) 5.
- **D316 (2026-11-03, same answer): v0.5 builds the test selection's ten
  faults and its false alarm's material;** every other trap stays listed
  for the GM, to write as a scenario's own fault when a game selects it
  (D309). Closes O165. Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md),
  [versions/v0.5/clinic-traps.md](versions/v0.5/clinic-traps.md).
- **D317 (2026-11-03, owner answer, relayed by the coordinator):
  `vet-scheduling`'s draft accepted as recommended.** The owner: "i
  agree with the recommendations as a whole". O168–O179 closed as the
  page recommends, but for the fold-in's changes: ten bookable machines,
  the core's staff layout and the purposes' numbers (D324), no
  appointment reminders (D321). Now in:
  [versions/v0.5/vet-scheduling-domain.md](versions/v0.5/vet-scheduling-domain.md#questions-for-the-owner).
- **D318 (2026-11-03, same answer): `vet-housing`'s draft accepted as
  recommended,** O180–O190 closed, but for O184's load: the tables stay
  in `clinic`, declared `lands_with: vet-core`, and the load computes
  the core's stays by functions instead of reading them (D322). Now in:
  [versions/v0.5/vet-housing-domain.md](versions/v0.5/vet-housing-domain.md#questions-for-the-owner).
- **D319 (2026-11-03, same answer): `vet-machinery`'s draft accepted as
  recommended,** O192–O203 closed, but for O203 (T208 stays a trap, s9
  going to T150, D325) and O198's staff ids (D324); O195's several
  databases are proposed format text for O111 (D323). Now in:
  [versions/v0.5/vet-machinery-domain.md](versions/v0.5/vet-machinery-domain.md#questions-for-the-owner).
- **D320 (2026-11-03, same answer): `vet-portal`'s draft accepted as
  recommended,** O204–O215 closed, but for O213: the load computes the
  sources' keys by functions, and only the copied content comes from a
  derivation step the GM sanctions (D322). Now in:
  [versions/v0.5/vet-portal-domain.md](versions/v0.5/vet-portal-domain.md#loading).
- **D321 (2026-11-03, owner ruling, relayed by the coordinator): No
  appointment reminders in v0.5;** the portal reminds owners of
  vaccinations only, with their consent. Scheduling had left them to the
  portal, the portal had left them out. `sched_upcoming` is not built.
  Now in:
  [versions/v0.5/vet-scheduling-domain.md](versions/v0.5/vet-scheduling-domain.md#no-appointment-reminders-in-v05-d321).
- **D322 (2026-11-03, owner ruling, relayed by the coordinator): The
  initial load is a step the GM adjudicates for the whole system; D249's
  deterministic keys stay the default.** The owner, after the
  coordinator recommended keeping D249: "although you are also right,
  initial load is a major step and will need to be adjudicated by the gm
  for coherence across the system." A part's load computes the core's
  keys from its documented ranges and functions (housing and the portal
  move to it); the GM checks and records cross-domain coherence at
  composition, may sanction an ordered derivation step, and placement
  constraints are declared (`lands_with`). The mechanism's details are
  (proposed), confirmed with the master spec (O111). Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#10-composing-domains-d322).
- **D323 (2026-11-03, same ruling): The parts' format changes join
  O111 as proposed format text:** a several-database part (O195),
  `lands_with`, the derivation step, a traffic source that is no
  business, the composition record, the `SECURITY DEFINER` check. Now
  in: [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#the-format-changes-the-parts-propose-for-o111).
- **D324 (2026-11-03, spec choice at the fold-in): The parts' overlaps
  settled in one layout.** Purposes renumbered 11–16 (scheduling,
  machinery, portal), housing's occupancy in purpose 9; machine ids are
  `vet-machinery`'s, ten bookable (7–16); one staff layout in the core
  within D295's 85; the imaging team cancels a sent imaging request, as
  D315 for the lab. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#deterministic-key-ranges-d249-d266),
  [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md#16-the-parts-purposes-11-to-16).
- **D325 (2026-11-03, spec choice, the GM's under D309): The test
  selection takes T270 for s5 and T150 for s9;** nothing of the ten
  tested row-level security, owner-scoped access or D287's display.
  T208 stays a trap; D290's mix holds (1 D, 2 V, 7 M). T150 is judged on
  the report at the final answer: the GM never switches the display off
  during play ("Stop only", no events outside the schedule). Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md).
- **D326 (2026-11-03, owner answer, relayed by the coordinator): The
  composition mechanism and the parts' format text for O111 confirmed
  as written:** `lands_with`, a several-database part, `derive:` and
  `data/derive.sql`, the traffic source that is no business,
  `composition.yaml`, the post-load coherence check, the `SECURITY
  DEFINER` `search_path` check (D322, D323). The owner: "ok agreed".
  O111 settled in substance; the master spec carries it at
  consolidation (D291), which closes it. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#10-composing-domains-d322).
- **D327 (2026-11-03, same answer): Domestic vets go from 11 to 8**
  (staff 18–25), so the imaging staff fit D295's 85 in D324's layout;
  the total stays 85 and scheduling's shifts are unchanged. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#deterministic-key-ranges-d249-d266).
- **D328 (2026-11-03, same answer): No fault of the ten sits on an `api`
  node's `db/` side (D271)** now that T78 has left; the `api` brick's
  own build checks cover that side. Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md#the-selection).
- **D329 (2026-11-03, owner ruling, relayed by the coordinator): No data
  register for this repository, and no data preflight in v0.5's
  consolidation or build plan:** all data is synthetic. The game's own
  inventory is its catalogue. Replaces the README's "(proposed)" default
  on the data preflight. The owner: "this repo doesn't "need" to have a
  data register (the only data register the game itself would have will
  focus on bricks, faults, domains, etc)". Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#the-ruling-d329d331).
- **D330 (2026-11-03, same ruling): A scenario's data register is game
  content:** a player handout generated from the ground truth. It may
  carry a fault (out of step, absent, badly documented), a trap family
  (T300–T308). The clinic's test scenario gets one. Narrows O21 to the
  other starter files. The owner: "Scenarios may/should have data
  registries (as handout) to the players(could also be some fault here:
  desync from the ground truth, entierely absent, ill documented, etc)".
  Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md),
  [versions/v0.5/clinic-traps.md](versions/v0.5/clinic-traps.md#11-the-data-register-t300t308-d330).
- **D331 (2026-11-03, owner addition, relayed by the coordinator): A GM
  sub-skill, `data-register`, generates each scenario's register,**
  with a fault planted or not: the true register in `gm/` and the
  handout. Its details are (proposed). The owner: "it should probably be
  added as a subskill to the GM ensuring such registries get generated
  with the appropriate informations (with fault planted or not)." Now
  in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#3-generation-the-gms-data-register-skill-d331).
- **D332 (2026-11-03, spec choice, the GM's under D309): The test
  selection's s6 is T307, the vault not declared in the register,**
  replacing T49, which goes back to the traps; D290's mix holds (1 D,
  2 V, 7 M). Reason: T307 is the only fault that proves the register's
  planted deviation, and T49's mechanism was already proved in v0.4.
  Now in:
  [versions/v0.5/clinic-test-selection.md](versions/v0.5/clinic-test-selection.md#the-selection).
- **D333 (2026-11-03, owner answer, relayed by the coordinator): A
  register fault is resolved by *propose*:** the corrected entry goes in
  the players' report, and the GM judges it against the answer key's
  `register_diff:`. A corrected file handed back waits for v0.6's
  reporting tool (O135). Closes O217. The owner: "i accept
  recommendations." Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#4-the-trap-family-the-register-itself-t300t308).
- **D334 (2026-11-03, same answer): The register's format additions go
  into the master spec with O111's text:** a domain's
  `data/register.yaml`, `governance.register`, `gm/data-register.yaml`,
  `register_diff:`, the loader's digest and coverage checks. Closes
  O218. Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#6-format-impact-o111-d334).
- **D335 (2026-11-03, same answer): Every scenario listing `domains:`
  must have a register,** and the deploy refuses one without it; v0.4's
  released shop scenario is exempt until next revised; optional with
  `governance:` alone. Closes O219. Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md#3-generation-the-gms-data-register-skill-d331).
- **D336 (2026-11-03, same answer): The handout page's other
  "(proposed)" details stand as written,** D331's skill details
  included: the entry and its grouping, the two handouts, the skill's
  inputs, outputs, triggers and checks, the trap family, the chunks.
  Reason: the page went to the owner whole, and no question but
  O217–O219 was left on it. Now in:
  [versions/v0.5/data-register-handout.md](versions/v0.5/data-register-handout.md).
- **D338 (2026-11-03, spec action at consolidation, on the owner's "yes,
  start the master spec"): O111 closed: the domain format is written
  into formats.md v28** ("Domain", "Scenario", "Purpose definition"):
  D326's composition items, the procedure's format changes, the variant
  and producer layout, the purpose format's extensions (D307) and the
  data register's additions (D334), as D291 set. Closes O111. Now in:
  [formats.md](formats.md#domain-from-v04-composed-domains-from-v05).
- **D339 (2026-11-03, owner approval, relayed by the coordinator): v0.5's
  master spec and access model are approved, with the review's R1–R3 and
  R5–R20 as recommended,** and the six domain documents with them
  (procedure step 9), corrected to the spec first (R16); purpose 2's
  30-second acknowledgement (R13), the night rota over the 25 section
  vets (R15). The owner: "agreed." Now in:
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md),
  [versions/v0.5/access-model.md](versions/v0.5/access-model.md).
- **D340 (2026-11-03, same answer, R4): The monitoring breadth is a
  `pgwatch` brick (pgwatch 3, its Prometheus sink feeding v0.2's
  Grafana), pgCluu in `postgres` run on demand as pgBadger is, and a
  light `health-check` node running `check_postgres` with a status page
  and the customer's scripts; one collector only if CPU is short.**
  Closes O220. The owner: "agreed." Now in:
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md#74-the-monitoring-breadth) 7.4, 14.
- **D342 (2026-11-03, owner approval, relayed by the coordinator): v0.5's
  build plan v1 is approved, with κ = 3 and its four plan choices as
  recommended:** the bumps and re-pins a chunk of their own (chunk 1),
  `bastion` 0.5.0 whole in the data-register chunk (17), each partner
  stub built by its domain's or purpose's chunk, the standby tooling in
  the `postgres` chunk (3). Clears G1, `v0.5-domains` merged into
  `main` by the coordinator. The owner: "agreed. merge. i'll clean after
  and start wave 1". Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) (header,
  "Gates", "Workflow deltas").
- **D343 (2026-11-03, same answer): O223–O227 as the plan recommends:**
  `grafana` 0.3.0, the existing scenarios re-pinned (O223); if CPU is
  short, the exporters kept and pgwatch dropped (O224); pgCluu's report
  in the player's home, read with `scp` (O225); the health node on the
  VPS (O226); machine 10's telemetry settled by measurement in chunk 15
  (O227). Closes O223–O227. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#settled-with-the-owner).
- **D344 (2026-11-03, wave 1 preflight correction 1): A domain's
  producer fragments sit in one folder per scheduler node they target,
  `producers/<node>/`; `api`, `partners` and `public` are reserved; the
  shop's move to `producers/producer/`.** The approved format said a
  domain declares the nodes its fragments target, but not how;
  `vet-housing` feeds `pms` and `ward`. Now in:
  [formats.md](formats.md#producer-material),
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md#61-the-domain-format) 6.1, 8.4,
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 2, 9, 12.
- **D345 (2026-11-03, correction 2): An `api` node's `api.yaml` names
  each endpoint's hostnames and accepted credentials and the node's
  connections; chunk 3 derives its roles' secrets and passwords from
  it, skipping `driver: http` connections.** 6.5 named the roles'
  secrets but nothing derived them; chunk 3 holds `localimpl.py` and
  `inject.py` in wave 1, so chunks 7 and 8 never share `inject.py`.
  Now in: [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md#65-brick-definition-brickyaml)
  6.5, 6.8; [formats.md](formats.md#producer-material);
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 2, 3, 5, 6.
- **D346 (2026-11-03, correction 3): Chunk 1 writes `GM_OPTIONS:
  monitoring` into the hand-written stack files whose `postgres` serves
  an exporter.** Once chunk 3 creates `monitoring` only with the
  option, they would fail at wave 1's gate. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#chunk-1--versions-declarations-and-re-pins).
- **D347 (2026-11-03, correction 4): The HTTP credential's secret, name
  and readers are W1's, since chunks 4 and 5 read them in wave 1; W2
  keeps which nodes mount which, and chunk 7 mounts them on callers,
  `api` nodes and archiving `postgres` nodes.** Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#chunk-7--render-for-v05-aliases-and-http-credentials).
- **D348 (2026-11-03, correction 5): Chunks 9 and 11 are cut once chunk
  6 has merged (in-wave edges `6 ──> 9`, `6 ──> 11`), not merge order
  only as proposed.** Until chunk 6 the loader refuses `driver: http`
  and the weighted `choice`, so vet-core's `check_domain_dir` and
  chunk 11's fixtures could not pass on a branch without it; chunk 10's
  edge stays merge order only (its key passes as unknown). Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#waves) ("Read first", "Waves").
- **D349 (2026-11-03, correction 6): `api` joins the node roles, the
  `api` brick's; `pgwatch` and `health-check` take `monitoring`.** Now
  in: [formats.md](formats.md#roles);
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 1, 2.
- **D350 (2026-11-03, correction 7): Chunk 6 reserves `options` and
  `standby_of` as parameters and `replicator` as a role, and checks a
  primary's replication line; chunk 4 forbids `replicator`.** Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 4, 6.
- **D351 (2026-11-03, G5 and G6 cleared): Chunk 3 builds under G5's
  conditions, `vault-post` in Perl with core `HTTP::Tiny`, the snakeoil
  key deleted as advised; chunk 5 under G6's, from the hash-pinned
  `bricks/api/requirements.txt`; the PyPI source is listed as pending
  with the owner.** Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 3, 5,
  "Pending with the owner".
- **D352 (2026-11-03, end of wave 1, chunk 3's finding 2): A restart
  from the hand-over snapshot not bringing a standby back as one is a
  named known limit of v0.5, not an inserted chunk.** No v0.5 game
  reaches it: the clinic has no snapshot on its declarations (master
  spec 14), G13 takes none (18.3), the existing scenarios have no
  standby (17.5); restarts are v1.0 gating's (18.4). 7.1's "keeps
  working" holds for taking it (W1-x). Re-cloning after a restore would
  add restart behaviour 15 does not state: the owner's to ask for. Now
  in: `bricks/postgres/docs/gm.md` "Known limits"; [versions/README.md](versions/README.md#v10-gating);
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) (release gate, item 12).
- **D353 (2026-11-03, chunk 2's point): `register_diff`'s key stays
  `true:` as master spec 6.8 writes it; the loader reads it as PyYAML
  gives it, boolean `True`, or quoted `"true"`, never both in one item,
  through one accessor its later readers share.** No author has to
  remember a quote. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#chunk-6--loader-checks-for-v05) chunk 6.
- **D354 (2026-11-03, chunk 2's point): `public` confirmed as a purpose's
  `connections:` value for an HTTP connection to a public endpoint; an
  HTTP credential named `public` refused.** It echoes `api.yaml`'s
  "absent: public" and cannot be a database role. Now in:
  [formats.md](formats.md#purpose-definition-from-v04);
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#chunk-6--loader-checks-for-v05) chunk 6.
- **D355 (2026-11-03, W1-y against W1-x, W1-z): The two `no-access`
  mechanisms stay as built; no chunk unifies them.** Same outcome
  (access model 5), each documented in its brick's `docs/gm.md`; a
  rewrite of a working entrypoint buys nothing in play. A later version
  touching `scheduler`'s entrypoint for its own reasons may adopt the
  filtering form.
- **D356 (2026-11-03, chunk 5's finding 3): A caller's bounded wait
  promises an honest failure past its bound, not resolution within it:**
  a health-checked peer enters Swarm's DNS only once healthy (a fresh
  `postgres` node about 49 s). Bounds kept at 30 s. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#read-first)
  ("Read first", workflow deltas, chunks 7, 10).
- **D357 (2026-11-03, end of wave 1): Text corrections:** chunk 1's
  count is twelve `postgres` faults; chunk 2's Done when names
  `tarnbeck-outdoor-campaign`; pgaudit 18.0 redacts role passwords
  itself (G5's premise was statement logging's only; the guards kept).
  formats.md lists no secret kinds, so `certificate` needs no line
  there. Now in: [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 1, 2, 3.
- **D358 (2026-11-03, wave 2's chunks read against W1-w to W1-z):**
  chunk 6 mirrors the scheduler's HTTP refusals (a target may be a
  partner's alias), checks `api.yaml`'s roles, the partners' hosts and
  `vault_*`, re-adding no `domains:` check; chunk 7 updates the secret
  lists' tests; chunk 8 reuses `NO_AUDIT_SQL` and `standby_plan`; chunk
  9's fixture waits for chunk 7 if `clinic-api` names a credential. Now
  in: [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 6 to 9.
- **D360 (2026-11-04, capture W2's corrections 1 and 2): Chunk 6 adds
  `model.node_creates` and a partner folder's `data.sql`; chunk 8 runs
  that file into `partners`, streams `data/keys.sql` and passes
  `load_epoch`; chunks 7 and 8 read `node_creates` and merge after 6.**
  Else a composed domain's databases, roles and partner state have no
  loader. Now in: [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 6 to 8, wave 2.
- **D361 (2026-11-04, the edges D360 and D362 add): Wave 2 keeps two
  three-chunk completion chains (6, 7, 11 and 6, 8, 9), past the
  model's two.** The merge-order edges delay no start, and W2 fixes
  every interface they cross. Rejected: moving 9 and 11 to wave 3,
  which would put it at seven chunks with in-wave chains of its own.
  Now in: [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#waves) ("Wave 2").
- **D362 (2026-11-04, capture W2's corrections 3, 4, 6, 10 and 7's Files):
  Chunk 9's fixture waits for chunks 7 and 8; chunk 7 gains
  `fixture-alias/`, chunks 6 then 8 the scenario-format skill, chunk 11
  `partners/` and the README's layout row; chunk 10's stack test answers
  `GET /manifests` with a stand-in.** Each names what its chunk already
  does. Now in: [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 6 to 11.
- **D363 (2026-11-04, capture W2's correction 5): Chunk 6 refuses every
  third-party node and alias in `web_routes`; chunk 17 adds cold
  storage's one exception to `model._check_web_routes`.** The route's
  form is chunk 17's front. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 6, 17.
- **D364 (2026-11-04, capture W2's correction 7): formats.md and master
  spec 5 take wave 2's format items as built, after its gate, as G16.**
  Wave 3 reads them from capture W2 and the skill meanwhile. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#gates) G16, release gate item 6.
- **D365 (2026-11-04, capture W2's correction 8): Chunk 17 hands the
  players the credentials `partners.md` documents with the starter
  pack: the customer's own with that partner, its game value, never
  `cold_storage` (upload is denied, its reads public); W4 fixes how a
  scenario names them.** Access model 3 and 6 and master spec 10.2 say
  the starter pack gives them, so "public endpoints only" is out.
  Now in: [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 17, 27.
- **D366 (2026-11-04, capture W2's correction 9): Purpose 14's planted
  manifests must fit W2 item 3's history rule; another form is an
  inserted chunk.** No chunk after 8 holds `inject.py`. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunk 21.
- **D367 (2026-11-04, wave 1's gate): The full quality command judges
  each existing scenario's smoke against its own design, by the
  harness's rules as wave 1's gate fixed them.** Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md#workflow-deltas).
- **D368 (2026-11-04, G9): Text correction: pgwatch is its latest
  release at the build (6.1.0 at G9), not "pgwatch 3".** The 3.x line
  ended at 3.7.0, which G9 rejected; 7.4's own rule already named the
  latest cleared release. Chunk 10 points to G9's conditions in the wave
  log. Now in: [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md)
  7.4, 21; [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) G3, G9, chunk 10.
- **D369 (2026-11-04, the spec gap chunks 6 and 8 found): The owners'
  traffic takes `producers/partners/owners/`; no v0.5 folder uses
  `public/`, and chunk 17 refuses a `data.sql` there.** The route keeps
  its record of visits in `partners` (master spec 9.7, 10.2), which only
  `partners/`' `data.sql` loads (W2 item 3), and no chunk after 8 holds
  `inject.py` (D366). No wave-3 chunk plans a `public/` one. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 16, 17, G16.
- **D370 (2026-11-04, the same pass): Text correction: chunk 12's lab
  stub folder is `producers/partners/xlab/`, not `northfield-lab/`.** A
  partner's folder is its prefix (W2 item 0), which chunk 6 checks;
  `xlab` serves the hostname `northfield-lab`. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunk 12.
- **D372 (2026-11-04, chunk 9's stop): The code catalogues live in their
  parts' domain documents: the lab's layout, named codes and the
  centre's draw; machinery's 30 procedures and their draw. The core's
  `keys.sql` draws from them (chunk 9); chunks 12 and 15 load them.**
  The tables are the parts'; one written source, not the core's code,
  keeps three chunks equal. Scheduling's imaging types are one per
  section and machine. Now in:
  [vet-lab](versions/v0.5/vet-lab-domain.md#the-test-catalogue-d372),
  [vet-machinery](versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373),
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md) (`sched_types`).
- **D373 (2026-11-04, the same stop): MR and NM codes on large animals
  are horses only: codes 26 and 27 and machines 10 and 16 take
  `species_group` `horse`; a farm animal draws DX, US and CT (the
  large-bore CT 8); an urgent request never draws 26 or 27.** The
  standing MRI and the gamma camera take horses only (machinery's
  machines). Now in: [vet-machinery](versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373);
  [master spec](versions/v0.5/master-spec.md) 9.2, 9.6.
- **D374 (2026-11-04, the same stop): The core's key functions are
  eighteen: W2 item 4's thirteen plus `core_animal`, `core_owner`,
  `core_ownership`, `core_exchange` and `core_shifts` (the rota's pattern
  with the history's absences), each returning what the table says; no
  `core_withdrawal` (the request carries it).** Each answers a part's
  load that would otherwise re-derive it. Amends capture W2 item 4. Now
  in: [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379);
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md) ("What the
  load needs of the core's").
- **D375 (2026-11-04, the same stop): `core_request` returns the
  request's state at T0 with its times (`resulted` or `cancelled`, the
  last 24 hours' `sent`, none `requested`), the consultation's priority
  (urgent for emergencies and stays), vet, animal and close, and the
  milk inhibitor test's withdrawal end; the parts fit their times inside
  it.** Chunk 9's choices, as the core's own `consultations.close`
  writes them. Now in: [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379).
- **D376 (2026-11-04, the same stop): Routine imaging is booked and
  scheduled within two working days, the final report within one more:
  the turnaround stays three.** Machinery's scheduling, its timeout and
  9.6's turnaround agree on 2 + 1; only 9.4's booking said three. Now
  in: [master spec](versions/v0.5/master-spec.md) 9.4;
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md) (`book-requests`).
- **D377 (2026-11-04, the same stop): An intensive-care session covers
  one domestic stay in two and one horse stay in four, never a farm
  stay, on a free monitor of its group, until a step-down 24 to 72 hours
  after admission or the stay's end.** "One in three for the whole
  stay" gave about 13 at once against the 8 monitors and the "about
  five" the raw volume rests on; the step-down keeps 2.7 a day and five
  at once. T206's witness is about one a day. Now in:
  [vet-machinery](versions/v0.5/vet-machinery-domain.md) answer 7,
  `mach.census`; [master spec](versions/v0.5/master-spec.md) 9.6.
- **D378 (2026-11-04, the same stop): Text correction: the referring
  vets' mapping (`core_referring_practice`) is read by
  `vet-scheduling`'s `sched_trainees` (master spec 9.4, left to the
  build by 24), not by 9.3: the lab reads practices by id only.** Now
  in: [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379).
- **D379 (2026-11-04, the same stop): Chunk 9's identifier and signature
  choices stand: chips on every dog, cat, horse and ferret, none on two
  rabbits in three (rabbits about 3 % of domestic animals, the 2 %);
  the member state `XA` and one user-assigned 900–998 code; time
  functions `(n, load_epoch, utc_offset)`, all `IMMUTABLE`.** Fictional
  codes point at no real registry; the zone is a fixed offset. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379)
  and its "Natural identifiers".
- **D380 (2026-11-04, the same stop): Plan correction: `vet-core`'s
  variant holds `parts: []`; chunks 12 to 16 each add their id to it, a
  shared list in their Files.** `check_domain_dir` requires every part
  named there to exist with its own manifest. Now in:
  [archive/v0.5/build-plan.md](archive/v0.5/build-plan.md) chunks 9,
  12 to 16, workflow deltas.
- **D381 (2026-11-04, chunk 11's finding): Cold storage's manifest is keyed
  `(source, shipment_id)`, its source the node holding the data; the same id
  from the same source replaces it, from another source makes a second;
  `GET /manifests` ordered by `received_at`, source, id; the page sums the
  sources.** `records` and `lab` post the same segment names. Gate fix. Now
  in: [master spec](versions/v0.5/master-spec.md) 10.4; [cold-storage.md](versions/v0.5/cold-storage.md) 3; [build plan](archive/v0.5/build-plan.md) gate, chunk 21.
- **D382 (2026-11-04, the same finding): The planted `wal` names sorting
  above the live ones stay a known limit: no check reads them in name order
  (s2's and T38's compare names or sources, the page counts days), and a
  check finding a node's latest `wal` manifest orders by `received_at`.**
  A 35-day history cannot sort below a fresh cluster's first segment;
  pushing the live names up (`pg_resetwal -l`) would change `postgres`
  0.5.0 for realism alone. s2's answer key notes it as a setup limit. Now
  in: [build plan](archive/v0.5/build-plan.md) chunk 23.
- **D383 (2026-11-04, chunk 11's second finding): `partners-db` gets no
  `gm_check` host line; a coherence check whose `reads` names `partners`
  runs in the partners' database on the partners' node (as `postgres`, read
  only, unseen), `gm_src_partners` over that node's socket, its other reads
  over TCP from there, every table through `gm_src_*`, no `database:`; a
  derivation or history reading `partners` from another node is refused.**
  A host line breaks 10.2 and access model 8; dropping such checks drops
  9.3's "stubs' open send-outs and orders matching the lab's". As purpose
  14's history. First met by chunk 12; fixed at wave 2's gate. Now in:
  [access model](versions/v0.5/access-model.md) 8; [build plan](archive/v0.5/build-plan.md) gate, chunk 12.
- **D384 (2026-11-04, chunk 9's second stop): Each section has a duty vet
  on Saturday and on Sunday, 08:00–20:00, by rotation over its vets,
  never one of that weekend's night vets; Saturday's two domestic vets
  08:00–13:00 stay, for the bookings.** A 24/7 hospital with stays and
  emergencies had no vet on Saturday afternoon, none for horses and farm
  all Saturday. `sched.rota.publish` carries the same. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md) (the rota's
  pattern); [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379) (`core_shifts`).
- **D385 (2026-11-04, the same stop): About four in ten consultations make
  requests, 0.65 on average: a lab order of 1.8 analyses in three in ten
  (about 7 700 in the history, no more), an imaging study in one in
  eight.** "Two in three" at 0.65 cannot give the lab's 1.8 tests an
  order; an imaging share drawn per request gives about 1.6 and 8 500
  orders, past the lab's 1–14 000 with the practices' 6 300. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379)
  (`core_request`'s `kind`), `consultations.close`, point 3;
  [vet-lab](versions/v0.5/vet-lab-domain.md) (the two constraints).
- **D386 (2026-11-04, the same stop): No history draw repeats with a fixed
  period in id order: fixed counts per block of ids may stay, their
  places shuffled per block by a hash of the block's number, or the draw
  a hash of the id.** Ids run in time order, so the requests' 40-id
  places (and the stays' section and outcome) show as a period in time;
  the live streams already vary by a hash of the row's id. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379) ("Draws from an id").
- **D387 (2026-11-04, the same stop): Text correction: the core's load is
  expected at one to two minutes, not "a few seconds"; it matters for
  nothing.** Each row is computed by the key functions (about 2 ms a
  consultation or request); `load-data` has no limit, every test stays
  under 30 minutes. Now in: [vet-core](versions/v0.5/vet-core-domain.md)
  (Loading); [master spec](versions/v0.5/master-spec.md) 9.2.
- **D388 (2026-11-04, the same stop): Chunk 9's nurses' four-week cycle
  stands, each section's every shift held, no rest, weekly-rest or
  48-hour breach; the history's absences are periods of one day to two
  weeks on weekday day and late shifts, leave about five weeks a year a
  head, about 600 a year.** The chosen 3.5 % of staff-weeks gave under
  two weeks' leave, below Directive 2003/88/EC Art 7's four, which the
  working-time purpose's reader knows. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md) (the rota's
  pattern, the history's absences); [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379) (`core_shifts`).
- **D389 (2026-11-04, the same stop): `MINH`'s checked line is on the
  herd's latest earlier consultation early enough for its withdrawal to
  end before the request, written by the load; `MINH` is never drawn
  where none exists.** The request's function must know the date; a
  count of cases without one would break the lab's validity rule. Now
  in: [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379)
  (`withdrawal_ends_on`); [vet-lab](versions/v0.5/vet-lab-domain.md#the-test-catalogue-d372).
- **D390 (2026-11-04, the same stop): The history's inbound exchanges are
  examinations of unregistered animals (`partner_patient` kept), no
  inbound transfer; their ids stay in `requested_at` order, an
  office-hours time drawn there, never moved past the next id's.** The
  history's ranges are in time order (vet-core's key ranges). Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379) (`core_exchange`).
- **D391 (2026-11-04, the same stop): An administration's `given_by` is a
  nurse of the stay's section, not matched against the rota, in the
  history and the live round alike.** The spec ties only a
  consultation's vet to the rota. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md) (Loading).
- **D393 (2026-11-04, chunk 9's third stop): The history's
  administrations stand at the build's 61 241, about 60 000, the range
  1–70 000 and the load's cap kept; the live round gives each active
  line's doses at its frequency (every 4, 12 or 24 hours), as the
  history does, about 210 a day.** One dosing model in the history and
  live keeps the ramp ending at the live rate (D279). Now in:
  [vet-core](versions/v0.5/vet-core-domain.md) (volumes, jobs); MR1, T65.
- **D394 (2026-11-04, the same stop): D388's every-shift rule binds each
  section's nurses and technicians; the carers keep the same cycle, 57–60
  horse, 61–62 farm, 63–66 domestic, the farm's two holding two phases a
  week and its nurses the rest; a care event's carer is of the unit's
  section, not matched against the rota.** Ten carers can't fill four
  phases in three sections, and two can't hold days and lates daily.
  Now in: [vet-scheduling](versions/v0.5/vet-scheduling-domain.md) (the
  rota's pattern); [vet-housing](versions/v0.5/vet-housing-domain.md).
- **D395 (2026-11-04, the owner on D365): D365 stays, tracked: the
  starter pack keeps handing the players the customer's own partner
  credentials, and whether to rectify it is a later question (O231).**
  A DBA may find it odd and report it, a plausible, reasonable finding;
  the owner keeps it as a game's distance from ground truth ("It's
  still a game"). Now in: [open-questions.md](open-questions.md) O231;
  [versions/v0.5/access-model.md](versions/v0.5/access-model.md) 13.
- **D396 (2026-11-04, the owner after D368): Until v1.0 each brick takes
  its tool's latest available version; from v1.0 versions are handled
  game-wide (old PostgreSQL majors such as 13, older and hand-installed
  tools, migrating up to standard).** Now in:
  [versions/README.md](versions/README.md#from-v10-versions-at-a-game-wide-scope-d396);
  [open-questions.md](open-questions.md) O11.
- **D397 (2026-11-04, the owner on D352): A restart from the hand-over
  snapshot gives back every node as it was meant to run, replication
  included; D352 is superseded and its known limit removed.** The owner:
  "a restoration procedure that doesn't work means as much as no
  procedure at all". A standby held as one and cloned again from its
  restored primary, the only mechanism that holds: the copies are taken
  at different moments and no WAL is kept to replay between them. Now
  in: [master spec](versions/v0.5/master-spec.md) 7.1, 15, 18.2;
  [versions/README.md](versions/README.md#v10-gating);
  [build plan](archive/v0.5/build-plan.md) chunk 28, release gate.
- **D398 (2026-11-04, D397's chunk): Chunk 28 is inserted into wave 2,
  gated but not merged, so the fix merges with it;** it depends on chunk
  3 alone and is cut from the gated `v0.5-w2`; the gate items it touches
  are rerun after it merges. Now in:
  [build plan](archive/v0.5/build-plan.md#chunk-28--a-restart-from-the-hand-over-snapshot-gives-back-replication)
  (waves, per-wave gate contents).
- **D399 (2026-11-04, the owner after D396): `check_postgres` stays the
  health node's checker for now; a switch is expected some day, though
  it may stay in use with older versions from v1.0.** Now in:
  [versions/README.md](versions/README.md#from-v10-versions-at-a-game-wide-scope-d396).
- **D400 (2026-11-04, the owner on G8's open point): pgBadger stays
  unpinned, as is.** Now in:
  [versions/README.md](versions/README.md#from-v10-versions-at-a-game-wide-scope-d396).
- **D401 (2026-11-04, capture W3's corrections 1 and 4, the wave
  driver): Chunk 29 is inserted into wave 3, for a `coding-executor`:
  W3 item 6's (a) to (d) and a `load-data` step running the purposes'
  target DDL in the composed domains' databases; G17 carries its format
  items into formats.md.** It is the only chunk holding `inject.py`
  before wave 4, which cannot be built without it. Now in: [build plan](archive/v0.5/build-plan.md)
  chunk 29, G17, waves, chunks 12, 15, 16, 18 to 21, release gate item 6.
- **D402 (2026-11-04, the edges D401 adds): Wave 3 keeps a three-chunk
  completion chain (29, 12, 16), past the model's two.** `29 ──> 12`
  holds back only chunk 12's composed check and fixture, so no start is
  delayed, and W3 items 0 and 6 fix the interfaces it crosses. Now in:
  [build plan](archive/v0.5/build-plan.md) ("Waves", wave 3).
- **D403 (2026-11-04, capture W3's correction 2): The fixtures meet
  compose's rule: chunks 13 and 14 add `clinic-api`, chunks 12 and 16
  use `left_out:` (W3 items 1 and 5), and chunk 12's stubs are composed
  by a unit test in `test_compose.py`.** Chunks 18 to 21 carry W4's
  counts to make. Now in: [build plan](archive/v0.5/build-plan.md) chunks 12 to 14, 16, 18 to 21.
- **D404 (2026-11-04, capture W3's correction 3): `derive.sql` writes
  `portal` only; purpose 16's `history` plants the messaging stub's
  messages, `target` the partners' database, source `portal`, the stub's
  DDL its receiver material in `partners-db`'s data file, `SELECT`
  granted to `owners`.** T0's state is the same either way, and only a
  history writes `partners` from a source. Closes O229. Now in:
  [master spec](versions/v0.5/master-spec.md) 9.7;
  [vet-portal](versions/v0.5/vet-portal-domain.md#loading) ("Loading",
  "The history before T0", `vet-portal-messages`); [build plan](archive/v0.5/build-plan.md) chunks 16, 21.
- **D405 (2026-11-04, capture W3's correction 5): A composed domain's
  `pg_cron` jobs go in its `data/cron.sql`, which `load-data` runs on
  its node after the part's load (chunk 29's (d)).** The node's data file
  runs before their databases and roles exist; chunk 29 first checks
  that pg_cron refuses such a job, and may drop (d) if it accepts one. Now in:
  [vet-machinery](versions/v0.5/vet-machinery-domain.md#loading) and
  [vet-portal](versions/v0.5/vet-portal-domain.md#loading) "Loading";
  [build plan](archive/v0.5/build-plan.md) chunks 15, 16, 29.
- **D406 (2026-11-04, capture W3's correction 6): Text correction: the
  portal's passwords and tokens use a key computed from the load's
  `load_epoch`, kept only in `owners`' schema on the partners' database,
  not "the game's seed",** which reaches neither the load nor the
  owners' route. Now in: [master spec](versions/v0.5/master-spec.md) 9.7
  "Keys and scale";
  [vet-portal](versions/v0.5/vet-portal-domain.md#deterministic-key-ranges-d249-d266);
  [build plan](archive/v0.5/build-plan.md) chunk 16.
- **D407 (2026-11-04, capture W3's correction 7): Wave 3's gate loads the
  six domains on `fixture-clinic-load`, uncomposed, built at the gate's
  start by a `coding-executor` from the merged parts, and reruns
  `fixture-lab-core` with the other four.** No chunk's Files held that
  fixture; chunk 27 changes it later. Now in: [build plan](archive/v0.5/build-plan.md) ("Per-wave gate
  contents", wave 3), chunk 27.
- **D408 (2026-11-04, chunk 13's stop, point 1): The history's scheduled
  consultations follow the agenda: on half-hour slots, the section's
  vets on a covering shift and its consultation spaces taken in id
  order, none past them; an unbooked consultation takes a vet with no
  booking over it when one is on shift.** The approved demand puts more
  domestic consultations at the evening and Saturday peaks than the rota
  has vets (1 474 unplaceable even optimally), so no free-vet pick, nor
  a booking's vet differing, can meet "no overlap"; this cap is the one
  draw within the figures: about 4 % fewer (16 700 attended). T100's
  witness reads scheduled consultations only. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379);
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#deterministic-key-ranges-d249-d266)
  ("The history on the agenda", T100); master spec 9.4; wave log "W3
  item 2, revised" (a), (b).
- **D409 (2026-11-04): Chunk 30 inserted into wave 3 for a
  `coding-executor`, ahead of chunk 13 (`30 ──> 13`, in-wave): D408's
  rule in `core_consultation` and D413's columns in `core_exchange`.**
  Wave 3 holds seven chunks, past the model's six: both insertions are
  small and came mid-wave. Chunks 12, 14, 15 and 16 call the core's
  functions, so none changes; the gate's loads supersede their figures.
  Chunk 13 gains a split rule. Now in: [build plan](archive/v0.5/build-plan.md)
  ("Waves", chunks 13, 30).
- **D410 (2026-11-04, point 2): Consultation types take 30 minutes on
  their room's half-hour grid, in their section's consultation spaces
  (domestic rooms 1–4, horse 8–10, farm 12 and 13); the farm's rooms
  open Monday to Friday 08:00–16:00.** One crush could not take the
  farm's concurrent bookings, nor two stalls the horses'; the core's
  farm consultations run to 16:00. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#entities)
  (`sched_types`, Cadences).
- **D411 (2026-11-04, point 3): Shifts are planned to the horizon ahead
  of their publication: the load and each Friday's job keep the rota
  planned to the end of the seventh week ahead, publishing the week
  after next; the slot function reads both; shifts 1–24 000.** The
  approved lifecycle already has planned shifts, and a 42-day horizon
  needs a rota to meet. Now in: [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#lifecycle-states)
  (lifecycle, ranges, `sched.rota.publish`); master spec 9.4; wave log
  "W3 item 2, revised" (d).
- **D412 (2026-11-04, points 4 and 5): `sched_free_slots` copies the
  core's staff layout into its text, one formula with `core_staff`; for
  a session type it checks enough teaching animals free and returns
  none, the caller picking them.** The schema must run without the
  core's tables; the signature stays W3's. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#entities)
  ("Logic in the database").
- **D413 (2026-11-04, point 6): `core_exchange` returns the reason and
  the partner patient's species its load writes; an inbound
  examination's machine follows them (CT, MRI, gamma camera,
  ultrasound by species; a second opinion or endoscopy a consultation).**
  A part's own draw would book an "MRI examination" on a CT. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#the-key-functions-d374-d375-d379);
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#deterministic-key-ranges-d249-d266)
  ("An inbound examination's booking"); build plan chunks 21, 30.
- **D414 (2026-11-04, point 7): Scheduling's schema grants `vet_reports`
  every `sched_` table, guarded on the role existing; W3 item 0 stands.**
  Master spec 9.2 and vet-core's grants say so; the domain document's
  table had left the row out. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#application-roles-and-grants).
- **D415 (2026-11-04, chunk 12a, documents to as-built): `vet-lab`'s
  figures and grants are the build's: `lab_samples` as loaded, about
  20 800 (one a container, the centre's 11 777); about 161 000 results,
  9 800 batches, 8 send-outs open at T0; intervals 61–456 in force,
  457–460 unused; `lab_instruments` reads `lab_orders (id, species,
  priority)` and `lab_tests (id, code, discipline)`, `lab_dispatch` the
  catalogue.** Measured by the load, within the approved spec; chunk 30
  (D408) moves them a few per cent, the wave gate's reruns the figures
  of record. Now in: [vet-lab](versions/v0.5/vet-lab-domain.md#deterministic-key-ranges-d249-d266)
  (the variant, ranges, grants, sizes, T0); master spec 9.3.
- **D416 (2026-11-04, chunk 15a, documents to as-built): `vet-machinery`
  as built: a settings row per database; `mach_worklist.cancelled_at`,
  read by `mach_orders`; `mach_maint` `LOGIN` for `pg_cron`; 11 machines
  reporting (O227); about 2 intensive-care sessions, 42 700 raw vitals
  and 59 000 rows a day, 2 980 imaging requests a year, 0.28 million
  rows, 75 MB, 51 s; the history's finals on the core's turnaround.**
  Measured within the approved rules; the PACS reading no registry is
  O235's. Now in: [vet-machinery](versions/v0.5/vet-machinery-domain.md#reference-sizes);
  master spec 9.6, 10.4; [purposes](versions/v0.5/clinic-purposes.md#the-roles-the-purposes-add).
- **D417 (2026-11-04, chunk 14, documents to as-built): `vet-housing`
  as built: `housing` reads `stays.reason`, `animals.born_on` and
  `business_settings` for the board, `housing_ward` has `USAGE` on the
  care log's sequence; an animal moves into isolation as soon as one is
  free and out when its alert ends (157 stays moving twice, 47 of 249
  infectious ones waiting, 5 never in); about 0.14 million rows, 17 MB,
  7.5 s; the short test's limits (T0 to the hour, a live release's
  disinfection unseen, the hand-over nine hours out).** Measured within
  the approved rules; T163's witness against the waits is O236's. Now
  in: [vet-housing](versions/v0.5/vet-housing-domain.md#reference-sizes); master spec 9.5.
- **D418 (2026-11-04, the driver, closes O235): The `pacs` load keeps
  the history's studies out of `biomed`'s downtime windows, derived by
  its formulas (salts 502, 505, 506), checked inside `pacs`; live, the
  PACS reads no registry, and a story taking a machine down stops its
  acquisitions itself.** As recommended; chunk 15b builds it. Now in:
  [vet-machinery](versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373);
  [build plan](archive/v0.5/build-plan.md) chunk 21 (`mach_archive`'s
  settings reads, for W4).
- **D419 (2026-11-04, the driver, closes O236): T163's witness is an
  infectious animal outside isolation while an isolation unit of its
  section has stood clean and free for more than a day.** As
  recommended: the history's waits, every isolation unit held, no
  longer fire it. Now in:
  [vet-housing](versions/v0.5/vet-housing-domain.md#3-care-feeding-and-biosecurity) (T163, false alarms).
- **D420 (2026-11-04, chunk 12b, documents to as-built): `vet-lab` as
  built: `lab_instruments` reads `lab_results (order_test_id)` (the
  driver's ruling), `lab_api` the reference intervals; the release
  rounds three jobs (`0 11 * * *`, `0 14`/`0 18` on days 1–6), the
  loader taking no day-of-week range nor two hours; the practices'
  `client_ref` on the local date, `practices.state`'s `utc_offset`; no
  food-chain status on an order (no trap reads one).** Grants and job
  layout the build needed, the times unchanged; 9.3's and SO4's
  "twenty" send-outs at T0 corrected to D415's eight. Now in:
  [vet-lab](versions/v0.5/vet-lab-domain.md#application-roles-and-grants)
  (grants, jobs, the practices); master spec 9.3; [purposes](versions/v0.5/clinic-purposes.md) (SO4).
- **D421 (2026-11-04, chunk 16b's stop, the driver's ruling (a)): Chunk
  31 inserted into wave 3 for a `coding-executor`, ahead of 16b's
  restart (`31 ──> 16`): with no `third_parties:` entry listing a
  scheduler or `api` node, `compose` and the loader take the `no-access`
  nodes `partners-backend` and `partners-api` as the partners' shared
  nodes when the only partner material composed onto them is a domain's
  `producers/partners/owners/`, serving `owners` alone.** The names are
  the plan's (chunk 11's nodes): the scenario says nothing else that finds
  them. Rejected: (b) `lab-api` and the lab's stubs composed for real
  changes the fixture chunk 21 builds on; (c) a placeholder messaging
  party builds chunk 21's material early. Now in: [build plan](archive/v0.5/build-plan.md)
  ("Waves", chunks 16, 31).
- **D422 (2026-11-04, chunk 13, documents to as-built): `vet-scheduling`
  as built: W3-b's columns (`sched_rooms.consultation_space`,
  `sched_types.staff` and `course_id`, `sched_machines.around_the_clock`,
  the generated `during`, `sched_shifts_staff_start_key`); types 1–12,
  13–24, 25–27, 28–29, 30–45; machines 7, 8, 11–15 around the clock, 9,
  10, 16 the imaging day; `sched_app`'s column grants on shifts and
  sessions; inbound examinations 28 001–28 700; shift ids past 24 000
  from a weekend T0; the load reading `vc_agenda`, a session six weeks
  from its target else the next course; about 800 theatre plans, 2 900
  imaging, 23 800 shifts, 800 absences, 0.10 million rows, 20 MB.**
  Measured within the approved rules, the inbound range the owner's
  choice; an urgent study after the imaging day is O239's, the load's
  future absences O240's. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#deterministic-key-ranges-d249-d266)
  (entities, ranges, placement, grants, sizes); master spec 9.4.
- **D423 (2026-11-04, chunk 16, documents to as-built): `vet-portal` as
  built: the keeper's clause and the documents' start through two
  `SECURITY DEFINER` helpers the policies call (`portal_keeper_granted`,
  `portal_owner_since`); `portal_logout`; one link slot, an invitation's
  or a reset's, 14 days; an `activation` event only on a grant; the
  logging settings in `schema.sql`; `portal` `BYPASSRLS`,
  `portal_housekeeping` a login role; the status codes, superseded
  versions listed, no herd listing; the outbox numbered by `queued_at`;
  `owners.accounts`; about 0.20 million rows, 77 MB.** Within the
  approved model (one link slot and life, the functions owning
  authentication), the figures after D408's agenda; the desk's 422 for a
  closed account is O241's, T274's witness O242's. Now in:
  [vet-portal](versions/v0.5/vet-portal-domain.md#who-sees-what-row-level-security-ruled-d320)
  (policies, endpoints, ranges, sizes, loading); master spec 9.7.
- **D424 (2026-11-04, the driver, closes O239): An urgent imaging
  request is booked at its machine's first free slot: the same day
  around the clock, otherwise the next imaging day's opening; BS3 and
  `book-requests` read so, and T113's witness is "urgent requests booked
  after their machine's first free slot".** As recommended: the MRIs and
  the gamma camera keep the imaging day. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#11-vet-bookings-sync-the-agenda-and-the-record)
  (BS3, T113); master spec 9.4; [build plan](archive/v0.5/build-plan.md) chunk 21.
- **D425 (2026-11-04, the driver, closes O240): The load's absences
  that start after T0, `absent` ones included, stay recorded before T0;
  a false-alarm line answers "sick leave booked weeks ahead".** As
  recommended: the kind only, no reason. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#5-false-alarm-material).
- **D426 (2026-11-04, the driver, closes O241): The desk's 422 for a
  closed account's owner is kept, about one desk call in thirty; a
  false-alarm line answers it by the account's `status`.** As
  recommended. Now in:
  [vet-portal](versions/v0.5/vet-portal-domain.md#false-alarm-material).
- **D427 (2026-11-04, the driver, closes O242): T274's witness is about
  one withdrawal every five or six days, the rate as built, and it is
  fixed on `portal_keeper_granted` (the withdrawal) or
  `portal_animals_scope` (the keeping's end).** As recommended; the
  traffic unchanged. Now in:
  [vet-portal](versions/v0.5/vet-portal-domain.md#3-who-sees-what-the-policies) (T274).
- **D428 (2026-11-04, the driver, chunk 16 as built): The access model's
  closed account: login `401`; a reset asked for its address `202`, as
  any address's, sending nothing (no account enumeration); its
  unsubscribe link `404`, as an unknown key's.** A text correction to
  what `portal_request_reset` and `portal_unsubscribe` do. Now in:
  [access model](versions/v0.5/access-model.md) 9.3.
- **D431 (2026-11-09, capture W4's correction 1, the wave driver): Chunk
  32 is inserted into wave 4, for a `coding-executor`: a purpose's
  `source_<w>` and `runner_<w>` parts, `pg_cron` jobs on a database part
  with no runner, and `load-data`'s step (2c) (D432); split 32a (2c),
  32b the parts.** Purposes 5, 6, 9, 14 to 16 have no form without it,
  and folding it into chunk 17 would serialise the wave behind its
  largest chunk. Now in: [build plan](archive/v0.5/build-plan.md) chunk 32, waves, chunks 17 to 21.
- **D432 (2026-11-09, capture W4 item 7, the wave driver): `gm_check`
  reads a table with row security through a `gm_check_read` policy
  (`FOR SELECT TO gm_check USING (true)`, commented "DO NOT TAMPER")
  that `load-data` adds at step (2c); a check reading such a table first
  finds it there, else exits 2, "cannot judge"; `postgres`' player notes
  name it.** Option A: v0.4's way for `cron.job`, within access model 8;
  `BYPASSRLS` is T272's witness. Nothing players see or may do changes
  in kind, so not the owner's; reported to him as information. Closes
  O243. Now in: [access model](versions/v0.5/access-model.md) 8;
  [vet-portal](versions/v0.5/vet-portal-domain.md#who-sees-what-row-level-security-ruled-d320);
  [build plan](archive/v0.5/build-plan.md) chunk 32.
- **D433 (2026-11-09, capture W4's correction 2): Chunk 17 also refuses
  a domain's `cron.sql` job naming a database its entry's `at:` does not
  place, corrects vet-machinery's and vet-portal's `cron.sql` headers,
  and adds `third_parties[].credentials:` with `partners.md`'s
  `{{credential:<name>}}` placeholders, filled by the bastion and
  checked by the loader (W4 items 1, 2).** Caught at the format check,
  not at the `cron.sql` step; D365's handed-over credentials need a
  name. Now in: [build plan](archive/v0.5/build-plan.md) chunk 17.
- **D434 (2026-11-09, capture W4's correction 5): D335's register
  requirement binds played scenarios: a scenario whose id starts
  `fixture-` is exempt, and a fixture with a register is checked in
  full.** A test fixture is never handed to players, and O219's
  recommendation meant the composed scenarios played. Now in:
  [master spec](versions/v0.5/master-spec.md) 13.2;
  [data-register-handout.md](versions/v0.5/data-register-handout.md#3-generation-the-gms-data-register-skill-d331);
  formats.md "Scenario" with G18; [build plan](archive/v0.5/build-plan.md) chunk 17.
- **D435 (2026-11-09, capture W4's corrections 3, 4, 6, 7): Wave 4's
  fixtures and shared material: chunk 19 adds vet-core's
  `partners/centres` to every composed fixture's `left_out:` (a shared
  list); chunk 18 adds `test_purposes.py` (the `ops` block and
  `office.sql` byte-identical); `office`'s DDL creates `office`,
  `office_jobs`, `office_reader` only; the send-outs, vault and portal
  fixtures as W4 items 3 and 6.** Now in: [build plan](archive/v0.5/build-plan.md) chunks 18 to 21, "Workflow deltas".
- **D436 (2026-11-09, capture W4's correction 9): A monthly, yearly or
  windowed job runs daily, or every 15 minutes, at its hour and acts only
  on its own date or window, read as the customer's local time; on other
  runs it writes neither output nor run row.** The scheduler's cron
  subset has no day of month or month, and a shifted hour may cross
  midnight. Now in: [master spec](versions/v0.5/master-spec.md) 12.2
  ("Cadences", purposes 3, 7 to 10, 12).
- **D437 (2026-11-09, capture W4's correction 8): Gate G18: after wave
  4's gate, `spec-writer` writes wave 4's format items as built into
  formats.md and master spec 5, 6 and 12.1, blocking release gate item
  6.** As G16 and G17. Now in: [build plan](archive/v0.5/build-plan.md) "Gates", release gate item 6.
- **D438 (2026-11-09, chunk 19's stop, gaps 1, 2 and 4 and the sweep):
  The purpose loader takes four forms the spec already uses: invariant
  ids `[A-Z]{1,2}[0-9]+` (12.2's LO1 to MS6, v0.4's R1); `data_moved.reads`
  in the scenario's classification-key form (an `ops` column,
  `clinic.ops.notifications.payload`); an HTTP connection `<part>_<w>`
  per hostname of a part reached under several (`partner_central`),
  checked as its part; `material/api/<node>/api.yaml` beside `routes/`
  and `db/`.** W4 item 0's table stands: a domain's `producers/api/`
  layout carries `api.yaml`, and the endpoint's hosts, credential and
  role have no other home; no render change. Now in:
  [master spec](versions/v0.5/master-spec.md) 12.1;
  [build plan](archive/v0.5/build-plan.md) chunk 33; formats.md with G18.
- **D439 (2026-11-09, chunk 19's stop): Chunk 33 is inserted into wave
  4, for a `coding-executor`, building D438 in `model.py`'s purpose
  checks, their tests and the scenario-format skill, cut once chunk 17
  has merged; it merges before the format checks of chunks 18 to 21.** Every
  wave-4 purpose fails on the ids alone, so one fix ahead of the four,
  not four stops. Now in: [build plan](archive/v0.5/build-plan.md)
  chunk 33, waves, chunks 17 to 21.
- **D440 (2026-11-09, chunk 19's gap 3): Purpose 4's inbound trip is
  judged end to end by EX2, reworded from the centre's side (each
  request recorded at once, its answer and report posted within 10
  minutes of the vets'); EX5 stays the outbound trip's. A round trip
  names one end-to-end invariant per `round_trips:` entry.** The loader's
  count and 12.1's "two, one each way" agree; the triggers-only EX2 saw
  nothing of T54's lost inbound requests. Rejected: one per purpose (an
  inbound fault then judged by nothing). Now in:
  [master spec](versions/v0.5/master-spec.md) 12.1, 12.2 purpose 4;
  [clinic-purposes](versions/v0.5/clinic-purposes.md) 8;
  [clinic-traps](versions/v0.5/clinic-traps.md) T54.
- **D441 (2026-11-09, chunk 19's gap 5 and the sweep): The roles table
  lists each purpose's column grants by number, a shared role holding
  their union, and defines `ops.*`; it gains purposes 4's and 5's reads
  for `vet_interfaces` and `vet_exchange` as chunk 19 granted them,
  `ops.notifications` for `vet_reports` and `lab_reports`, and
  `mach_archive`'s settings (W4 item 6).** Now in:
  [clinic-purposes](versions/v0.5/clinic-purposes.md) "The roles the
  purposes add".
- **D442 (2026-11-09, chunk 21's pause): The roles table gains chunk
  21's four grants (the slot function's and release trigger's reads and
  writes as invoker, purpose 11's and 13's core reads, `mach_orders`'
  procedure codes and join ids); the vault fixture sets `window_days` 0 so
  the loaded last full day ships at T0 21:55.** Each checked on the
  schemas. Now in: [clinic-purposes](versions/v0.5/clinic-purposes.md)
  "The roles the purposes add"; vet-scheduling 11, vet-machinery 13 and
  Testing, master spec 9.4, 9.6; [build plan](archive/v0.5/build-plan.md) chunk 21.
- **D443 (2026-11-10, the owner, gate G11.2): Debian `curl`
  8.14.1-2+deb13u7 goes into `bastion` 0.5.0 without a version bump
  (0.5.0 is unreleased); its trixie-unfixed client-side issues, and those
  of the seven images carrying the same build, are accepted until
  2027-02-01 or the next trixie `curl` security upload, whichever comes
  first.** As recommended: the players' HTTP client for the credentials
  `partners.md` hands over (access model 4). Now in:
  [master spec](versions/v0.5/master-spec.md) 5, 6.7, 7.3;
  [build plan](archive/v0.5/build-plan.md) G11.2; `.tech` (the advisor's).
- **D444 (2026-11-10, the owner, the security advisor's triage of
  2026-11-09, as recommended): the 50 `.tech` `[[ignore]]` entries hold
  until 2027-05-01; python3.13 is upgraded on armenelos (the owner's
  command); c-ares joins `.tech` with its ignore; the 19 orphan items
  leave `SECURITY_TODO.md`.** `.tech` is edited on `v0.5-w4` (a39f555)
  and reaches `main` with the wave. Now in:
  [build plan](archive/v0.5/build-plan.md) "Settled with the owner".
- **D445 (2026-11-10, the owner, the same triage): A brick's tag names
  one Debian package list: a rebuild that changes an image's content (a
  Debian package version, a pinned binary's release) takes the next
  patch version, with its re-pins in the same wave; a rebuild keeps its
  tag only for an identical `dpkg-query` list.** Read with master spec
  6.7 (a change to an unreleased version folds into it), as the owner
  kept `bastion` 0.5.0 for `curl` the same day (D443); `grafana` 0.3.0's
  case is O247. Now in: [master spec](versions/v0.5/master-spec.md) 6.7,
  7.5; [build plan](archive/v0.5/build-plan.md) "Workflow deltas"; `.tech`'s header.
- **D446 (2026-11-10, the owner, the same triage): Prometheus moves to
  its 3.16.x line in a later wave of v0.5, never wave 4.** For
  GO-2026-6865 (klauspost/compress) and grpc GHSA-2v4p-qf9q-27wj, fixed
  on 3.16 only and not reachable as run (`.tech`); the placement is
  D448's. Now in: [master spec](versions/v0.5/master-spec.md) 6.7, 7.5.
- **D447 (2026-11-10, the owner, wave 4's gate, option A): `pms`'s
  `sched.bookings.arrive` stamps an arrival when it records it: it takes
  a `booked` booking whose hashed arrival moment (`starts_at` + δ) has
  passed and sets `arrived_at = now()`; BS1's 2-minute rule stands.** The
  back-dated stamp (`least(now(), starts_at + δ)`) made a correct
  check-in of a booking reached late in the 10:00 burst look late, a
  false BS1 verdict in a game. Gate fix 7840cb8. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#the-producer-profiles-step-6)
  (`sched.bookings.arrive`); [master spec](versions/v0.5/master-spec.md) 9.4.
- **D448 (2026-11-10, spec-writer, placing D446 and the plugin): Chunk 34
  is inserted into wave 5, not the release gate: `grafana` 0.3.0 with its
  bundled Prometheus data-source plugin at 13.2.5 or later (brotli
  GO-2026-6888), from the first Grafana release bundling it, else the
  catalogue plugin sha256-pinned; `prometheus` 0.2.1 on Prometheus
  3.16.x, its SBOMs, stack test and re-pins in one commit; preflights
  G11.3 and G11.4 before its branch, post-change checks before wave 5's
  gate.** The release gate verifies and never builds; D446 names a wave;
  chunk 27 must pin the versions it ships. Now in:
  [build plan](archive/v0.5/build-plan.md) chunk 34, "Gates", "Waves";
  [master spec](versions/v0.5/master-spec.md) 5, 6.7, 7.5.
- **D449 (2026-11-10, wave 4's gate, D447's consequence): T115's variant
  holds `sched.bookings.arrive`'s transaction 30 to 90 seconds after its
  stamp (the desk printing its label inside it), a timeline change; its
  witness is the arrivals so held past a check-in run's start.** With
  arrivals stamped when recorded, a watermark from the run's start
  misses nothing unheld. T115 is in neither the test selection nor a
  wave 5 chunk. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#traps-step-8) T115.
- **D450 (2026-11-10, chunk 20's reading, as the driver recommended):
  On-call shifts take no part in the 11 hours' rest comparison (WT2,
  `feed-working-time`); their call-outs count in the hours (rule 3).** A
  call-out is clocked as the whole on-call span, so counting it gives
  about 494 breaches a year against the rota's none, a false trap; T125
  still overstates hours. Now in:
  [vet-scheduling](versions/v0.5/vet-scheduling-domain.md#12-vet-working-time-the-working-time-record)
  (WT2, false alarms); [master spec](versions/v0.5/master-spec.md) 9.4, 12.2.
- **D451 (2026-11-10, chunk 20's data finding): Chunk 35 is inserted
  into wave 5 for a `coding-executor`: vet-core's load sizes each
  medicine batch's receipt to at least the history's administrations
  and dispensings from it, plus a month of its average use for a batch
  in date at `load_epoch`; every planted partner reference takes its
  stub's live form (`AMU<year>-NNNN`, `HO<YYYYMM>-NNNN`).** 938 of 1 260
  planted controlled balances closed negative, and the planted
  references read unlike the live ones: two false traps in reports the
  players read. D278 stands: receipts at load only. Now in:
  [vet-core](versions/v0.5/vet-core-domain.md#entities);
  [purposes](versions/v0.5/clinic-purposes.md) 11 to 13;
  [build plan](archive/v0.5/build-plan.md) chunk 35.
- **D452 (2026-11-10, chunk 18, documents to as-built): `lab_dispatch`
  also reads `lab_settings (utc_offset_hours)`; PR1 judges each delivery
  a release made due (an interim, the final, an amendment); PR3 judges
  each attempt at its posting; SO1 the days whose 16:00 run follows the
  judged moment; SO4 the first release round after the answer; SO3 the
  catalogue fields the stub keeps, so T49's variant uses one.** Within
  the approved rules. Now in: [purposes](versions/v0.5/clinic-purposes.md)
  6, 7 and the roles table; [traps](versions/v0.5/clinic-traps.md) T49;
  [master spec](versions/v0.5/master-spec.md) 12.2.
- **D453 (2026-11-10, chunk 19, documents to as-built): ND3's keeper,
  from the lab, is the keeper's name and the practice's account (vet-lab
  holds no address); ND4 is judged at the quarter hour at or after the
  deadline, 3 minutes later; EX5 at a working day's 09:00 chase plus 15
  minutes; EX1 to EX4 run in shell with their verdict in SQL.** Within
  the approved rules. Now in: [purposes](versions/v0.5/clinic-purposes.md) 8, 9.
- **D454 (2026-11-10, chunk 20, documents to as-built): a `code` check
  runs the job's loaded SQL on the last planted period; AM4's run tries
  three times, then sets `escalated_at`; the balances are signed by the
  lowest-id vet employed; the brackets are 3, 5, 10 and 15 % from 0, 200,
  400 and 600; a statement subtracts voids of stated charges only;
  `monthly_figures` is month × section × measure (about 684 rows), its
  turnaround the median of the days' medians.** Within the approved rules;
  the sizes measured. Now in: [purposes](versions/v0.5/clinic-purposes.md)
  11 to 14, "`office` at T0"; [formats](formats.md) "Purpose definition".
- **D455 (2026-11-10, chunk 21, documents to as-built): `vet_portal_sync`
  reads `animals.registered_at`, `consultations.state` and `sections (id,
  kind)`, `lab_release` `lab_samples (id, collected_at)`,
  `portal_dispatch` accounts' id, owner and display name;
  `send-messages` stops a queued row whose basis changed (`failed_at`,
  its reason, no incident); RL2, RL3, RL5 and MS5 judge a satisfied
  trigger at once; RL5 reads closed accounts touched since their closure
  and the judged moment; the vault fixture holds `records`, not
  `equipment`, its T0 a minute of 21:00–21:59 local.** Within the approved
  rules. Now in: [vet-portal](versions/v0.5/vet-portal-domain.md#vet-portal-release-the-copies-and-the-release-gate)
  15, 16 and its roles; [purposes](versions/v0.5/clinic-purposes.md#the-roles-the-purposes-add);
  [vet-machinery](versions/v0.5/vet-machinery-domain.md#testing-in-v05-d314).
- **D456 (2026-11-10, wave 4's findings for wave 5): chunk 22's fixed s1
  reading releases the urgent test itself when `lis` has not within 5
  minutes; chunk 24's fixture gives `backoffice` the access model's
  `fixable-file`, so s3's fix and the moved feeders are the players';
  chunk 26's scenario document lists a `pg_cron` job a purpose's `ddl:`
  schedules; chunk 27's story names the vet signing the balances, and
  purpose 5's `clinic-reports` targets the standby as purpose 7's.**
  `lis` released no urgent order within 10 minutes at intensity 4 in
  chunk 18's runs; time is placed, never waited for. Now in:
  [build plan](archive/v0.5/build-plan.md) chunks 22, 24, 26, 27.
- **D457 (2026-11-10, spec-writer): Wave 5 holds eight chunks, 22 to 27,
  34 and 35, two past the model's six; 34 and 35 start first, a chunk
  merging after 34 re-pins its own new fixtures to `prometheus` 0.2.1,
  chunk 24's fixture runs once 35 has merged, and chunk 27 is cut once
  all seven have.** 34 is the owner's placement (D446), 35 a fix-sized
  data correction chunks 24 and 27 read; v0.5 has no later wave. Now in:
  [build plan](archive/v0.5/build-plan.md) "Waves", chunks 34, 35.
- **D458 (2026-11-10, owner; recorded by the wave driver): O247 closed: `grafana` 0.3.0 is rebuilt for the plugin update, not bumped to 0.3.1; the patch-bump rule (D445) binds released versions, as `bastion` 0.5.0 kept its tag for `curl` (D443). The owner also approved the advisor's 20 curl NVD false-positive ignores (Debian backports deb13u1-u7, one not affecting Debian) and CVE-2026-123158's (OpenSSH, musl libc without PAM only), until 2027-05-01.** Now in: [build plan](archive/v0.5/build-plan.md) "Settled with the owner", chunk 34; `.tech`.
- **D459 (2026-11-12, wave 5's preflight correction 1, accepted by the
  wave driver): chunk 36 builds three fault forms: a `state` script run
  on another node (`{script, on: <parameter>}`), `injection.kind:
  topology` with `option_absent`, and a false alarm (`covers: []`,
  `report`, the answer key's `false_alarms:`, in no score or cap).** s3,
  s10 and fa had no form in the loader. Rejected: the forms split into
  chunks 22 and 24, serialising three chunks. Now in:
  [build plan](archive/v0.5/build-plan.md) chunk 36, gate G19.
- **D460 (2026-11-12, wave 5's preflight correction 1, accepted by the
  wave driver): wave 5 holds nine chunks; 36 takes the first free slot,
  and only 22's fa issue, 24's s3, 25's s10 and 26's false-alarm and
  `inject` lines wait for its merge.** A fix-sized loader gap; v0.5 has
  no later wave. Now in: [build plan](archive/v0.5/build-plan.md)
  "Waves", workflow deltas.
- **D461 (2026-11-12, wave 5's preflight correction 2, accepted by the
  wave driver): s8's witness in a game is the 00:30 feeder; its short
  test reads the delay in effect, WAL received and not replayed, and
  late entries the test records after T0; the class unchanged.** The
  01:30 feeder's day is complete under a one-hour delay, and the lag
  reads an hour only after an hour. Now in:
  [master spec](versions/v0.5/master-spec.md) 17.2, 17.3, 18.3;
  [test selection](versions/v0.5/clinic-test-selection.md); build plan
  chunk 24.
- **D462 (2026-11-12, wave 5's preflight correction 3, accepted by the
  wave driver): s10 is resolved by *report* or *propose*; fixed, the
  option's role created on `lab` with the game's monitoring password,
  the GM applying the accepted proposal.** Players read no service
  credential, and the option chosen later creates nothing on an
  existing `pgdata`. Now in: [master spec](versions/v0.5/master-spec.md)
  17.3; [test selection](versions/v0.5/clinic-test-selection.md);
  build plan chunk 25.
- **D463 (2026-11-12, wave 5's preflight correction 4, accepted by the
  wave driver): s5 is planted a few hours before T0, so former owners
  have had hours, not days, to look; class M unchanged.** The portal
  copies every ownership, so every past sale is exposed, not only the
  day's. Now in: [master spec](versions/v0.5/master-spec.md) 17.2;
  [test selection](versions/v0.5/clinic-test-selection.md);
  [vet-portal](versions/v0.5/vet-portal-domain.md).
- **D464 (2026-11-12, wave 5's preflight correction 5, accepted by the
  wave driver): chunks 22 to 26 and the reports fixture's texts to the
  code and capture W5: T0 about 00:10 any day; chunk 23's register on
  the archive fixture; `fixture-lab` without a domain or Prometheus;
  the `planted/<fault-id>/` overlays; chunk 26's false alarm and
  `inject` rows.** Now in: [build plan](archive/v0.5/build-plan.md)
  chunks 22 to 26; [master spec](versions/v0.5/master-spec.md) 17.3,
  18.2; [test selection](versions/v0.5/clinic-test-selection.md).
- **D465 (2026-11-12, a loader gap chunk 23 found, decided by the wave
  driver): the true register digests `composition.yaml` without its
  top-level `coherence:` key and the indented lines under it, the span
  `load-data` rewrites; every other input's digest unchanged.** The
  coherence result is setup state that never feeds the register, and
  its rewrite left every scenario with a register stale after
  `load-data`. Rejected: the result in `state.yaml` only (it changes the
  format and the GM's composition record). Now in:
  [build plan](archive/v0.5/build-plan.md) chunk 37 and G19.
- **D466 (2026-11-12, chunk 22's finding, before chunk 27; spec-writer,
  the GM's selection): `aldermoor-centre` leaves s4 out, nine faults and
  the false alarm within the owner's budget (one dramatic, two on the
  verge, six minor); s4 stays built, proven on the orders fixture, for a
  scenario that plants the slowness.** Nothing in the clinic answers a
  post after the runner's ten seconds while each `lab-api` statement
  waits under its five, so s4's check reads too soon at the hand-over (a
  failure, v0.4 12.2) and after any fix. Rejected: planted slowness (a
  lock or sleep in the customer's own lab, itself a finding, no chunk
  building it); 3 accepted at the hand-over (an owner's rule change, the
  fix still never judged). Now in: [master spec](versions/v0.5/master-spec.md)
  18.3, 18.4; [test selection](versions/v0.5/clinic-test-selection.md);
  [build plan](archive/v0.5/build-plan.md) chunk 27, G13.
- **D467 (2026-11-12, chunk 35's finding; spec-writer): the partner
  stubs' references restarting at 0001 after the planted AMU and HO
  series are accepted in v0.5, a known limit; seeding the stubs' counters
  waits until the clinic is first played (O249).** No v0.5 run plays the
  clinic, the stubs number a live post only on the 1st to 5th at 05:00
  (HO) or on 15 January (AMU), and the fix spans two purposes' stubs and
  their fixtures. Now in: [build plan](archive/v0.5/build-plan.md)
  release gate item 12; [open questions](open-questions.md) O249.
- **D468 (2026-11-12, chunk 26's choice, recorded by spec-writer): the
  scenario document never shows the coherence result: setup state, as
  for the register's digest (D465), so a setup never makes the README
  stale.** Now in: [build plan](archive/v0.5/build-plan.md) G19
  (formats.md, "Composing domains").
- **D469 (2026-11-12, chunk 27's stop; spec-writer): the customer's
  governance judges its own estate: no `governance:` location or outbox
  on a third party's node (refused), no register `where` naming one, no
  governance walk of one; data sent a partner is judged as a flow (G4,
  `shared_with`).** 10.1 judges the customer's side, and `partners-db`
  rejects `gm_check` from the network (D383): every walk there reads 2.
  Rejected: dropping the location alone (still 2); exempting it from
  coverage (a location the customer does not hold). Now in: [master spec](versions/v0.5/master-spec.md)
  10.1, 10.2, 13.2; [build plan](archive/v0.5/build-plan.md) chunks 27, 38, G19.
- **D471 (2026-11-12, the owner, on O250 as proposed): the governance
  check set's gaps on the whole clinic are a v0.5 known limit, fixed
  when a scenario first calls the set there: G1 reads a standby as a
  location of its own, G3 stops at a transformer's HTTP connection
  ("cannot judge").** No v0.5 gate run or clinic check in play reaches
  either; release gate item 3 stays on chunk 27's load-only fixture
  (D469). Rejected: a second small chunk in wave 5. Now in:
  [master spec](versions/v0.5/master-spec.md) 18.4, 20.3;
  [build plan](archive/v0.5/build-plan.md) release gate items 3, 12.
- **D472 (2026-11-12, wave 5's gate finding; spec-writer): the scenario
  document shows a round-trip fault instance's `backlog:` (`what`,
  `cleanup`) with that instance's answer, as it shows every other
  answer-key item.** The document renders the answer key for review and a
  GM's restart (master spec 6.3: the backlog is in it, a creditable
  consequence); the template had no slot, so `aldermoor-centre`'s s1 lost
  it. Now in: [formats.md](formats.md) "Scenario";
  [master spec](versions/v0.5/master-spec.md) 6.3, 15;
  [build plan](archive/v0.5/build-plan.md) release gate item 6.
- **D473 (2026-11-12, wave 5's gate fix `70e0e5d`, recorded by
  spec-writer): the portal's messages carry the address, template, the
  recipient's name, the animal's name, a reminder's due date and a link;
  the flow `to: messaging` declares `address` and the payload keys
  `template`, `name`, `animal`, `due_on`, `link`, not `animal_name`.**
  The derivation and MS4 write them so (chunk 16); the approved text
  named the animal only. Now in: [master spec](versions/v0.5/master-spec.md)
  9.7 rule 7, 12.2; [vet-portal](versions/v0.5/vet-portal-domain.md).
- **D474 (2026-11-14, spec-writer, the release gate's gap; ISS-004): The
  partners' database admits by role and password, not by address; the
  access model's gap is verified, no longer "the build's to verify".**
  Chunk 11 measured the `samenet` form; the guarantee rests on the
  partners' passwords mounted on their nodes only. Admission by address
  is v0.6's question if wanted. Now in: [access model](versions/v0.5/access-model.md)
  13; [master spec](versions/v0.5/master-spec.md) 10.2.
- **D475 (2026-11-14, the owner, "ok" to the release gate's report;
  relayed by the top-level session): G15 cleared; v0.5 released.** The
  gate stands as run on `v0.5-g13`, not `v0.5-w5`, wave 5 having merged
  on his word; its fixes (`0118c90`, `2e34f44`, `2ea21f8` with
  `d53a12d`) are within settled intent. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#release-notes).
- **D476 (2026-11-14, the owner's direction, relayed by the top-level
  session): G13's findings 1 and 4 are v0.5 known limits, filed as
  ISS-001 and ISS-002.** The loader's check of a `seed-file` fault's
  lines is v0.6's (O269); the clinic's setup time and the vault's
  refusals before T0 are v1.0 gating's setup (O270). Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#known-limits);
  [versions/README.md](versions/README.md#v10-gating).
