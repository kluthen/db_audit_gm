"""The results back to the practices (vet-lab-practice-results, v0.5 master
spec 12.2 purpose 2; clinic-purposes.md section 6; capture W4 items 0 and 3):
the integration engine's script job between the lab's database, lab, and
the region's practices' callbacks (one stub, every account's callback
http://practices:8000/results). The practice asked (its order at lab-api,
vet-lab's); the centre's half is delivering the results.

Called by the scheduler as <function>(conns, options, log):
`conns["source"]` lab as vet-lab's lab_dispatch (psycopg 3, autocommit off),
`conns["partner"]` the HTTP client to the practices' stub (credential
practices_customer, a 30-second timeout; thread-safe). Each run writes one
ops.runs row in the transaction of its output, empty runs included (master
spec 12.1). Logs ids, kinds and statuses only, never a name.

deliver: the deliveries due on the practices' orders of the last
  options["days"] days, each keyed delivery_key, one per order, kind and
  revision, kept across attempts (md5('vet-lab-delivery:<order>:<kind>:
  <revision>'), the history's, vet-lab's keys.sql):
  - interim: an order of several tests, one of them released before the
    order completed (the history's rule, vet-lab's load.sql);
  - final: the order completed (every test released, not performed or
    cancelled);
  - amended: each amendment of the order's results, numbered in time order;
  and no acknowledged attempt of that key. A key with six failed attempts:
  one ops.incidents row (kind undelivered, ref the key), once, no seventh. A
  key whose last attempt is under five minutes old waits. The others, oldest
  event first, at most options["batch"], posted options["parallel"] at a
  time (POST <the account's callback path>): the order's account, accession
  and references, the kind, and each test's status with the results in
  force of its released tests only (lab rule 1). The read's transaction ends
  before the calls. After them one lab transaction: one lab_callbacks row
  per attempt (its HTTP status, none on a timeout; acknowledged_at on a
  2xx), the run's row, the incidents.
"""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from urllib.parse import urlsplit

PURPOSE = "vet-lab-practice-results"
JOB = "deliver-practice-results"
ATTEMPTS = 6                          # at most, then an incident
RETRY_MINUTES = 5                     # after the last attempt
UTC = "YYYY-MM-DD\"T\"HH24:MI:SS\"Z\""

DUE = (
    "WITH o AS MATERIALIZED ("
    "  SELECT o.id, o.account_id, o.completed_at, a.callback_url"
    "    FROM lab_orders AS o JOIN lab_accounts AS a ON a.id = o.account_id"
    "   WHERE a.kind = 'practice' AND o.cancelled_at IS NULL"
    "     AND o.ordered_at > now() - make_interval(days => %(days)s)),"
    " t AS MATERIALIZED ("
    "  SELECT t.order_id, count(*) AS n, min(t.released_at) AS first_release"
    "    FROM lab_order_tests AS t JOIN o ON o.id = t.order_id GROUP BY t.order_id),"
    " ev AS ("
    "  SELECT o.id AS order_id, 'interim' AS kind, 1 AS revision, t.first_release AS event_at"
    "    FROM o JOIN t ON t.order_id = o.id"
    "   WHERE t.n > 1 AND t.first_release < coalesce(o.completed_at, 'infinity')"
    "  UNION ALL"
    "  SELECT o.id, 'final', 1, o.completed_at FROM o WHERE o.completed_at IS NOT NULL"
    "  UNION ALL"
    "  SELECT x.order_id, 'amended',"
    "         row_number() OVER (PARTITION BY x.order_id ORDER BY r.amended_at, r.id)::integer, r.amended_at"
    "    FROM lab_results AS r JOIN lab_order_tests AS x ON x.id = r.order_test_id JOIN o ON o.id = x.order_id"
    "   WHERE r.supersedes_id IS NOT NULL AND r.amended_at IS NOT NULL),"
    " k AS (SELECT ev.*, md5('vet-lab-delivery:' || ev.order_id || ':' || ev.kind || ':' || ev.revision)"
    "                    ::uuid::text AS delivery_key FROM ev)"
    " SELECT k.order_id, k.kind, k.revision, k.delivery_key, o.account_id, o.callback_url,"
    "        coalesce(c.n, 0)::integer, coalesce(c.last_at < now() - make_interval(mins => %(retry)s), true)"
    "   FROM k JOIN o ON o.id = k.order_id"
    "   LEFT JOIN LATERAL (SELECT count(*) AS n, max(cb.posted_at) AS last_at,"
    "                             bool_or(cb.acknowledged_at IS NOT NULL) AS ack"
    "                        FROM lab_callbacks AS cb"
    "                       WHERE cb.order_id = k.order_id AND cb.delivery_key = k.delivery_key) AS c ON true"
    "  WHERE NOT coalesce(c.ack, false)"
    "    AND NOT EXISTS (SELECT 1 FROM ops.incidents AS i"
    "                     WHERE i.purpose = %(purpose)s AND i.kind = 'undelivered' AND i.ref = k.delivery_key)"
    "  ORDER BY k.event_at, k.order_id, k.kind, k.revision"
)
CONTENT = (
    "SELECT o.id, o.client_ref, o.patient_ref, o.client_surname, t.id, x.code, t.status,"
    f"       to_char(t.released_at AT TIME ZONE 'UTC', '{UTC}'),"
    "       a.code, r.numeric_value, r.text_value, a.unit, r.flag"
    "  FROM lab_orders AS o JOIN lab_order_tests AS t ON t.order_id = o.id"
    "  JOIN lab_tests AS x ON x.id = t.test_id"
    "  LEFT JOIN lab_results AS r ON r.order_test_id = t.id AND t.status = 'released'"
    "       AND NOT EXISTS (SELECT 1 FROM lab_results AS s WHERE s.supersedes_id = r.id)"
    "  LEFT JOIN lab_analytes AS a ON a.id = r.analyte_id"
    " WHERE o.id = ANY(%s)"
    " ORDER BY o.id, t.id, a.code"
)
CALLBACK = (
    "INSERT INTO lab_callbacks (order_id, kind, delivery_key, attempt, posted_at, http_status, acknowledged_at)"
    " VALUES (%s, %s, %s, %s, %s, %s, %s)"
)
RUN = (
    "INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
    " VALUES (%s, %s, %s, %s, %s) RETURNING id"
)
INCIDENT = (
    "INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
    " VALUES (%s, %s, 'undelivered', %s, %s, %s)"
)


