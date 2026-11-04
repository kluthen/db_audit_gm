-- vet-scheduling's history (v0.5 master spec 9.4; specs/versions/v0.5/
-- vet-scheduling-domain.md, "Deterministic key ranges", "The history on the
-- agenda", "In flight at T0", "Loading"; capture W3 item 2 and "W3 item 2,
-- revised", W3-g; spec D408-D413): last night's backup of the centre's
-- agenda, rota and training centre, a year ending at T0 and the agenda and
-- rota ahead of it. Runs after schema.sql, connected to the core's database,
-- as postgres, with the core's data/keys.sql streamed ahead of it in the same
-- session (capture W2 item 3). It never reads the core's tables (D249, D322):
-- the rota and its absences, the agenda's attended consultations, the
-- imaging requests, the inbound examinations, the deaths, the patients'
-- registrations and the staff layout are the core's functions (vet-core
-- docs/gm.md, "Core keys"), called with this run's load_epoch; the agenda's
-- placed rows are the core's vc_agenda, which its notes name for this part
-- (W3-g). Every other draw is a hash of an id (sched_u), never random().
-- docs/gm.md, "Core keys used" and "Loading", documents both.
--
-- It reads load-data's psql variables customer_utc_offset (hours, east
-- positive), customer_timezone and load_epoch (the run's start, UTC, to the
-- minute: the load's "now", T0, never now()). Every time in the database is
-- UTC; the rooms' hours and the rota's days are the customer's local ones.
-- The four exclusion constraints exist before this file runs (schema.sql);
-- the allocations are inserted in one statement at the end, which they
-- check.
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_utc_offset is not set '
                            '(gmctl load-data passes -v customer_utc_offset=<hours>)'; END $$;
\endif
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_timezone is not set '
                            '(gmctl load-data passes -v customer_timezone=<zone>)'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable load_epoch is not set '
                            '(gmctl load-data passes -v load_epoch=<UTC, ISO 8601>)'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.core_shifts(integer, date, integer)') IS NULL
       OR to_regprocedure('pg_temp.vc_agenda(timestamp without time zone, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'load.sql: the core''s key functions are missing (gmctl load-data streams '
                        'vet-core''s data/keys.sql ahead of this file, in the same session)';
    END IF;
END $$;

-- A uniform draw in [0, 1) from x and a salt (salts 1301 and up: scheduling's).
CREATE FUNCTION pg_temp.sched_u(x bigint, salt integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, salt) & 2147483647)::float8 / 2147483648 $$;
-- A UTC instant as the customer's local time, and back.
CREATE FUNCTION pg_temp.sched_local(t timestamptz, o integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t AT TIME ZONE 'UTC') + o * interval '1 hour' $$;
CREATE FUNCTION pg_temp.sched_utc(t timestamp, o integer) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - o * interval '1 hour') AT TIME ZONE 'UTC' $$;
-- The growth of a daily volume (D279): the share x of the year at which the
-- q-th quantile of a stream ramping from 0.6 to 1.0 falls (the core's ramp).
CREATE FUNCTION pg_temp.sched_ramp(q float8) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (sqrt(0.36 + 0.64 * q) - 0.6) / 0.4 $$;

-- The run's moment, offset and zone; the history's start S (local Monday
-- 00:00 52 weeks before T0's week, the core's calendar); the last Friday
-- 12:00 before T0 and its week, the rota published to the end of the week
-- after next from it and planned to the end of the seventh week after it
-- (D411).
CREATE TEMP TABLE s_env AS
WITH a AS (SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
                  :'customer_timezone'::text AS tz),
     b AS (SELECT a.*, pg_temp.sched_local(a.e, a.o) AS le FROM a),
     c AS (SELECT b.*, date_trunc('week', b.le) - interval '364 days' AS ls,
                  b.le::date - ((extract(isodow FROM b.le)::integer + 2) % 7) + time '12:00' AS f0 FROM b),
     d AS (SELECT c.*, CASE WHEN c.f0 >= c.le THEN c.f0 - interval '7 days' ELSE c.f0 END AS lf FROM c)
SELECT e, o, tz, le, ls, pg_temp.sched_utc(ls, o) AS s, lf, date_trunc('week', lf) AS lw,
       date_trunc('week', lf) + interval '21 days' AS pub_end, date_trunc('week', lf) + interval '56 days' AS plan_end
  FROM d;

-- --- Reference (docs/gm.md, "The rooms", "The machines", "The types", "The courses") ---------

INSERT INTO sched_settings (id, timezone, utc_offset) SELECT 1, tz, o FROM s_env;

INSERT INTO sched_rooms (id, code, name, kind, section_id, consultation_space, seats) VALUES
    (1, 'C-1', 'Consulting room 1', 'consulting', 3, true, NULL),
    (2, 'C-2', 'Consulting room 2', 'consulting', 3, true, NULL),
    (3, 'C-3', 'Consulting room 3', 'consulting', 3, true, NULL),
    (4, 'C-4', 'Consulting room 4', 'consulting', 3, true, NULL),
    (5, 'PR-D', 'Procedure room', 'procedure', 3, false, NULL),
    (6, 'TH-D1', 'Domestic theatre 1', 'theatre', 3, false, NULL),
    (7, 'TH-D2', 'Domestic theatre 2', 'theatre', 3, false, NULL),
    (8, 'EX-H1', 'Examination stall 1', 'examination', 1, true, NULL),
    (9, 'EX-H2', 'Examination stall 2', 'examination', 1, true, NULL),
    (10, 'AR-H', 'Trot-up and lunging arena', 'arena', 1, true, NULL),
    (11, 'TH-H', 'Horse theatre, induction and recovery boxes', 'theatre', 1, false, NULL),
    (12, 'EX-F', 'Examination crush', 'examination', 2, true, NULL),
    (13, 'TH-F', 'Standing-surgery theatre', 'theatre', 2, true, NULL),
    (14, 'CL-1', 'Classroom 1', 'classroom', NULL, false, 24),
    (15, 'CL-2', 'Classroom 2', 'classroom', NULL, false, 16),
    (16, 'PH-C', 'Canine practical hall', 'practical', NULL, false, 14);

-- Machines 7-16 (vet-machinery's, D324): the CTs, radiography and the
-- ultrasounds around the clock (the urgent studies, the imaging on-call);
-- the two MRIs and the gamma camera on the imaging day.
INSERT INTO sched_machines (machine_id, section_id, name, study_kind, slot_minutes, operator_kind,
                            around_the_clock) VALUES
    (7, 3, 'CT, small animal', 'ct', 30, 'radiographer', true),
    (8, NULL, 'CT, large bore', 'ct', 60, 'radiographer', true),
    (9, 3, 'MRI 1.5 T', 'mri', 60, 'radiographer', false),
    (10, 1, 'Standing MRI', 'mri-standing', 90, 'radiographer', false),
    (11, 3, 'Radiography room, domestic', 'radiography', 30, 'radiographer', true),
    (12, 1, 'Radiography room, horses', 'radiography', 30, 'radiographer', true),
    (13, NULL, 'Portable radiography, farm and stables', 'radiography', 30, 'radiographer', true),
    (14, 3, 'Ultrasound, domestic', 'ultrasound', 30, 'imaging-vet', true),
    (15, NULL, 'Portable ultrasound', 'ultrasound', 30, 'imaging-vet', true),
    (16, 1, 'Gamma camera, horses', 'scintigraphy', 60, 'radiographer', false);

-- The rooms' hours (D410): domestic consulting Monday to Friday 08:00-20:00
-- and Saturday 08:00-13:00; the procedure room and the theatres 08:00-18:00;
-- horse 08:00-17:00 (its theatre 08:00-18:00); farm 08:00-16:00; the
-- training centre 09:00-16:00; Monday to Friday. The machines: around the
-- clock, or the imaging day, Monday to Friday 08:00-18:00.
INSERT INTO sched_hours (resource_kind, resource_id, weekday, opens, closes)
SELECT 'room', r.id, w, h.opens, h.closes
  FROM generate_series(1, 16) AS r (id), generate_series(1, 6) AS w,
       LATERAL (SELECT CASE WHEN r.id <= 4 AND w = 6 THEN time '08:00' WHEN w <= 5 THEN
                         CASE WHEN r.id >= 14 THEN time '09:00' ELSE time '08:00' END END AS opens,
                       CASE WHEN r.id <= 4 THEN CASE WHEN w = 6 THEN time '13:00' ELSE time '20:00' END
                            WHEN r.id IN (5, 6, 7, 11) THEN time '18:00'
                            WHEN r.id IN (8, 9, 10) THEN time '17:00'
                            WHEN r.id IN (12, 13) THEN time '16:00'
                            ELSE time '16:00' END AS closes) AS h
 WHERE h.opens IS NOT NULL
UNION ALL
SELECT 'machine', m.machine_id, w, time '00:00', time '24:00'
  FROM sched_machines AS m, generate_series(1, 7) AS w WHERE m.around_the_clock
UNION ALL
SELECT 'machine', m.machine_id, w, time '08:00', time '18:00'
  FROM sched_machines AS m, generate_series(1, 5) AS w WHERE NOT m.around_the_clock;

INSERT INTO sched_courses (id, code, title, audience, species, days, hours, seats, teaching_animals, room_kind) VALUES
    (1, 'CAN-FA', 'Canine first aid for owners', 'owner', 'canine', 1, 7, 12, 4, 'practical'),
    (2, 'CAN-HND', 'Dog handling and restraint', 'handler', 'canine', 1, 7, 10, 4, 'practical'),
    (3, 'CAN-CARD', 'Canine cardiology update', 'vet', 'canine', 2, 14, 12, 2, 'practical'),
    (4, 'CAN-DERM', 'Canine dermatology in practice', 'vet', 'canine', 2, 14, 14, 0, 'classroom'),
    (5, 'CAN-NUR', 'Canine nursing skills', 'nurse', 'canine', 3, 21, 10, 4, 'practical'),
    (6, 'CAN-STU', 'Canine clinical examination for students', 'student', 'canine', 3, 21, 12, 6, 'practical'),
    (7, 'CAN-BEH', 'Canine behaviour for owners', 'owner', 'canine', 1, 7, 14, 0, 'classroom'),
    (8, 'EQ-LAME', 'Equine lameness examination', 'vet', 'equine', 2, 14, 10, 3, 'arena'),
    (9, 'EQ-HND', 'Horse handling for grooms', 'handler', 'equine', 1, 7, 8, 3, 'arena'),
    (10, 'EQ-FA', 'Equine first aid for owners', 'owner', 'equine', 1, 7, 12, 2, 'arena'),
    (11, 'EQ-STU', 'Equine clinical examination for students', 'student', 'equine', 3, 21, 10, 4, 'arena'),
    (12, 'EQ-NUR', 'Equine nursing skills', 'nurse', 'equine', 2, 14, 10, 3, 'arena'),
    (13, 'EQ-DENT', 'Equine dentistry update', 'vet', 'equine', 1, 7, 8, 2, 'arena'),
    (14, 'MX-RAD', 'Radiation safety', 'nurse', 'mixed', 1, 7, 14, 0, 'classroom'),
    (15, 'MX-ZOO', 'Zoonoses and biosecurity', 'vet', 'mixed', 1, 7, 14, 0, 'classroom'),
    (16, 'MX-AMR', 'Responsible antimicrobial use', 'vet', 'mixed', 2, 14, 14, 0, 'classroom');

INSERT INTO sched_types (id, code, name, kind, section_id, duration_minutes, room_kind, machine_id, staff, course_id)
VALUES
    (1, 'D-FR', 'Domestic first referral', 'consultation', 3, 30, 'consultation', NULL, 'vet', NULL),
    (2, 'D-FU', 'Domestic follow-up', 'consultation', 3, 30, 'consultation', NULL, 'vet', NULL),
    (3, 'D-CARD', 'Cardiology clinic', 'consultation', 3, 30, 'consultation', NULL, 'vet', NULL),
    (4, 'D-DERM', 'Dermatology clinic', 'consultation', 3, 30, 'consultation', NULL, 'vet', NULL),
    (5, 'D-SURG', 'Surgical consultation', 'consultation', 3, 30, 'consultation', NULL, 'vet', NULL),
    (6, 'H-FR', 'Horse first referral', 'consultation', 1, 30, 'consultation', NULL, 'vet', NULL),
    (7, 'H-FU', 'Horse follow-up', 'consultation', 1, 30, 'consultation', NULL, 'vet', NULL),
    (8, 'H-LAME', 'Lameness work-up', 'consultation', 1, 30, 'consultation', NULL, 'vet', NULL),
    (9, 'H-REPRO', 'Reproduction clinic', 'consultation', 1, 30, 'consultation', NULL, 'vet', NULL),
    (10, 'F-FR', 'Farm first referral', 'consultation', 2, 30, 'consultation', NULL, 'vet', NULL),
    (11, 'F-FU', 'Farm follow-up', 'consultation', 2, 30, 'consultation', NULL, 'vet', NULL),
    (12, 'F-HERD', 'Herd health consultation', 'consultation', 2, 30, 'consultation', NULL, 'vet', NULL),
    (13, 'D-CT', 'CT, domestic', 'imaging', 3, 30, NULL, 7, 'operator', NULL),
    (14, 'D-MR', 'MRI, domestic', 'imaging', 3, 60, NULL, 9, 'operator', NULL),
    (15, 'D-DX', 'Radiography, domestic', 'imaging', 3, 30, NULL, 11, 'operator', NULL),
    (16, 'D-US', 'Ultrasound, domestic', 'imaging', 3, 30, NULL, 14, 'operator', NULL),
    (17, 'H-CT', 'CT, horse', 'imaging', 1, 60, NULL, 8, 'operator', NULL),
    (18, 'H-MR', 'Standing MRI, horse', 'imaging', 1, 90, NULL, 10, 'operator', NULL),
    (19, 'H-DX', 'Radiography, horse', 'imaging', 1, 30, NULL, 12, 'operator', NULL),
    (20, 'H-US', 'Ultrasound, horse', 'imaging', 1, 30, NULL, 15, 'operator', NULL),
    (21, 'H-NM', 'Scintigraphy, horse', 'imaging', 1, 60, NULL, 16, 'operator', NULL),
    (22, 'F-CT', 'CT, farm', 'imaging', 2, 60, NULL, 8, 'operator', NULL),
    (23, 'F-DX', 'Portable radiography, farm', 'imaging', 2, 30, NULL, 13, 'operator', NULL),
    (24, 'F-US', 'Portable ultrasound, farm', 'imaging', 2, 30, NULL, 15, 'operator', NULL),
    (25, 'D-OP', 'Domestic surgery', 'surgery', 3, 120, 'theatre', NULL, 'theatre-team', NULL),
    (26, 'H-OP', 'Horse surgery', 'surgery', 1, 180, 'theatre', NULL, 'theatre-team', NULL),
    (27, 'F-OP', 'Standing surgery, farm', 'surgery', 2, 90, 'theatre', NULL, 'theatre-team', NULL),
    (28, 'B-MACH', 'Machine block: quality assurance, service', 'block', NULL, 60, NULL, NULL, NULL, NULL),
    (29, 'B-ROOM', 'Room block: deep clean', 'block', NULL, 120, NULL, NULL, NULL, NULL);
INSERT INTO sched_types (id, code, name, kind, section_id, duration_minutes, room_kind, staff, course_id)
SELECT 29 + c.id, 'S-' || c.code, 'Session day: ' || c.title, 'session',
       CASE c.species WHEN 'equine' THEN 1 ELSE NULL END, 420, c.room_kind, 'instructor', c.id
  FROM sched_courses AS c ORDER BY c.id;

-- The study codes' machines (vet-machinery's procedure catalogue, D372,
-- D373): the domestic, horse and farm animal's machine of each code.
CREATE TEMP TABLE s_code (code text PRIMARY KEY, m_dom integer, m_horse integer, m_farm integer);
INSERT INTO s_code VALUES
    ('DX-THX-S', 11, NULL, NULL), ('DX-ABD-S', 11, NULL, NULL), ('DX-LIMB-S', 11, NULL, NULL),
    ('DX-SPN-S', 11, NULL, NULL), ('US-ABD-S', 14, NULL, NULL), ('US-ECHO-S', 14, NULL, NULL),
    ('US-THX-S', 14, NULL, NULL), ('CT-HEAD-S', 7, NULL, NULL), ('CT-TAB-S', 7, NULL, NULL),
    ('CT-LSP-S', 7, NULL, NULL), ('MR-BRN-S', 9, NULL, NULL), ('MR-SPN-S', 9, NULL, NULL),
    ('DX-FOOT-L', NULL, 12, 13), ('DX-FTLK-L', NULL, 12, 13), ('DX-CRHK-L', NULL, 12, 13),
    ('DX-STFL-L', NULL, 12, 13), ('DX-HEAD-L', NULL, 12, 13), ('DX-NKBK-L', NULL, 12, 13),
    ('DX-THX-L', NULL, 12, 13), ('US-TEND-L', NULL, 15, 15), ('US-ABD-L', NULL, 15, 15),
    ('US-THX-L', NULL, 15, 15), ('US-REPR-L', NULL, 15, 15), ('CT-HEAD-L', NULL, 8, 8),
    ('CT-LIMB-L', NULL, 8, 8), ('MR-LIMB-H', NULL, 10, NULL), ('NM-BONE-H', NULL, 16, NULL),
    ('DX-VIEW-A', 11, 12, 13), ('US-GUID-A', 14, 15, 15), ('DX-CONT-A', 11, 12, 13);

-- --- The rota (vet-core core_shifts, D388, D411) ----------------------------------------------

-- Every staff member's shifts by the core's pattern, from the history's
-- first week to the end of the planned weeks; a shift with an absence
-- becomes part of an absence period, never a shift.
CREATE TEMP TABLE s_shift AS
SELECT n AS staff_id, f.section_id, x.kind, x.starts_at, x.ends_at, x.absence,
       (pg_temp.sched_local(x.starts_at, v.o))::date AS day
  FROM s_env AS v, generate_series(1, 85) AS n,
       generate_series(v.ls::date, (v.plan_end - interval '1 day')::date, interval '1 day') AS d,
       pg_temp.core_shifts(n, d::date, v.o) AS x,
       pg_temp.core_staff(n) AS f;

-- Shifts: staff by staff, week by week; published (at their publishing
-- Friday 12:00, ten days before their Monday) to the end of the week after
-- next from the last Friday 12:00 before T0, planned after; clocked in five
-- minutes either side of the start, out on time in four of five and up to
-- an hour late otherwise; an on-call shift clocked only on a call-out (one
-- in four, one to three hours from one to eight hours into it). Nothing at
-- or after T0: the night's shifts are clocked in, not out.
INSERT INTO sched_shifts (id, staff_id, section_id, kind, starts_at, ends_at, clocked_in_at, clocked_out_at,
                          published_at)
SELECT row_number() OVER (ORDER BY h.staff_id, h.starts_at), h.staff_id, h.section_id, h.kind, h.starts_at, h.ends_at,
       CASE WHEN c.cin < v.e THEN c.cin END,
       CASE WHEN c.cin < v.e AND c.cout < v.e THEN c.cout END,
       CASE WHEN w.monday < v.pub_end THEN pg_temp.sched_utc(w.monday - interval '10 days' + interval '12 hours', v.o) END
  FROM s_env AS v, s_shift AS h,
       LATERAL (SELECT date_trunc('week', pg_temp.sched_local(h.starts_at, v.o)) AS monday) AS w,
       LATERAL (SELECT k, CASE WHEN h.kind = 'on-call' THEN
                         CASE WHEN pg_temp.sched_u(k, 1303) < 0.25
                              THEN h.starts_at + (1 + 7 * pg_temp.sched_u(k, 1304)) * interval '1 hour' END
                       ELSE h.starts_at + (10 * pg_temp.sched_u(k, 1301) - 5) * interval '1 minute' END AS cin
                  FROM (SELECT h.staff_id::bigint * 100000000 + extract(epoch FROM h.starts_at)::bigint / 60 AS k) AS kk)
                AS c0,
       LATERAL (SELECT c0.cin,
                       CASE WHEN h.kind = 'on-call' THEN least(c0.cin + (1 + 2 * pg_temp.sched_u(c0.k, 1305)) * interval '1 hour',
                                                               h.ends_at)
                            WHEN pg_temp.sched_u(c0.k, 1302) < 0.8
                            THEN h.ends_at + (8 * pg_temp.sched_u(c0.k, 1306) - 3) * interval '1 minute'
                            ELSE h.ends_at + (5 + 55 * pg_temp.sched_u(c0.k, 1306)) * interval '1 minute' END AS cout) AS c
 WHERE h.absence IS NULL
 ORDER BY h.staff_id, h.starts_at;

-- Absences: a staff member's consecutive absent shifts of one kind, with no
-- worked shift between them, one period from the first one's local day to
-- the day after the last one's (one day to two weeks). Leave and training
-- recorded one to six weeks ahead, an absence the morning it starts; never
-- after T0. No reason, no note (rule 4).
INSERT INTO sched_absences (id, staff_id, kind, from_at, until_at, recorded_at, recorded_by, note)
SELECT row_number() OVER (ORDER BY g.from_at, g.staff_id), g.staff_id, g.kind, g.from_at, g.until_at,
       least(CASE WHEN g.kind = 'absent' THEN g.from_at + interval '7 hours'
                  ELSE g.from_at - (7 + 35 * pg_temp.sched_u(g.staff_id::bigint * 100000 + extract(epoch FROM g.from_at)::bigint / 86400, 1307))
                                   * interval '1 day' END,
             v.e - interval '1 hour'),
       NULL, NULL
  FROM s_env AS v,
       (SELECT staff_id, absence AS kind, pg_temp.sched_utc(min(day)::timestamp, (SELECT o FROM s_env)) AS from_at,
               pg_temp.sched_utc((max(day) + 1)::timestamp, (SELECT o FROM s_env)) AS until_at
          FROM (SELECT h.*, row_number() OVER (PARTITION BY staff_id ORDER BY starts_at)
                            - row_number() OVER (PARTITION BY staff_id, absence ORDER BY starts_at) AS grp
                  FROM s_shift AS h) AS x
         WHERE absence IS NOT NULL
         GROUP BY staff_id, absence, grp) AS g
 ORDER BY g.from_at, g.staff_id;
ANALYZE sched_shifts, sched_absences;

-- --- The working tables ------------------------------------------------------------------------

-- The bookings and allocations as placed, inserted into sched_bookings and
-- sched_allocations at the end, in id order. While placing, a resource is
-- free when no live allocation here overlaps (as the constraints say).
CREATE TEMP TABLE s_book (
    id integer PRIMARY KEY, type_id integer NOT NULL, kind text NOT NULL, animal_id integer, section_id integer,
    starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, state text NOT NULL, source text NOT NULL,
    request_id integer, exchange_id integer, session_id integer, booked_at timestamptz NOT NULL,
    booked_by integer, notes text, arrived_at timestamptz, cancelled_at timestamptz, cancel_reason text);
CREATE TEMP TABLE s_alloc (
    booking_id integer NOT NULL, ord integer NOT NULL, staff_id integer, room_id integer, machine_id integer,
    animal_id integer, role text NOT NULL, starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL,
    during tstzrange GENERATED ALWAYS AS (tstzrange(starts_at, ends_at, '[)')) STORED, released_at timestamptz);
CREATE INDEX ON s_alloc USING gist (staff_id, during) WHERE staff_id IS NOT NULL AND released_at IS NULL;
CREATE INDEX ON s_alloc USING gist (room_id, during) WHERE room_id IS NOT NULL AND released_at IS NULL;
CREATE INDEX ON s_alloc USING gist (machine_id, during) WHERE machine_id IS NOT NULL AND released_at IS NULL;
CREATE INDEX ON s_alloc USING gist (animal_id, during) WHERE animal_id IS NOT NULL AND released_at IS NULL;
CREATE SEQUENCE pg_temp.s_ahead START 49001;      -- the agenda ahead at T0 (49 001-50 000)
CREATE SEQUENCE pg_temp.s_block START 48301;      -- the history's blocks
CREATE SEQUENCE pg_temp.s_plan START 47001;       -- the history's theatre plans
CREATE SEQUENCE pg_temp.s_sday START 48701;       -- the history's session days
CREATE SEQUENCE pg_temp.s_missed START 25001;       -- the history's cancelled and no-show consultation bookings

-- A staff member free over [s, e): on a shift covering it (on call only for
-- an operator), on no absence over it, no live allocation over it.
CREATE FUNCTION pg_temp.sched_free(p integer, s timestamptz, e timestamptz, oncall boolean DEFAULT false)
  RETURNS boolean LANGUAGE sql STABLE AS $$
SELECT EXISTS (SELECT 1 FROM sched_shifts AS h WHERE h.staff_id = p AND h.starts_at <= s AND h.ends_at >= e
                  AND h.starts_at > s - interval '1 day' AND (oncall OR h.kind <> 'on-call'))
   AND NOT EXISTS (SELECT 1 FROM sched_absences AS a WHERE a.staff_id = p AND a.from_at < e AND a.until_at > s)
   AND NOT EXISTS (SELECT 1 FROM s_alloc AS a WHERE a.staff_id = p AND a.released_at IS NULL
                      AND a.during && tstzrange(s, e, '[)'))
$$;
CREATE FUNCTION pg_temp.sched_room_free(r integer, s timestamptz, e timestamptz) RETURNS boolean
  LANGUAGE sql STABLE AS $$
SELECT NOT EXISTS (SELECT 1 FROM s_alloc AS a WHERE a.room_id = r AND a.released_at IS NULL
                      AND a.during && tstzrange(s, e, '[)'))
$$;
CREATE FUNCTION pg_temp.sched_machine_free(m integer, s timestamptz, e timestamptz) RETURNS boolean
  LANGUAGE sql STABLE AS $$
SELECT NOT EXISTS (SELECT 1 FROM s_alloc AS a WHERE a.machine_id = m AND a.released_at IS NULL
                      AND a.during && tstzrange(s, e, '[)'))
$$;
-- A resource's slots of length dur from t0 to t1, in time order: the grid
-- of dur (or step) from each opening (sched_hours, local), within its hours.
CREATE FUNCTION pg_temp.sched_slots(k text, rid integer, dur interval, t0 timestamptz, t1 timestamptz, o integer,
                                    step interval DEFAULT NULL)
  RETURNS SETOF timestamptz LANGUAGE sql STABLE AS $$
SELECT x FROM generate_series(pg_temp.sched_local(t0, o)::date, pg_temp.sched_local(t1, o)::date, interval '1 day') AS d
  JOIN sched_hours AS h ON h.resource_kind = k AND h.resource_id = rid AND h.weekday = extract(isodow FROM d),
       LATERAL generate_series(pg_temp.sched_utc(d::date + h.opens, o), pg_temp.sched_utc(d::date + h.closes, o) - dur,
                               coalesce(step, dur)) AS x
 WHERE x >= t0 AND x <= t1
 ORDER BY x
$$;
-- A patient's registration and death (the core's), cached.
CREATE TEMP TABLE s_animal (n integer PRIMARY KEY, registered_at timestamptz, died_at timestamptz);
CREATE FUNCTION pg_temp.sched_patient(n integer) RETURNS s_animal LANGUAGE plpgsql AS $$
DECLARE r s_animal; v s_env;
BEGIN
    SELECT * INTO r FROM s_animal WHERE s_animal.n = sched_patient.n;
    IF FOUND THEN RETURN r; END IF;
    SELECT * INTO v FROM s_env;
    INSERT INTO s_animal
    SELECT sched_patient.n, (SELECT a.registered_at FROM pg_temp.core_animal(sched_patient.n, v.e, v.o) AS a),
           (SELECT min(d.died_at) FROM pg_temp.core_death(sched_patient.n, v.e, v.o) AS d)
    RETURNING * INTO r;
    RETURN r;
END $$;
-- A patient of section sec booked at b for t: the first of six drawn by
-- the key (never a teaching animal: the core's pools, docs/gm.md) registered
-- before b and alive at b.
CREATE FUNCTION pg_temp.sched_pick_patient(sec integer, b timestamptz, key bigint) RETURNS integer
  LANGUAGE plpgsql AS $$
DECLARE lo integer; hi integer; a integer; r s_animal;
BEGIN
    SELECT CASE sec WHEN 1 THEN 14609 WHEN 2 THEN 16001 ELSE 13 END,
           CASE sec WHEN 1 THEN 16000 WHEN 2 THEN 17000 ELSE 14600 END INTO lo, hi;
    FOR g IN 0..5 LOOP
        a := lo + floor((hi - lo + 1) * pg_temp.sched_u(key * 8 + g, 1310))::integer;
        r := pg_temp.sched_patient(a);
        IF r.registered_at < b AND (r.died_at IS NULL OR r.died_at > b) THEN RETURN a; END IF;
    END LOOP;
    RETURN NULL;
END $$;
-- A local time moved into reception's hours on its day (Monday to Friday
-- 08:00-19:00, Saturday 08:00-12:00), the minute by the key; a Sunday the
-- Saturday before; never at or after lim.
CREATE FUNCTION pg_temp.sched_office(t timestamptz, key bigint, lim timestamptz) RETURNS timestamptz
  LANGUAGE sql STABLE AS $$
SELECT least(x, lim - (5 + 55 * pg_temp.sched_u(key, 1311)) * interval '1 minute')
  FROM s_env AS v,
       LATERAL (SELECT pg_temp.sched_local(t, v.o)::date AS d0) AS a,
       LATERAL (SELECT CASE WHEN extract(isodow FROM a.d0) = 7 THEN a.d0 - 1 ELSE a.d0 END AS d) AS b,
       LATERAL (SELECT pg_temp.sched_utc(b.d + time '08:00'
                                         + CASE WHEN extract(isodow FROM b.d) = 6 THEN 4 ELSE 11 END
                                           * pg_temp.sched_u(key, 1312) * interval '1 hour', v.o) AS x) AS c
$$;
-- A consultation type of the section: first referral when referred, else
-- by the key (follow-ups 45 %, the specialty clinics the rest).
CREATE FUNCTION pg_temp.sched_ctype(sec integer, referred boolean, key bigint) RETURNS integer
  LANGUAGE sql IMMUTABLE AS $$
SELECT CASE WHEN referred THEN CASE sec WHEN 3 THEN 1 WHEN 1 THEN 6 ELSE 10 END
            WHEN u < 0.45 THEN CASE sec WHEN 3 THEN 2 WHEN 1 THEN 7 ELSE 11 END
            WHEN sec = 3 THEN 3 + floor(3 * (u - 0.45) / 0.55)::integer
            WHEN sec = 1 THEN 8 + floor(2 * (u - 0.45) / 0.55)::integer
            ELSE 12 END
  FROM (SELECT pg_temp.sched_u(key, 1313) AS u) AS x
$$;

-- --- The agenda: the history's attended consultations (D408, W3-g) -----------------------------

-- Each placed scheduled consultation of the core's agenda (vc_agenda, every
-- half-hour slot of the year before T0) with a row in core_consultation:
-- booking id the consultation's, the slot for 30 minutes, its vet, the
-- section's consultation space of its rank among the slot's placed ones of
-- its section in id order (vc_slot_rank's rk: domestic 1-4, horse 8, 9, 10,
-- farm 12, 13), arrived at its start.
CREATE TEMP TABLE s_agenda AS
SELECT a.c, a.sec, a.vet, s0, (row_number() OVER (PARTITION BY s0, a.sec ORDER BY a.c) - 1)::integer AS rk
  FROM s_env AS v,
       generate_series(v.ls + interval '8 hours', v.le, interval '30 minutes') AS s0,
       pg_temp.vc_agenda(s0, v.e, v.o) AS a
 WHERE s0::time BETWEEN time '08:00' AND time '19:30' AND extract(isodow FROM s0) < 7;
ALTER TABLE s_agenda ADD PRIMARY KEY (c);

CREATE TEMP TABLE s_cons AS
SELECT g.c, g.sec, g.vet, g.s0, g.rk, k.vet_id, k.animal_id, k.started_at, k.referral_id
  FROM s_env AS v, s_agenda AS g, pg_temp.core_consultation(g.c, v.e, v.o) AS k;

INSERT INTO s_book (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, booked_at, booked_by,
                    arrived_at)
SELECT c.c, t.type_id, 'consultation', c.animal_id, c.sec, x.s, x.s + interval '30 minutes', 'arrived',
       CASE WHEN c.referral_id IS NOT NULL THEN 'referral' WHEN t.type_id IN (2, 7, 11) THEN 'follow-up'
            WHEN pg_temp.sched_u(c.c, 1314) < 0.75 THEN 'phone' ELSE 'desk' END,
       greatest(pg_temp.sched_office(x.s - l.lead, c.c, x.s - interval '1 hour'),
                (pg_temp.sched_patient(c.animal_id)).registered_at + interval '2 minutes'),
       67 + (c.c % 4), c.started_at
  FROM s_env AS v, s_cons AS c,
       LATERAL (SELECT pg_temp.sched_utc(c.s0, v.o) AS s) AS x,
       LATERAL (SELECT pg_temp.sched_ctype(c.sec, c.referral_id IS NOT NULL, c.c) AS type_id) AS t,
       -- lead time: 30 % within two days, 50 % within two weeks, 20 % up to six weeks
       LATERAL (SELECT CASE WHEN u < 0.3 THEN 2 * u / 0.3 WHEN u < 0.8 THEN 2 + 12 * (u - 0.3) / 0.5
                            ELSE 14 + 28 * (u - 0.8) / 0.2 END * interval '1 day' AS lead
                  FROM (SELECT pg_temp.sched_u(c.c, 1315) AS u) AS z) AS l;
INSERT INTO s_alloc (booking_id, ord, staff_id, room_id, role, starts_at, ends_at)
SELECT b.id, 1, c.vet_id, NULL, 'vet', b.starts_at, b.ends_at FROM s_book AS b JOIN s_cons AS c ON c.c = b.id
UNION ALL
SELECT b.id, 2, NULL, (CASE c.sec WHEN 3 THEN ARRAY[1, 2, 3, 4] WHEN 1 THEN ARRAY[8, 9, 10] ELSE ARRAY[12, 13] END)[c.rk + 1],
       'room', b.starts_at, b.ends_at
  FROM s_book AS b JOIN s_cons AS c ON c.c = b.id;
ANALYZE s_book, s_alloc;

-- --- Blocks (types 28, 29): each week's, to the end of the published rota ---------------------

-- The MRI's quality assurance on Wednesday 08:00-10:00 (machine 9), each
-- CT's service on Tuesday (7) and Thursday (8) 07:00-08:00, each theatre's
-- deep clean on Friday afternoon (6, 7, 11 16:00-18:00, 13 14:00-16:00):
-- at the first free start that day from the planned one, on the 30-minute
-- grid. Booked with the rota, the Friday 12:00 ten days before its week;
-- held once past.
DO $$
DECLARE
    v s_env; w timestamp; b record; s timestamptz; bid integer; ok boolean;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR w IN SELECT generate_series(v.ls, v.pub_end - interval '7 days', interval '7 days') LOOP
        FOR b IN SELECT * FROM (VALUES ('machine', 9, 2, time '08:00', 120), ('machine', 7, 1, time '07:00', 60),
                                       ('machine', 8, 3, time '07:00', 60), ('room', 6, 4, time '16:00', 120),
                                       ('room', 7, 4, time '16:00', 120), ('room', 11, 4, time '16:00', 120),
                                       ('room', 13, 4, time '14:00', 120)) AS x (k, rid, dow, at, mins)
        LOOP
            ok := false;
            FOR s IN SELECT g FROM generate_series(pg_temp.sched_utc(w + (b.dow - 1) * interval '1 day' + time '07:00', v.o),
                                                   pg_temp.sched_utc(w + (b.dow - 1) * interval '1 day' + time '18:00', v.o),
                                                   interval '30 minutes') AS g
                      ORDER BY abs(extract(epoch FROM g - pg_temp.sched_utc(w + (b.dow - 1) * interval '1 day' + b.at, v.o))), g
            LOOP
                CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_temp.sched_slots(b.k, b.rid, b.mins * interval '1 minute', s, s, v.o));
                IF b.k = 'machine' THEN
                    ok := pg_temp.sched_machine_free(b.rid, s, s + b.mins * interval '1 minute');
                ELSE
                    ok := pg_temp.sched_room_free(b.rid, s, s + b.mins * interval '1 minute');
                END IF;
                EXIT WHEN ok;
            END LOOP;
            CONTINUE WHEN NOT ok;
            bid := CASE WHEN s >= v.e THEN nextval('pg_temp.s_ahead') ELSE nextval('pg_temp.s_block') END;
            INSERT INTO s_book (id, type_id, kind, section_id, starts_at, ends_at, state, source, booked_at, notes)
            VALUES (bid, CASE b.k WHEN 'machine' THEN 28 ELSE 29 END, 'block', NULL, s, s + b.mins * interval '1 minute',
                    CASE WHEN s + b.mins * interval '1 minute' <= v.e THEN 'held' ELSE 'booked' END, 'planned',
                    pg_temp.sched_utc(w - interval '10 days' + interval '12 hours', v.o),
                    CASE WHEN b.k = 'room' THEN 'deep clean: room ' WHEN b.rid = 9 THEN 'quality assurance: machine '
                         ELSE 'service: machine ' END || b.rid);
            INSERT INTO s_alloc (booking_id, ord, room_id, machine_id, role, starts_at, ends_at)
            VALUES (bid, 1, CASE b.k WHEN 'room' THEN b.rid END, CASE b.k WHEN 'machine' THEN b.rid END,
                    b.k, s, s + b.mins * interval '1 minute');
        END LOOP;
    END LOOP;
