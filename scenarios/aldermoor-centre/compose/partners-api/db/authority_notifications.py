"""The authority's notifications endpoint, its database side (purpose 5's
stub): as the role authority, on partners. A call's number is
nextval('authority.calls'), shared with purpose 8's route; the reference
continues the accepted ones' (N<year>-<6 digits>), one at a time under an
advisory lock."""

import json

import gm_api


def state(hostname):
    with gm_api.connection("authority-db") as conn:
        rows = conn.execute("SELECT name, value FROM authority.state WHERE hostname = %s", (hostname,)).fetchall()
    return dict(rows)


def take(body, fail_one_in):
    """-> the reference, or None for a call answered 503."""
    key = body["notification_key"]
    with gm_api.connection("authority-db") as conn:
        (call,) = conn.execute("SELECT nextval('authority.calls')").fetchone()
        if fail_one_in > 0 and call % fail_one_in == 0:
            conn.execute("INSERT INTO authority.notification_calls (call, notification_key, status) "
                         "VALUES (%s, %s, 503)", (call, key))
            conn.commit()
            return None
        conn.execute("SELECT pg_advisory_xact_lock(hashtext('authority.reference'))")
        (reference,) = conn.execute(
            "INSERT INTO authority.notifications (notification_key, reference, body) "
            "SELECT %s, 'N' || to_char(now(), 'YYYY') || '-' || lpad((count(*) + 1)::text, 6, '0'), %s::jsonb "
            "FROM authority.notifications "
            "ON CONFLICT (notification_key) DO UPDATE SET last_at = now(), "
            "accepted = authority.notifications.accepted + 1 RETURNING reference",
            (key, json.dumps(body))).fetchone()
        conn.execute("INSERT INTO authority.notification_calls (call, notification_key, status) "
                     "VALUES (%s, %s, 201)", (call, key))
        conn.commit()
    return reference
