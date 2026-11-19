# v0.7 — Build plan

Status: v2 (2026-11-19): the agent-definition check made a headless
`claude -p --agent` run, `claude agents` no longer listing definitions
(v1: written from the consolidated master spec).
**Approved by the owner on 2026-11-19** with it ("approved. you may
merge. ok"; spec D574); G1 and G5 cleared.
Written from: [master spec](master-spec.md) and
[access model](access-model.md) as consolidated 2026-11-19. The model
is `~/.local/share/dev_team/references/build-plan-model.md`; this plan
states only its deltas.

## Read first

- **Two groups.** Wave 1 builds now, on `main`, beside v0.6's remaining
  waves: nothing in it touches a file v0.6 is changing. Waves 2 and 3
  wait for v0.6's release (G3): they convert `.claude/skills/game-master/`,
  which v0.6's chunk 13 edits, bump `bastion` past 0.6.0, and need the
  `dev` branch.
- **The switch** (master spec 8.6) is a gate, not a chunk (G4): once
  v0.6 is released and wave 1 merged, the driver creates `dev` from
  `main` on the owner's word. Wave 1 merges into `main`; waves 2 and 3
  are cut from `dev` and merge into it. `main` changes after that only
  through `publish-main`, first run at the release gate.
- **No data preflight**: the repository keeps no data register (all its
  data is synthetic game content).
- **Pushes** run only on the owner's word, never from a chunk, a gate or
  the skill.

## Gates

| Gate | What | Cleared by | Blocks | Status |
|---|---|---|---|---|
| G1 | The master spec, the access model and this plan approved | owner | every chunk | done (2026-11-19, spec D574) |
| G2 | `v0.7-spec` merged into `main` (after `doc-ids compare main v0.7-spec`) | owner's word (given 2026-11-19, spec D574), driver | wave 1 | done (2026-11-19, merge 03429d9) |
| G3 | v0.6 released: its release gate passed, `bastion` 0.6.0 released, chunk 13 merged | v0.6's wave driver, owner | waves 2, 3 | open |
| G4 | The switch: wave 1 merged into `main`, then `dev` created from `main` at v0.6's release commit (or the merge after it holding wave 1); every open branch's base noted in the wave log | owner's word, driver | waves 2, 3 | open |
| G5 | `main`'s history and `dev`'s remote: one snapshot commit per publish, history never rewritten, `dev` kept off the public remote | owner ruling | the release gate's first publish | done (2026-11-19, spec D575) |
| G6 | The empirical check (master spec 7.7) recorded in both tools, at wave 2's gate | wave 2's gate | chunk 8 (whether it runs) | open |

## Waves

| Wave | Chunks | Waits for | Status |
|---|---|---|---|
| 1 | 1, 2, 3 | G1, G2 | in progress (2026-11-19) |
| 2 | 4, 5, 6, 7 | G3, G4, wave 1 | planned |
| 3 | 8 | G6 | planned; conditional: runs only for what G6 finds (a listing leaking a GM skill's description, an OpenCode answer needing a change), otherwise dropped. One chunk because what it holds can't be known before wave 2's gate. |

```
G1, G2 ──> wave 1: 1, 2, 3
G3, G4 ──> wave 2: 4 ──> 5 (capture W2: the GM's skill names); 6; 7
wave 2 gate (G6) ──> wave 3: 8 (conditional)
G5 ──> release gate (first publish)
```

Chunk 5 depends on chunk 4 inside wave 2: the GM's own skill names,
which chunk 5's generated settings leave `"on"`, are fixed by capture W2
at the wave preflight (chain of two).

## Workflow deltas

- **κ**: at most two active chunk owners **in total**, v0.6's included.
  While v0.6's wave 4 runs, wave 1 runs at κ = 1 (or not at all, when
  v0.6 already has two owners active); after v0.6's release, κ = 2.
  Driven from the top-level session.
- **Docker is serialised**: every Docker-using step runs under `flock
  /tmp/dbagm-docker.lock <command>`, under `systemd-inhibit
  --what=sleep:idle:handle-lid-switch` when longer than a few minutes.
  Chunks are marked **Docker: heavy**, **light** or **none**. The VPS is
  not used. Never `docker * prune`.
- **Tests under 30 minutes** each; no full game, no aging run.
- **Branches and worktrees**: waves `v0.7-w<n>` in
  `/home/bastien/work/db_audit_gm-wt/v0.7-w<n>`; chunks
  `v0.7-c<id>-<slug>` in `/home/bastien/work/db_audit_gm-wt/v0.7-c<id>-<slug>`;
  the release gate `v0.7-rg`. Wave 1 is cut from `main` after G2 and
  merges into `main`; waves 2 and 3 are cut from `dev` after G4 and
  merge into `dev`. Never in the main checkout.
- **Shared lists**, under the model's in-wave rule: `.gitignore`;
  `tools/tests/__init__.py`'s registrations, if any.
- **Chunk checks**, in addition to the model's (v0.6's kept):
  - Python: `python3 -m unittest discover -s tools/tests -t .`, and
    `python3 -m py_compile` on Python outside the suites;
  - shell: `sh -n` on every shell file touched, `shellcheck` when
    installed;
  - JSON: every settings file touched parses (`python3 -m json.tool`);
  - **an agent definition touched**: it loads in its tool:
    `opencode agent list` names it and `opencode debug agent <name>`
    shows the permissions the master spec sets (7.4, 7.5); the Claude
    Code one answers a headless run, `claude -p --agent <name>
    [--settings <file>] --max-turns 1` from the clone (the settings file
    the launcher gives that agent, when it has one), asked to list its
    tools and the skills it can see, and the answer matches master spec
    7.4 (the assistant) or 7.5 (the GM); one model call per run (Claude
    Code 2.1.328's `claude agents` lists background sessions, not
    definitions); the other dialect's file changed in the same commit,
    or the chunk says why not (the two-dialect rule, master spec 7.1);
  - a brick touched: its image build and stack test under the lock.
