-- vet-housing's history (v0.5 master spec 9.5; specs/versions/v0.5/
-- vet-housing-domain.md, "Deterministic key ranges", "The history before
-- T0", "Loading"; capture W3 items 0 and 3): last night's backup of the
-- wards, a year of placements, plans and care log ending at T0. Runs after
-- schema.sql, connected to the core's database, as postgres, with the core's
-- data/keys.sql streamed ahead of it in the same session (capture W2 item
-- 3). It never reads the core's tables (D249, D322): the stays, their
-- animals' species, their infectious alerts and the staff layout are the
-- core's functions pg_temp.core_stay, core_species, core_stay_alert and
-- core_staff (vet-core docs/gm.md, "Core keys"), called with this run's
-- load_epoch, so every placement follows the stay the core's load wrote.
-- Every other draw is a hash of an id (housing_u), never random().
-- docs/gm.md, "Core keys used" and "Loading", documents both.
--
-- It reads load-data's psql variables customer_utc_offset (hours, east
-- positive) and load_epoch (the run's start, UTC, to the minute: the load's
-- "now", T0, never now()). Every time in the database is UTC; the rounds and
-- the care day are the customer's local hours.
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_utc_offset is not set '
                            '(gmctl load-data passes -v customer_utc_offset=<hours>)'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable load_epoch is not set '
                            '(gmctl load-data passes -v load_epoch=<UTC, ISO 8601>)'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.core_stay(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'load.sql: the core''s key functions are missing (gmctl load-data streams '
                        'vet-core''s data/keys.sql ahead of this file, in the same session)';
    END IF;
END $$;

-- A uniform draw in [0, 1) from x and a salt (salts 1401 and up: housing's).
CREATE FUNCTION pg_temp.housing_u(x bigint, salt integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, salt) & 2147483647)::float8 / 2147483648 $$;
-- A UTC instant as the customer's local time, and back.
CREATE FUNCTION pg_temp.housing_local(t timestamptz, o integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t AT TIME ZONE 'UTC') + o * interval '1 hour' $$;
CREATE FUNCTION pg_temp.housing_utc(t timestamp, o integer) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - o * interval '1 hour') AT TIME ZONE 'UTC' $$;

-- The run's moment and offset.
CREATE TEMP TABLE h_env AS
SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
       (pg_temp.housing_local(:'load_epoch'::timestamptz, :customer_utc_offset))::date AS d;

-- --- The core's keys, computed (D322) -------------------------------------------------

-- The staff layout: nurses and carers by section (vet-core core_staff).
CREATE TEMP TABLE h_staff AS
SELECT s.section_id, k.kind, array_agg(k.n ORDER BY k.n) AS ids
  FROM (SELECT n, f.kind, f.section_id FROM generate_series(1, 85) AS n, pg_temp.core_staff(n) AS f) AS k
  JOIN (VALUES (1), (2), (3)) AS s (section_id) ON s.section_id = k.section_id
 WHERE k.kind IN ('nurse', 'carer')
 GROUP BY s.section_id, k.kind;

-- The year's stays (1-2 500, sparse): animal, section, admission, end; the
-- animal's species; the infectious alert, when the stay has one. A stay is
-- placed ten minutes after its admission (at T0 at the latest, so every
-- stay current at T0 is placed). One in nine of the horse and domestic
-- stays with no alert goes to intensive care first and moves out after one
-- or two days; a stay with an alert moves into isolation when it starts:
-- about one stay in five moved once.
CREATE TEMP TABLE h_stay AS
SELECT n, s.animal_id, s.section_id, s.admitted_at, s.discharged_at, s.outcome,
       pg_temp.core_species(s.animal_id) AS species, al.from_at AS alert_from, al.until_at AS alert_until,
       least(s.admitted_at + interval '10 minutes', v.e) AS place_at,
       (al.from_at IS NULL AND s.section_id IN (1, 3) AND pg_temp.housing_u(n, 1401) < 1.0 / 9) AS ic
  FROM h_env AS v, generate_series(1, 2500) AS n,
       pg_temp.core_stay(n, v.e, v.o) AS s
  LEFT JOIN LATERAL pg_temp.core_stay_alert(n, v.e, v.o) AS al ON true;
