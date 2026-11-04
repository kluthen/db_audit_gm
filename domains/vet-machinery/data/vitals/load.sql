-- vet-machinery's vitals history (v0.5 master spec 9.6; vet-machinery-domain.md,
-- "The history before T0", answer 7, D377): last night's backup of the
-- monitors' central station. Runs after vitals/schema.sql, connected to
-- vitals, as postgres, the core's data/keys.sql streamed ahead of it: the
-- stays and their animals are pg_temp.core_stay and core_animal, never read
-- from clinic (D302, O197). Every other value is a hash of its ids
-- (pg_temp.m_u), never random(); docs/gm.md, "The data", documents it.
--
-- psql variables (load-data's): customer_timezone, customer_utc_offset (hours),
-- load_epoch (T0, UTC, to the minute: the load's "now", never now()).
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'vitals/load.sql: psql variable customer_timezone is not set'; END $$;
\endif
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'vitals/load.sql: psql variable customer_utc_offset is not set'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'vitals/load.sql: psql variable load_epoch is not set'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.core_stay(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'vitals/load.sql: the core''s key functions are missing (gmctl load-data streams '
                        'vet-core''s data/keys.sql ahead of this file, in the same session)';
    END IF;
END $$;

CREATE FUNCTION pg_temp.m_u(x bigint, salt integer) RETURNS float8
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, salt) & 2147483647)::float8 / 2147483648 $$;
CREATE FUNCTION pg_temp.m_utc(t timestamp, o integer) RETURNS timestamptz
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - make_interval(hours => o)) AT TIME ZONE 'UTC' $$;
-- The first multiple of `step` seconds (on the UTC epoch) at or after t.
CREATE FUNCTION pg_temp.m_ceil(t timestamptz, step integer) RETURNS timestamptz
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT to_timestamp(ceil(extract(epoch FROM t) / step) * step) $$;
-- A measure about its baseline at t: a slow swing and a hash's jitter.
CREATE FUNCTION pg_temp.m_v(base float8, sid integer, t timestamptz, salt integer) RETURNS float8
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT base * (1 + 0.05 * sin(extract(epoch FROM t) / 900 + sid + salt)
                  + 0.06 * (pg_temp.m_u(extract(epoch FROM t)::bigint * 64 + sid % 64, salt) - 0.5)) $$;

-- T0 and the customer's calendar, as biomed's: s the history's start (the
-- core's), w0 the window's start (yesterday 00:00 local).
CREATE TEMP TABLE l_env AS
SELECT e, o, tl, tl::date AS today, date_trunc('week', tl) - interval '364 days' AS s,
       ((tl::date - 1)::timestamp - make_interval(hours => o)) AT TIME ZONE 'UTC' AS w0
  FROM (SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
               (:'load_epoch'::timestamptz AT TIME ZONE 'UTC')
                 + make_interval(hours => :customer_utc_offset::integer) AS tl) AS x;

INSERT INTO mach_vitals_settings (timezone, utc_offset_hours) VALUES (:'customer_timezone', :customer_utc_offset);

-- The partitions, yesterday to today plus three, created as mach.
SELECT today AS m_today FROM l_env \gset
SET ROLE mach;
SELECT count(*) FILTER (WHERE mach_partition_day(:'m_today'::date + i)) AS vitals_partitions
  FROM generate_series(-1, 3) AS i;
RESET ROLE;

-- --- The core's stays and their animals ---------------------------------------------

CREATE TEMP TABLE l_s AS
SELECT n AS id, s.animal_id, s.section_id, s.admitted_at, s.discharged_at, a.name, a.species
  FROM generate_series(1, 2500) AS n,
       pg_temp.core_stay(n, :'load_epoch', :customer_utc_offset) AS s,
       pg_temp.core_animal(s.animal_id, :'load_epoch', :customer_utc_offset) AS a;
CREATE INDEX ON l_s (admitted_at);
ANALYZE l_s;

-- --- Sessions (answer 7, D377) ----------------------------------------------------------

