"""Cold storage's manifests, their database side (v0.5 master spec 10.4;
capture W2 item 6): read as the role coldstore."""

import gm_api

LIST = """
SELECT shipment_id, type, source, name, rows_declared, rows_received, size,
       to_char(date_from, 'YYYY-MM-DD'), to_char(date_to, 'YYYY-MM-DD'),
       to_char(received_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
FROM coldstore.manifests
WHERE (%(type)s::text IS NULL OR type = %(type)s)
  AND (%(source)s::text IS NULL OR source = %(source)s)
  AND (%(from)s::date IS NULL OR date_to >= %(from)s)
  AND (%(to)s::date IS NULL OR date_from <= %(to)s)
ORDER BY received_at, shipment_id
"""
FIELDS = ("shipment_id", "type", "source", "name", "rows_declared", "rows_received", "size",
          "date_from", "date_to", "received_at")


def state(hostname):
    """{name: value} of the hostname's state rows."""
    with gm_api.connection("coldstore-db") as conn:
        rows = conn.execute("SELECT name, value FROM coldstore.state WHERE hostname = %s",
                            (hostname,)).fetchall()
    return dict(rows)


def manifests(kind, source, date_from, date_to):
    """The manifests meeting the filters (None: no filter), by received_at."""
    with gm_api.connection("coldstore-db") as conn:
        rows = conn.execute(LIST, {"type": kind, "source": source, "from": date_from,
                                   "to": date_to}).fetchall()
    return [dict(zip(FIELDS, r)) for r in rows]