ALTER TABLE h_stay ADD PRIMARY KEY (n);

-- --- Units and displays (docs/gm.md, "The units") --------------------------------------

-- 1-22 horse (1-2 isolation, 3-4 intensive care, 5-22 boxes; 15 out of
-- service), 23-32 farm (23 isolation pen, 24-28 stalls, 29-32 pens), 33-64
-- domestic (33 isolation kennel, 34 isolation cage, 35-40 intensive-care
-- cages, 41-54 kennels, 55-64 cages; 50 out of service). The two out of
-- service since a week before T0.
CREATE TEMP TABLE h_unit AS
SELECT id,
       CASE WHEN id <= 22 THEN 1 WHEN id <= 32 THEN 2 ELSE 3 END AS section_id,
       CASE WHEN id <= 22 THEN 'H-' || lpad(id::text, 2, '0')
            WHEN id <= 32 THEN 'F-' || lpad((id - 22)::text, 2, '0')
            ELSE 'D-' || lpad((id - 32)::text, 2, '0') END AS code,
       CASE WHEN id <= 22 THEN 'box' WHEN id = 23 THEN 'pen' WHEN id <= 28 THEN 'stall' WHEN id <= 32 THEN 'pen'
            WHEN id = 33 THEN 'kennel' WHEN id <= 40 THEN 'cage' WHEN id <= 54 THEN 'kennel' ELSE 'cage' END
           AS kind,
       id IN (1, 2, 23, 33, 34) AS isolation,
       id IN (3, 4, 35, 36, 37, 38, 39, 40) AS intensive,
       CASE WHEN id IN (15, 50) THEN v.e - interval '7 days' ELSE 'infinity' END AS out_from,
       pg_temp.housing_utc((v.d - 400)::timestamp, v.o) AS free_at,     -- clean since installation
       NULL::integer AS occupant
  FROM h_env AS v, generate_series(1, 64) AS id;
ALTER TABLE h_unit ADD PRIMARY KEY (id);

INSERT INTO housing_units (id, section_id, code, kind, isolation, intensive, state, state_since_at)
SELECT id, section_id, code, kind, isolation, intensive, 'clean', free_at FROM h_unit ORDER BY id;

-- Display u on unit u, installed 400 days before T0; 65 and 66 replaced those
-- of units 7 and 41 half a year before T0, displays 7 and 41 removed.
INSERT INTO housing_displays (id, unit_id, serial, installed_on, removed_on)
SELECT id, CASE id WHEN 65 THEN 7 WHEN 66 THEN 41 ELSE id END,
       'WD7-' || lpad(((id * 7919 + 1301) % 100000)::text, 5, '0'),
       CASE WHEN id > 64 THEN v.d - 182 ELSE v.d - 400 END,
       CASE WHEN id IN (7, 41) THEN v.d - 182 END
  FROM h_env AS v, generate_series(1, 66) AS id ORDER BY 1;

-- --- Placements: the wards, event by event --------------------------------------------

