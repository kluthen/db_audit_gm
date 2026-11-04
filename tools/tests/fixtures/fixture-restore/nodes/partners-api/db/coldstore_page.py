"""Cold storage's page, its database side (v0.5 master spec 10.4; capture
W2 item 6): the rows shipped per day per type over the last five weeks,
declared and received, read as the role coldstore. A shipment counts on its
range's first day (a data type's partition is one day; a segment or a backup
is its posting day)."""

import gm_api

DAYS = 35

PER_DAY = """
SELECT type, to_char(date_from, 'YYYY-MM-DD'), sum(rows_declared)::bigint,
       sum(rows_received)::bigint, count(*)::bigint
FROM coldstore.manifests
WHERE date_from > current_date - %(days)s AND date_from <= current_date
GROUP BY 1, 2
ORDER BY 1, 2
"""


def state(hostname):
    """{name: value} of the hostname's state rows."""
    with gm_api.connection("coldstore-db") as conn:
        rows = conn.execute("SELECT name, value FROM coldstore.state WHERE hostname = %s",
                            (hostname,)).fetchall()
    return dict(rows)


def per_day():
    """-> (today, [(type, day, declared, received, shipments)]), days as YYYY-MM-DD."""
    with gm_api.connection("coldstore-db") as conn:
        (today,) = conn.execute("SELECT to_char(current_date, 'YYYY-MM-DD')").fetchone()
        rows = conn.execute(PER_DAY, {"days": DAYS}).fetchall()
    return today, rows
