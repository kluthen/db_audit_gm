"""gmctl: the GM's host-side command (master spec 11).

Python 3, standard library plus PyYAML. Modules:

- `model`      loading and checking a scenario (completeness, catalog references);
- `localimpl`  the local implementation's files, names, labels and state (capture W2-A);
- `fit`        the capacity check and `implementation.yaml`;
- `render`     the stack file, the envelope files, the shift and the scheduler's files;
- `docker`     the Docker command line, aimed at the playground's engine;
- `state`      `gmctl status` (and `--set`, the GM-recorded stages), and
               recording a failed setup step;
- `deploy`     swarm check, credentials, labelled configs and secrets, the stack;
- `execnode`   `exec` (a script into a node's `sh -s`) and `logs`;
- `inject`     `load-data` and `inject`, the setup steps after deployment;
- `aging`      `start-load`, `inject --at`, the host timers (v0.3);
- `checks`     `validate` and `check`, the evaluation's live evidence;
- `teardown`   removing everything carrying the game's label.

Every subcommand prints a readable result and exits non-zero on failure.
"""

import argparse
import sys


def _scenario_args(parser):
    parser.add_argument("scenario_dir", metavar="<scenario-dir>",
                        help="the scenario folder (holds scenario.yaml)")
    parser.add_argument("--playground", required=True, metavar="<name>",
                        help="playground slug: local/<name>/ in the scenario folder")


def _cmd_fit(args):
    from . import fit
    result = fit.fit(args.scenario_dir, args.playground, endpoint=args.endpoint,
                     cpu=args.cpu, memory=args.memory, disk=args.disk)
    print(result.text())
    return 0 if result.ok else 1


def _cmd_render(args):
    from . import render
    print(render.render(args.scenario_dir, args.playground, handover=args.handover).text())
    return 0


def _cmd_deploy(args):
    from . import deploy
    print(deploy.deploy(args.scenario_dir, args.playground, init_swarm=args.init_swarm,
                        timeout=args.timeout).text())
    return 0


def _cmd_status(args):
    from . import localimpl, state
    ldir = localimpl.local_dir(args.scenario_dir, args.playground)
    if args.set and not state.set_gm_stage(ldir, args.set):
        print(f"Already at stage {args.set}: nothing changed.")
    print(state.status_text(ldir))
    return 0


def _cmd_load_data(args):
    from . import inject
    print(inject.load_data(args.scenario_dir, args.playground, timeout=args.timeout).text())
    return 0


def _cmd_inject(args):
    from . import inject
    from .model import GmError
    if args.at is not None or args.instance is not None:
        if args.at is None or args.instance is None:
            raise GmError("--at and --instance go together: --at <UTC instant>|now "
                          "--instance <id>")
        from . import aging
        result = aging.inject_at(args.scenario_dir, args.playground, args.at, args.instance,
                                 timeout=args.timeout)
        print(result.text())
        return 0 if result.ok else 1
    print(inject.inject(args.scenario_dir, args.playground, timeout=args.timeout).text())
    return 0


def _cmd_start_load(args):
    from . import aging
    result = aging.start_load(args.scenario_dir, args.playground,
                              test_aging_minimum=args.test_aging_minimum)
    print(result.text())
    return 0 if result.ok else 1


def _evaluation(args, run):
    """validate and check: exit 0/1/2 from the result; a refusal (nothing
    run, the result unknown) exits 2, not 1, which would read as red or
    present (capture W3-A)."""
    from .checks import ERROR
    from .model import GmError, IncompleteScenario
    try:
        result = run(args.scenario_dir, args.playground)
    except IncompleteScenario as exc:
        print(exc.report())
        print(f"gmctl {args.command}: refused: the scenario is incomplete "
              f"({len(exc.missing)} missing item(s))", file=sys.stderr)
        return ERROR
    except GmError as exc:
        print(f"gmctl {args.command}: {exc}", file=sys.stderr)
        return ERROR
    print(result.text())
    return result.exit_code


def _cmd_validate(args):
    from . import checks
    return _evaluation(args, checks.validate)


def _cmd_check(args):
    from . import checks
    return _evaluation(args, checks.check)


def _cmd_exec(args):
    from . import execnode, localimpl
    from .model import GmError
    try:
        result = execnode.exec_node(
            localimpl.local_dir(args.scenario_dir, args.playground), args.node, args.user,
            stdin=sys.stdin.buffer, env=execnode.parse_env(args.env), capture=False)
    except GmError as exc:
        print(f"gmctl exec: {exc}", file=sys.stderr)
        return execnode.CANNOT_RUN
    return result.returncode


def _cmd_logs(args):
    from . import execnode, localimpl
    return execnode.logs(localimpl.local_dir(args.scenario_dir, args.playground), args.node,
                         tail=args.tail, follow=args.follow)


def _cmd_teardown(args):
    from . import teardown
    print(teardown.teardown(args.scenario_dir, args.playground, reason=args.reason).text())
    return 0


