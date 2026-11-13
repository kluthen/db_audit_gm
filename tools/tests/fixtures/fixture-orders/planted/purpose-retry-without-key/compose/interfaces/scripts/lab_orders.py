"""The centre's lab orders and their results (vet-lab-centre-orders, v0.5
master spec 12.2 purpose 1; clinic-purposes.md section 5; capture W4 items 0
and 3): the integration engine's two script jobs between the core's record,
clinic, and the lab's order API, lab-api, as the centre's account 1 (never
charged). The lab never writes clinic; these jobs carry both ways.

Called by the scheduler as <function>(conns, options, log):
`conns["source"]` clinic as vet_interfaces (psycopg 3, autocommit off),
`conns["api"]` the HTTP client to lab-api (credential lab_centre). Each run
writes one ops.runs row in the transaction of its output, empty runs included
(master spec 12.1). Logs ids, codes and statuses only, never a name.

post: the analysis requests still `requested` whose consultation has closed,
  grouped by consultation and priority, urgent first then oldest, at most
  options["batch"] groups; the read's transaction ended before any call. Each
  group posted as one order, `POST /orders`, keyed client_ref
  C-<consultation>-<priority> (lab-api answers the same key again with the
  same accession, 200, writing nothing). After the calls, one clinic
  transaction: the run's row, each attempt in ops.lab_orders_sent, and the
  answered groups' requests `sent`. No answer (a timeout, the API down) ends
  the calls; the next run posts again with the same client_ref.

fetch: `GET /orders?account=1&released_since=<watermark - margin>`, the
  centre's tests released, not performed or cancelled since; each request
  carried on such a test copied once into ops.request_results (its primary
  key deduplicates the margin's repeats) and moved: `resulted` when released,
  `cancelled` otherwise (the reason kept in the copy), only from `sent`. The
  watermark advances to the latest (time, order_test_id) read. Requests sent
  and still unanswered past their test's turnaround plus two hours: one
  ops.incidents row each, once. One clinic transaction.
"""

PURPOSE = "vet-lab-centre-orders"
WATERMARK = "lab-results"
RESIDUE = ("MINH",)                  # a residue screening carries the withdrawal end
UTC = "YYYY-MM-DD\"T\"HH24:MI:SS\"Z\""

# The lab's turnarounds (hours) for the tests the centre orders (vet-lab's
# catalogue, lab_tests.turnaround_hours); 24 for any other code.
TURNAROUND = {
    "ACTHST": 72, "BGAS": 1, "BVDPCR": 72, "CALFD": 4, "CBC": 2, "CHEMEQ": 4, "CHEMSA": 4, "COAG": 2,
    "COLIC": 1, "CULT": 72, "DIARC": 2, "EACTH": 72, "EFFUS": 4, "EIA": 24, "FEC": 24, "FELV": 2, "FNA": 24,
    "FOAL": 2, "GLU": 1, "HERDB": 48, "HISTO": 120, "LIVER": 2, "MCULT": 72, "METRU": 4, "MINH": 24,
    "MINRU": 24, "PB": 120, "PCRSA": 96, "PCVTS": 1, "PERFEQ": 4, "PREA": 2, "RENAL": 2, "SENIOR": 4,
    "STREP": 72, "TT4": 72, "UA": 2, "UAUPC": 4, "UCULT": 72, "VECT": 2,
}
GRACE_HOURS = 2                      # an unanswered request escalated past turnaround + 2 h

