"""clinic-api's stays endpoint, its database side (vet-core; capture W2 item
4): as vet_lookup, which reads the stays' id, animal, section, admission and
discharge, and the animals' name and species. Times ISO 8601 UTC with Z."""

import gm_api

SESSION = {"statement_timeout": "5s"}


def current():
    with gm_api.connection("clinic", session=SESSION) as conn:
        rows = conn.execute(
            "SELECT s.id, s.animal_id, s.section_id, "
            "to_char(s.admitted_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
            "a.name, a.species "
            "FROM stays s JOIN animals a ON a.id = s.animal_id "
            "WHERE s.discharged_at IS NULL ORDER BY s.id").fetchall()
    return [{"stay_id": r[0], "animal_id": r[1], "section_id": r[2], "admitted_at": r[3],
             "name": r[4], "species": r[5]} for r in rows]
