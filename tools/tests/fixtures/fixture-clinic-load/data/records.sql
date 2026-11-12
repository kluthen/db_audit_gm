-- records' data file of the clinic load fixture: aldermoor-centre's, byte for
-- byte after this header (build plan chunk 27; the office database is one of
-- the scenario's governance locations): pg_cron's database jobs, then the
-- purposes' share: office.sql once (the back office's database office, which
-- no domain holds), then the data.sql of purposes 7, 8, 12, 9 and 10, in that
-- order (capture W4 item 5). load-data runs it as postgres, connected to
-- postgres, before the domains' loads.
-- records' data file (tools/tests, v0.5 wave 3 gate, spec D407; the portal
-- fixture's, chunk 16b; capture W3 items 4 and 5):
-- the database jobs, pg_cron's cron.database_name, which no domain holds, and
-- the extension in it. load-data runs it before the domains' loads; vet-core
-- creates clinic, vet-portal portal, and vet-portal's data/cron.sql schedules
-- the sessions' purge here once portal and portal_housekeeping exist.
CREATE DATABASE jobs;
REVOKE CONNECT ON DATABASE jobs FROM PUBLIC;
\connect jobs
CREATE EXTENSION pg_cron;

-- office.sql: the back office's database office (v0.5 master spec 11.3,
-- 12.1 item 5, 12.2; clinic-purposes.md, "The roles the purposes add" and
-- "`office` at T0"; capture W4 item 5 of specs/versions/v0.5/wave-log.md),
-- byte-identical in purposes 5, 7, 8, 9, 10 and 12 (tools/tests/test_purposes.py
-- compares them). office belongs to no domain: the GM copies this file once,
-- at the head of the purposes' share of the primary's (records') data file,
-- then each purpose's material/target/data.sql after it. load-data streams
-- the data file into psql as postgres, connected to postgres, before any
-- domain; this file ends connected to postgres again.
--
-- Roles: office owns everything, no login; office_jobs, the back office's
-- writes (the report runner's), reads nothing of the record; office_reader,
-- the back office's staff and dashboards, reads office. The reports read the
-- record as the domains' vet_reports, sched_reports and lab_reports, created
-- by their schemas after this file: never here.
CREATE ROLE office NOLOGIN;
CREATE ROLE office_jobs LOGIN;
CREATE ROLE office_reader LOGIN;
CREATE DATABASE office OWNER office;
REVOKE CONNECT ON DATABASE office FROM PUBLIC;
GRANT CONNECT ON DATABASE office TO office_jobs, office_reader;

\connect office
SET ROLE office;
-- The run ledger, ops.runs' columns (W4 item 0): one row a run, in the
-- transaction of its output.
CREATE TABLE runs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purpose text NOT NULL, job text NOT NULL,
    started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL DEFAULT now(),
    rows_read integer NOT NULL DEFAULT 0, rows_written integer NOT NULL DEFAULT 0);
CREATE INDEX runs_job_idx ON runs (purpose, job, started_at);
-- The copies of the regulatory submissions sent (purposes 5 and 8): kind
-- (notifiable-disease, amu-report), the source database, the notifier's key,
-- what was sent, when, the authority's reference.
CREATE TABLE regulatory_submissions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind text NOT NULL, source text NOT NULL, ref text NOT NULL,
    payload jsonb NOT NULL, sent_at timestamptz, reference text,
    copied_at timestamptz NOT NULL DEFAULT now(),
    run_id bigint NOT NULL REFERENCES runs (id));
CREATE INDEX regulatory_submissions_ref_idx ON regulatory_submissions (kind, ref);
RESET ROLE;
GRANT SELECT, INSERT, UPDATE ON runs, regulatory_submissions TO office_jobs;
GRANT SELECT ON runs, regulatory_submissions TO office_reader;
\connect postgres

