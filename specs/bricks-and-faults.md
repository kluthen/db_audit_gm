# Bricks and faults

Status: draft v9

The catalog of reusable bricks and fault definitions, and the rules that
keep scenarios fair. What a brick or fault definition must contain is in
[formats.md](formats.md); validator rules are in
[planes-and-access.md](planes-and-access.md); resource budgets in
[platform.md](platform.md).

## The catalog

The repository holds a growing catalog of bricks (Dockerfiles,
configurations, documentation for clean and faulty nodes) and of fault
definitions, expected to grow over time: older database versions (requiring
upgrades or hotfixes), new technologies (e.g. dbt + DuckDB), etc.

The GM picks bricks and faults from the catalog, and may also build its own,
following the same formats ([formats.md](formats.md)). A brick or fault
made solely for one scenario may live in that scenario's folder; shared
ones live in the catalog (D24). Whether and how a scenario-only brick or
fault is promoted into the catalog, and through which review: O25.

v0.2's monitoring tools are settled (D69, "Monitoring bricks" below);
the technologies and versions of the other roles: O11.

Brick documentation is split: player-facing and GM-facing, kept apart so
spoilers never ship to the player side.

## Checks on bricks

Machine checks are per brick (D28): a brick may ship its own checks among
its companion material ([formats.md](formats.md), "Brick definition"), and
the GM runs them before deploying a scenario that uses it. Reading, to
confirm (O20): there is no project-wide mandatory lint. The rules such a
lint would have checked still hold for every brick, and the format skill
asks for them: footprint declared, validator present, no privileges, no
Docker socket, protected files listed, documentation present.

## Monitoring bricks (v0.2)

The reference setup is the owner's `~/audits/bluebox-lab`; the gap v0.2
fills is a general per-node health view: each node's CPU, RAM, disk and
running services (D63). Free tools only; where the usual tool is paid, a
free tool or a script replaces it (D63).

v0.2 ships about one brick per need. Research may list the top three
candidates for a need, but one is built, and footprint (CPU, memory, disk
on a 2 CPU / 4G / 8G laptop) is a main criterion in choosing it (D64):

| Need | v0.2 brick (D66, D69) |
|---|---|
| Per-node health | the node-health script, a daemon on every node, configured by the GM at initialisation: the node's CPU, RAM, disk and the status of its important services; scraped by Prometheus. Companion material of the `prometheus` brick, which the GM mounts into each node as configs at deploy (D73, D88) |
| PostgreSQL metrics | `postgres_exporter` |
| Metrics store | Prometheus |
| Dashboards and alerting | Grafana, with its own alerting; no separate alerting brick |
| Log analysis | PostgreSQL logging to files, read by pgBadger run as a one-shot job |
| Log aggregation | none in v0.2 |

No cAdvisor and no Docker socket or host mount: each node reports on
itself from inside (D66). pgwatch and pgCluu, both in the reference, are
not v0.2 bricks. Every monitoring brick has its GM documentation like any
brick (D56); the node-health script's is `prometheus`'s (D88).

The node-health script (D73, D88) runs on every node whenever the
topology has a metrics store; a node left out is a monitoring fault. It
is companion material of the `prometheus` brick, versioned with it: a
change to the script bumps `prometheus`, and faults about it name
`prometheus` in `applies_to`. The GM installs it at deploy: the script
and its s6 service are mounted into each node as configs, with the
node's list of services, so a brick image only has to accept a mounted
service and none carries the script ([formats.md](formats.md),
"Companion material mounted into other nodes", D89). It reads CPU and
memory from the node's cgroup v2 files, disk as the use of the node's
own volumes (`du`) against its declared disk reservation, and services
with `s6-svstat`, and serves them in Prometheus' text format on a fixed
port. On one host every node sees the same host-wide free space, so the
view shows the host's free space once, not per node (D96). Its default
services are the brick's s6 `processes`, which the GM may adjust. Being
configs, the script and its list are read-only on the node: their faults
can be reported or a fix proposed, never fixed by the player. Such a
fault targets the `prometheus` node, takes the affected node as a
parameter and is planted through the node-health map (D92). A v0.5 metrics store other than
Prometheus would need its own copy. Other tools, other health solutions
(Nagios or others) and hand-made scripts come in v0.5 (D70).

