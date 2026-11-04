-- vet-machinery's pacs history (v0.5 master spec 9.6; vet-machinery-domain.md,
-- "The history before T0", "The procedure catalogue", D372, D373, D376):
-- last night's backup of the imaging archive and its worklist. Runs after
-- pacs/schema.sql, connected to pacs, as postgres, the core's data/keys.sql
-- streamed ahead of it: every imaging request the core sent is
-- pg_temp.core_request's, its animal core_animal's, its owner at the time
-- core_ownership's and core_owner's, never read from clinic (D302). Every
-- other value is a hash of its ids (pg_temp.m_u), never random(); docs/gm.md,
-- "The data", documents it.
--
-- psql variables (load-data's): customer_timezone, customer_utc_offset (hours),
-- load_epoch (T0, UTC, to the minute: the load's "now", never now()).
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'pacs/load.sql: psql variable customer_timezone is not set'; END $$;
\endif
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'pacs/load.sql: psql variable customer_utc_offset is not set'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'pacs/load.sql: psql variable load_epoch is not set'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.core_request(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'pacs/load.sql: the core''s key functions are missing (gmctl load-data streams '
                        'vet-core''s data/keys.sql ahead of this file, in the same session)';
    END IF;
END $$;

CREATE FUNCTION pg_temp.m_u(x bigint, salt integer) RETURNS float8
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, salt) & 2147483647)::float8 / 2147483648 $$;
CREATE FUNCTION pg_temp.m_local(t timestamptz, o integer) RETURNS timestamp
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t AT TIME ZONE 'UTC') + make_interval(hours => o) $$;
CREATE FUNCTION pg_temp.m_utc(t timestamp, o integer) RETURNS timestamptz
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - make_interval(hours => o)) AT TIME ZONE 'UTC' $$;
-- Who is on duty at t, by the core's published rota (vet-core's GM notes,
-- "The rota's pattern"): `count` people from `first`, any of them by a hash
-- in the imaging day (weekdays 08:00-18:00), the weekend's by the week
-- (first + wk mod count), the night's on-call by the day it started
-- (first + dn mod count).
CREATE FUNCTION pg_temp.m_duty(t timestamptz, o integer, first integer, count integer, salt bigint)
    RETURNS integer LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN extract(hour FROM l) BETWEEN 8 AND 17 AND extract(isodow FROM l) <= 5
            THEN first + floor(count * pg_temp.m_u(salt, 581))::integer
            WHEN extract(hour FROM l) BETWEEN 8 AND 17 THEN first + ((l::date - date '2000-01-03') / 7) % count
            ELSE first + ((l::date - CASE WHEN extract(hour FROM l) < 8 THEN 1 ELSE 0 END)
                          - date '2000-01-03') % count END
  FROM (SELECT pg_temp.m_local(t, o) AS l) AS x
$$;
-- The first imaging-day slot (Monday to Friday 08:00-17:30, on five minutes)
-- at or after t: within the day as it is, else the next weekday morning at
-- 08:00 plus a hash's hours.
CREATE FUNCTION pg_temp.m_slot(t timestamptz, o integer, salt bigint) RETURNS timestamptz
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT pg_temp.m_utc(CASE WHEN extract(isodow FROM l) <= 5 AND l::time BETWEEN time '08:00' AND time '17:30'
                          THEN date_trunc('hour', l) + floor(extract(minute FROM l) / 5) * interval '5 minutes'
                          ELSE (SELECT d::date FROM generate_series(l::date + CASE WHEN l::time < time '08:00' THEN 0 ELSE 1 END,
                                                              l::date + 4, interval '1 day') AS d
                                 WHERE extract(isodow FROM d) <= 5 ORDER BY d LIMIT 1)
                               + interval '8 hours' + floor(18 * pg_temp.m_u(salt, 582)) * interval '5 minutes' END, o)
  FROM (SELECT pg_temp.m_local(t, o) AS l) AS x
$$;

CREATE TEMP TABLE l_env AS
SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
       date_trunc('week', pg_temp.m_local(:'load_epoch'::timestamptz, :customer_utc_offset::integer))
         - interval '364 days' AS s;

INSERT INTO mach_pacs_settings (timezone, utc_offset_hours) VALUES (:'customer_timezone', :customer_utc_offset);

-- --- The procedure catalogue (D372, D373) -----------------------------------------

