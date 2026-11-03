"""The lab's order API (stack test fixture of the api brick): the contract.
Imports FastAPI, Pydantic, the standard library and db/ only."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import orders

router = APIRouter()


class Order(BaseModel):
    id: int
    label: str


@router.get("/orders/{order_id}")
def get_order(order_id: int):
    row = orders.find(order_id)
    if row is None:
        raise HTTPException(status_code=404, detail="no such order")
    return row


@router.post("/orders", status_code=201)
def post_order(order: Order):
    return orders.add(order.id, order.label)


@router.get("/whoami")
def whoami(owner: str = "-"):
    return orders.whoami(owner)
