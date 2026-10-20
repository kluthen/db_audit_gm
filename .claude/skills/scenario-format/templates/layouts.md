# Folder layouts — scenario, brick, fault

Initial version (v0.1), expected to evolve as games are played. Source:
master spec sections 6.1, 7 and 8. Every entry is required unless it says
*optional*. YAML for structured content, Markdown for prose.

## Scenario folder — `scenarios/<scenario-id>/`

```
<scenario-id>/
  README.md             the scenario document, generated (scenario-document skill)
  scenario.yaml         authoritative manifest            (template: scenario.yaml)
  brief.md              the initiator's inputs as given; may say "hand-written, no brief"
  player/               the starter pack, shipped to the bastion
    README.md           topology, node names, rules, DO NOT TAMPER list,
                        how to run the validator
    story.md            the customer's background
    issues.md           the issues given, each with its expected resolution
                        (may say there are none)
  gm/                   SEALED: never shipped to any node
    answer-key.yaml     authoritative answer key          (template: answer-key.yaml)
    notes.md            explanations the GM draws on for feedback
  nodes/<node>/         scenario-specific files per node (seed files), delivered
                        as Swarm configs; one folder per node with seed files
  data/<node>.sql       restored-backup data, streamed into the node;
                        one per node that holds data
  bricks/<brick-id>/    optional: bricks made solely for this scenario
  faults/<fault-id>/    optional: faults made solely for this scenario
  local/<playground>/   local implementations, one per playground; git-ignored,
                        written by the GM at deployment, never by hand
```

Rules:

- `scenario.yaml` and `gm/answer-key.yaml` are authoritative. `README.md`
  is generated from them and opens with a prominent warning that students
  and players should not read it. The starter pack does not carry the
  warning.
- Nothing under `gm/` reaches a node. Nothing under `player/` gives away a
  hidden fault or an answer.
- `player/issues.md` states the same issues as `scenario.yaml` `issues`,
  each with its expected resolution.
- Every file a node's `seed_files` names exists; every `data.file` exists.
- Catalog bricks and faults are referenced by id and pinned version, never
  copied in.

## Brick folder — `bricks/<brick-id>/`

```
<brick-id>/
  brick.yaml            identity, footprint, knobs, access, runtime  (template: brick.yaml)
  Dockerfile            and its build context; the image carries no scenario content
  validator/            the public validator, POSIX shell
  docs/player.md        what the player may read about this kind of node
  docs/gm.md            spoilers and operating notes; never shipped
  companion/            optional: the brick's own checks, scripts and tools;
                        brick.yaml `companion` says what it provides and when to use it
```

## Fault folder — `faults/<fault-id>/`

```
<fault-id>/
  fault.yaml            definition                       (template: fault.yaml)
  inject/               material that plants the fault: *.sh scripts (state faults),
                        snippets for seed files (seed-file faults)
  checks/fixed.sh       the sealed check
  checks/probe.md       the solvability probe description (descriptive only in v0.1)
  gm.md                 explanation the GM uses for feedback
```

## Script contracts (master spec 8.1)

- **Injection scripts** (`inject/*.sh`, and the data load): POSIX shell,
  fed on stdin to `sh -s` inside the target container, run as root unless
  the fault says otherwise, with parameters as environment variables
  (`FAULT_<NAME>`). Idempotent. Exit 0 on success; any other code fails
  the setup.
- **Sealed checks** (`checks/fixed.sh`): same delivery. Exit 0: the fault
  is no longer present in the effective live state; 1: still present; any
  other code: error. First output line: why, in one sentence the GM can
  reuse. A fix counts whichever path the player took. A check that queries
  PostgreSQL runs its query as `postgres` (`runuser -u postgres`, or by
  being executed as `postgres`), so that local peer authentication
  applies.
- **Public validator** (`validator/`): exit 0 green; 1 red, with one line
  per broken rule; any other code is an error.