Monitoring bricks are optional in a topology (D65), and may carry faults
of their own (D63; "Example families" below).

## Faults

The GM builds the full topology, plants faults, and gives the player zero
or more issues covering some of them; the rest stay hidden. Examples: a
pgBackRest stanza that doesn't actually work; a daily script that never
runs (badly configured cron job or similar).

The initiator's brief may impose a list of incidents and say whether the GM may
add more. Difficulty is a fault count: each fault is worth 1, an easy
game scores 5, a normal one 10, a hard one 20; a scoring system for the
players is post-v1.0 (D120); a score is the number of fault instances, the levels
targets (D134). The mix of faults,
and whether an issue may be a false alarm: O23.

### Tooling proportionate to the topology (D65)

How well the customer is tooled is itself something to audit. The
expectation is tooling proportionate to the topology's complexity: a very
small company (a producer, a database, a consumer) with a wide array of
tools is fine, but tooling that needs about three times the compute and
disk of what it watches is overkill, and that is a finding too.

Under-tooling (and overkill) is no fault kind of its own. It is an issue
the customer raises, a silent expectation of the GM, or both. A silent
expectation is an item of the answer key's list of tooling expectations,
outside the fault instances, judged in feedback; an issue may cover one
(D76; [formats.md](formats.md), "What a scenario must contain"). The
bastion and its tools are the players' kit, not the customer's tooling,
and do not count (D87).

### Solvability probe (proposed)

For every hidden fault, a probe runs *as the player user* and confirms the
evidence is actually reachable. This is the most important automated check:
without it the GM will eventually plant an undetectable fault and the
scenario becomes unfair without anyone noticing. Because many faults have
no evidence before aging, the probe runs after aging, before hand-over
(proposed; O20). Not in v0.1: its scenario is hand-written and a manual
play-through as `player` checks each fault's evidence instead (D38).

### Interactions

Monitoring that lies can hide a performance fault: a good layered trap when
intended, an unfair one when accidental. Fault definitions and scenarios
declare such dependencies explicitly (proposed).

### Example families (non-exhaustive)

| Family | Examples |
|---|---|
| Backups | stanza mismatch; `archive_command` failing but returning 0; retention purging too early; restore never tested |
| Scheduled jobs | unescaped `%` in crontab; missing final newline; wrong `PATH`; wrong time zone; script not executable |
| Monitoring that lies | collector pointed at the standby; alert threshold in the wrong unit; one host not collected; a node left without the node-health script (D73); a monitoring brick ill-configured, missing nodes, or starved of information, such as no slow-query log for pgBadger to read (D63) |
| Security | `trust` in `pg_hba.conf`; application role with superuser; secrets readable by everyone |
| Performance | missing index; autovacuum disabled on a hot table; bloat; bad memory settings |
| Replication | lag; abandoned replication slot filling the disk |
| Data flow | consumer producing duplicates; producer silently dropping records; transformer running on stale input |
| Versions | outdated engine needing a minor hotfix or a major upgrade |
| Rules | a node whose initial configuration is out of bounds and cannot be fixed by the player (see [planes-and-access.md](planes-and-access.md)) |
| Documentation | stale or wrong starter documentation (only if O21 allows it) |
| Network | exposure through the routing mesh, wrong segmentation (only if O12 allows it) |

v0.1's faults are limited to the restored database and its configuration
(D17).

### Future ideas: backup tooling

Recorded for later versions; each needs more investigation before it is
specified (D17).

- **Wrong backup configuration**: `pg_dump`, or whatever tool created the
  backup, was given the wrong configuration.
- **Restore succeeds, integration fails**: the database restores, but its
  integration with the wider system breaks.
- **Restore fails**: the restore itself fails. The backup file must then be
  present, and pointed out to the player.
