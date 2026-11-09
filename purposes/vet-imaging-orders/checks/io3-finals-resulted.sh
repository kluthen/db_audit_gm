#!/bin/sh
# IO3 finals copied back, never a preliminary (vet-imaging-orders, purpose
# 13; vet-machinery-domain.md, "vet-imaging-orders"): every final report
# signed since the judged moment has its request resulted within 10 minutes
# of its entry's first final, and no request resulted since the judged
# moment lacks a final signed before it was resulted. Judges runs (T229: a
# preliminary read as final; T231: the watermark taken from the run's start,
# finals signed during a run missed).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# and pacs are read as gm_check with check-sql; no job is ever run. Exit 0
# fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too soon
# (remaining=). Written for the clinic's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "IO3"
DB = ("records", "clinic")           # the source part: node, database
PACS = ("machines", "pacs")          # the target part: node, database
PURPOSE = "vet-imaging-orders"
DEADLINE = 600                       # seconds, 10 minutes
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
finals = query("""
SELECT w.request_id, extract(epoch FROM min(p.signed_at)),
       extract(epoch FROM min(p.signed_at) FILTER (WHERE p.signed_at > to_timestamp(%(judged)s::float8)))
  FROM mach_reports p JOIN mach_studies s ON s.id = p.study_id JOIN mach_worklist w ON w.id = s.worklist_id
 WHERE p.kind = 'final' AND p.status = 'signed'
 GROUP BY w.request_id
HAVING max(p.signed_at) > to_timestamp(%(judged)s::float8)
 ORDER BY 2, 1
""", db=PACS, judged=judged)
finals = [(int(r), float(first), float(new) if new else None) for r, first, new in finals]
resulted = query("""
SELECT r.id, extract(epoch FROM r.resulted_at) FROM requests r
 WHERE r.kind = 'imaging' AND r.resulted_at > to_timestamp(%(judged)s::float8) ORDER BY r.resulted_at, r.id
""", judged=judged)
resulted = [(int(r), float(a)) for r, a in resulted]
ids = sorted({f[0] for f in finals} | {r[0] for r in resulted})
state, first = {}, {}
if ids:
    for rid, st, at in query("""
SELECT id, state, extract(epoch FROM resulted_at) FROM requests
 WHERE id = ANY (string_to_array(%(ids)s, ',')::int[])
""", ids=",".join(map(str, ids))):
        state[int(rid)] = (st, float(at) if at else None)
    for rid, at in query("""
SELECT w.request_id, extract(epoch FROM min(p.signed_at))
  FROM mach_reports p JOIN mach_studies s ON s.id = p.study_id JOIN mach_worklist w ON w.id = s.worklist_id
 WHERE p.kind = 'final' AND p.status = 'signed' AND w.request_id = ANY (string_to_array(%(ids)s, ',')::int[])
 GROUP BY w.request_id
""", db=PACS, ids=",".join(map(str, ids))):
        first[int(rid)] = float(at)
early = [(r, a) for r, a in resulted if r not in first or first[r] > a]
if early:
    r, a = early[0]
    how = "no final at all" if r not in first else f"its first final signed {int(first[r] - a)} s later"
    more = f" ({len(early)} requests {window})" if len(early) > 1 else ""
    print(f"{INVARIANT} present: request {r} resulted at {iso(a)} with {how} (a preliminary){more}")
    sys.exit(1)
due = [f for f in finals if now > f[1] + DEADLINE]
late = []
for rid, signed, _ in due:
    st, at = state.get(rid, (None, None))
    if st == "cancelled":
        continue
    if st != "resulted" or at is None or at > signed + DEADLINE:
        how = f"still {st}" if st != "resulted" else f"resulted {int(at - signed)} s after"
        late.append((rid, how))
if late:
    rid, how = late[0]
    more = f" ({len(late)} finals {window})" if len(late) > 1 else ""
    print(f"{INVARIANT} present: request {rid}'s final signed, {how}, past 10 minutes{more}")
    sys.exit(1)
if due:
    print(f"{INVARIANT} fixed: {len(due)} finals signed {window}, each request resulted within 10 minutes; "
          f"{len(resulted)} requests resulted {window}, none on a preliminary")
    sys.exit(0)
if finals:
    later(finals[0][1] + DEADLINE - now, f"request {finals[0][0]}'s final is still to be judged")
wait("fetch-imaging-reports", f"no final signed {window}")
PY
