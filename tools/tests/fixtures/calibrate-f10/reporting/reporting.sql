-- f10's calibration fixture (v0.4 chunk 9; master spec 16.3, spec D209,
-- D213): the data file of the agency's reporting instance, as far as the
-- out-of-memory incident needs it. Not a scenario's file: chunk 15 writes
-- the scenario's; this is the draft the calibration measures.
--
-- Streamed by tools/tests/calibrate-f10.sh, as gmctl load-data would, into
--   psql -X -q -v ON_ERROR_STOP=1 -d postgres
-- run as the postgres OS user on reporting. The passwords are set after it
-- (load-data's steps, master spec 14): bi_etl's from its crontab secret,
-- the user mapping's from shop_etl's secret; never written here.
--
-- What it holds:
--   - the foreign server `shop` (db's database shop) and bi_etl's user
--     mapping to shop_etl;
--   - the foreign tables the roll-up reads, each declaring only the columns
--     the nightly close needs (master spec 9.6), src.orders without
--     customer_id (shop_etl may not read it);
--   - the run ledger rpt.etl_runs, the backfill request table and the
--     document table;
--   - the draft of rpt.sales_detail_rollup(), called from reporting's
--     crontab as bi_etl.
CREATE ROLE bi_etl LOGIN;
CREATE DATABASE reporting OWNER bi_etl;

\connect reporting
CREATE EXTENSION postgres_fdw;
CREATE SERVER shop FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'db', port '5432', dbname 'shop');
GRANT USAGE ON FOREIGN SERVER shop TO bi_etl;
CREATE USER MAPPING FOR bi_etl SERVER shop OPTIONS (user 'shop_etl');

SET ROLE bi_etl;
CREATE SCHEMA src;
CREATE SCHEMA rpt;

-- --- The shop's tables, over postgres_fdw ------------------------------------

CREATE FOREIGN TABLE src.orders (
    id         integer       NOT NULL,
    placed_at  timestamptz   NOT NULL,
    status     text          NOT NULL,
    total      numeric(10,2) NOT NULL,
    updated_at timestamptz   NOT NULL
) SERVER shop OPTIONS (schema_name 'public', table_name 'orders');

CREATE FOREIGN TABLE src.order_lines (
    order_id   integer       NOT NULL,
    product_id integer       NOT NULL,
    quantity   integer       NOT NULL,
    line_total numeric(10,2) NOT NULL
) SERVER shop OPTIONS (schema_name 'public', table_name 'order_lines');

CREATE FOREIGN TABLE src.products (
    id       integer NOT NULL,
    category text    NOT NULL
) SERVER shop OPTIONS (schema_name 'public', table_name 'products');

-- --- The agency's tables -----------------------------------------------------

-- The run ledger the agency's jobs on reporting write themselves (the shop's
-- etl_runs columns): a run's row is committed when it starts, so a run that
-- never ended stays without finished_at.
CREATE TABLE rpt.etl_runs (
    id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job          text        NOT NULL,
    started_at   timestamptz NOT NULL,
    finished_at  timestamptz,
    rows_read    bigint,
    rows_written bigint,
    watermark    timestamptz
);

-- A one-off request to recompute the last `days` days (in the story, the
-- agency changed its formula): planted by gmctl inject --at as a state
-- change. The roll-up takes the oldest one not yet taken, marks it taken
-- and commits before it computes; done_at once its document is written.
CREATE TABLE rpt.sales_detail_backfills (
    id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requested_at timestamptz NOT NULL DEFAULT now(),
    days         integer     NOT NULL CHECK (days > 0),
    reason       text        NOT NULL,
    taken_at     timestamptz,
    done_at      timestamptz
);

-- The agency's sales-detail document, one per run: every order changed in
-- the run's window, with its lines.
CREATE TABLE rpt.sales_detail (
    run_id       bigint      PRIMARY KEY REFERENCES rpt.etl_runs (id),
    window_start timestamptz NOT NULL,
    window_end   timestamptz NOT NULL,
    orders       integer     NOT NULL,
    lines        bigint      NOT NULL,
    built_at     timestamptz NOT NULL,
    document     jsonb       NOT NULL
);

