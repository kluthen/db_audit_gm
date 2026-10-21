# Brief

Hand-written, no brief. Written for db_audit_gm v0.1 (build plan chunk 8)
within master spec section 15: a bastion and one static PostgreSQL node;
defects only in the database and its configuration, visible without any
activity; at least one known and one hidden; at least one *report* or
*propose* issue and one *fix* issue. The defects were chosen from the
spec's candidates: `trust` for remote connections, an application role
with superuser rights, a memory setting outside its envelope, a missing
index on a frequently joined column, autovacuum disabled on a table, and
an abandoned replication slot (the bloated table was left out: it needs
activity to stay visible).
