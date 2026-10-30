-- Restored-backup data of fixture-v04-refusals' db node (tools/tests, v0.4
-- chunk 2), written as capture W1 item 0 reads a data file: each CREATE
-- DATABASE and CREATE ROLE at the start of its line, names unquoted.
CREATE ROLE shop NOLOGIN;
CREATE ROLE shop_app LOGIN;
CREATE ROLE shop_reports LOGIN;
CREATE ROLE shop_etl LOGIN;
CREATE DATABASE shop OWNER shop;

\connect shop
SET ROLE shop;

CREATE TABLE customers (
    id    integer PRIMARY KEY,
    name  text    NOT NULL,
    email text    NOT NULL
);

CREATE TABLE orders (
    id          integer       PRIMARY KEY,
    customer_id integer       NOT NULL REFERENCES customers (id),
    placed_at   timestamptz   NOT NULL,
    total       numeric(10,2) NOT NULL
);

CREATE TABLE mail_outbox (
    id      integer PRIMARY KEY,
    payload jsonb   NOT NULL
);

INSERT INTO customers (id, name, email)
SELECT g, 'customer ' || g, 'customer' || g || '@example.org' FROM generate_series(1, 500) AS g;

INSERT INTO orders (id, customer_id, placed_at, total)
SELECT g, 1 + g % 500, timestamptz '2026-01-01 00:00:00+00' + g * interval '7 minutes',
       (g % 97) + 0.99
  FROM generate_series(1, 20000) AS g;

GRANT SELECT ON customers, orders TO shop_app, shop_reports;
GRANT SELECT (id, customer_id, placed_at, total) ON orders TO shop_etl;
