# scheduler node — player notes

What you may know about a scheduler node in a db_audit_gm game. Initial
version (v0.3), expected to evolve.

The node runs one of the customer's applications: a scheduler that sends
the application's queries to its database, at the times and rates its
schedule says, and runs its fixed-time operations (nightly batches,
reports). It holds no business logic of its own: what it runs is in its
query repository.

## Getting there

- **Shell**: from the bastion, `ssh player@<node>` (the key is already in
  your `~/.ssh`).
- **Metrics**: `http://<node>:9120/metrics` from any node of the game, in
  Prometheus' text format, per query key: `scheduler_calls_total`,
  `scheduler_errors_total`, `scheduler_call_duration_seconds` (a
  histogram), and the fixed-time operations' runs and skips. For example,
  on this node, `curl -s http://localhost:9120/metrics | grep ^scheduler_errors_total`.

## What is where

| Path | Holds | You |
|---|---|---|
| `/srv/scheduler/repository/queries.yaml` | the query repository: each key, the SQL it runs, its parameters, whether it runs in a transaction | read; edit when the node is fixable for it |
| `/srv/scheduler/repository/builders/` | Python functions some keys use to build their statements | read; edit when fixable |
| `/srv/scheduler/jobs/jobs.yaml` | the fixed-time operations: name, key, connection, `at` (a cron expression), `timezone` (UTC when absent) | read; edit when fixable |
| `/opt/gm/seed/schedule.yaml` | the schedule: the traffic, its rates and connections | you cannot read it, by design: it stands for the customer's real traffic |
| `/var/log/scheduler/scheduler.log` | the scheduler's log | read |
| `/etc/scheduler/scheduler.yaml` | where the log and the metrics are | read |
| `/home/player` | your notes, scripts, `~/report.md` | yours |

The times in `jobs.yaml` and in the log are UTC.

**Which files you may change** depends on the game: on some scheduler
nodes the repository, `jobs.yaml`, or both are yours to fix; on others
you may only report what you find. Where you may not, editing them gives
an ordinary "permission denied", and `sudo gm-reload-scheduler` says the
node is report-only. Where you may, edit in place or with `sed -i`;
your changes stay when the scheduler restarts.

## Applying changes

The scheduler reads its repository and `jobs.yaml` when it starts and
when it is reloaded. You may run exactly two commands with `sudo`, with
no arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-scheduler` | Checks the repository and `jobs.yaml`, then has the scheduler reload them and prints when each fixed-time operation runs next (UTC). It refuses, and reloads nothing, when a file does not load or a key the schedule uses is missing, saying which. |
| `sudo gm-validate` | Runs the public validator. |

There is no "run now": to see a fixed-time operation work after a fix,
move its `at` to a few minutes ahead and reload. Nothing else changes
the traffic.

## The log

One line per event, each beginning with its UTC time:

- `summary minute=...` every minute while the application runs, then one
  `key` line per query key: calls, errors and latency percentiles
  (`p50_ms`, `p95_ms`, `p99_ms`) in that minute;
- `run job=... phase=start` and `phase=end` for each fixed-time run, with
  its rows or its error; `skip job=...` for a run that could not start
  (the previous one still going, or the database refusing the
  connection);
- `error key=... sqlstate=... message="..."` for each failed call;
- `reload` and `state` lines.

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- `queries.yaml`, the builders it names and `jobs.yaml` load;
- the scheduler answers on port 9120;
- the files have not changed since the scheduler last loaded them (if
  they have: `sudo gm-reload-scheduler`).

Whether the queries are right, fast or wise is the audit's business, not
the validator's.

## Do not tamper

SSH, `sudo`, the `gm-*` commands, the validator, `/etc/scheduler/` and
the program under `/usr/local/lib/python3.13/dist-packages/gm_scheduler`
are part of the game, not of the customer's system: leave them alone.
Builders are code the scheduler runs: a builder you edit runs as the
scheduler, so keep to what the customer's application would do.
