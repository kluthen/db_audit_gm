"""The owners_home endpoint's contract (tools/tests, v0.5 chunk 6). Never served."""
from fastapi import APIRouter

from db.owners_home import answer

router = APIRouter()


@router.get("/owners_home")
def get():
    return answer()
