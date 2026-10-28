#!/bin/sh
# Sealed check of scheduler-job-wrong-timezone (master spec 8.1, v0.3 master
# spec 6.5; capture W4 items 0 and 8; spec D168). Run as root on the
# scheduler node; reads the node's files only, opens no connection.
#
# FAULT_JOB names the job, FAULT_OFFSET the timezone_offset the scenario
# wrote on it. From the seed copy /opt/gm/seed/jobs.yaml (as rendered: the
# at as designed, timezone Etc/GMT∓M) it takes the designed at and M, and
# the customer's offset C = M - FAULT_OFFSET brought into -11..+12 (the
# shift's range, so the answer is unique). Exit 1 while the live jobs.yaml
# differs from what the program loaded (/run/scheduler/loaded), while the
# job is no longer in it, or while its loaded runs (at and timezone, read
# by the program's own cron) over the next 8 days differ from the designed
# at read in UTC+C; exit 0 once they are the same instants, whatever the
# form. Exit 2 on an error.
set -u
python3 -I - "${FAULT_JOB:-}" "${FAULT_OFFSET:-}" <<'EOF'
import datetime
import hashlib
import os
import re
import stat
import sys
import time

import yaml

from gm_scheduler import ConfigError
from gm_scheduler.cron import Cron

LIVE = "/srv/scheduler/jobs/jobs.yaml"
SEED = "/opt/gm/seed/jobs.yaml"
LOADED = "/run/scheduler/loaded"
HORIZON = 8 * 86400
MAX_RUNS = 20000


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


def job_of(raw, path, name):
    try:
        doc = yaml.safe_load(raw.decode("utf-8"))
    except (UnicodeDecodeError, yaml.YAMLError):
        done(2, f"{path} does not parse")
    jobs = (doc or {}).get("jobs") if isinstance(doc, dict) else None
    return next((j for j in jobs or [] if isinstance(j, dict) and j.get("name") == name), None)


def zone(offset):
    """The fixed zone UTC+offset, as render names it."""
    return "Etc/GMT" if offset == 0 else f"Etc/GMT{'-' if offset > 0 else '+'}{abs(offset)}"


def runs(cron, start):
    out, t = [], start
    while len(out) < MAX_RUNS:
        t = cron.next_after(t)
        if t is None or t > start + HORIZON:
            break
        out.append(t)
    return out


job, offset = sys.argv[1], sys.argv[2]
if not job:
    done(2, "FAULT_JOB must be set.")
try:
    offset = int(offset)
except ValueError:
    done(2, f"FAULT_OFFSET {offset!r} is not an integer.")
planted = job_of(regular(SEED), SEED, job)
if planted is None:
    done(2, f"the job {job} is not in the planted {SEED}.")
m = re.match(r"^Etc/GMT(?:([+-])([0-9]{1,2}))?$", str(planted.get("timezone", "")))
if m is None:
    done(2, f"the planted {job} job has no Etc/GMT timezone (got {planted.get('timezone')!r}): "
            "not planted with timezone_offset.")
planted_zone = 0 if m.group(1) is None else (-1 if m.group(1) == "+" else 1) * int(m.group(2))
customer = (planted_zone - offset + 11) % 24 - 11
try:
    expected = Cron(planted.get("at"), zone(customer))
except ConfigError as exc:
    done(2, f"the planted {job} job's at does not read: {exc}")

live_raw = regular(LIVE)
loaded = regular(LOADED).decode("utf-8", "replace").splitlines()
digest = next((l.split(" ", 2)[1] for l in loaded
               if l.startswith("file ") and l.endswith(" " + LIVE)), None)
if digest != hashlib.sha256(live_raw).hexdigest():
    done(1, f"jobs.yaml is changed but not reloaded: the program still runs the {job} job as it "
            "was (sudo gm-reload-scheduler).")
live = job_of(live_raw, LIVE, job)
if live is None:
    done(1, f"the {job} job is no longer in the loaded jobs.yaml: it no longer runs at all.")
try:
    actual = Cron(live.get("at"), live.get("timezone", "UTC"))
except ConfigError as exc:
    done(2, f"the {job} job's at or timezone does not read: {exc}")
now = time.time()
want, got = runs(expected, now), runs(actual, now)
if want == got and want:
    done(0, f"the {job} job runs at its intended time of day in the customer's zone "
            f"({planted.get('at')} in UTC{customer:+d}).")
first = next((t for t in got if t not in set(want)), got[0] if got else None)
when = (datetime.datetime.fromtimestamp(first, datetime.timezone.utc).strftime("%a %H:%M UTC")
        if first else "never")
done(1, f"the {job} job still does not run at its intended time of day in the customer's zone "
        f"({planted.get('at')} in UTC{customer:+d}): a run at {when}.")
EOF
