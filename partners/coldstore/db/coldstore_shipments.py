"""Cold storage's upload, its database side (v0.5 master spec 10.4; capture
W2 item 6): its state, and the manifest written as the role coldstore, the
same shipment id replacing its manifest."""

import gm_api

RECORD = """
INSERT INTO coldstore.manifests AS m (shipment_id, type, source, name, rows_declared,
                                      rows_received, size, date_from, date_to)
VALUES (%(id)s, %(type)s, %(source)s, %(name)s, %(declared)s, %(received)s, %(size)s,
        %(from)s, %(to)s)
ON CONFLICT (shipment_id) DO UPDATE SET
    type = EXCLUDED.type, source = EXCLUDED.source, name = EXCLUDED.name,
    rows_declared = EXCLUDED.rows_declared, rows_received = EXCLUDED.rows_received,
    size = EXCLUDED.size, date_from = EXCLUDED.date_from, date_to = EXCLUDED.date_to,
    received_at = now()
RETURNING shipment_id, type, rows_declared, rows_received, size,
          to_char(received_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
"""
FIELDS = ("shipment_id", "type", "rows_declared", "rows_received", "size", "received_at")


def state(hostname):
    """{name: value} of the hostname's state rows."""
    with gm_api.connection("coldstore-db") as conn:
        rows = conn.execute("SELECT name, value FROM coldstore.state WHERE hostname = %s",
                            (hostname,)).fetchall()
    return dict(rows)


def record(shipment_id, kind, source, name, declared, received, size, date_from, date_to):
    """Writes (or replaces) the shipment's manifest; -> the receipt."""
    with gm_api.connection("coldstore-db") as conn:
        row = conn.execute(RECORD, {"id": shipment_id, "type": kind, "source": source,
                                    "name": name, "declared": declared, "received": received,
                                    "size": size, "from": date_from, "to": date_to}).fetchone()
        conn.commit()
    return dict(zip(FIELDS, row))
