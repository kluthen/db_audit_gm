# Grafana brick — GM notes

GM documentation of the `grafana` brick (`brick.yaml`, v0.2 master spec 7
and 7.4; required sections: v0.2 master spec 6.2; interface: capture W3 in
`specs/versions/v0.2/wave-log.md`). Never shipped to players. Brick
version 0.2.0, expected to evolve as games are played.

## Purpose

Grafana OSS 13.2.4 on Debian 13 (trixie), with an SSH server for the
players, in the image `127.0.0.1:5000/dbagm/grafana:0.2.0`. It fills the
role `monitoring`: the customer's dashboards and alerting, built on the
game's Prometheus, which the players audit and read through its UI. There
is no separate alerting brick: Grafana's own alerting evaluates the alert
rules, and there is no notification channel, so firing alerts are read in
Grafana's alerting view. The reference node-health dashboard is the game's
**node-health view** (D104). The GM picks it for every scenario with
dashboards; one per scenario, next to a `prometheus` node.

The image:

- Debian 13 (`debian:13-slim`), `openssh-server`, `sudo`, `curl`, `jq`,
  `nano`, `vim-tiny`, `less`, `procps`.
- Grafana OSS 13.2.4 (linux-amd64) from the upstream release archive on
  `dl.grafana.com`
  (`grafana/release/13.2.4/grafana_13.2.4_38252365904_linux_amd64.tar.gz`),
  verified by SHA-256 at build
  (`c48765988fd88572607e4ea670251af8a8e64ab3e360d0f3cf67a6f3587b92ab`, the
  value of the archive's `.sha256` and of grafana.com's package list),
  in `/usr/share/grafana`. Unpacked in a build stage of its own so the
  archive (about 460MB) never reaches the image, and trimmed there: of the
  plugins bundled with the release only the Prometheus data source is kept
  (`data/plugins-bundled/prometheus`, plugin version 13.2.3); the front
  end's source maps, the Swagger UI, the documentation and the packaging
  samples are dropped. The binary is upstream's, unmodified.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content and no host keys in the image. The
  provisioning files arrive as seed files; the reference ones are in
  `companion/`.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/grafana:0.2.0 bricks/grafana`.
- **How many**: one per scenario. Prometheus and Grafana always keep
  separate nodes.
- **Next to which node**: any host; it reaches Prometheus by node name over
  the game's network, and the bastion's web front reaches it the same way.
- **What it needs**: the bastion at 0.3.0 or later with the route
  `grafana` in its `web_routes` (the loader refuses a web interface without
  a route), and a `prometheus` node for the data source. The bastion's
  `tools_password` is the same secret as this node's (see "Configuration").
- **Stateful**: yes (`stateful: true`). Its volumes `grafdata`,
  `grafconf`, `home`, `gmstate` and `run` (see "Configuration") must follow
  the node if it is replaced; otherwise the database, the players' changes
  and the seed marker are lost.
- **Networks**: it must share a network with the bastion (the players' way
  in, and the web front that relays its UI) and with the Prometheus node.
  The renderer runs the whole game on one network.
- **Mounted material**: when the topology has a `prometheus` node, the GM
  mounts the node-health script into this node too (see "Connections").

## Configuration

`brick.yaml` declares no parameter (`parameters: {}`) and no knobs
(`knobs: []`): Prometheus' address is in the data source seed file, so
master spec 11.1's "data source pointed at the wrong address" is a
seed-file fault.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| The five seed files (`seed.files`, all required) | `/opt/gm/seed/<file>`, root `0444`, copied into `/etc/grafana/provisioning/` at first start (table below) | the scenario's `seed_files` (`nodes/<node>/<file>`), copied from `companion/` |
| Secret `tools_password` (kind `password`, `handed_over: true`) | `/opt/gm/secrets/tools_password`, uid 0, gid 472 (`grafana`), `0440` | `gmctl deploy`: the same secret as the bastion's (16 characters, the player alphabet); the GM hands it over with the web front |
| Secret `player_ssh_pubkey` (kind `key-pair`, pair `player_ssh_key`, half `public`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy`: the public half of the bastion's `player_ssh_key` |

The `tools_password` secret's uid, gid and mode differ from the bastion's
(0:0 `0400`); a secret name is compared only on `kind`, `handed_over`,
`pair` and `half` (capture W1-B), so both bricks declare one secret.

### The seed files

Flat names, so the Swarm config names stay short. Each is copied once,
`grafana:grafconf` `0664`, into its directory (`2775`):

| Seed file (`/opt/gm/seed/`) | Live path under `/etc/grafana/provisioning/` | Holds |
|---|---|---|
| `datasources.yaml` | `datasources/datasources.yaml` | the data source: name `Prometheus`, uid `prometheus`, type `prometheus`, URL `http://<prometheus node>:9090/prometheus`, default, `editable: false` |
| `dashboards.yaml` | `dashboards/dashboards.yaml` | the dashboard file provider, path `/etc/grafana/provisioning/dashboards`, `allowUiUpdates: false`, `updateIntervalSeconds: 86400` |
| `node-health.json` | `dashboards/node-health.json` | dashboard uid `node-health`: the node-health view (D104) |
| `postgresql.json` | `dashboards/postgresql.json` | dashboard uid `postgresql` |
| `alert-rules.yaml` | `alerting/alert-rules.yaml` | alert rules in Grafana's file format; no contact points, no policies |

