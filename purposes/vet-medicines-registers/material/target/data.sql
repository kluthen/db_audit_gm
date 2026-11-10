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
