-- data.sql of partners-db, the partners' shared database (v0.5 master spec
-- 10.2; capture W2 items 0 and 6; partners/README.md): the database
-- partners. The GM copies this file first into the node's data file
-- (scenario.yaml's data.file), then, after it, cold storage's
-- partners/coldstore/data.sql and planted.sql when the scenario has a
-- vault. load-data streams the data file into psql as postgres, connected
-- to the database postgres, before any domain (W2 item 3, step 1); each
-- composed domain's producers/partners/<prefix>/data.sql then runs in
-- partners on its own (chunk 8).
--
-- Nothing else lives here: each partner brings its role (<prefix>, LOGIN,
-- no password: render's secret role_<prefix>_password, set by load-data),
-- its schema <prefix> owned by it, its tables and its state table
-- <prefix>.state (partners/README.md, "A partner's state").
CREATE DATABASE partners;

-- What the GM appends below runs in partners.
\connect partners
