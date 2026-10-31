-- g1-foreign-table: a foreign table in reporting over the shop's customers,
-- columns renamed (G1 by the remote column it maps). Owned by postgres and
-- read through bi_etl's mapping as shop_etl, which reads no classed column:
-- G3 holds.
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=0 G4=0
\if :revert
DROP FOREIGN TABLE src.people;
\else
CREATE FOREIGN TABLE src.people (who integer OPTIONS (column_name 'id'),
                                 contact text OPTIONS (column_name 'email'))
    SERVER shop_db OPTIONS (schema_name 'public', table_name 'customers');
\endif
