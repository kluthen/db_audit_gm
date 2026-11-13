# governance-register-flow-undeclared — GM notes

**What.** The players' data register (`~/data-register.md`, and the web
front's "Data register" section) leaves out a processor the data reaches.
By default that processor is cold storage, the vault: every instance that
archives its WAL and sends a nightly base backup there (`archive_command`,
the crontab's `pg_basebackup | vault-post basebackup`) hands it the whole
instance, so every entry held there has the vault among its recipients
and its copies. The handout drops it from every entry's **Shared with**
and, for the vault, the "cold storage (WAL archive, nightly base backup)"
item from every entry's **Where**: it is named nowhere. With `recipient`
set to the franchise's messaging service, the same fault is T308: the
portal's messages go to a processor the register omits (no copy item to
drop there).

Planted in the handout only (master spec 13.4): the `data-register` skill
writes the scenario's `player/data-register.md` with the change applied,
and the answer key's `register_diff:` with one item per entry and field
changed. The true register (`gm/data-register.yaml`) and the system are
unchanged: the archive still ships, the vault still holds its manifests.

**Why it matters.** A record of processing names every recipient,
processors included (GDPR Art 30(1)(d)). An owner's access request
answered from this register would omit where their data also sits, and an
inspector reading it would find an undeclared transfer of the whole
medical record to a third party. Nothing breaks: a minor friction (M) by
default; dramatic only with a story the customer noticed (an access
request answered from it, an inspector's question).

**Why it happens.** The register was written from the applications'
point of view (who reads which table) and nobody thought of the backups
as a flow; the archive was set up by operations after the register.

**What a good answer says.** Reads the register against the system and
`partners.md`: the database's `archive_command` and base-backup job post
to cold storage, the vault's page and `GET /manifests` show the node's
`wal` and `basebackup` shipments day by day, `partners.md` describes cold
storage as an off-site archive service; no entry of the register names
it. Proposes the corrected entries: cold storage among each entry's
recipients, a processor, receiving the whole instance archived; the vault
among its copies.

**Resolution: propose only.** The players cannot edit the customer's
register. Judge the proposal at the final answer against the instance's
`register_diff:` (each entry's `shared_with` and `where`, the true value
and the value handed out). The GM never clears it during play. Clearing
is regenerating the handout without the fault (the data-register skill,
the instance removed): the change is reversible.

**Sealed check.** On the bastion as root: the served handout,
`/home/player/data-register.md`, names the recipient (`FAULT_RECIPIENT`,
matched without regard to case) on no `### <id>: <name>` entry: *present*
(1); on at least one: the handout without the fault (0); no handout or no
entry: an error (2). It reads only that the change is present: the true
register is sealed and never on a node. A player who writes into their
own copy (the home is writable) changes its reading, so its result at the
final answer is not the verdict; `register_diff:` is.

**Placement.** The scenario has a data register (`governance.register`,
the bastion mapping `data-register.md`) and the true register names the
recipient on at least one entry: for cold storage, a node whose
`vault_target` is cold storage's hostname. Beside
`pg-archive-command-silent` on the same vault, the archive fails silently
while the vault still holds the planted `wal` and `basebackup` manifests
and the nightly base backups (the crontab's, unaffected), so this fault's
witness stands; the answer key notes it. Not with the register left out
(T305): there is no handout to read.

**Feedback points.** A record of processing lists processors too;
backups and archives are flows; read a document against the system it
describes.
