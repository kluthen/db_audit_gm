# pgwatch node — player notes

What you may know about the pgwatch node in a db_audit_gm game: a second
collector of PostgreSQL metrics, beside the exporters, read through
Prometheus and Grafana.

## Getting there

From the bastion, `ssh player@<node>` (the key is already in your
`~/.ssh`). The node has no web page of its own: its readings are in
Prometheus (the job `pgwatch`) and in Grafana's pgwatch dashboard, both
through the bastion's web front.

## What it does

pgwatch 6.1 connects to each database listed in its sources file as the
role `monitoring`, runs the queries of a metric preset on a schedule (once
a minute for most metrics of the `basic` preset), and serves the latest
values as Prometheus metrics on port 9188:

```
curl -s http://localhost:9188/metrics | grep '^pgwatch_'
```

Every series carries the label `dbname`, the source's name.
`pgwatch_instance_up` is 1 when pgwatch's last fetch reached the source
and 0 when it did not. pgwatch keeps no history: Prometheus does.

## What you can change

- **The sources**: `/etc/pgwatch/sources.yaml` (your account is in the
  `pwconf` group). One entry per watched database:

  ```yaml
  - name: records                                        # the dbname label
    conn_str: postgresql://monitoring@records:5432/postgres
    kind: postgres
    preset_metrics: basic
    is_enabled: true                                     # pgwatch skips an entry without it
  ```

  No password goes in the file: pgwatch reads it from a file of its own.
- **Your home**, `/home/player`: notes, `~/report.md`.

## Applying changes

pgwatch rereads `sources.yaml` every minute. To apply an edit at once and
see what it reaches:

```
sudo gm-restart-pgwatch
```

It refuses a file pgwatch cannot read, leaving the running pgwatch alone,
and prints `pgwatch_instance_up` for each source after the restart.

## The validator

`sudo gm-validate` checks that the sources file is valid for pgwatch, that
at least one source is enabled, that the metrics endpoint answers and that
pgwatch's own web interface is off. It prints `GREEN: ...` (exit 0) or one
`RED <rule>: ...` line per problem (exit 1). It never asks a database
anything: whether pgwatch reaches the right ones is for you to find out.

## Do not tamper

Do not tamper with SSH, `sudo`, the `gm-*` wrappers, the validator or the
pgwatch binary.

## Good to know

- A preset whose metrics need helper functions in the databases (such as
  `standard`) does not get them here: pgwatch is not allowed to create
  anything, so those metrics fail.
- Each fetch is a query on the watched database, inside its own limits.
