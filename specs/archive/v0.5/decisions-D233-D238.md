> **Archived 2026-11-14.** v0.5 closed (released at its release gate, G15 cleared by the owner on 2026-11-14, merged into `main`); entries D233 to D238 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan archived in the same pass were repaired to its archived path (`archive/v0.5/build-plan.md`), still written from `specs/`.

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
