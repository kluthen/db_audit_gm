-- The test core's schema (tools/tests, v0.5 chunk 8), run connected to its
-- database, named :"DBNAME".
CREATE ROLE core_app LOGIN;
GRANT CONNECT ON DATABASE :"DBNAME" TO core_app;
CREATE TABLE animals (id integer PRIMARY KEY, name text NOT NULL, species text NOT NULL);
CREATE TABLE stays (id integer PRIMARY KEY, animal_id integer NOT NULL REFERENCES animals,
                    admitted_at timestamptz NOT NULL, discharged_at timestamptz);
GRANT SELECT ON animals, stays TO core_app;
