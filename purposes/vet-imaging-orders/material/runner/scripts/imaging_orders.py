"""The imaging round trip inside the centre (purpose 13, vet-imaging-orders;
vet-machinery-domain.md, "vet-imaging-orders"; capture W4 items 0 and 6;
spec D315, D324, D376, D416): post-imaging-orders and fetch-imaging-reports,
script jobs of the centre's integration engine.

Called by the scheduler as post(conns, options, log) and fetch(conns,
options, log): `conns["clinic"]` the record as vet_interfaces, `conns["pacs"]`
the PACS's database as mach_orders (psycopg 3, autocommit off).

post, every minute: the imaging requests still `requested` whose
consultation has closed (oldest first, at most options["batch"]): one
worklist entry each in pacs (accession I-<request id>, the request,
consultation, animal, requesting vet, the procedure of its code, priority;
ids only, no identity: the PACS reads it from the lookup API), `ON CONFLICT
(accession) DO NOTHING` so a retry writes no second, with the run's
ops.runs row there; the pacs commit first, then the requests `sent` in
clinic with the run's row there (the same job and started_at tie the two).
A request whose pacs commit failed stays `requested` for the next run.

fetch, every five minutes: from pacs, the final reports signed since the
`finals` watermark (less ten minutes, the duplicates found by
ops.imaging_results' report_id) and the entries cancelled since the
`cancellations` watermark; in one clinic transaction: each final's copy in
ops.imaging_results and its request `resulted` (once: an addendum is copied,
the request already resulted), never on a preliminary; each cancelled
entry's request `cancelled` when still `sent` (a sent request is cancelled
by the imaging team only, D315); each request `sent` past its turnaround
(urgent: options["urgent_hours"] after it was sent; routine:
options["routine_working_days"] working days after its local date) with no
final, one ops.incidents row (kind overdue, ref the request's id), once;
the watermarks and the run's row.

Logs request ids, accessions and counts only. Returns the rows written.
Imports nothing but the standard library.
"""

import datetime

PURPOSE = "vet-imaging-orders"
OVERLAP = datetime.timedelta(minutes=10)

TO_POST = (
    "SELECT r.id, r.consultation_id, r.animal_id, r.requested_by, r.code, r.priority"
    " FROM requests r JOIN consultations c ON c.id = r.consultation_id"
    " WHERE r.kind = 'imaging' AND r.state = 'requested' AND c.state <> 'open'"
    " ORDER BY r.requested_at, r.id LIMIT %s")
FINALS = (
    "SELECT p.id, p.signed_at, w.request_id, w.accession"
    " FROM mach_reports p JOIN mach_studies s ON s.id = p.study_id JOIN mach_worklist w ON w.id = s.worklist_id"
    " WHERE p.kind = 'final' AND p.status = 'signed' AND p.signed_at > %s ORDER BY p.signed_at, p.id LIMIT %s")
CANCELLED = (
    "SELECT w.request_id, w.accession, w.cancelled_at FROM mach_worklist w"
    " WHERE w.state = 'cancelled' AND w.cancelled_at > %s ORDER BY w.cancelled_at, w.id LIMIT %s")
OVERDUE = (
    "SELECT r.id, r.priority FROM requests r CROSS JOIN business_settings b"
    " WHERE r.kind = 'imaging' AND r.state = 'sent'"
    " AND CASE r.priority WHEN 'urgent' THEN r.sent_at + make_interval(hours => %(hours)s) < now()"
    "     ELSE (SELECT count(*) FROM generate_series((r.sent_at AT TIME ZONE b.timezone)::date + 1,"
    "                                              (now() AT TIME ZONE b.timezone)::date, interval '1 day') AS d"
    "            WHERE extract(isodow FROM d) < 6) > %(days)s END"
    " AND NOT EXISTS (SELECT 1 FROM ops.incidents i WHERE i.purpose = %(purpose)s AND i.kind = 'overdue'"
    "                   AND i.ref = r.id::text)"
    " ORDER BY r.sent_at, r.id LIMIT %(batch)s")


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def _mark(cur, name):
    cur.execute("SELECT at FROM ops.watermarks WHERE purpose = %s AND name = %s", (PURPOSE, name))
    got = cur.fetchone()
    return got[0] if got and got[0] is not None else None


def _set_mark(cur, name, at, run_id):
    cur.execute("INSERT INTO ops.watermarks (purpose, name, at, run_id) VALUES (%s, %s, %s, %s)"
                " ON CONFLICT (purpose, name) DO UPDATE SET at = EXCLUDED.at, run_id = EXCLUDED.run_id",
                (PURPOSE, name, at, run_id))


