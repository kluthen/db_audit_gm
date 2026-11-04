"""lab-api's orders endpoint, its database side (vet-lab; capture W3 item 1):
as lab_api, which reads the catalogue, the accounts, orders, samples, tests
and results, and writes the intake. Times ISO 8601 UTC with Z.

The intake writes what the lab's information system then works on (its
receipt, lab.samples.receive and lab.courier.receive): the order, one sample
per sample type of its tests (label ALD and the id on eight digits, collected
now), one order test per test, routed as the catalogue performs it, ordered.
Idempotency is the unique (account_id, client_ref): a second post of the same
pair inserts nothing and answers the first's accession and tests."""

import gm_api

SESSION = {"statement_timeout": "5s"}

UTC = "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'"
OPTIONAL = ("animal_id", "consultation_id", "requested_by", "patient_ref", "client_surname", "species",
            "sex", "born_on", "microchip", "ueln", "ear_tag", "clinical_notes", "withdrawal_ends_on")


class Refused(Exception):
    """The order cannot be taken (422): an unknown account or test code."""


def _utc(column):
    return f"to_char({column} AT TIME ZONE 'UTC', {UTC})"


def _tests(conn, accession):
    rows = conn.execute(
        "SELECT t.id, x.code, t.request_id FROM lab_order_tests t JOIN lab_tests x ON x.id = t.test_id "
        "WHERE t.order_id = %s ORDER BY t.id", (accession,)).fetchall()
    return [{"order_test_id": r[0], "code": r[1], "request_id": r[2]} for r in rows]


def post(order):
    """-> (created, body)."""
    with gm_api.connection("lab", session=SESSION) as conn:
        account = conn.execute("SELECT id FROM lab_accounts WHERE id = %s AND closed_on IS NULL",
                               (order["account"],)).fetchone()
        if account is None:
            raise Refused(f"unknown account {order['account']}")
        codes = [t["code"] for t in order["tests"]]
        known = {r[0] for r in conn.execute("SELECT code FROM lab_tests WHERE code = ANY(%s)",
                                            (codes,)).fetchall()}
        unknown = [c for c in codes if c not in known]
        if unknown:
            raise Refused("unknown test code " + ", ".join(sorted(set(unknown))))
        columns = [c for c in OPTIONAL if order.get(c) is not None]
        row = conn.execute(
            "INSERT INTO lab_orders (account_id, client_ref, priority, ordered_at"
            + "".join(", " + c for c in columns) + ") VALUES (%s, %s, %s, now()"
            + ", %s" * len(columns) + ") ON CONFLICT (account_id, client_ref) DO NOTHING RETURNING id",
            [order["account"], order["client_ref"], order["priority"]] + [order[c] for c in columns]
        ).fetchone()
        if row is None:                      # the same account and client_ref again
            (accession,) = conn.execute(
                "SELECT id FROM lab_orders WHERE account_id = %s AND client_ref = %s",
                (order["account"], order["client_ref"])).fetchone()
            body = _tests(conn, accession)
            conn.rollback()
            return False, {"accession": accession, "account": order["account"],
                           "client_ref": order["client_ref"], "tests": body}
        (accession,) = row
        samples = {}
        tests = conn.execute(
            "SELECT x.code, x.id, x.sample_type, x.performed FROM lab_tests x "
            "JOIN unnest(%s::text[]) WITH ORDINALITY AS c (code, n) ON c.code = x.code ORDER BY c.n",
            (codes,)).fetchall()
        for _code, _tid, sample_type, _performed in tests:
            if sample_type not in samples:
                (sid,) = conn.execute("SELECT nextval('lab_samples_id_seq')::integer").fetchone()
                conn.execute(
                    "INSERT INTO lab_samples (id, order_id, label, sample_type, collected_at) "
                    "VALUES (%s, %s, 'ALD' || lpad(%s::text, 8, '0'), %s, now())",
                    (sid, accession, sid, sample_type))
                samples[sample_type] = sid
        for (_code, tid, sample_type, performed), test in zip(tests, order["tests"]):
            conn.execute(
                "INSERT INTO lab_order_tests (order_id, sample_id, test_id, request_id, routing) "
                "VALUES (%s, %s, %s, %s, %s)",
                (accession, samples[sample_type], tid, test.get("request_id"), performed))
        body = _tests(conn, accession)
        conn.commit()
    return True, {"accession": accession, "account": order["account"],
                  "client_ref": order["client_ref"], "tests": body}


