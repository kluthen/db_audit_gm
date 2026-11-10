# from scenario: compose/backoffice/scripts/head_office_figures.py
"""The head office's figures (purpose 9, vet-head-office-figures;
clinic-purposes.md 13; one-centre 1; master spec 11.3, 12.2; capture W4 items
0 and 5): the back office's report runner's two jobs.

Called by the scheduler as <function>(conns, options, log): `conns["clinic"]`
the record on its standby as vet_reports, read only, `conns["lab"]` the
laboratory's database on its only node as lab_reports, read only,
`conns["office"]` the back office's database as office_jobs (psycopg 3,
autocommit off), for the send `conns["receiver"]` the head office (the
scheduler's HTTP client, the customer's key headoffice_customer).

- feed (feed-daily-figures, 00:30), the feeder: yesterday, the customer's
  local date (business_settings.timezone) before today's, its figures per
  section and measure read on the standby and on the lab by the SQL keys
  options["read"] and options["lab"] name; written into office once: a day
  office already holds is not written again. One transaction in office: the
  runs row (its counts final), then the day's rows.
- send (send-monthly-figures, 05:00): run daily, it acts on the 1st to the
  5th only (options["first_day"], options["last_day"]), in the customer's
  local time (spec D436); on any other date it writes neither output nor runs
  row. The past month's figures, computed in office from the feeder's rows
  (options["compute"]) on its first run and kept, posted to the head office's
  POST /figures, at most options["attempts"] times while it answers 5xx or
  not at all; acknowledged (2xx), its reference kept; still unacknowledged
  after the last day's attempts, escalated (escalated_at). A month
  acknowledged or escalated is not sent again. One transaction in office:
  the runs row, the month's rows or their send columns.

The SQL keys are read from the runner's queries.yaml at each run, so the
queries there are the jobs' code. Logs counts, dates, keys and statuses only.
Returns the rows written (the runs row included). Imports the standard
library and PyYAML only.
"""

import datetime
import time
from decimal import Decimal
from pathlib import Path

import yaml

PURPOSE = "vet-head-office-figures"
QUERIES = Path(__file__).resolve().parent.parent / "queries.yaml"


def _sql(options, name):
    with open(QUERIES, encoding="utf-8") as fh:
        return yaml.safe_load(fh)["queries"][options[name]]["sql"]


def _today(clinic):
    """The customer's local date and zone, and the centre's site code, read on
    the record."""
    with clinic.cursor() as cur:
        cur.execute("SELECT (now() AT TIME ZONE b.timezone)::date, b.timezone, s.code"
                    " FROM business_settings b, sites s WHERE s.kind = 'own'")
        today, tz, site = cur.fetchone()
    clinic.commit()
    return today, tz, site


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def _read(conn, sql, params):
    with conn.cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    conn.commit()
    return rows


def feed(conns, options, log):
    clinic, lab, office = conns["clinic"], conns["lab"], conns["office"]
    started = _now()
    today, tz, _ = _today(clinic)
    day = today - datetime.timedelta(days=1)
    with clinic.cursor() as cur:
        cur.execute("SELECT %s::date::timestamp AT TIME ZONE %s, (%s::date + 1)::timestamp AT TIME ZONE %s",
                    (day, tz, day, tz))
        lo, hi = cur.fetchone()
    clinic.commit()
    rows = _read(clinic, _sql(options, "read"), {"lo": lo, "hi": hi})
    rows += _read(lab, _sql(options, "lab"), {"lo": lo, "hi": hi})
    with office.cursor() as cur:
        cur.execute("SELECT EXISTS (SELECT 1 FROM daily_figures WHERE day = %s)", (day,))
        held = cur.fetchone()[0]
        todo = [] if held else rows
        run_id = _run_row(cur, "feed-daily-figures", started, len(rows), len(todo))
        cur.executemany("INSERT INTO daily_figures (day, section, measure, value, run_id) VALUES (%s, %s, %s, %s, %s)",
                        [(day, *r, run_id) for r in todo])
    office.commit()
    log(f"day={day} rows={len(rows)} written={len(todo)}{' (the day already held)' if held else ''}")
    return 1 + len(todo)


def _value(v):
    return None if v is None else float(Decimal(v))


def _post(headoffice, payload, attempts, log):
    """(sent_at, reference): the first attempt's time, the reference when the
    head office acknowledged it."""
    sent_at = None
    for attempt in range(max(1, int(attempts))):
        if attempt:
            time.sleep(5)
        sent_at = sent_at or _now()
        try:
            answer = headoffice.post("/figures", payload)
        except headoffice.HttpError as exc:
            log(f"figures={payload['figures_key']} attempt={attempt + 1} status={exc.status}")
            continue
        log(f"figures={payload['figures_key']} attempt={attempt + 1} status={answer.status}")
        if answer.ok:
            return sent_at, (answer.json() or {}).get("reference")
        if answer.status < 500:
            break
    return sent_at, None


def send(conns, options, log):
    clinic, office, headoffice = conns["clinic"], conns["office"], conns["receiver"]
    started = _now()
    today, _, site = _today(clinic)
    first, last = int(options.get("first_day", 1)), int(options.get("last_day", 5))
    if not first <= today.day <= last:
        log(f"today={today}: not this job's date (the {first}st to the {last}th), nothing done")
        return 0
    month = (today.replace(day=1) - datetime.timedelta(days=1)).replace(day=1)
    with office.cursor() as cur:
        cur.execute("SELECT section, measure, value, sent_at, reference, escalated_at FROM monthly_figures"
                    " WHERE month = %s ORDER BY section, measure", (month,))
        kept = cur.fetchall()
        if kept and (kept[0][4] is not None or kept[0][5] is not None):
            office.commit()
            log(f"month={month}: already {'acknowledged' if kept[0][4] else 'escalated'}, nothing done")
            return 0
        rows = [r[:3] for r in kept]
        if not kept:
            cur.execute(_sql(options, "compute"), {"month": month})
            rows = cur.fetchall()
    office.commit()
    payload = {"figures_key": f"figures-{site}-{month:%Y-%m}", "month": f"{month:%Y-%m}", "centre": site,
               "figures": [{"section": s, "measure": m, "value": _value(v)} for s, m, v in rows]}
    sent_at, reference = _post(headoffice, payload, options.get("attempts", 3), log)
    sent_at = kept[0][3] if kept and kept[0][3] else sent_at
    stamp = _now()
    acknowledged = stamp if reference else None
    escalated = stamp if reference is None and today.day >= last else None
    with office.cursor() as cur:
        run_id = _run_row(cur, "send-monthly-figures", started, len(rows), len(rows))
        if kept:
            cur.execute("UPDATE monthly_figures SET sent_at = %s, reference = %s, acknowledged_at = %s,"
                        " escalated_at = %s WHERE month = %s", (sent_at, reference, acknowledged, escalated, month))
        else:
            cur.executemany("INSERT INTO monthly_figures (month, section, measure, value, sent_at, reference,"
                            " acknowledged_at, escalated_at, run_id) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                            [(month, s, m, v, sent_at, reference, acknowledged, escalated, run_id)
                             for s, m, v in rows])
    office.commit()
    log(f"month={month} figures={len(rows)} acknowledged={'yes' if reference else 'no'}"
        f"{' escalated' if escalated else ''}")
    return 1 + len(rows)