-- Every stay placed ten minutes after admission in the free unit its rules
-- give: free (no occupant, clean again since its last occupant's
-- disinfection) and in service, in its section, fitting its species; an
-- isolation unit first for an animal whose infectious alert is current, an
-- intensive-care unit first for a stay going there, else an ordinary unit,
-- then intensive care, then isolation, the lowest id within each. Released
-- at the stay's end, the unit disinfected 30 to 90 minutes later. A move
-- ends the open placement and opens the next at one instant, the old unit
-- disinfected likewise. An animal whose alert finds no isolation unit free
-- waits in its unit for the first one disinfected while the alert lasts;
-- once its alert has ended it leaves isolation for the lowest free ordinary
-- unit fitting it, so the isolation unit serves the next infectious animal
-- (or, last, a section full to its last fitting unit). Events at or after
-- T0 do not happen. The build fails if a stay finds no fitting unit
-- (vet-housing-domain.md, "Loading").
CREATE TEMP TABLE h_place (
    pid      serial PRIMARY KEY,
    unit_id  integer     NOT NULL,
    n        integer     NOT NULL,
    from_at  timestamptz NOT NULL,
    until_at timestamptz,
    reason   text        NOT NULL
);
CREATE TEMP TABLE h_disinfect (unit_id integer NOT NULL, at timestamptz NOT NULL);
CREATE TEMP TABLE h_ev (seq bigserial PRIMARY KEY, t timestamptz NOT NULL, prio integer NOT NULL,
                        kind text NOT NULL, n integer, unit_id integer);
CREATE INDEX ON h_ev (t, prio, seq);
CREATE TEMP TABLE h_wait (n integer PRIMARY KEY, section_id integer NOT NULL, since timestamptz NOT NULL);

INSERT INTO h_ev (t, prio, kind, n)
SELECT t, prio, kind, n
  FROM (SELECT place_at AS t, 3 AS prio, 'place' AS kind, n FROM h_stay
        UNION ALL
        SELECT discharged_at, 0, 'end', n FROM h_stay WHERE discharged_at IS NOT NULL
        UNION ALL
        SELECT alert_from, 2, 'isolate', n FROM h_stay
         WHERE alert_from IS NOT NULL AND alert_from < coalesce(discharged_at, 'infinity')
        UNION ALL
        SELECT alert_until, 2, 'out', n FROM h_stay
         WHERE alert_until IS NOT NULL AND alert_until < coalesce(discharged_at, 'infinity')) AS x
 ORDER BY t, prio, n;

DO $$
DECLARE
    v      h_env;
    ev     h_ev;
    st     h_stay;
    cur    h_place;
    target integer;
    lag    interval;
