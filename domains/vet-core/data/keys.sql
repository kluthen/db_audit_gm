-- vet-core's key functions (v0.5 master spec 8.5, 9.2; capture W2 items 3, 4;
-- vet-core-domain.md, "The key functions (D374, D375, D379)"). docs/gm.md,
-- "Core keys", documents each, its arguments, what it returns and its
-- formula; this file is the formula.
--
-- gmctl load-data streams this file ahead of the core's load.sql, each
-- part's load.sql, each partner data.sql and derive.sql, in their session:
-- every function lives in pg_temp and vanishes with the session, so nothing
-- reaches the catalog the players read.
--
-- The contract is the eighteen pg_temp.core_* functions. The pg_temp.vc_*
-- functions are their shared formulas (a hash, the calendar, the rota's
-- duties, the agenda, a vet's or a patient's pick); a part calls only the
-- eighteen.
--
-- Signatures (D379): an id function takes (n integer); a function computing
-- a time takes (n integer, load_epoch timestamptz, utc_offset integer), the
-- run's psql variable load_epoch (the load's "now", T0) and
-- customer_utc_offset (hours; the customer's zone a fixed Etc/GMT offset).
-- Every function is IMMUTABLE, a pure function of its arguments, and returns
-- no row for an id outside its range or not yet existing at load_epoch.
--
-- The history (vet-core-domain.md, "Deterministic key ranges", D279): 53
-- local weeks, Monday to Sunday, the last the week of load_epoch, cut at
-- load_epoch; each weekly volume ramps from 0.6 of today's rate in week 0
-- to 1.0 in week 52; inside a week, events follow the hour-of-week shape of
-- their stream (vet-core-domain.md, "The business hours"). Every draw is a
-- hash of the id (vc_u), never random().

-- --- Shared formulas (pg_temp.vc_*) -------------------------------------------

-- A uniform draw in [0, 1) from x and a salt.
CREATE FUNCTION pg_temp.vc_u(x bigint, salt integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, salt) & 2147483647)::float8 / 2147483648 $$;

-- A UTC instant as the customer's local time, and back.
CREATE FUNCTION pg_temp.vc_local(t timestamptz, utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t AT TIME ZONE 'UTC') + utc_offset * interval '1 hour' $$;
CREATE FUNCTION pg_temp.vc_utc(t timestamp, utc_offset integer) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - utc_offset * interval '1 hour') AT TIME ZONE 'UTC' $$;

