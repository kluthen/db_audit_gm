-- The external lab's state (tools/tests, v0.5 chunk 8): run by load-data into
-- the partners' database after fx-core's load, the core's keys ahead of it.
CREATE ROLE xlab LOGIN;
GRANT CONNECT ON DATABASE :"DBNAME" TO xlab;
CREATE SCHEMA xlab AUTHORIZATION xlab;
CREATE TABLE xlab.requests (stay_id integer PRIMARY KEY, sent_at timestamptz NOT NULL);
CREATE TABLE xlab.state (hostname text, name text, value text NOT NULL,
                         set_at timestamptz NOT NULL DEFAULT now(),
                         PRIMARY KEY (hostname, name));
INSERT INTO xlab.requests
SELECT pg_temp.core_stay(n), :'load_epoch'::timestamptz - interval '2 hours'
  FROM generate_series(1, 4) AS n;
INSERT INTO xlab.state VALUES ('xlab', 'mode', 'normal', :'load_epoch');
ALTER TABLE xlab.requests OWNER TO xlab;
ALTER TABLE xlab.state OWNER TO xlab;
