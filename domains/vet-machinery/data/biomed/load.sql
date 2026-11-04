-- vet-machinery's biomed history (v0.5 master spec 9.6; vet-machinery-domain.md,
-- "The history before T0", "Loading"): last night's backup of the biomedical
-- engineering system. Runs after biomed/schema.sql, connected to biomed, as
-- postgres, the core's data/keys.sql streamed ahead of it (unused here: the
-- registry, the logs and the telemetry name no core key but staff ids, by the
-- core's published layout). Every value is a hash of its ids (pg_temp.m_u),
-- never random(); docs/gm.md, "The data", documents it.
--
-- psql variables (load-data's): customer_timezone, customer_utc_offset (hours),
-- load_epoch (T0, UTC, to the minute: the load's "now", never now()).
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'biomed/load.sql: psql variable customer_timezone is not set'; END $$;
\endif
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'biomed/load.sql: psql variable customer_utc_offset is not set'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'biomed/load.sql: psql variable load_epoch is not set'; END $$;
\endif

-- The part's hash: uniform in [0, 1) from x and a salt (the core's formula,
-- the part's own salts, 500 and up).
CREATE FUNCTION pg_temp.m_u(x bigint, salt integer) RETURNS float8
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, salt) & 2147483647)::float8 / 2147483648 $$;

-- T0 and the customer's calendar: e T0 (UTC), o the offset, tl T0 local,
-- today its local day, s the history's start (local Monday 00:00 52 weeks
-- before T0's week, the core's), w0 the window's start (yesterday 00:00
-- local, as UTC).
CREATE TEMP TABLE l_env AS
SELECT e, o, tl, tl::date AS today, date_trunc('week', tl) - interval '364 days' AS s,
       ((tl::date - 1)::timestamp - make_interval(hours => o)) AT TIME ZONE 'UTC' AS w0
  FROM (SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
               (:'load_epoch'::timestamptz AT TIME ZONE 'UTC')
                 + make_interval(hours => :customer_utc_offset::integer) AS tl) AS x;
CREATE FUNCTION pg_temp.m_utc(t timestamp, o integer) RETURNS timestamptz
    LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - make_interval(hours => o)) AT TIME ZONE 'UTC' $$;

INSERT INTO mach_settings (timezone, utc_offset_hours) VALUES (:'customer_timezone', :customer_utc_offset);

-- --- The registry -------------------------------------------------------------

-- The 28 machines; qa_due_on from each ionising machine's QA test (below).
INSERT INTO mach_machines (id, code, name, kind, modality, ae_title, section_id, discipline, species_group,
                           vendor, model, serial, installed_on, bookable, ionising, telemetry, qa_due_on)
