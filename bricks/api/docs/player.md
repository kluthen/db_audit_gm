# api node — player notes

What you may know about an api node in a db_audit_gm game. Written for
v0.5; expected to evolve.

The node runs one of the customer's web APIs: an HTTP service other
applications call (to post an order, look a record up, send a result
back). It only answers: it never calls anyone of its own accord. Each of
its endpoints is two files of the same name: the route, which is the API's
contract with its callers, and its database side, which holds the SQL,
how the work is split into transactions, and the session settings.

## Getting there

- **Shell**: from the bastion, `ssh player@<node>` (the key is already in
  your `~/.ssh`).
- **The API**: `http://<node>:8000/` from any node of the game, plain HTTP.
  A request is answered by the endpoints of the hostname it names (the
  `Host` header, as `curl` sends it from the URL). Most endpoints need a
  credential: `Authorization: Bearer <credential>`; without it, or with a
  wrong one, the answer is 401. The starter pack says which credentials
  you hold. For example, from the node itself:
  `curl -s -H "Authorization: Bearer $KEY" http://<node>:8000/orders/1`.

## What is where

| Path | Holds | You |
|---|---|---|
| `/srv/api/api.yaml` | which hostname serves which endpoint, which credentials each accepts, and the connections the endpoints use (database targets and roles) | read |
| `/srv/api/routes/<name>.py` | each endpoint's route: its paths, its request and response models, the calls into its database side. The contract | read; never edit |
| `/srv/api/db/<name>.py` | each endpoint's database side: its queries, its transactions, its session settings, the functions the route calls | read; edit when the node is fixable |
| `/var/log/api/api.log` | the request log | read |
| `/home/player` | your notes, scripts, `~/report.md` | yours |

Times in the log are UTC.

**Which files you may change** depends on the game. Only the database
side (`db/`) is ever yours to fix; the routes belong to the application
and are read-only everywhere ("permission denied"). On some api nodes
`db/` is yours to fix; on others you may only report what you find, and
`sudo gm-reload-api` says the node is report-only. Where you may, edit in
place or with `sed -i`; your changes stay when the server restarts.

## The database side

A `db/` file is Python. It imports only psycopg 3, the standard library
and `gm_api`, the node's small library:

- `with gm_api.connection("<name>") as conn:` gives a session of the
  connection `<name>` of `api.yaml`, from a pool shared by the whole
  server, as that connection's role. A transaction is open from the first
  statement (autocommit is off): call `conn.commit()` to keep the work;
  whatever is not committed when the `with` block ends is rolled back,
  and the session goes back to the pool.
- `gm_api.connection("<name>", session={"statement_timeout": "5s"})`
  sets session-level settings on the session before it is handed over,
  whenever it does not have exactly those already (a setting it had and
  you no longer name is reset). A `SET` you run yourself on a session
  stays with it after your request too.
- A setting for one request only: `SELECT set_config('<name>', %s, true)`
  inside the request's transaction; it ends with the transaction.
- `gm_api.client("<name>")` calls another API (an `http` connection of
  `api.yaml`), with `.get(path, params=...)` and `.post(path, body)`.

The route calls functions of its `db/` file by name: keep their names,
arguments and what they return as they are, or the route breaks.

## Applying changes

The server reads `api.yaml`, `routes/` and `db/` when it starts. You may
run exactly two commands with `sudo`, with no arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-api` | Checks every endpoint (both files load; the imports each may make; every function a route calls is still in its `db/` file; the connections a `db/` file names exist), then restarts the server with the files as they are. It refuses on the first problem, saying which file and line, and the running server keeps the files it had. |
| `sudo gm-validate` | Runs the public validator. |

A restart takes a second or two; a request arriving meanwhile is refused
(connection refused) and its caller may retry or count an error.

## The request log

One line per request, beginning with its UTC time:

    <time> request status=<code> ms=<latency> method=<M> host=<hostname> endpoint=<name> from=<address> agent=<caller> path=<path>

`agent` is the caller's `User-Agent`: the customer's applications send
their node's name. `endpoint=-` is a request no endpoint took (an unknown
hostname or path). A request that failed inside the endpoint adds an
`error endpoint=<name> <exception>: <message>` line before its own; 503
means a database could not be reached or every session of the pool was
busy. `start` and `stop` lines mark the server's restarts. A request
from `127.0.0.1` to a hostname ending in `.invalid` is the node checking
its own server (at start, on `gm-reload-api` and `gm-validate`).

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- `api.yaml` and every endpoint load and pass `gm-reload-api`'s checks;
- the server answers on port 8000;
- the files have not changed since the server last loaded them (if they
  have: `sudo gm-reload-api`).

Whether the queries are right, fast or wise is the audit's business, not
the validator's.

## Do not tamper

SSH, `sudo`, the `gm-*` commands, the validator, `api.yaml`, `routes/` and
the library under `/usr/local/lib/python3.13/dist-packages` are part of
the game, not of the customer's system: leave them alone. A `db/` file is
code the server runs, as the API's database role: keep to what the
customer's application would do.
