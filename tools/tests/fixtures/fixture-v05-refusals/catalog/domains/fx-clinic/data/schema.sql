-- The test core's schema (tools/tests, v0.5 chunk 6): run connected to its
-- database (W2 item 3), never creating it.
CREATE ROLE clinic_app LOGIN;
CREATE TABLE owners (id integer PRIMARY KEY, name text NOT NULL);

CREATE FUNCTION owner_name(owner integer) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path = pg_catalog, public
AS $$ SELECT name FROM owners WHERE id = owner; $$;
