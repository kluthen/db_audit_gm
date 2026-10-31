-- g1-renamed-matview: a materialized view in reporting holding an e-mail
-- address under another name (G1's probe covers materialized views).
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=0 G4=0
\if :revert
DROP MATERIALIZED VIEW rpt.mailing;
\else
CREATE MATERIALIZED VIEW rpt.mailing AS SELECT 'customer3@example.org'::varchar(80) AS addr;
\endif
