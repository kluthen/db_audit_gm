-- vet-lab's key functions (v0.5 master spec 9.3; vet-lab-domain.md,
-- "Deterministic key ranges", "The test catalogue (D372)", "The history before
-- T0"; capture W3 items 0 and 1). docs/gm.md, "Part keys", documents each; this
-- file is the formula.
--
-- gmctl load-data streams this file after vet-core's data/keys.sql, ahead of
-- this part's load.sql and its partners' data.sql (producers/partners/xlab,
-- producers/partners/practices), in their session (W3 item 0, chunk 29's (a)):
-- every function lives in pg_temp and vanishes with the session.
--
-- The contract (W3 item 1): pg_temp.lab_order(n, load_epoch, utc_offset),
-- orders 1-14 000 in time order, and pg_temp.lab_send_out(n, load_epoch,
-- utc_offset), send-outs in packing order, each a lookup over
-- pg_temp.lab_order_tests(load_epoch, utc_offset), one row per order test with
-- its order's, its sample's and its send-out's columns; pg_temp.lab_catalogue(),
-- the 180 tests; pg_temp.lab_delivery(...), a practice delivery's key and
-- times. The centre's orders are the core's analysis requests that reached the
-- lab (sent), one order a consultation, so every id hangs on the core's whole
-- history: lab_order_tests computes it in one pass (core_request over its 17 000
-- ids, about 45 s), and a file calls it once, never lab_order per id.
-- pg_temp.lab_u and the calendar helpers below are its shared formulas: a part
-- calls only the core's eighteen pg_temp.core_* functions (vet-core docs/gm.md,
-- "Core keys"), never its pg_temp.vc_*.
--
-- Signatures as the core's (D379): IMMUTABLE, the run's load_epoch and
-- customer_utc_offset passed by the caller, never now(); times UTC; every draw
-- a hash of an id (lab_u), never random().

-- --- Shared formulas ---------------------------------------------------------------

-- A uniform draw in [0, 1) from x and a salt (salts 1-99, offset from the core's).
CREATE FUNCTION pg_temp.lab_u(x bigint, salt integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, 7100 + salt) & 2147483647)::float8 / 2147483648 $$;

-- A UTC instant as the customer's local time, and back.
CREATE FUNCTION pg_temp.lab_local(t timestamptz, utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t AT TIME ZONE 'UTC') + utc_offset * interval '1 hour' $$;
CREATE FUNCTION pg_temp.lab_utc(t timestamp, utc_offset integer) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - utc_offset * interval '1 hour') AT TIME ZONE 'UTC' $$;

