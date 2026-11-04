"""portal-api's accounts endpoint, its database side (vet-portal; capture W3
item 5, W3-e): as portal_api, which may only execute these functions, owned
by portal, SECURITY DEFINER, their search_path pinned (T255):
portal_activate(token, password, reminders), portal_request_reset(email),
portal_reset(token, password), portal_unsubscribe(message_key). Each call
one transaction, committed."""

import gm_api

SESSION = {"statement_timeout": "5s"}


def activate(token, password, reminders):
    """-> the account's id, or None."""
    with gm_api.connection("portal", session=SESSION) as conn:
        (account_id,) = conn.execute("SELECT portal_activate(%s, %s, %s)",
                                     (token, password, reminders)).fetchone()
        conn.commit()
    return account_id


def request_reset(email):
    with gm_api.connection("portal", session=SESSION) as conn:
        conn.execute("SELECT portal_request_reset(%s)", (email,))
        conn.commit()


def reset(token, password):
    """-> True when the link was used."""
    with gm_api.connection("portal", session=SESSION) as conn:
        (done,) = conn.execute("SELECT portal_reset(%s, %s)", (token, password)).fetchone()
        conn.commit()
    return bool(done)


def unsubscribe(message_key):
    """-> True when the key was a reminder's of an open account."""
    with gm_api.connection("portal", session=SESSION) as conn:
        (done,) = conn.execute("SELECT portal_unsubscribe(%s::uuid)", (message_key,)).fetchone()
        conn.commit()
    return bool(done)
