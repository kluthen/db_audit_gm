-- history.sql of vet-working-time (v0.5 master spec 12.1 item 5, 12.2
-- purpose 12; vet-scheduling-domain.md, purpose 12 and "`office` at T0, the
-- part's share"; capture W4 item 5 of specs/versions/v0.5/wave-log.md, "The
-- planted periods"): the working-time record's past, planted in office before
-- T0 exactly as the jobs would have written it. load-data runs it in the
-- target (office) after the domains' loads, as postgres, unseen, reading the
-- record (the core's staff, vet-scheduling's shifts) through gm_src_source
-- (postgres_fdw as gm_check; never the standby), with load_epoch.
--
-- From the history's first shift: the feeder's day d when d + 1 at 09:30
-- (local) is before load_epoch; a month's close (05:00) when the next
-- month's 1st at that hour is. Each run its runs row, its outputs carrying
-- it. The same computations as the jobs' queries (material/runner/
-- queries.yaml), over the source's foreign tables.
CREATE TEMP TABLE h_settings AS
SELECT b.timezone AS tz, :'load_epoch'::timestamptz AS epoch,
       (SELECT st.min_rest_hours FROM gm_src_source.sched_settings st) AS min_rest
  FROM gm_src_source.business_settings b;

CREATE TEMP TABLE h_shifts AS
SELECT (sh.starts_at AT TIME ZONE s.tz)::date AS day, sh.id, sh.staff_id, sh.kind, sh.starts_at, sh.ends_at,
       sh.clocked_in_at, sh.clocked_out_at
  FROM h_settings s, gm_src_source.sched_shifts sh
 WHERE sh.starts_at < s.epoch;
CREATE INDEX ON h_shifts (staff_id, clocked_in_at);

-- The feeder's days, from the history's first shift.
CREATE TEMP TABLE h_feeds AS
SELECT g::date AS day, ((g::date + 1) + time '09:30') AT TIME ZONE s.tz AS started_at
  FROM h_settings s,
       generate_series((SELECT min(day) FROM h_shifts), (s.epoch AT TIME ZONE s.tz)::date, interval '1 day') g
 WHERE ((g::date + 1) + time '09:30') AT TIME ZONE s.tz < s.epoch;

CREATE TEMP TABLE h_days AS
SELECT x.day, x.staff_id, v.name AS staff_name, count(*)::int AS shifts,
       round(coalesce(sum(extract(epoch FROM x.ends_at - x.starts_at)) FILTER (WHERE x.kind <> 'on-call'), 0) / 3600, 2)
         AS planned_hours,
       round(coalesce(sum(extract(epoch FROM x.clocked_out_at - x.clocked_in_at)), 0) / 3600, 2) AS worked_hours,
       round(coalesce(sum(extract(epoch FROM x.clocked_out_at - x.clocked_in_at)) FILTER (WHERE x.kind = 'night'), 0)
             / 3600, 2) AS night_hours,
       count(*) FILTER (WHERE x.kind = 'on-call' AND x.clocked_in_at IS NOT NULL)::int AS call_outs
  FROM h_shifts x JOIN h_feeds f USING (day)
  LEFT JOIN gm_src_source.staff v ON v.id = x.staff_id
 GROUP BY x.day, x.staff_id, v.name;

CREATE TEMP TABLE h_rests AS
SELECT d.day, d.staff_id, d.id AS shift_id, p.id AS previous_shift_id,
       round(extract(epoch FROM d.clocked_in_at - p.clocked_out_at) / 3600, 2) AS rest_hours
  FROM h_shifts d JOIN h_feeds f USING (day)
 CROSS JOIN h_settings s
  JOIN LATERAL (SELECT q.id, q.clocked_out_at FROM h_shifts q
                 WHERE q.staff_id = d.staff_id AND q.kind <> 'on-call' AND q.clocked_in_at IS NOT NULL
                   AND q.clocked_in_at < d.clocked_in_at
                 ORDER BY q.clocked_in_at DESC LIMIT 1) p ON true
 WHERE d.clocked_in_at IS NOT NULL AND d.kind <> 'on-call' AND p.clocked_out_at IS NOT NULL
   AND d.clocked_in_at - p.clocked_out_at < make_interval(hours => s.min_rest);

