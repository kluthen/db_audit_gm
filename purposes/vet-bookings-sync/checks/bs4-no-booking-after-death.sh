#!/bin/sh
# BS4 no booking left for a dead animal (vet-bookings-sync, purpose 11;
# vet-scheduling-domain.md, "11. vet-bookings-sync"): every animal recorded
# died since the judged moment has no future booking (starting after its
# death) left booked 2 minutes later: each is cancelled within 2 minutes.
# Its witness, a death since the judged moment with a booking starting after
# it. Judges triggers (T118: cancel-deceased missing, or its watermark on
# died_at rounded to the day).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# is read as gm_check with check-sql; no job is ever run. Exit 0 fixed (with
# its witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=).
# Written for the clinic's names (the constants below); the GM adapts them
# as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "BS4"
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
SELECT a.id, extract(epoch FROM a.died_at), b.id, b.state, extract(epoch FROM b.cancelled_at)
  FROM animals a JOIN sched_bookings b ON b.animal_id = a.id AND b.starts_at > a.died_at
       AND b.booked_at <= a.died_at
 WHERE a.status = 'died' AND a.died_at > to_timestamp(%(judged)s::float8)
   AND (b.state = 'booked' OR (b.state = 'cancelled' AND b.cancelled_at >= a.died_at))
 ORDER BY a.died_at, a.id, b.id
""", judged=judged)
items = [(int(a), float(d), int(b), s, float(c) if c else None) for a, d, b, s, c in rows]
late = [i for i in items if (i[3] == "booked" and now > i[1] + DEADLINE)
        or (i[3] == "cancelled" and i[4] > i[1] + DEADLINE)]
if late:
    a, d, b, s, c = late[0]
    how = (f"still booked {int(now - d)} s after the death" if s == "booked"
           else f"cancelled {int(c - d)} s after the death")
    more = f" ({len(late)} bookings of dead animals {window})" if len(late) > 1 else ""
    print(f"{INVARIANT} present: animal {a}, died at {iso(d)}: booking {b} {how}{more}")
    sys.exit(1)
old = [i for i in items if i[1] <= now - DEADLINE]
if old:
    print(f"{INVARIANT} fixed: {len({i[0] for i in old})} animals died {window} with a future booking, each "
          f"cancelled within 2 minutes ({len(old)} bookings)")
    sys.exit(0)
if items:
    later(items[0][1] + DEADLINE - now, f"animal {items[0][0]}'s bookings are still to be judged")
wait("cancel-deceased", f"no animal with a future booking died {window}")
PY
