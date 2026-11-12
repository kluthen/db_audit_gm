#!/bin/sh
# Sealed check of purpose-urgent-priority-dropped (v0.5 master spec 17.2 s1,
# 17.3; vet-lab-centre-orders, clinic-purposes.md section 5, LO4; capture W5
# item 1; spec D456): every urgent request of the record posted to the lab
# since the judged moment reached it as an urgent order, and those urgent
# orders the lab has answered were answered within their turnaround (LO4 end
# to end, completed orders only). Judged by runs.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the violations
# tolerated, 0 by the answer key's default), FAULT_SOURCE (the record,
# <node>/<database>), FAULT_LAB (the lab's database, <node>/<database>) and
# FAULT_JOB (the posting job). It reads the judged moment and the job's runs
# with check-runs, both databases as gm_check with check-sql; it never runs a
# job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - The orders judged: the centre's (account 1), received by the lab since
#   then, not cancelled, each test carrying a request id; a request's
#   priority is the record's.
# - A violation: an urgent request on an order that is not urgent; or, on an
#   urgent order every test of which the lab has answered (released or not
#   performed; a cancelled test is out), a test answered after its order's
#   posting plus the test's turnaround (lab_tests.turnaround_hours). An urgent
#   order not yet completed is not judged (D456): its result is LO3's and its
#   backlog the answer key's.
# Exit 1: more violations than the threshold, naming the first. Exit 0: none
# beyond it, with a completed urgent order since the judged moment (the
# witness). Exit 3 otherwise: remaining= until the first urgent order's
# deadline, or the job's next run when no urgent request was posted yet.
# Exit 2: it cannot judge (a helper failed, a parameter malformed).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"
WAIT = 15 * 60                       # seconds to wait for a first urgent request


def cannot(text):
    print(f"the urgent priority cannot be judged: {text}")
    sys.exit(2)


def part(name, default):
    value = os.environ.get(name) or default
    node, _, db = value.partition("/")
    if not (node and db) or "/" in db:
        cannot(f"{name} is {value!r}, not <node>/<database>")
    return node, db


SOURCE = part("FAULT_SOURCE", "records/clinic")
LAB = part("FAULT_LAB", "lab/lab")
JOB = os.environ.get("FAULT_JOB") or "post-lab-orders"
try:
    THRESHOLD = int(os.environ.get("CHECK_THRESHOLD", "0") or "0")
except ValueError:
    cannot(f"CHECK_THRESHOLD is {os.environ.get('CHECK_THRESHOLD')!r}, not an integer")


def helper(argv, stdin=None):
    try:
        p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    except OSError as exc:
        cannot(f"{argv[0]}: {exc.strerror}")
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def query(db, text, **values):
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def too_soon(seconds, why):
    print(f"remaining={max(1, int(seconds))} {why}")
    sys.exit(3)


def next_run():
    out = subprocess.run([CHECK_RUNS, "next", JOB], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{JOB} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query(LAB, "SELECT extract(epoch FROM now())")[0][0])
tests = query(LAB, """
SELECT o.id, o.client_ref, o.priority, extract(epoch FROM o.ordered_at), t.id, t.request_id, t.status,
       x.turnaround_hours, extract(epoch FROM coalesce(t.released_at, t.not_performed_at))
  FROM lab_orders o JOIN lab_order_tests t ON t.order_id = o.id JOIN lab_tests x ON x.id = t.test_id
 WHERE o.account_id = 1 AND o.cancelled_at IS NULL AND t.request_id IS NOT NULL
   AND o.ordered_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.ordered_at, t.id
""", judged=judged)
requests = ",".join(sorted({t[5] for t in tests})) or "0"
urgent = {r for (r,) in query(SOURCE, f"SELECT id FROM requests WHERE priority = 'urgent' AND id IN ({requests})")}

violations, orders = [], {}
for order, ref, priority, posted, test, request, status, tat, done in tests:
    if request not in urgent:
        continue
    if priority != "urgent":
        violations.append(f"request {request} (urgent in the record) reached the lab as {priority} order "
                          f"{order} ({ref})")
        continue
    orders.setdefault(order, []).append((test, status, float(posted) + int(tat) * 3600,
                                         float(done) if done else None))
completed = []
for order, ts in orders.items():
    judged_tests = [t for t in ts if t[1] != "cancelled"]
    if judged_tests and all(t[3] is not None for t in judged_tests):
        completed.append(order)
        for test, _status, due, done in judged_tests:
            if done > due:
                violations.append(f"urgent order {order}'s test {test} answered at {iso(done)}, due by {iso(due)}")

if len(violations) > THRESHOLD:
    more = f" ({len(violations)} violations {window})" if len(violations) > 1 else ""
    print(f"urgent priority present: {violations[0]}{more}")
    sys.exit(1)
tolerated = (f"; {len(violations)} violations tolerated (threshold {THRESHOLD})" if violations else "")
if completed:
    print(f"urgent priority fixed: {len(orders)} urgent orders posted {window} urgent at the lab, "
          f"{len(completed)} answered within their turnaround{tolerated}")
    sys.exit(0)
if orders:
    first = min(due for ts in orders.values() for _t, _s, due, _d in ts)
    too_soon(first - now + 1, f"{len(orders)} urgent orders posted {window} urgent at the lab, none answered "
             f"yet; the first deadline is {iso(first)}{tolerated}")
too_soon(max(next_run(), WAIT), f"no urgent request posted {window}{tolerated}")
PY
