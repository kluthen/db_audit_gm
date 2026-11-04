-- The test core's key functions (tools/tests, v0.5 chunk 8): streamed by
-- load-data ahead of every load, partner file and derivation of the core and
-- its parts, in their session; in pg_temp, so they vanish with it.
CREATE FUNCTION pg_temp.core_animal(n integer) RETURNS integer
  LANGUAGE sql IMMUTABLE AS 'SELECT 1000 + n';
CREATE FUNCTION pg_temp.core_stay(n integer) RETURNS integer
  LANGUAGE sql IMMUTABLE AS 'SELECT 5000 + n';
CREATE FUNCTION pg_temp.core_admitted(n integer, load_epoch timestamptz) RETURNS timestamptz
  LANGUAGE sql STABLE AS 'SELECT load_epoch - n * interval ''1 day''';
