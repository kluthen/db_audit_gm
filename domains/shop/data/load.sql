-- The shop domain's history (master spec 6.8, 9): last night's backup of
-- Tarnbeck Outdoor's database, at tarnbeck-outdoor-shop's sizes. Runs
-- after schema.sql, in the same psql session, as the postgres OS user.
--
-- It reads load-data's two psql variables (master spec 8.5; capture W1,
-- item 0): customer_timezone, the customer's zone (Etc/GMT-2 for UTC+2,
-- Etc/GMT at a shift of 0), and customer_utc_offset, its offset from UTC
-- in whole hours, east positive (2, -5, 0). Every time in the database is
-- UTC; the customer's zone lives in business_settings and in the
-- customers' own zones, which are offsets relative to it.
--
-- Sizes: 20 000 customers (a third lapsed: their last order 60 to 365
-- days old, from an archived history), 2 000 products, 300 000 orders over
-- the last fifteen days with 900 000 lines, 60 000 delivery events, about
-- 17 000 consent events, one active win-back campaign. The purposes'
-- outboxes, acknowledgements, incidents, leads and run ledger start empty.
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_timezone is not set '
                            '(gmctl load-data passes -v customer_timezone=<zone>)'; END $$;
\endif
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_utc_offset is not set '
                            '(gmctl load-data passes -v customer_utc_offset=<hours>)'; END $$;
\endif

\connect shop
SET ROLE shop;

-- --- Session helpers, gone with the session ----------------------------------

-- The fixed zone UTC+o, as render names it: Etc/GMT-N for UTC+N.
CREATE FUNCTION pg_temp.zone_name(o integer) RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN o = 0 THEN 'Etc/GMT'
                WHEN o > 0 THEN 'Etc/GMT-' || o
                ELSE 'Etc/GMT+' || -o END
$$;
-- An offset wrapped modulo 24 into UTC-12..UTC+14, the offsets Etc/GMT
-- names, as render wraps a job's zone: the local hour is kept.
CREATE FUNCTION pg_temp.wrap_offset(o integer) RETURNS integer LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN o > 14 THEN o - 24 WHEN o < -12 THEN o + 24 ELSE o END
$$;

-- --- Business settings (9.2) -------------------------------------------------

INSERT INTO business_settings (timezone, utc_offset_hours)
VALUES (:'customer_timezone', :customer_utc_offset);

DO $$
DECLARE
    s business_settings;
BEGIN
    SELECT * INTO s FROM business_settings;
    IF NOT EXISTS (SELECT 1 FROM pg_timezone_names
                    WHERE name = s.timezone
                      AND utc_offset = make_interval(hours => s.utc_offset_hours)) THEN
        RAISE EXCEPTION 'load.sql: customer_timezone % is not UTC% (customer_utc_offset)',
            s.timezone, CASE WHEN s.utc_offset_hours < 0 THEN '' ELSE '+' END
                        || s.utc_offset_hours;
    END IF;
END $$;

-- --- Customers (9.3) ---------------------------------------------------------

-- Each customer's buckets, spread over the ids (37, 53 and 13 are coprime
-- with 100), so the web shop's uniform picks reach every kind:
--   order bucket (id * 37) % 100: 0-59 ordered in the last fifteen days;
--     60-64 last ordered 16 to 59 days ago; 65-97 lapsed, last order 60 to
--     365 days ago (a third of the customers); 98-99 never ordered;
--   country bucket (id * 53) % 100: 91 % inside the customs union, 9 %
--     outside it (CH, GB, NO, US);
--   zone bucket (id / 100) % 20: 80 % at the customer's offset, 5 % each
--     at -1 h, +1 h, -8 h and +5 h (9.3), so every campaign batch has
--     recipients outside their sending hours.
-- The order, country and consent buckets (below) depend on id % 100 only,
-- the zone bucket on id / 100 only: each id % 100 meets each zone bucket
-- ten times, so every zone holds the same mix of lapsed customers with and
-- without consent. (A zone bucket of id % 20 lined up with the others: no
-- lapsed customer at +5 h had consent, and no batch from 16:00 a witness.)
CREATE TEMP TABLE customer_kinds AS
SELECT g AS id,
       (g * 37) % 100 AS order_bucket,
       CASE WHEN (g * 53) % 100 < 64 THEN 'DE' WHEN (g * 53) % 100 < 72 THEN 'AT'
            WHEN (g * 53) % 100 < 77 THEN 'FR' WHEN (g * 53) % 100 < 82 THEN 'NL'
            WHEN (g * 53) % 100 < 86 THEN 'IT' WHEN (g * 53) % 100 < 88 THEN 'DK'
            WHEN (g * 53) % 100 < 91 THEN 'BE' WHEN (g * 53) % 100 < 95 THEN 'CH'
            WHEN (g * 53) % 100 < 97 THEN 'GB' WHEN (g * 53) % 100 < 99 THEN 'NO'
            ELSE 'US' END AS country,
       (ARRAY[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1, -8, 5])[1 + (g / 100) % 20]
           AS zone_delta
  FROM generate_series(1, 20000) AS g;

