"""python3 -I -m gm_scheduler <command> [--config <file>]

    run          the program (the s6 service, as `scheduler`): the input on
                 standard input (gm_scheduler.schedule), exit codes in runner
    check        as `scheduler`: queries.yaml, builders/ and jobs.yaml load,
                 and jobs.yaml's keys are in queries.yaml; one problem a line
    check-keys   as root: every key the schedule names is in queries.yaml and
                 every job's connection is the schedule's; never imports a
                 builder and prints only keys and the players' job names
    pending      as `scheduler`: the files changed since the program loaded them
    restore      as root: the write policy's owner and modes (gm_scheduler.policy)
    reloadable   as root: exit 0 when a file gm-reload-scheduler applies is
                 fixable, 1 when the node is report-only for all of them
    write-policy as root, by the entrypoint: checks GM_WRITE_POLICY and
                 GM_WRITE_OVERRIDES and writes /run/gm/write-policy

Exit codes of the checks: 0 fine, 1 problems (one line each), 2 error.
"""

import argparse
import os
import sys

from . import ConfigError
from . import policy as wp
from .jobs import load_jobs
from .repository import fingerprint, load_repository, loaded_files, queries_keys_only
from .runner import CONFIG_FILE, load_config, run, write_atomic
from .schedule import parse_schedule
from .repository import load_yaml


def cmd_check(cfg):
    problems = []
    repo = jobs = None
    try:
        repo = load_repository(cfg["repository"])
    except ConfigError as exc:
        problems.append(str(exc))
    try:
        jobs = load_jobs(cfg["jobs"])
    except ConfigError as exc:
        problems.append(str(exc))
    if repo is not None and jobs is not None:
        for job in jobs:
            if job.key not in repo:
                problems.append(f"jobs.yaml: job {job.name}: key {job.key} is not in queries.yaml")
    for p in problems:
        print(p)
    return 1 if problems else 0


def cmd_check_keys(cfg):
    try:
        with open(cfg["schedule_seed"], encoding="utf-8") as f:
            schedule = parse_schedule(load_yaml(f.read(), "schedule"))
    except (OSError, ConfigError):
        print("the schedule does not load: the game master's business, not a file of yours")
        return 2
    problems = []
    try:
        keys = queries_keys_only(cfg["repository"])
    except ConfigError as exc:
        print(str(exc))
        return 1
    for key in sorted(schedule.keys()):
        if key not in keys:
            problems.append(f"queries.yaml: key {key} is named by the schedule but is missing")
    try:
        jobs = load_jobs(cfg["jobs"])
    except ConfigError as exc:
        problems.append(str(exc))
        jobs = []
    for job in jobs:
        if job.connection not in schedule.connections:
            problems.append(f"jobs.yaml: job {job.name}: connection {job.connection} is not one of the schedule's")
    for p in problems:
        print(p)
    return 1 if problems else 0


def cmd_pending(cfg):
    try:
        with open(cfg["loaded"], encoding="utf-8") as f:
            text = f.read()
    except OSError:
        print(f"{cfg['loaded']}: missing: the program has not loaded its files")
        return 2
    loaded, stamp = {}, "-"
    for line in text.splitlines():
        parts = line.split(" ", 2)
        if parts[0] == "file" and len(parts) == 3:
            loaded[parts[2]] = parts[1]
        elif line.startswith("loaded="):
            stamp = line.split("=", 1)[1]
    now = fingerprint(loaded_files(cfg["repository"], cfg["jobs"]))
    changed = sorted(p for p in set(now) | set(loaded) if now.get(p) != loaded.get(p))
    for p in changed:
        state = "added" if p not in loaded else ("removed" if p not in now or now[p] == "missing" else "changed")
        print(f"{p} {state} since the program loaded its files ({stamp})")
    return 1 if changed else 0


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
    return 0 if wp.any_fixable(policy, overrides) else 1


def cmd_write_policy():
    policy = os.environ.get("GM_WRITE_POLICY") or "fixable"
    overrides = sorted(set((os.environ.get("GM_WRITE_OVERRIDES") or "").split()))
    problem = wp.check_policy(policy, overrides)
    if problem:
        print(problem)
        return 1
    write_atomic(wp.POLICY_FILE, f"policy={policy}\noverrides={' '.join(overrides)}\n", 0o444)
    os.chmod(wp.POLICY_FILE, 0o444)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="gm_scheduler")
    parser.add_argument("command", choices=("run", "check", "check-keys", "pending", "restore", "reloadable",
                                            "write-policy"))
    parser.add_argument("--config", default=CONFIG_FILE)
    args = parser.parse_args(argv)
    if args.command == "restore":
        return cmd_restore()
    if args.command == "write-policy":
        return cmd_write_policy()
    if args.command == "reloadable":
        return cmd_reloadable()
    try:
        cfg = load_config(args.config)
    except (OSError, ConfigError) as exc:
        print(f"gm-scheduler: {exc}", file=sys.stderr)
        return 2
    if args.command == "run":
        data = sys.stdin.buffer.read().decode("utf-8", errors="replace")
        return run(cfg, data)
    if args.command == "check":
        return cmd_check(cfg)
    if args.command == "check-keys":
        return cmd_check_keys(cfg)
    return cmd_pending(cfg)


if __name__ == "__main__":
    sys.exit(main())
