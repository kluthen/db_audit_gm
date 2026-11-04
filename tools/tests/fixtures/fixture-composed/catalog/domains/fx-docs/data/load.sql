-- The test part's load (tools/tests, v0.5 chunk 8): a request per stay, from
-- its own key function over the core's (chunk 29's (a)); the documents are
-- derived (data/derive.sql).
INSERT INTO doc_requests SELECT pg_temp.docs_request(n) FROM generate_series(1, 6) AS n;
