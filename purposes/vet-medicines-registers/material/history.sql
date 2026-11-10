-- history.sql of vet-medicines-registers (v0.5 master spec 12.1 item 5,
-- 12.2 purpose 7; clinic-purposes.md 11, "`office` at T0"; capture W4 item 5
-- of specs/versions/v0.5/wave-log.md, "The planted periods"): the registers'
-- past, planted in office before T0 exactly as the jobs would have written
-- it. load-data runs it in the target (office) after the domains' loads, as
-- postgres, unseen, reading the record through gm_src_source (postgres_fdw as
-- gm_check; never the standby), with load_epoch.
--
-- From the history's first supply: a feeder's day d when d + 1 at its hour
-- (01:30 the supplies, 01:45 the controlled movements; local) is before
-- load_epoch; a month's extract (03:00) and balances (03:15) when the next
-- month's 1st at that hour is; an inventory (03:30) for each 1 January
-- whose run is, after a planted December. Each run its runs row, its outputs
-- carrying it. The same computations as the jobs' queries (material/runner/
-- queries.yaml), over the source's foreign tables.
CREATE TEMP TABLE h_settings AS
SELECT b.timezone AS tz, :'load_epoch'::timestamptz AS epoch,
       (SELECT s.name FROM gm_src_source.sites s WHERE s.kind = 'own') AS centre,
       (SELECT v.name FROM gm_src_source.staff v WHERE v.kind = 'vet' AND v.left_on IS NULL
         ORDER BY v.id LIMIT 1) AS signer
  FROM gm_src_source.business_settings b;

-- Every supply of the history: each dispensing and each dose given.
CREATE TEMP TABLE h_supplies AS
SELECT (x.supplied_at AT TIME ZONE s.tz)::date AS day, x.*
  FROM h_settings s, (
    SELECT 'dispensing'::text AS supply, d.id AS supply_id, d.dispensed_at AS supplied_at,
           m.id AS medicine_id, m.name AS product, m.form, m.authorisation_number, m.controlled,
           d.batch_id, b.batch_number, d.quantity, o.name AS recipient, o.address AS recipient_address,
           v.name AS prescribing_vet
      FROM gm_src_source.dispensings d
      JOIN gm_src_source.prescription_lines l ON l.id = d.prescription_line_id
      JOIN gm_src_source.prescriptions p ON p.id = l.prescription_id
      JOIN gm_src_source.medicines m ON m.id = l.medicine_id
      JOIN gm_src_source.medicine_batches b ON b.id = d.batch_id
      JOIN gm_src_source.owners o ON o.id = d.owner_id
      JOIN gm_src_source.staff v ON v.id = p.vet_id
    UNION ALL
    SELECT 'administration', a.id, a.given_at, m.id, m.name, m.form, m.authorisation_number, m.controlled,
           a.batch_id, b.batch_number, a.quantity, NULL, NULL, v.name
      FROM gm_src_source.administrations a
      JOIN gm_src_source.prescription_lines l ON l.id = a.prescription_line_id
      JOIN gm_src_source.prescriptions p ON p.id = l.prescription_id
      JOIN gm_src_source.medicines m ON m.id = a.medicine_id
      LEFT JOIN gm_src_source.medicine_batches b ON b.id = a.batch_id
      JOIN gm_src_source.staff v ON v.id = p.vet_id
     WHERE a.state = 'given') x;
UPDATE h_supplies SET recipient = (SELECT centre FROM h_settings) WHERE supply = 'administration';
CREATE INDEX ON h_supplies (day);

-- The controlled batches as received.
CREATE TEMP TABLE h_batches AS
SELECT b.id AS batch_id, m.id AS medicine_id, b.batch_number, b.quantity_received
  FROM gm_src_source.medicine_batches b JOIN gm_src_source.medicines m ON m.id = b.medicine_id
 WHERE m.controlled;

