# from scenario: compose/backoffice/scripts/medicines_registers.py
"""The medicines registers (purpose 7, vet-medicines-registers; clinic-purposes.md
11; master spec 11.3, 12.2; capture W4 items 0 and 5): the back office's
report runner's jobs, one function each.

Called by the scheduler as <function>(conns, options, log): `conns["clinic"]`
the record on its standby as vet_reports, read only, `conns["office"]` the back
office's database as office_jobs (psycopg 3, autocommit off).

- feed_register (feed-medicines-register, 01:30) and feed_controlled
  (feed-controlled-drugs, 01:45), the feeders: yesterday, the customer's local
  date (business_settings.timezone) before today's, read on the standby by
  the SQL key options["read"] names; written into office once: a day office
  already holds is not written again. One transaction in office: the runs row
  (its counts final), then the day's lines.
- close_register (close-medicines-register, 03:00), balance_controlled
  (balance-controlled-drugs, 03:15) and inventory_controlled
  (inventory-controlled-drugs, 03:30): run daily, they act on their own date
  only, the 1st (1 January for the inventory), in the customer's local time
  (spec D436); on any other date they write neither output nor runs row.
  Their period, the past month (the year's start for the inventory), is
  computed in office from the feeders' rows by the SQL key options["compute"]
  names; a period office already holds is not written again.

The SQL keys are read from the runner's queries.yaml at each run, so the
queries there are the jobs' code. Logs counts and dates only. Returns the
rows written (the runs row included). Imports the standard library and
PyYAML only.
"""

import datetime
import json
from pathlib import Path

import yaml

PURPOSE = "vet-medicines-registers"
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


def _feed(conns, options, log, job, table, columns):
    clinic, office = conns["clinic"], conns["office"]
    started = _now()
    today, tz = _today(clinic)
    day = today - datetime.timedelta(days=1)
    with clinic.cursor() as cur:
        cur.execute("SELECT %s::date::timestamp AT TIME ZONE %s, (%s::date + 1)::timestamp AT TIME ZONE %s",
                    (day, tz, day, tz))
        lo, hi = cur.fetchone()
        cur.execute(_sql(options, "read"), {"lo": lo, "hi": hi})
        rows = cur.fetchall()
    clinic.commit()
    with office.cursor() as cur:
        cur.execute(f"SELECT EXISTS (SELECT 1 FROM {table} WHERE day = %s)", (day,))
        held = cur.fetchone()[0]
        todo = [] if held else rows
        run_id = _run_row(cur, job, started, len(rows), len(todo))
        marks = ", ".join(["%s"] * (len(columns) + 2))
        cur.executemany(f"INSERT INTO {table} (day, {', '.join(columns)}, run_id) VALUES ({marks})",
                        [(day, *r, run_id) for r in todo])
    office.commit()
    log(f"day={day} read={len(rows)} written={len(todo)}{' (the day already held)' if held else ''}")
    return 1 + len(todo)


def feed_register(conns, options, log):
    return _feed(conns, options, log, "feed-medicines-register", "medicines_register",
                 ["supply", "supply_id", "supplied_at", "medicine_id", "product", "form",
                  "authorisation_number", "batch_number", "quantity", "recipient", "recipient_address",
                  "prescribing_vet"])


def feed_controlled(conns, options, log):
    return _feed(conns, options, log, "feed-controlled-drugs", "controlled_movements",
                 ["movement", "movement_id", "moved_at", "medicine_id", "batch_id", "batch_number", "quantity"])


def _periodic(conns, options, log, job, table, key, own, period, columns, params=None):
    """A periodic job: on its own date (own(today)), its period's rows
    computed in office and written once. params(clinic), when given, returns
    the computation's further values and the constant columns every row
    carries ([(column, value)])."""
    clinic, office = conns["clinic"], conns["office"]
    started = _now()
    today, _ = _today(clinic)
    if not own(today):
        log(f"today={today}: not this job's date, nothing done")
        return 0
    first = period(today)
    more, extra = params(clinic) if params else ({}, [])
    values = {key: first, **more}
    with office.cursor() as cur:
        cur.execute(_sql(options, "compute"), values)
        rows = cur.fetchall()
        cur.execute(f"SELECT EXISTS (SELECT 1 FROM {table} WHERE {key} = %s)", (first,))
        held = cur.fetchone()[0]
        todo = [] if held else rows
        run_id = _run_row(cur, job, started, len(rows), len(todo))
        marks = ", ".join(["%s"] * (len(columns) + 2 + len(extra)))
        cur.executemany(f"INSERT INTO {table} ({key}, {', '.join(columns)}"
                        f"{''.join(', ' + e[0] for e in extra)}, run_id) VALUES ({marks})",
                        [(first, *r, *(e[1] for e in extra), run_id) for r in todo])
    office.commit()
    log(f"{key}={first} computed={len(rows)} written={len(todo)}{' (already held)' if held else ''}")
    return 1 + len(todo)


def _past_month(today):
    return (today.replace(day=1) - datetime.timedelta(days=1)).replace(day=1)


def close_register(conns, options, log):
    return _periodic(conns, options, log, "close-medicines-register", "register_extracts", "month",
                     lambda d: d.day == 1, _past_month,
                     ["medicine_id", "product", "lines", "quantity", "checksum"])


def _batches(clinic):
    """The controlled batches as received, and the senior vet who signs."""
    with clinic.cursor() as cur:
        cur.execute("SELECT b.id, m.id, b.batch_number, b.quantity_received FROM medicine_batches b"
                    " JOIN medicines m ON m.id = b.medicine_id WHERE m.controlled ORDER BY b.id")
        received = {str(i): [m, n, str(q)] for i, m, n, q in cur.fetchall()}
        cur.execute("SELECT name FROM staff WHERE kind = 'vet' AND left_on IS NULL ORDER BY id LIMIT 1")
        signer = cur.fetchone()
    clinic.commit()
    return {"received": json.dumps(received), "signed_by": signer[0] if signer else "the senior vet"}


def balance_controlled(conns, options, log):
    def params(clinic):
        found = _batches(clinic)
        return {"received": found["received"]}, [("signed_by", found["signed_by"])]

    return _periodic(conns, options, log, "balance-controlled-drugs", "controlled_balances", "month",
                     lambda d: d.day == 1, _past_month,
                     ["medicine_id", "batch_id", "batch_number", "opening", "movements", "closing"],
                     params=params)


def inventory_controlled(conns, options, log):
    return _periodic(conns, options, log, "inventory-controlled-drugs", "controlled_inventories", "year",
                     lambda d: d.month == 1 and d.day == 1, lambda d: d,
                     ["medicine_id", "batch_id", "batch_number", "counted"])
