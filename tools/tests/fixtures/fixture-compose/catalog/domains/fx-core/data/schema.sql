-- The test core's schema (tools/tests, v0.5 chunk 2).
CREATE ROLE core NOLOGIN;
CREATE ROLE core_app LOGIN;
CREATE DATABASE clinic OWNER core;
\connect clinic
CREATE TABLE owners (id integer PRIMARY KEY, name text NOT NULL);
