"""The other centres' tick and own requests (vet-core's centres stub; capture
W2 item 6, "Ticks", W4 item 4): the back end calls them under a centre's
hostname with the credential partners_backend (any other caller: 401).
POST /tick posts that centre's answers and reports falling due, and its own
requests clinic-api did not take, to clinic-api (as clinic_centres); POST
/request makes one new request of that centre's and posts it. Never slowed:
a partner's misbehaviour is what its public routes answer."""

from fastapi import APIRouter, Request

from db import centres_tick

router = APIRouter()


def _hostname(request):
    return request.headers.get("host", "").rsplit(":", 1)[0].lower()


@router.post("/tick")
def tick(request: Request):
    return {"partner": "centres", "hostname": _hostname(request), **centres_tick.tick(_hostname(request))}


@router.post("/request")
def new_request(request: Request):
    return {"partner": "centres", "hostname": _hostname(request), **centres_tick.request(_hostname(request))}
