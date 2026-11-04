-- The test part's schema (tools/tests, v0.5 chunk 8): a contrib extension,
-- run as postgres (master spec 24).
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE ROLE ward_app LOGIN;
GRANT CONNECT ON DATABASE :"DBNAME" TO ward_app;
CREATE TABLE ward_placements (id integer PRIMARY KEY, stay_id integer NOT NULL,
                              unit text NOT NULL, during tstzrange NOT NULL,
                              EXCLUDE USING gist (unit WITH =, during WITH &&));
