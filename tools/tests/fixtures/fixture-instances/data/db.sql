-- Restored backup of db for the fixture scenario fixture-instances
-- (tools/tests/fixtures), loaded by gmctl load-data as postgres, with the
-- psql variables customer_timezone and customer_utc_offset (v0.4 capture
-- W1 item 0). shop_etl is the crontab's role here and the remote role of
-- reporting's user mapping; load-data sets its password from its secret.
CREATE ROLE shop NOLOGIN;
CREATE ROLE shop_etl LOGIN;
CREATE DATABASE shop OWNER shop;
-- Only the roles that need it connect; load-data grants gm_check CONNECT.
REVOKE CONNECT ON DATABASE shop FROM PUBLIC;
GRANT CONNECT ON DATABASE shop TO shop_etl;

\connect shop
SET ROLE shop;

CREATE TABLE business_settings (
    customer_timezone text NOT NULL,
    customer_utc_offset integer NOT NULL
);
INSERT INTO business_settings VALUES (:'customer_timezone', :customer_utc_offset);

CREATE TABLE orders (
    id integer PRIMARY KEY,
    placed_at timestamptz NOT NULL,
    total numeric(10, 2) NOT NULL
);
INSERT INTO orders
SELECT g, timestamptz '2026-10-01 00:00:00+00' + g * interval '1 hour', (g % 50) + 0.5
  FROM generate_series(1, 200) AS g;

-- One row per run of the crontab entry, by the role it connected as.
CREATE TABLE crontab_runs (
    run_at timestamptz NOT NULL DEFAULT now(),
    run_by name NOT NULL DEFAULT current_user
);

GRANT SELECT ON orders TO shop_etl;
GRANT INSERT ON crontab_runs TO shop_etl;
RESET ROLE;
