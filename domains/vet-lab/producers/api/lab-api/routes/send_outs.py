"""lab-api's send_outs endpoint (vet-lab; capture W3 item 1): the external
lab's answer to a send-out, matched on the lab's own send_key (never on the
external accession, T51), recorded once: the same key again answers the same
and writes nothing. Imports FastAPI, Pydantic, the standard library and db/
only."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from db import send_outs

router = APIRouter()

FLAGS = ("normal", "low", "high", "critical-low", "critical-high")


class Result(BaseModel):
    analyte: str = Field(min_length=1)
    numeric_value: float | None = None
    text_value: str | None = None
    unit: str | None = None
    flag: str | None = None


class Answer(BaseModel):
    accession: str | None = None          # the external lab's own, kept in its stub
    resulted_at: str
    results: list[Result] = Field(min_length=1, max_length=50)


@router.post("/send-outs/{send_key}/result")
def post_result(send_key: UUID, answer: Answer):
    try:
        resulted_at = datetime.fromisoformat(answer.resulted_at)
    except ValueError:
        raise HTTPException(status_code=422, detail="resulted_at is not an ISO 8601 time")
    if resulted_at.tzinfo is None:
        raise HTTPException(status_code=422, detail="resulted_at needs its offset (Z or +hh:mm)")
    for r in answer.results:
        if (r.numeric_value is None) == (r.text_value is None):
            raise HTTPException(status_code=422,
                                detail=f"{r.analyte}: exactly one of numeric_value and text_value")
        if r.flag is not None and r.flag not in FLAGS:
            raise HTTPException(status_code=422, detail=f"{r.analyte}: flag {r.flag!r} is not one of {FLAGS}")
    try:
        found = send_outs.record(str(send_key), resulted_at, [r.model_dump() for r in answer.results])
    except send_outs.Refused as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    if not found:
        raise HTTPException(status_code=404, detail="not found")
    return {"send_key": str(send_key), "status": "resulted"}
