-- The test part's schema (tools/tests, v0.5 chunk 8), in a database of its
-- own; a contrib extension, run as postgres (master spec 24).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE docs_app LOGIN;
GRANT CONNECT ON DATABASE :"DBNAME" TO docs_app;
CREATE TABLE doc_requests (stay_id integer PRIMARY KEY);
CREATE TABLE documents (stay_id integer PRIMARY KEY, title text NOT NULL,
                        digest text NOT NULL);
