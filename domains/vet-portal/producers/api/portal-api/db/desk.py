"""portal-api's desk endpoint, its database side (vet-portal; capture W3 item
5, W3-e): as portal_api, portal_desk_consent(owner_id, purpose, granted), a
SECURITY DEFINER function owned by portal: the event (source desk) and the
account's reminders flag beside it. One transaction, committed."""

import gm_api

SESSION = {"statement_timeout": "5s"}


def consent(owner_id, purpose, granted):
    """-> True when recorded."""
    with gm_api.connection("portal", session=SESSION) as conn:
        (done,) = conn.execute("SELECT portal_desk_consent(%s, %s, %s)",
                               (owner_id, purpose, granted)).fetchone()
        conn.commit()
    return bool(done)