-- The candidates in time order. Intensive care: the stays a hash picks (one
-- domestic in two, one horse in four, no farm stay), from the first census
-- after admission until the step-down, 24 to 72 hours after admission, or
-- the census after the stay ends. Anaesthesia: about ten a weekday in theatre
-- hours (08:00-18:00), ramping from 0.6 a year ago (D279), and one a night,
-- each 90 minutes plus up to an hour.
CREATE TEMP TABLE l_cand AS
SELECT 'icu' AS kind, pg_temp.m_ceil(s.admitted_at + interval '1 second', 300) AS t, s.id AS stay_id,
       s.id::bigint AS key, s.admitted_at + (24 + 48 * pg_temp.m_u(s.id, 542)) * interval '1 hour' AS step_down,
       pg_temp.m_ceil(s.discharged_at + interval '1 second', 300) AS gone
  FROM l_s AS s
 WHERE (s.section_id = 3 AND pg_temp.m_u(s.id, 541) < 0.5) OR (s.section_id = 1 AND pg_temp.m_u(s.id, 541) < 0.25)
UNION ALL
SELECT 'anaesthesia', t, NULL, key, t + (90 + 60 * pg_temp.m_u(key, 544)) * interval '1 minute', NULL
  FROM (SELECT pg_temp.m_ceil(pg_temp.m_utc(c.d + CASE WHEN k = 0
                       THEN interval '21 hours' + pg_temp.m_u(c.key, 543) * interval '9 hours'
                       ELSE interval '8 hours' + (k - 1) * interval '1 minute' * (540.0 / c.n)
                            + pg_temp.m_u(c.key + k, 543) * interval '30 minutes' END, env.o), 60) AS t,
               c.key + k AS key
          FROM l_env AS env,
               generate_series(env.s::date, env.today, interval '1 day') AS dd,
               LATERAL (SELECT dd::date AS d, (dd::date - date '2000-01-03')::bigint * 100 AS key,
                               CASE WHEN extract(isodow FROM dd) <= 5
                                    THEN round(10 * (0.6 + 0.4 * (dd::date - env.s::date)::float8
                                                     / greatest(env.today - env.s::date, 1)))::integer
                                    ELSE 0 END AS n) AS c,
               generate_series(0, c.n) AS k) AS a, l_env AS env
 WHERE t < env.e;
CREATE INDEX ON l_cand (t);

CREATE TEMP TABLE l_sess (seq serial, machine_id integer, kind text, stay_id integer, started_at timestamptz,
                          ended_at timestamptz, ended_by text);
CREATE INDEX ON l_sess (stay_id);

DO $$
DECLARE
    env record;
    c record;
    busy timestamptz[] := array_fill('-infinity'::timestamptz, ARRAY[28]);
    m integer;
    st record;
    fin timestamptz;
    how text;
BEGIN
    SELECT * INTO env FROM l_env;
    FOR c IN SELECT * FROM l_cand ORDER BY t, kind DESC, key LOOP
        m := NULL;
        IF c.kind = 'icu' THEN
            SELECT * INTO st FROM l_s WHERE id = c.stay_id;
            IF c.gone IS NOT NULL AND c.gone <= c.step_down THEN
                fin := c.gone; how := 'census';
            ELSE
                fin := c.step_down; how := 'staff';
            END IF;
            SELECT i INTO m FROM generate_series(CASE st.section_id WHEN 3 THEN 21 ELSE 27 END,
                                                 CASE st.section_id WHEN 3 THEN 26 ELSE 28 END) AS i
             WHERE busy[i] <= c.t ORDER BY i LIMIT 1;
        ELSE
            fin := c.step_down; how := 'staff';
            SELECT s.* INTO st FROM l_s AS s
             WHERE s.admitted_at <= c.t - interval '30 minutes' AND s.admitted_at > c.t - interval '8 days'
               AND coalesce(s.discharged_at, 'infinity') > fin
               AND NOT EXISTS (SELECT 1 FROM l_sess AS x WHERE x.stay_id = s.id
                                  AND x.started_at <= c.t AND coalesce(x.ended_at, 'infinity') > c.t)
             ORDER BY pg_temp.m_u(c.key * 4096 + s.id, 545), s.id LIMIT 1;
            IF FOUND THEN
                SELECT i INTO m FROM unnest(CASE WHEN st.section_id = 3
                                                 THEN CASE WHEN pg_temp.m_u(c.key, 546) < 0.12 THEN ARRAY[20]
                                                           ELSE ARRAY[17, 18] END
                                                 ELSE ARRAY[19] END) AS i
                 WHERE busy[i] <= c.t ORDER BY i LIMIT 1;
            END IF;
        END IF;
        IF m IS NOT NULL AND fin > c.t THEN
            IF fin >= env.e THEN
                fin := NULL; how := NULL;
            END IF;
            busy[m] := coalesce(fin, 'infinity');
            INSERT INTO l_sess (machine_id, kind, stay_id, started_at, ended_at, ended_by)
            VALUES (m, c.kind, st.id, c.t, fin, how);
        END IF;
    END LOOP;
