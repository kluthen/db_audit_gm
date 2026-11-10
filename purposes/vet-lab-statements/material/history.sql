-- history.sql of vet-lab-statements (v0.5 master spec 12.1 item 5, 12.2
-- purpose 10; clinic-purposes.md 14, "`office` at T0"; vet-lab rule 13;
-- capture W4 item 5 of specs/versions/v0.5/wave-log.md, "The planted
-- periods"): the year's charge lines and every month's statements, planted in
-- office before T0 exactly as the jobs would have written them. load-data
-- runs it in the target (office) after the domains' loads, as postgres,
-- unseen, reading the lab through gm_src_source (postgres_fdw as gm_check),
-- with load_epoch.
--
-- From the history's first charge event: the feeder's day d when d + 1 at
-- 02:30 (local) is before load_epoch; each month's statements when its next
-- 1st at 04:00 is, one per practice account with lines. Each run its runs
-- row, its outputs carrying it. The same computations as the jobs' queries
-- (material/runner/queries.yaml), over the source's foreign tables.
CREATE TEMP TABLE h_settings AS
SELECT l.timezone AS tz, :'load_epoch'::timestamptz AS epoch FROM gm_src_source.lab_settings l;

-- Every charge event of a practice's account: made billable on billable_on,
-- voided on voided_at's local date.
CREATE TEMP TABLE h_events AS
SELECT e.day, c.id AS charge_id, e.event, c.account_id, c.order_id, c.order_test_id, t.code AS test_code, c.kind,
       c.amount, o.patient_ref, o.client_surname
  FROM h_settings s
  CROSS JOIN gm_src_source.lab_charges c
  JOIN gm_src_source.lab_accounts a ON a.id = c.account_id
  JOIN gm_src_source.lab_orders o ON o.id = c.order_id
  LEFT JOIN gm_src_source.lab_order_tests ot ON ot.id = c.order_test_id
  LEFT JOIN gm_src_source.lab_tests t ON t.id = ot.test_id
  CROSS JOIN LATERAL (
    SELECT c.billable_on AS day, 'billable'::text AS event WHERE c.billable_on IS NOT NULL
    UNION ALL
    SELECT (c.voided_at AT TIME ZONE s.tz)::date, 'void' WHERE c.voided_at IS NOT NULL) e
 WHERE a.kind = 'practice';

-- The feeder's runs, one a day from the history's first event.
CREATE TEMP TABLE h_feeds AS
SELECT g::date AS day, ((g::date + 1) + time '02:30') AT TIME ZONE s.tz AS started_at
  FROM h_settings s,
       generate_series((SELECT min(day) FROM h_events), (s.epoch AT TIME ZONE s.tz)::date, interval '1 day') g
 WHERE ((g::date + 1) + time '02:30') AT TIME ZONE s.tz < s.epoch;
CREATE TEMP TABLE h_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-lab-statements', 'feed-lab-charges', f.started_at, f.started_at + interval '2 seconds',
         coalesce(n.n, 0), coalesce(n.n, 0)
    FROM h_feeds f LEFT JOIN (SELECT day, count(*)::int AS n FROM h_events GROUP BY day) n USING (day)
   ORDER BY f.day
  RETURNING id, started_at)
SELECT f.day, r.id FROM r JOIN h_feeds f USING (started_at);
INSERT INTO lab_charge_lines (day, event, charge_id, account_id, order_id, order_test_id, test_code, kind, amount,
                              patient_ref, client_surname, run_id)
SELECT e.day, e.event, e.charge_id, e.account_id, e.order_id, e.order_test_id, e.test_code, e.kind, e.amount,
       e.patient_ref, e.client_surname, r.id
  FROM h_events e JOIN h_runs r USING (day)
 ORDER BY e.day, e.charge_id, e.event;

-- The months' statements, from the planted lines (charges.close.compute).
CREATE TEMP TABLE h_closes AS
SELECT m.month, ((m.month + interval '1 month')::date + time '04:00') AT TIME ZONE s.tz AS started_at
  FROM h_settings s, (SELECT DISTINCT date_trunc('month', day)::date AS month FROM h_feeds) m
 WHERE ((m.month + interval '1 month')::date + time '04:00') AT TIME ZONE s.tz < s.epoch;
CREATE TEMP TABLE h_statements AS
SELECT c.month, x.account_id, x.lines, x.billable, x.voided, x.billable - x.voided AS total, b.pct,
       round((x.billable - x.voided) * b.pct / 100, 2) AS discount,
       (x.billable - x.voided) - round((x.billable - x.voided) * b.pct / 100, 2) AS due,
       x.n_read
  FROM h_closes c
  CROSS JOIN LATERAL (
    SELECT l.account_id, count(*) FILTER (WHERE l.event = 'billable')::int AS lines,
           coalesce(sum(l.amount) FILTER (WHERE l.event = 'billable'), 0) AS billable,
           coalesce(sum(l.amount) FILTER (WHERE l.event = 'void' AND EXISTS (
             SELECT 1 FROM lab_charge_lines p WHERE p.charge_id = l.charge_id AND p.event = 'billable'
                AND p.day < (c.month + interval '1 month')::date)), 0) AS voided,
           count(*)::int AS n_read
      FROM lab_charge_lines l
     WHERE l.day >= c.month AND l.day < (c.month + interval '1 month')::date
     GROUP BY l.account_id) x
  CROSS JOIN LATERAL (SELECT pct FROM (VALUES (0, 3), (200, 5), (400, 10), (600, 15)) br (from_total, pct)
                       WHERE from_total <= greatest(x.billable - x.voided, 0) ORDER BY from_total DESC LIMIT 1) b;
CREATE TEMP TABLE h_close_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-lab-statements', 'close-lab-statements', c.started_at, c.started_at + interval '2 seconds',
         coalesce(n.r, 0), coalesce(n.n, 0)
    FROM h_closes c
    LEFT JOIN (SELECT month, sum(n_read)::int AS r, count(*)::int AS n FROM h_statements GROUP BY month) n USING (month)
   ORDER BY c.month
  RETURNING id, started_at)
SELECT c.month, r.id FROM r JOIN h_closes c USING (started_at);
INSERT INTO lab_statements (month, account_id, lines, billable, voided, total, discount_pct, discount, due, run_id)
SELECT h.month, h.account_id, h.lines, h.billable, h.voided, h.total, h.pct, h.discount, h.due, r.id
  FROM h_statements h JOIN h_close_runs r USING (month)
 ORDER BY h.month, h.account_id;

DROP TABLE h_close_runs, h_statements, h_closes, h_runs, h_feeds, h_events, h_settings;
