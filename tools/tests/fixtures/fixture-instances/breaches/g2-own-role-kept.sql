-- g2-own-role-kept: monitoring, one of the game's own roles (a login role
-- on every postgres node choosing the option monitoring, as
-- smoke-governance.sh sets on db; v0.5), granted the customers table:
-- skipped as a reader by name (11.6, D230), so G2 holds.
-- node: db
-- database: shop
-- expect: G1=0 G2=0 G3=0 G4=0
\if :revert
REVOKE SELECT ON customers FROM monitoring;
REVOKE CONNECT ON DATABASE shop FROM monitoring;
\else
GRANT CONNECT ON DATABASE shop TO monitoring;
GRANT SELECT ON customers TO monitoring;
\endif
