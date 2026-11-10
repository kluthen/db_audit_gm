-- vet-notifiable-diseases' DDL in the core's record (v0.5 master spec 12.1,
-- 12.2 purpose 5; clinic-purposes.md 9 and "The roles the purposes add";
-- capture W4 items 0 and 4 of specs/versions/v0.5/wave-log.md), named by
-- purpose.yaml's ddl.source. load-data reads it from the catalogue at step
-- (2b) and runs it as postgres connected to the database the scenario maps
-- the source to (clinic), unseen, with load_epoch, customer_timezone and
-- customer_utc_offset and no key functions; never a database created nor a
-- \connect; the database is :"DBNAME".
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

-- The engine's role (purposes 1, 4, 5, 11 and 13 create it, each guarded);
-- CONNECT by name, load-data having revoked it from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vet_interfaces') THEN
CREATE ROLE vet_interfaces LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO vet_interfaces;

-- One row a trigger notified (a vet's notifiable diagnosis here, vet-<id>; a
-- lab notification in lab, lab-<id>): its category and deadline (an hour for
-- category A, a day otherwise), what was posted (payload), its attempts and
-- the last status, the authority's reference once given. The same text in
-- clinic's and lab's DDL.
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

GRANT USAGE ON SCHEMA ops TO vet_interfaces;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO vet_interfaces;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO vet_interfaces;
GRANT SELECT, INSERT, UPDATE ON ops.notifications TO vet_interfaces;

-- What a notification carries (clinic-purposes.md 9, ND3): the disease, the
-- species, the holding or the keeper's name and address, the notifying vet,
-- the date; never the findings.
GRANT SELECT ON diagnoses, diagnosis_codes, ownerships, business_settings TO vet_interfaces;
GRANT SELECT (id, animal_id, herd_id, vet_id) ON consultations TO vet_interfaces;
GRANT SELECT (id, species) ON animals TO vet_interfaces;
GRANT SELECT (id, keeper_owner_id, holding_number) ON herds TO vet_interfaces;
GRANT SELECT (id, kind, name, address, country) ON owners TO vet_interfaces;
GRANT SELECT (id, name) ON staff TO vet_interfaces;

-- The back office's copy (copy-notifications, on backoffice) reads the
-- notifications as the domain's vet_reports (granted here, never created).
GRANT USAGE ON SCHEMA ops TO vet_reports;
GRANT SELECT ON ops.notifications TO vet_reports;

-- notify-vet's horizon starts at load_epoch (W4 item 0): a diagnosis of the
-- history, before T0, is the past's.
INSERT INTO ops.watermarks (purpose, name, at) VALUES ('vet-notifiable-diseases', 'vet', :'load_epoch')
ON CONFLICT DO NOTHING;
