# pg-join-index-missing — GM notes

**What.** A column used in joins and lookups (typically a foreign key
pointing to a parent table) has no index. PostgreSQL indexes primary keys
and unique constraints automatically, never the referencing side of a
foreign key.

**Why it matters.** Every lookup of the children of one parent ("the
lines of order 42") reads the whole child table. The cost grows with the
table, so the screen gets slower as the business grows. Deleting or
updating a parent row also scans the child table to check the foreign
key.

**Why it happens.** The index was never created, or was lost in a
migration: a schema-only restore without its post-data section, or an
index dropped "to speed up the load" and never rebuilt.

**What a good answer says.** The table, the column, the missing index,
and a plan proving it (`EXPLAIN` or `EXPLAIN ANALYZE` showing a `Seq
Scan` with a filter on the column). The fix: `CREATE INDEX` on the column
(`CONCURRENTLY` on a production system), then the plan again, now an
index or bitmap scan. A thorough answer checks the other foreign keys of
the schema for the same gap.

**Fix path.** SQL as `dba`. Any valid index whose first column is the
joined column counts, whatever its name. Not a setting.

**Sealed check.** Counts valid indexes leading with the column. An index
left invalid by a failed `CREATE INDEX CONCURRENTLY` does not count.
