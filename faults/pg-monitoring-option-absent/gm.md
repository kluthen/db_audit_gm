# pg-monitoring-option-absent — GM notes

**What.** The `postgres` brick creates the role `monitoring` (`LOGIN`, a
member of `pg_monitor`, the game's `monitoring_password`) at initdb, and
only on a node choosing the option `monitoring` (its `docs/gm.md`,
"Option `monitoring`", "The monitoring role"). Planted by the topology
itself: the instance's node leaves the option out while a monitoring node
logs in as `monitoring` (T10; class m in the clinic). The exporter's
every scrape fails (`password authentication failed for user
"monitoring"`, the role absent), its metrics read `pg_up 0`; pgwatch's
source and the health check's instance on the node fail alike. Nothing
runs at injection (`injection.kind: topology`, W5-h): `gmctl inject`
lists the instance under its topology faults, `inject --at` refuses it.

**Writing it into a scenario.**
- The node is a `postgres` 0.5.0 database node without
  `options: [monitoring]`; one instance covers every monitoring node
  targeting it (`_check_monitors` accepts each for the instance's node).
  The scenario's other database nodes the monitoring targets choose the
  option.
- **Never name `postgres-exporter` in this fault's `applies_to`** (W5
  item 0): the exporter's side is the scenario's, in its answer key
  (`node:<exporter>`, `pg_up`, the dashboards), since a documentation
  change would bump that released brick.
- **The game's `monitoring_password` exists** even when no `postgres`
  node chooses the option: `postgres-exporter` declares the same secret,
  so `gmctl deploy` generates it and mounts it on the exporter alone
  (the brick's notes, "Rendered"). The GM reads it there, as root, to
  apply an accepted proposal.
- Resolutions `report` and `propose`, never `fix` (spec D462): players
  read no service credential (access model 5), so they cannot give a role
  the exporter's password; and choosing the option later creates nothing
  on an existing `pgdata` ("Changed later").
- The answer key's evidence on the exporter's side: `node:<exporter>`,
  `curl -s localhost:9187/metrics`, `pg_up 0`; the server log's refused
  logins on the node.

**Why it matters.** A database nobody watches is down the day it fails
and nobody knows; a dashboard that has always been empty is read as
"nothing to see".

**Why it happens.** The node was added after the others, from a template
without the option; the monitoring was pointed at it and never checked.

**What a good answer says.** Ties the empty dashboards and `pg_up 0` to
the refused logins on the node and the missing role; proposes the role
created as the option creates it (`CREATE ROLE monitoring LOGIN PASSWORD
...; GRANT pg_monitor TO monitoring`, with the exporter's own password,
which the operator holds) and the option chosen for the node's next
build; not the option alone.

**Applying an accepted proposal (the GM).** As root on the exporter's
node, read `/opt/gm/secrets/monitoring_password`; on the database node,
as `postgres` over the local socket, unseen (statement logging, pgaudit
and `pg_stat_statements` off for the session: the password must not
reach the log), `CREATE ROLE monitoring LOGIN PASSWORD '<it>'; GRANT
pg_monitor TO monitoring;`, as the option's initdb step does. The
exporter's next scrape logs in: `pg_up 1`, its metrics present.

**Sealed check.** On the node, as root, through `check-psql` as
`gm_check`: *fixed* (0) once the role `monitoring` exists, can log in and
holds `pg_monitor`; *present* (1) otherwise. Its password is judged on
the exporter's side (`pg_up 1`), which gm_check cannot read.
