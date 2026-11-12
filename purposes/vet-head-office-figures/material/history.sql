-- history.sql of vet-head-office-figures (v0.5 master spec 12.1 item 5, 12.2
-- purpose 9; clinic-purposes.md 13, "`office` at T0"; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md, "The planted periods"): the year's daily
-- figures and every month sent to the head office, planted in office before
-- T0 exactly as the jobs would have written them. load-data runs it in the
-- target (office) after the domains' loads, as postgres, unseen, reading the
-- record through gm_src_source and the lab through gm_src_source_lab
-- (postgres_fdw as gm_check; never the standby), with load_epoch.
--
-- From the history's first consultation: the feeder's day d when d + 1 at
-- 00:30 (local) is before load_epoch; each month's figures when its next 1st
-- at 05:00 is, acknowledged by the head office at the first attempt with its
-- stub's reference, HO<YYYYMM>-NNNN (D451). Each run its runs row, its
-- outputs carrying it. The same computations as the jobs' queries
-- (material/runner/queries.yaml), over local copies of the sources' foreign
-- tables.
CREATE TEMP TABLE h_settings AS
SELECT b.timezone AS tz, :'load_epoch'::timestamptz AS epoch FROM gm_src_source.business_settings b;

CREATE TEMP TABLE h_sections AS
SELECT sc.id, sc.kind FROM gm_src_source.sections sc JOIN gm_src_source.sites si ON si.id = sc.site_id
 WHERE si.kind = 'own';
CREATE TEMP TABLE h_consultations AS SELECT section_id, kind, started_at FROM gm_src_source.consultations;
CREATE TEMP TABLE h_stays AS SELECT section_id, admitted_at, discharged_at FROM gm_src_source.stays;
CREATE TEMP TABLE h_placements AS
SELECT u.section_id, p.from_at, p.until_at FROM gm_src_source.housing_placements p
  JOIN gm_src_source.housing_units u ON u.id = p.unit_id;
CREATE TEMP TABLE h_units AS SELECT section_id, state, state_since_at FROM gm_src_source.housing_units;
CREATE TEMP TABLE h_registered AS
SELECT 'owners.new'::text AS measure, registered_at FROM gm_src_source.owners
UNION ALL SELECT 'animals.new', registered_at FROM gm_src_source.animals;
CREATE TEMP TABLE h_lab_tests AS
SELECT 'tests.' || t.discipline || '.' || o.priority AS measure, ot.status, ot.released_at, o.received_at,
       a.kind AS account_kind
  FROM gm_src_source_lab.lab_order_tests ot JOIN gm_src_source_lab.lab_orders o ON o.id = ot.order_id
  JOIN gm_src_source_lab.lab_tests t ON t.id = ot.test_id JOIN gm_src_source_lab.lab_accounts a ON a.id = o.account_id
 WHERE ot.released_at IS NOT NULL;
CREATE TEMP TABLE h_lab_orders AS
SELECT o.ordered_at FROM gm_src_source_lab.lab_orders o JOIN gm_src_source_lab.lab_accounts a ON a.id = o.account_id
 WHERE a.kind = 'practice';
CREATE TEMP TABLE h_lab_grid AS
SELECT DISTINCT 'tests.' || t.discipline || '.' || p.priority AS measure
  FROM gm_src_source_lab.lab_tests t CROSS JOIN (VALUES ('routine'), ('urgent')) p (priority);

-- The feeder's runs, one a day from the history's first consultation, with
-- the day's bounds.
CREATE TEMP TABLE h_feeds AS
SELECT g::date AS day, ((g::date + 1) + time '00:30') AT TIME ZONE s.tz AS started_at,
       g::date::timestamp AT TIME ZONE s.tz AS lo, (g::date + 1)::timestamp AT TIME ZONE s.tz AS hi
  FROM h_settings s,
       generate_series((SELECT min((started_at AT TIME ZONE s2.tz)::date) FROM h_consultations, h_settings s2),
                       (s.epoch AT TIME ZONE s.tz)::date, interval '1 day') g
 WHERE ((g::date + 1) + time '00:30') AT TIME ZONE s.tz < s.epoch;

-- The day's events counted per local day (the same counts as the feeder's
-- queries'), then every day's grid: the record's and housing's measures per
-- section (the stocks at the day's closing midnight), the centre's, the
-- lab's (each discipline and priority, the outside orders, their median
-- turnaround).
CREATE TEMP TABLE h_events AS
SELECT (x.at AT TIME ZONE s.tz)::date AS day, x.section_id, x.measure, count(*) AS n
  FROM h_settings s, (
    SELECT section_id, 'consultations.' || kind AS measure, started_at AS at FROM h_consultations
    UNION ALL SELECT section_id, 'admissions', admitted_at FROM h_stays
    UNION ALL SELECT section_id, 'discharges', discharged_at FROM h_stays WHERE discharged_at IS NOT NULL
    UNION ALL SELECT NULL, measure, registered_at FROM h_registered
    UNION ALL SELECT NULL, measure, released_at FROM h_lab_tests
    UNION ALL SELECT NULL, 'orders.outside', ordered_at FROM h_lab_orders) x
 GROUP BY 1, 2, 3;
CREATE INDEX ON h_events (day, measure);
CREATE TEMP TABLE h_turnaround AS
SELECT (x.released_at AT TIME ZONE s.tz)::date AS day,
       round((percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM x.released_at - x.received_at) / 60))::numeric,
             2) AS value
  FROM h_settings s, h_lab_tests x
 WHERE x.account_kind = 'practice' AND x.status = 'released' AND x.received_at IS NOT NULL
 GROUP BY 1;