END $$;

-- --- Imaging: one booking per imaging request the core sent (D376, D372) -----------------------

-- Booking 30 000 + the request's id, of the section's type for its code's
-- machine, its operator (a radiographer, or an imaging vet for an
-- ultrasound) on a shift covering it, on-call included: an urgent one at
-- the first free slot from ten minutes after its request, on its machine's
-- hours; a routine one at the first free slot of the imaging day (Monday
-- to Friday 08:00-18:00) from an hour after it, so within two working days.
-- arrived when started before T0 (cancelled when the request was), else
-- booked.
CREATE TEMP TABLE s_req AS
SELECT n, r.code, r.animal_id, r.requested_at, r.priority, r.state, r.sent_at, r.cancelled_at,
       CASE WHEN r.animal_id <= 14600 THEN 3 WHEN r.animal_id <= 16000 THEN 1 ELSE 2 END AS sec
  FROM s_env AS v, generate_series(1, 17000) AS n, pg_temp.core_request(n, v.e, v.o) AS r
 WHERE r.kind = 'imaging' AND r.sent_at IS NOT NULL;

DO $$
DECLARE
    v s_env; q record; m integer; ty integer; dur interval; s timestamptz; op integer; ops integer[];
    found_ boolean; lo timestamptz;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR q IN SELECT r.*, c.m_dom, c.m_horse, c.m_farm FROM s_req AS r JOIN s_code AS c ON c.code = r.code ORDER BY r.n LOOP
        m := CASE q.sec WHEN 3 THEN q.m_dom WHEN 1 THEN q.m_horse ELSE q.m_farm END;
        SELECT t.id, t.duration_minutes * interval '1 minute' INTO ty, dur
          FROM sched_types AS t WHERE t.kind = 'imaging' AND t.machine_id = m AND t.section_id = q.sec;
        IF ty IS NULL THEN
            RAISE EXCEPTION 'load.sql: request % (code %, section %) has no imaging type', q.n, q.code, q.sec;
        END IF;
        ops := CASE WHEN m IN (14, 15) THEN ARRAY[26, 27, 28] ELSE ARRAY[52, 53, 54, 55] END;
        lo := q.requested_at + CASE WHEN q.priority = 'urgent' THEN interval '10 minutes' ELSE interval '1 hour' END;
        found_ := false;
        FOR s IN SELECT x FROM pg_temp.sched_slots('machine', m, dur, lo, lo + interval '6 days', v.o) AS x LOOP
            CONTINUE WHEN q.priority = 'routine'
                AND NOT (extract(isodow FROM pg_temp.sched_local(s, v.o)) <= 5
                         AND pg_temp.sched_local(s, v.o)::time >= time '08:00'
                         AND pg_temp.sched_local(s + dur, v.o) <= pg_temp.sched_local(s, v.o)::date + time '18:00');
            CONTINUE WHEN NOT pg_temp.sched_machine_free(m, s, s + dur);
            SELECT o INTO op FROM unnest(ops) AS o
             WHERE pg_temp.sched_free(o, s, s + dur, true) ORDER BY pg_temp.sched_u(q.n * 8 + o, 1320) LIMIT 1;
            IF op IS NOT NULL THEN found_ := true; EXIT; END IF;
        END LOOP;
        IF NOT found_ THEN
            RAISE EXCEPTION 'load.sql: imaging request % finds no slot on machine % within six days', q.n, m;
        END IF;
        INSERT INTO s_book (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, request_id,
                            booked_at, arrived_at, cancelled_at, cancel_reason)
        VALUES (30000 + q.n, ty, 'imaging', q.animal_id, q.sec, s, s + dur,
                CASE WHEN q.state = 'cancelled' THEN 'cancelled' WHEN s < v.e THEN 'arrived' ELSE 'booked' END,
                'request', q.n, q.requested_at + interval '1 minute',
                CASE WHEN q.state <> 'cancelled' AND s < v.e
                     THEN s + (5 * pg_temp.sched_u(q.n, 1321) - 2) * interval '1 minute' END,
                CASE WHEN q.state = 'cancelled'
                     THEN greatest(least(q.cancelled_at - interval '2 minutes', s - interval '1 minute'),
                                   q.requested_at + interval '2 minutes') END,
                CASE WHEN q.state = 'cancelled' THEN 'clinic' END);
        INSERT INTO s_alloc (booking_id, ord, machine_id, staff_id, role, starts_at, ends_at, released_at)
        SELECT 30000 + q.n, x.ord, x.mid, x.sid, x.role, s, s + dur,
               (SELECT b.cancelled_at FROM s_book AS b WHERE b.id = 30000 + q.n)
          FROM (VALUES (1, m, NULL::integer, 'machine'), (2, NULL, op, 'operator')) AS x (ord, mid, sid, role);
    END LOOP;
