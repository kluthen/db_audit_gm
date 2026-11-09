#!/bin/sh
# LO2 each request on one lab order test (vet-lab-centre-orders, v0.5 master
# spec 12.2 purpose 1; clinic-purposes.md section 5): no consultation's
# requests reach the lab as two orders; each request id appears on one lab
# order test only. Judged by runs.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment and the posting job's runs with
# check-runs, the lab's orders as gm_check with check-sql (capture W4 item 0).
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - Exit 1: a request id carried by the centre's account (1) on two lab order
#   tests or more, one of them on an order received since then.
#   Exit 0: none, with at least one successful post-lab-orders run and one
#   centre order posted since then (the witness). Exit 3 otherwise,
#   remaining= the job's next run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "LO2"
LAB = ("lab", "lab")                 # the lab's database (the api part's): node, database
JOB = "post-lab-orders"
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

dups = query(LAB, """
SELECT t.request_id, count(*), string_agg(DISTINCT o.client_ref, ',')
  FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = 1 AND t.request_id IN (
         SELECT t2.request_id FROM lab_order_tests t2 JOIN lab_orders o2 ON o2.id = t2.order_id
          WHERE o2.account_id = 1 AND o2.ordered_at > to_timestamp(%(judged)s::float8)
            AND t2.request_id IS NOT NULL)
 GROUP BY t.request_id HAVING count(*) > 1 ORDER BY t.request_id
""", judged=judged)
if dups:
    request, n, refs = dups[0]
    more = f" ({len(dups)} requests on more than one test)" if len(dups) > 1 else ""
    print(f"{INVARIANT} present: request {request} is on {n} lab order tests (orders {refs}){more}")
    sys.exit(1)
runs = helper([CHECK_RUNS, "runs", JOB, iso(judged)]).splitlines()
(posted,) = query(LAB, "SELECT count(*) FROM lab_orders WHERE account_id = 1 "
                       "AND ordered_at > to_timestamp(%(judged)s::float8)", judged=judged)[0]
if runs and int(posted):
    print(f"{INVARIANT} fixed: {posted} centre orders posted {window} in {len(runs)} runs of {JOB}, each "
          "request on one lab order test")
    sys.exit(0)
too_soon(next_run(JOB), f"{len(runs)} runs of {JOB} and {posted} centre orders {window}")
PY
