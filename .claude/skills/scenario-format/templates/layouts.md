# Folder layouts — scenario, brick, fault

Version v0.3, expected to evolve as games are played. Source: v0.1
master spec sections 6.1, 7 and 8, v0.2 master spec 6 (capture W1 of
`specs/versions/v0.2/wave-log.md`) and v0.3 master spec 6 and 7.1
(capture W1 of `specs/versions/v0.3/wave-log.md`). Every entry is required unless it says
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
                        as Swarm configs; one folder per node with seed files.
                        A scheduler node's (brick `scheduler`): queries.yaml,
                        jobs.yaml, schedule.yaml, and optionally builders/, a
                        folder of files (no subfolder), in scenario time; their
                        shapes are master spec 7.1's (normative until the
                        scheduler's templates exist) and capture W1 item 7
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
- A seed entry ending in `/` (`builders/`) maps to a folder of the
  scenario holding at least one regular file, named
  `[A-Za-z0-9_][A-Za-z0-9_.-]*`, and no subfolder; each file is delivered
  as its own seed config under the brick's `seed.dir`.

## Brick folder — `bricks/<brick-id>/`

```
<brick-id>/
  brick.yaml            identity, footprint, knobs, access, runtime, snapshot
                        methods                                     (template: brick.yaml)
  Dockerfile            and its build context; the image carries no scenario content
  validator/            the public validator, POSIX shell
  docs/player.md        what the player may read about this kind of node
  docs/gm.md            the GM documentation, never shipped: the nine required
                        sections of D56, in order               (template: brick-gm.md)
  companion/            optional: the brick's own checks, scripts and tools, and
                        material the GM mounts into other nodes; brick.yaml
                        `companion` says what it provides and when to use it, and
                        `companion.mounted` lists the mounted items
```

Rules:

- A brick's folder holds one version, the `version` of its `brick.yaml`;
  any change in the folder bumps it, unless the new version is still
  unreleased (it folds in). Bumping it re-pins every scenario and fixture
  that pins the brick, in the same change.
- **Mounted material** (`companion.mounted`): every file's `source` is
  under `companion/`; in each receiving node its `target` is an absolute
  path, root-owned (0:0) and read-only (no write bit), so a protected
  file. The material changes no image and no other brick's folder. The
  receiving nodes are the keys of the item's `parameter` (a `node-map`
  parameter set on the mounting brick's node), and each one's brick
  declares `receives`, meeting the item's `requires`.
- **The per-node config** (`node_config`) the renderer writes for each
  receiving node is UTF-8 text, one `key=value` per line, never empty:

  ```
  node=db
  services=postgres sshd
  disk_reservation=2147483648
  volumes=/var/lib/postgresql/18/data /etc/postgresql /home/player /var/lib/gm-state /run
  ```

  `services`: the node's map entry, `default` expanded to its brick's
  `processes`; `disk_reservation`: the node's
  `resources.reservations.disk` in bytes; `volumes`: the in-container
  paths of its brick's `volumes`.

## Fault folder — `faults/<fault-id>/`

```
<fault-id>/
  fault.yaml            definition                       (template: fault.yaml)
  inject/               material that plants the fault: *.sh scripts (state faults),
                        snippets for seed files (seed-file faults); none for a
                        parameter fault, whose fault.yaml holds its parameter_changes
  checks/fixed.sh       the sealed check
  checks/probe.md       the solvability probe description (descriptive only in v0.1)
  gm.md                 explanation the GM uses for feedback
```

## Script contracts (master spec 8.1)

- **Injection scripts** (`inject/*.sh`): POSIX shell, fed on stdin to
  `sh -s` inside the target container, run as root unless the fault says
  otherwise, with parameters as environment variables (`FAULT_<NAME>`).
  Idempotent. Exit 0 on success; any other code fails the setup.
- **The data load** (`data/<node>.sql`): SQL, not shell, streamed on stdin
  into `psql -X -q -v ON_ERROR_STOP=1 -d postgres` run as `postgres`
  inside the node's container (local peer authentication); the file
  creates its own databases and roles. It runs once per game: loading
  again once the data is in changes nothing. Any error fails the setup.
- **Sealed checks** (`checks/fixed.sh`): same delivery as injection
  scripts. Exit 0: the fault is no longer present in the effective live
  state; 1: still present; 3 (v0.3): too soon to tell, with the remaining
  window on the first output line; any other code: error. First output
  line: why, in one sentence the GM can reuse. A fix counts whichever path
  the player took. A behavioural check (the fault's
  `sealed_check.behavioural`) also gets its instance's window and
  threshold as `CHECK_WINDOW_SECONDS` and `CHECK_THRESHOLD`.
- **Database checks** (v0.3 master spec 6.5): a check that queries
  PostgreSQL connects as the GM check role `gm_check`, inside the GM's
  connection reserve, as root through the root-only helper
  `/usr/local/lib/gm/check-psql -d <db> -Atq -v ON_ERROR_STOP=1`
  (`postgres` 0.3.0, capture W1 item 8); never as `dba` or an
  application role. Clients of the load connect as ordinary roles.
- **Public validator** (`validator/`): exit 0 green; 1 red, with one line
  per broken rule; any other code is an error.
