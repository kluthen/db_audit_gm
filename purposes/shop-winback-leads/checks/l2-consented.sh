#!/bin/sh
# L2 consented (shop-winback-leads, v0.4 master spec 10.2, 9.3, 12.1 to
# 12.3): every lead extracted since the judged moment had marketing consent
# at its extracted_at: its latest marketing-email consent event at or before
# it was a grant. The opt-in flag is never read.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: a lead without consent at its extracted_at and a minute
#   before it: a withdrawal still committing when the job read (or a grant
#   just committed) is not held against it.
# - Witness (12.3): customers of the segment at the latest run's start
#   (last order 60 to 365 days before it), not yet leads, whose latest
#   consent event then is a withdrawal following an earlier grant: the
#   customers a job judging consent wrongly would take.
# Exit 1: a lead without consent, naming its run. Exit 0: every run since
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

INVARIANT = "L2"
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
       coalesce(CASE WHEN consent.granted THEN 'granted' ELSE 'withdrawn' END
                || ' at ' || to_char(consent.at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                || ' (' || consent.source || ')', 'no consent event')
  FROM leads l
  LEFT JOIN LATERAL (
       SELECT e.granted, e.at, e.source FROM consent_events e
        WHERE e.customer_id = l.customer_id AND e.purpose = 'marketing-email'
          AND e.at <= l.extracted_at
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent ON true
  LEFT JOIN LATERAL (
       SELECT e.granted FROM consent_events e
        WHERE e.customer_id = l.customer_id AND e.purpose = 'marketing-email'
          AND e.at <= l.extracted_at - interval '1 minute'
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS earlier ON true
 WHERE l.extracted_at > to_timestamp(%(judged)s::float8)
   AND coalesce(consent.granted, false) = false
   AND coalesce(earlier.granted, false) = false
 ORDER BY l.extracted_at, l.customer_id
""", judged=judged)
if bad:
    customer, at, latest_event = bad[0]
    run = run_of(float(at), rs)
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} leads without consent {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {named} extracted customer {customer} without consent, "
          f"the latest event then {latest_event}{more}")
    sys.exit(1)

latest = rs[-1][0]
witness = int(query("""
SELECT count(*)
  FROM customers c
 CROSS JOIN LATERAL (
       SELECT e.granted, e.at FROM consent_events e
        WHERE e.customer_id = c.id AND e.purpose = 'marketing-email'
          AND e.at <= to_timestamp(%(latest)s::float8)
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent
 WHERE c.last_order_at <= to_timestamp(%(latest)s::float8) - interval '60 days'
   AND c.last_order_at >= to_timestamp(%(latest)s::float8) - interval '365 days'
   AND NOT consent.granted
   AND EXISTS (SELECT 1 FROM consent_events g WHERE g.customer_id = c.id
                  AND g.purpose = 'marketing-email' AND g.granted AND g.at < consent.at)
   AND NOT EXISTS (SELECT 1 FROM leads l WHERE l.customer_id = c.id
                      AND l.extracted_at < to_timestamp(%(latest)s::float8))
""", latest=latest)[0][0])
if witness == 0:
    too_soon(JOB, f"{len(rs)} {JOB} runs {window}, clean, but no customer of the segment had "
                  "withdrawn consent at the latest: none could have been taken without it")
print(f"{INVARIANT} fixed: {len(rs)} {JOB} runs {window}, every lead with consent; {witness} "
      "customers of the segment had withdrawn consent at the latest run")
sys.exit(0)
PY
