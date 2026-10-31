-- g4-extra-key: a row sent to the mail provider whose payload carries a key
-- the flow does not list (address).
-- node: db
-- database: shop
-- expect: G1=0 G2=0 G3=0 G4=1
\if :revert
DELETE FROM mail_outbox WHERE payload ? 'address';
\else
INSERT INTO mail_outbox (customer_id, payload, sent_at)
VALUES (1, '{"email": "customer1@example.org", "name": "Customer 1", "order_id": 20, "address": "1 High Street"}', now());
\endif
