-- vet-lab's history (v0.5 master spec 9.3; vet-lab-domain.md, "The history
-- before T0", "Deterministic key ranges", "Loading"; capture W3 item 1): last
-- night's backup of the centre's laboratory, a year ending at T0. Runs after
-- schema.sql, connected to the lab's database, as postgres, with vet-core's
-- data/keys.sql and this part's data/keys.sql streamed ahead of it in the
-- same session (W3 item 0): every order, order test, sample and send-out, and
-- the core's ids they carry, come from pg_temp.lab_order_tests, the one pass
-- the partners' data.sql files run too; this file adds what no other file
-- reads (the reference tables, results, batches, QC runs, events, calls,
-- notifications, callbacks, charges) by hashes of the ids (lab_u), never
-- random(), and never reads the core's database. docs/gm.md, "Part keys" and
-- "The data", documents both.
--
-- load-data's three psql variables (capture W1 item 0, W2 item 3):
-- customer_timezone, customer_utc_offset and load_epoch (T0, never now()).
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_timezone is not set '
                            '(gmctl load-data passes -v customer_timezone=<zone>)'; END $$;
\endif
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
    IF to_regprocedure('pg_temp.core_request(integer, timestamp with time zone, integer)') IS NULL
       OR to_regprocedure('pg_temp.lab_order_tests(timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'load.sql: the key functions are missing (gmctl load-data streams vet-core''s '
                        'data/keys.sql, then vet-lab''s, ahead of this file, in the same session)';
    END IF;
END $$;

CREATE TEMP TABLE l_env AS
SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
       pg_temp.lab_start(:'load_epoch'::timestamptz, :customer_utc_offset) AS s,
       date_trunc('year', pg_temp.lab_local(:'load_epoch'::timestamptz, :customer_utc_offset))::date AS jan1;

-- --- Settings -----------------------------------------------------------------------------

INSERT INTO lab_settings (timezone, utc_offset_hours) VALUES (:'customer_timezone', :customer_utc_offset);

-- --- Reference: analytes, tests, intervals, prices, accounts --------------------------------

-- The 70 analytes: 1-14 haematology, 15-47 biochemistry, 48-53 blood gases,
-- 54-57 coagulation, 58-61 urine, 62-66 hormones, lead and IgG, 67-70 text
-- (an organism, a sensitivity, a qualitative result, a report). lo and hi the
-- dog's adult interval, the others' scaled from it (below); critical limits
-- on haematocrit, platelets, glucose and potassium only (answer 9).
CREATE TEMP TABLE l_analytes (id integer, code text, name text, unit text, kind text, lo numeric, hi numeric,
                              clo numeric, chi numeric);
INSERT INTO l_analytes VALUES
    (1, 'RBC', 'red blood cells', '10^12/L', 'numeric', 5.5, 8.5, NULL, NULL),
    (2, 'HGB', 'haemoglobin', 'g/L', 'numeric', 120, 180, NULL, NULL),
    (3, 'HCT', 'haematocrit', 'L/L', 'numeric', 0.37, 0.55, 0.15, 0.70),
    (4, 'MCV', 'mean cell volume', 'fL', 'numeric', 60, 77, NULL, NULL),
    (5, 'MCH', 'mean cell haemoglobin', 'pg', 'numeric', 19.5, 24.5, NULL, NULL),
    (6, 'MCHC', 'mean cell haemoglobin concentration', 'g/L', 'numeric', 320, 360, NULL, NULL),
    (7, 'WBC', 'white blood cells', '10^9/L', 'numeric', 6, 17, NULL, NULL),
    (8, 'NEU', 'neutrophils', '10^9/L', 'numeric', 3, 11.5, NULL, NULL),
    (9, 'LYM', 'lymphocytes', '10^9/L', 'numeric', 1, 4.8, NULL, NULL),
    (10, 'MONO', 'monocytes', '10^9/L', 'numeric', 0.15, 1.35, NULL, NULL),
    (11, 'EOS', 'eosinophils', '10^9/L', 'numeric', 0.1, 1.25, NULL, NULL),
    (12, 'BASO', 'basophils', '10^9/L', 'numeric', 0, 0.1, NULL, NULL),
    (13, 'PLT', 'platelets', '10^9/L', 'numeric', 200, 500, 20, 1000),
    (14, 'RETIC', 'reticulocytes', '10^9/L', 'numeric', 10, 110, NULL, NULL),
    (15, 'GLU', 'glucose', 'mmol/L', 'numeric', 3.9, 6.7, 2.2, 25),
    (16, 'UREA', 'urea', 'mmol/L', 'numeric', 2.5, 9.6, NULL, NULL),
    (17, 'CREA', 'creatinine', 'umol/L', 'numeric', 44, 159, NULL, NULL),
    (18, 'ALB', 'albumin', 'g/L', 'numeric', 23, 40, NULL, NULL),
    (19, 'TP', 'total protein', 'g/L', 'numeric', 52, 82, NULL, NULL),
    (20, 'GLOB', 'globulin', 'g/L', 'numeric', 25, 45, NULL, NULL),
    (21, 'ALT', 'alanine aminotransferase', 'U/L', 'numeric', 10, 125, NULL, NULL),
    (22, 'AST', 'aspartate aminotransferase', 'U/L', 'numeric', 0, 50, NULL, NULL),
    (23, 'ALP', 'alkaline phosphatase', 'U/L', 'numeric', 23, 212, NULL, NULL),
    (24, 'GGT', 'gamma-glutamyl transferase', 'U/L', 'numeric', 0, 11, NULL, NULL),
    (25, 'TBIL', 'total bilirubin', 'umol/L', 'numeric', 0, 15, NULL, NULL),
    (26, 'CHOL', 'cholesterol', 'mmol/L', 'numeric', 2.8, 8.3, NULL, NULL),
    (27, 'TRIG', 'triglycerides', 'mmol/L', 'numeric', 0.1, 1.1, NULL, NULL),
    (28, 'AMYL', 'amylase', 'U/L', 'numeric', 500, 1500, NULL, NULL),
    (29, 'LIPA', 'lipase', 'U/L', 'numeric', 200, 1800, NULL, NULL),
    (30, 'CK', 'creatine kinase', 'U/L', 'numeric', 10, 200, NULL, NULL),
    (31, 'CA', 'calcium', 'mmol/L', 'numeric', 1.98, 3.0, NULL, NULL),
    (32, 'PHOS', 'phosphate', 'mmol/L', 'numeric', 0.81, 2.2, NULL, NULL),
    (33, 'MG', 'magnesium', 'mmol/L', 'numeric', 0.7, 1.0, NULL, NULL),
    (34, 'NA', 'sodium', 'mmol/L', 'numeric', 144, 160, NULL, NULL),
    (35, 'K', 'potassium', 'mmol/L', 'numeric', 3.5, 5.8, 2.5, 7.5),
    (36, 'CL', 'chloride', 'mmol/L', 'numeric', 109, 122, NULL, NULL),
    (37, 'BHB', 'beta-hydroxybutyrate', 'mmol/L', 'numeric', 0, 1.2, NULL, NULL),
    (38, 'NEFA', 'non-esterified fatty acids', 'mmol/L', 'numeric', 0, 0.4, NULL, NULL),
    (39, 'GLDH', 'glutamate dehydrogenase', 'U/L', 'numeric', 0, 10, NULL, NULL),
    (40, 'SAA', 'serum amyloid A', 'mg/L', 'numeric', 0, 20, NULL, NULL),
    (41, 'CRP', 'C-reactive protein', 'mg/L', 'numeric', 0, 10, NULL, NULL),
    (42, 'FRUCT', 'fructosamine', 'umol/L', 'numeric', 250, 350, NULL, NULL),
    (43, 'SDMA', 'symmetric dimethylarginine', 'ug/dL', 'numeric', 0, 14, NULL, NULL),
    (44, 'BA', 'bile acids', 'umol/L', 'numeric', 0, 25, NULL, NULL),
    (45, 'CU', 'copper', 'umol/L', 'numeric', 9, 19, NULL, NULL),
    (46, 'SE', 'selenium', 'umol/L', 'numeric', 1, 3, NULL, NULL),
    (47, 'LDH', 'lactate dehydrogenase', 'U/L', 'numeric', 40, 400, NULL, NULL),
    (48, 'PH', 'pH', NULL, 'numeric', 7.35, 7.45, NULL, NULL),
    (49, 'PCO2', 'carbon dioxide partial pressure', 'kPa', 'numeric', 4.5, 6, NULL, NULL),
    (50, 'PO2', 'oxygen partial pressure', 'kPa', 'numeric', 10, 13, NULL, NULL),
    (51, 'HCO3', 'bicarbonate', 'mmol/L', 'numeric', 20, 26, NULL, NULL),
    (52, 'LACT', 'lactate', 'mmol/L', 'numeric', 0.5, 2.5, NULL, NULL),
    (53, 'ICA', 'ionised calcium', 'mmol/L', 'numeric', 1.12, 1.4, NULL, NULL),
    (54, 'PT', 'prothrombin time', 's', 'numeric', 6, 9, NULL, NULL),
    (55, 'APTT', 'activated partial thromboplastin time', 's', 'numeric', 10, 17, NULL, NULL),
    (56, 'FIBR', 'fibrinogen', 'g/L', 'numeric', 1, 4, NULL, NULL),
    (57, 'DDIM', 'D-dimers', 'mg/L', 'numeric', 0, 0.5, NULL, NULL),
    (58, 'USG', 'urine specific gravity', NULL, 'numeric', 1.015, 1.045, NULL, NULL),
    (59, 'UPH', 'urine pH', NULL, 'numeric', 5.5, 7.5, NULL, NULL),
    (60, 'UPC', 'urine protein to creatinine ratio', NULL, 'numeric', 0, 0.5, NULL, NULL),
    (61, 'UPRO', 'urine protein', 'g/L', 'numeric', 0, 0.3, NULL, NULL),
    (62, 'T4', 'thyroxine', 'nmol/L', 'numeric', 13, 51, NULL, NULL),
    (63, 'CORT', 'cortisol', 'nmol/L', 'numeric', 25, 150, NULL, NULL),
    (64, 'ACTH', 'adrenocorticotropic hormone', 'pg/mL', 'numeric', 9, 35, NULL, NULL),
    (65, 'PB', 'lead', 'umol/L', 'numeric', 0, 0.5, NULL, NULL),
    (66, 'IGG', 'immunoglobulin G', 'g/L', 'numeric', 8, 20, NULL, NULL),
    (67, 'ORG', 'organism', NULL, 'text', NULL, NULL, NULL, NULL),
    (68, 'SENS', 'antimicrobial sensitivity', NULL, 'text', NULL, NULL, NULL, NULL),
    (69, 'QUAL', 'qualitative result', NULL, 'text', NULL, NULL, NULL, NULL),
    (70, 'REPORT', 'report', NULL, 'text', NULL, NULL, NULL, NULL);
INSERT INTO lab_analytes (id, code, name, unit, kind) SELECT id, code, name, unit, kind FROM l_analytes;

INSERT INTO lab_tests (id, code, name, is_panel, discipline, sample_type, turnaround_hours, performed,
                       external_code, diagnosis_code)
SELECT id, code, name, is_panel, discipline, sample_type, turnaround_hours, performed, external_code, diagnosis_code
  FROM pg_temp.lab_catalogue();
INSERT INTO lab_test_analytes (test_id, analyte_id, position)
SELECT c.id, a.analyte, a.pos::integer FROM pg_temp.lab_catalogue() AS c, unnest(c.analytes) WITH ORDINALITY AS a (analyte, pos);

-- Intervals: every numeric analyte for the six species, the cat's within 15 %
-- of the dog's, the large animals' within 30 % (a hash of the pair), 61-456 in
-- force; the January review replaced the ten biochemistry analytes 15-24's,
-- whose earlier rows are 1-60 (valid until 1 January). The range's 457-460
-- stay unused: 66 numeric analytes, not the document's "about 400" exactly.
CREATE TEMP TABLE l_intervals AS
SELECT 60 + row_number() OVER (ORDER BY a.id, s.i)::integer AS id, a.id AS analyte_id, s.sp AS species,
       round(a.lo * f, 3) AS low, round(a.hi * f, 3) AS high, a.clo AS critical_low, a.chi AS critical_high,
       CASE WHEN a.id BETWEEN 15 AND 24 THEN (SELECT jan1 FROM l_env) ELSE date '2020-01-01' END AS valid_from
  FROM l_analytes AS a,
       (VALUES (1, 'dog'), (2, 'cat'), (3, 'horse'), (4, 'cattle'), (5, 'sheep'), (6, 'goat')) AS s (i, sp),
       LATERAL (SELECT CASE s.sp WHEN 'dog' THEN 1.0 WHEN 'cat' THEN 0.85 + 0.3 * pg_temp.lab_u(a.id * 8 + s.i, 50)
                       ELSE 0.7 + 0.6 * pg_temp.lab_u(a.id * 8 + s.i, 50) END::numeric AS f) AS ff
 WHERE a.kind = 'numeric';
INSERT INTO lab_reference_intervals (id, analyte_id, species, low, high, critical_low, critical_high, valid_from, valid_until)
SELECT id - 60 - 6 * (14), analyte_id, species, round(low * 0.95, 3), round(high * 1.04, 3), critical_low, critical_high,
       date '2020-01-01', valid_from
  FROM l_intervals WHERE analyte_id BETWEEN 15 AND 24
UNION ALL
SELECT id, analyte_id, species, low, high, critical_low, critical_high, valid_from, NULL FROM l_intervals;

-- Prices: test t's price t until 1 January, 180 + t from it, 3 % dearer (a
-- game value), by discipline; the handling fee is lab_settings'.
INSERT INTO lab_prices (id, test_id, price, valid_from, valid_until)
SELECT c.id + v.k * 180, c.id, round(p.base * (1 + 0.03 * v.k), 2),
       CASE v.k WHEN 0 THEN (SELECT jan1 FROM l_env) - interval '1 year' ELSE (SELECT jan1 FROM l_env) END,
       CASE v.k WHEN 0 THEN (SELECT jan1 FROM l_env) END
  FROM pg_temp.lab_catalogue() AS c, (VALUES (0), (1)) AS v (k),
       LATERAL (SELECT (CASE c.discipline WHEN 'haematology' THEN 14 WHEN 'biochemistry' THEN 9 WHEN 'blood-gas' THEN 18
                                          WHEN 'coagulation' THEN 22 WHEN 'urinalysis' THEN 12 WHEN 'cytology' THEN 38
                                          WHEN 'microbiology' THEN 30 WHEN 'serology' THEN 26 WHEN 'residue' THEN 15
                                          WHEN 'histopathology' THEN 72 WHEN 'molecular' THEN 58 WHEN 'endocrinology' THEN 34
                                          ELSE 48 END * CASE WHEN c.is_panel THEN 2.6 ELSE 1 END
                        * (0.85 + 0.3 * pg_temp.lab_u(c.id, 51)))::numeric AS base) AS p;

INSERT INTO lab_accounts (id, kind, practice_id, callback_url, opened_on)
SELECT 1, 'internal', NULL, NULL, date '2019-03-01'
UNION ALL
SELECT a, 'practice', 3 * (a - 1), 'http://practices:8000/results',
       date '2019-06-01' + floor(1500 * pg_temp.lab_u(a, 52))::integer
  FROM generate_series(2, 121) AS a;

-- --- The one pass: orders, tests, samples, send-outs ------------------------------------------

CREATE TEMP TABLE l_t AS SELECT * FROM pg_temp.lab_order_tests(:'load_epoch'::timestamptz, :customer_utc_offset);
CREATE INDEX ON l_t (order_test_id);
ANALYZE l_t;

INSERT INTO lab_orders (id, account_id, client_ref, priority, animal_id, consultation_id, requested_by, patient_ref,
                        client_surname, species, sex, born_on, microchip, ueln, ear_tag, clinical_notes,
                        withdrawal_ends_on, ordered_at, received_at, completed_at, cancelled_at)
SELECT DISTINCT ON (order_id) order_id, account_id, client_ref, priority, animal_id, consultation_id, requested_by,
       patient_ref, client_surname, species, sex, born_on, microchip, ueln, ear_tag,
       CASE WHEN pg_temp.lab_u(order_id, 53) < 0.3
            THEN (ARRAY['inappetence for three days', 'polyuria and polydipsia', 'pre-anaesthetic screen',
                        'weight loss', 'pyrexia of unknown origin', 'lameness, left fore', 'follow-up of treatment',
                        'vomiting', 'drop in milk yield', 'coughing'])[1 + floor(10 * pg_temp.lab_u(order_id, 54))::integer] END,
       withdrawal_ends_on, ordered_at, received_at, completed_at, order_cancelled_at
  FROM l_t ORDER BY order_id;

-- Samples: one a container; kept a week (two for serum), disposed by the
-- 06:00 job after; one in three hundred under a chain of custody.
INSERT INTO lab_samples (id, order_id, label, sample_type, collected_at, collected_by, received_at, condition, custody,
                         keep_until, disposed_at)
SELECT s.sample_id, s.order_id, s.label, s.sample_type, s.collected_at, s.collected_by, s.received_at, s.condition,
       pg_temp.lab_u(s.sample_id, 55) < 1.0 / 300, s.keep,
       CASE WHEN pg_temp.lab_utc(date_trunc('day', pg_temp.lab_local(s.keep, (SELECT o FROM l_env))) + interval '30 hours',
                                 (SELECT o FROM l_env)) < (SELECT e FROM l_env)
            THEN pg_temp.lab_utc(date_trunc('day', pg_temp.lab_local(s.keep, (SELECT o FROM l_env))) + interval '30 hours',
                                 (SELECT o FROM l_env)) + 20 * pg_temp.lab_u(s.sample_id, 56) * interval '1 minute' END
  FROM (SELECT DISTINCT ON (sample_id) sample_id, order_id, label, sample_type, collected_at, collected_by, received_at,
               condition,
               received_at + CASE WHEN sample_type = 'serum' THEN interval '14 days' ELSE interval '7 days' END AS keep
          FROM l_t ORDER BY sample_id) AS s;

INSERT INTO lab_order_tests (id, order_id, sample_id, test_id, request_id, routing, add_on, status, not_performed_reason,
                             not_performed_at, technical_by, technical_at, released_by, released_at, cancelled_at, comment)
SELECT order_test_id, order_id, sample_id, test_id, request_id, routing, false, status, not_performed_reason,
       CASE WHEN status = 'not-performed' THEN final_at END, technical_by, technical_at, released_by, released_at,
       cancelled_at,
       CASE WHEN status = 'released' AND pg_temp.lab_u(order_test_id, 57) < 0.05
            THEN (ARRAY['interpret with the clinical signs', 'mild haemolysis, potassium may be overestimated',
                        'repeat in two weeks advised', 'consistent with the previous result',
                        'result telephoned to the requesting vet'])[1 + floor(5 * pg_temp.lab_u(order_test_id, 58))::integer] END
  FROM l_t;

INSERT INTO lab_send_outs (id, order_test_id, send_key, external_accession, packed_at, sent_at, accepted_at, answered_at,
                           due_by, status)
SELECT send_out_id, order_test_id, send_key, xlab_accession, packed_at, sent_at, accepted_at, answered_at, due_by,
       send_status
  FROM l_t WHERE send_out_id IS NOT NULL;

-- --- Results -------------------------------------------------------------------------------------

-- One per analyte of each test measured (an in-house run or bench reading,
-- or the external lab's answer); a numeric value flagged against the
-- interval in force for the species on the day (none for a rabbit or a
-- ferret), 82 % normal, critical values 3.5 % of the critical-limited
-- analytes; text by its analyte; a listed disease's test positive or suspect
-- one in eight, a category A disease's never (the history holds no outbreak). Ids in time order, the amendments (about a thousand, below) after.
CREATE TEMP TABLE l_r AS
SELECT t.order_test_id, ta.analyte_id, ta.position, t.measured_at + (ta.position - 1) * interval '2 seconds' AS measured_at,
       t.species, t.test_id, c.discipline, c.diagnosis_code, a.kind, a.lo, a.hi, a.clo, a.chi,
       pg_temp.lab_u(t.order_test_id::bigint * 128 + ta.analyte_id, 60)::numeric AS u1,
       pg_temp.lab_u(t.order_test_id::bigint * 128 + ta.analyte_id, 61)::numeric AS u2
  FROM l_t AS t JOIN lab_test_analytes AS ta ON ta.test_id = t.test_id
  JOIN lab_tests AS c ON c.id = t.test_id JOIN l_analytes AS a ON a.id = ta.analyte_id
 WHERE t.measured_at IS NOT NULL AND t.status IN ('in-progress', 'sent-out', 'technical', 'released');

CREATE TEMP TABLE l_rv AS
SELECT r.*, i.id AS interval_id,
       CASE WHEN r.kind = 'text' THEN NULL
            WHEN r.clo IS NOT NULL AND r.u2 < 0.0175 THEN round(r.clo * (0.6 + 0.35 * r.u1), 3)
            WHEN r.clo IS NOT NULL AND r.u2 < 0.035 THEN round(r.chi * (1.05 + 0.35 * r.u1), 3)
            ELSE round((coalesce(i.low, r.lo) + (coalesce(i.high, r.hi) - coalesce(i.low, r.lo))
                        * CASE WHEN r.u1 < 0.82 THEN 0.05 + 0.9 * r.u1 / 0.82
                               WHEN r.u1 < 0.91 THEN 1.05 + 0.6 * (r.u1 - 0.82) / 0.09
                               WHEN coalesce(i.low, r.lo) > 0 THEN -0.05 - 0.4 * (r.u1 - 0.91) / 0.09
                               ELSE 0.05 + 0.9 * r.u2 END)::numeric, 3) END AS v,
       i.low, i.high
  FROM l_r AS r
  LEFT JOIN lab_reference_intervals AS i
    ON i.analyte_id = r.analyte_id AND i.species = r.species AND r.kind = 'numeric'
   AND i.valid_from <= pg_temp.lab_local(r.measured_at, (SELECT o FROM l_env))::date
   AND coalesce(i.valid_until, 'infinity') > pg_temp.lab_local(r.measured_at, (SELECT o FROM l_env))::date;

CREATE TEMP TABLE l_res AS
SELECT row_number() OVER (ORDER BY measured_at, order_test_id, position)::integer AS id, x.*
  FROM (SELECT order_test_id, analyte_id, position, measured_at, interval_id,
               CASE WHEN kind = 'numeric' THEN greatest(v, 0) END AS numeric_value,
               CASE WHEN kind = 'text' THEN
                 CASE analyte_id
                   WHEN 67 THEN CASE WHEN u1 < 0.55 THEN 'no growth'
                                     ELSE (ARRAY['Escherichia coli', 'Staphylococcus pseudintermedius', 'Streptococcus equi subsp. zooepidemicus',
                                                 'Pseudomonas aeruginosa', 'Proteus mirabilis', 'Staphylococcus aureus', 'Streptococcus uberis',
                                                 'Klebsiella pneumoniae', 'Trueperella pyogenes', 'Pasteurella multocida',
                                                 'Malassezia pachydermatis', 'Microsporum canis'])[1 + floor(12 * u2)::integer] END
                   WHEN 68 THEN (ARRAY['amoxicillin-clavulanate S; enrofloxacin S; tetracycline R; trimethoprim-sulfonamide S',
                                       'amoxicillin-clavulanate R; cefalexin R; enrofloxacin S; gentamicin S',
                                       'penicillin S; ceftiofur S; oxytetracycline S; florfenicol S',
                                       'ampicillin R; enrofloxacin I; marbofloxacin S; doxycycline S',
                                       'no isolate to test'])[1 + floor(5 * u2)::integer]
                   WHEN 69 THEN CASE WHEN diagnosis_code IN ('D-FM01', 'D-AH01', 'D-SP01', 'D-LS01') THEN 'negative'
                                     WHEN diagnosis_code IS NOT NULL THEN CASE WHEN u1 < 0.09 THEN 'positive' WHEN u1 < 0.12 THEN 'suspect' ELSE 'negative' END
                                     WHEN u1 < 0.10 THEN 'positive' WHEN u1 < 0.12 THEN 'suspect' ELSE 'negative' END
                   ELSE CASE discipline
                     WHEN 'cytology' THEN (ARRAY['inflammatory, neutrophilic; no neoplastic cells seen', 'lipoma consistent; adipocytes only',
                                                 'mast cell tumour suspected; histopathology advised', 'reactive lymph node',
                                                 'non-diagnostic, poorly cellular'])[1 + floor(5 * u2)::integer]
                     WHEN 'histopathology' THEN (ARRAY['benign, completely excised', 'malignant, margins narrow', 'chronic inflammation',
                                                       'no significant abnormality', 'neoplasia, grade II'])[1 + floor(5 * u2)::integer]
                     WHEN 'microbiology' THEN CASE WHEN u1 < 0.7 THEN 'no parasites seen' ELSE 'strongyle-type eggs, ' || (50 + floor(1500 * u2))::integer || ' per gram' END
                     WHEN 'urinalysis' THEN (ARRAY['inactive sediment', 'struvite crystals, few', 'pyuria and bacteriuria',
                                                   'calcium oxalate crystals', 'haematuria, moderate'])[1 + floor(5 * u2)::integer]
                     WHEN 'haematology' THEN (ARRAY['normal morphology', 'mild anisocytosis', 'toxic neutrophils seen',
                                                    'platelet clumps; count may be underestimated', 'polychromasia'])[1 + floor(5 * u2)::integer]
                     ELSE (ARRAY['within the reference range', 'above the reference range', 'below the reference range',
                                 'equivocal; repeat advised'])[1 + floor(4 * u2)::integer] END END END AS text_value,
               CASE WHEN kind = 'text' OR interval_id IS NULL THEN NULL
                    WHEN clo IS NOT NULL AND v < clo THEN 'critical-low' WHEN chi IS NOT NULL AND v > chi THEN 'critical-high'
                    WHEN v < low THEN 'low' WHEN v > high THEN 'high' ELSE 'normal' END AS flag,
               discipline, test_id, diagnosis_code
          FROM l_rv) AS x;

-- Amendments (rule 3): one released in-house test in twenty-two, its first
-- numeric result corrected 1 to 48 hours after the release by a clinical
-- pathologist, the first row kept; numbered after the year's results.
CREATE TEMP TABLE l_amend AS
SELECT (SELECT max(id) FROM l_res) + row_number() OVER (ORDER BY am.amended_at, am.order_test_id)::integer AS id, am.*
  FROM (SELECT DISTINCT ON (r.order_test_id) r.id AS supersedes_id, r.order_test_id, r.analyte_id, r.interval_id,
               round(r.numeric_value * (0.85 + 0.3 * pg_temp.lab_u(r.order_test_id, 62))::numeric, 3) AS numeric_value,
               t.released_at + (1 + 47 * pg_temp.lab_u(r.order_test_id, 63)) * interval '1 hour' AS amended_at,
               79 + floor(2 * pg_temp.lab_u(r.order_test_id, 64))::integer AS amended_by,
               (ARRAY['transcription error corrected', 'repeat on the stored sample', 'dilution factor not applied',
                      'wrong analyser channel', 'sample identity confirmed, value corrected'])[1 + floor(5 * pg_temp.lab_u(r.order_test_id, 65))::integer]
                 AS amendment_reason
          FROM l_res AS r JOIN l_t AS t USING (order_test_id)
         WHERE t.status = 'released' AND t.routing = 'in-house' AND r.numeric_value IS NOT NULL
           AND pg_temp.lab_u(r.order_test_id, 66) < 1.0 / 22
         ORDER BY r.order_test_id, r.position) AS am
 WHERE am.amended_at < (SELECT e FROM l_env);

-- --- Quality control and batches -------------------------------------------------------------------

-- QC (answer 8): every analyser at 06:45, the on-call ones (1, 3, 5) again at
-- 21:15; three levels on haematology (1, 2), two on the others; one run in
-- fifty fails and is rerun, passing, 20 to 40 minutes later.
CREATE TEMP TABLE l_qc AS
SELECT row_number() OVER (ORDER BY q.run_at, q.machine_id, q.level, q.rerun)::integer AS id, q.*
  FROM (SELECT b.machine_id, b.level, b.run_at, false AS rerun, b.fail,
               'L' || to_char(b.d, 'YYMM') || '-' || b.machine_id || b.level AS control_lot
          FROM (SELECT m.machine_id, lv.level, d.d, pg_temp.lab_utc(d.d + w.at, (SELECT o FROM l_env)) AS run_at,
                       pg_temp.lab_u((extract(epoch FROM d.d)::bigint / 86400) * 64 + m.machine_id * 8 + lv.level + w.k * 4, 67) < 0.02 AS fail
                  FROM generate_series((SELECT s FROM l_env), pg_temp.lab_local((SELECT e FROM l_env), (SELECT o FROM l_env)),
                                       interval '1 day') AS d (d),
                       (VALUES (1), (2), (3), (4), (5), (6)) AS m (machine_id),
                       (VALUES (0, interval '6 hours 45 minutes'), (1, interval '21 hours 15 minutes')) AS w (k, at),
                       LATERAL generate_series(1, CASE WHEN m.machine_id <= 2 THEN 3 ELSE 2 END) AS lv (level)
                 WHERE w.k = 0 OR m.machine_id IN (1, 3, 5)) AS b
         WHERE b.run_at < (SELECT e FROM l_env)
        UNION ALL
        SELECT b.machine_id, b.level, b.run_at + (20 + 20 * pg_temp.lab_u(extract(epoch FROM b.run_at)::bigint + b.level, 68)) * interval '1 minute',
               true, false, 'L' || to_char(b.d, 'YYMM') || '-' || b.machine_id || b.level
          FROM (SELECT m.machine_id, lv.level, d.d, pg_temp.lab_utc(d.d + w.at, (SELECT o FROM l_env)) AS run_at,
                       pg_temp.lab_u((extract(epoch FROM d.d)::bigint / 86400) * 64 + m.machine_id * 8 + lv.level + w.k * 4, 67) < 0.02 AS fail
                  FROM generate_series((SELECT s FROM l_env), pg_temp.lab_local((SELECT e FROM l_env), (SELECT o FROM l_env)),
                                       interval '1 day') AS d (d),
                       (VALUES (1), (2), (3), (4), (5), (6)) AS m (machine_id),
                       (VALUES (0, interval '6 hours 45 minutes'), (1, interval '21 hours 15 minutes')) AS w (k, at),
                       LATERAL generate_series(1, CASE WHEN m.machine_id <= 2 THEN 3 ELSE 2 END) AS lv (level)
                 WHERE w.k = 0 OR m.machine_id IN (1, 3, 5)) AS b
         WHERE b.fail AND b.run_at + interval '40 minutes' < (SELECT e FROM l_env)) AS q;

INSERT INTO lab_qc_runs (id, machine_id, level, control_lot, run_at, run_by, outcome, rule_broken, action)
SELECT id, machine_id, level, control_lot, run_at, 71 + floor(8 * pg_temp.lab_u(id, 69))::integer,
       CASE WHEN fail THEN 'fail' ELSE 'pass' END,
       CASE WHEN fail THEN (ARRAY['1-3s', '2-2s', 'R-4s', '4-1s', '10-x'])[1 + floor(5 * pg_temp.lab_u(id, 70))::integer] END,
       CASE WHEN fail THEN 'rerun' ELSE 'none' END
  FROM l_qc;

-- Batches: an analyser's results uploaded once an hour (haematology on 1 or
-- 2, biochemistry on 3 or 4, blood gases on 5, coagulation on 6; the on-call
-- 1, 3 and 5 at night), each naming the QC run in force (the machine's last
-- passing run before it).
CREATE TEMP TABLE l_rb AS
SELECT r.id AS result_id, r.measured_at,
       CASE r.discipline
         WHEN 'haematology' THEN CASE WHEN night OR pg_temp.lab_u(r.order_test_id, 71) < 0.5 THEN 1 ELSE 2 END
         WHEN 'biochemistry' THEN CASE WHEN night OR pg_temp.lab_u(r.order_test_id, 71) < 0.5 THEN 3 ELSE 4 END
         WHEN 'blood-gas' THEN 5 WHEN 'coagulation' THEN 6 END AS machine_id
  FROM l_res AS r JOIN lab_tests AS c ON c.id = r.test_id,
       LATERAL (SELECT extract(hour FROM pg_temp.lab_local(r.measured_at, (SELECT o FROM l_env))) NOT BETWEEN 7 AND 20
                       OR extract(isodow FROM pg_temp.lab_local(r.measured_at, (SELECT o FROM l_env))) = 7 AS night) AS n
 WHERE c.performed = 'in-house' AND r.discipline IN ('haematology', 'biochemistry', 'blood-gas', 'coagulation');

CREATE TEMP TABLE l_b AS
SELECT row_number() OVER (ORDER BY min(measured_at), machine_id)::integer AS id, machine_id,
       date_trunc('hour', measured_at) AS hr, min(measured_at) - interval '6 minutes' AS started_at,
       max(measured_at) + interval '2 minutes' AS uploaded_at, count(*)::integer AS result_count
  FROM l_rb GROUP BY machine_id, date_trunc('hour', measured_at);

INSERT INTO lab_batches (id, machine_id, qc_run_id, started_at, uploaded_at, result_count)
SELECT b.id, b.machine_id,
       (SELECT q.id FROM l_qc AS q WHERE q.machine_id = b.machine_id AND NOT q.fail AND q.run_at <= b.started_at
         ORDER BY q.run_at DESC LIMIT 1),
       b.started_at, CASE WHEN b.uploaded_at < (SELECT e FROM l_env) THEN b.uploaded_at ELSE (SELECT e FROM l_env) - interval '1 minute' END,
       b.result_count
  FROM l_b AS b;

INSERT INTO lab_results (id, order_test_id, analyte_id, batch_id, numeric_value, text_value, flag, interval_id, measured_at)
SELECT r.id, r.order_test_id, r.analyte_id, b.id, r.numeric_value, r.text_value, r.flag, r.interval_id, r.measured_at
  FROM l_res AS r LEFT JOIN l_rb AS rb ON rb.result_id = r.id
  LEFT JOIN l_b AS b ON b.machine_id = rb.machine_id AND b.hr = date_trunc('hour', rb.measured_at);
INSERT INTO lab_results (id, order_test_id, analyte_id, numeric_value, flag, interval_id, measured_at, supersedes_id,
                         amended_by, amended_at, amendment_reason)
SELECT a.id, a.order_test_id, a.analyte_id, a.numeric_value,
       CASE WHEN i.id IS NULL THEN NULL
            WHEN i.critical_low IS NOT NULL AND a.numeric_value < i.critical_low THEN 'critical-low'
            WHEN i.critical_high IS NOT NULL AND a.numeric_value > i.critical_high THEN 'critical-high'
            WHEN a.numeric_value < i.low THEN 'low' WHEN a.numeric_value > i.high THEN 'high' ELSE 'normal' END,
       a.interval_id, a.amended_at, a.supersedes_id, a.amended_by, a.amended_at, a.amendment_reason
  FROM l_amend AS a LEFT JOIN lab_reference_intervals AS i ON i.id = a.interval_id;

-- --- Critical calls, notifications ------------------------------------------------------------------

-- Each critical result phoned within the hour (rule 6): the centre's to its
-- requesting vet, a practice's to a person there, by name.
INSERT INTO lab_critical_calls (id, result_id, called_at, called_by, called_staff_id, called_person, read_back)
SELECT row_number() OVER (ORDER BY c.called_at, c.result_id)::integer, c.*
  FROM (SELECT r.id AS result_id, r.measured_at + (5 + 45 * pg_temp.lab_u(r.id, 72)) * interval '1 minute' AS called_at,
               71 + floor(8 * pg_temp.lab_u(r.id, 73))::integer AS called_by, t.requested_by,
               CASE WHEN t.account_id > 1
                    THEN 'Dr ' || (ARRAY['Moreau', 'Bauer', 'Lindqvist', 'Costa', 'Hartmann', 'Byrne', 'Vermeulen',
                                         'Kowalski'])[1 + floor(8 * pg_temp.lab_u(r.id, 74))::integer] END,
               pg_temp.lab_u(r.id, 75) >= 0.03
          FROM lab_results AS r JOIN l_t AS t USING (order_test_id)
         WHERE r.flag IN ('critical-low', 'critical-high') AND r.supersedes_id IS NULL) AS c
 WHERE c.called_at < (SELECT e FROM l_env);

-- A positive or suspect result for a listed disease's test, technically
-- validated: notified within the hour for category A, the day for the others
-- (rule 7), by the authority's portal.
INSERT INTO lab_notifications (id, order_test_id, diagnosis_code, category, suspected_at, notified_at, channel, authority_ref)
SELECT row_number() OVER (ORDER BY n.suspected_at, n.order_test_id)::integer, n.order_test_id, n.diagnosis_code, n.category,
       n.suspected_at, CASE WHEN n.notified_at < (SELECT e FROM l_env) THEN n.notified_at END,
       CASE WHEN n.notified_at < (SELECT e FROM l_env) THEN 'authority-portal' END,
       CASE WHEN n.notified_at < (SELECT e FROM l_env) THEN 'VS-' || to_char(n.notified_at, 'YYYY') || '-'
                                                           || lpad(n.order_test_id::text, 6, '0') END
  FROM (SELECT DISTINCT ON (t.order_test_id) t.order_test_id, c.diagnosis_code,
               CASE WHEN c.diagnosis_code IN ('D-FM01', 'D-AH01', 'D-SP01', 'D-LS01') THEN 'A' ELSE 'other' END AS category,
               t.technical_at AS suspected_at,
               t.technical_at + CASE WHEN c.diagnosis_code IN ('D-FM01', 'D-AH01', 'D-SP01', 'D-LS01')
                                     THEN (10 + 40 * pg_temp.lab_u(t.order_test_id, 76)) * interval '1 minute'
                                     ELSE (1 + 19 * pg_temp.lab_u(t.order_test_id, 76)) * interval '1 hour' END AS notified_at
          FROM l_t AS t JOIN lab_tests AS c ON c.id = t.test_id JOIN lab_results AS r USING (order_test_id)
         WHERE c.diagnosis_code IS NOT NULL AND t.technical_at IS NOT NULL AND r.text_value IN ('positive', 'suspect')
         ORDER BY t.order_test_id) AS n;

-- --- Sample events --------------------------------------------------------------------------------

-- Received, stored once every test on the sample is final, sent out with its
-- send-outs, disposed: about three a sample.
INSERT INTO lab_sample_events (id, sample_id, kind, at, recorded_by, place)
SELECT row_number() OVER (ORDER BY e.at, e.sample_id, e.k)::integer, e.sample_id, e.kind, e.at,
       71 + floor(8 * pg_temp.lab_u(e.sample_id * 8 + e.k, 77))::integer, e.place
  FROM (SELECT s.id AS sample_id, 1 AS k, 'received' AS kind, s.received_at AS at, 'reception' AS place
          FROM lab_samples AS s WHERE s.received_at IS NOT NULL
        UNION ALL
        SELECT t.sample_id, 2, 'stored', max(t.final_at) + interval '10 minutes',
               'fridge ' || (1 + t.sample_id % 4)
          FROM l_t AS t GROUP BY t.sample_id
        HAVING bool_and(t.final_at IS NOT NULL) AND max(t.final_at) + interval '10 minutes' < (SELECT e FROM l_env)
           AND bool_or(t.status IN ('released', 'not-performed'))
        UNION ALL
        SELECT t.sample_id, 3, 'sent-out', t.packed_at, 'courier, external reference lab'
          FROM l_t AS t WHERE t.packed_at IS NOT NULL
        UNION ALL
        SELECT s.id, 4, 'disposed', s.disposed_at, 'clinical waste' FROM lab_samples AS s WHERE s.disposed_at IS NOT NULL) AS e;

-- --- The practices' deliveries ----------------------------------------------------------------------

-- Purpose 2's record (vet-lab-practice-results): an interim delivery when a
-- test of a several-test order is released before the last, the final one at
-- completion, one per amendment; an attempt failing first (a 503) retried.
CREATE TEMP TABLE l_cb AS
SELECT ev.order_id, ev.kind, ev.revision, d.*
  FROM (SELECT o.order_id, 'interim' AS kind, 1 AS revision, min(o.final_at) AS event_at
          FROM l_t AS o WHERE o.account_id > 1 AND o.order_state <> 'cancelled' GROUP BY o.order_id
        HAVING count(*) > 1 AND min(o.final_at) < coalesce(max(o.completed_at), 'infinity')
           AND bool_or(o.status = 'released')
        UNION ALL
        SELECT DISTINCT o.order_id, 'final', 1, o.completed_at FROM l_t AS o
         WHERE o.account_id > 1 AND o.completed_at IS NOT NULL
        UNION ALL
        SELECT t.order_id, 'amended', row_number() OVER (PARTITION BY t.order_id ORDER BY a.amended_at)::integer, a.amended_at
          FROM l_amend AS a JOIN l_t AS t USING (order_test_id) WHERE t.account_id > 1) AS ev,
       LATERAL pg_temp.lab_delivery(ev.order_id, ev.kind, ev.revision, ev.event_at) AS d
 WHERE d.acknowledged_at < (SELECT e FROM l_env);

INSERT INTO lab_callbacks (id, order_id, kind, delivery_key, attempt, posted_at, http_status, acknowledged_at)
SELECT row_number() OVER (ORDER BY c.posted_at, c.order_id, c.attempt)::integer, c.*
  FROM (SELECT order_id, kind, delivery_key, 1 AS attempt, first_at AS posted_at,
               CASE WHEN attempts = 2 THEN 503 ELSE 200 END AS http_status,
               CASE WHEN attempts = 1 THEN acknowledged_at END AS acknowledged_at
          FROM l_cb
        UNION ALL
        SELECT order_id, kind, delivery_key, 2, posted_at, 200, acknowledged_at FROM l_cb WHERE attempts = 2) AS c;

-- --- Charges ----------------------------------------------------------------------------------------

-- The practices' orders only (rule 13): each test at the price of its order's
-- day, half again when urgent, a handling fee an order; billable on the
-- release's local date, voided on a cancellation or an unfit sample.
INSERT INTO lab_charges (id, account_id, order_id, order_test_id, kind, price, amount, billable_on, voided_at)
SELECT row_number() OVER (ORDER BY c.ordered_at, c.order_id, c.k, c.order_test_id)::integer, c.account_id, c.order_id,
       c.order_test_id, c.kind, c.price, c.amount, c.billable_on, c.voided_at
  FROM (SELECT t.ordered_at, t.order_id, t.order_test_id, 1 AS k, t.account_id, 'test' AS kind, p.price, p.price AS amount,
               pg_temp.lab_local(t.released_at, (SELECT o FROM l_env))::date AS billable_on,
               CASE WHEN t.status IN ('cancelled', 'not-performed') THEN t.final_at END AS voided_at
          FROM l_t AS t JOIN lab_prices AS p ON p.test_id = t.test_id
               AND p.valid_from <= pg_temp.lab_local(t.ordered_at, (SELECT o FROM l_env))::date
               AND coalesce(p.valid_until, 'infinity') > pg_temp.lab_local(t.ordered_at, (SELECT o FROM l_env))::date
         WHERE t.account_id > 1
        UNION ALL
        SELECT t.ordered_at, t.order_id, t.order_test_id, 2, t.account_id, 'urgent', p.price, round(p.price * 0.5, 2),
               pg_temp.lab_local(t.released_at, (SELECT o FROM l_env))::date,
               CASE WHEN t.status IN ('cancelled', 'not-performed') THEN t.final_at END
          FROM l_t AS t JOIN lab_prices AS p ON p.test_id = t.test_id
               AND p.valid_from <= pg_temp.lab_local(t.ordered_at, (SELECT o FROM l_env))::date
               AND coalesce(p.valid_until, 'infinity') > pg_temp.lab_local(t.ordered_at, (SELECT o FROM l_env))::date
         WHERE t.account_id > 1 AND t.priority = 'urgent'
        UNION ALL
        (SELECT DISTINCT ON (t.order_id) t.ordered_at, t.order_id, NULL, 0, t.account_id, 'handling', s.handling_fee,
                s.handling_fee, pg_temp.lab_local(t.completed_at, (SELECT o FROM l_env))::date, t.order_cancelled_at
           FROM l_t AS t, lab_settings AS s WHERE t.account_id > 1 ORDER BY t.order_id)) AS c;

-- --- Checks: the ranges hold, the core's requests agree ------------------------------------------------

DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(x, '; ') INTO bad FROM (
        SELECT 'lab_orders ' || max(id) AS x FROM lab_orders HAVING max(id) > 14000
        UNION ALL SELECT 'lab_order_tests ' || max(id) FROM lab_order_tests HAVING max(id) > 24000
        UNION ALL SELECT 'lab_results ' || max(id) FROM lab_results HAVING max(id) > 192000
        UNION ALL SELECT 'lab_reference_intervals ' || max(id) FROM lab_reference_intervals HAVING max(id) > 460
        UNION ALL SELECT 'a centre order on account ' || account_id FROM lab_orders
         WHERE consultation_id IS NOT NULL AND account_id <> 1 GROUP BY account_id
        UNION ALL SELECT 'request ' || request_id || ' twice' FROM lab_order_tests
         WHERE request_id IS NOT NULL GROUP BY request_id HAVING count(*) > 1
        UNION ALL SELECT 'released test ' || id || ' without both validations' FROM lab_order_tests
         WHERE status = 'released' AND (technical_at IS NULL OR released_at < technical_at)
        UNION ALL SELECT 'send_key of send-out ' || id FROM lab_send_outs
         WHERE send_key <> md5('vet-lab-send-out:' || id)::uuid
        UNION ALL SELECT 'a time after T0 in ' || t FROM (
            SELECT 'lab_orders' AS t FROM lab_orders WHERE greatest(ordered_at, received_at, completed_at, cancelled_at) >= (SELECT e FROM l_env)
            UNION ALL SELECT 'lab_order_tests' FROM lab_order_tests
             WHERE greatest(technical_at, released_at, cancelled_at, not_performed_at) >= (SELECT e FROM l_env)
            UNION ALL SELECT 'lab_results' FROM lab_results WHERE measured_at >= (SELECT e FROM l_env)) AS y GROUP BY t
    ) AS z;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'load.sql: a range or an invariant does not hold: %', bad;
    END IF;
END $$;

-- --- Sequences: each resumes after its range (D276) -----------------------------------------------------

SELECT setval(pg_get_serial_sequence(t, 'id'), v)
  FROM (VALUES ('lab_analytes', 70), ('lab_tests', 180), ('lab_reference_intervals', 460), ('lab_prices', 360),
               ('lab_accounts', 121), ('lab_orders', 14000), ('lab_order_tests', 24000),
               ('lab_results', 192000)) AS r (t, v);
SELECT setval(pg_get_serial_sequence(t, 'id'), greatest(1, (xpath('/row/m/text()',
              query_to_xml(format('SELECT max(id) AS m FROM %I', t), false, true, '')))[1]::text::bigint))
  FROM unnest(ARRAY['lab_samples', 'lab_sample_events', 'lab_qc_runs', 'lab_batches', 'lab_critical_calls',
                    'lab_notifications', 'lab_send_outs', 'lab_callbacks', 'lab_charges']) AS t;

VACUUM (ANALYZE) lab_settings, lab_analytes, lab_tests, lab_test_analytes, lab_reference_intervals, lab_prices,
                 lab_accounts, lab_orders, lab_samples, lab_order_tests, lab_sample_events, lab_qc_runs, lab_batches,
                 lab_results, lab_critical_calls, lab_notifications, lab_send_outs, lab_callbacks, lab_charges;
