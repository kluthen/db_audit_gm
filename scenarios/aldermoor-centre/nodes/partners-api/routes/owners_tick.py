# from vet-portal@regional-franchise: domains/vet-portal/producers/partners/owners/routes/owners_tick.py
"""The owners' tick (vet-portal's owners' traffic; capture W3 item 5; spec
D369): the back end calls it under the hostname owners with the credential
partners_backend (any other caller: 401), body {kind}: visit, activate,
reset, unsubscribe, keeper or close. Each tick one owner's doing on
portal-api, every call recorded in owners.visits. Never slowed: the owners
have no misbehaviour key."""

from fastapi import APIRouter
from pydantic import BaseModel, Field

from db import owners_tick

router = APIRouter()


class Tick(BaseModel):
    kind: str = Field(pattern="^(visit|activate|reset|unsubscribe|keeper|close)$")


@router.post("/tick")
def tick(body: Tick):
    return {"partner": "owners", "kind": body.kind, **owners_tick.tick(body.kind)}
