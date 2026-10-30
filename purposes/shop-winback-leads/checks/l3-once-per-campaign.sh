#!/bin/sh
# L3 once per campaign (shop-winback-leads, v0.4 master spec 10.2, 12.1 to
# 12.3): at most one lead per (campaign, customer). By design the table's
# unique constraint holds it; the check judges the rows, not the constraint.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: a (campaign, customer) with two leads or more, one of them
#   extracted since the judged moment (past duplicates never count, 12.2).
# - Witness (12.3): leads of an active campaign extracted before the latest
#   run's start, which a run ignoring "not yet a lead" would extract again.
# Exit 1: a duplicate, naming its run. Exit 0: every run since clean, a
# witness at the latest. Exit 3, remaining= to the job's next run: no run
# since the judged moment, or none with a witness. Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "L3"
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
SELECT campaign_id, customer_id, count(*), extract(epoch FROM max(extracted_at))
  FROM leads
 GROUP BY campaign_id, customer_id
HAVING count(*) > 1 AND max(extracted_at) > to_timestamp(%(judged)s::float8)
 ORDER BY max(extracted_at), customer_id
""", judged=judged)
if bad:
    campaign, customer, n, at = bad[0]
    run = run_of(float(at), rs)
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} duplicated leads {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {named} extracted customer {customer} again for campaign "
          f"{campaign}, {n} leads{more}")
    sys.exit(1)

latest = rs[-1][0]
witness = int(query("""
SELECT count(*) FROM leads l JOIN campaigns k ON k.id = l.campaign_id
 WHERE k.active AND l.extracted_at < to_timestamp(%(latest)s::float8)
""", latest=latest)[0][0])
if witness == 0:
    too_soon(JOB, f"{len(rs)} {JOB} runs {window}, clean, but the campaign had no lead before "
                  "the latest: none could have been extracted twice")
print(f"{INVARIANT} fixed: {len(rs)} {JOB} runs {window}, no lead twice; {witness} leads "
      "existed before the latest run")
sys.exit(0)
PY