def _bodies(cur, orders):
    """{order id: (references, tests)}: each test's status, its results in
    force when released, nothing of a test not released."""
    out = {}
    cur.execute(CONTENT, (list(orders),))
    for oid, ref, patient, surname, tid, code, status, released, analyte, num, text, unit, flag in cur.fetchall():
        refs, tests = out.setdefault(oid, ({"client_ref": ref, "patient_ref": patient,
                                             "client_surname": surname}, {}))
        test = tests.setdefault(tid, {"code": code, "status": status, "results": []})
        if status == "released":
            test["released_at"] = released
            if analyte is not None:
                result = {"analyte": analyte, "flag": flag}
                if num is not None:
                    result["numeric_value"], result["unit"] = num, unit
                else:
                    result["text_value"] = text
                test["results"].append(result)
    return out


def _post(partner, path, body):
    """-> (posted_at, HTTP status or None, acknowledged_at or None)."""
    posted = datetime.now(timezone.utc)
    try:
        answer = partner.post(path, body)
    except partner.HttpError:
        return posted, None, None
    return posted, answer.status, datetime.now(timezone.utc) if answer.ok else None


def deliver(conns, options, log):
    db, partner = conns["source"], conns["partner"]
    batch = int(options.get("batch", 40))
    parallel = max(1, int(options.get("parallel", 4)))
    days = int(options.get("days", 30))
    with db.cursor() as cur:
        cur.execute("SELECT now()")
        (started,) = cur.fetchone()
        cur.execute(DUE, {"days": days, "retry": RETRY_MINUTES, "purpose": PURPOSE})
        due = cur.fetchall()
        exhausted = [d for d in due if d[6] >= ATTEMPTS]
        ready = [d for d in due if d[6] < ATTEMPTS and d[7] and d[5]][:batch]
        bodies = _bodies(cur, {d[0] for d in ready}) if ready else {}
    db.commit()

    calls = []                        # (delivery, path, body)
    for oid, kind, revision, key, account, callback, attempts, _ready in ready:
        refs, tests = bodies.get(oid, ({}, {}))
        body = {"delivery_key": key, "account": account, "accession": oid, "kind": kind, "revision": revision,
                **refs, "tests": list(tests.values())}
        calls.append(((oid, kind, key, attempts + 1), urlsplit(callback).path or "/results", body))
    with ThreadPoolExecutor(max_workers=parallel) as pool:
        outcomes = list(pool.map(lambda c: _post(partner, c[1], c[2]), calls))
    for ((oid, kind, key, attempt), _path, _body), (_posted, status, acked) in zip(calls, outcomes):
        if acked is None:
            log(f"delivery {key} order={oid} kind={kind} attempt={attempt} status={status or 'no answer'}"
                + (": the last, an incident at the next run" if attempt >= ATTEMPTS else ""))

    # The callbacks first (they name no run), then the run's row with its
    # counts (the role inserts ops.runs, never updates it), then the
    # incidents referencing it.
    with db.cursor() as cur:
        for ((oid, kind, key, attempt), _path, _body), (posted, status, acked) in zip(calls, outcomes):
            cur.execute(CALLBACK, (oid, kind, key, attempt, posted, status, acked))
        written = len(calls) + len(exhausted)
        cur.execute(RUN, (PURPOSE, JOB, started, len(due), written))
        (run,) = cur.fetchone()
        for oid, kind, revision, key, account, _callback, attempts, _ready in exhausted:
            cur.execute(INCIDENT, (PURPOSE, JOB, key,
                                   f"{kind} delivery of order {oid} (revision {revision}) to account {account} "
                                   f"unacknowledged after {attempts} attempts: the practice to be called", run))
    db.commit()
    return written
