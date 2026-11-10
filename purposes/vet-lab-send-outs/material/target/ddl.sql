-- vet-lab-send-outs: the DDL of its target, lab (purpose.yaml ddl.target;
-- v0.5 master spec 12.2 purpose 3; clinic-purposes.md section 7 and "The
-- roles the purposes add"; capture W4 items 0 and 3 of
-- specs/versions/v0.5/wave-log.md). Run by gmctl load-data at step (2b), as
-- postgres connected to the database the scenario maps the part to (vet-lab's,
-- :"DBNAME"), after every domain's load, unseen; read from the catalogue at
-- every load, never copied.
--
-- 1. The ops schema, the same text in every purpose's DDL between the lines
--    "-- ops: begin" and "-- ops: end" (tools/tests/test_purposes.py keeps it
--    byte-identical): guarded, so whichever purpose's DDL runs first in a
--    database creates it for all.
-- 2. The engine's role on lab is vet-lab's lab_dispatch, granted here, never
--    created (vet-lab's schema creates it, grants it CONNECT, the tests,
--    samples, orders and catalogue it reads, the send-outs and sent-out events
--    it writes): the ops tables, and the lab's UTC offset, so the chase acts
--    on the customer's own hours (08:00 to 19:59, Monday to Saturday, spec
--    D436; a grant beyond "The roles the purposes add", reported). The
--    purpose has no table of its own in lab (W4 item 3): lab_send_outs,
--    vet-lab's, is its ledger; its chases are ops.incidents rows.
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

GRANT USAGE ON SCHEMA ops TO lab_dispatch;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO lab_dispatch;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO lab_dispatch;
GRANT SELECT (utc_offset_hours) ON lab_settings TO lab_dispatch;
