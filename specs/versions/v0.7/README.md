# v0.7 — the game assistant

Status: draft v1. No master spec, no build plan. Opened on 2026-11-19
(D549), after v0.6 and before v1.0.

## Goal

A player-side helper for the game, the **game assistant**: a DBA
colleague who coaches the players, with the player's access and none of
the game's background (D545, D546, D550–D554). The GM and the assistant
both become agent definitions, for Claude Code and OpenCode (D559–D561).
And, raised with it, the
repository played from in **game mode**, its memory kept clean of game
data (D555–D557).

## Drafts

| Document | What |
|---|---|
| [game-assistant.md](game-assistant.md) | The assistant: its knowledge, access and purview on trust, SQL minimised by design, the report and drafts, graded reminders on what players paste, the coach stance, no channel to the GM, the owner's audit grid as an example |
| [game-mode.md](game-mode.md) | Dev mode and game mode, the GM's memory, the skills' listing |
| [agents.md](agents.md) | The GM and the assistant as agents, for Claude Code and OpenCode: their definitions, where the files live, how each is started, the build's impact (D559–D561) |

Source kept in the tree: the owner's audit grid,
[references/grille-audit-pg.md](../../references/grille-audit-pg.md),
informative (D558).

## Open

O282, O286–O288 ([open-questions.md](../../open-questions.md),
"The game assistant"), the drafts' `(proposed)` items (GA, MD and AG labels),
and a definition of done once they are ruled.
