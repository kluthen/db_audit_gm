"""alpha's tick (fixture-partners, v0.5 chunk 11a; capture W2 item 6, "Ticks"):
the back end calls it under the partner's hostname with the credential
partners_backend (any other caller: 401); the partner acts, here recording
the tick in its state (last_tick). Never slowed: a partner's misbehaviour is
what its public routes answer."""

from fastapi import APIRouter, Request

from db import alpha_tick

router = APIRouter()


@router.post("/tick")
def tick(request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    return {"partner": "alpha", "hostname": hostname, "last_tick": alpha_tick.tick(hostname)}
