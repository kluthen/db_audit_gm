-- g2-through-public: customers' e-mails granted to PUBLIC: shop_etl, a
-- login role connecting to the shop, may read them (G2 through PUBLIC); and
-- reporting's mapping to shop_etl now reaches them (G3).
-- node: db
-- database: shop
-- expect: G1=0 G2=1 G3=1 G4=0
\if :revert
REVOKE SELECT (email) ON customers FROM PUBLIC;
\else
GRANT SELECT (email) ON customers TO PUBLIC;
\endif
