#!/bin/sh
# IO4 end to end (vet-imaging-orders, purpose 13; vet-machinery-domain.md,
# "vet-imaging-orders"): every imaging request posted (sent) since the
# judged moment has its final signed within its turnaround and is resulted,
# or is cancelled: urgent within 18 hours of its posting, routine by the end
# of the third working day (Monday to Friday, the customer's zone) after its
# local date. A request settled (resulted or cancelled) is judged at once; one
# still open, at its turnaround. Judges the round trip end to end (T228: the
# priority dropped, an urgent study on the routine schedule; T232:
# cancellations never read back; any of T227 to T233 that breaks it).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# and pacs are read as gm_check with check-sql; no job is ever run. Exit 0
# fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too soon
# (remaining=). Written for the clinic's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "IO4"
DB = ("records", "clinic")           # the source part: node, database
PACS = ("machines", "pacs")          # the target part: node, database
PURPOSE = "vet-imaging-orders"
URGENT_HOURS = 18
ROUTINE_DAYS = 3                     # working days after the local date
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
SELECT r.id, r.priority, extract(epoch FROM r.sent_at), r.state,
       extract(epoch FROM CASE r.priority
         WHEN 'urgent' THEN r.sent_at + make_interval(hours => %(hours)s::int)
         ELSE ((SELECT d FROM generate_series((r.sent_at AT TIME ZONE b.timezone)::date + 1,
                                              (r.sent_at AT TIME ZONE b.timezone)::date + 14, interval '1 day') AS d
                 WHERE extract(isodow FROM d) < 6 ORDER BY d OFFSET %(days)s::int - 1 LIMIT 1)
               + interval '1 day') AT TIME ZONE b.timezone END)
  FROM requests r CROSS JOIN business_settings b
 WHERE r.kind = 'imaging' AND r.sent_at > to_timestamp(%(judged)s::float8)
 ORDER BY r.sent_at, r.id
""", judged=judged, hours=URGENT_HOURS, days=ROUTINE_DAYS)
items = [(int(i), p, float(s), st, float(d)) for i, p, s, st, d in rows]
first = {}
if items:
    for rid, at in query("""
SELECT w.request_id, extract(epoch FROM min(p.signed_at))
  FROM mach_reports p JOIN mach_studies s ON s.id = p.study_id JOIN mach_worklist w ON w.id = s.worklist_id
 WHERE p.kind = 'final' AND p.status = 'signed' AND w.request_id = ANY (string_to_array(%(ids)s, ',')::int[])
 GROUP BY w.request_id
""", db=PACS, ids=",".join(str(i[0]) for i in items)):
        first[int(rid)] = float(at)
bad, good = [], []
for rid, prio, sent, st, limit in items:
    if st == "cancelled":
        good.append(rid)
    elif rid in first and first[rid] > limit:
        bad.append((rid, prio, f"its final signed {(first[rid] - sent) / 3600:.1f} h after its posting, "
                               f"past its turnaround"))
    elif st == "resulted" and rid in first:
        good.append(rid)
    elif now > limit:
        how = "resulted with no final" if st == "resulted" else f"still {st}, no final"
        bad.append((rid, prio, f"{how} at its turnaround ({iso(limit)})"))
if bad:
    rid, prio, how = bad[0]
    more = f" ({len(bad)} requests {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {prio} imaging request {rid}: {how}{more}")
    sys.exit(1)
if good:
    print(f"{INVARIANT} fixed: {len(good)} imaging requests posted {window} through their round trip, "
          f"resulted on a final within the turnaround or cancelled ({len(items) - len(good)} still within it)")
    sys.exit(0)
if items:
    first_due = min(items, key=lambda i: i[4])
    later(first_due[4] - now, f"request {first_due[0]} is still within its turnaround")
wait("post-imaging-orders", f"no imaging request posted {window}")
PY
