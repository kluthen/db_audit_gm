"""portal-api's accounts endpoint (vet-portal; capture W3 item 5): the calls
before anyone is known, each a SECURITY DEFINER function of portal's. POST
/accounts/activate {token, password, reminders} an invitation's link used:
200 {account_id}, 401 for a link unknown, used or expired; POST
/password-reset {email} 202 whatever the address (a reset message queued for
a known one, none for another, answered the same); POST
/password-reset/{token} {password} 200, 401 for a link unknown, used or
expired; POST /unsubscribe/{message_key} a reminder's link: the reminders
withdrawn, 200, 404 for another key. Imports FastAPI, Pydantic, the standard
library and db/ only."""

import uuid

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from db import accounts

router = APIRouter()


class Activation(BaseModel):
    token: str = Field(min_length=1, max_length=200)
    password: str = Field(min_length=8, max_length=200)
    reminders: bool = False


class ResetRequest(BaseModel):
    email: str = Field(min_length=1, max_length=320)


class NewPassword(BaseModel):
    password: str = Field(min_length=8, max_length=200)


@router.post("/accounts/activate")
def activate(body: Activation):
    account_id = accounts.activate(body.token, body.password, body.reminders)
    if account_id is None:
        raise HTTPException(status_code=401, detail="this link is unknown, used or expired")
    return {"account_id": account_id}


@router.post("/password-reset")
def request_reset(body: ResetRequest):
    accounts.request_reset(body.email)
    return JSONResponse(status_code=202,
                        content={"detail": "if the address is an account's, a reset link is on its way"})


@router.post("/password-reset/{token}")
def reset(token: str, body: NewPassword):
    if not accounts.reset(token, body.password):
        raise HTTPException(status_code=401, detail="this link is unknown, used or expired")
    return {"reset": True}


@router.post("/unsubscribe/{message_key}")
def unsubscribe(message_key: uuid.UUID):
    if not accounts.unsubscribe(str(message_key)):
        raise HTTPException(status_code=404, detail="not found")
    return {"unsubscribed": True}
