> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); the open-questions register's "Resolved during v0.4" paragraph, its "v0.4: purposes" section and its "v0.4: data governance" section's introduction, verbatim at this pass, and the entries of the five questions raised and closed during v0.4's build, verbatim as each last stood in the register (taken from git: the commit before the one that removed it, named under each). Only resolved IDs are here; every question still open, O111 and O136 among them, stays in the live register. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; the build plan link was repaired to its archived path, still written from `specs/`.

## Resolved during v0.4

Resolved during v0.4's drafting: O106 (D194), O110 (D195), O107 (D197), O120
(D198), O109 (D199), O121 (D200), O123 (D202), O105 (D203), O129 (D206), O131 (D207),
O132 (D211), O133 (D212). Resolved by the approval of v0.4's master
spec (D215): O104, O108, O115, O116, O117, O119, O122, O124, O125, and
O111's v0.4 part. Resolved during v0.4's build: O134 (D224), O140 (D253),
O146 (D284), O161 (D311), O162 (D312), O163 (D313).

## v0.4: purposes

Raised when the owner recast v0.4 as "bricks of why and bits of hows"
on 2026-10-28 (D190). O11, O22, O25 and O52 are revised by it. Worked
into drafts on 2026-10-30 ([versions/v0.4/](versions/v0.4/README.md#documents)):
O106 closed (D194), O110 closed (D195), O122 to O125 raised; the
owner's rulings closed O107 (D197) and O109 (D199) the same day, and his
technology direction O123 (D202) and O105 (D203), raising O129, which
his ruling on jobs on a database node closed (D206), raising O131,
which he confirmed as written (D207). O132 and O133, raised by the
consolidation, were ruled the same day (D211, D212), and the approval
of the [master spec](versions/v0.4/master-spec.md) closed O104, O108,
O122, O124 and O125 as written there (D215). O146, raised by wave 4's
capture W4, closed by the owner's ruling (D284). O161, raised by the
owner's remark beside D310, closed by his ruling (D311), which raised
O162, closed by his ruling on long-running tests (D312); O163 raised
in writing it into the plan, closed by his answer (D313).

## v0.4: data governance (introduction)

Raised when the owner added a first cut of data governance to v0.4 on
2026-10-28 (D191): data classes, their rules, a policy handed to the
players, `gm_check` definition checks. The customer's governance, in the
game's world, not the game's access model. Drafted on 2026-10-30 in
[governance.md](versions/v0.4/governance.md), tested against the
clinic's classes (D196); O120 closed by D198 (an instance of its own);
O115, O116, O117 and O119 closed by the master spec's approval, as
written there (D215). O118, held for v0.5, closed by D250 and D261
(TLS and pgaudit always available in `postgres`); O134, raised by D221,
closed by D224; O136, raised by D230, waits for a later version. O140,
raised by chunk 12, closed by D253.

## The build's questions, as they stood

From the register at f6cdc92^ (removed by f6cdc92):

- **O140** (next, v0.4) — `separation: instance`. 11.4 and 6.9 say the
  check verifies it by node, but 11.6 gives it no rule, and chunk 12's
  check set does not judge it; the loader accepts it, no v0.4 scenario
  uses it. Either (a) define the rule, every database on a node holding
  one of the class's locations being itself one of them (`postgres` and
  the templates aside), and build it into the shared set as a small
  insertion, or (b) leave it to v0.5's regulated domains, the loader
  refusing the field until then. Recommended: (a). Refs:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 6.9, 11.4,
  11.6; [versions/v0.4/wave-log.md](versions/v0.4/wave-log.md) chunk 12.

From the register at 872921f^ (removed by 872921f):

- **O146** (next, v0.4 wave 4, for the owner) — In the first scenario
  f5 (`shop_etl` expired at 09:00) makes every hourly roll-up fail from
  09:05, among them the 12:05 run f4's evidence needs after the noon
  invoicing, so f4 reads "too soon" and the hand-over check fails.
  (a) f4 expected 3 at the hand-over check, masked by f5 (recommended);
  (b) f5 planted at `handover-1h`, I5 reworded; (c) the invoicing moved
  earlier in this scenario. Refs:
  [versions/v0.4/wave-log.md](versions/v0.4/wave-log.md) "Questions from
  the capture" (wave 4); [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.1.

From the register at d8f5f3c^ (removed by d8f5f3c):

- **O161** (v0.4's release, owner) — When do v0.4's remaining two-host
  runs happen: 17b's rehearsal on armenelos plus the VPS, the wave 4
  gate's two-host `smoke-load.sh`, the release gate's two-host runs
  (items 8 and 12), and possibly 17a's skipped two-host smoke run (D310)?
  The owner, 2026-11-03: "we may do the 2 host testing later tonight
  (report it maybe to the end of v0.6 prior tagging v1.0", not a ruling.
  Proposed: run them tonight if the laptop is connected; if not, the
  owner rules the move to the end of v0.6, before the v1.0 tag, and the
  release gate names what is then left unproven. 17b's and the release
  gate's text unchanged until then. Refs:
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 17,
  release gate; [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 18.

From the register at fd2124f^ (removed by fd2124f):

- **O162** (v0.4's release, owner) — Does release gate item 9's
  unobserved part move to v1.0 gating with the two-host runs (D311)? It
  is single-host, no game: f4's steps after the scenario's local
  midnight, f8's fixed reading and the cycles run's clean end-to-end
  verdict (D310), about a nine-hour run on armenelos. D311 names the
  two-host sessions, the stance check-list and full-game testing, not
  it, and master spec 18 item 2 still asks for it, so it stays in v0.4's
  gate until the owner rules. Proposed: moved, named in the release
  notes' known limits, since the owner asked to close without the long
  runs; else run once at the release gate. Refs:
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) release
  gate item 9; [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 18;
  [versions/README.md](versions/README.md#v10-gating).

From the register at 956802b^ (removed by 956802b):

- **O163** (v0.4's release, owner) — Release gate item 8's end-of-run
  checks with every fault planted at once: the wave 4 gate's `smoke` run
  stopped at f8's wait (D312), so its later steps never ran (every job
  of every runner and `db`'s and `reporting`'s jobs since T0, every
  scheduler key called, the full `gmctl check`, the teardown leaving
  nothing). No faulted run has reached them: chunk 17a's cycles run
  stopped at f4's wait (D310); the unfaulted `baseline` run passes them
  but `reporting`'s `pg_cron` job, which it does not read.
  Proposed: (a) read them by hand on the stopped run's deployment before
  its teardown, minutes; else (b) a harness option skipping f8's wait,
  `smoke` re-run, about an hour; else (c) left, named in the known
  limits. Refs: [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md)
  release gate item 8; [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 18 item 1.
