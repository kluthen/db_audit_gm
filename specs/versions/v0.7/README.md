# v0.7 — the game assistant

Status: draft v3. **Consolidated** on 2026-11-19 into the
[master spec](master-spec.md) and its [access model](access-model.md)
(D573), after an independent review of the drafts (REJECT, ten
findings, all closed: D572); the [build plan](build-plan.md) v1 written
the same day; all three **approved** by the owner the same day,
`main`'s history settled (D574, D575). The three drafts stay as
the working record; where they and the master spec differ, the master
spec wins. Opened on 2026-11-19 (D549), after v0.6 and before v1.0.

## Goal

A player-side helper for the game, the **game assistant**: a DBA
colleague who coaches the players, with the player's access and none of
the game's background (D545, D546, D550–D554). The GM and the assistant
both become agent definitions, for Claude Code and OpenCode (D559–D561);
the assistant may use the web to check versions and the tools'
behaviour, under its stance (D563).
And, raised with it, the
repository played from in **game mode**, its memory kept clean of game
data (D555–D557).

## Drafts

| Document | What |
|---|---|
| [game-assistant.md](game-assistant.md) | The assistant: its knowledge, access and purview on trust, SQL minimised by design, the report and drafts, graded reminders on what players paste, the coach stance, no channel to the GM, the owner's audit grid as an example |
| [game-mode.md](game-mode.md) | Dev mode and game mode, the GM's memory, the skills' listing |
| [master-spec.md](master-spec.md), [access-model.md](access-model.md) | The consolidated deliverable and its companion |
| [build-plan.md](build-plan.md) | The build plan, v1: wave 1 now, waves 2 and 3 after v0.6's release |
| [agents.md](agents.md) | The GM and the assistant as agents, for Claude Code and OpenCode: their definitions, where the files live, how each is started, the build's impact (D559–D561) |

Source kept in the tree: the owner's audit grid,
[references/grille-audit-pg.md](../../references/grille-audit-pg.md),
informative (D558).

## Open

Nothing: every question closed and the plan approved (D574, D575).
Next: `v0.7-spec` merged into `main` (G2), then wave 1 (chunks 1–3);
waves 2 and 3 after v0.6's release and the switch to `dev` (G3, G4).
