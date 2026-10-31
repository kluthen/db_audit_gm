# security-crontab-superuser — GM notes

**What.** An entry of the database node's crontab (postgres 0.4.0's cron
daemon, master spec 7.2) runs `psql` over the local socket with no role:
cron runs it as OS user `postgres`, and peer authentication logs it in as
the superuser `postgres`. The customer role prepared for it (parameter
`role`: in `tarnbeck-outdoor-campaign`, `shop_refresh` with `MAINTAIN` on
`popular_products`) exists, its password is in the password file the
crontab's `PGPASSFILE` line names, and the entry never uses it (16.2, f6).

**Writing it into a scenario.**
- The node seeds a `crontab` and names `role` in its `crontab_roles`, so
  render mounts the role's secret and the password file holds its line;
  the node's own data file creates the role with LOGIN and the grant the
  statement needs (the loader checks both, W1 item 8).
- The scenario's copy of the crontab is the baseline entry with its
  `-U <role>` removed (`inject/crontab.snippet`): same time, database,
  statement and job log. Keep the `PGPASSFILE` line: the prepared, unused
  path is half the evidence.
- The seed `pg_hba.conf` keeps the GM's `local all postgres peer` line
  (every postgres seed has it) and lets the role in over the local socket
  by password (`local all all scram-sha-256`), so the fix works.
- `log_connections = on` in the seed `postgresql.conf` puts each run's
  connection in the server log.
- **Aging minimum.** 1h, counted from the entry's first run after T0:
  an hourly entry runs within the hour, so the instance needs no raise
  beyond its minute (spec D189).

**Why it matters.** A job that needs one grant runs with every right on
the instance. A mistake in its statement, or anyone who can change the
entry, the script it calls or a program on its path, acts as `postgres`:
reads and changes every database, runs commands as the OS user.

**Why it happens.** The entry was written and tested in a shell as
`postgres`, where it worked; the role and its password file were set up
later, by someone else, and nobody switched the entry over.

**What a good answer says.** Lists the crontab (`sudo gm-crontab -l`),
sees that the entry names no role, works out that it runs as `postgres`
by peer (the server log at its minute: `connection authenticated:
identity="postgres" method=peer`, then `connection authorized:
user=postgres ... application_name=psql`; or `pg_stat_activity` during a
run), finds the prepared role and
its grant (`\du`, `\dp`), and connects the entry as that role.

**Fix path.** On the node, as `player`: `sudo gm-crontab -l > /tmp/c`,
add `-U <role>` to the entry (the password comes from `PGPASSFILE`),
`sudo gm-crontab /tmp/c`; cron reads it within the minute, and the job's
next run in `/var/log/postgresql/cron/<job>.log` shows it still works
(`REFRESH MATERIALIZED VIEW`). A `PGUSER=<role>` line above the entry is
the same fix.

**Sealed check.** The live state, exit 0 or 1 (12.6). It reads every
crontab of cron's spool (`postgres`'s, and any other OS user's, since
`cron.allow` is absent, D211), takes each entry running a PostgreSQL
client with the role it connects as (`-U`, `--username`, `user=`, a URI,
`PGUSER`, else the crontab's OS user), and reads `rolsuper` as
`gm_check`. *Present* while any such entry connects as a superuser,
`postgres` or `dba` alike: a fix moving the job to `dba` is a new path
(11.7). *Fixed* when none does. Deleting the entry also reads *fixed*,
with a first line saying no entry connects any more: the web shop's
refresh is gone, which is not acceptable as the fix. A role that does not
exist is not a superuser: the check reads *fixed*, and the job's log shows
it failing; check the log after a fix. The check does not follow a
script the entry calls, nor `sudo -u` or `su` inside it.
