#!/bin/sh
# IO1 each closed consultation's imaging requests sent (vet-imaging-orders,
# purpose 13; vet-machinery-domain.md, "vet-imaging-orders"): every imaging
# request of a consultation closed since the judged moment is sent, its
# worklist entry (accession I- and its id) in pacs, within 5 minutes of the
# close (2 for an urgent one), or cancelled. The close is the later of the
# consultation's end and the request's time. Judges triggers (T227: requests
# sent before their entry commits; T233: the post job on business hours
# only).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# and pacs are read as gm_check with check-sql; no job is ever run. Exit 0
# fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too soon
# (remaining=). Written for the clinic's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "IO1"
DB = ("records", "clinic")           # the source part: node, database
PACS = ("machines", "pacs")          # the target part: node, database
PURPOSE = "vet-imaging-orders"
DEADLINE = {"routine": 300, "urgent": 120}   # seconds
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
SELECT r.id, r.priority, extract(epoch FROM greatest(c.ended_at, r.requested_at)), r.state,
       extract(epoch FROM r.sent_at)
  FROM requests r JOIN consultations c ON c.id = r.consultation_id
 WHERE r.kind = 'imaging' AND c.ended_at > to_timestamp(%(judged)s::float8)
 ORDER BY c.ended_at, r.id
""", judged=judged)
items = [(int(i), p, float(t), s, float(x) if x else None) for i, p, t, s, x in rows]
entries = {}
if items:
    for rid, acc, at in query("""
SELECT request_id, accession, extract(epoch FROM created_at) FROM mach_worklist
 WHERE request_id = ANY (string_to_array(%(ids)s, ',')::int[])
""", db=PACS, ids=",".join(str(i[0]) for i in items)):
        entries.setdefault(int(rid), []).append((acc, float(at) if at else None))
due = [i for i in items if now > i[2] + DEADLINE[i[1]]]
bad = []
for rid, prio, closed, state, sent in due:
    limit = closed + DEADLINE[prio]
    mine = [e for e in entries.get(rid, []) if e[0] == f"I-{rid}"]
    if state == "cancelled":
        continue
    if state == "requested":
        bad.append((rid, prio, f"still requested {int(now - closed)} s after its consultation closed"))
    elif sent is not None and sent > limit:
        bad.append((rid, prio, f"sent {int(sent - closed)} s after its consultation closed"))
    elif not mine:
        bad.append((rid, prio, f"{state}, but no worklist entry I-{rid} in pacs"))
if bad:
    rid, prio, how = bad[0]
    more = f" ({len(bad)} requests {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {prio} imaging request {rid}: {how}{more}")
    sys.exit(1)
if due:
    sent = sum(1 for i in due if i[3] != "cancelled")
    print(f"{INVARIANT} fixed: {len(due)} imaging requests of consultations closed {window}, {sent} sent "
          f"with their entry in time, {len(due) - sent} cancelled")
    sys.exit(0)
if items:
    first = min(items, key=lambda i: i[2] + DEADLINE[i[1]])
    later(first[2] + DEADLINE[first[1]] - now, f"request {first[0]} is still to be judged")
wait("post-imaging-orders", f"no imaging request of a consultation closed {window}")
PY
