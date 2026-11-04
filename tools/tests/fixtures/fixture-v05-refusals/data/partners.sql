-- The partners' database (tools/tests, v0.5 chunk 6; W2 item 0): the
-- external lab's role and schema.
CREATE ROLE xlab LOGIN;
CREATE DATABASE partners;

\connect partners
CREATE SCHEMA xlab AUTHORIZATION xlab;
CREATE TABLE xlab.orders (id integer PRIMARY KEY, client_ref text NOT NULL);
ALTER TABLE xlab.orders OWNER TO xlab;
