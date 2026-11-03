-- Stack test fixture of the api brick: the two databases its nodes reach,
-- the application roles (passwords as psql variables) and a SECURITY
-- DEFINER function on each side. Run as postgres on the db node.
CREATE ROLE lab_api LOGIN PASSWORD :'lab_api';
CREATE ROLE xlab LOGIN PASSWORD :'xlab';
CREATE DATABASE lab;
CREATE DATABASE partners;
\c lab
CREATE TABLE orders (id int PRIMARY KEY, label text NOT NULL);
INSERT INTO orders VALUES (1, 'first'), (2, 'second');
GRANT SELECT, INSERT ON orders TO lab_api;
CREATE TABLE owner_audit (who text, owner text, at timestamptz DEFAULT now());
CREATE FUNCTION record_owner() RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ INSERT INTO owner_audit (who, owner) VALUES (session_user, current_setting('portal.owner_id', true))
      RETURNING current_user::text $$;
REVOKE ALL ON FUNCTION record_owner() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION record_owner() TO lab_api;
\c partners
CREATE TABLE results (order_id int, label text, by_role text);
CREATE FUNCTION record_result(int, text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ INSERT INTO results VALUES ($1, $2, session_user) RETURNING current_user::text $$;
REVOKE ALL ON FUNCTION record_result(int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION record_result(int, text) TO xlab;
