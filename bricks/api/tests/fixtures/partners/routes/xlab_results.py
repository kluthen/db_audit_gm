"""The external lab's result callback (stack test fixture of the api brick)."""

from fastapi import APIRouter

from db import xlab_results

router = APIRouter()


@router.post("/results/{order_id}")
def post_result(order_id: int):
    return xlab_results.fetch_and_record(order_id)
