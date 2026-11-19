# docs-overview-backup-claimed — GM notes

**What.** The players' network overview (`~/network-overview.md`, and the
web front's "Network overview" page) claims, in one customer node's entry
under **Backups**, a protection the node does not have: trap N5 of master
spec 8.5. By the spec's example, a database server that sends a nightly
base backup to the vault and archives no WAL is handed out as "WAL archived
to Cold Storage, segment by segment", its true "(no WAL archive)" note
dropped: the customer believes it can restore the server to any point in
time, and it can restore only last night's base backup. The parameters name
the node (`node`) and the claimed line (`claimed`), as the handout writes
it.

Planted in the handout only (master spec 6.3, 8.3): the `network-overview`
skill writes the scenario's `player/network-overview.md` with the change
applied, and the answer key's `overview_diff:` with one item, the node's
`backups`, its true lines and the lines handed out (a list stays a list).
The true overview (`gm/network-overview.yaml`) and the system are
unchanged: the node archives nothing, the vault holds no WAL manifest of
it. The header and **Your access** never change: they are the game's rule.

**Why it matters.** A backup the documentation claims is the one nobody
checks. The day a restore is asked for ("bring `machines` back to yesterday
noon"), the answer is a day lost, found out during the incident. Nothing
breaks while the claim stands: a minor friction (M) by default, as a
register fault; on the verge or dramatic when the story leans on the
claimed backup (an issue asking for a point-in-time restore, an incident
the customer expects to undo).

**Why it happens.** The overview was written from the plan (every database
server to archive its WAL), or from another server's entry, and nobody read
it against the server; or the archive was turned off during a migration and
the page never followed.

**The witnesses.** The page read against the system (8.5's N5):
`archive_mode` and `archive_command` (`SHOW`), `pg_stat_archiver` (no
segment archived, `last_archived_wal` empty), `pg_stat_replication` (for a
claimed replica: no row), the vault's manifests (`GET
/manifests?type=wal&source=<node>`: none; `type=basebackup`: the nightly
ones, which are true). The server's crontab and the health page's checks
name the base backup only.

**What a good answer says.** Reads the overview's **Backups** against the
server: the WAL archive it claims does not exist (`archive_mode` off,
nothing archived, no WAL in the vault), only the nightly base backup does;
so a restore reaches last night, not yesterday noon. Proposes the corrected
entry (the node's Backups as they are, the answer key's `overview_diff:`)
and puts the choice to the customer: make the claim true (archive the WAL)
or the page honest. Archiving the WAL is a recommendation, not the fault's
resolution: a player with write access who turns `archive_mode` on changes
the system, not the customer's documentation.

**Resolution: propose only.** The players cannot edit the customer's
documentation. Judge the proposal at the final answer against the
instance's `overview_diff:` (node, field `backups`, the true lines and the
lines handed out). The GM never clears it during play. Clearing is
regenerating the handout without the fault (the `network-overview` skill,
the instance removed): the change is reversible.

**Sealed check.** On the bastion as root: the served handout,
`/home/player/network-overview.md`, has under the `### <node>` entry's
**Backups** an item carrying `FAULT_CLAIMED` (matched without regard to
case): *present* (1); none: the handout without the fault (0); no handout,
no entry for the node, or no Backups in it: an error (2). Only the Backups
items count: the entry's **Third parties** and **Background tasks** may
name the vault for what truly goes there. It reads only that the change is
present: the true overview is sealed and never on a node. A player who
writes into their own copy (the home is writable) changes its reading, so
its result at the final answer is not the verdict; `overview_diff:` is.

**Placement.** The scenario has a network overview (every scenario listing
`domains:`), and the node is a customer node whose true Backups lack the
claim: in the clinic, `machines` (a nightly base backup, no WAL archive)
for a claimed WAL archive; a server with Backups "none" for a claimed base
backup. Never a claim the system makes true: on `records` or `lab`, which
archive their WAL, "WAL archived" is no fault. Beside `pg-archive-command-
silent` on another node, the two read differently (a claim with no archive
behind it; an archive failing silently behind a true claim); the answer
key notes the help when one makes the other easier to see. A system fault
the page's truth makes easier to see is no overview fault (8.5).

**Class.** A minor friction (M) by default; on the verge or dramatic only
when the story leans on the claimed backup (an issue asking whether the
node can be brought back to yesterday noon, as the complaint template
words it).

**Feedback points.** Documentation is a claim to check, not a fact; a
backup nobody has restored from, or read in the system, is a hope; read a
document against the system it describes.
