#!/bin/sh
# Sealed check of scheduler-transaction-held-open (master spec 8.1, v0.3
# master spec 6.5; capture W4 items 0 and 6; spec D186). Run as root on the
# scheduler node; reads the node's files only, opens no connection, never
# runs the repository's code.
#
# FAULT_KEY names the queries.yaml key. Exit 1 while the live queries.yaml
# differs from what the program loaded (/run/scheduler/loaded: changed but
# not reloaded), or while the key's loaded entry carries a hold (a
# transaction: hold above 0s on the entry, a pool entry or the sequence);
# exit 0 once it carries none. Reachable only where a scenario makes the
# repository editable anyway: the fault is report or propose only. Exit 2
# on an error.
set -u
python3 -I - "${FAULT_KEY:-}" <<'EOF'
import hashlib
import os
import stat
import sys

import yaml

from gm_scheduler import ConfigError
from gm_scheduler.timeutil import parse_duration

LIVE = "/srv/scheduler/repository/queries.yaml"
SEED = "/opt/gm/seed/queries.yaml"
LOADED = "/run/scheduler/loaded"


def done(code, line):
    print(line)
    sys.exit(code)


def regular(path):
    """A regular file's bytes, never through a symbolic link."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError as exc:
        done(2, f"cannot read {path}: {exc.strerror}")
    with os.fdopen(fd, "rb") as f:
        if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
            done(2, f"{path} is not a regular file")
        return f.read()


def entry(raw, path, key):
    try:
        doc = yaml.safe_load(raw.decode("utf-8"))
    except (UnicodeDecodeError, yaml.YAMLError):
        done(2, f"{path} does not parse")
    queries = doc.get("queries") if isinstance(doc, dict) else None
    if not isinstance(queries, dict) or key not in queries:
        return None
    return queries[key]


def holds(value):
    """The longest hold, in seconds, of an entry's transactions (a builder's
    transaction is code: not read)."""
    items = value if isinstance(value, list) else [value]
    longest = 0
    for item in items:
        txn = item.get("transaction") if isinstance(item, dict) else None
        if isinstance(txn, dict) and "hold" in txn:
            try:
                longest = max(longest, parse_duration(txn["hold"], "hold"))
            except ConfigError:
                done(2, f"the {key} entry's hold {txn['hold']!r} is not a duration.")
    return longest


key = sys.argv[1]
if not key:
    done(2, "FAULT_KEY must be set.")
live_raw = regular(LIVE)
if entry(regular(SEED), SEED, key) is None:
    done(2, f"the key {key} is not in the planted {SEED}.")
live = entry(live_raw, LIVE, key)
hold = holds(live) if live is not None else 0
loaded = regular(LOADED).decode("utf-8", "replace").splitlines()
digest = next((l.split(" ", 2)[1] for l in loaded
               if l.startswith("file ") and l.endswith(" " + LIVE)), None)
if digest != hashlib.sha256(live_raw).hexdigest():
    if hold:
        done(1, f"the {key} transaction is still held open {hold} s after its statements "
                "(queries.yaml changed elsewhere, not reloaded either).")
    done(1, f"queries.yaml is changed but not reloaded: the program still holds the {key} "
            "transaction open as it was (sudo gm-reload-scheduler).")
if live is None:
    done(2, f"the key {key} is not in the loaded queries.yaml.")
if hold:
    done(1, f"the {key} transaction is still held open {hold} s after its statements in the "
            "loaded queries.yaml.")
done(0, f"the {key} transaction is no longer held open in the loaded queries.yaml.")
EOF