The entrypoint also creates the empty `plugins/` directory (Grafana logs
an error without it). A scenario needing another seeded dashboard bumps
the brick, as prometheus' rule files do. On a fixable node players may
edit these files and add others (any `*.yaml`, `*.yml` or `*.json`).

**The reference files**, in `companion/` under the same names: a scenario
copies them into `nodes/<node>/`, byte for byte or changed for a fault,
and never points at them (the loader's `_inside` refuses a path outside
the scenario folder); nothing is mounted. Changing the host part of the
data source URL is all a scenario with a Prometheus node not called
`prometheus` needs. Dashboards set `"timezone": "utc"` and the data source
`{type: prometheus, uid: prometheus}`, have no `__inputs`, and select by
metric name and the `node` label, never by `job`.

- **`node-health.json`, the node-health view** (master spec 14 item 5):
  CPU as a share of each node's limit and memory working set as a share of
  its limit (time series per node, warning at 80 %, critical at 90 %);
  disk, the node's volumes against its reservation (bar per node) and the
  bytes used and reserved (table); every service of every node's list as
  UP or DOWN (`node_health_service_up`); the host's free space once
  (`max(node_health_host_free_bytes)`).
- **`postgresql.json`**: whether the exporter is connected (`pg_up`,
  CONNECTED or DISCONNECTED); statement calls per second; execution time
  per second, mean time per call and calls per second for the ten heaviest
  statements (`pg_stat_statements_calls_total`,
  `pg_stat_statements_seconds_total`, by `queryid`).
