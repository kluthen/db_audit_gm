> **Archived 2026-11-14.** v0.5 closed (released at its release gate, G15 cleared by the owner on 2026-11-14, merged into `main`); entries D260 to D280 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan archived in the same pass were repaired to its archived path (`archive/v0.5/build-plan.md`), still written from `specs/`.

- **D260 (2026-10-31, owner ruling on spec-writer's recommendations,
  relayed by the coordinator: "agreed to your recomendations"): The
  domain procedure is approved as drafted: what a domain holds and
  leaves out, the steps and who takes part, done and its checklist, the
  effort estimate.** With D249, the whole procedure is settled. Closes
  O139. Now in: [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 1, 2, 3, 7.
- **D261 (2026-10-31, owner ruling, same recommendations): pgaudit is
  not an option: it is always available in `postgres` and turned on by
  the seed, as TLS is (D250), its settings in the seed so their removal
  can be a fault.** The options model is left serving the `monitoring`
  role alone. Closes O118, TLS ruled by D250; O79 narrowed. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md#the-owners-rulings-d250-d261-d262).
- **D262 (2026-10-31, owner ruling, same recommendations): Options are
  for `postgres` only, unless one of the clinic's parts calls for
  another brick.** `postgres` is the only brick the clinic is known to
  need them on; a part that calls for one raises its own question.
  Closes O80. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md#the-owners-rulings-d250-d261-d262).
- **D263 (2026-11-01, owner ruling on the lead's proposal, relayed by the
  coordinator): "Size" becomes a domain's scale, on three axes
  (population, history, throughput); one domain covers several setups
  as variants, short manifests of parts, scale, purposes and tags from a
  fixed vocabulary; large setups show through structure, not volume;
  v0.5 builds one variant per domain.** The owner: "size isnt sufficient
  to describe whatever it is." Closes O114. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 9.
- **D264 (2026-11-01, owner ruling, "agreed" to the lead's proposal,
  relayed by the coordinator): A `gmctl compose` script merges a node's
  fragments at design time, built with the format changes:** layers
  domain default < variant profile < scenario, a higher layer winning
  silently and the merge report recording it; a profile-to-profile
  conflict stops the merge, its resolution in the scenario's
  `merge.yaml`; part prefixes, provenance comments, duplicate keys
  refused. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 1.
- **D265 (2026-11-01, owner ruling, same proposal): Weekly, monthly and
  yearly reports are part of the game:** past periods planted by the
  load, unseen in logs and pgwatch; if the GM plants faults there, at
  least one shows a witness within the aging; one periodic run may be
  scheduled in the aging; every report runs on demand for a period;
  calibrated per node, never killed for memory. Replaces D199 for
  domains. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 4.
- **D266 (2026-11-01, owner ruling, same proposal): `vet-core` is the
  system of record for owners and animals,** reached through a lookup
  API or a synced reference table; natural identifiers (microchip,
  UELN and passport, ear tag) carry identity across systems and are
  fault vectors; no central id provider; an EMPI-style `vet-identity`
  part maybe later. O113 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 7,
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md).
- **D267 (2026-11-01, owner ruling, same proposal): An `api` brick on
  FastAPI serves endpoint files the GM drops in, and the scheduler gets
  an HTTP driver as its caller;** first for the core's lookup API, the
  external labs and the machinery; FastAPI and uvicorn pass a
  security-advisor dependency check before the build; message queues
  wait for a flow that needs one. Narrows D118 and D248's targets. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D268 (2026-11-01, owner ruling, same proposal): The external lab is
  a consumer-producer round trip over APIs:** the clinic POSTs an order,
  gets "accepted" with a correlation id, and the lab's stub calls back
  hours later; its faults are lost, duplicate, late or out-of-order
  callbacks, a wrong correlation id, a retry without an idempotency key;
  SQL stubs stay where no API is needed. O128 narrowed. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D269 (2026-11-01, owner ruling, relayed by the coordinator): No
  periodic report runs on demand in v0.5;** "run March's report now"
  comes later, probably v1.0+, possibly v0.6, on an instance spawned for
  the occasion. Revises D265; D117 and D131 stand. The owner: "we're
  barely begining to introduce API and stuff like that." Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 4.
