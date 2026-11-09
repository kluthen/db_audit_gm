#!/bin/sh
# BS5 each accepted examination booked on its date, or an incident
# (vet-bookings-sync, purpose 11; vet-scheduling-domain.md, "11.
# vet-bookings-sync"; spec D413, D422): every inbound examination accepted
# since the judged moment has, within 2 minutes, its booking (28 000 + the
# exchange's id) starting on its accepted date (local), or an ops.incidents
# row of the purpose naming it (examination-moved, examination-unbooked).
# Judges triggers (T119: booked on another day with no incident).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# is read as gm_check with check-sql; no job is ever run. Exit 0 fixed (with
# its witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=).
# Written for the clinic's names (the constants below); the GM adapts them
# as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "BS5"
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
SELECT x.id, extract(epoch FROM x.answered_at), x.accepted_for,
       (SELECT (b.starts_at AT TIME ZONE st.timezone)::date FROM sched_bookings b
         WHERE b.exchange_id = x.id AND b.booked_at <= x.answered_at + interval '2 minutes'
         ORDER BY b.booked_at LIMIT 1),
       EXISTS (SELECT 1 FROM ops.incidents i WHERE i.purpose = %(purpose)s AND i.ref = x.id::text
                  AND i.kind LIKE 'examination-%%' AND i.opened_at <= x.answered_at + interval '2 minutes')
  FROM exchanges x, (SELECT timezone FROM sched_settings WHERE id = 1) AS st
 WHERE x.direction = 'in' AND x.kind = 'examination' AND x.accepted_for IS NOT NULL
   AND x.answered_at > to_timestamp(%(judged)s::float8)
 ORDER BY x.answered_at, x.id
""", judged=judged, purpose=PURPOSE)
items = [(int(x), float(a), acc, day or None, inc == "t") for x, a, acc, day, inc in rows]
bad = [i for i in items if now > i[1] + DEADLINE and not i[4] and i[3] != i[2]]
if bad:
    x, a, acc, day, _ = bad[0]
    how = f"booked on {day}" if day else "not booked"
    more = f" ({len(bad)} examinations {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: inbound examination {x}, accepted for {acc}: {how} within 2 minutes, "
          f"and no incident{more}")
    sys.exit(1)
old = [i for i in items if i[1] <= now - DEADLINE]
if old:
    print(f"{INVARIANT} fixed: {len(old)} inbound examinations accepted {window}, each booked on its date or "
          f"with an incident ({sum(1 for i in old if i[4])} incidents)")
    sys.exit(0)
if items:
    later(items[0][1] + DEADLINE - now, f"exchange {items[0][0]} is still to be judged")
wait("book-requests", f"no inbound examination accepted {window}")
PY