END $$;

-- --- Inbound examinations (D413): booked on their accepted date -------------------------------

-- Booking 28 000 + the exchange's id, for each examination another centre
-- had accepted: the machine its reason and species name (a CT the small-
-- animal CT for a dog or a cat, the large bore otherwise; an MRI the
-- standing MRI for a horse, the 1.5 T otherwise; scintigraphy the gamma
-- camera; a cardiology examination the domestic ultrasound for a dog or a
-- cat, the portable otherwise), its type the species' section's for that
-- machine (the 1.5 T's only type, domestic, for a calf; the gamma camera's,
-- horse); a second opinion or an endoscopy a first referral of the species'
-- section, with a vet and a consultation space. On the accepted date's
-- imaging day (Monday to Friday 08:00-18:00), at its first free slot, else
-- the first after. No animal: the partner's patient is not registered.
CREATE TEMP TABLE s_exch AS
SELECT n, x.reason, x.partner_species AS species, x.accepted_for, x.answered_at, x.state,
       CASE x.partner_species WHEN 'horse' THEN 1 WHEN 'cow' THEN 2 ELSE 3 END AS sec
  FROM s_env AS v, generate_series(1, 700) AS n, pg_temp.core_exchange(n, v.e, v.o) AS x
 WHERE x.direction = 'in' AND x.kind = 'examination' AND x.answer = 'accepted';

