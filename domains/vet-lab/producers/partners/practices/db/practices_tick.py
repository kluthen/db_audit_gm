"""The practices' tick, its database side (vet-lab's practices stub): as the
role practices, on partners; the orders posted through the connection
practices-lab. An order is a pure function of its number m (a hash of m,
never random), so a retry posts the same body under the same client_ref
<local YYMMDD>-<m>, m continuing the history's (docs/gm.md, "Part keys"):
account 2 + 120 u, one in twenty urgent, the species mix 42 % dogs, 28 %
cats, 15 % horses, 9 % cattle, 3 % sheep, 3 % goats, one to three tests (55,
30, 15 %) from the tests a practice of that species asks most, an urgent
order's in house of four hours or less. Each row is written before its post,
its accession once lab-api answers."""

import hashlib
from datetime import datetime, timedelta, timezone

import gm_api

RETRIES = 3
SURNAMES = ("Abbott", "Baker", "Carter", "Dupont", "Evans", "Fischer", "Garcia", "Hughes", "Ivanova", "Jansen",
            "Keller", "Laurent", "Martin", "Novak", "Olsen", "Peeters", "Quinn", "Rossi", "Schmidt", "Turner",
            "Urban", "Vogel", "Walsh", "Young", "Zimmer")
# The tests a practice asks most, by species group and priority (vet-lab's
# catalogue codes, each valid for the group).
TESTS = {
    ("domestic", "routine"): ("CBC", "CHEMSA", "PREA", "SENIOR", "UA", "SDMA", "TT4", "FFLOT", "FNA", "HISTO",
                              "CRP", "EARCY", "CULT", "FRUCT", "UPC", "PCRSA"),
    ("domestic", "urgent"): ("CBC", "PREA", "GLU", "CHEMSA", "UA"),
    ("horse", "routine"): ("CBC", "CHEMEQ", "SAA", "FEC", "STREP", "EACTH", "CK", "FIBR", "EIA"),
    ("horse", "urgent"): ("CBC", "SAA", "CK", "COLIC"),
    ("farm", "routine"): ("METRU", "BHB", "FEC", "MINRU", "CBC", "CU", "FFLOT", "HISTOP"),
    ("farm", "urgent"): ("CBC", "BHB", "GLU"),
}


def _u(m, salt):
    return int(hashlib.sha256(f"practices:{m}:{salt}".encode()).hexdigest()[:8], 16) / 2 ** 32


def order(m, posted_on):
    """Order m's body (posted_on its local date, for the client_ref)."""
    u4 = _u(m, 4)
    species = ("dog" if u4 < 0.42 else "cat" if u4 < 0.70 else "horse" if u4 < 0.85 else
               "cattle" if u4 < 0.94 else "sheep" if u4 < 0.97 else "goat")
    group = "domestic" if species in ("dog", "cat") else "horse" if species == "horse" else "farm"
    priority = "urgent" if _u(m, 3) < 0.05 else "routine"
    choices = list(TESTS[(group, priority)])
    n = 1 if _u(m, 13) < 0.55 else 2 if _u(m, 13) < 0.85 else 3
    tests = sorted(choices, key=lambda c: _u(m, "test:" + c))[:n]
    years = {"domestic": 1 + 13 * _u(m, 6), "horse": 2 + 18 * _u(m, 6)}.get(group, 1.5 + 6 * _u(m, 6))
    body = {
        "account": 2 + int(120 * _u(m, 2)),
        "client_ref": f"{posted_on:%y%m%d}-{m:05d}",
        "priority": priority,
        "tests": [{"code": c} for c in tests],
        "patient_ref": f"P{1 + int(99999 * _u(m, 7)):05d}",
        "client_surname": SURNAMES[int(25 * _u(m, 8))],
        "species": species,
        "sex": "female" if _u(m, 5) < (0.8 if group != "domestic" else 0.5) else "male",
        "born_on": (posted_on - timedelta(days=int(years * 365.25))).isoformat(),
    }
    if species in ("dog", "cat", "horse") and _u(m, 9) < 0.8:
        body["microchip"] = "941" + f"{int(1e12 * _u(m, 10)):012d}"
    if species == "horse" and _u(m, 9) < 0.6:
        body["ueln"] = "941002" + f"{int(1e9 * _u(m, 11)):09d}"
    if group == "farm":
        body["ear_tag"] = "XA" + f"{int(1e12 * _u(m, 12)):012d}"
    return body


def _post(lab, body):
    """-> the accession, or None when lab-api did not take it."""
    try:
        answer = lab.post("/orders", body)
    except gm_api.HttpError:
        return None
    return answer.json()["accession"] if answer.status in (200, 201) else None


def _accession(conn, body, accession):
    conn.execute("UPDATE practices.orders SET accession = %s WHERE account_id = %s AND client_ref = %s",
                 (accession, body["account"], body["client_ref"]))
    conn.commit()


def tick():
    """-> {posted, retried, failed}."""
    lab = gm_api.client("practices-lab")
    posted = retried = failed = 0
    with gm_api.connection("practices-db") as conn:
        offset = int(dict(conn.execute("SELECT name, value FROM practices.state WHERE hostname = 'practices'")
                          .fetchall()).get("utc_offset", "0"))
        pending = conn.execute(
            "SELECT client_ref FROM practices.orders WHERE accession IS NULL AND posted_at > now() - interval '1 day' "
            "AND client_ref ~ '^[0-9]{6}-[0-9]+$' ORDER BY posted_at LIMIT %s", (RETRIES,)).fetchall()
        conn.rollback()
        for (client_ref,) in pending:
            day, _, m = client_ref.partition("-")
            body = order(int(m), datetime.strptime(day, "%y%m%d").date())
            accession = _post(lab, body)
            if accession is None:
                failed += 1
            else:
                _accession(conn, body, accession)
                retried += 1
        conn.execute("SELECT pg_advisory_xact_lock(hashtext('practices.order'))")
        (m,) = conn.execute(
            "SELECT coalesce(max(split_part(client_ref, '-', 2)::integer), 0) + 1 FROM practices.orders "
            "WHERE client_ref ~ '^[0-9]{6}-[0-9]+$'").fetchone()
        body = order(m, (datetime.now(timezone.utc) + timedelta(hours=offset)).date())
        conn.execute(
            "INSERT INTO practices.orders (account_id, client_ref, priority, tests, posted_at) "
            "VALUES (%s, %s, %s, %s, now())",
            (body["account"], body["client_ref"], body["priority"], [t["code"] for t in body["tests"]]))
        conn.commit()
        accession = _post(lab, body)
        if accession is None:
            failed += 1
        else:
            _accession(conn, body, accession)
            posted += 1
    return {"posted": posted, "retried": retried, "failed": failed}
