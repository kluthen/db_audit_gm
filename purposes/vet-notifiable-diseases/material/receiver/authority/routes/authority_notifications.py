"""The authority's notifications endpoint (purpose 5's stub; clinic-purposes.md
9; capture W4 items 0 and 4, W2-f): POST /notifications under the hostname
authority. A notification is accepted with a reference (201), the same
notification_key again answering the same reference and never a second
notification; every call is numbered, and a number that is a multiple of
fail_one_in (50) answers 503, the standing one call in fifty that gives the
retries and escalations their witness (D214's precedent). The body is kept as
first accepted (the purpose's ND3 reads what was sent). The state is read
first and the session returned before the delay (delay_ms), as every stub
does. Imports FastAPI, Pydantic, the standard library and db/ only."""

import time

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field

from db import authority_notifications

router = APIRouter()


class Notification(BaseModel):
    """The key the authority files it under; the rest of the body (the
    disease, the species, the holding or keeper, the notifier, the date) is
    kept as sent."""
    model_config = ConfigDict(extra="allow")
    notification_key: str = Field(pattern=r"^(lab|vet)-[0-9]+$")


@router.post("/notifications", status_code=201)
def notify(notification: Notification, request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    state = authority_notifications.state(hostname)
    delay_ms = int(state.get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    reference = authority_notifications.take(notification.model_dump(mode="json"),
                                             int(state.get("fail_one_in", "50")))
    if reference is None:
        raise HTTPException(status_code=503, detail="the authority's service is unavailable; try again")
    return {"notification_key": notification.notification_key, "reference": reference}
