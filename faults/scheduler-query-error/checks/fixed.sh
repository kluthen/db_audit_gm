#!/bin/sh
# Sealed check of scheduler-query-error (master spec 8.1, v0.3 master spec
# 6.5; capture W4 items 0 and 2). Run as root on the scheduler node; reads
# the node's files and the scheduler's log, opens no connection, never runs
# the repository's code.
#
# FAULT_KEY names the queries.yaml key. The planted form is the seed copy
# /opt/gm/seed/queries.yaml (capture W4 item 0). Exit 1 while the live
# queries.yaml differs from what the program loaded (/run/scheduler/loaded:
# fixed but not reloaded, or not fixed), while the loaded entry of the key
# equals the planted one, or while an `error key=<key>` line of SQLSTATE
# class 42 or 22 follows the last load (a 2 s grace after it, for a call
# drawn before it). Exit 0 once a minute that began after the load has a
# `key` line for the key with calls above 0 and no such error. Exit 3 until
# then, `remaining=<seconds>` first: the time to that minute's key line
# (written within ten seconds after the minute). Exit 2 on an error.
set -u
python3 -I - "${FAULT_KEY:-}" <<'EOF'
import datetime
import hashlib
import os
import re
import stat
import sys

import yaml

LIVE = "/srv/scheduler/repository/queries.yaml"
SEED = "/opt/gm/seed/queries.yaml"
LOADED = "/run/scheduler/loaded"
LOG = "/var/log/scheduler/scheduler.log"
GRACE = 2          # seconds after the load: a call drawn before it may still end
LINE_DELAY = 10    # a minute's key lines are written within ten seconds after it
UTC = datetime.timezone.utc


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


def when(text):
    return datetime.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


key = sys.argv[1]
if not key:
    done(2, "FAULT_KEY must be set.")
live_raw = regular(LIVE)
planted = entry(regular(SEED), SEED, key)
if planted is None:
    done(2, f"the key {key} is not in the planted {SEED}.")
live = entry(live_raw, LIVE, key)

loaded = regular(LOADED).decode("utf-8", "replace").splitlines()
digest = next((l.split(" ", 2)[1] for l in loaded
               if l.startswith("file ") and l.endswith(" " + LIVE)), None)
stamp = next((l.split("=", 1)[1] for l in loaded if l.startswith("loaded=")), None)
if digest != hashlib.sha256(live_raw).hexdigest():
    if live == planted:
        done(1, f"the {key} query still carries its error (queries.yaml changed elsewhere, "
                "not reloaded either).")
    done(1, f"queries.yaml is fixed but not reloaded: the program still runs the {key} query "
            "as it was (sudo gm-reload-scheduler).")
if live == planted:
    done(1, f"the {key} query still carries its error in the loaded queries.yaml.")
try:
    since = when(stamp)
except (TypeError, ValueError):
    done(2, f"no loaded= instant in {LOADED}.")

err_re = re.compile(r"^(\S+) error key=(\S+) (?:job=\S+ )?sqlstate=(\S+) ")
key_re = re.compile(r"^\S+ key minute=(\S+) key=(\S+) calls=(\d+) errors=(\d+)")
first_minute = since.replace(second=0) + datetime.timedelta(
    minutes=0 if since.second == 0 else 1)
errors, last_code, calls_after = 0, None, False
try:
    with open(LOG, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = err_re.match(line)
            if m and m.group(2) == key and m.group(3)[:2] in ("42", "22"):
                try:
                    t = when(m.group(1))
                except ValueError:
                    continue
                if (t - since).total_seconds() > GRACE:
                    errors += 1
                    last_code = m.group(3)
                continue
            m = key_re.match(line)
            if m and m.group(2) == key and int(m.group(3)) > 0:
                try:
                    minute = datetime.datetime.strptime(m.group(1), "%Y-%m-%dT%H:%MZ") \
                        .replace(tzinfo=UTC)
                except ValueError:
                    continue
                if minute >= first_minute:
                    calls_after = True
except OSError as exc:
    done(2, f"cannot read {LOG}: {exc.strerror}")
if errors:
    done(1, f"the {key} query still fails: {errors} call(s) ended with SQLSTATE class 42 or 22 "
            f"since the reload at {stamp} (the last {last_code}).")
if calls_after:
    done(0, f"the {key} query is corrected and its calls since the reload at {stamp} end "
            "without a syntax or type error.")
now = datetime.datetime.now(UTC)
due = first_minute + datetime.timedelta(seconds=60 + LINE_DELAY)
if due <= now:
    nxt = now.replace(second=0, microsecond=0) + datetime.timedelta(minutes=1)
    due = nxt + datetime.timedelta(seconds=LINE_DELAY)
remaining = max(1, int((due - now).total_seconds()) + 1)
done(3, f"remaining={remaining} the {key} query is corrected and reloaded at {stamp}; no call "
        "of it has ended since.")
EOF
