# Bastion brick — GM notes

GM documentation of the `bastion` brick (`brick.yaml`, master spec 9.2
and 14; required sections: spec D56). Never shipped to players. Brick
version 0.6.0, expected to evolve as games are played.

## Purpose

An SSH bastion on Debian 13 (trixie): OpenSSH 10.0 with the PostgreSQL 18
client tools alongside, in the image
`127.0.0.1:5000/dbagm/bastion:0.6.0`. It fills the role `bastion`: the
players' only way into the game. They log in with a per-game password,
find the starter pack in their home, and reach the in-game nodes from
there by SSH and `psql`. Its **web front**, on a second port behind the
per-game tools password, runs in every game (D224): its home is a
read-only page of the starter pack, and it publishes the topology's
monitoring web interfaces (Prometheus, Grafana) to the players' browsers
when there are any (master spec 7.6; v0.4 master spec 7.3). The GM picks
it for every scenario; nothing on it is part of the game.

The image:

- Debian 13 (`debian:13-slim`), `openssh-server` and `openssh-client`
  (OpenSSH 10.0), PostgreSQL 18 client tools from the PGDG repository
  (`trixie-pgdg`, `postgresql-client-18`), `openssl` (password hashing),
  `nano`, `vim-tiny`, `less`, `procps`. No `sudo`.
- nginx 1.26.3 from Debian's own repository (package `nginx`), the web
  front. Its packaged site, logs and state directories are removed; its
  configuration is written at start-up.
- `cmark-gfm` 0.29.0.gfm.13 from Debian (package `cmark-gfm`, unpinned,
  with `libcmark-gfm0.29.0.gfm.13` and
  `libcmark-gfm-extensions0.29.0.gfm.13`; gate G13), which renders the
  starter pack into the front's page at start-up (D222). The build
  asserts it runs, renders a table with `-e table`, and omits raw HTML.
- `curl` 8.14.1 from Debian (package `curl`, unpinned, installed with
  `--no-install-recommends`; `libcurl4t64` and its libraries with it;
  gate G11.2, accepted by the owner on 2026-11-10 with trixie's unfixed
  curl issues until 2027-02-01 or the next trixie curl security upload),
  the players' HTTP client (access model 4): they call the partners'
  endpoints with the credentials `partners.md` hands over. The build
  asserts `curl --version` runs.
- s6-overlay 3.2.3.2 (x86_64), same archives and SHA-256 as the PostgreSQL
  brick.
- Generic: no scenario content, no host key, no password in the image.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion`.
- **How many**: one per scenario (master spec: the players reach the
  system through a single bastion).
- **Next to which node**: on the manager. Its SSH port and the web
  front's port are published in host mode, never
  through the routing mesh, on the host that runs it, so the players
  connect to that host's address. On a playground of several hosts (master
  spec 7.5 and 10.2, D180) `gmctl fit` places it through the mapping of
  its designed host and `gmctl render` pins it there (`node.hostname ==
  <host>` in the stack file), so its ports open on that host only, never
  on another host's addresses; the routing mesh would have opened them on
  every host, a VPS's public address included. That host must be the
  manager: `gmctl fit` refuses a mapping that places the bastion, or any
  node publishing ports, on another host, and names the `--map` to change.
  The image is unchanged.
- **Across hosts, as tried** (chunk 10b's two-host try, 2026-10-26,
  armenelos plus the VPS; master spec 20): the swarm is bound to the
  hosts' Tailscale addresses (`--advertise-addr`, `--listen-addr` and
  `--data-path-addr` on `tailscale0`); the game's overlay and the
  swarm's ingress carry the MTU option 1230, which Docker reads as the
  outer MTU, so 1180 inside a node, within Tailscale's 1280 (D184); the
  bastion's ports 2222 and 8080 opened on its own host only. `gmctl
  deploy` copies each image a host lacks with `docker save <image> |
  docker --context dbagm-<host> load`, through that host's SSH Docker
  context, never pulled (D181), and skips one held under the same id.
- **Stateful**: yes (`stateful: true`): the player's home (`~/report.md`,
  notes) and the sshd host key. Its volumes `home` and `hostkeys` must
  follow the node if it is replaced; `run` is emptied at each start.
- **Networks**: it must share a network with every node the players reach
  (see "Connections"). Each network a scenario declares renders as
  `<game_id>_<network name>`; v0.2 scenarios declare one network, and the
  scripts refuse a second (master spec 6.3), so it shares it with every
  node.

## Configuration

`brick.yaml` declares one parameter, `web_routes`, and no knobs (`knobs:
[]`): otherwise the scenario's content is the starter pack, and the rest
is per-game secrets.

### The routes parameter `web_routes`

`shape: web-routes`, `default: {}`, `required: false` (capture W1, items 2
and 3). A map from route name to `"<node>:<port>"`, one route per web
interface of the topology, the route name being the upstream's own
`web_path` without its slashes. On the bastion's node in `scenario.yaml`:

```yaml
parameters:
  web_routes: {prometheus: "prometheus:9090", grafana: "grafana:3000"}