-- The 30 codes, and the machine each takes (domestic / horse / farm; for
-- `any` the three), which the PACS's schedule follows.
CREATE TEMP TABLE l_proc (id integer, code text, name text, modality text, grp text, body_part text, minutes integer,
                          under_ga boolean, m_dom integer, m_horse integer, m_farm integer);
INSERT INTO l_proc VALUES
    (1, 'DX-THX-S', 'thorax radiographs', 'DX', 'small', 'thorax', 15, false, 11, NULL, NULL),
    (2, 'DX-ABD-S', 'abdomen radiographs', 'DX', 'small', 'abdomen', 15, false, 11, NULL, NULL),
    (3, 'DX-LIMB-S', 'limb and joint radiographs', 'DX', 'small', 'limb', 20, false, 11, NULL, NULL),
    (4, 'DX-SPN-S', 'spine and skull radiographs', 'DX', 'small', 'spine', 20, true, 11, NULL, NULL),
    (5, 'US-ABD-S', 'abdominal ultrasound', 'US', 'small', 'abdomen', 30, false, 14, NULL, NULL),
    (6, 'US-ECHO-S', 'echocardiography', 'US', 'small', 'heart', 40, false, 14, NULL, NULL),
    (7, 'US-THX-S', 'thoracic and neck ultrasound', 'US', 'small', 'thorax', 20, false, 14, NULL, NULL),
    (8, 'CT-HEAD-S', 'head CT', 'CT', 'small', 'head', 30, true, 7, NULL, NULL),
    (9, 'CT-TAB-S', 'thorax and abdomen CT', 'CT', 'small', 'thorax and abdomen', 30, true, 7, NULL, NULL),
    (10, 'CT-LSP-S', 'limb and spine CT', 'CT', 'small', 'limb and spine', 30, true, 7, NULL, NULL),
    (11, 'MR-BRN-S', 'brain MRI', 'MR', 'small', 'brain', 60, true, 9, NULL, NULL),
    (12, 'MR-SPN-S', 'spine MRI', 'MR', 'small', 'spine', 60, true, 9, NULL, NULL),
    (13, 'DX-FOOT-L', 'foot radiographs (navicular series)', 'DX', 'large', 'foot', 30, false, NULL, 12, 13),
    (14, 'DX-FTLK-L', 'fetlock and pastern radiographs', 'DX', 'large', 'fetlock', 20, false, NULL, 12, 13),
    (15, 'DX-CRHK-L', 'carpus and hock radiographs', 'DX', 'large', 'carpus and hock', 30, false, NULL, 12, 13),
    (16, 'DX-STFL-L', 'stifle radiographs', 'DX', 'large', 'stifle', 20, false, NULL, 12, 13),
    (17, 'DX-HEAD-L', 'head, teeth and sinus radiographs', 'DX', 'large', 'head', 20, false, NULL, 12, 13),
    (18, 'DX-NKBK-L', 'neck and back radiographs', 'DX', 'large', 'neck and back', 30, false, NULL, 12, 13),
    (19, 'DX-THX-L', 'thorax radiographs (foal, calf, small ruminant)', 'DX', 'large', 'thorax', 20, false, NULL, 12, 13),
    (20, 'US-TEND-L', 'tendon and ligament ultrasound', 'US', 'large', 'tendon', 40, false, NULL, 15, 15),
    (21, 'US-ABD-L', 'abdominal ultrasound', 'US', 'large', 'abdomen', 30, false, NULL, 15, 15),
    (22, 'US-THX-L', 'thoracic ultrasound', 'US', 'large', 'thorax', 20, false, NULL, 15, 15),
    (23, 'US-REPR-L', 'reproductive tract ultrasound', 'US', 'large', 'reproductive tract', 20, false, NULL, 15, 15),
    (24, 'CT-HEAD-L', 'head CT, standing (large bore)', 'CT', 'large', 'head', 45, false, NULL, 8, 8),
    (25, 'CT-LIMB-L', 'distal limb CT (large bore)', 'CT', 'large', 'distal limb', 60, true, NULL, 8, 8),
    (26, 'MR-LIMB-H', 'standing distal limb MRI', 'MR', 'horse', 'distal limb', 90, false, NULL, 10, NULL),
    (27, 'NM-BONE-H', 'bone scintigraphy', 'NM', 'horse', 'whole body', 60, false, NULL, 16, NULL),
    (28, 'DX-VIEW-A', 'single follow-up radiograph', 'DX', 'any', 'as requested', 10, false, 11, 12, 13),
    (29, 'US-GUID-A', 'ultrasound-guided aspirate or biopsy', 'US', 'any', 'as requested', 30, false, 14, 15, 15),
    (30, 'DX-CONT-A', 'contrast radiography', 'DX', 'any', 'as requested', 45, false, 11, 12, 13);

