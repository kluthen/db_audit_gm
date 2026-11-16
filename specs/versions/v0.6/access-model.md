# db_audit_gm v0.6 — Access model

Status: **consolidated on 2026-11-16 with the [master spec](master-spec.md)
it accompanies, for the owner's review; not yet approved.** Revises the
[v0.5 access model](../v0.5/access-model.md), which stays in force for
v0.6 games in everything this document does not change: its actors,
their assignment and lifecycle, its permission matrix, conditions,
denial behaviour, the fiction's access, the partners in the fiction,
its audited operations and its known gaps. This document states only
what v0.6 adds or changes; where they disagree, this one wins.

## 1. Purpose and scope

v0.6 changes two things about who may do what in one game:

- **The bastion's web front serves more**: a home page, a documentation
  site, a reports folder and a status page per partner, all behind the
  same basic authentication. No new route to any node, and none to a
  third party's node.
- **Fake aging adds GM-only knowledge** that the players must not reach
  during the game (that the game was fake-aged, its virtual timeline,
  the restart record), and a setup question to the initiator, who may
  also be a player.

The fiction's access (the customer's staff, roles and partners) is
unchanged.

## 2. Actors

Unchanged: `initiator`, `player`, `session-participant`, `gm`,
`network-visitor`. One clarification: **an initiator who will play is
treated as a `player` for everything the GM says during setup that
touches the aging** (section 6). The GM learns which by asking once, at
setup, whether the initiator will play.

The status pages' renderer on the bastion is not an actor: it acts only
as configured, for the `gm`, rendering what the GM delivered.

## 3. Role assignment and lifecycle

Unchanged. The `player` role still begins at hand-over with the bastion
password and the tools password; the documentation site, the reports
folder and the status pages are reached with the tools password, like
the rest of the front.

## 4. Resources and operations (new or changed)

| Resource | Operations |
|---|---|
| The home page (`/`) | `view` |
| The documentation site (`/docs/...`): the starter pack, the handouts (the network overview new among them), the player documentation of each brick the players may reach | `view` |
| The reports folder: `~/reports/` on the bastion, served at `/reports/` | `write` (on the bastion, as files in the home), `view` (through the front) |
| A partner's status page (`/status/<id>/`) | `view` |
| The partners' status file (the GM's, on the bastion; incidents to come included) | `read` |
| The true network overview (`gm/network-overview.yaml`) | `read`, `generate` |
| The network overview handout (`player/network-overview.md`, the bastion's copy) | `generate`, `read` |
| The restart record (`local/<playground>/fake-aging.yaml`) | `read`, `write` |
| The aging mode of a game (whether it is fake-aged, its virtual T0, its tail) | `know` |
| The fill, the maintenance restart, the history import | `run` |
| The bastion's tooling (`jq`, `tmux` added) | `use` |

## 5. Permission matrix (the changed rows)

| Resource and operation | `gm` | `initiator` (not playing) | `initiator` (playing) | `player` | `session-participant` | `network-visitor` |
|---|---|---|---|---|---|---|
| Home page, documentation site, status pages: `view` | yes | no¹ | after hand-over | yes | no¹ | no: basic authentication |
| Reports folder: `write` on the bastion | no² | no¹ | after hand-over | yes | no | no |
| Reports folder: `view` through the front | yes | no¹ | after hand-over | yes | no¹ | no |
| The partners' status file: `read` | yes | no | no | **no** | no | no |
| The true network overview: `read`, `generate` | yes | no | no | no | no | no |
| The network overview handout: `read` | yes | no¹ | after hand-over | yes | no¹ | no |
| The network overview handout: `edit` (their home copy) | no² | no | after hand-over | yes, their copy only; the page never changes | no | no |
| The restart record: `read`, `write` | yes | no | no | no | no | no |
| The aging mode: `know` | yes | **yes, may be told** | **no, during the game** | **no, during the game**; a reported tell may be explained after the final answer | no | no |
| The fill, the restart, the history import: `run` | yes | no | no | no | no | no |
| Bastion tooling, `jq` and `tmux` included: `use` | no² | no¹ | after hand-over | yes | no | no |

¹ Not a role's right: anyone holding the handed-over passwords is
acting as a `player`.
² The GM acts on the infrastructure, not as `player` on the bastion.

## 6. Conditions

- **The never-told rule.** Until the game is concluded (the final answer
  given and processed), nothing a `player` reads names the aging
  technique: no aging, fill, forged, virtual clock or fake, a restart's
  confirmation included. An initiator who may play is a `player` for
  this rule from the first setup question touching the aging: the GM
  offers a quick or an extended game by duration only. After the final
  answer, the teaching part of the feedback may explain a tell the
  report names; with none named, aging is not mentioned.
- **The status file is read by root only** on the bastion: it lists
  incidents still to come, and a player reading it would see the
  partner's future. The rendered pages show an incident only once its
  start has passed.
- **The reports folder serves only its own files**, read-only, with the
  sandbox header; a player's report never acts on another site of the
  front.
- **The documentation pages render the starter pack as handed over**,
  never the players' home copies: editing a home copy changes no page.
- **No page for a brick only a third party's nodes run**: the partners'
  nodes stay out of the starter pack and out of reach.

## 7. Denial behaviour

- A request to the front without the tools password: HTTP 401, as
  today.
- A path under `/reports/` outside the folder, or a missing file: 404.
- A status page for a third party without a player document, or a
  missing page: 404, as any unknown path.
- A route named `docs`, `reports` or `status` in a scenario: refused by
  the loader before deployment.
- A question about the aging from an initiator who may play, or from a
  player during the game: answered in-world only (the customer's
  servers were restarted for maintenance; older logs archived); never
  confirmed or denied.
- A fake game holding a `real-only` or unassessed fault: refused by
  `gmctl render`, naming the reason, before deployment.

## 8. Elevation, delegation and non-human actors

Unchanged, with one addition: the status pages' renderer runs as root
on the bastion, reads the GM's status file and writes only the front's
own files; it opens no connection to any node. The fill and the history
import run for the `gm` through `gmctl`, as the setup actions do.

## 9. Known gaps

v0.5's stand. v0.6 adds:

- The reports folder is in the player's home: a player may remove the
  front's read access to it and break their own Reports page. Their
  problem, as the report is.
- The fake game's documented limits (the restart's traces, the logs
  starting at the restart, the inode change times, the last-use times)
  are visible to a player with superuser access who hunts for them. By
  design: the bar is that a student doing the audit doesn't stumble on
  the fake, not that a hunting DBA can't prove it.

## 10. Changes from v0.5

- New resources: the home page, the documentation site, the reports
  folder, the status pages, the status file, the network overview (true
  and handout), the restart record, the aging mode as knowledge.
- The starter-pack page is replaced by the home page; the network
  overview joins the handouts.
- An initiator who may play is a `player` for the never-told rule from
  setup on.
- `jq` and `tmux` on the bastion.