DO $$
DECLARE
    v s_env; q record; m integer; ty integer; dur interval; s timestamptz; who integer; room integer;
    found_ boolean; lo timestamptz;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR q IN SELECT * FROM s_exch ORDER BY n LOOP
        m := CASE q.reason
               WHEN 'CT examination' THEN CASE WHEN q.species IN ('dog', 'cat') THEN 7 ELSE 8 END
               WHEN 'MRI examination' THEN CASE WHEN q.species = 'horse' THEN 10 ELSE 9 END
               WHEN 'scintigraphy' THEN 16
               WHEN 'cardiology examination' THEN CASE WHEN q.species IN ('dog', 'cat') THEN 14 ELSE 15 END END;
        IF m IS NULL THEN
            ty := CASE q.sec WHEN 3 THEN 1 WHEN 1 THEN 6 ELSE 10 END;
        ELSE
            SELECT t.id INTO ty FROM sched_types AS t
             WHERE t.kind = 'imaging' AND t.machine_id = m
             ORDER BY t.section_id = q.sec DESC, t.section_id = 3 DESC, t.id LIMIT 1;
        END IF;
        SELECT t.duration_minutes * interval '1 minute' INTO dur FROM sched_types AS t WHERE t.id = ty;
        lo := greatest(pg_temp.sched_utc(q.accepted_for + time '08:00', v.o), q.answered_at + interval '1 hour');
        found_ := false;
        IF m IS NOT NULL THEN
            FOR s IN SELECT x FROM pg_temp.sched_slots('machine', m, dur, lo, lo + interval '14 days', v.o) AS x LOOP
                CONTINUE WHEN NOT (extract(isodow FROM pg_temp.sched_local(s, v.o)) <= 5
                                   AND pg_temp.sched_local(s, v.o)::time >= time '08:00'
                                   AND pg_temp.sched_local(s + dur, v.o) <= pg_temp.sched_local(s, v.o)::date + time '18:00');
                CONTINUE WHEN NOT pg_temp.sched_machine_free(m, s, s + dur);
                SELECT o INTO who FROM unnest(CASE WHEN m IN (14, 15) THEN ARRAY[26, 27, 28] ELSE ARRAY[52, 53, 54, 55] END) AS o
                 WHERE pg_temp.sched_free(o, s, s + dur, true) ORDER BY o LIMIT 1;
                IF who IS NOT NULL THEN found_ := true; EXIT; END IF;
            END LOOP;
        ELSE
            FOR s IN SELECT x FROM pg_temp.sched_slots('room', CASE q.sec WHEN 3 THEN 1 WHEN 1 THEN 8 ELSE 12 END,
                                                     dur, lo, lo + interval '14 days', v.o) AS x LOOP
                SELECT r INTO room FROM unnest(CASE q.sec WHEN 3 THEN ARRAY[1, 2, 3, 4] WHEN 1 THEN ARRAY[8, 9, 10]
                                                    ELSE ARRAY[12, 13] END) AS r
                 WHERE pg_temp.sched_room_free(r, s, s + dur) ORDER BY r LIMIT 1;
                CONTINUE WHEN room IS NULL;
                SELECT p INTO who FROM generate_series(CASE q.sec WHEN 1 THEN 1 WHEN 2 THEN 11 ELSE 18 END,
                                                       CASE q.sec WHEN 1 THEN 10 WHEN 2 THEN 17 ELSE 25 END) AS p
                 WHERE pg_temp.sched_free(p, s, s + dur) ORDER BY pg_temp.sched_u(q.n * 32 + p, 1322) LIMIT 1;
                IF who IS NOT NULL THEN found_ := true; EXIT; END IF;
            END LOOP;
        END IF;
        IF NOT found_ THEN
            RAISE EXCEPTION 'load.sql: inbound examination % (%, %) finds no slot within 14 days', q.n, q.reason, q.species;
        END IF;
        INSERT INTO s_book (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, exchange_id,
                            booked_at, booked_by, arrived_at)
        VALUES (28000 + q.n, ty, CASE WHEN m IS NULL THEN 'consultation' ELSE 'imaging' END, NULL, q.sec, s, s + dur,
                CASE WHEN s < v.e THEN 'arrived' ELSE 'booked' END, 'exchange', q.n,
                q.answered_at + interval '5 minutes', 67 + (q.n % 4),
                CASE WHEN s < v.e THEN s + (5 * pg_temp.sched_u(q.n, 1323) - 2) * interval '1 minute' END);
        IF m IS NULL THEN
            INSERT INTO s_alloc (booking_id, ord, staff_id, room_id, role, starts_at, ends_at)
            VALUES (28000 + q.n, 1, who, NULL, 'vet', s, s + dur), (28000 + q.n, 2, NULL, room, 'room', s, s + dur);
        ELSE
            INSERT INTO s_alloc (booking_id, ord, staff_id, machine_id, role, starts_at, ends_at)
            VALUES (28000 + q.n, 1, NULL, m, 'machine', s, s + dur), (28000 + q.n, 2, who, NULL, 'operator', s, s + dur);
        END IF;
    END LOOP;
