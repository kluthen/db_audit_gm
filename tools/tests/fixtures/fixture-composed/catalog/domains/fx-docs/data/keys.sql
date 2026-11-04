-- The test part's key functions (tools/tests, v0.5 chunk 29's (a)): streamed by
-- load-data after the core's keys, ahead of fx-docs' load and derivation, in
-- their session; pg_temp.docs_* only, so they vanish with it.
CREATE FUNCTION pg_temp.docs_request(n integer) RETURNS integer
  LANGUAGE sql IMMUTABLE AS 'SELECT pg_temp.core_stay(n)';
CREATE FUNCTION pg_temp.docs_title(name text, species text) RETURNS text
  LANGUAGE sql IMMUTABLE AS 'SELECT name || '' ('' || species || '')''';