BEGIN
    SELECT * INTO v FROM h_env;
    LOOP
        SELECT * INTO ev FROM h_ev ORDER BY t, prio, seq LIMIT 1;
        -- Nothing happens at or after T0 but the placing of a stay admitted in
        -- its last ten minutes, placed at T0.
        EXIT WHEN NOT FOUND OR ev.t > v.e;
        DELETE FROM h_ev WHERE seq = ev.seq;
        CONTINUE WHEN ev.t = v.e AND ev.kind <> 'place';
        IF ev.n IS NOT NULL THEN
            SELECT * INTO st FROM h_stay WHERE n = ev.n;
            SELECT * INTO cur FROM h_place WHERE n = ev.n AND until_at IS NULL;
        END IF;

        IF ev.kind = 'place' THEN
            SELECT u.id INTO target FROM h_unit AS u
             WHERE u.section_id = st.section_id AND u.occupant IS NULL AND u.free_at <= ev.t
               AND u.out_from > ev.t
               AND (u.isolation OR u.intensive
                    OR (u.kind, st.species) IN (('box', 'horse'), ('stall', 'cattle'), ('pen', 'sheep'),
                                                ('pen', 'goat'), ('kennel', 'dog'), ('cage', 'cat'),
                                                ('cage', 'rabbit'), ('cage', 'ferret')))
             ORDER BY CASE WHEN u.isolation AND st.alert_from <= ev.t THEN 0
                           WHEN u.intensive AND st.ic THEN 1
                           WHEN NOT u.isolation AND NOT u.intensive THEN 2
                           WHEN u.intensive THEN 3 ELSE 4 END, u.id
             LIMIT 1;
            IF target IS NULL THEN
                RAISE EXCEPTION 'load.sql: stay % (section %, %) finds no fitting unit free at %',
                    st.n, st.section_id, st.species, ev.t;
            END IF;
            INSERT INTO h_place (unit_id, n, from_at, reason) VALUES (target, st.n, ev.t, 'admission');
            UPDATE h_unit SET occupant = st.n WHERE id = target;
            IF st.ic AND (SELECT intensive FROM h_unit WHERE id = target) THEN
                INSERT INTO h_ev (t, prio, kind, n)
                VALUES (ev.t + (24 + 24 * pg_temp.housing_u(st.n, 1402)) * interval '1 hour', 2, 'out', st.n);
            END IF;

        ELSIF ev.kind = 'end' THEN
            IF cur.pid IS NOT NULL THEN
                lag := (30 + 60 * pg_temp.housing_u(cur.pid, 1403)) * interval '1 minute';
                UPDATE h_place SET until_at = ev.t WHERE pid = cur.pid;
                UPDATE h_unit SET occupant = NULL, free_at = ev.t + lag WHERE id = cur.unit_id;
                INSERT INTO h_disinfect VALUES (cur.unit_id, ev.t + lag);
                INSERT INTO h_ev (t, prio, kind, unit_id) VALUES (ev.t + lag, 1, 'free', cur.unit_id);
            END IF;
            DELETE FROM h_wait WHERE n = ev.n;

        ELSIF ev.kind IN ('isolate', 'out', 'free') THEN
            IF ev.kind = 'free' THEN
                -- A unit clean again: an isolation unit takes the longest waiting
                -- infectious animal of its section whose alert still lasts.
                CONTINUE WHEN NOT (SELECT isolation AND occupant IS NULL FROM h_unit WHERE id = ev.unit_id);
                SELECT s.* INTO st FROM h_wait AS w JOIN h_stay AS s ON s.n = w.n
                 WHERE w.section_id = (SELECT section_id FROM h_unit WHERE id = ev.unit_id)
                   AND coalesce(s.alert_until, 'infinity') > ev.t
                 ORDER BY w.since, w.n LIMIT 1;
                CONTINUE WHEN NOT FOUND;
                SELECT * INTO cur FROM h_place WHERE n = st.n AND until_at IS NULL;
                target := ev.unit_id;
            ELSIF ev.kind = 'isolate' THEN
                CONTINUE WHEN cur.pid IS NULL OR (SELECT isolation FROM h_unit WHERE id = cur.unit_id);
                SELECT u.id INTO target FROM h_unit AS u
                 WHERE u.section_id = st.section_id AND u.isolation AND u.occupant IS NULL
                   AND u.free_at <= ev.t AND u.out_from > ev.t
                 ORDER BY u.id LIMIT 1;
                IF target IS NULL THEN
                    INSERT INTO h_wait VALUES (st.n, st.section_id, ev.t) ON CONFLICT DO NOTHING;
                    CONTINUE;
                END IF;
            ELSE   -- out of intensive care or isolation, into the lowest free ordinary unit fitting it
                CONTINUE WHEN cur.pid IS NULL
                           OR NOT (SELECT intensive OR isolation FROM h_unit WHERE id = cur.unit_id);
                SELECT u.id INTO target FROM h_unit AS u
                 WHERE u.section_id = st.section_id AND NOT u.isolation AND NOT u.intensive
                   AND u.occupant IS NULL AND u.free_at <= ev.t AND u.out_from > ev.t
                   AND (u.kind, st.species) IN (('box', 'horse'), ('stall', 'cattle'), ('pen', 'sheep'),
                                                ('pen', 'goat'), ('kennel', 'dog'), ('cage', 'cat'),
                                                ('cage', 'rabbit'), ('cage', 'ferret'))
                 ORDER BY u.id LIMIT 1;
                CONTINUE WHEN target IS NULL;
            END IF;
            lag := (30 + 60 * pg_temp.housing_u(cur.pid, 1403)) * interval '1 minute';
            UPDATE h_place SET until_at = ev.t WHERE pid = cur.pid;
            UPDATE h_unit SET occupant = NULL, free_at = ev.t + lag WHERE id = cur.unit_id;
            INSERT INTO h_disinfect VALUES (cur.unit_id, ev.t + lag);
            INSERT INTO h_ev (t, prio, kind, unit_id) VALUES (ev.t + lag, 1, 'free', cur.unit_id);
            INSERT INTO h_place (unit_id, n, from_at, reason)
            VALUES (target, st.n, ev.t, CASE WHEN ev.kind = 'out' THEN 'move' ELSE 'isolation' END);
            UPDATE h_unit SET occupant = st.n WHERE id = target;
            DELETE FROM h_wait WHERE n = st.n;
        END IF;
    END LOOP;
