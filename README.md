# db_audit_gm — Database Audit Game Master

A generator of **live database audit exercises**. An agent (the *game
master*) assembles a realistic data stack — producers, databases,
transformers, consumers, backup and monitoring tools — on a Docker Swarm,
plants a set of issues in it, ages it so that those issues leave traces, and
hands it over to a student (the *player*) through a single bastion host.

The player's job is the auditor's job: map the system, check what the
monitoring says against what is really happening, find the issues the
customer already knows about, discover the ones nobody has noticed, fix what
they are allowed to fix, and write an audit report.

## Status

**v0.1 released** (2026-10-21): one static PostgreSQL scenario, played end
to end with a GM session. v0.2 (monitoring and the usual tooling) is in
drafting. The specification is in [`specs/`](specs/README.md), the roadmap
in [`specs/versions/`](specs/versions/README.md), and v0.1's release notes
in [`specs/versions/v0.1/README.md`](specs/versions/v0.1/README.md).

| Path | What |
|---|---|
| [`tools/gmctl`](tools/gmctl) | The GM's command line: fit, render, deploy, load data, inject, validate, check, status, teardown |
| [`bricks/`](bricks/) | Node definitions: `postgres` and `bastion` |
| [`faults/`](faults/) | The fault catalog |
| [`scenarios/`](scenarios/) | Scenario folders (`bookshop-new-server`) |
| [`.claude/skills/`](.claude/skills/) | The `game-master`, `scenario-format` and `scenario-document` skills |

To play, open a Claude Code session at the repository root and run
`/game-master`.

## Core ideas

- **Scenarios, not a fixed lab.** Each scenario is generated from a teacher's
  brief (background story, required incidents, whether the agent may add
  more), then frozen into a manifest and a sealed answer key so it can be
  redeployed identically.
- **A growing catalog of bricks.** The repository holds Dockerfiles,
  configurations and documentation for clean and faulty nodes: several
  database engines and versions, backup tools, monitoring, pipelines (e.g.
  dbt + DuckDB). The agent picks bricks from the catalog or builds new ones
  that follow the brick contract.
- **Constrained resources.** Every scenario must fit in the cluster's CPU and
  memory budget. Databases are deliberately nerfed; the player's tuning must
  stay within published bounds, checked by a validator on each node.
- **Bastion only.** The player never touches the swarm. They get SSH access
  to the bastion and, from there, legal access to every node of the
  topology, with write access only where fixing is part of the exercise.
- **Trust, documented.** Some tampering cannot be prevented in practice. What
  can't be enforced is clearly marked (`DO NOT TAMPER`), and the players are
  trusted not to break the game.
- **Sessions of up to 4 hours**, usually one scenario per class, sometimes one
  per student.