INSERT INTO mach_procedures (id, code, name, modality, species_group, body_part, minutes, under_ga, turnaround_hours)
SELECT id, code, name, modality, grp, body_part, minutes, under_ga, 72 FROM l_proc ORDER BY id;

-- --- The core's imaging requests that were sent ----------------------------------------

-- Only a sent request reaches a part (the core's GM notes): the vet's own
-- cancellations before sending never came here. sec is the animal's section
-- by the core's ranges (domestic 1-14 600, horses to 16 000, farm above).
CREATE TEMP TABLE l_r AS
SELECT n AS request_id, r.*, CASE WHEN r.animal_id <= 14600 THEN 3 WHEN r.animal_id <= 16000 THEN 1 ELSE 2 END AS sec
  FROM generate_series(1, 17000) AS n, pg_temp.core_request(n, :'load_epoch', :customer_utc_offset) AS r
 WHERE r.kind = 'imaging' AND r.sent_at IS NOT NULL;

-- The worklist's rows in time order (the post's): its id is the k-th sent
-- imaging request, by sent_at then request id.
CREATE TEMP TABLE l_w AS
SELECT row_number() OVER (ORDER BY r.sent_at, r.request_id)::integer AS id, r.*, p.id AS procedure_id,
       p.modality, p.minutes, p.under_ga,
       CASE r.sec WHEN 3 THEN p.m_dom WHEN 1 THEN p.m_horse ELSE p.m_farm END AS machine_id,
       to_timestamp(ceil(extract(epoch FROM r.sent_at + interval '1 second') / 60) * 60) AS identity_at
  FROM l_r AS r JOIN l_proc AS p ON p.code = r.code;
CREATE UNIQUE INDEX ON l_w (id);

-- The identity the lookup API answered at identity_at: the animal, its
-- natural identifiers as the core's functions give them, its owner then.
CREATE TEMP TABLE l_id AS
SELECT w.id, a.species, a.breed, a.sex, a.born_on, a.name, o.name AS owner_name, o.family_name,
       pg_temp.core_microchip(w.animal_id) AS microchip, pg_temp.core_ueln(w.animal_id) AS ueln,
       pg_temp.core_ear_tag(w.animal_id) AS ear_tag
  FROM l_w AS w,
       pg_temp.core_animal(w.animal_id, :'load_epoch', :customer_utc_offset) AS a,
       LATERAL (SELECT ow.owner_id FROM pg_temp.core_ownership(w.animal_id, :'load_epoch', :customer_utc_offset) AS ow
                 WHERE ow.role = 'owner' AND ow.from_at <= w.identity_at
                   AND (ow.until_at IS NULL OR ow.until_at > w.identity_at)
                 ORDER BY ow.from_at DESC LIMIT 1) AS cur,
       pg_temp.core_owner(cur.owner_id, :'load_epoch', :customer_utc_offset) AS o;

-- --- Each entry's course: scheduled, acquired, reported, or cancelled ------------------

