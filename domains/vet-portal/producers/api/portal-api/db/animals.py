"""portal-api's animals endpoint, its database side (vet-portal; capture W3
item 5, W3-e): as portal_api, one transaction per request: portal_session
(token), then set_config('portal.owner_id', <owner>, true). No owner filter
here: portal_animals_scope shows the asker's animals (owned now, or kept now
with the owner's latest keeper-access a grant), portal_documents_scope an
animal's documents from the current ownership's start. An animal's documents
by portal_documents_animal_idx (animal_id, record_at DESC; T294)."""

from datetime import date, timezone

import gm_api

SESSION = {"statement_timeout": "5s"}

ANIMAL = ("animal_id", "name", "species", "sex", "born_on", "status")
DOCUMENT = ("document_id", "kind", "title", "version", "record_at", "published_at", "superseded_at")


def _json(value):
    if hasattr(value, "astimezone"):
        return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(value, date):
        return value.isoformat()
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


def mine(token):
    """-> the asker's animals, or None (401)."""
    with gm_api.connection("portal", session=SESSION) as conn:
        if _asker(conn, token) is None:
            return None
        rows = conn.execute("SELECT animal_id, name, species, sex, born_on, status FROM portal_animals "
                            "ORDER BY animal_id").fetchall()
        conn.commit()
    return [{k: _json(v) for k, v in zip(ANIMAL, r)} for r in rows]


def documents(token, animal_id):
    """-> (None, None) for 401, (False, None) for an animal the asker does not
    see, else (True, its documents newest first, 50 at most)."""
    with gm_api.connection("portal", session=SESSION) as conn:
        if _asker(conn, token) is None:
            return None, None
        if conn.execute("SELECT 1 FROM portal_animals WHERE animal_id = %s", (animal_id,)).fetchone() is None:
            conn.commit()
            return False, None
        rows = conn.execute(
            "SELECT id, kind, title, version, record_at, published_at, superseded_at FROM portal_documents "
            "WHERE animal_id = %s ORDER BY record_at DESC, id DESC LIMIT 50", (animal_id,)).fetchall()
        conn.commit()
    return True, [{k: _json(v) for k, v in zip(DOCUMENT, r)} for r in rows]
