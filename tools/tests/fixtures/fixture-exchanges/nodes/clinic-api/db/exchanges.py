# from scenario: compose/clinic-api/db/exchanges.py
"""clinic-api's exchanges endpoint, its database side (purpose 4,
vet-centre-exchanges; capture W4 items 0 and 4): as vet_exchange, which reads
exchanges and the sites' codes, files the centres' requests and writes the
answers and reports on the clinic's own. Each request taken is one ops.runs
row (job exchanges-endpoint) and one ops.exchange_messages row (direction in,
the centre its site's code) in the transaction of what it writes; the row is
locked while it is read, so two deliveries racing write it once."""

import gm_api

SESSION = {"statement_timeout": "5s"}
PURPOSE = "vet-centre-exchanges"
JOB = "exchanges-endpoint"


class UnknownSite(Exception):
    """The request names no other centre of the franchise (422)."""


def _ledger(conn, xid, key, kind, centre, status, written):
    (run_id,) = conn.execute(
        "INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written) "
        "VALUES (%s, %s, now(), 1, %s) RETURNING id", (PURPOSE, JOB, written + 2)).fetchone()
    conn.execute("INSERT INTO ops.exchange_messages (run_id, exchange_id, exchange_key, kind, direction, centre, "
                 "http_status) VALUES (%s, %s, %s, %s, 'in', %s, %s)", (run_id, xid, key, kind, centre, status))


def take(key, site, kind, reason, requested_at, patient):
    """-> True when filed now, False when the key was already filed."""
    with gm_api.connection("clinic-exchanges", session=SESSION) as conn:
        row = conn.execute("SELECT id FROM sites WHERE code = %s AND kind <> 'own'", (site,)).fetchone()
        if row is None:
            raise UnknownSite(site)
        summary = f"partner record {site}/{patient['ref']}: {patient['species']}"
        if patient.get("age_years") is not None:
            summary += f", {patient['age_years']} years"
        got = conn.execute(
            "INSERT INTO exchanges (direction, kind, partner_site_id, partner_patient, reason, exchange_key, "
            "requested_at, state) VALUES ('in', %s, %s, %s, %s, %s, %s, 'received') "
            "ON CONFLICT (exchange_key) DO NOTHING RETURNING id",
            (kind, row[0], summary, reason, key, requested_at)).fetchone()
        if got is None:
            xid = conn.execute("SELECT id FROM exchanges WHERE exchange_key = %s", (key,)).fetchone()[0]
            _ledger(conn, xid, key, "request", site, 200, 0)
        else:
            _ledger(conn, got[0], key, "request", site, 201, 1)
        conn.commit()
    return got is not None


def _centre(conn, xid):
    return conn.execute("SELECT s.code FROM exchanges e JOIN sites s ON s.id = e.partner_site_id WHERE e.id = %s",
                        (xid,)).fetchone()[0]


def answer(key, answer, accepted_for):
    """-> the exchange's state once recorded, or None: not one of the
    clinic's requests."""
    with gm_api.connection("clinic-exchanges", session=SESSION) as conn:
        row = conn.execute("SELECT id, state FROM exchanges WHERE exchange_key = %s AND direction = 'out' "
                           "FOR UPDATE", (key,)).fetchone()
        if row is None:
            return None
        xid, state = row
        written = 0
        if state in ("requested", "sent"):
            conn.execute("UPDATE exchanges SET state = %s, accepted_for = %s, answered_at = now() WHERE id = %s",
                         (answer, accepted_for if answer == "accepted" else None, xid))
            state, written = answer, 1
        _ledger(conn, xid, key, "answer", _centre(conn, xid), 200, written)
        conn.commit()
    return state


def report(key, text):
    """-> the exchange's state once recorded (reported), its state when it is
    not an accepted examination, or None: not one of the clinic's requests."""
    with gm_api.connection("clinic-exchanges", session=SESSION) as conn:
        row = conn.execute("SELECT id, kind, state FROM exchanges WHERE exchange_key = %s AND direction = 'out' "
                           "FOR UPDATE", (key,)).fetchone()
        if row is None:
            return None
        xid, kind, state = row
        written = 0
        if kind == "examination" and state == "accepted":
            conn.execute("UPDATE exchanges SET state = 'reported', report = %s, reported_at = now() WHERE id = %s",
                         (text, xid))
            state, written = "reported", 1
        _ledger(conn, xid, key, "report", _centre(conn, xid), 200 if state == "reported" else 409, written)
        conn.commit()
    return state
