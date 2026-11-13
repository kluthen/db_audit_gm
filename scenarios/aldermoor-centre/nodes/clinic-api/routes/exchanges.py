# from scenario: compose/clinic-api/routes/exchanges.py
"""clinic-api's exchanges endpoint, purpose 4's (vet-centre-exchanges;
clinic-purposes.md 8; capture W4 items 0 and 4): the other centres' side of
the exchanges, only answering (D270), behind the centres' credential
clinic_centres.

- POST /exchanges: a centre's request, filed as an inbound exchange
  `received` (201); the same exchange_key again answers 200 and files nothing.
- POST /exchanges/{key}/answer: a centre's answer on one of the clinic's
  requests, accepted (with its date) or declined, recorded on that exchange
  only; again, 200 and nothing changed; a key not the clinic's request 404.
- POST /exchanges/{key}/report: a centre's report on an accepted examination
  the clinic asked for; again 200; 404 for an unknown key, 409 when the
  exchange is not an accepted examination.

Imports FastAPI, Pydantic, the standard library and db/ only."""

from datetime import date, datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from db import exchanges

router = APIRouter()


class Patient(BaseModel):
    ref: int
    species: str = Field(min_length=1, max_length=40)
    age_years: int | None = None


class Request(BaseModel):
    exchange_key: UUID
    site: str = Field(pattern=r"^[A-Z][A-Z0-9-]{1,15}$")
    kind: str = Field(pattern="^(transfer|examination)$")
    reason: str = Field(min_length=1, max_length=200)
    requested_at: str
    patient: Patient


class Answer(BaseModel):
    answer: str = Field(pattern="^(accepted|declined)$")
    accepted_for: date | None = None


class Report(BaseModel):
    report: str = Field(min_length=1, max_length=4000)


@router.post("/exchanges")
def take(request: Request):
    try:
        requested_at = datetime.fromisoformat(request.requested_at.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(status_code=422, detail="requested_at is not an ISO 8601 time")
    if requested_at.tzinfo is None:
        raise HTTPException(status_code=422, detail="requested_at needs its offset (Z or +hh:mm)")
    try:
        created = exchanges.take(str(request.exchange_key), request.site, request.kind, request.reason,
                                 requested_at, request.patient.model_dump())
    except exchanges.UnknownSite:
        raise HTTPException(status_code=422, detail=f"site {request.site} is not another centre")
    return JSONResponse(status_code=201 if created else 200,
                        content={"exchange_key": str(request.exchange_key), "status": "received"})


@router.post("/exchanges/{exchange_key}/answer")
def answer(exchange_key: UUID, body: Answer):
    if body.answer == "accepted" and body.accepted_for is None:
        raise HTTPException(status_code=422, detail="an accepted exchange needs its accepted_for")
    state = exchanges.answer(str(exchange_key), body.answer, body.accepted_for)
    if state is None:
        raise HTTPException(status_code=404, detail="not found")
    return {"exchange_key": str(exchange_key), "status": state}


@router.post("/exchanges/{exchange_key}/report")
def report(exchange_key: UUID, body: Report):
    state = exchanges.report(str(exchange_key), body.report)
    if state is None:
        raise HTTPException(status_code=404, detail="not found")
    if state != "reported":
        raise HTTPException(status_code=409, detail=f"the exchange is {state}, not an accepted examination")
    return {"exchange_key": str(exchange_key), "status": state}
