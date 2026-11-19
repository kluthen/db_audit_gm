# The game's agents: the GM and the game assistant

Status: draft v1

From v0.7 the GM and the game assistant are **agent definitions**, not
skills, for Claude Code and OpenCode both (D559–D561). This draft says
what each definition holds, where its files live, how each tool starts
each agent, and what a build changes. Settled items are stated as fact;
tentative ones are tagged `(proposed)` and labelled **AG1**, **AG2**…;
questions in [open-questions.md](../../open-questions.md), "The game
assistant". The assistant's stance is [game-assistant.md](game-assistant.md);
the repository's game mode is [game-mode.md](game-mode.md).

The exchange, 2026-11-19: the owner asked "can't we limit the skill this
agent is allowed to use ?", then "checkout how we do it in
~/work/dev_team"; told dev_team's pattern and offered the assistant as an
agent, the owner replied: "yeah, the GM should also be an agent as well.
Ensure both claude code and opencode are supported."

## 1. The rulings

- **The game assistant is an agent** (D559, amending D546): a Claude Code
  agent and an OpenCode agent, neither allowed skills, still on trust,
  still run from the game's clone (D557).
- **The GM is an agent** (D560): a Claude Code agent and an OpenCode
  agent, allowed the skills it uses during setup (`scenario-format`,
  `scenario-document`, `data-register`, `network-overview`). D6 (the GM
  in a Claude Code or OpenCode session) and D33 (started explicitly, so a
  development session is never a GM session) hold: a session is a GM
  session only when started as the GM agent (section 4).
- **Both tools, two dialects kept by hand** (D561): each agent has one
  definition per tool, and a change to one is carried to the other by
  hand, with no automated sync, as dev_team does it (its `README.md`,
  "Editing"). A skill holds one workflow's procedure, pulled in on
  demand; stance that runs across an agent's workflows stays in its
  core file (the same, "Editing").

## 2. The pattern, from dev_team (read 2026-11-19)

`~/work/dev_team` keeps one persona in two dialects:

- **Claude Code** (`claude-agents/<name>.md`): frontmatter `name`,
  `description`, `model`, `tools`, a flat allow-list of tools; an agent
  allowed no skill leaves `Skill` out (`reviewer`: `tools: Read, Bash`).
- **OpenCode** (`agents/<name>.md`): frontmatter `description`, `mode`
  (`primary`, `subagent`, `all`), `model`, `temperature`, and a
  `permission:` map (`edit`, `bash`, `webfetch`, `glob`, `grep`, `task`,
  `todowrite`, `websearch`, `lsp`, `skill`, each `allow`, `ask` or
  `deny`); `reviewer` and `multimodal-looker` have `skill: deny`.

dev_team installs its agents at user scope (symlinks from
`~/.claude/agents/` and `~/.config/opencode/agents/`); this game's agents
are project agents, in the repository, so a fresh clone (D557) carries
them. dev_team's README says no Claude Code agent can be "the persona you
start `claude` as"; that is out of date: the installed `claude` has
`--agent <agent>`, "Agent for the current session".

## 3. Where the files live

| | Claude Code | OpenCode |
|---|---|---|
| The GM | `.claude/agents/game-master.md` | `.opencode/agents/game-master.md` |
| The game assistant | `.claude/agents/game-assistant.md` | `.opencode/agents/game-assistant.md` |
| The GM's helpers | `.claude/skills/<name>/SKILL.md`, as today | the same files: OpenCode discovers a project's `.claude/skills/` |

**Verified locally** (OpenCode 1.18.32, its built-in `customize-opencode`
documentation, and a probe repository in a scratch folder, 2026-11-19):

- OpenCode reads project agents from `.opencode/agents/<name>.md` and
  `.opencode/agent/<name>.md` (both probed, both listed by `opencode
  agent list`), and does not read `.claude/agents/` (a probe there was
  not listed);
- it discovered a skill placed in the probe repository's
  `.claude/skills/<name>/SKILL.md` (`opencode debug skill`), beside the
  user's `~/.claude/skills/` its documentation names;
- an agent's `permission.skill` takes per-skill patterns, the last
  matching rule winning (`skill: {"*": deny, <name>: allow}` resolved as
  such by `opencode debug agent`); `edit` and `bash` take patterns too,
  `webfetch` and `websearch` only a flat action;
- `opencode --agent <name>` starts a session with an agent, and the
  project config's `default_agent` must name a non-hidden `primary`
  agent; `instructions: [...]` in a project `opencode.json` loads files
  into every session;
- `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` skips the scans of
  `~/.claude/` and `~/.agents/` (whether it also skips a project's
  `.claude/skills/` is not documented).

**Not verified** (to check in the build, AG5):

- whether an OpenCode agent with `skill: deny` still sees the skills'
  names and descriptions in its context;
- whether OpenCode loads `CLAUDE.md`, `AGENTS.md`, or neither, without
  `instructions` (game-mode.md 3);
- whether OpenCode keeps any memory across sessions, as Claude Code's
  automatic memory does;