-- A resulted request's final is signed 1 to 9 minutes before the core's
-- resulted_at (purpose 13 copies it within ten); its study acquired between
-- the post and the final (urgent ones early); an urgent study's preliminary
-- 10 to 60 minutes after it ends. One urgent night study in two (21:00-
-- 07:00) was typed on the modality before its entry existed, then
-- reconciled. A sent request of the last day: urgent ones acquired at once,
-- routine ones on an imaging-day slot within two working days. A request the
-- imaging team cancelled after sending: the entry cancelled a few minutes
-- before the core's copy.
CREATE TEMP TABLE l_c AS
SELECT w.id, w.state AS core_state, w.priority, w.minutes,
       f.final_at, f.started_at, f.started_at + w.minutes * interval '1 minute' AS ended_at,
       f.unscheduled, f.cancelled_at
  FROM l_env AS env, l_w AS w,
       LATERAL (SELECT pg_temp.m_u(w.request_id, 591) AS u1, pg_temp.m_u(w.request_id, 592) AS u2,
                       pg_temp.m_u(w.request_id, 593) AS u3,
                       extract(hour FROM pg_temp.m_local(w.sent_at, env.o)) AS lh) AS h,
       LATERAL (SELECT CASE WHEN w.state = 'resulted' THEN w.resulted_at - (1 + 8 * h.u1) * interval '1 minute' END AS fin) AS g,
       LATERAL (SELECT g.fin AS final_at,
                       w.state = 'resulted' AND w.priority = 'urgent' AND (h.lh >= 21 OR h.lh < 7) AND h.u3 < 0.55 AS unscheduled,
                       CASE
                         WHEN w.state = 'cancelled' THEN NULL
                         WHEN w.state = 'resulted' AND w.priority = 'urgent' AND (h.lh >= 21 OR h.lh < 7) AND h.u3 < 0.55
                           THEN w.sent_at - (5 + 25 * h.u2) * interval '1 minute'
                         WHEN w.state = 'resulted'
                           THEN w.sent_at + (CASE w.priority WHEN 'urgent' THEN 0.02 + 0.2 * h.u2 ELSE 0.15 + 0.4 * h.u2 END)
                                            * (g.fin - w.sent_at - (w.minutes + 15) * interval '1 minute')
                         WHEN w.priority = 'urgent' THEN w.sent_at + (10 + 30 * h.u2) * interval '1 minute'
                         ELSE pg_temp.m_slot(w.sent_at + (1 + 40 * h.u2) * interval '1 hour', env.o, w.request_id)
                       END AS started_at,
                       CASE WHEN w.state = 'cancelled'
                            THEN greatest(w.cancelled_at - (1 + 3 * h.u1) * interval '1 minute', w.identity_at)
                       END AS cancelled_at) AS f;

INSERT INTO mach_worklist (id, accession, request_id, consultation_id, animal_id, requested_by, procedure_id, priority,
                           machine_id, scheduled_at, patient_id, patient_name, species, breed, sex, born_on,
                           microchip, ueln, ear_tag, responsible_person, identity_at, state, cancelled_because,
                           cancelled_at, created_at)
SELECT w.id, 'I-' || w.request_id, w.request_id, w.consultation_id, w.animal_id, w.requested_by, w.procedure_id,
       w.priority,
       CASE WHEN c.started_at IS NOT NULL THEN w.machine_id END,
       CASE WHEN c.started_at IS NOT NULL THEN date_trunc('minute', c.started_at) END,
       'A-' || w.animal_id, i.family_name || '^' || i.name, i.species, i.breed, i.sex, i.born_on,
       i.microchip, i.ueln, i.ear_tag, i.owner_name, w.identity_at,
       CASE WHEN c.core_state = 'cancelled' THEN 'cancelled'
            WHEN c.started_at >= env.e THEN 'scheduled'
            WHEN c.ended_at >= env.e THEN 'in-progress'
            ELSE 'completed' END,
       CASE WHEN c.core_state = 'cancelled'
            THEN (ARRAY['animal discharged before the study', 'study no longer indicated after review',
                        'owner declined the study', 'animal unfit for anaesthesia',
                        'duplicate of another request'])[1 + floor(5 * pg_temp.m_u(w.request_id, 594))::integer] END,
       c.cancelled_at, w.sent_at
  FROM l_env AS env, l_w AS w JOIN l_c AS c ON c.id = w.id JOIN l_id AS i ON i.id = w.id
 ORDER BY w.id;

-- --- Studies, series, reports ------------------------------------------------------------

-- Ids in acquisition order; the six unmatched studies are 3 465-3 470
-- whatever the year holds before them (the load refuses more).
CREATE TEMP TABLE l_st AS
SELECT row_number() OVER (ORDER BY c.started_at, w.id)::integer AS id, w.id AS worklist_id, w.request_id, w.machine_id,
       w.modality, w.priority, w.sec, w.requested_by, c.started_at,
       CASE WHEN c.ended_at < env.e THEN c.ended_at END AS ended_at, c.final_at, c.unscheduled,
       w.modality IN ('CT', 'DX', 'NM') AS ionising
  FROM l_env AS env, l_w AS w JOIN l_c AS c ON c.id = w.id
 WHERE c.started_at < env.e;

INSERT INTO mach_studies (id, study_uid, worklist_id, accession, machine_id, patient_id, patient_name, performed_by,
                          restrained_by, companion_present, started_at, ended_at, images, size_mb, exposure, state,
                          reconciled_at, reconciled_by)
