-- history.sql of vet-antimicrobial-use (v0.5 master spec 12.1 item 5, 12.2
-- purpose 8; clinic-purposes.md 12, "`office` at T0"; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md, "The planted periods"): the daily use and
-- last year's report, planted in office before T0 exactly as the jobs would
-- have written them. load-data runs it in the target (office) after the
-- domains' loads, as postgres, unseen, reading the record through
-- gm_src_source (postgres_fdw as gm_check; never the standby), with
-- load_epoch.
--
-- From the history's first use: the feeder's day d when d + 1 at 02:00
-- (local) is before load_epoch; each year's report when its 15 January at
-- 04:00 is, for the species due that day (cattle; the others from mid-2027
-- and mid-2030, the report's options), acknowledged by the authority with
-- its stub's reference, AMU<year>-NNNN (D451), and copied into
-- regulatory_submissions. Each run its runs row, its outputs carrying it.
-- The same computations as the jobs' queries (material/runner/queries.yaml),
-- over the source's foreign tables.
CREATE TEMP TABLE h_settings AS
SELECT b.timezone AS tz, :'load_epoch'::timestamptz AS epoch,
       (SELECT s.code FROM gm_src_source.sites s WHERE s.kind = 'own') AS site
  FROM gm_src_source.business_settings b;

CREATE TEMP TABLE h_uses AS
WITH herd_species AS (
  SELECT herd_id, min(species) AS species FROM gm_src_source.animals WHERE herd_id IS NOT NULL GROUP BY herd_id)
SELECT (u.at AT TIME ZONE s.tz)::date AS day, u.*
  FROM h_settings s, (
    SELECT an.species, m.atcvet_code, 'administration'::text AS use, a.given_at AS at, a.quantity, a.animal_id,
           NULL::integer AS herd_id
      FROM gm_src_source.administrations a
      JOIN gm_src_source.medicines m ON m.id = a.medicine_id
      JOIN gm_src_source.animals an ON an.id = a.animal_id
     WHERE m.antimicrobial AND a.state = 'given'
    UNION ALL
    SELECT coalesce(an.species, hs.species), m.atcvet_code, 'dispensing', d.dispensed_at, d.quantity, p.animal_id,
           p.herd_id
      FROM gm_src_source.dispensings d
      JOIN gm_src_source.prescription_lines l ON l.id = d.prescription_line_id
      JOIN gm_src_source.prescriptions p ON p.id = l.prescription_id
      JOIN gm_src_source.medicines m ON m.id = l.medicine_id
      LEFT JOIN gm_src_source.animals an ON an.id = p.animal_id
      LEFT JOIN herd_species hs ON hs.herd_id = p.herd_id
     WHERE m.antimicrobial) u;

CREATE TEMP TABLE h_daily AS
SELECT day, species, atcvet_code, count(*) FILTER (WHERE use = 'administration')::int AS administrations,
       count(*) FILTER (WHERE use = 'dispensing')::int AS dispensings, sum(quantity) AS quantity,
       count(DISTINCT animal_id)::int AS animals_treated, count(DISTINCT herd_id)::int AS herds_treated
  FROM h_uses GROUP BY day, species, atcvet_code;

-- The feeder's runs, one a day from the history's first use.
CREATE TEMP TABLE h_feeds AS
SELECT g::date AS day, ((g::date + 1) + time '02:00') AT TIME ZONE s.tz AS started_at
  FROM h_settings s,
       generate_series((SELECT min(day) FROM h_uses), (s.epoch AT TIME ZONE s.tz)::date, interval '1 day') g
 WHERE ((g::date + 1) + time '02:00') AT TIME ZONE s.tz < s.epoch;
CREATE TEMP TABLE h_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-antimicrobial-use', 'feed-antimicrobial-use', f.started_at, f.started_at + interval '2 seconds',
         coalesce(n.n, 0), coalesce(n.n, 0)
    FROM h_feeds f LEFT JOIN (SELECT day, count(*)::int AS n FROM h_daily GROUP BY day) n USING (day)
   ORDER BY f.day
  RETURNING id, started_at)
SELECT f.day, r.id FROM r JOIN h_feeds f USING (started_at);
INSERT INTO antimicrobial_use (day, species, atcvet_code, administrations, dispensings, quantity, animals_treated,
                               herds_treated, run_id)
