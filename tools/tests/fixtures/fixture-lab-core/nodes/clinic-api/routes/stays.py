# from vet-core@regional-franchise: domains/vet-core/producers/api/clinic-api/routes/stays.py
"""clinic-api's stays endpoint (vet-core; capture W2 item 4; D319): the
census, the current stays with their animal's name and species, read by
vet-machinery's mach.census. Imports FastAPI, the standard library and db/
only."""

from fastapi import APIRouter, HTTPException

from db import stays

router = APIRouter()


@router.get("/stays")
def census(current: str | None = None):
    if current != "true":
        raise HTTPException(status_code=422, detail="current must be true")
    return stays.current()