-- --- The nightly sales-detail roll-up ----------------------------------------

-- The order lines changed since the last finished run (their order's
-- updated_at; one day back on the first run), or over a backfill request's
-- days, built into one document by one aggregate over the window
-- (jsonb_agg, one element per order with its lines) and inserted. The
-- window's rows are read once from the shop (a materialised CTE: the
-- remote join is pushed down, the aggregation stays in this backend), and
-- the aggregate holds every order of the window in memory until it
-- returns: unbounded by work_mem, unlike a sort or a hash aggregate.
-- Called from the crontab as `psql -c 'CALL rpt.sales_detail_rollup()'`,
-- which receives no result set. SECURITY INVOKER (the default): it reads
-- the shop as bi_etl's user mapping.
CREATE PROCEDURE rpt.sales_detail_rollup()
LANGUAGE plpgsql
AS $$
DECLARE
    v_end      timestamptz := clock_timestamp();
    v_start    timestamptz;
    v_request  bigint;
    v_days     integer;
    v_run      bigint;
    v_orders   integer;
    v_lines    bigint;
BEGIN
    SELECT id, days INTO v_request, v_days
      FROM rpt.sales_detail_backfills
     WHERE taken_at IS NULL
     ORDER BY requested_at, id
     LIMIT 1
       FOR UPDATE SKIP LOCKED;
    IF v_request IS NOT NULL THEN
        UPDATE rpt.sales_detail_backfills SET taken_at = clock_timestamp() WHERE id = v_request;
        v_start := v_end - make_interval(days => v_days);
    ELSE
        SELECT max(watermark) INTO v_start
          FROM rpt.etl_runs
         WHERE job = 'sales-detail-rollup' AND finished_at IS NOT NULL;
        v_start := coalesce(v_start, v_end - interval '1 day');
    END IF;
    INSERT INTO rpt.etl_runs (job, started_at)
    VALUES ('sales-detail-rollup', clock_timestamp())
    RETURNING id INTO v_run;
    -- The request taken and the run started, whatever happens next.
    COMMIT;

    INSERT INTO rpt.sales_detail (run_id, window_start, window_end, orders, lines, built_at,
                                  document)
    WITH changed AS MATERIALIZED (
        SELECT o.id, o.placed_at, o.status, o.total, o.updated_at,
               l.product_id, p.category, l.quantity, l.line_total
          FROM src.orders o
          JOIN src.order_lines l ON l.order_id = o.id
          JOIN src.products p ON p.id = l.product_id
         WHERE o.updated_at >= v_start AND o.updated_at < v_end
    ), per_order AS (
        SELECT jsonb_build_object(
                   'order', id, 'placed_at', placed_at, 'status', status, 'total', total,
                   'updated_at', updated_at,
                   'lines', jsonb_agg(jsonb_build_object(
                                'product', product_id, 'category', category,
                                'quantity', quantity, 'line_total', line_total)
                            ORDER BY product_id)) AS doc,
               count(*) AS lines
          FROM changed
         GROUP BY id, placed_at, status, total, updated_at
    )
    SELECT v_run, v_start, v_end, count(*), coalesce(sum(lines), 0), clock_timestamp(),
           coalesce(jsonb_agg(doc), '[]'::jsonb)
      FROM per_order
    RETURNING orders, lines INTO v_orders, v_lines;

    UPDATE rpt.etl_runs
       SET finished_at = clock_timestamp(), rows_read = v_lines, rows_written = 1,
           watermark = v_end
     WHERE id = v_run;
    IF v_request IS NOT NULL THEN
        UPDATE rpt.sales_detail_backfills SET done_at = clock_timestamp() WHERE id = v_request;
    END IF;
END
$$;

RESET ROLE;
