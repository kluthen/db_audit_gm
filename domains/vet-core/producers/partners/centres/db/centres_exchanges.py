"""The other centres' exchanges endpoint, its database side (vet-core's
centres stub): as the role centres, on partners. A request is filed once
under its exchange_key (a resend counted), its answer due within a working
day of its first arrival: two to eight office hours later (Monday to Friday
08:00-18:00 local, the customer's zone), a hash of the key, never random.
Every message is kept in centres.messages with the status answered."""

import hashlib
import json
from datetime import datetime, timedelta, timezone

import gm_api

OPEN, CLOSE = 8, 18                  # the centres' office hours, local


def u(key, salt):
    """A draw in [0, 1) from the exchange key, never random."""
    return int(hashlib.sha256(f"centres:{key}:{salt}".encode()).hexdigest()[:8], 16) / 2 ** 32


def office_after(start, hours, offset):
    """`start` (UTC) plus `hours` of office time (Monday to Friday 08:00-18:00
    in the zone UTC+offset), in UTC."""
    local = start + timedelta(hours=offset)
    left = timedelta(hours=hours)
    while True:
        day_open = local.replace(hour=OPEN, minute=0, second=0, microsecond=0)
        day_close = local.replace(hour=CLOSE, minute=0, second=0, microsecond=0)
        if local.weekday() >= 5 or local >= day_close:
            local = (local + timedelta(days=1)).replace(hour=OPEN, minute=0, second=0, microsecond=0)
            continue
        local = max(local, day_open)
        if local + left <= day_close:
            return local + left - timedelta(hours=offset)
        left -= day_close - local
        local = day_close


def state(hostname):
    with gm_api.connection("centres-db") as conn:
        rows = conn.execute("SELECT name, value FROM centres.state WHERE hostname = %s", (hostname,)).fetchall()
    return dict(rows)


def _message(conn, hostname, key, kind, status, body):
    conn.execute("INSERT INTO centres.messages (hostname, exchange_key, kind, status, body) "
                 "VALUES (%s, %s, %s, %s, %s::jsonb)", (hostname, key, kind, status, json.dumps(body)))


def refused(hostname, key, kind, status, body):
    with gm_api.connection("centres-db") as conn:
        _message(conn, hostname, key, kind, status, body)
        conn.commit()


def take(hostname, body):
    """-> the requests received under the key (1 the first time)."""
    key = body["exchange_key"]
    offset = int(state(hostname).get("utc_offset", "0"))
    animal = body.get("animal") if isinstance(body.get("animal"), dict) else {}
    site = body.get("site") if isinstance(body.get("site"), str) else ""
    due = office_after(datetime.now(timezone.utc), 2 + 6 * u(key, "answer"), offset)
    with gm_api.connection("centres-db") as conn:
        (requests,) = conn.execute(
            "INSERT INTO centres.exchanges (exchange_key, hostname, site_code, asked_by, kind, ref, animal_id, "
            "reason, requested_at, received_at, requests, due_at) "
            "VALUES (%s, %s, %s, 'customer', %s, %s, %s, %s, %s::timestamptz, now(), 1, %s) "
            "ON CONFLICT (exchange_key) DO UPDATE SET requests = centres.exchanges.requests + 1 "
            "RETURNING requests",
            (key, hostname, site[:16], body["kind"], body["ref"], animal.get("id"), body["reason"],
             body["requested_at"], due)).fetchone()
        _message(conn, hostname, key, "request", 201, body)
        conn.commit()
    return requests


def answer(hostname, key, body):
    """The clinic's answer on a request this centre made; False: not its own."""
    with gm_api.connection("centres-db") as conn:
        found = conn.execute(
            "UPDATE centres.exchanges SET answer = %s, accepted_for = %s, "
            "answered_at = coalesce(answered_at, now()) "
            "WHERE exchange_key = %s AND hostname = %s AND asked_by = 'centre' RETURNING 1",
            (body["answer"], body.get("accepted_for"), key, hostname)).fetchone()
        _message(conn, hostname, key, "answer", 200 if found else 404, body)
        conn.commit()
    return found is not None


def report(hostname, key, body):
    """The clinic's report on an examination this centre asked for; False:
    not its own."""
    with gm_api.connection("centres-db") as conn:
        found = conn.execute(
            "UPDATE centres.exchanges SET reported_at = coalesce(reported_at, now()) "
            "WHERE exchange_key = %s AND hostname = %s AND asked_by = 'centre' AND kind = 'examination' "
            "RETURNING 1", (key, hostname)).fetchone()
        _message(conn, hostname, key, "report", 200 if found else 404, body)
        conn.commit()
    return found is not None
