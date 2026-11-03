# db_audit_gm v0.5 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

On 2026-11-03 the owner asked for wave 1 to start and for wave 2 to follow
it, then left the laptop to the driver until the next day ("work on the
second wave whenever the first one's done, i'll review results
tomorrow"). The driver reads that as: wave 1 runs to its gate; wave 2 is
cut from the gated `v0.5-w1` (the model's "go on before merging"), since
no merge into `main` was asked; both merges wait for the owner's word. An
owner question met meanwhile is logged with the driver's recommendation
and holds only the chunks it touches.

## Wave 1 — started 2026-11-03

Chunks 1, 2, 3, 4, 5 (κ = 3). Branch `v0.5-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.5-w1`, cut from `main` at 24f7835
(G1: `v0.5-domains` merged into `main`).

### Gates checked at the start

- G3 (network at image build time), hand check 2026-11-03: Debian's
  trixie `Release`, the PostgreSQL apt repository's `trixie-pgdg`
  `Release`, GitHub's s6-overlay and pgwatch releases, and PyPI's
  `fastapi` index answer 200. Cleared for wave 1.
- G4 (Docker host in swarm mode), hand check 2026-11-03: armenelos,
  Docker Engine 29.9.2, swarm active, leader; the VPS `vps-5718ad52`
  (29.9.2) a worker, `Ready`, `Drain`; `tailscale status` shows the VPS
  active, direct. Cleared for wave 1.
- Host resources on 2026-11-03: about 3.9G of memory available, 1.2G of
  swap in use, 9.6G free on `/`. Docker checks stay serialized under the
  host lock.

### Capture W1 — v0.5 versions, template keys and contracts (chunks 1–5; read by 2–5 and later)

Recorded 2026-11-03, before any code; drafted for the wave driver from
the capture lines of chunks 1 to 5, master spec 5, 6, 7.1, 7.2, 7.5, 8.2
to 8.5, 10.2, 10.4, 11.1, 11.2, 14, 15, 17.5 and 24, access model 4 and
5, [formats.md](../../formats.md) v28, the domain procedure 3, 9 and 10,
producer-profiles 12, `vet-portal`'s and `vet-machinery`'s producer and
purpose pages where an interface needed them, spec D264, D267, D274,
D289, D299, D303 and D322 to D343, and the code on `v0.5-w1` at 8b2224c
(`tools/gm/{model,render,localimpl,deploy,inject}.py`, the format skill's
templates, `bricks/{postgres,scheduler}/`, the scheduler program's
`drivers/`, `repository.py`, `scripts.py`, `metrics.py`, `textlog.py`).
v0.4's rules: where the spec fixes a point it is cited, not restated;
**(choice)** marks a point the sources left open, settled here with its
reason; each item names the chunk that writes it and the chunks that
read it. Chunk internals stay out; chunks record their as-built outcomes
as **W1-w** (chunk 2), **W1-x** (chunk 3, `postgres`, as in v0.3 and
v0.4), **W1-y** (chunk 4, `scheduler`, likewise) and **W1-z** (chunk 5,
`api`); chunk 1 is mechanical and records nothing.

Held, cited not restated: v0.3 W1 items 0 (key conventions, `# optional:
<when>`, `<placeholder>` map keys, durations), 3 (directory seed
entries, `only_with_role`, `seed.paths`), 5 (write policies,
`GM_WRITE_POLICY`), 6 (snapshot), 7 (the scheduler's runtime interface,
the `role_<role>_password` secrets, `password <role> <password>` on
standard input), 8 (`gm_check`); v0.4 W1 items 0 (cron subset, the `psql`
variables), 4 (`seed.optional`), 5 (a fragment holds only the entries it
adds, never `intensity` or `timeline`), 7 (the script contract), 8 (the
password file under `/run`, the crontab's baseline entry and log file).
Every key v0.5 adds is *optional* in its template, so v0.4's definitions
load unchanged (the templates are the loader's schema,
`model.template_schema`).

**0. Conventions** (read by every chunk)

- **A node's choices reach its container as `GM_*`**, as its write
  policy does: `GM_OPTIONS`, the options it chooses, space-separated,
  `""` when none; `GM_STANDBY_OF`, its primary's node name, `""` when it
  is no standby. Rendered by chunk 3, read by the `postgres` entrypoint
  and the clone step (item 6). **(choice**: the entrypoint already reads
  `GM_WRITE_POLICY` at start; no brick parameter is needed.) Chunk 6 adds
  `options` and `standby_of` to `model.RESERVED_PARAMETERS`.
- **Derived secrets** keep v0.3 W1 item 7's rule: one per name per game,
  mounted at `/opt/gm/secrets/<name>`, 0:0 `"0400"`, on each node that
  names it. v0.5 adds `http_<credential>` (item 3). A brick whose
  unprivileged process needs one copies it at every start under `/run`,
  owner-only, as `postgres` 0.4.0 writes `/run/gm-cron/pgpass`
  **(choice**: one mount rule for every derived secret; `/run` is never
  copied into the snapshot).
- **Reserved role** `replicator` (item 6): chunk 6 adds it to
  `model.RESERVED_DB_ROLES`, chunk 4 to the program's `FORBIDDEN_ROLES`.
- **Endpoint names** `[a-z][a-z0-9_]*` (a Python module's), a partner's
  prefixed `<prefix>_` (`xlab_orders`), as 8.4's prefixes **(choice**:
  `.` and `-` cannot name a module).

**1. Versions, declarations and roles** (chunk 1 writes; read by every
chunk)

- **Versions** as master spec 6.7's table; tags
  `127.0.0.1:5000/dbagm/<brick>:<version>`; `scheduler`'s
  `technology.version` `"0.3.0"`. Pins: 6.7's last paragraph and 17.5;
  `applies_to` and "Supported faults": the plan's "Read first". `api`,
  `pgwatch` and `health-check` start at 0.1.0 in their own chunks.
- **`postgres`' `options:`** as master spec 6.8 shows it, verbatim.
  **(choice)** `brings.secrets` names a secret declared under `secrets:`,
  whose entry (path, owner, mode) stays there unchanged
  (`monitoring_password`'s); render mounts a secret an option brings only
  on a node choosing that option (chunk 3), while another brick declaring
  the same name (`postgres-exporter`) mounts it as before. `brings.roles`
  is created at initdb only when `GM_OPTIONS` names the option (chunk 3).
  `docs: docs/gm.md#option-monitoring` names a level-3 heading
  "Option `monitoring`" under "Configuration" **(choice**: formats.md
  allows a brick's own sections as subsections of a required one); chunk
  1 writes the heading and one paragraph stating 7.1 items 1, 2 and 5,
  chunk 3a the rest.
- **`no-access`** appended to `write_policies` of `postgres` and
  `scheduler`; `api` declares its own (chunk 5). Until chunk 6 the loader
  accepts `no-access` on any brick (`model.py`'s write-policy check skips
  it); chunk 6 removes that bypass (10.2, 15).
- **`ROLES` gains `api`**, the role of the `api` brick **(choice**: it
  names 6.6's `api` part, so chunk 6's `PART_ROLES` maps `api: api`);
  `pgwatch` and `health-check` take `monitoring`, already in the list. A
  standby keeps `database` **(choice**: it is read as a database;
  `backup` stays unused). See Preflight corrections, item 6.
- **Written ahead for chunk 3**: `options: [monitoring]` on every node an
  exporter targets (17.5), and `GM_OPTIONS: monitoring` in the
  hand-written stack files whose `postgres` container serves an exporter
  (Preflight corrections, item 3); both are ignored until chunk 3 reads
  them.

**2. Scenario and node keys** (chunk 2 writes the templates, chunk 3
renders `options` and `standby_of`, chunk 6 checks; read by 7, 8, 10,
11, 17, 27). Shapes: master spec 6.2, 6.8; formats.md "Scenario",
"Composing domains".

- `options:` a non-empty list of unique names the node's brick declares
  **(choice**: `[]` says nothing absence does not).
- `standby_of: <node>`: a `postgres` node that is no standby itself; the
  standby has no `data:` entry, its data coming by the clone (item 6)
  **(choice)**. Several standbys of one primary each get a slot; v0.5
  builds one.
- `third_parties:` as 6.2. **(choice)** `hostname` unique,
  `[a-z][a-z0-9-]*`, never a node's name: an alias equal to a node name
  would shadow it on the one network.
- `domains:`, `governance.register`: formats.md. `variant:` is required
  on the core's entry and refused on a part's **(choice**: 6.2's "beside
  the core"; the loader then checks that the core's manifest names each
  part, D301). A scenario lists `domain:` or `domains:`, never both
  **(choice)**.

**3. HTTP connections, the call form, the weighted `choice`**
(`schedule.yaml`, `queries.yaml`; chunk 4 implements, chunk 2's
templates carry, chunk 6 checks, chunk 7 renders the credentials; read
by 9, 11 to 16, 18 to 21). Master spec 6.8, 7.2, 24.

```yaml
connections:
  lab-api:
    driver: http
    target: lab-api:8000            # <host>:<port>: a node, or a third party's hostname
                                    # (an alias on the partners' api node)
    credential: interfaces_lab_api  # optional: absent for a public endpoint; [a-z][a-z0-9_]*,
                                    # the game's secret http_<credential> (item 0)
    pool: 2                         # kept-alive connections, a positive integer
    timeout: 10s                    # optional: per request, <n>s, 1 to 60; default 10s
```

- **(choice)** `credential` optional: the owners' traffic and cold
  storage's page call public endpoints. `pool` an integer, as 6.8 shows,
  with no `per-call` form. `timeout` defaults to 10 s, the SQL driver's
  connect timeout, one figure for the connection and the answer. An HTTP
  connection has no `role` and no database: the template's `role` becomes
  optional, for `sql/postgresql` only.
- **On the wire (choice)**: `Authorization: Bearer <secret>` when a
  credential is set; `Host:` the target as written (item 5's dispatch);
  `User-Agent: <the caller's hostname>`, as `application_name` is on a
  SQL session, so the players find the caller in the `api` node's log;
  JSON bodies `application/json`, UTF-8.
- **The call**, a sixth repository form beside v0.3's four and v0.4's
  script **(choice**: the call's contract stays readable in
  `queries.yaml`, as a query's SQL is):

  ```yaml
  queries:
    portal.desk-consent:
      call: POST /desk/consents     # "<METHOD> <path>": GET POST PUT PATCH DELETE; the path
                                    # absolute, its %(name)s filled from params, URL-quoted
      params:                       # optional: generators, as a query's; those not in the path
        owner: {int: [2, 10000]}    #   are the JSON body's fields (GET, DELETE: the query string)
        consent: {choice: {grant: 3, withdraw: 1}}
    lab.order.post:
      call: POST /orders
      builder: builders/orders.py:order   # optional: returns the JSON body; called as a
      options: {urgent_share: 0.08}       #   builder is, (intensity, options, rng=)
  ```

  A call key runs only on an `http` connection, and a query, pool,
  sequence or builder key only on a SQL one. With `builder`, `params`
  holds only the path's names **(choice)**. No pool, sequence or
  transaction of calls. Drawn values in JSON: `int` and `decimal` as
  numbers, `choice` as drawn, `now` as an ISO 8601 UTC string. A stream's
  call discards the answer's body.
- **The weighted `choice`**, 6.8's form: weights positive integers,
  relative, not summing to 100 **(choice)**; values scalars, as the list
  form's, which stays.

**4. The scheduler's side** (chunk 4; read by 7, 11, 12 and every chunk
with HTTP flows). Master spec 7.2.

- **Credentials**: the entrypoint passes `credential <name> <value>`
  lines on standard input, beside `password <role> <password>`, from each
  mounted `/opt/gm/secrets/http_<name>` **(choice)**; a connection whose
  credential is not passed refuses the schedule, as a role without its
  password does.
- **A stream's call** counts as one call of its key in the minute
  summaries and the metrics, unchanged. A non-2xx answer, a timeout or
  no connection is an error: v0.3's `error` line with
  `status=<three digits>|timeout|refused` in place of `sqlstate=`, and
  `message=` the reason or the answer's first 200 characters
  **(choice)**.
- **The scripts' client**: in a script job, `conns[<name>]` for an HTTP
  connection is a client with `get(path, params=None, *, headers=None)`
  and `post(path, body=None, *, headers=None)`. `body` is
  JSON-serialisable (sent as `application/json`) or `bytes` (sent as is,
  `Content-Type` from `headers`, default `application/octet-stream`: a
  shipment's NDJSON); `headers` never sets `Authorization` or `Host`. A
  call returns an answer with `status` (an integer), `headers`, `text`
  and `json()`, **whatever its status (choice**: a round trip expects
  rejections, 6.6, and the script decides); a timeout or a refused
  connection raises `HttpError` (`.status` `timeout` or `refused`),
  which, unhandled, ends the run as any exception does (v0.4 W1 item 7).
- **Logged and counted (choice)**: each script call one line, `http
  job=<job> connection=<name> method=<M> status=<s> ms=<latency>
  path=<path>`, the path last as it may be quoted; counted under the
  series `<job's key>/<connection>` (calls; errors: non-2xx, timeout,
  refused; latency), apart from the run's own count under the job's key.
  A `/` never appears in a repository key (`KEY_RE`), so no series
  clashes, and the run's figures stay v0.4's.
- The client is the standard library's (`http.client`) unless G7 clears
  a package (24).
- **`no-access`**: no `player` account, no wrappers; `sshd` and
  `processes` unchanged **(choice**: node-health's `default` still holds,
  and no account can log in).
- W1-y records the module paths, the standard-input form and the bounded
  wait as built.

**5. The `api` brick** (chunk 5; read by 7, 9, 11, 12, 15, 16, 18 to
21). Master spec 7.2 "The `api` brick"; access model 5, "`api` nodes".

- **Port 8000**, plain HTTP/1.1 **(choice**: 6.8's example; TLS is
  `postgres`' only in v0.5).
- **On the node (choice)**: `/srv/api/api.yaml` and
  `/srv/api/routes/<name>.py` protected, `/srv/api/db/<name>.py` the one
  writable path (7.2), the brick's library `gm_api` in the image,
  protected. Seed entries `api.yaml`, `routes/`, `db/` (directory
  entries), mapped by `seed.paths`; `writable_paths` `/srv/api/db` and
  `/home/player`.
- **`api.yaml` (choice**: 6.5 names the endpoint files and the roles'
  secrets, but render must know which roles and credentials to mount, and
  the brick which hostname serves which endpoint; one declarative file
  holds both and no secret):

  ```yaml
  endpoints:                        # name -> how it is served: routes/<name>.py and db/<name>.py
    orders:
      hosts: [lab-api]              # the hostnames it answers under: on a node in the players'
                                    # scope its own name only; on the partners' node a third
                                    # party's hostname, or owners
      credentials: [interfaces_lab_api]   # optional: those it accepts, any one; absent: public
  connections:                      # optional: schedule.yaml's two forms
    lab: {driver: sql/postgresql, target: lab:5432/lab, role: lab_api, pool: {size: 4}}
    xlab-results: {driver: http, target: lab-api:8000, credential: xlab_results, pool: 1}
  ```

- **Dispatch**: the request's `Host` without its port picks the
  endpoints listing it; an unknown host answers 404; two endpoints of
  one host declaring one method and path are refused at start and at
  reload; a missing or wrong credential answers 401 before the route
  runs.
- **A route file** defines `router`, a FastAPI `APIRouter`, at top
  level, and imports FastAPI, Pydantic, the standard library and `db/`
  modules only (7.2). Routes are plain `def` **(choice**: synchronous
  psycopg 3 in FastAPI's thread pool reads simply for the players; chunk
  11 measures one partner's slowness never holding another's).
- **A `db/` file** imports psycopg 3, the standard library and
  `gm_api`: `gm_api.connection("<name>")`, a context manager giving a
  pooled connection of `api.yaml`'s connection, autocommit off, as its
  role, the password read by the brick from
  `/opt/gm/secrets/role_<role>_password` (derived as on a scheduler node:
  Preflight corrections, item 2), never by endpoint code; on leaving,
  whatever is uncommitted is rolled back and the connection returned.
  `gm_api.client("<name>")` gives item 4's client on an `http`
  connection, for a partner's endpoint that reads, calls and writes
  (7.2).
- **The transaction-local setting**: the `db/` side runs `SELECT
  set_config('portal.owner_id', %s, true)` inside the request's
  transaction (7.2); the rollback on return means none outlives its
  request. How a `db/` module sets session-level settings on its pooled
  connections, the players' lever (7.2), is W1-z's.
- **Reload**: `sudo gm-reload-api` (a sudo wrapper, the
  `fixable-node` condition) imports every endpoint pair and builds the
  application; on the first error it refuses, naming it, and the running
  server stays; else it restarts the server **(choice**: named as
  `gm-reload-scheduler`).
- `no-access` as item 4. W1-z records `gm_api`'s surface, the request
  log (path and line), the workers, the reload's messages and the build
  checks as built.

**6. `postgres` 0.5.0's interfaces** (chunk 3; read by 7, 8, 10, 11,
20, 23, 24, 27). Master spec 7.1, 11.1, 11.2.

- **The option and `no-access`**: item 1; `no-access` creates no
  `player` account and no wrappers (the entrypoint's steps 6 and 8, no
  sudoers file); `sshd` runs, as item 4.
- **The standby**:
  - the replication role `replicator`, `LOGIN REPLICATION`, set on the
    primary by the clone step as a SCRAM verifier with statement logging
    off, as `load-data` sets passwords; never created at initdb or by a
    data file **(choice**: it exists where a standby needs it). Its
    secret `replication_password`, a password declared in `postgres`'
    `brick.yaml` at `/opt/gm/secrets/replication_password`, 0:0 `"0400"`,
    mounted on every `postgres` node **(choice**: no new condition key;
    a spare secret costs nothing);
  - the slot: the standby's node name, `-` read as `_` **(choice**: slot
    names take `[a-z0-9_]`); `standby` in the clinic;
  - the primary's seed `pg_hba.conf` carries `host replication
    replicator samenet scram-sha-256` **(choice**: the format skill states
    it, chunk 6 checks it on a primary with a standby); the standby's
    seed sets `hot_standby_feedback = on` (7.1);
  - the password is never in `primary_conninfo`: a password file under
    `/run`, `postgres`-only (access model 4, service credentials);
  - **the clone step** is `load-data`'s last step, after every step
    chunk 8 adds **(choice**: the standby copies the checked load), for
    each standby in topology order: `replicator` set on the primary, then
    `/usr/local/lib/gm/clone-standby`, root-only, no arguments (it reads
    `GM_STANDBY_OF`), run as root in the standby: postgres stopped, the
    data directory emptied, `pg_basebackup -X stream -C -S <slot> -R`
    from the primary, postgres started as a standby; `load-data` then
    waits, bounded by its `--timeout`, until the primary's
    `pg_stat_replication` shows the slot's sender `streaming`. Any
    failure is a failed setup. **Every other `load-data` step skips a
    standby**: no data file, password, grant, survey or mapping is
    written there; all of them reach it from the primary.
- **Archiving and the base backup**:
  - **`vault-post <type> <name> [<file>]`** at `/usr/local/bin/vault-post`
    **(choice**: on `PATH`, readable in the seed as a customer's tool),
    `<type>` `wal` or `basebackup`, the payload from `<file>` or standard
    input. The seed: `archive_command = 'vault-post wal %f %p'`; the
    crontab's line, in v0.4 W1 item 8's baseline form: `<m> <h> * * *
    pg_basebackup -h /run/postgresql -D - -Ft -X fetch | vault-post
    basebackup "<node>-$(date -u +\%Y\%m\%dT\%H\%MZ)" >>
    /var/log/postgresql/cron/basebackup.log 2>&1`;
  - its target and credential: `postgres` parameters `vault_target`
    (`<host>:<port>`, cold storage's hostname) and `vault_credential`
    (a credential name, mounted as `http_<name>`), both default null
    **(choice**: render mounts only what a declaration names; with
    neither, `vault-post` exits 1, "no vault configured");
  - **the request (choice)**: `POST /shipments` (10.4) with headers
    `Shipment-Id` (the segment's name, the backup's name),
    `Shipment-Type`, `Shipment-Rows` (`1` for `wal` and `basebackup`),
    `Shipment-From` and `Shipment-To` (dates; for these two types the
    posting day, UTC), `Shipment-Name`, `Shipment-Source` (the node:
    11.2, "each manifest names its node") and `Authorization`; the body
    the file's bytes, `application/octet-stream`. A data type (purpose
    14) takes the same headers, an NDJSON body and its partitions' dates.
    The receipt: 201, JSON `{shipment_id, type, rows_declared,
    rows_received, size, received_at}`, `size` the bytes received.
    Reason: headers keep a binary payload whole, and one form serves
    every type; chunk 11 builds the stub on it, chunk 3's stack test a
    stand-in;
  - **honest failure**: exit 0 only on a 2xx receipt naming the shipment
    whose `size` equals the bytes sent; otherwise non-zero, with one
    line on standard error (the server's log) saying why, so PostgreSQL
    keeps the segment and retries (7.1). Built without a package beyond
    the image's, or the package joins G5.
- **TLS**: one certificate per game, self-signed, its names every
  `postgres` node's and `localhost`, valid a year, generated by
  `deploy.generate_credentials` with the host's `openssl`, as `ssh-keygen`
  makes key pairs; a secret kind `certificate` (`pair: tls`, `half:
  certificate | key`), its files `secrets/tls.crt` and `secrets/tls.key`
  **(choice**: one name is one secret per game; nothing verifies a host
  name in v0.5; an expiry inside a game is a fault to plant, never an
  accident). `postgres`' `brick.yaml`: `tls_certificate` at
  `/opt/gm/secrets/tls.crt`, 0:0 `"0444"`, and `tls_key` at
  `/opt/gm/secrets/tls.key`, 0:102 `"0440"` (PostgreSQL's rule for a
  root-owned key); the seed: `ssl = on`, `ssl_cert_file` and
  `ssl_key_file` naming them. Generated in every game with a `postgres`
  node, used only where a seed turns `ssl` on (17.5).
- W1-x records the brick as built: the entrypoint's option and
  `no-access` paths, `clone-standby`, `vault-post`, the base-backup
  job's log, pgaudit's classes in the stack test's seed.

**7. The domain format and `gmctl compose`** (chunk 2; read by 6, 8, 9,
12 to 17, 26, 27). Formats.md "Domain", "Composing domains"; master spec
8.2 to 8.5, 15.

- **`domain.yaml`** as formats.md "`domain.yaml` must contain".
  **(choice)** `requires` a one-item list; `lands_with` equal to its
  item; with `databases`, `schema` and `load` absent and
  `data/<database>/{schema,load}.sql` for each; `derive` requiring
  `data/derive.sql`; `policy` and `governance` (`docs/policy.md`,
  `data/governance.yaml`) both or neither.
- **Producer folders per node (choice**; Preflight corrections, item 1):
  `producers/<node>/` holds the fragments for the scheduler node of that
  name (`queries.yaml`, `schedule.yaml`, `jobs.yaml`, `builders/`,
  `scripts/`); `producers/api/<node>/` an `api` node's `api.yaml`
  fragment, `routes/` and `db/`; `producers/partners/<partner>/` the back
  end's fragments at its root and the partner's `api.yaml`, `routes/`
  and `db/`; `api`, `partners` and `public` are reserved names. Reason:
  `vet-housing`'s fragments target `pms` and `ward`, compose needs each
  fragment's node, and `producers/api/<node>/` already names its node.
  The shop's move to `producers/producer/`, its v0.4 scenario's node.
- **A variant's manifest (choice)**: the core's `variants/<variant>.yaml`
  holds `parts` (may be `[]`), `scale: {population, history,
  throughput}`, each a non-empty map of name to number or text,
  `purposes` and `tags`; a part's manifest of the same name holds `scale`
  and `purposes` only. Tags from formats.md's vocabulary, at most one
  maturity and one reach **(choice**: a setup has one of each).
- **The classification key** as formats.md (`<table>.<column>`, or
  `<schema>.<table>.<column>` outside `public`); a scenario's copy
  prefixes the database, four parts outside `public` **(choice)**. The
  register fragment's and the other templates' key names are chunk 2's,
  recorded in W1-w.
- **`gmctl compose <scenario-dir> [--check]` (choice)**: design time, no
  playground. It reads `scenario.yaml`'s `domains:` (with the core's
  variant) and `third_parties:`, the catalogue's domains, the scenario's
  layer and `merge.yaml`, and writes each target node's files under
  `nodes/<node>/` (a scheduler node's three files, `builders/`,
  `scripts/`; an `api` node's `api.yaml`, `routes/`, `db/`);
  `scenario.yaml`'s `seed_files` stay the GM's. `--check` writes
  nothing and exits 1 when a written file differs. Exit 0 merged; 1 an
  unresolved conflict, a stale or malformed `merge.yaml`, or `--check`
  finding a difference; 2 usage.
- **Layers**, 8.4's order. **(choice)** The domain layer is
  `producers/<node>/` of every domain composed, and each
  `producers/partners/<partner>/` onto the shared nodes, the scheduler
  and `api` nodes every `third_parties:` entry lists (compose refuses
  entries naming different ones); the variant layer
  `variants/<variant>/producers/<node>/`; **the scenario layer the
  scenario folder's `compose/<node>/`**, kept apart from the output so a
  rerun reproduces it, holding the purposes' material the GM adds and
  each scheduler node's `intensity` and `timeline` (never in a fragment).
- **Merge units (choice)**: `connections.<name>`, `shapes.<name>`,
  `streams` by key, `intensity`, `timeline`; `queries.<key>`; `jobs` by
  name; `api.yaml`'s `endpoints.<name>` and `connections.<name>`; files
  under `builders/`, `scripts/`, `routes/` and `db/` by name. Identical
  merges silently, a higher layer wins and is reported, two sources of
  one layer differing stop the merge, naming the unit and both sources.
- **Provenance (choice)**: each output entry and file carries `# from
  <domain>@<variant>: <path in the catalogue>` or `# from scenario:
  compose/<node>/<file>`, with `, over <source>` on an override, so the
  report's record stays in the files; the report is printed only.
- **`merge.yaml` (choice)**:

  ```yaml
  resolutions:
    - node: pms
      file: schedule.yaml
      entry: connections.clinic     # the unit, as the conflict names it
      take: vet-core@regional-franchise   # the source that wins, or
      # value: {...}                # the entry, written as is
      reason: <one line>
  ```

  Exactly one of `take` and `value`; a resolution meeting no conflict is
  refused as stale.
- **Duplicate keys**: one loader refusing a duplicate mapping key,
  applied to compose's inputs, `merge.yaml`, `composition.yaml` and every
  file `check_domain_dir` reads **(choice**: v0.4's released scenario
  files keep loading as they are).
- **`composition.yaml`**: formats.md's fields. Checked against
  `domains:` as formats.md and chunk 2's scope say, with these
  **(choices)**: required with `domains:`, refused without; its
  `domains` entries equal `scenario.yaml`'s (id, variant, `at:`),
  `lands_with` present exactly for a domain declaring it; `order` lists
  every id once, a part after its core, a derivation's domain after its
  `after`; `derive` only for a domain declaring it, its `after` the
  declared one; `keys` keyed by listed parts, names unparsed; `scale`
  `{checked, note}`; `coherence` optional, written by chunk 8. `at:` names
  a `database` node and a database; whether the scenario's data creates
  it is chunk 8's (W2).

**8. Wave 1 coordination** (for the driver and chunks 1 to 5)

- **Ownership**: chunk 1 owns every version line of `postgres`,
  `scheduler`, `bastion` and `grafana`, every pin, `applies_to` and
  "Supported faults", `postgres`' `options:` entry and its heading, the
  `no-access` lines, `ROLES`, and item 1's lines written ahead; chunks 3
  and 4 every other line of their brick; chunk 5 all of `bricks/api/`
  and its row in the root `README.md`; chunk 2 `model.py` and the
  templates. Chunks 2 to 5 share no source file (with Preflight
  corrections, item 2, chunk 3 keeps `localimpl.py` and `inject.py`).
- **Order**: chunk 1 alone; then 2 to 5, three at a time (3 after G5, 5
  after G6, 4 after G7 if a package). No in-wave edge among 2 to 5.
- **Until chunk 6**, the loader refuses `driver: http`
  (`model.DRIVERS`) and the map form of `choice` (`GENERATORS`'
  check): nothing the unit suite loads in wave 1 (scenarios,
  `tools/tests/fixtures/`, `domains/`) uses them; the scheduler's and
  the `api` brick's own stack-test fixtures are outside it, and chunk 2's
  compose tests use neither (Preflight corrections, item 5).
- **The templates are the schema**: every key chunk 2 adds is
  `# optional:`; `schedule.yaml`'s `role` optional for `sql/postgresql`
  only, `credential` and `timeout` optional.
- **Images**: as v0.4 W1 item 9, a tag is built only from a branch
  holding its version; new callers start before their peers in their
  stack tests (workflow deltas).

**Choices made here, not in the spec** (for the driver's review): the
`GM_OPTIONS` and `GM_STANDBY_OF` variables; derived secrets' one mount
rule and the copy under `/run`; endpoint names; an option's secret
declared under `secrets:` and mounted only with the option; the option's
heading under "Configuration"; `api` as the `api` brick's role and
`database` the standby's; `options:` non-empty; a standby with no data
entry; third parties' hostnames unique and never a node's; `variant:` on
the core only; `domain:` or `domains:`; `credential` optional, `pool` an
integer, the 10 s `timeout`; the wire headers and `User-Agent`; the call
as a sixth form, its `"<METHOD> <path>"`, the body from `params` or a
builder, path names from `params`; relative weights; credentials on
standard input; HTTP errors' `status=`; the client's answer whatever its
status, `HttpError`, the `http` line and the `<key>/<connection>`
series; `sshd` kept on a `no-access` node; port 8000 without TLS; the
`api` node's paths and `api.yaml`; synchronous routes; `gm-reload-api`;
`replicator` set by the clone step, its secret on every `postgres` node;
the slot's name; the primary's replication line; the clone as
`load-data`'s last step, `clone-standby`; `vault-post`, its parameters,
the shipment headers and receipt; one TLS certificate per game, its
secret kind and paths; `domain.yaml`'s key rules; producer folders per
node; the variant manifest and tag limits; the four-part scenario key;
`gmctl compose`'s arguments, layers' folders, the scenario layer
`compose/<node>/`, merge units, provenance comments, the printed report,
`merge.yaml`'s form; the duplicate-key refusal's reach;
`composition.yaml`'s checks.

### Preflight corrections for spec-writer

1. **A domain's producer folders** (formats.md "Domain" layout and
   "Producer material"; chunk 2). formats.md lays out one fragment set at
   `producers/`'s root and `producers/builders/`, so a domain whose
   fragments target two scheduler nodes (`vet-housing`: `pms` and `ward`)
   has no place for the second, and nothing says which node a fragment
   targets, which `gmctl compose` needs. Proposal: W1 item 7's
   `producers/<node>/`; chunk 2's Files gain `domains/shop/producers/`
   (the shop's fragments moved to `producers/producer/`). W1 holds it
   meanwhile.
2. **The `api` node's `api.yaml` and its secrets** (master spec 6.5,
   formats.md; chunks 2, 3, 6). 6.5 gives the `api` brick its endpoint
   files and its roles' secrets, but no chunk derives those secrets:
   `localimpl.connection_roles` and `inject.password_plan` read scheduler
   nodes' `schedule.yaml` only, and would take an `http` connection's
   missing role as a role. Proposal: W1 item 5's `api.yaml` in formats.md
   and 6.5; chunk 3's scope (it holds `localimpl.py` and `inject.py` in
   wave 1) gains the connection roles read from an `api` node's
   `api.yaml` and `driver: http` connections skipped, in both places, so
   wave 2's chunks 7 and 8 do not both edit `inject.py`; chunk 2's
   templates gain `api.yaml` and its compose scope the `api` nodes'
   `api.yaml` and endpoint files (8.4 already merges a partner's endpoint
   files); chunk 6's scope gains `api.yaml`'s checks (its two files per
   endpoint, its hosts, its connections).
3. **`GM_OPTIONS` in the hand-written stack files** (chunks 1, 3). Once
   chunk 3 creates `monitoring` only with the option, a `postgres`
   container without `GM_OPTIONS: monitoring` has no `monitoring` role,
   and the `postgres-exporter` and `prometheus` stack tests and
   `tools/tests/fixtures/calibrate-f10/stack.yml` fail at wave 1's gate;
   those files are not in chunk 3's Files. Proposal: chunk 1's scope
   gains those lines (it already edits the files for tags), as W1 item 1.
4. **The HTTP credential before W2** (chunks 4, 5, 7). The plan leaves
   the credential's secret, its name and where the caller and the
   endpoint read it to W2, but chunks 4 and 5 read it in wave 1.
   Proposal: W1 fixes them (items 0, 3, 4, 5); W2 keeps render's
   generation and which nodes mount which; chunk 7's scope gains the
   mounts on `postgres` nodes (`vault_credential`) and on `api` nodes
   (`api.yaml`'s `credentials`); the aliases can be read from the
   partners' `api.yaml` hosts.
5. **HTTP connections and the weighted `choice` before chunk 6** (plan
   "Read first"; dependency graph). "The loader refuses no unknown key
   today" holds for keys, not for these values: `model.DRIVERS` refuses
   `driver: http` and the generator check the map `choice`, in scenarios
   and in domain fragments (`_check_fragments` checks a `queries.yaml`
   as a repository). `vet-core`'s profiles use the weighted `choice`, and
   chunk 11's fixtures HTTP connections. Proposal: merge-order edges `6
   ──> 9` and `6 ──> 11` in wave 2, as `3, 6 ──> 10` has.
6. **The `api` role** (formats.md "Roles"; chunk 2's `brick.yaml`
   template comment). The roles list gains `api`; chunk 1 adds it to
   `ROLES`.
7. **Small lines for chunks 4 and 6**: chunk 6's scope gains `options`
   and `standby_of` in `RESERVED_PARAMETERS`, `replicator` in
   `RESERVED_DB_ROLES` and the primary's replication line; chunk 4's
   `replicator` in `FORBIDDEN_ROLES`.

### Questions for the owner

None.
### G5 — dependency preflight on `postgres` 0.5.0's packages (security-advisor, 2026-11-03)

**Clear, with conditions; nothing for the owner.** Resolved in throwaway
`debian:13-slim` containers with the Dockerfile's PGDG line (none left).

- **pgaudit**: `postgresql-18-pgaudit=18.0-3.pgdg13+1` (upstream 18.0),
  **pinned exactly** (`ARG PG_AUDIT_PACKAGE=18.0-3.pgdg13+1`, the second,
  PGDG `apt-get install`, a `dpkg-query` assertion as pg_cron's; plus
  `test -f /usr/lib/postgresql/18/lib/pgaudit.so`). Pulls in nothing new.
  No advisory (no CPE; CVE-2025-23413 is F5's, not pgaudit's).
- **Build note bearing on the game**: pgaudit's `role` class logs
  statement text, so `CREATE/ALTER ROLE … PASSWORD '…'` lands in clear in
  the file log, which `pgconf` (the players' group) reads. The initdb
  steps setting the `monitoring` and replication passwords run before
  pgaudit is loaded, or with `pgaudit.log = 'none'` and `log_statement =
  'none'` for that session, or pass SCRAM verifiers. (Passed to chunk 3.)
- **TLS: nothing to add.** `postgres` 18.6 is built `--with-openssl`;
  `libssl3t64`/`openssl` 3.5.7-1~deb13u3 and `ssl-cert` 1.1.3 are already
  pulled in by `postgresql-common`; `postgres` is in group `ssl-cert`.
  **Condition**: assert the floor `dpkg --compare-versions
  "$(dpkg-query -W -f '${Version}' libssl3t64)" ge 3.5.7-1~deb13u3`
  (DSA-6531-1, the 2026-09-29 OpenSSL batch, fixed only in
  trixie-security). Advised hardening: delete `ssl-cert`'s snakeoil key at
  build and assert it gone (identical in every game built from the image).
- **Standby and archiving**: `pg_basebackup` already present. The posting
  command **in Perl with core `HTTP::Tiny`** 0.088 (perl 5.40.1, already in
  the image through pgbadger): no package added; assert `perl
  -MHTTP::Tiny -e 1`. curl (13 more packages, ~13 open trixie CVEs) is the
  second choice; Python is not advised.
- `.tech` at G8: OpenSSL as a platform (`cpe:2.3:a:openssl:openssl`,
  3.5.7, Debian deb13u3; expect NVD false positives for the backported
  batch), pgaudit 18.0 (no CPE).

G5 **done (2026-11-03)**.

### G6 — dependency preflight on `api` 0.1.0 (security-advisor, 2026-11-03)

**Clear, with conditions.** Source: **a pinned PyPI set**, hash-pinned in
`bricks/api/requirements.txt` (that exact name, so the daily sweep reads
it as a lockfile). Fifteen wheels, each 0 known vulnerabilities
(`cve-watch query pypi`), pip's resolution in a trixie container:

```
fastapi==0.162.0          --hash=sha256:3785963de305dd09912426cb81f2d230fce98ab3521cdfe97265c8d14983128c
uvicorn==0.54.0           --hash=sha256:505bdb0f318731d45f1f712071fc781a8981f6847a31c902c9f5e652d4f67faf
starlette==1.10.0         --hash=sha256:478c0ab3b4ced6e82719849c118fa406f0278a3499c1a898cd15cd31bdc38ce4
pydantic==2.14.2          --hash=sha256:7efbf7507b937931cd32a5755acb00ea1cf5ccb1d4e8067a5850d5069e382118
pydantic-core==2.50.2     --hash=sha256:31a1fb3ffbd1195b24490f671d12623dd4c9bfa56d6af0a299fa43b516134f5b
psycopg==3.3.7            --hash=sha256:d592e88a077e01ff57f22d59f16e828b92f2b2d9f439b6679d582b48d74cf306
h11==0.16.0               --hash=sha256:63cf8bbe7522de3bf65932fda1d9c2772064ffb3dae62d55932da54b31cb6c86
anyio==4.16.0             --hash=sha256:c66ae634e0b8228396b801741beb3294326d4b6102f7bba4041c0dfb58c29026
idna==3.20                --hash=sha256:ab7ae7122974553370f0bdb919e1a960b2cd1bc1ef0276416d896db81c14582c
click==8.5.0              --hash=sha256:255bc9599cf7748b4b1a446ccc735421bd08a2ae529a8b88597d3de5664ee360
typing-extensions==4.16.0 --hash=sha256:481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8
typing-inspection==0.4.4  --hash=sha256:65b8397ba37ccbce054456aaccddfc91e6e3083c92824df348d96ca832f3f147
annotated-types==0.8.0    --hash=sha256:f072f4d804ea359e4eaf198b1af7a8b0943881a87f31bb764f8bf219bb9419e0
annotated-doc==0.0.5      --hash=sha256:117bac03a25ede5df5440e855b32d556049ca169ead221505badf432fed4b101
opentelemetry-api==1.45.2 --hash=sha256:2cbd737377e710ee740d261c94e93fa0f08e6d037c18f17513cc0a2d94479a34
```

(pydantic-core's hash is the cp313 manylinux x86_64 wheel; psycopg 3.3.6
is also clean if 3.3.7, released today, misbehaves.)

Conditions on the build:
- plain `uvicorn` (no `[standard]`: no uvloop, httptools, websockets), no
  python-multipart (JSON only);
- plain `psycopg`, never `psycopg[binary]` (its bundled libpq and OpenSSL
  are invisible to Debian and the sweep); Debian `libpq5` as the
  scheduler;
- installed in a throwaway build stage with `pip install --require-hashes
  --only-binary=:all: --no-deps --target <stage> -r requirements.txt`,
  copied into `/usr/local/lib/python3.13/dist-packages` (the scheduler's
  pattern); **no pip in the final image** (Debian's python3-pip 25.1.1 has
  open trixie CVEs, build-time only); uvicorn run as `python3 -I -m
  uvicorn`; optional `ENV OTEL_SDK_DISABLED=true` (FastAPI 0.162
  hard-depends on `opentelemetry-api`, which exports nothing without the
  SDK).
- Build assertions: `sys.version_info[:2] == (3, 13)`; each
  `importlib.metadata.version` equal to its pin; `psycopg.pq.__impl__ ==
  "python"` and `psycopg.pq.version() >= 170000`; `! python3 -I -m pip
  --version` in the final stage.

The Debian 13 route (FastAPI 0.115.11, 23 packages) was rejected: four
open, unreachable but permanent watch items (anyio CVE-2026-63374,
-64847, -63349; dnspython CVE-2026-114605), and no lockfile for the
sweep to read. CVE-2026-15308 (python3.13 `html.parser`) extends to the
`api` image as a watch item: not reachable (nothing in the set imports
`html.parser`), and a player editing `db/` already runs Python in the
process. `.tech` at G8: `bricks/api/requirements.txt` and the `api`
brick under the Python platform.

**For the owner, not blocking**: this is the project's first PyPI
dependency set and first lockfile. The plan (G6) allowed either source;
the driver takes the advisor's recommendation. Should the owner want
Debian packages only as a policy, that is a ruling, and chunk 5 would be
reworked to the Debian route.

G6 **done (2026-11-03)**.

### G7 — `scheduler` 0.3.0's client

W1 item 4 keeps the HTTP driver and the scripts' client in the standard
library (`http.client`). G7 is **not needed** unless chunk 4 adds a
package; its owner is told to stop and report before adding one.

### W1 reviewed by the driver, 2026-11-03

The capture's 49 **(choice)** points are accepted as drafted. G5's
advice settles one point W1 left to chunk 3: `vault-post` is written in
Perl with core `HTTP::Tiny` (no package added). Its seven preflight
corrections go to `spec-writer` before chunk 1's branch is cut; it has
no question for the owner.

### Plan revision before chunk 1, 2026-11-03

`spec-writer` applied W1's seven corrections and G5's and G6's results:
build plan v2 (99ecd28), spec D344 (producer fragments in
`producers/<node>/`, the shop's in `producers/producer/`), D345
(`api.yaml`; chunk 3 derives the `api` nodes' roles from it and skips
`driver: http`), D346 (`GM_OPTIONS: monitoring` in the hand-written
stack files, chunk 1), D347 (the HTTP credential fixed by W1; W2 keeps
the mounts), D348 (chunks 9 and 11 **cut** once chunk 6 has merged, not
merge order only: W1's correction 5 replaced), D349 (`api` a node role),
D350 (the reserved names), D351 (chunks 3 and 5 under G5's and G6's
conditions; the PyPI source listed under "Pending with the owner").
No W1 item to amend; no owner question. Left for W2: whether chunk 7
reads the partners' aliases from `third_parties:` or from their
`api.yaml` hosts (chunk 6 checks the two agree).

### Chunk 1 — merged (1c76772), 2026-11-03

ec32633, merge 1c76772. Unit suite 854 OK (with `test_brick_docs`),
scheduler unit tests 72 OK in `scheduler:0.3.0`'s image; `postgres`
0.5.0, `scheduler` 0.3.0, `bastion` 0.5.0 and `grafana` 0.3.0 build;
the stack tests of those four and of `pgbouncer`, `postgres-exporter`
and `prometheus` pass (the last two with `GM_OPTIONS: monitoring`). The
loader loads the 7 bricks, 29 faults, 4 scenarios and 9 fixtures. Ten
READMEs regenerated (only the brick versions changed). `options:
[monitoring]` on each exporter-targeted `db` node (three scenarios,
three fixtures). Smoke scripts' tags updated, not run: wave gate.

Notes, none needing a spec change:
- **Twelve** catalog faults named `postgres` 0.4.0, not eleven; all took
  0.5.0 beside 0.4.0 (master spec 6.4). A miscount in the plan, for
  `spec-writer`'s next revision.
- `fixture-v04-refusals` keeps its own local `postgres` 0.4.0,
  `scheduler` 0.2.0 and `bastion` 0.4.0 against its own `catalog/` (as
  `fixture-v03-refusals` kept its scheduler 0.1.0 through v0.4); only its
  faults gained the new versions.
- `scheduler`'s program `VERSION` (`gm_scheduler/__init__.py`) set to
  0.3.0, outside the chunk's Files list (v0.4's chunk 1a precedent):
  chunk 4 may meet it as a one-line conflict.
- `GM_OPTIONS` in `calibrate-f10/stack.yml` on `db` only, the exporter's
  target.
- Left as they are: `bricks/{prometheus,pgbouncer,postgres-exporter}/docs/gm.md`
  still say "postgres 0.4.0" (a change would force a bump under 6.7);
  `.tech`'s brick versions (G8); the format skill's templates (chunk 2);
  the faults' prose.
- **For chunk 2**: the scenario-document template has no slot for a
  node's `options:`, so the READMEs don't show it.
- Risks until chunks 3 and 4: the `postgres` image still creates
  `monitoring` on every node; `no-access` is declared but no entrypoint
  implements it.
- Old images kept locally: `postgres` 0.1.0–0.4.0, `bastion` 0.1.0–0.4.0,
  `scheduler` 0.1.0, 0.2.0, `grafana` 0.1.0, 0.2.0, the scheduler unit
  images 0.1.0, 0.2.0. `/var` has 41G free.

**`main` moved during the wave**: 117678b (the root README's status,
version table and full layout) landed on `main` after `v0.5-w1` was cut.
The driver merged `main` into `v0.5-w1` before chunks 2 to 5 were cut,
and brought the README's bricks row to chunk 1's versions.

Chunks 2, 3 and 4 dispatched (κ = 3); chunk 5 at the first free slot.

### Chunk 2 — merged (c9ab20c), 2026-11-03

2a edf1dd5, 2b 2dc4267, merge c9ab20c. Unit suite 893 OK; templates
load with PyYAML and `model.strict_load`, every `template_schema`
builds; `check_domain_dir` clean on the rekeyed shop; `TestDomainRefusals`
(part without its core, classification keyed with its database, table in
no activity, variant tag outside the vocabulary, fragment at
`producers/`' root, and more); `test_compose.py` (two layers and an
override, a conflict stopping, `merge.yaml` taking a source or writing a
value, `api` nodes and a partner's onto the shared nodes, `--check`);
duplicate keys refused in fragments, `merge.yaml`, `composition.yaml`.
The only existing key made optional is `schedule.yaml`'s connection
`role`, and `_check_connection` now refuses an `sql/postgresql`
connection without one. The scenario holding `domain: shop` and a
classification copy is `tarnbeck-outdoor-campaign` (the plan's Done when
named `tarnbeck-outdoor-shop`, which has neither); both load.

Outside the Files list: `tools/tests/test_aging.py`'s verb list gains
`compose`; `domains/shop/docs/gm.md` names `producers/producer/`;
`fixture-v04-refusals`' own `fixture-shop` domain rekeyed likewise.

Points for review (no spec contradiction):
- `scenarios/tarnbeck-outdoor-campaign/scenario.yaml` line 75's comment
  ("the shop domain's, unchanged") is stale: the copy keeps the database
  prefix, the domain's file no longer does. Comment-only; left for the
  wave gate (a `scenario.yaml` edit regenerates the README).
- **`true:` in `register_diff`** (master spec 6.8) is read by PyYAML as
  boolean `True`: chunk 6 must look it up as `True`, or the format quotes
  it. For `spec-writer`.
- `public` as a purpose job's HTTP connection value for a public endpoint
  is the executor's word, not the spec's. For `spec-writer`.
- `scenario.yaml` gains `purposes[].parts.api` and `parts.partner`, so a
  scenario can map the new purpose parts (beyond the brief; accepted).

**Capture W1-w — chunk 2 outcomes (the domain format and `gmctl compose`;
read by 6, 8, 9 and every domain chunk)**, as the chunk owner reported:

- Template keys: `register.yaml` `activities[]` of `id`, `name`,
  `purpose`, `people` (may be `[]`), `tables` (`<table>` or
  `<schema>.<table>`), `retention: {period, then: erased|anonymised}`;
  `variant.yaml` `parts`, `scale.{population,history,throughput}`,
  `purposes`, `tags` (`parts` and `tags` required on a core, refused on a
  part); `domain.yaml` `register` required, `schema` and `load` required
  by code without `databases`, `policy` and `governance`
  (`data/governance.yaml`), `requires`, `lands_with`, `databases`,
  `derive.after`; `fault.yaml` `requires_option`, `option_absent`,
  `partner_behaviour: {partner, key, placed: timeline|standing,
  material}`; `answer-key.yaml` `register_diff[]` of `entry`, `field`,
  `true`, `handed_out`, `absent`, and `backlog: {what, cleanup}`;
  `purpose.yaml` `round_trips[]` (`asks`, `request{job,counterpart,sends}`,
  `correlation`, `answers[]{form,when,carries}`, `timeout{after,then}`,
  `reactions`), `history`, `classification.columns`, `jobs[].feeder`,
  `invariants[].judged`, `parts.api`, `parts.partner`; `brick.yaml`
  `options[]` of `name`, `brings{secrets,roles}`, `docs`; `schedule.yaml`
  connection `credential` and `timeout`; `queries.yaml` `call`.
- The register's tables come from `CREATE TABLE` in the schema files
  (`PARTITION OF` children with their parent, materialized views
  excluded); a table name in two databases of one part is refused.
- "Keyed with its database": a three-name key whose first name is a
  database the schema files create or `databases` lists; `public.` never
  written. A scenario's copy has 3 or 4 names
  (`SCENARIO_CLASSIFICATION_KEY_RE`); a purpose's `data_moved` key stays
  3 names (`CLASSIFICATION_KEY_RE`).
- Variants: every domain at least one `variants/<v>.yaml`; a variant's
  `purposes` among `domain.yaml`'s; each part a core's `parts` names
  requires that core and has a manifest of that name; a part's manifest
  is refused if its core's variant does not name it. The shop's variant
  is `present` (tags `managed`, `global`, `seasonal`).
- Producer folders: `producers/<node>/` allows `scripts/`;
  `producers/partners/<p>/` and `producers/public/<n>/` checked alike. An
  `api.yaml` fragment's keys: top level `endpoints` and `connections`;
  `endpoints.<name>` `[a-z][a-z0-9_]*`, non-empty `hosts`, optional
  `credentials`; connections `CONNECTION_KEYS` plus `credential` and
  `timeout`. Chunk 6 keeps the two files per endpoint and hosts against
  the topology.
- Duplicate keys: `model.strict_load` (a SafeLoader subclass);
  `_load_yaml(..., strict=True)` on every file `check_domain_dir` reads,
  and in compose, `merge.yaml`, `composition.yaml`; `check_scenario`
  loads `scenario.yaml` as before, compose strictly.
- Composition: `model.check_domains_entries(data, catalog_root)`
  (`domain:` and `domains:` never both; entry keys `id`, `variant`, `at`;
  each id once, of the catalogue; a part with no `variant`, its core
  listed, one of the core variant's parts; a core's `variant` required, a
  manifest of the core; `at` a `node/database` of a `role: database` node
  or a map exactly over `databases`; a `lands_with` part the same `at`),
  shared by compose and `check_composition` — **chunk 6 does not re-add
  these `domains:` checks**. `model.check_composition(data, sdir,
  catalog_root)` checks the record against `domains:`, runs in
  `check_scenario` only when `domains:` is present, refuses a
  `composition.yaml` without `domains:`, compares `derive.after` as sets.
- Compose: `compose.compose(scenario_dir, catalog_root, check)` returns a
  `Result` (`files`, `overrides`, `resolutions`, `differing`, `text()`),
  raises `ComposeRefused` (a `GmError`); exit 0 merged or up to date, 1
  refused or `--check` differing, 2 usage. It refuses its input when
  `check_domains_entries` fails (each domain's `check_domain_dir`
  included). Target nodes come from the producer folders and must exist
  in `nodes:` with brick `scheduler` or `api`; the shared nodes come from
  `third_parties:` entries with nodes (exactly one scheduler and one
  `api` node, the same in every entry; `nodes: []` ignored). Source names
  `<domain>@<core's variant>` (domain and variant layers, told apart by
  path), `scenario`, `merge.yaml`. A conflict within a layer is resolved
  only by `merge.yaml`; `take` matches a source name or its catalogue
  path, exactly one side. Provenance `# from <name>: <path>[, over
  <name>: <path>…][ (taken by merge.yaml)]` (`--` in `.sql`, after a
  shebang). A scheduler node always gets its three files, an `api` node
  its `api.yaml`. Stale files under `nodes/<node>/builders` are not
  deleted. `merge.yaml` units: for a file in a folder, `file` the folder,
  `entry` the file name.
- Risks: the `CREATE TABLE` parse misses quoted table names; compose's
  block-style output drops the fragments' comments (provenance comments
  replace them); compose run only on its fixture so far.

Chunk 5 dispatched in chunk 2's slot.

### Chunk 4 — merged (99d5398), 2026-11-03

4a 3316e42, 4b 48a2224, merge 99d5398. Scheduler unit tests 91 OK in
the image; stack test 178 of 178 (about 21 min; a first run's one
failure was the test's own `s6-svstat` path); `tools/tests` 854 OK.
Stack: 394 `POST /consents/<owner>` from params and 78 `POST /orders`
from a builder; 78 of 78 503s and 78 of 78 timeouts counted as errors;
weighted `{grant: 3, withdraw: 1}` gave 77 % (unit: 20,000 seeded draws
within ±1.5 points); the caller waited (`wait status=waiting bound=30s`)
and resolved after 6.2 s when the stub started; the script job's client
logged one `http` line per call, its `stub.relay/lab` series apart; a
`no-access` node has no `player` (getent, id, ssh refused, sshd up).
Footprint at rest: caller idle 18–19M of 128M (RSS 26–27M), 48 calls a
minute 20M, plus a script job each minute as `no-access` 28M; image
171MB; `brick.yaml`'s `footprint` unchanged. G7 not needed (standard
library only).

Deviations (inside the brick, accepted):
- Files outside the Files line: `repository.py` (the call form, W1 item
  3's sixth repository form), `runner.py`, `__main__.py`, the s6 `run`
  script; `streams.py` unchanged.
- **`no-access` as built**: the image bakes `player` and the root
  filesystem is read-only, so the account can't be removed at start. Two
  account sets in `/etc/gm-accounts/{player,no-access}`; `/etc/passwd`,
  `group`, `shadow`, `gshadow` link into `/run/gm-accounts`, filled by
  the entrypoint by write policy before any lookup; the image's own
  `/run/gm-accounts` holds the full files (the engine resolves `exec -u`
  from the image). The outcome is W1 item 4's. **The driver passed the
  mechanism to chunks 3 and 5** while they ran, to adopt unless their
  brick has a reason not to.
- W1 read so: `connection=<name>` in the `http` line and the
  `<key>/<connection>` series is the script's own name for the
  connection (the `conns` key in `jobs.yaml`); a job with `connection:`
  may not name an HTTP connection or run a call key (calls run in
  streams; HTTP otherwise only through a script).

**Capture W1-y — chunk 4 outcomes (`scheduler` 0.3.0; read by 7, 11, 12
and every chunk with HTTP flows)**, as the chunk owner reported:
- Modules: `gm_scheduler/drivers/http.py` (`HttpSession`, `Client`,
  `HttpError`, `Answer`, `encode_json`, `exchange`); `drivers.in_thread`
  moved out of `scripts` (re-exported); `repository.CallEntry`,
  `CallPlan`; `runner.driver_problems`, `wait_for_names`;
  `schedule.parse_http_connection`.
- Standard input: `credential <name> <secret>` lines (name
  `[a-z][a-z0-9_]{0,62}`) after the `password` lines; the run script
  reads `/opt/gm/secrets/http_*`; the entrypoint refuses an `http_*`
  secret badly named, empty, multi-line or holding a space; a credential
  the schedule names but not passed exits 2.
- Connection: `timeout` `<n>s`, 1–60, default 10, bounding connect plus
  the answer's head, then each body read; `pool` kept-alive connections;
  a kept connection closed while idle is reopened and the request sent
  once more.
- Wire: `Host` the target as written; `User-Agent` the hostname;
  `Authorization: Bearer <secret>` only with a credential; compact UTF-8
  `application/json`, decimals keeping their digits, `now` ISO UTC with
  `Z`; a call with no remaining params sends `{}`, a builder returning
  `None` no body; GET and DELETE: a builder returns a map, the query
  string; in the path `%` is `%(name)s` or `%XX`, `#` refused.
- Stream errors: `error key=… status=<3 digits>|timeout|refused
  message=…` (the body's first 200 characters trimmed, `<status>
  <reason>` when empty, `no answer within <n>s`, `<Exception>: <text>`);
  a failed lookup counts as `refused`.
- Scripts' client: `get(path, params)`, `post(path, body, headers=)` (a
  bytes body `application/octet-stream`); the answer's `status`,
  `reason`, `headers`, `content`, `text`, `json()`, `ok`; `HttpError` as
  `conns[n].HttpError`, `gm_scheduler.scripts.HttpError` or
  `gm_scheduler.drivers.http.HttpError`; up to `pool` idle connections,
  thread-safe; each call logs `http job= connection= method= status= ms=
  path=`; series declared at 0 at start and reload.
- Bounded wait: 30 s, each HTTP target probed once a second (5 s per
  lookup), only with an HTTP connection; `wait status=waiting bound=30s
  connections=…`, then `resolved ms=…` or `unresolved ms=…
  connections=…`; no status written meanwhile; SIGTERM cancels it.
- `no-access`: the account mechanism above; no `player_ssh_pubkey`
  required; home `root:root 0700`; report-only modes; the sudoers rule
  and wrappers stay but name no account; sshd kept.
- `replicator` in `FORBIDDEN_ROLES`.
- Risks: an idle-closed kept connection's request re-sent once; the
  `/etc/passwd` link mechanism relies on the engine resolving `-u` from
  the image's files (held on Docker 29); a POST body to the test stub
  took about 40 ms (the stub's unbuffered writes, not the scheduler).
- Untagged leftovers from the rebuilds of `scheduler:0.3.0` and
  `scheduler-unit:0.3.0` remain locally (no prune).

### Chunk 3 — merged (0e152ac), 2026-11-03

3a c0525d9, 3b bb0c43e, merge 0e152ac (after chunk 4's). Unit suite 880
OK on the branch, 919 OK merged; `postgres`' stack test all passed (8 min
28 s, armenelos), and `postgres-exporter`'s (1 min 38 s) and
`prometheus`' (1 min 18 s) against the final 0.5.0 image. TLS: TLSv1.3,
`verify-full` against the game's certificate, a plain connection turned
away, a seed leaving TLS off answering "does not support SSL"; pgaudit's
`DDL`, `WRITE`, `ROLE` lines in the file log, readable by `player`; no
password (nor SCRAM verifier) of any role in any node's log; `monitoring`
only on nodes choosing the option, its secret mounted only there, an
unknown option failing the container; `no-access` (`pdb`): no `player`,
no sudo rules, no `~/.pgpass`, ssh as player refused, sshd and
PostgreSQL up; the standby started while its primary was scaled to 0,
waited 14 s, cloned, streaming (`pg_stat_replication`), reads answered,
writes refused, `primary_conninfo` naming only the password file;
`gm-snapshot-db` leaving only the standby's slot; a switched segment
posted whole (16777216 bytes) with W1's headers and credential, a 503
and a short receipt failing honestly (segment kept `.ready`,
`failed_count` up), shipped on retry; the base-backup job posting once
(41,410,560 bytes) when moved to the next minute; the image build
asserting G5's conditions. Footprint at rest (512M limit): `rec` 32.4MiB
(TLS, pgaudit, the option, archiving, a standby attached), `standby`
36.2MiB, `pdb` 30.8MiB, `db` 32.4MiB, `db2` 29.3MiB; `rec`'s pgdata 136M
(`pg_wal` 113M), the standby's 152M.

Findings:
1. **G5's premise doesn't hold for pgaudit 18.0**: it redacts passwords
   itself (`password <REDACTED>`); PostgreSQL's own statement logging
   still writes them in clear (the stack test's canary under
   `log_statement = 'ddl'`). The guards stand (initdb with no preload
   library; load-data's password sessions `SET pgaudit.log = 'none'` and
   statement logging off). For `security-advisor`'s G8 and
   `spec-writer`, information only.
2. **A restart from the hand-over snapshot can't bring a standby back as
   one** (a base backup leaves out `standby.signal` and the primary's
   `pg_replslot/`, and the two copies are taken at different moments): a
   fresh clone is needed after the restore. That is `restart.py`'s,
   outside chunk 3's files; recorded under Known limits in `postgres`'
   `docs/gm.md`. A restart without a snapshot re-clones. **Sent to
   `spec-writer`** to rule: an inserted chunk, or a named known limit.
3. Files outside the list: `tools/gm/state.py` (`gmctl status` listing
   the certificate's two files) and the secret-list expectations in
   `test_fit`, `test_state`, `test_teardown`.
4. The format skill's `brick.yaml` template comment lists secret kinds as
   `password | key-pair`; `certificate` should join it (not checked by
   the loader). For the wave gate's fix list.
5. `no-access`: chunk 3 kept its own mechanism, alike in outcome to chunk
   4's (account files linked into `/run/gm-accounts`, an image-layer copy
   for `exec -u`), differing in filtering one baked copy at start, the
   sudoers file also linked into `/run` (absent on `no-access`), and the
   home volume left as it is.

**Capture W1-x — chunk 3 outcomes (`postgres` 0.5.0; read by 7, 8, 10,
11, 20, 23, 24)**, as the chunk owner reported:
- Rendering: `GM_OPTIONS` to a node whose brick declares `options:`;
  `GM_STANDBY_OF` to every `postgres` node (`""` when no standby);
  `vault_target` and `vault_credential` brick parameters (default null),
  passed as `GM_VAULT_*`; an option's secret mounted only on a node
  choosing it (`localimpl.unchosen_option_secrets`).
- Entrypoint: refuses an unknown option; `monitoring_password` required
  only with the option, `player_ssh_pubkey` not on `no-access`; initdb
  with no preload library and nothing logged, `monitoring` created only
  with the option; step 7 skipped when PGDATA holds `standby.signal`;
  `/run/gm-replication/pgpass` (`*:*:*:replicator:`) on a standby;
  `/run/gm-vault/{target,credential}` (postgres 0600) with a vault; a
  vault credential whose `http_<credential>` secret is missing fails the
  container (its mounts are chunk 7's: until then a scenario setting
  `vault_credential` fails to start).
- TLS: secret kind `certificate` (pair `tls`), files `tls.crt`,
  `tls.key`; P-256, CN the first `postgres` node, SANs every `postgres`
  node plus localhost, 365 days; `deploy.openssl_certificate`,
  `deploy.certificate_names`.
- pgaudit: `inject.NO_AUDIT_SQL` (`SET pgaudit.log = 'none'`) in the
  password, mapping and replication sessions.
- `clone-standby`: waits up to 120 s for the primary's `pg_isready`;
  stops postgres through s6; `pg_basebackup -X stream -C -S <slot> -R -w
  --checkpoint=fast --no-manifest`, `application_name` the standby's
  name; refuses a `primary_conninfo` holding a password; waits up to 120
  s for recovery; exits 0, 1 or 2.
- `load-data`: `standby_plan` lists the standbys (data, survey and grant
  skip them; a role naming a standby target gets its password on the
  primary); `replication_sql` creates or alters `replicator` (LOGIN
  REPLICATION, SCRAM verifier) and drops an inactive slot of the
  standby's name; the streaming wait `STANDBY_WAIT` 300 s or
  `--timeout`.
- `vault-post`: payload from the file, or standard input spooled to
  `/run/tmp`; `Content-Length`, `User-Agent: vault-post (<node>)`,
  timeout 60 s; a `basebackup` without tar's end-of-archive blocks
  refused; success prints one "shipped" line; exits 1 with no vault
  configured, 2 on bad usage.
- The crontab line needs its own `PATH=` line; the s6 run script exports
  `PATH` so `archive_command` finds `vault-post`. Slot name: the
  standby's node name, `-` read as `_`. The fault's precondition is
  prose (an orphan slot: `slot-name` other than the standby's); no fault
  version bump (6.7).
- Risks: `docker exec -u player` on a `no-access` node still finds a uid
  from the image's copy (only the GM can do that).
- The other bricks' stack tests using `postgres:0.5.0` (pgbouncer,
  scheduler, bastion, grafana) now run on chunk 3's image: wave gate.

### Chunk 5 — merged (c888d18), 2026-11-03

5a 1f744d1, 5b a259052, merge c888d18 (both halves written and tested
together at 5b's state; 5a not built alone). Unit suite 893 OK on the
branch, 919 OK merged; `check_brick_dir("bricks/api")` clean; the brick's
unit tests 36 OK (a throwaway PostgreSQL 17.11 in the image); stack test
88 PASS (about 3 min). Two hostnames each answering only its own routes,
the partners' node serving nine as aliases, an unknown hostname 404; 401
without, with a wrong or another endpoint's credential, before any body
is parsed; `player` edits `db/` and reloads (`gm-reload-api`), may not
touch `routes/` or `api.yaml`; three broken edits refused and named while
the server keeps answering; `no-access`: no `player`, no sudoers, ssh
refused, sshd up; the endpoint connects as its application role (never a
superuser), `SECURITY DEFINER` and the transaction-local setting never
outliving its request; started before its database it waits (bounded
30 s), answers 503, then 200; the image build asserting the 15 pins,
nothing else in `dist-packages`, `psycopg.pq.__impl__ == "python"` over
libpq 170011, no pip. Footprint at rest: `lab-api` (one hostname) 47M of
128M (RSS 53M), `partners` (nine) 43M (RSS 55M), CPU about 0.2 %; within
master spec 7.2's 96M and 128M. `brick.yaml`: limits 0.25 CPU and 128M,
reservations 0.1 CPU, 96M, 64M disk, `disk_growth_per_hour` 2M
provisional.

Deviations:
1. **A package beyond G6's set**: Debian trixie `python3-yaml`
   6.0.2-1+b2 (with `libyaml-0-2` 0.2.5-2), to parse `api.yaml`. The
   chunk owner asked `security-advisor` for a preflight first: **clear**,
   on safe loading only (the brick uses a SafeLoader subclass refusing
   duplicate keys) and `.tech`'s Python entry gaining `api 0.1.0 (with
   python3-yaml 6.0.2)` at G8. Recorded as gate **G11.1** (done,
   2026-11-03; its post-change check folded into G8).
   `requirements.txt` stays G6's 15 wheels, psycopg 3.3.7.
2. `no-access`: chunk 3's mechanism (account files kept in
   `/usr/local/lib/gm/accounts`, rewritten at start without `player`),
   not chunk 4's two baked sets. The bricks now use two variants
   (`postgres` and `api` one way, `scheduler` the other): a candidate
   for later unification, not a defect.
3. **Swarm DNS timing**: a health-checked task enters its service's DNS
   only once healthy, so a fresh `postgres` node (initdb included, 49 s)
   does not resolve within the 30 s bound (60 s failed alike). Kept 30 s
   (as `pgbouncer`); the test checks the wait ends within its bound; the
   endpoints answer 503 until the database is up (psycopg resolves at
   each connect). Documented in `api`'s `docs/gm.md`.

**Capture W1-z — chunk 5 outcomes (`api` 0.1.0; read by 7, 9, 11, 12,
15, 16, 18 to 21)**, as the chunk owner reported:
- Image: Debian 13, Python 3.13, G6's 15 wheels from a throwaway stage;
  Debian libpq5, python3-yaml, tzdata; s6-overlay 3.2.3.2
  checksum-pinned; openssh-server, sudo, curl, procps, perl. Accounts
  `api` 991:991, `apiconf` 992 (the group holding `player`). Server:
  `python3 -I -m uvicorn --factory gm_api.app:create_app --host 0.0.0.0
  --port 8000 --no-access-log --timeout-keep-alive 60
  --timeout-graceful-shutdown 5`, as `api`, `OTEL_SDK_DISABLED=true`; one
  process, plain `def` routes in AnyIO's 40 worker threads, an `async
  def` route refused.
- Paths: `/srv/api` the volume `endpoints`, seeded once; `api.yaml` and
  `routes/` root 0644, always protected; `db/` `api:apiconf`, 2775 with
  files 0664 when fixable, 2755 and 0644 otherwise; overrides may name
  only `/srv/api/db` or `/home/player`, none on `no-access`.
- Secrets: `role_<role>_password` and `http_<name>` checked (one line,
  no space), copied at each start to `/run/gm-api/secrets/` (`api`
  0400); a missing one stops the server, naming it.
- Start-up wait: 30 s per start on `getent ahosts` of every host
  `api.yaml`'s connections name.
- `gm_api.connection(name, session=None)`: pooled, as the role,
  autocommit off, `application_name` the hostname,
  `prepare_threshold=None`, TCP keepalives, 10 s connect timeout,
  uncommitted work rolled back on leaving. Pools `{size: N}` (30 s for a
  free session, then 503) or `{per-call: true}`. `session=` maps
  settings to values (`set_config(..., false)`, committed when the
  mapping differs; a setting no longer named is `RESET`): the players'
  lever. `gm_api.client(name)`: W1 item 3's wire form, `get`, `post`,
  `HttpError` (`.status` `timeout` or `refused`), one stale keep-alive
  retried once. Also `gm_api.HttpError`, `Unavailable`, `ConfigError`.
- Dispatch: the `Host` header (port removed, lowercased) picks one
  FastAPI app per hostname (`/docs`, `/redoc`, `/openapi.json` off); the
  matched route's endpoint credentials checked first (`Authorization:
  Bearer`, case-insensitive scheme, constant-time); 401 with
  `WWW-Authenticate: Bearer` and `{"detail":"unauthorized"}`; unknown
  host 404; a duplicate method and path on one hostname refused;
  `OperationalError` or `Unavailable` 503, any other exception 500.
- Request log `/var/log/api/api.log` (volume `apilog`, `api:apiconf`
  0640, never rotated): `<UTC ms>Z request status= ms= method= host=
  endpoint=<name|-> from= agent= path=<path?query>`; `error endpoint=…`,
  `start`, `stop`, `fatal` lines; the node's own checks use `*.invalid`
  hostnames.
- `gm-reload-api`: restores owners and modes, then report-only (exit 1),
  "the endpoints do not load; the server was NOT restarted …" with the
  first problem (exit 1), or "restarted the server …" (exit 0) after an
  s6 restart, waiting up to 60 s.
- Build checks (`gm_api.check`, at start, on reload, by the validator;
  first problem stops): both files regular; a route imports only
  FastAPI, Pydantic, the standard library and `db.<name>`; a `db/` file
  only psycopg, the standard library and `gm_api`; no relative import;
  both import, the route defines `router`, its routes plain `def`; every
  name a route takes from `db/` defined there; literal `connection`/
  `client` names match `api.yaml`'s connections by driver; no duplicate
  route on a hostname.
- Validator rules `config`, `server` (port 8000), `pending` (fingerprint
  against `/run/gm-api/loaded`), as `api`.
- Risks: import rules read `import` statements only (a `db/` file runs as
  `api` and can read the secret copies; accepted on access model 8's
  trust line); a reload drops in-flight requests (callers without retry
  log errors for a second or two); after a database restart each pooled
  session fails one request with 503; `disk_growth_per_hour`
  provisional.
- Images kept: `dbagm-test/api-unit:0.1.0`, `127.0.0.1:5000/dbagm/api:0.1.0`.

All five chunks merged. Next: G8 (`security-advisor`) and the open
points to `spec-writer`, then the wave gate.
