# from vet-lab@regional-franchise: domains/vet-lab/producers/lis/scripts/lab_identity.py
"""The centre's patients' identity from the core (vet-lab's lab.identity;
vet-lab-domain.md, "Rates at intensity 1.0", fixed-time operations; D266,
D267, D303): every minute, the lab's information system reads from the
core's lookup API (clinic-api) the animals of the centre's new orders and
stores what it answers on the order.

Called by the scheduler as run(conns, options, log): `conns["lab"]` the lab's
database as lab_app (psycopg 3, autocommit off), `conns["clinic_api"]` the
HTTP client to clinic-api (credential clinic_lookup).

1. On lab: the centre's orders (account 1) of the last two days with an
   animal and no species yet, oldest first, at most options["batch"]; the
   read's transaction ended before any call, so no transaction stays open
   across the HTTP calls.
2. For each, `GET /animals/{id}` and `GET /animals/{id}/owner`: an answer
   that is not 2xx (a 404 among them) is logged and the order left as it
   is, the next run trying again while it is recent; no answer at all
   (HttpError: a timeout, the API down) is logged and ends the run.
3. The order's species, sex, date of birth, natural identifiers (microchip,
   UELN, ear tag) as the core holds them (its mistyped chips included,
   D278) and the owner's surname (a person's family name, the name's last
   word; a stable's, a holding's or a clinic's whole name) written in one
   UPDATE, committed per order. lab_orders has no food-chain column, so
   the animal's food_chain is not stored.

Logs order ids and statuses only, never an identifier or a name (rule 11).
Returns the number of orders written. Imports nothing but the standard
library.
"""

PENDING = (
    "SELECT id, animal_id FROM lab_orders"
    " WHERE account_id = 1 AND animal_id IS NOT NULL AND species IS NULL"
    " AND ordered_at > now() - interval '2 days'"
    " ORDER BY ordered_at, id LIMIT %s"
)

WRITE = (
    "UPDATE lab_orders"
    " SET species = %s, sex = %s, born_on = %s::date, microchip = %s, ueln = %s, ear_tag = %s,"
    " client_surname = %s"
    " WHERE id = %s AND species IS NULL"
)


def _surname(owner):
    """The owner's surname as the lab stores it: a person's last word, any
    other kind's whole name."""
    name = (owner.get("name") or "").strip()
    if not name:
        return None
    if owner.get("kind") == "person":
        return name.split()[-1]
    return name


def run(conns, options, log):
    db = conns["lab"]
    api = conns["clinic_api"]
    batch = int(options.get("batch", 20))

    with db.cursor() as cur:
        cur.execute(PENDING, (batch,))
        pending = cur.fetchall()
    db.commit()

    written = 0
    for order_id, animal_id in pending:
        try:
            animal = api.get(f"/animals/{animal_id}")
            if not 200 <= animal.status < 300:
                log(f"order={order_id} animal status={animal.status}: left")
                continue
            owner = api.get(f"/animals/{animal_id}/owner")
            if not 200 <= owner.status < 300:
                log(f"order={order_id} owner status={owner.status}: left")
                continue
        except api.HttpError as exc:
            log(f"order={order_id} clinic-api {exc.status}: {exc.message}; run stopped")
            break
        a = animal.json() or {}
        with db.cursor() as cur:
            cur.execute(WRITE, (a.get("species"), a.get("sex"), a.get("born_on"), a.get("microchip"),
                                a.get("ueln"), a.get("ear_tag"), _surname(owner.json() or {}), order_id))
            written += cur.rowcount
        db.commit()
    return written
