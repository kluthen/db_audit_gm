"""The reference lab's status (fixture-alias, v0.5 chunk 7)."""

from fastapi import APIRouter

from db import xlab_status

router = APIRouter()


@router.get("/status")
def status():
    return xlab_status.status()
