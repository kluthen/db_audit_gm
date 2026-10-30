-- The test domain's schema (tools/tests, v0.4 chunk 2).
CREATE ROLE shop NOLOGIN;
CREATE ROLE shop_app LOGIN;
CREATE DATABASE shop OWNER shop;
\connect shop
CREATE TABLE customers (id integer PRIMARY KEY, name text NOT NULL, email text NOT NULL);
