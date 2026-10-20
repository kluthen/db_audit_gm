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

**Pre-specification.** Nothing is built yet. The ideas, decisions and open
questions gathered so far are in [`precursor.md`](precursor.md), which is the
input for the specification work.

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

## Language

Everything in this repository (code, comments, documentation, commit
messages) is written in **English**.
