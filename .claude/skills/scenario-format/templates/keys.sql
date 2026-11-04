-- keys.sql — template for domains/<core-id>/data/keys.sql, a core's key
-- functions, and for domains/<part-id>/data/keys.sql, a part's
--
-- Version v0.5, expected to evolve as games are played.
-- Shape: v0.5 master spec 8.5, 9.2; capture W2 items 3 and 4 of
-- specs/versions/v0.5/wave-log.md. Optional: a core ships one when its parts
-- or its partners compute its ids (a fixed path, no domain.yaml key).
--
-- load-data streams this file ahead of the core's load.sql, each of its
-- parts' load.sql, each partner data.sql of the core and its parts, and each
-- of their derive.sql, in the same psql session; never ahead of a schema.sql
-- or a purpose's history. So:
--   - every function is created in pg_temp, as pg_temp.core_<name>, and is
--     called as pg_temp.core_<name>(...) (PostgreSQL never looks a function
--     up in pg_temp unqualified); it vanishes with the session, so nothing
--     reaches the catalog the players read;
--   - the file creates nothing else: no table, no role, no SET;
--   - IMMUTABLE, a pure function of its arguments, a function computing a
--     time included: it takes load_epoch as an argument (D379); a load
--     passes :'load_epoch'::timestamptz, never now();
--   - each function is listed in docs/gm.md's "Core keys", with its
--     arguments, what it returns and this file's formula; a part names those
--     it relies on in its "Core keys used", and the composition record's
--     keys: lists them per part.
-- A part's keys.sql (from v0.5 chunk 29, capture W3 item 0) follows the same
-- rules under its own prefix: pg_temp.<its table prefix>_* (lab_, portal_),
-- one prefix, never core_ nor a prefix of the core's file (model.
-- check_domain_dir refuses either); streamed after the core's, in the same
-- session, ahead of that part's load.sql, its partners' data.sql and its
-- derive.sql; listed in the part's docs/gm.md "Part keys". A part's function
-- may call the core's (pg_temp.core_<name>(...)).
-- Replace every <placeholder>. A filled file keeps none.

CREATE FUNCTION pg_temp.core_<animal>(n integer) RETURNS integer
  LANGUAGE sql IMMUTABLE AS 'SELECT <1000000> + n';

CREATE FUNCTION pg_temp.core_<admitted>(n integer, load_epoch timestamptz) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE AS 'SELECT load_epoch - n * interval ''<1 day>''';