END $$;

-- --- Theatre plans (types 25-27): about 6 a weekday at 1.0, ramped ----------------------------

-- Each weekday's plans (6 at today's rate, from 60 % a year ago; domestic
-- 55 %, horse 35 %, farm 10 % by a hash), each at the first start of its
-- theatre's grid that day with a theatre of the section, its surgeon (a
-- vet of the section in surgery), an anaesthetist (another vet of the
-- section, anaesthesia first) and a nurse of the section free of the
-- agenda and of each other, else the next weekday's; planned two to ten
-- days ahead by the section's planner (its first nurse), its patient alive
-- then. Ahead of T0: the next ten days' plans already made.
DO $$
DECLARE
    v s_env; d date; k integer; j integer; n integer; key bigint; sec integer; ty integer; dur interval;
    rooms integer[]; s timestamptz; th integer; sg integer; an integer; nu integer; found_ boolean;
    bdate timestamptz; animal integer; bid integer; tries integer; day date; i integer;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR d IN SELECT g::date FROM generate_series(v.ls::date, v.le::date + 10, interval '1 day') AS g
              WHERE extract(isodow FROM g) <= 5 LOOP
        -- the weekday's plans: C(i + 1) - C(i), C(i) = 6 (0.6 i + 0.2 i^2 / 260) over the
        -- weekdays since S (6 a weekday at T0, 3.6 a year before)
        i := (SELECT count(*) FROM generate_series(v.ls::date, d - 1, interval '1 day') AS g
               WHERE extract(isodow FROM g) <= 5)::integer;
        n := floor(6 * (0.6 * (i + 1) + 0.2 * (i + 1) ^ 2 / 260))::integer - floor(6 * (0.6 * i + 0.2 * i ^ 2 / 260))::integer;
        FOR j IN 1..n LOOP
            key := (d - date '2000-01-03')::bigint * 16 + j;
            sec := CASE WHEN pg_temp.sched_u(key, 1330) < 0.55 THEN 3 WHEN pg_temp.sched_u(key, 1330) < 0.90 THEN 1
                        ELSE 2 END;
            ty := CASE sec WHEN 3 THEN 25 WHEN 1 THEN 26 ELSE 27 END;
            SELECT t.duration_minutes * interval '1 minute' INTO dur FROM sched_types AS t WHERE t.id = ty;
            rooms := CASE sec WHEN 3 THEN ARRAY[6, 7] WHEN 1 THEN ARRAY[11] ELSE ARRAY[13] END;
            found_ := false; tries := 0; day := d;
            WHILE NOT found_ AND tries < 5 LOOP
                FOR s, th IN SELECT x2, r FROM unnest(rooms) AS r,
                                    pg_temp.sched_slots('room', r, dur, pg_temp.sched_utc(day + time '00:00', v.o),
                                                        pg_temp.sched_utc(day + time '23:59', v.o), v.o,
                                                        interval '30 minutes') AS x2
                              ORDER BY x2, r LOOP
                    CONTINUE WHEN NOT pg_temp.sched_room_free(th, s, s + dur);
                    SELECT p INTO sg FROM generate_series(1, 25) AS p
                     WHERE ((p IN (1, 3, 7) AND sec = 1) OR (p = 13 AND sec = 2) OR (p IN (19, 22) AND sec = 3))
                       AND pg_temp.sched_free(p, s, s + dur) ORDER BY pg_temp.sched_u(key * 32 + p, 1331) LIMIT 1;
                    CONTINUE WHEN sg IS NULL;
                    SELECT p INTO an FROM generate_series(CASE sec WHEN 1 THEN 1 WHEN 2 THEN 11 ELSE 18 END,
                                                          CASE sec WHEN 1 THEN 10 WHEN 2 THEN 17 ELSE 25 END) AS p
                     WHERE p <> sg AND pg_temp.sched_free(p, s, s + dur)
                     ORDER BY p IN (4, 10, 21) DESC, pg_temp.sched_u(key * 32 + p, 1332) LIMIT 1;
                    CONTINUE WHEN an IS NULL;
                    SELECT p INTO nu FROM generate_series(CASE sec WHEN 1 THEN 29 WHEN 2 THEN 37 ELSE 43 END,
                                                          CASE sec WHEN 1 THEN 36 WHEN 2 THEN 42 ELSE 51 END) AS p
                     WHERE p % 3 <> 0 AND pg_temp.sched_free(p, s, s + dur)
                     ORDER BY pg_temp.sched_u(key * 64 + p, 1333) LIMIT 1;
                    CONTINUE WHEN nu IS NULL;
                    found_ := true; EXIT;
                END LOOP;
                IF NOT found_ THEN
                    tries := tries + 1;
                    day := day + CASE extract(isodow FROM day)::integer WHEN 5 THEN 3 ELSE 1 END;
                END IF;
            END LOOP;
            CONTINUE WHEN NOT found_;
            bdate := pg_temp.sched_office(s - (2 + 8 * pg_temp.sched_u(key, 1334)) * interval '1 day', key, s);
            CONTINUE WHEN bdate >= v.e;                    -- not yet planned at T0
            animal := pg_temp.sched_pick_patient(sec, bdate, key + 7000000);
            CONTINUE WHEN animal IS NULL;
            CONTINUE WHEN (pg_temp.sched_patient(animal)).died_at <= s;
            bid := CASE WHEN s >= v.e THEN nextval('pg_temp.s_ahead') ELSE nextval('pg_temp.s_plan') END;
            INSERT INTO s_book (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, booked_at,
                                booked_by, arrived_at)
            VALUES (bid, ty, 'surgery', animal, sec, s, s + dur, CASE WHEN s < v.e THEN 'arrived' ELSE 'booked' END,
                    'planned', bdate, CASE sec WHEN 1 THEN 29 WHEN 2 THEN 37 ELSE 43 END,
                    CASE WHEN s < v.e THEN s - (5 + 25 * pg_temp.sched_u(key, 1335)) * interval '1 minute' END);
            INSERT INTO s_alloc (booking_id, ord, staff_id, room_id, role, starts_at, ends_at)
            VALUES (bid, 1, NULL, th, 'room', s, s + dur), (bid, 2, sg, NULL, 'surgeon', s, s + dur),
                   (bid, 3, an, NULL, 'anaesthetist', s, s + dur), (bid, 4, nu, NULL, 'nurse', s, s + dur);
        END LOOP;
    END LOOP;
END $$;

-- --- The training centre: sessions and their days (types 30-45) -------------------------------

-- A teaching animal free for a session's two hours from ws (an hour after
-- its 09:00 start): no live allocation over them; under two sessions and
-- four hours that local day with them; never a third day in a row (rule 7).
CREATE FUNCTION pg_temp.sched_animal_ok(a integer, ws timestamptz, o integer) RETURNS boolean
  LANGUAGE sql STABLE AS $$
WITH d AS (SELECT pg_temp.sched_local(ws, o)::date AS d),
used AS (SELECT j FROM d, generate_series(-2, 2) AS j
          WHERE j = 0 OR EXISTS (SELECT 1 FROM s_alloc AS x
                                  WHERE x.animal_id = a AND x.released_at IS NULL
                                    AND x.during && tstzrange(pg_temp.sched_utc((d.d + j)::timestamp, o),
                                                              pg_temp.sched_utc((d.d + j + 1)::timestamp, o), '[)')))
