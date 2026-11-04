#!/bin/sh
# Sealed check of fixture-job-every-minute (tools/tests, v0.3 chunk 12; master
# spec 8.1, v0.3 master spec 6.5 and 11). Run as root on the scheduler node.
# A behavioural check: FAULT_JOB names the job, CHECK_WINDOW_SECONDS the
# trailing window and CHECK_THRESHOLD the most runs of the job a fixed node
# starts in it (the answer key's window and threshold).
#
# The cause first (rule 1): while jobs.yaml schedules the job more than once
# an hour, exit 1; while the program has not loaded the fixed file (no
# sudo gm-reload-scheduler since the edit), exit 1. Then the behaviour over
# the window (rule 2): until the window has passed since the program loaded
# the fix, exit 3 with remaining=<seconds> first (rule 3); then exit 1 when
# more than CHECK_THRESHOLD runs of the job started in the window, else 0.
# Exit 2 on an error. It reads the files only: no connection.
set -u
python3 -I - "${FAULT_JOB:-}" "${CHECK_WINDOW_SECONDS:-}" "${CHECK_THRESHOLD:-}" <<'EOF'
import datetime
import hashlib
import sys

import yaml

JOBS = "/srv/scheduler/jobs/jobs.yaml"
LOADED = "/run/scheduler/loaded"
LOG = "/var/log/scheduler/scheduler.log"


def done(code, line):
    print(line)
    sys.exit(code)


try:
    job, window, threshold = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
except ValueError:
    done(2, "FAULT_JOB, CHECK_WINDOW_SECONDS and CHECK_THRESHOLD must be set.")
if not job or window < 1:
    done(2, "FAULT_JOB and a positive CHECK_WINDOW_SECONDS must be set.")


def minutes(field):
    """The minutes of the hour a cron minute field names (None: unreadable)."""
    out = set()
    for item in str(field).split(","):
        rng, _, step = item.partition("/")
        try:
            step = int(step) if step else 1
            if rng == "*":
                lo, hi = 0, 59
            elif "-" in rng:
                lo, hi = (int(x) for x in rng.split("-", 1))
            else:
                lo = int(rng)
                hi = 59 if step > 1 else lo
        except ValueError:
            return None
        if step < 1:
            return None
        out.update(range(lo, hi + 1, step))
    return out


try:
    with open(JOBS, "rb") as f:
        raw = f.read()
    doc = yaml.safe_load(raw.decode("utf-8")) or {}
except (OSError, ValueError, yaml.YAMLError) as exc:
    done(2, f"cannot read {JOBS}: {exc}")
entries = [j for j in (doc.get("jobs") or []) if isinstance(j, dict) and j.get("name") == job]
for entry in entries:
    at = str(entry.get("at", ""))
    mins = minutes(at.split()[0]) if at.split() else None
    if mins is None:
        done(2, f"the {job} job's at in jobs.yaml is not readable: {at!r}.")
    if len(mins) > 1:
        done(1, f"the {job} job is still scheduled {len(mins)} times an hour in jobs.yaml "
                f"(at \"{at}\").")

try:
    with open(LOADED, encoding="utf-8") as f:
        loaded_lines = f.read().splitlines()
except OSError as exc:
    done(2, f"cannot read {LOADED} (the program's loaded files): {exc}")
digest = next((l.split(" ", 2)[1] for l in loaded_lines
               if l.startswith("file ") and l.endswith(" " + JOBS)), None)
stamp = next((l.split("=", 1)[1] for l in loaded_lines if l.startswith("loaded=")), None)
if digest != hashlib.sha256(raw).hexdigest():
    done(1, f"jobs.yaml is fixed but not reloaded: the program still runs the {job} job "
            "as it was (sudo gm-reload-scheduler).")
try:
    since = datetime.datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(
        tzinfo=datetime.timezone.utc)
except (TypeError, ValueError):
    done(2, f"no loaded= instant in {LOADED}.")
now = datetime.datetime.now(datetime.timezone.utc)
elapsed = int((now - since).total_seconds())
if elapsed < window:
    done(3, f"remaining={window - elapsed} the fix was loaded at {stamp}; the {job} job's "
            f"runs are judged over {window} s after it.")

start = now - datetime.timedelta(seconds=window)
runs = 0
try:
    with open(LOG, encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.split()
            if len(parts) < 4 or parts[1] != "run" or parts[2] != f"job={job}" \
                    or "phase=start" not in parts:
                continue
            try:
                t = datetime.datetime.strptime(parts[0], "%Y-%m-%dT%H:%M:%SZ").replace(
                    tzinfo=datetime.timezone.utc)
            except ValueError:
                continue
            if t > start:
                runs += 1
except OSError as exc:
    done(2, f"cannot read {LOG}: {exc}")
if runs > threshold:
    done(1, f"{runs} runs of the {job} job started in the last {window} s, more than "
            f"{threshold:g}.")
done(0, f"the {job} job runs at most once an hour: {runs} run(s) in the last {window} s.")
EOF
