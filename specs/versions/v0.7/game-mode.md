# Game mode and memory

Status: draft v3

The repository as players and GMs meet it, apart from the repository as
it is developed. Raised on 2026-11-19 by the game assistant's session
cleanliness (O282) and widened by the owner into a repository rule
(D555–D557); `main` made the game branch the same day (D564); a v0.7
item beside [the game assistant](game-assistant.md) (D549). Settled
items are stated as fact, tentative ones tagged `(proposed)` and
labelled **MD1**, **MD2**…; open questions in
[open-questions.md](../../open-questions.md), "The game assistant".

The owner, 2026-11-19:

> that's a current repo problem and a GM leak: the GM must not leak data
> in memory. If needed it can have it's own memory files that are
> restricted to his section of the repo.

> Likewise, current repo is in 'dev mode' so to say, so CLAUDE.md and
> the memories are bound to contains data relevant to developping this
> project. We should ensure that we only push the repo in 'game mode'
> (switching CLAUDE.md to a curated version dedicated to the game itself
> and not the dev, README.md as well). If I were to start a game here, i
> would clone the repo elsewhere thus solving part of the memory problem
> as well.

> actually the main branch should be the "game" branch, and a side dev
> branch should hold dev enviroment. Have a specific skill dedicated to
> updating main branch.

## 1. The rulings

- **The GM leaks no game data through memory** (D555). Whatever a GM
  must remember of a game is its own, kept in its section of the
  repository; nothing of a game goes into a memory that another session
  in the same clone loads.
- **Dev mode and game mode** (D556): the repository is developed in dev
  mode; only game mode is pushed, with a `CLAUDE.md` and a `README.md`
  curated for playing, not for developing.
- **A game is played from a fresh clone** (D557), elsewhere than the
  development checkout, never from the development checkout itself.
- **`main` is the game branch** (D564, superseding MD1): what players and
  GMs clone. A side dev branch holds the development environment, and a
  dedicated dev-side skill is the only way `main` is updated.
- **Automatic memory off in game mode** (D565, MD2; section 4).
- **The skills' listing** handled by the assistant's session settings,
  checked empirically, neutral descriptions the fallback (D570, MD3,
  MD4; section 5).

## 2. What exists (checked 2026-11-19)

- **No `CLAUDE.md`** in the repository. `README.md` is the developer's
  entry: the project's status, the versions table, the layout, pointers
  into `specs/`.
