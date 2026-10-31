# governance-personal-copied — GM notes

**What.** The agency's churn dashboard keeps a copy of the shop's
customers, names and e-mail addresses included, in the reporting
database: a second foreign server to the shop (`server`), mapped for the
loader (`bi_etl`) to the back office's login (`shop_reports`, which reads
`customers` whole), a foreign table over `customers` (`foreign-table`),
the table (`table`), and a `pg_cron` job (`job`) as the loader, every
thirty minutes, recreating the table if it is gone and upserting every
customer into it. No runner lists the job: it lives in `cron.job` only
(16.2, f9). Breaks G1 (personal columns outside `db/shop`: the foreign
table's, by the remote column it maps, and the table's, by the content
probe) and G3 (the mapping's remote role reads `personal`, so the
reporting database is a reader; the job's `bi_etl` reaches the copy).

**Writing it into a scenario.**
- The seed change is `data`, the reporting node's data file (spec D226):
  append `inject/customer_activity.sql.snippet` after the purpose's
  material and `CREATE EXTENSION pg_cron`, in `cron.database_name`'s
  database. It is written for the first v0.4 scenario's names; adapt the
  roles, the source's host and database, and keep the parameters equal to
  what the copy creates (the loader checks neither).
- The scenario has `governance:` classing `customers.name` and
  `customers.email` `personal`, allowed in `db/shop` only, and
  `shop_reports` not a reader of `reporting`. The policy
  (`governance.policy`, on the bastion) says it in words: f9 is found by
  reading it (16.1).
- The mapping's remote role is a login role the source's data file
  creates, so `load-data` sets the mapping's password from its game
  secret (`role_<role>_password`); the source's `pg_hba.conf` admits it
  from the node by password (the campaign's `host all all 0.0.0.0/0
  scram-sha-256` does). Nothing changes on the source: a fault's seed
  changes target its own node only.
- The seed `postgresql.conf` keeps `cron.log_run = on` (12.5), so
  `cron.job_run_details` shows the job's runs.
- **Aging minimum (spec D189).** 30m from the job's first run after the
  data load: the copy is full from then. The definitions break G1 and G3
  at once.

**Why it matters.** The policy keeps personal data in the shop's
database, read by named accounts. The copy puts every customer's name and
address in a database the agency administers, refreshed every half hour,
reachable by whoever reads the dashboards, backed up and kept with it: a
second place to secure, to answer access requests from and to erase
from. And the path borrows the back office's login, so the shop's own
grants no longer say who reads its customers.

**Why it happens.** A dashboard wanted "who has not ordered lately"; the
agency's loader could not read `customers`, the back office's login
could, and a job inside the database was quicker than asking the shop.

**What a good answer says.** Finds the copy (`\dt rpt.*`, a look at the
table, or the policy read against what the reporting database holds),
follows it back to the foreign table and its server and mapping (`\det+`,
`\des+`, `\deu+`), and finds the job that keeps refilling it in
`cron.job`, since no runner lists it. Proposes removing all of it, and a
dashboard on data the policy allows. Dropping the table alone is not
enough: the job recreates it on its next run.

**Fix path** (an overstep in a game: the node is the agency's, the
issue asks for a proposal, 16.5). As `dba` in the reporting database:
`SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = '<job>'`
(by id: `cron.unschedule('<job>')` finds only the caller's own jobs, and
this one is the loader's), `DROP TABLE <table>`, `DROP FOREIGN TABLE
<foreign table>`, `DROP SERVER <server> CASCADE` (its mapping with it). The check then reads *fixed*; the GM judges the proposal, and names
the unrequested change.

**Sealed check** (the live state, exit 0 or 1, 12.6). Calls the
governance check set, `check_governance G1 G3` (capture W3-a), on the
reporting node: G1 and G3 walk every database node. While either is
broken it exits 1 with the set's first line. When both hold it requires
the job (by name, or any job whose command names the table or the
foreign table), the table, the foreign table and the server gone from
the node's database (11.7); one left: exit 1, naming it. So dropping the
table alone reads 1 (the foreign table still breaks G1, the mapping G3),
and so does a table emptied with its job unscheduled while the server
stays. Exit 2 when the set cannot judge, or when `gm_check`'s read policy
on `cron.job` is gone and no job is visible (capture W2-x). The judgement
does not depend on the job's runs, so no `--since`.
