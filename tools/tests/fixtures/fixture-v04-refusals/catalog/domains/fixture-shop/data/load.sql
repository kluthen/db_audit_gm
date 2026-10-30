-- The test domain's history (tools/tests, v0.4 chunk 2).
\connect shop
INSERT INTO customers SELECT g, 'customer ' || g, g || '@example.org' FROM generate_series(1, 10) AS g;
