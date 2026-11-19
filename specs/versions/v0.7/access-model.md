# db_audit_gm v0.7 — Access model

Status: **approved by the owner on 2026-11-19** with the
[master spec](master-spec.md) it accompanies ("approved. you may merge.
ok"). Revises the [v0.6 access
model](../v0.6/access-model.md), which stays in force for v0.7 games in
everything this document does not change (and through it v0.5's, its
baseline). This document states only what v0.7 adds or changes; where
they disagree, this one wins.

## 1. Purpose and scope

v0.7 changes three things about who may do what:

- **A new actor, the game assistant**: an agent any player may start,
  with the player's own access, limited by its stance, not by the
  system.
- **The GM is an agent**, started by name; its rights are unchanged.
- **The repository has a game branch and a dev branch**: who changes
  `main`, and how.

The fiction's access (the customer's staff, roles and partners) is
unchanged.

## 2. Actors

v0.6's actors stand (`initiator`, `player`, `session-participant`, `gm`,
`network-visitor`), with one addition and one change:

| Actor | Definition | How acquired | Stacks? |
|---|---|---|---|
| `assistant` (new) | The game assistant agent (non-human), helping the players | Started by any player, by name, on the player's side: the player's own machine and clone, never the machine holding the GM's local implementation unless it is the player's own (master spec 6.3) | No: exclusive; it is never the `gm`, and a session is one or the other |
| `gm` (changed) | The GM agent (non-human), with what it runs as today | Started by the initiator, by name (`tools/play gm`, or the tool's agent selection), no longer by invoking a skill | No: exclusive |

The `assistant` acts within the access of the `player` who started it,
through the shared SSH connection that player opens; it is handed no
password. It is not a `session-participant` of the GM's session.

Not actors: the launcher (`tools/play`), which only writes a session's
settings and starts an agent; the `publish-main` skill, which acts for
the repository's owner on `dev`.

## 3. Role assignment and lifecycle

- The `assistant` exists from the moment a player starts it, for as long
  as its session; any number may run, in sessions of their own. Its use
  is from the hand-over to the final answer. Nothing grants or revokes
  it for a game: it is always available.
- The `gm` exists from the moment the initiator starts the GM agent, as
  the GM skill's invocation did before.
- On the repository: whoever holds the owner's word updates `main`, only
  through `publish-main`; pushes run only on the owner's word.

## 4. Resources and operations (new or changed)

| Resource | Operations |
|---|---|
| The bastion, as `player` (through the player's shared SSH connection) | `read` (the listings of the home and `~/reports/`, `~/report.md` and notes pointed to, `~/.bash_history`), `run` (other commands) |
| The secrets in the player's home (`~/.pgpass`, `~/.ssh/`), `~/.psql_history` | `read` |
| The web front's pages (home, `/docs/`, `/status/`, `/reports/`) | `view` |
| A database, any node beyond the bastion | `connect`, `run SQL` |
| The clone the assistant runs from: the starter pack, the handouts, the bricks' player documentation, the audit grid | `read` |
| The clone the assistant runs from: everything else (a scenario's GM side, `faults/`, the bricks' GM documentation, `tools/`, other agents and skills) | `read` |
| The assistant's drafts folder (`play/<game>/` by default) | `write` |
| The report | `write` (its drafts), `hand in` |
| The web | `search`, `fetch` |
| This project's public repository, its forks and mirrors | `fetch` |
| The GM's session | `talk to` |
| The GM's skills | `list`, `invoke` |
| `main` | `update`, `push` |

## 5. Permission matrix (the new and changed rows)

| Resource and operation | `gm` | `player` | `assistant` |
|---|---|---|---|
| Bastion as `player`: `read` its purview | no¹ | yes | yes, through the player's connection |
| Bastion as `player`: `run` other commands | no¹ | yes | **no, by stance**² |
| `~/.pgpass`, `~/.ssh/`, `~/.psql_history`: `read` | no¹ | yes | **no, by stance**² |
| Web front pages: `view` | yes | yes | **no, by stance**²: the partners' page carries credentials and the front needs the tools password; the player tells it what a page shows |
| `~/.bash_history`: `read` | no¹ | yes | yes, through a filter on the bastion that drops lines carrying credentials |
| `~/reports/`: `read` a report | no¹ | yes | only one made anonymised |
| A database, a node beyond the bastion: `connect`, `run SQL` | yes (its check role, as today) | yes | **no, by stance**² |
| The clone's player-side material: `read` | yes | yes | yes |
| The clone's GM side, other agents and skills: `read` | yes | trust line³ | **no, by stance**² |
| Drafts folder: `write` | no | yes | yes |
| The report: `hand in` | receives it | yes | **no** |
| The web: `search`, `fetch` | yes | yes | yes, nothing of the game in a query or URL² |
| This project's repository on the web: `fetch` | yes | trust line³ | **no, by stance**² |
| The GM's session: `talk to` | — | yes | **no** |
| The GM's skills: `list`, `invoke` | its own only | — | **no**⁴ |
| `main`: `update` | no | no | no |

¹ The GM acts on the infrastructure, not as `player` on the bastion.
² Within the player's access, the system would allow it; the
assistant's stance refuses it (trust in the assistant), and a player
asking for it is refused (trust in the players).
³ Players reading the repository is on the trust line, as since v0.1.
⁴ Enforced by its agent definitions: no skill tool on Claude Code,
`skill: deny` on OpenCode; the listing hidden by its session settings on
Claude Code.

`main` is updated only by `publish-main` on the owner's word; it is not
a game role.

## 6. Conditions

- **The assistant's purview** is its stance: what serves the players'
  audit, read as a colleague over their shoulder would; never a secret,
  never a database, never the GM's side.
- **Nothing of the game leaves** in the assistant's web queries or URLs:
  no value, schema, host name, address, customer or partner name,
  credential or log line.
- **One agent per session**: a session started as the assistant is never
  the GM's, and the reverse; each refuses a session holding the other's
  work.
- **The never-told rule** (v0.6) binds the assistant as it binds what
  players read: it never names the aging technique, never confirms or
  denies a forged history.

## 7. Denial behaviour

- A player asks the assistant to run a query, connect to a node, read a
  secret or the GM's side: it declines in one sentence, says why (its
  purview), and offers what it can do instead (the query written for the
  player to run, the evidence to look for).
- A player asks it to hand in the report, end, stop or restart the game:
  it sends them to the GM's session.
- A player pastes customer material: the graded reminder (master spec
  6.9); it still helps.
- The assistant tries to invoke a skill: refused by its tool (the skill
  tool absent, or denied); on Claude Code, a hidden skill invoked by name
  returns the settings' refusal.
- `tools/play` run on `dev`: refused, naming that a game is played from
  a clone of `main`.
- `publish-main`'s check fails: nothing is committed to `main`, the
  failures listed.

## 8. Elevation, delegation and non-human actors

- The `assistant` is a non-human actor acting for the players, with
  their access and the credentials they give it; it holds no credential
  of its own. It spawns no subagent (none allowed in its definitions).
- The `gm` is unchanged; it is never delegated to as a subagent from
  another session.

## 9. Known gaps

v0.6's stand. v0.7 adds:

- **The assistant's limits are its stance.** With the player's access it
  could read `~/.pgpass`, connect to a database, read the GM's side of
  the clone or fetch the public answer keys; nothing in the system
  stops it. Accepted on the two trust lines, like the players' own
  access to the repository.
- **The machine it runs on.** Its shell runs as that machine's user. On
  the student's own machine in solo play, that machine also holds the
  GM's local implementation and the playground's Docker: more than the
  player's access, on the trust line the student is already on. Run on
  a teacher's machine operated for the players, it would reach the
  GM's side and the infrastructure; the rule is that it never runs
  there (master spec 6.3), nothing enforces it.
- **OpenCode's memory**, if the build finds OpenCode keeps one and offers
  no setting to turn it off: the rule against writing game data to it
  stands on trust (master spec 7.7).
- **The speed bumps are partial**: the denied commands (`psql`,
  `docker`, `gmctl`) stop the obvious forms only.
- **Plugin skills** are not hidden by the GM's session settings on
  Claude Code; the launcher warns about them.
- **The skills' listing** in an agent session is settled by the build's
  check, not by documentation.

## 10. Changes from v0.6

- New actor: `assistant`, with its rows above.
- The `gm` is an agent started by name.
- `main` is the game branch, updated only through `publish-main`; pushes
  on the owner's word.
