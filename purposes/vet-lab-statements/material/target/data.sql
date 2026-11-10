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
