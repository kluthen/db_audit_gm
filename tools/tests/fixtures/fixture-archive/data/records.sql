-- Data of records, the archive fixture's archiving node (tools/tests, v0.5
-- chunk 11b): a small clinic database whose writes fill the WAL segments the
-- short test switches and archives.
CREATE DATABASE clinic;

\connect clinic
CREATE TABLE visits (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    animal_id integer NOT NULL,
    seen_at   timestamptz NOT NULL
);
INSERT INTO visits (animal_id, seen_at)
SELECT 1 + g % 400, now() - (g || ' minutes')::interval FROM generate_series(1, 2000) AS g;