def _results(conn, test_ids):
    """{order_test_id: [result in force, ...]} in the test's report order."""
    if not test_ids:
        return {}
    rows = conn.execute(
        "SELECT r.order_test_id, a.code, r.numeric_value, r.text_value, a.unit, r.flag, i.low, i.high "
        "FROM lab_results r JOIN lab_analytes a ON a.id = r.analyte_id "
        "JOIN lab_order_tests t ON t.id = r.order_test_id "
        "LEFT JOIN lab_test_analytes ta ON ta.test_id = t.test_id AND ta.analyte_id = r.analyte_id "
        "LEFT JOIN lab_reference_intervals i ON i.id = r.interval_id "
        "WHERE r.order_test_id = ANY(%s) "
        "AND NOT EXISTS (SELECT 1 FROM lab_results s WHERE s.supersedes_id = r.id) "
        "ORDER BY r.order_test_id, ta.position, r.id", (list(test_ids),)).fetchall()
    out = {}
    for tid, analyte, num, text, unit, flag, low, high in rows:
        out.setdefault(tid, []).append({"analyte": analyte, "numeric_value": num, "text_value": text,
                                        "unit": unit, "flag": flag, "low": low, "high": high})
    return out


def by_accession(accession):
    with gm_api.connection("lab", session=SESSION) as conn:
        order = conn.execute(
            "SELECT id, account_id, client_ref, priority, "
            "CASE WHEN cancelled_at IS NOT NULL THEN 'cancelled' WHEN completed_at IS NOT NULL THEN 'completed' "
            "WHEN received_at IS NOT NULL THEN 'received' ELSE 'ordered' END, "
            f"{_utc('ordered_at')}, {_utc('received_at')}, {_utc('completed_at')}, {_utc('cancelled_at')}, "
            "animal_id, consultation_id, patient_ref, species "
            "FROM lab_orders WHERE id = %s", (accession,)).fetchone()
        if order is None:
            return None
        tests = conn.execute(
            "SELECT t.id, x.code, t.request_id, t.routing, t.status, t.not_performed_reason, "
            f"{_utc('t.technical_at')}, {_utc('t.released_at')}, {_utc('t.not_performed_at')}, "
            f"{_utc('t.cancelled_at')} "
            "FROM lab_order_tests t JOIN lab_tests x ON x.id = t.test_id WHERE t.order_id = %s ORDER BY t.id",
            (accession,)).fetchall()
        results = _results(conn, [t[0] for t in tests])
    keys = ("accession", "account", "client_ref", "priority", "state", "ordered_at", "received_at",
            "completed_at", "cancelled_at", "animal_id", "consultation_id", "patient_ref", "species")
    body = dict(zip(keys, order))
    body["tests"] = [{"order_test_id": t[0], "code": t[1], "request_id": t[2], "routing": t[3],
                      "status": t[4], "reason": t[5], "technical_at": t[6], "released_at": t[7],
                      "not_performed_at": t[8], "cancelled_at": t[9], "results": results.get(t[0], [])}
                     for t in tests]
    return body


# The feed: three branches, each on its own time column, so the released
# branch reads lab_order_tests_released_at_idx (T80's baseline).
FEED = (
    f"SELECT o.id, o.client_ref, t.id, t.request_id, x.code, t.status, {_utc('f.at')}, "
    "t.not_performed_reason "
    "FROM (SELECT id, released_at AS at FROM lab_order_tests WHERE status = 'released' AND released_at >= %(s)s "
    "      UNION ALL "
    "      SELECT id, not_performed_at FROM lab_order_tests "
    "       WHERE status = 'not-performed' AND not_performed_at >= %(s)s "
    "      UNION ALL "
    "      SELECT id, cancelled_at FROM lab_order_tests WHERE status = 'cancelled' AND cancelled_at >= %(s)s) f "
    "JOIN lab_order_tests t ON t.id = f.id JOIN lab_orders o ON o.id = t.order_id "
    "JOIN lab_tests x ON x.id = t.test_id "
    "WHERE o.account_id = %(a)s ORDER BY f.at, t.id")


def feed(account, since):
    with gm_api.connection("lab", session=SESSION) as conn:
        rows = conn.execute(FEED, {"s": since, "a": account}).fetchall()
        results = _results(conn, [r[2] for r in rows if r[5] == "released"])
    return [{"accession": r[0], "client_ref": r[1], "order_test_id": r[2], "request_id": r[3], "code": r[4],
             "status": r[5], "at": r[6], "reason": r[7], "results": results.get(r[2], [])} for r in rows]
