# v0.1 — archive

Status: archived 2026-10-21. v0.1 was released on 2026-10-21 and merged
into `main` at 3c852e1. Live summary: the
[v0.1 page](../../versions/v0.1/README.md) and its release notes.

## Archived files

Kept verbatim; never edited after this pass.

| File | Purpose |
|---|---|
| [build-plan.md](build-plan.md) | The v0.1 build plan, v6: ten chunks in three waves, the gates G1 to G5, the release gate. Fully executed |
| [decisions-D1-D54.md](decisions-D1-D54.md) | The decisions log from the seeding of the tree to the release close, D1 to D54 |
| [open-questions-resolved.md](open-questions-resolved.md) | The open-questions register's "Resolved" table at v0.1 close: which decision resolved each closed question |

## Where it now lives

Every archived decision is stated as fact in a live document. Paths are
relative to `specs/`. "History" marks wording a later decision replaced.

| ID | Ruling | Now lives in |
|---|---|---|
| D1 | `specs/` is the only expression of intent | `README.md` (opening paragraph, "History"). Still pending: removing `precursor.md`, carried to `README.md` "Next steps" |
| D2 | Small project; no ATD, no UI/UX tree | `README.md` "Status snapshot"; `concept.md` "Scope" |
| D3 | Tree shape: actors in `concept.md`, rights in `planes-and-access.md` | `README.md` "Tree shape" (written at this archive) |
| D4 | v0.1 and v1.0 | `versions/README.md`; `concept.md` "Versions" |
| D5 | Formats enforced by one skill plus templates | `formats.md` "Enforcement" |
| D6 | The GM is the agent | `concept.md` "Actors" |
| D7 | Hosting is a setup input | `platform.md` "Hosting" |
| D8 | One game, one report | `scenario-lifecycle.md` |
| D9 | Grading left to the GM; four expected resolutions | `gm-stance.md` |
| D10 | Validators may be red from the start | `planes-and-access.md` "Rules and validators" |
| D11 | Scenario content delivery, option C | `platform.md` "Delivering scenario content" |
| D12 | Swarm first; Linux-only multi-host swarms | `platform.md` "Hosting", "Portability" |
| D13 | Light enforcement of secrecy | `planes-and-access.md` "Trust"; `formats.md` "Scenario" |
| D14 | v0.1 is a static database | `versions/v0.1/README.md`; `versions/v0.1/master-spec.md` section 2 |
| D15 | v0.1's goal; no monitoring in v0.1 | `versions/v0.1/README.md` "Goal"; `gm-stance.md` |
| D16 | The playground is the only required input | `scenario-lifecycle.md` "Setup inputs and the brief"; `gm-stance.md` "At setup" |
| D17 | v0.1 defects limited to the database and its configuration | `bricks-and-faults.md` "Future ideas: backup tooling"; `versions/v0.1/README.md` |
| D18 | The report is the players' only interaction | `gm-stance.md` "During the game", "Future ideas" |
| D19 | No hints, node resets or extra time | `gm-stance.md` |
| D20 | The scenario document's template belongs to the GM | `formats.md` "Scenario" |
| D21 | Skills and templates start in v0.1 and evolve | `formats.md` "Enforcement"; `versions/v0.1/README.md` |
| D22 | Kubernetes portability is a requirement | `platform.md` "Portability"; `formats.md` "Brick definition" |
| D23 | A scenario is a self-sufficient folder (amended by D24) | `formats.md` "Scenario", "Local implementation" |
| D24 | Scenarios reference the catalog | `formats.md` "Scenario" |
| D25 | Limited `sudo` for the player | `planes-and-access.md` "Node hardening" |
| D26 | The GM uses an existing swarm, or sets one up | `platform.md` "Hosting"; `gm-stance.md` |
| D27 | The GM reaches each host's engine over SSH | `platform.md` |
| D28 | Checks are per brick | `formats.md` "Brick definition"; the reading to confirm stays open as O20 |
| D29 | GM permissions and skills home | `gm-stance.md` |
| D30 | s6-overlay is the node supervisor | `planes-and-access.md` "Node hardening". History: its "tmpfs `/run`" is replaced by D55 |
| D31 | Player credentials, both hops | `planes-and-access.md` "Credentials and the way in"; "nothing written to the repository" narrowed by D45 (`versions/v0.1/README.md` "Per-game credentials") |
| D32 | v0.1 limits and envelopes are absolute | `formats.md` "Local implementation" |
| D33 | v0.1 artifacts and the script/agent split | `versions/v0.1/README.md` "Artifacts"; `versions/v0.1/master-spec.md` section 11 |
| D34 | Player access to the database node | `planes-and-access.md` "The database node" |
| D35 | v0.1 scope cuts | `versions/v0.1/README.md` "Not needed for v0.1" |
| D36 | Game naming, teardown, failures | `scenario-lifecycle.md`; `versions/v0.1/master-spec.md` section 12 |
| D37 | PostgreSQL 18 on Debian 13 | `versions/v0.1/README.md` "Artifacts"; `versions/v0.1/master-spec.md` section 9.1 |
| D38 | A testable stance; a play-through instead of the probe | `versions/v0.1/README.md` "Definition of done" |
| D39 | Session practice and data | `gm-stance.md`; `platform.md` "Delivering scenario content" |
| D40 | Authority inside the scenario folder | `formats.md` "Scenario" |
| D41 | v0.1 hardening | `planes-and-access.md` "Node hardening". History: its "tmpfs `/run`" is replaced by D55 |
| D42 | Proposed items v0.1 relies on, accepted | `planes-and-access.md` "Planes"; `formats.md` "Layout", "Local implementation"; `versions/v0.1/README.md` |
| D43 | Script contracts | `formats.md` "Script contracts"; `versions/v0.1/master-spec.md` section 8.1 |
| D44 | The v0.1 master spec and access model are approved | `versions/v0.1/master-spec.md` status line; `versions/v0.1/README.md` |
| D45 | Build-level details | `versions/v0.1/master-spec.md` sections 9 to 11 and 15; `versions/v0.1/README.md` "Per-game credentials" |
| D46 | Three clarifications before wave 1 | `versions/v0.1/master-spec.md` sections 8.1, 9.1, 10.1, 11 |
| D47 | The roadmap to v1.0 | `versions/README.md` |
| D48 | Customer role-play and hints are beyond v1.0 | `versions/README.md`; `versions/v1.0/README.md`; `gm-stance.md` "Future ideas" |
| D49 | `gmctl status --set` for the GM-only stages | `versions/v0.1/README.md` "What v0.1 delivers"; `versions/v0.1/wave-log.md` capture W3-A |
| D50 | A stop's reason through `gmctl teardown --reason` | `versions/v0.1/master-spec.md` section 11 |
| D51 | `fit` may start a new game after a torn-down failed one | `versions/v0.1/README.md` "What v0.1 delivers" |
| D52 | Master spec 8.1 clarified for the data load | `versions/v0.1/master-spec.md` section 8.1; `formats.md` "Script contracts" |
| D53 | Master spec 17 item 4 clarified | `versions/v0.1/master-spec.md` section 17 |
| D54 | The seed marker leaves the group-writable directory | `versions/v0.1/master-spec.md` section 9.1; `platform.md` "Delivering scenario content"; `planes-and-access.md` "Node hardening" |

