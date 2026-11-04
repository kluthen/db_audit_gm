"""The external lab's orders endpoint (vet-lab's xlab stub; capture W3 item 1,
W2-f): a send-out taken (POST /orders), answered accepted with the lab's own
accession, the same send_key again answering the same accession; a chase
(POST /orders/{send_key}/resend), its answer posted again by the next tick,
at once when resulted, else when due. What a send-out may carry is rule 11's:
the accession, the label, the test, species, sex and age, never an
identifier. The state is read first and the session returned before the
delay (delay_ms), as every stub does. Imports FastAPI, Pydantic, the standard
library and db/ only."""

import time
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from db import xlab_orders

router = APIRouter()


class SendOut(BaseModel):
    send_key: UUID
    accession: int                       # the centre lab's order
    label: str = Field(min_length=1)
    test_code: str = Field(pattern=r"^NL-[A-Z0-9]+$")
    species: str | None = None
    sex: str | None = None
    age: int | None = None               # whole years


def _delay(request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    delay_ms = int(xlab_orders.state(hostname).get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)


@router.post("/orders")
def take(send_out: SendOut, request: Request):
    _delay(request)
    accession, due_at = xlab_orders.take(send_out.model_dump())
    return {"send_key": str(send_out.send_key), "status": "accepted", "accession": accession,
            "due_at": due_at}


@router.post("/orders/{send_key}/resend")
def resend(send_key: UUID, request: Request):
    _delay(request)
    row = xlab_orders.resend(str(send_key))
    if row is None:
        raise HTTPException(status_code=404, detail="not found")
    return row
