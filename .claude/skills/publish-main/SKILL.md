---
name: publish-main
description: Publish db_audit_gm's game branch main from a dev commit the owner names — build main's tree without the dev-only paths, with game mode's README.md, CLAUDE.md and settings.json, check it, and commit it as one snapshot on main. Run only when the owner asks for a publish, never on your own initiative; it never pushes.
disable-model-invocation: true
---

# publish-main

`main` is the game branch: what players and GMs clone. It changes only
through this skill (v0.7 master spec 8.1). The skill lives on `dev` and
never reaches `main`: `game-mode/paths` lists it as dev-only.

Sources: v0.7 master spec 8.2 (what `main` carries), 8.3 (this
procedure) and spec D575 (one snapshot commit per publish, `main`'s
history never rewritten, `dev` kept off the public remote); capture W1,
items 2, 4 and 5, in `specs/versions/v0.7/wave-log.md`.

## When

Only when the owner asks for a publish and names the `dev` commit (a
release, normally). Never on your own initiative, never as a step of a
wave, a chunk or a gate. If the owner has not named the commit, ask.

## The files

- `game-mode/publish.py`: builds and checks the tree, then commits it.
- `game-mode/paths`: the dev-only paths, one git `:(glob)` pathspec per
  line (`#` comments; a trailing `/` names a directory and everything
  under it).
- `game-mode/spoiler-words`: the words `README.md`, `CLAUDE.md` and the
  assistant's two definitions may not carry (case-insensitive, whole
  word); the fault names, read from `faults/<name>/` at check time, are
  added to them.
- `game-mode/README.md`, `game-mode/CLAUDE.md`, `game-mode/settings.json`:
  what replaces the dev `README.md`, `CLAUDE.md` and
  `.claude/settings.json` on `main`.

## The procedure

1. **Check first.** From a checkout of `dev` (never of `main`):

   ```sh
   python3 game-mode/publish.py --check-only --from <rev>
   ```

   It builds `main`'s tree from `<rev>` in a temporary index and folder
   (the caller's checkout untouched): the commit's tree minus the paths
   `game-mode/paths` lists, with `README.md`, `CLAUDE.md` and
   `.claude/settings.json` replaced by game mode's. Then it runs every
   check below and prints each finding as
   `<check>: <path>[:<line>]: <what>`. Exit 0: no finding; 1: findings;
   2: a usage or git error.

2. **Stop on any finding.** Report the findings to the owner and fix
   them on `dev` (or have them fixed); never publish around one, and
   never edit `game-mode/paths` or `game-mode/spoiler-words` to silence
   one without the owner's word.

3. **Publish.** With no finding, and the owner's go:

   ```sh
   python3 game-mode/publish.py --from <rev>
   ```

   It runs the same build and checks, then commits the tree as one new
   commit on `main` (its parent `main`'s previous commit, its message
   naming the `dev` commit), and prints the push command. It refuses
   when `main` is checked out in a worktree, and commits nothing when
   `main` already carries that tree.

4. **Never push.** Give the owner the printed push command. It runs only
   on the owner's word, and `dev` is never pushed to the public remote.

## The checks

| Check | Refuses |
|---|---|
| `replace` | a missing `game-mode/README.md`, `game-mode/CLAUDE.md` or `game-mode/settings.json` |
| `dev-only` | a carried path that is dev-only (`game-mode/paths`, and master spec 8.2's list as a guard), a missing `game-mode/paths`, an 8.2 path the file doesn't list |
| `pointer` | a carried file telling its reader to open a dev-only path: a Markdown link into one, or an open verb (read, open, consult, see, refer to, look at or in, follow) before one in the same clause. A mention as provenance is allowed (8.2) |
| `dev-matter` | `README.md`, `CLAUDE.md` or an assistant definition naming a dev-only path |
| `spoiler` | a spoiler word or a fault name in `README.md`, `CLAUDE.md` or an assistant definition; a missing `game-mode/spoiler-words` |
| `skills` | a skill carried under `.claude/skills/` not set `"off"` in `.claude/game-assistant.settings.json`. Every skill `main` carries is a GM skill: the rule needs no list, and a new `game-master-<workflow>` skill is caught until it is added there |
| `ignored` | a carried path the tree's own `.gitignore` files ignore |
| `local` | a local implementation (a `local/` folder outside a brick's `rootfs/`) |
| `agents` | a missing definition: the GM and the assistant, each in `.claude/agents/` and `.opencode/agents/` |
| `memory` | game mode's `.claude/settings.json` without `"autoMemoryEnabled": false` |
| `format` | a scenario failing the loader's format check (`tools.gm.model.check_scenario`, as `gmctl` loads a scenario), run with the built tree's own loader |

The checks' tests: `tools/tests/test_publish_main.py`, on fixture
repositories built from `tools/tests/fixtures/publish/`.