-- The days and months, from the history's first supply to load_epoch.
CREATE TEMP TABLE h_days AS
SELECT g::date AS day
  FROM h_settings s,
       generate_series((SELECT min(day) FROM h_supplies), (s.epoch AT TIME ZONE s.tz)::date, interval '1 day') g;
CREATE TEMP TABLE h_months AS
SELECT DISTINCT date_trunc('month', day)::date AS month FROM h_days;

-- A run: its row, started at its date's hour (local), a few seconds long.
CREATE TEMP TABLE h_runs (job text, period date, id bigint);
CREATE FUNCTION pg_temp.h_plant(p_job text, p_at time, p_periods date[], p_run_on date[], p_read int[],
                                p_written int[]) RETURNS void LANGUAGE sql AS $$
  WITH r AS (
    INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
    SELECT 'vet-medicines-registers', p_job, (q.run_on + p_at) AT TIME ZONE s.tz,
           (q.run_on + p_at) AT TIME ZONE s.tz + interval '3 seconds', q.n_read, q.n_written
      FROM h_settings s, unnest(p_periods, p_run_on, p_read, p_written) AS q(period, run_on, n_read, n_written)
     WHERE (q.run_on + p_at) AT TIME ZONE s.tz < s.epoch
     ORDER BY q.run_on
    RETURNING id, started_at)
  INSERT INTO h_runs
  SELECT p_job, q.period, r.id
    FROM r, h_settings s, unnest(p_periods, p_run_on) AS q(period, run_on)
   WHERE r.started_at = (q.run_on + p_at) AT TIME ZONE s.tz;
$$;

-- The feeders: a day each.
SELECT pg_temp.h_plant('feed-medicines-register', time '01:30', array_agg(d.day ORDER BY d.day),
                       array_agg(d.day + 1 ORDER BY d.day), array_agg(coalesce(n.n, 0)::int ORDER BY d.day),
                       array_agg(coalesce(n.n, 0)::int ORDER BY d.day))
  FROM h_days d LEFT JOIN (SELECT day, count(*) AS n FROM h_supplies GROUP BY day) n USING (day);
SELECT pg_temp.h_plant('feed-controlled-drugs', time '01:45', array_agg(d.day ORDER BY d.day),
                       array_agg(d.day + 1 ORDER BY d.day), array_agg(coalesce(n.n, 0)::int ORDER BY d.day),
                       array_agg(coalesce(n.n, 0)::int ORDER BY d.day))
  FROM h_days d LEFT JOIN (SELECT day, count(*) AS n FROM h_supplies WHERE controlled GROUP BY day) n USING (day);

INSERT INTO medicines_register (day, supply, supply_id, supplied_at, medicine_id, product, form,
                                authorisation_number, batch_number, quantity, recipient, recipient_address,
                                prescribing_vet, run_id)
SELECT x.day, x.supply, x.supply_id, x.supplied_at, x.medicine_id, x.product, x.form, x.authorisation_number,
       x.batch_number, x.quantity, x.recipient, x.recipient_address, x.prescribing_vet, r.id
  FROM h_supplies x JOIN h_runs r ON r.job = 'feed-medicines-register' AND r.period = x.day
 ORDER BY x.day, x.supply, x.supply_id;
INSERT INTO controlled_movements (day, movement, movement_id, moved_at, medicine_id, batch_id, batch_number,
                                  quantity, run_id)
SELECT x.day, x.supply, x.supply_id, x.supplied_at, x.medicine_id, x.batch_id, x.batch_number, x.quantity, r.id
  FROM h_supplies x JOIN h_runs r ON r.job = 'feed-controlled-drugs' AND r.period = x.day
 WHERE x.controlled
 ORDER BY x.day, x.supply, x.supply_id;

-- The months' extracts, from the planted register.
CREATE TEMP TABLE h_extracts AS
SELECT date_trunc('month', day)::date AS month, medicine_id, min(product) AS product, count(*)::int AS lines,
       sum(quantity) AS quantity,
       md5(string_agg(supply || ':' || supply_id || ':' || quantity, ',' ORDER BY supply, supply_id)) AS checksum
  FROM medicines_register GROUP BY 1, 2;
