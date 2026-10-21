# Brief

Hand-written, no brief. Written for db_audit_gm v0.2 (build plan chunk
14a) within master spec section 11.1: one database, a small or mid-size
customer, some monitoring present and ill-configured, one need left
uncovered as a tooling expectation (not node health: the scenario has
Grafana, so the node-health view exists, D104). Every v0.2 brick at its
v0.2 version (bastion and postgres 0.2.0; prometheus, postgres-exporter
and grafana 0.1.0), on the `laptop` playground (2 CPU / 4G / 8G, D105).

The monitoring side follows capture W4 of
`specs/versions/v0.2/wave-log.md` ("What chunk 14's scenario declares"):
the node names, the node-health map, the five seed-file settings and the
five monitoring fault instances f1 to f5 as written there; any issue on f2
or f3 expects report or propose; at least one *fix* issue on a monitoring
tool (here f1). Grafana's seed files are the brick's companion files byte
for byte, except `alert-rules.yaml` (f5).

Chosen when the folder was written (reviewed by the owner at G10): the
customer and its story; three v0.1 database faults from W4's "suit well"
list (`pg-hba-trust-remote`, `pg-role-superuser`,
`pg-table-autovacuum-off`; `pg-memory-over-envelope` left out, the
database side needing no red validator); which instances are known and
which hidden; the three issues; the tooling expectation (PostgreSQL log
analysis).