SELECT m.id, m.code, m.name, m.kind, m.modality, m.ae_title, m.section_id, m.discipline, m.grp, m.vendor,
       m.model, m.code || '-' || lpad(((m.id * 7919 + 4243) % 100000)::text, 5, '0'),
       env.today - (400 + floor(2500 * pg_temp.m_u(m.id, 501)))::integer,
       m.id BETWEEN 7 AND 16, m.ionising, m.id BETWEEN 1 AND 10 OR m.id = 16,
       CASE WHEN m.ionising THEN date '1900-01-01' END
  FROM l_env AS env, (VALUES
    (1, 'HA-LAB-1', 'Haematology analyser 1', 'analyser', NULL, NULL, NULL, 'haematology', 'any', 'Corvus Diagnostics', 'HX 5', false),
    (2, 'HA-LAB-2', 'Haematology analyser 2', 'analyser', NULL, NULL, NULL, 'haematology', 'any', 'Corvus Diagnostics', 'HX 5', false),
    (3, 'BC-LAB-1', 'Biochemistry analyser 1', 'analyser', NULL, NULL, NULL, 'biochemistry', 'any', 'Corvus Diagnostics', 'Chem 800', false),
    (4, 'BC-LAB-2', 'Biochemistry analyser 2', 'analyser', NULL, NULL, NULL, 'biochemistry', 'any', 'Corvus Diagnostics', 'Chem 800', false),
    (5, 'BG-LAB-1', 'Blood gas and electrolyte analyser', 'analyser', NULL, NULL, NULL, 'blood gases', 'any', 'Tarn Analytics', 'BGE 3', false),
    (6, 'CO-LAB-1', 'Coagulation analyser', 'analyser', NULL, NULL, NULL, 'coagulation', 'any', 'Tarn Analytics', 'Coag 2', false),
    (7, 'CT-SA-1', 'CT, small animal', 'ct', 'CT', 'ALD_CT_SA1', 3, NULL, 'small', 'Halden Imaging', 'Vista 64', true),
    (8, 'CT-LB-1', 'CT, large bore (horses and farm)', 'ct', 'CT', 'ALD_CT_LB1', 1, NULL, 'large', 'Halden Imaging', 'Vista XL 32', true),
    (9, 'MR-SA-1', 'MRI 1.5 T, small animal', 'mri', 'MR', 'ALD_MR_SA1', 3, NULL, 'small', 'Norvane Medical', 'Magna 1.5T', false),
    (10, 'MR-EQ-1', 'Standing MRI, horses (permanent magnet)', 'mri', 'MR', 'ALD_MR_EQ1', 1, NULL, 'horse', 'Steadfield Equine', 'Stance 0.27T', false),
    (11, 'DX-SA-1', 'Digital radiography room, domestic', 'dr', 'DX', 'ALD_DX_SA1', 3, NULL, 'small', 'Halden Imaging', 'DRX Room', true),
    (12, 'DX-EQ-1', 'Digital radiography room, horses', 'dr', 'DX', 'ALD_DX_EQ1', 1, NULL, 'large', 'Halden Imaging', 'DRX Room L', true),
    (13, 'DX-PO-1', 'Portable radiography (farm and stables)', 'dr', 'DX', 'ALD_DX_PO1', 2, NULL, 'large', 'Halden Imaging', 'DRX Go', true),
    (14, 'US-SA-1', 'Ultrasound, domestic', 'us', 'US', 'ALD_US_SA1', 3, NULL, 'small', 'Norvane Medical', 'Sono 9', false),
    (15, 'US-PO-1', 'Portable ultrasound (horses and farm)', 'us', 'US', 'ALD_US_PO1', 1, NULL, 'large', 'Norvane Medical', 'Sono Go', false),
    (16, 'NM-EQ-1', 'Gamma camera, horses', 'gamma', 'NM', 'ALD_NM_EQ1', 1, NULL, 'horse', 'Steadfield Equine', 'Scinti L', true),
    (17, 'AN-SA-1', 'Anaesthesia monitor, small-animal theatre 1', 'monitor-anaesthesia', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K7 OR', false),
    (18, 'AN-SA-2', 'Anaesthesia monitor, small-animal theatre 2', 'monitor-anaesthesia', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K7 OR', false),
    (19, 'AN-EQ-1', 'Anaesthesia monitor, equine theatre', 'monitor-anaesthesia', NULL, NULL, 1, NULL, 'large', 'Kestrel Monitoring', 'K7 OR L', false),
    (20, 'AN-MR-1', 'Anaesthesia monitor, MRI-compatible', 'monitor-anaesthesia', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K7 MR', false),
    (21, 'IC-SA-1', 'Intensive-care monitor, domestic 1', 'monitor-icu', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K5 ICU', false),
    (22, 'IC-SA-2', 'Intensive-care monitor, domestic 2', 'monitor-icu', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K5 ICU', false),
    (23, 'IC-SA-3', 'Intensive-care monitor, domestic 3', 'monitor-icu', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K5 ICU', false),
    (24, 'IC-SA-4', 'Intensive-care monitor, domestic 4', 'monitor-icu', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K5 ICU', false),
    (25, 'IC-SA-5', 'Intensive-care monitor, domestic 5', 'monitor-icu', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K5 ICU', false),
    (26, 'IC-SA-6', 'Intensive-care monitor, domestic 6', 'monitor-icu', NULL, NULL, 3, NULL, 'small', 'Kestrel Monitoring', 'K5 ICU', false),
    (27, 'IC-EQ-1', 'Intensive-care monitor, horses and foals 1', 'monitor-icu', NULL, NULL, 1, NULL, 'horse', 'Kestrel Monitoring', 'K5 ICU L', false),
    (28, 'IC-EQ-2', 'Intensive-care monitor, horses and foals 2', 'monitor-icu', NULL, NULL, 1, NULL, 'horse', 'Kestrel Monitoring', 'K5 ICU L', false)
  ) AS m (id, code, name, kind, modality, ae_title, section_id, discipline, grp, vendor, model, ionising)
 ORDER BY m.id;

-- --- The partitions: yesterday to today plus three, the events' months -----

-- Created as mach, so mach owns them (a detach needs the owner).
SELECT today AS m_today, s::date AS m_s FROM l_env \gset
SET ROLE mach;
SELECT count(*) FILTER (WHERE mach_partition_day(:'m_today'::date + i)) AS readings_partitions
  FROM generate_series(-1, 3) AS i;
SELECT count(*) FILTER (WHERE mach_partition_month(m::date)) AS events_partitions
  FROM generate_series(date_trunc('month', :'m_s'::date), date_trunc('month', :'m_today'::date + 3)
                       + interval '1 month', interval '1 month') AS m;
RESET ROLE;

-- --- Maintenance, QA, downtimes ---------------------------------------------------

-- The vendors' engineers, by name (personal: rule 8 keeps maintenance the
-- machine's life and five years).
CREATE TEMP TABLE l_engineers AS
SELECT * FROM (VALUES ('Corvus Diagnostics', ARRAY['Tom Reilly', 'Ines Vidal']),
                      ('Tarn Analytics', ARRAY['Karl Beck', 'Maud Oster']),
                      ('Halden Imaging', ARRAY['Sven Lund', 'Aiko Mori', 'Paul Grant']),
                      ('Norvane Medical', ARRAY['Rita Costa', 'Jan Visser']),
                      ('Steadfield Equine', ARRAY['Owen Hale']),
                      ('Kestrel Monitoring', ARRAY['Lea Brandt'])) AS v (vendor, names);

CREATE TEMP TABLE l_m AS
SELECT x.machine_id, x.kind, x.at, x.vendor, x.engineer, x.staff_id, x.outcome, x.next_due_on, x.notes,
       x.down_hours
  FROM (
    -- the analysers' monthly calibration, by the biomedical engineer (staff 56)
    SELECT m.id AS machine_id, 'calibration' AS kind,
           pg_temp.m_utc(env.s::date + 30 * k + (m.id * 3) % 28 + time '07:15', env.o) AS at,
           NULL::text AS vendor, NULL::text AS engineer, 56 AS staff_id, 'pass' AS outcome,
           (env.s::date + 30 * k + (m.id * 3) % 28 + 30) AS next_due_on, 'monthly calibration and QC' AS notes,
           0::float8 AS down_hours
      FROM l_env AS env, mach_machines AS m, generate_series(0, 12) AS k WHERE m.kind = 'analyser'
    UNION ALL
    -- imaging's quarterly service visit by the vendor, three to five hours down
    SELECT m.id, 'service', pg_temp.m_utc(env.s::date + 91 * k + 20 + m.id * 5 + time '08:00', env.o),
           m.vendor, e.names[1 + (m.id + k) % cardinality(e.names)], NULL, 'done',
           env.s::date + 91 * k + 20 + m.id * 5 + 91, 'planned service visit', 3 + 2 * pg_temp.m_u(m.id * 10 + k, 502)
      FROM l_env AS env, mach_machines AS m JOIN l_engineers AS e ON e.vendor = m.vendor,
           generate_series(0, 3) AS k WHERE m.id IN (7, 8, 9, 10, 16)
    UNION ALL
    -- each ionising machine's yearly QA test, by the radiation protection expert
    SELECT m.id, 'qa-test', pg_temp.m_utc(env.s::date + 30 + floor(300 * pg_temp.m_u(m.id, 503))::integer
                                          + time '13:00', env.o),
           'Radiation Protection Services', 'Dr Hanna Wolff', NULL, 'pass',
           (env.s::date + 30 + floor(300 * pg_temp.m_u(m.id, 503))::integer + interval '12 months')::date,
           'yearly acceptance and constancy test (rule 6)', 0
      FROM l_env AS env, mach_machines AS m WHERE m.ionising
    UNION ALL
    -- the monitors' yearly service, by the biomedical engineer
    SELECT m.id, 'service', pg_temp.m_utc(env.s::date + 60 + m.id * 9 + time '14:00', env.o),
           NULL, NULL, 56, 'pass', (env.s::date + 60 + m.id * 9 + interval '12 months')::date,
           'yearly safety and performance check', 0
      FROM l_env AS env, mach_machines AS m WHERE m.kind LIKE 'monitor-%'
    UNION ALL
    -- two software updates a year on the big imaging machines
    SELECT m.id, 'software-update', pg_temp.m_utc(env.s::date + 120 + 180 * k + m.id * 2 + time '17:30', env.o),
           m.vendor, e.names[1], NULL, 'done', NULL, 'vendor software release', 1
      FROM l_env AS env, mach_machines AS m JOIN l_engineers AS e ON e.vendor = m.vendor,
           generate_series(0, 1) AS k WHERE m.id IN (7, 8, 9, 10, 16)
    UNION ALL
    -- fourteen repairs over the year, each after a downtime of 2 to 30 hours
    SELECT mm.id, 'repair',
           pg_temp.m_utc(env.s::date + 10 + 25 * k + floor(10 * pg_temp.m_u(k, 505))::integer + time '10:00', env.o),
           mm.vendor, e.names[1 + k % cardinality(e.names)], NULL, 'done', NULL,
           (ARRAY['tube replaced', 'detector recalibrated', 'pump replaced', 'board replaced', 'cable repaired'])
             [1 + k % 5], 2 + 28 * pg_temp.m_u(k, 506)
      FROM l_env AS env, generate_series(0, 13) AS k,
           LATERAL (SELECT (ARRAY[1, 3, 5, 7, 8, 9, 11, 12, 13, 14, 15, 2, 4, 6])[k + 1] AS id) AS r
           JOIN mach_machines AS mm ON mm.id = r.id JOIN l_engineers AS e ON e.vendor = mm.vendor
  ) AS x, l_env AS env
 WHERE x.at < env.e - interval '1 day';

INSERT INTO mach_maintenance (id, machine_id, kind, performed_at, vendor, engineer, staff_id, outcome,
                              next_due_on, notes)
SELECT row_number() OVER (ORDER BY at, machine_id), machine_id, kind, at, vendor, engineer, staff_id, outcome,
       next_due_on, notes
  FROM l_m ORDER BY at, machine_id;

INSERT INTO mach_downtimes (id, machine_id, from_at, until_at, reason)
SELECT row_number() OVER (ORDER BY from_at, machine_id), machine_id, from_at, until_at, reason
  FROM (SELECT machine_id,
               CASE WHEN kind = 'repair' THEN at - down_hours * interval '1 hour' ELSE at END AS from_at,
               CASE WHEN kind = 'repair' THEN at ELSE at + down_hours * interval '1 hour' END AS until_at,
               CASE WHEN kind = 'repair' THEN 'fault: ' || notes ELSE kind || ' visit' END AS reason
          FROM l_m WHERE kind IN ('repair', 'service') AND down_hours > 0) AS d
 ORDER BY from_at, machine_id;

UPDATE mach_machines AS m SET qa_due_on = q.due
  FROM (SELECT machine_id, max(next_due_on) AS due FROM mach_maintenance WHERE kind = 'qa-test'
         GROUP BY machine_id) AS q
 WHERE q.machine_id = m.id;

-- --- The machines' logs (a year, monthly partitions) --------------------------------

-- A day's events: 250 at 1.0 on a weekday's mix, ramping from 0.6 a year ago
-- (D279); 80 % of a weekday's in the imaging day; the machine by a weighted
-- hash (imaging and analysers log most); an operator for imaging (52-55) and
-- the analysers (71-78) by the core's layout.
CREATE TEMP TABLE l_ev AS
SELECT d, k, x.machine_id, x.at, x.u
  FROM l_env AS env,
       generate_series(env.s::date, env.today, interval '1 day') AS dd,
       LATERAL (SELECT dd::date AS d, extract(isodow FROM dd)::integer AS dow,
                       0.6 + 0.4 * (dd::date - env.s::date)::float8 / greatest(env.today - env.s::date, 1) AS ramp) AS c,
       LATERAL generate_series(1, round(250 * c.ramp * CASE WHEN c.dow <= 5 THEN 1.08 WHEN c.dow = 6 THEN 0.85
                                                             ELSE 0.7 END)::integer) AS k,
       LATERAL (SELECT (c.d - date '2000-01-03')::bigint * 1000 + k AS key) AS h,
       LATERAL (SELECT pg_temp.m_u(h.key, 511) AS u,
                       (ARRAY[1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 7, 7, 8, 8, 9, 9, 9, 10, 11, 11, 11, 12, 12, 13,
                              14, 14, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28])
                         [1 + floor(43 * pg_temp.m_u(h.key, 512))::integer] AS machine_id,
                       pg_temp.m_utc(c.d + CASE WHEN c.dow <= 5 AND pg_temp.m_u(h.key, 513) < 0.8
                                                THEN interval '8 hours' + pg_temp.m_u(h.key, 514) * interval '10 hours'
                                                ELSE pg_temp.m_u(h.key, 514) * interval '24 hours' END, env.o) AS at) AS x
 WHERE x.at < env.e;

INSERT INTO mach_events (id, machine_id, at, level, code, message, operator_id, acknowledged_at, acknowledged_by)
SELECT row_number() OVER (ORDER BY v.at, v.machine_id, v.k), v.machine_id, v.at, lv.level, msg.code, msg.message,
       CASE WHEN v.machine_id BETWEEN 7 AND 16 THEN 52 + floor(4 * pg_temp.m_u(v.d - date '2000-01-03' + v.k, 517))::integer
            WHEN v.machine_id <= 6 THEN 71 + floor(8 * pg_temp.m_u(v.d - date '2000-01-03' + v.k, 517))::integer END,
       CASE WHEN lv.level = 'critical' AND v.at + ack.lag < env.e THEN v.at + ack.lag END,
       CASE WHEN lv.level = 'critical' AND v.at + ack.lag < env.e THEN 56 END
  FROM l_env AS env, l_ev AS v JOIN mach_machines AS m ON m.id = v.machine_id,
       LATERAL (SELECT CASE WHEN v.u < 0.80 THEN 'info' WHEN v.u < 0.95 THEN 'warning'
                            WHEN v.u < 0.997 THEN 'error' ELSE 'critical' END AS level) AS lv,
       LATERAL (SELECT (10 + 200 * pg_temp.m_u((v.d - date '2000-01-03') * 1000 + v.k, 518)) * interval '1 minute' AS lag) AS ack,
       LATERAL (SELECT c.code, c.message FROM (VALUES
                  ('analyser', 'info', 'RUN-OK', 'batch run completed'),
                  ('analyser', 'info', 'QC-PASS', 'quality control passed'),
                  ('analyser', 'warning', 'REAGENT-LOW', 'reagent below 20 %'),
                  ('analyser', 'error', 'SAMPLE-CLOT', 'sample probe clot detected, run aborted'),
                  ('analyser', 'critical', 'TEMP-RANGE', 'reaction temperature out of range'),
                  ('ct', 'info', 'EXAM-START', 'examination started'),
                  ('ct', 'info', 'EXAM-END', 'examination completed'),
                  ('ct', 'warning', 'TUBE-HEAT', 'tube heat above 80 %, cooling'),
                  ('ct', 'error', 'RECON-FAIL', 'reconstruction job failed, retried'),
                  ('ct', 'critical', 'GANTRY-STOP', 'gantry emergency stop'),
                  ('mri', 'info', 'EXAM-START', 'examination started'),
                  ('mri', 'info', 'EXAM-END', 'examination completed'),
                  ('mri', 'warning', 'COLDHEAD', 'cold head temperature rising'),
                  ('mri', 'error', 'COIL-FAULT', 'receive coil not detected'),
                  ('mri', 'critical', 'HE-LEVEL', 'helium level alarm'),
                  ('dr', 'info', 'EXPOSURE', 'exposure acquired'),
                  ('dr', 'info', 'DETECTOR-OK', 'detector calibration check passed'),
                  ('dr', 'warning', 'DETECTOR-BATT', 'detector battery low'),
                  ('dr', 'error', 'GEN-FAULT', 'generator fault, exposure inhibited'),
                  ('dr', 'critical', 'GEN-OVERLOAD', 'generator overload'),
                  ('us', 'info', 'EXAM-START', 'examination started'),
                  ('us', 'info', 'PROBE-OK', 'probe self-test passed'),
                  ('us', 'warning', 'PROBE-TEMP', 'probe surface temperature high'),
                  ('us', 'error', 'EXPORT-FAIL', 'export to PACS failed, queued'),
                  ('us', 'critical', 'POWER', 'power supply fault'),
                  ('gamma', 'info', 'ACQ-START', 'acquisition started'),
                  ('gamma', 'info', 'QC-FLOOD', 'flood uniformity check passed'),
                  ('gamma', 'warning', 'DETECTOR-TEMP', 'detector temperature drifting'),
                  ('gamma', 'error', 'ACQ-ABORT', 'acquisition aborted'),
                  ('gamma', 'critical', 'COLLIMATOR', 'collimator interlock open'),
                  ('monitor-anaesthesia', 'info', 'SELFTEST', 'self-test passed'),
                  ('monitor-anaesthesia', 'info', 'GAS-CAL', 'gas module calibrated'),
                  ('monitor-anaesthesia', 'warning', 'BATTERY', 'running on battery'),
                  ('monitor-anaesthesia', 'error', 'MODULE', 'module communication lost'),
                  ('monitor-anaesthesia', 'critical', 'POWER', 'power supply fault'),
                  ('monitor-icu', 'info', 'SELFTEST', 'self-test passed'),
                  ('monitor-icu', 'info', 'NETWORK', 'reconnected to the central station'),
                  ('monitor-icu', 'warning', 'BATTERY', 'running on battery'),
                  ('monitor-icu', 'error', 'NETWORK-LOST', 'connection to the central station lost'),
                  ('monitor-icu', 'critical', 'POWER', 'power supply fault')) AS c (kind, level, code, message)
                 WHERE c.kind = m.kind AND c.level = lv.level
                 ORDER BY c.code OFFSET floor(2 * pg_temp.m_u(v.machine_id * 100000 + v.k, 519))::integer
                                        % (CASE lv.level WHEN 'info' THEN 2 ELSE 1 END)
                 LIMIT 1) AS msg
 ORDER BY v.at, v.machine_id, v.k;

-- --- The telemetry: the window's raw rows, the year's aggregates -------------------

-- A reading a minute per machine with telemetry (1-10, 16; machine 10 a
-- permanent magnet: status only, no channel), [w0, T0) on the UTC minute's
-- grid: the last full day and today so far.
CREATE TEMP TABLE l_rd AS
SELECT m.id AS machine_id, t AS read_at,
       (extract(epoch FROM t)::bigint / 60) * 32 + m.id AS key,
       extract(hour FROM t AT TIME ZONE 'UTC' + make_interval(hours => env.o))::integer AS lh
  FROM l_env AS env, mach_machines AS m,
       generate_series(env.w0, env.e - interval '1 minute', interval '1 minute') AS t
 WHERE m.telemetry;

INSERT INTO mach_readings (machine_id, read_at, status, channels)
SELECT r.machine_id, r.read_at,
       CASE WHEN r.machine_id <> 10 AND pg_temp.m_u(r.key, 521) < 0.001 THEN 'warning' ELSE 'ok' END,
       CASE
         WHEN r.machine_id IN (1, 2) THEN jsonb_build_object(
             'temp_c', round((24 + 1.5 * pg_temp.m_u(r.key, 522))::numeric, 1),
             'reagent_pct', round((95 - 70 * ((r.lh * 60 + extract(minute FROM r.read_at)) / 1440.0))::numeric, 0))
         WHEN r.machine_id IN (3, 4) THEN jsonb_build_object(
             'incubator_c', round((37 + 0.2 * (pg_temp.m_u(r.key, 522) - 0.5))::numeric, 2),
             'reagent_pct', round((90 - 60 * ((r.lh * 60 + extract(minute FROM r.read_at)) / 1440.0))::numeric, 0),
             'lamp_hours', 1800 + (r.read_at::date - date '2026-01-01') * 24 / 7)
         WHEN r.machine_id = 5 THEN jsonb_build_object(
             'temp_c', round((37 + 0.1 * (pg_temp.m_u(r.key, 522) - 0.5))::numeric, 2),
             'cartridge_pct', round((100 - 90 * ((r.lh * 60 + extract(minute FROM r.read_at)) / 1440.0))::numeric, 0))
         WHEN r.machine_id = 6 THEN jsonb_build_object(
             'temp_c', round((37 + 0.2 * (pg_temp.m_u(r.key, 522) - 0.5))::numeric, 2),
             'reagent_pct', round((85 - 40 * ((r.lh * 60 + extract(minute FROM r.read_at)) / 1440.0))::numeric, 0))
         WHEN r.machine_id IN (7, 8) THEN jsonb_build_object(
             'tube_heat_pct', round((CASE WHEN r.lh BETWEEN 8 AND 17 THEN 25 + 45 * pg_temp.m_u(r.key, 522)
                                         ELSE 8 + 10 * pg_temp.m_u(r.key, 522) END)::numeric, 0),
             'gantry_temp_c', round((24 + 2 * pg_temp.m_u(r.key, 523))::numeric, 1))
         WHEN r.machine_id = 9 THEN jsonb_build_object(
             'helium_pct', round((78.4 - 0.002 * (extract(epoch FROM r.read_at - env.w0) / 3600))::numeric, 2),
             'cold_head_k', round((4.15 + 0.1 * pg_temp.m_u(r.key, 522))::numeric, 2),
             'shield_k', round((41 + 2 * pg_temp.m_u(r.key, 523))::numeric, 1),
             'compressor', 'on')
         WHEN r.machine_id = 10 THEN '{}'::jsonb
         ELSE jsonb_build_object(
             'detector_temp_c', round((21 + pg_temp.m_u(r.key, 522))::numeric, 1),
             'humidity_pct', round((40 + 8 * pg_temp.m_u(r.key, 523))::numeric, 0))
       END
  FROM l_env AS env, l_rd AS r
 ORDER BY r.read_at, r.machine_id;

-- Each shipped day's aggregate, every day of the year before the window
-- (rows: the day's raw count, 1 440; each channel's min, max and mean, drawn
-- about the channels' baselines: the raw rows are in the vault).
INSERT INTO mach_readings_daily (machine_id, day, rows, channels)
SELECT m.id, dd::date, 1440,
       CASE m.id
         WHEN 10 THEN '{}'::jsonb
         ELSE (SELECT jsonb_object_agg(c.name, jsonb_build_object(
                        'min', round((c.base - c.spread * (0.4 + 0.1 * pg_temp.m_u(k.key, 531)))::numeric, 2),
                        'max', round((c.base + c.spread * (0.4 + 0.1 * pg_temp.m_u(k.key, 532)))::numeric, 2),
                        'mean', round((c.base + c.spread * 0.05 * (pg_temp.m_u(k.key, 533) - 0.5))::numeric, 2)))
                 FROM (VALUES (1, 'temp_c', 24.75, 1.5), (1, 'reagent_pct', 60, 70),
                              (2, 'temp_c', 24.75, 1.5), (2, 'reagent_pct', 60, 70),
                              (3, 'incubator_c', 37, 0.2), (3, 'reagent_pct', 60, 60), (3, 'lamp_hours', 1700, 1),
                              (4, 'incubator_c', 37, 0.2), (4, 'reagent_pct', 60, 60), (4, 'lamp_hours', 1700, 1),
                              (5, 'temp_c', 37, 0.1), (5, 'cartridge_pct', 55, 90),
                              (6, 'temp_c', 37, 0.2), (6, 'reagent_pct', 65, 40),
                              (7, 'tube_heat_pct', 30, 60), (7, 'gantry_temp_c', 25, 2),
                              (8, 'tube_heat_pct', 30, 60), (8, 'gantry_temp_c', 25, 2),
                              (9, 'helium_pct', 79, 0.1), (9, 'cold_head_k', 4.2, 0.1), (9, 'shield_k', 42, 2),
                              (16, 'detector_temp_c', 21.5, 1), (16, 'humidity_pct', 44, 8))
                      AS c (machine_id, name, base, spread)
                WHERE c.machine_id = m.id)
       END
  FROM l_env AS env, mach_machines AS m,
       generate_series(env.s::date, env.today - 2, interval '1 day') AS dd,
       LATERAL (SELECT (dd::date - date '2000-01-03')::bigint * 32 + m.id AS key) AS k
 WHERE m.telemetry
 ORDER BY dd, m.id;

-- --- Sequences, and the load's own checks ------------------------------------------

SELECT setval(pg_get_serial_sequence('mach_machines', 'id'), 28);
SELECT setval(pg_get_serial_sequence('mach_maintenance', 'id'), greatest((SELECT max(id) FROM mach_maintenance), 1));
SELECT setval(pg_get_serial_sequence('mach_downtimes', 'id'), greatest((SELECT max(id) FROM mach_downtimes), 1));
SELECT setval(pg_get_serial_sequence('mach_events', 'id'), greatest((SELECT max(id) FROM mach_events), 1));

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM mach_events_default) OR EXISTS (SELECT 1 FROM mach_readings_default) THEN
        RAISE EXCEPTION 'biomed/load.sql: rows in a default partition (a partition missing)';
    END IF;
    IF (SELECT count(DISTINCT machine_id) FROM mach_readings) <> 11 THEN
        RAISE EXCEPTION 'biomed/load.sql: % machines reporting, 11 expected',
            (SELECT count(DISTINCT machine_id) FROM mach_readings);
    END IF;
END $$;

ANALYZE;
