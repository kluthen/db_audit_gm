# from vet-machinery@regional-franchise: domains/vet-machinery/producers/equipment/scripts/lookup.py
"""vet-machinery's script jobs on the core's lookup API (vet-machinery-domain.md,
"Fixed-time operations"; D266, D303, D377), run by equipment's scheduler as
`<function>(conns, options, log)`: `conns` maps the job's connection names to
an open psycopg connection (autocommit off) or the scheduler's HTTP client
(`get`, `post`). Each commits what it writes and returns the rows written.
Imports the standard library only: the database work is SQL, the hashes
hashint8extended's, as the load's."""

import json


def _get(api, path, params=None):
    """The answer's JSON for a 2xx, None for a 404; RuntimeError otherwise (the
    run ends in error, counted by the scheduler)."""
    answer = api.get(path, params)
    if answer.status == 404:
        return None
    if not answer.ok:
        raise RuntimeError(f"GET {path}: {answer.status} {answer.text[:200]}")
    return answer.json()


def identity(conns, options, log):
    """mach.identity: each new worklist entry lacking its identity, oldest
    first (at most options' batch): the animal and its current owner read from
    clinic-api, written in DICOM's form (patient_name "family^name",
    Responsible Person the owner's name; a name only, never a contact)."""
    db, api = conns["pacs"], conns["clinic"]
    batch = int(options.get("batch", 20))
    with db.cursor() as cur:
        cur.execute("SELECT id, animal_id FROM mach_worklist WHERE state = 'new' AND identity_at IS NULL "
                    "ORDER BY created_at, id LIMIT %s FOR UPDATE SKIP LOCKED", (batch,))
        entries = cur.fetchall()
        written = 0
        for wid, animal_id in entries:
            animal = _get(api, f"/animals/{animal_id}")
            owner = _get(api, f"/animals/{animal_id}/owner") if animal is not None else None
            if animal is None or owner is None:
                log(f"entry {wid}: animal {animal_id} not found by the lookup API")
                continue
            name = owner.get("name") or ""
            family = name.split()[-1] if owner.get("kind") == "person" and name.split() else name
            cur.execute(
                "UPDATE mach_worklist SET patient_id = %s, patient_name = %s, species = %s, breed = %s, sex = %s, "
                "born_on = %s, microchip = %s, ueln = %s, ear_tag = %s, responsible_person = %s, "
                "identity_at = now() WHERE id = %s",
                (f"A-{animal_id}", f"{family}^{animal.get('name')}", animal.get("species"), animal.get("breed"),
                 animal.get("sex"), animal.get("born_on"), animal.get("microchip"), animal.get("ueln"),
                 animal.get("ear_tag"), name, wid))
            written += cur.rowcount
    db.commit()
    return written


CENSUS_SQL = """
WITH seen AS (
  SELECT * FROM jsonb_to_recordset(%(stays)s::jsonb)
           AS x (stay_id integer, animal_id integer, section_id integer, admitted_at timestamptz,
                 name text, species text)),
up AS (
  INSERT INTO mach_census (stay_id, animal_id, animal_name, species, section_id, admitted_at, seen_at)
  SELECT stay_id, animal_id, name, species, section_id, admitted_at, now() FROM seen
  ON CONFLICT (stay_id) DO UPDATE SET seen_at = now(), left_at = NULL
  RETURNING stay_id, (xmax = 0) AS inserted),
gone AS (
  UPDATE mach_census SET left_at = now()
   WHERE left_at IS NULL AND stay_id NOT IN (SELECT stay_id FROM seen)
  RETURNING stay_id)
SELECT (SELECT count(*) FROM up), (SELECT count(*) FROM gone),
       (SELECT coalesce(array_agg(stay_id), '{}') FROM gone),
       (SELECT coalesce(array_agg(stay_id), '{}') FROM up WHERE inserted)
"""

# A session of a stay that left ended by the census; an intensive-care
# session past its step-down (24 to 72 hours after admission, by a hash of
# the stay) ended by staff.
END_SQL = """
UPDATE mach_sessions AS x SET ended_at = now(),
       ended_by = CASE WHEN x.stay_id = ANY(%(gone)s) THEN 'census' ELSE 'staff' END
  FROM mach_census AS c
 WHERE c.stay_id = x.stay_id AND x.ended_at IS NULL
   AND (x.stay_id = ANY(%(gone)s)
        OR (x.kind = 'icu' AND now() >= c.admitted_at
            + (24 + 48 * ((hashint8extended(c.stay_id, 542) & 2147483647) / 2147483648.0)) * interval '1 hour'))
"""

# An intensive-care session for each new stay the hash picks (one domestic
# stay in two, one horse stay in four, no farm stay), on the first free
# monitor of its group (21-26, 27-28); none when no monitor is free.
OPEN_SQL = """
INSERT INTO mach_sessions (machine_id, kind, stay_id, animal_id, animal_name, species, weight_kg, started_at,
                           started_by)
SELECT m.id, 'icu', c.stay_id, c.animal_id, c.animal_name, c.species,
       round((CASE c.species WHEN 'dog' THEN 4 + 41 * w.u WHEN 'cat' THEN 3 + 4 * w.u WHEN 'rabbit' THEN 1 + 2 * w.u
                             WHEN 'ferret' THEN 0.6 + 1.4 * w.u ELSE 350 + 300 * w.u END)::numeric, 1),
       now(), CASE c.section_id WHEN 3 THEN 43 + c.stay_id %% 9 ELSE 29 + c.stay_id %% 8 END
  FROM mach_census AS c,
       LATERAL (SELECT (hashint8extended(c.animal_id, 547) & 2147483647) / 2147483648.0 AS u) AS w,
       LATERAL (SELECT i AS id FROM generate_series(CASE c.section_id WHEN 3 THEN 21 ELSE 27 END,
                                                    CASE c.section_id WHEN 3 THEN 26 ELSE 28 END) AS i
                 WHERE NOT EXISTS (SELECT 1 FROM mach_sessions AS x WHERE x.machine_id = i AND x.ended_at IS NULL)
                 ORDER BY i LIMIT 1) AS m
 WHERE c.stay_id = %(stay)s AND c.section_id IN (1, 3)
   AND (hashint8extended(c.stay_id, 541) & 2147483647) / 2147483648.0
       < CASE c.section_id WHEN 3 THEN 0.5 ELSE 0.25 END
"""


def census(conns, options, log):
    """mach.census: GET /stays?current=true on clinic-api (O197); mach_census
    upserted, the stays no longer current marked left; the sessions of the
    stays that left ended (census), those past their step-down ended (staff);
    an intensive-care session opened for each new stay the hash picks."""
    db, api = conns["vitals"], conns["clinic"]
    stays = _get(api, "/stays", {"current": "true"})
    if stays is None:
        raise RuntimeError("GET /stays?current=true: 404")
    with db.cursor() as cur:
        cur.execute(CENSUS_SQL, {"stays": json.dumps(stays)})
        upserted, left, gone, new = cur.fetchone()
        cur.execute(END_SQL, {"gone": list(gone)})
        ended = cur.rowcount
        opened = 0
        for stay in sorted(new):
            cur.execute(OPEN_SQL, {"stay": stay})
            opened += cur.rowcount
    db.commit()
    log(f"census: {len(stays)} current, {len(new)} new, {left} left; sessions {opened} opened, {ended} ended")
    return upserted + left + ended + opened
