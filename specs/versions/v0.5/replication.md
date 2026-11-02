# v0.5 — replication and the off-site copies

Status: draft v1, proposed throughout (O149). Raised by the owner's
question of 2026-11-02.

The owner: "have we set replications needs for this project ? we could
have probably one off site (but still within network) replication set
up, and another (cold storage like) set as well ?"

**What is settled today.** Replication is a standby mode of the
`postgres` brick, a node the topology chooses, no option (D250); every
seed carries the replication line in `pg_hba.conf` (D164); the brick's
hand-over snapshot uses a temporary physical slot it removes
(`bricks/postgres/docs/gm.md`); redundancy stays inside the one centre
a scenario deploys (D285). Nothing says which databases have a standby,
synchronous or not, where it runs, its slot, its lag, nor any WAL
archive. Backup tooling is O49, in no version.

## 1. A standby off site (proposed)

- **Which**: the instance holding `vet-core`, the system of record
  (D266) every part and the portal reads, around the clock. A part the
  scenario lands in that instance (procedure 5) rides along. Not
  `vet-machinery`'s databases: their heavy data ships to cold storage
  (D288), a standby would double it. `vet-lab` on an instance of its own
  is the next candidate (regulated results, paying customers, D294),
  left out of the first scenario for the memory it costs (section 4).
- **Where**: a `postgres` node in standby mode, the centre's
  **off-site room** (a second building, a rented rack), in the players'
  scope, on the one network (D275); on another host where there are
  several, a preference as for third parties.
- **How**: asynchronous streaming replication; a physical replication
  slot named for the standby; a replication role whose password is a
  secret; `hot_standby` on, so the standby is readable.
- **Reports read there.** The periodic reports (D265) run their heavy
  reads on the standby, and write their outputs to the primary through
  the same job, a script holding both connections (a standby is
  read-only). `hot_standby_feedback` on, so long report queries are not
  cancelled, its cost (vacuum held back on the primary) a thing to watch.
- **Built**: the standby cloned from the primary after the data load,
  before the aging; the brick's standby mode is specified with it.
- **Observed**: `pg_stat_replication` on the primary, its lag in the
  monitoring the scenario has (pgwatch, D238).

## 2. A copy in a vault (proposed)

- **WAL archiving**: `archive_mode` on, an `archive_command` sending each
  WAL segment, and `archive_timeout` at an hour so a quiet night still
  ships its segments.
- **Base backups**: `pg_basebackup` each night, in the low hours, sent
  whole, from the database node's cron daemon (D206).
- **The vault: cold storage itself** (recommended), with two more data
  types, `wal` and `basebackup`, each shipment's manifest carrying the
  segment or backup's name and size beside its time; the payload
  discarded as for every type ([cold-storage.md](cold-storage.md), D296).
  One stub, one page, one manifest model, its store already in the
  partners' shared database (D293). The other reading: a backup vault of
  its own, a second provider, more realistic but one more node and a
  second page on the bastion.
- **Plain PostgreSQL tools**, no pgBackRest. What this pulls of O49 into
  v0.5: WAL archiving and base backups, and the faults of their failing.
  What stays with O49: pgBackRest and its kind, restores, point-in-time
  recovery and restore drills, which need a vault that keeps the data,
  so they wait for v1.0+'s DBA work (D272).

## 3. Fault candidates

| Candidate | What the players find |
|---|---|
| `synchronous_standby_names` naming an absent standby | every commit waits: writes hang, the application stalls; a candidate for the dramatic fault the customer noticed (D290) |
| An abandoned slot filling `pg_wal` | exists: `pg-abandoned-replication-slot`; its precondition, no standby in the topology, needs revisiting to allow a second, orphan slot beside the standby's |
| Replication lag | the standby hours behind, the reports read there stale |
| Query conflicts on the reporting standby | reports cancelled (`hot_standby_feedback` off), or the primary bloated by the standby's old snapshots (on) |
| `archive_command` failing silently | a command swallowing its error (exiting 0 whatever happened): segments recycled unsent, gaps in the vault |
| Gaps in the WAL sequence | missing segment names in the manifests |
| Base backups older than the retention | the last `basebackup` manifest days old against the policy |
| `pg_wal` filling the disk when archiving fails | the command failing honestly, PostgreSQL keeping every segment until the disk is full |

## 4. Topology and cost

- **One more `postgres` node**: the brick's reservation is 0.5 CPU,
  512M and 2.25G of disk, its limit 1G (`bricks/postgres/brick.yaml`);
  `fit` counts it.
- **The vault**: nothing more where the scenario already has cold
  storage; its traffic is the WAL's volume, small at one centre's rates
  (D295), plus a base backup a night.
- **A second standby** (`vet-lab`'s) would be another such node.

## What O149 asks the owner

1. A streaming standby of the instance holding `vet-core`, asynchronous
   with a slot, readable, on an off-site node of the centre in the
   players' scope?
2. Only that instance in v0.5, `vet-lab` left without a standby unless
   it lands in the core's instance?
3. The periodic reports reading on the standby, writing their outputs
   to the primary, `hot_standby_feedback` on?
4. WAL archiving and a nightly base backup, plain PostgreSQL tools, sent
   to the cold storage stub as types `wal` and `basebackup` rather than
   a vault of its own; pgBackRest, restores and drills left with O49 for
   v1.0+?
5. The fault candidates above, the absent synchronous standby among the
   candidates for the dramatic fault?
