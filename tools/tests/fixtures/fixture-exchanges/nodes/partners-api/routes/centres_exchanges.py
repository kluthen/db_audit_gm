# from vet-core@regional-franchise: domains/vet-core/producers/partners/centres/routes/centres_exchanges.py
"""The other centres' exchanges endpoint (vet-core's centres stub; capture W4
item 4, W2-f): under each centre's hostname, the clinic's request taken (POST
/exchanges), the same exchange_key again counted as a resend and never a
second exchange; the clinic's answer (POST /exchanges/{key}/answer) and
report (POST /exchanges/{key}/report) on a request this centre made, 404 for
a key this centre does not hold. Every message is kept as received, with the
status answered (the purpose's checks read what was sent). The state is read
first and the session returned before the delay (delay_ms), as every stub
does. Imports FastAPI, Pydantic, the standard library and db/ only."""

import time
from datetime import date
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field

from db import centres_exchanges

router = APIRouter()


class Exchange(BaseModel):
    """The fields the stub files the request under; the rest of the body
    (the animal, its record's summary, its owner's contact) is kept as sent."""
    model_config = ConfigDict(extra="allow")
    exchange_key: UUID
    ref: int                                     # the clinic's exchange id
    kind: str = Field(pattern="^(transfer|examination)$")
    reason: str = Field(min_length=1, max_length=200)
    requested_at: str


class Answer(BaseModel):
    model_config = ConfigDict(extra="allow")
    answer: str = Field(pattern="^(accepted|declined)$")
    accepted_for: date | None = None


class Report(BaseModel):
    model_config = ConfigDict(extra="allow")
    report: str = Field(min_length=1, max_length=4000)


def _hostname(request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    delay_ms = int(centres_exchanges.state(hostname).get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    return hostname


@router.post("/exchanges", status_code=201)
def take(exchange: Exchange, request: Request):
    hostname = _hostname(request)
    requests = centres_exchanges.take(hostname, exchange.model_dump(mode="json"))
    return {"exchange_key": str(exchange.exchange_key), "status": "received", "requests": requests}


@router.post("/exchanges/{exchange_key}/answer")
def answer(exchange_key: UUID, body: Answer, request: Request):
    hostname = _hostname(request)
    if body.answer == "accepted" and body.accepted_for is None:
        centres_exchanges.refused(hostname, str(exchange_key), "answer", 422, body.model_dump(mode="json"))
        raise HTTPException(status_code=422, detail="an accepted exchange needs its accepted_for")
    if not centres_exchanges.answer(hostname, str(exchange_key), body.model_dump(mode="json")):
        raise HTTPException(status_code=404, detail="not found")
    return {"exchange_key": str(exchange_key), "status": body.answer}


@router.post("/exchanges/{exchange_key}/report")
def report(exchange_key: UUID, body: Report, request: Request):
    hostname = _hostname(request)
    if not centres_exchanges.report(hostname, str(exchange_key), body.model_dump(mode="json")):
        raise HTTPException(status_code=404, detail="not found")
    return {"exchange_key": str(exchange_key), "status": "reported"}