- **`alert-rules.yaml`**: one group `db_audit_gm` in folder `db_audit_gm`,
  evaluated every minute; each rule an instant query and a threshold, no
  data counted as normal (a missing exporter shows as a target down):

  | Rule uid | Title | Fires when | For | Severity |
  |---|---|---|---|---|
  | `gm-target-down` | Scrape target down | `up < 1` | 1m | critical |
  | `gm-service-down` | Service down on a node | `node_health_service_up < 1` | 1m | critical |
  | `gm-exporter-disconnected` | Exporter disconnected from PostgreSQL | `pg_up < 1` | 1m | critical |
  | `gm-disk-near-reservation` | Disk near the node's reservation | volumes' use / reservation `> 0.9` | 5m | warning |
  | `gm-memory-near-limit` | Memory near the node's limit | working set / memory limit `> 0.9` | 5m | warning |

  Five rules. A fault leaving out an alert (for example "no alert on a
  target down") removes its rule from the scenario's copy.

### Settings in the image

`/etc/grafana/grafana.ini` is in the image, root `0444`, protected, not a
seed file: it holds the administrator account, the sub-path and the
authentication settings. Everything else keeps Grafana's defaults.

| Setting | Value |
|---|---|
| `[server]` | `http_port = 3000`, `root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/`, `serve_from_sub_path = true` (the sub-path, master spec 15) |
| `[security]` | `admin_user = admin`, `admin_password = $__file{/opt/gm/secrets/tools_password}`, no Gravatar |
| `[date_formats]` | `default_timezone = UTC` |
| `[users]` | `allow_sign_up = false`, `allow_org_create = false` |
| `[auth.anonymous]`, `[auth.basic]` | anonymous off; basic authentication on (the in-node API calls use it) |
| `[paths]` | `data = /var/lib/grafana` (`grafana.db`), `plugins = /var/lib/grafana/plugins`, `provisioning = /etc/grafana/provisioning` |
| `[log]` | `mode = console`: Grafana's log is the container's output (`gmctl logs`) |
| no outbound calls | `[smtp] enabled = false`; `[analytics]` no reporting, update or plugin-update checks, no feedback links; `[news]` off; `[snapshots] external_enabled = false`; `[plugins]` no pre-installation, no public-key retrieval, no plugin catalog |
| `[unified_alerting]` | `enabled = true`; no contact point provisioned |

**Settled at build** (master spec 15 and capture W3):

- *Sub-path*: `root_url` ending in `/grafana/` and `serve_from_sub_path =
  true`; Grafana serves everything under `/grafana/`, the path the front
  forwards unchanged, so the route name must be `grafana`. Its pages carry
  `<base href="/grafana/">` and `appSubUrl` `/grafana`. Outside the
  sub-path Grafana only redirects (`/` and `/login` answer 301 to
  `http://localhost:3000/grafana/...`, built from `root_url`), except
  `/api/health`, which also answers there.
- *`$__file{}`*: works as capture W3 states in 13.2.4; the value is
  trimmed, so a password file with or without a final newline gives the
  same password.
- *Time zone*: Grafana 13.2.4 refuses the lowercase `utc` that capture W3
  wrote (warning "Unknown timezone as default_timezone", and the browser's
  zone stays in effect); it takes the zone name `UTC`. The setting in
  effect is in `/api/frontend/settings` (`dateFormats.defaultTimezone`:
  `UTC`); `/api/admin/settings` only echoes the file's value. Dashboards
  keep `"timezone": "utc"`, which Grafana accepts there.
- *Brute-force protection*: Grafana's default, 5 failed logins for one user
  name lock it for 5 minutes (`[security]` unchanged).

### Fixed paths (capture W1-B)

| What | Path | Notes |
|---|---|---|
| Seed directory | `/opt/gm/seed/` | configs, read-only |
| Provisioning | `/etc/grafana/provisioning/` | volume `grafconf`; `grafana:grafconf`, each dir `2775` and seeded file `0664` when fixable, `2755` and `0644` otherwise (see "Access") |
| Write policy | `/run/gm/write-policy` | root `0444` in the root-only `/run/gm`; written at each start from `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES` |
| Settings | `/etc/grafana/grafana.ini` | in the image, root `0444` |
| Database, plugins | `/var/lib/grafana` | volume `grafdata`; `grafana:grafana` `0750`, unreadable to `player` |
| Grafana itself | `/usr/share/grafana` | in the image (`bin/grafana`, `conf/defaults.ini`, `public/`) |
| Seed marker | `/var/lib/gm-state/.gm-seeded` | volume `gmstate`; dir root `0755`, marker root `0444` |
| Record of the last start or reload | `/run/gm-grafana/applied` | root:grafana `0440` in a `0750` dir; written by root only (see "Checks") |
| Player home | `/home/player` | volume `home` |
| Runtime | `/run` | volume `run`, emptied at each start |
| Secrets | `/opt/gm/secrets/tools_password`, `/opt/gm/secrets/player_ssh_pubkey` | |
| Validator | `/opt/gm/validator/validate.sh` | |
| Wrappers | `/usr/local/sbin/gm-reload-grafana`, `gm-validate` | |
| Write-policy helper | `/usr/local/sbin/gm-write-policy` | run as root by the entrypoint and `gm-reload-grafana`; not a `sudo` wrapper |
| API helper | `/usr/local/lib/gm/grafana-api` | root:grafana `0750` (see "Access") |
| Shared shell functions | `/usr/local/lib/gm/grafana-files` | root `0444`, sourced by the run script, the wrapper and the validator |
| Entrypoint, health check | `/usr/local/sbin/gm-entrypoint`, `/usr/local/lib/gm/healthcheck` | |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/sshd`, `/run/sshd-keys`, `/run/gm`,
   `/run/tmp` (`/tmp` and `/var/tmp` are symlinks to it) and
   `/run/gm-grafana`.
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container if `player_ssh_pubkey` is missing or empty, or
   `tools_password` is missing, empty, more than one line, or unreadable
   by `grafana`.
4. Reads the write policy from `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES`
   (both unset or empty: `fixable`, no override) and writes
   `/run/gm/write-policy`. An unknown policy, or an override that is not
   one of `writable_paths`, fails the container with one line
   (`gm-entrypoint: fatal: GM_WRITE_POLICY='read-only' is not one of
   fixable, report-only, no-access`, `gm-entrypoint: fatal:
   GM_WRITE_OVERRIDES: '<path>' is not one of this brick's writable_paths
   (...)`).
5. If `/var/lib/gm-state/.gm-seeded` is absent: creates `datasources/`,
   `dashboards/`, `alerting/` and `plugins/`, copies the five seed files to
   their live paths and writes the marker. A missing seed file fails the
   container. Never overwrites afterwards. The marker is on its own
   root-owned volume, out of reach of `player` and `grafana`.
6. Applies the write policy's owner and modes to the seeded files and the
   provisioning directories (see "Access"), seeding or not, contents
   untouched; logs `write policy: policy=... overrides=...`.
7. Sets the ownership of the database directory and the player's home.
8. **The administrator's password** (ruling 8 of capture W3): when the
   database already exists, sets the `admin` account's password from the
   secret (`grafana cli admin reset-admin-password --password-from-stdin`
   as `grafana`, the password on stdin). On the first start Grafana creates
   the account with the password from `grafana.ini`. So the password is
   the tools password from the game's first start, and **every container
   start sets it again**: a restart (`docker service update --force`, or
   any new container) undoes a changed password and lets the GM's checks
   in again. A failure here is logged as a warning, not fatal. Brute-force
   lockouts are not cleared by it (see "Known limits").
9. Execs s6-overlay's `/init`, which supervises `grafana` and `sshd`.

Grafana runs as `grafana` (`s6-setuidgid`) with
`grafana server --homepath=/usr/share/grafana --config=/etc/grafana/grafana.ini`;
before each start its s6 `run` script records the provisioning files'
state in `/run/gm-grafana/applied` (see "Checks"). First start: about 12 s
to healthy in the stack test (database migrations). `/run` is a named
volume for the reason the `postgres` brick's
[GM notes](../../postgres/docs/gm.md#why-run-is-a-volume) give.

## Connections

Container ports 3000 and 22; nothing is published (only the bastion
publishes ports), so both are reachable only from nodes sharing a network
with it, by its node name.

- **Provides `ui`, HTTP, port 3000, web path `/grafana/`.** Grafana's UI
  and HTTP API. The other side is the bastion's web front: route `grafana`
  in the bastion's `web_routes` parameter (`grafana: "<node>:3000"`;
  confirms the bastion's `consumes {ui, http, 3000}`), which the front
  serves at `/grafana/` and forwards with the path unchanged, clearing the
  players' `Authorization` header. Players sign in on Grafana's login page
  as `admin` with the tools password, after the front's own `player` login
  with the same password.
- **Provides `ssh`, SSH protocol, port 22.** The other side is the
  bastion's inner hop (`ssh <node>`), as `player`, by public key only: the
  node's `player_ssh_pubkey` is the public half of the bastion's
  `player_ssh_key`. The node's host key is created anew at each container
  start; see the bastion brick's
  [GM notes](../../bastion/docs/gm.md#inner-hop-and-host-keys).
- **Consumes `ui`, HTTP, port 9090**: Prometheus, the data source, at
  `http://<prometheus node>:9090/prometheus` (Prometheus serves under its
  own sub-path). The address is in the data source seed file, not wired by
  the topology. Nothing has to exist first: a data source that does not
  answer is a finding (its health check fails, panels show errors), not a
  deployment failure.

