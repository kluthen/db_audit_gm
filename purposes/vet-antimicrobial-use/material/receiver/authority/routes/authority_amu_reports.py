"""The authority's yearly antimicrobial-use reports endpoint (purpose 8's
stub; clinic-purposes.md 12; capture W4 items 0 and 5, W2-f): POST
/amu-reports under the hostname authority. A report is acknowledged with a
reference (201), the same report_key again answering the same reference and
never a second report; every call is numbered on the counter purpose 5's
route shares, and a number that is a multiple of fail_one_in (50) answers
503, the standing one call in fifty. The body is kept as first acknowledged
(AM3 compares what was sent). The state is read first and the session
returned before the delay (delay_ms), as every stub does. Imports FastAPI,
Pydantic, the standard library and db/ only."""

import time

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field

from db import authority_amu_reports

router = APIRouter()


class AmuReport(BaseModel):
    """The key the authority files it under, the year and the species; the
    rest of the body (the centre, the lines per ATCvet code) is kept as
    sent."""
    model_config = ConfigDict(extra="allow")
    report_key: str = Field(pattern=r"^amu-[0-9]{4}-[a-z]+$")
    year: int
    species: str


@router.post("/amu-reports", status_code=201)
def amu_report(report: AmuReport, request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    state = authority_amu_reports.state(hostname)
    delay_ms = int(state.get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    reference = authority_amu_reports.take(report.model_dump(mode="json"), int(state.get("fail_one_in", "50")))
    if reference is None:
        raise HTTPException(status_code=503, detail="the authority's service is unavailable; try again")
    return {"report_key": report.report_key, "reference": reference}
