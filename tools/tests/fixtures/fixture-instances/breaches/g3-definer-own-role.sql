-- g3-definer-own-role: a SECURITY DEFINER function owned by postgres, one of
-- the game's own roles, in reporting where a foreign table maps the shop's
-- e-mails: judged all the same (D230), a superuser reaching every classed
-- column of its database. The foreign table alone is G1's, not G3's
-- (g1-foreign-table). No schema_name: read as public (capture W3-a item 4).
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=1 G4=0
\if :revert
DROP FUNCTION rpt.peek();
DROP FOREIGN TABLE src.people;
\else
CREATE FOREIGN TABLE src.people (contact text OPTIONS (column_name 'email'))
    SERVER shop_db OPTIONS (table_name 'customers');
CREATE FUNCTION rpt.peek() RETURNS bigint LANGUAGE sql SECURITY DEFINER
    AS 'SELECT count(*) FROM src.people';
\endif