**Monitoring**: Grafana serves its own metrics at `/grafana/metrics`; no
reference scrape configuration lists them.

**Mounted material**: the image accepts another brick's mounted companion
material (`brick.yaml` `receives`): it runs s6-overlay `3.2.3.2`, and the
commands `sh`, `cat`, `du`, `df`, `awk`, `sed`, `grep`, `sleep`, `perl`,
`s6-svstat` and `s6-setuidgid` are on an s6 service's PATH (checked with
`command -v` at build). With a `prometheus` node in the topology, the GM
mounts the node-health script here, as on every node; its `default` entry
expands to `grafana sshd`.

The GM's own operations (validator, sealed checks, the API) do not use
these interfaces: they run inside the container through `gmctl exec`.

## Access

### Accounts and access

- `player`: SSH by public key only (`AuthorizedKeysFile` points at the
  secret; no password, no PAM), member of `grafconf` (gid 473), never of
  `grafana`. No TCP, agent or X11 forwarding.
- `grafana` (uid and gid 472, checked at build): runs the server, owns the
  database; no login. The secret's gid is this group's.
- Grafana's own users: **`admin` only**, a Grafana administrator, password
  the tools password. Sign-up and organisation creation are off;
  anonymous access is off. The front's user `player` is not a Grafana user,
  so a front header that leaked through could never log anyone in.
- `sudo`: `player` may run the two wrappers as root, with no arguments
  (`/etc/sudoers.d/gm-player`): `env_reset`, fixed `secure_path`, no
  syslog, log in `/run/gm/sudo.log`.

**Web interface**: Grafana's UI through the bastion's web front at
`/grafana/`. The tools password makes the players Grafana administrators
(access model 8): they may edit dashboards, data sources and alert rules
they create in the UI, and must not change Grafana's users or the
administrator's password (DO NOT TAMPER, `docs/player.md`; not enforced,
access model 11). What came from the seed files cannot be changed in the
UI: the data source is `editable: false`, provisioned dashboards are not
savable (`allowUiUpdates: false`; "Save as" a copy works), provisioned
alert rules have provenance `file`. Changes to them go through the files
and the wrapper, so a fix lives in the file and survives a restart.

### Writable and protected paths, write policies

- Writable by the player: `/etc/grafana/provisioning` and its
  subdirectories where they are fixable (below: `grafana:grafconf`,
  `2775`; seeded files `0664`), `/home/player` under every policy, and the
  scratch space `/tmp` and `/var/tmp`, both links to `/run/tmp` (root,
  `1777`, emptied at each start, see "Start-up"). `brick.yaml`'s
  `writable_paths` also declares the three provisioning subdirectories
  `/etc/grafana/provisioning/alerting`,
  `/etc/grafana/provisioning/dashboards` and
  `/etc/grafana/provisioning/datasources`, each a possible
  `write_overrides` entry.
- Protected (root-owned, read-only to the player): `grafana.ini`,
  `/etc/ssh/sshd_config`, `/etc/sudoers`, `/etc/sudoers.d/gm-player`, the
  entrypoint, the two wrappers and their helper `gm-write-policy`, the
  health check, the API helper (also not
  runnable by `player`), the shared functions, the validator, the s6
  service definitions, the seed marker's directory `/var/lib/gm-state` and
  `/run/gm-grafana`. The database directory and the secret are not
  readable by the player.
