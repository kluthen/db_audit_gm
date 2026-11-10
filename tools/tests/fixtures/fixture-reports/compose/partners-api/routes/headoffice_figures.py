"""The head office's monthly figures endpoint (purpose 9's stub;
clinic-purposes.md 13; capture W4 items 0 and 5, W2-f): POST /figures under
the hostname head-office. A month's figures are acknowledged with a reference
(201), the same figures_key again answering the same reference and never a
second month; every call is numbered, and a number that is a multiple of
fail_one_in (50) answers 503, the standing one call in fifty. The body is
kept as first acknowledged. The state is read first and the session returned
before the delay (delay_ms), as every stub does. Imports FastAPI, Pydantic,
the standard library and db/ only."""

import time

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field

from db import headoffice_figures

router = APIRouter()


class Figures(BaseModel):
    """The key the head office files it under and the month; the rest of the
    body (the centre, the figures per section and measure) is kept as
    sent."""
    model_config = ConfigDict(extra="allow")
    figures_key: str = Field(pattern=r"^figures-[A-Za-z0-9-]+-[0-9]{4}-[0-9]{2}$")
    month: str = Field(pattern=r"^[0-9]{4}-[0-9]{2}$")


@router.post("/figures", status_code=201)
def figures(body: Figures, request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    state = headoffice_figures.state(hostname)
    delay_ms = int(state.get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    reference = headoffice_figures.take(body.model_dump(mode="json"), int(state.get("fail_one_in", "50")))
    if reference is None:
        raise HTTPException(status_code=503, detail="the head office's service is unavailable; try again")
    return {"figures_key": body.figures_key, "reference": reference}
