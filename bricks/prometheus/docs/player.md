# Prometheus node — player notes

What you may know about a Prometheus node in a db_audit_gm game. Initial
version (v0.2), expected to evolve.

## Getting there

- **Shell**: from the bastion, `ssh player@<node>` (the key is already in
  your `~/.ssh`).
- **Web interface**: Prometheus' own UI, through the bastion's web front,
  at `/prometheus/` (the game master gives you the address and the tools
  password). Prometheus has no login of its own.
- **From any node of the game**: `http://<node>:9090/prometheus/`, for
  example with `curl` on this node: `curl -s
  http://localhost:9090/prometheus/api/v1/targets`.

## What you can change

- **Configuration**: `/etc/prometheus/prometheus.yml`: the scrape targets
  (`scrape_configs`) and the retention (`storage.tsdb.retention.time` and
  `.size`). You can edit it (your account is in the `promconf` group) and
  create files next to it, such as rule files it names.
- **Your home**, `/home/player`: notes, scripts, `~/report.md`.

Changes to `/etc/prometheus` stay in place when Prometheus restarts.

## Applying changes

You may run exactly two commands with `sudo`, with no arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-prometheus` | Checks `prometheus.yml` with `promtool`, then reloads it, retention included. It refuses to reload a file that does not load, so a typo does not reach the server. |
| `sudo gm-validate` | Runs the public validator. |

`promtool check config /etc/prometheus/prometheus.yml` checks a file
without reloading it.

Prometheus' own HTTP reload, shutdown and administration endpoints are
disabled: changes go through `sudo gm-reload-prometheus`.

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- `prometheus.yml` loads;
- Prometheus is ready, under `/prometheus/`;
- Prometheus runs the file as it is now: the last reload succeeded, and the
  file has not changed since (otherwise reload it);
- the retention is bounded both by time and by size.

The validator does not tell you whether Prometheus watches the right
things: that is part of your audit.

## Node health

Every node of the game, this one included, reports its own health at
`http://<node>:9110/metrics`, in Prometheus' text format: CPU and memory
against the node's limits, the space its volumes use against its disk
reservation, the host's free space, and the status of the services in its
list. The list is in `/opt/gm/node-health/node.conf` on each node. The
script and its list are read-only on every node: if they are wrong, report
it, or propose a fix.

## Do not tamper

Changing Prometheus' configuration is expected. Do not change SSH, `sudo`,
the `gm-*` commands or the validator (they are read-only anyway).

## Good to know

- No ports of this node are published outside the game's network.
- Prometheus' log goes to the container's output, which you do not see.
  If a reload fails, `gm-reload-prometheus` says so.
- Most of the system is read-only; `/tmp` is available.
- Times are in UTC.
