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
- D107, D113, D192, D196, D201, D233–D238, D248–D251, D260–D280,
  D285–D304, D306–D309 and D314–D476 (v0.5), one file per range in
  [archive/v0.5/](archive/v0.5/README.md#archived-files), mapped in
  [archive/v0.5/README.md](archive/v0.5/README.md#where-it-now-lives).
- D480–D544, D548, D578–D600 and D602 (v0.6), one file per range in
  [archive/v0.6/](archive/v0.6/README.md#archived-files), mapped in
  [archive/v0.6/README.md](archive/v0.6/README.md#where-it-now-lives).

Archived IDs keep their meaning and are cited as they are. Never issued:
D232 and D259 (v0.4); D337, D341, D359, D371, D392, D429, D430 and D470
(reserved during v0.5 and never used); D477–D479 (set aside for v0.5's
close, unused at its archive); D526 (reserved during v0.6's wave 2,
never used), D531 and D579 (reserved during v0.6's build, never used).
The live entries below are v0.7's, from D545 on, and D601, v0.6's
last, kept live until what it rules is done (O298, O299, ISS-009).
Take the next number from `doc-ids`; no ID is reused.

- **D545 (2026-11-19, owner request, relayed by the coordinator): a game
  assistant, a player-side helper distinct from the GM**, with no access
  to the game's background: player handouts and basic bastion activity
  only, never a database, no file beyond the report and its drafts
  (tracking only when asked), DBA and basic dev knowledge, SQL written
  unverified for the players to run, a reminder of the breach when a
  player hands it database snippets. Not in v0.6 (O274). Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 1.
- **D546 (2026-11-19, owner ruling, same relay): the assistant is a skill
  in this repository, `/game-assistant`, on trust,** invoked at the
  repository root as `/game-master` is; its off-limits material is so by
  stance, as D13's light enforcement. Rejected: an exported player
  workspace with deny rules; Claude Code installed on the bastion. Now
  in: [game-assistant.md](versions/v0.7/game-assistant.md) 1, 3.
  *Amended by D559 (an agent, not a skill) (2026-11-19).*
- **D547 (2026-11-19, owner ruling, same relay): the bastion link is a
  fixed, read-only set of reads, never a shell; the assistant's files are
  local,** the players copying the report to `~/report.md`, where the GM
  fetches it. A shell as `player` reaches every database (`~/.pgpass`).
  Rejected: writing into the bastion's home; paste only. The mechanism is
  O275, the set O276. Now in: [game-assistant.md](versions/v0.7/game-assistant.md) 4, 6.
  *Amended by D550 (the player's access, no fixed read set) and D554 (the
  report's location free) (2026-11-19).*
- **D549 (2026-11-19, owner ruling, relayed by the coordinator): v0.7,
  the game assistant its subject** ("it'll be v0.7"), after v0.6 and
  before v1.0; the repository's game mode (D555–D557) joins it. Closes
  O274. Now in: [versions/README.md](versions/README.md),
  [versions/v0.7/README.md](versions/v0.7/README.md).
- **D550 (2026-11-19, owner ruling, same relay): the assistant has the
  player's access, on trust,** amending D547: the bastion as `player`,
  the web front, the handouts; no door, no `gmctl` verb, no key. Two
  trust lines: in the assistant (no database, no write beyond its report
  and drafts, reads only what serves its purview) and in the players
  (they don't use it to reach what they can't). Closes O275, O276. Now
  in: [game-assistant.md](versions/v0.7/game-assistant.md) 1, 3.
- **D551 (2026-11-19, owner ruling, same relay): the assistant is a
  coach** ("it's indeed a coach"), as recommended. Closes O277. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 10.
- **D552 (2026-11-19, owner ruling, same relay): reminders graded by
  criticality, and its own SQL minimised by design.** A schema widens the
  attack surface, "still bad"; high items draw the full reminder, medium
  ones a lighter one naming the risk, after the owner's notes
  (`/home/bastien/audits/bluebox-lab/docs/ADAPTATION.md` 7.5, restated,
  not copied). Closes O278. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 5, 7.
- **D553 (2026-11-19, owner ruling, same relay): the assistant is always
  available** ("it's just not called upon when not needed"); no
  initiator switch, nothing in the hand-over. Closes O279. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 1.
- **D554 (2026-11-19, owner ruling, same relay): no communication
  between the assistant and the GM, and the report's location free,**
  amending D547: the GM isn't told; how the report reaches the GM is the
  players' affair; `play/<game>/` a default only. Closes O280, O281. Now
  in: [game-assistant.md](versions/v0.7/game-assistant.md) 6, 9.
- **D555 (2026-11-19, owner ruling, same relay): the GM leaks no game
  data through memory;** any GM memory is its own, kept to its section
  of the repository. Mechanism O287. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 1, 4.
- **D556 (2026-11-19, owner ruling, same relay): dev mode and game mode;
  only game mode is pushed,** with a `CLAUDE.md` and a `README.md`
  curated for playing. `origin/main` (7a62c54) was pushed in dev mode;
  the mechanism is O286. Now in: [game-mode.md](versions/v0.7/game-mode.md)
  1, 3.
- **D557 (2026-11-19, owner ruling, same relay): a game is played from a
  fresh clone elsewhere,** never from the development checkout, whose
  automatic memory holds development notes. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 1, 2.
- **D558 (2026-11-19, owner ruling, same relay): the owner's audit grid
  is informative,** "not scoped for our purpose but hints as to how to
  handle an audit"; a verbatim copy stored in the tree; the assistant may
  draw on it, never bound to it; a game-scoped English rewrite optional
  and later. Closes O283, O284, O285. Now in:
  [references/grille-audit-pg.md](../references/grille-audit-pg.md),
  [game-assistant.md](versions/v0.7/game-assistant.md) 11.
- **D559 (2026-11-19, owner ruling, relayed by the coordinator): the game
  assistant is an agent, not a skill,** amending D546: one definition for
  Claude Code and one for OpenCode, allowed no skill (no `Skill` in its
  tools, `skill: deny`), started by name, still on trust. Asked "can't we
  limit the skill this agent is allowed to use ?", the owner took
  dev_team's agent pattern. Now in: [agents.md](versions/v0.7/agents.md)
  1, 5; [game-assistant.md](versions/v0.7/game-assistant.md) 1.
- **D560 (2026-11-19, owner ruling, same relay): the GM is an agent too**
  ("the GM should also be an agent as well"), allowed its four helper
  skills; today's `game-master` skill becomes its core file plus
  workflow skills and references, split at build in a v0.7 chunk after
  v0.6's merge. D6 and D33 hold: a GM session is one started as the GM
  agent. Now in: [agents.md](versions/v0.7/agents.md) 1, 4, 6, 7.
- **D561 (2026-11-19, owner ruling, same relay): Claude Code and OpenCode
  both supported** ("Ensure both claude code and opencode are
  supported"): each agent defined in both dialects, kept in step by hand
  with no automated sync, as dev_team does. Now in:
  [agents.md](versions/v0.7/agents.md) 1–3.
- **D562 (2026-11-19, owner ruling, relayed by the coordinator): the game
  assistant has no web access** ("no web access"), as recommended: no
  `WebFetch` or `WebSearch` in its Claude Code tools, `webfetch: deny`
  and `websearch: deny` in OpenCode. Closes O289. Now in:
  [agents.md](versions/v0.7/agents.md) 5.
  *Superseded by D563 (2026-11-19).*
- **D563 (2026-11-19, owner ruling, relayed by the coordinator): the game
  assistant has web access,** superseding D562: `WebFetch` and
  `WebSearch` in its Claude Code tools, `webfetch` and `websearch`
  allowed in OpenCode. "we may have to handle weird version and such,
  and i would prefer the assistant to provide TRUE indications or the
  ability to check should the player report something different from
  expectations." The leak D562 guarded against is held by stance
  (GA24, GA25, proposed). O289 stays closed, by this entry. Now in:
  [agents.md](versions/v0.7/agents.md) 5;
  [game-assistant.md](versions/v0.7/game-assistant.md) 2.
- **D564 (2026-11-19, owner ruling, relayed by the coordinator): `main`
  is the game branch,** what players and GMs clone; a side dev branch
  holds the development environment; a dedicated dev-side skill is the
  only way `main` is updated. "actually the main branch should be the
  "game" branch, and a side dev branch should hold dev enviroment."
  Supersedes MD1, the tracked files as game mode. Closes O286. Its
  proposals MD5–MD9 and O290 follow. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 1, 3.
- **D565 (2026-11-19, owner ruling, same relay): automatic memory off in
  game mode,** as recommended (MD2): game mode's committed
  `.claude/settings.json` sets `autoMemoryEnabled: false`, and the GM's
  memory is the game's local implementation; OpenCode's side verified
  at build. Closes O287. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 4.
- **D566 (2026-11-19, owner ruling, same relay): v1.0 gating runs after
  v0.7,** as recommended, and the game assistant's stance items join its
  stance check-list. Closes O288. Now in:
  [versions/README.md](versions/README.md#v10-gating).
- **D567 (2026-11-19, owner ruling, same relay: every pending proposal
  accepted as drafted): the assistant's actor, knowledge and purview,**
  GA1–GA8 and GA23: an actor at consolidation; scripts read, never
  written; the game's own scripts known from the player documentation;
  the allow-list and the off-limits list; no `gmctl` or `docker`; the
  partners' credentials never repeated; handouts as the customer's
  claims; its purview on the bastion; reads through the player's shared
  SSH connection. Now in: [game-assistant.md](versions/v0.7/game-assistant.md)
  1–3.
- **D568 (2026-11-19, same ruling): its SQL, reminders and bounds,** GA9,
  GA10, GA13 and GA22: queries labelled unverified, read-only first,
  changes flagged with the node's write policy; the graded reminder every
  time, a paragraph the first, the paste still used; "propose, don't do"
  beyond each issue's resolution and write policy. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 4, 5, 7.
- **D569 (2026-11-19, same ruling): its stance with the game and the GM,
  and on the web,** GA14, GA15, GA17–GA19 and GA24–GA27: no talk of the
  game's mechanics or the aging; its opening and the bastion's player
  page telling it from the GM; never the GM's session; files in English,
  the conversation in the player's language; nothing of the game in a
  query or URL, never this project's material, sources cited, the
  in-world stance on the web. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 2, 8, 9, 12.
- **D570 (2026-11-19, same ruling): the skills' listing,** MD3 and MD4:
  the assistant's session-only `skillOverrides` hide the GM's skills;
  the build's empirical check in both tools settles the listing, and the
  helpers' descriptions are rewritten neutral if it still leaks. Closes
  O282. Now in: [game-mode.md](versions/v0.7/game-mode.md) 5.
- **D571 (2026-11-19, same ruling): the agents' definitions,** AG1–AG6:
  each agent started by name, no default agent; the assistant's and the
  GM's tools and permissions in both dialects; the GM's core file and
  workflow skills; the empirical check; the GM's session settings,
  generated at each launch by a launcher. Now in:
  [agents.md](versions/v0.7/agents.md) 4–7.
- **D572 (2026-11-19, spec-writer, closing the independent review of
  v0.7's drafts, REJECT, ten findings): the review's closures,** each
  following from an owner ruling. The assistant runs on the player's
  side, never on a machine holding the GM's local implementation unless
  it is the player's own (from D550: the player's access, not the GM's
  machine's). It reads neither the web front nor the home `partners.md`
  and is handed no password; the shell history reaches it filtered of
  credentials. Its definition names no aging word or game mechanic and
  `publish-main` scans it (the drafts' GA14/GA15 wording contradicted
  the spoiler check). Every GM skill, workflow skills included, hidden
  from it and named in its settings; the handouts treated as the
  customer's claims without the GM's rule on which may be wrong; game
  mode's settings from `game-mode/settings.json`; the grid at
  `references/`; each OpenCode check given its consequence; bricks'
  `tests/` kept on `main` (two images copy them at build). Now in:
  [master spec](versions/v0.7/master-spec.md) 6.3–6.5, 6.9, 6.10, 7.4,
  7.7, 8.2, 8.3; [access model](versions/v0.7/access-model.md) 5, 9.
- **D573 (2026-11-19, owner's word, relayed by the coordinator): v0.7
  consolidated** into its master spec and access model, a delta on
  v0.6's, the game branch's shape (MD5–MD8) and where the assistant runs
  carried for review in context and confirmed by approval; formats.md
  v37, gm-stance.md v16, planes-and-access.md v20 and concept.md v17
  brought up to date; the drafts kept as the working record, the master
  spec winning where they differ. Now in:
  [versions/v0.7/master-spec.md](versions/v0.7/master-spec.md).
- **D574 (2026-11-19, owner approval, relayed by the coordinator): v0.7's
  master spec, access model and build plan v1 approved** ("approved. you
  may merge. ok"), with the points carried for review in context: the
  game branch's shape, where the assistant runs (master spec 6.3, solo
  play included, reread and kept as written) and `tools/play` refusing
  `dev` without `--dev`; `v0.7-spec` may merge into `main` after
  `doc-ids compare`. Clears G1; G2 clears at the merge. Now in:
  [master spec](versions/v0.7/master-spec.md),
  [build plan](versions/v0.7/build-plan.md).
- **D575 (2026-11-19, owner ruling, same relay): `main`'s history and
  `dev`'s remote, as recommended:** one snapshot commit on `main` per
  publish, its history never rewritten; `dev` kept off the public remote,
  a private remote optional. Closes O290; clears G5. Now in:
  [master spec](versions/v0.7/master-spec.md) 16.
- **D576 (2026-11-19, spec-writer, plan v3, from chunk 3's starting
  state): chunk 9 inserted in wave 2, rewriting the 41 Markdown links the
  carried GM docs make into `specs/` and `tools/tests/` as plain
  provenance text.** No chunk owned them; 8.2 already makes such mentions
  provenance, so 8.3's check stands. Raises O291. Now in:
  [build plan](versions/v0.7/build-plan.md) chunk 9.
- **D577 (2026-11-19, spec-writer, plan v3): `SECURITY_TODO.md` is
  dev-only,** built in chunk 7. The game-mode draft listed it; the
  consolidation dropped it. Now in:
  [master spec](versions/v0.7/master-spec.md#82-what-main-carries) 8.2;
  [build plan](versions/v0.7/build-plan.md) chunk 7.
- **D601 (2026-11-20, the owner, G11: wave 4's items, all as
  proposed):** D595's two readings and f8's `counter_per_call` (4 a
  call) confirmed; O298 ruled (pgaudit in `lab` and `portal`, a later
  build), O299 ruled (the owner amends his grid, the copy refreshed);
  ISS-009 fixed in v0.7. Now in: [open-questions.md](open-questions.md) O298, O299;
  [ISS-009](../issues/ISS-009_20261120_scenario_document_template_gaps.md); [release notes](versions/v0.6/README.md#release-notes).
