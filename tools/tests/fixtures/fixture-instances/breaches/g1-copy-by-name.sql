-- g1-copy-by-name: customers' ids and e-mails copied into reporting under
-- their own names, rpt.customers (G1 by name; owned by postgres, granted to
-- nobody, so no customer role reads it: G2 and G3 hold).
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=0 G4=0
\if :revert
DROP TABLE rpt.customers;
\else
CREATE TABLE rpt.customers (id integer, email text);
INSERT INTO rpt.customers VALUES (1, 'customer1@example.org');
\endif
