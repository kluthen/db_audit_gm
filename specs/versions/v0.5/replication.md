# v0.5 — replication and the off-site copies

Status: draft v3, ruled. The owner ruled the standby, the vault and the
fault candidates on 2026-11-02, and that the periodic reports read on
the standby (D299); then, the same day, that they write to a back-office
database, `office` (section 3, D300, closing O149); and that the lab,
on a node of its own, sends its WAL and base backups to the vault too
(section 2, D301, extending D299).

The owner, asking on 2026-11-02: "have we set replications needs for
this project ? we could have probably one off site (but still within
network) replication set up, and another (cold storage like) set as
well ?" Then, on the draft: "ok" to each point but one, and on where the
reports run: "hmmm agreed on reading on the standby. I'm on the fence to
have a dedicated database for administrative purpose (separation of
concern, etc)." And on the back-office database as drafted: "agreed for
the office database".

**Before this page.** Replication is a standby mode of the `postgres`
brick, a node the topology chooses, no option (D250); every seed
carries the replication line in `pg_hba.conf` (D164); the brick's
hand-over snapshot uses a temporary physical slot it removes
(`bricks/postgres/docs/gm.md`); redundancy stays inside the one centre
a scenario deploys (D285).

## 1. A standby off site (D299)

- **Which**: the instance holding `vet-core`, the system of record
  (D266) every part and the portal reads, around the clock; the only
  standby in v0.5. A part the scenario lands in that instance
  (procedure 5) rides along. `vet-machinery`'s databases have none:
  their heavy data ships to cold storage (D288), a standby would double
  it. `vet-lab`, on a `postgres` node of its own (D301), has none
  either: its copy is the vault's (section 2).
- **Where**: a `postgres` node in standby mode, the centre's
  **off-site room** (a second building, a rented rack), in the players'
  scope, on the one network (D275); on another host where there are
  several, a preference as for third parties.
- **How**: asynchronous streaming replication; a physical replication
  slot named for the standby; a replication role whose password is a
  secret; `hot_standby` on, so the standby is readable.
- **Reports read there.** The periodic reports (D265) run their heavy
  reads on the standby, `hot_standby_feedback` on so that long report
  queries are not cancelled, its cost (vacuum held back on the primary)
  a thing to watch. A standby is read-only: the report's job holds a
  second connection for its outputs, to the back-office database on
  the primary (section 3, D300).
- **Built**: the standby cloned from the primary after the data load,
  before the aging; the brick's standby mode is specified with it.
- **Observed**: `pg_stat_replication` on the primary, its lag in the
  monitoring the scenario has (pgwatch, D238).

## 2. A copy in the vault (D299)

- **WAL archiving**: `archive_mode` on, an `archive_command` sending each
  WAL segment, and `archive_timeout` at an hour so a quiet night still
  ships its segments.
- **Base backups**: `pg_basebackup` each night, in the low hours, sent
  whole, from the database node's cron daemon (D206).
- **Both instances** (D301, extending D299): the core's primary and
  the lab's node, each archiving its WAL and sending its nightly base
  backup; each manifest names its node.
- **The vault is cold storage itself**, with two more data types, `wal`
  and `basebackup`, each shipment's manifest carrying the segment or
  backup's name and size beside its time; the payload discarded as for
  every type ([cold-storage.md](cold-storage.md), D296). One stub, one
  page, one manifest model, its store in the partners' shared database
  (D293).
- **Plain PostgreSQL tools**, no pgBackRest. This brings WAL archiving,
  base backups and the faults of their failing into v0.5. pgBackRest and
  its kind, restores, point-in-time recovery and restore drills stay
  with O49, for v1.0+'s DBA work (D272): they need a vault that keeps the
  data.

## 3. Where the reports write: a back-office database (D300)

The reports read on the standby (D299) and write their outputs to a
database of the business's office, `office`, not back into the clinic's
database (D300, closing O149).

- **What it holds**: what the office produces, not the clinic's
  operational record: the periodic reports' outputs (D265), the lab's
  monthly statements to its outside customers (D294), copies of the
  regulatory submissions sent (the registers' extracts, the
  antimicrobial-use report, the notifiable-disease reports).
- **Its roles**: an office role reading the standby and writing the
  back-office database, and no write grant on the clinic's record; the
  operational record carries no report table.
- **Placement**: a database of its own, `office`, on the primary's
  instance: no new node, and it rides the standby and the WAL
  archive for free; the separation is by database and roles. A variant
  may move it to an instance of its own.
- **Not a domain part.** Its tables are the purposes' targets: a
  purpose's definition carries its target's DDL ([formats.md](../../formats.md)
  "Purpose definition"), and each report or statement is a purpose
  reading the core or the lab and writing the office. A `vet-office`
  part would hold no data of its own and no producer, which a domain
  needs (procedure 1). The back-office database is topology, named in
  the scenario and defaulted in the clinic's GM notes; D293's "core and
  five parts" stands. The lab's prices and charges stay in `vet-lab`
  (D294); only the statements land in the office.
- **Fault candidates**, accepted (D300):

  | Candidate | What the players find |
  |---|---|
  | A report job still writing to the old target | report tables reappearing in the clinic's database, the office's copy stale |
  | The office role holding write grants on the clinic's record | a grant the separation forbids, shown by the roles' privileges |
  | A report reading the primary, not the standby | its heavy reads competing with the clinic's traffic at the report's hour |
  | The back-office database on an instance of its own, left out of the standby, the archive or the checks | a database with no copy anywhere, its manifests absent from the vault |

Rejected: the outputs back into the clinic's database, as first
drafted, report tables beside the record and the separation by roles
alone.

The office role's name, and whether it is `vet-core`'s `vet_reports`
given its write grants on `office`, are settled with the purposes
(procedure step 7), each report's or statement's target DDL in its
purpose.

## 4. Fault candidates (D299)

| Candidate | What the players find |
|---|---|
| `synchronous_standby_names` naming an absent standby | every commit waits: writes hang, the application stalls; a candidate for the dramatic fault the customer noticed (D290) |
| An abandoned slot filling `pg_wal` | `pg-abandoned-replication-slot`, its precondition changed from "no standby in the topology" to allow an orphan slot beside the standby's (a fault bump in the build) |
| Replication lag | the standby hours behind, the reports read there stale |
| Query conflicts on the reporting standby | reports cancelled (`hot_standby_feedback` off), or the primary bloated by the standby's old snapshots (on) |
| `archive_command` failing silently | a command swallowing its error (exiting 0 whatever happened): segments recycled unsent, gaps in the vault |
| Gaps in the WAL sequence | missing segment names in the manifests |
| Base backups older than the retention | the last `basebackup` manifest days old against the policy |
| `pg_wal` filling the disk when archiving fails | the command failing honestly, PostgreSQL keeping every segment until the disk is full |
| The lab's node left out of the archive (D301) | no `wal` or `basebackup` manifest naming the lab: its record has no copy anywhere |

## 5. Topology and cost

- **One more `postgres` node**, the standby: the brick's reservation is
  0.5 CPU, 512M and 2.25G of disk, its limit 1G
  (`bricks/postgres/brick.yaml`); `fit` counts it.
- **The vault**: nothing more where the scenario already has cold
  storage; its traffic is the WAL's volume, small at one centre's rates
  (D295), plus a base backup a night, for the core's instance and the
  lab's (D301). The lab's node itself is the lab's topology, not
  replication's.
- **The back-office database** (D300): no node.
