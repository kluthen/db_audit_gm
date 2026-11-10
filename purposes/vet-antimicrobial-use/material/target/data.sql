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