- whether OpenCode's interface lets a player switch a running session
  from one primary agent to the other, carrying the context across
  (GA18 assumes it can, and both agents refuse such a session).

**Claude Code** (documentation check relayed by the coordinator,
2026-11-19): an agent's `tools:` without `Skill` (or `Skill` in
`disallowedTools`) stops it invoking any skill; the `skills:` field
preloads skills and is no allow-list; `claude --agent <name>` runs the
main session under that agent's tools and model, its prompt replacing the
default system prompt, while `CLAUDE.md` and the project's automatic
memory still load; `skillOverrides` set to `"off"` hides a skill from the
model's listing and the `/` menu; `claude --settings <file>` applies
settings for one session; `autoMemoryEnabled: false` turns the automatic
memory off. Whether an agent session is still shown the skill listing is
not documented (AG5).

## 4. Starting each agent

| | Claude Code | OpenCode |
|---|---|---|
| The GM | `claude --agent game-master` | `opencode --agent game-master` |
| The game assistant | `claude --agent game-assistant --settings .claude/game-assistant.settings.json` | `opencode --agent game-assistant` |

Proposed (AG1): no `default_agent` and no `agent` setting in game mode,
so a session started plainly is neither, and each is started by name, as
`/game-master` is invoked today (D33). Both agent files' descriptions say
they run only when started by name and are never delegated to as
subagents (a development session's `Agent` tool would otherwise see
them). The OpenCode definitions are `mode: primary`.

## 5. The game assistant's definition

Proposed (AG2):

- **Claude Code**: `tools: Read, Write, Edit, Bash`. `Bash` for its reads
  on the bastion through the player's shared SSH connection and `curl`
  to the web front (game-assistant.md GA23); `Write` and `Edit` for its
  report and drafts; no `Skill`, no `Agent` (a subagent it spawned would
  bring its own, wider tools), no `WebFetch` or `WebSearch` (O289). The
  session settings file `.claude/game-assistant.settings.json` sets
  `skillOverrides` to `"off"` for `game-master`, `scenario-format`,
  `scenario-document`, `data-register` and `network-overview`, and
  `autoMemoryEnabled: false`; session-only, so the GM's sessions keep
  their helpers. It may also deny `Bash(psql:*)`, `Bash(docker:*)` and
  `Bash(tools/gmctl:*)` as speed bumps, the trust line unchanged.
- **OpenCode**: `mode: primary`; `permission`: `skill: deny`,
  `task: deny`, `webfetch: deny`, `websearch: deny` (O289); `read`,
  `glob`, `grep`, `list` allowed; `edit: {"*": ask, "play/**": allow}`,
  its default folder free and anything else asked (D554);
  `bash: {"*": allow, "psql*": deny, "docker*": deny, "*gmctl*": deny}`,
  the same speed bumps; `todowrite` allowed (its session list, not a
  file).

## 6. The GM's definition

Proposed (AG3):

- **Claude Code**: the GM's tools as its work needs them today (reading
  and writing scenario folders, `Bash` for `gmctl`, Docker and SSH,
  D29), with `Skill` for its helpers. An agent's `tools:` can't narrow
  `Skill` to some skills, so the GM may also invoke any user-level skill
  of the machine it runs on; its core file names the four it uses, on
  trust.
- **OpenCode**: `mode: primary`; `skill: {"*": deny,
  "scenario-format": allow, "scenario-document": allow,
  "data-register": allow, "network-overview": allow}`, verified as a
  form OpenCode resolves.
- **The core file and its skills** (AG4): today's
  `.claude/skills/game-master/` (`SKILL.md` 97 KB, `gmctl.md` 51 KB,
  `feedback.md` 12 KB) becomes the agent's core file, holding the stance
  every workflow shares (no reveals, stop only, the report as the only
  interaction, never speaking of the aging, UTC, the session rules),
  plus a skill per self-contained workflow (setup and deploy, a restart,
  taking the final answer and evaluating it, the feedback) and its
  references (`gmctl.md`). The split itself is the build's work.

## 7. Build impact

- **New**: the four agent files; `.claude/game-assistant.settings.json`;
  the GM's workflow skills split out of today's skill.
- **Changed**: `.claude/skills/game-master/` stops being a skill invoked
  as `/game-master`; every reference to `/game-master` (the specs, the
  bricks' GM documentation, the scenario documents' template, the
  player READMEs' hand-over wording, if any) is read again. v0.6 wave 3's
  chunk 13 is editing `.claude/skills/game-master/` now: the conversion
  is a v0.7 chunk, built after v0.6 is merged, never before.
- **Two dialects**: the build writes each definition twice and records
  the hand-kept rule where the agent files live (a `README.md` beside
  them, or the game-mode `CLAUDE.md`).
- **The check** (AG5, proposed): the v0.7 build, or its release gate,
  starts the assistant in each tool, asks it to list its skills and to
  invoke one of the GM's, and records what it sees; and does the same
  for the GM with a skill outside its four (OpenCode refuses it; Claude
  Code allows it, AG3). O282 closes on that record.
