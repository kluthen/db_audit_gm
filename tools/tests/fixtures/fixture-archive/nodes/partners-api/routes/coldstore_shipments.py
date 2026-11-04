"""Cold storage's upload, POST /shipments (v0.5 master spec 10.4, 11.2;
cold-storage.md 3; capture W1 item 6, W2 item 6, W2-f): one shipment, its
header in Shipment-* headers, its payload the body (a WAL segment's or a
base backup's bytes, application/octet-stream; a data type's rows,
NDJSON). The payload is counted and discarded, never kept: the body is
streamed (a base backup is the whole instance) and only its size and, for a
data type, its non-empty lines are counted. A manifest is written (the same
shipment id again replaces it) and the receipt answered, 201:
{shipment_id, type, rows_declared, rows_received, size, received_at}.

Behind the credential cold_storage (the brick's dispatch: 401 without it).
A header missing or malformed: 400, naming it. Its state, read at each
request: delay_ms before the answer; uploads refuse, 503 (an outage)."""

import datetime
import re
import time

from fastapi import APIRouter, Depends, HTTPException, Request

from db import coldstore_shipments

router = APIRouter()

ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
TYPE_RE = re.compile(r"[a-z][a-z0-9-]{0,31}")
SOURCE_RE = re.compile(r"[a-z][a-z0-9-]{0,62}")
WHOLE_TYPES = ("wal", "basebackup")            # one row a shipment, whatever its bytes


async def received(request: Request):
    """Streams the body, keeping nothing: (bytes, non-empty lines). Async so
    that reading a large body never holds a worker thread; the route itself
    is plain def, as the brick requires."""
    count_lines = request.headers.get("shipment-type", "") not in WHOLE_TYPES
    size, lines, open_line = 0, 0, False
    async for chunk in request.stream():
        if not chunk:
            continue
        size += len(chunk)
        if count_lines:
            parts = chunk.split(b"\n")
            for i, part in enumerate(parts):
                if part.strip():
                    open_line = True
                if i < len(parts) - 1:
                    lines += open_line
                    open_line = False
    return size, lines + open_line


def _header(request, name, pattern=None):
    value = request.headers.get(name, "").strip()
    if not value or (pattern is not None and not pattern.fullmatch(value)):
        raise HTTPException(400, f"header {name}: missing or malformed")
    return value


def _date(request, name):
    try:
        return datetime.date.fromisoformat(_header(request, name, re.compile(r"\d{4}-\d{2}-\d{2}")))
    except ValueError:
        raise HTTPException(400, f"header {name}: not a date (YYYY-MM-DD)") from None


@router.post("/shipments", status_code=201)
def shipments(request: Request, body=Depends(received)):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    shipment_id = _header(request, "Shipment-Id", ID_RE)
    kind = _header(request, "Shipment-Type", TYPE_RE)
    source = _header(request, "Shipment-Source", SOURCE_RE)
    rows = _header(request, "Shipment-Rows", re.compile(r"\d{1,15}"))
    date_from, date_to = _date(request, "Shipment-From"), _date(request, "Shipment-To")
    if date_from > date_to:
        raise HTTPException(400, "header Shipment-From: after Shipment-To")
    name = request.headers.get("shipment-name", "").strip() or shipment_id
    if not ID_RE.fullmatch(name):
        raise HTTPException(400, "header Shipment-Name: malformed")
    size, lines = body
    state = coldstore_shipments.state(hostname)
    delay_ms = int(state.get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    if state.get("uploads", "accept") != "accept":
        raise HTTPException(503, "service unavailable")
    rows_received = (1 if size else 0) if kind in WHOLE_TYPES else lines
    return coldstore_shipments.record(shipment_id, kind, source, name, int(rows), rows_received,
                                      size, date_from, date_to)
