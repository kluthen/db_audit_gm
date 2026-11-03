# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived, verbatim, with where each one now lives in its milestone's
README:

- D1–D54 (v0.1):
  [archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md),
  mapped in [archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
- D55–D106 (v0.2):
  [archive/v0.2/decisions-D55-D106.md](archive/v0.2/decisions-D55-D106.md),
  mapped in [archive/v0.2/README.md](archive/v0.2/README.md#where-it-now-lives).
- D108–D112 and D114–D189 (v0.3):
  [archive/v0.3/decisions-D108-D112.md](archive/v0.3/decisions-D108-D112.md)
  and [archive/v0.3/decisions-D114-D189.md](archive/v0.3/decisions-D114-D189.md),
  mapped in [archive/v0.3/README.md](archive/v0.3/README.md#where-it-now-lives).
- D190–D191, D193–D195, D197–D200, D202–D231, D239–D247, D252–D258,
  D281–D284, D305 and D310–D313 (v0.4), one file per range in
  [archive/v0.4/](archive/v0.4/README.md#archived-files), mapped in
  [archive/v0.4/README.md](archive/v0.4/README.md#where-it-now-lives).

Archived IDs keep their meaning and are cited as they are. D107 and D113
stay live: rulings still to be applied in v0.5. The rest is v0.5's: D192,
D196 and D201, its scope set while v0.4 was drafted, then its drafting
from D233 on. Take the next number from `doc-ids`; no ID is reused.

- **D107 (2026-10-21, owner direction, relayed by the wave driver): Brick
  options are a v0.5 topic; v0.2 stays as built.** The `postgres` brick
  will offer optional elements (PostGIS, TimescaleDB, pgBadger,
  replication modules...), each documented and added to a scenario when
  appropriate; v0.5 improves and extends the bricks. Design open: O79,
  O80. Now in: [versions/v0.5/README.md](versions/v0.5/README.md).
- **D113 (2026-10-22, owner ruling at the v0.2 release close; RG-5): The
  `monitoring` role stays in every postgres game until v0.5.** The owner:
  "monitoring isn't mandatory in any game (highly suspect if there isn't
  any of course, but it remains a valid game)", then "Keep, move to
  v0.5". Making the role conditional on the game having monitoring is a
  brick improvement, with O79. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md) "In scope",
  [versions/v0.2/README.md](versions/v0.2/README.md) "Known issues".
- **D192 (2026-10-28, owner direction, relayed by the lead session): v0.5
  brings business domains:** a reusable catalogue unit (working name) of
  a business data model, producer profiles, common scheduler scripts and
  input types, and fitting purposes; a scenario is a domain, a size,
  bricks, purposes and faults. v0.4 ships one, the shop, structured so
  more can be added. Open: O111–O114; O108, O47 revised. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **D196 (2026-10-30, owner input, relayed by the wave driver): The
  veterinary clinic franchise is a v0.5 domain candidate,** the flagship
  of the regulated domains; v0.4 only borrows its strict reporting and
  its data classes as test cases, scope unchanged. Open: O126, O127;
  O112 revised. Now in: [versions/v0.5/README.md](versions/v0.5/README.md)
  "The veterinary clinic".
- **D201 (2026-10-30, owner idea, relayed by the coordinator; placed in
  v0.5 by the owner): Round trips, an acknowledgement as an inbound flow
  that the setup waits on and that drives further processes, are v0.5's;**
  v0.4's P5 only records and checks acknowledgements and opens an
  incident. Open: O128. Now in: [versions/v0.5/README.md](versions/v0.5/README.md)
  "Round trips"; [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md) P5.
- **D233 (2026-10-31, owner direction, relayed by the coordinator): v0.5
  centres on domain definition, the veterinary clinic franchise (D196)
  its worked example; tools unrelated to the clinic move later
  ("probably v1.0+"), bastion-related items unrelated to it to v0.6.**
  The owner will help define the clinic's bricks, faults, topology and
  configurations later. Every earlier v0.5 item sorted, the judgment
  calls proposed (O137). Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#sorting-d233),
  [versions/v0.6/README.md](versions/v0.6/README.md#the-setups-entry-point-d224),
  [versions/README.md](versions/README.md#deferred-from-v05-d233-d237).
- **D234 (2026-10-31, owner direction, relayed by the coordinator): A
  collection of real incident reports (post-mortems, retex) begins in
  v0.5, in `post_mortem/` at the repository's root, each entry with the
  source's stack and topology, symptoms, diagnosis, resolution and a hard
  link; not bound to faults yet.** Intended later use: an end-of-game
  handout, a replicated main culprit with the real failure's
  explanation. Open: O138. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-post-mortem-collection-d234).
- **D235 (2026-10-31, owner direction, relayed by the coordinator): A
  domain is defined through a procedure, what goes in and what does not;
  whether domains beyond the clinic's join v0.5 waits until the
  procedure shows what defining one costs.** The owner: "the clinic will
  probably spawn multiple such domain". Drafted, not approved (O139);
  O112 deferred, O126 and O127 narrowed. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md).
- **D236 (2026-10-31, owner direction, relayed by the coordinator): Brick
  options (D107; O79, O80) stay in v0.5, tied to the clinic, and are
  reviewed against what its parts need.** The owner: "brick options may
  come in with the clinic scenario honestly. We need to review this as
  well." Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md).
- **D237 (2026-10-31, owner direction, relayed by the coordinator):
  Bluebox and the other datasets (O53, O54) move to a later version, not
  set; Bluebox, "quite akin to a domain", is a later domain candidate
  brought in through the procedure, its dataset filling the data
  model.** Now in: [versions/README.md](versions/README.md#deferred-from-v05-d233-d237),
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 2.
- **D238 (2026-10-31, owner correction, relayed by the coordinator):
  pgwatch and pgCluu stay in v0.5 as the clinic's monitoring, and
  "related to the clinic" is judged against what a setting that complex
  plausibly needs, monitoring breadth included; amends D233's tool
  rule.** The owner: "they are monitoring tooling that are required in
  such complex settings." Nagios-style health tools stay with them; the
  other tools re-sorted. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#sorting-d233),
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md).
- **D248 (2026-10-31, owner ruling on spec-writer's scope review,
  relayed by the coordinator: "accept all recomendations for v0.5"):
  v0.5's sorting stands with every proposed row as proposed, and v0.5
  ships a scenario using the clinic's domains.** Scenario generation
  comes in v1.0. Closes O137 and O47. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#sorting-d233),
  [versions/README.md](versions/README.md#deferred-from-v05-d233-d237),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **D249 (2026-10-31, owner ruling, same review): The clinic splits into
  the procedure's seven domains, revised once `vet-core` is defined;
  domains compose as a core and parts one level deep, flows between
  parts as purposes, keys by id without foreign keys to the core, a part
  taken only with its core, tried first on `vet-core` and `vet-lab`.**
  The four format changes are built in one chunk; the procedure becomes
  a skill after two or three domains. Closes O126; O111 and O139
  narrowed. Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 4, 6, 8.
- **D250 (2026-10-31, owner ruling, same review): For the clinic,
  `postgres` keeps plain partitioned tables before any TimescaleDB,
  offers replication as a standby mode, has TLS always available and
  turned on by the seed, and makes only the `monitoring` role an option
  of today's four elements.** O79 and O118 narrowed; pgaudit's form
  stays open. Now in:
  [versions/v0.5/brick-options-review.md](versions/v0.5/brick-options-review.md).
- **D251 (2026-10-31, owner ruling, same review): Post-mortems are bound
  to faults in a later version; the end-of-game handout comes after the
  final answer and summarises and links its source, never copying it.**
  O138 narrowed. Now in:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-post-mortem-collection-d234).
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
