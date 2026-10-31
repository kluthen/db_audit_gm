-- g1-renamed-copy: e-mail addresses copied into reporting under another
-- table and column name, rpt.contacts.who: only G1's content probe sees it.
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=0 G4=0
\if :revert
DROP TABLE rpt.contacts;
\else
CREATE TABLE rpt.contacts (who text, since date);
INSERT INTO rpt.contacts VALUES ('customer2@example.org', '2026-10-01');
\endif
