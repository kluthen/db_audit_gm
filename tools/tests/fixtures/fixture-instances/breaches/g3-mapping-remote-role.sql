-- g3-mapping-remote-role: bi_etl's user mapping in reporting now connects
-- to the shop as shop_app, which reads personal and customer-linked data:
-- the mapping (and the foreign table src.orders, over orders.customer_id)
-- reach them from reporting.
-- node: reporting
-- database: reporting
-- expect: G1=0 G2=0 G3=1 G4=0
\if :revert
ALTER USER MAPPING FOR bi_etl SERVER shop_db OPTIONS (SET user 'shop_etl');
\else
ALTER USER MAPPING FOR bi_etl SERVER shop_db OPTIONS (SET user 'shop_app');
\endif
