# from vet-portal@regional-franchise: domains/vet-portal/producers/api/portal-api/routes/me.py
"""portal-api's me endpoint (vet-portal; capture W3 item 5): the asker's
account, by the session cookie portal_session (401 without an open session).
GET /me the account without its hashes, its channel and its consents (the
latest event of each purpose, animal and keeper); PUT /me/preferences
{notify_by} the channel changed; POST /me/consents {purpose, granted,
animal_id, keeper_id} a grant or a withdrawal, reminders or keeper-access for
an animal the asker owns now and a keeper (403 otherwise); POST /me/close the
account closed (portal_close) and the cookie cleared. Imports FastAPI,
Pydantic, the standard library and db/ only."""

from fastapi import APIRouter, Cookie, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from db import me

router = APIRouter()

COOKIE = "portal_session"


def _unauthorised():
    return HTTPException(status_code=401, detail="no open session")


class Preferences(BaseModel):
    notify_by: str = Field(pattern="^(email|sms|none)$")


class Consent(BaseModel):
    purpose: str = Field(pattern="^(reminders|keeper-access)$")
    granted: bool
    animal_id: int | None = None
    keeper_id: int | None = None


@router.get("/me")
def get_me(portal_session: str | None = Cookie(default=None)):
    account = me.get(portal_session)
    if account is None:
        raise _unauthorised()
    return account


@router.put("/me/preferences")
def put_preferences(body: Preferences, portal_session: str | None = Cookie(default=None)):
    account = me.preferences(portal_session, body.notify_by)
    if account is None:
        raise _unauthorised()
    return account


@router.post("/me/consents")
def post_consent(body: Consent, portal_session: str | None = Cookie(default=None)):
    keeper = body.purpose == "keeper-access"
    if keeper != (body.animal_id is not None and body.keeper_id is not None) or (
            not keeper and (body.animal_id is not None or body.keeper_id is not None)):
        raise HTTPException(status_code=422, detail="keeper-access names an animal and a keeper, "
                                                    "reminders neither")
    try:
        event = me.consent(portal_session, body.purpose, body.granted, body.animal_id, body.keeper_id)
    except me.Refused as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    if event is None:
        raise _unauthorised()
    return JSONResponse(status_code=201, content=event)


@router.post("/me/close")
def close(portal_session: str | None = Cookie(default=None)):
    if not me.close(portal_session):
        raise _unauthorised()
    answer = JSONResponse(status_code=200, content={"closed": True})
    answer.delete_cookie(COOKIE, path="/")
    return answer
