-- The test part's schema (tools/tests, v0.5 chunk 2).
CREATE ROLE part_app LOGIN;
CREATE TABLE part_boxes (id integer PRIMARY KEY, owner_id integer NOT NULL);