SELECT NOT EXISTS (SELECT 1 FROM s_alloc AS x WHERE x.animal_id = a AND x.released_at IS NULL
                      AND x.during && tstzrange(ws, ws + interval '2 hours', '[)'))
   AND (SELECT count(*) < 2 AND coalesce(sum(x.ends_at - x.starts_at), interval '0') <= interval '2 hours'
          FROM d, s_alloc AS x
         WHERE x.animal_id = a AND x.released_at IS NULL
           AND x.during && tstzrange(pg_temp.sched_utc(d.d::timestamp, o), pg_temp.sched_utc((d.d + 1)::timestamp, o), '[)'))
   AND NOT EXISTS (SELECT 1 FROM generate_series(-2, 0) AS k
                    WHERE (SELECT count(*) FROM used WHERE j BETWEEN k AND k + 2) > 2)
$$;
-- An instructor free over [s, e): within the planned rota by its shifts
-- (sched_free); beyond it by the core's pattern, absences included.
CREATE FUNCTION pg_temp.sched_free_instructor(p integer, t0 timestamptz, t1 timestamptz) RETURNS boolean
  LANGUAGE sql STABLE AS $$
SELECT CASE WHEN t1 <= (SELECT pg_temp.sched_utc(v.plan_end, v.o) FROM s_env AS v) THEN pg_temp.sched_free(p, t0, t1)
            ELSE EXISTS (SELECT 1 FROM s_env AS v, pg_temp.core_shifts(p, pg_temp.sched_local(t0, v.o)::date, v.o) AS x
                          WHERE x.starts_at <= t0 AND x.ends_at >= t1 AND x.absence IS NULL)
                 AND NOT EXISTS (SELECT 1 FROM s_alloc AS a WHERE a.staff_id = p AND a.released_at IS NULL
                                    AND a.during && tstzrange(t0, t1, '[)')) END
$$;

CREATE TEMP TABLE s_session (id integer PRIMARY KEY, course_id integer, first_on date, last_on date, led_by integer,
                             state text);

-- Sessions 1-100 held over the year, evenly (about two a week); 101-125
-- planned over the next three months, open when within eight weeks. Each a
-- course by a hash, on its days in a row Monday to Friday, 09:00-16:00 on a
-- room of its kind (a classroom, the practical hall, the horse section's
-- arena) and its lead instructor every day, its teaching animals the lowest
-- ids free within their limits each day from 10:00 to 12:00; from its target
-- day, else the next that fits (six weeks at most: the arena is the horse
-- section's third consultation space, taken on about half the weekdays),
-- else the next course in order.
DO $$
DECLARE
    v s_env; i integer; c sched_courses; d date; k integer; s timestamptz; rm integer; ins integer; cc integer;
    ok boolean; target date; held boolean; bid integer; an integer[]; animals integer[]; day_s timestamptz;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR i IN 1..125 LOOP
        held := i <= 100;
        target := CASE WHEN held THEN v.ls::date + floor((i - 0.5) * 358 / 100)::integer
                       ELSE v.le::date + 1 + floor((i - 100 - 0.5) * 90 / 25)::integer END;
        ok := false;
        FOR cc IN 0..15 LOOP
        SELECT * INTO c FROM sched_courses WHERE id = 1 + (floor(16 * pg_temp.sched_u(i, 1340))::integer + cc) % 16;
        FOR d IN SELECT g::date FROM generate_series(target, target + 41, interval '1 day') AS g LOOP
            CONTINUE WHEN extract(isodow FROM d) + c.days - 1 > 5;
            CONTINUE WHEN held AND d + c.days - 1 >= v.le::date;
            CONTINUE WHEN NOT held AND d <= v.le::date;
            FOR rm IN SELECT r.id FROM sched_rooms AS r WHERE r.kind = c.room_kind ORDER BY r.id LOOP
                ok := true;
                FOR k IN 0..c.days - 1 LOOP
                    s := pg_temp.sched_utc((d + k) + time '09:00', v.o);
                    IF NOT pg_temp.sched_room_free(rm, s, s + interval '7 hours')
                       OR NOT EXISTS (SELECT 1 FROM pg_temp.sched_slots('room', rm, interval '7 hours', s, s, v.o)
                                      UNION ALL SELECT 1 WHERE rm = 10 AND EXISTS (
                                          SELECT 1 FROM sched_hours AS h WHERE h.resource_kind = 'room' AND h.resource_id = 10
                                             AND h.weekday = extract(isodow FROM d + k) AND h.opens <= time '09:00'
                                             AND h.closes >= time '16:00')) THEN
                        ok := false; EXIT;
                    END IF;
                END LOOP;
                EXIT WHEN ok;
            END LOOP;
            CONTINUE WHEN NOT ok;
            SELECT p INTO ins FROM generate_series(81, 85) AS p
             WHERE NOT EXISTS (SELECT 1 FROM generate_series(0, c.days - 1) AS kk
                                WHERE NOT pg_temp.sched_free_instructor(p, pg_temp.sched_utc((d + kk) + time '09:00', v.o),
                                                                        pg_temp.sched_utc((d + kk) + time '16:00', v.o)))
             ORDER BY pg_temp.sched_u(i * 8 + p, 1341) LIMIT 1;
            IF ins IS NULL THEN ok := false; CONTINUE; END IF;
            -- the animals, day by day, written as they are taken (the limits read them)
            animals := ARRAY[]::integer[];
            FOR k IN 0..c.days - 1 LOOP
                day_s := pg_temp.sched_utc((d + k) + time '10:00', v.o);
                SELECT array_agg(a ORDER BY a) INTO an
                  FROM (SELECT a FROM generate_series(CASE c.species WHEN 'canine' THEN 1 ELSE 14601 END,
                                                      CASE c.species WHEN 'canine' THEN 12 ELSE 14608 END) AS a
                         WHERE c.teaching_animals > 0 AND pg_temp.sched_animal_ok(a, day_s, v.o)
                         ORDER BY a LIMIT c.teaching_animals) AS y;
                IF c.teaching_animals > 0 AND coalesce(cardinality(an), 0) < c.teaching_animals THEN
                    ok := false; EXIT;
                END IF;
                bid := CASE WHEN held THEN nextval('pg_temp.s_sday') ELSE nextval('pg_temp.s_ahead') END;
                s := pg_temp.sched_utc((d + k) + time '09:00', v.o);
                INSERT INTO s_book (id, type_id, kind, section_id, starts_at, ends_at, state, source, session_id,
                                    booked_at, booked_by)
                VALUES (bid, 29 + c.id, 'session', CASE c.species WHEN 'equine' THEN 1 END, s, s + interval '7 hours',
                        CASE WHEN held THEN 'held' ELSE 'booked' END, 'planned', i,
                        least(pg_temp.sched_office(pg_temp.sched_utc(d - 91 + time '10:00', v.o), i, v.e),
                              v.e - interval '1 day'), ins);
                INSERT INTO s_alloc (booking_id, ord, room_id, staff_id, animal_id, role, starts_at, ends_at)
                SELECT bid, 1, rm, NULL::integer, NULL::integer, 'room', s, s + interval '7 hours'
                UNION ALL SELECT bid, 2, NULL, ins, NULL, 'instructor', s, s + interval '7 hours'
                UNION ALL SELECT bid, (2 + o)::integer, NULL, NULL, a::integer, 'teaching', day_s, day_s + interval '2 hours'
                            FROM unnest(an) WITH ORDINALITY AS u (a, o);
            END LOOP;
            IF NOT ok THEN      -- the animals failed on a later day: undo this session's days, try the next day
                DELETE FROM s_alloc WHERE booking_id IN (SELECT id FROM s_book WHERE session_id = i);
                DELETE FROM s_book WHERE session_id = i;
                CONTINUE;
            END IF;
            INSERT INTO s_session VALUES (i, c.id, d, d + c.days - 1, ins,
                                          CASE WHEN held THEN 'held' WHEN d <= v.le::date + 56 THEN 'open'
                                               ELSE 'planned' END);
            EXIT;
        END LOOP;
        EXIT WHEN ok;
        END LOOP;
        IF NOT ok THEN
            RAISE EXCEPTION 'load.sql: session % finds no course and days within six weeks of %', i, target;
        END IF;
    END LOOP;
END $$;

-- --- Consultation bookings around the agenda (25 001-28 000; the agenda ahead) ---------------

-- The first free consultation slot of section sec from t0 to t1: a space of
-- the section (the lowest free) and a vet of the section on a shift
-- covering it with no absence, free (by a hash of the slot and the key).
CREATE FUNCTION pg_temp.sched_consult_slot(sec integer, t0 timestamptz, t1 timestamptz, key bigint,
                                           OUT s timestamptz, OUT room integer, OUT vet integer)
  LANGUAGE plpgsql STABLE AS $$
DECLARE o integer;
BEGIN
    SELECT s_env.o INTO o FROM s_env;
    FOR s IN SELECT x FROM pg_temp.sched_slots('room', CASE sec WHEN 3 THEN 1 WHEN 1 THEN 8 ELSE 12 END,
                                               interval '30 minutes', t0, t1, o) AS x LOOP
        SELECT r INTO room FROM unnest(CASE sec WHEN 3 THEN ARRAY[1, 2, 3, 4] WHEN 1 THEN ARRAY[8, 9, 10]
                                            ELSE ARRAY[12, 13] END) AS r
         WHERE pg_temp.sched_room_free(r, s, s + interval '30 minutes') ORDER BY r LIMIT 1;
        CONTINUE WHEN room IS NULL;
        SELECT p INTO vet FROM generate_series(CASE sec WHEN 1 THEN 1 WHEN 2 THEN 11 ELSE 18 END,
                                               CASE sec WHEN 1 THEN 10 WHEN 2 THEN 17 ELSE 25 END) AS p
         WHERE pg_temp.sched_free(p, s, s + interval '30 minutes')
         ORDER BY pg_temp.sched_u(key * 32 + p, 1352) LIMIT 1;
        IF vet IS NOT NULL THEN RETURN; END IF;
    END LOOP;
    s := NULL; room := NULL; vet := NULL;
END $$;

-- A local hour drawn from a section's consultation hours on weekday dow
-- (the core's shapes: domestic busiest late in the afternoon, Saturday
-- mornings; horse and farm in the morning), as an offset from 00:00.
CREATE FUNCTION pg_temp.sched_hour(sec integer, dow integer, u float8) RETURNS interval
  LANGUAGE sql IMMUTABLE AS $$
WITH w AS (SELECT CASE WHEN sec = 3 AND dow = 6 THEN ARRAY[1, 1, 1, 1, 1]::float8[]
                       WHEN sec = 3 THEN ARRAY[0.5, 0.6, 0.8, 0.8, 0.4, 0.6, 1.0, 1.0, 1.2, 1.4, 1.4, 0.6]
                       ELSE ARRAY[1.0, 1.2, 1.2, 1.0, 0.5, 0, 0.4, 0.3] END AS w),
c AS (SELECT h, sum(w.w[h]) OVER (ORDER BY h) / (SELECT sum(x) FROM unnest(w.w) AS x) AS cum, w.w[h] AS wh,
             (SELECT sum(x) FROM unnest(w.w) AS x) AS tot
        FROM w, generate_series(1, cardinality(w.w)) AS h)
SELECT (7 + h) * interval '1 hour'
       + ((u - (cum - wh / tot)) / (wh / tot)) * interval '1 hour'
  FROM c WHERE u < cum ORDER BY h LIMIT 1
$$;

-- The history's 3 000 consultation bookings not attended: about 2 100
-- cancelled ahead and 900 not attended (game values), ramped as the core's
-- volumes; each at the first free slot from its drawn time (section 75/18/7,
-- the section's hours), so around the agenda; its patient alive when
-- booked. A no-show's allocations stay live; a cancelled one's are released
-- at its cancellation (owner, clinic, moved; deceased when its animal died
-- before it).
DO $$
DECLARE
    v s_env; k integer; sec integer; t timestamptz; r record; bdate timestamptz; animal integer; died timestamptz;
    state_ text; cat timestamptz; reason text; ty integer; bid integer; u float8;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR k IN 1..3000 LOOP
        u := pg_temp.sched_u(k, 1350);
        sec := CASE WHEN u < 0.75 THEN 3 WHEN u < 0.93 THEN 1 ELSE 2 END;
        t := v.s + pg_temp.sched_ramp((k - 0.5) / 3000) * (v.e - interval '2 hours' - v.s);
        t := pg_temp.sched_utc(pg_temp.sched_local(t, v.o)::date
                               + pg_temp.sched_hour(sec, extract(isodow FROM pg_temp.sched_local(t, v.o))::integer,
                                                    pg_temp.sched_u(k, 1353)), v.o);
        SELECT * INTO r FROM pg_temp.sched_consult_slot(sec, t, least(t + interval '7 days', v.e - interval '1 hour'),
                                                        25000 + k);
        CONTINUE WHEN r.s IS NULL;
        ty := pg_temp.sched_ctype(sec, pg_temp.sched_u(k, 1354) < 0.21, 25000 + k);
        bdate := pg_temp.sched_office(r.s - CASE WHEN pg_temp.sched_u(k, 1355) < 0.3 THEN 2 * pg_temp.sched_u(k, 1356)
                                                 WHEN pg_temp.sched_u(k, 1355) < 0.8 THEN 2 + 12 * pg_temp.sched_u(k, 1356)
                                                 ELSE 14 + 28 * pg_temp.sched_u(k, 1356) END * interval '1 day',
                                      25000 + k, r.s - interval '1 hour');
        animal := pg_temp.sched_pick_patient(sec, bdate, 25000 + k);
        CONTINUE WHEN animal IS NULL;
        died := (pg_temp.sched_patient(animal)).died_at;
        IF died IS NOT NULL AND died < r.s THEN
            state_ := 'cancelled'; reason := 'deceased';
            cat := least(died + (10 + 110 * pg_temp.sched_u(k, 1357)) * interval '1 minute', r.s - interval '1 minute');
        ELSIF pg_temp.sched_u(k, 1351) < 0.3 THEN
            state_ := 'no-show'; reason := NULL; cat := NULL;
        ELSE
            state_ := 'cancelled';
            reason := CASE WHEN pg_temp.sched_u(k, 1358) < 0.70 THEN 'owner' WHEN pg_temp.sched_u(k, 1358) < 0.95 THEN 'clinic'
                           ELSE 'moved' END;
            cat := bdate + (0.05 + 0.9 * pg_temp.sched_u(k, 1359)) * (r.s - bdate);
        END IF;
        bid := nextval('pg_temp.s_missed');
        INSERT INTO s_book (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, booked_at,
                            booked_by, cancelled_at, cancel_reason)
        VALUES (bid, ty, 'consultation', animal, sec, r.s, r.s + interval '30 minutes', state_,
                CASE WHEN ty IN (1, 6, 10) THEN 'referral' WHEN ty IN (2, 7, 11) THEN 'follow-up'
                     WHEN pg_temp.sched_u(k, 1314) < 0.75 THEN 'phone' ELSE 'desk' END,
                bdate, 67 + (k % 4), cat, reason);
        INSERT INTO s_alloc (booking_id, ord, staff_id, room_id, role, starts_at, ends_at, released_at)
        VALUES (bid, 1, r.vet, NULL, 'vet', r.s, r.s + interval '30 minutes', cat),
               (bid, 2, NULL, r.room, 'room', r.s, r.s + interval '30 minutes', cat);
    END LOOP;
END $$;

-- The agenda ahead (49 001-50 000 with the plans, blocks and session days
-- ahead): for each day of the next six weeks and each section, the
-- consultations already booked at T0, the day's demand (domestic 58.5 a
-- weekday and 30 on Saturday, horse 14, farm 5.5) by the share of the lead
-- times longer than the day's distance (30 % within two days, 50 % within
-- two weeks, 20 % up to six weeks): the next days nearly full, thinning out.
-- Each at the first free slot from a drawn hour of the day, else from the
-- day's opening; its patient alive at T0; booked in the last two weeks, at
-- reception's hours.
DO $$
DECLARE
    v s_env; dd integer; d date; sec integer; n integer; j integer; key bigint; dem float8; p float8; t timestamptz;
    r record; bdate timestamptz; animal integer; died timestamptz; ty integer; bid integer; dow integer;
    rest float8;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR dd IN 0..41 LOOP
        d := v.le::date + dd;
        dow := extract(isodow FROM d)::integer;
        FOR sec IN SELECT unnest(ARRAY[3, 1, 2]) LOOP
            dem := CASE WHEN dow = 7 THEN 0 WHEN dow = 6 THEN CASE sec WHEN 3 THEN 30 ELSE 0 END
                        ELSE CASE sec WHEN 3 THEN 58.5 WHEN 1 THEN 14 ELSE 5.5 END END;
            p := CASE WHEN dd < 2 THEN 1 - 0.15 * dd WHEN dd < 14 THEN 0.7 - 0.5 * (dd - 2) / 12.0
                      ELSE 0.2 - 0.2 * (dd - 14) / 28.0 END;
            -- today: the share of the section's hours still ahead
            rest := CASE WHEN dd > 0 THEN 1 ELSE
                      greatest(0, least(1, extract(epoch FROM (d + CASE WHEN sec = 3 AND dow = 6 THEN time '13:00'
                                                                        WHEN sec = 3 THEN time '20:00'
                                                                        ELSE time '16:00' END) - v.le) / 3600.0
                                           / CASE WHEN sec = 3 AND dow = 6 THEN 5 WHEN sec = 3 THEN 12 ELSE 8 END)) END;
            n := round(0.95 * dem * p * rest);
            FOR j IN 1..n LOOP
                key := (d - date '2000-01-03')::bigint * 1000 + sec * 100 + j;
                t := greatest(pg_temp.sched_utc(d + pg_temp.sched_hour(sec, dow, pg_temp.sched_u(key, 1360)), v.o),
                              v.e + interval '10 minutes');
                SELECT * INTO r FROM pg_temp.sched_consult_slot(sec, t, pg_temp.sched_utc(d + time '23:59', v.o), key);
                IF r.s IS NULL THEN
                    SELECT * INTO r FROM pg_temp.sched_consult_slot(sec, greatest(pg_temp.sched_utc(d + time '00:00', v.o),
                                                                                  v.e + interval '10 minutes'),
                                                                    pg_temp.sched_utc(d + time '23:59', v.o), key);
                END IF;
                CONTINUE WHEN r.s IS NULL;
                bdate := pg_temp.sched_office(v.e - (0.02 + 0.98 * pg_temp.sched_u(key, 1361))
                                                    * least(r.s - v.e + interval '6 hours', interval '14 days'),
                                              key, v.e - interval '10 minutes');
                animal := pg_temp.sched_pick_patient(sec, bdate, key + 5000000);
                CONTINUE WHEN animal IS NULL;
                died := (pg_temp.sched_patient(animal)).died_at;
                CONTINUE WHEN died IS NOT NULL;
                ty := pg_temp.sched_ctype(sec, pg_temp.sched_u(key, 1354) < 0.21, key);
                bid := nextval('pg_temp.s_ahead');
                INSERT INTO s_book (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source,
                                    booked_at, booked_by)
                VALUES (bid, ty, 'consultation', animal, sec, r.s, r.s + interval '30 minutes', 'booked',
                        CASE WHEN ty IN (1, 6, 10) THEN 'referral' WHEN ty IN (2, 7, 11) THEN 'follow-up'
                             WHEN pg_temp.sched_u(key, 1314) < 0.75 THEN 'phone' ELSE 'desk' END,
                        bdate, 67 + (j % 4));
                INSERT INTO s_alloc (booking_id, ord, staff_id, room_id, role, starts_at, ends_at)
                VALUES (bid, 1, r.vet, NULL, 'vet', r.s, r.s + interval '30 minutes'),
                       (bid, 2, NULL, r.room, 'room', r.s, r.s + interval '30 minutes');
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- --- Trainees and enrolments ---------------------------------------------------------------------