PENDING = (
    "SELECT r.consultation_id, r.priority, array_agg(r.id ORDER BY r.id), array_agg(r.code ORDER BY r.id),"
    " min(r.animal_id), min(r.requested_by)"
    " FROM requests AS r JOIN consultations AS c ON c.id = r.consultation_id"
    " WHERE r.state = 'requested' AND r.kind = 'analysis' AND c.state IN ('closed', 'signed')"
    " GROUP BY r.consultation_id, r.priority"
    " ORDER BY r.priority = 'urgent' DESC, min(c.ended_at), r.consultation_id"
    " LIMIT %s"
)
WITHDRAWAL = (
    "SELECT to_char(max(l.withdrawal_ends_on), 'YYYY-MM-DD')"
    " FROM administrations AS a JOIN prescription_lines AS l ON l.id = a.prescription_line_id"
    " WHERE a.animal_id = %s"
)
RUN = (
    "INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
    " VALUES (%s, %s, %s, %s, %s) RETURNING id"
)
LEDGER = (
    "INSERT INTO ops.lab_orders_sent AS s (client_ref, request_ids, accession, last_status, posted_at,"
    " answered_at, run_id) VALUES (%s, %s, %s, %s, %s, %s, %s)"
    " ON CONFLICT (client_ref) DO UPDATE SET request_ids = EXCLUDED.request_ids,"
    " accession = coalesce(EXCLUDED.accession, s.accession), attempts = s.attempts + 1,"
    " last_status = EXCLUDED.last_status, answered_at = coalesce(s.answered_at, EXCLUDED.answered_at),"
    " run_id = EXCLUDED.run_id"
)
SENT = "UPDATE requests SET state = 'sent', sent_at = now() WHERE id = ANY(%s) AND state = 'requested'"


