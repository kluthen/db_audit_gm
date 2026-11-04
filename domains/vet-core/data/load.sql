-- vet-core's history (v0.5 master spec 9.2; vet-core-domain.md, "The data
-- model", "Deterministic key ranges", "Loading"): last night's backup of the
-- centre's medical record, a year of history ending at T0. Runs after
-- schema.sql, connected to the core's database, as postgres, with
-- data/keys.sql streamed ahead of it in the same session (capture W2 item
-- 3): every id, and what the parts read of it, is computed by the key
-- functions pg_temp.core_*, never drawn here; this file adds what no part
-- reads (names, addresses, texts, diagnoses, procedures, prescriptions and
-- their lines, administrations, dispensings, batches, the other alerts) by
-- hashes of the ids (vc_u), never random(). docs/gm.md, "Core keys" and
-- "The data", documents both.
--
-- It reads load-data's three psql variables (capture W1 item 0, W2 item 3):
-- customer_timezone (Etc/GMT-2 for UTC+2), customer_utc_offset (hours, east
-- positive) and load_epoch (the run's start, UTC, to the minute: the load's
-- "now", T0, never now()). Every time in the database is UTC.
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
    IF to_regprocedure('pg_temp.core_stay(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'load.sql: the key functions are missing (gmctl load-data streams '
                        'data/keys.sql ahead of this file, in the same session)';
    END IF;
END $$;

-- The run's moment and offset, for the statements below and the checks.
CREATE TEMP TABLE l_env AS
SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
       pg_temp.vc_start(:'load_epoch'::timestamptz, :customer_utc_offset) AS s;

-- --- Business settings -----------------------------------------------------------

INSERT INTO business_settings (timezone, utc_offset_hours)
VALUES (:'customer_timezone', :customer_utc_offset);

DO $$
DECLARE
    s business_settings;
BEGIN
    SELECT * INTO s FROM business_settings;
    IF NOT EXISTS (SELECT 1 FROM pg_timezone_names
                    WHERE name = s.timezone
                      AND utc_offset = make_interval(hours => s.utc_offset_hours)) THEN
        RAISE EXCEPTION 'load.sql: customer_timezone % is not UTC% (customer_utc_offset)',
            s.timezone, CASE WHEN s.utc_offset_hours < 0 THEN '' ELSE '+' END
                        || s.utc_offset_hours;
    END IF;
END $$;

-- --- Places and people ---------------------------------------------------------

INSERT INTO sites (id, code, name, country, kind) VALUES
    (1, 'ALD-N', 'Aldermoor Veterinary Hospital North', 'XA', 'own'),
    (2, 'ALD-C', 'Aldermoor Veterinary Hospital Central', 'XA', 'centre'),
    (3, 'ALD-S', 'Aldermoor Veterinary Hospital South', 'XA', 'centre'),
    (4, 'ALD-BE', 'Aldermoor Veterinary Hospital Liège', 'BE', 'abroad'),
    (5, 'ALD-DE', 'Aldermoor Tierklinik Aachen', 'DE', 'abroad'),
    (6, 'ALD-LU', 'Aldermoor Veterinary Hospital Luxembourg', 'LU', 'abroad');

INSERT INTO sections (id, site_id, kind) VALUES (1, 1, 'horse'), (2, 1, 'farm'), (3, 1, 'domestic');

-- The diagnosis codes: a few per species group; the listed diseases flagged
-- (Regulation (EU) 2016/429; A: category A, notified within the hour; other:
-- another listed disease, within the day).
INSERT INTO diagnosis_codes (code, label, species_group, notifiable) VALUES
    ('D-GE01', 'gastroenteritis', 'domestic', 'none'),
    ('D-DE01', 'atopic dermatitis', 'domestic', 'none'),
    ('D-OT01', 'otitis externa', 'domestic', 'none'),
    ('D-OR01', 'cranial cruciate ligament rupture', 'domestic', 'none'),
    ('D-FB01', 'gastrointestinal foreign body', 'domestic', 'none'),
    ('D-RE01', 'chronic kidney disease', 'domestic', 'none'),
    ('D-EN01', 'diabetes mellitus', 'domestic', 'none'),
    ('D-EN02', 'hyperthyroidism', 'domestic', 'none'),
    ('D-CA01', 'congestive heart failure', 'domestic', 'none'),
    ('D-TR01', 'road traffic trauma', 'domestic', 'none'),
    ('D-DN01', 'periodontal disease', 'domestic', 'none'),
    ('D-UR01', 'feline lower urinary tract disease', 'domestic', 'none'),
    ('D-NE01', 'neoplasia', 'any', 'none'),
    ('D-WO01', 'wound', 'any', 'none'),
    ('D-PA01', 'endoparasitism', 'any', 'none'),
    ('D-PN01', 'pneumonia', 'any', 'none'),
    ('D-HC01', 'routine health check', 'any', 'none'),
    ('D-VA01', 'vaccination', 'any', 'none'),
    ('D-CO01', 'colic, spasmodic', 'horse', 'none'),
    ('D-CO02', 'colic, surgical', 'horse', 'none'),
    ('D-LA01', 'lameness, foot abscess', 'horse', 'none'),
    ('D-LA02', 'laminitis', 'horse', 'none'),
    ('D-LA03', 'osteoarthritis', 'horse', 'none'),
    ('D-RS01', 'equine asthma', 'horse', 'none'),
    ('D-DS01', 'dental overgrowth', 'horse', 'none'),
    ('D-RP01', 'pregnancy diagnosis', 'any', 'none'),
    ('D-EI01', 'equine influenza', 'horse', 'none'),
    ('D-SG01', 'strangles', 'horse', 'none'),
    ('D-MA01', 'mastitis', 'farm', 'none'),
    ('D-LA11', 'lameness, digital dermatitis', 'farm', 'none'),
    ('D-MF01', 'milk fever', 'farm', 'none'),
    ('D-DY01', 'dystocia', 'farm', 'none'),
    ('D-RE11', 'retained placenta', 'farm', 'none'),
    ('D-SC01', 'neonatal scour', 'farm', 'none'),
    ('D-BR01', 'bovine respiratory disease', 'farm', 'none'),
    ('D-KE01', 'ketosis', 'farm', 'none'),
    ('D-RB01', 'rabies', 'any', 'other'),
    ('D-EA01', 'equine infectious anaemia', 'horse', 'other'),
    ('D-EV01', 'equine viral arteritis', 'horse', 'other'),
    ('D-WN01', 'West Nile fever', 'horse', 'other'),
    ('D-BT01', 'bluetongue', 'farm', 'other'),
    ('D-TB01', 'bovine tuberculosis', 'farm', 'other'),
    ('D-BC01', 'brucellosis', 'farm', 'other'),
    ('D-BV01', 'bovine viral diarrhoea', 'farm', 'other'),
    ('D-QF01', 'Q fever', 'farm', 'other'),
    ('D-AN01', 'anthrax', 'any', 'other'),
    ('D-FM01', 'foot-and-mouth disease', 'farm', 'A'),
    ('D-AH01', 'African horse sickness', 'horse', 'A'),
    ('D-SP01', 'sheep pox and goat pox', 'farm', 'A'),
    ('D-LS01', 'lumpy skin disease', 'farm', 'A');

-- --- Medicines ------------------------------------------------------------------

-- 400 presentations of 40 products, ten each (five strengths in two forms):
-- id = 10 * (product - 1) + presentation. The antimicrobials and the
-- controlled drugs (ketamine and the opioids) flagged; meat and milk
-- withdrawal days null where the product is not authorised for
-- food-producing animals (the cascade then applies its minimums, rule 1);
-- food_chain_horse_allowed false for a product a food-chain horse may not
-- receive (phenylbutazone).
INSERT INTO medicines (id, name, authorisation_number, atcvet_code, form, antimicrobial,
                       controlled, meat_withdrawal_days, milk_withdrawal_days,
                       food_chain_horse_allowed)
SELECT 10 * (p.n - 1) + v,
       p.name || ' ' || (p.strength * (ARRAY[1, 2, 5, 10, 20])[1 + (v - 1) % 5])::text
              || ' ' || p.unit,
       'XA/V/' || lpad((10 * (p.n - 1) + v)::text, 5, '0'),
       p.atc,
       CASE WHEN v <= 5 THEN p.form1 ELSE p.form2 END,
       p.am, p.ctl, p.meat, p.milk, p.horse
  FROM (VALUES
    (1,  'Amoxicillin',              50, 'mg',    'QJ01CA04', 'tablet',    'injection', true,  false, 14,   2,    true),
    (2,  'Amoxicillin clavulanate',  50, 'mg',    'QJ01CR02', 'tablet',    'injection', true,  false, 42,   3,    true),
    (3,  'Benzylpenicillin procaine',300,'mg',    'QJ01CE09', 'injection', 'intramammary', true, false, 6, 3,  true),
    (4,  'Oxytetracycline',          100,'mg',    'QJ01AA06', 'injection', 'spray',     true,  false, 21,   7,    true),
    (5,  'Enrofloxacin',             15, 'mg',    'QJ01MA90', 'tablet',    'injection', true,  false, 10,   null, false),
    (6,  'Marbofloxacin',            5,  'mg',    'QJ01MA93', 'tablet',    'injection', true,  false, 6,    3,    false),
    (7,  'Ceftiofur',                50, 'mg',    'QJ01DD90', 'injection', 'intramammary', true, false, 8, 0,  true),
    (8,  'Trimethoprim sulfadiazine',80, 'mg',    'QJ01EW10', 'tablet',    'oral paste', true, false, 12,  4,    true),
    (9,  'Gentamicin',               40, 'mg',    'QJ01GB03', 'injection', 'eye drops', true,  false, 160,  7,    true),
    (10, 'Tulathromycin',            25, 'mg',    'QJ01FA94', 'injection', 'injection', true,  false, 22,   null, false),
    (11, 'Florfenicol',              300,'mg',    'QJ01BA90', 'injection', 'injection', true,  false, 30,   null, false),
    (12, 'Metronidazole',            50, 'mg',    'QJ01XD01', 'tablet',    'oral suspension', true, false, null, null, false),
    (13, 'Ketamine',                 10, 'mg/ml', 'QN01AX03', 'injection', 'injection', false, true,  1,    0,    true),
    (14, 'Methadone',                10, 'mg/ml', 'QN02AC90', 'injection', 'injection', false, true,  null, null, false),
    (15, 'Butorphanol',              10, 'mg/ml', 'QN02AF01', 'injection', 'injection', false, true,  0,    0,    true),
    (16, 'Buprenorphine',            3,  'mg/ml', 'QN02AE01', 'injection', 'injection', false, true,  null, null, false),
    (17, 'Morphine',                 10, 'mg/ml', 'QN02AA01', 'injection', 'injection', false, true,  null, null, false),
    (18, 'Fentanyl',                 50, 'ug/ml', 'QN01AH01', 'injection', 'transdermal patch', false, true, null, null, false),
    (19, 'Meloxicam',                1,  'mg',    'QM01AC06', 'tablet',    'injection', false, false, 5,    5,    true),
    (20, 'Carprofen',                20, 'mg',    'QM01AE91', 'tablet',    'injection', false, false, 21,   0,    true),
    (21, 'Flunixin',                 50, 'mg/ml', 'QM01AG90', 'injection', 'oral paste', false, false, 10,  1,    true),
    (22, 'Phenylbutazone',           200,'mg',    'QM01AA01', 'oral paste', 'injection', false, false, null, null, false),
    (23, 'Dexamethasone',            2,  'mg/ml', 'QH02AB02', 'injection', 'tablet',    false, false, 8,    3,    true),
    (24, 'Prednisolone',             5,  'mg',    'QH02AB06', 'tablet',    'injection', false, false, null, null, false),
    (25, 'Omeprazole',               10, 'mg',    'QA02BC01', 'oral paste', 'capsule',  false, false, null, null, false),
    (26, 'Maropitant',               16, 'mg',    'QA04AD90', 'tablet',    'injection', false, false, null, null, false),
    (27, 'Furosemide',               10, 'mg',    'QC03CA01', 'tablet',    'injection', false, false, 1,    1,    true),
    (28, 'Ivermectin',               10, 'mg',    'QP54AA01', 'injection', 'pour-on',   false, false, 28,   null, true),
    (29, 'Fenbendazole',             100,'mg',    'QP52AC13', 'oral paste', 'granules', false, false, 7,    5,    true),
    (30, 'Oxytocin',                 10, 'IU/ml', 'QH01BB02', 'injection', 'injection', false, false, 0,    0,    true),
    (31, 'Xylazine',                 20, 'mg/ml', 'QN05CM92', 'injection', 'injection', false, false, 1,    0,    true),
    (32, 'Detomidine',               10, 'mg/ml', 'QN05CM90', 'injection', 'oral gel', false, false, 2,    1,    true),
    (33, 'Acepromazine',             10, 'mg',    'QN05AA04', 'tablet',    'injection', false, false, null, null, false),
    (34, 'Propofol',                 10, 'mg/ml', 'QN01AX10', 'injection', 'injection', false, false, null, null, false),
    (35, 'Isoflurane',               100,'ml',    'QN01AB06', 'inhalation', 'inhalation', false, false, 2,  null, true),
    (36, 'Lidocaine',                20, 'mg/ml', 'QN01BB02', 'injection', 'gel',       false, false, 5,    1,    true),
    (37, 'Calcium borogluconate',    200,'mg/ml', 'QA12AA03', 'injection', 'oral gel', false, false, 0,    0,    true),
    (38, 'Rabies vaccine',           1,  'dose',  'QI07AA02', 'injection', 'injection', false, false, 0,    0,    true),
    (39, 'Equine influenza vaccine', 1,  'dose',  'QI05AA01', 'injection', 'injection', false, false, 0,    0,    true),
    (40, 'Clostridial vaccine',      1,  'dose',  'QI02AB01', 'injection', 'injection', false, false, 0,    0,    true)
  ) AS p (n, name, strength, unit, atc, form1, form2, am, ctl, meat, milk, horse),
       generate_series(1, 10) AS v;

-- --- The key functions' rows, computed once ------------------------------------

CREATE TEMP TABLE l_c AS
SELECT n AS id, c.* FROM generate_series(1, 25000) AS n,
       pg_temp.core_consultation(n, :'load_epoch', :customer_utc_offset) AS c;
CREATE TEMP TABLE l_s AS
SELECT n AS id, s.* FROM generate_series(1, 2500) AS n,
       pg_temp.core_stay(n, :'load_epoch', :customer_utc_offset) AS s;
CREATE TEMP TABLE l_r AS
SELECT n AS id, r.* FROM generate_series(1, 17000) AS n,
       pg_temp.core_request(n, :'load_epoch', :customer_utc_offset) AS r;
CREATE TEMP TABLE l_e AS
SELECT n AS id, x.* FROM generate_series(1, 700) AS n,
       pg_temp.core_exchange(n, :'load_epoch', :customer_utc_offset) AS x;
CREATE UNIQUE INDEX ON l_c (id);
ANALYZE l_c, l_s, l_r, l_e;

-- --- Staff (core_staff) -----------------------------------------------------------

INSERT INTO staff (id, name, email, kind, section_id, specialty, started_on)
SELECT n, f || ' ' || l, lower(f) || '.' || lower(l) || '.' || n || '@example.net',
       k.kind, k.section_id, k.specialty,
       (env.s - (200 + floor(4000 * pg_temp.vc_u(n, 301))) * interval '1 day')::date
  FROM l_env AS env, generate_series(1, 85) AS n, pg_temp.core_staff(n) AS k,
       LATERAL (SELECT (ARRAY['Alice', 'Bruno', 'Chloé', 'Daniel', 'Elena', 'Fabien', 'Greta', 'Henrik', 'Inès',
                              'Julien', 'Karin', 'Lars', 'Mira', 'Nils', 'Oriane', 'Pieter', 'Rania', 'Stefan',
                              'Theo', 'Ursula'])[1 + floor(20 * pg_temp.vc_u(n, 302))::integer] AS f,
                       (ARRAY['Aubert', 'Brandt', 'Claes', 'Delvaux', 'Engel', 'Faure', 'Gerritsen', 'Hoffmann',
                              'Jacobs', 'Kramer', 'Lemaire', 'Maes', 'Nowak', 'Petit', 'Roth', 'Simon', 'Tanguy',
                              'Vermeulen', 'Wagner', 'Wouters'])[1 + floor(20 * pg_temp.vc_u(n, 303))::integer] AS l) AS nm;

-- --- Owners (core_owner), herds (core_holding) ------------------------------------

-- The address is the load's alone: no part, and no function, gives it.
INSERT INTO owners (id, kind, name, email, phone, address, country, registered_at)
SELECT n, o.kind, o.name, o.email, o.phone,
       CASE WHEN n = 1 THEN '1 Hospital Road, Aldermoor'
            ELSE (1 + floor(180 * pg_temp.vc_u(n, 311)))::integer || ' '
                 || (ARRAY['Church Street', 'Mill Lane', 'Station Road', 'High Street', 'Orchard Way', 'Brook Lane',
                           'Market Place', 'Farm Road', 'Chapel Row', 'Meadow Close', 'Green Lane',
                           'Bridge Street'])[1 + floor(12 * pg_temp.vc_u(n, 312))::integer] || ', '
                 || (ARRAY['Aldermoor', 'Brackley', 'Coldwater', 'Dunmere', 'Eastholm', 'Fernhill', 'Greyford',
                           'Hollins', 'Kirkby Vale', 'Lowmoor'])[1 + floor(10 * pg_temp.vc_u(n, 313))::integer] END,
       'XA', o.registered_at
  FROM generate_series(1, 10000) AS n, pg_temp.core_owner(n, :'load_epoch', :customer_utc_offset) AS o;

INSERT INTO herds (id, keeper_owner_id, holding_number, site_id)
SELECT h, h + 1, pg_temp.core_holding(h), 1 FROM generate_series(1, 200) AS h;

-- --- Animals (core_animal, the identifiers, core_death) ---------------------------

-- The dozen mistyped chips (T13, D278): twelve dogs and cats of the
-- pre-history, ids 13 + 607 k, their stored chip with two adjacent digits of
-- its twelve swapped (the first differing pair from the (4 + k mod 7)-th
-- digit); the parts hold the function's value.
CREATE TEMP TABLE l_swap AS
SELECT n AS sn, (row_number() OVER (ORDER BY n) - 1)::integer AS k
  FROM generate_series(13, 9737, 607) AS n
 WHERE pg_temp.core_species(n) IN ('dog', 'cat') AND pg_temp.core_microchip(n) IS NOT NULL
 ORDER BY n LIMIT 12;

INSERT INTO animals (id, species, breed, sex, born_on, name, food_chain, food_chain_excluded_on,
                     food_chain_excluded_by, herd_id, microchip, ueln, passport_number, ear_tag,
                     registered_at, status, died_at, death_kind)
SELECT n, a.species, a.breed, a.sex, a.born_on, a.name, a.food_chain, a.food_chain_excluded_on,
       a.food_chain_excluded_by, a.herd_id,
       CASE WHEN w.sn IS NULL THEN chip
            ELSE '941' || substr(t, 1, p - 1) || substr(t, p + 1, 1) || substr(t, p, 1) || substr(t, p + 2) END,
       pg_temp.core_ueln(n), pg_temp.core_passport(n), pg_temp.core_ear_tag(n), a.registered_at,
       CASE WHEN d.died_at IS NULL THEN 'alive' ELSE 'died' END, d.died_at, d.how
  FROM generate_series(1, 17000) AS n
       CROSS JOIN LATERAL pg_temp.core_animal(n, :'load_epoch', :customer_utc_offset) AS a
       LEFT JOIN LATERAL pg_temp.core_death(n, :'load_epoch', :customer_utc_offset) AS d ON true
       LEFT JOIN l_swap AS w ON w.sn = n
       CROSS JOIN LATERAL (SELECT pg_temp.core_microchip(n) AS chip, substr(pg_temp.core_microchip(n), 4) AS t) AS c
       CROSS JOIN LATERAL (SELECT coalesce((SELECT min(q) FROM generate_series(4 + coalesce(w.k, 0) % 7, 11) AS q
                                             WHERE substr(c.t, q, 1) <> substr(c.t, q + 1, 1)), 1) AS p) AS sw;

INSERT INTO ownerships (animal_id, owner_id, role, from_at, until_at)
SELECT n, o.owner_id, o.role, o.from_at, o.until_at
  FROM generate_series(1, 17000) AS n, pg_temp.core_ownership(n, :'load_epoch', :customer_utc_offset) AS o;

-- --- Referring practices and vets (core_referring_practice) -----------------------

INSERT INTO referring_practices (id, name, address, country, email)
SELECT p, pl || ' Veterinary ' || (ARRAY['Practice', 'Surgery', 'Clinic', 'Centre'])[1 + p % 4],
       (1 + p % 90) || ' ' || (ARRAY['Market Street', 'Park Road', 'Kingsway', 'Mill Road'])[1 + p % 4] || ', ' || pl,
       'XA', 'reception.' || p || '@example.net'
  FROM generate_series(1, 400) AS p,
       LATERAL (SELECT (ARRAY['Aldermoor', 'Brackley', 'Coldwater', 'Dunmere', 'Eastholm', 'Fernhill', 'Greyford',
                              'Hollins', 'Kirkby Vale', 'Lowmoor', 'Marston', 'Northwick', 'Oakham', 'Penmere',
                              'Ravensby', 'Stowe', 'Thornbury', 'Upwell', 'Westerley', 'Yarrow'])
                       [1 + floor(20 * pg_temp.vc_u(p, 321))::integer] AS pl) AS x;

INSERT INTO referring_vets (id, practice_id, name, email)
SELECT v, pg_temp.core_referring_practice(v), f || ' ' || l,
       lower(f) || '.' || lower(l) || '.' || v || '@example.net'
  FROM generate_series(1, 800) AS v,
       LATERAL (SELECT (ARRAY['Ada', 'Bram', 'Cecile', 'Dirk', 'Eva', 'Frans', 'Gaby', 'Hanna', 'Ivo',
                              'Jana'])[1 + floor(10 * pg_temp.vc_u(v, 322))::integer] AS f,
                       (ARRAY['Arnaud', 'Bos', 'Collin', 'Dekker', 'Evrard', 'Fontaine', 'Gilles', 'Hendriks',
                              'Joosten', 'Leclerc'])[1 + floor(10 * pg_temp.vc_u(v, 323))::integer] AS l) AS x;

-- --- Stays (core_stay), their admitting vet --------------------------------------

INSERT INTO stays (id, animal_id, site_id, section_id, admitting_vet_id, reason, admitted_at, discharged_at,
                   outcome, transferred_to_site_id)
SELECT s.id, s.animal_id, 1, s.section_id,
       pg_temp.vc_vet_at(s.section_id, pg_temp.vc_local(s.admitted_at, env.o), env.o, 3000000 + s.id),
       CASE s.section_id
         WHEN 1 THEN (ARRAY['colic, for monitoring', 'colic surgery', 'lameness work-up', 'wound management',
                            'foaling', 'respiratory disease'])[1 + floor(6 * pg_temp.vc_u(s.id, 331))::integer]
         WHEN 2 THEN (ARRAY['dystocia', 'displaced abomasum', 'pneumonia', 'neonatal care',
                            'lameness'])[1 + floor(5 * pg_temp.vc_u(s.id, 331))::integer]
         ELSE (ARRAY['post-operative care', 'gastroenteritis', 'trauma', 'renal failure', 'diabetes stabilisation',
                     'foreign body surgery', 'observation'])[1 + floor(7 * pg_temp.vc_u(s.id, 331))::integer] END,
       s.admitted_at, s.discharged_at, s.outcome, s.transferred_to_site_id
  FROM l_s AS s, l_env AS env;

-- --- Referrals (core_consultation's referral_id), consultations --------------------

-- A referral's id is its consultation's: received days before a scheduled
-- one (minutes before an emergency), accepted before it, closed by the
-- vet's letter one to three days after the consultation is signed.
INSERT INTO referrals (id, animal_id, referring_vet_id, site_id, received_at, reason, state, decided_at,
                       report_sent_at)
SELECT c.id, c.animal_id, 1 + floor(800 * pg_temp.vc_u(c.id, 341))::integer, 1, r.rec,
       (ARRAY['second opinion', 'surgery', 'imaging work-up', 'internal medicine work-up', 'oncology',
              'lameness investigation', 'cardiology', 'critical care'])[1 + floor(8 * pg_temp.vc_u(c.id, 342))::integer],
       CASE WHEN r.rep < env.e THEN 'closed' ELSE 'accepted' END,
       least(r.rec + (5 + 600 * pg_temp.vc_u(c.id, 344)) * interval '1 minute', c.started_at - interval '1 minute'),
       CASE WHEN r.rep < env.e THEN r.rep END
  FROM l_c AS c, l_env AS env,
       LATERAL (SELECT CASE WHEN c.kind = 'emergency'
                            THEN c.started_at - (15 + 45 * pg_temp.vc_u(c.id, 343)) * interval '1 minute'
                            ELSE c.started_at - (3 + 25 * pg_temp.vc_u(c.id, 343)) * interval '1 day' END AS rec,
                       CASE WHEN c.signed_at IS NOT NULL
                            THEN pg_temp.vc_utc(date_trunc('day', pg_temp.vc_local(c.signed_at, env.o))
                                                + (1 + floor(3 * pg_temp.vc_u(c.id, 345))) * interval '1 day'
                                                + interval '10 hours' + 6 * pg_temp.vc_u(c.id, 346) * interval '1 hour',
                                                env.o) END AS rep) AS r
 WHERE c.referral_id IS NOT NULL;

INSERT INTO consultations (id, animal_id, herd_id, site_id, section_id, vet_id, kind, referral_id, stay_id,
                           booking_id, started_at, ended_at, findings, state, signed_at)
SELECT c.id, c.animal_id, c.herd_id, 1, c.section_id, c.vet_id, c.kind, c.referral_id, c.stay_id, c.booking_id,
       c.started_at, c.closed_at,
       CASE WHEN c.closed_at IS NOT NULL THEN
            (ARRAY['Bright and alert; examination unremarkable apart from the presenting complaint.',
                   'Mild dehydration; vital signs within normal limits.', 'Pain on palpation; further work-up advised.',
                   'Improving since the last examination.', 'Stable; treatment continued.',
                   'Findings discussed with the keeper; recheck advised.', 'Herd health plan reviewed.',
                   'Lame on the affected limb; nerve blocks planned.'])[1 + floor(8 * pg_temp.vc_u(c.id, 351))::integer] END,
       CASE WHEN c.signed_at IS NOT NULL THEN 'signed' WHEN c.closed_at IS NOT NULL THEN 'closed' ELSE 'open' END,
       c.signed_at
  FROM l_c AS c;

-- --- Diagnoses, procedures --------------------------------------------------------

-- One diagnosis a closed consultation, a second one in five (1.2), from the
-- section's codes and the "any" codes; a listed disease one in 250, never a
-- category A one (an outbreak is a story's).
CREATE TEMP TABLE l_dx AS
SELECT g.sec, d.notifiable <> 'none' AS listed, array_agg(d.code ORDER BY d.code) AS codes
  FROM (VALUES (1, 'horse'), (2, 'farm'), (3, 'domestic')) AS g (sec, grp), diagnosis_codes AS d
 WHERE d.species_group IN (g.grp, 'any') AND d.notifiable <> 'A'
 GROUP BY 1, 2;

INSERT INTO diagnoses (consultation_id, code, confirmed, recorded_at)
SELECT c.id, x.codes[1 + floor(cardinality(x.codes) * pg_temp.vc_u(c.id * 4 + k, 362))::integer],
       pg_temp.vc_u(c.id * 4 + k, 363) < 0.85, c.closed_at
  FROM l_c AS c, generate_series(0, 1) AS k, l_dx AS x
 WHERE c.closed_at IS NOT NULL AND (k = 0 OR pg_temp.vc_u(c.id, 361) < 0.2)
   AND x.sec = c.section_id AND x.listed = (pg_temp.vc_u(c.id * 4 + k, 364) < 0.004)
 ORDER BY c.id, k;

-- A procedure in about three in ten closed consultations, led by its vet.
INSERT INTO procedures (consultation_id, stay_id, code, lead_staff_id, anaesthesia, performed_at)
SELECT c.id, c.stay_id, p.code, c.vet_id, p.anaesthesia, c.started_at + interval '10 minutes'
  FROM l_c AS c,
       LATERAL (SELECT code, anaesthesia FROM (VALUES
                  (1, 'P-HOOF', false), (1, 'P-COLIC', true), (1, 'P-ARTH', true), (1, 'P-DENT-E', false),
                  (1, 'P-NERVE', false), (1, 'P-WOUND', false),
                  (2, 'P-CSEC', false), (2, 'P-DISP', false), (2, 'P-CLAW', false), (2, 'P-DEHORN', false),
                  (2, 'P-WOUND', false),
                  (3, 'P-DENT', true), (3, 'P-CAST', true), (3, 'P-WOUND', true), (3, 'P-ORTH', true),
                  (3, 'P-ENDO', true), (3, 'P-BIOP', false), (3, 'P-FLUID', false)) AS v (sec, code, anaesthesia)
                 WHERE v.sec = c.section_id
                 ORDER BY pg_temp.vc_u(c.id * 32 + ascii(substr(code, 3, 1)) + length(code), 372), code LIMIT 1) AS p
 WHERE c.closed_at IS NOT NULL AND pg_temp.vc_u(c.id, 371) < 0.28
 ORDER BY c.id;

-- --- Requests (core_request) --------------------------------------------------------

INSERT INTO requests (id, consultation_id, animal_id, kind, code, requested_by, priority, requested_at, state,
                      sent_at, resulted_at, cancelled_at)
SELECT id, consultation_id, animal_id, kind, code, requested_by, priority, requested_at, state, sent_at,
       resulted_at, cancelled_at
  FROM l_r;

-- --- Alerts (core_stay_alert, and the others) -------------------------------------

INSERT INTO alerts (animal_id, kind, text, from_at, until_at)
SELECT animal_id, kind, text, from_at, until_at FROM (
  SELECT s.animal_id, 'infectious' AS kind,
         (ARRAY['isolation: suspected salmonellosis', 'isolation: strangles suspected', 'barrier nursing: MRSP',
                'isolation: parvovirus suspected', 'barrier nursing: diarrhoea of unknown cause'])
           [1 + floor(5 * pg_temp.vc_u(s.id, 381))::integer] AS text, a.from_at, a.until_at
    FROM l_s AS s, pg_temp.core_stay_alert(s.id, :'load_epoch', :customer_utc_offset) AS a
  UNION ALL
  SELECT n, k.kind,
         CASE k.kind WHEN 'allergy' THEN (ARRAY['penicillin allergy', 'NSAID intolerance', 'reaction to vaccine',
                                                'chlorhexidine sensitivity'])[1 + floor(4 * pg_temp.vc_u(n, 384))::integer]
                     WHEN 'dangerous' THEN (ARRAY['bites when handled', 'kicks: approach from the shoulder',
                                                  'muzzle for examination'])[1 + floor(3 * pg_temp.vc_u(n, 384))::integer]
                     ELSE (ARRAY['blind', 'deaf', 'needle-shy', 'on long-term medication'])
                            [1 + floor(4 * pg_temp.vc_u(n, 384))::integer] END,
         least(an.registered_at + (1 + 300 * pg_temp.vc_u(n, 385)) * interval '1 day', env.e - interval '1 day'),
         NULL::timestamptz
    FROM l_env AS env, animals AS an, generate_series(13, 17000) AS n,
         LATERAL (SELECT CASE WHEN pg_temp.vc_u(n, 383) < 0.5 THEN 'allergy'
                              WHEN pg_temp.vc_u(n, 383) < 0.8 THEN 'dangerous' ELSE 'other' END AS kind) AS k
   WHERE an.id = n AND pg_temp.vc_u(n, 382) < 0.085 AND NOT n BETWEEN 14601 AND 14608
) AS x
 ORDER BY from_at, animal_id;

-- --- Exchanges (core_exchange) -------------------------------------------------------

INSERT INTO exchanges (id, direction, kind, partner_site_id, animal_id, partner_patient, stay_id, reason,
                       exchange_key, requested_at, sent_at, state, accepted_for, answered_at, report,
                       reported_at)
SELECT e.id, e.direction, e.kind, e.site_id, e.animal_id,
       CASE WHEN e.direction = 'in' THEN
            'partner record ' || si.code || '/' || (100000 + e.id) || ': '
            || e.partner_species || ', '
            || (1 + floor(14 * pg_temp.vc_u(e.id, 392)))::integer || ' years' END,
       e.stay_id, e.reason,
       e.exchange_key, e.requested_at, e.sent_at, e.state, e.accepted_for, e.answered_at,
       CASE WHEN e.reported_at IS NOT NULL THEN 'Examination performed; report attached.' END, e.reported_at
  FROM l_e AS e JOIN sites AS si ON si.id = e.site_id
 WHERE e.animal_id IS NOT NULL OR e.direction = 'in';

-- --- Medicine batches ---------------------------------------------------------------

-- One or two batches a medicine (about 700), received before the history,
-- each expiring after T0.
INSERT INTO medicine_batches (medicine_id, batch_number, site_id, expires_on, quantity_received)
SELECT m, 'B' || lpad((m * 37 + b * 7919)::text, 6, '0'), 1,
       (env.e + (120 + floor(800 * pg_temp.vc_u(m * 2 + b, 402))) * interval '1 day')::date,
       50 + 10 * floor(45 * pg_temp.vc_u(m * 2 + b, 403))
  FROM l_env AS env, generate_series(1, 400) AS m, generate_series(1, 2) AS b
 WHERE b = 1 OR pg_temp.vc_u(m, 401) < 0.75
 ORDER BY m, b;

-- --- Prescriptions and their lines -----------------------------------------------------

-- The milk inhibitor tests' checked lines (D389): each MINH request's herd
-- visit, the herd's latest early enough (its local day ten days before the
-- request's withdrawal_ends_on: three days' oxytetracycline, seven days'
-- milk withdrawal).
CREATE TEMP TABLE l_minh AS
SELECT r.id AS request_id, r.withdrawal_ends_on,
       (SELECT max(c.id) FROM l_c AS c
         WHERE c.kind = 'herd-visit' AND c.herd_id = 1 + (r.animal_id - 16001) % 200 AND c.closed_at IS NOT NULL
           AND pg_temp.vc_local(c.closed_at, env.o)::date = r.withdrawal_ends_on - 10) AS consultation_id
  FROM l_r AS r, l_env AS env WHERE r.code = 'MINH';

-- A prescription in about six in ten closed consultations: every ward round
-- (in-hospital), 53 % of the others, and the MINH lines' herd visits; issued
-- at the close, ids in issue order. A herd visit's is the herd's.
CREATE TEMP TABLE l_p AS
SELECT row_number() OVER (ORDER BY c.closed_at, c.id)::integer AS id, c.id AS consultation_id, c.animal_id,
       c.herd_id, c.vet_id, c.closed_at AS issued_at, c.kind, c.section_id, c.stay_id
  FROM l_c AS c
 WHERE c.closed_at IS NOT NULL
   AND (c.kind = 'in-hospital' OR pg_temp.vc_u(c.id, 411) < 0.53
        OR c.id IN (SELECT consultation_id FROM l_minh));

-- Products a section may use: a farm animal or a food-chain horse only those
-- with a meat withdrawal period (and, for a horse, allowed in the food chain);
-- the farm-only products never for pets, the equine vaccine for horses only.
CREATE TEMP TABLE l_prod AS
SELECT g.sec, g.food, array_agg(p ORDER BY p) AS products
  FROM (VALUES (1, false), (1, true), (2, true), (3, false)) AS g (sec, food), generate_series(1, 40) AS p,
       LATERAL (SELECT * FROM medicines WHERE id = 10 * (p - 1) + 1) AS m
 WHERE CASE WHEN g.food THEN m.meat_withdrawal_days IS NOT NULL AND (g.sec = 2 OR m.food_chain_horse_allowed)
            ELSE true END
   AND NOT (g.sec = 3 AND p IN (10, 11, 37, 39, 40)) AND NOT (g.sec = 1 AND p IN (10, 11, 37, 38, 40))
   AND NOT (g.sec = 2 AND p IN (38, 39))
 GROUP BY 1, 2;

-- Lines: 2 to 4 on a ward round, 1 to 4 otherwise (2.5 on average). A ward
-- round's lines every 4, 12 or 24 hours for 1 to 5 days, on the rounds; an
-- outpatient's every 8, 12 or 24 hours for 3 to 10 days. Withdrawal periods
-- recorded for a food-producing animal (rule 6): meat, and milk for a farm
-- female, the end the later of the two; none for the others.
CREATE TEMP TABLE l_l AS
SELECT p.id AS prescription_id, j, p.consultation_id, p.kind, p.section_id, p.stay_id, p.issued_at,
       coalesce(p.animal_id, NULL) AS animal_id, p.herd_id,
       10 * (pr.products[1 + floor(cardinality(pr.products) * pg_temp.vc_u(p.id * 8 + j, 422))::integer] - 1)
         + 1 + floor(10 * pg_temp.vc_u(p.id * 8 + j, 423))::integer AS medicine_id,
       CASE WHEN p.kind = 'in-hospital' THEN (ARRAY[4, 4, 12, 12, 24])[1 + floor(5 * pg_temp.vc_u(p.id * 8 + j, 424))::integer]
            ELSE (ARRAY[8, 12, 24])[1 + floor(3 * pg_temp.vc_u(p.id * 8 + j, 424))::integer] END AS freq,
       CASE WHEN p.kind = 'in-hospital' THEN 1 + floor(5 * pg_temp.vc_u(p.id * 8 + j, 425))::integer
            ELSE 3 + floor(8 * pg_temp.vc_u(p.id * 8 + j, 425))::integer END AS days,
       f.food, f.milk
  FROM l_p AS p
       LEFT JOIN animals AS a ON a.id = p.animal_id
       CROSS JOIN LATERAL (SELECT p.section_id = 2
                                  OR (a.species = 'horse' AND (a.food_chain = 'food-producing'
                                      OR a.food_chain_excluded_on > p.issued_at::date)) AS food,
                                  p.section_id = 2 AND (coalesce(a.sex, 'female') = 'female') AS milk) AS f
       JOIN l_prod AS pr ON pr.sec = p.section_id AND pr.food = f.food
       CROSS JOIN LATERAL generate_series(0, CASE WHEN p.kind = 'in-hospital' THEN 1 + floor(3 * pg_temp.vc_u(p.id, 421))::integer
                                                  ELSE floor(4 * pg_temp.vc_u(p.id, 421))::integer END) AS j;

INSERT INTO prescriptions (id, consultation_id, animal_id, herd_id, vet_id, issued_at, valid_until, state)
SELECT p.id, p.consultation_id, p.animal_id, p.herd_id, p.vet_id, p.issued_at, v.valid_until,
       CASE WHEN pg_temp.vc_u(p.id, 431) < 0.015 AND p.kind <> 'in-hospital'
                 AND p.consultation_id NOT IN (SELECT consultation_id FROM l_minh WHERE consultation_id IS NOT NULL)
                 THEN 'cancelled'
            WHEN p.kind = 'in-hospital' OR (pg_temp.vc_u(p.id, 432) < 0.9 AND p.issued_at + interval '30 minutes' < env.e)
                 THEN 'dispensed'
            WHEN v.valid_until < env.last_expire  -- as prescriptions.expire: past five days, or the lines' days
                 OR (v.valid_until - p.issued_at > interval '5 days'
                     AND p.issued_at + (SELECT max(l.days) FROM l_l AS l WHERE l.prescription_id = p.id)
                                       * interval '1 day' < env.last_expire) THEN 'expired'
            ELSE 'issued' END
  FROM l_p AS p,
       (SELECT e, pg_temp.vc_utc(date_trunc('day', pg_temp.vc_local(e, o) - interval '15 minutes')
                                 + interval '15 minutes', o) AS last_expire FROM l_env) AS env,
       LATERAL (SELECT p.issued_at + CASE WHEN EXISTS (SELECT 1 FROM l_l AS l JOIN medicines AS m ON m.id = l.medicine_id
                                                        WHERE l.prescription_id = p.id AND m.antimicrobial)
                                          THEN interval '5 days' ELSE interval '30 days' END AS valid_until) AS v;

INSERT INTO prescription_lines (prescription_id, medicine_id, dose, unit, frequency_hours, days, cascade,
                                meat_withdrawal_days, milk_withdrawal_days, withdrawal_ends_on)
SELECT prescription_id, medicine_id, dose, unit, freq, days, false, meat_d, milk_d,
       CASE WHEN food THEN pg_temp.vc_local(issued_at, env.o)::date + days + greatest(meat_d, coalesce(milk_d, 0)) END
  FROM (SELECT l.*, (1 + floor(8 * pg_temp.vc_u(l.prescription_id * 8 + l.j, 426))) / 2.0 AS dose,
               split_part(m.name, ' ', -1) AS unit,
               CASE WHEN l.food THEN m.meat_withdrawal_days END AS meat_d,
               CASE WHEN l.food AND l.milk THEN m.milk_withdrawal_days END AS milk_d, 0 AS ord
          FROM l_l AS l JOIN medicines AS m ON m.id = l.medicine_id
        UNION ALL  -- the MINH lines: oxytetracycline 100 mg (medicine 31), three days, milk seven
        SELECT p.id, 9, p.consultation_id, p.kind, p.section_id, p.stay_id, p.issued_at, NULL, p.herd_id, 31, 24, 3,
               true, true, 10, 'mg', 21, 7, 1
          FROM (SELECT DISTINCT consultation_id FROM l_minh WHERE consultation_id IS NOT NULL) AS x
          JOIN l_p AS p ON p.consultation_id = x.consultation_id) AS q, l_env AS env
 ORDER BY prescription_id, ord, j;

-- --- Administrations (the ward rounds' lines), dispensings (the others') ----------------

-- A ward round's line given at the rounds (02:00, 06:00 ... 22:00 local)
-- from the first after its issue, every freq hours, while the stay lasts
-- and the line runs; given 5 to 30 minutes after the round by a nurse of the
-- stay's section (D391), one in a hundred missed; the next round after T0
-- planned (scheduled). Ids in schedule order, within 1-70 000.
CREATE TEMP TABLE l_ad AS
SELECT row_number() OVER (ORDER BY t.at, pl.id)::integer AS id, a.animal_id, p.stay_id, pl.id AS line_id,
       pl.medicine_id, pl.dose, t.at, p.section_id
  FROM prescription_lines AS pl JOIN prescriptions AS pr ON pr.id = pl.prescription_id
  JOIN l_p AS p ON p.id = pl.prescription_id
  JOIN stays AS a ON a.id = p.stay_id
  CROSS JOIN l_env AS env
  CROSS JOIN LATERAL (SELECT pg_temp.vc_utc(date_trunc('day', pg_temp.vc_local(p.issued_at, env.o))
                                            + interval '2 hours'
                                            + 4 * ceil(extract(epoch FROM pg_temp.vc_local(p.issued_at, env.o)
                                                               - date_trunc('day', pg_temp.vc_local(p.issued_at, env.o))
                                                               - interval '2 hours') / 14400) * interval '1 hour',
                                            env.o) AS first) AS f
  CROSS JOIN LATERAL (SELECT f.first + g * pl.frequency_hours * interval '1 hour' AS at
                        FROM generate_series(0, pl.days * 24 / pl.frequency_hours - 1) AS g) AS t
 WHERE p.kind = 'in-hospital'
   AND t.at < coalesce(a.discharged_at, 'infinity')
   AND t.at <= pg_temp.vc_utc(date_trunc('day', pg_temp.vc_local(env.e, env.o)) + interval '2 hours'
                              + 4 * ceil(extract(epoch FROM pg_temp.vc_local(env.e, env.o)
                                                 - date_trunc('day', pg_temp.vc_local(env.e, env.o))
                                                 - interval '2 hours') / 14400) * interval '1 hour', env.o);

INSERT INTO administrations (id, animal_id, stay_id, prescription_line_id, medicine_id, batch_id, quantity,
                             scheduled_at, given_at, given_by, state)
SELECT d.id, d.animal_id, d.stay_id, d.line_id, d.medicine_id,
       (SELECT min(b.id) FROM medicine_batches AS b WHERE b.medicine_id = d.medicine_id),
       d.dose, d.at,
       CASE WHEN d.at < env.e AND pg_temp.vc_u(d.id, 441) >= 0.01
            THEN least(d.at + (5 + 25 * pg_temp.vc_u(d.id, 442)) * interval '1 minute', env.e - interval '1 minute') END,
       CASE WHEN d.at < env.e AND pg_temp.vc_u(d.id, 441) >= 0.01
            THEN (CASE d.section_id WHEN 1 THEN ARRAY[29, 30, 31, 32, 33, 34, 35, 36]
                                    WHEN 2 THEN ARRAY[37, 38, 39, 40, 41, 42]
                                    ELSE ARRAY[43, 44, 45, 46, 47, 48, 49, 50, 51] END)
                 [1 + floor(CASE d.section_id WHEN 1 THEN 8 WHEN 2 THEN 6 ELSE 9 END * pg_temp.vc_u(d.id, 443))::integer] END,
       CASE WHEN d.at >= env.e THEN 'scheduled' WHEN pg_temp.vc_u(d.id, 441) < 0.01 THEN 'missed' ELSE 'given' END
  FROM l_ad AS d, l_env AS env;

-- An outpatient's dispensed prescription: each line dispensed to the owner
-- at the time (a herd's keeper), 5 to 25 minutes after the close, by a
-- nurse of the section.
INSERT INTO dispensings (prescription_line_id, batch_id, quantity, owner_id, dispensed_by, dispensed_at)
SELECT pl.id,
       (SELECT b.id FROM medicine_batches AS b WHERE b.medicine_id = pl.medicine_id
         ORDER BY pg_temp.vc_u(pl.id * 2 + b.id, 451) LIMIT 1),
       least(9999, pl.dose * pl.days * 24 / pl.frequency_hours),
       coalesce((SELECT o.owner_id FROM ownerships AS o
                  WHERE o.animal_id = pr.animal_id AND o.role = 'owner' AND o.from_at <= pr.issued_at
                    AND coalesce(o.until_at, 'infinity') > pr.issued_at
                  ORDER BY o.from_at DESC LIMIT 1),
                pr.herd_id + 1,
                (SELECT o.owner_id FROM ownerships AS o WHERE o.animal_id = pr.animal_id AND o.role = 'owner'
                  ORDER BY o.from_at LIMIT 1)),
       (CASE c.section_id WHEN 1 THEN ARRAY[29, 30, 31, 32, 33, 34, 35, 36] WHEN 2 THEN ARRAY[37, 38, 39, 40, 41, 42]
                          ELSE ARRAY[43, 44, 45, 46, 47, 48, 49, 50, 51] END)
         [1 + floor(CASE c.section_id WHEN 1 THEN 8 WHEN 2 THEN 6 ELSE 9 END * pg_temp.vc_u(pl.id, 452))::integer],
       pr.issued_at + (5 + 20 * pg_temp.vc_u(pl.id, 453)) * interval '1 minute'
  FROM prescription_lines AS pl JOIN prescriptions AS pr ON pr.id = pl.prescription_id
  JOIN consultations AS c ON c.id = pr.consultation_id
 WHERE pr.state = 'dispensed' AND c.kind <> 'in-hospital'
 ORDER BY pr.issued_at, pl.id;

-- --- Checks: the ranges hold, the MINH lines match ------------------------------------

DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(x, '; ') INTO bad FROM (
        SELECT 'prescriptions ' || max(id) AS x FROM prescriptions HAVING max(id) > 15000
        UNION ALL SELECT 'administrations ' || max(id) FROM administrations HAVING max(id) > 70000
        UNION ALL SELECT 'MINH request ' || m.request_id || ' has no checked line'
          FROM l_minh AS m
         WHERE NOT EXISTS (SELECT 1 FROM prescriptions AS p JOIN prescription_lines AS l ON l.prescription_id = p.id
                                     JOIN business_settings AS b ON true
                            WHERE p.consultation_id = m.consultation_id AND l.medicine_id = 31
                              AND (p.issued_at AT TIME ZONE b.timezone)::date + l.days + l.milk_withdrawal_days
                                  = m.withdrawal_ends_on)
    ) AS y;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'load.sql: a range or a MINH line does not hold: %', bad;
    END IF;
END $$;

-- --- Sequences: each resumes after its range (D276) -----------------------------------

SELECT setval(pg_get_serial_sequence(t, 'id'), v)
  FROM (VALUES ('sites', 6), ('sections', 3), ('staff', 85), ('owners', 10000), ('herds', 200),
               ('animals', 17000), ('referring_practices', 400), ('referring_vets', 800), ('medicines', 400),
               ('consultations', 25000), ('referrals', 25000), ('requests', 17000), ('stays', 2500),
               ('exchanges', 700), ('prescriptions', 15000), ('administrations', 70000)) AS r (t, v);
SELECT setval(pg_get_serial_sequence(t, 'id'), (xpath('/row/m/text()',
              query_to_xml(format('SELECT max(id) AS m FROM %I', t), false, true, '')))[1]::text::bigint)
  FROM unnest(ARRAY['diagnoses', 'procedures', 'alerts', 'medicine_batches', 'prescription_lines',
                    'dispensings']) AS t;

VACUUM (ANALYZE) business_settings, sites, sections, staff, owners, herds, animals, ownerships,
                 referring_practices, referring_vets, referrals, stays, consultations, diagnosis_codes,
                 diagnoses, procedures, requests, alerts, exchanges, medicines, medicine_batches,
                 prescriptions, prescription_lines, administrations, dispensings;