SELECT s.id, '1.2.826.0.1.3680043.9.7433.1.' || s.id, s.worklist_id,
       CASE WHEN NOT s.unscheduled THEN 'I-' || s.request_id END,
       s.machine_id, mw.patient_id, mw.patient_name,
       pg_temp.m_duty(s.started_at, env.o, 52, 4, s.id),
       CASE WHEN s.ionising THEN CASE s.sec WHEN 1 THEN 29 + floor(8 * pg_temp.m_u(s.id, 601))::integer
                                            WHEN 2 THEN 37 + floor(6 * pg_temp.m_u(s.id, 601))::integer
                                            ELSE 43 + floor(9 * pg_temp.m_u(s.id, 601))::integer END END,
       s.ionising AND pg_temp.m_u(s.id, 602) < 0.1,
       s.started_at, s.ended_at,
       sz.images, sz.size_mb,
       CASE s.modality WHEN 'DX' THEN (55 + floor(35 * pg_temp.m_u(s.id, 603)))::integer || ' kV, '
                                      || (4 + floor(16 * pg_temp.m_u(s.id, 604)))::integer || ' mAs'
                       WHEN 'CT' THEN 'DLP ' || (150 + floor(900 * pg_temp.m_u(s.id, 603)))::integer || ' mGy.cm'
                       WHEN 'NM' THEN 'Tc-99m HDP ' || (3500 + floor(1500 * pg_temp.m_u(s.id, 603)))::integer || ' MBq'
       END,
       CASE WHEN s.final_at IS NOT NULL AND s.final_at < env.e THEN 'reported' ELSE 'acquired' END,
       CASE WHEN s.unscheduled THEN least(s.started_at + (2 + 18 * pg_temp.m_u(s.id, 605)) * interval '1 hour',
                                          s.final_at - interval '10 minutes') END,
       CASE WHEN s.unscheduled THEN pg_temp.m_duty(s.started_at, env.o, 52, 4, s.id + 1) END
  FROM l_env AS env, l_st AS s JOIN mach_worklist AS mw ON mw.id = s.worklist_id,
       LATERAL (SELECT CASE s.modality WHEN 'DX' THEN 2 + floor(5 * pg_temp.m_u(s.id, 606))::integer
                                       WHEN 'US' THEN 20 + floor(40 * pg_temp.m_u(s.id, 606))::integer
                                       WHEN 'CT' THEN 300 + floor(900 * pg_temp.m_u(s.id, 606))::integer
                                       WHEN 'MR' THEN 200 + floor(400 * pg_temp.m_u(s.id, 606))::integer
                                       ELSE 20 + floor(40 * pg_temp.m_u(s.id, 606))::integer END AS images) AS im,
       LATERAL (SELECT CASE WHEN s.ended_at IS NULL THEN 0 ELSE im.images END AS images,
                       CASE WHEN s.ended_at IS NULL THEN 0
                            ELSE round((im.images * CASE s.modality WHEN 'DX' THEN 12 WHEN 'US' THEN 0.6
                                                                    WHEN 'CT' THEN 0.5 WHEN 'MR' THEN 0.25 ELSE 1 END)::numeric, 1)
                       END AS size_mb) AS sz
 ORDER BY s.id;

