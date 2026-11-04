-- data.sql of the external reference lab, Northfield Veterinary Laboratories
-- (v0.5 master spec 9.3; vet-lab-domain.md, "The partners the lab meets", "The
-- history before T0"; capture W3 item 1, W2-f; partners/README.md): its role,
-- its schema, the send-outs it holds and its state, in the partners' database.
-- load-data runs it connected to partners, as postgres, with vet-core's and
-- vet-lab's data/keys.sql streamed ahead of it (W3 item 0): the send-outs are
-- pg_temp.lab_order_tests', the pass vet-lab's load.sql runs, so the stub
-- knows every send-out the lab's history leaves open, by the same send_key
-- (D304), and no other. The stub serves the hostname northfield-lab (D370).
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'xlab data.sql: psql variable load_epoch is not set'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.lab_order_tests(timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'xlab data.sql: vet-lab''s key functions are missing (load-data streams vet-core''s '
                        'and vet-lab''s data/keys.sql ahead of this file)';
    END IF;
END $$;

-- The role: LOGIN with no password here; load-data sets its secret.
CREATE ROLE xlab LOGIN;
CREATE SCHEMA xlab AUTHORIZATION xlab;

-- One row a send-out received (POST /orders): what rule 11 lets the lab send
-- (the accession, the sample's label, the test, species, sex and age), the
-- stub's own accession, its due time, its answer once posted back to lab-api
-- (POST /send-outs/{send_key}/result), the chases it took (resend).
CREATE TABLE xlab.orders (
    send_key      uuid        PRIMARY KEY,
    accession     text        UNIQUE,            -- the external lab's own
    lab_accession integer     NOT NULL,          -- the centre lab's order id
    label         text        NOT NULL,
    test_code     text        NOT NULL,          -- the external lab's code (lab_tests.external_code)
    species       text,
    sex           text,
    age           integer,                       -- years, at the send
    received_at   timestamptz NOT NULL,
    due_at        timestamptz NOT NULL,
    answered_at   timestamptz,
    answer        jsonb,
    resends       integer     NOT NULL DEFAULT 0
);
CREATE INDEX orders_due_at_idx ON xlab.orders (due_at) WHERE answered_at IS NULL;
ALTER TABLE xlab.orders OWNER TO xlab;

-- Its state, read by its routes at each request (W2-f); the back end's
-- xlab_tick upserts this baseline, a fault's key other values.
CREATE TABLE xlab.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name)
);
ALTER TABLE xlab.state OWNER TO xlab;
INSERT INTO xlab.state (hostname, name, value) VALUES ('northfield-lab', 'delay_ms', '0');

-- The send-outs the history leaves open (sent, not yet answered).
INSERT INTO xlab.orders (send_key, accession, lab_accession, label, test_code, species, sex, age, received_at, due_at)
SELECT t.send_key, t.xlab_accession, t.order_id, t.label, c.external_code, t.species, t.sex,
       CASE WHEN t.born_on IS NOT NULL
            THEN extract(year FROM age(t.sent_at::date, t.born_on))::integer END,
       coalesce(t.accepted_at, t.sent_at), t.due_by
  FROM pg_temp.lab_order_tests(:'load_epoch'::timestamptz, :customer_utc_offset) AS t
  JOIN pg_temp.lab_catalogue() AS c ON c.id = t.test_id
 WHERE t.send_status IN ('sent', 'accepted');
ANALYZE xlab.orders;
