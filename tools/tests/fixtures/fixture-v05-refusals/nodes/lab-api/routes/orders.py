"""The orders endpoint's contract (tools/tests, v0.5 chunk 6). Never served."""
from fastapi import APIRouter

from db.orders import answer

router = APIRouter()


@router.get("/orders")
def get():
    return answer()
