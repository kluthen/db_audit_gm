"""portal-api's me endpoint, its database side (vet-portal; capture W3 item
5, W3-e): as portal_api, one transaction per request. First portal_session
(token) gives the account and its owner (nothing for a session closed, idle
or expired, which it ends), then set_config('portal.owner_id', <owner>,
true), local to the transaction; the queries add no owner filter of their
own: the policies do (portal_accounts_scope, portal_consent_events_scope).
The account's hashes are not granted; the closure is portal_close's."""

from datetime import timezone

import psycopg

import gm_api

SESSION = {"statement_timeout": "5s"}

ACCOUNT = ("account_id", "owner_id", "kind", "display_name", "email", "phone", "status", "notify_by",
           "reminders", "invited_at", "activated_at", "last_login_at")
CONSENT = ("purpose", "animal_id", "keeper_id", "granted", "at", "source")


class Refused(Exception):
    """A consent the policies refuse (403): keeper-access for an animal the
    asker does not own now."""


def _utc(value):
    if hasattr(value, "astimezone"):
        return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return value


def _asker(conn, token):
    """-> (account_id, owner_id), portal.owner_id set for this transaction;
    None when portal_session refuses the token."""
    if not token:
        return None
    account_id, owner_id = conn.execute("SELECT account_id, owner_id FROM portal_session(%s)",
                                        (token,)).fetchone()
    if account_id is None:
        conn.commit()                        # an idle or expired session stays ended
        return None
    conn.execute("SELECT set_config('portal.owner_id', %s, true)", (str(owner_id),))
    return account_id, owner_id


def _account(conn):
    row = conn.execute(
        "SELECT id, owner_id, kind, display_name, email, phone, status, notify_by, reminders, invited_at, "
        "activated_at, last_login_at FROM portal_accounts").fetchone()
    account = {k: _utc(v) for k, v in zip(ACCOUNT, row)}
    rows = conn.execute(
        "SELECT DISTINCT ON (purpose, animal_id, keeper_id) purpose, animal_id, keeper_id, granted, at, source "
        "FROM portal_consent_events ORDER BY purpose, animal_id, keeper_id, at DESC, id DESC").fetchall()
    account["consents"] = [{k: _utc(v) for k, v in zip(CONSENT, r)} for r in rows]
    return account


def get(token):
    """-> the account, or None (401)."""
    with gm_api.connection("portal", session=SESSION) as conn:
        if _asker(conn, token) is None:
            return None
        account = _account(conn)
        conn.commit()
    return account


def preferences(token, notify_by):
    """The channel changed; -> the account, or None (401)."""
    with gm_api.connection("portal", session=SESSION) as conn:
        asker = _asker(conn, token)
        if asker is None:
            return None
        conn.execute("UPDATE portal_accounts SET notify_by = %s WHERE id = %s", (notify_by, asker[0]))
        account = _account(conn)
        conn.commit()
    return account


def consent(token, purpose, granted, animal_id, keeper_id):
    """The event as the asker (source portal), and the account's reminders
    flag beside a reminders' one; -> the event, or None (401)."""
    with gm_api.connection("portal", session=SESSION) as conn:
        asker = _asker(conn, token)
        if asker is None:
            return None
        try:
            (event_id, at) = conn.execute(
                "INSERT INTO portal_consent_events (owner_id, purpose, animal_id, keeper_id, granted, at, source) "
                "VALUES (%s, %s, %s, %s, %s, now(), 'portal') RETURNING id, at",
                (asker[1], purpose, animal_id, keeper_id, granted)).fetchone()
        except psycopg.errors.InsufficientPrivilege:
            conn.rollback()
            raise Refused("keeper-access only for an animal you own now") from None
        if purpose == "reminders":
            conn.execute("UPDATE portal_accounts SET reminders = %s WHERE id = %s", (granted, asker[0]))
        conn.commit()
    return {"event_id": event_id, "purpose": purpose, "animal_id": animal_id, "keeper_id": keeper_id,
            "granted": granted, "at": _utc(at), "source": "portal"}


def close(token):
    """portal_close(): -> True when the asker's account was closed."""
    with gm_api.connection("portal", session=SESSION) as conn:
        if _asker(conn, token) is None:
            return False
        (closed,) = conn.execute("SELECT portal_close()").fetchone()
        conn.commit()
    return bool(closed)