END $$;

INSERT INTO mach_sessions (id, machine_id, kind, stay_id, animal_id, animal_name, species, weight_kg, started_at,
                           started_by, ended_at, ended_by)
SELECT row_number() OVER (ORDER BY x.started_at, x.seq), x.machine_id, x.kind, x.stay_id, s.animal_id, s.name,
       s.species,
       round((w.lo + (w.hi - w.lo) * pg_temp.m_u(s.animal_id, 547))::numeric, 1),
       x.started_at,
       CASE WHEN x.kind = 'icu' THEN CASE s.section_id WHEN 3 THEN 43 + floor(9 * pg_temp.m_u(x.seq, 548))::integer
                                                       ELSE 29 + floor(8 * pg_temp.m_u(x.seq, 548))::integer END
            WHEN s.section_id = 3 THEN 21
            ELSE (ARRAY[4, 10])[1 + floor(2 * pg_temp.m_u(x.seq, 548))::integer] END,
       x.ended_at, x.ended_by
  FROM l_sess AS x JOIN l_s AS s ON s.id = x.stay_id,
       LATERAL (SELECT CASE s.species WHEN 'dog' THEN 4 WHEN 'cat' THEN 3 WHEN 'rabbit' THEN 1 WHEN 'ferret' THEN 0.6
                                      WHEN 'horse' THEN 350 WHEN 'cattle' THEN 250 WHEN 'sheep' THEN 40 ELSE 30 END AS lo,
                       CASE s.species WHEN 'dog' THEN 45 WHEN 'cat' THEN 7 WHEN 'rabbit' THEN 3 WHEN 'ferret' THEN 2
                                      WHEN 'horse' THEN 650 WHEN 'cattle' THEN 750 WHEN 'sheep' THEN 90 ELSE 80 END AS hi) AS w
 ORDER BY x.started_at, x.seq;
SELECT setval(pg_get_serial_sequence('mach_sessions', 'id'), greatest((SELECT max(id) FROM mach_sessions), 1));

-- Each session's baselines by species, lower under anaesthesia; end-tidal
-- CO2 under anaesthesia only.
CREATE TEMP TABLE l_base AS
SELECT x.id, x.kind, x.started_at, least(coalesce(x.ended_at, env.e), env.e) AS until_at,
       b.hr * CASE WHEN x.kind = 'anaesthesia' THEN 0.85 ELSE 1 END AS hr,
       b.rr * CASE WHEN x.kind = 'anaesthesia' THEN 0.7 ELSE 1 END AS rr,
       CASE WHEN x.kind = 'anaesthesia' THEN 40 END AS etco2, b.sys, b.dia, b.temp
  FROM l_env AS env, mach_sessions AS x,
       LATERAL (SELECT * FROM (VALUES ('dog', 90, 18, 125, 75, 38.5), ('cat', 170, 28, 130, 80, 38.6),
                                      ('rabbit', 200, 45, 110, 70, 38.8), ('ferret', 220, 35, 120, 75, 38.8),
                                      ('horse', 38, 12, 115, 70, 37.8), ('cattle', 70, 25, 130, 85, 38.8),
                                      ('sheep', 80, 25, 120, 80, 39.2), ('goat', 85, 25, 120, 80, 39.2))
                         AS v (species, hr, rr, sys, dia, temp) WHERE v.species = x.species) AS b;

-- --- The raw vitals: the window only (the last full day and today) ----------------

-- A row every 10 seconds per open session, on the UTC minute's grid, within
-- [w0, T0): so a day's count is the 10-second ticks of each session's
-- interval that day (docs/gm.md, "A history day's rows").
INSERT INTO mach_vitals (session_id, at, heart_rate, resp_rate, spo2, etco2, systolic, diastolic, mean_bp,
                         temperature)