END $$;
DELETE FROM h_disinfect WHERE at >= (SELECT e FROM h_env);   -- after T0: still to clean
ANALYZE h_place, h_stay;

-- In time order, by a nurse of the stay's section.
INSERT INTO housing_placements (id, unit_id, stay_id, from_at, until_at, reason, placed_by)
SELECT row_number() OVER (ORDER BY p.from_at, p.pid), p.unit_id, p.n, p.from_at, p.until_at, p.reason,
       n.ids[1 + floor(pg_temp.housing_u(p.pid, 1404) * array_length(n.ids, 1))::integer]
  FROM h_place AS p JOIN h_stay AS s ON s.n = p.n
  JOIN h_staff AS n ON n.section_id = s.section_id AND n.kind = 'nurse'
 ORDER BY p.from_at, p.pid;

-- --- Feeding plans ---------------------------------------------------------------------

-- Each stay's diet from its placement to its end, from its species' short
-- list, at its species' meals a day; one stay in six a nil-by-mouth order
-- before a morning anaesthetic at 09:00, the first morning at least 18 hours
-- after admission: from twelve hours before it for a horse or a ruminant,
-- eight for the others, until the anaesthetic. Set by a nurse of the
-- section.
CREATE TEMP TABLE h_plan AS
SELECT s.n, 'diet'::text AS kind,
       CASE s.species
         WHEN 'horse' THEN (ARRAY['hay and concentrate', 'hay only', 'soaked hay, low starch',
                                  'mash, small and often'])[1 + floor(4 * pg_temp.housing_u(s.n, 1405))::integer]
         WHEN 'cattle' THEN (ARRAY['hay and silage', 'hay and concentrate', 'calf milk replacer'])
                            [1 + floor(3 * pg_temp.housing_u(s.n, 1405))::integer]
         WHEN 'dog' THEN (ARRAY['standard dry', 'gastrointestinal', 'renal', 'recovery wet', 'low fat'])
                         [1 + floor(5 * pg_temp.housing_u(s.n, 1405))::integer]
         WHEN 'cat' THEN (ARRAY['standard dry', 'renal', 'recovery wet', 'urinary'])
                         [1 + floor(4 * pg_temp.housing_u(s.n, 1405))::integer]
         WHEN 'rabbit' THEN (ARRAY['hay and pellets', 'critical care feed'])
                            [1 + floor(2 * pg_temp.housing_u(s.n, 1405))::integer]
         WHEN 'ferret' THEN (ARRAY['standard dry', 'recovery wet'])
                            [1 + floor(2 * pg_temp.housing_u(s.n, 1405))::integer]
         ELSE (ARRAY['hay and browse', 'hay and concentrate'])[1 + floor(2 * pg_temp.housing_u(s.n, 1405))::integer]
       END AS diet,
       CASE WHEN s.species = 'horse' THEN 4 WHEN s.species IN ('cattle', 'sheep', 'goat', 'dog') THEN 2 ELSE 3 END
           AS meals_a_day,
       f.from_at, s.discharged_at AS until_at, NULL::text AS note
  FROM h_stay AS s
  JOIN (SELECT n, min(from_at) AS from_at FROM h_place GROUP BY n) AS f ON f.n = s.n
