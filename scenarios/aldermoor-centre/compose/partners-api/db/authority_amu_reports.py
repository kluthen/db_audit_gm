"""The authority's yearly reports endpoint, its database side (purpose 8's
stub): as the role authority, on partners. A call's number is
nextval('authority.calls'), shared with purpose 5's route; the reference
continues the acknowledged ones' (AMU<year>-<4 digits>), one at a time under
an advisory lock."""

import json

import gm_api


def state(hostname):
    with gm_api.connection("authority-db") as conn:
        rows = conn.execute("SELECT name, value FROM authority.state WHERE hostname = %s", (hostname,)).fetchall()
    return dict(rows)


def take(body, fail_one_in):
    """-> the reference, or None for a call answered 503."""
    key = body["report_key"]
    with gm_api.connection("authority-db") as conn:
        (call,) = conn.execute("SELECT nextval('authority.calls')").fetchone()
        if fail_one_in > 0 and call % fail_one_in == 0:
            conn.execute("INSERT INTO authority.amu_report_calls (call, report_key, status) "
                         "VALUES (%s, %s, 503)", (call, key))
            conn.commit()
            return None
        conn.execute("SELECT pg_advisory_xact_lock(hashtext('authority.amu-reference'))")
        (reference,) = conn.execute(
            "INSERT INTO authority.amu_reports (report_key, reference, body) "
            "SELECT %s, 'AMU' || to_char(now(), 'YYYY') || '-' || lpad((count(*) + 1)::text, 4, '0'), %s::jsonb "
            "FROM authority.amu_reports "
            "ON CONFLICT (report_key) DO UPDATE SET last_at = now(), "
            "accepted = authority.amu_reports.accepted + 1 RETURNING reference",
            (key, json.dumps(body))).fetchone()
        conn.execute("INSERT INTO authority.amu_report_calls (call, report_key, status) "
                     "VALUES (%s, %s, 201)", (call, key))
        conn.commit()
    return reference
