# from vet-core@regional-franchise: domains/vet-core/producers/api/clinic-api/db/animals.py
"""clinic-api's animals endpoint, its database side (vet-core; capture W2
item 4): as vet_lookup, which reads animals without the death columns,
ownerships, and owners' id, kind and name. Times ISO 8601 UTC with Z."""

import gm_api

SESSION = {"statement_timeout": "5s"}

COLUMNS = ("id", "species", "breed", "sex", "born_on", "name", "food_chain", "herd_id",
           "microchip", "ueln", "passport_number", "ear_tag", "registered_at")
SELECT = ("SELECT id, species, breed, sex, to_char(born_on, 'YYYY-MM-DD'), name, food_chain, "
          "herd_id, microchip, ueln, passport_number, ear_tag, "
          "to_char(registered_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') "
          "FROM animals")
WHERE = {"microchip": " WHERE microchip = %s", "ueln": " WHERE ueln = %s",
         "ear_tag": " WHERE ear_tag = %s"}


def _animal(row):
    return dict(zip(COLUMNS, row))


def by_id(animal_id):
    with gm_api.connection("clinic", session=SESSION) as conn:
        row = conn.execute(SELECT + " WHERE id = %s", (animal_id,)).fetchone()
    return None if row is None else _animal(row)


def by_identifier(column, value):
    with gm_api.connection("clinic", session=SESSION) as conn:
        rows = conn.execute(SELECT + WHERE[column] + " ORDER BY id", (value,)).fetchall()
    return [_animal(r) for r in rows]


def current_owner(animal_id):
    with gm_api.connection("clinic", session=SESSION) as conn:
        row = conn.execute(
            "SELECT o.id, o.kind, o.name FROM ownerships w JOIN owners o ON o.id = w.owner_id "
            "WHERE w.animal_id = %s AND w.role = 'owner' AND w.until_at IS NULL",
            (animal_id,)).fetchone()
    return None if row is None else {"id": row[0], "kind": row[1], "name": row[2]}
