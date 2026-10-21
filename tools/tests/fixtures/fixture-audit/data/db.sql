-- Restored-backup data of the fixture scenario's db node (tools/tests,
-- chunk 7). gmctl load-data streams this file into
--   psql -X -q -v ON_ERROR_STOP=1 -d postgres
-- run as the postgres OS user; the file creates its own roles and databases.
CREATE ROLE shop NOLOGIN;
CREATE DATABASE shop OWNER shop;

\connect shop
SET ROLE shop;

CREATE TABLE customers (
    id   integer PRIMARY KEY,
    name text    NOT NULL
);

CREATE TABLE orders (
    id          integer       PRIMARY KEY,
    customer_id integer       NOT NULL REFERENCES customers (id),
    placed_at   timestamptz   NOT NULL,
    total       numeric(10,2) NOT NULL
);

INSERT INTO customers (id, name)
SELECT g, 'customer ' || g FROM generate_series(1, 500) AS g;

INSERT INTO orders (id, customer_id, placed_at, total)
SELECT g, 1 + g % 500, timestamptz '2026-01-01 00:00:00+00' + g * interval '7 minutes',
       (g % 97) + 0.99
  FROM generate_series(1, 20000) AS g;

CREATE INDEX orders_customer_id_idx ON orders (customer_id);

ANALYZE customers;
ANALYZE orders;
