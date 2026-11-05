"""lab-api's send_outs endpoint, its database side (vet-lab; capture W3 item
1): as lab_api, which updates a send-out's status and answered_at and writes
its results. The send-out row is locked while it is read, so two deliveries of
one answer racing each other write it once. The test itself stays sent-out
until the information system's technical validation (lis, lab.validate.technical)."""

import gm_api

SESSION = {"statement_timeout": "5s"}


class Refused(Exception):
    """The answer cannot be recorded (422): an analyte the lab does not know."""


def record(send_key, resulted_at, results):
    """-> False for an unknown send_key; True once recorded (now or before)."""
    with gm_api.connection("lab", session=SESSION) as conn:
        row = conn.execute("SELECT id, order_test_id, status FROM lab_send_outs WHERE send_key = %s FOR UPDATE",
                           (send_key,)).fetchone()
        if row is None:
            return False
        _sid, order_test_id, status = row
        if status == "resulted":             # the same answer again: nothing written twice
            conn.rollback()
            return True
        codes = [r["analyte"] for r in results]
        known = dict(conn.execute("SELECT code, id FROM lab_analytes WHERE code = ANY(%s)", (codes,)).fetchall())
        unknown = sorted(set(codes) - set(known))
        if unknown:
            conn.rollback()
            raise Refused("unknown analyte " + ", ".join(unknown))
        for r in results:
            conn.execute(
                "INSERT INTO lab_results (order_test_id, analyte_id, numeric_value, text_value, flag, measured_at) "
                "VALUES (%s, %s, %s, %s, %s, %s)",
                (order_test_id, known[r["analyte"]], r["numeric_value"], r["text_value"], r["flag"], resulted_at))
        conn.execute("UPDATE lab_send_outs SET status = 'resulted', answered_at = now() WHERE send_key = %s",
                     (send_key,))
        conn.commit()
    return True
