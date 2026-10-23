# Grafana node — player notes

What you may know about a Grafana node in a db_audit_gm game. Initial
version (v0.2), expected to evolve.

## Getting there

- **Web interface**: Grafana, through the bastion's web front, at
  `/grafana/` (the game master gives you the address and the tools
  password). The front asks for its own login first (user `player`, the
  tools password); then Grafana asks for its own: user **`admin`**, the
  same tools password. That account is Grafana's administrator.
- **Shell**: from the bastion, `ssh player@<node>` (the key is already in
  your `~/.ssh`).
- **From any node of the game**: `http://<node>:3000/grafana/`, for
  example with `curl` on this node: `curl -s
  http://localhost:3000/grafana/api/health`.

## Do not tamper: Grafana's users and the administrator's password

**Do not change Grafana's users or the administrator's password**: do not
change `admin`'s password, rename or delete it, or add, change or remove
users. The game master's own checks log in as `admin` with the tools
password; changing it locks them out. Grafana lets an administrator do
it, so nothing stops you: the rule is yours to keep. Several failed logins
in a row also lock the `admin` account for a few minutes.

## What you can change

- **In Grafana's UI**: dashboards, alert rules and data sources you
  create yourself. What came from the files below cannot be changed in
  the UI (Grafana says it was provisioned); you can save a copy of a
  dashboard under another name.
- **Provisioning files**, under `/etc/grafana/provisioning/` (your account
  is in the `grafconf` group; you can edit them and add files next to
  them):

  | File | Holds |
  |---|---|
  | `datasources/datasources.yaml` | the data source `Prometheus`: its address and settings |
  | `dashboards/dashboards.yaml` | where Grafana looks for dashboard files |
  | `dashboards/node-health.json` | the node-health dashboard (every node's CPU, memory, disk and services) |
  | `dashboards/postgresql.json` | the PostgreSQL dashboard |
  | `alerting/alert-rules.yaml` | the alert rules |

  On some games these files are read-only: an edit gets "permission
  denied", and `gm-reload-grafana` says the node is report-only.

- **Your home**, `/home/player`: notes, scripts, `~/report.md`.

Changes to `/etc/grafana/provisioning` stay in place when Grafana
restarts.

## Applying changes

You may run exactly two commands with `sudo`, with no arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-grafana` | Reloads the data sources, dashboards and alert rules from the files and prints what Grafana says. It refuses to reload while a dashboard file is not valid JSON, so a typo does not make a dashboard disappear. |
| `sudo gm-validate` | Runs the public validator. |

`jq . <file>` checks a dashboard file's JSON without reloading it.

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- the five provisioning files are in place, readable by Grafana, and the
  dashboard files are valid JSON;
- Grafana answers, under `/grafana/`;
- Grafana runs the files as they are now: the last reload succeeded, every
  dashboard file is loaded, and no file changed since (otherwise reload).

`ERROR: Grafana refused the administrator's login` means its password is
no longer the tools password: tell the game master.

The validator does not tell you whether the dashboards and alerts watch
the right things, or whether the data source points at the right place:
that is part of your audit.

## Alerts

Grafana evaluates the alert rules itself. Nothing is sent anywhere (no
e-mail, no chat): firing alerts are shown in Grafana's alerting view
(Alerting, Alert rules).

## Also do not tamper

Do not change SSH, `sudo`, the `gm-*` commands, Grafana's settings file or
the validator (they are read-only anyway).

## Good to know

- No ports of this node are published outside the game's network.
- Grafana's log goes to the container's output, which you do not see. If
  a reload fails, `gm-reload-grafana` says which part Grafana refused.
- Most of the system is read-only; `/tmp` is available.
- Times are in UTC, in Grafana too.
