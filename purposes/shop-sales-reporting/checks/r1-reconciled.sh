#!/bin/sh
# R1 reconciled (shop-sales-reporting, v0.4 master spec 10.1, 12.1 to 12.3):
# for every hour and day the hourly roll-up's runs since the judged moment
# were due to publish, rpt.sales_hourly and rpt.sales_daily hold the
# source's orders, units and revenue for that local hour or day (and a
# day's invoiced revenue), counting the source's orders as they stood at
# the run's start.
#
# Runs on the runner node (bi) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# both databases as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since).
# - A bucket (an hour and category, or a day) is compared at the latest
#   run L since then only when the source has not changed it since L's
#   start less SETTLE seconds (its last order placed, or for a day its last
#   order invoiced, before that): the source then stands as L found it. A
#   closed day is compared on its invoiced revenue only (its orders and
#   revenue are the nightly close's, R3).
# - A difference counts when the run due to publish it ran since the
#   judged moment: the hourly run that last wrote the bucket did, or the
#   source's last change came after the start of the last run before the
#   judged moment. An older difference is a past violation, left as
#   evidence.
# Exit 1: a counted difference, naming the run and one bucket. Exit 0: none,
# and the runs had a witness: a published hour of orders, and a past day
# whose invoicing (the 12:00 close-of-day) came after it ended. Exit 3, with
# remaining= to the job's next run: no run since the judged moment, or no
# witness yet. Exit 2: it cannot judge (a helper failed).
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

SOURCE = ("db", "shop")              # the source part: node, database
TARGET = ("reporting", "reporting")  # the target part: node, database
JOB = "rollup-hourly"
SETTLE = 60                          # seconds: a change older than this before a run's start
                                     # was committed when the run read the source
CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"R1 cannot be judged: {text}")
    sys.exit(2)


def helper(argv, stdin=None):
    p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def sql(part, statement):
    out = helper([CHECK_SQL, "-h", part[0], "-d", part[1]], statement)
    return [line.split("|") for line in out.splitlines()]


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def runs(job):
    """Every successful run of `job` in the log, oldest first: (start, end)."""
    out = []
    for line in helper([CHECK_RUNS, "runs", job, "1970-01-01T00:00:00Z"]).splitlines():
        start, end, _, ms = line.split()
        end = epoch(end)
        out.append((epoch(start) if start != "-" else end - int(ms[3:]) / 1000, end))
    return out