UNION ALL
SELECT s.n, 'nil-by-mouth', NULL, NULL, a.at - l.len, a.at, 'nil by mouth before anaesthesia'
  FROM h_env AS v, h_stay AS s
  JOIN (SELECT n, min(from_at) AS from_at FROM h_place GROUP BY n) AS f ON f.n = s.n,
       LATERAL (SELECT CASE WHEN s.species IN ('horse', 'cattle', 'sheep', 'goat') THEN interval '12 hours'
                            ELSE interval '8 hours' END AS len) AS l,
       LATERAL (SELECT pg_temp.housing_utc((pg_temp.housing_local(s.admitted_at + interval '18 hours', v.o)::date
                                            + 1)::timestamp + interval '9 hours', v.o) AS at) AS a
 WHERE pg_temp.housing_u(s.n, 1406) < 1.0 / 6
   AND a.at - l.len >= f.from_at AND a.at - l.len < v.e
   AND a.at <= coalesce(s.discharged_at, 'infinity');

INSERT INTO housing_feeding_plans (id, stay_id, kind, diet, meals_a_day, from_at, until_at, set_by, note)
SELECT row_number() OVER (ORDER BY p.from_at, p.n, p.kind), p.n, p.kind, p.diet, p.meals_a_day, p.from_at,
       p.until_at, n.ids[1 + floor(pg_temp.housing_u(p.n * 2 + (p.kind = 'diet')::integer, 1407)
                                   * array_length(n.ids, 1))::integer], p.note
  FROM h_plan AS p JOIN h_stay AS s ON s.n = p.n
  JOIN h_staff AS n ON n.section_id = s.section_id AND n.kind = 'nurse'
 ORDER BY p.from_at, p.n, p.kind;

-- --- The care log ---------------------------------------------------------------------

