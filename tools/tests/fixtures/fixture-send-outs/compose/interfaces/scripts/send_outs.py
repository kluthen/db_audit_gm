"""The external reference lab (vet-lab-send-outs, v0.5 master spec 12.2
purpose 3; clinic-purposes.md section 7; capture W4 items 0 and 3; spec
D436): the integration engine's two script jobs between the lab's database,
lab, and the external lab's stub, Northfield Veterinary Laboratories
(hostname northfield-lab). The lab asks; the external lab accepts at once
and posts its result one to five days later to lab-api's
POST /send-outs/{send_key}/result (vet-lab's endpoint, not this purpose's).

Called by the scheduler as <function>(conns, options, log):
`conns["source"]` lab as vet-lab's lab_dispatch (psycopg 3, autocommit off),
`conns["partner"]` the HTTP client to the stub (credential xlab_customer).
Each run writes one ops.runs row in the transaction of its output, empty
runs included (master spec 12.1); the chase outside its hours writes nothing.
Logs ids, codes and statuses only, never a name.

A send-out carries what lab rule 11 lets it: its send_key, the lab's
accession (the order's id), the sample's label, the external code, the
animal's species, sex and age in whole years; never the owner, the client,
an identifier or a clinical note. Its send_key is one per test,
md5('vet-lab-send-out-test:<order test id>'), the same on every post of it:
a run stopped between its calls and its commit posts the same key again.

send: the tests routed sent-out, still sent-out, whose sample is received and
  which have no send-out yet, oldest receipt first, at most
  options["batch"]; the read's transaction ended before the calls. Each
  posted (POST /orders); the stub answers accepted with its accession and
  due time. No answer (a timeout, refused) ends the calls. After them one
  transaction: one lab_send_outs row per test read (packed; sent once
  posted; accepted with the external accession and due_by on acceptance), a
  sent-out sample event each, the run's row.

chase: every 15 minutes, acting only 08:00 to 19:59 Monday to Saturday in
  the lab's local time (lab_settings' UTC offset; options["window"]),
  otherwise returning at once, writing nothing. In its hours:
  - a send-out not accepted: posted again with its send_key; still not
    accepted from 19:45 local on its packing day on: one ops.incidents row
    (kind unaccepted, ref the send_key), once;
  - an accepted one unanswered a working day past its due_by (a working day:
    24 hours, Sunday not counted): POST /orders/{send_key}/resend, the stub
    posting its answer again; each chase an ops.incidents row (kind chased),
    the second a working day after the first; a working day after the
    second, still unanswered: one row of kind unanswered, the escalation,
    once.
  One transaction after the calls: the send-outs accepted, the run's row,
  the incidents.
"""

from datetime import datetime, timezone

PURPOSE = "vet-lab-send-outs"
PLACE = "courier, external reference lab"
UTC = "YYYY-MM-DD\"T\"HH24:MI:SS\"Z\""
CHASES = 2                            # resends asked, then the escalation
LAST_CALL = (19, 45)                  # local: an unaccepted send-out escalated from then on its packing day

# What a send-out carries (lab rule 11), by order test: the key, the
# accession, the label, the external code, species, sex, whole years.
PAYLOAD = (
    "SELECT t.id, {key}, t.order_id, s.id, s.label, x.external_code, o.species, o.sex,"
    "       CASE WHEN o.born_on IS NOT NULL THEN extract(year FROM age(current_date, o.born_on))::integer END"
)
TESTS = (
    "  FROM lab_order_tests AS t JOIN lab_samples AS s ON s.id = t.sample_id"
    "  JOIN lab_orders AS o ON o.id = t.order_id JOIN lab_tests AS x ON x.id = t.test_id"
)
PENDING = (
    PAYLOAD.format(key="md5('vet-lab-send-out-test:' || t.id)::uuid::text") + TESTS
    + " WHERE t.routing = 'sent-out' AND t.status = 'sent-out' AND s.received_at IS NOT NULL"
      "   AND o.cancelled_at IS NULL AND x.external_code IS NOT NULL"
      "   AND NOT EXISTS (SELECT 1 FROM lab_send_outs AS so WHERE so.order_test_id = t.id)"
      " ORDER BY s.received_at, t.id LIMIT %s"
)
SEND_OUT = (
    "INSERT INTO lab_send_outs (order_test_id, send_key, external_accession, packed_at, sent_at, accepted_at,"
    " due_by, status) VALUES (%s, %s::uuid, %s, %s, %s, %s, %s::timestamptz, %s) ON CONFLICT (send_key) DO NOTHING"
)
EVENT = (
    "INSERT INTO lab_sample_events (sample_id, kind, at, place) VALUES (%s, 'sent-out', %s, %s)"
)
RUN = (
    "INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
    " VALUES (%s, %s, %s, %s, %s) RETURNING id"
)


