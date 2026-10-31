-- g1-separation-database: a second database, scratch, created empty on db,
-- the instance personal's location db/shop must have to itself
-- (separation: instance; G1 by node, spec D253). CREATE and DROP DATABASE
-- run outside a transaction: psql reads them one by one in autocommit.
-- node: db
-- database: shop
-- expect: G1=1 G2=0 G3=0 G4=0
-- first: db/scratch database shares the instance of db/shop, where personal data lives
\if :revert
DROP DATABASE scratch;
\else
CREATE DATABASE scratch;
\endif
