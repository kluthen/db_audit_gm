"""portal-api's documents endpoint, its database side (vet-portal; capture W3
item 5, W3-e): as portal_api, one transaction per request: portal_session
(token), then set_config('portal.owner_id', <owner>, true); the document as
portal_documents_scope shows it, then its portal_views row (open, as the
asker's account) in the same transaction, so what was released to whom is
recorded with the read (rule 8, T280)."""

from datetime import timezone

import gm_api

SESSION = {"statement_timeout": "5s"}

DOCUMENT = ("document_id", "animal_id", "herd_id", "kind", "source_ref", "version", "record_at", "gated_at",
            "published_at", "title", "vet_name", "body", "supersedes_id", "superseded_at")


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


def open_one(token, document_id):
    """-> (None, None) for 401, (False, None) for a document the asker does
    not see, else (True, the document), its view written."""
    with gm_api.connection("portal", session=SESSION) as conn:
        asker = _asker(conn, token)
        if asker is None:
            return None, None
        row = conn.execute(
            "SELECT id, animal_id, herd_id, kind, source_ref, version, record_at, gated_at, published_at, title, "
            "vet_name, body, supersedes_id, superseded_at FROM portal_documents WHERE id = %s",
            (document_id,)).fetchone()
        if row is None:
            conn.commit()
            return False, None
        conn.execute("INSERT INTO portal_views (account_id, document_id, at, action) VALUES (%s, %s, now(), 'open')",
                     (asker[0], document_id))
        conn.commit()
    return True, {k: _utc(v) for k, v in zip(DOCUMENT, row)}