-- Each placement's actions, day by day in local time, while placed and
-- before T0: a check every four hours around the clock (02, 06, ... 22, a
-- few minutes after); the species' meals at its rounds after it was placed,
-- none while a nil-by-mouth order is in force, what was eaten by a hash
-- (about 85 % all, 12 % part, 3 % none); four other actions in the care day
-- (water, mucking out, bedding, a walk for a dog or a horse, grooming;
-- water instead of a walk for the others); each emptied unit's disinfection.
-- Times and carers by hashes of the placement and the day, a carer of the
-- unit's section, not matched against the rota (D394).
CREATE TEMP TABLE h_care AS
WITH pl AS (
    SELECT p.pid, p.unit_id, p.n, p.from_at, least(coalesce(p.until_at, v.e), v.e) AS until_at, s.species,
           u.section_id, v.o
      FROM h_env AS v, h_place AS p JOIN h_stay AS s ON s.n = p.n JOIN h_unit AS u ON u.id = p.unit_id
), days AS (
    SELECT pl.*, d::date AS day
      FROM pl, generate_series(pg_temp.housing_local(pl.from_at, pl.o)::date,
                               pg_temp.housing_local(pl.until_at, pl.o)::date, interval '1 day') AS d
), keyed AS (
    SELECT days.*, pid::bigint * 1000000 + (day - DATE '2000-01-01') * 24 AS dk FROM days
), slots AS (
    SELECT keyed.*, 'check' AS kind, h, h + 25 * pg_temp.housing_u(dk + h, 1408) / 60 AS at_h
      FROM keyed, unnest(ARRAY[2, 6, 10, 14, 18, 22]) AS h
    UNION ALL
    SELECT keyed.*, 'feeding', h, h + (5 + 40 * pg_temp.housing_u(dk + h, 1409)) / 60
      FROM keyed, unnest(CASE species WHEN 'horse' THEN ARRAY[6, 12, 17, 21]
                                     WHEN 'cattle' THEN ARRAY[7, 16] WHEN 'sheep' THEN ARRAY[7, 16]
                                     WHEN 'goat' THEN ARRAY[7, 16] WHEN 'dog' THEN ARRAY[8, 17]
                                     ELSE ARRAY[8, 13, 18] END) AS h
    UNION ALL
    SELECT keyed.*, 'care', h, h + 50 * pg_temp.housing_u(dk + h, 1410) / 60
      FROM keyed, unnest(ARRAY[7, 10, 15, 19]) AS h
), timed AS (
    SELECT slots.*, pg_temp.housing_utc(day + at_h * interval '1 hour', o) AS done_at,
           pg_temp.housing_utc(day + h * interval '1 hour', o) AS slot_at,
           dk + h AS k
      FROM slots
)
SELECT t.unit_id, t.n AS stay_id,
       CASE WHEN t.kind <> 'care' THEN t.kind
            ELSE CASE WHEN c.x < 25 THEN 'water' WHEN c.x < 50 THEN 'mucking-out' WHEN c.x < 62 THEN 'bedding'
                      WHEN c.x < 92 THEN CASE WHEN t.species IN ('dog', 'horse') THEN 'walk' ELSE 'water' END
                      ELSE 'grooming' END END AS kind,
       CASE WHEN t.kind = 'feeding' THEN CASE WHEN c.y < 0.85 THEN 'all' WHEN c.y < 0.97 THEN 'part' ELSE 'none' END
            END AS eaten,
       t.done_at, c.carer AS done_by
  FROM timed AS t
  JOIN h_staff AS cs ON cs.section_id = t.section_id AND cs.kind = 'carer',
       LATERAL (SELECT floor(100 * pg_temp.housing_u(t.k, 1411)) AS x, pg_temp.housing_u(t.k, 1412) AS y,
                       cs.ids[1 + floor(pg_temp.housing_u(t.dk, 1413) * array_length(cs.ids, 1))::integer]
                           AS carer) AS c
 WHERE t.done_at >= t.from_at AND t.done_at < t.until_at
   AND (t.kind <> 'feeding'
        OR (t.slot_at >= t.from_at
            AND NOT EXISTS (SELECT 1 FROM h_plan AS f
                             WHERE f.n = t.n AND f.kind = 'nil-by-mouth'
                               AND ((t.done_at >= f.from_at AND t.done_at < f.until_at)
                                    OR (t.slot_at >= f.from_at AND t.slot_at < f.until_at)))))
UNION ALL
SELECT d.unit_id, NULL, 'disinfection', NULL, d.at,
       cs.ids[1 + floor(pg_temp.housing_u(extract(epoch FROM d.at)::bigint + d.unit_id, 1414)
                        * array_length(cs.ids, 1))::integer]
  FROM h_disinfect AS d JOIN h_unit AS u ON u.id = d.unit_id
  JOIN h_staff AS cs ON cs.section_id = u.section_id AND cs.kind = 'carer';

INSERT INTO housing_care_events (id, unit_id, stay_id, kind, eaten, done_at, done_by)
SELECT row_number() OVER (ORDER BY done_at, unit_id, kind), unit_id, stay_id, kind, eaten, done_at, done_by
  FROM h_care ORDER BY done_at, unit_id, kind;

-- --- The units at T0 -------------------------------------------------------------------

-- A unit released whose disinfection falls at or after T0 is to clean since
-- its release; the two under repair out of service since a week before T0;
-- the others clean since their last disinfection (or their installation).
UPDATE housing_units AS u
   SET state = CASE WHEN u.id IN (15, 50) THEN 'out-of-service'
                    WHEN h.free_at >= v.e THEN 'to-clean' ELSE 'clean' END,
       state_since_at = CASE WHEN u.id IN (15, 50) THEN greatest(v.e - interval '7 days',
                                                                 least(h.free_at, v.e))
                             WHEN h.free_at >= v.e THEN (SELECT max(p.until_at) FROM h_place AS p
                                                         WHERE p.unit_id = u.id)
                             ELSE h.free_at END
  FROM h_env AS v, h_unit AS h
 WHERE h.id = u.id;

