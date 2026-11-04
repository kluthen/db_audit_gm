"""The coldstore_shipments endpoint's contract (tools/tests, v0.5 chunk 6). Never served."""
from fastapi import APIRouter

from db.coldstore_shipments import answer

router = APIRouter()


@router.get("/coldstore_shipments")
def get():
    return answer()
