"""python3 -I -m gm_api <command>: the brick's own commands (the server itself
runs under uvicorn: python3 -I -m uvicorn --factory gm_api.app:create_app).

    check         imports and checks every endpoint pair and builds the
                  application, as the server does at start (gm_api.check);
                  run as `api`, by gm-reload-api and the validator
    pending       exit 1 when api.yaml or an endpoint file changed since the
                  running server loaded them (/run/gm-api/loaded)
    hosts         the names api.yaml's connections resolve, one a line (the
                  start-up wait); nothing when api.yaml does not load
    write-policy  as root, by the entrypoint: checks GM_WRITE_POLICY and
                  GM_WRITE_OVERRIDES and writes /run/gm/write-policy
    restore       as root: the write policy's owners and modes (gm_api.policy)
    reloadable    as root: exit 0 when db/ is fixable, 1 otherwise

Exit codes: 0 fine, 1 problems (one line each), 2 error.
"""

import argparse
import os
import sys

from . import ConfigError
from . import policy as wp


def cmd_check():
    from . import app
    try:
        _, cfg = app.build()
    except ConfigError as exc:
        print(exc)
        return 1
    names = ", ".join(cfg.endpoints)
    print(f"api.yaml and {len(cfg.endpoints)} endpoint pair(s) load ({names}); "
          f"hostnames: {', '.join(cfg.hosts())}")
    return 0


def cmd_pending():
    from . import app, config
    try:
        with open(config.LOADED_FILE, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError as exc:
        print(f"{config.LOADED_FILE}: cannot be read ({exc.strerror}); the server has not loaded "
              "the files")
        return 2
    loaded = {k: v for k, _, v in (l.partition("=") for l in lines if "=" in l)}
    if loaded.get("fingerprint") != app.fingerprint():
        print(f"api.yaml, routes/ or db/ changed since the server loaded them "
              f"(at {loaded.get('loaded', '?')})")
        return 1
    return 0


def cmd_hosts():
    from . import config
    try:
        cfg = config.load()
    except ConfigError:
        return 1
    for h in cfg.target_hosts():
        print(h)
    return 0


def cmd_write_policy():
    policy = os.environ.get("GM_WRITE_POLICY") or "fixable"
    overrides = sorted(set((os.environ.get("GM_WRITE_OVERRIDES") or "").split()))
    problem = wp.check_policy(policy, overrides)
    if problem:
        print(problem)
        return 1
    tmp = wp.POLICY_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(f"policy={policy}\noverrides={' '.join(overrides)}\n")
    os.chmod(tmp, 0o444)
    os.replace(tmp, wp.POLICY_FILE)
    return 0


def cmd_restore():
    try:
        policy, overrides = wp.read_policy()
        notes = wp.restore(policy, overrides)
    except (wp.PolicyError, OSError) as exc:
        print(f"restore: {exc}", file=sys.stderr)
        return 2
    for n in notes:
        print(n)
    return 0


def cmd_reloadable():
    try:
        policy, overrides = wp.read_policy()
    except wp.PolicyError as exc:
        print(f"reloadable: {exc}", file=sys.stderr)
        return 2
    return 0 if wp.db_fixable(policy, overrides) else 1


COMMANDS = {"check": cmd_check, "pending": cmd_pending, "hosts": cmd_hosts,
            "write-policy": cmd_write_policy, "restore": cmd_restore, "reloadable": cmd_reloadable}


def main(argv=None):
    parser = argparse.ArgumentParser(prog="gm_api", description=__doc__.split("\n")[0])
    parser.add_argument("command", choices=sorted(COMMANDS))
    args = parser.parse_args(argv)
    return COMMANDS[args.command]()


if __name__ == "__main__":
    sys.exit(main())
