-- vet-bookings-sync's DDL in the core's record (v0.5 master spec 12.1, 12.2
-- purpose 11; vet-scheduling-domain.md, "11. vet-bookings-sync";
-- clinic-purposes.md "The roles the purposes add"; capture W4 items 0 and 6
-- of specs/versions/v0.5/wave-log.md), named by purpose.yaml's ddl.target.
-- load-data reads it from the catalogue at step (2b), after every domain's
-- load (vet-core's and vet-scheduling's, both in clinic), and runs it as
-- postgres connected to the database the scenario maps the target to
-- (clinic), unseen, with the variables load_epoch, customer_timezone and
-- customer_utc_offset and no key functions. It never creates a database nor
-- \connects; the database is :"DBNAME". Roles two purposes create on one
-- node are created guarded.
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

-- The purpose's roles: the engine's core role (purposes 1, 4, 5, 11 and 13
-- create it, each guarded) and its scheduling role (this purpose's alone).
-- LOGIN, their passwords the game's secrets (load-data sets them); CONNECT
-- by name, load-data having revoked it from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vet_interfaces') THEN
CREATE ROLE vet_interfaces LOGIN;
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sched_interfaces') THEN
CREATE ROLE sched_interfaces LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO vet_interfaces, sched_interfaces;

-- The check-in's ledger (vet-scheduling-domain.md, purpose 11's trace): one
-- row a consultation opened for a booking, in the consultation's
-- transaction. No unique constraint: "never two" (BS2) is the job's care
-- and the core's index's, which a fault can break.
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.booking_consultations (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id          bigint      NOT NULL REFERENCES ops.runs (id),
    booking_id      integer     NOT NULL,
    consultation_id integer     NOT NULL,
    at              timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE INDEX IF NOT EXISTS booking_consultations_booking_idx ON ops.booking_consultations (booking_id);
RESET ROLE;

-- The ops grants (W4 item 0), for each of the purpose's roles.
GRANT USAGE ON SCHEMA ops TO vet_interfaces, sched_interfaces;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO vet_interfaces, sched_interfaces;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO vet_interfaces, sched_interfaces;
GRANT SELECT, INSERT ON ops.booking_consultations TO vet_interfaces;

-- The engine on the core (vet-scheduling-domain.md, purpose 11's roles):
-- INSERT on consultations' open columns only (T112), the booking's
-- consultation found by its booking_id (and its section for a request's
-- study); the animals' death; the imaging requests and the inbound
-- examinations to book.
GRANT INSERT (animal_id, site_id, section_id, vet_id, kind, booking_id, started_at) ON consultations
   TO vet_interfaces;
GRANT SELECT (id, booking_id, section_id) ON consultations TO vet_interfaces;
GRANT SELECT (id, status, died_at) ON animals TO vet_interfaces;
GRANT SELECT ON requests, exchanges TO vet_interfaces;

-- The engine on the agenda: the part's tables as the slot function reads
-- them (its LEFT JOIN of sched_courses and its rooms included, so both are
-- granted beside the list), the function itself (security invoker: it
-- reads as the caller),
-- new imaging and examination bookings with their allocations, bookings'
-- state and links; the release trigger (security invoker) marks a cancelled
-- booking's allocations released.
GRANT SELECT ON sched_settings, sched_rooms, sched_hours, sched_machines, sched_types, sched_courses,
                sched_bookings, sched_allocations, sched_shifts, sched_absences
   TO sched_interfaces;
GRANT EXECUTE ON FUNCTION sched_free_slots(integer, timestamptz, integer) TO sched_interfaces;
GRANT INSERT ON sched_bookings, sched_allocations TO sched_interfaces;
GRANT UPDATE (state, cancelled_at, cancel_reason, request_id, exchange_id) ON sched_bookings TO sched_interfaces;
GRANT UPDATE (released_at) ON sched_allocations TO sched_interfaces;

-- The watermarks start at load_epoch (W4 item 0): the agenda and the record
-- agree at T0 (the coherence check attended-bookings), every request and
-- examination before it booked by the load.
INSERT INTO ops.watermarks (purpose, name, at, last_id) VALUES
    ('vet-bookings-sync', 'check-in', :'load_epoch', 0),
    ('vet-bookings-sync', 'requests', :'load_epoch', 0),
    ('vet-bookings-sync', 'examinations', :'load_epoch', 0),
    ('vet-bookings-sync', 'deaths', :'load_epoch', 0)
ON CONFLICT DO NOTHING;
