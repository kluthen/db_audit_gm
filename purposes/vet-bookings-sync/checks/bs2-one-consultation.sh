#!/bin/sh
# BS2 one consultation per booking (vet-bookings-sync, purpose 11;
# vet-scheduling-domain.md, "11. vet-bookings-sync"): no booking has two
# consultations, and no consultation's booking is anything but arrived,
# judged on the consultations check-in opened in its runs since the judged
# moment (their ops.booking_consultations rows) and on every booking id
# those consultations carry. Judges runs (T116: the core's unique index and
# the job's test both gone; T117: bookings taken by their start, not their
# arrival).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# is read as gm_check with check-sql; no job is ever run. Exit 0 fixed (with
# its witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=).
# Written for the clinic's names (the constants below); the GM adapts them
# as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "BS2"
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

rows = query("""
WITH opened AS (
  SELECT l.booking_id FROM ops.booking_consultations l JOIN ops.runs r ON r.id = l.run_id
   WHERE r.purpose = %(purpose)s AND r.started_at > to_timestamp(%(judged)s::float8))
SELECT o.booking_id, (SELECT count(*) FROM consultations c WHERE c.booking_id = o.booking_id),
       coalesce((SELECT b.state FROM sched_bookings b WHERE b.id = o.booking_id), 'missing')
  FROM (SELECT DISTINCT booking_id FROM opened) AS o ORDER BY o.booking_id
""", judged=judged, purpose=PURPOSE)
opened = [(int(b), int(n), s) for b, n, s in rows]
twice = [o for o in opened if o[1] > 1]
wrong = [o for o in opened if o[2] != "arrived"]
if twice:
    b, n, _ = twice[0]
    print(f"{INVARIANT} present: booking {b} has {n} consultations"
          + (f" ({len(twice)} bookings with more than one {window})" if len(twice) > 1 else ""))
    sys.exit(1)
if wrong:
    b, _, s = wrong[0]
    print(f"{INVARIANT} present: booking {b} has a consultation opened by check-in, but is {s}"
          + (f" ({len(wrong)} such bookings {window})" if len(wrong) > 1 else ""))
    sys.exit(1)
if opened:
    print(f"{INVARIANT} fixed: {len(opened)} consultations opened by check-in {window}, each the only one "
          "of an arrived booking")
    sys.exit(0)
wait("check-in", f"no consultation opened by check-in {window}")
PY
