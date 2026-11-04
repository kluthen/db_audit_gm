-- The test part's load (tools/tests, v0.5 chunk 8): each current stay placed,
-- its id from the core's key function, never read from the core's tables.
INSERT INTO ward_placements
SELECT n, pg_temp.core_stay(n), 'unit-' || n,
       tstzrange(pg_temp.core_admitted(n, :'load_epoch'), NULL)
  FROM generate_series(1, 4) AS n;
