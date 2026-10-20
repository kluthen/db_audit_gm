# Bricks and faults

Status: draft v4

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

First technologies and versions per role: O11.

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

## Faults

The GM builds the full topology, plants faults, and gives the player zero
or more issues covering some of them; the rest stay hidden. Examples: a
pgBackRest stanza that doesn't actually work; a daily script that never
runs (badly configured cron job or similar).

The initiator's brief may impose a list of incidents and say whether the GM may
add more. How many faults of each kind a scenario has, what "difficulty"
means, and whether an issue may be a false alarm: O23.

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
| Monitoring that lies | collector pointed at the standby; alert threshold in the wrong unit; one host not collected |
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
