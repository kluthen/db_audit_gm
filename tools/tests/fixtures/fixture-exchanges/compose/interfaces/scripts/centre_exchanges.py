"""The exchanges with the other centres (purpose 4, vet-centre-exchanges;
clinic-purposes.md 8; capture W4 items 0 and 4): sync-exchanges and
chase-exchanges, script jobs of the centre's integration engine.

Called by the scheduler as sync(conns, options, log) and chase(conns,
options, log): `conns["clinic"]` the record as vet_interfaces (psycopg 3,
autocommit off), `conns["partner_central"]`, `conns["partner_south"]` and
`conns["partner_abroad"]` the HTTP clients to the three centres' hostnames
(credential centres_customer). A centre is its site: 2 central, 3 south, 4
to 6 abroad (the centres abroad as one).

sync, every five minutes:
1. One read, its transaction ended before any call: the outbound requests
   still `requested` (oldest first, at most options["batch"]), each with what
   the franchise's agreement lets it carry (EX4): the animal's identity, its
   record's summary (its last three closed or signed consultations' dates and
   findings) and its current owner's name, e-mail and phone; the inbound
   exchanges answered (accepted or declined) since the `answers` watermark
   with no answer posted (a 2xx `answer` message out), and those reported
   since the `reports` watermark with no report posted.
2. The posts: POST /exchanges, /exchanges/{key}/answer, /exchanges/{key}/report
   to the centre's hostname. An answer that is not 2xx is recorded and left
   for the next run; no answer at all (HttpError) is recorded with no status.
3. One transaction: the run's ops.runs row (its counts known before it: the
   engine's role may insert a run, never update one), one ops.exchange_messages row a
   post, each request taken marked `sent` (sent_at the answer's time), each
   watermark moved to the oldest answer or report still unposted (or the
   read's time less ten minutes, the overlap a late commit needs). Commit.

chase, at 09:00 on working days: the outbound requests `sent` and still
unanswered. A working day after sending (the customer's local dates, Monday to
Friday) they are resent once with the same exchange_key and body (a `resend`
message); two working days after, one ops.incidents row (kind unanswered, ref
the key), once. One transaction after the calls, as sync.

Logs exchange ids, keys and statuses only, never a name or an identifier.
Returns the rows written. Imports nothing but the standard library.
"""

import datetime

PURPOSE = "vet-centre-exchanges"
CENTRES = {2: "partner_central", 3: "partner_south"}      # 4-6: partner_abroad
HOSTS = {"partner_central": "aldermoor-central", "partner_south": "aldermoor-south",
         "partner_abroad": "aldermoor-abroad"}
OVERLAP = datetime.timedelta(minutes=10)

OUTBOUND = (
    "SELECT e.id, e.exchange_key::text, e.kind, e.reason, e.requested_at, e.partner_site_id, e.animal_id"
    " FROM exchanges e WHERE e.direction = 'out' AND e.state = 'requested'"
    " ORDER BY e.requested_at, e.id LIMIT %s")
SENT_UNANSWERED = (
    "SELECT e.id, e.exchange_key::text, e.kind, e.reason, e.requested_at, e.partner_site_id, e.animal_id,"
    " (SELECT count(*) FROM generate_series((e.sent_at AT TIME ZONE b.timezone)::date + 1,"
    "                                       (now() AT TIME ZONE b.timezone)::date, interval '1 day') AS d"
    "   WHERE extract(isodow FROM d) < 6) AS working_days,"
    " EXISTS (SELECT 1 FROM ops.exchange_messages m WHERE m.exchange_key = e.exchange_key"
    "           AND m.kind = 'resend' AND m.direction = 'out' AND m.http_status BETWEEN 200 AND 299),"
    " EXISTS (SELECT 1 FROM ops.incidents i WHERE i.purpose = %s AND i.kind = 'unanswered'"
    "           AND i.ref = e.exchange_key::text)"
    " FROM exchanges e CROSS JOIN business_settings b"
    " WHERE e.direction = 'out' AND e.state = 'sent' AND e.answered_at IS NULL"
    " ORDER BY e.sent_at, e.id LIMIT %s")
