-- vet-notifiable-diseases' DDL in the laboratory's database (v0.5 master
-- spec 12.1, 12.2 purpose 5; clinic-purposes.md 9 and "The roles the
-- purposes add"; capture W4 items 0 and 4 of specs/versions/v0.5/
-- wave-log.md), named by purpose.yaml's ddl.source_lab. load-data reads it
-- from the catalogue at step (2b) and runs it as postgres connected to the
-- database the scenario maps source_lab to (lab), unseen, with the variables
-- and no key functions; never a database created nor a \connect.
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

-- One row a trigger notified (a lab notification here, lab-<id>; a vet's
-- notifiable diagnosis in clinic, vet-<id>): the same text in clinic's and
-- lab's DDL.
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.notifications (
    id               bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id           bigint      NOT NULL REFERENCES ops.runs (id),
    trigger          text        NOT NULL CHECK (trigger IN ('vet', 'lab')),
    trigger_id       integer     NOT NULL,
    notification_key text        NOT NULL UNIQUE,
    category         text        NOT NULL CHECK (category IN ('A', 'other')),
    triggered_at     timestamptz NOT NULL,
    deadline         timestamptz NOT NULL,
    payload          jsonb       NOT NULL,
    first_sent_at    timestamptz NOT NULL,
    last_sent_at     timestamptz NOT NULL,
    attempts         integer     NOT NULL DEFAULT 1,
    last_status      integer,
    reference        text,
    referenced_at    timestamptz);
CREATE INDEX IF NOT EXISTS notifications_open_idx ON ops.notifications (trigger, referenced_at);
RESET ROLE;

-- The lab's engine role is vet-lab's lab_dispatch (granted here, never
-- created): it already reads the orders, their tests and the notifications and
-- writes the notifications' notified_at, channel and authority_ref (vet-lab's
-- schema); the ops tables are the purpose's.
GRANT USAGE ON SCHEMA ops TO lab_dispatch;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO lab_dispatch;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO lab_dispatch;
GRANT SELECT, INSERT, UPDATE ON ops.notifications TO lab_dispatch;

-- The back office's copy reads them as the domain's lab_reports.
GRANT USAGE ON SCHEMA ops TO lab_reports;
GRANT SELECT ON ops.notifications TO lab_reports;
