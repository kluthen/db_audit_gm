# from vet-lab@regional-franchise: domains/vet-lab/producers/api/lab-api/routes/orders.py
"""lab-api's orders endpoint (vet-lab; capture W3 item 1): an order posted,
idempotent on its account and client_ref; an order's state by its accession;
the released results feed of one account since a time. JSON keys are the
columns' names, times ISO 8601 UTC with Z. Imports FastAPI, Pydantic, the
standard library and db/ only."""

from datetime import datetime

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from db import orders

router = APIRouter()


class Test(BaseModel):
    code: str = Field(min_length=1)
    request_id: int | None = None


class Order(BaseModel):
    """The order: its account, its own reference, its priority and its tests;
    the rest lab_orders' descriptive columns, each optional (the centre's
    animal, consultation and requesting vet; a practice's patient)."""
    account: int
    client_ref: str = Field(min_length=1, max_length=64)
    priority: str = Field(pattern="^(routine|urgent)$")
    tests: list[Test] = Field(min_length=1, max_length=20)
    animal_id: int | None = None
    consultation_id: int | None = None
    requested_by: int | None = None
    patient_ref: str | None = None
    client_surname: str | None = None
    species: str | None = None
    sex: str | None = None
    born_on: str | None = Field(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    microchip: str | None = None
    ueln: str | None = None
    ear_tag: str | None = None
    clinical_notes: str | None = None
    withdrawal_ends_on: str | None = Field(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$")


@router.post("/orders")
def post_order(order: Order):
    """201 and the accession for a new (account, client_ref); the same pair
    again 200 and the same body, nothing written."""
    try:
        created, body = orders.post(order.model_dump())
    except orders.Refused as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    return JSONResponse(status_code=201 if created else 200, content=body)


@router.get("/orders")
def feed(account: int | None = None, released_since: str | None = None):
    """The account's order tests released, not performed or cancelled at or
    after the time, in that time's order then order_test_id."""
    if account is None or released_since is None:
        raise HTTPException(status_code=422, detail="account and released_since are both required")
    try:
        since = datetime.fromisoformat(released_since)
    except ValueError:
        raise HTTPException(status_code=422, detail="released_since is not an ISO 8601 time")
    if since.tzinfo is None:
        raise HTTPException(status_code=422, detail="released_since needs its offset (Z or +hh:mm)")
    return orders.feed(account, since)


@router.get("/orders/{accession}")
def get_order(accession: int):
    """The order, its state (ordered, received, completed, cancelled) and its
    tests, each with its status and its results in force."""
    row = orders.by_accession(accession)
    if row is None:
        raise HTTPException(status_code=404, detail="not found")
    return row