Resolved questions, each living where its deciding decision lives (row
above):

| Questions | Resolved by |
|---|---|
| O1 | D4 |
| O3 | D29 |
| O4 | D6 |
| O6 | D7 |
| O7 | D8 |
| O8 | D11 |
| O9 | D30 |
| O14 | D31 |
| O15 | D25 |
| O17, O18 | D10 |
| O19 | D32 |
| O26, O27 | D9 |
| O28 | D19 |
| O33 | D14, D15 |
| O34 | D26 |
| O35 | D27 |
| O36 | D13 |
| O37 | D28 |
| O39 | D20 |
| O40 | D22 |
| O41 | D17 |
| O42 | D18 |
| O43 | D23 |
| O44 | D24 |
| O55 | D54 |

## Left in place

| Document | Role | Referrers |
|---|---|---|
| `specs/versions/v0.1/README.md` | The version's page: scope, definition of done, release notes and known issues RG-3, RG-4 | `specs/README.md`, `specs/versions/README.md`, `specs/concept.md`, `specs/versions/v1.0/README.md`, archived decisions |
| `specs/versions/v0.1/master-spec.md` | The contract for what v0.1 built; the skills' stated source | `.claude/skills/game-master/SKILL.md`, `.claude/skills/scenario-format/SKILL.md`, `.claude/skills/scenario-document/SKILL.md`, `bricks/*/brick.yaml`, `specs/README.md` |
| `specs/versions/v0.1/access-model.md` | The master spec's companion; still in force for the v0.1 game | `.claude/skills/game-master/SKILL.md`, `specs/open-questions.md` (O45) |
| `specs/versions/v0.1/wave-log.md` | Execution record, but its captures (W1-A to W3-B) fix the `gmctl` command lines, brick paths and `brick.yaml` keys | `tools/gm/checks.py`, `tools/gm/inject.py`, `tools/gm/localimpl.py`, `bricks/*/brick.yaml`, `.claude/skills/game-master/SKILL.md`, `.claude/skills/game-master/gmctl.md`, `.claude/skills/scenario-format/SKILL.md` and its `brick.yaml` template |

## Carried forward

- Every open question stays live in
  [open-questions.md](../../open-questions.md) with its ID: O2, O5, O10 to
  O13, O16, O20 to O25, O29 to O32, O38, O45 to O54.
- Known issues RG-3 and RG-4, kept open by the owner: in the
  [v0.1 page](../../versions/v0.1/README.md), "Known issues".
- Removing `precursor.md` (D1): in [README.md](../../README.md), "Next
  steps", for the owner.
