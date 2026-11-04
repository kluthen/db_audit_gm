"""The external lab's orders endpoint, its database side (vet-lab's xlab
stub): as the role xlab, on partners. Its accession numbers continue the
history's (NL and 400000 + n, docs/gm.md "Part keys"), one at a time under an
advisory lock; its due time is its own turnaround for the test."""

import gm_api

UTC = "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'"

# The lab's turnarounds (hours) for the tests it is sent (vet-lab's
# catalogue, 115-150); 72 for any other code.
TURNAROUND = {
    "NL-HISTO": 120, "NL-HISTOM": 120, "NL-HISTOS": 120, "NL-HISTOE": 120, "NL-HISTOB": 168, "NL-HISTOP": 168,
    "NL-IHC": 168, "NL-HISTOR": 96, "NL-PCRSA": 96, "NL-STREP": 72, "NL-BVDPCR": 72, "NL-BTPCR": 72,
    "NL-FMDPCR": 48, "NL-EHV1": 72, "NL-LEPPCR": 72, "NL-FCVPCR": 96, "NL-CRDPCR": 72, "NL-MYCPCR": 96,
    "NL-BABPCR": 72, "NL-AHSPCR": 48, "NL-TT4": 72, "NL-ACTHST": 72, "NL-EACTH": 72, "NL-FT4": 72,
    "NL-TSH": 72, "NL-LDDS": 72, "NL-INSUL": 72, "NL-PROG": 72, "NL-TESTO": 72, "NL-PTH": 72,
    "NL-PB": 120, "NL-ETGLY": 120, "NL-ANTICO": 120, "NL-MYCOT": 120, "NL-ORGPH": 120, "NL-NITR": 120,
}


def state(hostname):
    with gm_api.connection("xlab-db") as conn:
        rows = conn.execute("SELECT name, value FROM xlab.state WHERE hostname = %s", (hostname,)).fetchall()
    return dict(rows)


def take(s):
    """-> (accession, due_at): a new send_key recorded, a known one answered as before."""
    with gm_api.connection("xlab-db") as conn:
        conn.execute("SELECT pg_advisory_xact_lock(hashtext('xlab.accession'))")
        row = conn.execute(f"SELECT accession, to_char(due_at AT TIME ZONE 'UTC', {UTC}) FROM xlab.orders "
                           "WHERE send_key = %s", (str(s["send_key"]),)).fetchone()
        if row is None:
            row = conn.execute(
                "INSERT INTO xlab.orders (send_key, accession, lab_accession, label, test_code, species, sex, age, "
                "received_at, due_at) "
                "SELECT %s, 'NL' || lpad((coalesce(max(substr(accession, 3)::integer), 400000) + 1)::text, 7, '0'), "
                "%s, %s, %s, %s, %s, %s, now(), now() + %s * interval '1 hour' "
                "FROM xlab.orders WHERE accession ~ '^NL[0-9]{7}$' "
                f"RETURNING accession, to_char(due_at AT TIME ZONE 'UTC', {UTC})",
                (str(s["send_key"]), s["accession"], s["label"], s["test_code"], s["species"], s["sex"], s["age"],
                 TURNAROUND.get(s["test_code"], 72))).fetchone()
        conn.commit()
    return row[0], row[1]


def resend(send_key):
    """A chase counted; -> its state, or None for an unknown key."""
    with gm_api.connection("xlab-db") as conn:
        row = conn.execute(
            "UPDATE xlab.orders SET resends = resends + 1 WHERE send_key = %s "
            f"RETURNING accession, answered_at IS NOT NULL, to_char(due_at AT TIME ZONE 'UTC', {UTC}), resends",
            (send_key,)).fetchone()
        conn.commit()
    if row is None:
        return None
    return {"send_key": send_key, "accession": row[0], "status": "resulted" if row[1] else "accepted",
            "due_at": row[2], "resends": row[3]}
