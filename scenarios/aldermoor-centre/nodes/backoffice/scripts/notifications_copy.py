# from scenario: compose/backoffice/scripts/notifications_copy.py
"""The copy of the notifications into the back office (purpose 5,
vet-notifiable-diseases, copy-notifications; clinic-purposes.md 9; master
spec 11.3; capture W4 items 0, 4 and 5): a script job of the back office's
report runner, at 02:15.

Called by the scheduler as copy(conns, options, log): `conns["clinic"]` the
record as vet_reports and `conns["lab"]` the lab as lab_reports, read only,
`conns["office"]` office as office_jobs (psycopg 3, autocommit off).

1. Yesterday is the customer's local date before today's
   (business_settings.timezone); the notifications first sent on it, in both
   databases (ops.notifications): their key, payload, first post and
   reference.
2. office's copies of them already made (regulatory_submissions, kind
   notifiable-disease), so a second run that day copies nothing twice (ND5).
3. One transaction in office: its runs row, then one regulatory_submissions
   row a notification not yet copied (source clinic or lab, ref the key,
   payload as sent, sent_at its first post, reference the authority's).

Logs counts and keys only. Returns the rows written. Imports nothing but the
standard library.
"""

import datetime
import json

PURPOSE = "vet-notifiable-diseases"
KIND = "notifiable-disease"
NOTIFIED = ("SELECT notification_key, payload, first_sent_at, reference FROM ops.notifications"
            " WHERE first_sent_at >= %s AND first_sent_at < %s ORDER BY first_sent_at, id")


def copy(conns, options, log):
    clinic, lab, office = conns["clinic"], conns["lab"], conns["office"]
    started = datetime.datetime.now(datetime.timezone.utc)
    with clinic.cursor() as cur:
        cur.execute("SELECT (now() AT TIME ZONE timezone)::date - 1, timezone FROM business_settings")
        day, tz = cur.fetchone()
        cur.execute("SELECT %s::date::timestamp AT TIME ZONE %s, (%s::date + 1)::timestamp AT TIME ZONE %s",
                    (day, tz, day, tz))
        lo, hi = cur.fetchone()
        cur.execute(NOTIFIED, (lo, hi))
        rows = [("clinic", *r) for r in cur.fetchall()]
    clinic.commit()
    with lab.cursor() as cur:
        cur.execute(NOTIFIED, (lo, hi))
        rows += [("lab", *r) for r in cur.fetchall()]
    lab.commit()

    with office.cursor() as cur:
        cur.execute("SELECT ref FROM regulatory_submissions WHERE kind = %s AND ref = ANY(%s)",
                    (KIND, [r[1] for r in rows]))
        done = {r[0] for r in cur.fetchall()}
        todo = [r for r in rows if r[1] not in done]
        cur.execute("INSERT INTO runs (purpose, job, started_at, rows_read, rows_written)"
                    " VALUES (%s, 'copy-notifications', %s, %s, %s) RETURNING id",
                    (PURPOSE, started, len(rows), 1 + len(todo)))
        (run_id,) = cur.fetchone()
        for source, key, payload, sent_at, reference in todo:
            cur.execute("INSERT INTO regulatory_submissions (kind, source, ref, payload, sent_at, reference, run_id)"
                        " VALUES (%s, %s, %s, %s::jsonb, %s, %s, %s)",
                        (KIND, source, key, json.dumps(payload), sent_at, reference, run_id))
    office.commit()
    log(f"day={day} notifications={len(rows)} copied={len(todo)}")
    return 1 + len(todo)
