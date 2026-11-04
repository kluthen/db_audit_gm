# api brick — GM notes

GM documentation of the `api` brick (`brick.yaml`). Never shipped to
players.

## Purpose

- **What it is**: an HTTP API node, FastAPI 0.162.0 on uvicorn 0.54.0,
  Python 3.13 (Debian 13), psycopg 3.3.7 on Debian's libpq, image
  `127.0.0.1:5000/dbagm/api:0.1.0`. The GM drops endpoint files into the
  node and the brick serves them; the image is generic and holds no
  scenario content (v0.5 master spec 7.2, "The `api` brick").
- **Role**: `api` (spec D349).
- **It only answers.** A node in the players' scope never acts on its own
  and has no timer: producers and consumers on scheduler nodes call it.
  The one exception is the partners' node, whose endpoints may read, call
  and write when the partners' back end ticks them (master spec 10.2).
- **When the GM picks it**: for every API a scenario's customer runs
  (`clinic-api`, `lab-api`, `portal-api` in the clinic) and for the
  partners' node serving every third party under its own hostname.
- **Packages**: the hash-pinned PyPI set of `requirements.txt`, fifteen
  wheels, exactly as security-advisor cleared it (G6,
  `specs/versions/v0.5/wave-log.md`): plain `uvicorn` (no `[standard]`),
  plain `psycopg` (never `[binary]`), no python-multipart (JSON only);
  installed with `pip install --require-hashes --only-binary=:all:
  --no-deps` in a throwaway build stage, so no pip reaches the node; plus
  Debian's `libpq5` and `python3-yaml` (api.yaml, safe loading only;
  cleared by security-advisor for this brick, 2026-11-03).

## Placement

- One node per API of the scenario; the partners' node is one more, with
  `no-access` and the partners' hostnames as network aliases (render's,
  chunk 7). Next to nothing in particular: it reaches its databases and
  the APIs it calls by name.
