#!/bin/sh
# BS1 each arrival has its consultation within 2 minutes (vet-bookings-sync,
# purpose 11; vet-scheduling-domain.md, "11. vet-bookings-sync"): every
# consultation booking of a patient (animal_id set) arrived since the judged
# moment has a consultation carrying its id, opened (its ops.booking_consultations
# row's time) within 2 minutes of the arrival. A consultation with the id
# and no ledger row counts as opened in time (it cannot be dated). Judges
# triggers (T115: arrivals the watermark missed).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# is read as gm_check with check-sql; no job is ever run. Exit 0 fixed (with
# its witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=).
# Written for the clinic's names (the constants below); the GM adapts them
# as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "BS1"
DB = ("records", "clinic")           # the source and target part: node, database
PURPOSE = "vet-bookings-sync"
DEADLINE = 120                       # seconds, 2 minutes
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"{INVARIANT} cannot be judged: {text}")
    sys.exit(2)


def helper(argv, stdin=None):
    try:
        p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    except OSError as exc:
        cannot(f"{argv[0]}: {exc.strerror}")
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def query(text, db=None, **values):
    node, name = db or DB
    argv = [CHECK_SQL, "-h", node, "-d", name]
    for key, value in values.items():
        argv += ["-v", f"{key}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def wait(job, why):
    """Exit 3, remaining= until the job's next run."""
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def later(seconds, why):
    print(f"remaining={max(1, int(seconds) + 1)} {why}")
    sys.exit(3)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query("SELECT extract(epoch FROM now())")[0][0])
rows = query("""
SELECT b.id, extract(epoch FROM b.arrived_at),
       (SELECT count(*) FROM consultations c WHERE c.booking_id = b.id),
       extract(epoch FROM (SELECT min(l.at) FROM ops.booking_consultations l WHERE l.booking_id = b.id))
  FROM sched_bookings b
 WHERE b.kind = 'consultation' AND b.animal_id IS NOT NULL AND b.arrived_at > to_timestamp(%(judged)s::float8)
 ORDER BY b.arrived_at, b.id
""", judged=judged)
triggers = [(int(b), float(a), int(n), float(l) if l else None) for b, a, n, l in rows]
late = [t for t in triggers if (t[2] == 0 and now > t[1] + DEADLINE)
        or (t[3] is not None and t[3] > t[1] + DEADLINE)]
if late:
    b, a, n, l = late[0]
    how = f"opened {int(l - a)} s after the arrival" if n and l else f"no consultation {int(now - a)} s after it"
    more = f" ({len(late)} arrivals {window} not checked in within 2 minutes)" if len(late) > 1 else ""
    print(f"{INVARIANT} present: booking {b}, arrived at {iso(a)}: {how}{more}")
    sys.exit(1)
old = [t for t in triggers if t[1] <= now - DEADLINE]
if old:
    print(f"{INVARIANT} fixed: {len(old)} arrivals {window}, each with its consultation within 2 minutes "
          f"({len(triggers) - len(old)} younger)")
    sys.exit(0)
if triggers:
    later(triggers[0][1] + DEADLINE - now, f"booking {triggers[0][0]} arrived {window} is still to be judged")
wait("check-in", f"no patient's consultation booking arrived {window}")
PY