- **Wave gate (full quality command)**, under the lock and on armenelos
  alone, each item under 30 minutes: the full unit suite; `sh -n` and
  `py_compile` over every file of their kind; every agent definition
  loading in its tool, by the chunk check above (OpenCode's two
  commands, the headless `claude -p --agent` run, one model call per
  Claude Code definition); the wave's brick builds and stack tests; from
  wave 2, the GM agent's regression smoke (`sh tools/tests/smoke-scenario.sh`
  on `bookshop-new-server`, set up and judged by the GM agent started
  through `tools/play gm --dev`); at wave 2's gate, the empirical check
  (G6).
- **Link lint**: `doc-ids lint spec` and `doc-get lint plan` when a
  chunk touches `specs/`.

## Measurements and hand checks

- **The empirical check** (master spec 7.7), at wave 2's gate (G6) and
  again at the release gate: each agent started in each tool as master
  spec 7.3 says, asked to list its skills and to invoke a GM skill (the
  assistant) or a skill not its own (the GM); the OpenCode questions
  (`CLAUDE.md` loaded unasked, memory across sessions, switching agents
  in a running session). Answers in the wave log.
- **The GM agent's regression**, wave 2's gate: one short smoke scenario
  set up, handed over and judged by the GM agent, its figures beside
  v0.6's gate run of the same scenario.

## Chunks

### Chunk 1 — The game assistant's agent definitions and settings

Status: merged (w1, e89a7f2)
Record: ecccbbf, merged as e89a7f2. Its Done when's `claude agents` check was replaced by a headless `claude -p --agent game-assistant` run, because `claude agents` no longer lists definitions in Claude Code 2.1.328 (wave log, chunk 1; sent to spec-writer). The prompt words `docs/gm.md` as "every file under `docs/` other than `docs/player.md`", per capture W1 point 2.
Wave: 1
Depends on: G1, G2
Architecture capture: W1: the assistant's file names and the settings
file's keys (`skillOverrides`, `autoMemoryEnabled`, the denied commands);
the spoiler word list chunk 3's check uses, which chunk 1's definitions
must pass.
Docker: none

- Goal: the game assistant exists in both tools, with the stance of the
  master spec, its session settings, and the audit grid where `main`
  will carry it.
