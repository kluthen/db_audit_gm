# Health node — player notes

What you may know about the health node in a db_audit_gm game: the
customer's Nagios-style health tooling, `check_postgres` and the IT's own
scripts, with a status page.

## Getting there

- **The page**: from your browser, the bastion's web front, `/health/`
  (the tools password). `status.txt` beside it is the same in plain text.
- **The node**: from the bastion, `ssh player@<node>`.

## What it does

Every five minutes, from the crontab of the OS user `postgres`,
`health-run checks` runs `check_postgres` against each database listed
in `/etc/health/health.yaml`, as the role `monitoring`: connection,
backends, locks, transaction wraparound, the last autovacuum and analyze
(not on a standby), database sizes, and a standby's replay delay against
its primary. The same crontab runs the customer's scripts in
`/etc/health/scripts/`, each a Nagios plugin (one line, exit 0 OK,
1 WARNING, 2 CRITICAL, 3 UNKNOWN). Each run rewrites the page: every
check's and every script's state, its line, and its time (UTC).

## What you can change

- **The instances**: `/etc/health/health.yaml` (your account is in the
  `healthconf` group):

  ```yaml
  instances:
    - name: records        # the page's label
      host: records
      port: 5432
      dbname: postgres
    - name: standby
      host: standby
      port: 5432
      dbname: postgres
      primary: records     # a standby: its replay delay against records
  ```

- **The scripts**: `/etc/health/scripts/`, executable files.
- **The schedule**: `sudo gm-crontab -l` lists the crontab; edit a copy in
  your home and install it with `sudo gm-crontab <file>`.
- **Your home**, `/home/player`: notes, `~/report.md`.

## Applying changes

The files are read at each run. `sudo gm-run-checks` runs the checks at
once; a script runs at its crontab line's time.

## The validator

`sudo gm-validate` checks that `health.yaml` is valid, that every script
the crontab names is there and executable, that cron runs, that the page
answers and that the checks ran in the last 15 minutes. It prints
`GREEN: ...` (exit 0) or one `RED <rule>: ...` line per problem (exit 1).
What the checks find is for you to judge.

## Do not tamper

Do not tamper with SSH, `sudo`, the `gm-*` wrappers, `health-run`, the
web server's configuration or the validator.

## Good to know

- A check that finds nothing to judge on a fresh database (no table ever
  vacuumed) says UNKNOWN.
- The thresholds of the checks are the IT's, fixed; the scripts carry
  their own on their crontab line.
