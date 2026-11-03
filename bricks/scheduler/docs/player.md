# scheduler node — player notes

What you may know about a scheduler node in a db_audit_gm game. Written
for v0.3, extended in v0.4 (scripts) and v0.5 (calls to APIs); expected
to evolve.

The node runs one of the customer's applications: a scheduler that sends
the application's queries to its database, and its calls to the APIs it
uses, at the times and rates its schedule says, and runs its fixed-time
operations (nightly batches,
reports, and scripts moving rows from one database to another). It holds
no business logic of its own: what it runs is in its query repository.
Some nodes only run fixed-time operations and send no traffic.

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
| `/srv/scheduler/repository/queries.yaml` | the query repository: each key, the SQL it runs (or the API call it makes), its parameters, whether it runs in a transaction | read; edit when the node is fixable for it |
| `/srv/scheduler/repository/builders/` | Python functions some keys use to build their statements | read; edit when fixable |
| `/srv/scheduler/repository/scripts/` | Python functions some fixed-time operations run, moving rows between databases (below) | read; edit when fixable |
| `/srv/scheduler/jobs/jobs.yaml` | the fixed-time operations: name, key, `connection` (or `connections`, for a script), `at` (a cron expression), `timezone` (UTC when absent) | read; edit when fixable |
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

## Calls to an API

A key of `queries.yaml` may be an HTTP call instead of SQL:

```yaml
  portal.desk-consent:
    call: POST /owners/%(owner)s/consents   # the method and the path; %(owner)s from params
    params:
      owner: {int: [2, 10000]}
      consent: {choice: {grant: 3, withdraw: 1}}   # grant three times in four
```

The scheduler sends one request per call, to the API its connection
names: the parameters not in the path are the request's JSON body (for
`GET` and `DELETE`, its query string), or a builder writes the body. The
request names the node in its `User-Agent` header, so the API's log shows
which application called. An answer that is not a success (`2xx`), no
answer in time, or no connection at all counts as an error, like a
failed query, in the log and the metrics.

A parameter may also pick among values by weight, `{choice: {a: 3, b:
1}}`, as well as evenly, `{choice: [a, b]}`.

## Scripts and their connections

A key of `queries.yaml` may name a script instead of SQL:

```yaml
  rollup.hourly:
    script: scripts/rollup.py:hourly     # a file of scripts/ and a function in it
    options: {batch: 5000}               # passed to the function
```

Such a key runs only as a fixed-time operation, never as traffic. Its
entry in `jobs.yaml` names `connections:` instead of `connection:`: for
each name the script uses, one of the scheduler's connections.

```yaml
  - name: rollup-hourly
    key: rollup.hourly
    connections:
      source: shop          # the script reads conns["source"]
      target: reporting     # and writes conns["target"]
    at: "5 * * * *"
```

The scheduler calls the function as `hourly(conns, options, log)`:
`conns` holds one open database connection per name, each as the
database role the scheduler uses for that connection, outside autocommit;
the script commits what it writes and returns the number of rows it
wrote, and `log("...")` adds a line to the scheduler's log. What a script
leaves uncommitted is rolled back when its run ends. You see which
connections a script uses in `jobs.yaml`, and while it runs, its
sessions in `pg_stat_activity` (`application_name` the node's name,
`usename` the role); you never see a password.

A script may use the Python standard library, `psycopg` 3 and `yaml`;
nothing else is installed. A run that raises an error ends with
`status=error` in the log; the scheduler goes on.

## Applying changes

The scheduler reads its repository and `jobs.yaml` when it starts and
when it is reloaded. You may run exactly two commands with `sudo`, with
no arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-scheduler` | Checks the repository and `jobs.yaml`, then has the scheduler reload them and prints when each fixed-time operation runs next (UTC). It refuses, and reloads nothing, when a file does not load or a key the schedule uses is missing, saying which. |
| `sudo gm-validate` | Runs the public validator. |

There is no "run now". To see a fixed-time operation work after a fix
(to its SQL, its builder, its script or its time), move its `at` to a few
minutes ahead and reload: `gm-reload-scheduler` prints when it runs next,
and the log shows its `run job=<name> ... phase=end` line when it has.
Put its time back afterwards and reload again, unless its time was what
needed fixing. This is how you verify a fix to any fixed-time operation
you may edit. Nothing else changes the traffic.

## The log

One line per event, each beginning with its UTC time:

- `summary minute=...` every minute while the application runs, then one
  `key` line per query key: calls, errors and latency percentiles
  (`p50_ms`, `p95_ms`, `p99_ms`) in that minute;
- `run job=... phase=start` and `phase=end` for each fixed-time run, with
  its rows or its error (`sqlstate=...` for a database error, `error=...`
  naming the kind of error a script raised otherwise); `skip job=...`
  for a run that could not start (the previous one still going, or a
  database refusing the connection);
- `script job=... <text>` for each line a script logs;
- `error key=... sqlstate=... message="..."` for each failed call; for
  a call to an API, `status=...` instead of `sqlstate=...`: the answer's
  three-digit status, `timeout` or `refused`;
- `reload` and `state` lines.

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- `queries.yaml`, the builders and scripts it names and `jobs.yaml` load,
  and each script's operation names `connections:`;
- the scheduler answers on port 9120;
- the files have not changed since the scheduler last loaded them (if
  they have: `sudo gm-reload-scheduler`).

Whether the queries are right, fast or wise is the audit's business, not
the validator's.

## Do not tamper

SSH, `sudo`, the `gm-*` commands, the validator, `/etc/scheduler/` and
the program under `/usr/local/lib/python3.13/dist-packages/gm_scheduler`
are part of the game, not of the customer's system: leave them alone.
Builders and scripts are code the scheduler runs: a builder or a script
you edit runs as the scheduler, a script with its database connections
open, so keep to what the customer's application would do.
