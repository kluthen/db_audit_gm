# from vet-core@regional-franchise: domains/vet-core/producers/api/clinic-api/routes/animals.py
"""clinic-api's animals endpoint (vet-core; capture W2 item 4): an animal by
its id or by one natural identifier, and its current owner. Never a contact,
never a death. Imports FastAPI, the standard library and db/ only."""

from fastapi import APIRouter, HTTPException

from db import animals

router = APIRouter()

IDENTIFIERS = ("microchip", "ueln", "ear_tag")


@router.get("/animals")
def find(microchip: str | None = None, ueln: str | None = None, ear_tag: str | None = None):
    """The animals carrying one natural identifier: a list, [] when none, so
    an unknown identifier is told from an unknown route."""
    given = {k: v for k, v in (("microchip", microchip), ("ueln", ueln), ("ear_tag", ear_tag))
             if v is not None}
    if len(given) != 1:
        raise HTTPException(status_code=422,
                            detail="exactly one of microchip, ueln or ear_tag")
    (column, value), = given.items()
    return animals.by_identifier(column, value)


@router.get("/animals/{animal_id}")
def get_animal(animal_id: int):
    row = animals.by_id(animal_id)
    if row is None:
        raise HTTPException(status_code=404, detail="not found")
    return row


@router.get("/animals/{animal_id}/owner")
def get_owner(animal_id: int):
    """The current owner's id, kind and name."""
    row = animals.current_owner(animal_id)
    if row is None:
        raise HTTPException(status_code=404, detail="not found")
    return row
