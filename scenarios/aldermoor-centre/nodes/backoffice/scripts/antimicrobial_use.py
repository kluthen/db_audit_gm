# from scenario: compose/backoffice/scripts/antimicrobial_use.py
"""The antimicrobial use (purpose 8, vet-antimicrobial-use; clinic-purposes.md
12; master spec 11.3, 12.2; capture W4 items 0 and 5): the back office's
report runner's two jobs.

Called by the scheduler as <function>(conns, options, log): `conns["clinic"]`
the record on its standby as vet_reports, read only, `conns["office"]` the back
office's database as office_jobs (psycopg 3, autocommit off), for the report
`conns["receiver"]` the authority (the scheduler's HTTP client, the
customer's key authority_customer).

- feed (feed-antimicrobial-use, 02:00), the feeder: yesterday, the
  customer's local date (business_settings.timezone) before today's, its use
  per species and ATCvet code read on the standby by the SQL key
  options["read"] names; written into office once: a day office already
  holds is not written again. One transaction in office: the runs row (its
  counts final), then the day's rows.
- report (report-antimicrobial-use, 04:00): run daily, it acts on 15 January
  only, in the customer's local time (spec D436); on any other date it writes
  neither output nor runs row. Last year's report for each species due on
  the day (options["due"]), not yet acknowledged nor escalated, summed in
  office from the feeder's rows (options["compute"]), posted to the
  authority's POST /amu-reports, at most options["attempts"] times while it
  answers 5xx or not at all; acknowledged (2xx), its reference kept and a
  copy in regulatory_submissions (kind amu-report); still unacknowledged
  after the attempts, escalated at once (escalated_at), the deadline
  (options["deadline"], 31 January) left to the back office. One
  transaction in office: the runs row, the reports, the copies.

The SQL keys are read from the runner's queries.yaml at each run, so the
queries there are the jobs' code. Logs counts, dates, keys and statuses only.
Returns the rows written (the runs row included). Imports the standard
library and PyYAML only.
"""

import datetime
import json
import time
from pathlib import Path

import yaml

PURPOSE = "vet-antimicrobial-use"
KIND = "amu-report"
QUERIES = Path(__file__).resolve().parent.parent / "queries.yaml"
FEED_COLUMNS = ["species", "atcvet_code", "administrations", "dispensings", "quantity", "animals_treated",
                "herds_treated"]


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


def feed(conns, options, log):
    clinic, office = conns["clinic"], conns["office"]
    started = _now()
    today, tz, _ = _today(clinic)
    day = today - datetime.timedelta(days=1)
    with clinic.cursor() as cur:
        cur.execute("SELECT %s::date::timestamp AT TIME ZONE %s, (%s::date + 1)::timestamp AT TIME ZONE %s",
                    (day, tz, day, tz))
        lo, hi = cur.fetchone()
        cur.execute(_sql(options, "read"), {"lo": lo, "hi": hi})
        rows = cur.fetchall()
    clinic.commit()
    with office.cursor() as cur:
        cur.execute("SELECT EXISTS (SELECT 1 FROM antimicrobial_use WHERE day = %s)", (day,))
        held = cur.fetchone()[0]
        todo = [] if held else rows
        run_id = _run_row(cur, "feed-antimicrobial-use", started, len(rows), len(todo))
        cur.executemany(f"INSERT INTO antimicrobial_use (day, {', '.join(FEED_COLUMNS)}, run_id)"
                        f" VALUES ({', '.join(['%s'] * (len(FEED_COLUMNS) + 2))})",
                        [(day, *r, run_id) for r in todo])
    office.commit()
    log(f"day={day} rows={len(rows)} written={len(todo)}{' (the day already held)' if held else ''}")
    return 1 + len(todo)


def _post(authority, payload, attempts, log):
    """(sent_at, reference): the first attempt's time, the reference when the
    authority acknowledged it."""
    sent_at = None
    for attempt in range(max(1, int(attempts))):
        if attempt:
            time.sleep(5)
        sent_at = sent_at or _now()
        try:
            answer = authority.post("/amu-reports", payload)
        except authority.HttpError as exc:
            log(f"report={payload['report_key']} attempt={attempt + 1} status={exc.status}")
            continue
        log(f"report={payload['report_key']} attempt={attempt + 1} status={answer.status}")
        if answer.ok:
            return sent_at, (answer.json() or {}).get("reference")
        if answer.status < 500:
            break
    return sent_at, None


def report(conns, options, log):
    clinic, office, authority = conns["clinic"], conns["office"], conns["receiver"]
    started = _now()
    today, _, site = _today(clinic)
    if not (today.month == 1 and today.day == 15):
        log(f"today={today}: not 15 January, nothing done")
        return 0
    year = datetime.date(today.year - 1, 1, 1)
    due = sorted(s for s, since in options["due"].items() if datetime.date.fromisoformat(str(since)) <= today)
    month, day = (int(x) for x in str(options["deadline"]).split("-"))
    deadline = datetime.date(today.year, month, day)
    with office.cursor() as cur:
        cur.execute(_sql(options, "compute"), {"year": year, "species": due})
        rows = cur.fetchall()
        cur.execute("SELECT species FROM amu_reports WHERE year = %s"
                    " AND (reference IS NOT NULL OR escalated_at IS NOT NULL)", (year,))
        done = {r[0] for r in cur.fetchall()}
    office.commit()
    reports = []
    for species in (s for s in due if s not in done):
        lines = [{"atcvet_code": r[1], "administrations": int(r[2]), "dispensings": int(r[3]),
                  "quantity": float(r[4]), "animals_treated": int(r[5]), "herds_treated": int(r[6])}
                 for r in rows if r[0] == species]
        payload = {"report_key": f"amu-{year.year}-{species}", "year": year.year, "species": species,
                   "centre": site, "lines": lines}
        sent_at, reference = _post(authority, payload, options.get("attempts", 3), log)
        reports.append((species, payload, sent_at, reference))
    with office.cursor() as cur:
        run_id = _run_row(cur, "report-antimicrobial-use", started, len(rows),
                          len(reports) + sum(1 for r in reports if r[3]))
        for species, payload, sent_at, reference in reports:
            stamp = _now()
            cur.execute("INSERT INTO amu_reports (year, species, deadline, payload, sent_at, reference,"
                        " acknowledged_at, escalated_at, run_id) VALUES (%s, %s, %s, %s::jsonb, %s, %s, %s, %s, %s)",
                        (year, species, deadline, json.dumps(payload), sent_at, reference,
                         stamp if reference else None, None if reference else stamp, run_id))
            if reference:
                cur.execute("INSERT INTO regulatory_submissions (kind, source, ref, payload, sent_at, reference,"
                            " run_id) VALUES (%s, 'clinic', %s, %s::jsonb, %s, %s, %s)",
                            (KIND, payload["report_key"], json.dumps(payload), sent_at, reference, run_id))
    office.commit()
    log(f"year={year.year} due={','.join(due)} reports={len(reports)}"
        f" acknowledged={sum(1 for r in reports if r[3])}")
    return 1 + len(reports) + sum(1 for r in reports if r[3])
