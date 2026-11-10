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
