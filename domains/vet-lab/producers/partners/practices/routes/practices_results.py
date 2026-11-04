"""The practices' results endpoint (vet-lab's practices stub; capture W3 item
1, W2-f): a delivery (interim, final or amended) posted by the centre's lab
to an account's callback, acknowledged once per delivery_key; a repeat is
acknowledged again and counted, never recorded twice. The state is read first
and the session returned before the delay (delay_ms), as every stub does.
Imports FastAPI, Pydantic, the standard library and db/ only."""

import time

from fastapi import APIRouter, Request
from pydantic import BaseModel, Field

from db import practices_results

router = APIRouter()


class Delivery(BaseModel):
    """The fields the stub keeps; the rest of the delivery (its tests and
    results) is read and not stored."""
    delivery_key: str = Field(min_length=1, max_length=64)
    account: int
    accession: int
    kind: str = Field(pattern="^(interim|final|amended)$")


@router.post("/results")
def deliver(delivery: Delivery, request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    delay_ms = int(practices_results.state(hostname).get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    repeats = practices_results.acknowledge(delivery.model_dump())
    return {"delivery_key": delivery.delivery_key, "acknowledged": True, "repeats": repeats}