CREATE TEMP TABLE h_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-working-time', 'feed-working-time', f.started_at, f.started_at + interval '2 seconds',
         coalesce(n.n, 0) + coalesce(b.n, 0), coalesce(n.n, 0) + coalesce(b.n, 0)
    FROM h_feeds f
    LEFT JOIN (SELECT day, count(*)::int AS n FROM h_days GROUP BY day) n USING (day)
    LEFT JOIN (SELECT day, count(*)::int AS n FROM h_rests GROUP BY day) b USING (day)
   ORDER BY f.day
  RETURNING id, started_at)
SELECT f.day, r.id FROM r JOIN h_feeds f USING (started_at);
INSERT INTO working_time_days (day, staff_id, staff_name, shifts, planned_hours, worked_hours, night_hours, call_outs,
                               run_id)
SELECT d.day, d.staff_id, coalesce(d.staff_name, 'staff ' || d.staff_id), d.shifts, d.planned_hours, d.worked_hours,
       d.night_hours, d.call_outs, r.id
  FROM h_days d JOIN h_runs r USING (day)
 ORDER BY d.day, d.staff_id;
INSERT INTO rest_breaches (day, staff_id, shift_id, previous_shift_id, rest_hours, run_id)
SELECT b.day, b.staff_id, b.shift_id, b.previous_shift_id, b.rest_hours, r.id
  FROM h_rests b JOIN h_runs r USING (day)
 ORDER BY b.day, b.staff_id, b.shift_id;

-- The months' closes, from the planted daily rows (worktime.close.compute).
CREATE TEMP TABLE h_closes AS
SELECT m.month, ((m.month + interval '1 month')::date + time '05:00') AT TIME ZONE s.tz AS started_at
  FROM h_settings s, (SELECT DISTINCT date_trunc('month', day)::date AS month FROM h_feeds) m
 WHERE ((m.month + interval '1 month')::date + time '05:00') AT TIME ZONE s.tz < s.epoch;
CREATE TEMP TABLE h_months AS
SELECT c.month, w.staff_id, min(w.staff_name) AS staff_name, sum(w.worked_hours) AS worked_hours,
       sum(w.night_hours) AS night_hours, sum(w.call_outs)::int AS call_outs,
       (SELECT count(*) FROM rest_breaches b WHERE b.staff_id = w.staff_id AND b.day >= c.month
           AND b.day < (c.month + interval '1 month')::date)::int AS breaches,
       round((SELECT sum(f.worked_hours) FROM working_time_days f
               WHERE f.staff_id = w.staff_id AND f.day >= (c.month - interval '3 months')::date
                 AND f.day < (c.month + interval '1 month')::date) * 7
             / ((c.month + interval '1 month')::date - (c.month - interval '3 months')::date), 2)
         AS average_weekly_hours
  FROM h_closes c JOIN working_time_days w ON w.day >= c.month AND w.day < (c.month + interval '1 month')::date
 GROUP BY c.month, w.staff_id;
CREATE TEMP TABLE h_close_runs AS
WITH r AS (
  INSERT INTO runs (purpose, job, started_at, finished_at, rows_read, rows_written)
  SELECT 'vet-working-time', 'close-working-time', c.started_at, c.started_at + interval '2 seconds',
         coalesce(n.n, 0), coalesce(n.n, 0)
    FROM h_closes c LEFT JOIN (SELECT month, count(*)::int AS n FROM h_months GROUP BY month) n USING (month)
   ORDER BY c.month
  RETURNING id, started_at)
SELECT c.month, r.id FROM r JOIN h_closes c USING (started_at);
INSERT INTO working_time_months (month, staff_id, staff_name, worked_hours, night_hours, call_outs, breaches,
                                 average_weekly_hours, run_id)
SELECT m.month, m.staff_id, m.staff_name, m.worked_hours, m.night_hours, m.call_outs, m.breaches,
       m.average_weekly_hours, r.id
  FROM h_months m JOIN h_close_runs r USING (month)
 ORDER BY m.month, m.staff_id;

DROP TABLE h_close_runs, h_months, h_closes, h_runs, h_rests, h_days, h_feeds, h_shifts, h_settings;