def too_soon(text):
    out = subprocess.run([CHECK_RUNS, "next", JOB], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{JOB} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {text}")
    sys.exit(3)


since = os.environ.get("CHECK_SINCE", "")
judged = epoch(helper([CHECK_RUNS, "since", since]).strip())
every = runs(JOB)
after = [r for r in every if r[1] > judged]
if not after:
    too_soon(f"no {JOB} run has ended since {iso(judged)}")
latest_start = after[-1][0]
before = [r for r in every if r[1] <= judged]
last_before = before[-1][0] if before else None


def due_since(change):
    """Whether the run due to pick up a source change at `change` ran since
    the judged moment."""
    return last_before is None or change > last_before - SETTLE


def responsible(change):
    """The start of the first run that read the source after `change`."""
    return next((s for s, _ in every if s - SETTLE >= change), latest_start)


(tz, offset), = sql(SOURCE, "SELECT timezone, utc_offset_hours FROM business_settings")
offset = timedelta(hours=int(offset))


def utc(local):
    return (local - offset).replace(tzinfo=timezone.utc).timestamp()


ledger = {row[0]: (row[1], float(row[2]) if row[2] else None, float(row[3]))
          for row in sql(TARGET, "SELECT id, job, extract(epoch FROM finished_at), "
                                 "extract(epoch FROM started_at) FROM rpt.etl_runs")}


def written_since(run_id):
    """(written by an hourly run since the judged moment, its start)."""
    job, finished, started = ledger.get(run_id, (None, None, None))
    return job == JOB and finished is not None and finished > judged, started


hours_t = {(r[0], r[1]): (tuple(Decimal(v) for v in r[2:5]), r[5]) for r in sql(TARGET,
           "SELECT to_char(hour_local, 'YYYY-MM-DD HH24:MI'), category, orders, units, revenue, "
           "run_id FROM rpt.sales_hourly")}
days_t = {r[0]: (r[1] == "closed", tuple(Decimal(v) for v in r[2:5]), r[5]) for r in sql(TARGET,
          "SELECT to_char(day_local, 'YYYY-MM-DD'), CASE WHEN closed THEN 'closed' END, orders, revenue, "
          "invoiced_revenue, "
          "run_id FROM rpt.sales_daily")}

# The window: from two local days before the judged moment, or the oldest
# bucket an hourly run since then wrote, whichever is older.
first = (datetime.fromtimestamp(judged, timezone.utc).replace(tzinfo=None) + offset).date() \
    - timedelta(days=2)
for (hour, _), (_, run_id) in hours_t.items():
    if written_since(run_id)[0]:
        first = min(first, date.fromisoformat(hour[:10]))
for day, (_, _, run_id) in days_t.items():
    if written_since(run_id)[0]:
        first = min(first, date.fromisoformat(day))
lo = f"'{first.isoformat()}'::timestamp AT TIME ZONE s.timezone"

hours_s = {(r[0], r[1]): (tuple(Decimal(v) for v in r[2:5]), float(r[5])) for r in sql(SOURCE,
           "SELECT to_char(date_trunc('hour', o.placed_at AT TIME ZONE s.timezone), "
           "'YYYY-MM-DD HH24:MI'), p.category, count(DISTINCT o.id), sum(l.quantity), "
           "sum(l.line_total), extract(epoch FROM max(o.placed_at)) "
           "FROM orders o JOIN order_lines l ON l.order_id = o.id "
           "JOIN products p ON p.id = l.product_id, business_settings s "
           f"WHERE o.placed_at >= {lo} GROUP BY 1, 2")}
days_s = {r[0]: (tuple(Decimal(v) for v in r[1:4]), float(r[4]), float(r[5]) if r[5] else None)
          for r in sql(SOURCE,
          "SELECT to_char((o.placed_at AT TIME ZONE s.timezone)::date, 'YYYY-MM-DD'), count(*), "
          "sum(o.total), coalesce(sum(o.total) FILTER (WHERE o.status = 'invoiced'), 0), "
          "extract(epoch FROM max(o.placed_at)), "
          "extract(epoch FROM max(o.updated_at) FILTER (WHERE o.status = 'invoiced')) "
          f"FROM orders o, business_settings s WHERE o.placed_at >= {lo} GROUP BY 1")}

violations, compared, witness_hour, witness_day = [], 0, False, False


def judge(what, figures_t, figures_s, change, run_id, names):
    """One bucket: compared when the source stood still since before the
    latest run's start; a difference counted when due since the judged
    moment. Returns whether it was compared and counted."""
    global compared
    if change > latest_start - SETTLE:
        return False
    since_writer, writer_start = written_since(run_id) if run_id else (False, None)
    if not (since_writer or due_since(change)):
        return False
    compared += 1
    if figures_t != figures_s:
        run = writer_start if since_writer and writer_start - SETTLE >= change \
            else responsible(change)
        shown = lambda f: ", ".join(f"{n} {v}" for n, v in zip(names, f)) if f else "no row"
        violations.append(f"the {JOB} run of {iso(run)} left {what} at {shown(figures_t)} where "
                          f"the source holds {shown(figures_s)}")
    return True


for key in sorted(set(hours_t) | set(hours_s)):
    hour, category = key
    start = datetime.strptime(hour, "%Y-%m-%d %H:%M")
    if start.date() < first:
        continue
    t, run_id = hours_t.get(key, (None, None))
    s, change = hours_s.get(key, (None, utc(start + timedelta(hours=1))))
    if judge(f"hour {hour} {category}", t, s, change, run_id, ("orders", "units", "revenue")) \
            and s is not None and s[0] > 0:
        witness_hour = True

for day in sorted(set(days_t) | set(days_s)):
    if date.fromisoformat(day) < first:
        continue
    end = utc(datetime.combine(date.fromisoformat(day) + timedelta(days=1), datetime.min.time()))
    closed, t, run_id = days_t.get(day, (False, None, None))
    s, placed, invoiced = days_s.get(day, (None, end, None))
    if closed:                       # its orders and revenue are the close's (R3)
        names, t, s = ("invoiced revenue",), t[2:], s[2:] if s else None
        change = invoiced if invoiced is not None else end
    else:
        names = ("orders", "revenue", "invoiced revenue")
        change = max(placed, invoiced or 0)
    what = f"{'closed ' if closed else ''}day {day}"
    if judge(what, t, s, change, run_id, names) and invoiced is not None and invoiced > end:
        witness_day = True

window = f"since {iso(judged)}"
if violations:
    more = f" ({len(violations)} buckets differ)" if len(violations) > 1 else ""
    print(f"R1 present: {violations[0]}{more}")
    sys.exit(1)
if not (witness_hour and witness_day):
    missing = " and ".join(w for w, ok in (("an hour of orders", witness_hour),
                                           ("a past day invoiced after it ended", witness_day))
                           if not ok)
    too_soon(f"{len(after)} {JOB} runs {window} reconcile with the source ({compared} buckets "
             f"compared), but none yet published {missing} to compare")
print(f"R1 fixed: {len(after)} {JOB} runs {window} reconcile with the source ({compared} "
      "buckets compared, a re-invoiced past day among them)")
sys.exit(0)
PY
