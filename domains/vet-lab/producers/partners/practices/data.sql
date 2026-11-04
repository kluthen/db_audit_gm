-- data.sql of the region's practices, one stub for the lab's 120 accounts
-- (v0.5 master spec 9.3; vet-lab-domain.md, "The partners the lab meets", "The
-- history before T0"; capture W3 item 1, W2-f; partners/README.md): its role,
-- its schema, the orders it holds open, the deliveries it has taken for them
-- and its state, in the partners' database. load-data runs it connected to
-- partners, as postgres, with vet-core's and vet-lab's data/keys.sql streamed
-- ahead of it (W3 item 0): the orders are pg_temp.lab_order_tests', the pass
-- vet-lab's load.sql runs, so the stub knows every practice order the lab has
-- not completed at T0 (D304), and its interim deliveries by the same
-- delivery_key (pg_temp.lab_delivery). The stub serves the hostname
-- practices, every account's callback http://practices:8000/results (D293).
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'practices data.sql: psql variable load_epoch is not set'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.lab_order_tests(timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'practices data.sql: vet-lab''s key functions are missing (load-data streams '
                        'vet-core''s and vet-lab''s data/keys.sql ahead of this file)';
    END IF;
END $$;

CREATE ROLE practices LOGIN;
CREATE SCHEMA practices AUTHORIZATION practices;

-- One row an order a practice posted to lab-api (practices.order), keyed as
-- the lab keys it; the accession lab-api answered.
CREATE TABLE practices.orders (
    account_id integer     NOT NULL,
    client_ref text        NOT NULL,
    accession  integer,
    priority   text        NOT NULL,
    tests      text[]      NOT NULL,             -- the lab's codes
    posted_at  timestamptz NOT NULL,
    PRIMARY KEY (account_id, client_ref)
);
ALTER TABLE practices.orders OWNER TO practices;

-- One row a delivery_key taken at POST /results: a repeat is acknowledged
-- again and counted, never recorded twice.
CREATE TABLE practices.deliveries (
    delivery_key text        PRIMARY KEY,
    account_id   integer     NOT NULL,
    accession    integer     NOT NULL,
    kind         text        NOT NULL CHECK (kind IN ('interim', 'final', 'amended')),
    first_at     timestamptz NOT NULL,
    last_at      timestamptz NOT NULL,
    repeats      integer     NOT NULL DEFAULT 0
);
ALTER TABLE practices.deliveries OWNER TO practices;

CREATE TABLE practices.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name)
);
ALTER TABLE practices.state OWNER TO practices;
INSERT INTO practices.state (hostname, name, value) VALUES ('practices', 'delay_ms', '0');

CREATE TEMP TABLE p_t AS
SELECT * FROM pg_temp.lab_order_tests(:'load_epoch'::timestamptz, :customer_utc_offset)
 WHERE account_id > 1 AND completed_at IS NULL AND order_cancelled_at IS NULL;

INSERT INTO practices.orders (account_id, client_ref, accession, priority, tests, posted_at)
SELECT account_id, client_ref, order_id, priority, array_agg(code ORDER BY test_position), ordered_at
  FROM p_t GROUP BY account_id, client_ref, order_id, priority, ordered_at;

-- Their interim deliveries (vet-lab's load.sql, lab_callbacks): a test of a
-- several-test order released before the last, acknowledged before T0.
INSERT INTO practices.deliveries (delivery_key, account_id, accession, kind, first_at, last_at)
SELECT d.delivery_key, e.account_id, e.order_id, 'interim', d.posted_at, d.posted_at
  FROM (SELECT order_id, account_id, min(final_at) AS event_at FROM p_t GROUP BY order_id, account_id
        HAVING count(*) > 1 AND bool_or(status = 'released')) AS e,
       LATERAL pg_temp.lab_delivery(e.order_id, 'interim', 1, e.event_at) AS d
 WHERE d.acknowledged_at < :'load_epoch'::timestamptz;
ANALYZE practices.orders, practices.deliveries;
