"""alpha's public status (fixture-partners, v0.5 chunk 11a; capture W2 item 6):
the partner's state is read at each request, under the hostname asked, and
its misbehaviour applied: delay_ms, the slow answers its key switches on.
The state is read first and the session returned to the pool before the
delay, so a slow partner holds one of the server's worker threads per
request in flight, never a database session, and never another partner's."""

import time

from fastapi import APIRouter, Request

from db import alpha_status

router = APIRouter()


@router.get("/status")
def status(request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    state = alpha_status.state(hostname)
    delay_ms = int(state.get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    return {"partner": "alpha", "hostname": hostname, "delay_ms": delay_ms}
