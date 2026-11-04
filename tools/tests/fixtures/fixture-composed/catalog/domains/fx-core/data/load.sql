-- The test core's load (tools/tests, v0.5 chunk 8): ten animals, six stays,
-- the first four current, every time from :'load_epoch'.
INSERT INTO animals
SELECT pg_temp.core_animal(n), 'animal ' || n, CASE WHEN n % 2 = 0 THEN 'cat' ELSE 'dog' END
  FROM generate_series(1, 10) AS n;
INSERT INTO stays
SELECT pg_temp.core_stay(n), pg_temp.core_animal(n),
       pg_temp.core_admitted(n, :'load_epoch'),
       CASE WHEN n > 4 THEN :'load_epoch'::timestamptz - interval '1 hour' END
  FROM generate_series(1, 6) AS n;