def _body(row):
    _tid, key, order, _sample, label, code, species, sex, age = row
    return {"send_key": key, "accession": order, "label": label, "test_code": code,
            "species": species, "sex": sex, "age": age}


def _post(partner, path, body, log, what):
    """-> (answer or None, stop): an answer whatever its status; None and
    stop on no answer (a timeout, refused)."""
    try:
        return partner.post(path, body), False
    except partner.HttpError as exc:
        log(f"{what} {exc.status}: run stopped")
        return None, True


def _accepted(answer):
    """-> (external accession, due time) of an acceptance, else None."""
    if answer is None or not answer.ok:
        return None
    data = answer.json() or {}
    if data.get("status") != "accepted" or not data.get("accession"):
        return None
    return data["accession"], data.get("due_at")


def send(conns, options, log):
    db, partner = conns["source"], conns["partner"]
    batch = int(options.get("batch", 60))
    with db.cursor() as cur:
        cur.execute("SELECT now()")
        (started,) = cur.fetchone()
        cur.execute(PENDING, (batch,))
        rows = cur.fetchall()
    db.commit()

    outcomes = []                     # (row, sent_at, accepted_at, (accession, due) or None)
    stopped = False
    for row in rows:
        if stopped:
            outcomes.append((row, None, None, None))
            continue
        sent = datetime.now(timezone.utc)
        answer, stopped = _post(partner, "/orders", _body(row), log, f"send-out {row[1]} test={row[0]}")
        accepted = _accepted(answer)
        if answer is not None and accepted is None:
            log(f"send-out {row[1]} test={row[0]} status={answer.status}: not accepted, the chase retries it")
        outcomes.append((row, sent if answer is not None else None,
                         datetime.now(timezone.utc) if accepted else None, accepted))

    # The send-outs and their events first (they name no run), then the run's
    # row with its counts.
    with db.cursor() as cur:
        for row, sent, accepted_at, accepted in outcomes:
            status = "accepted" if accepted else "sent" if sent else "packed"
            cur.execute(SEND_OUT, (row[0], row[1], accepted[0] if accepted else None, started, sent, accepted_at,
                                   accepted[1] if accepted else None, status))
            cur.execute(EVENT, (row[3], started, PLACE))
        written = 2 * len(outcomes)
        cur.execute(RUN, (PURPOSE, "send-outs", started, len(rows), written))
    db.commit()
    return written


# The lab's local time (lab_settings' offset, the one vet-lab's own jobs use).
CLOCK = (
    "SELECT now(), (now() AT TIME ZONE 'UTC') + s.utc_offset_hours * interval '1 hour', s.utc_offset_hours"
    "  FROM lab_settings AS s"
)
# A working day after t: 24 hours, a day more when that lands on a local Sunday.
WORKING_DAY = (
    "({t} + interval '1 day' * CASE WHEN extract(isodow FROM ({t} + interval '1 day') AT TIME ZONE 'UTC'"
    " + %(offset)s * interval '1 hour') = 7 THEN 2 ELSE 1 END)"
)
UNACCEPTED = (
    PAYLOAD.format(key="so.send_key::text") + ", so.id,"
    "       ((so.packed_at AT TIME ZONE 'UTC') + %(offset)s * interval '1 hour')::date,"
    "       EXISTS (SELECT 1 FROM ops.incidents AS i"
    "                WHERE i.purpose = %(purpose)s AND i.kind = 'unaccepted' AND i.ref = so.send_key::text)"
    + TESTS + " JOIN lab_send_outs AS so ON so.order_test_id = t.id"
    " WHERE so.accepted_at IS NULL AND so.status IN ('packed', 'sent')"
    " ORDER BY so.packed_at, so.id LIMIT %(batch)s"
)
OVERDUE = (
    "SELECT so.id, so.send_key::text, coalesce(c.n, 0)::integer,"
    f"       to_char(so.due_by AT TIME ZONE 'UTC', '{UTC}')"
    "  FROM lab_send_outs AS so"
    "  LEFT JOIN LATERAL (SELECT count(*) AS n, max(i.opened_at) AS last_at FROM ops.incidents AS i"
    "                      WHERE i.purpose = %(purpose)s AND i.kind = 'chased' AND i.ref = so.send_key::text) AS c"
    "         ON true"
    " WHERE so.status = 'accepted' AND so.answered_at IS NULL AND so.due_by IS NOT NULL"
    "   AND " + WORKING_DAY.format(t="coalesce(c.last_at, so.due_by)") + " <= now()"
    "   AND NOT EXISTS (SELECT 1 FROM ops.incidents AS i"
    "                    WHERE i.purpose = %(purpose)s AND i.kind = 'unanswered' AND i.ref = so.send_key::text)"
    " ORDER BY so.due_by, so.id LIMIT %(batch)s"
)
ACCEPT = (
    "UPDATE lab_send_outs SET status = 'accepted', external_accession = %s, accepted_at = %s, due_by = %s::timestamptz,"
    " sent_at = coalesce(sent_at, %s) WHERE id = %s AND accepted_at IS NULL"
)
SENT = "UPDATE lab_send_outs SET status = 'sent', sent_at = coalesce(sent_at, %s) WHERE id = %s AND status = 'packed'"
INCIDENT = (
    "INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
    " VALUES (%s, 'chase-send-outs', %s, %s, %s, %s)"
)