published_ports: [{port: 22, default: 2222}, {port: 8080, default: 8080}]
```

- The container gets it as `GM_WEB_ROUTES`: `name=node:port` tokens
  sorted by name, separated by spaces (`grafana=grafana:3000
  prometheus=prometheus:9090`).
- Route `<name>` is served at `/<name>/` on the front, and the path is
  forwarded unchanged: the upstream serves under `/<name>/` itself (its
  brick's `web_path`, through Prometheus' or Grafana's sub-path setting).
- Routes or none, the scenario publishes the front's port, `{port: 8080,
  default: 8080}`, beside SSH's: the front runs in every game (D224), and
  the loader refuses a bastion without it.
- Empty or absent (the default): the front serves the starter-pack page
  alone, with no web-interface section or link; the tools password is
  read and handed over all the same. v0.3's rule (no route, no front, no
  second port, no tools password; D103) no longer holds.
- The loader checks that each route's node exists and provides a web
  interface on that port with `web_path: /<name>/`, and that every web
  interface of the topology has exactly one route. The entrypoint checks
  the tokens again and fails the container on a malformed one.
- **Cold storage's console** (v0.5, master spec 7.3, spec D363; capture
  W4 item 1): the one route to a third party, as a provider's console the
  customer logs into. Its target is cold storage's hostname, the one its
  `coldstore_manifests` endpoint answers under on the partners' api node,
  on port 8000: `web_routes: {cold-storage: "cold-storage:8000"}`. Render
  passes it as `cold-storage=cold-storage:8000:console`; the front proxies
  only `GET /cold-storage/` (to `/`, the vault's page) and `GET
  /cold-storage/manifests` (to `/manifests`, its query string kept), with
  `Host: cold-storage`; any other path under it, and any other method
  (`POST /cold-storage/shipments`, the upload), answers 404. The loader
  refuses every other third party's node or hostname in `web_routes`.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Starter pack `README.md`, `story.md`, `issues.md` (`seed.files`) | `/opt/gm/starter/`, root `0444`, copied once into `/home/player`, rendered into the page at each start | the scenario's `seed_files`: `{README.md: player/README.md, story.md: player/story.md, issues.md: player/issues.md}` (capture W1-D) |
| Starter pack `data-policy.md` (`seed.files`, `seed.optional`) | `/opt/gm/starter/data-policy.md`, likewise, when mapped | a scenario with `governance:` maps it to its policy file, `data-policy.md: player/data-policy.md` (v0.4 master spec 11.5); one without maps none, and the bastion copies and shows none (v0.4 capture W1 item 4) |
| Starter pack `partners.md` (`seed.files`, `seed.optional`; v0.5) | `/opt/gm/starter/partners.md`, likewise, when mapped, each `{{credential:<name>}}` replaced in the home's copy and on the page | a scenario with partners maps it, `partners.md: player/partners.md` (master spec 6.2, 7.3) |
| Starter pack `data-register.md` (`seed.files`, `seed.optional`; v0.5) | `/opt/gm/starter/data-register.md`, likewise, when mapped | a scenario with `governance.register` maps it to the register handout, `data-register.md: player/data-register.md` (master spec 13.2), unless a planted fault leaves the register out |
| Secret `http_<name>` (kind `password`, handed over; v0.5) | `/opt/gm/secrets/http_<name>`, root `0400`; read at every start into `partners.md` | render, one per name a `third_parties:` entry lists under `credentials:` (the customer's own credential with that partner; spec D365, D433), the same secret as the partner's endpoint checks; `gmctl status` lists it as "password, handed over" |
| Secret `player_password` (kind `password`, handed over) | `/opt/gm/secrets/player_password`, root `0400` | `gmctl deploy`; the GM hands it to the players |
| Secret `player_ssh_key` (kind `key-pair`, pair `player_ssh_key`, half `private`) | `/opt/gm/secrets/player_ssh_key`, root `0400` | `gmctl deploy`: an ed25519 key pair whose public half is the database node's `player_ssh_pubkey` |
| Secret `dba_password` (kind `password`, not handed over) | `/opt/gm/secrets/dba_password`, root `0400` | `gmctl deploy`: the same secret as the database node's |
| Secret `tools_password` (kind `password`, handed over) | `/opt/gm/secrets/tools_password`, root `0400`; read at every start | `gmctl deploy`, whenever `bastion` 0.6.0 is in the topology; the GM hands it to the players in every game, with the bastion password (D224). The same secret as Grafana's administrator password |
| Routes `web_routes` | `GM_WEB_ROUTES`, turned into `/run/web-front/nginx.conf` and the page's links at start-up | the scenario's node `parameters` (above) |
| Published ports | the host's ports for container ports 22 and 8080 | the scenario's `published_ports: [{port: 22, default: 2222}, {port: 8080, default: 8080}]`, routes or none |

`dba_password` is the same Swarm secret as the database node's.
`player_ssh_key` is the private half of the database node's
`player_ssh_pubkey`: an unencrypted OpenSSH private key (ed25519).
`player_password`, `dba_password` and `tools_password` are single lines.

### Fixed paths (capture W1-C)

| What | Path | Notes |
|---|---|---|
| Starter pack | `/opt/gm/starter/` | configs `README.md`, `story.md`, `issues.md` and, when mapped, `data-policy.md`, `partners.md`, `data-register.md`, `network-overview.md`, read-only |
| Resolved starter files | `/run/gm/starter/partners.md` | root, `0700` dir: `partners.md` with its credentials written in, the source of the home's copy and of `/docs/partners` |
| Brick pages | `/opt/gm/docs/bricks/<brick-id>.md` | v0.6: configs `<game_id>_bastion_doc-<brick-id>`, each brick's `docs/player.md`, one per brick of a node the players may reach, written by `gmctl fit` (capture W2 item 1); root, `0444` |
| Player home | `/home/player` | volume `home`; `player`, `0751` (v0.6: the front's account passes through to `~/reports/` alone) |
| Reports folder | `/home/player/reports/` | v0.6: `player`, `0755`, made by the entrypoint when missing (a link or a file in its place is replaced); served at `/reports/` |
| Starter marker | `/home/player/.gm-starter-copied` | root, `0444` |
| Inner-hop key | `/home/player/.ssh/id_ed25519` | `player`, `0600`, rewritten at each start |
| `.pgpass` | `/home/player/.pgpass` | `*:*:*:dba:<password>`, `player`, `0600`, rewritten at each start |
| Secrets | `/opt/gm/secrets/player_password`, `player_ssh_key`, `dba_password`, `tools_password` | root, `0400` |
| sshd host key | `/var/lib/gm-sshd-keys/ssh_host_ed25519_key` | volume `hostkeys`, root, `0700` dir |
| Password file | `/etc/shadow` → `/run/gm/shadow` | rebuilt at each start (see below) |
| Runtime | `/run` | volume `run`, emptied at each start |
| Validator | `/opt/gm/validator/validate.sh` | `/usr/local/bin/gm-validate` links to it |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| SSH client settings | `/etc/ssh/ssh_config.d/gm-game.conf` | see "Inner hop and host keys" |
| Web front directory | `/run/web-front/` | root:www-data, `0750`, rewritten at each start, routes or none; `tmp/` (www-data, `0700`) holds nginx's pid and temporary files |
| Web front configuration | `/run/web-front/nginx.conf` | root, `0444` |
| Web front password file | `/run/web-front/htpasswd` | `player:<SHA-512 crypt>`, root:www-data, `0440` |
| Web front's own answers | `/run/web-front/www/` | root:www-data, `0750`: `index.html` (the home at `/`, see "Web front" under "Access"), `docs/<id>.html` and `docs/bricks/<brick-id>.html` (the documentation site) and `not-found.txt` (the 404 body), `0440`; `routes/<name>/`, one empty directory per route (and `routes/reports/`), from which nginx answers `/<name>` with the redirect to `/<name>/` |
| Page renderers | `/usr/local/lib/gm/pages.sh`, `/usr/local/lib/gm/html-ids`, `/usr/local/lib/gm/render-status` | v0.6: the page functions (`md_page`: `cmark-gfm -e table`, then `html-ids`), sourced by the entrypoint and `render-status`; `html-ids` gives each heading its GitHub id, points links between starter files to `/docs/` and, with the status map, links each partner's status page under its heading; `render-status` writes the partners' status pages |
| Partners' status file | `/opt/gm/secrets/partners_status.json` | v0.6: secret `<game_id>_partners_status`, kind `rendered`, written by `gmctl render` (and a restart's re-render) into `local/<playground>/secrets/partners_status.json`, mounted only when a third party has a player document; root, `0400`: it holds incidents still to come (capture W2 item 1) |
| Status pages | `/run/web-front/www/status/<id>/index.html` | v0.6: root:www-data, `0750` folders, `0440` pages, rewritten every minute by the s6 service `status-pages` (root), each through a temporary file moved into place |
| Web front service | `/etc/s6-overlay/s6-rc.d/web-front/run` | nginx as `www-data` |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/sshd`, `/run/gm` (root, `0700`) and
   `/run/tmp` (`/tmp` and `/var/tmp` link to it). `/run` is the named
   volume `run`, for the reason given in the PostgreSQL brick's
   [GM notes](../../postgres/docs/gm.md#why-run-is-a-volume) (capture
   W1-E).
