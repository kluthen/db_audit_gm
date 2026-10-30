#!/bin/sh
# R2 counted once (shop-sales-reporting, v0.4 master spec 10.1, 12.1 to
# 12.3): each (hour, category) has one row in rpt.sales_hourly, and a day's
# revenue in rpt.sales_daily equals the sum of its hours' revenue.
#
# Runs on the runner node (bi) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs of both jobs with
# check-runs and the target as gm_check with check-sql (one statement, one
# snapshot); it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - Judged: the rows a run since then wrote (their run_id's rpt.etl_runs row
#   finished after it), of either job.
# Exit 1: a duplicated (hour, category), or a day whose revenue is not the
# sum of its hours', naming the run and the row. Exit 0: none, and at least
# one such day had hours (the witness). Exit 3, with remaining= to the next
# run of either job: no run since the judged moment, or no witness yet.
# Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone
from decimal import Decimal

TARGET = ("reporting", "reporting")  # the target part: node, database
JOBS = ("rollup-hourly", "rollup-close")
CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"R2 cannot be judged: {text}")
    sys.exit(2)


def helper(argv, stdin=None):
    p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def too_soon(text):
    best = None
    for job in JOBS:
        out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
        if "remaining=" in out:
            s = int(out.split("remaining=")[1].split()[0])
            best = s if best is None else min(best, s)
    if best is None:
        cannot(f"neither {' nor '.join(JOBS)} is due in the loaded jobs.yaml: no run to wait for")
    print(f"remaining={max(1, best)} {text}")
    sys.exit(3)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
ran = sum(len(helper([CHECK_RUNS, "runs", job, iso(judged)]).splitlines()) for job in JOBS)
if not ran:
    too_soon(f"no run of {' or '.join(JOBS)} has ended since {iso(judged)}")

rows = helper([CHECK_SQL, "-h", TARGET[0], "-d", TARGET[1]], f"""
SELECT 'dup', to_char(h.hour_local, 'YYYY-MM-DD HH24:MI') || ' ' || h.category, h.n::text, '',
       e.job, extract(epoch FROM e.started_at)::text
  FROM (SELECT hour_local, category, count(*) AS n, max(run_id) AS run_id
          FROM rpt.sales_hourly GROUP BY 1, 2 HAVING count(*) > 1) h
  JOIN rpt.etl_runs e ON e.id = h.run_id
 WHERE e.finished_at > to_timestamp({judged})
UNION ALL
SELECT 'day', to_char(d.day_local, 'YYYY-MM-DD'), d.revenue::text,
       coalesce(sum(h.revenue), 0)::text || ' ' || count(h.hour_local)::text,
       e.job, extract(epoch FROM e.started_at)::text
  FROM rpt.sales_daily d
  JOIN rpt.etl_runs e ON e.id = d.run_id
  LEFT JOIN rpt.sales_hourly h ON h.hour_local >= d.day_local AND h.hour_local < d.day_local + 1
 WHERE e.finished_at > to_timestamp({judged})
 GROUP BY d.day_local, d.revenue, e.job, e.started_at
""").splitlines()

violations, days, witness = [], 0, False
for line in rows:
    kind, what, value, hours, job, started = line.split("|")
    run = f"the {job} run of {iso(float(started))}"
    if kind == "dup":
        violations.append(f"{run} left hour {what} in {value} rows")
        continue
    days += 1
    total, count = hours.split()
    if Decimal(value) != Decimal(total):
        violations.append(f"{run} left day {what} at revenue {value} where its {count} hour rows "
                          f"sum to {total}")
    elif int(count) > 0:
        witness = True

window = f"since {iso(judged)}"
if violations:
    more = f" ({len(violations)} rows wrong)" if len(violations) > 1 else ""
    print(f"R2 present: {violations[0]}{more}")
    sys.exit(1)
if not witness:
    too_soon(f"{ran} runs {window}, but no day they wrote has hours yet")
print(f"R2 fixed: {ran} runs {window}, every hour once and the {days} days they wrote equal to "
      "the sum of their hours")
sys.exit(0)
PY
