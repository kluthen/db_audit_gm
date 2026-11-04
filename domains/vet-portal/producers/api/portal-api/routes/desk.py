"""portal-api's desk endpoint (vet-portal; capture W3 item 5): POST
/desk/consents {owner_id, purpose, granted}, the reception desk recording an
owner's reminders' consent, behind the desk's credential portal_desk (the
brick answers 401 to any other caller); 201 {recorded: true}, 422 when the
function refuses it (another purpose, no open account for that owner).
Imports FastAPI, Pydantic, the standard library and db/ only."""

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from db import desk

router = APIRouter()


class DeskConsent(BaseModel):
    owner_id: int
    purpose: str = Field(min_length=1, max_length=40)
    granted: bool


@router.post("/desk/consents")
def post_consent(body: DeskConsent):
    if not desk.consent(body.owner_id, body.purpose, body.granted):
        raise HTTPException(status_code=422, detail="not recorded: no open account for that owner, or not a "
                                                    "purpose the desk records")
    return JSONResponse(status_code=201, content={"recorded": True})