ANIMAL = ("SELECT id, species, breed, sex, born_on::text, name, microchip, ueln, passport_number, ear_tag"
          " FROM animals WHERE id = %s")
RECORD = ("SELECT to_char(started_at, 'YYYY-MM-DD'), coalesce(findings, '') FROM consultations"
          " WHERE animal_id = %s AND state <> 'open' ORDER BY started_at DESC, id DESC LIMIT 3")
OWNER = ("SELECT o.id, o.name, o.email, o.phone FROM ownerships w JOIN owners o ON o.id = w.owner_id"
         " WHERE w.animal_id = %s AND w.role = 'owner' AND w.until_at IS NULL"
         " ORDER BY w.from_at DESC LIMIT 1")
TO_POST = (
    "SELECT e.id, e.exchange_key::text, e.partner_site_id, e.state, e.accepted_for::text, e.{at}, e.report"
    " FROM exchanges e WHERE e.direction = 'in' AND e.{at} >= %s AND e.state IN ({states})"
    " AND NOT EXISTS (SELECT 1 FROM ops.exchange_messages m WHERE m.exchange_key = e.exchange_key"
    "                   AND m.kind = %s AND m.direction = 'out' AND m.http_status BETWEEN 200 AND 299)"
    " ORDER BY e.{at}, e.id LIMIT %s")


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _iso(value):
    return value.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _centre(site_id):
    return CENTRES.get(site_id, "partner_abroad")


def _request_body(cur, row):
    """What a request may carry (EX4): this animal's record and its current
    owner's contact, nothing else."""
    xid, key, kind, reason, requested_at, _site, animal_id = row[:7]
    cur.execute(ANIMAL, (animal_id,))
    a = cur.fetchone()
    animal = dict(zip(("id", "species", "breed", "sex", "born_on", "name", "microchip", "ueln",
                       "passport_number", "ear_tag"), a)) if a else {"id": animal_id}
    cur.execute(RECORD, (animal_id,))
    record = [{"date": d, "findings": f} for d, f in cur.fetchall()]
    cur.execute(OWNER, (animal_id,))
    o = cur.fetchone()
    owner = dict(zip(("id", "name", "email", "phone"), o)) if o else None
    return {"exchange_key": key, "ref": xid, "kind": kind, "reason": reason,
            "requested_at": _iso(requested_at), "animal": animal, "record": record, "owner": owner}


def _post(conns, name, path, body):
    """-> (status or None, the answer's time)."""
    try:
        status = conns[name].post(path, body).status
    except conns[name].HttpError:
        status = None
    return status, _now()


def _ok(status):
    return status is not None and 200 <= status < 300


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def _messages(cur, run_id, posts):
    for xid, key, kind, centre, status, at in posts:
        cur.execute("INSERT INTO ops.exchange_messages (run_id, exchange_id, exchange_key, kind, direction, centre,"
                    " http_status, at) VALUES (%s, %s, %s, %s, 'out', %s, %s, %s)",
                    (run_id, xid, key, kind, centre, status, at))


