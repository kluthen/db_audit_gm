#!/bin/sh
# LO3 each release resulted, nothing resulted unreleased (vet-lab-centre-
# orders, v0.5 master spec 12.2 purpose 1; clinic-purposes.md section 5):
# every centre test released since the judged moment has its request resulted
# within 10 minutes, and no request is resulted while its test is not
# released. Judged by runs.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment with check-runs, the lab's tests and
# the record's requests as gm_check with check-sql (capture W4 item 0).
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - Exit 1: a request resulted since then whose lab test (the centre's
#   account, by request_id) is not released, or released after it; or a
#   centre test released since then whose request is not resulted 10 minutes
#   after the release, or resulted later.
#   Exit 0: neither, with at least one release at least 10 minutes old (the
#   witness). Exit 3 otherwise, remaining= until the youngest pending release
#   is 10 minutes old, or the next fetch run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "LO3"
CLINIC = ("records", "clinic")       # the source and target parts: node, database
LAB = ("lab", "lab")                 # the lab's database (the api part's)
JOB = "fetch-lab-results"
WITHIN = 10 * 60                     # seconds from the release to resulted
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

now = float(query(CLINIC, "SELECT extract(epoch FROM now())")[0][0])
resulted = {int(r): float(t) for r, t in query(CLINIC, """
SELECT id, extract(epoch FROM resulted_at) FROM requests
 WHERE state = 'resulted' AND resulted_at > to_timestamp(%(judged)s::float8) ORDER BY resulted_at, id
""", judged=judged)}
tests = {}
for r, status, rel in query(LAB, """
SELECT t.request_id, t.status, extract(epoch FROM t.released_at)
  FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = 1 AND t.request_id = ANY(string_to_array(%(ids)s, ',')::integer[])
""", ids=ids(resulted)):
    tests[int(r)] = (status, num(rel))
early = [r for r, at in resulted.items()
         if tests.get(r, ("", None))[0] != "released" or tests[r][1] is None or tests[r][1] > at]
if early:
    r = early[0]
    status = tests.get(r, ("no lab order test", None))[0]
    print(f"{INVARIANT} present: request {r} resulted at {iso(resulted[r])} while its lab test is "
          f"{status}" + (f" ({len(early)} requests resulted unreleased {window})" if len(early) > 1 else ""))
    sys.exit(1)
releases = [(int(r), float(rel)) for r, rel in query(LAB, """
SELECT t.request_id, extract(epoch FROM t.released_at)
  FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = 1 AND t.request_id IS NOT NULL AND t.status = 'released'
   AND t.released_at > to_timestamp(%(judged)s::float8)
 ORDER BY t.released_at, t.request_id
""", judged=judged)]
states = {int(r): (s, num(t)) for r, s, t in query(CLINIC, """
SELECT id, state, extract(epoch FROM resulted_at) FROM requests
 WHERE id = ANY(string_to_array(%(ids)s, ',')::integer[])
""", ids=ids(r for r, _ in releases))}


def resulted_at(r):
    state, at = states.get(r, ("", None))
    return at if state == "resulted" else None


late = [(r, rel) for r, rel in releases
        if (resulted_at(r) is not None and resulted_at(r) > rel + WITHIN)
        or (resulted_at(r) is None and now > rel + WITHIN)]
if late:
    r, rel = late[0]
    at = resulted_at(r)
    how = (f"resulted {int(at - rel)} s after" if at is not None
           else f"still {states.get(r, ('missing', None))[0]} {int(now - rel)} s after")
    print(f"{INVARIANT} present: request {r}'s test released at {iso(rel)}, {how}"
          + (f" ({len(late)} releases not resulted in time {window})" if len(late) > 1 else ""))
    sys.exit(1)
old = [x for x in releases if now > x[1] + WITHIN]
if old:
    print(f"{INVARIANT} fixed: {len(old)} centre tests released {window} at least 10 minutes ago, each "
          f"request resulted within 10 minutes; {len(resulted)} requests resulted, none unreleased")
    sys.exit(0)
if releases:
    too_soon(releases[0][1] + WITHIN - now + 1, f"{len(releases)} centre tests released {window}, the "
             f"oldest at {iso(releases[0][1])}")
too_soon(next_run(JOB) + WITHIN, f"no centre test released {window}")
PY