def _run_row(cur, job, started, read, written):
    cur.execute(RUN, (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def post(conns, options, log):
    db, api = conns["source"], conns["api"]
    batch = int(options.get("batch", 20))
    with db.cursor() as cur:
        cur.execute("SELECT now()")
        (started,) = cur.fetchone()
        cur.execute(PENDING, (batch,))
        groups = cur.fetchall()
        cur.execute("SELECT client_ref FROM ops.lab_orders_sent WHERE answered_at IS NULL AND last_status = 'timeout'")
        timed_out = {r for (r,) in cur.fetchall()}
        withdrawal = {}
        for _cid, _prio, _ids, codes, animal, _vet in groups:
            if any(c in RESIDUE for c in codes) and animal not in withdrawal:
                cur.execute(WITHDRAWAL, (animal,))
                withdrawal[animal] = cur.fetchone()[0]
    db.commit()

    attempts = []                    # (client_ref, request ids, accession, status, answered)
    for cid, priority, ids, codes, animal, vet in groups:
        ref = f"C-{cid}-{priority}"
        body = {"account": 1, "client_ref": ref, "priority": priority, "animal_id": animal,
                "consultation_id": cid, "requested_by": vet,
                "tests": [{"code": c, "request_id": r} for r, c in zip(ids, codes)]}
        if withdrawal.get(animal) and any(c in RESIDUE for c in codes):
            body["withdrawal_ends_on"] = withdrawal[animal]
        if ref in timed_out:         # no answer last time: a reference of its own, so the lab takes the retry
            ref = body["client_ref"] = f"{ref}-{started:%H%M}"
        try:
            answer = api.post("/orders", body)
        except api.HttpError as exc:
            log(f"order {ref} requests={','.join(map(str, ids))} lab-api {exc.status}: run stopped")
            attempts.append((ref, ids, None, str(exc.status), False))
            break
        accession = (answer.json() or {}).get("accession") if answer.ok else None
        if not answer.ok:
            log(f"order {ref} status={answer.status}: left requested")
        attempts.append((ref, ids, accession, str(answer.status), answer.ok and accession is not None))

    # The requests first (they name no run), then the run's row with its
    # counts (the role inserts ops.runs, never updates it), then the ledger.
    with db.cursor() as cur:
        sent = 0
        for _ref, ids, _acc, _status, answered in attempts:
            if answered:
                cur.execute(SENT, (ids,))
                sent += cur.rowcount
        written = sent + len(attempts)
        run = _run_row(cur, "post-lab-orders", started, len(groups), written)
        for ref, ids, accession, status, answered in attempts:
            cur.execute(LEDGER, (ref, ids, accession, status, started, started if answered else None, run))
    db.commit()
    return written


FEED_ROW = (
    "INSERT INTO ops.request_results (request_id, order_test_id, accession, status, reason, released_at, run_id)"
    " VALUES (%s, %s, %s, %s, %s, %s, %s) ON CONFLICT (request_id) DO NOTHING"
)
RESULTED = "UPDATE requests SET state = 'resulted', resulted_at = now() WHERE id = %s AND state = 'sent'"
CANCELLED = "UPDATE requests SET state = 'cancelled', cancelled_at = now() WHERE id = %s AND state = 'sent'"
ADVANCE = (
    "UPDATE ops.watermarks SET at = %s, last_id = %s, run_id = %s"
    " WHERE purpose = %s AND name = %s AND (at IS NULL OR (at, coalesce(last_id, 0)) < (%s::timestamptz, %s))"
)
OVERDUE = (
    "SELECT r.id, r.code, extract(epoch FROM now() - r.sent_at) / 3600 FROM requests AS r"
    " WHERE r.state = 'sent' AND r.kind = 'analysis' AND r.sent_at < now() - make_interval(hours => %s)"
    " AND NOT EXISTS (SELECT 1 FROM ops.incidents AS i"
    "                  WHERE i.purpose = %s AND i.kind = 'overdue' AND i.ref = r.id::text)"
    " ORDER BY r.sent_at, r.id"
)
INCIDENT = (
    "INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
    " VALUES (%s, 'fetch-lab-results', 'overdue', %s, %s, %s)"
)


def fetch(conns, options, log):
    db, api = conns["source"], conns["api"]
    margin = int(options.get("margin_minutes", 15))
    with db.cursor() as cur:
        cur.execute(
            f"SELECT now(), to_char((coalesce(w.at, now()) - make_interval(mins => %s)) AT TIME ZONE 'UTC', '{UTC}')"
            " FROM (SELECT 1) AS one LEFT JOIN ops.watermarks AS w ON w.purpose = %s AND w.name = %s",
            (margin, PURPOSE, WATERMARK))
        started, since = cur.fetchone()
    db.commit()

    feed, failed = [], None
    try:
        answer = api.get("/orders", {"account": "1", "released_since": since})
        if answer.ok:
            feed = answer.json() or []
        else:
            failed = f"status={answer.status}"
    except api.HttpError as exc:
        failed = str(exc.status)
    if failed:
        log(f"feed since {since}: {failed}; nothing copied")

    rows = [r for r in feed if r.get("request_id") is not None]
    with db.cursor() as cur:
        cur.execute("SELECT request_id FROM ops.request_results WHERE request_id = ANY(%s)",
                    ([r["request_id"] for r in rows],))
        known = {k for (k,) in cur.fetchall()}
        new, moved = [], 0
        for row in rows:             # the margin's repeats were copied by an earlier run
            if row["request_id"] in known:
                continue
            known.add(row["request_id"])
            new.append(row)
            cur.execute(RESULTED if row["status"] == "released" else CANCELLED, (row["request_id"],))
            moved += cur.rowcount
        cur.execute(OVERDUE, (min(TURNAROUND.values()) + GRACE_HOURS, PURPOSE))
        overdue = [(r, c, h) for r, c, h in cur.fetchall() if h > TURNAROUND.get(c, 24) + GRACE_HOURS]
        last = max(feed, key=lambda r: (r["at"], r["order_test_id"])) if feed else None
        written = len(new) + moved + len(overdue) + (1 if last else 0)
        run = _run_row(cur, "fetch-lab-results", started, len(feed), written)
        for row in new:
            cur.execute(FEED_ROW, (row["request_id"], row["order_test_id"], row["accession"], row["status"],
                                   row.get("reason"), row["at"], run))
        if last:
            cur.execute(ADVANCE, (last["at"], last["order_test_id"], run, PURPOSE, WATERMARK,
                                  last["at"], last["order_test_id"]))
        for request, code, hours in overdue:
            cur.execute(INCIDENT, (PURPOSE, str(request),
                                   f"request sent {int(hours)} h ago, its test ({code}) still unanswered past "
                                   f"its turnaround of {TURNAROUND.get(code, 24)} h plus {GRACE_HOURS}: the "
                                   "lab to be called", run))
    db.commit()
    return written
