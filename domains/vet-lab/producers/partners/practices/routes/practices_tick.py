"""The practices' tick (vet-lab's practices stub; capture W2 item 6, "Ticks",
W3 item 1): the back end calls it under the hostname practices with the
credential partners_backend (any other caller: 401), on the practices' hours.
Each tick posts one practice's new order to lab-api's POST /orders (as
lab_practices) and keeps the accession; an order whose post failed is posted
again first, under the same client_ref (never a new one: T41). Never slowed:
a partner's misbehaviour is what its public routes answer."""

from fastapi import APIRouter

from db import practices_tick

router = APIRouter()


@router.post("/tick")
def tick():
    return {"partner": "practices", **practices_tick.tick()}
