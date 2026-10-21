# Welcome to Pages & Co's database audit

You are on the **bastion**, your only way into the system. Read
`story.md` for the customer's background and `issues.md` for what you are
asked to look at. You have up to 3 hours.

## The system

| Node | What it is | Your access | Write policy |
|---|---|---|---|
| `bastion` | this machine: SSH, PostgreSQL 18 client tools, your notes and report | you are here, as `player` | **report-only**: nothing to fix here |
| `db` | the shop's PostgreSQL 18 server, database `bookshop` | `ssh db` as `player`; `psql` as the role `dba` | **fixable**: configuration changes are expected |

Both nodes are on one private network. Only the bastion's SSH port is
reachable from outside.

- `ssh db` logs you in to the database node (the key is in
  `~/.ssh/id_ed25519`).
- `psql -h db` from the bastion, or `psql` on `db`, connects you as the
  superuser role `dba` (the password is in `~/.pgpass` on both
  machines). Add `-d bookshop` for the shop's database.
- On `db`, PostgreSQL's configuration lives outside the data directory,
  in `/etc/postgresql/postgresql.conf` and `/etc/postgresql/pg_hba.conf`.
  You may edit them (your account is in the `pgconf` group), and `ALTER
  SYSTEM` works too.

## Applying changes on `db`

You may run exactly three commands with `sudo` on `db`, with no
arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-db` | reloads the configuration, then lists what PostgreSQL found wrong in the files, including settings that need a restart |
| `sudo gm-restart-db` | checks that the configuration loads, then restarts PostgreSQL; it refuses if the files do not load. Your SSH session stays open |
| `sudo gm-validate` | runs the public validator of `db` (below) |

## The validators

- On `db`: `sudo gm-validate`. It checks that the server accepts
  connections, that the game master's line is still in `pg_hba.conf`, and
  that the settings with an *envelope* (an allowed range or set of values)
  are within it, both the value in effect and the value written in the
  files. It prints `GREEN: ...` and exits 0, or one `RED ...` line per
  broken rule and exits 1.
- On the bastion: `gm-validate` (no `sudo` there) checks that the bastion
  is still usable for you.

Some settings may start outside their envelope; that is a finding, and
the shop expects it in your report. The validators are not monitoring
tools: run them to make sure you have not broken the game. If you cannot
make one green, report that too.

## Rules

- Work only through the bastion and `db`, with the accounts above.
- Changing the database's configuration and its contents is expected on
  `db`: it is fixable. Explain every change in your report.
- Stay inside the envelopes the validator checks.
- The game master answers no questions during the game: hints, restarts,
  resets and extra time are refused. You may ask to stop.

## DO NOT TAMPER

On `db`:

- the line `local all postgres peer` in `/etc/postgresql/pg_hba.conf`: it
  is the game master's access to the node;
- the file `/etc/postgresql/.gm-seeded`: removing it makes a restarted
  node overwrite your changes;
- SSH, `sudo`, the `gm-*` commands and the validator (read-only anyway).

Being a database superuser also gives you access to the operating system
of `db` as `postgres` (for example `COPY ... TO PROGRAM`). It cannot be
prevented, so it is a rule: do not use it to get around the list above.

On the bastion: SSH, the validator, `~/.ssh/id_ed25519`, `~/.pgpass` and
`~/.gm-starter-copied`.

## Your report

Write it in `~/report.md` on the bastion (or keep it on your machine and
paste it to the game master). For each issue, and for anything else you
found: what is wrong, the evidence (where you looked, what you saw), why
it matters, and what you did or recommend. Tell the game master when it is
your **final answer**.
