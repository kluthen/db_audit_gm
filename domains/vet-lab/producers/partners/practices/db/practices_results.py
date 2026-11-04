"""The practices' results endpoint, its database side (vet-lab's practices
stub): as the role practices, on partners."""

import gm_api


def state(hostname):
    with gm_api.connection("practices-db") as conn:
        rows = conn.execute("SELECT name, value FROM practices.state WHERE hostname = %s",
                            (hostname,)).fetchall()
    return dict(rows)


def acknowledge(d):
    """-> the delivery_key's repeats (0 the first time)."""
    with gm_api.connection("practices-db") as conn:
        (repeats,) = conn.execute(
            "INSERT INTO practices.deliveries (delivery_key, account_id, accession, kind, first_at, last_at) "
            "VALUES (%s, %s, %s, %s, now(), now()) "
            "ON CONFLICT (delivery_key) DO UPDATE SET last_at = now(), "
            "repeats = practices.deliveries.repeats + 1 RETURNING repeats",
            (d["delivery_key"], d["account"], d["accession"], d["kind"])).fetchone()
        conn.commit()
    return repeats