-- Each held session's enrolments: its seats less up to two, one in
-- twenty-five more cancelled; each attended day 95 % of the time by a hash,
-- attended at 80 % of the hours certified (rule 8) when the session closed,
-- else a no-show for one in twenty. An open session's enrolments so far
-- (fuller as it nears; waitlisted past its seats, the session full); a
-- planned one has none. A trainee is new, of the course's audience, in
-- three enrolments of five, else an earlier one of that audience; a vet
-- one in two a core referring vet.
CREATE TEMP TABLE s_trainee (id integer PRIMARY KEY, kind text, registered_at timestamptz);
CREATE TEMP TABLE s_enrol (id integer PRIMARY KEY, session_id integer, trainee_id integer, enrolled_at timestamptz,
                           state text, hours numeric(4,1), certificate text, issued_at timestamptz);
DO $$
DECLARE
    v s_env; ss record; m integer; j integer; key bigint; who integer; at_ timestamptz; st text; hrs numeric;
    eid integer := 0; tid integer := 0; att integer; lo timestamptz; days_ahead integer; seats integer;
BEGIN
    SELECT * INTO v FROM s_env;
    FOR ss IN SELECT s.*, c.audience, c.days, c.hours, c.seats FROM s_session AS s JOIN sched_courses AS c ON c.id = s.course_id
               ORDER BY s.first_on, s.id LOOP
        IF ss.state = 'held' THEN
            m := ss.seats - floor(3 * pg_temp.sched_u(ss.id, 1370))::integer;
            m := m + (pg_temp.sched_u(ss.id, 1371) < 0.5)::integer;      -- the cancelled one, one session in two
        ELSIF ss.state = 'open' THEN
            days_ahead := ss.first_on - v.le::date;
            m := round(ss.seats * (1.15 - days_ahead / 56.0) * (0.8 + 0.4 * pg_temp.sched_u(ss.id, 1372)));
            m := greatest(m, 1);
        ELSE
            m := 0;
        END IF;
        lo := pg_temp.sched_utc(ss.first_on - 56 + time '09:00', v.o);
        seats := 0;
        FOR j IN 1..m LOOP
            key := ss.id * 100 + j;
            at_ := pg_temp.sched_office(lo + (j - 0.5) / m * (least(pg_temp.sched_utc(ss.first_on - 1 + time '12:00', v.o),
                                                                    v.e - interval '1 hour') - lo),
                                        key, v.e - interval '10 minutes');
            who := NULL;
            IF pg_temp.sched_u(key, 1373) >= 0.6 OR tid >= 750 THEN
                SELECT t.id INTO who FROM s_trainee AS t
                 WHERE t.kind = ss.audience AND t.registered_at < at_
                   AND NOT EXISTS (SELECT 1 FROM s_enrol AS e WHERE e.session_id = ss.id AND e.trainee_id = t.id)
                 ORDER BY pg_temp.sched_u(key * 1000 + t.id, 1374) LIMIT 1;
            END IF;
            IF who IS NULL THEN
                IF tid >= 750 THEN CONTINUE; END IF;
                tid := tid + 1; who := tid;
                INSERT INTO s_trainee VALUES (tid, ss.audience, at_ - interval '2 minutes');
            END IF;
            eid := eid + 1;
            hrs := NULL;
            IF ss.state = 'held' THEN
                IF j = m AND pg_temp.sched_u(ss.id, 1371) < 0.5 THEN
                    st := 'cancelled';
                ELSIF pg_temp.sched_u(key, 1375) < 0.05 THEN
                    st := 'no-show'; hrs := 0;
                ELSE
                    att := (SELECT count(*) FROM generate_series(1, ss.days) AS g WHERE pg_temp.sched_u(key * 4 + g, 1376) < 0.95);
                    st := CASE WHEN att = 0 THEN 'no-show' ELSE 'attended' END;
                    hrs := 7 * att;
                END IF;
            ELSE
                seats := seats + 1;
                st := CASE WHEN seats <= ss.seats THEN 'enrolled' ELSE 'waitlisted' END;
            END IF;
            INSERT INTO s_enrol VALUES (eid, ss.id, who, at_, st, hrs,
                CASE WHEN st = 'attended' AND hrs >= 0.8 * ss.hours
                     THEN 'AVH-TC-' || lpad(ss.id::text, 3, '0') || '-' || lpad(eid::text, 4, '0') END,
                CASE WHEN st = 'attended' AND hrs >= 0.8 * ss.hours
                     THEN pg_temp.sched_utc(ss.last_on + time '16:30', v.o) END);
        END LOOP;
        IF ss.state = 'open' AND seats >= ss.seats THEN
            UPDATE s_session SET state = 'full' WHERE id = ss.id;
        END IF;
    END LOOP;