- **Write policies** (`write_policies`): `fixable` and `report-only`
  (v0.3 master spec 7.4), as on the `prometheus` brick, **for the files
  only** (the interface gap below). The renderer passes the node's policy
  as `GM_WRITE_POLICY` and its `write_overrides` as `GM_WRITE_OVERRIDES`
  (sorted, space-separated); `no-access` is read as `report-only` for the
  files. A path is *fixable* when the policy is `fixable`, or it is an
  override or lies under one, so an override of
  `/etc/grafana/provisioning` makes the whole tree fixable and one of a
  subdirectory only that one. Each directory and seeded file takes its
  mode from its own path:

  | | a fixable directory | a seeded file in it | otherwise |
  |---|---|---|---|
  | mode | `2775` | `0664` | `2755`, `0644` |

  The directories are `provisioning/` itself, `datasources/`,
  `dashboards/`, `alerting/` and `plugins/` (the last holds no seeded file
  and follows its own path the same way). Owner `grafana:grafconf`
  throughout. On a report-only node, with no override, `player` (in
  `grafconf`) can read every file but not change, replace, remove or add
  one, nor add a directory: an ordinary "permission denied". With the
  override `/etc/grafana/provisioning/alerting`, only `alert-rules.yaml`
  and its directory are fixable. The policy is set at each container
  start (entrypoint) and enforced again by the wrapper before every
  reload; it changes only with a new deployment.
- **Owner restored**: `sed -i` replaces a file with one owned by
  `player`. The entrypoint at every start, and `gm-reload-grafana` before
  it reloads, give the five seeded files and the provisioning directories
  their owner and mode back, contents untouched. Nothing is changed
  through a symbolic link or on a file with other hard links: such an
  entry is left alone and named (`left alone: ...`); a directory a player
  removed on a fixable node is not recreated. Files players add on a
  fixable path (a dashboard of their own, a second rules file) stay as
  they made them, owned by `player`, group `grafconf`, readable by
  Grafana, which provisions them with the rest.
