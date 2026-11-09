#!/bin/sh
# IO2 one worklist entry per request (vet-imaging-orders, purpose 13;
# vet-machinery-domain.md, "vet-imaging-orders"): no request has two
# worklist entries, and every entry posted since the judged moment carries
# its request's accession (I- and the request's id), judged on every entry
# created since the judged moment and on every request they name. Judges
# runs (T230: the accession's uniqueness dropped and the retry posting
# again).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# and pacs are read as gm_check with check-sql; no job is ever run. Exit 0
# fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too soon
# (remaining=). Written for the clinic's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "IO2"
DB = ("records", "clinic")           # the source part: node, database
PACS = ("machines", "pacs")          # the target part: node, database
PURPOSE = "vet-imaging-orders"
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
WITH posted AS (SELECT DISTINCT request_id FROM mach_worklist WHERE created_at > to_timestamp(%(judged)s::float8))
SELECT p.request_id, count(w.id), bool_and(w.accession = 'I-' || p.request_id)
  FROM posted p JOIN mach_worklist w ON w.request_id = p.request_id
 GROUP BY p.request_id ORDER BY p.request_id
""", db=PACS, judged=judged)
posted = [(int(r), int(n), ok == "t") for r, n, ok in rows]
twice = [p for p in posted if p[1] > 1]
wrong = [p for p in posted if not p[2]]
if twice:
    r, n, _ = twice[0]
    more = f" ({len(twice)} requests {window})" if len(twice) > 1 else ""
    print(f"{INVARIANT} present: request {r} has {n} worklist entries{more}")
    sys.exit(1)
if wrong:
    r = wrong[0][0]
    print(f"{INVARIANT} present: request {r}'s worklist entry does not carry the accession I-{r}")
    sys.exit(1)
if posted:
    print(f"{INVARIANT} fixed: {len(posted)} worklist entries posted {window}, one per request, each "
          f"with its accession")
    sys.exit(0)
wait("post-imaging-orders", f"no worklist entry posted {window}")
PY