- **D270 (2026-11-01, owner ruling, same message, amended the same day
  by his addendum): An `api` node in the players' scope only answers
  requests;** producers and consumers on scheduler nodes call it. The
  one exception is a third party outside the players' scope, the
  external lab, whose callbacks initiate, still driven by its hidden
  schedule. The owner: "API layer isn't a scheduler"; then "that's out
  of player's scope." Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D271 (2026-11-01, owner ruling, same message): Players read every
  endpoint file of an `api` node and, where the scenario makes it
  fixable, edit its database side only** (queries, transactional work,
  session settings), never an endpoint's route or contract; application
  roles, a reload wrapper. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 8.
- **D272 (2026-11-01, owner direction, same message): v1.0 to v2 leans
  to DBA work with bits of devops:** reports on a spawned instance,
  major-version upgrades, hotfixes, moving providers, setting up
  replication. v0.5 is not widened. Now in:
  [versions/README.md](versions/README.md#v10-to-v2-dba-work-with-bits-of-devops-d272).
- **D273 (2026-11-01, owner ruling, "agreed" to the lead's proposal,
  relayed by the coordinator): A third party's nodes are outside the
  players' reach:** no `player` account, no route on the bastion, not in
  the starter pack; a per-node option settled with the `api` brick.
  Hiding alone would not do: a player with a shell elsewhere finds them
  on the network. v0.4's customs gateway stays as built until the
  definition says otherwise. Raises O145. Now in:
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md) 3.
- **D274 (2026-11-01, owner ruling, "agreed with your recomendations",
  relayed by the coordinator): Third parties as the draft recommends,
  but for the network:** `no-access` made real, no new key; players may
  call a partner's public interface; `partners.md`, a fifth optional
  starter-pack file, on the bastion's page; a status page with v0.6; an
  unanswering in-world support contact; v0.4's customs gateway as
  built, a purpose's `receiver` a third party from v0.5; the centres
  abroad third parties; no fix ever on the partner's side. Closes O145
  with D275. Now in:
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md).
- **D275 (2026-11-01, owner ruling, same answer; against spec-writer's
  recommendation of a network of its own): v0.5 stays on one network;
  a third party's back end is closed by its own access rules,** its
  database's `pg_hba.conf` admitting only its own nodes, its other
  services only their callers. A real lab's API is reachable from
  outside, its database is not. Separate networks wait with O12. Now in:
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md) 3.
- **D276 (2026-11-01, owner confirmation "yes", relayed by the
  coordinator): O113's remaining recommendations are ruled as written:**
  readable profiles on the trust line, no timeline, intensity or planted
  fault in a fragment; rates the variant's throughput at intensity 1.0;
  values from SQL and domain builders; a producer node per application;
  every site in the customer's zone in v0.5; a variant's profile in
  `variants/<name>/producers/`. O113 narrowed to frictions 9 and 11. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md).
- **D277 (2026-11-01, same confirmation): A fix to a periodic report's
  fault is checked without a run on demand:** inputs or feeder on the
  feeder's next run; the report's code by the sealed check reading it,
  and against the scheduled run's output if the GM placed one; planted
  past outputs stay wrong, the players recommending the rerun. Completes
  D269. Now in:
  [versions/v0.5/producer-profiles.md](versions/v0.5/producer-profiles.md) 4.
- **D278 (2026-11-01, owner answer "agreed" to the defaults the lead
  listed, relayed by the coordinator): `vet-core`'s business sketch is
  ruled with all fourteen answers as proposed:** one shared record for
  the three national centres; Aldermoor Veterinary Hospitals in an
  unnamed EU state; hospital stays, medicines and referrals in the
  core; no billing or pharmacy part in v0.5; the scale figures; the
  variant `regional-franchise`; the identifiers and a dozen mistyped
  chips. Closes O144. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-owners-answers-d278).
- **D279 (2026-11-01, owner confirmation "ok understood and agreed",
  relayed by the coordinator): The clinic's split is confirmed as
  revised, lab and imaging requests and alerts in the core;** and the
  history shows the clinic's growth, its daily volumes ramping up to
  today's live rates, not a busy season (the shop's). `clinic` holds
  `vet-core` only; the parts land where `domains:` `at:` places them.
  Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-split-step-3-confirmed-d279).
- **D280 (2026-11-01, owner confirmation "they're great", relayed by
  the coordinator): `vet-core`'s step 5 is ruled:** the classification
  as drafted and the eleven rules of its default policy, with their
  game values; the lower year totals the growth curve gives (about
  73 000 consultations, 44 000 prescriptions, 0.82 million rows) are
  accepted. Now in:
  [versions/v0.5/vet-core-domain.md](versions/v0.5/vet-core-domain.md#the-rules-as-the-owner-confirmed-them-d280).