INSERT INTO customers (id, name, email, address, country, timezone, created_at)
SELECT k.id, n.first || ' ' || n.last,
       lower(n.first || '.' || n.last || '.' || k.id) || '@example.net',
       (1 + k.id % 180) || ' '
           || (ARRAY['Birch Lane', 'Station Road', 'Mill Street', 'Lake View', 'Hill Road',
                     'Market Square', 'Forest Way', 'River Walk'])[1 + k.id % 8]
           || ', ' || lpad(((k.id * 7307) % 90000 + 10000)::text, 5, '0') || ' '
           || CASE k.country
                  WHEN 'DE' THEN (ARRAY['Berlin', 'Hamburg', 'Leipzig', 'Freiburg', 'Kassel'])
                                 [1 + k.id % 5]
                  WHEN 'AT' THEN (ARRAY['Wien', 'Graz', 'Innsbruck'])[1 + k.id % 3]
                  WHEN 'FR' THEN (ARRAY['Lyon', 'Grenoble', 'Lille'])[1 + k.id % 3]
                  WHEN 'NL' THEN (ARRAY['Utrecht', 'Leiden', 'Arnhem'])[1 + k.id % 3]
                  WHEN 'IT' THEN (ARRAY['Bolzano', 'Torino', 'Trento'])[1 + k.id % 3]
                  WHEN 'DK' THEN (ARRAY['Aarhus', 'Odense'])[1 + k.id % 2]
                  WHEN 'BE' THEN (ARRAY['Gent', 'Namur'])[1 + k.id % 2]
                  WHEN 'CH' THEN (ARRAY['Bern', 'Chur', 'Luzern'])[1 + k.id % 3]
                  WHEN 'GB' THEN (ARRAY['Kendal', 'Keswick', 'Inverness'])[1 + k.id % 3]
                  WHEN 'NO' THEN (ARRAY['Bergen', 'Tromso'])[1 + k.id % 2]
                  ELSE (ARRAY['Boulder', 'Bend'])[1 + k.id % 2] END,
       k.country,
       pg_temp.zone_name(pg_temp.wrap_offset(:customer_utc_offset + k.zone_delta)),
       now() - interval '3 years' + k.id * interval '1 hour'
  FROM customer_kinds k
 CROSS JOIN LATERAL (
       SELECT (ARRAY['Anna', 'Ben', 'Clara', 'David', 'Elif', 'Felix', 'Greta', 'Hugo', 'Ines',
                     'Jonas', 'Karin', 'Lukas', 'Mira', 'Noah', 'Olga', 'Paul', 'Rosa', 'Samir',
                     'Tilda', 'Viktor'])[1 + k.id % 20] AS first,
              (ARRAY['Achterberg', 'Brandt', 'Castell', 'Dahl', 'Eder', 'Fontaine', 'Gruber',
                     'Hansen', 'Iversen', 'Jansen', 'Keller', 'Lindqvist', 'Moreau', 'Novak',
                     'Olsen', 'Peters', 'Quist', 'Richter', 'Svensson', 'Tanaka', 'Urban',
                     'Vogel', 'Weber', 'Young', 'Zimmer'])[1 + (k.id / 20) % 25] AS last) AS n;

INSERT INTO products (id, sku, name, category, price, stock)
SELECT g, 'TB-' || lpad(g::text, 5, '0'),
       (ARRAY['Tent', 'Sleeping bag', 'Backpack', 'Boots', 'Jacket', 'Stove', 'Head torch',
              'Water bottle'])[1 + g % 8] || ' ' || g,
       (ARRAY['tents', 'sleeping-bags', 'backpacks', 'footwear', 'clothing', 'stoves', 'lighting',
              'accessories'])[1 + g % 8],
       round((5 + (g * 37) % 395)::numeric + 0.90, 2), 50 + (g * 13) % 450
  FROM generate_series(1, 2000) AS g;

