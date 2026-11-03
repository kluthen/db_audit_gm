"""The lab's order API, its database side (stack test fixture of the api
brick): the queries, the transactions, the session settings."""

import gm_api

SESSION = {"statement_timeout": "5s"}


def find(order_id):
    with gm_api.connection("lab", session=SESSION) as conn:
        row = conn.execute("SELECT id, label FROM orders WHERE id = %s", (order_id,)).fetchone()
    return None if row is None else {"id": row[0], "label": row[1]}


def add(order_id, label):
    with gm_api.connection("lab", session=SESSION) as conn:
        conn.execute("INSERT INTO orders VALUES (%s, %s)", (order_id, label))
        conn.commit()
    return {"id": order_id, "label": label}


def whoami(owner):
    """The session as the endpoint sees it: its role, a transaction-local
    setting (set for this request only), a SECURITY DEFINER call."""
    with gm_api.connection("lab", session=SESSION) as conn:
        before = conn.execute("SELECT current_setting('portal.owner_id', true)").fetchone()[0]
        conn.execute("SELECT set_config('portal.owner_id', %s, true)", (owner,))
        definer = conn.execute("SELECT record_owner()").fetchone()[0]
        row = conn.execute("SELECT current_user, session_user, current_setting('portal.owner_id', true), "
                           "current_setting('statement_timeout'), "
                           "(SELECT rolsuper FROM pg_roles WHERE rolname = current_user)").fetchone()
        conn.commit()
    return {"user": row[0], "session_user": row[1], "owner": row[2], "before": before,
            "timeout": row[3], "superuser": row[4], "definer": definer}