- **The interface gap** (v0.3 master spec 7.4, access model 11, accepted):
  the write policy guards the files on the node, not Grafana's interface.
  On a report-only Grafana node the players, administrators through the
  tools password, can still create and edit dashboards, data sources,
  alert rules and contact points in the UI or the API; what came from the
  seed files stays locked there as on a fixable node (see "Web
  interface"). Nothing in the brick refuses it. A scenario that makes a
  Grafana node report-only expects the fix in the report, and its sealed
  checks judge the live state, whatever changed it.

### Wrappers

- `gm-reload-grafana`: first restores the owner and mode (above); then,
  when none of `datasources/`, `dashboards/` and `alerting/` is fixable
  (report-only, no override), prints one line and exits 1, reloading
  nothing: `gm-reload-grafana: this node is report-only: its files cannot
  be changed, so nothing was reloaded.` (exit 2 if the policy cannot be
  read or the owner not restored). An override of one subdirectory is
  enough for it to reload all three kinds. It then checks the
  provisioning files as the validator's
  `files` rule does, as `grafana`, and refuses (exit 1, "NOT reloaded") if
  a dashboard file is not valid JSON or a file is unreadable to `grafana`
  (a missing seed file is only a warning). Otherwise POSTs
  `/api/admin/provisioning/datasources/reload`, `.../dashboards/reload`
  and `.../alerting/reload` through the API helper, prints each answer
  (`Datasources config reloaded`, ...) and records the result. Exit 1 if
  Grafana refuses one ("REFUSED", for example an alert rules file that does
  not parse: `Internal Server Error`; the reason is in Grafana's log), or
  refuses the administrator's login (the DO NOT TAMPER message; it stops at
  the first refusal, so one failed login only). If Grafana is not running
  (a data source or alert rules file that stopped it at start), s6 keeps
  restarting it; the wrapper waits up to 30 s for it to answer, then
  reloads.
- `gm-validate`: runs the validator as `grafana`, exit code passed through.
  Never refused, whatever the policy.

**Edits and Grafana's own polling** (ruling 6 of capture W3): the
reference provider polls the dashboard files once a day
(`updateIntervalSeconds: 86400`), so in practice an edited file takes
effect through the wrapper, as with Prometheus, and the validator's
`pending` rule stays truthful. `allowUiUpdates: false`: see "Web
interface" above. A scenario may change both in its copy of
`dashboards.yaml`.

### The API helper

`/usr/local/lib/gm/grafana-api <METHOD> <path>`, root:grafana `0750`,
protected, not a `sudo` wrapper. `METHOD` is `GET`, `POST`, `PUT`, `PATCH`
or `DELETE`; `path` starts with `/` (for example `/api/health`), without
spaces or quotes. It reads the secret and sends `admin:<password>` to
`http://127.0.0.1:3000/grafana<path>` through `curl -K -` (the password on
stdin, never in an argument or the environment); no request body. Prints
the response body; on a status other than 2xx also `grafana-api: HTTP
<status>` on stderr. Exit 0 on 2xx, 1 on any other HTTP status (401: the
administrator's login was refused), 2 when Grafana does not answer or on a
usage error. It never retries. The wrapper, the validator, sealed checks
and the GM all use it.

### Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, prometheus' list for the
same reasons: the entrypoint needs `CHOWN`, `DAC_OVERRIDE`, `FOWNER`,
`SETGID` and `SETUID`; SSH logins need `SYS_CHROOT`; `sudo` needs
`AUDIT_WRITE` to stay quiet; s6 needs `KILL` to signal the
`grafana`-owned server; `NET_BIND_SERVICE` is for sshd's port 22 on
platforms other than Docker. `no-new-privileges` is off: `sudo` is setuid.
Not re-checked by dropping each one in turn for this brick.

### What the GM uses

`gmctl exec --node <node> --user root` running the helper; `gmctl
validate` runs the validator as `grafana`; `gmctl logs --node <node>`
shows Grafana's log. Never a credential in `--env` or on a command line.
The endpoints, as capture W3 lists them, all answer in 13.2.4 as stated:

| Endpoint | Gives |
|---|---|
| `/api/health` | `database` (`ok`), `version` |
| `/api/user` | `login` `admin`, `isGrafanaAdmin` `true` |
| `/api/datasources`, `/api/datasources/uid/prometheus` | the data source (`url`, `isDefault`, `readOnly`) |
| `/api/datasources/uid/prometheus/health` | `status` `OK`, or `ERROR` with Prometheus' error (HTTP 400: the helper exits 1) |
| `/api/search?type=dash-db`, `/api/dashboards/uid/<uid>` | the dashboards; `meta.provisioned`, `dashboard.timezone` |
| `/api/v1/provisioning/alert-rules`, `/api/v1/provisioning/alert-rules/<uid>` | the rules, `provenance` `file` |
| `/api/prometheus/grafana/api/v1/rules` | each rule's `state` (`inactive`, `pending`, `firing`) and `health`; firing alerts |
| `/api/v1/provisioning/contact-points` | `[]` (no contact point) |
| `/api/frontend/settings` | `dateFormats.defaultTimezone`: the time zone in effect (`UTC`) |
| `/api/admin/settings` | the files' settings: `date_formats.default_timezone` (`UTC`), `server.root_url` (the template as written), `server.serve_from_sub_path` |

Never send a wrong administrator's password: the brute-force protection
locks `admin` out for 5 minutes after 5 failures.

## Footprint

Default footprint in `brick.yaml`, in the shape of a scenario node's
`resources`: limits CPU `0.495` and memory `378M`; reservations CPU
`0.095`, memory `266M` and disk `256M`. The limits, the CPU and the disk
are master spec 12's figures for a Grafana node (limits 0.5 / 384M,
reservations 0.1 CPU, 256M of volumes), which include the node-health
script, less the script's own cost (0.005 CPU / 6M, see the `prometheus`
brick), since a brick's footprint excludes mounted material. The memory
reservation is measured: a node of `272M` (this figure plus the script's
6M) in place of the spec's estimate of 160M, which the node exceeded at
rest. The scenario sets each node's own `resources`, and `gmctl` uses
those. Disk growth per hour (`disk_growth_per_hour`): `1M` (below).

Measured in the v0.2 game (`fernway-clinics-monitoring` on the `laptop`
playground, declared at 2 CPU / 4G / 8G on armenelos: AMD Ryzen 5 PRO
8640HS, 11.3 GiB, Docker 29.9.1; 2026-10-21; `docker stats`, the highest
of its samples, the node-health script included), under a 384M limit:

