# db_audit_gm: a checkout for playing

This checkout is for playing the game, not for developing it. Its
`README.md` says what the game is and how a game starts.

- **The game master and the game assistant are started by name**, each in
  a session of its own: `tools/play gm` and `tools/play assistant` (with
  OpenCode, `opencode --agent game-master` and `opencode --agent
  game-assistant`). A session started plainly is neither of them: it does
  not set a game up, run one, judge one, or coach the players, and it
  never hands work to either agent.
- **No game data goes into memory.** This checkout's
  `.claude/settings.json` turns automatic memory off
  (`autoMemoryEnabled: false`) for every session in it, the game
  master's included. Write nothing about a game, a scenario or the
  players to any agent's memory: the game master keeps a game in its
  local implementation under the scenario's folder, and the assistant
  keeps only the players' report and its drafts.
- **The game master's side of every scenario is the game master's.** The
  repository holds the game's answers. Only the game master reads its
  side of a scenario, of the catalogue and of a game in progress; no
  other session reads it, quotes it or hands it on, and none helps a
  player reach it.
