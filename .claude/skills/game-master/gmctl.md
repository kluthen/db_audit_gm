# `gmctl` for the GM — command reference

Every call the [GM skill](SKILL.md) makes, as built in v0.1. Run from the
repository root. Each subcommand takes `<scenario-dir> --playground
<name>`, prints a readable result, and exits non-zero on failure; `gmctl
<subcommand> --help` is the authority when this page and the tool
disagree. Fixed by captures W2-A, W2-C, W3-A and W3-B in
`specs/versions/v0.1/wave-log.md` (master spec 11).

## Stages

`state.yaml` in `local/<pg>/` records, in order: `fitted`, `rendered`,
`deployed`, `data-loaded`, `injected`, `handed-over`, `final-answer`,
`feedback-given`, `torn-down`; or `failed`, with `failure: {stage,
reason, at}` (the stage it was working towards). `gmctl` records every
stage up to `injected`, and `torn-down`; the GM records the other three
with `status --set`.

## Commands

| Command | Allowed at | Records | Exit |
|---|---|---|---|
| `tools/gmctl status <dir> --playground <pg>` | any game | nothing | 0; 1 no game |
| `tools/gmctl fit <dir> --playground <pg> [--endpoint ssh://user@host] [--cpu N --memory SIZE --disk SIZE]` | no game, `fitted`, `rendered`, `torn-down`, or `failed` before deployment | `fitted` | 0 fits; 1 does not fit, or refused |
| `tools/gmctl render <dir> --playground <pg>` | `fitted`, `rendered` | `rendered` | 0; 1 refused |
| `tools/gmctl deploy <dir> --playground <pg> [--init-swarm] [--timeout SECONDS]` | `rendered`, or `failed` in deploy | `deployed` | 0; 1 refused or failed |
| `tools/gmctl load-data <dir> --playground <pg> [--timeout SECONDS]` | `deployed` (later deployed stages: no-op, exit 0) | `data-loaded` | 0; 1 refused or failed |
| `tools/gmctl inject <dir> --playground <pg> [--timeout SECONDS]` | `data-loaded`, `injected` (a replay) | `injected` | 0; 1 refused or failed |
| `tools/gmctl status <dir> --playground <pg> --set handed-over` | `injected` | `handed-over` | 0; 1 refused |
| `printf '%s\n' 'cat ~/report.md' \| tools/gmctl exec <dir> --playground <pg> --node <bastion> --user player` | any deployed stage | nothing | the script's own; 125 could not start |
| `tools/gmctl status <dir> --playground <pg> --set final-answer` | `handed-over` | `final-answer` | 0; 1 refused |
| `tools/gmctl validate <dir> --playground <pg>` | any deployed stage | nothing | 0 green; 1 red; 2 error or refused |
| `tools/gmctl check <dir> --playground <pg>` | `injected` and later deployed stages | nothing | 0 all fixed; 1 any present; 2 any error or refused |
| `tools/gmctl logs <dir> --playground <pg> --node <node> [--tail N]` | any game (useful while its services exist) | nothing | Docker's (`docker service logs`); 1 no game |
| `tools/gmctl status <dir> --playground <pg> --set feedback-given` | `final-answer` | `feedback-given` | 0; 1 refused |
| `tools/gmctl teardown <dir> --playground <pg>` | any game (idempotent) | `torn-down` (a failed game stays `failed`) | 0; 1 leftovers |

The deployed stages are `deployed` to `feedback-given`. `status --set` on
the stage the game is already at prints `Already at stage <stage>:
nothing changed.` and exits 0. `logs --follow` exists but blocks: the GM
does not use it.

## What the output looks like

- **`fit`**: the capacity lines, then `Result: fits. Game id <id>.` or
  `Result: does not fit; nothing deployed.` with one line per problem. An
  incomplete scenario: the list of missing items, then `refused`.
- **`deploy`**: `Game <id>: deployed on <endpoint>.`, the credentials
  directory (never printed), the services healthy, then one line per
  published port: `node <bastion>: port <port> on the swarm host
  (container port 22)`; `Stage deployed.`
- **A failed setup step** (`deploy`, `load-data`, `inject`): `setup failed
  before stage <stage>: <reason>`, the teardown it ran, then `Recorded in
  state.yaml (stage failed).`
- **`inject`**: one line per script, `<instance> <script> (<node>, as
  <user>): ok|exit N`, then the script's output indented 4 spaces.
  Spoilers: keep it from the players.
- **`validate`**: each validator's lines under `<node>:` (`GREEN: ...`,
  or `RED <rule>: ...` lines, or `ERROR: ...`), ending `Validators of game
  <id>: <node> green|red|error, ...`.
- **`check`**: one line per fault instance, `<instance> <fault-id>:
  fixed|present|error — <reason>`; no summary line.
- **`status`**: game id, playground and endpoint, stage (for a failed
  game, the last stage reached), the failure if any, the history, and for
  a deployed game the credentials directory (`local/<pg>/secrets/`, not
  printed).
- **`teardown`**: `Teardown of game <id>: removed ...; nothing carrying
  its label is left.` (`... nothing carrying its label was left.` when
  there was nothing to remove), or the leftovers and exit 1.

## Files of the local implementation the GM reads

In `scenarios/<id>/local/<pg>/` (git-ignored; never edit by hand):

- `playground.yaml`: `docker_endpoint` (`null` for the local engine) and
  the declared capacity;
- `implementation.yaml`: `game_id`, and per node `published_ports`
  (`[{target, published, mode}]`; only the bastion publishes one);
- `state.yaml`: through `gmctl status`;
- `secrets/player_password`: the bastion password to hand over (mode
  0600; never print it anywhere but the hand-over).
