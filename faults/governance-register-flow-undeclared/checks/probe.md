# Probe — governance-register-flow-undeclared

Descriptive only. As `player`, on the bastion:

1. `grep -n '\*\*Shared with\*\*\|\*\*Where\*\*' ~/data-register.md | grep -i '{RECIPIENT}'`
   prints nothing: no entry's recipients or copies name it (an entry's
   **Kept for** line may still name the vault as where its data ends);
   the web front's "Data register" section names it among no entry's
   recipients either.
2. `grep -n -i -A3 '{RECIPIENT}' ~/partners.md` describes the processor
   (cold storage: an off-site archive service, what is shipped there
   leaves the site).
3. For cold storage: `psql -h {database node} -c 'SHOW archive_command'`
   calls `vault-post`; `curl -s "http://cold-storage:8000/manifests?type=basebackup&source={database node}"`
   lists the node's nightly base backups (the vault's page shows them day
   by day): the whole instance, the data of every entry held there, goes
   to the vault.

Expected: all three from the start of the game, with no load.
