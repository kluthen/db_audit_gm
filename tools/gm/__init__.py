"""gmctl: the GM's host-side command (master spec 11).

Python 3, standard library plus PyYAML. Modules:

- `model`      loading and checking a scenario (completeness, catalog references);
- `localimpl`  the local implementation's files, names, labels and state (capture W2-A);
- `fit`        the capacity check and `implementation.yaml`;
- `render`     the stack file and the envelope files.

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
    print(render.render(args.scenario_dir, args.playground).text())
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

    p = sub.add_parser("render", help="write the stack file and the envelope files")
    _scenario_args(p)
    p.set_defaults(func=_cmd_render)
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