| Moment | Memory | CPU |
|---|---|---|
| At rest, 11 to 15 minutes after the deployment | 195M | 0.07 |
| During dashboard loads (three browsers at a time through the web front, both dashboards, every panel's query) | 304M | 0.26 |
| During a pgBadger run on `db` | 301M | 0.07 |
| At rest again, 9 to 13 minutes after the dashboard loads | 258M | 0.05 |

The node was never OOM-killed nor restarted, and never reached its limit
(cgroup `memory.events` `max 0`; `memory.peak`, page cache included,
332M). Grafana keeps much of what a dashboard load takes for minutes
after it, so the reservation covers the reading at rest after use, not
only the one after hand-over (the stack test's 180M to 195M,
`memory.current`, agrees with the latter). Over half-second windows
a dashboard load reaches 0.47 CPU, close to the 0.5 limit: a player sees
slower panels, not a failure. The database volume: about 2M (1.7M after
35 minutes).

Measured in the v0.3 rehearsal (`tools/tests/rehearsal.sh`:
`tarnbeck-outdoor-shop` on armenelos, AMD Ryzen 5 PRO 8640HS, 11.3 GiB,
Debian 13, Docker 29.9.1, plus the VPS `vps-5718ad52`, 4 vCPU Intel
Haswell, 7.6 GiB, Docker 29.9.2; 2026-10-28; 46 minutes of load from T0
12:59Z to the hand-over check, the customer's noon peak from 13:00Z;
`docker stats` every 20 s, the node-health script included), under the
384M limit, no dashboard opened: 182M at most and throughout, 0.19 CPU at
most (0.12 at the 95th percentile); `grafdata` grew 5K an hour (alert
rules evaluated every minute, none firing), so `disk_growth_per_hour` went
from a provisional `2M` to `1M`. Its snapshot stop: `grafana` down 7 s
(13:46:57Z to 13:47:04Z, a 1.7M `grafdata` copied on the VPS).

What makes it grow:

- **Memory**: dashboards being viewed (each panel's queries go through
  Grafana), the number of alert rules and their series, Grafana's caches.
- **Disk**: `grafana.db` (dashboards' versions, alert state history,
  sessions); small for a game.
- **CPU**: dashboard loads and alert rule evaluation (every minute), the
  first start's database migrations.

Levers: fewer panels or a longer refresh, fewer rules or a longer
evaluation interval.

**Image**: 866MB (`docker image inspect`), against master spec 12's
estimate of about 450M: the Grafana binary alone is 499M (Go, with debug
information, kept as published), the front end about 130M without its
source maps, the Prometheus data source plugin 54M.

### Snapshot

How each volume is copied at hand-over (`snapshot:` in `brick.yaml`):

- `grafdata`: `stop`. The brick's services other than `sshd` (here
  `grafana`) are stopped through s6, never by a Swarm scale to zero,
  while the volume is copied, then started again: Grafana is briefly
  down at hand-over (the health checks stay green; the players are told
  it is maintenance). A stop, not a copy, because `grafana.db` is SQLite,
  written while Grafana runs (alert state, sessions). The brief stop,
  measured by the stack test (armenelos, 2026-10-23, a `grafdata` of
  1.6M): the stop 30 ms, the copy 3 ms, back up 35 ms after the stop
  began, answering its API about 2 s later. s6 waits up to 60 s for each
  step.
- `grafconf`, `home`, `gmstate`: `copy`, a tar of the volume while the
  node runs, taken before the stop to keep it short.
- `run` (`/run`) is never copied.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59). This list is every catalog fault (`faults/`) whose `applies_to`
names `grafana` `0.2.0`, and no other.

| Fault | Kind | What it needs from the brick |
|---|---|---|
| `grafana-alert-for-too-long` | seed file | the seed `alert-rules.yaml` (material `inject/alert-rules.yaml.snippet`): rule `rule` (a uid, `gm-service-down` in the v0.2 scenario, never `gm-target-down`) with `for: 2h`, the other four seed files as the companion's; `gm-reload-grafana` for the fix; the helper `/usr/local/lib/gm/grafana-api` and `jq` for the sealed check, which reads the rule through `/api/v1/provisioning/alert-rules/<uid>` |

It is fixable on this fixable node through the file and
`gm-reload-grafana` (provisioned rules are not editable in the UI); the
sealed check judges the live state through the API, so a change made
through the API also counts.

Faults it lends itself to with no definition yet (master spec 11.1's
candidates), all seed-file faults on the scenario's copies of the
companion files: the data source pointed at the wrong address
(`datasources.yaml`; not chosen for v0.2: it hides every other monitoring
fault); an alert left out (`alert-rules.yaml`); a misleading dashboard,
for example a panel reading the wrong metric or a threshold set too high
(`node-health.json`, `postgresql.json`); an alert rule with a threshold
in the wrong unit. All would be fixable on a fixable node through the
files and `gm-reload-grafana`; sealed checks judge the result through the
API.

Known interactions: a data source at the wrong address empties every panel
and makes every rule's evaluation fail (rule `health` `error`); a scrape
target left out of Prometheus' configuration hides that node from the
node-health view and fires no target-down alert, since Prometheus does not
know the target. `gm-target-down` firing is the evidence of
`prometheus-node-health-node-missing`, so `grafana-alert-for-too-long`
never targets it.

Faults it cannot host: anything needing a notification channel (none),
and a default administrator's password: there is none (master spec 7.4).

## Checks

### Validator