SELECT pg_temp.h_plant('close-medicines-register', time '03:00', array_agg(m.month ORDER BY m.month),
                       array_agg((m.month + interval '1 month')::date ORDER BY m.month),
                       array_agg(coalesce(n.n, 0)::int ORDER BY m.month), array_agg(coalesce(n.n, 0)::int ORDER BY m.month))
  FROM h_months m LEFT JOIN (SELECT month, count(*) AS n FROM h_extracts GROUP BY month) n USING (month);
INSERT INTO register_extracts (month, medicine_id, product, lines, quantity, checksum, run_id)
SELECT e.month, e.medicine_id, e.product, e.lines, e.quantity, e.checksum, r.id
  FROM h_extracts e JOIN h_runs r ON r.job = 'close-medicines-register' AND r.period = e.month
 ORDER BY e.month, e.medicine_id;

-- The months' balances: a batch's opening the quantity received less the
-- movements before the month (the previous closing), its closing the
-- opening less the month's.
CREATE TEMP TABLE h_balances AS
SELECT m.month, b.medicine_id, b.batch_id, b.batch_number,
       b.quantity_received - coalesce(before.q, 0) AS opening, coalesce(during.q, 0) AS movements,
       b.quantity_received - coalesce(before.q, 0) - coalesce(during.q, 0) AS closing
  FROM h_months m CROSS JOIN h_batches b
  LEFT JOIN LATERAL (SELECT sum(c.quantity) AS q FROM controlled_movements c
                      WHERE c.batch_id = b.batch_id AND c.day < m.month) before ON true
  LEFT JOIN LATERAL (SELECT sum(c.quantity) AS q FROM controlled_movements c
                      WHERE c.batch_id = b.batch_id AND c.day >= m.month
                        AND c.day < (m.month + interval '1 month')::date) during ON true;
SELECT pg_temp.h_plant('balance-controlled-drugs', time '03:15', array_agg(m.month ORDER BY m.month),
                       array_agg((m.month + interval '1 month')::date ORDER BY m.month),
                       array_agg((SELECT count(*) FROM h_batches)::int ORDER BY m.month),
                       array_agg((SELECT count(*) FROM h_batches)::int ORDER BY m.month))
  FROM h_months m;
INSERT INTO controlled_balances (month, medicine_id, batch_id, batch_number, opening, movements, closing,
                                 signed_by, run_id)
SELECT b.month, b.medicine_id, b.batch_id, b.batch_number, b.opening, b.movements, b.closing, s.signer, r.id
  FROM h_balances b JOIN h_runs r ON r.job = 'balance-controlled-drugs' AND r.period = b.month
 CROSS JOIN h_settings s
 ORDER BY b.month, b.batch_id;

-- The inventories: each 1 January after a planted December.
SELECT pg_temp.h_plant('inventory-controlled-drugs', time '03:30', array_agg(y ORDER BY y), array_agg(y ORDER BY y),
                       array_agg((SELECT count(*) FROM h_batches)::int ORDER BY y),
                       array_agg((SELECT count(*) FROM h_batches)::int ORDER BY y))
  FROM (SELECT (month + interval '1 month')::date AS y FROM h_months WHERE extract(month FROM month) = 12) j;
INSERT INTO controlled_inventories (year, medicine_id, batch_id, batch_number, counted, run_id)
SELECT r.period, c.medicine_id, c.batch_id, c.batch_number, c.closing, r.id
  FROM h_runs r JOIN controlled_balances c ON c.month = (r.period - interval '1 month')::date
 WHERE r.job = 'inventory-controlled-drugs'
 ORDER BY r.period, c.batch_id;

DROP FUNCTION pg_temp.h_plant(text, time, date[], date[], int[], int[]);
DROP TABLE h_runs, h_months, h_days, h_batches, h_supplies, h_settings, h_extracts, h_balances;
