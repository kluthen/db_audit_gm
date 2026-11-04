"""Cold storage's manifests, GET /manifests (v0.5 master spec 10.4;
cold-storage.md 3; capture W2 item 6): public, read by the players through
the bastion and by the GM's checks. Filters, each optional: type, source,
and from and to (dates, YYYY-MM-DD, inclusive), against the manifest's
range: a manifest is listed when its range meets [from, to]. A JSON list,
in the order the shipments were received."""

import datetime
import time
from typing import Optional

from fastapi import APIRouter, Query, Request

from db import coldstore_manifests

router = APIRouter()


@router.get("/manifests")
def manifests(request: Request,
              type: Optional[str] = Query(None, max_length=32),
              source: Optional[str] = Query(None, max_length=63),
              date_from: Optional[datetime.date] = Query(None, alias="from"),
              date_to: Optional[datetime.date] = Query(None, alias="to")):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    delay_ms = int(coldstore_manifests.state(hostname).get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    return coldstore_manifests.manifests(type, source, date_from, date_to)
