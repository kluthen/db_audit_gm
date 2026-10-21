# Planes, access and rules

Status: draft v11

Who may reach what, what the player may change, how the rules are checked,
and what is left to trust. At consolidation this document feeds the access
model companion of the master spec.

## Bastion only

The player only ever accesses the system through a bastion. They must not
interact with the swarm itself; doing so defeats the purpose of the game.
Access to a Swarm manager's API is effectively root on every host, so the
player side never gets a Docker socket or manager credentials.

The bastion is itself a node of the topology (a Swarm service). In v0.1 it
shares one overlay network with the database node, and its SSH port is the
only port published (D35). v0.2 keeps one network and adds the web front's
port (D77, D83); the network layout of later versions is O12.

Credentials: see "Credentials and the way in" below.

**The bastion publishes the web interfaces** (D68): the monitoring UIs
(Grafana, Prometheus) are reached through the bastion, and no other node
publishes a port. Ports published through the routing mesh are open on
every host, so a UI port published by its own node would bypass the
bastion. It publishes them through a web front (D77): a reverse proxy on
the bastion's second published port, in host mode, every UI behind it
under its own path, with HTTP basic authentication on the per-game tools
password (D79), since Prometheus has no login of its own; plain HTTP in
v0.2. Files and reports still leave through `scp` and `sftp`. From v0.6
the bastion becomes the players' main activity point: web interfaces, a
documentation website, general-use tooling (D71).

## Planes (D42)

| Plane | Who | Has access to |
|---|---|---|
| Infrastructure | The GM, in its agent session | Swarm managers or host access given at setup, Docker API, stack files, images, the scenario folder including the answer key |
| Scenario | The scenario folder and its local implementation | Topology, host topology and resources, fault instances, issues, aging plan, answer key |
| Player | Student(s) | Bastion, SSH to nodes with restricted rights, monitoring UIs published by the bastion (D68) |

The teacher acts only at setup, through the GM session (D6).

## The GM session

The player also talks to the GM: they hand in their report there, and
anyone in the session may ask the GM to stop the game (D6). The GM session
is therefore a door from the player side into the infrastructure plane, and
the GM holds the answer key. Two rules close that door (D13), stated in
[gm-stance.md](gm-stance.md), "During the game": the GM reveals no answers
before the final answer, and on the players' request it takes no action
other than stopping the game.

## Trust

Enforcement is deliberately light (D13). The repository holds failure
scenarios in bulk, so students may find answers in it, just as answers
exist on the internet, in textbooks and in lessons. Players are expected to
dig into the live scenario and may draw on any side material; if they read
the repository, that's life. The only safeguard on a scenario is a
prominent warning that students and players should not read it (see
[formats.md](formats.md)).

How much of the rest can be enforced depends on where the game runs (D7):

