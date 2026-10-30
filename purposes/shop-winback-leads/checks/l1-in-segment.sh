#!/bin/sh
# L1 in segment (shop-winback-leads, v0.4 master spec 10.2, 12.1 to 12.3):
# every lead extracted since the judged moment had, at its extracted_at, no
# order in the previous 60 days and one within 365.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A lead's last order at its extracted_at: the latest of its orders in
#   orders placed at or before it, else customers.last_order_at when that is
#   not later (the archived history), counting only orders placed a minute
#   or more before the extraction: a checkout still committing (it holds its
#   transaction a few seconds) was not there for the job to see. A lead
#   whose customer ordered since and has no order in orders before it is
#   not judged: its last order then is in no table any more.
# - Witness (12.3): a customer with no order in orders before the judged
#   moment ordering between it and the latest run's start, with consent at
#   that start and not yet a lead: the material a wrong segment would take.
# Exit 1: a lead out of the segment, naming its run. Exit 0: every run since
# clean, a witness at the latest. Exit 3, remaining= to the job's next run:
# no run since the judged moment, or none with a witness. Exit 2: it cannot
# judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "L1"
DB = ("db", "shop")                  # the source part: node, database
JOB = "leads-extract"
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


def runs(job, since):
    """(start, end, rows) of each successful run of `job` ended after `since`."""
    out = []
    for line in helper([CHECK_RUNS, "runs", job, iso(since)]).splitlines():
        start, end, rows, ms = line.split()
        end = epoch(end)
        out.append((epoch(start) if start != "-" else end - float(ms[3:]) / 1000, end,
                    int(rows[5:])))
    return out


def query(text, **values):
    argv = [CHECK_SQL, "-h", DB[0], "-d", DB[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def too_soon(job, why):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def run_of(ts, rs):
    """The run in whose transaction a row written at `ts` was (log instants are
    whole seconds, truncated)."""
    return next((r for r in rs if r[0] - 1 <= ts < r[1] + 1), None)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
rs = runs(JOB, judged)
if not rs:
    too_soon(JOB, f"no {JOB} run has ended {window}")

bad = query("""
SELECT l.customer_id, extract(epoch FROM l.extracted_at),
       CASE WHEN k.last_known IS NULL THEN 'none'
            ELSE floor(extract(epoch FROM l.extracted_at - k.last_known) / 86400)::text END
  FROM leads l
  JOIN customers c ON c.id = l.customer_id
 CROSS JOIN LATERAL (SELECT max(o.placed_at) AS placed FROM orders o
                      WHERE o.customer_id = l.customer_id
                        AND o.placed_at <= l.extracted_at - interval '1 minute') AS r
 CROSS JOIN LATERAL (
       SELECT CASE WHEN c.last_order_at <= l.extracted_at - interval '1 minute'
                   THEN greatest(r.placed, c.last_order_at) ELSE r.placed END AS last_known) AS k
 WHERE l.extracted_at > to_timestamp(%(judged)s::float8)
   AND (k.last_known > l.extracted_at - interval '60 days'
        OR k.last_known < l.extracted_at - interval '365 days'
        OR (k.last_known IS NULL AND c.last_order_at IS NULL))
 ORDER BY l.extracted_at, l.customer_id
""", judged=judged)
if bad:
    customer, at, days = bad[0]
    run = run_of(float(at), rs)
    how = "had never ordered" if days == "none" else f"had last ordered {days} days before"
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} leads out of the segment {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {named} extracted customer {customer}, who {how}{more}")
    sys.exit(1)

latest = rs[-1][0]
witness = int(query("""
SELECT count(DISTINCT o.customer_id)
  FROM orders o
 CROSS JOIN LATERAL (
       SELECT e.granted FROM consent_events e
        WHERE e.customer_id = o.customer_id AND e.purpose = 'marketing-email'
          AND e.at <= to_timestamp(%(latest)s::float8)
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent
 WHERE o.placed_at > to_timestamp(%(judged)s::float8)
   AND o.placed_at < to_timestamp(%(latest)s::float8)
   AND consent.granted
   AND NOT EXISTS (SELECT 1 FROM orders p WHERE p.customer_id = o.customer_id
                      AND p.placed_at <= to_timestamp(%(judged)s::float8))
   AND NOT EXISTS (SELECT 1 FROM leads l WHERE l.customer_id = o.customer_id
                      AND l.extracted_at < to_timestamp(%(latest)s::float8))
""", judged=judged, latest=latest)[0][0])
if witness == 0:
    too_soon(JOB, f"{len(rs)} {JOB} runs {window}, clean, but no returning customer with "
                  "consent ordered before the latest: none could have been taken out of segment")
print(f"{INVARIANT} fixed: {len(rs)} {JOB} runs {window}, every lead in the segment; "
      f"{witness} returning customers with consent had ordered before the latest run")
sys.exit(0)
PY