- Build: `docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api`
  (x86_64: the s6-overlay archive and pydantic-core's wheel). The build
  asserts G6's pins (each package at exactly its pin, nothing else in
  `dist-packages`), psycopg's pure-Python implementation over libpq 17 or
  later, Python 3.13, and no pip in the node (`build/check-image.py`, the
  Dockerfile's last checks).
- Stateful: its volumes hold the endpoint files (the players' edits to
  `db/`) and the request log. One network, the game's.

## Configuration

### Seed files

| Seed file | Lands at | What it must contain |
|---|---|---|
| `api.yaml` | `/srv/api/api.yaml`, root 0644 | `endpoints`: name (`[a-z][a-z0-9_]*`, a partner's prefixed) -> `hosts` (non-empty, the hostnames it answers under: on a node in the players' scope its own name only; on the partners' node a third party's hostname, or `owners`) and optional `credentials` (absent: public). `connections` (optional): `schedule.yaml`'s two forms, `sql/postgresql` (`target: <node>:<port>/<db>`, `role`, `pool: {size: N}` or `{per-call: true}`) and `http` (`target: <host>:<port>`, optional `credential`, `pool: N`, optional `timeout: <n>s`, 1 to 60, default 10 s). The template: the format skill's `templates/api.yaml` |
| `routes/<name>.py` | `/srv/api/routes/`, root 0644 | one per endpoint: defines `router`, a FastAPI `APIRouter`, at top level; imports FastAPI, Pydantic, the standard library and `db/` modules only; routes are plain `def` |
| `db/<name>.py` | `/srv/api/db/`, `api:apiconf`, 0664 fixable or 0644 | one per endpoint: the functions the route calls; imports psycopg, the standard library and `gm_api` only |

Each endpoint is the two files of its name; a file of `routes/` or `db/`
no endpoint names is never imported. Everything is seeded once (marker
`/var/lib/gm-state/.gm-seeded`); later starts keep the players' `db/`.

### What a `db/` file may use (`gm_api`)

- `gm_api.connection("<name>", session=None)`: a context manager giving
  a pooled psycopg connection of an `sql/postgresql` connection, as its
  role, autocommit off, `application_name` the node's hostname, no
  server-side prepared statements (any PgBouncer pool mode works), TCP
  keepalives (300 s idle), a 10 s connect timeout. On leaving, whatever
  is uncommitted is rolled back and the session returns to the pool, so a
  transaction-local setting (`SELECT set_config('portal.owner_id', %s,
  true)`, `portal-api`'s row-level security) never outlives its request.
  `pool: {size: N}` is N sessions for the whole server; a request waits
  for a free one at most 30 s, then answers 503. A session found broken
  (the database restarted) fails its request with 503 and is replaced at
  the next.
- **Session-level settings, the players' lever**: `session=` a mapping of
  setting -> value, applied with `set_config(..., false)` and committed
  before the session is handed over whenever the session's last applied
  mapping differs; a setting it no longer names is `RESET`. A `SET` the
  endpoint runs itself stays with the pooled session.
- `SECURITY DEFINER` functions are called as any function; nothing more
  is asked of the brick.
- `gm_api.client("<name>")`: an `http` connection's client, the wire form
  of the scheduler's (capture W1 items 3 and 4): `Authorization: Bearer
  <secret>` when the connection has a credential, `Host:` the target as
  written, `User-Agent:` the node's hostname; `get(path, params=None, *,
  headers=None)`, `post(path, body=None, *, headers=None)` (a body
  JSON-serialisable, or bytes sent as they are); an answer (`status`,
  `headers`, `text`, `json()`) whatever its status; a timeout or a
  refused connection raises `gm_api.HttpError` (`.status` `timeout` or
  `refused`). `pool: N` kept-alive connections; one stale keep-alive
  connection is retried once.
- Passwords and credentials are the brick's to read; endpoint code never
  opens a secret (it could: it runs as `api`; accepted on the trust line,
  access model 8).

### Secrets

| Secret | Path | Notes |
|---|---|---|
| `player_ssh_pubkey` (key-pair, public half) | `/opt/gm/secrets/player_ssh_pubkey`, 0444 | SSH as player; required unless `no-access` |
| `role_<role>_password` (derived, one per role `api.yaml`'s connections name) | `/opt/gm/secrets/role_<role>_password`, 0:0 0400 | render derives them from `api.yaml` (spec D345, chunk 3's `localimpl.connection_roles`) |
| `http_<credential>` (derived, one per credential an endpoint accepts or a connection sends) | `/opt/gm/secrets/http_<credential>`, 0:0 0400 | capture W1 items 0 and 3; render mounts them (chunk 7) |

The entrypoint checks each (single line, no space) and copies it, at
every start, to `/run/gm-api/secrets/<name>`, `api` 0400 (W1 item 0):
`/run` is never in the snapshot. A credential or role password
`api.yaml` needs and that is not mounted stops the server, naming the
secret, never its value.

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run`; writes the account files `/etc/passwd`, `group`,
   `shadow`, `gshadow` and the player's sudo rules link to
   (`/run/gm-accounts`), without `player` on a `no-access` node (as
   `postgres` 0.5.0 does).
2. Generates the sshd host key.
3. Checks and copies the secrets; checks `api.yaml`'s seed.
4. Checks `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES` (only `/srv/api/db`
   or `/home/player`; none on `no-access`) and writes
   `/run/gm/write-policy`.
5. Seeds `/srv/api` once.
6. Applies the write policy's owners and modes (below).
7. Log, marker and home owners and modes; then s6 starts `api` and `sshd`.

The `api` service first waits, bounded (30 s), until every host
`api.yaml`'s connections name resolves (`getent ahosts`), printing the
wait and its outcome to the container's log (`api: waiting up to 30s for
connection hosts to resolve: db`, then `... resolve after Ns`, or `still
unresolved ..., starting anyway`); v0.4's lesson (spec D305). Swarm puts a
health-checked task in its service's DNS only once the task is healthy, so
on a first deployment a fresh `postgres` node (initdb included) usually
resolves after the bound: the server starts anyway and its endpoints
answer 503 until the database is there (the stack test saw both). psycopg
resolves at every connect, so nothing keeps a stale address. It then runs
`python3 -I -m uvicorn --factory gm_api.app:create_app --host 0.0.0.0
--port 8000` as `api`: one process; the routes, plain `def`, run in
AnyIO's worker threads (40), so a slow endpoint never holds the others;
keep-alive 60 s. The application imports and checks every endpoint pair
first (the checks of `gm-reload-api`); on a problem the server exits 3,
writes a `fatal` line to the request log, and s6 tries again 4 s later.

## Connections

- **Provides** `http` on port 8000, plain HTTP/1.1, no TLS (capture W1
  item 5): every endpoint, by hostname. The request's `Host` without its
  port picks the endpoints listing that hostname (case-insensitive); an
  unknown hostname answers 404 (the node's own name too, unless an
  endpoint lists it); two endpoints of one hostname declaring one method
  and path (parameter names aside) are refused at start and on reload.
  The route a request matches names its endpoint; a missing or wrong
  `Authorization: Bearer <secret>` for an endpoint with credentials
  answers 401 (`WWW-Authenticate: Bearer`) before anything else runs,
  body parsing included. FastAPI's `/docs`, `/redoc` and `/openapi.json`
  are off. A database out of reach (psycopg's `OperationalError`) or a
  pool with no free session answers 503; any other exception 500.
- **Provides** `ssh` on port 22: `player` from the bastion (no account on
  `no-access`).
- **Consumes** what `api.yaml`'s connections name: a `postgres` node
  (5432) or a `pgbouncer` node (6432) as an application role, never a
  superuser; another API (port 8000) with an HTTP credential. Nothing has
  to exist first: the start-up waits for the names, bounded, and a
  database that is not there yet answers 503 until it is.
- **Mounted material**: the image accepts the `prometheus` brick's
  node-health script (`receives`: s6-overlay 3.2.3.2 and the commands
  `sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid`). Its
  node-health map entry is `default`, the brick's `processes`: `api` and
  `sshd`.

## Access

- **Players**: SSH from the bastion as `player`, group `apiconf`; `sudo`
  for exactly `gm-reload-api` and `gm-validate`, no arguments. They read
  `api.yaml`, `routes/`, `db/` and the request log.
- **Write policy, per directory** (master spec 7.2): `api.yaml` and
  `routes/` are root-owned and protected on every node: the contract is
  never the players' (access model 5). `db/` is the one writable path:
  `api:apiconf`, 2775 and files 0664 when fixable (policy `fixable`, or
  `report-only` with the override `/srv/api/db`), 2755 and 0644
  otherwise. Editing a protected file is an ordinary "permission denied".
  Every start and every `gm-reload-api` restores those owners and modes,
  never through a link (a link, a file with other hard links or a
  non-regular file is left alone and named).
- **`gm-reload-api`**: restores the owners and modes; refuses on a node
  where `db/` is not fixable (`gm-reload-api: this node is report-only:
  db/ cannot be changed, so nothing was restarted.`); runs the checks as
  `api` (`python3 -I -m gm_api check`); on the first problem prints
  `gm-reload-api: the endpoints do not load; the server was NOT restarted
  and keeps the files it loaded:` and the problem, by file and line, and
  exits 1; else restarts the server through s6, waits (60 s, beyond the
  start-up wait) for it to
  load and answer, and prints `gm-reload-api: restarted the server with
  api.yaml, routes/ and db/ as they are: ...`. A restart drops the
  requests in flight; a caller sees a refused connection for a second or
  two.
- **The checks** (`gm_api.check`, the brick's build checks on the `db/`
  side, master spec 7.2): both files of every endpoint, regular files; a
  route imports FastAPI, Pydantic, the standard library and `db/` modules
  only, a `db/` file psycopg, the standard library and `gm_api` only (no
  relative import); both import, the route defines `router`, its routes
  plain `def` (an `async def` route is refused); every name a
  route takes from a `db/` module is defined there (a `db/` side that
  drops or renames a function the route calls is refused, not found at
  the first request); `gm_api.connection("<name>")` and
  `gm_api.client("<name>")` with a literal name name an `sql/postgresql`
  or an `http` connection of `api.yaml`; no method and path twice on a
  hostname.
- **`no-access`** (master spec 10.2): no `player` account, no `player`
  group, no membership of `apiconf`, no sudo rules; `sshd` still runs (no
  account can log in) and the GM's `docker exec -u api` works; `/home/player`
  is root 0700. Overrides are refused there.
- **Capabilities** added back: `AUDIT_WRITE`, `CHOWN`, `DAC_OVERRIDE`,
  `FOWNER`, `KILL`, `NET_BIND_SERVICE`, `SETGID`, `SETUID`, `SYS_CHROOT`,
  for the reasons `brick.yaml` gives.
- **The GM** uses `docker exec` (root, or `-u api`), the request log as
  evidence (the partners' stubs' log especially: access model 7), and the
  validator (`/opt/gm/validator/validate.sh`, as `api`).

## Footprint

- `brick.yaml`: limits 0.25 CPU and 128M, reservations 0.1 CPU, 96M and
  64M of disk (master spec 7.2's starting figures: 0.1 CPU and 96M; 128M
  for the partners' node serving nine hostnames).
- **At rest, first figures** (the stack test, 2026-11-03, after 30 s
  without a request; four runs agreed within 5M):

  | Node | Hostnames, endpoints | Memory (cgroup) | Server RSS | CPU |
  |---|---|---|---|---|
  | `lab-api` | one, one endpoint and a connection | 47M of 128M | 53M | 0.2% |
  | `partners` (`no-access`) | nine, nine endpoints, two connections | 43M of 128M | 55M | 0.2% |

  Both well within master spec 7.2's starting figures (96M; 128M for nine
  hostnames): a hostname and its endpoint pair add about 1M to the server.
  The disk at rest: 24K to 88K of endpoint files, a few kilobytes of log.
- What makes it grow: the endpoints imported (each pair a few hundred
  kilobytes), the pooled sessions' buffers, the request log on disk.
  `disk_growth_per_hour` 2M is provisional: about 170 bytes a request,
  some 3 requests a second; a game's measured rates set it.
- Levers: fewer endpoints per node, smaller pools.

### Snapshot

Every volume but `/run` by `copy` (`brick.yaml`): `endpoints` (seeded
files, the players' `db/`), `apilog` (append-only), `home`, `gmstate`.
Restored by copying back; the server reads the files at start.

## Supported faults

None yet: no catalog fault's `applies_to` names `api` 0.1.0. v0.5's test
selection plants no fault on the `db/` side (master spec 7.2: it is
covered by the brick's own build checks). What a scenario plants around
an API (in its data, its routes or a partner's misbehaviour keys) comes
with the domains' and purposes' chunks, not with this brick.

## Checks

- **Validator** (`sudo gm-validate`; the GM runs
  `/opt/gm/validator/validate.sh` as `api`): `config` (the endpoints load
  and pass the checks), `server` (it answers on port 8000), `pending` (no
  file changed since the server loaded them, `/run/gm-api/loaded`).
  `GREEN: ...` exit 0, `RED <rule>: ...` exit 1, `ERROR: ...` exit 2.
- **Health check**: healthy once the server has answered on :8000 once
  in this container, while `sshd` is up; never asks a database; after the
  first answer it sends no more requests, so the request log holds only
  the callers'.
- **After deployment**: the node healthy; `docker exec <node> cat
  /run/gm-api/loaded` lists each hostname's endpoints; one call per
  endpoint with its credential answers, and without it 401; the request
  log shows them.
- **Unit tests**: `sh bricks/api/tests/run-unit-tests.sh` (the `unit-test`
  stage, with a throwaway PostgreSQL).
- **Stack test**: `sh bricks/api/tests/run-stack-test.sh` (about 8
  minutes; needs `postgres` 0.5.0's image): both nodes started before
  their database, waiting and then answering; dispatch by hostname over
  nine aliases, 401s, the application role, the transaction-local
  setting, `SECURITY DEFINER`, a partner calling back; the player's `db/`
  edit and reload, the refusals; report-only and its override;
  `no-access`; the node-health script; the entrypoint's refusals; the
  footprint at rest.

## Known limits

- One server process: a CPU-bound endpoint holds the others' share of the
  node's 0.25 CPU; the threads keep slow I/O apart.
- A reload restarts the server: requests in flight are dropped.
- The request log is never rotated within a game.
- The import rules are read from the files' `import` statements; code
  importing dynamically (`importlib`) is not caught, and a `db/` file can
  read the server's secrets (it runs as `api`): the trust line.
- After a database restart each pooled session fails one request (503)
  before it is replaced.
- No TLS, no HTTP/2, no websockets, no form or multipart bodies.