- **One machine operated for the players** (e.g. a teacher's laptop): the
  players only get the bastion, and the rules below hold as written.
- **A student playing alone at home**: the student owns the hosts, the GM
  session and the repository. Everything rests on trust.
- **A classroom swarm of student laptops**: every student owns one host and
  can reach its Docker engine, the containers running there, and whatever
  configs and secrets are mounted into them. The bastion-only rule is
  trust-only on those hosts. The delivery design keeps spoilers off the
  hosts as far as it can ([platform.md](platform.md), D11), but nothing
  more is attempted.

Some tampering cannot be prevented in practice. Those cases are at least
documented, in place and in the player documentation (`DO NOT TAMPER WITH
THIS`, with the reason). Players are trusted not to break the game.

## Player access to nodes

The player has legal access to every node of the topology, but not
necessarily write access everywhere: on some nodes (e.g. producers and
consumers) they can only observe and report findings.

Each node has a **write policy** (D42):

- *fixable* — configuration changes are expected;
- *report-only* — read access, findings go in the report;
- *no access* — e.g. the game's own infrastructure.

Access is limited: the default configuration (SSH etc.) gives access to the
information needed but does not allow the system's behaviour to be altered
beyond what is acceptable. Changing a database's configuration files is
expected; changing SSH behaviour is not.

### The monitoring nodes (v0.2)

- Prometheus, Grafana and `postgres_exporter` are full nodes: the player
  reaches each by SSH as `player` from the bastion, reads everything, and
  on a *fixable* node edits its seed-once configuration and reloads it
  through a `sudo` wrapper (D74).
- Grafana's write policy is a known gap (D94): the tools password makes
  the players Grafana administrators, so on a *report-only* Grafana node
  they can still change dashboards, data sources and alert rules through
  the UI. Accepted under light enforcement, like the superuser gap on
  report-only databases (O45). Sealed checks judge Grafana's effective
  live state (through its API), not only its provisioned files.
- The node-health script and its service list are configs, read-only on
  every node (D73); its endpoint is readable from every node.

### Credentials and the way in (D31)

- The players log in to the bastion with a per-game password the GM hands
  over. The bastion's SSH port is the only port published, and from v0.2
  its web front's port (D77).
- From v0.2, a second per-game password, the **tools password**, opens
  the web front and Grafana's administrator account; the GM hands it over
  with the bastion password (D79). A topology with no web interface has
  no web front: the bastion publishes SSH only and no tools password is
  handed over (D103).
- From the bastion they reach other nodes as user `player`, with a per-game
  key pair: the private key sits in the player's home on the bastion, the
  public key in the node's authorized keys. Both halves travel as Swarm
  secrets.
- Nothing about credentials is committed: they live only in the game's
  secrets and in the git-ignored local implementation (D45). From v0.2
  gmctl generates the secrets the bricks declare, by kind (password, key
  pair), among them the password of the exporter's monitoring role (D79).

### The database node (D34)

- The player has an SSH account `player` on the node, and a PostgreSQL
  superuser role `dba`. Superuser is realistic for a DBA audit and fits the
  light enforcement of D13. It also gives operating-system access as the
  `postgres` user (for example through `COPY ... TO PROGRAM`); that is
  accepted. Protected files and validators are root-owned and read-only,
  so it cannot alter them.
- `postgresql.conf` and `pg_hba.conf` live outside PGDATA (e.g.
  `/etc/postgresql/`, through `config_file` and `hba_file`), owned by
  `postgres` with a group `player` belongs to, group-writable on a fixable
  node.
- Reload and restart go through `sudo` wrappers.
- From v0.2 the PostgreSQL log files are readable by the players' group,
  so players run pgBadger themselves, as `player`, with no wrapper; its
  report lands in their home (D95).
- `ALTER SYSTEM` is a legitimate fix path too. Sealed checks judge the
  effective live setting, not which file changed.
- A superuser can run `ALTER SYSTEM` whatever the node's write policy, so
  "no configuration changes" cannot be enforced on a report-only database
  node. Irrelevant in v0.1 (its database node is fixable): O45.

### Node hardening

Every item is decided; what `docker stack deploy` honours is in
[platform.md](platform.md), "Constraints and pitfalls".

- Read-only root filesystem (`read_only`, honoured); writable volumes only
  where changes are legitimate (database configuration and data, a
  crontab, backup tool configuration). "What may change = what is
  writable." A read-only root also needs a writable `/run` and a writable
  target for `sudo`'s log (D41): `/run` is a named volume the entrypoint
  empties at each start, since a stack file's tmpfs is `noexec` and
  s6-overlay must execute from it (D55). A brick's own state, such as the
  seeding marker, sits on a root-owned volume of its own, never in a
  directory the player can write (D54).
- A non-root player account.
- **Capabilities**: drop all, add back per brick what it needs, listed in
  `brick.yaml` (D41). `sshd`, s6 and the entrypoint's `chown` need more
  than `SETUID` and `SETGID`.
- **Limited `sudo`** (D25): a few wrappers (e.g. `gm-reload-db`,
  `gm-restart-db`, `gm-validate`). `sudoers` lists only those wrappers, by
  absolute path, with no arguments or a fixed set; no `ALL`, no shell,
  editor or interpreter. `env_reset` and a fixed `secure_path` stay on.
  Wrappers run as the service account where that is enough. Because of
  `sudo`, `no-new-privileges` is not set on such nodes; in v0.1 it is not
  set at all (D41).
- **Supervisor**: s6-overlay runs the service and `sshd`, with
  `S6_READ_ONLY_ROOT` and `/run` on that named volume (D30, D55).
  Settings that need a restart (e.g. PostgreSQL `shared_buffers`) would
  otherwise kill the container, since Swarm has no pods or sidecars.
- **Protected files** (`sshd_config`, `sudoers`, wrappers, validators, the
  game's own scripts) are root-owned and mounted read-only (image files on
  the read-only root, or Swarm configs, D11). Hash-checking files that are
  already read-only is deferred (D35).
- **Secrets** reach nodes through Swarm secrets or generated
  `.pgpass`-style files, never as a connection string with an embedded
  password.

Later versions (not v0.1): nodes without `sudo` wrappers keep
`no-new-privileges` where the platform can set it (on Swarm only through
the API, Engine 25.0+; on Kubernetes through `allowPrivilegeEscalation:
false`). On Kubernetes, pods with wrappers keep `allowPrivilegeEscalation`
permissive and so need the Pod Security "baseline" profile rather than
"restricted"; nodes running `sshd` likely cannot require `runAsNonRoot`
(to verify).

## Rules and validators

- Some settings cannot be altered beyond certain thresholds, so that the
  system keeps working within limited CPU and memory.
- Bounds are an envelope, not the initial value. The fix can be to raise a
  setting: the native configuration may have been set badly to begin with.
- In v0.1 the brick declares a default envelope, the scenario may tighten
  it, and the scenario fixes the absolute resource limits; nothing
  recomputes them per playground (D32).
- The initial value may lie outside the envelope. The node's validator then
  shows an error from the start; that is accepted, and the out-of-bounds
  value is a finding in itself (D10).
- Every node has a public validator, runnable by the player (on the
  database node through the `gm-validate` wrapper): values within their
  envelopes, both those in effect and those pending in the configuration
  files, and the service healthy.
- Validators are not monitoring tools. Players may run them to make sure
  they haven't broken the game, but are not expected to; they are expected
  to follow the rules, not to break them actively.
- The goal is every validator green. When a validator cannot be made green
  by the player (a report-only node out of bounds, for example), that is
  itself a known or hidden defect the player must report, and the GM takes
  it into account (D10).
- Health information is fair game: the player cannot and must not reach the
  swarm itself, but a monitoring tool or validator reporting "not healthy"
  is legitimate information. The node-health script reports each node's
  CPU, RAM, disk and services from inside the node, with no Docker socket
  or host mount, so the player side stays socket-free (D66). The GM mounts
  it into each node as configs, read-only there (D73).

**Sealed checks** are the GM's side (D33): run through the exec verb, they
check the answer key (fault fixed or not) against the effective live state.
The GM's official run of the public validators also goes through the exec
verb, so a locally modified validator does not matter.
