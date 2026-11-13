-- Data of records, the archive fixture's archiving node (tools/tests, v0.5
-- chunks 11b and 23): the short tests' filler, in a database of its own,
-- fill, whose writes fill the WAL segments they switch. load-data runs it
-- before vet-core's load, which creates clinic (the domain's at:,
-- records/clinic; capture W5 item 2). No business data: the register
-- covers clinic only.
CREATE DATABASE fill;

\connect fill
CREATE TABLE fill_rows (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    n          integer NOT NULL,
    written_at timestamptz NOT NULL
);
INSERT INTO fill_rows (n, written_at)
SELECT g, now() - (g || ' minutes')::interval FROM generate_series(1, 2000) AS g;