-- data.sql of vet-medicines-registers' target, office (v0.5 master spec
-- 11.3, 12.1 item 5, 12.2 purpose 7; clinic-purposes.md 11, "The roles the
-- purposes add" and "`office` at T0"; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md): the two registers and their periodic
-- outputs, in the back office's database. The GM copies it into the
-- primary's (records') data file after office.sql (copied once for every
-- periodic purpose); load-data streams that file into psql as postgres,
-- connected to postgres. Its tables are office's, in public; the planted
-- past is material/history.sql's, run by load-data after the domains' loads.
--
-- Each output row carries the run that wrote it (run_id, office's runs);
-- day is the customer's local day of the supply, month the first day of its
-- month. No unique key on a day's lines: "once" is the feeders' care and the
-- checks' judgement (MR1, MR3), so a fault can break it.
\connect office
SET ROLE office;

-- The register of supplies (Regulation (EU) 2019/6 Art 103(3)): one line a
-- dispensing to an owner and a dose given in hospital, of yesterday, the
-- customer's day; the recipient the owner (name and address, as the law
-- requires: nothing else of the owner) or the centre (no address: its own).
CREATE TABLE medicines_register (
    id                   bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day                  date          NOT NULL,
    supply               text          NOT NULL CHECK (supply IN ('dispensing', 'administration')),
    supply_id            integer       NOT NULL,      -- clinic's dispensings.id or administrations.id
    supplied_at          timestamptz   NOT NULL,
    medicine_id          integer       NOT NULL,
    product              text          NOT NULL,
    form                 text          NOT NULL,
    authorisation_number text          NOT NULL,
    batch_number         text,                        -- a dose given from no recorded batch: none
    quantity             numeric(10,2) NOT NULL,
    recipient            text          NOT NULL,      -- the owner's name, or the centre's
    recipient_address    text,                        -- the owner's address; none for the centre
    prescribing_vet      text          NOT NULL,
    run_id               bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX medicines_register_day_idx ON medicines_register (day);
CREATE INDEX medicines_register_supply_idx ON medicines_register (supply, supply_id);

-- The controlled-drugs register: one movement a dispensing or a dose given
-- of a controlled medicine (medicines.controlled), out of the batches the
-- load received (stock receipts are out of v0.5, D278).
CREATE TABLE controlled_movements (
    id           bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day          date          NOT NULL,
    movement     text          NOT NULL CHECK (movement IN ('dispensing', 'administration')),
    movement_id  integer       NOT NULL,              -- as medicines_register.supply_id
    moved_at     timestamptz   NOT NULL,
    medicine_id  integer       NOT NULL,
    batch_id     integer,
    batch_number text,
    quantity     numeric(10,2) NOT NULL,
    run_id       bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX controlled_movements_day_idx ON controlled_movements (day);
CREATE INDEX controlled_movements_batch_idx ON controlled_movements (batch_id, day);

-- The month's extract (close-medicines-register, the 1st): per product, the
-- month's lines and quantity, and a checksum of its lines (md5 of each
-- line's supply, id and quantity in that order).
CREATE TABLE register_extracts (
    id          bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    month       date          NOT NULL,
    medicine_id integer       NOT NULL,
    product     text          NOT NULL,
    lines       integer       NOT NULL,
    quantity    numeric(12,2) NOT NULL,
    checksum    text          NOT NULL,
    run_id      bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX register_extracts_month_idx ON register_extracts (month);

-- The month's balance of each controlled batch (balance-controlled-drugs,
-- the 1st): the opening (the previous month's closing, the quantity received
-- for a batch's first month), the month's movements, the closing (the
-- opening less the movements, MR4), signed by the centre's senior vet.
CREATE TABLE controlled_balances (
    id           bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    month        date          NOT NULL,
    medicine_id  integer       NOT NULL,
    batch_id     integer       NOT NULL,
    batch_number text          NOT NULL,
    opening      numeric(12,2) NOT NULL,
    movements    numeric(12,2) NOT NULL,
    closing      numeric(12,2) NOT NULL,
    signed_by    text          NOT NULL,
    run_id       bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX controlled_balances_month_idx ON controlled_balances (month, batch_id);

-- The yearly inventory (inventory-controlled-drugs, 1 January): each
-- controlled batch's stock at the year's start, December's closing.
CREATE TABLE controlled_inventories (
    id           bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    year         date          NOT NULL,              -- 1 January
    medicine_id  integer       NOT NULL,
    batch_id     integer       NOT NULL,
    batch_number text          NOT NULL,
    counted      numeric(12,2) NOT NULL,
    run_id       bigint        NOT NULL REFERENCES runs (id));
RESET ROLE;

-- office_jobs writes them (the report runner), office_reader reads them (the
-- back office's staff, the inspector's queries).
GRANT SELECT, INSERT ON medicines_register, controlled_movements, register_extracts,
                        controlled_balances, controlled_inventories TO office_jobs;
GRANT SELECT ON medicines_register, controlled_movements, register_extracts,
                controlled_balances, controlled_inventories TO office_reader;
\connect postgres

-- data.sql of vet-antimicrobial-use's target, office (v0.5 master spec 11.3,
-- 12.1 item 5, 12.2 purpose 8; clinic-purposes.md 12, "The roles the
-- purposes add" and "`office` at T0"; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md): the daily antimicrobial use and the
-- yearly reports, in the back office's database. The GM copies it into the
-- primary's (records') data file after office.sql (copied once for every
-- periodic purpose); load-data streams that file into psql as postgres,
-- connected to postgres. The planted past is material/history.sql's.
--
-- Each output row carries the run that wrote it (run_id, office's runs);
-- day is the customer's local day. No unique key on a day's rows: "once" is
-- the feeder's care and the checks' judgement (AM1).
\connect office
SET ROLE office;

-- One row a local day, species and ATCvet code (feed-antimicrobial-use): the
-- doses given and the dispensings of antimicrobials, their quantity, the
-- animals and the herds treated (a herd treatment counted under its herd's
-- species: no animal, AM2).
CREATE TABLE antimicrobial_use (
    id              bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day             date          NOT NULL,
    species         text          NOT NULL,
    atcvet_code     text          NOT NULL,
    administrations integer       NOT NULL,
    dispensings     integer       NOT NULL,
    quantity        numeric(12,2) NOT NULL,
    animals_treated integer       NOT NULL,
    herds_treated   integer       NOT NULL,
    run_id          bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX antimicrobial_use_day_idx ON antimicrobial_use (day, species);

-- One row a year and species due (report-antimicrobial-use, 15 January): the
-- report as posted to the authority, its deadline (31 January, a game
-- value), its reference when acknowledged, or its escalation.
CREATE TABLE amu_reports (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    year            date        NOT NULL,                 -- 1 January of the year reported
    species         text        NOT NULL,
    deadline        date        NOT NULL,
    payload         jsonb       NOT NULL,
    sent_at         timestamptz,
    reference       text,
    acknowledged_at timestamptz,
    escalated_at    timestamptz,
    run_id          bigint      NOT NULL REFERENCES runs (id));
CREATE INDEX amu_reports_year_idx ON amu_reports (year, species);
RESET ROLE;

-- office_jobs writes them (the report runner), office_reader reads them.
GRANT SELECT, INSERT ON antimicrobial_use, amu_reports TO office_jobs;
GRANT SELECT ON antimicrobial_use, amu_reports TO office_reader;
\connect postgres

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

-- data.sql of vet-head-office-figures' target, office (v0.5 master spec
-- 11.3, 12.1 item 5, 12.2 purpose 9; clinic-purposes.md 13, "The roles the
-- purposes add" and "`office` at T0"; one-centre 1; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md): the centre's daily activity figures and
-- the months sent to the franchise's head office, in the back office's
-- database. The GM copies it into the primary's (records') data file after
-- office.sql (copied once for every periodic purpose); load-data streams that
-- file into psql as postgres, connected to postgres. The planted past is
-- material/history.sql's.
--
-- Each output row carries the run that wrote it (run_id, office's runs);
-- day is the customer's local day, month its first day. No unique key on a
-- day's rows: "one row per day, section and measure" is the feeder's care
-- and the checks' judgement (HO2).
\connect office
SET ROLE office;

-- One row a local day, section and measure (feed-daily-figures): section
-- the core's section kind (horse, farm, domestic) for the record's and
-- housing's measures, centre for the new owners and animals, lab for the
-- laboratory's; value a count, or the outside orders' median turnaround in
-- minutes (none on a day with no outside test released).
CREATE TABLE daily_figures (
    id      bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day     date          NOT NULL,
    section text          NOT NULL,
    measure text          NOT NULL,
    value   numeric(12,2),
    run_id  bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX daily_figures_day_idx ON daily_figures (day, section, measure);

-- One row a month, section and measure (send-monthly-figures, the 1st to
-- the 5th): the month's figure summed from its days (the turnaround the
-- median of its days'), as posted to the head office; its reference when
-- acknowledged, or its escalation on the 5th. The send columns are the
-- month's, the same on each of its rows.
CREATE TABLE monthly_figures (
    id              bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    month           date          NOT NULL,
    section         text          NOT NULL,
    measure         text          NOT NULL,
    value           numeric(12,2),
    sent_at         timestamptz,
    reference       text,
    acknowledged_at timestamptz,
    escalated_at    timestamptz,
    run_id          bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX monthly_figures_month_idx ON monthly_figures (month, section, measure);
RESET ROLE;

-- office_jobs writes them (the report runner; a retry or an escalation
-- updates a month's send columns), office_reader reads them.
GRANT SELECT, INSERT ON daily_figures, monthly_figures TO office_jobs;
GRANT UPDATE (sent_at, reference, acknowledged_at, escalated_at) ON monthly_figures TO office_jobs;
GRANT SELECT ON daily_figures, monthly_figures TO office_reader;
\connect postgres

-- data.sql of vet-lab-statements' target, office (v0.5 master spec 11.3,
-- 12.1 item 5, 12.2 purpose 10; clinic-purposes.md 14, "The roles the
-- purposes add" and "`office` at T0"; vet-lab rule 13; capture W4 item 5 of
-- specs/versions/v0.5/wave-log.md): the practices' charge lines and their
-- monthly statements, in the back office's database. The GM copies it into
-- the primary's (records') data file after office.sql (copied once for every
-- periodic purpose); load-data streams that file into psql as postgres,
-- connected to postgres. The planted past is material/history.sql's.
--
-- Each output row carries the run that wrote it (run_id, office's runs);
-- day is the customer's local day. No unique key on a day's lines: "once" is
-- the feeder's care and the checks' judgement (ST1).
\connect office
SET ROLE office;

-- One line a charge event of a local day (feed-lab-charges): a practice's
-- charge made billable that day (the release's local date, the lab's
-- billable_on), or voided that day (voided_at), with its order, test (none
-- for the handling fee), kind, amount, and the order's patient reference
-- and client surname as the practice gave them (personal: the statement
-- lists the practice's own clients' orders). Never the centre's account.
CREATE TABLE lab_charge_lines (
    id             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day            date         NOT NULL,
    event          text         NOT NULL CHECK (event IN ('billable', 'void')),
    charge_id      integer      NOT NULL,                -- the lab's lab_charges.id
    account_id     integer      NOT NULL,                -- the lab's lab_accounts.id
    order_id       integer      NOT NULL,
    order_test_id  integer,
    test_code      text,
    kind           text         NOT NULL,                -- test, handling, urgent
    amount         numeric(8,2) NOT NULL,
    patient_ref    text,
    client_surname text,
    run_id         bigint       NOT NULL REFERENCES runs (id));
CREATE INDEX lab_charge_lines_day_idx ON lab_charge_lines (day, account_id);
CREATE INDEX lab_charge_lines_charge_idx ON lab_charge_lines (charge_id);

-- One statement a month and practice account with charges
-- (close-lab-statements, the 1st): its billable lines and their sum, the
-- voids of charges stated before, the total, the volume discount's bracket
-- (3 to 15 % by the total, a game value), the discount on the total and the
-- amount due.
CREATE TABLE lab_statements (
    id           bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    month        date          NOT NULL,                 -- its first day
    account_id   integer       NOT NULL,
    lines        integer       NOT NULL,
    billable     numeric(10,2) NOT NULL,
    voided       numeric(10,2) NOT NULL,
    total        numeric(10,2) NOT NULL,
    discount_pct integer       NOT NULL,
    discount     numeric(10,2) NOT NULL,
    due          numeric(10,2) NOT NULL,
    run_id       bigint        NOT NULL REFERENCES runs (id));
CREATE INDEX lab_statements_month_idx ON lab_statements (month, account_id);
RESET ROLE;

-- office_jobs writes them (the report runner), office_reader reads them.
GRANT SELECT, INSERT ON lab_charge_lines, lab_statements TO office_jobs;
GRANT SELECT ON lab_charge_lines, lab_statements TO office_reader;
\connect postgres