`/opt/gm/validator/validate.sh`, run as `grafana`. The official run is
`gmctl validate` (the GM's exec as `grafana`). It judges only whether
Grafana runs its own files as written, never what they point at: a wrong
data source address or a dashboard watching the wrong metric is a finding,
not a red rule. Rules:

| Rule | Red when |
|---|---|
| `files` | one of the five files is missing from its live path, a file under `/etc/grafana/provisioning` is unreadable to `grafana`, or a dashboard file is not valid JSON |
| `server` | Grafana does not answer `/grafana/api/health` on port 3000, or reports its database other than `ok` (the next two rules are then not checked) |
| `reload` | the last reload through the wrapper failed; or a dashboard file with a `uid` is not served by Grafana (not checked while a change is pending) |
| `pending` | a provisioning file (`*.yaml`, `*.yml`, `*.json`: name, size or time of change) differs from when Grafana last loaded them, at its last start or reload through the wrapper |

Output: `GREEN: ...` and exit 0; one `RED <rule>: ...` line per broken
rule and exit 1, for example

```
RED files: /etc/grafana/provisioning/dashboards/postgresql.json is not valid JSON: jq: error (at ...): ...
RED pending: a provisioning file changed after Grafana last loaded them (the start at 2026-10-21T16:58:10Z); run sudo gm-reload-grafana
```

`ERROR: ...` and exit 2 when Grafana **refuses the administrator's login**
(its password is no longer the tools password: the DO NOT TAMPER rule was
broken; a restart sets it back, see "Start-up"), or answers unexpectedly.
The administrator's login is checked once per run (`/api/user`); each run
with a changed password counts one failed login. How "last loaded" is
known: before each start the s6 `run` script, and after each reload the
wrapper, write `/run/gm-grafana/applied` (`how`, `at`, `result`, a
fingerprint of the files, `detail`), as root; `grafana` can read it,
`player` cannot read or write it. A start that provisioned with an error
in a data source or alert rules file does not leave Grafana running, so
`server` is red then.

### Sealed checks

Sealed checks on this node judge **Grafana's effective live state through
its API**, not only the provisioned files (master spec 7.4, access model
9): a script run with `run_as: root` calls the helper on the endpoints in
"What the GM uses", for example the data source's `url` and health, a
rule present in `/api/v1/provisioning/alert-rules` with its threshold, a
rule `firing` in `/api/prometheus/grafana/api/v1/rules`. A player may have
changed things in the UI that no file shows.

### Health check

Healthy while `sshd` is up, once Grafana has answered `/grafana/api/health`
at least once in this container (marker `/run/gm/grafana-was-ready`).
After that, Grafana being down does not make the container unhealthy, so
Swarm does not replace it and cut the players' SSH sessions.
`start_period: 120s` for the first start's migrations at 0.5 CPU.

### After deployment

`gmctl deploy` returns once the node is healthy, which proves Grafana
started (with its data source and alert rules files, which stop it when
they fail). `gmctl validate` shows the validator. The wiring is confirmed
from inside the node with the helper: `/api/datasources/uid/prometheus/health`
`OK`, both dashboard uids in `/api/search?type=dash-db`, the alert rule
count equal to the scenario's file, the default time zone `UTC`; and the UI
answering at `/grafana/` through the bastion's web front.

### Stack test

`sh bricks/grafana/tests/run-stack-test.sh` deploys the brick as stack
`gmtest-grafana` (`tests/stack.test.yml`, no published port) with its five
seed files copied from `companion/` and a `prometheus` 0.2.0 node seeded
with that brick's test fixture, checks the chunk's Done-when and removes
everything it created, volumes included. It reads the API with the helper,
the UI from a client container on the stack's network (this image, entry
point replaced), and SSHes in as `player`; every credential goes to `curl`
on stdin. It never sends a wrong administrator's password, so the
validator's `ERROR` on a refused login is not exercised there. Then the
snapshot's brief stop, the node redeployed `report-only` (`docker service
update --env-add GM_WRITE_POLICY=report-only`: modes, denied edits, the
wrapper's refusal, nothing reloaded), then with the override
`/etc/grafana/provisioning/alerting` (the rule file's edit through the
wrapper, the owner restored, the data source file still locked), and the
entrypoint's two write-policy refusals. Needs a swarm manager and both
images built.

## Known limits

- **Write policy, files only**: on a report-only node the players, as
  administrators, can still change content in the UI or the API (the
  interface gap, see "Access"; access model 11, accepted).
- **DO NOT TAMPER, not enforced**: players can change Grafana's users or
  the administrator's password through the UI or the API. The GM's checks
  then get `ERROR` (validator) or HTTP 401 (helper) until a restart sets
  the password back. Each refused login counts towards the brute-force
  lockout (5 in 5 minutes), which a restart does not clear: after a
  lockout, wait 5 minutes.
- **Contact point** (ruling 3 of capture W3): Grafana 13.2.4's default
  alerting configuration routes to a receiver `empty` with no integration
  and lists no contact point, so nothing tries to deliver and nothing is
  logged for it; with SMTP off, a contact point a player adds in the UI
  could not deliver either. Firing alerts are read in the alerting view.
- **`pending` and reloads outside the wrapper**: a reload a player
  triggers through Grafana's API (they are administrators) is not
  recorded, so `pending` stays red until `sudo gm-reload-grafana` or a
  restart; touching a file without changing it also counts as a change.
- **Errors in a refused reload** are only in Grafana's log, which players
  do not see; the wrapper says which kind failed (`Internal Server Error`
  for alert rules that do not parse).
- **Dashboard files Grafana skips** (valid JSON it cannot load) are only
  reported when they carry a `uid`.
- **Host key per container**: generated at each container start; players
  see a changed host key on the inner hop if the container is replaced.
- **Encryption key**: Grafana's default `secret_key` (it encrypts data
  source secrets in the database; the reference data source has none).
- **Image size**: 866MB, about twice master spec 12's estimate (see
  "Footprint").
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
