-- vet-imaging-orders' DDL in the PACS's database (v0.5 master spec 12.1, 12.2 purpose
-- 13; vet-machinery-domain.md, "vet-imaging-orders"; clinic-purposes.md "The
-- roles the purposes add"; spec D416; capture W4 items 0 and 6 of
-- specs/versions/v0.5/wave-log.md), named by purpose.yaml's ddl.target.
-- load-data reads it from the catalogue at step (2b), after every domain's
-- load, and runs it as postgres connected to the database the scenario maps
-- the target to (pacs), unseen, with the variables load_epoch,
-- customer_timezone and customer_utc_offset and no key functions. It never
-- creates a database nor \connects; the database is :"DBNAME".
--
-- The ops schema (W4 item 0), the same text in every purpose's DDL:
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

-- The engine's role on the PACS (this purpose's alone). LOGIN, its password
-- the game's secret; CONNECT by name, the part's schema having revoked it
-- from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mach_orders') THEN
CREATE ROLE mach_orders LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO mach_orders;

-- The ops grants (W4 item 0): post-imaging-orders' run rows here, in the
-- worklist's transaction.
GRANT USAGE ON SCHEMA ops TO mach_orders;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO mach_orders;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO mach_orders;

-- The worklist (clinic-purposes.md, mach_orders; spec D416): entries
-- inserted with ids only (the PACS reads the identity from the lookup API),
-- read back with their state and cancellation; the studies' worklist and
-- state, the reports' kind, status, signing and supersession. The ids the
-- joins need (an entry's, a study's, a report's) and the procedure
-- catalogue's code and id, which an entry's procedure_id names, beside the
-- list (reported to spec-writer, as chunk 19's roles).
GRANT INSERT (accession, request_id, consultation_id, animal_id, requested_by, procedure_id, priority,
              created_at) ON mach_worklist TO mach_orders;
GRANT SELECT (id, accession, request_id, state, cancelled_because, cancelled_at) ON mach_worklist TO mach_orders;
GRANT SELECT (id, worklist_id, state) ON mach_studies TO mach_orders;
GRANT SELECT (id, study_id, kind, status, signed_at, supersedes_id) ON mach_reports TO mach_orders;
GRANT SELECT (id, code) ON mach_procedures TO mach_orders;
