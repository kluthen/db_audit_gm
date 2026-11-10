"""The practices' monthly statements (purpose 10, vet-lab-statements;
clinic-purposes.md 14; vet-lab rule 13; master spec 11.3, 12.2; capture W4
items 0 and 5): the back office's report runner's two jobs.

Called by the scheduler as <function>(conns, options, log): `conns["lab"]`
the laboratory's database on its only node as lab_reports, read only (the lab
has no standby, D304), `conns["office"]` the back office's database as
office_jobs (psycopg 3, autocommit off).

- feed (feed-lab-charges, 02:30), the feeder: yesterday, the customer's local
  date (lab_settings.timezone) before today's, its practices' charge events
  read on the lab by the SQL key options["read"] names (each charge made
  billable that day, each voided that day); written into office once: a day
  office already holds is not written again. One transaction in office: the
  runs row (its counts final), then the day's lines.
- close (close-lab-statements, 04:00): run daily, it acts on the 1st only, in
  the customer's local time (spec D436); on any other date it writes neither
  output nor runs row. The past month's statement for each practice account
  with lines, computed in office from the feeder's lines (options["compute"]:
  billable less the voids of stated charges, the bracket's discount); a month
  office already holds statements for is not closed again. One transaction in
  office: the runs row, the statements.

The SQL keys are read from the runner's queries.yaml at each run, so the
queries there are the jobs' code. Logs counts, dates and keys only (never a
patient reference or a surname). Returns the rows written (the runs row
included). Imports the standard library and PyYAML only.
"""

import datetime
from pathlib import Path

import yaml

PURPOSE = "vet-lab-statements"
QUERIES = Path(__file__).resolve().parent.parent / "queries.yaml"
LINE_COLUMNS = ["charge_id", "event", "account_id", "order_id", "order_test_id", "test_code", "kind", "amount",
                "patient_ref", "client_surname"]
STATEMENT_COLUMNS = ["account_id", "lines", "billable", "voided", "total", "discount_pct", "discount", "due"]


def _sql(options, name):
    with open(QUERIES, encoding="utf-8") as fh:
        return yaml.safe_load(fh)["queries"][options[name]]["sql"]


def _today(lab):
    """The customer's local date and zone, read on the lab's settings."""
    with lab.cursor() as cur:
        cur.execute("SELECT (now() AT TIME ZONE timezone)::date, timezone FROM lab_settings")
        today, tz = cur.fetchone()
    lab.commit()
    return today, tz


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def _insert(cur, table, columns, rows, lead, run_id):
    cur.executemany(f"INSERT INTO {table} ({', '.join([lead[0]] + columns)}, run_id)"
                    f" VALUES ({', '.join(['%s'] * (len(columns) + 2))})",
                    [(lead[1], *r, run_id) for r in rows])


def feed(conns, options, log):
    lab, office = conns["lab"], conns["office"]
    started = _now()
    today, tz = _today(lab)
    day = today - datetime.timedelta(days=1)
    with lab.cursor() as cur:
        cur.execute("SELECT %s::date::timestamp AT TIME ZONE %s, (%s::date + 1)::timestamp AT TIME ZONE %s",
                    (day, tz, day, tz))
        lo, hi = cur.fetchone()
        cur.execute(_sql(options, "read"), {"day": day, "lo": lo, "hi": hi})
        rows = cur.fetchall()
    lab.commit()
    with office.cursor() as cur:
        cur.execute("SELECT EXISTS (SELECT 1 FROM lab_charge_lines WHERE day = %s)", (day,))
        held = cur.fetchone()[0]
        todo = [] if held else rows
        run_id = _run_row(cur, "feed-lab-charges", started, len(rows), len(todo))
        _insert(cur, "lab_charge_lines", LINE_COLUMNS, todo, ("day", day), run_id)
    office.commit()
    log(f"day={day} lines={len(rows)} written={len(todo)}{' (the day already held)' if held else ''}")
    return 1 + len(todo)


def close(conns, options, log):
    lab, office = conns["lab"], conns["office"]
    started = _now()
    today, _ = _today(lab)
    if today.day != 1:
        log(f"today={today}: not this job's date (the 1st), nothing done")
        return 0
    month = (today - datetime.timedelta(days=1)).replace(day=1)
    with office.cursor() as cur:
        cur.execute("SELECT EXISTS (SELECT 1 FROM lab_statements WHERE month = %s)", (month,))
        if cur.fetchone()[0]:
            office.commit()
            log(f"month={month}: already stated, nothing done")
            return 0
        cur.execute(_sql(options, "compute"), {"month": month})
        rows = cur.fetchall()
        cur.execute("SELECT count(*) FROM lab_charge_lines WHERE day >= %s AND day < %s",
                    (month, today))
        read = cur.fetchone()[0]
        run_id = _run_row(cur, "close-lab-statements", started, read, len(rows))
        _insert(cur, "lab_statements", STATEMENT_COLUMNS, rows, ("month", month), run_id)
    office.commit()
    log(f"month={month} lines={read} statements={len(rows)}")
    return 1 + len(rows)
