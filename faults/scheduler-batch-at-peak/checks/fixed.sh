#!/bin/sh
# Sealed check of scheduler-batch-at-peak (master spec 8.1, v0.3 master
# spec 6.5; capture W4 items 0 and 7). Run as root on the scheduler node;
# reads the node's files only (the rendered schedule.yaml, root-only, among
# them), opens no connection.
#
# FAULT_JOB names the job, FAULT_SHAPE the shape of the rendered
# /opt/gm/seed/schedule.yaml (already per UTC weekday, so no shift is
# needed) and FAULT_QUIET_BELOW the multiplier at or below which an hour is
# quiet. Exit 1 while the live jobs.yaml differs from what the program
# loaded (/run/scheduler/loaded), while the job is no longer in it (the
# batch must still run), or while a run of the loaded job over the next 35
# days (its at and timezone, read by the program's own cron) falls in a UTC
# hour whose multiplier, on that UTC weekday, is above FAULT_QUIET_BELOW;
# exit 0 once every run is in a quiet hour. Exit 2 on an error.
set -u
python3 -I - "${FAULT_JOB:-}" "${FAULT_SHAPE:-}" "${FAULT_QUIET_BELOW:-0.5}" <<'EOF'
import datetime
import hashlib
import os
import stat
import sys
import time

import yaml

from gm_scheduler import ConfigError
from gm_scheduler.cron import Cron

LIVE = "/srv/scheduler/jobs/jobs.yaml"
SCHEDULE = "/opt/gm/seed/schedule.yaml"
LOADED = "/run/scheduler/loaded"
WEEKDAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
HORIZON = 35 * 86400          # every weekday five times, a monthly job at least once
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


def load(raw, path):
    try:
        return yaml.safe_load(raw.decode("utf-8"))
    except (UnicodeDecodeError, yaml.YAMLError):
        done(2, f"{path} does not parse")


job, shape_name, quiet = sys.argv[1], sys.argv[2], sys.argv[3]
if not job or not shape_name:
    done(2, "FAULT_JOB and FAULT_SHAPE must be set.")
try:
    quiet = float(quiet)
except ValueError:
    done(2, f"FAULT_QUIET_BELOW {quiet!r} is not a number.")
schedule = load(regular(SCHEDULE), SCHEDULE)
shape = (((schedule or {}).get("shapes") or {}).get(shape_name) or {}).get("utc") \
    if isinstance(schedule, dict) else None
if not isinstance(shape, dict) or any(len(shape.get(d) or []) != 24 for d in WEEKDAYS):
    done(2, f"the rendered schedule.yaml has no shape {shape_name} with 24 hours per weekday.")

live_raw = regular(LIVE)
loaded = regular(LOADED).decode("utf-8", "replace").splitlines()
digest = next((l.split(" ", 2)[1] for l in loaded
               if l.startswith("file ") and l.endswith(" " + LIVE)), None)
if digest != hashlib.sha256(live_raw).hexdigest():
    done(1, f"jobs.yaml is changed but not reloaded: the program still runs the {job} job as it "
            "was (sudo gm-reload-scheduler).")
jobs = (load(live_raw, LIVE) or {}).get("jobs") or []
entry = next((j for j in jobs if isinstance(j, dict) and j.get("name") == job), None)
if entry is None:
    done(1, f"the {job} job is no longer in the loaded jobs.yaml: the batch no longer runs at all.")
try:
    cron = Cron(entry.get("at"), entry.get("timezone", "UTC"))
except ConfigError as exc:
    done(2, f"the {job} job's at or timezone does not read: {exc}")

now = time.time()
t, runs, busy = now, 0, []
while runs < MAX_RUNS:
    t = cron.next_after(t)
    if t is None or t > now + HORIZON:
        break
    runs += 1
    u = datetime.datetime.fromtimestamp(t, datetime.timezone.utc)
    m = float(shape[WEEKDAYS[u.weekday()]][u.hour])
    if m > quiet:
        busy.append((u, m))
if not runs:
    done(1, f"the {job} job never runs in the next 35 days as loaded: the batch no longer runs.")
if busy:
    u, m = busy[0]
    done(1, f"the {job} job still runs in busy hours: {len(busy)} of its {runs} runs in the next "
            f"35 days, the next {u:%a %H:%M} UTC where the {shape_name} shape is at {m:g}, "
            f"above {quiet:g}.")
done(0, f"every run of the {job} job falls in a quiet hour of the {shape_name} shape (at most "
        f"{quiet:g}).")
EOF