def _window(text):
    """'HH:MM-HH:MM' -> ((h, m), (h, m)), the local hours the chase acts in."""
    first, _, last = (text or "08:00-19:59").partition("-")
    return tuple(tuple(int(p) for p in part.split(":")) for part in (first, last))


def chase(conns, options, log):
    db, partner = conns["source"], conns["partner"]
    batch = int(options.get("batch", 40))
    (opens, closes) = _window(options.get("window"))
    with db.cursor() as cur:
        cur.execute(CLOCK)
        started, local, offset = cur.fetchone()
        if local.isoweekday() == 7 or not opens <= (local.hour, local.minute) <= closes:
            db.rollback()
            return 0                  # outside its hours: nothing written, no run row (spec D436)
        args = {"offset": offset, "purpose": PURPOSE, "batch": batch}
        cur.execute(UNACCEPTED, args)
        unaccepted = cur.fetchall()
        cur.execute(OVERDUE, args)
        overdue = cur.fetchall()
    db.commit()

    accepts, sents, incidents = [], [], []   # (args), (args), (kind, send_key, reason)
    stopped = False
    for row in unaccepted:
        payload, (so_id, packed_on, escalated) = row[:9], row[9:]
        key = payload[1]
        if not stopped:
            sent = datetime.now(timezone.utc)
            answer, stopped = _post(partner, "/orders", _body(payload), log, f"send-out {key} retried")
            accepted = _accepted(answer)
            if accepted:
                accepts.append((accepted[0], datetime.now(timezone.utc), accepted[1], sent, so_id))
                continue
            if answer is not None:
                sents.append((sent, so_id))
                log(f"send-out {key} retried status={answer.status}: still not accepted")
        if not escalated and (local.date() > packed_on or (local.hour, local.minute) >= LAST_CALL):
            incidents.append(("unaccepted", key, f"send-out of test {payload[0]} (accession {payload[2]}) packed "
                              f"on {packed_on} still not accepted by the external lab: the lab to be called"))
    for so_id, key, chases, due in overdue:
        if chases >= CHASES:
            incidents.append(("unanswered", key, f"send-out unanswered a working day after its {chases} chases "
                              f"(due {due}): escalated to the lab's manager"))
            continue
        if stopped:
            continue
        answer, stopped = _post(partner, f"/orders/{key}/resend", None, log, f"send-out {key} chased")
        if answer is None:
            continue
        if not answer.ok:
            log(f"send-out {key} chased status={answer.status}")
        incidents.append(("chased", key, f"chase {chases + 1} of {CHASES}: send-out due {due} unanswered a working "
                          f"day after, resend asked (status {answer.status})"))

    with db.cursor() as cur:
        for args in accepts:
            cur.execute(ACCEPT, args)
        for args in sents:
            cur.execute(SENT, args)
        written = len(accepts) + len(sents) + len(incidents)
        cur.execute(RUN, (PURPOSE, "chase-send-outs", started, len(unaccepted) + len(overdue), written))
        (run,) = cur.fetchone()
        for kind, key, reason in incidents:
            cur.execute(INCIDENT, (PURPOSE, kind, key, reason, run))
    db.commit()
    return written