-- The six unmatched studies (the PACS's mistyped chips): urgent night
-- acquisitions typed for animals the record does not hold, spread over the
-- year, with no entry and no request.
INSERT INTO mach_studies (id, study_uid, worklist_id, accession, machine_id, patient_id, patient_name, performed_by,
                          restrained_by, companion_present, started_at, ended_at, images, size_mb, exposure, state)
SELECT 3464 + k, '1.2.826.0.1.3680043.9.7433.1.' || (3464 + k), NULL, NULL, u.machine_id, u.patient_id, u.patient_name,
       pg_temp.m_duty(t, env.o, 52, 4, 3464 + k), u.restrainer, false, t, t + interval '20 minutes',
       u.images, u.images * 12, u.exposure, 'unmatched'
  FROM l_env AS env,
       (VALUES (1, 11, 'A-17423', 'Becker^Rex', 47, 3, '70 kV, 8 mAs'),
               (2, 12, 'A-15124', 'Fischer^Duke', 31, 4, '75 kV, 12 mAs'),
               (3, 11, 'A-9318', 'Martin^Luna', 44, 2, '62 kV, 6 mAs'),
               (4, 13, 'A-18210', 'Hughes Farm^Bella 0421', 38, 3, '80 kV, 10 mAs'),
               (5, 11, 'A-21007', 'Dubois^Milo', 49, 2, '58 kV, 5 mAs'),
               (6, 12, 'A-14916', 'Keller^Storm', 33, 4, '78 kV, 14 mAs'))
         AS u (k, machine_id, patient_id, patient_name, restrainer, images, exposure),
       LATERAL (SELECT pg_temp.m_utc(env.s::date + (60 * u.k - 30) + time '23:00' + u.k * interval '17 minutes', env.o) AS t) AS x
 WHERE t < env.e - interval '1 day';

-- Series: by modality, numbered in the study; their images sum to the study's.
INSERT INTO mach_series (id, study_id, number, modality, body_part, description, images)
SELECT row_number() OVER (ORDER BY st.id, n), st.id, n, mp.modality, mp.body_part,
       CASE mp.modality WHEN 'DX' THEN (ARRAY['lateral', 'ventrodorsal', 'oblique', 'dorsopalmar', 'skyline'])[n]
                        WHEN 'US' THEN (ARRAY['survey', 'targeted', 'Doppler'])[n]
                        WHEN 'CT' THEN (ARRAY['pre-contrast', 'post-contrast', 'bone window', 'reformats'])[n]
                        WHEN 'MR' THEN (ARRAY['T2 sagittal', 'T1 transverse', 'STIR', 'T2* gradient echo', 'post-contrast T1'])[n]
                        ELSE (ARRAY['pool phase', 'bone phase', 'delayed views'])[n] END,
       CASE WHEN n < k.cnt THEN st.images / k.cnt ELSE st.images - (k.cnt - 1) * (st.images / k.cnt) END
  FROM mach_studies AS st JOIN mach_worklist AS w ON w.id = st.worklist_id
       JOIN mach_procedures AS mp ON mp.id = w.procedure_id,
       LATERAL (SELECT least(st.images, CASE mp.modality WHEN 'DX' THEN 1 + floor(3 * pg_temp.m_u(st.id, 611))::integer
                                                         WHEN 'US' THEN 1 + floor(3 * pg_temp.m_u(st.id, 611))::integer
                                                         WHEN 'CT' THEN 2 + floor(3 * pg_temp.m_u(st.id, 611))::integer
                                                         WHEN 'MR' THEN 3 + floor(3 * pg_temp.m_u(st.id, 611))::integer
                                                         ELSE 2 + floor(2 * pg_temp.m_u(st.id, 611))::integer END) AS cnt) AS k,
       generate_series(1, k.cnt) AS n
 WHERE st.ended_at IS NOT NULL
UNION ALL
SELECT 900000 + st.id, st.id, 1, 'DX', 'as typed', 'survey', st.images
  FROM mach_studies AS st WHERE st.state = 'unmatched';
-- (the unmatched studies' one series each, numbered after the others)
UPDATE mach_series SET id = (SELECT max(id) FROM mach_series WHERE id < 900000) + study_id - 3464 WHERE id >= 900000;

-- Reports: an urgent study's preliminary by the requesting (duty) vet; the
-- final by the imaging specialist on duty (26-28, the core's rota); one final
-- in about a hundred superseded by an addendum, both kept (rule 2). No text
-- names an owner.
CREATE TEMP TABLE l_rep AS
SELECT st.id AS study_id, 'preliminary' AS kind, st.requested_by AS author,
       least(st.ended_at + (10 + 50 * pg_temp.m_u(st.id, 621)) * interval '1 minute',
             coalesce(st.ended_at + (st.final_at - st.ended_at) / 2, 'infinity')) AS signed_at,
       NULL::integer AS supersedes_study, NULL::text AS why, st.modality
  FROM l_st AS st WHERE st.priority = 'urgent' AND st.ended_at IS NOT NULL
UNION ALL
SELECT st.id, 'final', pg_temp.m_duty(st.final_at, env.o, 26, 3, st.id), st.final_at, NULL, NULL, st.modality
  FROM l_env AS env, l_st AS st WHERE st.final_at IS NOT NULL
UNION ALL
SELECT st.id, 'final', pg_temp.m_duty(st.final_at, env.o, 26, 3, st.id),
       st.final_at + (1 + 9 * pg_temp.m_u(st.id, 622)) * interval '1 day', st.id,
       (ARRAY['measurement corrected after review', 'additional finding on the delayed series',
              'comparison with the previous study added'])[1 + floor(3 * pg_temp.m_u(st.id, 623))::integer],
       st.modality
  FROM l_env AS env, l_st AS st
 WHERE st.final_at IS NOT NULL AND pg_temp.m_u(st.id, 624) < 0.012
   AND st.final_at + (1 + 9 * pg_temp.m_u(st.id, 622)) * interval '1 day' < env.e;
DELETE FROM l_rep USING l_env AS env WHERE l_rep.signed_at >= env.e;

CREATE TEMP TABLE l_rid AS
SELECT row_number() OVER (ORDER BY signed_at, study_id, kind, why NULLS FIRST)::integer AS id, * FROM l_rep;
-- An addendum supersedes its study's first final.
INSERT INTO mach_reports (id, study_id, kind, author, findings, conclusion, status, signed_at, supersedes_id, why)
SELECT r.id, r.study_id, r.kind, r.author,
       (ARRAY['No abnormality detected in the regions examined.',
              'Mild degenerative changes, consistent with age.',
              'Focal soft-tissue swelling; no bony involvement.',
              'Findings consistent with the clinical suspicion; see conclusion.',
              'Changes compared with the previous study: stable.'])[1 + floor(5 * pg_temp.m_u(r.study_id * 4 + length(r.kind), 625))::integer]
         || CASE r.kind WHEN 'preliminary' THEN ' Preliminary reading, final report to follow.' ELSE '' END,
       (ARRAY['Normal study.', 'Mild changes, clinical correlation advised.', 'Abnormal: see findings.',
              'Recheck in four to six weeks advised.'])[1 + floor(4 * pg_temp.m_u(r.study_id * 4 + length(r.kind), 626))::integer],
       'signed', r.signed_at,
       CASE WHEN r.why IS NOT NULL THEN (SELECT f.id FROM l_rid AS f WHERE f.study_id = r.study_id
                                            AND f.kind = 'final' AND f.why IS NULL) END,
       r.why
  FROM l_rid AS r
 ORDER BY r.id;

-- --- Sequences, and the load's own checks ------------------------------------------------

SELECT setval(pg_get_serial_sequence('mach_procedures', 'id'), 30);
SELECT setval(pg_get_serial_sequence('mach_worklist', 'id'), greatest((SELECT max(id) FROM mach_worklist), 3400));
SELECT setval(pg_get_serial_sequence('mach_studies', 'id'), 3470);
SELECT setval(pg_get_serial_sequence('mach_series', 'id'), greatest((SELECT max(id) FROM mach_series), 8000));
SELECT setval(pg_get_serial_sequence('mach_reports', 'id'), greatest((SELECT max(id) FROM mach_reports), 3450));

DO $$
BEGIN
    IF (SELECT max(id) FROM mach_worklist) > 3400 THEN
        RAISE EXCEPTION 'pacs/load.sql: % worklist entries, above the range 1-3 400', (SELECT max(id) FROM mach_worklist);
    END IF;
    IF (SELECT max(id) FROM mach_studies WHERE state <> 'unmatched') >= 3465 THEN
        RAISE EXCEPTION 'pacs/load.sql: studies reach 3 465, the unmatched studies'' ids';
    END IF;
    IF (SELECT count(*) FROM mach_studies WHERE state = 'unmatched') <> 6 THEN
        RAISE EXCEPTION 'pacs/load.sql: % unmatched studies, 6 expected', (SELECT count(*) FROM mach_studies WHERE state = 'unmatched');
    END IF;
    IF EXISTS (SELECT 1 FROM mach_worklist w JOIN mach_procedures p ON p.id = w.procedure_id
                WHERE (p.species_group = 'small' AND w.species IN ('horse', 'cattle', 'sheep', 'goat'))
                   OR (p.species_group = 'horse' AND w.species <> 'horse')
                   OR (p.species_group = 'large' AND w.species NOT IN ('horse', 'cattle', 'sheep', 'goat'))) THEN
        RAISE EXCEPTION 'pacs/load.sql: a study code outside its species group (the core''s draw, D373)';
    END IF;
    IF EXISTS (SELECT 1 FROM mach_studies s JOIN mach_reports r ON r.study_id = s.id
                WHERE r.signed_at < s.ended_at) THEN
        RAISE EXCEPTION 'pacs/load.sql: a report signed before its study ended';
    END IF;
END $$;

ANALYZE;