- **`main` has been pushed in dev mode**: `origin/main` is at 7a62c54
  (v0.5's close), with that README. Every wave driver merges into
  `main`; v0.6's wave 3 is validating and its wave 4 follows.
- **The tracked tree** (`git ls-files`, by top-level path): `.claude/`
  (the GM skill and its four helpers), `bricks/` (each with `brick.yaml`,
  `Dockerfile`, `rootfs/`, `validator/`, `docs/player.md`, `docs/gm.md`,
  and 88 files under `tests/` and 6 under `sbom/` across them),
  `domains/`, `faults/`, `partners/`, `purposes/`, `scenarios/`
  (`local/` git-ignored), `post_mortem/`, `tools/` (`gmctl`, `gm/`,
  `fake_aging/reference/`, `go-sbom`, and 1,298 files under `tests/`),
  `specs/`, `issues/`, `.tech`, `README.md`, `.gitignore`;
  `SECURITY_TODO.md` sits untracked at the root.
- **What the game's tools cite of `specs/`**: the skills and `tools/gm/`
  mention `specs/` paths (wave logs, master specs, `formats.md`) as
  provenance in comments and prose; nothing reads a `specs/` file at run
  time. The `scenario-format` skill points its reader to
  `specs/formats.md` for the format's detail in four places.
- **Claude Code's automatic memory** is kept per checkout path, outside
  the repository (under the user's `~/.claude/projects/`), so it is never
  pushed. The owner's memory for the development checkout holds
  development notes; a fresh clone at another path starts with none
  (D557), but a GM session in that clone writing memory would leave it
  for the next session there: the leak D555 closes.
- **The GM already has its own record**: the game's local
  implementation, `scenarios/<s>/local/`, git-ignored and GM-side.
- **From v0.7 the GM and the assistant are agents** (D559–D561;
  [agents.md](agents.md)). Under `claude --agent <name>`, `CLAUDE.md` and
  the project's automatic memory still load (agents.md 3): whatever
  game mode's `CLAUDE.md` says, the assistant reads too.

## 3. The game branch and the dev branch (D564)

MD1 (the tracked files as game mode, checked before each push) is
superseded by D564; its check is folded into the skill's checks (MD8).

**What `main` carries** (MD5, proposed): everything `gmctl` and the GM
agent need to set up, run and judge a game, and the assistant needs to
help; nothing that serves development only.

| On `main` | Dev only |
|---|---|
| `.claude/` and `.opencode/`: the agents, the GM's skills and helpers, the game-mode `settings.json`, the assistant's settings file | the dev-side skills (`publish-main`, MD8), any dev settings |
| `bricks/<b>/`: `brick.yaml`, `Dockerfile`, `rootfs/`, `validator/`, `docs/` (`player.md` and `gm.md`, which the GM needs) | `bricks/<b>/tests/`, `bricks/<b>/sbom/` |
| `domains/`, `faults/`, `partners/`, `purposes/`, `scenarios/` (the GM side included: the GM needs it, the trust line covers it, D13), `post_mortem/` (a handout after the final answer, D251) | |
| `tools/gmctl`, `tools/__init__.py`, `tools/gm/`, the launcher (agents.md AG6) | `tools/tests/`, `tools/go-sbom`, `tools/fake_aging/reference/` (the real-aging reference for tests) |
| the game-mode `README.md` and `CLAUDE.md`, `.gitignore` | `specs/`, `issues/`, `.tech`, `SECURITY_TODO.md`, the dev `README.md` |
| `specs/references/grille-audit-pg.md`, moved beside the assistant's files (agents.md 7) | |

**`specs/` stays off `main`.** Its mentions in the game's files are
provenance, harmless when the path is absent; the one place a reader is
sent there, the `scenario-format` skill's pointers to `formats.md`, is
made self-sufficient when the GM's skills are split (D560): what a GM
needs of the format is in its skill and templates. The skill's check
refuses any carried file that tells its reader to open a `specs/` path.

**The dev branch** (MD6, proposed): named `dev`. Spec branches
(`v0.8-spec`), wave branches (`v0.7-w2`) and chunk branches are cut from
`dev` and merge back into it, as they merge into `main` today. `dev`
starts at `main`'s commit at the switch, so a branch cut from `main`
before the switch merges into `dev` with no rebase: its merge base is
already on `dev`. Worktrees keep their paths; only their base changes.

**The switch** (MD7, proposed, the coordinator's recommendation
confirmed): after v0.6 is released, so v0.6's waves keep merging into
`main` undisturbed. `dev` is created from `main` at v0.6's release
commit; from then every wave merges into `dev`, and `main` changes only
through the skill. Its first run produces the first game-mode `main`. A
v0.7 wave that passes its gate before the switch merges into `main` as
waves do today, then reaches `dev` by the switch itself (v0.7 build
plan).

**The skill** (MD8, proposed): `publish-main`, in `.claude/skills/` on
`dev` only. From a `dev` commit the owner names (a release, normally):

1. builds `main`'s tree: the commit's tree minus the dev-only paths of
   MD5, which a manifest on `dev` lists (`game-mode/paths`), with
   `README.md` and `CLAUDE.md` replaced by their game versions, kept on
   `dev` as `game-mode/README.md` and `game-mode/CLAUDE.md`;
2. checks it, and stops on any failure:
   - no dev-only path, and no carried file telling its reader to open a
     `specs/`, `issues/` or `tools/tests/` path;
   - `README.md` and `CLAUDE.md` free of development matter and of
     spoilers: no fault name, no aging word (aging mode, fill, forged,
     virtual clock, fake), nothing of a scenario's GM side, since both
     load into the assistant's session;
   - no secret: nothing git-ignored, no local implementation;
   - the agents present in both dialects (D561), the game-mode
     `.claude/settings.json` with `autoMemoryEnabled: false` (D565);
   - every scenario passes the loader's format check, as a release gate
     does;
3. commits that tree on `main` (its history: O290, below), with the
   `dev` commit it came from in the message;
4. **never pushes** without the owner's word; it prints the command.

The game-mode `README.md` says what the game is, how to start one (a
fresh clone, then the GM through the launcher, `tools/play gm`, which
runs `claude --agent game-master --settings
.claude/game-master.settings.json`, or `opencode --agent game-master`),
the players' assistant (`tools/play assistant`, or `claude --agent
game-assistant --settings .claude/game-assistant.settings.json`, or
`opencode --agent game-assistant`), and the trust line (the repository
holds the answers; players don't read it). The game-mode `CLAUDE.md`
says this checkout is for playing, the GM and the assistant are started
by name, no game data goes into memory, and the GM side of every
scenario is the GM's; it holds nothing the assistant may not read.
OpenCode gets the same text through a project `opencode.json` with
`instructions: ["CLAUDE.md"]`, or an `AGENTS.md`, whichever the build
finds OpenCode needs (agents.md 3). On `dev`, `README.md` and a
`CLAUDE.md` stay the developer's.

**`main`'s history** (O290, the owner's call): `main` can't take a plain
merge of `dev`, which would carry the dev-only paths. Proposed (MD9):
each publish is one new commit on `main` whose tree is the filtered
snapshot, so `main`'s history stays continuous, nothing is rewritten, and
its past commits keep the development material already public. The
alternative, rewriting `main`'s history to strip that material, needs a
force-push that breaks every existing clone. Whether `dev` is pushed,
and where (the public `origin` would publish dev mode, against D556; a
private remote for a backup), is part of O290.

## 4. The GM's memory (D565)

The GM's memory is the game's local implementation and nothing else; the
GM writes no game data to Claude Code's automatic memory; the game-mode
`CLAUDE.md` and the GM's agent both say so; and game mode's committed
`.claude/settings.json` sets `autoMemoryEnabled: false` (a documented
setting; the environment variable `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`
does the same for one session), which turns it off for every session in
the clone, the GM's included (MD2, D565). The game assistant keeps no
memory beyond its drafts (game-assistant.md 12). OpenCode's side is
verified at build (agents.md 3).

## 5. The skills' listing (D570)

**Invocation is closed** by the assistant's definitions: no `Skill` in
its Claude Code `tools:`, `skill: deny` in OpenCode (D559;
[agents.md](agents.md) 5).

**The listing**, the skills' names and descriptions in its context:

- Claude Code: whether an agent session still shows it is not
  documented. The assistant's session-only settings file sets
  `skillOverrides` to `"off"` for `game-master` and the four helpers,
  which hides them from the model's listing; session-only, because
  committed project settings would hide the helpers from the GM too
  (MD4).
- OpenCode: whether `skill: deny` hides the listing is not documented.
- Both are settled by the build's empirical check (agents.md 7, AG5).
  If either listing still shows a GM skill's description, the four
  helpers' descriptions are rewritten neutral ("GM only, invoked by the
  game master during setup: generates a scenario's …", without the
  answer key or the faults) (MD3). Making the helpers user-only
  (`disable-model-invocation: true`) is ruled out: it would stop the GM
  from invoking them.
