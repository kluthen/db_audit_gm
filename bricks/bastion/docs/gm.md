# Bastion brick — GM notes

Operating notes and internals of the `bastion` brick (`brick.yaml`,
master spec 9.2 and 14). Never shipped to players. Initial version
(v0.1), expected to evolve as games are played.

## Image

- Debian 13 (`debian:13-slim`), `openssh-server` and `openssh-client`
  (OpenSSH 10.0), PostgreSQL 18 client tools from the PGDG repository
  (`trixie-pgdg`, `postgresql-client-18`), `openssl` (password hashing),
  `nano`, `vim-tiny`, `less`, `procps`. No `sudo`.
- s6-overlay 3.2.3.2 (x86_64), same archives and SHA-256 as the PostgreSQL
  brick.
- Build: `docker build -t 127.0.0.1:5000/dbagm/bastion:0.1.0 bricks/bastion`.
  Deploy with `docker stack deploy --resolve-image never`.
- Generic: no scenario content, no host key, no password in the image.

## Fixed paths (capture W1-C)

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

Container port 22. The stack publishes it, default 2222 (scenario
`published_ports: [{port: 22, default: 2222}]`); the local implementation
records the port actually used. The scenario maps the starter pack with
`seed_files: {README.md: player/README.md, story.md: player/story.md,
issues.md: player/issues.md}` (capture W1-D).

`dba_password` is the same Swarm secret as the database node's.
`player_ssh_key` is the private half of the database node's
`player_ssh_pubkey`: an unencrypted OpenSSH private key (ed25519).

## Start-up (`gm-entrypoint`, every container start)

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

### Why `/etc/shadow` is a symlink

The root filesystem is read-only, and the password is per game. sshd runs
without PAM (as on the database node) and reads `/etc/shadow` itself, so
the image replaces it with a symlink to `/run/gm/shadow`, which the
entrypoint writes. `passwd` cannot change the password: the players keep
the one the GM handed over for the whole game.

## SSH server

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

## Inner hop and host keys (capture W1-E)

The database node's sshd host key is created anew whenever its container
is replaced. A remembered key would then make `ssh db` refuse to connect
("REMOTE HOST IDENTIFICATION HAS CHANGED") until the player removes the
entry, which is a dead end for a student.

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

## Validator

`gm-validate` (players) or, for the official result,
`docker exec -u player <container> /opt/gm/validator/validate.sh` (GM,
through the exec operation). Run as anyone but `player` it prints
`ERROR: ...` and exits 2. It checks the bastion's own invariants only:

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
`.pgpass`.

## Health check

Healthy while `sshd` is up under s6 and listening on port 22. The check
reads `/proc/net/tcp`, so it leaves nothing in sshd's log.

## Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, checked by dropping each
one in turn (Docker 29.8.2): without `CHOWN`, `DAC_OVERRIDE` or `FOWNER`
the entrypoint fails; without `SETGID`, `SETUID` or `SYS_CHROOT` password
logins fail; without `KILL` a container stop with a player logged in
waits out Docker's grace period and ends in `SIGKILL` (exit 137).
`NET_BIND_SERVICE` is not needed under Docker, which sets
`net.ipv4.ip_unprivileged_port_start=0`, but sshd binds port 22, so it
stays for other platforms. `AUDIT_WRITE` is not needed: there is no
`sudo` and no PAM.

## Known limits (v0.1)

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

## Stack test

`sh bricks/bastion/tests/run-stack-test.sh` deploys the bastion and a
PostgreSQL node (chunk 2's image and its test fixtures) as a two-service
stack (`tests/stack.test.yml`), logs in with the password on the published
port (`GMTEST_BASTION_PORT`, default 22222), checks the inner hop by key
and `psql`, replaces each node in turn, and removes everything it created,
volumes, configs and secrets included. Needs a swarm manager, both images
built, and an OpenSSH client 8.4 or later on the host (`SSH_ASKPASS_REQUIRE`).
