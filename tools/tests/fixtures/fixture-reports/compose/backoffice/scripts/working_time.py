"""The working-time record (purpose 12, vet-working-time;
vet-scheduling-domain.md, purpose 12; master spec 11.3, 12.2; capture W4 items
0 and 5): the back office's report runner's two jobs.

Called by the scheduler as <function>(conns, options, log): `conns["sched"]`
the record on its standby as vet-scheduling's sched_reports and
`conns["clinic"]` as the core's vet_reports, read only, `conns["office"]` the
back office's database as office_jobs (psycopg 3, autocommit off).

- feed (feed-working-time, 09:30), the feeder: yesterday, the customer's
  local date (business_settings.timezone) before today's; the shifts that
  started that day per staff member (options["read"]) and its short rests
  (options["rests"]) read as sched_reports, the staff's names
  (options["staff"]) as vet_reports; written into office once: a day office
  already holds is not written again. One transaction in office: the runs
  row (its counts final), then the day's rows and breaches.
- close (close-working-time, 05:00): run daily, it acts on the 1st only, in
  the customer's local time (spec D436); on any other date it writes neither
  output nor runs row. The past month per staff member computed in office
  from the feeder's rows (options["compute"]), written once.

The SQL keys are read from the runner's queries.yaml at each run, so the
queries there are the jobs' code. Logs counts and dates only, never a name.
Returns the rows written (the runs row included). Imports the standard
library and PyYAML only.
"""

import datetime
from pathlib import Path

import yaml

PURPOSE = "vet-working-time"
QUERIES = Path(__file__).resolve().parent.parent / "queries.yaml"


def _sql(options, name):
    with open(QUERIES, encoding="utf-8") as fh:
        return yaml.safe_load(fh)["queries"][options[name]]["sql"]


def _today(clinic):
    """The customer's local date and zone, read on the record."""
    with clinic.cursor() as cur:
        cur.execute("SELECT (now() AT TIME ZONE timezone)::date, timezone FROM business_settings")
        today, tz = cur.fetchone()
    clinic.commit()
    return today, tz


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def feed(conns, options, log):
    sched, clinic, office = conns["sched"], conns["clinic"], conns["office"]
    started = _now()
    today, tz = _today(clinic)
    day = today - datetime.timedelta(days=1)
    with clinic.cursor() as cur:
        cur.execute("SELECT %s::date::timestamp AT TIME ZONE %s, (%s::date + 1)::timestamp AT TIME ZONE %s",
                    (day, tz, day, tz))
        lo, hi = cur.fetchone()
        cur.execute(_sql(options, "staff"))
        names = dict(cur.fetchall())
    clinic.commit()
    with sched.cursor() as cur:
        cur.execute(_sql(options, "read"), {"lo": lo, "hi": hi})
        days = cur.fetchall()
        cur.execute(_sql(options, "rests"), {"lo": lo, "hi": hi})
        rests = cur.fetchall()
    sched.commit()
    with office.cursor() as cur:
        cur.execute("SELECT EXISTS (SELECT 1 FROM working_time_days WHERE day = %s)", (day,))
        held = cur.fetchone()[0]
        todo_days, todo_rests = ([], []) if held else (days, rests)
        run_id = _run_row(cur, "feed-working-time", started, len(days) + len(rests),
                          len(todo_days) + len(todo_rests))
        cur.executemany("INSERT INTO working_time_days (day, staff_id, staff_name, shifts, planned_hours,"
                        " worked_hours, night_hours, call_outs, run_id) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                        [(day, r[0], names.get(r[0], f"staff {r[0]}"), *r[1:], run_id) for r in todo_days])
        cur.executemany("INSERT INTO rest_breaches (day, staff_id, shift_id, previous_shift_id, rest_hours, run_id)"
                        " VALUES (%s, %s, %s, %s, %s, %s)", [(day, *r, run_id) for r in todo_rests])
    office.commit()
    log(f"day={day} staff={len(days)} breaches={len(rests)} written={len(todo_days) + len(todo_rests)}"
        f"{' (the day already held)' if held else ''}")
    return 1 + len(todo_days) + len(todo_rests)


def close(conns, options, log):
    clinic, office = conns["clinic"], conns["office"]
    started = _now()
    today, _ = _today(clinic)
    if today.day != 1:
        log(f"today={today}: not the 1st, nothing done")
        return 0
    month = (today - datetime.timedelta(days=1)).replace(day=1)
    with office.cursor() as cur:
        cur.execute(_sql(options, "compute"), {"month": month})
        rows = cur.fetchall()
        cur.execute("SELECT EXISTS (SELECT 1 FROM working_time_months WHERE month = %s)", (month,))
        held = cur.fetchone()[0]
        todo = [] if held else rows
        run_id = _run_row(cur, "close-working-time", started, len(rows), len(todo))
        cur.executemany("INSERT INTO working_time_months (month, staff_id, staff_name, worked_hours, night_hours,"
                        " call_outs, breaches, average_weekly_hours, run_id)"
                        " VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)", [(month, *r, run_id) for r in todo])
    office.commit()
    log(f"month={month} staff={len(rows)} written={len(todo)}{' (already held)' if held else ''}")
    return 1 + len(todo)
