# Bastion brick — GM notes

GM documentation of the `bastion` brick (`brick.yaml`, master spec 9.2
and 14; required sections: spec D56). Never shipped to players. Brick
version 0.2.0, expected to evolve as games are played.

## Purpose

An SSH bastion on Debian 13 (trixie): OpenSSH 10.0 with the PostgreSQL 18
client tools alongside, in the image
`127.0.0.1:5000/dbagm/bastion:0.2.0`. It fills the role `bastion`: the
players' only way into the game. They log in with a per-game password,
find the starter pack in their home, and reach the in-game nodes from
there by SSH and `psql`. The GM picks it for every scenario; nothing on
it is part of the game.

The image:

- Debian 13 (`debian:13-slim`), `openssh-server` and `openssh-client`
  (OpenSSH 10.0), PostgreSQL 18 client tools from the PGDG repository
  (`trixie-pgdg`, `postgresql-client-18`), `openssl` (password hashing),
  `nano`, `vim-tiny`, `less`, `procps`. No `sudo`.
- s6-overlay 3.2.3.2 (x86_64), same archives and SHA-256 as the PostgreSQL
  brick.
- Generic: no scenario content, no host key, no password in the image.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/bastion:0.2.0 bricks/bastion`.
- **How many**: one per scenario (master spec: the players reach the
  system through a single bastion).
- **Next to which node**: any host. Its SSH port is published on the host
  that runs it, so the players connect to that host's address; in v0.1 the
  renderer runs the whole game on one host.
- **Stateful**: yes (`stateful: true`): the player's home (`~/report.md`,
  notes) and the sshd host key. Its volumes `home` and `hostkeys` must
  follow the node if it is replaced; `run` is emptied at each start.
- **Networks**: it must share a network with every node the players reach
  (see "Connections"). v0.1 renders a single network for the whole game,
  so it shares it with every node.

## Configuration

`brick.yaml` declares no parameters (`parameters: {}`) and no knobs
(`knobs: []`): the scenario's content is the starter pack, and the rest is
per-game secrets.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Starter pack `README.md`, `story.md`, `issues.md` (`seed.files`) | `/opt/gm/starter/`, root `0444`, copied once into `/home/player` | the scenario's `seed_files`: `{README.md: player/README.md, story.md: player/story.md, issues.md: player/issues.md}` (capture W1-D) |
| Secret `player_password` (kind `password`, handed over) | `/opt/gm/secrets/player_password`, root `0400` | `gmctl deploy`; the GM hands it to the players |
| Secret `player_ssh_key` (kind `key-pair`, pair `player_ssh_key`, half `private`) | `/opt/gm/secrets/player_ssh_key`, root `0400` | `gmctl deploy`: an ed25519 key pair whose public half is the database node's `player_ssh_pubkey` |
| Secret `dba_password` (kind `password`, not handed over) | `/opt/gm/secrets/dba_password`, root `0400` | `gmctl deploy`: the same secret as the database node's |
| Published port | the host's port for container port 22 | the scenario's `published_ports: [{port: 22, default: 2222}]` |

`dba_password` is the same Swarm secret as the database node's.
`player_ssh_key` is the private half of the database node's
`player_ssh_pubkey`: an unencrypted OpenSSH private key (ed25519).
`player_password` and `dba_password` are single lines.

### Fixed paths (capture W1-C)

| What | Path | Notes |
|---|---|---|
| Starter pack | `/opt/gm/starter/` | configs `README.md`, `story.md`, `issues.md`, read-only |
| Player home | `/home/player` | volume `home`; `player`, `0750` |
| Starter marker | `/home/player/.gm-starter-copied` | root, `0444` |
| Inner-hop key | `/home/player/.ssh/id_ed25519` | `player`, `0600`, rewritten at each start |
| `.pgpass` | `/home/player/.pgpass` | `*:*:*:dba:<password>`, `player`, `0600`, rewritten at each start |
| Secrets | `/opt/gm/secrets/player_password`, `player_ssh_key`, `dba_password` | root, `0400` |
| sshd host key | `/var/lib/gm-sshd-keys/ssh_host_ed25519_key` | volume `hostkeys`, root, `0700` dir |
| Password file | `/etc/shadow` → `/run/gm/shadow` | rebuilt at each start (see below) |
| Runtime | `/run` | volume `run`, emptied at each start |
| Validator | `/opt/gm/validator/validate.sh` | `/usr/local/bin/gm-validate` links to it |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| SSH client settings | `/etc/ssh/ssh_config.d/gm-game.conf` | see "Inner hop and host keys" |

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
   `player_ssh_key` does not load as an unencrypted private key.
4. Builds `/run/gm/shadow` (root:shadow, `0640`): the image's own copy
   (`/usr/local/lib/gm/shadow.base`) with `player`'s hash
   (`openssl passwd -6`, SHA-512 crypt) of the per-game password.
5. Fails the container if a starter pack file is missing. If
   `~/.gm-starter-copied` is absent, copies the starter pack into
   `/home/player` (`player`, `0644`), skipping any file already there, then
   writes the marker.
6. Writes `~/.ssh/id_ed25519` (final newline added back; OpenSSH refuses a
   key without it) and `~/.pgpass` (`:` and `\` escaped). Whatever the
   player left at those paths is removed first, so a symlink cannot point
   root's write elsewhere.
7. Execs s6-overlay's `/init`, which supervises `sshd`.

Seeded once: the starter pack (on a fresh `home` volume) and the sshd host
key (on a fresh `hostkeys` volume). Rewritten at each start: `/run`, the
password file, `~/.ssh/id_ed25519` and `~/.pgpass`.

### Why `/etc/shadow` is a symlink

The root filesystem is read-only, and the password is per game. sshd runs
without PAM (as on the database node) and reads `/etc/shadow` itself, so
the image replaces it with a symlink to `/run/gm/shadow`, which the
entrypoint writes. `passwd` cannot change the password: the players keep
the one the GM handed over for the whole game.

## Connections

The bastion provides one interface and consumes two (`interfaces` in
`brick.yaml`).

- **Provides `ssh`, SSH protocol, port 22**: the players, from outside
  the game. It is the only port a game publishes: the scenario's
  `published_ports: [{port: 22, default: 2222}]` (`extra.published_port_default:
  2222`) publishes it on the host that runs the bastion, and the local
  implementation records the port actually used. The players log in as
  `player` with the per-game password (see "Access").
- **Consumes `ssh`, SSH protocol, port 22**, on the in-game nodes, by node
  name: the inner hop, `ssh <node>` as `player`, with the key
  `~/.ssh/id_ed25519` written from the secret `player_ssh_key`. The other
  side is every node whose brick provides `ssh` (in v0.1, the database
  node), which must carry the matching public key (`player_ssh_pubkey`)
  and share a network with the bastion. `gmctl deploy` generates the pair;
  no brick parameter supplies it.
- **Consumes `sql`, PostgreSQL protocol, port 5432**, on the database
  nodes, by node name: `psql -h <node>` as the role `dba`, with the
  password from `~/.pgpass`, written from the secret `dba_password` (the
  same secret as the database node's, generated by `gmctl deploy`). sshd
  sets `PGUSER=dba` and `PGDATABASE=postgres` for SSH sessions, so `psql
  -h <node>` needs no other option. Before the wiring works: the database
  node's seed files listen on port 5432 and let `dba` in from the game's
  network (PostgreSQL brick, [GM notes](../../postgres/docs/gm.md#what-the-seed-files-must-contain)).

**Monitoring**: `brick.yaml` declares no monitoring exposure, and the
bastion has no metrics endpoint. The sshd log goes to the container's
output only (`gmctl logs`). It has no web interface to relay in v0.1.

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
- Writable: `/home/player` only (`~/report.md`, notes; `~/.ssh/id_ed25519`
  and `~/.pgpass` are rewritten at each start).
- Protected (root-owned, read-only): `/etc/ssh/sshd_config`,
  `/etc/ssh/ssh_config.d/gm-game.conf`, the entrypoint, the health check,
  `/usr/local/lib/gm/shadow.base`, the validator, and the s6-overlay
  service definitions (`/etc/s6-overlay/s6-rc.d`,
  `/etc/s6-overlay/user-bundles.d`).
- Write policy: `report-only`. Nothing on the bastion is part of the game:
  players write only their home.
- No web interface.

### Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, checked by dropping each
one in turn (Docker 29.8.2): without `CHOWN`, `DAC_OVERRIDE` or `FOWNER`
the entrypoint fails; without `SETGID`, `SETUID` or `SYS_CHROOT` password
logins fail; without `KILL` a container stop with a player logged in
waits out Docker's grace period and ends in `SIGKILL` (exit 137).
`NET_BIND_SERVICE` is not needed under Docker, which sets
`net.ipv4.ip_unprivileged_port_start=0`, but sshd binds port 22, so it
stays for other platforms. `AUDIT_WRITE` is not needed: there is no
`sudo` and no PAM.

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

What makes it grow: the number of players logged in at once (an sshd
process, a shell and a `psql` or `ssh` client each), and what they keep
or copy into their home (`scp`, `sftp`, query output saved to files). The
starter pack, the key and `.pgpass` are a few kilobytes. Size the memory
limit from the expected number of simultaneous sessions, and the disk
reservation from what the players may save. The levers that shrink it:
fewer simultaneous sessions (players sharing a session), and a smaller
limit for a single-player game.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59), and no catalog fault (`faults/`) names `bastion` there (the code
accepts a fault instance on a node only when it does:
`tools/gm/model.py`). The bastion hosts no fault, and none should be
written for it: nothing on it is part of the game (master spec 9.2), its
write policy is `report-only`, and a fault there would cut the players off
from the system they audit.

Faults it lends itself to with no definition yet: none, for the same
reason.

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

Healthy while `sshd` is up under s6 and listening on port 22. The check
reads `/proc/net/tcp`, so it leaves nothing in sshd's log.

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

### Stack test

`sh bricks/bastion/tests/run-stack-test.sh` deploys the bastion and a
PostgreSQL node (chunk 2's image and its test fixtures) as a two-service
stack (`tests/stack.test.yml`), logs in with the password on the published
port (`GMTEST_BASTION_PORT`, default 22222), checks the inner hop by key
and `psql`, replaces each node in turn, and removes everything it created,
volumes, configs and secrets included. Needs a swarm manager, both images
built, and an OpenSSH client 8.4 or later on the host (`SSH_ASKPASS_REQUIRE`).

## Known limits

- **Starter pack copied once.** A changed starter pack in a running game
  reaches the home only on a fresh `home` volume. Deleting the marker
  (the player owns the home) re-copies only the files that are missing.
- **Key and `.pgpass` rewritten** at each container start from the
  secrets; a player's edits to them do not survive a restart.
- **Single-line passwords.** A secret holding a newline fails the
  container.
- **sshd log** only in the container output (`gmctl logs`).
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
