-- data.sql of vet-working-time's target, office (v0.5 master spec 11.3,
-- 12.1 item 5, 12.2 purpose 12; vet-scheduling-domain.md, purpose 12 and
-- "`office` at T0, the part's share"; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md): the working-time record, in the back
-- office's database. The GM copies it into the primary's (records') data
-- file after office.sql (copied once for every periodic purpose); load-data
-- streams that file into psql as postgres, connected to postgres. The
-- planted past is material/history.sql's.
--
-- Each output row carries the run that wrote it (run_id, office's runs);
-- day is the customer's local day a shift started, month the first day of
-- its month. No unique key on a day's rows: "once" is the feeder's care and
-- the checks' judgement (WT1).
\connect office
SET ROLE office;

-- One row a staff member and local day (feed-working-time): the shifts that
-- started that day, their planned hours (on call excluded: at home), the
-- hours worked as clocked (an on-call shift's call-out included), the night
-- shifts' hours, the call-outs. The staff member's name, the inspector's
-- record; an absence's kind or note never.
CREATE TABLE working_time_days (
    id           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day          date         NOT NULL,
    staff_id     integer      NOT NULL,
    staff_name   text         NOT NULL,
    shifts       integer      NOT NULL,
    planned_hours numeric(6,2) NOT NULL,
    worked_hours numeric(6,2) NOT NULL,
    night_hours  numeric(6,2) NOT NULL,
    call_outs    integer      NOT NULL,
    run_id       bigint       NOT NULL REFERENCES runs (id));
CREATE INDEX working_time_days_day_idx ON working_time_days (day, staff_id);

-- One row a shift started that day whose rest since the staff member's
-- previous clocked shift is under the minimum (11 hours, sched_settings):
-- the two shifts and the rest, clocked. On-call shifts take no part (at
-- home: the rota's rests are between the shifts on site).
CREATE TABLE rest_breaches (
    id                bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day               date         NOT NULL,
    staff_id          integer      NOT NULL,
    shift_id          integer      NOT NULL,
    previous_shift_id integer      NOT NULL,
    rest_hours        numeric(6,2) NOT NULL,
    run_id            bigint       NOT NULL REFERENCES runs (id));
CREATE INDEX rest_breaches_day_idx ON rest_breaches (day, staff_id);

-- One row a staff member and month (close-working-time, the 1st): the
-- month's hours, night hours, call-outs and breaches from the daily rows,
-- and the weekly average of the hours worked over the last four months (the
-- month and the three before it; Directive 2003/88/EC Arts 6, 16(b)).
CREATE TABLE working_time_months (
    id                   bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    month                date         NOT NULL,
    staff_id             integer      NOT NULL,
    staff_name           text         NOT NULL,
    worked_hours         numeric(8,2) NOT NULL,
    night_hours          numeric(8,2) NOT NULL,
    call_outs            integer      NOT NULL,
    breaches             integer      NOT NULL,
    average_weekly_hours numeric(6,2) NOT NULL,
    run_id               bigint       NOT NULL REFERENCES runs (id));
CREATE INDEX working_time_months_month_idx ON working_time_months (month, staff_id);
RESET ROLE;

-- office_jobs writes them (the report runner), office_reader reads them (the
-- back office's staff, the inspector's queries).
GRANT SELECT, INSERT ON working_time_days, rest_breaches, working_time_months TO office_jobs;
GRANT SELECT ON working_time_days, rest_breaches, working_time_months TO office_reader;
\connect postgres
