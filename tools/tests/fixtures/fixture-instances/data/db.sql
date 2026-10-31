-- Restored backup of db for the fixture scenario fixture-instances
-- (tools/tests/fixtures), loaded by gmctl load-data as postgres, with the
-- psql variables customer_timezone and customer_utc_offset (v0.4 capture
-- W1 item 0). shop_etl is the crontab's role here and the remote role of
-- reporting's user mapping; load-data sets its password from its secret.
-- Governance (v0.4 chunk 12, data/classification.yaml): customers and the
-- outbox's payload are personal, orders.customer_id customer-linked;
-- shop_app, the policy's one reader, reads them; shop_etl reads no classed
-- column (orders without customer_id), so reporting's mapping reaches none.
CREATE ROLE shop NOLOGIN;
CREATE ROLE shop_etl LOGIN;
CREATE ROLE shop_app LOGIN;
CREATE DATABASE shop OWNER shop;
-- Only the roles that need it connect; load-data grants gm_check CONNECT.
REVOKE CONNECT ON DATABASE shop FROM PUBLIC;
GRANT CONNECT ON DATABASE shop TO shop_etl, shop_app;

\connect shop
SET ROLE shop;

CREATE TABLE business_settings (
    customer_timezone text NOT NULL,
    customer_utc_offset integer NOT NULL
);
INSERT INTO business_settings VALUES (:'customer_timezone', :customer_utc_offset);

CREATE TABLE customers (
    id integer PRIMARY KEY,
    name text NOT NULL,
    email text NOT NULL
);
INSERT INTO customers
SELECT g, 'Customer ' || g, 'customer' || g || '@example.org'
  FROM generate_series(1, 20) AS g;

CREATE TABLE orders (
    id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers,
    placed_at timestamptz NOT NULL,
    total numeric(10, 2) NOT NULL
);
INSERT INTO orders
SELECT g, (g % 20) + 1, timestamptz '2026-10-01 00:00:00+00' + g * interval '1 hour',
       (g % 50) + 0.5
  FROM generate_series(1, 200) AS g;

-- What leaves for the mail provider: the payload's keys are governance's
-- outbound fields (email, name, order_id).
CREATE TABLE mail_outbox (
    id bigserial PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers,
    payload jsonb NOT NULL,
    sent_at timestamptz NOT NULL
);
INSERT INTO mail_outbox (customer_id, payload, sent_at)
SELECT c.id, jsonb_build_object('email', c.email, 'name', c.name, 'order_id', o.id),
       o.placed_at + interval '1 day'
  FROM orders o JOIN customers c ON c.id = o.customer_id
 WHERE o.id <= 10;

-- One row per run of the crontab entry, by the role it connected as.
CREATE TABLE crontab_runs (
    run_at timestamptz NOT NULL DEFAULT now(),
    run_by name NOT NULL DEFAULT current_user
);

GRANT SELECT (id, placed_at, total) ON orders TO shop_etl;
GRANT INSERT ON crontab_runs TO shop_etl;
GRANT SELECT ON customers, orders, mail_outbox TO shop_app;
GRANT INSERT ON mail_outbox TO shop_app;
GRANT USAGE ON SEQUENCE mail_outbox_id_seq TO shop_app;
RESET ROLE;
