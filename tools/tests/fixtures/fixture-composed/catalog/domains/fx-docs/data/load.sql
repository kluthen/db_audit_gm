-- The test part's load (tools/tests, v0.5 chunk 8): a request per stay, from
-- the core's key function; the documents are derived (data/derive.sql).
INSERT INTO doc_requests SELECT pg_temp.core_stay(n) FROM generate_series(1, 6) AS n;