def build_parser():
    parser = argparse.ArgumentParser(
        prog="gmctl", description="db_audit_gm host-side operations (master spec 11).")
    sub = parser.add_subparsers(dest="command", metavar="<subcommand>")
    sub.required = True

    p = sub.add_parser("fit", help="check a scenario against a declared playground and "
                                   "write its local implementation")
    _scenario_args(p)
    p.add_argument("--endpoint", metavar="<url>",
                   help="Docker endpoint, e.g. ssh://user@host (default: local engine)")
    p.add_argument("--cpu", metavar="N", help="playground CPUs")
    p.add_argument("--memory", metavar="SIZE", help="playground memory (8G)")
    p.add_argument("--disk", metavar="SIZE", help="playground disk (40G)")
    p.set_defaults(func=_cmd_fit)

    p = sub.add_parser("render", help="write the stack file, the envelope files and the "
                                      "scheduler's files, shifted for the planned hand-over")
    _scenario_args(p)
    p.add_argument("--handover", metavar="<UTC date and hour>",
                   help="the planned hand-over, YYYY-MM-DDTHH:00Z (2026-10-27T14:00Z); "
                        "required with scheduler nodes")
    p.set_defaults(func=_cmd_render)

    p = sub.add_parser("deploy", help="create the game's credentials, configs and secrets, "
                                      "deploy its stack and wait for health checks")
    _scenario_args(p)
    p.add_argument("--init-swarm", action="store_true",
                   help="run docker swarm init if the engine is not part of a swarm")
    p.add_argument("--timeout", type=int, default=300, metavar="SECONDS",
                   help="how long to wait for health checks (default 300)")
    p.set_defaults(func=_cmd_deploy)

    p = sub.add_parser("load-data", help="stream each node's data/<node>.sql into it "
                                         "(psql as postgres), after deployment")
    _scenario_args(p)
    p.add_argument("--timeout", type=int, metavar="SECONDS",
                   help="limit for each node's load (default: none)")
    p.set_defaults(func=_cmd_load_data)

    p = sub.add_parser("inject", help="plant the state faults: run each one's inject/ "
                                      "scripts on its node, after the data load (with "
                                      "scheduler nodes, those due at T0); with --at and "
                                      "--instance, one state fault during the aging")
    _scenario_args(p)
    p.add_argument("--timeout", type=int, metavar="SECONDS",
                   help="limit for each script (default: none)")
    p.add_argument("--at", metavar="<UTC instant>|now",
                   help="at stage load-started: schedule the instance's planting at "
                        "YYYY-MM-DDTHH:MMZ (a host timer), or plant it now")
    p.add_argument("--instance", metavar="<id>", help="the state fault instance --at plants")
    p.set_defaults(func=_cmd_inject)

    p = sub.add_parser("start-load", help="start every scheduler's load and record T0 (needs "
                                          "stage injected, and scheduler nodes)")
    _scenario_args(p)
    # The test harness's override of the aging minimum (v0.3 capture W2,
    # item 10): passed only by the harness scripts, never shown in help.
    p.add_argument("--test-aging-minimum", metavar="<duration>", help=argparse.SUPPRESS)
    p.set_defaults(func=_cmd_start_load)

    p = sub.add_parser("validate", help="the official run of every node's public validator; "
                                        "exit 0 green, 1 red, 2 error")
    _scenario_args(p)
    p.set_defaults(func=_cmd_validate)

    p = sub.add_parser("check", help="run every sealed check, one line per fault instance; "
                                     "exit 0 all fixed, 1 any present, 3 any too soon, "
                                     "2 any error")
    _scenario_args(p)
    p.set_defaults(func=_cmd_check)

    from .state import GM_STAGES
    p = sub.add_parser("status", help="the game's recorded state; --set records a stage "
                                      "only the GM can tell")
    _scenario_args(p)
    # Not argparse choices: any other stage is a refused transition (exit 1).
    p.add_argument("--set", metavar="<stage>",
                   help=f"record {', '.join(GM_STAGES)} (each follows the one before; "
                        "handed-over follows injected)")
    p.set_defaults(func=_cmd_status)

    p = sub.add_parser("exec", help="stream stdin into sh -s in a node's container, as a "
                                    "given user; exits with the script's status (125: "
                                    "the script could not be started)")
    _scenario_args(p)
    p.add_argument("--node", required=True, metavar="<node>", help="node name (db, bastion)")
    p.add_argument("--user", required=True, metavar="<user>",
                   help="user to run as (root, postgres, player)")
    p.add_argument("--env", action="append", default=[], metavar="KEY=VALUE",
                   help="environment variable for the script (repeatable)")
    p.set_defaults(func=_cmd_exec)

    p = sub.add_parser("logs", help="a node's service logs")
    _scenario_args(p)
    p.add_argument("--node", required=True, metavar="<node>", help="node name (db, bastion)")
    p.add_argument("--tail", type=int, metavar="N", help="only the last N lines")
    p.add_argument("--follow", action="store_true", help="keep following the logs")
    p.set_defaults(func=_cmd_logs)

    p = sub.add_parser("teardown", help="remove everything carrying the game's label, "
                                        "volumes included (never images or the swarm)")
    _scenario_args(p)
    p.add_argument("--reason", metavar="TEXT",
                   help="why the game was stopped, recorded with the teardown (one line)")
    p.set_defaults(func=_cmd_teardown)
    return parser


def main(argv=None):
    from .model import GmError, IncompleteScenario
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except IncompleteScenario as exc:
        print(exc.report())
        print(f"gmctl {args.command}: refused: the scenario is incomplete "
              f"({len(exc.missing)} missing item(s))", file=sys.stderr)
        return 1
    except GmError as exc:
        print(f"gmctl {args.command}: {exc}", file=sys.stderr)
        return 1