SELECT b.id, t, round(pg_temp.m_v(b.hr, b.id, t, 551)), round(pg_temp.m_v(b.rr, b.id, t, 552)),
       least(100, round(pg_temp.m_v(97, b.id, t, 553) * 0.4 + 58)),
       round(pg_temp.m_v(b.etco2, b.id, t, 554)),
       round(pg_temp.m_v(b.sys, b.id, t, 555)), round(pg_temp.m_v(b.dia, b.id, t, 556)),
       round((2 * pg_temp.m_v(b.dia, b.id, t, 556) + pg_temp.m_v(b.sys, b.id, t, 555)) / 3),
       round((b.temp + 0.3 * sin(extract(epoch FROM t) / 3600 + b.id))::numeric, 1)
  FROM l_env AS env, l_base AS b,
       generate_series(pg_temp.m_ceil(greatest(b.started_at, env.w0), 10), b.until_at - interval '1 microsecond',
                       interval '10 seconds') AS t
 WHERE b.until_at > env.w0
 ORDER BY t, b.id;

-- --- The chart (kept five years) and the alarms ---------------------------------------

-- Every 5 minutes under anaesthesia, every hour in intensive care, at each
-- interval's end within the session: the measures' mean about the session's
-- baselines at the interval's middle, its min and max a spread about it.
INSERT INTO mach_vitals_chart
SELECT b.id, t,
       round(v.hr), round(v.hr * (1 - sp)), round(v.hr * (1 + sp)),
       round(v.rr), round(v.rr * (1 - sp)), round(v.rr * (1 + sp)),
       least(100, round(v.spo2)), least(100, round(v.spo2 - 2 * sp * 10)), least(100, round(v.spo2 + 1)),
       round(v.etco2), round(v.etco2 * (1 - sp)), round(v.etco2 * (1 + sp)),
       round(v.sys), round(v.sys * (1 - sp)), round(v.sys * (1 + sp)),
       round(v.dia), round(v.dia * (1 - sp)), round(v.dia * (1 + sp)),
       round((2 * v.dia + v.sys) / 3), round((2 * v.dia + v.sys) / 3 * (1 - sp)), round((2 * v.dia + v.sys) / 3 * (1 + sp)),
       round(v.temp::numeric, 1), round((v.temp - 0.2)::numeric, 1), round((v.temp + 0.2)::numeric, 1)
  FROM l_base AS b,
       LATERAL (SELECT CASE b.kind WHEN 'anaesthesia' THEN 300 ELSE 3600 END AS step) AS k,
       generate_series(pg_temp.m_ceil(b.started_at + interval '1 second', k.step), b.until_at,
                       k.step * interval '1 second') AS t,
       LATERAL (SELECT 1 FROM l_env AS env WHERE t < env.e) AS before_t0,
       LATERAL (SELECT t - k.step * interval '0.5 second' AS mid,
                       0.04 + 0.04 * pg_temp.m_u(extract(epoch FROM t)::bigint * 64 + b.id % 64, 561) AS sp) AS q,
       LATERAL (SELECT pg_temp.m_v(b.hr, b.id, q.mid, 551) AS hr, pg_temp.m_v(b.rr, b.id, q.mid, 552) AS rr,
                       pg_temp.m_v(97, b.id, q.mid, 553) * 0.4 + 58 AS spo2,
                       pg_temp.m_v(b.etco2, b.id, q.mid, 554) AS etco2, pg_temp.m_v(b.sys, b.id, q.mid, 555) AS sys,
                       pg_temp.m_v(b.dia, b.id, q.mid, 556) AS dia,
                       b.temp + 0.3 * sin(extract(epoch FROM q.mid) / 3600 + b.id) AS temp) AS v
 ORDER BY b.id, t;