2. Creates the ed25519 sshd host key in the `hostkeys` volume if it is not
   there yet.
3. Fails the container if a secret is missing or empty, if
   `player_password` or `dba_password` is not a single line, or if
   `player_ssh_key` does not load as an unencrypted private key. When
   the scenario maps `partners.md`, writes `/run/gm/starter/partners.md`,
   each `{{credential:<name>}}` replaced by the secret
   `/opt/gm/secrets/http_<name>`, failing the container on a name that is
   not a credential's or has no secret (v0.5, spec D365, D433).
4. Builds `/run/gm/shadow` (root:shadow, `0640`): the image's own copy
   (`/usr/local/lib/gm/shadow.base`) with `player`'s hash
   (`openssl passwd -6`, SHA-512 crypt) of the per-game password.
5. Fails the container if a required starter pack file (`README.md`,
   `story.md`, `issues.md`) is missing. If `~/.gm-starter-copied` is
   absent, copies the starter pack into `/home/player` (`player`,
   `0644`; `partners.md` from its resolved copy), skipping any file
   already there and an optional file (`data-policy.md`, `partners.md`,
   `data-register.md`) the scenario provides none of, then writes the
   marker.
6. Writes `~/.ssh/id_ed25519` (final newline added back; OpenSSH refuses a
   key without it) and `~/.pgpass` (`:` and `\` escaped). Whatever the
   player left at those paths is removed first, so a symlink cannot point
   root's write elsewhere.
7. Reads `GM_WEB_ROUTES`, failing the container on a token that is not
   `name=node:port` or, cold storage's console, `name=host:port:console`
   (lowercase names, as the loader checks them) or on a
   route given twice. Then, routes or none (D224): reads
   `tools_password` (same rules as the other passwords); writes
   `/run/web-front/htpasswd` (user `player`, `openssl passwd -6` hash),
   `/run/web-front/www/` (the front's own answers, served as static files
   so that they come after the password check: the page, rendered from
   `/opt/gm/starter/`, and the 404 body) and `/run/web-front/nginx.conf`
   (the page at `/`, one `location /<name>/` per route, see "Web front"
   under "Access"); fails the container if `cmark-gfm` cannot render a
   starter file or nginx (`nginx -t`, as `www-data`) refuses the
   configuration.
8. Execs s6-overlay's `/init`, which supervises `sshd` and `web-front`.
   The `web-front` service, keyed on `/run/web-front/nginx.conf`, finds it
   at every start; without it (a start that wrote none) it would mark
   itself once-only (`s6-svc -O`) and exit.

Seeded once: the starter pack (on a fresh `home` volume) and the sshd host
key (on a fresh `hostkeys` volume). Rewritten at each start: `/run`, the
password file, `~/.ssh/id_ed25519`, `~/.pgpass`, and the web front's
configuration, password file and page.

### Why `/etc/shadow` is a symlink

The root filesystem is read-only, and the password is per game. sshd runs
without PAM (as on the database node) and reads `/etc/shadow` itself, so
the image replaces it with a symlink to `/run/gm/shadow`, which the
entrypoint writes. `passwd` cannot change the password: the players keep
the one the GM handed over for the whole game.

## Connections

The bastion provides two interfaces and consumes four, of three kinds
(`interfaces` in `brick.yaml`): `ssh` on port 22, `sql` on port 5432, and
`ui` twice, on ports 9090 and 3000.

- **Provides `ssh`, SSH protocol, port 22**: the players, from outside
  the game. The scenario's `published_ports: [{port: 22, default: 2222}]`
  (`extra.published_port_default: 2222`) publishes it on the host that
  runs the bastion, and the local implementation records the port
  actually used. The players log in as `player` with the per-game
  password (see "Access").
- **Provides `web-front`, HTTP, port 8080**, in every game (D224): the
  players' browsers, from outside the game. The scenario publishes
  `{port: 8080, default: 8080}` (`extra.web_front_port_default: 8080`)
  beside SSH's, in host mode like it; these two are the only ports a game
  publishes. Without routes it serves the starter-pack page alone.
- **Consumes `ssh`, SSH protocol, port 22**, on the in-game nodes, by node
  name: the inner hop, `ssh <node>` as `player`, with the key
  `~/.ssh/id_ed25519` written from the secret `player_ssh_key`. The other
  side is every node whose brick provides `ssh` (in v0.2, every node but
  the bastion: `postgres`, `prometheus`, `postgres-exporter` and
  `grafana` all provide it), which must carry the matching public key
  (`player_ssh_pubkey`) and share a network with the bastion. `gmctl deploy` generates the pair;
  no brick parameter supplies it.
- **Consumes `sql`, PostgreSQL protocol, port 5432**, on the database
  nodes, by node name: `psql -h <node>` as the role `dba`, with the
  password from `~/.pgpass`, written from the secret `dba_password` (the
  same secret as the database node's, generated by `gmctl deploy`). sshd
  sets `PGUSER=dba` and `PGDATABASE=postgres` for SSH sessions, so `psql
  -h <node>` needs no other option. Before the wiring works: the database
  node's seed files listen on port 5432 and let `dba` in from the game's
  network (PostgreSQL brick, [GM notes](../../postgres/docs/gm.md#what-the-seed-files-must-contain)).

- **Consumes `ui`, HTTP, ports 9090 and 3000**, on the nodes the routes
  name, by node name: the topology's web interfaces (`prometheus` on
  port 9090, `grafana` on port 3000), each declaring `web_path:
  /<route>/` and serving under that path itself. The front resolves the node name through Docker's DNS at
  request time, so an upstream that is down answers 502 until it is back,
  and never stops the front or the bastion.

**Monitoring**: `brick.yaml` declares no monitoring exposure, and the
bastion has no metrics endpoint. The sshd log and the web front's errors
(a wrong password, an unreachable upstream) go to the container's output
only (`gmctl logs`); the front keeps no access log.

**Mounted material**: the image accepts another brick's mounted companion
material (`brick.yaml` `receives`): it runs s6-overlay `3.2.3.2`, and the
commands `sh`, `cat`, `du`, `df`, `awk`, `sed`, `grep`, `sleep`, `perl`,
`s6-svstat` and `s6-setuidgid` are on an s6 service's PATH. A brick whose
mounted material requires no more than that (such as `prometheus`'s
node-health script) can be mounted into this node; the cost of that
material is stated by the brick that ships it, not here.

### Inner hop and host keys

Capture W1-E. The database node's sshd host key is created anew whenever
its container is replaced. A remembered key would then make `ssh db`
refuse to connect ("REMOTE HOST IDENTIFICATION HAS CHANGED") until the
player removes the entry, which is a dead end for a student.

**Chosen approach: no strict checking, for in-game node names only.**
`/etc/ssh/ssh_config.d/gm-game.conf` (root-owned, read-only) applies to
host names without a dot (`Host * !*.*`): `StrictHostKeyChecking no`,
`UserKnownHostsFile /dev/null`, `LogLevel ERROR`. Nothing is remembered,
so a node replacement never locks the player out, and no "permanently
added" warning shows. Peers are reached by node name only (master spec
7), and node names have no dot. Addresses and domain names keep OpenSSH's
default checks.

The same block sets `ServerAliveInterval 60`: the inner hop goes through
the node's Swarm service address (IPVS), which forgets a TCP flow idle
for about 900 s, so an `ssh <node>` session left idle longer would hang.

The alternative, `accept-new` with a known_hosts the entrypoint resets,
was not taken: it only resets when the *bastion* restarts, so a database
node replaced mid-game would still lock the players out.

What it costs: no protection against a man-in-the-middle on the game's own
overlay network, which only the game's containers are on. A player may
override it in `~/.ssh/config`; nothing in the game depends on it.

## Access

### SSH server

- Password login as `player` only (`AllowUsers player`); public keys,
  keyboard-interactive and root are refused.
- `PerSourcePenalties no`: players often share one source address (a
  classroom NAT, or Swarm's routing mesh), and OpenSSH's default
  per-source penalties would lock all of them out after a few mistyped
  passwords. The password is random and per game, and a game lasts at most
  4 hours.
- No forwarding of any kind (TCP, agent, X11, tunnels): players work on
  the bastion, and the database node's ports stay inside the game's
  network. `sftp` and `scp` are allowed, so players can copy
  `~/report.md` or notes to and from their machines.
- `SetEnv PGUSER=dba PGDATABASE=postgres` for SSH sessions, so
  `psql -h <node>` needs no other option.
- The host key survives a container replacement (volume `hostkeys`), so
  the players' own SSH clients do not see it change.

### Account, paths and write policy

- `player`, group `player`, no `sudo` and no wrappers (`sudo_wrappers:
  []`; master spec 9.2). The players run the validator as `gm-validate`.
- Writable: `/home/player` (`~/report.md`, notes; `~/.ssh/id_ed25519`
  and `~/.pgpass` are rewritten at each start), and the scratch space
  `/tmp` and `/var/tmp`, both links to `/run/tmp` (root, `1777`, emptied
  at each start, see "Start-up").
- Protected (root-owned, read-only): `/etc/ssh/sshd_config`,
  `/etc/ssh/ssh_config.d/gm-game.conf`, the entrypoint, the health check,
  `/usr/local/lib/gm/shadow.base`, the validator, and the s6-overlay
  service definitions (`/etc/s6-overlay/s6-rc.d`,
  `/etc/s6-overlay/user-bundles.d`).
- Write policy: `report-only`. Nothing on the bastion is part of the game:
  players write only their home and the scratch space.
- The web front's files under `/run/web-front/` are root-owned; `player`
  cannot read the password file.

### Web front

Master spec 7.6; access model 5 ("Bastion and web front"), 6 and 7.

- **Where**: `http://<host>:<port>/`, the home, and
  `http://<host>:<port>/<route>/`, `<port>` being the port the local
  implementation recorded for container port 8080 (default 8080),
  `<route>` a key of `web_routes`. With the v0.2 monitoring bricks:
  `/prometheus/` and `/grafana/`. `/<route>` redirects to `/<route>/`.
  The front's own (v0.6, master spec 7.1 to 7.5; capture W2 item 2):
  `/docs/<id>`, `/docs/bricks/<brick-id>`, `/reports/` (and, with
  partners, `/status/<id>/`); a route named `docs`, `reports` or
  `status` is refused (by the loader, and by the entrypoint). Any other
  path answers 404.
- **The home** (`/`, v0.6 master spec 7.2): one HTML page (`text/html`,
  UTF-8), a header naming the customer (the first `# ` heading of the
  handed-over `story.md`), then two lists: **Sites** (`<section
  id="sites">`: one link `/<route>/` per route of `GM_WEB_ROUTES`, then
  **Reports**, `/reports/`, always) and **Documents** (`<section
  id="documents">`: one link `/docs/<id>` per starter file present, in
  this order: `readme`, `story`, `issues`, `data-policy`, `partners`,
  `data-register`, `network-overview`; then **Tools**, one link
  `/docs/bricks/<brick-id>` per brick page delivered, by its first
  heading, by brick id). An absent element leaves nothing: no link, no
  page.
- **The documentation site** (`/docs/`, master spec 7.3): each page
  rendered at each start from the starter pack as handed over (the
  mounted `/opt/gm/starter/`, `partners.md` with its credentials written
  in, never the players' home copies) and from the brick pages
  (`/opt/gm/docs/bricks/`), by `cmark-gfm -e table` (GitHub tables; raw
  HTML replaced by a `raw HTML omitted` comment, `cmark-gfm`'s safe
  default, never `--unsafe`), then `html-ids`: every heading gets an id
  by GitHub's rule (so `partners.md#<anchor>` resolves), and a link to
  a starter file (`partners.md#x`) points to its page (`/docs/partners#x`).
  Each page links home. nginx: `location /docs/`, `try_files $uri.html
  =404`.
- **The partners' status pages** (`/status/<id>/`, master spec 7.6;
  capture W2 items 1 and 2): one per third party with a player document,
  written every minute by the s6 service `status-pages` (root, running
  `render-status`, then sleeping 60 s) from the status file, which only
  root reads: the partner's name, "Operational" or "Incident ongoing"
  (an admitted incident started and not ended), each admitted incident
  whose start has passed, newest first, its title, text, start and, once
  passed, end, in UTC; an incident not yet started is absent. Linked from
  the home's Sites by the partner's name and from the partner's section
  of `/docs/partners` ("Status page", under the heading whose id is the
  `player_doc`'s anchor). Without the status file `status-pages` asks s6
  not to restart it (down, as `web-front` without its configuration) and
  no `/status/` page exists. A live page, not a handout: the
  static-snapshot rule does not apply. Never a route to a third party's
  node. In a fake game the instants fall where the virtual timeline puts
  them (`render.t0_instant` reads `timeline.virtual_t0`, chunk 9).
- **Reports** (`/reports/`, master spec 7.5): `~/reports/` served
  read-only (GET and HEAD) as nginx's directory listing, with
  `Content-Security-Policy: sandbox allow-scripts` on every answer, the
  files' types from `/etc/nginx/mime.types`; `disable_symlinks on`, so a
  link a player makes there is never followed; anything outside the
  folder, a missing file or another method: 404. The front never reaches
  into a database node: the players bring a report in one hop, `scp
  <node>:pgbadger.html ~/reports/`.
- **Authentication**: HTTP basic, user `player`, password the per-game
  `tools_password`, on every path, `/` included. Without it, or with a
  wrong user or password: `401` with `WWW-Authenticate: Basic
  realm="db_audit_gm web front"`, so the browser asks for it. Plain HTTP
  (access model, "Known gaps").
- **Cold storage's console** (v0.5): `GET /cold-storage/` and `GET
  /cold-storage/manifests` only, forwarded to `/` and `/manifests` with
  `Host: cold-storage` and the query kept; any other path or method under
  it 404 (see "The routes parameter `web_routes`").
- **What it forwards**: the request's method, path and query unchanged;
  `Host` as the browser sent it (`<host>:<port>`, which Grafana compares
  with `Origin`); `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto:
  http`; WebSocket upgrades (Grafana Live). It removes the `Authorization`
  header, so Grafana never sees the front's credentials and keeps its own
  login, and hides an upstream's `WWW-Authenticate` header, which would
  make the browser drop the front's credentials.
- **Errors**: an upstream that is down or not yet started answers `502`;
  the other routes keep working.
- **Without routes** (no web interface in the topology): the front runs
  all the same, on the published port 8080, behind the tools password,
  and serves its own pages alone, with no route on the home; the
  GM hands over the tools password in every game (D224; v0.3's D103 no
  longer holds).
- **Process**: nginx (master and one worker) as `www-data` under s6
  (`web-front`); 256 connections at most; request bodies up to 16M
  (Grafana dashboard imports).

### Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, checked by dropping each
one in turn (Docker 29.8.2): without `CHOWN`, `DAC_OVERRIDE` or `FOWNER`
the entrypoint fails; without `SETGID`, `SETUID` or `SYS_CHROOT` password
logins fail; without `KILL` a container stop with a player logged in
waits out Docker's grace period and ends in `SIGKILL` (exit 137).
`NET_BIND_SERVICE` is not needed under Docker, which sets
`net.ipv4.ip_unprivileged_port_start=0`, but sshd binds port 22, so it
stays for other platforms. `AUDIT_WRITE` is not needed: there is no
`sudo` and no PAM. The web front needs none of its own: it listens on an
unprivileged port, and `s6-setuidgid www-data` uses `SETUID` and
`SETGID`, already in the list.

### What the GM uses

`gmctl exec --node <bastion> --user player` (or `--user root`): the
official validator run, and fetching the players' `~/report.md`
(`printf '%s\n' 'cat ~/report.md' | tools/gmctl exec <dir> --playground
<pg> --node <bastion> --user player`). `gmctl logs --node <bastion>`
shows the sshd log.

## Footprint

Default footprint in `brick.yaml`, in the shape of a scenario node's
`resources`: limits CPU `0.5` and memory `256M`; reservations CPU `0.25`,
memory `128M` and disk `256M` (v0.1's single figures became the
reservations, the limits twice the CPU and memory). No allowed range. It
excludes any material other bricks mount into the node: what that adds
per node is stated by the brick that ships it, and the GM adds it to the
node's `resources` in the scenario. The scenario sets the node's own
`resources` (limits for CPU and memory, reservations for CPU, memory and
disk), and `gmctl` uses those, never the brick's footprint. The renderer
applies the CPU and memory limits and reservations; disk is only counted
by the capacity check (`gmctl fit`: reservations plus 10 % headroom
against the playground); the volumes themselves have no size limit.
Disk growth per hour (`disk_growth_per_hour`): `1M`, for the players'
notes and reports; the v0.3 rehearsal, with no player, measured none
(below).

What makes it grow: the number of players logged in at once (an sshd
process, a shell and a `psql` or `ssh` client each), and what they keep
or copy into their home (`scp`, `sftp`, query output saved to files). The
starter pack, the key and `.pgpass` are a few kilobytes. Size the memory
limit from the expected number of simultaneous sessions, and the disk
reservation from what the players may save. The levers that shrink it:
fewer simultaneous sessions (players sharing a session), and a smaller
limit for a single-player game.

The web front fits within these figures, which v0.2 leaves unchanged:
measured in the stack test (Docker 29.9.1, idle, 2026-10-21), the
bastion's container uses about 5 MiB of memory with the front and 2.8 MiB
without; nginx's master and worker show about 13 MiB resident, most of it
shared libraries. What makes the front grow: the players' browsers
(Grafana dashboards issue several requests per panel and refresh), each
proxied response buffered in memory or, above nginx's buffers, under
`/run/web-front/tmp/` (the `run` volume). CPU: a password check (SHA-512
crypt) per request, a few milliseconds each.

At rest since v0.4, the front running in every game: measured in the
stack test (armenelos, Docker 29.9.1, idle, 2026-10-30), the bastion's
container uses 5.1 MiB of memory with routes and 4.9 MiB without, serving
the page alone, where v0.3's bastion without routes, with no nginx, used
2.8 MiB; nginx's master and worker show 12.8 MiB resident with routes and
12.1 MiB without. The page is a few kilobytes under `/run/web-front/www/`
(the `run` volume). `cmark-gfm` runs only at start-up, a few milliseconds
per starter file, and holds nothing after; with its two libraries it adds
about 860 KiB to the image (`dpkg`'s installed sizes: 370, 380 and 108
KiB). The figures in `brick.yaml` are unchanged.

At rest in v0.6 (chunk 6: the home, the documentation site, the reports
folder, `jq` and `tmux`): measured in the stack test (armenelos, Docker
29.9.3, idle, 2026-11-17), the bastion's container uses 5.5 MiB of memory
with routes and 5.0 MiB without; nginx's master and worker show 13.2 MiB
resident with routes and 12.3 MiB without: as v0.4 and v0.5. The pages
are rendered once at start-up and hold nothing after: a few kilobytes
each under `/run/web-front/www/` (the `run` volume), one per starter file
and brick page. `jq` and `tmux` run only when a player starts them; with
their four libraries they add 3.6 MiB to the image (`dpkg`'s installed
sizes: `jq` 125, `libjq1` 439, `libonig5` 677, `tmux` 1209,
`libevent-core-2.1-7t64` 306, `libjemalloc2` 876 KiB; the image 199 MB,
from 195). What grows: `~/reports/`, the reports the players bring there
(a pgBadger report is a few megabytes, pgCluu's folder a few more), on
the `home` volume; covered by `disk_growth_per_hour`. The figures in
`brick.yaml` are unchanged.

Measured in the v0.2 game (`fernway-clinics-monitoring` on the `laptop`
playground, declared at 2 CPU / 4G / 8G on armenelos: AMD Ryzen 5 PRO
8640HS, 11.3 GiB, Docker 29.9.1; 2026-10-21; `docker stats`, the highest
of its samples, the node-health script included), with that scenario's
own `resources` (limits 0.5 CPU / 256M, reservation 96M): at rest 11 to
15 minutes after the deployment 10M and 0.06 CPU; during dashboard loads
(three browsers at a time through the web front, both dashboards, every
panel's query, about 500 requests in 14 s) 18M and 0.20 CPU; during a
pgBadger run on `db` 11M; at rest again after them 18M. Never OOM-killed
nor restarted, never at its limit (`memory.peak`, page cache included,
22M). Its volumes: about 40K.

Measured in the v0.3 rehearsal (`tools/tests/rehearsal.sh`:
`tarnbeck-outdoor-shop` on armenelos, AMD Ryzen 5 PRO 8640HS, 11.3 GiB,
Debian 13, Docker 29.9.1, plus the VPS `vps-5718ad52`, 4 vCPU Intel
Haswell, 7.6 GiB, Docker 29.9.2; 2026-10-28; 46 minutes of load from T0
12:59Z to the hand-over check, the customer's noon peak from 13:00Z;
`docker stats` every 20 s, the node-health script included), with
`tarnbeck-outdoor-shop`'s `resources` (limits 0.5 CPU / 256M, reservation
96M), no player logged in: 11M at most, 0.03 CPU at most; its volumes did
not grow.

### Snapshot

How each volume is copied at hand-over (`snapshot:` in `brick.yaml`):

- `home`, `hostkeys`: `copy`, a tar of the volume while the node runs.
- `run` (`/run`) is never copied.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59): a fault instance is accepted on a node when the fault's
`applies_to` names the node's brick and version (`tools/gm/model.py`).
This list is every catalog fault (`faults/`) whose `applies_to` names
`bastion` `0.6.0`, and no other.

Nothing on the bastion is part of the game (master spec 9.2), its write
policy is `report-only`, and a fault in its configuration would cut the
players off from the system they audit: none is written. The one kind it
hosts, from v0.5, is a **register fault** (master spec 6.4, 13.4): a
change to the starter pack's data register, the optional seed file
`data-register.md`, planted in the handout only. The `data-register`
skill writes the scenario's `player/data-register.md` with the change
applied and the answer key's `register_diff:`; the bastion copies and
shows it as any seed file, and nothing else on it, or in the system,
changes. Its fault id is `governance-register-*` (family `security`),
its resolution *propose*, judged at the final answer against
`register_diff:`; its sealed check reads only that the change is present
in the served handout.

| Fault | Kind | What it needs from the brick |
|---|---|---|
| `governance-register-flow-undeclared` | seed file (`data-register.md`) | the optional seed file `data-register.md` mapped to the scenario's `governance.register` (a scenario with a data register), copied into `/home/player` and shown on the page's "Data register" section; parameter `recipient` (default `Cold Storage`), the processor the handout names nowhere (dropped from every entry's recipients and, for cold storage, its copies); the sealed check reads `/home/player/data-register.md` as root with `awk` |

Faults it lends itself to with no definition yet: the other register
traps (an entry out of date, a column or a store missing, a wrong class,
a wrong retention, the register absent, the register vague; the
`data-register` skill's table), each a change to `data-register.md`; and,
for the same reasons as above, none in the bastion's own configuration.

Known interactions: the bastion is where the players gather the evidence
of faults elsewhere, so what it sets up shapes what they see. Its
`~/.pgpass` supplies the `dba` password on every connection, which hides
a `trust` line on a database node (`pg-hba-trust-remote`) in ordinary
use; that fault's evidence connects with `PGPASSFILE=/nonexistent`.

## Checks

### Validator

`gm-validate` (players) or, for the official result,
`docker exec -u player <container> /opt/gm/validator/validate.sh` (GM,
through the exec operation: `gmctl validate`). Run as anyone but `player`
it prints `ERROR: ...` and exits 2. It checks the bastion's own invariants
only:

- `sshd` runs and listens on port 22;
- `/etc/ssh/sshd_config` is root-owned, not writable by others, and still
  has `AllowUsers player` and `PasswordAuthentication yes`;
- `/home/player` is a directory owned by `player`, and a file can be
  created in it (a full disk shows here);
- `~/.ssh/id_ed25519` is a regular file, `player`, `0600`, and loads as a
  key (`ssh` refuses a key readable by others);
- `~/.pgpass` is a regular file, `player`, `0600` (`psql` ignores it
  otherwise), with a line for `dba`.

Output: `GREEN: ...` and exit 0, or one `RED <rule>: ...` line per broken
rule and exit 1 (capture W1-E). Everything it flags is fixed by the player
in their home, or by a container restart, which rewrites the key and
`.pgpass`. It is green from the start: the bastion carries no planted
finding.

### Health check

Healthy while `sshd` is up under s6 and listening on port 22, and, when
the web front is configured (`/run/web-front/nginx.conf` exists, which
the entrypoint writes at every start, routes or none), while `web-front`
is up and listening on port 8080. The check reads `/proc/net/tcp`, so it
leaves nothing in any log. It
does not reach the upstreams: a monitoring node that is down shows on its
own node, not here.

### Companion checks

None: the brick ships no `companion/` material.

### After deployment

`gmctl deploy` returns once the node is healthy (sshd listening), and
`gmctl validate` shows its validator. To confirm the wiring to a database
node `<db>`, run the inner hop and `psql` from the bastion as `player`
(sshd's `SetEnv` does not apply to an exec, hence `-U` and `-d`):

```sh
printf '%s\n' "ssh -o BatchMode=yes <db> true && psql -h <db> -U dba -d postgres -XAtc 'select 1'" \
  | tools/gmctl exec <dir> --playground <pg> --node <bastion> --user player
```

Exit 0 and `1` printed: the key, the host-key settings, the `dba`
password and the database node's `pg_hba.conf` all work. Then log in once
from outside on the published port with the player password, as the
players will.

Check the web front from outside, in every game, as the players'
browsers will (`<web port>` is the port recorded for container port 8080; read the
tools password from `local/<pg>/secrets/tools_password` and hand it to
`curl -K -` on its standard input through `printf`, a shell builtin; never
pass it to `gmctl exec --env` nor on a command line):

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://<host>:<web port>/      # 401
printf 'user = "player:%s"\n' "$(cat local/<pg>/secrets/tools_password)" | curl -s -K - http://<host>:<web port>/   # the page
```

The page holds a section per starter file the scenario provides and, with
routes, their links. Then open each `/<route>/` with the password: a
`502` means the upstream is not up (yet), or does not serve under
`/<route>/`.

### Stack test

`sh bricks/bastion/tests/run-stack-test.sh` deploys the bastion, a
PostgreSQL node (the `postgres` image and its test fixtures) and a stub web
interface (`tests/fixtures/stub-upstream.pl`, a Perl script in
`debian:13-slim` that answers with the request it received) as a
three-service stack (`tests/stack.test.yml`, stack `gmtest-bastion`),
with the starter pack of `tests/fixtures/starter/` (a README with a table
and a `<script>`, a data policy, partners, a data register and a network
overview) and two brick pages (this brick's and the `postgres` brick's
`docs/player.md`, as `gmctl fit` delivers them). It
logs in with the password on the published SSH port (`GMTEST_BASTION_PORT`,
default 22222), checks the four starter files in the home and the inner
hop by key and `psql`, replaces each node in turn (the player having
edited `~/story.md`), then checks the web front on its published port
(`GMTEST_BASTION_WEB_PORT`, default 28080), with the routes `stub=stub:9090`
and `other=stub:9091` (nothing listens there): 401 and the challenge
without the tools password, with a wrong one or another user name; the
stub reached under `/stub/` with the path and query unchanged, no
`Authorization` header upstream, `Host` and `X-Forwarded-Proto` set, the
stub's own challenge hidden; the home (the customer named, Sites, then
Documents and Tools, its links only to the routes, Reports, the seven
documents and the two brick pages, each answering 200 and 401 without the
password); the documentation site (the README's table as an HTML table,
raw HTML omitted, the player's edits absent, GitHub heading ids, links
between starter files pointing to `/docs/`, 404 for a brick not
delivered); `jq` (on the stub's answer in Prometheus' API form, through
`curl`) and `tmux` as `player`; a pgBadger report made on `db`, copied
into `~/reports/` in one hop, listed and served with the sandbox header,
and nothing outside the folder (a link, `..`, a POST: 404); the redirect, 404, 502 on
`/other/`; nginx as `www-data`; the health check failing while the front
is stopped. Then it empties the routes (port 8080 and `tools_password`
kept): the front up, 401 without the password, the page alone, no
web-interface section or link, the health check green, the data policy
copied again; then removes the data policy, the partners, the register
and the overview and sets two routes (master spec 12.1): the home lists
the two routes, Reports and the three documents, no dead link; then
removes `issues.md`: the container refused. The
validator is green in every state that starts. It removes everything it created, volumes, configs and secrets
included. Needs a swarm manager, the bastion and postgres images built,
`debian:13-slim`, `curl`, and an OpenSSH client 8.4 or later on the host
(`SSH_ASKPASS_REQUIRE`).

## Known limits

- **Starter pack copied once.** A changed starter pack in a running game
  reaches the home only on a fresh `home` volume. Deleting the marker
  (the player owns the home) re-copies only the files that are missing.
- **The page is the starter pack as handed over**, rendered at each
  container start: it never shows the players' edits, so their
  `~/README.md` may differ from it. GitHub tables only: no other GitHub
  extension (strikethrough, autolinks, task lists) is on.
- **Key and `.pgpass` rewritten** at each container start from the
  secrets; a player's edits to them do not survive a restart.
- **Single-line passwords.** A secret holding a newline fails the
  container.
- **sshd log** only in the container output (`gmctl logs`), as the web
  front's errors; the front keeps no access log.
- **Plain HTTP** on the web front: the tools password crosses the network
  base64-encoded (access model, "Known gaps").
- **One user name**, `player`, for the web front; a browser that offers
  another is refused like a wrong password.
- **Routes fixed at start-up.** The front reads `GM_WEB_ROUTES` when the
  container starts; a changed `web_routes` needs a new render and deploy.
- **The front publishes, it does not protect.** Prometheus has no login of
  its own and stays reachable from every node of the game without the
  tools password (access model, "Known gaps").
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
