-- cold-storage-archive's DDL in the machinery's vitals database (v0.5 master spec
-- 12.1, 12.2 purpose 14; vet-machinery-domain.md, "cold-storage-archive";
-- cold-storage.md 2; clinic-purposes.md "The roles the purposes add"; spec
-- D366, D381, D418; capture W4 items 0 and 6 of
-- specs/versions/v0.5/wave-log.md), named by purpose.yaml's ddl.source.
-- load-data reads it from the catalogue at step (2b), after every domain's
-- load, and runs it as postgres connected to the database the scenario maps
-- the part to (vitals), unseen, with the variables load_epoch,
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

-- The shipping job's role on the machinery's databases (this purpose's
-- alone, created guarded by both DDLs). LOGIN, its password the game's
-- secret; CONNECT by name, the part's schema having revoked it from PUBLIC.
-- It owns no table: the partitions are dropped by mach_drop_shipped, SECURITY
-- DEFINER, owned by mach.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mach_archive') THEN
CREATE ROLE mach_archive LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO mach_archive;

-- The shipments (vet-machinery-domain.md, purpose 14's trace): one row a type
-- and day, its shipment id (<type>-<YYYYMMDD>, sent again on a resend), the
-- rows sent and received, the attempts, when it was posted, answered and
-- dropped, the run that last touched it.
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.shipments (
    type          text        NOT NULL,
    day           date        NOT NULL,
    shipment_id   text        NOT NULL,
    rows_sent     bigint      NOT NULL,
    rows_received bigint,
    attempts      integer     NOT NULL DEFAULT 1,
    posted_at     timestamptz NOT NULL,
    receipt_at    timestamptz,
    dropped_at    timestamptz,
    run_id        bigint      NOT NULL REFERENCES ops.runs (id),
    PRIMARY KEY (type, day));
RESET ROLE;

-- The ops grants (W4 item 0), and the shipments' upsert.
GRANT USAGE ON SCHEMA ops TO mach_archive;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO mach_archive;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO mach_archive;
GRANT SELECT, INSERT, UPDATE ON ops.shipments TO mach_archive;

-- The data shipped and the window (clinic-purposes.md, mach_archive; spec
-- D418): mach_vitals read through its parent (pruning picks the day's partition),
-- mach_vitals_settings for the customer's offset and the kept window, the
-- drop through the part's own function.
GRANT SELECT ON mach_vitals, mach_vitals_settings TO mach_archive;
GRANT EXECUTE ON FUNCTION mach_drop_shipped(date) TO mach_archive;