-- About one alarm every two hours in intensive care, one every three under
-- anaesthesia; four in five physiological; acknowledged by a nurse of the
-- section within ten minutes (vitals.alarm.ack), none after T0.
INSERT INTO mach_alarms (id, session_id, at, priority, kind, parameter, value, acknowledged_at, acknowledged_by)
SELECT row_number() OVER (ORDER BY a.at, a.id, a.k), a.id, a.at,
       CASE WHEN a.u < 0.15 THEN 'high' WHEN a.u < 0.6 THEN 'medium' ELSE 'low' END,
       CASE WHEN a.phys THEN 'physiological' ELSE 'technical' END, a.parameter,
       CASE WHEN a.phys THEN a.value END,
       CASE WHEN a.at + a.lag < env.e THEN a.at + a.lag END,
       CASE WHEN a.at + a.lag < env.e THEN a.nurse END
  FROM l_env AS env,
       (SELECT b.id, k, x.at, x.u, x.phys, x.lag,
               CASE WHEN x.phys THEN (ARRAY['heart rate', 'SpO2', 'respiratory rate', 'blood pressure',
                                            'temperature'])[1 + floor(5 * x.v)::integer]
                    ELSE (ARRAY['leads off', 'SpO2 probe off', 'cuff error', 'battery low'])[1 + floor(4 * x.v)::integer]
               END AS parameter,
               CASE floor(5 * x.v)::integer WHEN 0 THEN round(b.hr * 1.4)::text || ' bpm' WHEN 1 THEN '88 %'
                    WHEN 2 THEN round(b.rr * 1.6)::text || ' /min' WHEN 3 THEN round(b.sys * 0.65)::text || ' mmHg'
                    ELSE round((b.temp + 1.2)::numeric, 1)::text || ' °C' END AS value,
               CASE WHEN s.section_id = 3 THEN 43 + floor(9 * x.v)::integer ELSE 29 + floor(8 * x.v)::integer END AS nurse
          FROM l_base AS b JOIN mach_sessions AS ms ON ms.id = b.id JOIN l_s AS s ON s.id = ms.stay_id,
               generate_series(1, floor(extract(epoch FROM b.until_at - b.started_at) / 3600
                                        * CASE b.kind WHEN 'icu' THEN 0.45 ELSE 0.33 END
                                        + pg_temp.m_u(b.id, 571))::integer) AS k,
               LATERAL (SELECT b.started_at + pg_temp.m_u(b.id * 512 + k, 572) * (b.until_at - b.started_at) AS at,
                               pg_temp.m_u(b.id * 512 + k, 573) AS u, pg_temp.m_u(b.id * 512 + k, 574) < 0.8 AS phys,
                               pg_temp.m_u(b.id * 512 + k, 575) AS v,
                               (0.5 + 9.5 * pg_temp.m_u(b.id * 512 + k, 576)) * interval '1 minute' AS lag) AS x) AS a
 ORDER BY a.at, a.id, a.k;
SELECT setval(pg_get_serial_sequence('mach_alarms', 'id'), greatest((SELECT max(id) FROM mach_alarms), 1));

-- --- The census: the stays current at T0, and those that left in the window ----

INSERT INTO mach_census (stay_id, animal_id, animal_name, species, section_id, admitted_at, seen_at, left_at)
SELECT s.id, s.animal_id, s.name, s.species, s.section_id, s.admitted_at,
       CASE WHEN s.discharged_at IS NULL OR g.left_at > env.e
            THEN to_timestamp(floor(extract(epoch FROM env.e) / 300) * 300)
            ELSE g.left_at - interval '5 minutes' END,
       CASE WHEN g.left_at <= env.e THEN g.left_at END
  FROM l_env AS env, l_s AS s,
       LATERAL (SELECT pg_temp.m_ceil(s.discharged_at + interval '1 second', 300) AS left_at) AS g
 WHERE s.admitted_at < to_timestamp(floor(extract(epoch FROM env.e) / 300) * 300)
   AND (s.discharged_at IS NULL OR s.discharged_at >= env.w0)
 ORDER BY s.id;

-- --- The load's own checks -------------------------------------------------------------

DO $$
DECLARE
    env record;
BEGIN
    SELECT * INTO env FROM l_env;
    IF EXISTS (SELECT 1 FROM mach_vitals_default) THEN
        RAISE EXCEPTION 'vitals/load.sql: rows in mach_vitals_default (a partition missing)';
    END IF;
    IF EXISTS (SELECT 1 FROM mach_sessions a JOIN mach_sessions b ON a.machine_id = b.machine_id AND a.id < b.id
                WHERE b.started_at < coalesce(a.ended_at, 'infinity') AND a.started_at < coalesce(b.ended_at, 'infinity')) THEN
        RAISE EXCEPTION 'vitals/load.sql: two sessions at once on one monitor';
    END IF;
    IF (SELECT count(*) FROM mach_sessions) > 3800 THEN
        RAISE EXCEPTION 'vitals/load.sql: % sessions, above the range 1-3 800', (SELECT count(*) FROM mach_sessions);
    END IF;
END $$;

ANALYZE;
