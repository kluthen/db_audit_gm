"""The xlab_results endpoint's contract (tools/tests, v0.5 chunk 6). Never served."""
from fastapi import APIRouter

from db.xlab_results import answer

router = APIRouter()


@router.get("/xlab_results")
def get():
    return answer()
