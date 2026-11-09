-- vet-lab-critical-calls: the DDL of its target, lab (purpose.yaml ddl.target;
-- v0.5 master spec 12.2 purpose 6; clinic-purposes.md section 10 and "The
-- roles the purposes add"; capture W4 items 0 and 3 of
-- specs/versions/v0.5/wave-log.md). Run by gmctl load-data at step (2b), as
-- postgres connected to the database the scenario maps the part to (vet-lab's,
-- :"DBNAME"), after every domain's load, unseen; read from the catalogue at
-- every load, never copied.
--
-- The lab's pg_cron lives in lab itself (W4 item 3): the node's seed
-- postgresql.conf preloads it with cron.database_name the lab's database,
-- cron.timezone the customer's and cron.log_run on, so this file creates the
-- extension here and schedules the watch in its own database. No runner.
--
-- 1. The ops schema, the same text in every purpose's DDL between the lines
--    "-- ops: begin" and "-- ops: end" (tools/tests/test_purposes.py).
-- 2. pg_cron, created here (cron.database_name names this database).
-- 3. lab_watch, the watch's role, LOGIN (pg_cron's background worker connects
--    as it), CONNECT granted by name (vet-lab revokes it from PUBLIC); it
--    reads the results, their calls and tests, and writes ops.incidents and
--    ops.runs (with the shared grants on ops).
-- 4. The watch, watch-critical-calls, scheduled as lab_watch every ten
--    minutes under pg_cron's job name lab-critical-calls: one set-based
--    statement writing an ops.incidents row for each critical result measured
--    more than 60 minutes ago with no read-back call and no incident yet, and
--    the run's ops.runs row, in one transaction.
-- ops: begin
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ops') THEN
CREATE ROLE ops NOLOGIN;   -- owns the purposes' tables
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS ops AUTHORIZATION ops;
REVOKE ALL ON SCHEMA ops FROM PUBLIC;
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.runs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purpose text NOT NULL, job text NOT NULL,
    started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL DEFAULT now(),
    rows_read integer NOT NULL DEFAULT 0, rows_written integer NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS runs_job_idx ON ops.runs (purpose, job, started_at);
CREATE TABLE IF NOT EXISTS ops.incidents (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purpose text NOT NULL, job text NOT NULL, kind text NOT NULL, ref text NOT NULL,
    opened_at timestamptz NOT NULL DEFAULT now(), reason text NOT NULL,
    run_id bigint REFERENCES ops.runs (id));
CREATE INDEX IF NOT EXISTS incidents_ref_idx ON ops.incidents (purpose, kind, ref);
CREATE TABLE IF NOT EXISTS ops.watermarks (
    purpose text NOT NULL, name text NOT NULL,
    at timestamptz, last_id bigint, run_id bigint REFERENCES ops.runs (id),
    PRIMARY KEY (purpose, name));
RESET ROLE;
-- ops: end

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $guard$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'lab_watch') THEN
CREATE ROLE lab_watch LOGIN;   -- the critical calls' pg_cron watch
END IF; END $guard$;
GRANT CONNECT ON DATABASE :"DBNAME" TO lab_watch;

GRANT SELECT ON lab_results, lab_critical_calls, lab_order_tests TO lab_watch;
GRANT USAGE ON SCHEMA ops TO lab_watch;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO lab_watch;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO lab_watch;

SELECT cron.schedule_in_database('lab-critical-calls', '*/10 * * * *', $job$
WITH due AS (
  SELECT r.id FROM lab_results AS r
   WHERE r.flag IN ('critical-low', 'critical-high')
     AND r.measured_at <= now() - interval '60 minutes' AND r.measured_at > now() - interval '7 days'
     AND NOT EXISTS (SELECT 1 FROM lab_critical_calls AS c WHERE c.result_id = r.id AND c.read_back)
     AND NOT EXISTS (SELECT 1 FROM ops.incidents AS i
                      WHERE i.purpose = 'vet-lab-critical-calls' AND i.kind = 'uncalled' AND i.ref = r.id::text)),
run AS (
  INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)
  SELECT 'vet-lab-critical-calls', 'watch-critical-calls', now(), count(*), count(*) FROM due
  RETURNING id)
INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)
SELECT 'vet-lab-critical-calls', 'watch-critical-calls', 'uncalled', due.id::text,
       'critical result not read back within 60 minutes: the on-call pathologist to call', run.id
  FROM due CROSS JOIN run
$job$, current_database(), 'lab_watch');