def post(conns, options, log):
    clinic, pacs = conns["clinic"], conns["pacs"]
    batch = int(options.get("batch", 50))
    started = _now()
    with clinic.cursor() as cur:
        cur.execute(TO_POST, (batch,))
        todo = cur.fetchall()
    clinic.rollback()
    if not todo:
        return 0
    with pacs.cursor() as cur:
        cur.execute("SELECT code, id FROM mach_procedures")
        procedures = dict(cur.fetchall())
        posted, inserted = [], 0
        for rid, consultation, animal, vet, code, priority in todo:
            procedure = procedures.get(code)
            if procedure is None:
                log(f"request={rid} code={code}: not in the PACS's catalogue, not posted")
                continue
            cur.execute("INSERT INTO mach_worklist (accession, request_id, consultation_id, animal_id, requested_by,"
                        " procedure_id, priority, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s, now())"
                        " ON CONFLICT (accession) DO NOTHING",
                        (f"I-{rid}", rid, consultation, animal, vet, procedure, priority))
            inserted += cur.rowcount
            posted.append(rid)
        _run_row(cur, "post-imaging-orders", started, len(todo), inserted)
    pacs.commit()
    with clinic.cursor() as cur:
        cur.execute("UPDATE requests SET state = 'sent', sent_at = now() WHERE id = ANY(%s) AND state = 'requested'",
                    (posted,))
        sent = cur.rowcount
        _run_row(cur, "post-imaging-orders", started, len(todo), sent)
    clinic.commit()
    for rid in posted:
        log(f"request={rid} accession=I-{rid} sent")
    return inserted + sent + 2


def fetch(conns, options, log):
    clinic, pacs = conns["clinic"], conns["pacs"]
    batch = int(options.get("batch", 100))
    started = _now()
    with clinic.cursor() as cur:
        cur.execute("SELECT now()")
        (read_at,) = cur.fetchone()
        fmark, cmark = _mark(cur, "finals"), _mark(cur, "cancellations")
    with pacs.cursor() as cur:
        cur.execute(FINALS, ((fmark or read_at) - OVERLAP, batch))
        finals = cur.fetchall()
        cur.execute(CANCELLED, ((cmark or read_at) - OVERLAP, batch))
        cancelled = cur.fetchall()
    pacs.rollback()
    written = 0
    with clinic.cursor() as cur:
        new = []
        for report, signed_at, rid, accession in finals:
            cur.execute("SELECT EXISTS (SELECT 1 FROM ops.imaging_results WHERE report_id = %s)", (report,))
            if not cur.fetchone()[0]:
                new.append((report, signed_at, rid, accession))
        cur.execute(OVERDUE, {"hours": int(options.get("urgent_hours", 18)),
                              "days": int(options.get("routine_working_days", 3)),
                              "purpose": PURPOSE, "batch": batch})
        overdue = [(rid, prio) for rid, prio in cur.fetchall() if rid not in {f[2] for f in new}]
        resulted, cancels = [], []
        if new:
            cur.execute("UPDATE requests SET state = 'resulted', resulted_at = now()"
                        " WHERE id = ANY(%s) AND state = 'sent' RETURNING id", ([f[2] for f in new],))
            resulted = [r[0] for r in cur.fetchall()]
        if cancelled:
            cur.execute("UPDATE requests SET state = 'cancelled', cancelled_at = now()"
                        " WHERE id = ANY(%s) AND state = 'sent' RETURNING id", ([c[0] for c in cancelled],))
            cancels = [r[0] for r in cur.fetchall()]
        written = len(new) + len(resulted) + len(cancels) + len(overdue)
        run_id = _run_row(cur, "fetch-imaging-reports", started, len(finals) + len(cancelled), written)
        for report, signed_at, rid, accession in new:
            cur.execute("INSERT INTO ops.imaging_results (run_id, request_id, accession, report_id, signed_at)"
                        " VALUES (%s, %s, %s, %s, %s)", (run_id, rid, accession, report, signed_at))
            log(f"request={rid} accession={accession} report={report} copied")
        for rid, prio in overdue:
            cur.execute("INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
                        " VALUES (%s, 'fetch-imaging-reports', 'overdue', %s, %s, %s)",
                        (PURPOSE, str(rid), f"{prio} imaging request {rid}: no final within its turnaround", run_id))
            log(f"request={rid} overdue ({prio})")
        for rid in cancels:
            log(f"request={rid} cancelled by the imaging team")
        _set_mark(cur, "finals", finals[-1][1] if len(finals) >= batch else read_at, run_id)
        _set_mark(cur, "cancellations", cancelled[-1][2] if len(cancelled) >= batch else read_at, run_id)
    clinic.commit()
    return written + 3