CREATE TEMP TABLE h_daily AS
SELECT f.day, sec.kind AS section, m.measure,
       (CASE m.measure
          WHEN 'stays.midnight' THEN (SELECT count(*) FROM h_stays x WHERE x.section_id = sec.id
                                         AND x.admitted_at < f.hi AND (x.discharged_at IS NULL OR x.discharged_at >= f.hi))
          WHEN 'units.occupied' THEN (SELECT count(*) FROM h_placements x WHERE x.section_id = sec.id
                                         AND x.from_at < f.hi AND (x.until_at IS NULL OR x.until_at >= f.hi))
          WHEN 'units.in-service' THEN (SELECT count(*) FROM h_units x WHERE x.section_id = sec.id
                                           AND NOT (x.state = 'out-of-service' AND x.state_since_at <= f.hi))
          ELSE coalesce((SELECT e.n FROM h_events e WHERE e.day = f.day AND e.measure = m.measure
                            AND e.section_id = sec.id), 0)
        END)::numeric AS value
  FROM h_feeds f CROSS JOIN h_sections sec
  CROSS JOIN (VALUES ('consultations.scheduled'), ('consultations.emergency'), ('consultations.herd-visit'),
                     ('consultations.in-hospital'), ('admissions'), ('discharges'), ('stays.midnight'),
                     ('units.occupied'), ('units.in-service')) m (measure)
UNION ALL
SELECT f.day, 'centre', m.measure,
       coalesce((SELECT e.n FROM h_events e WHERE e.day = f.day AND e.measure = m.measure), 0)::numeric
  FROM h_feeds f CROSS JOIN (VALUES ('owners.new'), ('animals.new')) m (measure)
UNION ALL
SELECT f.day, 'lab', g.measure,
       coalesce((SELECT e.n FROM h_events e WHERE e.day = f.day AND e.measure = g.measure), 0)::numeric
  FROM h_feeds f CROSS JOIN (SELECT measure FROM h_lab_grid UNION ALL SELECT 'orders.outside') g
UNION ALL
SELECT f.day, 'lab', 'turnaround.outside.median-minutes', t.value
  FROM h_feeds f LEFT JOIN h_turnaround t USING (day);

CREATE TEMP TABLE h_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-head-office-figures', 'feed-daily-figures', f.started_at, f.started_at + interval '2 seconds',
         n.n, n.n
    FROM h_feeds f JOIN (SELECT day, count(*)::int AS n FROM h_daily GROUP BY day) n USING (day)
   ORDER BY f.day
  RETURNING id, started_at)
SELECT f.day, r.id FROM r JOIN h_feeds f USING (started_at);
INSERT INTO daily_figures (day, section, measure, value, run_id)
SELECT d.day, d.section, d.measure, d.value, r.id
  FROM h_daily d JOIN h_runs r USING (day)
 ORDER BY d.day, d.section, d.measure;

-- Each month's figures, sent on its next 1st at 05:00, summed from the
-- planted daily rows (figures.send.compute), acknowledged at once.
CREATE TEMP TABLE h_sends AS
SELECT m.month, ((m.month + interval '1 month')::date + time '05:00') AT TIME ZONE s.tz AS sent_at
  FROM h_settings s, (SELECT DISTINCT date_trunc('month', day)::date AS month FROM h_feeds) m
 WHERE ((m.month + interval '1 month')::date + time '05:00') AT TIME ZONE s.tz < s.epoch;
CREATE TEMP TABLE h_months AS
SELECT c.month, d.section, d.measure,
       CASE WHEN starts_with(d.measure, 'turnaround.')
            THEN round((percentile_cont(0.5) WITHIN GROUP (ORDER BY d.value))::numeric, 2)
            ELSE sum(d.value) END AS value
  FROM h_sends c JOIN daily_figures d ON d.day >= c.month AND d.day < (c.month + interval '1 month')::date
 GROUP BY c.month, d.section, d.measure;
CREATE TEMP TABLE h_send_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-head-office-figures', 'send-monthly-figures', c.sent_at, c.sent_at + interval '3 seconds',
         coalesce(n.n, 0), coalesce(n.n, 0)
    FROM h_sends c LEFT JOIN (SELECT month, count(*)::int AS n FROM h_months GROUP BY month) n USING (month)
   ORDER BY c.month
  RETURNING id, started_at)
SELECT c.month, c.sent_at, r.id FROM r JOIN h_sends c ON c.sent_at = r.started_at;
-- The head office's references as its stub gives them live (D451):
-- HO<the figures' month, YYYYMM>-NNNN, NNNN its count of the months it holds,
-- so the planted months in the order posted.
INSERT INTO monthly_figures (month, section, measure, value, sent_at, reference, acknowledged_at, escalated_at, run_id)
SELECT m.month, m.section, m.measure, m.value, r.sent_at,
       'HO' || to_char(m.month, 'YYYYMM') || '-' || lpad(dense_rank() OVER (ORDER BY r.sent_at)::text, 4, '0'),
       r.sent_at + interval '2 seconds', NULL, r.id
  FROM h_months m JOIN h_send_runs r USING (month)
 ORDER BY m.month, m.section, m.measure;

DROP TABLE h_send_runs, h_months, h_sends, h_runs, h_daily, h_turnaround, h_events, h_feeds, h_lab_grid, h_lab_orders, h_lab_tests,
           h_registered, h_units, h_placements, h_stays, h_consultations, h_sections, h_settings;