def sync(conns, options, log):
    db = conns["clinic"]
    batch = int(options.get("batch", 20))
    started = _now()
    with db.cursor() as cur:
        cur.execute("SELECT now()")
        (read_at,) = cur.fetchone()
        cur.execute(OUTBOUND, (batch,))
        requests = [(row, _request_body(cur, row)) for row in cur.fetchall()]
        marks = {}
        for name in ("answers", "reports"):
            cur.execute("SELECT at FROM ops.watermarks WHERE purpose = %s AND name = %s", (PURPOSE, name))
            got = cur.fetchone()
            marks[name] = got[0] if got and got[0] is not None else read_at - OVERLAP
        cur.execute(TO_POST.format(at="answered_at", states="'accepted', 'declined', 'reported'"),
                    (marks["answers"], "answer", batch))
        answers = cur.fetchall()
        cur.execute(TO_POST.format(at="reported_at", states="'reported'"), (marks["reports"], "report", batch))
        reports = cur.fetchall()
    db.commit()

    posts, sent = [], []
    for row, body in requests:
        xid, key = row[0], row[1]
        name = _centre(row[5])
        status, at = _post(conns, name, "/exchanges", body)
        log(f"exchange={xid} key={key} request {HOSTS[name]} status={status}")
        posts.append((xid, key, "request", HOSTS[name], status, at))
        if _ok(status):
            sent.append((at, xid))
    left = {"answers": [], "reports": []}
    for xid, key, site, state, accepted_for, answered_at, _report in answers:
        name = _centre(site)
        body = {"answer": "declined" if state == "declined" else "accepted",
                "accepted_for": None if state == "declined" else accepted_for, "answered_at": _iso(answered_at)}
        status, at = _post(conns, name, f"/exchanges/{key}/answer", body)
        log(f"exchange={xid} key={key} answer {HOSTS[name]} status={status}")
        posts.append((xid, key, "answer", HOSTS[name], status, at))
        if not _ok(status):
            left["answers"].append(answered_at)
    for xid, key, site, _state, _for, reported_at, report in reports:
        name = _centre(site)
        status, at = _post(conns, name, f"/exchanges/{key}/report",
                           {"report": report or "", "reported_at": _iso(reported_at)})
        log(f"exchange={xid} key={key} report {HOSTS[name]} status={status}")
        posts.append((xid, key, "report", HOSTS[name], status, at))
        if not _ok(status):
            left["reports"].append(reported_at)

    written = 1 + len(posts) + len(sent) + 2          # the run, its messages, the requests sent, two marks
    with db.cursor() as cur:
        run_id = _run_row(cur, "sync-exchanges", started, len(requests) + len(answers) + len(reports), written)
        _messages(cur, run_id, posts)
        for at, xid in sent:
            cur.execute("UPDATE exchanges SET state = 'sent', sent_at = %s WHERE id = %s AND state = 'requested'",
                        (at, xid))
        for name, rows in (("answers", answers), ("reports", reports)):
            if left[name]:
                mark = min(left[name])
            elif len(rows) >= batch:
                mark = rows[-1][5]
            else:
                mark = read_at - OVERLAP
            mark = max(mark, marks[name])
            cur.execute("UPDATE ops.watermarks SET at = %s, run_id = %s WHERE purpose = %s AND name = %s",
                        (mark, run_id, PURPOSE, name))
    db.commit()
    return written


def chase(conns, options, log):
    db = conns["clinic"]
    batch = int(options.get("batch", 50))
    started = _now()
    resend, escalate = [], []
    with db.cursor() as cur:
        cur.execute(SENT_UNANSWERED, (PURPOSE, batch))
        rows = cur.fetchall()
        for row in rows:
            working_days, resent, escalated = row[7], row[8], row[9]
            if working_days >= 1 and not resent:
                resend.append((row, _request_body(cur, row)))
            if working_days >= 2 and not escalated:
                escalate.append(row)
    db.commit()

    posts = []
    for row, body in resend:
        xid, key = row[0], row[1]
        name = _centre(row[5])
        status, at = _post(conns, name, "/exchanges", body)
        log(f"exchange={xid} key={key} resend {HOSTS[name]} status={status}")
        posts.append((xid, key, "resend", HOSTS[name], status, at))

    written = 1 + len(posts) + len(escalate)
    with db.cursor() as cur:
        run_id = _run_row(cur, "chase-exchanges", started, len(rows), written)
        _messages(cur, run_id, posts)
        for row in escalate:
            cur.execute("INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
                        " VALUES (%s, 'chase-exchanges', 'unanswered', %s, %s, %s)",
                        (PURPOSE, row[1], f"exchange {row[0]} unanswered {row[7]} working days after sending",
                         run_id))
            log(f"exchange={row[0]} key={row[1]} escalated")
    db.commit()
    return written
