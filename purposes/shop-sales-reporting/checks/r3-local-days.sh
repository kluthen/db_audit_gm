#!/bin/sh
# R3 local days (shop-sales-reporting, v0.4 master spec 10.1, 12.1 to
# 12.3): the hours and days both jobs publish are the customer's local hours
# and days, business_settings.timezone on the source.
#
# Runs on the runner node (bi) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs of both jobs with
# check-runs and both databases as gm_check with check-sql; it never runs a
# job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - Judged: the rows a run since then wrote (their run_id's rpt.etl_runs row
#   finished after it): every hour row, and every day row of the nightly
#   close or, not yet closed, of the hourly roll-up. Each is compared, on
#   the figures an order's placing fixes (orders, units, revenue), with the
#   source's local hour or day, once the source's last order in it was
#   placed SETTLE seconds before the writing run started.
# Exit 1: a row differing from its local hour or day, naming the run and the
# row. Exit 0: none, and a compared day had orders in its first and in its
# last local hour (the witness: any other boundary moves them). Exit 3,
# with remaining= to the next run of either job: no run since the judged
# moment, or no witness yet. Exit 2: it cannot judge.
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
JOBS = ("rollup-hourly", "rollup-close")
SETTLE = 60                          # seconds, as R1's
CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"R3 cannot be judged: {text}")
    sys.exit(2)


def helper(argv, stdin=None):
    p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def sql(part, statement):
    return [line.split("|") for line in helper([CHECK_SQL, "-h", part[0], "-d", part[1]],
                                               statement).splitlines()]


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

after = f"e.finished_at > to_timestamp({judged})"
hours_t = sql(TARGET, "SELECT to_char(h.hour_local, 'YYYY-MM-DD HH24:MI'), h.category, h.orders, "
              "h.units, h.revenue, e.job, extract(epoch FROM e.started_at) FROM rpt.sales_hourly h "
              f"JOIN rpt.etl_runs e ON e.id = h.run_id WHERE {after}")
days_t = sql(TARGET, "SELECT to_char(d.day_local, 'YYYY-MM-DD'), d.orders, d.revenue, e.job, "
             "extract(epoch FROM e.started_at) FROM rpt.sales_daily d "
             f"JOIN rpt.etl_runs e ON e.id = d.run_id WHERE {after}")
if not hours_t and not days_t:
    too_soon(f"{ran} runs since {iso(judged)}, but no row they wrote is left to judge")

first = min([date.fromisoformat(r[0][:10]) for r in hours_t]
            + [date.fromisoformat(r[0]) for r in days_t])
lo = f"'{first.isoformat()}'::timestamp AT TIME ZONE s.timezone"
hours_s = {(r[0], r[1]): (tuple(Decimal(v) for v in r[2:5]), float(r[5])) for r in sql(SOURCE,
           "SELECT to_char(date_trunc('hour', o.placed_at AT TIME ZONE s.timezone), "
           "'YYYY-MM-DD HH24:MI'), p.category, count(DISTINCT o.id), sum(l.quantity), "
           "sum(l.line_total), extract(epoch FROM max(o.placed_at)) "
           "FROM orders o JOIN order_lines l ON l.order_id = o.id "
           "JOIN products p ON p.id = l.product_id, business_settings s "
           f"WHERE o.placed_at >= {lo} GROUP BY 1, 2")}
days_s = {r[0]: (tuple(Decimal(v) for v in r[1:3]), float(r[3]), int(r[4]), int(r[5]))
          for r in sql(SOURCE,
          "SELECT to_char(t.day, 'YYYY-MM-DD'), count(*), sum(t.total), "
          "extract(epoch FROM max(t.placed_at)), count(*) FILTER (WHERE t.hour = 0), "
          "count(*) FILTER (WHERE t.hour = 23) "
          "FROM (SELECT (o.placed_at AT TIME ZONE s.timezone)::date AS day, "
          "             extract(hour FROM o.placed_at AT TIME ZONE s.timezone) AS hour, "
          "             o.total, o.placed_at "
          f"        FROM orders o, business_settings s WHERE o.placed_at >= {lo}) t GROUP BY 1")}
(offset,), = sql(SOURCE, "SELECT utc_offset_hours FROM business_settings")
offset = timedelta(hours=int(offset))


def end_of(local):
    return (local - offset).replace(tzinfo=timezone.utc).timestamp()


violations, compared, witness = [], 0, False


def shown(names, figures):
    return ", ".join(f"{n} {v}" for n, v in zip(names, figures)) if figures else "nothing"


for hour, category, orders, units, revenue, job, started in hours_t:
    started = float(started)
    s, placed = hours_s.get((hour, category),
                            (None, end_of(datetime.strptime(hour, "%Y-%m-%d %H:%M")
                                          + timedelta(hours=1))))
    if placed > started - SETTLE:
        continue                     # still filling when the run read it
    compared += 1
    t = (Decimal(orders), Decimal(units), Decimal(revenue))
    if t != s:
        names = ("orders", "units", "revenue")
        violations.append(f"the {job} run of {iso(started)} left hour {hour} {category} at "
                          f"{shown(names, t)} where the source's local hour holds "
                          f"{shown(names, s)}")

for day, orders, revenue, job, started in days_t:
    started = float(started)
    end = end_of(datetime.combine(date.fromisoformat(day) + timedelta(days=1),
                                  datetime.min.time()))
    s, placed, first_hour, last_hour = days_s.get(day, (None, end, 0, 0))
    if placed > started - SETTLE:
        continue                     # the day was not over when the run read it
    compared += 1
    t = (Decimal(orders), Decimal(revenue))
    if t != s:
        names = ("orders", "revenue")
        violations.append(f"the {job} run of {iso(started)} left day {day} at {shown(names, t)} "
                          f"where the source's local day holds {shown(names, s)}")
    elif first_hour and last_hour:
        witness = True

window = f"since {iso(judged)}"
if violations:
    more = f" ({len(violations)} rows differ)" if len(violations) > 1 else ""
    print(f"R3 present: {violations[0]}{more}")
    sys.exit(1)
if not witness:
    too_soon(f"{ran} runs {window} published local hours and days ({compared} rows compared), "
             "but no whole day with orders at both its ends yet")
print(f"R3 fixed: {ran} runs {window} published the customer's local hours and days ({compared} "
      "rows compared, a whole day among them)")
sys.exit(0)
PY
