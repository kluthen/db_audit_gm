# from vet-portal@regional-franchise: domains/vet-portal/producers/api/portal-api/db/session.py
"""portal-api's session endpoint, its database side (vet-portal; capture W3
item 5, W3-e): as portal_api, through the SECURITY DEFINER functions owned by
portal (the sessions have no grant): portal_login checks the bcrypt hash and
the lock and returns a new token, its hash stored; portal_logout ends a
session. Each call one transaction, committed whatever it answered, so a
failure counted or a lock set stays (T279)."""

import gm_api

SESSION = {"statement_timeout": "5s"}


def login(email, password):
    """-> (result, token): ('ok', the token), ('wrong', None) or ('locked', None)."""
    with gm_api.connection("portal", session=SESSION) as conn:
        result, token = conn.execute("SELECT result, token FROM portal_login(%s, %s)",
                                     (email, password)).fetchone()
        conn.commit()
    return result, token


def logout(token):
    """-> True when an open session was ended."""
    with gm_api.connection("portal", session=SESSION) as conn:
        (ended,) = conn.execute("SELECT portal_logout(%s)", (token,)).fetchone()
        conn.commit()
    return bool(ended)