SELECT d.day, d.species, d.atcvet_code, d.administrations, d.dispensings, d.quantity, d.animals_treated,
       d.herds_treated, r.id
  FROM h_daily d JOIN h_runs r USING (day)
 ORDER BY d.day, d.species, d.atcvet_code;

-- Each year's report, sent on 15 January at 04:00 for the year before, for
-- the species due that day, summed from the planted daily rows.
CREATE TEMP TABLE h_reports AS
SELECT y.year, sp.species, y.sent_at, make_date(extract(year FROM y.year)::int + 1, 1, 31) AS deadline,
       jsonb_build_object('report_key', 'amu-' || extract(year FROM y.year) || '-' || sp.species,
                          'year', extract(year FROM y.year)::int, 'species', sp.species, 'centre', s.site,
                          'lines', coalesce((
         SELECT jsonb_agg(jsonb_build_object('atcvet_code', a.atcvet_code, 'administrations', a.administrations,
                                             'dispensings', a.dispensings, 'quantity', a.quantity,
                                             'animals_treated', a.animals_treated, 'herds_treated', a.herds_treated)
                          ORDER BY a.atcvet_code)
           FROM (SELECT atcvet_code, sum(administrations) AS administrations, sum(dispensings) AS dispensings,
                        sum(quantity)::float8 AS quantity, sum(animals_treated) AS animals_treated,
                        sum(herds_treated) AS herds_treated
                   FROM antimicrobial_use
                  WHERE species = sp.species AND day >= y.year AND day < (y.year + interval '1 year')::date
                  GROUP BY atcvet_code) a), '[]'::jsonb)) AS payload,
       (SELECT count(*)::int FROM antimicrobial_use
         WHERE species = sp.species AND day >= y.year AND day < (y.year + interval '1 year')::date) AS n_read
  FROM h_settings s,
       LATERAL (SELECT make_date(extract(year FROM g)::int - 1, 1, 1) AS year,
                       (g::date + time '04:00') AT TIME ZONE s.tz AS sent_at
                  FROM generate_series(make_date(extract(year FROM (SELECT min(day) FROM h_uses))::int + 1, 1, 15),
                                       (s.epoch AT TIME ZONE s.tz)::date, interval '1 year') g) y,
       (VALUES ('cattle', date '2024-01-01'), ('sheep', date '2027-07-01'), ('goat', date '2027-07-01'),
               ('horse', date '2027-07-01'), ('dog', date '2030-07-01'), ('cat', date '2030-07-01')) sp(species, due)
 WHERE y.sent_at < s.epoch AND sp.due <= (y.year + interval '1 year 14 days')::date;
CREATE TEMP TABLE h_report_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-antimicrobial-use', 'report-antimicrobial-use', sent_at, sent_at + interval '3 seconds', sum(n_read),
         2 * count(*)
    FROM h_reports GROUP BY sent_at ORDER BY sent_at
  RETURNING id, started_at)
SELECT id, started_at AS sent_at FROM r;
-- The authority's references as its stub gives them live (D451):
-- AMU<year posted>-NNNN, NNNN its count of the reports it holds, so the
-- planted ones in the order posted (a run's species sorted, as the job
-- posts them).
CREATE TEMP TABLE h_refs AS
SELECT year, species,
       'AMU' || to_char(sent_at, 'YYYY') || '-' || lpad(row_number() OVER (ORDER BY sent_at, species)::text, 4, '0')
         AS reference
  FROM h_reports;
INSERT INTO amu_reports (year, species, deadline, payload, sent_at, reference, acknowledged_at, escalated_at, run_id)
SELECT h.year, h.species, h.deadline, h.payload, h.sent_at, f.reference,
       h.sent_at + interval '2 seconds', NULL, r.id
  FROM h_reports h JOIN h_report_runs r USING (sent_at) JOIN h_refs f USING (year, species)
 ORDER BY h.year, h.species;
INSERT INTO regulatory_submissions (kind, source, ref, payload, sent_at, reference, copied_at, run_id)
SELECT 'amu-report', 'clinic', h.payload->>'report_key', h.payload, h.sent_at, f.reference,
       h.sent_at + interval '2 seconds', r.id
  FROM h_reports h JOIN h_report_runs r USING (sent_at) JOIN h_refs f USING (year, species)
 ORDER BY h.year, h.species;

DROP TABLE h_refs, h_report_runs, h_reports, h_runs, h_feeds, h_daily, h_uses, h_settings;