INSERT INTO export_countries (country)
VALUES ('CH'), ('GB'), ('NO'), ('IS'), ('US'), ('CA');

-- --- Orders (9.4) ------------------------------------------------------------

-- The 12 000 customers who ordered in the last fifteen days, numbered.
CREATE TEMP TABLE recent_customers AS
SELECT row_number() OVER (ORDER BY id) AS n, id, country
  FROM customer_kinds WHERE order_bucket < 60;
ALTER TABLE recent_customers ADD PRIMARY KEY (n);

-- 300 000 orders over the last fifteen days, one every 4.32 s, each with
-- one to five lines (900 000 lines); the newest are still being packed and
-- shipped, the rest invoiced. Packed 20 minutes to 6 hours after the
-- order, shipped half an hour to 10 hours after packing, never later than
-- now; one order in 25 ships to another country than the customer's.
INSERT INTO orders (id, customer_id, placed_at, status, total, updated_at, packed_at, shipped_at,
                    ship_country)
SELECT g, r.id, t.placed_at, s.status, b.total,
       CASE s.status WHEN 'invoiced' THEN d.invoiced_at WHEN 'shipped' THEN d.shipped_at
                     WHEN 'packed' THEN d.packed_at ELSE t.placed_at END,
       CASE WHEN s.status <> 'paid' THEN d.packed_at END,
       CASE WHEN s.status IN ('shipped', 'invoiced') THEN d.shipped_at END,
       CASE WHEN g % 25 = 0 THEN (ARRAY['DE', 'FR', 'NL', 'AT', 'CH', 'GB', 'NO'])[1 + (g / 25) % 7]
            ELSE r.country END
  FROM generate_series(1, 300000) AS g
  JOIN recent_customers r ON r.n = 1 + (g::bigint * 7919) % 12000
 CROSS JOIN LATERAL (
       SELECT now() - interval '15 days' + g * interval '4.32 seconds' AS placed_at) AS t
 CROSS JOIN LATERAL (
       SELECT CASE WHEN g <= 280000 THEN 'invoiced' WHEN g <= 290000 THEN 'shipped'
                   WHEN g <= 295000 THEN 'packed' ELSE 'paid' END AS status) AS s
 CROSS JOIN LATERAL (
       SELECT least(t.placed_at + (20 + (g * 17) % 340) * interval '1 minute',
                    now() - interval '1 minute') AS packed_at) AS p
 CROSS JOIN LATERAL (
       SELECT p.packed_at,
              least(p.packed_at + (30 + (g * 29) % 600) * interval '1 minute',
                    now() - interval '30 seconds') AS shipped_at,
              least(p.packed_at + (30 + (g * 29) % 600) * interval '1 minute'
                        + (1 + g % 20) * interval '1 hour',
                    now() - interval '10 seconds') AS invoiced_at) AS d
 CROSS JOIN LATERAL (
       SELECT sum((1 + (g + k) % 3) * pr.price) AS total
         FROM generate_series(1, 1 + g % 5) AS k
         JOIN products pr ON pr.id = 1 + (g * 31 + k * 97) % 2000) AS b;
SELECT setval(pg_get_serial_sequence('orders', 'id'), 300000);

INSERT INTO order_lines (order_id, product_id, sku, product_name, quantity, unit_price, vat_rate,
                         line_total, created_at)
SELECT g, p.id, p.sku, p.name, 1 + (g + k) % 3, p.price, 20.00, (1 + (g + k) % 3) * p.price,
       now() - interval '15 days' + g * interval '4.32 seconds'
  FROM generate_series(1, 300000) AS g
 CROSS JOIN LATERAL generate_series(1, 1 + g % 5) AS k
  JOIN products p ON p.id = 1 + (g * 31 + k * 97) % 2000;

-- --- The archived history (9.5) ----------------------------------------------

