-- g3-mapping-public: a user mapping for PUBLIC on the shop's server: it
-- makes reporting a reader of the shop's classes (11.6), whatever its
-- remote role.
-- node: reporting
-- database: reporting
-- expect: G1=0 G2=0 G3=1 G4=0
\if :revert
DROP USER MAPPING FOR PUBLIC SERVER shop_db;
\else
CREATE USER MAPPING FOR PUBLIC SERVER shop_db OPTIONS (user 'shop_etl');
\endif