END $$;

INSERT INTO sched_sessions (id, course_id, first_on, last_on, led_by, state)
SELECT id, course_id, first_on, last_on, led_by, state FROM s_session ORDER BY id;

INSERT INTO sched_trainees (id, name, email, phone, kind, practice_id, referring_vet_id, registered_at)
SELECT t.id, f.first || ' ' || f.family,
       lower(f.first || '.' || replace(f.family, ' ', '') || '.t' || t.id) || '@example.org',
       '+999 ' || lpad(((6271 * t.id + 3456789) % 100000000)::text, 8, '0'),
       t.kind, CASE WHEN rv.v IS NOT NULL THEN pg_temp.core_referring_practice(rv.v) END, rv.v, t.registered_at
  FROM s_trainee AS t,
       LATERAL (SELECT (ARRAY['Anna', 'Ben', 'Clara', 'David', 'Elena', 'Felix', 'Greta', 'Hugo', 'Ines', 'Jonas',
                              'Katrin', 'Lukas', 'Marie', 'Niels', 'Olga', 'Paul', 'Rosa', 'Simon', 'Tara', 'Victor'])
                        [1 + floor(20 * pg_temp.sched_u(t.id, 1380))::integer] AS first,
                       (ARRAY['Adler', 'Becker', 'Claes', 'Dubois', 'Engel', 'Fontaine', 'Gerard', 'Hoffmann', 'Jansen',
                              'Keller', 'Lambert', 'Martin', 'Noel', 'Peeters', 'Renard', 'Schmitt', 'Thomas', 'Vogel',
                              'Weber', 'Zimmer'])[1 + floor(20 * pg_temp.sched_u(t.id, 1381))::integer] AS family) AS f,
       LATERAL (SELECT CASE WHEN t.kind = 'vet' AND pg_temp.sched_u(t.id, 1382) < 0.5 THEN 1 + (t.id * 37) % 800 END AS v)
                AS rv
 ORDER BY t.id;

INSERT INTO sched_enrolments (id, session_id, trainee_id, enrolled_at, state, hours_attended, certificate_number, issued_at)
SELECT id, session_id, trainee_id, enrolled_at, state, hours, certificate, issued_at FROM s_enrol ORDER BY id;

-- --- Bookings and allocations, in id order ----------------------------------------------------------

INSERT INTO sched_bookings (id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, request_id,
                            exchange_id, session_id, booked_at, booked_by, notes, arrived_at, cancelled_at, cancel_reason)
SELECT id, type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, request_id, exchange_id, session_id,
       booked_at, booked_by, notes, arrived_at, cancelled_at, cancel_reason
  FROM s_book ORDER BY id;

-- The four exclusion constraints check this statement: no staff member,
-- room, machine or teaching animal allocated twice at once.
INSERT INTO sched_allocations (id, booking_id, staff_id, room_id, machine_id, animal_id, role, starts_at, ends_at,
                               released_at)
SELECT row_number() OVER (ORDER BY booking_id, ord), booking_id, staff_id, room_id, machine_id, animal_id, role,
       starts_at, ends_at, released_at
  FROM s_alloc ORDER BY booking_id, ord;

-- --- The build's checks (vet-scheduling-domain.md, "Loading", "In flight at T0") -------------

DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(x, '; ') INTO bad FROM (
        -- the core's agenda: every attended booking its placed consultation, by id, with its vet
        SELECT 'consultation ' || c.c || ' of the agenda has no attended booking with its vet' AS x
          FROM s_cons AS c
         WHERE NOT EXISTS (SELECT 1 FROM sched_bookings AS b JOIN sched_allocations AS a ON a.booking_id = b.id
                            WHERE b.id = c.c AND b.state = 'arrived' AND a.role = 'vet' AND a.staff_id = c.vet_id)
        UNION ALL
        SELECT 'booking ' || b.id || ' in the attended range is no consultation of the agenda'
          FROM sched_bookings AS b WHERE b.id <= 25000 AND NOT EXISTS (SELECT 1 FROM s_cons AS c WHERE c.c = b.id)
        UNION ALL
        -- every staff allocation on a shift covering it with no absence (on call: an operator only)
        SELECT 'allocation ' || a.id || ' (staff ' || a.staff_id || ', ' || a.role || ') off shift or absent'
          FROM s_env AS v, sched_allocations AS a
         WHERE a.staff_id IS NOT NULL AND a.ends_at <= pg_temp.sched_utc(v.plan_end, v.o)
           AND (NOT EXISTS (SELECT 1 FROM sched_shifts AS h
                             WHERE h.staff_id = a.staff_id AND h.starts_at <= a.starts_at AND h.ends_at >= a.ends_at
                               AND (h.kind <> 'on-call' OR a.role = 'operator'))
                OR EXISTS (SELECT 1 FROM sched_absences AS ab
                            WHERE ab.staff_id = a.staff_id AND ab.from_at < a.ends_at AND ab.until_at > a.starts_at))
        UNION ALL
        -- every room or machine allocation within its resource's hours
        SELECT 'allocation ' || a.id || ' (' || coalesce('room ' || a.room_id, 'machine ' || a.machine_id)
               || ') outside its hours'
          FROM s_env AS v, sched_allocations AS a
         WHERE (a.room_id IS NOT NULL OR a.machine_id IS NOT NULL)
           AND NOT EXISTS (SELECT 1 FROM sched_hours AS h
                            WHERE h.resource_kind = CASE WHEN a.room_id IS NOT NULL THEN 'room' ELSE 'machine' END
                              AND h.resource_id = coalesce(a.room_id, a.machine_id)
                              AND h.weekday = extract(isodow FROM pg_temp.sched_local(a.starts_at, v.o))
                              AND pg_temp.sched_local(a.starts_at, v.o)
                                  >= pg_temp.sched_local(a.starts_at, v.o)::date + h.opens
                              AND pg_temp.sched_local(a.ends_at, v.o)
                                  <= pg_temp.sched_local(a.starts_at, v.o)::date + h.closes)
        UNION ALL
        SELECT 'booking ' || id || ' outside its range (' || kind || ', ' || state || ')'
          FROM s_env AS v, sched_bookings
         WHERE NOT (CASE WHEN starts_at >= v.e AND kind IN ('surgery', 'block', 'session')
                              THEN id BETWEEN 49001 AND 50000
                         WHEN starts_at >= v.e AND kind = 'consultation' AND exchange_id IS NULL
                              THEN id BETWEEN 49001 AND 50000
                         WHEN request_id IS NOT NULL THEN id = 30000 + request_id
                         WHEN exchange_id IS NOT NULL THEN id = 28000 + exchange_id
                         WHEN kind = 'consultation' THEN id BETWEEN 1 AND 28000
                         WHEN kind = 'surgery' THEN id BETWEEN 47001 AND 48300
                         WHEN kind = 'block' THEN id BETWEEN 48301 AND 48700
                         WHEN kind = 'session' THEN id BETWEEN 48701 AND 49000 ELSE false END)
        UNION ALL
        SELECT 'a booking started at or after T0 is ' || state FROM s_env AS v, sched_bookings
         WHERE starts_at >= v.e AND state NOT IN ('booked', 'cancelled')
        UNION ALL
        SELECT 'a booking ended before T0 is still booked' FROM s_env AS v, sched_bookings
         WHERE ends_at < v.e - interval '30 minutes' AND state = 'booked'
        UNION ALL
        SELECT 'booking ' || b.id || ' of a dead animal ahead' FROM s_env AS v, sched_bookings AS b JOIN s_animal AS a ON a.n = b.animal_id
         WHERE b.starts_at >= v.e AND b.state = 'booked' AND a.died_at IS NOT NULL AND a.died_at < b.starts_at
        UNION ALL
        SELECT 'a cancelled booking''s allocation is live' FROM sched_allocations AS a JOIN sched_bookings AS b ON b.id = a.booking_id
         WHERE b.state = 'cancelled' AND a.released_at IS NULL
        UNION ALL
        SELECT 'booking ids or allocation ids past their range'
          WHERE (SELECT max(id) FROM sched_bookings) > 50000 OR (SELECT max(id) FROM sched_allocations) > 60000
             OR (SELECT count(*) FROM sched_sessions) <> 125 OR (SELECT max(id) FROM sched_trainees) > 750
             OR (SELECT max(id) FROM sched_enrolments) > 1250
        LIMIT 20
    ) AS y;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'load.sql: the agenda does not hold: %', bad;
    END IF;
END $$;

-- --- Sequences: each resumes after its range, or after the load's ids past it (D276) ------------

SELECT setval(pg_get_serial_sequence('sched_rooms', 'id'), 16),
       setval(pg_get_serial_sequence('sched_types', 'id'), 45),
       setval(pg_get_serial_sequence('sched_courses', 'id'), 16),
       setval(pg_get_serial_sequence('sched_bookings', 'id'), greatest(50000, (SELECT max(id) FROM sched_bookings))),
       setval(pg_get_serial_sequence('sched_allocations', 'id'), greatest(60000, (SELECT max(id) FROM sched_allocations))),
       setval(pg_get_serial_sequence('sched_shifts', 'id'), greatest(24000, (SELECT max(id) FROM sched_shifts))),
       setval(pg_get_serial_sequence('sched_absences', 'id'), greatest(1000, (SELECT max(id) FROM sched_absences))),
       setval(pg_get_serial_sequence('sched_sessions', 'id'), 125),
       setval(pg_get_serial_sequence('sched_trainees', 'id'), 750),
       setval(pg_get_serial_sequence('sched_enrolments', 'id'), 1250);

VACUUM (ANALYZE) sched_settings, sched_rooms, sched_hours, sched_machines, sched_types, sched_courses, sched_bookings,
                 sched_allocations, sched_shifts, sched_absences, sched_sessions, sched_trainees, sched_enrolments;
