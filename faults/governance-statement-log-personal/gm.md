# governance-statement-log-personal — GM notes

**What.** The record's instance logs every statement: one line in its seed
`postgresql.conf`, `log_statement = 'all'`
([`inject/postgresql.conf.snippet`](inject/postgresql.conf.snippet)),
planted at render. Every write the practice software makes as `vet_app`
(a new owner, a changed phone number, an address) lands in the server log
with its values: owners' names, phone numbers and addresses in a file
outside the database, read by the players' group, rotated and kept by no
rule of the record's. Against the business's own rule, "none in the logs"
(vet-core's core rule 10; T1 of the clinic's traps, held since v0.4 under
this id).

**Writing it into a scenario.**
- The node is the primary holding the record (`postgres` 0.5.0), with the
  brick's logging block (`logging_collector = on`, the log on its volume,
  `log_file_mode = 0640`) and no other `log_statement` line. Add the
  snippet's line to the node's `nodes/<node>/postgresql.conf` (a database
  node's seed is never `gmctl compose`'s). With
  `pg-archive-command-silent` planted too, both lines go in the one file
  (capture W5 item 0); each sealed check judges its own setting, so fixing
  one leaves the other present.
- No parameter. Its evidence needs writes on personal data: the practice
  software (`pms`) writes all day in the clinic; a fixture with `pms` left
  out writes as `vet_app` itself.
- Aging minimum `0m`: the first `pms` write after planting.
- Visibility: hidden or known (a data protection officer's complaint).
  The node is fixable in the clinic; an issue may expect `fix`, `propose`
  or `report`.
- **With `scheduler-display-refresh-loop`** (the clinic's s9): with every
  statement logged, the display's board parameter is in the log already,
  so s9's careful logging step is unneeded while this stands; s9's "no
  instance-wide logging left behind" is met by this fault's fix (capture
  W5 item 6).

**Why it matters.** A server log is a copy of the data nobody classed: it
leaves the database's access rules behind, is read by whoever reads logs
(an operator, a log shipper, a support ticket's attachment), and is kept
until someone thinks of it. A medical record's owners' phone numbers do
not belong there.

**Why it happens.** An audit asked for "a trail of every statement"; the
quickest setting that gives one was turned on and never revisited. The
trail an audit needs (who changed the schema, who connected) holds no
values.

**What a good answer says.** Finds the owners' names and phone numbers in
the log, traces them to `log_statement = 'all'`, proposes `none` (or
`ddl`) and a reload, meets the audit's need with something that keeps no
values (pgaudit's `ddl` and `role` classes, the connection log), and names
the log files already written as personal data to purge or keep under the
record's rules: the fix leaves them.

**Fix path.** Edit `/etc/postgresql/postgresql.conf` (or `ALTER SYSTEM SET
log_statement = 'none'`), `sudo gm-reload-db`. A role or database setting
(`ALTER ROLE vet_app SET log_statement = 'all'`) planted as a workaround
counts as present.

**Sealed check.** On the node, as root, live state, through `check-psql`
as `gm_check`. *Fixed* (0) when `log_statement` in effect server-wide
(`pg_settings`, so as loaded at the last reload) is `none` or `ddl` and no
`pg_db_role_setting` entry sets `mod` or `all` for every role or database,
a database other than `postgres` and the templates, or a role other than
the game's own (`postgres`, `dba`, `gm_check`, `monitoring`, `replicator`,
`pgbouncer_lookup`) and `pg_*`. *Present* (1) otherwise, naming the
setting. Exit 2 when `gm_check`'s own session carries a `log_statement`
(its role is DO NOT TAMPER). It never reads the log: the files already
written stay a finding, not the check's.