-- --- The build's checks (vet-housing-domain.md, "Loading"; "In flight at T0") ----------------

DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(x, '; ') INTO bad FROM (
        SELECT 'stay ' || s.n || ' current at T0 has ' || count(p.id) || ' open placements' AS x
          FROM h_stay AS s LEFT JOIN housing_placements AS p ON p.stay_id = s.n AND p.until_at IS NULL
         WHERE s.discharged_at IS NULL GROUP BY s.n HAVING count(p.id) <> 1
        UNION ALL
        SELECT 'placement ' || p.id || ' open on ended stay ' || p.stay_id
          FROM housing_placements AS p JOIN h_stay AS s ON s.n = p.stay_id
         WHERE p.until_at IS NULL AND s.discharged_at IS NOT NULL
        UNION ALL
        SELECT 'unit ' || unit_id || ' holds ' || count(*) || ' open placements'
          FROM housing_placements WHERE until_at IS NULL GROUP BY unit_id HAVING count(*) > 1
        UNION ALL
        SELECT 'stay ' || s.n || ' never placed'
          FROM h_stay AS s WHERE NOT EXISTS (SELECT 1 FROM housing_placements AS p WHERE p.stay_id = s.n)
        UNION ALL
        SELECT 'placement ' || p.id || ' on a stay that does not exist'
          FROM housing_placements AS p WHERE NOT EXISTS (SELECT 1 FROM h_stay AS s WHERE s.n = p.stay_id)
        UNION ALL
        SELECT 'placement ' || p.id || ' outside its stay'
          FROM housing_placements AS p JOIN h_stay AS s ON s.n = p.stay_id
         WHERE p.from_at < s.admitted_at OR p.until_at > s.discharged_at
        UNION ALL
        SELECT 'a ' || e.kind || ' at unit ' || e.unit_id || ' at ' || e.done_at || ' outside its stay''s placement'
          FROM housing_care_events AS e
         WHERE e.stay_id IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM housing_placements AS p
                            WHERE p.unit_id = e.unit_id AND p.stay_id = e.stay_id AND e.done_at >= p.from_at
                              AND e.done_at < coalesce(p.until_at, 'infinity'))
        UNION ALL
        SELECT 'a feeding of stay ' || e.stay_id || ' inside a nil-by-mouth order'
          FROM housing_care_events AS e JOIN housing_feeding_plans AS f
            ON f.stay_id = e.stay_id AND f.kind = 'nil-by-mouth' AND e.done_at >= f.from_at AND e.done_at < f.until_at
         WHERE e.kind = 'feeding'
        UNION ALL
        SELECT 'unit ' || p.unit_id || ' occupied at T0 is ' || u.state
          FROM housing_placements AS p JOIN housing_units AS u ON u.id = p.unit_id
         WHERE p.until_at IS NULL AND u.state <> 'clean'
        LIMIT 20
    ) AS y;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'load.sql: the wards do not hold: %', bad;
    END IF;
END $$;

-- --- Sequences: each resumes after its range (D276) ---------------------------------------

SELECT setval(pg_get_serial_sequence('housing_units', 'id'), 64),
       setval(pg_get_serial_sequence('housing_displays', 'id'), 66);
SELECT setval(pg_get_serial_sequence(t, 'id'), (xpath('/row/m/text()',
              query_to_xml(format('SELECT max(id) AS m FROM %I', t), false, true, '')))[1]::text::bigint)
  FROM unnest(ARRAY['housing_placements', 'housing_feeding_plans', 'housing_care_events']) AS t;

VACUUM (ANALYZE) housing_units, housing_displays, housing_placements, housing_feeding_plans,
                 housing_care_events;
