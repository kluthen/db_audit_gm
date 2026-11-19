# Game mode and memory

Status: draft v1

The repository as players and GMs meet it, apart from the repository as
it is developed. Raised on 2026-11-19 by the game assistant's session
cleanliness (O282) and widened by the owner into a repository rule
(D555–D557); a v0.7 item beside [the game assistant](game-assistant.md)
(D549). Settled items are stated as fact, tentative ones tagged
`(proposed)` and labelled **MD1**, **MD2**…; open questions in
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

## 2. What exists (checked 2026-11-19)

- **No `CLAUDE.md`** in the repository. `README.md` is the developer's
  entry: the project's status, the versions table, the layout, pointers
  into `specs/`.
- **`main` has been pushed in dev mode**: `origin/main` is at 7a62c54
  (v0.5's close), with that README. So D556 needs a mechanism; nothing
  produces or checks a game mode today.
- **Claude Code's automatic memory** is kept per checkout path, outside
  the repository (under the user's `~/.claude/projects/`), so it is never
  pushed. The owner's memory for the development checkout holds
  development notes (versions' status, fake aging, fault selection); a
  game started there would load them. A fresh clone at another path
  starts with none (D557), but a GM session in that clone writing memory
  would leave it for the next session there, an assistant's or a
  player's: the leak D555 closes.
- **The GM already has its own record**: the game's local
  implementation, `scenarios/<s>/local/`, git-ignored and GM-side, from
  which a fresh GM session grounds itself (D39) and where the restart
  record lives.
- **The skills' listing**: every session at the repository root lists
  the project's skills with their descriptions. `game-master` has
  `disable-model-invocation: true`; the four GM sub-skills
  (`scenario-format`, `scenario-document`, `data-register`,
  `network-overview`) don't, and their descriptions name the answer key,
  the register faults and the overview faults. The game-master skill
  uses each of them "with the … skill" during setup, so making them
  user-only (`disable-model-invocation: true`) would stop the GM from
  invoking them unless it reads their files instead (O282).

## 3. Producing game mode (O286)

Proposed (MD1): **the tracked files are the game mode**; dev mode is a
local overlay, so no push can carry dev mode and there is nothing to
swap:

- `README.md` becomes the game's: what the game is, how to start one
  (a fresh clone, `/game-master`), the players' assistant
  (`/game-assistant`), the trust line (the repository holds the answers;
  players don't read it). The developer's content moves to
  `specs/README.md`, already the spec tree's index, and a
  `DEVELOPING.md` for the layout and the tooling.
- `CLAUDE.md` is the game's: this checkout is for playing; no
  development; the GM's and the assistant's skills are invoked
  explicitly; no game data in memory (MD2); the GM side of every
  scenario is the GM's.
- The developer's own instructions live outside the tracked files: a
  git-ignored local file, or the developer's user-level memory.
- **A check before every push**: a script (`tools/tests/check-game-mode.sh`,
  say) that fails when `README.md` or `CLAUDE.md` carry development
  matter (a marker, or a list of forbidden sections), run by a pre-push
  hook each checkout installs and by every release gate.

The alternatives: a release step that writes the curated files onto a
`game` branch or tag, the only one pushed, `main` staying local (two
histories to keep apart, and `main` is already public); a pre-push hook
rewriting the files (a push that changes what it pushes). Either keeps
the dev README as the tracked one, the opposite of "only push game
mode". Everything else (specs, scenarios, answer keys) is pushed as
today, on the trust line (D13): game mode is about what a session loads
and what a reader is first told, not about hiding the answers.

## 4. The GM's memory (O287)

Proposed (MD2): the GM's memory is the game's local implementation and
nothing else; the GM writes no game data to Claude Code's automatic
memory; the game-mode `CLAUDE.md` and the game-master skill both say so;
and, if Claude Code lets a project turn its automatic memory off in its
committed settings (to verify at build), game mode does. The game
assistant keeps no memory beyond its drafts (game-assistant.md 12).

The alternatives: the rule in `CLAUDE.md` and the skill only, on trust;
a GM memory folder of its own (`scenarios/<s>/local/memory/`, say),
which the local implementation already is in all but name.

## 5. The skills' listing (O282)

Proposed (MD3): the four GM sub-skills' descriptions rewritten neutral
("GM only, invoked by the game master during setup: generates a
scenario's …"), without the answer key or the faults, so the listing
leaks nothing and the GM can still invoke them; the game assistant never
invokes another skill (game-assistant.md GA5). Making them user-only
(`disable-model-invocation: true`), the first recommendation, works only
if the game-master skill reads their files instead of invoking them.
