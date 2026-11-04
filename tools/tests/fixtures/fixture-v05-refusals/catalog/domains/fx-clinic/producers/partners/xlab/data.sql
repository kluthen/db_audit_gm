-- The external lab's state in the partners' database (tools/tests, v0.5
-- chunk 6; W2 items 1 and 3): its misbehaviour key's table.
CREATE TABLE xlab.state (hostname text, name text, value text NOT NULL,
                         set_at timestamptz NOT NULL DEFAULT now(),
                         PRIMARY KEY (hostname, name));
CREATE OR REPLACE FUNCTION xlab.normal() RETURNS void
    LANGUAGE sql SECURITY DEFINER SET search_path TO xlab, pg_catalog
AS $f$ INSERT INTO xlab.state (hostname, name, value) VALUES ('northfield-lab', 'mode', 'normal')
       ON CONFLICT (hostname, name) DO UPDATE SET value = 'normal'; $f$;
