"""The messaging service's messages endpoint (purpose 16's stub;
vet-portal-domain.md, "vet-portal-messages"; capture W4 items 0 and 6, W3
item 5, W2-f): POST /messages under the hostname messaging, behind the
customer's key messaging_customer. A message is accepted with the service's
id (202), the same message_key again answering the same id and never a
second message; every call is numbered, and a number that is a multiple of
fail_one_in (50) answers 503, the standing one call in fifty that gives the
retries their witness (D214's precedent). The message is kept as first
accepted (the owners' route reads its tokens and recipients). The state is
read first and the session returned before the delay (delay_ms), as every
stub does. Imports FastAPI, Pydantic, the standard library and db/ only."""

import time
import uuid

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from db import messaging_messages

router = APIRouter()


class Message(BaseModel):
    """What the sender hands over: its key, the channel and address, the
    template, its own account reference, the payload to render."""
    message_key: uuid.UUID
    channel: str = Field(pattern="^(email|sms)$")
    address: str = Field(min_length=1)
    template: str = Field(min_length=1)
    account_id: int | None = None
    payload: dict


@router.post("/messages", status_code=202)
def accept(message: Message, request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    state = messaging_messages.state(hostname)
    delay_ms = int(state.get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    provider_id = messaging_messages.take(message.model_dump(mode="json"), int(state.get("fail_one_in", "50")))
    if provider_id is None:
        raise HTTPException(status_code=503, detail="the messaging service is unavailable; try again")
    return {"message_key": str(message.message_key), "id": provider_id}
