# from scenario: compose/partners-api/db/headoffice_figures.py
"""The head office's figures endpoint, its database side (purpose 9's stub):
as the role headoffice, on partners. A call's number is
nextval('headoffice.calls'); the reference continues the acknowledged ones'
(HO<YYYYMM>-<4 digits>, the month posted), one at a time under an advisory
lock."""

import json

import gm_api


def state(hostname):
    with gm_api.connection("headoffice-db") as conn:
        rows = conn.execute("SELECT name, value FROM headoffice.state WHERE hostname = %s", (hostname,)).fetchall()
    return dict(rows)


def take(body, fail_one_in):
    """-> the reference, or None for a call answered 503."""
    key = body["figures_key"]
    with gm_api.connection("headoffice-db") as conn:
        (call,) = conn.execute("SELECT nextval('headoffice.calls')").fetchone()
        if fail_one_in > 0 and call % fail_one_in == 0:
            conn.execute("INSERT INTO headoffice.figure_calls (call, figures_key, status) "
                         "VALUES (%s, %s, 503)", (call, key))
            conn.commit()
            return None
        conn.execute("SELECT pg_advisory_xact_lock(hashtext('headoffice.figures-reference'))")
        (reference,) = conn.execute(
            "INSERT INTO headoffice.figures (figures_key, reference, body) "
            "SELECT %s, 'HO' || replace(%s, '-', '') || '-' || lpad((count(*) + 1)::text, 4, '0'), %s::jsonb "
            "FROM headoffice.figures "
            "ON CONFLICT (figures_key) DO UPDATE SET last_at = now(), "
            "accepted = headoffice.figures.accepted + 1 RETURNING reference",
            (key, body["month"], json.dumps(body))).fetchone()
        conn.execute("INSERT INTO headoffice.figure_calls (call, figures_key, status) "
                     "VALUES (%s, %s, 201)", (call, key))
        conn.commit()
    return reference