-- Older orders were archived away: what is left of them is each
-- customer's last order and lifetime value. A customer who ordered in the
-- last fifteen days has their latest order; the others' last order comes
-- from the archive, never before their account was opened.
UPDATE customers c
   SET last_order_at = CASE
           WHEN k.order_bucket < 60 THEN s.last_order_at
           WHEN k.order_bucket < 65 THEN
               greatest(now() - (16 + (c.id * 7) % 44) * interval '1 day'
                              - (c.id % 86400) * interval '1 second',
                        c.created_at + interval '1 day')
           WHEN k.order_bucket < 98 THEN
               greatest(now() - (61 + (c.id * 7) % 304) * interval '1 day'
                              - (c.id % 86400) * interval '1 second',
                        c.created_at + interval '1 day')
       END,
       lifetime_value = CASE WHEN k.order_bucket < 98
                             THEN round((40 + (c.id * 53) % 600)::numeric * (1 + c.id % 3), 2)
                             ELSE 0 END
                        + coalesce(s.invoiced, 0)
  FROM customer_kinds k
  LEFT JOIN (SELECT customer_id, max(placed_at) AS last_order_at,
                    sum(total) FILTER (WHERE status = 'invoiced') AS invoiced
               FROM orders GROUP BY customer_id) s ON s.customer_id = k.id
 WHERE c.id = k.id;

UPDATE products p SET sold = s.quantity
  FROM (SELECT product_id, sum(quantity) AS quantity FROM order_lines GROUP BY product_id) s
 WHERE p.id = s.product_id;

-- 60 000 delivery events over the same fifteen days.
INSERT INTO delivery_events (event_id, order_id, status, received_at)
SELECT gen_random_uuid(), g * 5,
       (ARRAY['picked-up', 'in-transit', 'delivered', 'failed'])[1 + g % 4],
       now() - interval '15 days' + g * interval '21.6 seconds'
  FROM generate_series(1, 60000) AS g;

-- --- The consent history (9.3) -----------------------------------------------

-- 64 % granted marketing e-mail at their first checkout; 22 % of those
-- withdrew later (the unsubscribe link, one in five through support); 15 %
-- of those without consent then granted it again at a later checkout.
-- The opt-in flag is the latest event's state: right at the backup.
INSERT INTO consent_events (customer_id, purpose, granted, at, source)
SELECT customer_id, 'marketing-email', granted, at, source
  FROM (SELECT c.id AS customer_id, e.granted, e.at, e.source
          FROM customers c
         CROSS JOIN LATERAL (
               SELECT (c.id * 13) % 100 < 64 AS first_grant,
                      (c.id * 13) % 100 < 64 AND (c.id * 17) % 100 < 22 AS withdrew,
                      c.created_at + (5 + (c.id * 31) % 95) / 100.0 * (now() - c.created_at)
                          AS withdrew_at) AS h
         CROSS JOIN LATERAL (
               SELECT h.*, (NOT h.first_grant OR h.withdrew) AND (c.id * 19) % 100 < 15
                               AS regranted,
                      CASE WHEN h.withdrew THEN h.withdrew_at ELSE c.created_at END
                          AS base_at) AS h2
         CROSS JOIN LATERAL (
               SELECT true AS granted, c.created_at AS at, 'checkout' AS source
                WHERE h2.first_grant
               UNION ALL
               SELECT false, h2.withdrew_at,
                      CASE WHEN c.id % 5 = 0 THEN 'support' ELSE 'unsubscribe-link' END
                WHERE h2.withdrew
               UNION ALL
               SELECT true,
                      h2.base_at + (10 + (c.id * 23) % 90) / 100.0 * (now() - h2.base_at),
                      'checkout'
                WHERE h2.regranted) AS e) AS events
 ORDER BY at;

UPDATE customers c SET marketing_opt_in = l.granted
  FROM (SELECT DISTINCT ON (customer_id) customer_id, granted
          FROM consent_events WHERE purpose = 'marketing-email'
         ORDER BY customer_id, at DESC, id DESC) l
 WHERE c.id = l.customer_id;

-- --- The win-back campaign (9.6) ---------------------------------------------

-- Launched today; its first extraction runs tonight.
INSERT INTO campaigns (code, segment, starts_on, ends_on, active)
VALUES ('winback-' || to_char(current_date, 'YYYY-MM'), 'winback', current_date,
        current_date + 28, true);

-- --- The best sellers --------------------------------------------------------

REFRESH MATERIALIZED VIEW popular_products;

RESET ROLE;
VACUUM (ANALYZE) business_settings, customers, consent_events, products, orders, order_lines,
                 delivery_events, export_countries, campaigns, popular_products;