-- The history's start: local Monday 00:00, 52 weeks before load_epoch's week.
CREATE FUNCTION pg_temp.vc_start(load_epoch timestamptz, utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT date_trunc('week', pg_temp.vc_local(load_epoch, utc_offset)) - interval '364 days' $$;

-- A stream's events an hour at rate 1.0, by local weekday (1 Monday .. 7
-- Sunday) and hour (vet-core-domain.md, producer profiles; D304):
--   sched-*     78 on a weekday (domestic 75 % late in the afternoon, horse
--               18 % and farm 7 % in the morning), 30 on Saturday morning
--               (domestic), none on Sunday
--   emergency   10 a day around the clock, a third between 22:00 and 08:00
--   in-hospital 12 a day on the ward rounds, 09-12, and 16-18 at half
--   herd-visit  10 on Tuesday and Thursday, 08-13
--   stay        admissions around the clock (0.8 at night, 1.1 by day, 0.9 late)
--   flat        every hour alike
CREATE FUNCTION pg_temp.vc_rate(stream text, dow integer, h integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE stream
  WHEN 'sched-domestic' THEN CASE WHEN dow <= 5 THEN 78 * 0.75 * coalesce((ARRAY[0.5, 0.6, 0.8, 0.8, 0.4, 0.6, 1.0, 1.0, 1.2, 1.4, 1.4, 0.6])[h - 7], 0) / 10.3
                                  WHEN dow = 6 THEN 30 * coalesce((ARRAY[0.8, 1.0, 1.0, 1.0, 0.6])[h - 7], 0) / 4.4
                                  ELSE 0 END
  WHEN 'sched-horse' THEN CASE WHEN dow <= 5 THEN 78 * 0.18 * coalesce((ARRAY[1.0, 1.2, 1.2, 1.0, 0.5, 0, 0.4, 0.3])[h - 7], 0) / 5.6 ELSE 0 END
  WHEN 'sched-farm'  THEN CASE WHEN dow <= 5 THEN 78 * 0.07 * coalesce((ARRAY[1.0, 1.2, 1.2, 1.0, 0.5, 0, 0.4, 0.3])[h - 7], 0) / 5.6 ELSE 0 END
  WHEN 'emergency'   THEN 10 * CASE WHEN h < 8 THEN 0.8 WHEN h < 22 THEN 1.1 ELSE 0.9 END / 23.6
  WHEN 'in-hospital' THEN 12 * CASE WHEN h BETWEEN 9 AND 11 THEN 1.0 WHEN h BETWEEN 16 AND 17 THEN 0.5 ELSE 0 END / 4
  WHEN 'herd-visit'  THEN CASE WHEN dow IN (2, 4) AND h BETWEEN 8 AND 12 THEN 2.0 ELSE 0 END
  WHEN 'stay'        THEN CASE WHEN h < 8 THEN 0.8 WHEN h < 22 THEN 1.1 ELSE 0.9 END
  WHEN 'flat'        THEN 1.0
  ELSE 0 END
$$;

-- An hour-of-week weight: a consultation's is the sum of its streams'.
CREATE FUNCTION pg_temp.vc_weight(shape text, dow integer, h integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE shape
  WHEN 'consult' THEN pg_temp.vc_rate('sched-domestic', dow, h) + pg_temp.vc_rate('sched-horse', dow, h)
                    + pg_temp.vc_rate('sched-farm', dow, h) + pg_temp.vc_rate('emergency', dow, h)
                    + pg_temp.vc_rate('in-hospital', dow, h) + pg_temp.vc_rate('herd-visit', dow, h)
  ELSE pg_temp.vc_rate(shape, dow, h) END
$$;

-- A shape as 168 cumulative fractions, the share of the week before each
-- hour (Monday 00:00 first).
CREATE FUNCTION pg_temp.vc_shape(shape text) RETURNS float8[]
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT array_agg(coalesce(c, 0) / t ORDER BY i)
  FROM (SELECT i, sum(w) OVER (ORDER BY i ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS c,
               sum(w) OVER () AS t
          FROM (SELECT i, pg_temp.vc_weight(shape, i / 24 + 1, i % 24) AS w
                  FROM generate_series(0, 167) AS i) AS a) AS b
$$;

-- A stream's events in the weeks before week w: the weekly volume wbase
-- times the ramp 0.6 + 0.4 v / 52 summed over v < w, floored.
CREATE FUNCTION pg_temp.vc_weeks(w integer, wbase float8) RETURNS bigint
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT floor(wbase * (0.6 * w + w * (w - 1) / 260.0))::bigint $$;

-- The local time of a stream's event n (1, 2, ... in time order), or null
-- when it falls at or after load_epoch: its week by the ramp's inverse, its
-- place in the week the quantile (j + 0.5) / (the week's count) of the
-- shape c (vc_shape's, passed by the caller so it is computed once a query).
CREATE FUNCTION pg_temp.vc_cal(n bigint, wbase float8, c float8[], load_epoch timestamptz,
                               utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN t < pg_temp.vc_local(load_epoch, utc_offset) THEN t END
  FROM (SELECT pg_temp.vc_start(load_epoch, utc_offset) + w * interval '7 days'
               + (i - 1) * interval '1 hour'
               + (q - c[i]) / (coalesce(c[i + 1], 1) - c[i]) * interval '1 hour' AS t
          FROM (SELECT w, q, width_bucket(q, c) AS i
                  FROM (SELECT w, (n - pg_temp.vc_weeks(w, wbase) - 0.5)
                                  / (pg_temp.vc_weeks(w + 1, wbase) - pg_temp.vc_weeks(w, wbase)) AS q
                          FROM (SELECT floor((sqrt((0.6 - 1 / 260.0) ^ 2 + 4 / 260.0 * (n - 0.5) / wbase)
                                              - (0.6 - 1 / 260.0)) * 130)::integer AS w0) AS r,
                               generate_series(greatest(0, w0 - 1), least(52, w0 + 1)) AS w
                         WHERE n >= 1 AND pg_temp.vc_weeks(w, wbase) < n
                           AND n <= pg_temp.vc_weeks(w + 1, wbase) OFFSET 0) AS a OFFSET 0) AS b OFFSET 0) AS e
$$;

-- How many of a stream's events fall before local time t (t at or before
-- load_epoch): vc_cal's inverse.
CREATE FUNCTION pg_temp.vc_before(t timestamp, wbase float8, c float8[], load_epoch timestamptz,
                                  utc_offset integer) RETURNS bigint
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN w < 0 THEN 0
            ELSE pg_temp.vc_weeks(w, wbase)
                 + greatest(0, least(cw, ceil((c[i] + (coalesce(c[i + 1], 1) - c[i]) * (hw - i + 1)) * cw - 0.5)))::bigint END
  FROM (SELECT w, hw, floor(hw)::integer + 1 AS i,
               pg_temp.vc_weeks(w + 1, wbase) - pg_temp.vc_weeks(w, wbase) AS cw
          FROM (SELECT w, extract(epoch FROM t - s - w * interval '7 days') / 3600 AS hw
                  FROM (SELECT s, floor(extract(epoch FROM t - s) / 604800)::integer AS w
                          FROM (SELECT pg_temp.vc_start(load_epoch, utc_offset) AS s) AS a) AS b) AS c) AS d
$$;

-- The ramp's quantile: the fraction of the year by which a share x of a
-- volume growing from 0.6 to 1.0 has happened.
CREATE FUNCTION pg_temp.vc_ramp(x float8) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (sqrt(0.36 + 0.64 * x) - 0.6) / 0.4 $$;

-- The rota's duties (vet-scheduling's pattern, O175, D339), by the local
-- date: the night vet over the 25 section vets; for the week of d, the
-- weekend's duty vet of each section (Saturday and Sunday 08:00-20:00) and
-- Saturday's two domestic consulting vets (08:00-13:00). A duty skips the
-- vets resting from a night: Friday's, Saturday's and Sunday's night vets.
CREATE FUNCTION pg_temp.vc_night_vet(d date) RETURNS integer
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT 1 + (d - date '2000-01-03') % 25 $$;
-- [horse duty, farm duty, domestic duty, Saturday consulting 1, 2]
CREATE FUNCTION pg_temp.vc_weekend_vets(d date) RETURNS integer[]
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
WITH k AS (SELECT (d - date '2000-01-03') / 7 AS wk, d - (d - date '2000-01-03') % 7 + 4 AS fri),
     x AS (SELECT wk, ARRAY[pg_temp.vc_night_vet(fri), pg_temp.vc_night_vet(fri + 1),
                            pg_temp.vc_night_vet(fri + 2)] AS rest FROM k),
     duty AS (SELECT (SELECT 1 + (wk + g) % 10 FROM generate_series(0, 9) AS g
                       WHERE 1 + (wk + g) % 10 <> ALL (rest) ORDER BY g LIMIT 1) AS horse,
                     (SELECT 11 + (wk + g) % 7 FROM generate_series(0, 6) AS g
                       WHERE 11 + (wk + g) % 7 <> ALL (rest) ORDER BY g LIMIT 1) AS farm,
                     (SELECT 18 + (wk + 3 + g) % 8 FROM generate_series(0, 7) AS g
                       WHERE 18 + (wk + 3 + g) % 8 <> ALL (rest) ORDER BY g LIMIT 1) AS dom,
                     wk, rest FROM x)
SELECT ARRAY[horse, farm, dom]
       || ARRAY(SELECT 18 + (2 * wk + g) % 8 FROM generate_series(0, 7) AS g
                 WHERE 18 + (2 * wk + g) % 8 <> ALL (rest) AND 18 + (2 * wk + g) % 8 <> dom
                 ORDER BY g LIMIT 2)
  FROM duty
$$;

-- --- Staff ---------------------------------------------------------------------

-- staff n's kind, section and specialty: the layout (D324, D327).
CREATE FUNCTION pg_temp.core_staff(n integer)
  RETURNS TABLE (kind text, section_id integer, specialty text)
  LANGUAGE sql IMMUTABLE AS $$
SELECT CASE WHEN n BETWEEN 1 AND 28 OR n IN (79, 80) THEN 'vet'
            WHEN n BETWEEN 29 AND 51 THEN CASE WHEN n % 3 = 0 THEN 'technician' ELSE 'nurse' END
            WHEN n BETWEEN 52 AND 56 THEN 'technician'
            WHEN n BETWEEN 57 AND 66 THEN 'carer'
            WHEN n BETWEEN 67 AND 70 THEN 'reception'
            WHEN n BETWEEN 71 AND 78 THEN 'lab'
            WHEN n BETWEEN 81 AND 85 THEN 'instructor' END,
       CASE WHEN n BETWEEN 1 AND 10 OR n BETWEEN 29 AND 36 OR n BETWEEN 57 AND 60 THEN 1
            WHEN n BETWEEN 11 AND 17 OR n BETWEEN 37 AND 42 OR n BETWEEN 61 AND 62 THEN 2
            WHEN n BETWEEN 18 AND 25 OR n BETWEEN 43 AND 51 OR n BETWEEN 63 AND 66 THEN 3 END,
       CASE WHEN n BETWEEN 1 AND 10
                 THEN (ARRAY['surgery', 'internal medicine', 'surgery', 'anaesthesia',
                             'reproduction', 'internal medicine', 'surgery', 'reproduction',
                             'internal medicine', 'anaesthesia'])[n]
            WHEN n BETWEEN 11 AND 17
                 THEN (ARRAY['herd health', 'herd health', 'surgery', 'reproduction',
                             'herd health', 'internal medicine', 'reproduction'])[n - 10]
            WHEN n BETWEEN 18 AND 25
                 THEN (ARRAY['internal medicine', 'surgery', 'emergency and critical care',
                             'anaesthesia', 'surgery', 'internal medicine',
                             'emergency and critical care', 'dermatology'])[n - 17]
            WHEN n BETWEEN 26 AND 28 THEN 'diagnostic imaging'
            WHEN n BETWEEN 52 AND 55 THEN 'radiography'
            WHEN n = 56 THEN 'biomedical engineering'
            WHEN n BETWEEN 79 AND 80 THEN 'clinical pathology'
            WHEN n BETWEEN 81 AND 85 THEN 'teaching' END
 WHERE n BETWEEN 1 AND 85
$$;

-- The history's absences (D388): staff n's absence on weekday dn (days since
-- Monday 2000-01-03), applied to its day and late shifts only, so the nights
-- and the weekend's cover are never short. Periods of one day to two weeks,
-- by a hash of the person and the week: a fortnight's leave (1/52 a week
-- starting one), a week's (0.0385), one or two days' (0.067 a week), about
-- five weeks a year a head; then a day's training or one to three days
-- absent (0.01 a week each). Nurses, technicians and carers take their
-- fortnights and weeks from their late week ((n + wk) mod 4 = 2, five
-- weekday shifts), at four times the rate, and their short leave at twice.
CREATE FUNCTION pg_temp.vc_absence(n integer, dn integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN dn % 7 >= 5 THEN NULL
            WHEN (NOT nur OR (n + w - 1) % 4 = 2) AND pg_temp.vc_u(n * 100000 + w - 1, 14) < f / 52.0 THEN 'leave'
            WHEN (NOT nur OR (n + w) % 4 = 2) AND pg_temp.vc_u(n * 100000 + w, 14) < f / 52.0 THEN 'leave'
            WHEN (NOT nur OR (n + w) % 4 = 2) AND pg_temp.vc_u(n * 100000 + w, 11) < f * 0.0385 THEN 'leave'
            WHEN pg_temp.vc_u(n * 100000 + w, 15) < CASE WHEN nur THEN 0.134 ELSE 0.067 END
                 AND d - floor(5 * pg_temp.vc_u(n * 100000 + w, 16)) BETWEEN 0 AND (pg_temp.vc_u(n * 100000 + w, 17) < 0.5)::integer
                 THEN 'leave'
            WHEN pg_temp.vc_u(n * 100000 + w, 12) < 0.01 AND d = floor(5 * pg_temp.vc_u(n * 100000 + w, 18))
                 THEN 'training'
            WHEN pg_temp.vc_u(n * 100000 + w, 13) < 0.01
                 AND d - floor(5 * pg_temp.vc_u(n * 100000 + w, 19)) BETWEEN 0 AND floor(3 * pg_temp.vc_u(n * 100000 + w, 20))
                 THEN 'absent' END
  FROM (SELECT dn / 7 AS w, dn % 7 AS d, n BETWEEN 29 AND 51 OR n BETWEEN 57 AND 66 AS nur,
               CASE WHEN n BETWEEN 29 AND 51 OR n BETWEEN 57 AND 66 THEN 4 ELSE 1 END AS f) AS a
$$;

-- staff n's shifts starting on local day `day`, by the rota's pattern
-- (vet-scheduling, step 6; docs/gm.md "The rota's pattern"; D384, D388),
-- with the history's absences on weekday day and late shifts (vc_absence).
CREATE FUNCTION pg_temp.core_shifts(n integer, day date, utc_offset integer)
  RETURNS TABLE (kind text, starts_at timestamptz, ends_at timestamptz, absence text)
  LANGUAGE sql IMMUTABLE AS $$
WITH q AS MATERIALIZED (SELECT dn, dn / 7 AS wk, dn % 7 + 1 AS dow,
                  CASE WHEN dn % 7 >= 5 THEN pg_temp.vc_weekend_vets(day) END AS we
             FROM (SELECT day - date '2000-01-03' AS dn) AS a),
r (kind, s, e) AS MATERIALIZED (
  -- the section vets: four weekdays of five, domestic vets of odd id
  -- 10:00-20:00, the others 08:00-18:00; never the day of their night or the next
  SELECT 'day', day + CASE WHEN n BETWEEN 18 AND 25 AND n % 2 = 1 THEN time '10:00' ELSE time '08:00' END,
         day + CASE WHEN n BETWEEN 18 AND 25 AND n % 2 = 1 THEN time '20:00' ELSE time '18:00' END
    FROM q WHERE n BETWEEN 1 AND 25 AND dow <= 5 AND (n + wk) % 5 <> dow - 1
             AND n <> pg_temp.vc_night_vet(day) AND n <> pg_temp.vc_night_vet(day - 1)
  UNION ALL  -- one vet a night, 20:00-08:00
  SELECT 'night', day + time '20:00', day + 1 + time '08:00'
    FROM q WHERE n BETWEEN 1 AND 25 AND n = pg_temp.vc_night_vet(day)
  UNION ALL  -- the weekend's duty vets, Saturday's two domestic consulting vets
  SELECT 'day', day + time '08:00', day + time '20:00' FROM q WHERE dow >= 6 AND n = ANY (we[1:3])
  UNION ALL
  SELECT 'day', day + time '08:00', day + time '13:00' FROM q WHERE dow = 6 AND n = ANY (we[4:5])
  UNION ALL  -- a surgeon and an anaesthetist on call each night, never the night vet
  SELECT 'on-call', day + time '20:00', day + 1 + time '08:00'
    FROM q WHERE n = (SELECT v FROM unnest(ARRAY[1, 3, 7, 13, 19, 22]) WITH ORDINALITY AS u (v, o)
                       WHERE v <> pg_temp.vc_night_vet(day) ORDER BY (o + q.dn) % 6 LIMIT 1)
              OR n = (SELECT v FROM unnest(ARRAY[4, 10, 21]) WITH ORDINALITY AS u (v, o)
                       WHERE v <> pg_temp.vc_night_vet(day) ORDER BY (o + q.dn) % 3 LIMIT 1)
  UNION ALL  -- the imaging vets and the radiographers: four weekdays of five, their own on-call
  SELECT 'day', day + time '08:00', day + time '18:00'
    FROM q WHERE (n BETWEEN 26 AND 28 OR n BETWEEN 52 AND 55) AND dow <= 5 AND (n + wk) % 5 <> dow - 1
  UNION ALL
  SELECT 'on-call', day + time '18:00', day + 1 + time '08:00' FROM q WHERE n = 26 + dn % 3 OR n = 52 + dn % 4
  UNION ALL
  SELECT 'on-call', day + time '08:00', day + time '18:00'
    FROM q WHERE dow >= 6 AND (n = 26 + wk % 3 OR n = 52 + wk % 4)
  UNION ALL  -- the biomedical engineer, Monday to Friday
  SELECT 'day', day + time '08:00', day + time '16:30' FROM q WHERE n = 56 AND dow <= 5
  UNION ALL  -- nurses, technicians, carers: a four-week cycle staggered by id, (n + wk) mod 4:
             -- 0 day Mon-Tue, night Thu-Sun; 1 night Mon-Wed, late Sat-Sun;
             -- 2 late Mon-Fri; 3 day Wed-Sun. One of each holds every shift of
             -- every day (D388): 47.25 h a week on average, 11 h rests, a
             -- weekly rest of 24 h in every week.
  SELECT k.kind, day + CASE k.kind WHEN 'day' THEN interval '07:00' WHEN 'late' THEN interval '13:30'
                                   ELSE interval '21:30' END,
         day + CASE k.kind WHEN 'day' THEN interval '15:30' WHEN 'late' THEN interval '22:00'
                           ELSE interval '31:30' END
    FROM q, LATERAL (SELECT CASE (n + wk) % 4
                              WHEN 0 THEN CASE WHEN dow <= 2 THEN 'day' WHEN dow >= 4 THEN 'night' END
                              WHEN 1 THEN CASE WHEN dow <= 3 THEN 'night' WHEN dow >= 6 THEN 'late' END
                              WHEN 2 THEN CASE WHEN dow <= 5 THEN 'late' END
                              ELSE CASE WHEN dow >= 3 THEN 'day' END
                            END AS kind) AS k
   WHERE (n BETWEEN 29 AND 51 OR n BETWEEN 57 AND 66) AND k.kind IS NOT NULL
  UNION ALL  -- reception, Monday to Saturday, five days of six
  SELECT 'day', day + CASE WHEN dow = 6 OR (n + dn) % 2 = 0 THEN time '08:00' ELSE time '11:00' END,
         day + CASE WHEN dow = 6 THEN time '12:30' WHEN (n + dn) % 2 = 0 THEN time '16:00' ELSE time '19:00' END
    FROM q WHERE n BETWEEN 67 AND 70 AND dow <= 6 AND dow <> (n + wk) % 6 + 1
  UNION ALL  -- the lab: the bench's hours, Monday to Saturday, a day and a late week in turn; on-call nights and Sundays
  SELECT CASE WHEN (n + wk) % 2 = 0 THEN 'day' ELSE 'late' END,
         day + CASE WHEN (n + wk) % 2 = 0 THEN time '07:00' ELSE time '13:00' END,
         day + CASE WHEN (n + wk) % 2 = 0 THEN time '15:00' ELSE time '21:00' END
    FROM q WHERE n BETWEEN 71 AND 78 AND dow <= 6 AND dow <> (n + wk) % 6 + 1
  UNION ALL
  SELECT 'on-call', day + time '21:00', day + 1 + time '07:00' FROM q WHERE n = 71 + dn % 8
  UNION ALL
  SELECT 'on-call', day + time '07:00', day + time '21:00' FROM q WHERE dow = 7 AND n = 71 + wk % 8
  UNION ALL  -- the clinical pathologists and the instructors: four weekdays of five
  SELECT 'day', day + time '08:30', day + time '17:00'
    FROM q WHERE (n IN (79, 80) OR n BETWEEN 81 AND 85) AND dow <= 5 AND (n + wk) % 5 <> dow - 1
)
SELECT r.kind, pg_temp.vc_utc(r.s, utc_offset), pg_temp.vc_utc(r.e, utc_offset),
       CASE WHEN r.kind IN ('day', 'late') AND q.dow <= 5 THEN pg_temp.vc_absence(n, q.dn) END
  FROM r, q
 WHERE n BETWEEN 1 AND 85
 ORDER BY r.s
$$;

-- A vet on shift at local time t with no absence, drawn by the salt: a vet
-- of the section on a day or night shift; else any section vet on one;
-- else the night vet. The section vets' rules of core_shifts, in closed form
-- (docs/gm.md says the two are one formula).
CREATE FUNCTION pg_temp.vc_vet_at(section integer, t timestamp, utc_offset integer, salt bigint)
  RETURNS integer LANGUAGE sql IMMUTABLE AS $$
WITH p AS MATERIALIZED (SELECT dn, dn / 7 AS wk, dn % 7 + 1 AS dow, t::time AS tm,
                  pg_temp.vc_night_vet(t::date) AS nv0, pg_temp.vc_night_vet(t::date - 1) AS nv1,
                  CASE WHEN dn % 7 >= 5 THEN pg_temp.vc_weekend_vets(t::date) END AS we
             FROM (SELECT t::date - date '2000-01-03' AS dn) AS a),
on_shift AS MATERIALIZED (
  SELECT v, CASE WHEN v <= 10 THEN 1 WHEN v <= 17 THEN 2 ELSE 3 END AS sec
    FROM p, generate_series(1, 25) AS v
   WHERE (dow <= 5 AND (v + wk) % 5 <> dow - 1 AND v <> nv0 AND v <> nv1
          AND tm >= CASE WHEN v >= 18 AND v % 2 = 1 THEN time '10:00' ELSE time '08:00' END
          AND tm < CASE WHEN v >= 18 AND v % 2 = 1 THEN time '20:00' ELSE time '18:00' END
          AND pg_temp.vc_absence(v, dn) IS NULL)
      OR (tm >= time '20:00' AND v = nv0) OR (tm < time '08:00' AND v = nv1)
      OR (dow >= 6 AND v = ANY (we[1:3]) AND tm >= time '08:00' AND tm < time '20:00')
      OR (dow = 6 AND v = ANY (we[4:5]) AND tm >= time '08:00' AND tm < time '13:00'))
SELECT coalesce((SELECT v FROM on_shift WHERE sec = section ORDER BY pg_temp.vc_u(salt * 32 + v, 21) LIMIT 1),
                (SELECT v FROM on_shift ORDER BY pg_temp.vc_u(salt * 32 + v, 22) LIMIT 1),
                (SELECT CASE WHEN tm < time '08:00' THEN nv1 ELSE nv0 END FROM p))
$$;

-- The section vets' shifts starting on local day d (vets 1-25; core_shifts'
-- rules in closed form, the same formula as vc_vet_at's): the weekday day
-- shifts, absent when vc_absence covers them; the night (20:00-08:00); the
-- weekend's duties (08:00-20:00) and Saturday's two domestic consulting
-- vets (08:00-13:00), kind 'day'.
CREATE FUNCTION pg_temp.vc_vet_shifts(d date)
  RETURNS TABLE (v integer, sec integer, kind text, s timestamp, e timestamp, absent boolean)
  LANGUAGE sql IMMUTABLE STRICT AS $$
WITH p AS MATERIALIZED (SELECT dn, dn / 7 AS wk, dn % 7 + 1 AS dow,
                  pg_temp.vc_night_vet(d) AS nv0, pg_temp.vc_night_vet(d - 1) AS nv1,
                  CASE WHEN dn % 7 >= 5 THEN pg_temp.vc_weekend_vets(d) END AS we
             FROM (SELECT d - date '2000-01-03' AS dn) AS a),
x (v, kind, s, e, absent) AS MATERIALIZED (
  SELECT g, 'day', d + CASE WHEN g >= 18 AND g % 2 = 1 THEN time '10:00' ELSE time '08:00' END,
         d + CASE WHEN g >= 18 AND g % 2 = 1 THEN time '20:00' ELSE time '18:00' END,
         pg_temp.vc_absence(g, dn) IS NOT NULL
    FROM p, generate_series(1, 25) AS g
   WHERE dow <= 5 AND (g + wk) % 5 <> dow - 1 AND g <> nv0 AND g <> nv1
  UNION ALL
  SELECT nv0, 'night', d + time '20:00', d + 1 + time '08:00', false FROM p
  UNION ALL
  SELECT g, 'day', d + time '08:00', d + time '20:00', false FROM p, unnest(we[1:3]) AS g WHERE dow >= 6
  UNION ALL
  SELECT g, 'day', d + time '08:00', d + time '13:00', false FROM p, unnest(we[4:5]) AS g WHERE dow = 6)
SELECT x.v, CASE WHEN x.v <= 10 THEN 1 WHEN x.v <= 17 THEN 2 ELSE 3 END, x.kind, x.s, x.e, x.absent FROM x
$$;

-- --- Animals, their identifiers, owners and herds --------------------------------

-- animal n's species: 1-12 the teaching dogs; domestic 13-14 600 (dog 56 %,
-- cat 39 %, rabbit 3 %, ferret 2 %); horses 14 601-16 000; farm animals
-- 16 001-17 000, in herd 1 + (n - 16 001) mod 200: cattle in herds 1-120
-- (dairy 1-80), sheep 121-170, goats 171-200.
CREATE FUNCTION pg_temp.core_species(n integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN n BETWEEN 1 AND 12 THEN 'dog'
            WHEN n BETWEEN 13 AND 14600 THEN
                 CASE WHEN pg_temp.vc_u(n, 61) < 0.56 THEN 'dog' WHEN pg_temp.vc_u(n, 61) < 0.95 THEN 'cat'
                      WHEN pg_temp.vc_u(n, 61) < 0.98 THEN 'rabbit' ELSE 'ferret' END
            WHEN n BETWEEN 14601 AND 16000 THEN 'horse'
            WHEN n BETWEEN 16001 AND 17000 THEN
                 CASE WHEN 1 + (n - 16001) % 200 <= 120 THEN 'cattle'
                      WHEN 1 + (n - 16001) % 200 <= 170 THEN 'sheep' ELSE 'goat' END END
$$;

-- The identifiers as the parts hold them (D379; ISO 11784/11785, UELN): the
-- fictional member state's numeric code 941 (of the user-assigned 900-998)
-- starts every chip and every UELN; XA (ISO 3166-1 user-assigned) every ear
-- tag and passport number. Each is an affine bijection of the id, so unique.
-- Chips: every dog, cat, horse and ferret; two rabbits in three none; no
-- farm animal (ear tags). The dozen mistyped chips are load.sql's own swap.
CREATE FUNCTION pg_temp.core_microchip(n integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT '941' || lpad(((n::bigint * 7919813 + 104729) % 1000000000000)::text, 12, '0')
 WHERE n BETWEEN 1 AND 16000
   AND NOT (pg_temp.core_species(n) = 'rabbit' AND pg_temp.vc_u(n, 62) < 2.0 / 3)
$$;
CREATE FUNCTION pg_temp.core_ueln(n integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT '941001' || lpad(((n::bigint * 7919 + 1009) % 1000000000)::text, 9, '0')
 WHERE n BETWEEN 14601 AND 16000
$$;
CREATE FUNCTION pg_temp.core_passport(n integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT 'XA' || lpad(((n::bigint * 104723 + 7) % 10000000000)::text, 10, '0')
 WHERE n BETWEEN 14601 AND 16000
$$;
CREATE FUNCTION pg_temp.core_ear_tag(n integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT 'XA' || lpad(((n::bigint * 9973 + 31) % 1000000000000)::text, 12, '0')
 WHERE n BETWEEN 16001 AND 17000
$$;
-- herd h's holding number.
CREATE FUNCTION pg_temp.core_holding(h integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT 'XA' || lpad((h * 7883 + 100003)::text, 9, '0') WHERE h BETWEEN 1 AND 200
$$;

-- A section's patients (1 horse, 2 farm, 3 domestic): ids lo..hi less the
-- teaching animals; the first `pre` registered before the history, the rest
-- during it, in id order.
CREATE FUNCTION pg_temp.vc_pool(section integer)
  RETURNS TABLE (lo integer, hi integer, pre integer)
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT p.lo, p.hi, p.pre
  FROM (VALUES (1, 14609, 16000, 928), (2, 16001, 17000, 667), (3, 13, 14600, 9725)) AS p (s, lo, hi, pre)
 WHERE p.s = section
$$;
CREATE FUNCTION pg_temp.vc_section(n integer) RETURNS integer
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN n BETWEEN 1 AND 14600 THEN 3 WHEN n BETWEEN 14601 AND 16000 THEN 1
            WHEN n BETWEEN 16001 AND 17000 THEN 2 END
$$;

-- animal n's registration: the teaching animals 800 days before the
-- history; a pre-history patient 30 to 2 530 days before it; one registered
-- during the year at its place in id order on the ramp, Monday to Saturday,
-- 08:00-19:00 (new animals, about 20 a day at 1.0).
CREATE FUNCTION pg_temp.vc_registered(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS timestamptz LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT pg_temp.vc_utc(least(t, pg_temp.vc_local(load_epoch, utc_offset) - interval '10 minutes'), utc_offset)
  FROM (SELECT CASE
          WHEN n BETWEEN 1 AND 12 OR n BETWEEN 14601 AND 14608 THEN s - interval '800 days' + interval '10 hours'
          WHEN n < p.lo + p.pre THEN
               date_trunc('day', s - (30 + floor(2500 * pg_temp.vc_u(n, 63))) * interval '1 day')
               + interval '8 hours' + pg_temp.vc_u(n, 64) * interval '11 hours'
          ELSE (SELECT date_trunc('day', d) + CASE WHEN extract(isodow FROM d) = 7 THEN interval '1 day' ELSE interval '0' END
                       + interval '8 hours' + pg_temp.vc_u(n, 64) * interval '11 hours'
                  FROM (SELECT s + pg_temp.vc_ramp((n - p.lo - p.pre + 0.5) / (p.hi - p.lo + 1 - p.pre))
                                   * (pg_temp.vc_local(load_epoch, utc_offset) - s) AS d) AS x)
          END AS t
          FROM (SELECT pg_temp.vc_start(load_epoch, utc_offset) AS s) AS a,
               pg_temp.vc_pool(pg_temp.vc_section(n)) AS p) AS b
 WHERE n BETWEEN 1 AND 17000
$$;

-- animal n's identity and food-chain status (D266, D280 rule 5): a horse is
-- in the food chain unless excluded (three in five, and the teaching horses;
-- dated, one way, signed by a horse vet when during the year); farm animals
-- food-producing; domestic not-applicable.
CREATE FUNCTION pg_temp.core_animal(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (species text, breed text, sex text, born_on date, name text, food_chain text,
                 food_chain_excluded_on date, food_chain_excluded_by integer, herd_id integer,
                 registered_at timestamptz)
  LANGUAGE sql IMMUTABLE AS $$
SELECT sp,
       CASE sp
         WHEN 'dog' THEN (ARRAY['Labrador Retriever', 'German Shepherd', 'Border Collie', 'Golden Retriever',
                                'French Bulldog', 'Jack Russell Terrier', 'Beagle', 'Dachshund', 'Cocker Spaniel',
                                'mixed breed'])[1 + floor(10 * pg_temp.vc_u(n, 65))::integer]
         WHEN 'cat' THEN (ARRAY['European Shorthair', 'Maine Coon', 'British Shorthair', 'Siamese', 'Persian',
                                'mixed breed'])[1 + floor(6 * pg_temp.vc_u(n, 65))::integer]
         WHEN 'rabbit' THEN (ARRAY['Netherland Dwarf', 'Holland Lop', 'Rex'])[1 + floor(3 * pg_temp.vc_u(n, 65))::integer]
         WHEN 'ferret' THEN 'domestic ferret'
         WHEN 'horse' THEN (ARRAY['Warmblood', 'Thoroughbred', 'Arabian', 'Haflinger', 'Welsh Pony', 'Friesian',
                                  'Connemara', 'cob'])[1 + floor(8 * pg_temp.vc_u(n, 65))::integer]
         WHEN 'cattle' THEN CASE WHEN h <= 80 THEN (ARRAY['Holstein', 'Montbéliarde', 'Jersey'])[1 + h % 3]
                                 ELSE (ARRAY['Charolais', 'Limousin', 'Angus'])[1 + h % 3] END
         WHEN 'sheep' THEN (ARRAY['Texel', 'Suffolk', 'Lacaune'])[1 + h % 3]
         ELSE (ARRAY['Saanen', 'Alpine'])[1 + h % 2] END,
       CASE WHEN (sp = 'cattle' AND h <= 80) OR sp = 'goat' THEN
                 CASE WHEN pg_temp.vc_u(n, 66) < 0.92 THEN 'female' ELSE 'male' END
            WHEN pg_temp.vc_u(n, 66) < 0.5 THEN 'female' ELSE 'male' END,
       (r AT TIME ZONE 'UTC')::date
         - (CASE WHEN n >= p.lo + p.pre AND NOT teach THEN 30 + 1000 * pg_temp.vc_u(n, 67) ^ 2
                 WHEN sp = 'horse' THEN 400 + 6000 * pg_temp.vc_u(n, 67)
                 WHEN sp IN ('cattle', 'sheep', 'goat') THEN 60 + 2000 * pg_temp.vc_u(n, 67)
                 ELSE 90 + 4000 * pg_temp.vc_u(n, 67) END)::integer,
       CASE WHEN sp IN ('cattle', 'sheep', 'goat') THEN
                 (ARRAY['Bella', 'Daisy', 'Rosie', 'Clover', 'Bluebell', 'Molly', 'Buttercup', 'Hazel',
                        'Poppy', 'Willow'])[1 + floor(10 * pg_temp.vc_u(n, 68))::integer]
                 || ' ' || right(pg_temp.core_ear_tag(n), 4)
            ELSE (ARRAY['Max', 'Luna', 'Bella', 'Charlie', 'Milo', 'Nala', 'Rocky', 'Lola', 'Oscar', 'Daisy',
                        'Simba', 'Coco', 'Toby', 'Ruby', 'Leo', 'Maya', 'Jasper', 'Rosie', 'Bailey', 'Zoe',
                        'Storm', 'Duke', 'Misty', 'Shadow', 'Pepper', 'Ginger', 'Biscuit', 'Hazel', 'Archie',
                        'Willow'])[1 + floor(30 * pg_temp.vc_u(n, 68))::integer] END,
       fc, CASE WHEN fc = 'excluded' THEN exd END,
       CASE WHEN fc = 'excluded' AND exd >= (pg_temp.vc_start(load_epoch, utc_offset))::date THEN 1 + n % 10 END,
       CASE WHEN sp IN ('cattle', 'sheep', 'goat') THEN h END,
       r
  FROM (SELECT pg_temp.core_species(n) AS sp, 1 + (n - 16001) % 200 AS h,
               pg_temp.vc_registered(n, load_epoch, utc_offset) AS r,
               n BETWEEN 1 AND 12 OR n BETWEEN 14601 AND 14608 AS teach) AS a,
       pg_temp.vc_pool(pg_temp.vc_section(n)) AS p,
       LATERAL (SELECT CASE WHEN a.sp = 'horse' THEN
                            CASE WHEN teach OR pg_temp.vc_u(n, 69) < 0.6 THEN 'excluded' ELSE 'food-producing' END
                            WHEN a.sp IN ('cattle', 'sheep', 'goat') THEN 'food-producing'
                            ELSE 'not-applicable' END AS fc,
                       (a.r AT TIME ZONE 'UTC')::date
                       + floor(least(200 * pg_temp.vc_u(n, 70),
                                     greatest(0, pg_temp.vc_local(load_epoch, utc_offset)::date
                                                 - (a.r AT TIME ZONE 'UTC')::date - 1)))::integer AS exd) AS f
 WHERE n BETWEEN 1 AND 17000
$$;

-- owner n: 1 the clinic; 2-201 holdings (herd h's keeper is owner h + 1);
-- 202-301 stables, 302-901 horse owners; 902-10 000 pet owners, 6 001-10 000
-- registered during the year with their first animal, the others 2 540 to
-- 3 600 days before the history (before any of their animals). Every owner has an
-- e-mail (first.last.<id>@example.net); never the address.
CREATE FUNCTION pg_temp.core_owner(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (kind text, name text, family_name text, email text, phone text, registered_at timestamptz)
  LANGUAGE sql IMMUTABLE AS $$
SELECT k,
       CASE k WHEN 'clinic' THEN 'Aldermoor Veterinary Hospitals' WHEN 'holding' THEN fam || ' Farm'
              WHEN 'stable' THEN place || ' Stables' ELSE first || ' ' || fam END,
       CASE k WHEN 'clinic' THEN 'Aldermoor Veterinary Hospitals' WHEN 'holding' THEN fam || ' Farm'
              WHEN 'stable' THEN place || ' Stables' ELSE fam END,
       CASE k WHEN 'clinic' THEN 'records.' || n || '@example.net'
              WHEN 'holding' THEN lower(fam) || '.farm.' || n || '@example.net'
              WHEN 'stable' THEN lower(replace(place, ' ', '')) || '.stables.' || n || '@example.net'
              ELSE lower(first) || '.' || lower(fam) || '.' || n || '@example.net' END,
       '+999 ' || lpad(((n::bigint * 7907 + 1234567) % 100000000)::text, 8, '0'),
       CASE WHEN n BETWEEN 6001 AND 10000
            THEN pg_temp.vc_registered(9738 + floor((n - 6001) * 4863.0 / 4000)::integer, load_epoch, utc_offset)
                 - interval '5 minutes'
            ELSE pg_temp.vc_utc(pg_temp.vc_start(load_epoch, utc_offset)
                                - (2540 + floor(1060 * pg_temp.vc_u(n, 71))) * interval '1 day'
                                + interval '9 hours', utc_offset) END
  FROM (SELECT CASE WHEN n = 1 THEN 'clinic' WHEN n <= 201 THEN 'holding' WHEN n <= 301 THEN 'stable'
                    ELSE 'person' END AS k,
               (ARRAY['Anna', 'Ben', 'Clara', 'David', 'Emma', 'Felix', 'Grace', 'Hugo', 'Iris', 'Jonas',
                      'Kate', 'Lukas', 'Marie', 'Noah', 'Olivia', 'Paul', 'Rosa', 'Samuel', 'Tessa', 'Victor',
                      'Wendy', 'Xavier', 'Yara', 'Zoe'])[1 + floor(24 * pg_temp.vc_u(n, 72))::integer] AS first,
               (ARRAY['Adler', 'Becker', 'Carter', 'Dubois', 'Evans', 'Fischer', 'Garnier', 'Hughes', 'Ivers',
                      'Janssen', 'Keller', 'Lambert', 'Moreau', 'Novak', 'Olsen', 'Peeters', 'Quinn', 'Renard',
                      'Schmidt', 'Thomas', 'Unger', 'Vogel', 'Weber', 'Young', 'Zimmer', 'Martin', 'Bernard',
                      'Muller', 'Brooks', 'Laurent'])[1 + floor(30 * pg_temp.vc_u(n, 73))::integer] AS fam,
               (ARRAY['Oakfield', 'Riverside', 'Hillcrest', 'Willowbrook', 'Meadowview', 'Stonebridge',
                      'Elmwood', 'Foxhollow', 'Greenacre', 'Ashford'])[1 + floor(10 * pg_temp.vc_u(n, 74))::integer]
                 || CASE WHEN n % 3 = 0 THEN ' Livery' ELSE '' END AS place) AS a
 WHERE n BETWEEN 1 AND 10000
$$;

-- --- Stays and deaths -----------------------------------------------------------

-- A stay's section and its rank in the section (D386): in each block of 20
-- stays, seven horse, three farm and ten domestic places, shuffled by a hash
-- of the block's number (u91); i counts the section's stays before it.
CREATE FUNCTION pg_temp.vc_stay_place(n integer) RETURNS TABLE (sec integer, i integer)
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
WITH r AS MATERIALIZED (
  SELECT q, CASE WHEN rk < 7 THEN 1 WHEN rk < 10 THEN 2 ELSE 3 END AS s
    FROM (SELECT q, (rank() OVER (ORDER BY pg_temp.vc_u((n / 20) * 32 + q, 91), q) - 1)::integer AS rk
            FROM generate_series(0, 19) AS q) AS a)
SELECT r.s, ((n / 20) * CASE r.s WHEN 1 THEN 7 WHEN 2 THEN 3 ELSE 10 END
             + (SELECT count(*) FROM r AS o WHERE o.s = r.s AND o.q < r.q))::integer
  FROM r WHERE r.q = n % 20
$$;
-- Its inverse: the stay holding rank i of section sec.
CREATE FUNCTION pg_temp.vc_stay_at(sec integer, i integer) RETURNS integer
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT (b * 20 + q)::integer
  FROM (SELECT i / c AS b, i % c AS j, c
          FROM (SELECT CASE sec WHEN 1 THEN 7 WHEN 2 THEN 3 ELSE 10 END AS c) AS x) AS y,
       LATERAL (SELECT q FROM (SELECT q, rank() OVER (ORDER BY pg_temp.vc_u(b * 32 + q, 91), q) - 1 AS rk
                                 FROM generate_series(0, 19) AS q) AS a
                 WHERE CASE WHEN rk < 7 THEN 1 WHEN rk < 10 THEN 2 ELSE 3 END = sec
                 ORDER BY q OFFSET j LIMIT 1) AS z
$$;
-- A stay's outcome by its id (D386): in each block of 25 one transfer, in
-- each block of 16 one death, each at a place drawn by a hash of the block.
CREATE FUNCTION pg_temp.vc_stay_outcome(n integer) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN n % 25 = floor(25 * pg_temp.vc_u(n / 25, 92)) THEN 'transferred'
            WHEN n % 16 = floor(16 * pg_temp.vc_u(n / 16, 93)) THEN 'died' ELSE 'discharged' END
$$;

-- stay n (1-2 500 in admission order, about 8 a day at 1.0): its section and
-- rank i by vc_stay_place; its animal through an affine bijection of i over
-- the section's pre-history patients (one stay an animal at most); one in 25
-- transferred, to sites 2-6, a day after admission once the partner has
-- answered; one in 16 died, 0.3 to 4.3 days after admission; else
-- discharged 2.5 to 6.5 days after admission, 10:00-13:00. A stay lasts at
-- most seven days, so a section never holds more current stays than its
-- units in service (21 horse, 10 farm, 31 domestic).
CREATE FUNCTION pg_temp.core_stay(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (animal_id integer, section_id integer, admitted_at timestamptz, discharged_at timestamptz,
                 outcome text, transferred_to_site_id integer)
  LANGUAGE sql IMMUTABLE AS $$
SELECT p.lo + ((a.i::bigint * 7919 + 101 * a.sec) % p.pre)::integer, a.sec, pg_temp.vc_utc(a.adm, utc_offset),
       CASE WHEN fin < load_epoch THEN fin END,
       CASE WHEN fin < load_epoch THEN a.outc END,
       CASE WHEN fin < load_epoch AND a.outc = 'transferred' THEN 2 + (n / 25) % 5 END
  FROM (SELECT pg_temp.vc_cal(n, 58, pg_temp.vc_shape('stay'), load_epoch, utc_offset) AS adm,
               sp.sec, sp.i, pg_temp.vc_stay_outcome(n) AS outc
          FROM pg_temp.vc_stay_place(n) AS sp OFFSET 0) AS a,
       pg_temp.vc_pool(a.sec) AS p,
       LATERAL (SELECT CASE a.outc
                  WHEN 'died' THEN pg_temp.vc_utc(a.adm + (0.3 + 4 * pg_temp.vc_u(n, 31)) * interval '1 day', utc_offset)
                  WHEN 'transferred' THEN pg_temp.vc_utc(a.adm + interval '1 day'
                                          + (2 + 6 * pg_temp.vc_u(n, 34)) * interval '1 hour'
                                          + (2 + 4 * pg_temp.vc_u(n, 33)) * interval '1 hour', utc_offset)
                  ELSE pg_temp.vc_utc(d + CASE WHEN d < a.adm + interval '2 days' THEN interval '1 day' ELSE interval '0' END,
                                      utc_offset) END AS fin
                  FROM (SELECT date_trunc('day', a.adm + (2.5 + 4 * pg_temp.vc_u(n, 31)) * interval '1 day')
                               + interval '10 hours' + pg_temp.vc_u(n, 32) * interval '3 hours' AS d OFFSET 0) AS x OFFSET 0) AS f
 WHERE n BETWEEN 1 AND 2500 AND a.adm IS NOT NULL
$$;

-- stay n's infectious alert, one stay in ten: from 1 to 12 hours after
-- admission, for 1.5 to 4.5 days or to the stay's end; until_at null while
-- current at T0.
CREATE FUNCTION pg_temp.core_stay_alert(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (from_at timestamptz, until_at timestamptz)
  LANGUAGE sql IMMUTABLE AS $$
SELECT a.f, CASE WHEN b.u < load_epoch THEN b.u END
  FROM pg_temp.core_stay(n, load_epoch, utc_offset) AS s,
       LATERAL (SELECT s.admitted_at + (1 + 11 * pg_temp.vc_u(n, 42)) * interval '1 hour' AS f) AS a,
       LATERAL (SELECT least(coalesce(s.discharged_at, 'infinity'),
                             a.f + (1.5 + 3 * pg_temp.vc_u(n, 43)) * interval '1 day') AS u) AS b
 WHERE pg_temp.vc_u(n, 41) < 0.10 AND a.f < load_epoch AND a.f < coalesce(s.discharged_at, 'infinity')
$$;

-- animal n's death in the history: in hospital, at its died stay's end (the
-- stay found by the inverse of core_stay's bijection and vc_stay_at); else at home, about
-- one animal in forty that no stay takes, on the ramp, at least 30 days
-- after its registration. How: euthanasia three in five in hospital, one in
-- two at home.
CREATE FUNCTION pg_temp.core_death(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (died_at timestamptz, how text)
  LANGUAGE sql IMMUTABLE AS $$
WITH a AS MATERIALIZED (
  SELECT ((((n - p.lo - 101 * s.sec) % p.pre + p.pre) % p.pre)::bigint * c.inv % p.pre)::integer AS i, s.sec
    FROM (SELECT pg_temp.vc_section(n) AS sec) AS s, pg_temp.vc_pool(s.sec) AS p,
         LATERAL (SELECT CASE s.sec WHEN 1 THEN 15 WHEN 2 THEN 102 ELSE 3904 END AS inv) AS c
   WHERE n BETWEEN 13 AND 17000 AND NOT n BETWEEN 14601 AND 14608 AND n < p.lo + p.pre),
st AS MATERIALIZED (SELECT pg_temp.vc_stay_at(a.sec, a.i) AS sn FROM a),
stay AS MATERIALIZED (SELECT st.sn, s.* FROM st, pg_temp.core_stay(st.sn, load_epoch, utc_offset) AS s
          WHERE st.sn BETWEEN 1 AND 2500)
SELECT discharged_at, CASE WHEN pg_temp.vc_u(sn, 35) < 0.6 THEN 'euthanasia' ELSE 'natural' END
  FROM stay WHERE outcome = 'died' AND animal_id = n
UNION ALL
SELECT t, CASE WHEN pg_temp.vc_u(n, 39) < 0.5 THEN 'euthanasia' ELSE 'natural' END
  FROM (SELECT pg_temp.vc_utc(s + pg_temp.vc_ramp(pg_temp.vc_u(n, 37))
                                  * (pg_temp.vc_local(load_epoch, utc_offset) - s), utc_offset) AS t
          FROM (SELECT pg_temp.vc_start(load_epoch, utc_offset) AS s) AS x) AS y
 WHERE n BETWEEN 13 AND 17000 AND NOT n BETWEEN 14601 AND 14608
   AND pg_temp.vc_u(n, 36) < 0.026 AND t < load_epoch
   AND t > pg_temp.vc_registered(n, load_epoch, utc_offset) + interval '30 days'
   AND NOT EXISTS (SELECT 1 FROM stay)
$$;

-- animal n's ownerships over the year (D278 answer 4): its owner from its
-- registration (a farm animal its herd's holding; a horse one of 202-901;
-- a domestic animal registered during the year with a new owner that
-- owner, else one of 902-6 000); a horse of a person (302-901) kept at a
-- stable one time in two; about one animal in sixteen sold during the year
-- (horses and domestic animals), the sale ending the owner's and the
-- keeper's rows and opening the buyer's, never after the animal's death.
CREATE FUNCTION pg_temp.core_ownership(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (owner_id integer, role text, from_at timestamptz, until_at timestamptz)
  LANGUAGE sql IMMUTABLE AS $$
WITH a AS MATERIALIZED (
  SELECT CASE WHEN n BETWEEN 1 AND 12 OR n BETWEEN 14601 AND 14608 THEN 1
              WHEN n >= 16001 THEN 2 + (n - 16001) % 200
              WHEN n >= 14601 THEN 202 + (n * 37) % 700
              WHEN f.first_of IS NOT NULL THEN f.first_of
              ELSE 902 + (n * 31) % 5099 END AS o1,
         pg_temp.vc_registered(n, load_epoch, utc_offset) AS r,
         (SELECT d.died_at FROM pg_temp.core_death(n, load_epoch, utc_offset) AS d LIMIT 1) AS died
    FROM (SELECT (SELECT o FROM (SELECT 6001 + ceil((n - 9738) * 4000.0 / 4863)::integer AS o) AS c
                   WHERE n BETWEEN 9738 AND 14600 AND o <= 10000
                     AND 9738 + floor((o - 6001) * 4863.0 / 4000)::integer = n) AS first_of) AS f
   WHERE n BETWEEN 1 AND 17000),
s AS MATERIALIZED (
  SELECT a.*,
         CASE WHEN n BETWEEN 13 AND 16000 AND NOT n BETWEEN 14601 AND 14608
                   AND pg_temp.vc_u(n, 75) < 0.06
                   AND a.r + interval '31 days' < load_epoch
              THEN a.r + interval '30 days'
                   + pg_temp.vc_u(n, 76) * (load_epoch - interval '1 day' - a.r - interval '30 days') END AS sale,
         CASE WHEN n BETWEEN 14609 AND 16000 AND (202 + (n * 37) % 700) >= 302 AND pg_temp.vc_u(n, 77) < 0.5
              THEN 202 + n % 100 END AS keeper,
         CASE WHEN n >= 14601 THEN 202 + (n * 53 + 17) % 700 ELSE 902 + (n * 47 + 3) % 5099 END AS o2
    FROM a),
t AS MATERIALIZED (SELECT s.*, CASE WHEN s.sale < coalesce(s.died, 'infinity') THEN s.sale END AS sold FROM s)
SELECT o1, 'owner', r, sold FROM t
UNION ALL
SELECT keeper, 'keeper', r, sold FROM t WHERE keeper IS NOT NULL
UNION ALL
SELECT CASE WHEN o2 = o1 THEN o2 + 1 ELSE o2 END, 'owner', sold, NULL FROM t WHERE sold IS NOT NULL
$$;

-- referring vet v's practice: two vets a practice.
CREATE FUNCTION pg_temp.core_referring_practice(v integer) RETURNS integer
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (v + 1) / 2 WHERE v BETWEEN 1 AND 800 $$;

-- A patient of a section at time t: the first of six drawn by the salt that
-- is registered an hour before t and alive at t; never a teaching animal.
CREATE FUNCTION pg_temp.vc_patient(section integer, t timestamptz, load_epoch timestamptz,
                                   utc_offset integer, salt bigint) RETURNS integer
  LANGUAGE sql IMMUTABLE AS $$
SELECT c.a FROM generate_series(0, 5) AS g, pg_temp.vc_pool(section) AS p,
       LATERAL (SELECT p.lo + floor((p.hi - p.lo + 1) * pg_temp.vc_u(salt * 8 + g, 51))::integer AS a) AS c
 WHERE pg_temp.vc_registered(c.a, load_epoch, utc_offset) < t - interval '1 hour'
   AND NOT EXISTS (SELECT 1 FROM pg_temp.core_death(c.a, load_epoch, utc_offset) AS d WHERE d.died_at <= t)
 LIMIT 1
$$;

-- --- Consultations -------------------------------------------------------------

-- The agenda (D408, D410): the half-hour slot (on the hour or the half-hour,
-- local) holding local time t.
CREATE FUNCTION pg_temp.vc_slot(t timestamp) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT date_trunc('hour', t) + CASE WHEN extract(minute FROM t) >= 30 THEN interval '30 minutes'
                                       ELSE interval '0' END $$;

-- A section's consultation spaces: domestic the consulting rooms 1-4, horse
-- the stalls 8, 9 and the arena 10, farm the crush 12 and theatre 13.
CREATE FUNCTION pg_temp.vc_spaces(section integer) RETURNS integer
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT CASE section WHEN 3 THEN 4 WHEN 1 THEN 3 WHEN 2 THEN 2 END $$;

-- Slot s0's scheduled consultations: the ids of the slot (vc_before at its
-- start and end) whose kind and section draw (core_consultation's, by u1
-- among the hour's rates) is scheduled, each with its rank in its section
-- in id order (0 first). The draws alone: no time, no patient computed.
CREATE FUNCTION pg_temp.vc_slot_rank(s0 timestamp, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (c integer, sec integer, rk integer)
  LANGUAGE sql IMMUTABLE STRICT AS $$
WITH r AS MATERIALIZED (
  SELECT pg_temp.vc_before(s0, 589, pg_temp.vc_shape('consult'), load_epoch, utc_offset) AS lo,
         pg_temp.vc_before(s0 + interval '30 minutes', 589, pg_temp.vc_shape('consult'), load_epoch, utc_offset) AS hi,
         pg_temp.vc_rate('sched-domestic', dow, h) AS sd, pg_temp.vc_rate('sched-horse', dow, h) AS sh,
         pg_temp.vc_rate('sched-farm', dow, h) AS sf, pg_temp.vc_weight('consult', dow, h) AS w
    FROM (SELECT extract(isodow FROM s0)::integer AS dow, extract(hour FROM s0)::integer AS h) AS a)
SELECT y.c, y.sec, (row_number() OVER (PARTITION BY y.sec ORDER BY y.c) - 1)::integer
  FROM (SELECT g::integer AS c,
               CASE WHEN x < r.sd THEN 3 WHEN x < r.sd + r.sh THEN 1 WHEN x < r.sd + r.sh + r.sf THEN 2 END AS sec
          FROM r, generate_series(r.lo + 1, least(r.hi, 25000)) AS g,
               LATERAL (SELECT r.w * pg_temp.vc_u(g, 1) AS x) AS z) AS y
 WHERE y.sec IS NOT NULL
$$;

-- Slot s0's vets by section: the section's vets on a day shift covering the
-- whole slot with no absence, in an order hashed by the slot (u23).
CREATE FUNCTION pg_temp.vc_slot_vets(s0 timestamp) RETURNS TABLE (sec integer, vets integer[])
  LANGUAGE sql IMMUTABLE STRICT AS $$
SELECT x.sec, array_agg(x.v ORDER BY pg_temp.vc_u((extract(epoch FROM s0)::bigint / 1800) * 32 + x.v, 23), x.v)
  FROM pg_temp.vc_vet_shifts(s0::date) AS x
 WHERE x.kind = 'day' AND NOT x.absent AND x.s <= s0 AND x.e >= s0 + interval '30 minutes'
 GROUP BY x.sec
$$;

-- A placed scheduled consultation's start and close from its drawn local
-- time t: started in its slot's first five minutes, at a sixth of its drawn
-- offset in the slot (so the slot keeps its id order), closed 25 minutes
-- after its start or later (u6) and by the slot's end.
CREATE FUNCTION pg_temp.vc_slot_times(t timestamp, n integer) RETURNS TABLE (s timestamp, e timestamp)
  LANGUAGE sql IMMUTABLE AS $$
SELECT st, st + interval '25 minutes' + pg_temp.vc_u(n, 6) * (s0 + interval '5 minutes' - st)
  FROM (SELECT s0, s0 + (t - s0) / 6 AS st FROM (SELECT pg_temp.vc_slot(t) AS s0) AS a) AS b
$$;

-- Slot s0's agenda: its placed scheduled consultations, the section's of
-- rank rk taking the slot's vet rk + 1 while rk is below both the slot's
-- vets and the section's spaces; past that, the agenda is full (no row).
CREATE FUNCTION pg_temp.vc_agenda(s0 timestamp, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (c integer, sec integer, vet integer, started timestamp, closed timestamp)
  LANGUAGE sql IMMUTABLE STRICT AS $$
WITH q AS MATERIALIZED (SELECT * FROM pg_temp.vc_slot_rank(s0, load_epoch, utc_offset)),
v AS MATERIALIZED (SELECT * FROM pg_temp.vc_slot_vets(s0) WHERE EXISTS (SELECT 1 FROM q))
SELECT q.c, q.sec, v.vets[q.rk + 1], tt.s, tt.e
  FROM q JOIN v ON v.sec = q.sec,
       LATERAL (SELECT pg_temp.vc_cal(q.c, 589, pg_temp.vc_shape('consult'), load_epoch, utc_offset) AS t OFFSET 0) AS ct,
       LATERAL pg_temp.vc_slot_times(ct.t, q.c) AS tt
 WHERE q.rk < least(cardinality(v.vets), pg_temp.vc_spaces(q.sec)) AND ct.t IS NOT NULL
$$;

-- An unbooked consultation's vet (emergency, in hospital, herd visit) from
-- local time t to its close e: a vet on shift at t with no absence (as
-- vc_vet_at's) and no placed scheduled consultation over t to e, of the
-- section first, else any section vet, drawn by the salt (vc_vet_at's
-- hashes); when there is none, vc_vet_at's draw.
CREATE FUNCTION pg_temp.vc_free_vet(section integer, t timestamp, e timestamp, load_epoch timestamptz,
                                    utc_offset integer, salt bigint)
  RETURNS integer LANGUAGE sql IMMUTABLE AS $$
WITH busy AS MATERIALIZED (
  SELECT a.vet FROM generate_series(pg_temp.vc_slot(t), e, interval '30 minutes') AS s0,
                    LATERAL pg_temp.vc_agenda(s0, load_epoch, utc_offset) AS a
   WHERE a.started < e AND a.closed > t),
on_shift AS MATERIALIZED (
  SELECT x.v, x.sec FROM (SELECT y.v, y.sec, y.s, y.e, y.absent FROM pg_temp.vc_vet_shifts(t::date) AS y
                          UNION ALL  -- the night started the day before (vc_vet_shifts' night row)
                          SELECT nv, CASE WHEN nv <= 10 THEN 1 WHEN nv <= 17 THEN 2 ELSE 3 END,
                                 t::date - 1 + time '20:00', t::date + time '08:00', false
                            FROM (SELECT pg_temp.vc_night_vet(t::date - 1) AS nv) AS z) AS x
   WHERE x.s <= t AND t < x.e AND NOT x.absent AND x.v NOT IN (SELECT vet FROM busy))
SELECT coalesce((SELECT v FROM on_shift WHERE sec = section ORDER BY pg_temp.vc_u(salt * 32 + v, 21) LIMIT 1),
                (SELECT v FROM on_shift ORDER BY pg_temp.vc_u(salt * 32 + v, 22) LIMIT 1),
                pg_temp.vc_vet_at(section, t, utc_offset, salt))
$$;

-- consultation n (1-25 000 in drawn-time order, 589 a week at 1.0, 84 a
-- day): its kind and section drawn among the streams' rates at its hour; a
-- scheduled one on the agenda (D408): in its slot, placed by its rank among
-- the slot's scheduled ones of its section (vc_agenda's rule), its vet the
-- slot's of that rank, started and closed in the slot (vc_slot_times), no
-- row when the agenda is full; its booking_id its own id (D317), one in five
-- carrying a referral (referral_id its own id), an emergency one in ten; an
-- in-hospital one on a stay current then (else an emergency); a herd visit
-- on a herd; an unbooked one's vet vc_free_vet's, closed 25 to 45 minutes
-- after its start; signed within the day, a night's the next morning. Times
-- null after T0.
CREATE FUNCTION pg_temp.core_consultation(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (kind text, section_id integer, vet_id integer, animal_id integer, herd_id integer,
                 stay_id integer, referral_id integer, started_at timestamptz, closed_at timestamptz,
                 signed_at timestamptz, booking_id integer)
  LANGUAGE sql IMMUTABLE AS $$
WITH k AS MATERIALIZED (SELECT t, extract(isodow FROM t)::integer AS dow, extract(hour FROM t)::integer AS h
             FROM (SELECT pg_temp.vc_cal(n, 589, pg_temp.vc_shape('consult'), load_epoch, utc_offset) AS t) AS a
            WHERE t IS NOT NULL AND n BETWEEN 1 AND 25000),
w AS MATERIALIZED (SELECT k.t, pg_temp.vc_rate('sched-domestic', dow, h) AS sd, pg_temp.vc_rate('sched-horse', dow, h) AS sh,
             pg_temp.vc_rate('sched-farm', dow, h) AS sf, pg_temp.vc_rate('emergency', dow, h) AS em,
             pg_temp.vc_rate('in-hospital', dow, h) AS ih,
             pg_temp.vc_weight('consult', dow, h) * pg_temp.vc_u(n, 1) AS x FROM k),
d AS MATERIALIZED (SELECT t, CASE WHEN x < sd + sh + sf THEN 'scheduled' WHEN x < sd + sh + sf + em THEN 'emergency'
                     WHEN x < sd + sh + sf + em + ih THEN 'in-hospital' ELSE 'herd-visit' END AS kd,
             CASE WHEN x < sd THEN 3 WHEN x < sd + sh THEN 1 WHEN x < sd + sh + sf THEN 2
                  WHEN x < sd + sh + sf + em THEN CASE WHEN pg_temp.vc_u(n, 2) < 0.65 THEN 3
                                                       WHEN pg_temp.vc_u(n, 2) < 0.90 THEN 1 ELSE 2 END
                  ELSE 2 END AS sec
        FROM w),
a AS MATERIALIZED (SELECT d.*, ag.vet AS a_vet, ag.st AS a_start, ag.cl AS a_close
        FROM d LEFT JOIN LATERAL (
               SELECT vv.vets[rr.rk + 1] AS vet, tt.s AS st, tt.e AS cl
                 FROM pg_temp.vc_slot_rank(pg_temp.vc_slot(d.t), load_epoch, utc_offset) AS rr,
                      pg_temp.vc_slot_vets(pg_temp.vc_slot(d.t)) AS vv,
                      pg_temp.vc_slot_times(d.t, n) AS tt
                WHERE d.kd = 'scheduled' AND rr.c = n AND vv.sec = rr.sec
                  AND rr.rk < least(cardinality(vv.vets), pg_temp.vc_spaces(rr.sec))) AS ag ON true
       WHERE d.kd <> 'scheduled' OR ag.vet IS NOT NULL),
s AS MATERIALIZED (SELECT a.*,
             CASE WHEN kd = 'in-hospital' THEN
               (SELECT c.sn FROM (SELECT pg_temp.vc_before(a.t - interval '7 days', 58, pg_temp.vc_shape('stay'), load_epoch, utc_offset) AS lo,
                                         pg_temp.vc_before(a.t, 58, pg_temp.vc_shape('stay'), load_epoch, utc_offset) AS hi) AS r,
                                 generate_series(0, 7) AS g,
                                 LATERAL (SELECT (r.lo + 1 + floor((r.hi - r.lo) * pg_temp.vc_u(n * 8 + g, 3)))::integer AS sn) AS c,
                                 LATERAL pg_temp.core_stay(c.sn, load_epoch, utc_offset) AS st
                 WHERE r.hi > r.lo AND st.admitted_at <= pg_temp.vc_utc(a.t, utc_offset) - interval '1 hour'
                   AND coalesce(st.discharged_at, 'infinity') > pg_temp.vc_utc(a.t, utc_offset)
                 LIMIT 1) END AS stay
        FROM a),
f AS MATERIALIZED (SELECT coalesce(s.a_start, s.t) AS t, s.a_vet, s.a_close,
             CASE WHEN kd = 'in-hospital' AND stay IS NULL THEN 'emergency' ELSE kd END AS kind,
             st.section_id AS stay_sec, st.animal_id AS stay_animal, s.sec, s.stay
        FROM s LEFT JOIN LATERAL pg_temp.core_stay(s.stay, load_epoch, utc_offset) AS st ON s.stay IS NOT NULL),
g AS MATERIALIZED (SELECT f.t, f.kind, coalesce(f.stay_sec, f.sec) AS sec, f.stay, f.a_vet,
             CASE WHEN f.kind = 'herd-visit' THEN NULL
                  WHEN f.stay IS NOT NULL THEN f.stay_animal
                  ELSE pg_temp.vc_patient(f.sec, pg_temp.vc_utc(f.t, utc_offset), load_epoch, utc_offset, n) END AS animal,
             CASE WHEN f.kind = 'herd-visit' THEN 1 + floor(200 * pg_temp.vc_u(n, 5))::integer END AS herd,
             coalesce(f.a_close, f.t + (25 + 20 * pg_temp.vc_u(n, 6)) * interval '1 minute') AS closed
        FROM f)
SELECT g.kind, g.sec, coalesce(g.a_vet, pg_temp.vc_free_vet(g.sec, g.t, g.closed, load_epoch, utc_offset, n)),
       g.animal, g.herd, g.stay,
       CASE WHEN (g.kind = 'scheduled' AND pg_temp.vc_u(n, 7) < 0.21) OR (g.kind = 'emergency' AND pg_temp.vc_u(n, 7) < 0.10)
            THEN n END,
       pg_temp.vc_utc(g.t, utc_offset),
       CASE WHEN g.closed < pg_temp.vc_local(load_epoch, utc_offset) THEN pg_temp.vc_utc(g.closed, utc_offset) END,
       CASE WHEN x.sg < pg_temp.vc_local(load_epoch, utc_offset) THEN pg_temp.vc_utc(x.sg, utc_offset) END,
       CASE WHEN g.kind = 'scheduled' THEN n END
  FROM g, LATERAL (SELECT CASE WHEN extract(hour FROM g.closed) BETWEEN 8 AND 19
                               THEN least(g.closed + (0.5 + 3 * pg_temp.vc_u(n, 8)) * interval '1 hour',
                                          date_trunc('day', g.closed) + interval '21 hours')
                               WHEN extract(hour FROM g.closed) < 8
                               THEN date_trunc('day', g.closed) + interval '8 hours' + 2 * pg_temp.vc_u(n, 8) * interval '1 hour'
                               ELSE date_trunc('day', g.closed) + interval '32 hours' + 2 * pg_temp.vc_u(n, 8) * interval '1 hour'
                          END AS sg) AS x
 WHERE g.kind = 'herd-visit' OR g.animal IS NOT NULL
$$;

-- --- Requests ---------------------------------------------------------------------

-- The latest herd visit of herd h on a local day at or before d (D389),
-- searched over the 16 weeks before: the herd visits fall on Tuesday and
-- Thursday 08:00-12:59, so each hour's consultation ids are known by
-- vc_before, and a consultation is a herd visit when its kind draw passes
-- the other streams' rates at that hour (core_consultation's rule).
CREATE FUNCTION pg_temp.vc_herd_visit_on(h integer, d date, load_epoch timestamptz, utc_offset integer)
  RETURNS date LANGUAGE sql IMMUTABLE AS $$
WITH dd AS MATERIALIZED (SELECT x::date AS day FROM generate_series(d - 111, d, interval '1 day') AS x
                          WHERE extract(isodow FROM x) IN (2, 4)),
hb AS MATERIALIZED (SELECT dd.day, hh,
                           pg_temp.vc_before(dd.day + hh * interval '1 hour', 589, pg_temp.vc_shape('consult'),
                                             load_epoch, utc_offset) AS lo,
                           pg_temp.vc_before(dd.day + (hh + 1) * interval '1 hour', 589, pg_temp.vc_shape('consult'),
                                             load_epoch, utc_offset) AS hi,
                           1 - pg_temp.vc_rate('herd-visit', extract(isodow FROM dd.day)::integer, hh)
                               / pg_temp.vc_weight('consult', extract(isodow FROM dd.day)::integer, hh) AS cut
                      FROM dd, generate_series(8, 12) AS hh)
SELECT max(hb.day) FROM hb, generate_series(hb.lo + 1, hb.hi) AS c
 WHERE hb.hi > hb.lo AND c BETWEEN 1 AND 25000
   AND pg_temp.vc_u(c, 1) >= hb.cut AND 1 + floor(200 * pg_temp.vc_u(c, 5))::integer = h
$$;

-- request n (1-17 000, in its consultation's order; D302, D375, D385, D386):
-- in every block of 40 consultation ids, 17 places write requests at their
-- close, 27 requests a block (0.675 a consultation): eleven places one,
-- three two, two three, one four, the places and their counts shuffled in
-- each block by hashes of the block's number (u94, u95). A one-request place
-- is an imaging study when u81 of the consultation is below 0.395 domestic,
-- 0.68 horse, 0.41 farm (one consultation in eight, the imaging mix about
-- 60/30/10); every other request is an analysis, a consultation's analyses
-- one lab order (three consultations in ten, 1.83 tests an order). Each code
-- drawn by the catalogue's weights for the section (vet-lab "The test
-- catalogue", vet-machinery "The procedure catalogue"; D372, D373), valid for
-- the animal, distinct within the consultation (a weighted draw without
-- replacement), urgent requests (emergencies, stays) only in-house analyses
-- of 4 hours or less and never imaging 26 or 27, outside the bench's hours
-- (21:00-07:00, Sundays) only the night-capable analyses; MINH only on a
-- herd with a visit early enough for its line (D389). State at T0: of the
-- last 24 hours sent, or cancelled by the vet (2 %); older resulted, or
-- cancelled by the vet (2 %) or after sending by the part (2 %), within the
-- code's turnaround (imaging urgent 18 hours, routine 72, D376).
CREATE FUNCTION pg_temp.core_request(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (kind text, code text, consultation_id integer, animal_id integer, requested_by integer,
                 requested_at timestamptz, priority text, state text, sent_at timestamptz,
                 resulted_at timestamptz, cancelled_at timestamptz, withdrawal_ends_on date)
  LANGUAGE sql IMMUTABLE AS $$
WITH b AS MATERIALIZED (SELECT (n - 1) / 27 AS blk, (n - 1) % 27 AS r WHERE n BETWEEN 1 AND 17000),
pl AS MATERIALIZED (
  SELECT x.p, (ARRAY[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 4])
              [rank() OVER (ORDER BY pg_temp.vc_u(x.blk * 64 + x.o, 95), x.o)] AS cnt
    FROM (SELECT a.blk, a.p, (row_number() OVER (ORDER BY a.p) - 1)::integer AS o
            FROM (SELECT b.blk, p, rank() OVER (ORDER BY pg_temp.vc_u(b.blk * 64 + p, 94), p) AS rk
                    FROM b, generate_series(0, 39) AS p) AS a
           WHERE a.rk <= 17) AS x),
m AS MATERIALIZED (SELECT b.blk * 40 + q.p + 1 AS c, b.r - (q.s - q.cnt) AS j, q.cnt
        FROM b, (SELECT p, cnt, sum(cnt) OVER (ORDER BY p) AS s FROM pl) AS q
       WHERE b.r >= q.s - q.cnt AND b.r < q.s),
k AS MATERIALIZED (SELECT m.c, m.j, x.*,
             m.cnt = 1 AND pg_temp.vc_u(m.c, 81) < CASE x.section_id WHEN 1 THEN 0.68 WHEN 2 THEN 0.41 ELSE 0.395 END AS img
        FROM m, pg_temp.core_consultation(m.c::integer, load_epoch, utc_offset) AS x
       WHERE x.closed_at IS NOT NULL),
a AS MATERIALIZED (SELECT k.*,
             coalesce(k.animal_id,
                      (SELECT 16001 + (k.herd_id - 1) + 200 * ((g + floor(5 * pg_temp.vc_u(k.c, 82))::integer) % 5)
                         FROM generate_series(0, 4) AS g
                        WHERE pg_temp.vc_registered(16001 + (k.herd_id - 1) + 200 * ((g + floor(5 * pg_temp.vc_u(k.c, 82))::integer) % 5),
                                                    load_epoch, utc_offset) < k.started_at
                          AND NOT EXISTS (SELECT 1 FROM pg_temp.core_death(16001 + (k.herd_id - 1)
                                                + 200 * ((g + floor(5 * pg_temp.vc_u(k.c, 82))::integer) % 5),
                                                load_epoch, utc_offset) AS d WHERE d.died_at <= k.started_at)
                        ORDER BY g LIMIT 1)) AS animal,
             k.kind IN ('emergency', 'in-hospital') AS urgent,
             pg_temp.vc_local(k.closed_at, utc_offset) AS lt
        FROM k),
z AS MATERIALIZED (SELECT a.*, pg_temp.core_species(a.animal) AS sp,
             (SELECT an.sex FROM pg_temp.core_animal(a.animal, load_epoch, utc_offset) AS an) AS sex,
             extract(hour FROM a.lt) >= 21 OR extract(hour FROM a.lt) < 7 OR extract(isodow FROM a.lt) = 7 AS night
        FROM a WHERE a.animal IS NOT NULL),
code AS MATERIALIZED (
  SELECT z.*, CASE WHEN z.img THEN
           (SELECT i.code FROM (VALUES
              (1, 'DX-THX-S', 14, 0, 0), (2, 'DX-ABD-S', 9, 0, 0), (3, 'DX-LIMB-S', 10, 0, 0), (4, 'DX-SPN-S', 5, 0, 0),
              (5, 'US-ABD-S', 15, 0, 0), (6, 'US-ECHO-S', 7, 0, 0), (7, 'US-THX-S', 3, 0, 0), (8, 'CT-HEAD-S', 7, 0, 0),
              (9, 'CT-TAB-S', 9, 0, 0), (10, 'CT-LSP-S', 5, 0, 0), (11, 'MR-BRN-S', 4, 0, 0), (12, 'MR-SPN-S', 4, 0, 0),
              (13, 'DX-FOOT-L', 0, 10, 12), (14, 'DX-FTLK-L', 0, 8, 10), (15, 'DX-CRHK-L', 0, 7, 8), (16, 'DX-STFL-L', 0, 3, 5),
              (17, 'DX-HEAD-L', 0, 5, 6), (18, 'DX-NKBK-L', 0, 3, 4), (19, 'DX-THX-L', 0, 2, 10), (20, 'US-TEND-L', 0, 16, 6),
              (21, 'US-ABD-L', 0, 6, 9), (22, 'US-THX-L', 0, 3, 5), (23, 'US-REPR-L', 0, 5, 12), (24, 'CT-HEAD-L', 0, 3, 3),
              (25, 'CT-LIMB-L', 0, 4, 2), (26, 'MR-LIMB-H', 0, 7, 0), (27, 'NM-BONE-H', 0, 10, 0), (28, 'DX-VIEW-A', 3, 3, 3),
              (29, 'US-GUID-A', 3, 3, 3), (30, 'DX-CONT-A', 2, 2, 2)) AS i (id, code, wd, wh, wf),
                   LATERAL (SELECT CASE z.section_id WHEN 3 THEN i.wd WHEN 1 THEN i.wh ELSE i.wf END
                                   + CASE WHEN z.urgent AND z.section_id = 1 AND i.id = 13 THEN 10
                                          WHEN z.urgent AND z.section_id = 1 AND i.id = 20 THEN 7 ELSE 0 END AS w) AS ww
             WHERE ww.w > 0 AND NOT (z.urgent AND i.id IN (26, 27))
             ORDER BY ln(pg_temp.vc_u(z.c * 1000 + i.id, 83) + 1e-12) / ww.w DESC
             LIMIT 1)
         ELSE
           (SELECT t.code FROM (VALUES
              (13, 'GLU', 'any', 1, true, true, 2, 0, 0), (75, 'FNA', 'any', 24, true, false, 4, 0, 0),
              (99, 'EIA', 'horse', 24, true, false, 0, 4, 0), (114, 'MINH', 'minh', 24, true, false, 0, 0, 5),
              (115, 'HISTO', 'any', 120, false, false, 5, 3, 3), (123, 'PCRSA', 'domestic', 96, false, false, 1, 0, 0),
              (124, 'STREP', 'horse', 72, false, false, 0, 3, 0), (125, 'BVDPCR', 'cattle', 72, false, false, 0, 0, 3),
              (135, 'TT4', 'dogcat', 72, false, false, 2, 0, 0), (136, 'ACTHST', 'dog', 72, false, false, 1, 0, 0),
              (137, 'EACTH', 'horse', 72, false, false, 0, 3, 0), (145, 'PB', 'any', 120, false, false, 0, 0, 2),
              (151, 'CBC', 'any', 2, true, true, 22, 27, 18), (153, 'PCVTS', 'any', 1, true, true, 0, 5, 0),
              (154, 'PREA', 'domestic', 2, true, true, 8, 0, 0), (155, 'CHEMSA', 'domestic', 4, true, true, 14, 0, 0),
              (156, 'SENIOR', 'domestic', 4, true, true, 4, 0, 0), (157, 'RENAL', 'any', 2, true, true, 4, 0, 4),
              (158, 'LIVER', 'any', 2, true, true, 3, 0, 4), (160, 'BGAS', 'any', 1, true, true, 5, 6, 6),
              (161, 'CHEMEQ', 'horse', 4, true, true, 0, 18, 0), (162, 'COLIC', 'horse', 1, true, true, 0, 6, 0),
              (163, 'PERFEQ', 'horse', 4, true, true, 0, 4, 0), (164, 'METRU', 'farm', 4, true, true, 0, 0, 18),
              (165, 'MINRU', 'farm', 24, true, true, 0, 0, 6), (166, 'COAG', 'any', 2, true, false, 4, 2, 0),
              (167, 'UA', 'any', 2, true, false, 6, 2, 0), (168, 'UAUPC', 'domestic', 4, true, false, 2, 0, 0),
              (170, 'FEC', 'horsefarm', 24, true, false, 0, 3, 6), (171, 'CULT', 'any', 72, true, false, 3, 5, 4),
              (172, 'UCULT', 'any', 72, true, false, 3, 0, 0), (173, 'MCULT', 'farmfemale', 72, true, false, 0, 0, 10),
              (174, 'FELV', 'cat', 2, true, false, 2, 0, 0), (175, 'VECT', 'dog', 2, true, false, 2, 0, 0),
              (176, 'DIARC', 'dog', 2, true, false, 1, 0, 0), (177, 'CALFD', 'cattle', 4, true, false, 0, 0, 5),
              (178, 'FOAL', 'horse', 2, true, false, 0, 3, 0), (179, 'EFFUS', 'any', 4, true, false, 2, 6, 0),
              (180, 'HERDB', 'cattle', 48, true, false, 0, 0, 6))
                     AS t (id, code, spec, tat, inhouse, nightcap, wd, wh, wf),
                   LATERAL (SELECT CASE z.section_id WHEN 3 THEN t.wd WHEN 1 THEN t.wh ELSE t.wf END AS w) AS ww
             WHERE ww.w > 0
               AND CASE t.spec WHEN 'any' THEN true WHEN 'domestic' THEN z.section_id = 3
                               WHEN 'horse' THEN z.sp = 'horse' WHEN 'farm' THEN z.section_id = 2
                               WHEN 'horsefarm' THEN z.section_id IN (1, 2) WHEN 'cattle' THEN z.sp = 'cattle'
                               WHEN 'dog' THEN z.sp = 'dog' WHEN 'cat' THEN z.sp = 'cat'
                               WHEN 'dogcat' THEN z.sp IN ('dog', 'cat')
                               WHEN 'farmfemale' THEN z.section_id = 2 AND z.sex = 'female'
                               WHEN 'minh' THEN CASE WHEN z.sp IN ('cattle', 'goat') AND z.sex = 'female'
                                                     AND NOT z.urgent AND NOT z.night
                                                THEN pg_temp.vc_herd_visit_on(1 + (z.animal - 16001) % 200, z.lt::date - 11,
                                                                               load_epoch, utc_offset) IS NOT NULL
                                                ELSE false END
                               ELSE false END
               AND (NOT z.urgent OR (t.inhouse AND t.tat <= 4))
               AND (NOT z.night OR t.nightcap)
             ORDER BY ln(pg_temp.vc_u(z.c * 1000 + t.id, 83) + 1e-12) / ww.w DESC
             OFFSET z.j LIMIT 1) END AS cd
    FROM z),
s AS MATERIALIZED (SELECT code.*,
             CASE WHEN img THEN CASE WHEN urgent THEN 18 ELSE 72 END
                  ELSE (SELECT t.tat FROM (VALUES ('GLU', 1), ('FNA', 24), ('EIA', 24), ('MINH', 24), ('HISTO', 120),
                          ('PCRSA', 96), ('STREP', 72), ('BVDPCR', 72), ('TT4', 72), ('ACTHST', 72), ('EACTH', 72),
                          ('PB', 120), ('CBC', 2), ('PCVTS', 1), ('PREA', 2), ('CHEMSA', 4), ('SENIOR', 4), ('RENAL', 2),
                          ('LIVER', 2), ('BGAS', 1), ('CHEMEQ', 4), ('COLIC', 1), ('PERFEQ', 4), ('METRU', 4),
                          ('MINRU', 24), ('COAG', 2), ('UA', 2), ('UAUPC', 4), ('FEC', 24), ('CULT', 72), ('UCULT', 72),
                          ('MCULT', 72), ('FELV', 2), ('VECT', 2), ('DIARC', 2), ('CALFD', 4), ('FOAL', 2), ('EFFUS', 4),
                          ('HERDB', 48)) AS t (code, tat) WHERE t.code = code.cd) END AS tat,
             closed_at >= load_epoch - interval '24 hours' AS recent,
             pg_temp.vc_u(n, 85) AS uc,
             closed_at + least((1 + 4 * pg_temp.vc_u(n, 84)) * interval '1 minute', (load_epoch - closed_at) / 2) AS sent
        FROM code WHERE cd IS NOT NULL),
f AS MATERIALIZED (SELECT s.*,
             least(s.sent + s.tat * (0.4 + 0.5 * pg_temp.vc_u(n, 86)) * interval '1 hour'
                          + (5 + 15 * pg_temp.vc_u(n, 86)) * interval '1 minute'
                          + CASE WHEN s.img AND NOT s.urgent
                                  AND extract(isodow FROM pg_temp.vc_local(s.sent + s.tat * (0.4 + 0.5 * pg_temp.vc_u(n, 86))
                                                                           * interval '1 hour', utc_offset)) = 7
                                 THEN interval '1 day' ELSE interval '0' END,
                   load_epoch - interval '5 minutes') AS res
        FROM s)
SELECT CASE WHEN img THEN 'imaging' ELSE 'analysis' END, cd, c::integer, animal, vet_id, closed_at,
       CASE WHEN urgent THEN 'urgent' ELSE 'routine' END,
       CASE WHEN uc < 0.02 THEN 'cancelled' WHEN recent THEN 'sent' WHEN uc < 0.04 THEN 'cancelled' ELSE 'resulted' END,
       CASE WHEN uc >= 0.02 THEN sent END,
       CASE WHEN uc >= 0.04 AND NOT recent THEN res END,
       CASE WHEN uc < 0.02 THEN closed_at + least((2 + 8 * pg_temp.vc_u(n, 88)) * interval '1 minute', (load_epoch - closed_at) / 2)
            WHEN uc < 0.04 AND NOT recent THEN sent + (res - sent) * 0.3 * pg_temp.vc_u(n, 88) END,
       CASE WHEN cd = 'MINH' THEN pg_temp.vc_herd_visit_on(1 + (animal - 16001) % 200, lt::date - 11,
                                                           load_epoch, utc_offset) + 10 END
  FROM f
$$;

-- --- Exchanges ----------------------------------------------------------------------

-- Office time (Monday to Friday 08:00-18:00, local): the office minutes
-- since Monday 2000-01-03 at local time t, and back.
CREATE FUNCTION pg_temp.vc_om(t timestamp) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT (dn / 7) * 3000.0 + CASE WHEN dn % 7 >= 5 THEN 3000
                                ELSE (dn % 7) * 600 + least(600, greatest(0, extract(epoch FROM t - t::date) / 60 - 480)) END
  FROM (SELECT t::date - date '2000-01-03' AS dn) AS a
$$;
CREATE FUNCTION pg_temp.vc_om_inv(m float8) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT date '2000-01-03' + (wk * 7 + d)::integer + interval '8 hours' + (rem - d * 600) * interval '1 minute'
  FROM (SELECT wk, rem, least(4, floor(rem / 600)) AS d
          FROM (SELECT floor(m / 3000) AS wk, m - floor(m / 3000) * 3000 AS rem) AS a) AS b
$$;
-- Block k's transfer: the stay of its block of 25 that ends transferred.
CREATE FUNCTION pg_temp.vc_transfer_stay(k integer) RETURNS integer
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT 25 * k + floor(25 * pg_temp.vc_u(k, 92))::integer $$;

-- exchange n (1-700, D306, D390): in blocks of seven around the transfers,
-- in requested_at order. Block k's fourth (n mod 7 = 3, from 0) is the
-- transfer of block k's transferred stay, asked a day after its admission;
-- the six examinations between two transfer requests (block k's last three,
-- block k + 1's first three) are drawn in that interval's office hours
-- (Monday to Friday 08:00-18:00), each in its sixth of the office time, so
-- the ids stay in time order; the second, sixth (and in even blocks the
-- seventh) outbound, the others inbound; none where the interval holds no
-- office time (a weekend between two transfers). An outbound exchange is sent
-- within minutes; the partner answers within a working day, an examination
-- declined one in ten, accepted for 1 to 10 days later, reported 1 to 3
-- days after. An inbound one's animal is the partner's (partner_patient),
-- not registered here. Its reason (D413): a transfer's, or an examination's
-- drawn by u393 among six; an inbound one's partner patient's species by
-- u391 among four; the values load.sql writes in exchanges.reason and
-- partner_patient.
CREATE FUNCTION pg_temp.core_exchange(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (direction text, kind text, site_id integer, animal_id integer, stay_id integer,
                 exchange_key uuid, requested_at timestamptz, sent_at timestamptz, state text, answer text,
                 accepted_for date, answered_at timestamptz, reported_at timestamptz, reason text,
                 partner_species text)
  LANGUAGE sql IMMUTABLE AS $$
WITH b AS MATERIALIZED (SELECT (n - 1) / 7 AS k, (n - 1) % 7 AS r WHERE n BETWEEN 1 AND 700),
an AS MATERIALIZED (SELECT b.*,
              pg_temp.vc_cal(pg_temp.vc_transfer_stay(k), 58, pg_temp.vc_shape('stay'), load_epoch, utc_offset) + interval '1 day' AS a0,
              CASE WHEN r < 3 THEN pg_temp.vc_cal(pg_temp.vc_transfer_stay(k - 1), 58, pg_temp.vc_shape('stay'), load_epoch, utc_offset)
                                   + interval '1 day' END AS am,
              CASE WHEN r > 3 THEN pg_temp.vc_cal(pg_temp.vc_transfer_stay(k + 1), 58, pg_temp.vc_shape('stay'), load_epoch, utc_offset)
                                   + interval '1 day' END AS ap
         FROM b),
iv AS MATERIALIZED (SELECT an.k, an.r, an.a0,
             CASE WHEN r < 3 THEN coalesce(am, a0 - interval '3.5 days') ELSE a0 END AS lo,
             CASE WHEN r < 3 THEN a0 ELSE coalesce(ap, a0 + interval '3.5 days') END AS hi,
             CASE WHEN r < 3 THEN r + 3 ELSE r - 4 END AS slot
        FROM an WHERE a0 IS NOT NULL AND pg_temp.vc_transfer_stay(k) BETWEEN 1 AND 2500),
o AS MATERIALIZED (SELECT iv.k, iv.r,
             CASE WHEN r = 3 THEN 'out' WHEN r IN (1, 5) OR (r = 6 AND k % 2 = 0) THEN 'out' ELSE 'in' END AS dir,
             CASE WHEN r = 3 THEN 'transfer' ELSE 'examination' END AS kd,
             CASE WHEN r = 3 THEN a0
                  WHEN pg_temp.vc_om(hi) - pg_temp.vc_om(lo) >= 6
                  THEN pg_temp.vc_om_inv(pg_temp.vc_om(lo) + (pg_temp.vc_om(hi) - pg_temp.vc_om(lo))
                                         * (slot + 0.1 + 0.8 * pg_temp.vc_u(n, 103)) / 6)
                  END AS lreq       -- no office time between the two transfers: no examination
        FROM iv),
p AS MATERIALIZED (SELECT o.*, pg_temp.vc_utc(o.lreq, utc_offset) AS req,
             CASE WHEN kd = 'transfer' THEN pg_temp.vc_utc(o.lreq + (2 + 6 * pg_temp.vc_u(pg_temp.vc_transfer_stay(k), 34)) * interval '1 hour', utc_offset)
                  ELSE pg_temp.vc_utc(o.lreq + (2 + 6 * pg_temp.vc_u(n, 104)) * interval '1 hour', utc_offset) END AS ans,
             kd = 'examination' AND pg_temp.vc_u(n, 102) < 0.1 AS declined
        FROM o),
q AS MATERIALIZED (SELECT p.*,
             CASE WHEN kd = 'transfer' THEN (pg_temp.vc_local(ans, utc_offset))::date
                  ELSE (pg_temp.vc_local(ans, utc_offset))::date + 1 + floor(9 * pg_temp.vc_u(n, 105))::integer END AS acc,
             CASE WHEN dir = 'out' THEN req + (2 + 8 * pg_temp.vc_u(n, 106)) * interval '1 minute' END AS sent
        FROM p WHERE req < load_epoch),
w AS MATERIALIZED (SELECT q.*,
             CASE WHEN kd = 'examination' AND NOT declined
                  THEN pg_temp.vc_utc(acc + (1 + floor(3 * pg_temp.vc_u(n, 107)))::integer + time '10:00'
                                      + pg_temp.vc_u(n, 108) * interval '7 hours', utc_offset) END AS rep
        FROM q)
SELECT dir, kd,
       CASE WHEN kd = 'transfer' THEN 2 + k % 5 ELSE 2 + floor(5 * pg_temp.vc_u(n, 101))::integer END,
       CASE WHEN kd = 'transfer' THEN (SELECT s.animal_id FROM pg_temp.core_stay(pg_temp.vc_transfer_stay(k), load_epoch, utc_offset) AS s)
            WHEN dir = 'out' THEN pg_temp.vc_patient(CASE WHEN pg_temp.vc_u(n, 109) < 0.6 THEN 3
                                                          WHEN pg_temp.vc_u(n, 109) < 0.9 THEN 1 ELSE 2 END,
                                                     req, load_epoch, utc_offset, n + 1000000) END,
       CASE WHEN kd = 'transfer' THEN pg_temp.vc_transfer_stay(k) END,
       md5('vet-core-exchange:' || n)::uuid,
       req,
       CASE WHEN sent < load_epoch THEN sent END,
       CASE WHEN dir = 'out' AND sent >= load_epoch THEN 'requested'
            WHEN ans >= load_epoch THEN CASE dir WHEN 'out' THEN 'sent' ELSE 'received' END
            WHEN declined THEN 'declined'
            WHEN rep < load_epoch THEN 'reported'
            ELSE 'accepted' END,
       CASE WHEN ans < load_epoch THEN CASE WHEN declined THEN 'declined' ELSE 'accepted' END END,
       CASE WHEN ans < load_epoch AND NOT declined THEN acc END,
       CASE WHEN ans < load_epoch THEN ans END,
       CASE WHEN ans < load_epoch AND rep < load_epoch THEN rep END,
       CASE WHEN kd = 'transfer' THEN 'transfer for specialist care'
            ELSE (ARRAY['CT examination', 'MRI examination', 'scintigraphy', 'second opinion', 'endoscopy',
                        'cardiology examination'])[1 + floor(6 * pg_temp.vc_u(n, 393))::integer] END,
       CASE WHEN dir = 'in' THEN (ARRAY['dog', 'cat', 'horse', 'cow'])[1 + floor(4 * pg_temp.vc_u(n, 391))::integer] END
  FROM w
$$;
