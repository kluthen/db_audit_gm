"""The external lab's tick (vet-lab's xlab stub; capture W2 item 6, "Ticks",
W3 item 1): the back end calls it under the lab's hostname with the
credential partners_backend (any other caller: 401), in the lab's hours. Each
send-out past its due time with no answer posted, or chased since its last
post, gets its result posted to lab-api's POST /send-outs/{send_key}/result
(as lab_xlab), the answer kept and posted again unchanged on a chase. Never
slowed: a partner's misbehaviour is what its public routes answer."""

from fastapi import APIRouter

from db import xlab_tick

router = APIRouter()


@router.post("/tick")
def tick():
    return {"partner": "xlab", **xlab_tick.tick()}