- Scope: in: `.claude/agents/game-assistant.md` and
  `.opencode/agents/game-assistant.md` (the stance of master spec 6 as
  the agent's prompt: knowledge, where it runs, purview, the shared SSH
  connection and the history read through its credential filter, the
  allow-list, the web rules, SQL, writes, graded reminders, in-world
  stance in the terms of 6.10, the GM, coach, bounds, sessions,
  language); the opening
  message (6.11); `.claude/game-assistant.settings.json` (7.4, listing
  today's five GM skill names); the grid moved to
  `references/grille-audit-pg.md` with its note's path updated;
  `.gitignore` gains `play/`. Out: the launcher (chunk 2); the bastion's
  page (chunk 6); the GM's workflow skill names in the settings (chunk 4
  adds them).
- Files: `.claude/agents/game-assistant.md`,
  `.opencode/agents/game-assistant.md`,
  `.claude/game-assistant.settings.json`,
  `references/grille-audit-pg.md` (moved from
  `specs/references/grille-audit-pg.md`), `.gitignore`,
  `specs/versions/v0.7/game-assistant.md` and the other drafts' links to
  the grid.
- Spec sections: [master spec](master-spec.md#6-the-game-assistant) 6,
  [7.2](master-spec.md#72-where-the-files-live),
  [7.4](master-spec.md#74-the-assistants-definition); items 1, 7.
- Atoms: none (no intent record).
- Done when: both definitions load in their tools (`opencode debug agent
  game-assistant` shows `skill: deny`, `task: deny`, `webfetch` and
  `websearch` allowed, the edit and bash patterns of 7.4; `claude agents`
  lists it with the tools of 7.4 and no `Skill`); the settings file
  parses and holds the five names, `autoMemoryEnabled: false` and the
  three denied commands; the prompt covers every subsection of master
  spec 6, checked by a table in the commit message mapping each to its
  place; neither definition holds a word of capture W1's spoiler list
  (`grep -i -w -f`); the history filter drops a fixture line with an
  `Authorization: Bearer` header; the grid's text below its note is
  unchanged (`diff` against the
  owner's file); `play/` is ignored.
- Verification: chunk checks.
- Split rule: none expected (four files of substance); if the prompt
  outgrows one session, 1a the Claude Code file and the settings, 1b the
  OpenCode port and the grid's move.

### Chunk 2 — The launcher, `tools/play`: the assistant's half

Status: planned
Wave: 1
Depends on: G1, G2
Architecture capture: W1: `tools/play`'s command line (`gm` |
`assistant`, `--opencode`, `--dev`) and its refusal on `dev`.
Docker: none

- Goal: `tools/play assistant` starts the assistant in either tool, and
  the launcher refuses to run on `dev`.
- Scope: in: `tools/play` (POSIX shell) with `assistant`, `--opencode`,
  the branch refusal, and `gm` answering "not yet available" until
  chunk 5; its unit tests with a fake `claude` and `opencode` on `PATH`
  (the suite's `fakebin/` pattern). Out: the GM half (chunk 5).
- Files: `tools/play`, `tools/tests/test_play.py`,
  `tools/tests/fakebin/` (fake `claude`, `opencode`, recording their
  arguments).
- Spec sections: [master spec 7.3](master-spec.md#73-starting-each-agent),
  [7.6](master-spec.md#76-the-launcher-and-the-gms-settings); item 3.
- Done when: `tools/play assistant` runs `claude --agent game-assistant
  --settings .claude/game-assistant.settings.json`, and with
  `--opencode`, `opencode --agent game-assistant` (the fakes record
  exactly these); on a checkout whose branch is `dev` it exits non-zero
  naming why, and runs with `--dev`; an unknown verb prints the usage.
- Verification: chunk checks.

### Chunk 3 — `publish-main`: its checks and the dev-only paths

Status: planned
Wave: 1
Depends on: G1, G2
Architecture capture: W1: `game-mode/paths`' format (one path or glob per
line, `#` comments) and the publish script's command line.
Docker: none

- Goal: the skill that will update `main`, with every check of master
  spec 8.3 implemented and tested against fixture trees, before `dev`
  exists.
- Scope: in: `.claude/skills/publish-main/SKILL.md` (the procedure of
  8.3, the owner's word before any push, never run on its own
  initiative, `disable-model-invocation: true`); `game-mode/publish.py`
  building the filtered tree into a temporary worktree and running the
  checks (dev-only paths absent; no carried file telling its reader to
  open a `specs/`, `issues/` or `tools/tests/` path; no spoiler word or
  fault name in `README.md`, `CLAUDE.md` and the assistant's two
  definitions; every GM skill named `"off"` in the assistant's settings
  file; nothing git-ignored; both
  dialects of both agents present; `.claude/settings.json` with
  `autoMemoryEnabled: false`; the loader's format check on every
  scenario), with a `--check-only` mode; `game-mode/paths` listing
  master spec 8.2's dev-only paths, itself and the skill included.
  Out: committing to `main` for real (the release gate's first publish);
  the game-mode `README.md`, `CLAUDE.md` and `settings.json` (chunk 7).
- Files: `.claude/skills/publish-main/SKILL.md`,
  `game-mode/publish.py`, `game-mode/paths`,
  `tools/tests/test_publish_main.py`, `tools/tests/fixtures/publish/`.
- Spec sections: [master spec 8.2](master-spec.md#82-what-main-carries),
  [8.3](master-spec.md#83-publish-main); item 5.
- Done when: each check refuses its fixture (a dev-only path, a pointer
  into `specs/`, an aging word in the game `README.md`, a missing
  dialect, memory left on) and passes a clean fixture; `--check-only`
  on the current tree lists today's findings without writing anything
  (recorded in the wave log as the starting state for chunk 7 and chunk
  4's `specs/` pointers).
- Verification: chunk checks.

### Chunk 4 — The GM as an agent: its core file and its skills

Status: planned
Wave: 2
Depends on: G3, G4
Architecture capture: W2: the GM's workflow skills' names
(`game-master-<workflow>`), which chunk 5 and chunk 1's settings file
read.
Docker: heavy (the regression smoke)

- Goal: the GM runs as an agent in both tools, with every procedure of
  today's skill moved, none rewritten.
- Scope: in: `.claude/agents/game-master.md` (the core file: the stance
  every workflow shares, memory in the local implementation only, never
  delegated to); `.opencode/agents/game-master.md` (7.5's permissions,
  its own skills allowed by name); `.claude/skills/game-master-<workflow>/`
  for setup and deploy, restart, the final answer and evaluation, the
  feedback, with `gmctl.md` as a reference; the old
  `.claude/skills/game-master/` removed; the `scenario-format` skill's
  pointers to `specs/formats.md` made self-sufficient; every
  `/game-master` mention outside `specs/` re-read and updated; the
  assistant's settings file gains the workflow skills' names. Out: the
  launcher's GM half (chunk 5).
- Files: `.claude/agents/game-master.md`,
  `.opencode/agents/game-master.md`, `.claude/skills/game-master-*/`,
  `.claude/skills/game-master/` (removed),
  `.claude/skills/scenario-format/SKILL.md`,
  `.claude/game-assistant.settings.json`.
- Spec sections: [master spec 7.5](master-spec.md#75-the-gms-definition),
  [8.5](master-spec.md#85-memory); item 2.
- Done when: every section of the old `SKILL.md`, `gmctl.md` and
  `feedback.md` is found, unchanged in substance, in the core file or a
  workflow skill (a mapping table in the commit message); both
  definitions load; `publish-main --check-only` finds no carried pointer
  into `specs/`; the regression smoke passes under the GM agent.
- Verification: chunk checks; the regression smoke on
  `bookshop-new-server`, under the lock.
- Split rule: 4a the Claude Code core file and the skills' split (the
  bulk); 4b the OpenCode port, the `scenario-format` pointers, the
  mentions and the settings file's names, then the smoke.

### Chunk 5 — The launcher's GM half and its generated settings

Status: planned
Wave: 2
Depends on: chunk 2, chunk 4 (capture W2)
Architecture capture: none beyond W2
Docker: none

- Goal: `tools/play gm` starts the GM with settings hiding every skill
  but its own.
- Scope: in: `tools/play gm` (the skill scan, the generated git-ignored
  `.claude/game-master.settings.json`, `disableBundledSkills`,
  `autoMemoryEnabled: false`, the plugin warning, `--opencode`);
  `.gitignore` gains the generated file; tests.
- Files: `tools/play`, `tools/tests/test_play.py`, `.gitignore`.
- Spec sections: [master spec 7.6](master-spec.md#76-the-launcher-and-the-gms-settings);
  item 3.
- Done when: for a fixture home and clone holding user, project and
  nested skills, the generated file sets every name to `"off"` but the
  GM's own (its workflow skills and the four helpers), and the fake
  `claude` records `--agent game-master --settings
  .claude/game-master.settings.json`; an enabled plugin in the fixture's
  Claude Code settings is named in a warning; the file is ignored by git.
- Verification: chunk checks.

### Chunk 6 — `bastion` 0.7.0: "The game assistant" in the player documentation

Status: planned
Wave: 2
Depends on: G3
Architecture capture: none
Docker: light

- Goal: players find what the assistant is, what it isn't, and how to
  start it, on the bastion.
- Scope: in: `bricks/bastion/docs/player.md` gains "The game assistant"
  (master spec 6.11: what it is and is not; the GM takes the report;
  started from a clone with `tools/play assistant`; the shared SSH
  connection, 6.4); `brick.yaml`'s version 0.7.0 and its comment. Out:
  any other bastion change.
- Files: `bricks/bastion/docs/player.md`, `bricks/bastion/brick.yaml`,
  the scenarios' pins of `bastion` where they name 0.6.0.
- Spec sections: [master spec 6.11](master-spec.md#611-the-assistant-and-the-gm),
  [6.4](master-spec.md#64-its-reads-on-the-bastion-and-how); item 8.
- Done when: the section is on the documentation site's bastion page
  after a build; the image builds and the stack test passes; every
  scenario loads with the new pin.
- Verification: chunk checks.

### Chunk 7 — Game mode's files

Status: planned
Wave: 2
Depends on: G4, chunk 3
Architecture capture: none
Docker: none

- Goal: the game versions of the root files, kept on `dev`, ready for
  the first publish.
- Scope: in: `game-mode/README.md` and `game-mode/CLAUDE.md` (master
  spec 8.4), `game-mode/settings.json` (`autoMemoryEnabled: false`),
  `publish.py` taking `.claude/settings.json` from it; on `dev`, the
  root `README.md` and a `CLAUDE.md` stay the developer's, the latter
  stating the two-dialect rule (7.1). Out: running the publish.
- Files: `game-mode/README.md`, `game-mode/CLAUDE.md`,
  `game-mode/settings.json`, `game-mode/publish.py`, `CLAUDE.md`.
- Spec sections: [master spec 8.4](master-spec.md#84-the-game-mode-readmemd-and-claudemd),
  [8.5](master-spec.md#85-memory); item 5.
- Done when: `publish.py --check-only` on `dev` passes every check but
  those chunk 4 clears, which it lists; the game `CLAUDE.md` holds no
  word a check refuses.
- Verification: chunk checks.

### Chunk 8 — The empirical check's consequences (conditional)

Status: planned (conditional on G6)
Wave: 3
Depends on: G6
Architecture capture: none
Docker: none

- Goal: what wave 2's empirical check found is answered as master spec
  7.7 says.
- Scope: in, each only when G6 found its cause: every GM skill's
  `description:` rewritten neutral (the four helpers and the workflow
  skills), the GM's invocations unchanged; a project `opencode.json`
  with `instructions: ["CLAUDE.md"]`, and OpenCode's memory turned off
  there if it has a setting, otherwise the rule written into the
  game-mode `CLAUDE.md` and the GM's core file and the gap into the
  access model; the game-mode `README.md`'s line on one agent per
  session; the empirical check rerun. Out: `disable-model-invocation`
  (never).
- Files: the GM skills' `SKILL.md`, `opencode.json`,
  `game-mode/CLAUDE.md`, `game-mode/README.md`,
  `.claude/agents/game-master.md`, `.opencode/agents/game-master.md`,
  `specs/versions/v0.7/access-model.md`.
- Spec sections: [master spec 7.7](master-spec.md#77-the-empirical-check);
  item 4.
- Done when: the rerun check shows no GM skill's description in the
  assistant's session and each OpenCode finding answered; the GM's
  regression smoke still invokes its skills.
- Split rule: 8a the descriptions; 8b the OpenCode answers.
- Verification: chunk checks; the empirical check rerun; the regression
  smoke under the lock.

## Release gate

Against master spec [11](master-spec.md#11-definition-of-done), on `dev`,
after the last wave's gate: every item; the
empirical check rerun in both tools; the full unit suite and the GM
agent's regression smoke; release notes on v0.7's page. Then, with G5
cleared, the first `publish-main` run from the release commit produces
the first game-mode `main` (item 6), its checks green; the push command
is printed and runs only on the owner's word.
