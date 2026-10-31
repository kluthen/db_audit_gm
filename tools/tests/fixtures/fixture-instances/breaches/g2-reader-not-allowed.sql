-- g2-reader-not-allowed: a new login role in the shop, not one of the
-- policy's readers, granted the customers table.
-- node: db
-- database: shop
-- expect: G1=0 G2=1 G3=0 G4=0
\if :revert
REVOKE ALL ON customers FROM shop_audit;
REVOKE CONNECT ON DATABASE shop FROM shop_audit;
DROP ROLE shop_audit;
\else
CREATE ROLE shop_audit LOGIN;
GRANT CONNECT ON DATABASE shop TO shop_audit;
GRANT SELECT ON customers TO shop_audit;
\endif
