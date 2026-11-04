"""portal-api's documents endpoint (vet-portal; capture W3 item 5): GET
/documents/{id}, by the session cookie portal_session (401 without an open
session), one document the asker sees, its view recorded in the same
transaction; 404 for a document the asker does not see, another owner's
among them. {document_id, animal_id, herd_id, kind, source_ref, version,
record_at, gated_at, published_at, title, vet_name, body, supersedes_id,
superseded_at}. Imports FastAPI, the standard library and db/ only."""

from fastapi import APIRouter, Cookie, HTTPException

from db import documents

router = APIRouter()


@router.get("/documents/{document_id}")
def get_document(document_id: int, portal_session: str | None = Cookie(default=None)):
    found, row = documents.open_one(portal_session, document_id)
    if found is None:
        raise HTTPException(status_code=401, detail="no open session")
    if not found:
        raise HTTPException(status_code=404, detail="not found")
    return row
