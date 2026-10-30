#!/bin/sh
# R4 fresh (shop-sales-reporting, v0.4 master spec 10.1, 12.1, 12.2): the
# latest successful rollup-hourly started within 70 minutes and read rows,
# and no run since the judged moment ended in error, was refused its
# connection, or read no row in business hours.
#
# Runs on the runner node (bi) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runner's log (the
# program's own parser), the runs with check-runs, and the target's
# rpt.etl_runs as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - A failure since then: a `run job=rollup-hourly ... phase=end
#   status=error` line, or a `skip job=rollup-hourly ...
#   reason=connection-refused` one (a source or target role refused, say).
# - Each successful run since then is tied to its rpt.etl_runs row by its
#   start (the script writes it in the run's transaction); one with no row,
#   or one reading no changed order between 08:00 and 20:00 customer time,
#   is a violation; so is a latest run older than 70 minutes or reading no
#   row.
# Exit 1: a failure or a violation, naming the run. Exit 0: none (the
# latest run read changed orders: the witness). Exit 3, with
# remaining= to the job's next run: no successful run since the judged
# moment and no failure. Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

TARGET = ("reporting", "reporting")  # the target part: node, database
JOB = "rollup-hourly"
FRESH = 70 * 60                      # seconds: the latest run's age at most
BUSINESS_HOURS = (8, 20)             # customer time, [from, to)
CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"R4 cannot be judged: {text}")
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


def runs(since):
    out = []
    for line in helper([CHECK_RUNS, "runs", JOB, since]).splitlines():
        start, end, _, ms = line.split()
        end = epoch(end)
        out.append((epoch(start) if start != "-" else end - int(ms[3:]) / 1000, end))
    return out


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

from gm_scheduler.runner import load_config         # noqa: E402 (the node's program)
from gm_scheduler.textlog import read_events        # noqa: E402

try:
    log = load_config()["log"]
    failures = [(at, event, fields) for at, event, fields, _ in read_events(log)
                if fields.get("job") == JOB and epoch(at) > judged
                and ((event == "run" and fields.get("phase") == "end"
                      and fields.get("status") == "error")
                     or (event == "skip" and fields.get("reason") == "connection-refused"))]
except Exception as exc:                            # the log or the configuration unreadable
    cannot(f"the runner's log: {exc}")
if failures:
    at, event, fields = failures[0]
    how = (f"was refused its connection (due {fields.get('at')})" if event == "skip" else
           "ended in error (" + ", ".join(f"{k}={fields[k]}" for k in ("sqlstate", "error")
                                           if k in fields) + ")")
    more = f" ({len(failures)} failed {window})" if len(failures) > 1 else ""
    print(f"R4 present: the {JOB} run at {at} {how}{more}")
    sys.exit(1)

after = runs(iso(judged))
if not after:
    out = subprocess.run([CHECK_RUNS, "next", JOB], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{JOB} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} no {JOB} run has "
          f"ended {window}")
    sys.exit(3)

rows = helper([CHECK_SQL, "-h", TARGET[0], "-d", TARGET[1]],
              "SELECT extract(epoch FROM e.started_at), coalesce(e.rows_read, -1), s.utc_offset_hours "
              "FROM rpt.etl_runs e, rpt.business_settings s "
              f"WHERE e.job = '{JOB}' AND e.finished_at IS NOT NULL "
              f"AND e.started_at > to_timestamp({judged - 3600})").splitlines()
ledger = [(float(a), int(b), int(c)) for a, b, c in (r.split("|") for r in rows)]


def ledger_of(start, end):
    """The run's rpt.etl_runs row: started within the run (log instants are
    whole seconds, truncated)."""
    return next((row for row in ledger if start - 1 <= row[0] <= end + 1), None)


violations = []
for start, end in after:
    row = ledger_of(start, end)
    if row is None:
        violations.append(f"the {JOB} run of {iso(start)} ended without its rpt.etl_runs row")
        continue
    local = datetime.fromtimestamp(start, timezone.utc) + timedelta(hours=row[2])
    if row[1] <= 0 and BUSINESS_HOURS[0] <= local.hour < BUSINESS_HOURS[1]:
        violations.append(f"the {JOB} run of {iso(start)} read no changed order at "
                          f"{local:%H:%M} customer time")
latest_start, latest_end = after[-1]
age = time.time() - latest_start
if age > FRESH:
    violations.append(f"the latest {JOB} run started at {iso(latest_start)}, {int(age // 60)} "
                      "minutes ago")
else:
    row = ledger_of(latest_start, latest_end)
    if row is not None and row[1] <= 0:
        violations.append(f"the latest {JOB} run, at {iso(latest_start)}, read no row")

if violations:
    more = f" ({len(violations)} violations)" if len(violations) > 1 else ""
    print(f"R4 present: {violations[0]}{more}")
    sys.exit(1)
print(f"R4 fixed: {len(after)} {JOB} runs {window}, none failed, the latest at "
      f"{iso(latest_start)}, each with its ledger row and changed orders read")
sys.exit(0)
PY