-- The history's start, as the core's: local Monday 00:00, 52 weeks before
-- load_epoch's week (53 weeks, cut at load_epoch).
CREATE FUNCTION pg_temp.lab_start(load_epoch timestamptz, utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT date_trunc('week', pg_temp.lab_local(load_epoch, utc_offset)) - interval '364 days' $$;

-- The pathologist's next round at or after local time t: 11:00, 14:00 and
-- 18:00 Monday to Saturday, 11:00 on Sunday (vet-lab-domain.md, "Cadences").
CREATE FUNCTION pg_temp.lab_next_round(t timestamp) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT min(c) FROM (SELECT d + h * interval '1 hour' AS c
                      FROM generate_series(date_trunc('day', t), date_trunc('day', t) + interval '2 days',
                                           interval '1 day') AS d, unnest(ARRAY[11, 14, 18]) AS h
                     WHERE extract(isodow FROM d) < 7 OR h = 11) AS x
 WHERE c >= t
$$;

-- The send-outs' packing at or after local time t: 16:00, Monday to Friday.
CREATE FUNCTION pg_temp.lab_next_pack(t timestamp) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT min(d + interval '16 hours')
  FROM generate_series(date_trunc('day', t), date_trunc('day', t) + interval '4 days', interval '1 day') AS d
 WHERE extract(isodow FROM d) <= 5 AND d + interval '16 hours' >= t
$$;

-- The bench's next opening after local time t: 07:00, Monday to Saturday.
CREATE FUNCTION pg_temp.lab_next_bench(t timestamp) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT min(d + interval '7 hours')
  FROM generate_series(date_trunc('day', t), date_trunc('day', t) + interval '2 days', interval '1 day') AS d
 WHERE extract(isodow FROM d) <= 6 AND d + interval '7 hours' > t
$$;

-- The courier's wave carrying a practice's sample posted at local time t:
-- posted by 09:30 on a working day (Monday to Saturday), the 10:45 wave;
-- by 15:30, the 16:45 one; else the next working day's morning.
CREATE FUNCTION pg_temp.lab_courier(t timestamp) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT min(d + w.arrive)
  FROM generate_series(date_trunc('day', t), date_trunc('day', t) + interval '3 days', interval '1 day') AS d,
       (VALUES (interval '9 hours 30 minutes', interval '10 hours 45 minutes'),
               (interval '15 hours 30 minutes', interval '16 hours 45 minutes')) AS w (cutoff, arrive)
 WHERE extract(isodow FROM d) <= 6 AND d + w.cutoff > t
$$;

-- The external lab's hours (Monday to Saturday 08:00-20:00): t when open, else
-- its next opening.
CREATE FUNCTION pg_temp.lab_xlab_open(t timestamp) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN extract(isodow FROM t) <= 6 AND extract(hour FROM t) BETWEEN 8 AND 19 THEN t
            ELSE (SELECT min(d + interval '8 hours')
                    FROM generate_series(date_trunc('day', t), date_trunc('day', t) + interval '2 days',
                                         interval '1 day') AS d
                   WHERE extract(isodow FROM d) <= 6 AND d + interval '8 hours' > t) END
$$;

-- --- The test catalogue (vet-lab-domain.md, "The test catalogue (D372)") --------------

-- lab_tests 1-180: the layout by range (1-114 in house, 115-150 sent out,
-- 151-180 the panels) and the named codes as the domain document fixes them;
-- the other tests' codes, names, analytes and sample types this part's, within
-- their range's discipline. species: who may have it ordered (the core's draw's
-- groups); analytes: lab_analytes' ids, in report order (load.sql); wd, wh, wf:
-- the practices' draw weights for a domestic animal, a horse, a farm animal,
-- a sent-out test's half again (the centre's draw is the core's, core_request). Night-capable: the in-house
-- haematology, biochemistry and blood gases.
CREATE FUNCTION pg_temp.lab_catalogue()
  RETURNS TABLE (id integer, code text, name text, is_panel boolean, discipline text, sample_type text,
                 turnaround_hours integer, performed text, external_code text, diagnosis_code text,
                 night_capable boolean, species text, analytes integer[], wd float8, wh float8, wf float8)
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT c.id, c.code, c.name, c.id > 150, c.disc, c.st, c.tat,
       CASE WHEN c.id BETWEEN 115 AND 150 THEN 'sent-out' ELSE 'in-house' END,
       CASE WHEN c.id BETWEEN 115 AND 150 THEN 'NL-' || c.code END, c.dx,
       c.id <= 60 OR (c.id > 150 AND c.disc IN ('haematology', 'biochemistry', 'blood-gas')),
       c.sp, c.an, c.wd, c.wh, c.wf
  FROM (VALUES
  -- haematology, in house, night-capable
  (1, 'HCT', 'haematocrit', 'haematology', 'edta-blood', 1, 'any', NULL, ARRAY[3], 0.4, 0.4, 0.3),
  (2, 'HGB', 'haemoglobin', 'haematology', 'edta-blood', 1, 'any', NULL, ARRAY[2], 0.2, 0.2, 0.1),
  (3, 'WBC', 'white cell count', 'haematology', 'edta-blood', 1, 'any', NULL, ARRAY[7], 0.4, 0.4, 0.3),
  (4, 'DIFF', 'differential white cell count', 'haematology', 'edta-blood', 2, 'any', NULL, ARRAY[8, 9, 10, 11, 12], 0.6, 0.6, 0.4),
  (5, 'PLT', 'platelet count', 'haematology', 'edta-blood', 1, 'any', NULL, ARRAY[13], 0.5, 0.3, 0.2),
  (6, 'RETIC', 'reticulocyte count', 'haematology', 'edta-blood', 2, 'any', NULL, ARRAY[14], 0.5, 0.1, 0.1),
  (7, 'RBCI', 'red cell count and indices', 'haematology', 'edta-blood', 1, 'any', NULL, ARRAY[1, 4, 5, 6], 0.4, 0.4, 0.3),
  (8, 'SMEAR', 'blood smear review', 'haematology', 'edta-blood', 4, 'any', NULL, ARRAY[70], 0.5, 0.4, 0.3),
  (9, 'BLPAR', 'blood parasite smear', 'haematology', 'edta-blood', 4, 'any', NULL, ARRAY[69], 0.4, 0.3, 0.4),
  (10, 'COOMBS', 'direct antiglobulin test', 'haematology', 'edta-blood', 4, 'any', NULL, ARRAY[69], 0.3, 0.1, 0.0),
  (11, 'XMATCH', 'crossmatch', 'haematology', 'edta-blood', 2, 'any', NULL, ARRAY[69], 0.2, 0.2, 0.0),
  (12, 'BTYPE', 'blood typing', 'haematology', 'edta-blood', 2, 'any', NULL, ARRAY[70], 0.2, 0.1, 0.0),
  -- biochemistry, in house, night-capable
  (13, 'GLU', 'glucose', 'biochemistry', 'serum', 1, 'any', NULL, ARRAY[15], 2.0, 0.5, 0.3),
  (14, 'UREA', 'urea', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[16], 0.4, 0.3, 0.3),
  (15, 'CREA', 'creatinine', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[17], 0.6, 0.3, 0.2),
  (16, 'ALB', 'albumin', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[18], 0.3, 0.3, 0.3),
  (17, 'TP', 'total protein', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[19], 0.3, 0.4, 0.4),
  (18, 'GLOB', 'globulin', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[20], 0.2, 0.2, 0.2),
  (19, 'ALT', 'alanine aminotransferase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[21], 0.5, 0.1, 0.1),
  (20, 'AST', 'aspartate aminotransferase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[22], 0.2, 0.5, 0.4),
  (21, 'ALP', 'alkaline phosphatase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[23], 0.4, 0.2, 0.1),
  (22, 'GGT', 'gamma-glutamyl transferase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[24], 0.2, 0.5, 0.5),
  (23, 'TBIL', 'total bilirubin', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[25], 0.3, 0.3, 0.2),
  (24, 'CHOL', 'cholesterol', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[26], 0.2, 0.1, 0.1),
  (25, 'TRIG', 'triglycerides', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[27], 0.2, 0.3, 0.1),
  (26, 'AMYL', 'amylase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[28], 0.2, 0.0, 0.0),
  (27, 'LIPA', 'lipase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[29], 0.4, 0.0, 0.0),
  (28, 'CK', 'creatine kinase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[30], 0.2, 0.6, 0.4),
  (29, 'CA', 'calcium', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[31], 0.4, 0.3, 0.6),
  (30, 'PHOS', 'phosphate', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[32], 0.3, 0.2, 0.4),
  (31, 'MG', 'magnesium', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[33], 0.1, 0.2, 0.5),
  (32, 'NA', 'sodium', 'biochemistry', 'serum', 1, 'any', NULL, ARRAY[34], 0.2, 0.2, 0.2),
  (33, 'K', 'potassium', 'biochemistry', 'serum', 1, 'any', NULL, ARRAY[35], 0.3, 0.2, 0.2),
  (34, 'CL', 'chloride', 'biochemistry', 'serum', 1, 'any', NULL, ARRAY[36], 0.1, 0.1, 0.1),
  (35, 'BHB', 'beta-hydroxybutyrate', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[37], 0.1, 0.1, 1.0),
  (36, 'NEFA', 'non-esterified fatty acids', 'biochemistry', 'serum', 4, 'any', NULL, ARRAY[38], 0.0, 0.1, 0.8),
  (37, 'GLDH', 'glutamate dehydrogenase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[39], 0.0, 0.4, 0.4),
  (38, 'SAA', 'serum amyloid A', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[40], 0.1, 1.0, 0.2),
  (39, 'CRP', 'C-reactive protein', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[41], 0.8, 0.0, 0.0),
  (40, 'FRUCT', 'fructosamine', 'biochemistry', 'serum', 4, 'dogcat', NULL, ARRAY[42], 0.6, 0.0, 0.0),
  (41, 'SDMA', 'symmetric dimethylarginine', 'biochemistry', 'serum', 4, 'dogcat', NULL, ARRAY[43], 0.8, 0.0, 0.0),
  (42, 'BA', 'bile acids', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[44], 0.5, 0.3, 0.0),
  (43, 'BASTIM', 'bile acid stimulation test', 'biochemistry', 'serum', 4, 'dogcat', NULL, ARRAY[44], 0.3, 0.0, 0.0),
  (44, 'CU', 'copper', 'biochemistry', 'serum', 24, 'any', NULL, ARRAY[45], 0.0, 0.1, 0.6),
  (45, 'SE', 'selenium', 'biochemistry', 'serum', 24, 'any', NULL, ARRAY[46], 0.0, 0.3, 0.6),
  (46, 'LDH', 'lactate dehydrogenase', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[47], 0.1, 0.2, 0.1),
  (47, 'UREACR', 'urea and creatinine', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[16, 17], 0.8, 0.3, 0.2),
  (48, 'ALBGLB', 'albumin and globulin', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[18, 20], 0.3, 0.3, 0.3),
  (49, 'CAPHOS', 'calcium and phosphate', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[31, 32], 0.3, 0.2, 0.5),
  (50, 'LIVENZ', 'liver enzymes', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[21, 23, 24], 0.6, 0.3, 0.2),
  (51, 'MUSCLE', 'muscle enzymes', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[22, 30, 47], 0.1, 0.6, 0.3),
  (52, 'NAKCL', 'sodium, potassium and chloride', 'biochemistry', 'serum', 1, 'any', NULL, ARRAY[34, 35, 36], 0.3, 0.2, 0.2),
  -- blood gases, in house, night-capable
  (53, 'PH', 'blood pH', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[48], 0.1, 0.1, 0.1),
  (54, 'PCO2', 'carbon dioxide partial pressure', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[49], 0.1, 0.1, 0.1),
  (55, 'PO2', 'oxygen partial pressure', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[50], 0.1, 0.1, 0.1),
  (56, 'HCO3', 'bicarbonate', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[51], 0.1, 0.1, 0.1),
  (57, 'LACT', 'lactate', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[52], 0.2, 0.5, 0.2),
  (58, 'ICA', 'ionised calcium', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[53], 0.2, 0.1, 0.3),
  (59, 'VBG', 'venous blood gas', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[48, 49, 51], 0.2, 0.2, 0.2),
  (60, 'LACGLU', 'lactate and glucose', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[52, 15], 0.1, 0.3, 0.1),
  -- coagulation, in house
  (61, 'PT', 'prothrombin time', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[54], 0.2, 0.1, 0.0),
  (62, 'APTT', 'activated partial thromboplastin time', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[55], 0.2, 0.1, 0.0),
  (63, 'FIBR', 'fibrinogen', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[56], 0.1, 0.5, 0.3),
  (64, 'DDIM', 'D-dimers', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[57], 0.1, 0.1, 0.0),
  (65, 'PTAPTT', 'prothrombin and partial thromboplastin times', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[54, 55], 0.4, 0.1, 0.0),
  (66, 'FIBDD', 'fibrinogen and D-dimers', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[56, 57], 0.1, 0.2, 0.0),
  -- urinalysis, in house
  (67, 'USG', 'urine specific gravity', 'urinalysis', 'urine', 1, 'any', NULL, ARRAY[58], 0.4, 0.1, 0.1),
  (68, 'DIP', 'urine dipstick', 'urinalysis', 'urine', 1, 'any', NULL, ARRAY[59, 70], 0.3, 0.1, 0.1),
  (69, 'SED', 'urine sediment', 'urinalysis', 'urine', 2, 'any', NULL, ARRAY[70], 0.4, 0.1, 0.1),
  (70, 'UPC', 'urine protein to creatinine ratio', 'urinalysis', 'urine', 4, 'any', NULL, ARRAY[60], 0.8, 0.0, 0.0),
  (71, 'UPRO', 'urine protein', 'urinalysis', 'urine', 2, 'any', NULL, ARRAY[61], 0.2, 0.1, 0.1),
  (72, 'UCCR', 'urine cortisol to creatinine ratio', 'urinalysis', 'urine', 24, 'dog', NULL, ARRAY[63], 0.3, 0.0, 0.0),
  (73, 'UCRYS', 'urine crystals', 'urinalysis', 'urine', 2, 'any', NULL, ARRAY[70], 0.3, 0.0, 0.1),
  (74, 'UBLD', 'urine occult blood', 'urinalysis', 'urine', 1, 'any', NULL, ARRAY[69], 0.2, 0.0, 0.0),
  -- cytology, in house
  (75, 'FNA', 'fine-needle aspirate cytology', 'cytology', 'tissue', 24, 'any', NULL, ARRAY[70], 1.6, 0.3, 0.2),
  (76, 'CSF', 'cerebrospinal fluid analysis', 'cytology', 'tissue', 24, 'any', NULL, ARRAY[70], 0.1, 0.1, 0.0),
  (77, 'BALCY', 'bronchoalveolar lavage cytology', 'cytology', 'swab', 24, 'any', NULL, ARRAY[70], 0.1, 0.4, 0.1),
  (78, 'SYNCY', 'synovial fluid analysis', 'cytology', 'tissue', 24, 'any', NULL, ARRAY[70], 0.2, 0.4, 0.1),
  (79, 'EARCY', 'ear cytology', 'cytology', 'swab', 24, 'any', NULL, ARRAY[70], 0.8, 0.0, 0.0),
  (80, 'SKINCY', 'skin cytology', 'cytology', 'swab', 24, 'any', NULL, ARRAY[70], 0.6, 0.1, 0.0),
  (81, 'BMCY', 'bone marrow cytology', 'cytology', 'tissue', 48, 'any', NULL, ARRAY[70], 0.1, 0.0, 0.0),
  (82, 'TWCY', 'tracheal wash cytology', 'cytology', 'swab', 24, 'any', NULL, ARRAY[70], 0.0, 0.5, 0.1),
  (83, 'VAGCY', 'vaginal cytology', 'cytology', 'swab', 4, 'any', NULL, ARRAY[70], 0.3, 0.0, 0.0),
  (84, 'IMPCY', 'impression smear cytology', 'cytology', 'tissue', 24, 'any', NULL, ARRAY[70], 0.2, 0.1, 0.0),
  -- microbiology, in house
  (85, 'AERO', 'aerobic culture', 'microbiology', 'swab', 48, 'any', NULL, ARRAY[67], 0.4, 0.4, 0.3),
  (86, 'ANAER', 'anaerobic culture', 'microbiology', 'swab', 72, 'any', NULL, ARRAY[67], 0.1, 0.1, 0.1),
  (87, 'FUNG', 'fungal culture', 'microbiology', 'swab', 72, 'any', NULL, ARRAY[67], 0.1, 0.2, 0.0),
  (88, 'DERM', 'dermatophyte culture', 'microbiology', 'swab', 72, 'any', NULL, ARRAY[67], 0.4, 0.1, 0.1),
  (89, 'SENS', 'antimicrobial sensitivity', 'microbiology', 'swab', 48, 'any', NULL, ARRAY[68], 0.2, 0.2, 0.2),
  (90, 'GRAM', 'Gram stain', 'microbiology', 'swab', 2, 'any', NULL, ARRAY[70], 0.1, 0.1, 0.1),
  (91, 'FFLOT', 'faecal flotation', 'microbiology', 'faeces', 4, 'any', NULL, ARRAY[70], 0.6, 0.3, 0.6),
  (92, 'BAERM', 'Baermann larval test', 'microbiology', 'faeces', 24, 'any', NULL, ARRAY[70], 0.1, 0.1, 0.4),
  (93, 'GIARD', 'Giardia antigen', 'microbiology', 'faeces', 2, 'any', NULL, ARRAY[69], 0.4, 0.0, 0.1),
  (94, 'CRYPT', 'Cryptosporidium', 'microbiology', 'faeces', 4, 'any', NULL, ARRAY[69], 0.1, 0.0, 0.6),
  (95, 'SALM', 'Salmonella culture', 'microbiology', 'faeces', 72, 'any', NULL, ARRAY[67], 0.1, 0.3, 0.4),
  (96, 'CAMPY', 'Campylobacter culture', 'microbiology', 'faeces', 72, 'any', NULL, ARRAY[67], 0.1, 0.0, 0.1),
  (97, 'MILKB', 'milk bacteriology', 'microbiology', 'milk', 48, 'farmfemale', NULL, ARRAY[67], 0.0, 0.0, 1.0),
  (98, 'BCULT', 'blood culture', 'microbiology', 'heparin-blood', 72, 'any', NULL, ARRAY[67], 0.1, 0.2, 0.1),
  -- serology, in house (rapid tests and ELISAs)
  (99, 'EIA', 'equine infectious anaemia antibody (Coggins)', 'serology', 'serum', 24, 'horse', 'D-EA01', ARRAY[69], 0.0, 2.0, 0.0),
  (100, 'BRUC', 'brucellosis antibody', 'serology', 'serum', 24, 'farm', 'D-BC01', ARRAY[69], 0.0, 0.0, 0.8),
  (101, 'QFEV', 'Q fever antibody', 'serology', 'serum', 24, 'farm', 'D-QF01', ARRAY[69], 0.0, 0.0, 0.5),
  (102, 'BTAB', 'bluetongue antibody', 'serology', 'serum', 24, 'farm', 'D-BT01', ARRAY[69], 0.0, 0.0, 0.5),
  (103, 'WNF', 'West Nile virus IgM', 'serology', 'serum', 24, 'horse', 'D-WN01', ARRAY[69], 0.0, 0.4, 0.0),
  (104, 'EVA', 'equine viral arteritis antibody', 'serology', 'serum', 24, 'horse', 'D-EV01', ARRAY[69], 0.0, 0.6, 0.0),
  (105, 'LEPTO', 'Leptospira antibody', 'serology', 'serum', 24, 'any', NULL, ARRAY[69], 0.4, 0.1, 0.3),
  (106, 'TOXO', 'Toxoplasma antibody', 'serology', 'serum', 24, 'any', NULL, ARRAY[69], 0.2, 0.0, 0.2),
  (107, 'NEOS', 'Neospora antibody', 'serology', 'serum', 24, 'cattle', NULL, ARRAY[69], 0.0, 0.0, 0.6),
  (108, 'FCOV', 'feline coronavirus antibody', 'serology', 'serum', 4, 'cat', NULL, ARRAY[69], 0.4, 0.0, 0.0),
  (109, 'HWAG', 'heartworm antigen', 'serology', 'serum', 2, 'dog', NULL, ARRAY[69], 0.4, 0.0, 0.0),
  (110, 'PARVO', 'parvovirus antigen', 'serology', 'faeces', 1, 'dog', NULL, ARRAY[69], 0.4, 0.0, 0.0),
  (111, 'FELVAG', 'FeLV antigen', 'serology', 'serum', 1, 'cat', NULL, ARRAY[69], 0.3, 0.0, 0.0),
  (112, 'IGG', 'immunoglobulin G', 'serology', 'serum', 2, 'any', NULL, ARRAY[66], 0.0, 0.5, 0.4),
  (113, 'LYME', 'Borrelia antibody', 'serology', 'serum', 4, 'dog', NULL, ARRAY[69], 0.3, 0.0, 0.0),
  -- residue, in house (answer 11)
  (114, 'MINH', 'milk inhibitor test (antimicrobial residues)', 'residue', 'milk', 24, 'minh', NULL, ARRAY[69], 0.0, 0.0, 0.8),
  -- histopathology, sent out
  (115, 'HISTO', 'histopathology, biopsy', 'histopathology', 'tissue', 120, 'any', NULL, ARRAY[70], 1.6, 0.8, 0.6),
  (116, 'HISTOM', 'histopathology, excision with margins', 'histopathology', 'tissue', 120, 'any', NULL, ARRAY[70], 1.0, 0.2, 0.1),
  (117, 'HISTOS', 'histopathology, skin biopsies', 'histopathology', 'tissue', 120, 'any', NULL, ARRAY[70], 0.5, 0.2, 0.0),
  (118, 'HISTOE', 'histopathology, endoscopic biopsies', 'histopathology', 'tissue', 120, 'any', NULL, ARRAY[70], 0.3, 0.1, 0.0),
  (119, 'HISTOB', 'histopathology, bone biopsy', 'histopathology', 'tissue', 168, 'any', NULL, ARRAY[70], 0.1, 0.1, 0.0),
  (120, 'HISTOP', 'histopathology, post-mortem tissues', 'histopathology', 'tissue', 168, 'any', NULL, ARRAY[70], 0.1, 0.2, 0.6),
  (121, 'IHC', 'immunohistochemistry', 'histopathology', 'tissue', 168, 'any', NULL, ARRAY[70], 0.2, 0.0, 0.0),
  (122, 'HISTOR', 'histopathology, second-opinion review', 'histopathology', 'tissue', 96, 'any', NULL, ARRAY[70], 0.1, 0.1, 0.0),
  -- molecular, sent out
  (123, 'PCRSA', 'small-animal infectious disease PCR panel', 'molecular', 'swab', 96, 'domestic', NULL, ARRAY[69], 0.8, 0.0, 0.0),
  (124, 'STREP', 'strangles PCR (Streptococcus equi)', 'molecular', 'swab', 72, 'horse', NULL, ARRAY[69], 0.0, 1.2, 0.0),
  (125, 'BVDPCR', 'bovine viral diarrhoea virus PCR', 'molecular', 'edta-blood', 72, 'cattle', 'D-BV01', ARRAY[69], 0.0, 0.0, 1.0),
  (126, 'BTPCR', 'bluetongue virus PCR', 'molecular', 'edta-blood', 72, 'farm', 'D-BT01', ARRAY[69], 0.0, 0.0, 0.3),
  (127, 'FMDPCR', 'foot-and-mouth disease virus PCR', 'molecular', 'swab', 48, 'farm', 'D-FM01', ARRAY[69], 0.0, 0.0, 0.05),
  (128, 'EHV1', 'equine herpesvirus 1 PCR', 'molecular', 'swab', 72, 'horse', NULL, ARRAY[69], 0.0, 0.8, 0.0),
  (129, 'LEPPCR', 'Leptospira PCR', 'molecular', 'urine', 72, 'any', NULL, ARRAY[69], 0.3, 0.0, 0.1),
  (130, 'FCVPCR', 'feline coronavirus PCR', 'molecular', 'faeces', 96, 'cat', NULL, ARRAY[69], 0.3, 0.0, 0.0),
  (131, 'CRDPCR', 'canine respiratory disease PCR', 'molecular', 'swab', 72, 'dog', NULL, ARRAY[69], 0.3, 0.0, 0.0),
  (132, 'MYCPCR', 'Mycobacterium bovis PCR', 'molecular', 'tissue', 96, 'cattle', 'D-TB01', ARRAY[69], 0.0, 0.0, 0.2),
  (133, 'BABPCR', 'Babesia PCR', 'molecular', 'edta-blood', 72, 'any', NULL, ARRAY[69], 0.3, 0.1, 0.1),
  (134, 'AHSPCR', 'African horse sickness virus PCR', 'molecular', 'edta-blood', 48, 'horse', 'D-AH01', ARRAY[69], 0.0, 0.05, 0.0),
  -- endocrinology, sent out
  (135, 'TT4', 'total thyroxine', 'endocrinology', 'serum', 72, 'dogcat', NULL, ARRAY[62], 1.2, 0.0, 0.0),
  (136, 'ACTHST', 'ACTH stimulation test (cortisol)', 'endocrinology', 'serum', 72, 'dog', NULL, ARRAY[63], 0.6, 0.0, 0.0),
  (137, 'EACTH', 'equine endogenous ACTH (PPID)', 'endocrinology', 'edta-blood', 72, 'horse', NULL, ARRAY[64], 0.0, 1.2, 0.0),
  (138, 'FT4', 'free thyroxine', 'endocrinology', 'serum', 72, 'dogcat', NULL, ARRAY[62], 0.4, 0.0, 0.0),
  (139, 'TSH', 'canine thyroid-stimulating hormone', 'endocrinology', 'serum', 72, 'dog', NULL, ARRAY[70], 0.3, 0.0, 0.0),
  (140, 'LDDS', 'low-dose dexamethasone suppression test', 'endocrinology', 'serum', 72, 'dog', NULL, ARRAY[63], 0.3, 0.0, 0.0),
  (141, 'INSUL', 'insulin', 'endocrinology', 'serum', 72, 'any', NULL, ARRAY[70], 0.1, 0.4, 0.0),
  (142, 'PROG', 'progesterone', 'endocrinology', 'serum', 72, 'any', NULL, ARRAY[70], 0.3, 0.2, 0.2),
  (143, 'TESTO', 'testosterone', 'endocrinology', 'serum', 72, 'any', NULL, ARRAY[70], 0.1, 0.2, 0.0),
  (144, 'PTH', 'parathyroid hormone', 'endocrinology', 'serum', 72, 'any', NULL, ARRAY[70], 0.1, 0.0, 0.0),
  -- toxicology, sent out
  (145, 'PB', 'blood lead', 'toxicology', 'edta-blood', 120, 'any', NULL, ARRAY[65], 0.1, 0.0, 0.5),
  (146, 'ETGLY', 'ethylene glycol', 'toxicology', 'serum', 120, 'any', NULL, ARRAY[70], 0.1, 0.0, 0.0),
  (147, 'ANTICO', 'anticoagulant rodenticide screen', 'toxicology', 'serum', 120, 'any', NULL, ARRAY[70], 0.2, 0.0, 0.1),
  (148, 'MYCOT', 'mycotoxin screen', 'toxicology', 'tissue', 120, 'any', NULL, ARRAY[70], 0.0, 0.1, 0.3),
  (149, 'ORGPH', 'organophosphate screen', 'toxicology', 'serum', 120, 'any', NULL, ARRAY[70], 0.1, 0.0, 0.2),
  (150, 'NITR', 'nitrate and nitrite', 'toxicology', 'serum', 120, 'farm', NULL, ARRAY[70], 0.0, 0.0, 0.2),
  -- the panels, in house, each its own discipline (named codes)
  (151, 'CBC', 'complete blood count', 'haematology', 'edta-blood', 2, 'any', NULL, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], 12, 10, 8),
  (152, 'CBCS', 'complete blood count with smear review', 'haematology', 'edta-blood', 4, 'any', NULL, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 70], 3, 2, 1),
  (153, 'PCVTS', 'haematocrit and total solids', 'haematology', 'edta-blood', 1, 'any', NULL, ARRAY[3, 19], 0.5, 2, 0.5),
  (154, 'PREA', 'pre-anaesthetic profile', 'biochemistry', 'serum', 2, 'domestic', NULL, ARRAY[15, 16, 17, 19, 21, 23], 5, 0, 0),
  (155, 'CHEMSA', 'biochemistry profile, small animal', 'biochemistry', 'serum', 4, 'domestic', NULL, ARRAY[15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 26, 29, 31, 32, 34, 35, 36], 10, 0, 0),
  (156, 'SENIOR', 'senior profile', 'biochemistry', 'serum', 4, 'domestic', NULL, ARRAY[15, 16, 17, 18, 19, 20, 21, 23, 26, 31, 32, 34, 35, 36, 43], 4, 0, 0),
  (157, 'RENAL', 'renal profile', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[16, 17, 32, 31, 18, 34, 35], 3, 0.5, 1),
  (158, 'LIVER', 'liver profile', 'biochemistry', 'serum', 2, 'any', NULL, ARRAY[21, 23, 24, 25, 18, 44], 2, 0.5, 1),
  (159, 'LYTES', 'electrolytes', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[34, 35, 36, 53], 0.5, 0.5, 0.5),
  (160, 'BGAS', 'blood gas and electrolytes', 'blood-gas', 'heparin-blood', 1, 'any', NULL, ARRAY[48, 49, 50, 51, 52, 53, 34, 35, 36], 0.5, 1, 1),
  (161, 'CHEMEQ', 'equine biochemistry profile', 'biochemistry', 'serum', 4, 'horse', NULL, ARRAY[15, 16, 17, 18, 19, 20, 22, 23, 24, 25, 30, 31, 32, 34, 35, 36, 40], 0, 10, 0),
  (162, 'COLIC', 'equine colic profile', 'biochemistry', 'heparin-blood', 1, 'horse', NULL, ARRAY[52, 15, 19, 3, 40], 0, 2, 0),
  (163, 'PERFEQ', 'equine performance profile', 'biochemistry', 'serum', 4, 'horse', NULL, ARRAY[22, 30, 47, 16, 17, 19, 33, 46], 0, 4, 0),
  (164, 'METRU', 'ruminant metabolic profile', 'biochemistry', 'serum', 4, 'farm', NULL, ARRAY[37, 38, 15, 16, 18, 19, 22, 24, 31, 32, 33], 0, 0, 10),
  (165, 'MINRU', 'ruminant mineral profile', 'biochemistry', 'serum', 24, 'farm', NULL, ARRAY[31, 32, 33, 45, 46], 0, 0, 5),
  (166, 'COAG', 'coagulation profile', 'coagulation', 'citrate-plasma', 2, 'any', NULL, ARRAY[54, 55, 56, 57], 1.5, 0.5, 0),
  (167, 'UA', 'urinalysis, complete', 'urinalysis', 'urine', 2, 'any', NULL, ARRAY[58, 59, 61, 70], 4, 0.5, 0.5),
  (168, 'UAUPC', 'urinalysis with protein to creatinine ratio', 'urinalysis', 'urine', 4, 'domestic', NULL, ARRAY[58, 59, 61, 70, 60], 2, 0, 0),
  (169, 'FAECP', 'faecal parasitology', 'microbiology', 'faeces', 24, 'any', NULL, ARRAY[70, 69], 2, 0.5, 1),
  (170, 'FEC', 'faecal egg count', 'microbiology', 'faeces', 24, 'horsefarm', NULL, ARRAY[70], 0, 4, 4),
  (171, 'CULT', 'aerobic culture and sensitivity', 'microbiology', 'swab', 72, 'any', NULL, ARRAY[67, 68], 3, 3, 2),
  (172, 'UCULT', 'urine culture and sensitivity', 'microbiology', 'urine', 72, 'any', NULL, ARRAY[67, 68], 2.5, 0, 0),
  (173, 'MCULT', 'milk culture and sensitivity (mastitis)', 'microbiology', 'milk', 72, 'farmfemale', NULL, ARRAY[67, 68], 0, 0, 8),
  (174, 'FELV', 'feline viral screen (FeLV antigen, FIV antibody)', 'serology', 'serum', 2, 'cat', NULL, ARRAY[69, 70], 2, 0, 0),
  (175, 'VECT', 'canine vector-borne screen', 'serology', 'serum', 2, 'dog', NULL, ARRAY[69, 70], 2, 0, 0),
  (176, 'DIARC', 'canine diarrhoea screen (parvovirus, Giardia)', 'serology', 'faeces', 2, 'dog', NULL, ARRAY[69, 70], 1, 0, 0),
  (177, 'CALFD', 'neonatal calf diarrhoea screen', 'serology', 'faeces', 4, 'cattle', NULL, ARRAY[69, 70], 0, 0, 4),
  (178, 'FOAL', 'foal IgG and sepsis screen', 'serology', 'serum', 2, 'horse', NULL, ARRAY[66, 70], 0, 2, 0),
  (179, 'EFFUS', 'effusion analysis', 'cytology', 'edta-blood', 4, 'any', NULL, ARRAY[19, 7, 70], 1, 2, 0),
  (180, 'HERDB', 'bovine herd-health screen (BVD, IBR, Johne''s antibodies)', 'serology', 'serum', 48, 'cattle', 'D-BV01', ARRAY[69, 70], 0, 0, 5)
  ) AS c (id, code, name, disc, st, tat, sp, dx, an, wd, wh, wf)
$$;

-- --- The history: one pass ---------------------------------------------------------------

-- Every order test of the year before load_epoch, with its order's, sample's
-- and send-out's columns (vet-lab-domain.md, "Deterministic key ranges", "The
-- history before T0"; docs/gm.md, "Part keys", the formulas):
--   * the centre's orders: the core's analysis requests that reached the lab
--     (core_request, sent_at set), one order a consultation, client_ref
--     C-<consultation>-<priority>, ordered at the first request's sent_at; each
--     test's final state the core's (resulted: released, or not performed on an
--     unfit sample; cancelled after sending: cancelled), a few minutes before
--     the core's resulted_at or cancelled_at (purpose 1's polling lag); the
--     core's requests of the last 24 hours, all sent, unreleased at T0;
--   * the practices' orders: 2.9 an hour on practice-hours (Monday to Friday
--     08-12 and 14-19, 0.3 over lunch, Saturday 08-12), ramping from 0.6 to 1.0
--     over the year; accounts 2-121, 1.6 tests each, one in twenty urgent;
--     received with the courier's wave, released at the pathologist's rounds;
--   * orders numbered in time order (ordered_at), order tests in their order's
--     order, samples one per order and sample type, send-outs in packing order.
-- States and times are those at load_epoch: a time at or after it is null.
CREATE FUNCTION pg_temp.lab_order_tests(load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (
    order_id integer, account_id integer, client_ref text, priority text, animal_id integer,
    consultation_id integer, requested_by integer, patient_ref text, client_surname text,
    species text, sex text, born_on date, microchip text, ueln text, ear_tag text,
    withdrawal_ends_on date, ordered_at timestamptz, received_at timestamptz,
    completed_at timestamptz, order_cancelled_at timestamptz, order_state text,
    order_test_id integer, test_position integer, test_id integer, code text, request_id integer,
    routing text, status text, not_performed_reason text, measured_at timestamptz,
    technical_at timestamptz, technical_by integer, released_at timestamptz, released_by integer,
    cancelled_at timestamptz, final_at timestamptz,
    sample_id integer, sample_type text, label text, collected_at timestamptz, collected_by integer,
    condition text,
    send_out_id integer, send_key uuid, xlab_accession text, packed_at timestamptz,
    sent_at timestamptz, accepted_at timestamptz, answered_at timestamptz, due_by timestamptz,
    send_status text)
  LANGUAGE sql IMMUTABLE AS $$
WITH cat AS MATERIALIZED (SELECT * FROM pg_temp.lab_catalogue()),
-- The centre: the core's analysis requests the lab received.
cr AS MATERIALIZED (
  SELECT n AS request_id, r.code, r.consultation_id, r.animal_id, r.requested_by, r.priority, r.state,
         r.sent_at, r.resulted_at, r.cancelled_at AS core_cancelled_at, r.withdrawal_ends_on
    FROM generate_series(1, 17000) AS n, LATERAL pg_temp.core_request(n, load_epoch, utc_offset) AS r
   WHERE r.kind = 'analysis' AND r.sent_at IS NOT NULL),
co AS MATERIALIZED (
  SELECT c.consultation_id, min(c.sent_at) AS ordered_at, min(c.animal_id) AS animal_id,
         min(c.requested_by) AS requested_by, min(c.priority) AS priority,
         min(c.withdrawal_ends_on) AS withdrawal_ends_on
    FROM cr AS c GROUP BY c.consultation_id),
coa AS MATERIALIZED (
  SELECT co.*, an.species, an.sex, an.born_on, pg_temp.core_microchip(co.animal_id) AS microchip,
         pg_temp.core_ueln(co.animal_id) AS ueln, pg_temp.core_ear_tag(co.animal_id) AS ear_tag,
         (SELECT ow.family_name FROM pg_temp.core_ownership(co.animal_id, load_epoch, utc_offset) AS os,
                 LATERAL pg_temp.core_owner(os.owner_id, load_epoch, utc_offset) AS ow
           WHERE os.from_at <= co.ordered_at AND coalesce(os.until_at, 'infinity') > co.ordered_at
           ORDER BY os.from_at DESC LIMIT 1) AS surname
    FROM co, LATERAL pg_temp.core_animal(co.animal_id, load_epoch, utc_offset) AS an),
-- The practices: one hour at a time over the year, 2.9 an hour at 1.0.
hr AS MATERIALIZED (
  SELECT h, t, sum(w) OVER (ORDER BY h) AS cum, w
    FROM (SELECT h, t, 2.9 * (0.6 + 0.4 * least(h / 168, 52) / 52.0)
                     * CASE WHEN extract(isodow FROM t) <= 5 AND extract(hour FROM t) IN (8, 9, 10, 11, 14, 15, 16, 17, 18) THEN 1.0
                            WHEN extract(isodow FROM t) <= 5 AND extract(hour FROM t) IN (12, 13) THEN 0.3
                            WHEN extract(isodow FROM t) = 6 AND extract(hour FROM t) BETWEEN 8 AND 11 THEN 1.0
                            ELSE 0 END AS w
            FROM (SELECT h, pg_temp.lab_start(load_epoch, utc_offset) + h * interval '1 hour' AS t
                    FROM generate_series(0, 53 * 168) AS h) AS a
           WHERE t < pg_temp.lab_local(load_epoch, utc_offset)) AS b),
po AS MATERIALIZED (
  SELECT m, pg_temp.lab_utc(hr.t + (j - 1 + pg_temp.lab_u(m, 1)) / cnt * interval '1 hour', utc_offset) AS ordered_at
    FROM hr, LATERAL (SELECT (floor(hr.cum) - floor(hr.cum - hr.w))::integer AS cnt) AS k,
         LATERAL generate_series(1, k.cnt) AS j,
         LATERAL (SELECT floor(hr.cum - hr.w)::integer + j AS m) AS mm
   WHERE k.cnt > 0),
poa AS MATERIALIZED (
  SELECT po.m, po.ordered_at, 2 + floor(120 * pg_temp.lab_u(m, 2))::integer AS account_id,
         CASE WHEN pg_temp.lab_u(m, 3) < 0.05 THEN 'urgent' ELSE 'routine' END AS priority,
         CASE WHEN u4 < 0.42 THEN 'dog' WHEN u4 < 0.70 THEN 'cat' WHEN u4 < 0.85 THEN 'horse'
              WHEN u4 < 0.94 THEN 'cattle' WHEN u4 < 0.97 THEN 'sheep' ELSE 'goat' END AS species,
         CASE WHEN pg_temp.lab_u(m, 5) < CASE WHEN u4 >= 0.85 THEN 0.8 ELSE 0.5 END THEN 'female' ELSE 'male' END AS sex
    FROM po, LATERAL (SELECT pg_temp.lab_u(m, 4) AS u4) AS x),
pob AS MATERIALIZED (
  SELECT poa.*,
         (pg_temp.lab_local(ordered_at, utc_offset)::date
          - (CASE WHEN species IN ('dog', 'cat') THEN 1 + 13 * pg_temp.lab_u(m, 6)
                  WHEN species = 'horse' THEN 2 + 18 * pg_temp.lab_u(m, 6)
                  ELSE 1.5 + 6 * pg_temp.lab_u(m, 6) END * 365.25)::integer) AS born_on,
         'P' || lpad((1 + floor(99999 * pg_temp.lab_u(m, 7)))::integer::text, 5, '0') AS patient_ref,
         (ARRAY['Abbott', 'Baker', 'Carter', 'Dupont', 'Evans', 'Fischer', 'Garcia', 'Hughes', 'Ivanova', 'Jansen',
                'Keller', 'Laurent', 'Martin', 'Novak', 'Olsen', 'Peeters', 'Quinn', 'Rossi', 'Schmidt', 'Turner',
                'Urban', 'Vogel', 'Walsh', 'Young', 'Zimmer'])[1 + floor(25 * pg_temp.lab_u(m, 8))::integer] AS surname,
         CASE WHEN species IN ('dog', 'cat', 'horse') AND pg_temp.lab_u(m, 9) < 0.8
              THEN '941' || lpad((floor(1e12 * pg_temp.lab_u(m, 10)))::bigint::text, 12, '0') END AS microchip,
         CASE WHEN species = 'horse' AND pg_temp.lab_u(m, 9) < 0.6
              THEN '941002' || lpad((floor(1e9 * pg_temp.lab_u(m, 11)))::bigint::text, 9, '0') END AS ueln,
         CASE WHEN species IN ('cattle', 'sheep', 'goat')
              THEN 'XA' || lpad((floor(1e12 * pg_temp.lab_u(m, 12)))::bigint::text, 12, '0') END AS ear_tag,
         CASE WHEN pg_temp.lab_u(m, 13) < 0.55 THEN 1 WHEN pg_temp.lab_u(m, 13) < 0.85 THEN 2 ELSE 3 END AS ntests
    FROM poa),
-- Every order, numbered in time order.
ord AS MATERIALIZED (
  SELECT (row_number() OVER (ORDER BY x.ordered_at, x.src, x.k))::integer AS order_id, x.*
    FROM (SELECT 'c' AS src, consultation_id AS k, 1 AS account_id,
                 'C-' || consultation_id || '-' || priority AS client_ref, priority, animal_id, consultation_id,
                 requested_by, NULL::text AS patient_ref, surname AS client_surname, species, sex, born_on,
                 microchip, ueln, ear_tag, withdrawal_ends_on, ordered_at
            FROM coa
          UNION ALL
          SELECT 'p', m, account_id, to_char(pg_temp.lab_local(ordered_at, utc_offset), 'YYMMDD') || '-'
                 || lpad(m::text, 5, '0'), priority, NULL, NULL, NULL, patient_ref, surname, species, sex,
                 born_on, microchip, ueln, ear_tag,
                 CASE WHEN species IN ('cattle', 'goat') AND sex = 'female'
                      THEN pg_temp.lab_local(ordered_at, utc_offset)::date - 1 - floor(5 * pg_temp.lab_u(m, 14))::integer END,
                 ordered_at
            FROM pob) AS x
   WHERE x.ordered_at < load_epoch),
-- The tests: the centre's one a request, the practices' drawn by weight
-- without replacement among the codes valid for the patient.
tc AS MATERIALIZED (
  SELECT o.order_id, (row_number() OVER (PARTITION BY o.order_id ORDER BY c.request_id))::integer AS position,
         t.id AS test_id, c.code, c.request_id, c.state AS core_state, c.resulted_at AS core_resulted_at,
         c.core_cancelled_at
    FROM cr AS c JOIN ord AS o ON o.src = 'c' AND o.k = c.consultation_id JOIN cat AS t ON t.code = c.code
  UNION ALL
  SELECT o.order_id, (row_number() OVER (PARTITION BY o.order_id ORDER BY d.rk))::integer, d.id, d.code, NULL,
         NULL, NULL, NULL
    FROM ord AS o, pob AS p,
         LATERAL (SELECT t.id, t.code, ln(pg_temp.lab_u(p.m::bigint * 1000 + t.id, 15) + 1e-12)
                                       / (CASE WHEN p.species IN ('dog', 'cat') THEN t.wd
                                               WHEN p.species = 'horse' THEN t.wh ELSE t.wf END
                                          * CASE WHEN t.performed = 'sent-out' THEN 1.5 ELSE 1 END) AS rk
                    FROM cat AS t
                   WHERE CASE WHEN p.species IN ('dog', 'cat') THEN t.wd WHEN p.species = 'horse' THEN t.wh ELSE t.wf END > 0
                     AND CASE t.species WHEN 'any' THEN true WHEN 'domestic' THEN p.species IN ('dog', 'cat')
                                        WHEN 'horse' THEN p.species = 'horse'
                                        WHEN 'farm' THEN p.species IN ('cattle', 'sheep', 'goat')
                                        WHEN 'horsefarm' THEN p.species NOT IN ('dog', 'cat')
                                        WHEN 'cattle' THEN p.species = 'cattle' WHEN 'dog' THEN p.species = 'dog'
                                        WHEN 'cat' THEN p.species = 'cat' WHEN 'dogcat' THEN p.species IN ('dog', 'cat')
                                        WHEN 'farmfemale' THEN p.species IN ('cattle', 'sheep', 'goat') AND p.sex = 'female'
                                        WHEN 'minh' THEN p.species IN ('cattle', 'goat') AND p.sex = 'female'
                                        ELSE false END
                     AND (p.priority = 'routine' OR (t.performed = 'in-house' AND t.turnaround_hours <= 4))
                   ORDER BY 3 DESC LIMIT p.ntests) AS d
   WHERE o.src = 'p' AND o.k = p.m),
-- Ids: order tests in their order's order, samples one per order and type.
ti AS MATERIALIZED (
  SELECT (row_number() OVER (ORDER BY tc.order_id, tc.position))::integer AS order_test_id,
         (dense_rank() OVER (ORDER BY tc.order_id, t.sample_type))::integer AS sample_id,
         tc.*, t.sample_type, t.performed AS routing, t.turnaround_hours AS tat, t.night_capable
    FROM tc JOIN cat AS t ON t.id = tc.test_id),
-- A sample's condition at receipt: 97 % fit; a centre's sample unfit only
-- when every request on it resulted in the core (its tests then not performed).
sc AS MATERIALIZED (
  SELECT ti.sample_id,
         CASE WHEN pg_temp.lab_u(ti.sample_id, 16) < 0.97
                   OR bool_or(o.src = 'c' AND ti.core_state IS DISTINCT FROM 'resulted') THEN 'fit'
              ELSE (ARRAY['haemolysed', 'lipaemic', 'clotted', 'under-filled', 'unlabelled', 'icteric'])
                   [1 + floor(6 * pg_temp.lab_u(ti.sample_id, 17))::integer] END AS condition
    FROM ti JOIN ord AS o USING (order_id) GROUP BY ti.sample_id),
-- The centre's tests' final times, the core's less purpose 1's polling lag.
cf AS MATERIALIZED (
  SELECT ti.order_test_id,
         CASE ti.core_state
           WHEN 'resulted' THEN greatest(o.ordered_at + interval '20 minutes',
                                         ti.core_resulted_at - (0.5 + 4 * pg_temp.lab_u(ti.order_test_id, 18)) * interval '1 minute')
           WHEN 'cancelled' THEN greatest(o.ordered_at,
                                          ti.core_cancelled_at - (0.5 + 4 * pg_temp.lab_u(ti.order_test_id, 18)) * interval '1 minute')
         END AS fin
    FROM ti JOIN ord AS o USING (order_id) WHERE o.src = 'c'),
cr2 AS MATERIALIZED (
  SELECT o.order_id,
         o.ordered_at + least((15 + 20 * pg_temp.lab_u(o.order_id, 19)) * interval '1 minute',
                              (coalesce(min(cf.fin) FILTER (WHERE ti.core_state = 'resulted'), load_epoch)
                               - o.ordered_at) * 0.3) AS recv
    FROM ord AS o JOIN ti USING (order_id) LEFT JOIN cf USING (order_test_id)
   WHERE o.src = 'c'
   GROUP BY o.order_id, o.ordered_at),
-- Planned times (UTC), before T0's cut.
pl AS MATERIALIZED (
  SELECT ti.*, o.src, o.ordered_at, sc.condition, o.priority,
         CASE WHEN o.src = 'c' THEN (SELECT r.recv FROM cr2 AS r WHERE r.order_id = ti.order_id)
              WHEN pg_temp.lab_u(o.order_id, 20) < 0.01 THEN NULL
              ELSE pg_temp.lab_utc(pg_temp.lab_courier(pg_temp.lab_local(o.ordered_at, utc_offset)), utc_offset)
                   + (15 + 60 * pg_temp.lab_u(o.order_id, 21)) * interval '1 minute' END AS recv,
         CASE WHEN o.src = 'p' AND pg_temp.lab_u(o.order_id, 20) < 0.01
              THEN o.ordered_at + (1 + 8 * pg_temp.lab_u(o.order_id, 22)) * interval '1 hour' END AS p_cancel,
         (SELECT cf.fin FROM cf WHERE cf.order_test_id = ti.order_test_id) AS c_fin
    FROM ti JOIN ord AS o USING (order_id) JOIN sc USING (sample_id)),
pt AS MATERIALIZED (
  SELECT pl.*,
         -- in house: measured, technically validated, released
         CASE WHEN routing = 'in-house' AND condition = 'fit' AND recv IS NOT NULL THEN
           CASE WHEN src = 'c' AND core_state = 'resulted' THEN recv + (c_fin - recv) * (0.3 + 0.3 * pg_temp.lab_u(order_test_id, 23))
                WHEN src = 'c' AND core_state = 'cancelled' THEN NULL
                ELSE (SELECT CASE WHEN night_capable OR (extract(isodow FROM l) <= 6 AND extract(hour FROM l) BETWEEN 7 AND 20)
                                  THEN pg_temp.lab_utc(l, utc_offset)
                                  ELSE pg_temp.lab_utc(pg_temp.lab_next_bench(l)
                                                       + (0.5 + 2 * pg_temp.lab_u(order_test_id, 24)) * interval '1 hour', utc_offset) END
                        FROM (SELECT pg_temp.lab_local(recv + tat * (0.3 + 0.5 * pg_temp.lab_u(order_test_id, 23)) * interval '1 hour',
                                                       utc_offset) AS l) AS z) END END AS meas,
         -- sent out: packed, sent, accepted, answered
         CASE WHEN routing = 'sent-out' AND condition = 'fit' AND recv IS NOT NULL
                   AND NOT (src = 'c' AND core_state = 'cancelled') THEN
           CASE WHEN src = 'c' AND core_state = 'resulted' THEN recv + (c_fin - recv) * 0.05
                ELSE pg_temp.lab_utc(pg_temp.lab_next_pack(pg_temp.lab_local(recv, utc_offset)), utc_offset) END END AS pack
    FROM pl),
pu AS MATERIALIZED (
  SELECT pt.*,
         CASE WHEN pack IS NULL THEN NULL WHEN src = 'c' AND core_state = 'resulted' THEN recv + (c_fin - recv) * 0.07
              ELSE pack + (20 + 30 * pg_temp.lab_u(order_test_id, 25)) * interval '1 minute' END AS sent,
         CASE WHEN pack IS NULL THEN NULL WHEN src = 'c' AND core_state = 'resulted' THEN recv + (c_fin - recv) * 0.75
              ELSE pg_temp.lab_utc(pg_temp.lab_xlab_open(pg_temp.lab_local(pack + interval '50 minutes'
                     + tat * (0.6 + 0.4 * pg_temp.lab_u(order_test_id, 26)) * interval '1 hour', utc_offset)), utc_offset)
                   + 90 * pg_temp.lab_u(order_test_id, 27) * interval '1 minute' END AS answ
    FROM pt),
pv AS MATERIALIZED (
  SELECT pu.*,
         CASE WHEN src = 'c' AND core_state = 'resulted' AND condition = 'fit' THEN
                CASE WHEN routing = 'in-house' THEN meas + (c_fin - meas) * (0.2 + 0.6 * pg_temp.lab_u(order_test_id, 28))
                     ELSE recv + (c_fin - recv) * 0.9 END
              WHEN routing = 'in-house' THEN meas + (10 + 50 * pg_temp.lab_u(order_test_id, 28)) * interval '1 minute'
              ELSE answ + (30 + 120 * pg_temp.lab_u(order_test_id, 28)) * interval '1 minute' END AS tech
    FROM pu),
pw AS MATERIALIZED (
  SELECT pv.*,
         CASE WHEN src = 'c' THEN CASE WHEN core_state = 'resulted' AND condition = 'fit' THEN c_fin END
              WHEN tech IS NULL THEN NULL
              WHEN priority = 'urgent' THEN tech + (5 + 15 * pg_temp.lab_u(order_test_id, 29)) * interval '1 minute'
              ELSE pg_temp.lab_utc(pg_temp.lab_next_round(pg_temp.lab_local(tech, utc_offset)), utc_offset)
                   + 25 * pg_temp.lab_u(order_test_id, 29) * interval '1 minute' END AS rel,
         CASE WHEN condition <> 'fit' THEN coalesce(c_fin, recv + (10 + 30 * pg_temp.lab_u(order_test_id, 30)) * interval '1 minute') END AS np,
         CASE WHEN src = 'c' AND core_state = 'cancelled' THEN c_fin ELSE p_cancel END AS canc
    FROM pv),
-- The cut at T0, and each test's state.
cut AS MATERIALIZED (
  SELECT pw.order_id, pw.order_test_id, pw.position, pw.test_id, pw.code, pw.request_id, pw.routing, pw.sample_id,
         pw.sample_type, pw.condition, pw.src, pw.tat,
         CASE WHEN pw.recv < load_epoch AND (pw.canc IS NULL OR pw.recv < pw.canc) THEN pw.recv END AS recv,
         CASE WHEN pw.meas < load_epoch THEN pw.meas END AS meas,
         CASE WHEN pw.tech < load_epoch THEN pw.tech END AS tech,
         CASE WHEN pw.rel < load_epoch THEN pw.rel END AS rel,
         CASE WHEN pw.np < load_epoch THEN pw.np END AS np,
         CASE WHEN pw.canc < load_epoch THEN pw.canc END AS canc,
         CASE WHEN pw.pack < load_epoch THEN pw.pack END AS pack,
         CASE WHEN pw.sent < load_epoch THEN pw.sent END AS sent,
         CASE WHEN pw.sent + (1 + 4 * pg_temp.lab_u(pw.order_test_id, 31)) * interval '1 minute' < load_epoch
              THEN pw.sent + (1 + 4 * pg_temp.lab_u(pw.order_test_id, 31)) * interval '1 minute' END AS acc,
         CASE WHEN pw.answ < load_epoch THEN pw.answ END AS answ,
         pw.pack + interval '50 minutes' + pw.tat * interval '1 hour' AS due
    FROM pw),
st AS MATERIALIZED (
  SELECT cut.*,
         CASE WHEN canc IS NOT NULL THEN 'cancelled' WHEN np IS NOT NULL THEN 'not-performed'
              WHEN rel IS NOT NULL THEN 'released' WHEN tech IS NOT NULL THEN 'technical'
              WHEN recv IS NOT NULL AND routing = 'sent-out' THEN 'sent-out'
              WHEN recv IS NOT NULL THEN 'in-progress' ELSE 'ordered' END AS status,
         coalesce(canc, np, rel) AS fin
    FROM cut),
so AS MATERIALIZED (
  SELECT order_test_id, (row_number() OVER (ORDER BY pack, order_test_id))::integer AS send_out_id
    FROM st WHERE pack IS NOT NULL),
os AS MATERIALIZED (
  SELECT order_id, min(recv) AS recv,
         CASE WHEN bool_and(fin IS NOT NULL) AND bool_or(status <> 'cancelled') THEN max(fin) END AS completed,
         CASE WHEN bool_and(status = 'cancelled') THEN max(canc) END AS cancelled
    FROM st GROUP BY order_id)
SELECT o.order_id, o.account_id, o.client_ref, o.priority, o.animal_id, o.consultation_id, o.requested_by,
       o.patient_ref, o.client_surname, o.species, o.sex, o.born_on, o.microchip, o.ueln, o.ear_tag,
       o.withdrawal_ends_on, o.ordered_at, os.recv, os.completed, os.cancelled,
       CASE WHEN os.cancelled IS NOT NULL THEN 'cancelled' WHEN os.completed IS NOT NULL THEN 'completed'
            WHEN os.recv IS NOT NULL THEN 'received' ELSE 'ordered' END,
       st.order_test_id, st.position, st.test_id, st.code, st.request_id, st.routing, st.status,
       CASE WHEN st.status = 'not-performed' THEN st.condition END,
       coalesce(st.meas, st.answ),
       st.tech, CASE WHEN st.tech IS NOT NULL THEN 71 + floor(8 * pg_temp.lab_u(st.order_test_id, 32))::integer END,
       st.rel, CASE WHEN st.rel IS NOT NULL THEN 79 + floor(2 * pg_temp.lab_u(st.order_test_id, 33))::integer END,
       st.canc, st.fin,
       st.sample_id, st.sample_type, 'ALD' || lpad(st.sample_id::text, 8, '0'),
       CASE WHEN o.src = 'c' THEN o.ordered_at + (2 + 8 * pg_temp.lab_u(st.sample_id, 34)) * interval '1 minute'
            ELSE o.ordered_at - (10 + 110 * pg_temp.lab_u(st.sample_id, 34)) * interval '1 minute' END,
       CASE WHEN o.src = 'c' THEN 29 + floor(23 * pg_temp.lab_u(st.sample_id, 35))::integer END,
       CASE WHEN os.recv IS NOT NULL THEN st.condition END,
       so.send_out_id, CASE WHEN so.send_out_id IS NOT NULL THEN md5('vet-lab-send-out:' || so.send_out_id)::uuid END,
       CASE WHEN st.acc IS NOT NULL THEN 'NL' || lpad((400000 + so.send_out_id)::text, 7, '0') END,
       st.pack, st.sent, st.acc, st.answ, CASE WHEN st.sent IS NOT NULL THEN st.due END,
       CASE WHEN so.send_out_id IS NULL THEN NULL WHEN st.answ IS NOT NULL THEN 'resulted'
            WHEN st.acc IS NOT NULL THEN 'accepted' WHEN st.sent IS NOT NULL THEN 'sent' ELSE 'packed' END
  FROM st JOIN ord AS o USING (order_id) JOIN os USING (order_id) LEFT JOIN so USING (order_test_id)
$$;

-- Order n (1-14 000, in time order) at load_epoch: a lookup over the one pass
-- (about 45 s a call; a file calls lab_order_tests once).
CREATE FUNCTION pg_temp.lab_order(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (account_id integer, client_ref text, priority text, animal_id integer, consultation_id integer,
                 requested_by integer, patient_ref text, client_surname text, species text, sex text,
                 born_on date, microchip text, ueln text, ear_tag text, withdrawal_ends_on date,
                 ordered_at timestamptz, received_at timestamptz, completed_at timestamptz,
                 cancelled_at timestamptz, state text, tests text[])
  LANGUAGE sql IMMUTABLE AS $$
SELECT account_id, client_ref, priority, animal_id, consultation_id, requested_by, patient_ref, client_surname,
       species, sex, born_on, microchip, ueln, ear_tag, withdrawal_ends_on, ordered_at, received_at,
       completed_at, order_cancelled_at, order_state, array_agg(code ORDER BY test_position)
  FROM pg_temp.lab_order_tests(load_epoch, utc_offset) WHERE order_id = n
 GROUP BY account_id, client_ref, priority, animal_id, consultation_id, requested_by, patient_ref, client_surname,
          species, sex, born_on, microchip, ueln, ear_tag, withdrawal_ends_on, ordered_at, received_at,
          completed_at, order_cancelled_at, order_state
$$;

-- Send-out n (in packing order) at load_epoch, the same lookup.
CREATE FUNCTION pg_temp.lab_send_out(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (order_test_id integer, order_id integer, send_key uuid, xlab_accession text, label text,
                 test_code text, packed_at timestamptz, sent_at timestamptz, accepted_at timestamptz,
                 answered_at timestamptz, due_by timestamptz, status text)
  LANGUAGE sql IMMUTABLE AS $$
SELECT t.order_test_id, t.order_id, t.send_key, t.xlab_accession, t.label, c.external_code, t.packed_at,
       t.sent_at, t.accepted_at, t.answered_at, t.due_by, t.send_status
  FROM pg_temp.lab_order_tests(load_epoch, utc_offset) AS t JOIN pg_temp.lab_catalogue() AS c ON c.id = t.test_id
 WHERE t.send_out_id = n
$$;

-- A practice delivery (purpose 2's, vet-lab-practice-results): its
-- delivery_key, one per order, kind and revision, kept across attempts
-- (clinic-purposes.md 3), and its times from the event it reports (a release,
-- the order's completion, an amendment): posted 1 to 3 minutes after, one
-- attempt in fifty failing first (a 503) and retried 5 minutes after.
CREATE FUNCTION pg_temp.lab_delivery(accession integer, kind text, revision integer, event_at timestamptz)
  RETURNS TABLE (delivery_key text, attempts integer, first_at timestamptz, posted_at timestamptz,
                 acknowledged_at timestamptz)
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT md5('vet-lab-delivery:' || accession || ':' || kind || ':' || revision)::uuid::text,
       CASE WHEN u2 < 0.02 THEN 2 ELSE 1 END,
       event_at + (1 + 2 * u1) * interval '1 minute',
       event_at + (1 + 2 * u1) * interval '1 minute' + CASE WHEN u2 < 0.02 THEN interval '5 minutes' ELSE interval '0' END,
       event_at + (1 + 2 * u1) * interval '1 minute' + CASE WHEN u2 < 0.02 THEN interval '5 minutes' ELSE interval '0' END
       + (0.2 + 1.8 * u2) * interval '1 second'
  FROM (SELECT pg_temp.lab_u(accession::bigint * 64 + revision * 4 + length(kind), 40) AS u1,
               pg_temp.lab_u(accession::bigint * 64 + revision * 4 + length(kind), 41) AS u2) AS x
$$;
