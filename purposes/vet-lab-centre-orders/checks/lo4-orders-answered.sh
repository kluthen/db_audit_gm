#!/bin/sh
# LO4 end to end, each centre order answered (vet-lab-centre-orders, v0.5
# master spec 12.2 purpose 1; clinic-purposes.md section 5): every centre
# order posted since the judged moment has each test released or not
# performed within its turnaround plus the wait for the next release round,
# an urgent one within its turnaround. Judged end to end: on the trace after
# the fix, wherever the players fixed it; the orders a fault left stuck before
# it are the answer key's backlog, never this check's (master spec 12.1).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment with check-runs and the lab's
# orders, tests and catalogue as gm_check with check-sql (capture W4 item 0).
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - An order: the centre's account (1), received by lab-api since then, not
#   cancelled. A test's deadline: its posting plus its turnaround
#   (lab_tests.turnaround_hours); a routine one's then the next release round
#   (11:00, 14:00, 18:00 Monday to Saturday, 11:00 on Sunday, the lab's local
#   time). A test the lab cancelled is out.
# - Exit 1: a test past its deadline neither released nor not performed, or
#   answered after it. Exit 0: none, with at least one order every test of
#   which is answered (the witness). Exit 3 otherwise, remaining= until the
#   next deadline. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "LO4"
LAB = ("lab", "lab")                 # the lab's database (the api part's): node, database
ROUNDS = {d: (11, 14, 18) for d in range(6)}   # Monday (0) to Saturday
ROUNDS[6] = (11,)                    # Sunday
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


def query(db, text, **values):
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def num(text):
    return float(text) if text != "" else None


def ids(values):
    return ",".join(str(v) for v in values) or "0"


def next_run(job):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


def too_soon(seconds, why):
    print(f"remaining={max(1, int(seconds))} {why}")
    sys.exit(3)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

from datetime import timedelta

now = float(query(LAB, "SELECT extract(epoch FROM now())")[0][0])
offset = int(query(LAB, "SELECT utc_offset_hours FROM lab_settings")[0][0]) * 3600
rows = query(LAB, """
SELECT o.id, o.priority, extract(epoch FROM o.ordered_at), t.id, t.status, x.turnaround_hours,
       extract(epoch FROM coalesce(t.released_at, t.not_performed_at))
  FROM lab_orders o JOIN lab_order_tests t ON t.order_id = o.id JOIN lab_tests x ON x.id = t.test_id
 WHERE o.account_id = 1 AND o.cancelled_at IS NULL AND t.status <> 'cancelled'
   AND o.ordered_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.ordered_at, t.id
""", judged=judged)


def next_round(ts):
    """The first release round at or after `ts`, in UTC seconds."""
    local = datetime.fromtimestamp(ts + offset, timezone.utc)
    day = local.replace(hour=0, minute=0, second=0, microsecond=0)
    for k in range(8):
        d = day + timedelta(days=k)
        for h in ROUNDS[d.weekday()]:
            at = (d + timedelta(hours=h)).timestamp() - offset
            if at >= ts:
                return at
    cannot("no release round within a week")


tests = []
for order, priority, posted, test, status, tat, done in rows:
    due = float(posted) + int(tat) * 3600
    if priority != "urgent":
        due = next_round(due)
    tests.append((int(order), priority, int(test), status, due, num(done)))
late = [t for t in tests if (t[5] is not None and t[5] > t[4]) or (t[5] is None and now > t[4])]
if late:
    order, priority, test, status, due, done = late[0]
    how = f"answered at {iso(done)}" if done is not None else f"still {status}"
    print(f"{INVARIANT} present: order {order} ({priority}), test {test} due by {iso(due)}, {how}"
          + (f" ({len(late)} tests late {window})" if len(late) > 1 else ""))
    sys.exit(1)
orders = {}
for t in tests:
    orders.setdefault(t[0], []).append(t)
complete = [o for o, ts in orders.items() if all(t[5] is not None for t in ts)]
if complete:
    print(f"{INVARIANT} fixed: {len(complete)} centre orders posted {window} answered in time "
          f"({len(orders) - len(complete)} still within their turnaround)")
    sys.exit(0)
if tests:
    first = min(t[4] for t in tests)
    too_soon(first - now + 1, f"{len(orders)} centre orders posted {window}, none answered yet; the first "
             f"deadline is {iso(first)}")
too_soon(15 * 60, f"no centre order posted {window}")
PY
