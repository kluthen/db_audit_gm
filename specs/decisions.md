# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

- **D1 (2026-10-20, rewritten the same day at the owner's request):
  `specs/` is the only expression of intent.** The owner's pre-spec notes
  (`precursor.md`, to be removed) were a draft, including the items they
  marked as decided. Everything still needed from them now lives in
  `specs/`; nothing here depends on them. Statements of fact in the topic
  docs are the current intent; `(proposed)` items await the owner's
  confirmation. Now in: [README](README.md).
- **D2 (2026-10-20): Owner constraints on the project and its
  documentation.** The project is small: scripts and small apps. No ATD and
  nothing shaped like it (a lighter intent record is O5). No designed player
  interface and no UI/UX design tree: players report their findings
  directly to the game master at the end of the session (form: O26). Now
  in: [concept.md](concept.md) "Scope", [README](README.md).
- **D3 (2026-10-20): Tree shape for the drafting phase.** Five topic docs
  plus the registers. Actors are a short section of
  [concept.md](concept.md) rather than a `personas.md`, since there is no
  interface to design. Their rights live in
  [planes-and-access.md](planes-and-access.md), because who reaches what is
  a game mechanic here; that document becomes the master spec's access
  model companion at consolidation. Rejected: a separate personas and
  access model now (duplication for a three-actor project). The owner may
  overturn this. Now in: [README](README.md).
- **D4 (2026-10-20): v0.1 and v1.0.** v0.1, the first milestone (wave 1),
  is a single hand-specified PostgreSQL node scenario, end to end. v1.0,
  the first release, is the full pipeline (producer -> database ->
  transformation -> database -> consumer, plus monitoring and the bastion).
  The formats express the v1.0 pipeline from the start. Closes O1. Now in:
  [versions/README.md](versions/README.md).
- **D5 (2026-10-20): Scenario format, brick and fault definitions, enforced
  by one skill plus templates.** The specs state what each must contain;
  writing the skill and templates is a future build item. Now in:
  [formats.md](formats.md).
- **D6 (2026-10-20): The GM is the agent.** The teacher only provides
  inputs at the start, then is out of the game. Anyone may ask the GM to
  stop the game and turn off the containers. A student may play alone, with
  the GM designing the exercise. Closes O4. Now in:
  [concept.md](concept.md) "Actors".
- **D7 (2026-10-20): Hosting is a setup input.** Among its first questions
  the GM asks where the game takes place (swarm hosts, access keys).
  Targets: a single laptop, a student's home network, a classroom of
  student laptops joined into one swarm. Closes O6. Now in:
  [platform.md](platform.md) "Hosting".
- **D8 (2026-10-20): One game, one report.** Who sits behind a report (one
  student or twenty) is outside the project's and the GM's concern, so
  per-student grading on a shared deployment is not a problem to solve.
  Closes O7. Now in: [scenario-lifecycle.md](scenario-lifecycle.md).
- **D9 (2026-10-20, amended the same day, arbitrated by the lead under the
  owner's delegation): Grading is left to the GM.** Issues given (possibly
  none) each state one of four expected resolutions: *report*, *propose* (a
  concrete fix, not applied), *fix*, *improve*. The player reports by file,
  discussion or both and states the answer is final (the GM asks if not);
  the GM gives positive, teacher-style feedback. Closes O26, O27. Now in:
  [gm-stance.md](gm-stance.md).
- **D10 (2026-10-20): Validators may be red from the start.** Validators
  are not monitoring tools; a validator the player cannot make green is a
  defect to report, handled by the GM; health information from monitoring
  is fair game. Closes O17, O18. Now in:
  [planes-and-access.md](planes-and-access.md) "Rules and validators".
- **D11 (2026-10-20): Scenario content delivery, option C.** Generic brick
  images; scenario files as versioned Swarm configs, seeded once into a
  pinned named volume; protected files mounted read-only from configs;
  state faults planted by the GM during aging. Closes O8. Now in:
  [platform.md](platform.md) "Delivering scenario content".
- **D12 (2026-10-20): Swarm first, stay adaptable; Linux-only multi-host
  swarms.** Swarm is the starting platform, not a commitment. Multi-host
  swarms use Linux hosts (or bridged Linux VMs) only, since Docker Desktop
  can't join one. O34 stays open for how the swarm gets created. Now in:
  [platform.md](platform.md) "Hosting", "Portability".
- **D13 (2026-10-20): Light enforcement of secrecy.** The GM reveals no
  answers before the final answer and takes no action but stopping the
  game. The repository holds scenarios in bulk; reading it is like reading
  a textbook. Each scenario is a standalone document with a prominent "do
  not read" warning, and nothing more. Closes O36. Now in:
  [planes-and-access.md](planes-and-access.md) "Trust",
  [formats.md](formats.md) "Scenario".
- **D14 (2026-10-20): v0.1 is a static database.** The equivalent of a
  snapshot or a restored backup, with no load producer; its definition of
  done is settled. Whether it has monitoring stays open (O33). Now in:
  [versions/v0.1/README.md](versions/v0.1/README.md).
- **D15 (2026-10-20): v0.1's goal, and no monitoring in v0.1.** v0.1 settles
  the GM stance on one simple scenario: a static PostgreSQL database
  investigated for specific defects, with the player reporting, proposing
  or enacting configuration fixes as each issue asks. Closes O33. Now in:
  [versions/v0.1/README.md](versions/v0.1/README.md),
  [gm-stance.md](gm-stance.md).
- **D16 (2026-10-20): The playground is the only required input.** At setup
  the GM must know the swarm, its hosts and the capacity available (CPU,
  RAM, disk). Topology, story, data schema and the like are optional
  initiator inputs, possibly sketched or left out; the GM fills the blanks
  and sizes the setup to the capacity. Replaces the reading that the whole
  topology is a fixed declarative definition. Narrows O2 and O34. Now in:
  [scenario-lifecycle.md](scenario-lifecycle.md) "Setup inputs and the
  brief", [gm-stance.md](gm-stance.md) "At setup".
- **D17 (2026-10-20): v0.1 defects are limited to the restored database and
  its configuration.** Backup-tooling defects (wrong backup configuration,
  restore succeeds but integration fails, restore fails with the backup file
  present and pointed out) are future fault families needing more
  investigation. Closes O41. Now in:
  [bricks-and-faults.md](bricks-and-faults.md) "Future ideas: backup
  tooling", [versions/v0.1/README.md](versions/v0.1/README.md).
- **D18 (2026-10-20): In v0.1 the players' only interaction with the GM is
  the report** (plus asking to stop). The GM answering in character as the
  customer is a future idea. Closes O42. Now in:
  [gm-stance.md](gm-stance.md) "During the game", "Future ideas".
- **D19 (2026-10-20): No hints, node resets or extra time for now.** Kept
  as a future idea. Closes O28. Now in: [gm-stance.md](gm-stance.md).
- **D20 (2026-10-20, amended the same day to the owner's clarification):
  The scenario document's detailed template belongs to the GM.** The GM
  generates it with its own skill and template; it holds the full setup of
  the exercise, to ground the GM after a session restart and to re-deploy
  the scenario on another playground. What a scenario must contain is still
  stated in this spec (the owner had read "not spec-writer's job" as "not
  in specs/"); its "do not read" warning stays required (D13). Closes O39.
  Now in: [formats.md](formats.md) "Scenario".
- **D21 (2026-10-20): Skills and templates start in v0.1 and evolve.** The
  format skill and templates and the GM's scenario-document skill and
  template ship in initial versions in v0.1, explicitly expected to evolve.
  Narrows O37 to the machine check. Now in: [formats.md](formats.md)
  "Enforcement", [versions/v0.1/README.md](versions/v0.1/README.md).
- **D22 (2026-10-20): Kubernetes portability is a requirement.** The
  portability hedges are adopted (rendered stack files, named platform
  verbs, Swarm-agnostic bricks, Kubernetes-valid names, idempotent
  stdin-streamed injection, registry-qualified images, no reliance on the
  routing mesh). Closes O40. Now in: [platform.md](platform.md)
  "Portability", [formats.md](formats.md) "Brick definition".
- **D23 (2026-10-20, amended the same day by D24): A scenario is a
  self-sufficient folder, deployed through a local implementation.** The
  folder is the source of truth: with the full repository (its catalog) and
  the GM persona and skills, it is enough to start the exercise. It holds
  the scenario information, a clear topology, the background, the defects,
  and the host topology it was designed for. At deployment the GM generates
  a local implementation mapping the real playground onto it; if capacity
  is insufficient, the GM says so instead of deploying. Closes O43. Now in:
  [formats.md](formats.md) "Scenario", "Local implementation".
- **D24 (2026-10-20): Scenarios reference the catalog.** Shared bricks and
  fault definitions live in the catalog; the scenario folder references
  them by id and pinned version and needs the full repository. A brick or
  fault made solely for one scenario may live inside that scenario's
  folder. Closes O44. Now in: [formats.md](formats.md) "Scenario".
- **D25 (2026-10-20): Limited `sudo` for the player.** Nodes where the player
  needs `sudo` wrappers do not use `no-new-privileges` (nor, on Kubernetes,
  `allowPrivilegeEscalation: false`). Closes O15. Now in:
  [planes-and-access.md](planes-and-access.md) "Node hardening".
- **D26 (2026-10-20): The GM uses an existing swarm, or sets one up.** If
  none exists, it creates one when given sufficient access keys, and
  otherwise guides the user through setting it up. Closes O34. Now in:
  [platform.md](platform.md) "Hosting", [gm-stance.md](gm-stance.md).
- **D27 (2026-10-20): The GM reaches each host's engine over SSH** (SSH
  Docker contexts or the equivalent), inside the "exec in a node" verb.
  Closes O35. Now in: [platform.md](platform.md).
- **D28 (2026-10-20): Checks are per brick.** A brick may ship companion
  material (information, scripts, tools) to help its integration and use,
  including its own checks. Reading, to confirm (O20): no project-wide
  mandatory machine check, the format skill included. Closes O37. Now in:
  [formats.md](formats.md) "Brick definition".
- **D29 (arbitrated by the lead under the owner's delegation, 2026-10-20): GM permissions and skills home.** Skills live in
  `.claude/skills/` (opencode reads it too). The GM may read and write
  scenario folders, use the Docker CLI, and reach hosts over SSH with the
  keys given at setup; "nothing else" is trust, not enforcement (D13).
  Closes O3. Now in: [gm-stance.md](gm-stance.md).
- **D30 (arbitrated by the lead under the owner's delegation, 2026-10-20): s6-overlay is the node supervisor**, with
  `S6_READ_ONLY_ROOT` and a tmpfs `/run`. Closes O9. Now in:
  [planes-and-access.md](planes-and-access.md) "Node hardening".
- **D31 (arbitrated by the lead under the owner's delegation, 2026-10-20): Player credentials, both hops.** A per-game bastion password
  handed over by the GM; a per-game key pair for the bastion-to-node hop as
  user `player`, private key in the player's bastion home, both halves as
  Swarm secrets; nothing written to the repository. Closes O14. Now in:
  [planes-and-access.md](planes-and-access.md) "Player access to nodes".
- **D32 (arbitrated by the lead under the owner's delegation, 2026-10-20): v0.1 limits and envelopes are absolute.** The brick declares
  a default envelope, the scenario fixes the (nerfed) limits and may tighten
  envelopes; the local implementation only checks they fit, never
  recomputes them, since recomputing could turn a planted out-of-bounds
  value into an in-bounds one. Relative rules wait for later versions.
  Closes O19. Now in: [formats.md](formats.md) "Local implementation".
- **D33 (arbitrated by the lead under the owner's delegation, 2026-10-20): v0.1 artifacts and the script/agent split.** Seven artifacts:
  the GM skill (explicitly invoked), the format skill, the scenario-document
  skill, a minimal script set (renderer, capacity check, platform verbs,
  in-node validator, sealed-check runner, stdin-fed injection), the
  PostgreSQL brick, the bastion brick, the v0.1 scenario. Host scripts in
  Python 3 (standard library plus PyYAML), node scripts in POSIX shell.
  Scripts do rendering, checks, verbs, validators, injection; the agent does
  the dialogue, local-implementation choices within what scripts accept,
  evaluation and feedback. O2 stays open for later versions. Now in:
  [versions/v0.1/README.md](versions/v0.1/README.md) "Artifacts".
- **D34 (arbitrated by the lead under the owner's delegation, 2026-10-20): Player access to the database node.** SSH as `player` from
  the bastion; a PostgreSQL superuser role `dba`; `postgresql.conf` and
  `pg_hba.conf` outside PGDATA, owned by `postgres`, group-writable by the
  player's group on fixable nodes; reload and restart through `sudo`
  wrappers; `ALTER SYSTEM` is a legitimate fix, and sealed checks judge the
  effective live setting. Now in:
  [planes-and-access.md](planes-and-access.md) "Player access to nodes".
- **D35 (arbitrated by the lead under the owner's delegation, 2026-10-20): v0.1 scope cuts.** One host (the manager the GM targets),
  local images, no registry; swarm setup limited to a local `docker swarm
  init` or guiding the user. Producers and consumers are v1.0+. Deferred,
  not deleted: multi-host, the registry, per-host SSH contexts, remote swarm
  creation, "Beyond the hedges", computed envelopes, `no-new-privileges`
  through the API, hash checks on read-only mounts. `brick.yaml` fields with
  no v0.1 use become optional. Now in:
  [versions/v0.1/README.md](versions/v0.1/README.md).
- **D36 (arbitrated by the lead under the owner's delegation, 2026-10-20): Game naming, teardown, failures.** Volumes, configs,
  secrets and networks are named per game id; teardown removes everything
  carrying the game's stack label, volumes included, not images or the
  swarm. On any setup failure, or a stop during setup, the GM reports it,
  tears down what it deployed, and records the stage reached in `local/`.
  Now in: [scenario-lifecycle.md](scenario-lifecycle.md).
- **D37 (arbitrated by the lead under the owner's delegation, 2026-10-20): PostgreSQL 18 on Debian 13 (trixie).** Now in:
  [versions/v0.1/README.md](versions/v0.1/README.md).
- **D38 (arbitrated by the lead under the owner's delegation, 2026-10-20): A testable stance, and a play-through instead of the
  probe.** v0.1's definition of done checks the stance with a scripted
  list (hint, reveal and reset refused; non-final report questioned; stop
  obeyed with teardown; feedback content) and a manual play-through as
  `player` confirming each fault's evidence. The probe field in
  `fault.yaml` is descriptive in v0.1. Feedback tone stays an owner
  judgement at acceptance. Now in:
  [versions/v0.1/README.md](versions/v0.1/README.md).
- **D39 (arbitrated by the lead under the owner's delegation, 2026-10-20): Session practice and data.** Recommended, not enforced: the
  setup session ends at hand-over and the report is taken in a fresh GM
  session. The report is pasted in the session or left in `~/report.md` on
  the bastion. Restored-backup data is streamed as SQL through the
  injection path before faults are planted; v0.1 plants state faults right
  after deployment. Now in: [gm-stance.md](gm-stance.md),
  [platform.md](platform.md) "Delivering scenario content".
- **D40 (arbitrated by the lead under the owner's delegation, 2026-10-20): Authority inside the scenario folder.** `scenario.yaml` and
  `answer-key.yaml` are authoritative; the scenario document is generated
  from them by its skill. The format skill flags missing items and the GM
  refuses to deploy an incomplete scenario. `local/` is git-ignored (a
  build item). Now in: [formats.md](formats.md) "Scenario".
- **D41 (arbitrated by the lead under the owner's delegation, 2026-10-20): v0.1 hardening.** Capabilities: drop all, add back per
  brick, listed in `brick.yaml`. A read-only root needs a tmpfs `/run` and a
  writable target for `sudo`'s log. `no-new-privileges` is not set in v0.1.
  Now in: [planes-and-access.md](planes-and-access.md) "Node hardening".
- **D42 (arbitrated by the lead under the owner's delegation, 2026-10-20): Proposed items v0.1 relies on, accepted.** The three planes
  and write policies; the scenario folder layout and `local/<playground>/`;
  the platform-neutral brick details; the companion material layout; the
  restart item; no solvability probe in v0.1. Now in: the documents
  concerned.
- **D43 (2026-10-20, set by spec-writer at consolidation, for the lead to
  revisit): Script contracts.** Injection, sealed-check and validator
  scripts are POSIX shell fed on stdin to `sh -s` in the container, with
  parameters as environment variables and fixed exit codes (0 / 1 / other).
  Fixed so the scripts, faults and GM skill agree. Now in:
  [formats.md](formats.md) "Script contracts".
- **D44 (2026-10-20, approved by the lead under the owner's delegation):
  The v0.1 master spec and access model are approved.** The owner may
  revisit any point. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md),
  [versions/v0.1/access-model.md](versions/v0.1/access-model.md).
- **D45 (2026-10-20, set by spec-writer at consolidation, for the lead to
  revisit): Build-level details.** The `gmctl` subcommand set; the
  bastion's default published port 2222; per-game credentials kept in the
  git-ignored `local/<playground>/secrets/` (mode 0600) so a restarted GM
  can hand them over again; a `dba` password delivered as a secret into
  `.pgpass`; the GM's `local all postgres peer` line in `pg_hba.conf`,
  marked DO NOT TAMPER and checked by the validator; image names with a
  non-Hub registry host, deployed without resolving; the candidate defect
  list, with the lead's review of the final choice. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md) sections
  9 to 11 and 15.
- **D46 (2026-10-20, set by spec-writer from the reviewer's non-blocking
  findings, before wave 1): Three clarifications of the v0.1 master spec.**
  `gmctl deploy` creates configs and secrets itself, labelled with the game
  id and external in the stack file, so label-based teardown finds them;
  the validator reads a per-game envelope file delivered as a protected
  config; sealed checks query PostgreSQL as `postgres` (`runuser -u
  postgres`) for peer authentication. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md) sections
  8.1, 9.1, 10.1, 11.
- **D47 (2026-10-20, set by the owner, relayed by the lead): The roadmap
  to v1.0.** v0.2 monitoring and usual tooling; v0.3 producers and
  consumers; v0.4 transformers; v0.5 research and broadening (more known
  issues, pre-planned topology parts, common schemas and datasets, Bluebox
  or internet sources). The owner believes v0.2–v0.5 suffice for v1.0.
  Beyond v1.0: TimescaleDB, columnar databases, MySQL and other databases.
  Gaps and risks it raises are O46–O54. Now in:
  [versions/README.md](versions/README.md).
- **D48 (2026-10-20, set by the owner, relayed by the lead): Customer
  role-play and hints are beyond v1.0.** The GM playing the customer
  during the game, and the GM giving hints (with node resets and extra
  time), are out of v1.0 scope; both stay future ideas. Now in:
  [versions/README.md](versions/README.md),
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [gm-stance.md](gm-stance.md) "Future ideas".
- **D49 (2026-10-20, set by spec-writer at the wave driver's request,
  wave 3 start): `gmctl status --set` records the GM-only stages.**
  `handed-over`, `final-answer` and `feedback-given` are reached by no
  script, so `status` gains `--set`; it stays within master spec 11's
  "`status` — the game's recorded state" and section 12's stages, so the
  master spec is unchanged. Rules: wave-log capture W3-A. Now in:
  [versions/v0.1/build-plan.md](versions/v0.1/build-plan.md) chunks 7, 9.
- **D50 (2026-10-21, owner ruling, relayed by the wave driver): A stop's
  reason is recorded by `gmctl teardown --reason TEXT`.** Master spec 12
  ("Failures") requires the stage reached and the reason of a stop during
  setup; between setup steps only `teardown` runs, and it recorded no
  reason. The GM skill's stop bullet uses the option. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md) section 11,
  [versions/v0.1/build-plan.md](versions/v0.1/build-plan.md) chunk 10.
- **D51 (2026-10-21, owner ruling, relayed by the wave driver): `fit` may
  start a new game on a playground whose failed game was torn down.**
  After a failed `load-data` or `inject` and its teardown the playground
  was a dead end (`fit` refused with a misleading message, `deploy` only
  retries a failed deploy). `fit` now accepts once nothing labelled with
  the failed game's id is left, and its remaining refusals say what to do.
  Now in: [versions/v0.1/build-plan.md](versions/v0.1/build-plan.md)
  chunk 10.
- **D52 (2026-10-21, set by spec-writer at the wave driver's request,
  wave 3): Master spec 8.1 clarified for the data load.** It said the data
  load is fed to `sh -s` like an injection script; as built (wave-log
  capture W3-A, chunk 7) `data/<node>.sql` is SQL streamed into `psql` as
  `postgres`, and running `load-data` again changes nothing. A
  clarification of what was built, not a change of behaviour. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md) section 8.1,
  [formats.md](formats.md) "Script contracts".
