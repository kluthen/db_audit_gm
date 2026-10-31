-- g1-view-customer-linked: a view in reporting named as the shop's orders,
-- with a customer_id column: customer-linked data where it may not live
-- (G1 by name, a view).
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=0 G4=0
\if :revert
DROP VIEW rpt.orders;
\else
CREATE VIEW rpt.orders AS SELECT 1 AS id, 7 AS customer_id;
\endif
