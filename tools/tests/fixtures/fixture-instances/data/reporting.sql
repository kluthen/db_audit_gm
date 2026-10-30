-- Restored backup of reporting for the fixture scenario fixture-instances
-- (tools/tests/fixtures), loaded by gmctl load-data as postgres. The
-- foreign server shop_db reaches db's shop as shop_etl through bi_etl's
-- user mapping, whose password load-data sets from shop_etl's secret; two
-- pg_cron jobs, as two roles, so a role sees only its own (master spec 7.2).
CREATE ROLE bi_etl LOGIN;
CREATE ROLE bi_reader LOGIN;
CREATE DATABASE reporting OWNER bi_etl;

\connect reporting

CREATE EXTENSION postgres_fdw;
CREATE SERVER shop_db FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'db', port '5432', dbname 'shop');
GRANT USAGE ON FOREIGN SERVER shop_db TO bi_etl;
CREATE USER MAPPING FOR bi_etl SERVER shop_db OPTIONS (user 'shop_etl');

CREATE SCHEMA src AUTHORIZATION bi_etl;
CREATE FOREIGN TABLE src.orders (
    id integer,
    placed_at timestamptz,
    total numeric(10, 2)
) SERVER shop_db OPTIONS (schema_name 'public', table_name 'orders');
ALTER FOREIGN TABLE src.orders OWNER TO bi_etl;

CREATE SCHEMA rpt AUTHORIZATION bi_etl;
CREATE TABLE rpt.order_counts (
    counted_at timestamptz NOT NULL DEFAULT now(),
    orders bigint NOT NULL
);
ALTER TABLE rpt.order_counts OWNER TO bi_etl;
CREATE TABLE rpt.pings (
    pinged_at timestamptz NOT NULL DEFAULT now(),
    pinged_by name NOT NULL DEFAULT current_user
);
ALTER TABLE rpt.pings OWNER TO bi_etl;
GRANT USAGE ON SCHEMA rpt TO bi_reader;
GRANT INSERT ON rpt.pings TO bi_reader;

-- pg_cron in cron.database_name (the seed's reporting), as superuser.
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule_in_database('order-count', '* * * * *',
    'INSERT INTO rpt.order_counts (orders) SELECT count(*) FROM src.orders',
    'reporting', username => 'bi_etl');
SELECT cron.schedule_in_database('ping', '* * * * *',
    'INSERT INTO rpt.pings DEFAULT VALUES',
    'reporting', username => 'bi_reader');
