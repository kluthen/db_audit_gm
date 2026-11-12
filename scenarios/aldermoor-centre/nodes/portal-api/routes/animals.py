# from vet-portal@regional-franchise: domains/vet-portal/producers/api/portal-api/routes/animals.py
"""portal-api's animals endpoint (vet-portal; capture W3 item 5): by the
session cookie portal_session (401 without an open session), GET /animals the
asker's animals as the policies show them, [{animal_id, name, species, sex,
born_on, status}] by animal_id; GET /animals/{id}/documents that animal's
documents, newest first, 50 at most, [{document_id, kind, title, version,
record_at, published_at, superseded_at}], 404 for an animal the asker does
not see. Imports FastAPI, the standard library and db/ only."""

from fastapi import APIRouter, Cookie, HTTPException

from db import animals

router = APIRouter()


@router.get("/animals")
def list_animals(portal_session: str | None = Cookie(default=None)):
    rows = animals.mine(portal_session)
    if rows is None:
        raise HTTPException(status_code=401, detail="no open session")
    return rows


@router.get("/animals/{animal_id}/documents")
def list_documents(animal_id: int, portal_session: str | None = Cookie(default=None)):
    found, rows = animals.documents(portal_session, animal_id)
    if found is None:
        raise HTTPException(status_code=401, detail="no open session")
    if not found:
        raise HTTPException(status_code=404, detail="not found")
    return rows
