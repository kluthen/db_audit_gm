# db_audit_gm — Database Audit Game Master

A game of **live database audits**. An agent, the *game master*, builds a
realistic data stack on a Docker Swarm: databases, the applications and
jobs around them, backups, monitoring. It hands the stack over to the
players through a single bastion host, as a customer would hand its
systems over to a team of auditors.

The players do the auditor's job: map the system, check what the
monitoring says against what is really happening, find the issues the
customer already knows about and the ones nobody has noticed, fix what
they are allowed to fix, and write an audit report. The game master takes
the report and the players' final answer, evaluates them against the live
system, and gives feedback.

A game lasts up to about four hours, usually one scenario for a class,
sometimes one per student.

## The trust line

**This repository holds the game's answers.** Everything the game master
needs to set a game up and judge it is here, the game master's side of
every scenario included. Players don't read it: a player reads only what
the game hands over on the bastion, and what the game master gives them.
Some tampering can't be prevented in practice; what can't be enforced is
marked `DO NOT TAMPER`, and the players are trusted not to break the game.

## What you need

- Docker, with Swarm mode, on the machine or machines that run the game;
- Python 3 with PyYAML, and git;
- [Claude Code](https://claude.com/claude-code) or
  [OpenCode](https://opencode.ai), for the game master and the players'
  assistant.

## Starting a game

From a fresh clone of this repository, never from a checkout used for
anything else, start the game master by name, in a session of its own,
at the repository root:

```sh
git clone <this repository> db_audit_gm
cd db_audit_gm
tools/play gm
```

`tools/play gm` runs Claude Code as the game master; with OpenCode, run
`tools/play gm --opencode`, or `opencode --agent game-master`. The game
master picks or designs a scenario with you, sets the game up through
`tools/gmctl`, hands it over, keeps its stance during play, evaluates the
players' final answer, gives feedback and tears the game down.

A session started plainly is neither the game master nor the assistant:
each is started by name, and never handed work by another session.

## The players' assistant

The game assistant is an agent a player may run beside them: a
PostgreSQL DBA colleague who coaches the players through their audit,
with no knowledge of the game's answers. It never connects to a
database: it writes the SQL and the commands, and the players run them.
It never talks to the game master; the players' report reaches the game
master as ever.

**It runs on the player's side.** Each player runs it on their own
machine, from their own clone of this repository:

```sh
tools/play assistant
```

(`tools/play assistant --opencode`, or `opencode --agent game-assistant`,
with OpenCode). It runs in a session of its own, never the game
master's.

- A student playing alone runs it on their own machine, which also runs
  the game master.
- When one machine is run for the players (a teacher's), the assistant
  never runs there: each player runs it on their own machine and reaches
  the bastion over the network.
- On a classroom swarm of student laptops, each student runs it on their
  own laptop.

**The shared connection.** The bastion takes passwords only, and the
assistant is never given one. The player opens a shared SSH connection
in their own terminal, typing the password once (`<game>` is a label of
their choice):

```sh
ssh -M -S ~/.ssh/dbagm-<game>.sock -fN -p <port> player@<address>
```

The assistant runs each of its reads on the bastion through that
connection. It writes the players' report, its drafts and the tracking
files they ask for in the clone, under `play/` by default, never on the
bastion. The bastion's own documentation has a page on the assistant.

## Layout

| Path | What |
|---|---|
| `.claude/agents/`, `.opencode/agents/` | The game master and the game assistant, one definition per tool |
| `.claude/skills/` | The game master's workflow skills and helpers |
| `tools/play` | Starts the game master or the assistant |
| `tools/gmctl` | The game master's command line (code in `tools/gm/`) |
| `bricks/` | The nodes a game is built from, with their players' and game master's documentation |
| `domains/`, `purposes/`, `partners/` | The customers' businesses, the side uses of their data, and the third parties they deal with |
| `faults/` | The game master's catalogue |
| `scenarios/` | The playable scenarios, the game master's side included |
| `post_mortem/` | Summaries of public database incident reports, handed out after a game |
| `references/` | The audit grid |
