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

### G8 — dependency post-change check (security-advisor, 2026-11-03)

**Clear; one note for the owner.** `.tech` updated on `v0.5-w1`
(d7580ca). The resolved versions match the preflights: `postgres` 0.5.0
pgaudit `18.0-3.pgdg13+1`, `libssl3t64`/`openssl` `3.5.7-1~deb13u3`
(floor asserted), the snakeoil pair gone, HTTP::Tiny 0.088; PostgreSQL
18.6, pg_cron 1.6.8, cron unchanged; **pgBadger moved 13.2 → 13.3**
(unpinned; upstream released 13.3 today, a maintenance release).
`scheduler` 0.3.0: no new package. `api` 0.1.0: exactly G6's 15 wheels
plus Debian PyYAML 6.0.2, psycopg pure Python over libpq 170011, no pip;
`html.parser` imported by nothing (CVE-2026-15308 not reachable).
`bastion` 0.5.0 and `grafana` 0.3.0 are the same images as 0.4.0 and
0.2.0 (version lines only). osv-scanner on `bricks/api/requirements.txt`:
no issue.

OpenSSL 3.5.7, now a `.tech` platform as G5 asked, makes NVD show 22
advisories (18 at or above medium), all resolved in Debian (DSA-6465-1,
DSA-6531-1; every brick image carries deb13u3): false positives, the
class of the nginx, sudo, OpenSSH and python3.13 backports. `cve-watch
check`: 42 → 60 at or above medium (+18 OpenSSL). `.tech` gains the
`frameworks` line, Perl 5.40, pgaudit 18.0 and TLS, pgBadger 13.3, the
eight bricks' versions, `lockfiles = ["bricks/api/requirements.txt"]`,
platforms OpenSSL and pgaudit; PostgreSQL, libpq, pg_cron, cron, nginx,
cmark-gfm, OpenSSH, sudo and Python entries name the new bricks.
`SECURITY_TODO.md` unchanged; the next sweep after `main` takes this
will write about 18 OpenSSL items, to triage as Debian backports.

**For the owner, not blocking**: the pending ruling on `.tech` ignore
entries for triaged Debian backports now also covers OpenSSL 3.5.7
(proposed reason "fixed in Debian 3.5.7-1~deb13u3 (DSA-6465-1,
DSA-6531-1); NVD reads the upstream version", review 2027-02-01 or the
next rebuild moving `libssl3t64`); and whether to pin pgBadger for
reproducible images.

G8 **done (2026-11-03)**.

### Plan revision after the chunks, 2026-11-03

`spec-writer`, on the chunks' open points: build plan v3 (29ea5c1), spec
D352 (the restore gap a named known limit, not an inserted chunk: no v0.5
game restores a standby from a snapshot; release notes and v1.0 gating
name it; a re-clone in `restart.py` would be an inserted chunk 28 on the
owner's word), D353 (`register_diff`'s bare `true:` kept; chunk 6 reads
`True` or `"true"` through one shared accessor), D354 (`public` confirmed
for a public endpoint's connection value; formats.md line), D355 (both
`no-access` mechanisms kept), D356 (a bounded wait promises an honest
failure past its bound, not resolution within it; bounds stay 30 s),
D357 (text corrections: twelve faults, chunk 2's scenario, pgaudit's
redaction), D358 (wave 2's chunks 6 to 10 corrected against W1-w to
W1-z: chunk 6 repeats the HTTP connection checks at load, takes
third-party hostnames and `owners` as targets, checks `vault_*`,
`register_diff:`, does not re-add chunk 2's `domains:` checks; chunk 7's
Files gain three tests' secret lists; chunk 8 reuses `NO_AUDIT_SQL` and
`standby_plan`; chunk 9's fixture after chunk 7 if `clinic-api` names a
credential). D359 reserved by mistake, never used. No owner question.

### Wave gate — started 2026-11-03

On armenelos alone, the VPS drained, κ = 1 for the gate, every step
under the host lock and the sleep inhibitor; dispatched to a
`coding-executor` (verification level: wave gate) with two known fixes:
the `brick.yaml` template's secret kinds gaining `certificate` (chunk 3,
finding 4) and `tarnbeck-outdoor-campaign`'s stale classification
comment (chunk 2), its README regenerated.

### Wave gate — results, 2026-11-04

`coding-executor`, armenelos alone, 2026-11-03 23:20Z to 2026-11-04
00:33Z, κ = 1, every step under the host lock and the sleep inhibitor;
every item under 30 minutes. Logs:
`/tmp/claude-1001/-home-bastien-work-db-audit-gm/626ab41f-a466-4175-9a28-a4f76cedff0e/scratchpad/gate-w1/`
(session scratchpad, not kept).

| Item | Result | Wall |
|---|---|---|
| Unit suite (`tools/tests`), before and after the fixes | 919 OK, both | 145 s, 146 s |
| `bricks/scheduler` unit runner | 91 OK | 195 s |
| `bricks/api` unit runner | 36 OK | 4 s |
| `sh -n` (177 files), `perl -c` (9), `py_compile` (57 outside the suites) | 0 fail | ~2 s |
| Chunk 2's compose tests (`test_compose`, in the suite) | 27 OK | — |
| `postgres` 0.5.0 build / stack test | ok / 302 PASS | 0 s / 515 s |
| `scheduler` 0.3.0 (clean rebuild, rerun) | ok / 178 PASS | 11 s / 851 s |
| `bastion` 0.5.0 | ok / 90 PASS | 0 s / 82 s |
| `grafana` 0.3.0 | ok / 119 PASS | 0 s / 161 s |
| `api` 0.1.0 (clean rebuild, rerun) | ok / 88 PASS | 0 s / 195 s |
| `pgbouncer` 0.1.1 | ok / 120 PASS | 1 s / 173 s |
| `prometheus` 0.2.0 | ok / 131 PASS | 0 s / 78 s |
| `postgres-exporter` 0.2.0 | ok / 103 PASS | 1 s / 98 s |
| `smoke.sh` (after `1ddf90d`) | 61/61 | 29 s |
| `smoke-monitoring.sh`, twice | 43/43 | 52 s, 47 s |
| `smoke-governance.sh armenelos` (after `3aeb094`) | 121/121 | 105 s |
| `smoke-load.sh armenelos` | 73/73 | 423 s |
| `smoke-scenario.sh bookshop-new-server`, twice | 19/19 | 22 s, 21 s |
| `smoke-scenario.sh fernway-clinics-monitoring`, twice | 18/18 | 33 s, 30 s |
| `smoke-scenario.sh tarnbeck-outdoor-shop` | 26/26 | 836 s |
| `smoke-scenario.sh tarnbeck-outdoor-campaign`, before the fix | 27 PASS / 6 FAIL (harness, below) | 666 s |
| `smoke-scenario.sh tarnbeck-outdoor-campaign`, after `a100f5a` | 33/33 | 290 s |
| `smoke-scenario.sh bookshop-new-server`, after `a100f5a` | 19/19 | 22 s |

Wave 1's own items: the standby, cloned from `rec` on slot `standby`,
streams, is in recovery, answers a read-only query over TLS (a row
written after the clone included) and refuses a write; segment `…06`
switched and archived, a refused segment kept `.ready` and shipped once
the vault accepts; `api` with two hostnames: each of eight other
hostnames answers its own `GET /status`, an unknown one 404, the
footprint recorded at one hostname and at nine.

Image sizes (armenelos, 2026-11-04): `postgres:0.5.0` 262 MB,
`scheduler:0.3.0` 171 MB, `bastion:0.5.0` 186 MB (the 0.4.0 image ID),
`grafana:0.3.0` 866 MB (the 0.2.0 image ID), `api:0.1.0` 218 MB,
`pgbouncer:0.1.1` 182 MB, `prometheus:0.2.0` 488 MB,
`postgres-exporter:0.2.0` 165 MB. `/var` 36 GB free; nothing pruned.

Fix commits on `v0.5-w1`:
- `f9f57f0` (chunk 3, known): the `brick.yaml` template's secret kinds
  `password | key-pair | certificate`, the certificate pair's form.
- `da887a7` (chunk 2, known): tarnbeck-outdoor-campaign's
  classification comment (the shop's classes keyed with the `shop.`
  prefix); README regenerated, identical.
- `1ddf90d` (chunk 3): `smoke.sh`'s counts, configs+secrets 13 → 15,
  secret files 7 → 9 (`replication_password`, `tls_certificate`,
  `tls_key` on every node; `monitoring_password` only with the option).
- `3aeb094` (chunk 3): `smoke-governance.sh`'s copy of
  fixture-instances turns on `options: [monitoring]` for db (the
  `g2-own-role-kept` breach grants the `monitoring` role, which
  `postgres` 0.5.0 creates only with the option, master spec 7.1).

Run-1 mistakes of the executor's own, not defects: the two
`<playground>`-taking smokes called without it; `py_compile` left
`__pycache__` folders in seed folders, which `fit` refuses. Removed,
all eight images rebuilt (only `scheduler`'s and `api`'s IDs changed,
their contexts having held `__pycache__`; both stack tests rerun), steps
3 and 4 rerun.

**tarnbeck-outdoor-campaign through `smoke-scenario.sh`**: deployment,
data load, planting, all 12 validators and teardown passed from the
first run; six failures were the harness reading the scenario against
its design, no chunk regressing: `consent.unsubscribe` renamed `-v2` at
T0 by the timeline; the consumer's dashboard keys at 12/h, 6/h and 4/h
silent in 3 minutes; `check` exiting 2 on window-based `too-soon`
readings and f10's `error` (v0.4's wave log: as designed for a smoke
run). v0.4's gates ran this scenario through `smoke-purposes.sh` only,
whose `smoke` mode waits past 47 minutes for f8, over the 30-minute
rule. **Driver's ruling** (spec D367 words the gate item to match): a
harness fix on the wave branch, `a100f5a` (chunk 1, which holds
`smoke-scenario.sh`), a `coding-executor`, nothing a brick, fault or
scenario does changed:
- keys read through each schedule's timeline as render applies it (a
  change at or before T0 from T0; a change inside the judged minutes
  splits them);
- keys judged by rate with `smoke-purposes.py`'s own `expected_calls`
  and `JUDGED` (4), loaded, not copied: a silent key fails only when 4
  calls were expected; slower keys "not judged", their key lines still
  required (the campaign's two consent keys and four dashboard keys);
- `check`'s accepted readings derived from the scenario's files, no
  fault id written in: `present` always; `too-soon` too when the answer
  key's `sealed_check.judges` is `runs` or `triggers`; `error` too for an
  incident check (no `judges`, resolutions only `report`, master spec
  12.7: only `purpose-heavy-job-on-database-node`); the exit code must
  match the readings; a scenario expecting `present` everywhere is
  judged as before.
Rerun: campaign 33/33 (290 s; f1 to f4, f7, f8 `too-soon`, f10 `error`,
no `absent` or `fixed` anywhere), bookshop 19/19 (22 s, the same check
lines). Note: the poll now stops at the first run where every reading is
as expected, so a quick run may see f1 and f2 at `too-soon` where a
slower one saw `present`; both are the design's. **For the owner to
confirm or overrule.**
"Every fixture short test the wave's chunks ran, rerun": covered by the
stack tests above (the standby, archiving and two-hostname fixtures are
stack-test items).

Wave 1's gate **passed (2026-11-04)**, at `a100f5a`. Wave sync: none
(no intent register). Not merged into `main`: the owner's word.

### Wave 1 — report to the owner, 2026-11-04

- **Chunks merged**: 1 (1c76772), 2 (c9ab20c), 3 (0e152ac), 4
  (99d5398), 5 (c888d18); none moved, none blocked.
- **Gates**: G3, G4, G5, G6, G8, G11.1 done; G7 not needed; the wave
  gate passed (above), five fix commits (`f9f57f0`, `da887a7`,
  `1ddf90d`, `3aeb094`, `a100f5a`).
- **Rulings**: spec D344 to D358 (plan v2, v3); D359 unused.
- **For the owner, none blocking**:
  1. confirm or overrule the harness ruling above (`a100f5a`);
  2. G6: the project's first PyPI set and lockfile
     (`bricks/api/requirements.txt`, 15 hash-pinned wheels); a
     Debian-only policy would rework chunk 5;
  3. G8: `.tech` ignore entries for triaged Debian backports, now also
     OpenSSL 3.5.7 (18 NVD false positives); whether to pin pgBadger
     (13.2 → 13.3 between builds);
  4. D352: the standby-after-restore gap a named known limit (a re-clone
     in `restart.py` would be an inserted chunk 28).
- **Merge**: `v0.5-w1` → `main` waits for the owner's word; before it,
  `doc-ids compare main v0.5-w1`. Wave 2 goes on from `v0.5-w1` as the
  owner asked.

## Wave 2 — started 2026-11-04

Branch `v0.5-w2`, worktree `/home/bastien/work/db_audit_gm-wt/v0.5-w2`,
cut from the gated `v0.5-w1` at 3aeb094, not from `main`: the owner
asked the wave to go on without the merge ("work on the second wave
whenever the first one's done"). Chunks 6 to 11. No intent register,
so no documentalist preflight; the driver drafted capture W2 from the
chunks' **Architecture capture** lines, as W1. Wave 1's gate entry lands
on `v0.5-w1` and is merged in here.

### Capture W2 — v0.5 loader checks, render, load-data, the core, monitoring, the partners (chunks 6–11; read by 7–27)

Recorded 2026-11-04, before any code; drafted for the wave driver from
the **Architecture capture** lines of chunks 6 to 11 (plan v3, with its
header, "Read first", the dependency graph, "Left for the build" and
"The partners, and where each stub is built"), master spec 6, 7.2, 7.4,
8.5, 9.2, 10.2, 10.4, 11.2, 12.1, 14, 15 and 24, access model 5, 8, 9
and 10, [cold-storage.md](cold-storage.md) 2 and 3,
[third-parties.md](third-parties.md) 3, [vet-core-domain.md](vet-core-domain.md)
("Deterministic key ranges", "Application roles and grants", "The
applications and their nodes", "Loading"), [formats.md](../../formats.md)
v28 ("Purpose definition", "Domain", "Composing domains"), spec D344 to
D358, and the code on `v0.5-w1` at 4f8b341
(`tools/gm/{model,render,localimpl,deploy,inject,compose}.py`,
`bricks/{api,scheduler,postgres,postgres-exporter,bastion}/`). W1's
rules: cited, not restated; **(choice)** marks a point the sources left
open, settled here with its reason; each item names the chunk that
writes it and the chunks that read it. Held: W1 items 0 to 8 and its
addenda W1-w (chunk 2), W1-x (chunk 3), W1-y (chunk 4), W1-z (chunk 5);
where the merged code differs from W1, the code and the addenda win.
Chunks record their as-built outcomes as **W2-a** (chunk 6), **W2-b**
(chunk 7), **W2-c** (chunk 8), **W2-d** (chunk 9), **W2-e** (chunk 10)
and **W2-f** (chunk 11).

**0. Names shared by the wave** (read by 6 to 27)

- **A partner's prefix** `[a-z][a-z0-9]{0,15}` **(choice)** is its
  folder's name, `producers/partners/<prefix>/` (or `partners/<prefix>/`,
  item 6), its role and its schema on the partners' database, its keys
  `<prefix>.<…>`, its endpoints `<prefix>_<…>` (W1 item 0) and its
  connections `<prefix>-<…>`. Reason: one token valid as a role, a
  schema, a Python module and a key, with neither `_` nor `-`, so every
  split is unambiguous. One folder may serve several hostnames
  (`vet-core`'s `centres`: two centres and the centres abroad, D306).
- **The partners' database** is `partners` **(choice)**, on the
  `postgres` node every `third_parties:` entry with nodes lists (the
  shared nodes as compose finds them, W1-w), created by that node's
  data file (item 6). Reason: one fixed name lets a domain's partner
  material, a coherence query and a history file name it without the
  scenario.
- **Reserved (choice)**: `owners` is never a node's name, a
  `third_parties:` id or hostname (10.2: the tenth hostname, no
  business); `partners` is never a domain id (it names the partners'
  database in a coherence query's `reads`, item 3); schemas `gm_src_*`
  and functions `pg_temp.core_*` are load-data's and the core's (items
  3, 4).

**1. The loader's v0.5 checks** (chunk 6 writes, W2-a records; read by
7, 8 and every chunk loading a scenario or fixture). Scope as the plan
states it (6a, 6b, spec D350, D353, D354, D358); these points fix what
it leaves open.

- **`model.node_creates(sdir, data, node, catalog_root)` (choice)**: the
  `DataFileCreates` of what is created on a `postgres` node: its data
  file's (`node_data_file_creates`), plus, for every `domains:` entry
  placed there, each `at:` database and the roles and databases its
  schema and load files create, plus, on the partners' node, each
  composed domain's partner `data.sql` (item 3). The location check
  (`_location_problem`: purposes' parts, governance locations), the
  crontab roles' check and the governance readers' check read it;
  `localimpl.data_login_roles` (chunk 7) and `inject.password_plan`
  (chunk 8) switch to it (Preflight corrections, item 2). Reason: a
  composed scenario's `records/clinic` is created by `load-data` from
  the domain (item 3), not by `records`' data file, so the v0.4 check
  would refuse every location in it.
- **A monitor's targets (choice)**, read per brick from its seed:
  `postgres-exporter`'s `exporter.conf` (`DATA_SOURCE_URI`'s host),
  `pgwatch`'s `sources.yaml` (each enabled entry's `conn_str` host, the
  URI form only) and `health-check`'s `health.yaml` (`instances[].host`)
  (item 5). Each target is a `postgres` node choosing `monitoring`; a
  monitored standby's primary chooses it too (the role is the
  primary's, cloned: W1-x); a third-party node is never a target (7.4,
  "never the partners' database"). The gap is accepted only when a
  fault instance whose fault declares `option_absent: monitoring` has
  that target as its node. Reason: three known readers cost less than a
  new `brick.yaml` key, and the fault's node is where the gap lies.
- **`third_parties:`** (10.2, W1 item 2), with these **(choices)**:
  - **hosts and hostnames agree**: on the api node the entries list,
    the set of its `api.yaml` hosts equals the hostnames of the entries
    naming nodes, plus `owners` when listed; the node's own name is
    never among them; on every other `api` node, an endpoint's hosts
    are exactly `[<its own name>]`. A hostname on an entry with
    `nodes: []` aliases nothing (documentation only). Reason: item 2
    reads the aliases from the hosts, so this equality is what makes
    the declaration authoritative;
  - **the partners' roles are theirs alone**: a role a third-party
    node's SQL connection names is named by no other node's connection
    or `crontab_roles` (10.2: their passwords mounted on the partners'
    nodes only, which render then guarantees, one secret per role);
  - **the third-party `pg_hba.conf` form**: every line is a DO NOT
    TAMPER line (the template's), a `reject` line, or `host partners
    <roles> <address> scram-sha-256` whose roles are the partners'
    (above); the last line is `host all all all reject`. The address
    field is not checked: its form on one Swarm network is chunk 11's
    measurement (10.2, item 6), and `samenet` the starting form;
  - a composed domain with a partner `data.sql` needs a partners'
    `postgres` node (else refused, naming the folder).
- **HTTP targets (choice)**: a connection's `target` host (schedule,
  `api.yaml`, `vault_target`) is a node or an alias (an `api` node's
  host other than its name, item 2); on an `api` node or an alias the
  port is 8000 (W1 item 5). Credentials: `[a-z][a-z0-9_]{0,62}`, never
  `public` (W1-y, D354), no cross-check between caller and endpoint
  (a mismatch is a 401 in play, fault surface).
- **`web_routes`**: no third-party node and no alias, with no exception
  in chunk 6; cold storage's route is chunk 17's (Preflight
  corrections, item 5).
- **A standby is no location (choice)**: an `at:`, a purpose's location
  part and a governance location never name a standby. Reason: every
  load step skips it (W1-x); it holds only its primary's copy.
- **A receiver is a declared third party (choice)** only in a scenario
  with `third_parties:` or `domains:`; the four existing scenarios keep
  v0.4's `receiver` (`gateway`, 17.5's seeds kept).
- **`SECURITY DEFINER` (choice)**: in a domain's `schema.sql`,
  `load.sql`, `derive.sql`, `keys.sql` and partner `data.sql`, each
  `CREATE [OR REPLACE] FUNCTION|PROCEDURE` statement holding `SECURITY
  DEFINER` holds a `SET search_path` clause whose value never names
  `"$user"`; checked by `check_domain_dir` (15).
- **`register_diff:` (choice)**: the accessor is
  `model.register_diff_true(item)` (the value under `True` or `"true"`,
  D353), read by chunks 17 and 23.
- **A partner folder** `producers/partners/<prefix>/` (and `public/`)
  accepts one file `data.sql` beside its fragments (`_check_fragments`;
  compose already skips it as "the other half") **(choice**: item 3's
  partner state**)**.
- **Out (choice)**: a domain's `data/coherence.yaml` is not checked by
  `check_domain_dir` in v0.5; `load-data` refuses a malformed one before
  any query runs (item 3). Reason: chunk 8 owns its shape and no chunk
  holding `model.py` follows it before chunk 17.

**2. Render: aliases and HTTP credentials** (chunk 7 writes, W2-b
records; read by 11, 12, 15 to 21, 23, 27). Master spec 10.2, 15;
spec D347.

- **The aliases come from the `api.yaml` hosts (choice)**, the point
  `spec-writer` left to W2 (D347, D358): every `api` node gets as
  network aliases the hosts its seed `api.yaml` lists other than its own
  name, sorted, unique; with chunk 6's checks that is the partners' node
  alone, and its set equals the `third_parties:` hostnames plus
  `owners`. Reasons: one rule with no special case for `owners`, which
  has no `third_parties:` entry; the network then resolves exactly what
  the server dispatches (no alias answering only 404, no served host
  unresolved); render already reads `api.yaml` (D345, below); the
  declaration still governs through chunk 6's equality, so on any
  loaded scenario both sources give the same set.
- **The stack file (choice)**: a service with aliases takes
  `networks: {<network>: {aliases: [...]}}`, every other keeps the list
  form (`[<network>]`), so v0.4's stack files render unchanged;
  `implementation.yaml`'s node entry gains `aliases` when non-empty. An
  alias enters Swarm's DNS once its task is healthy (D356).
- **HTTP credentials**: one password secret `http_<credential>` per name
  per game, not handed over (32 characters, the dba alphabet), mounted
  at `/opt/gm/secrets/http_<credential>`, 0:0 `"0400"` (W1 item 0;
  read there by the scheduler's run script, W1-y, the `api` entrypoint,
  W1-z, and `postgres`' entrypoint, W1-x) on: a scheduler node for each
  `credential` its `schedule.yaml` connections name; an `api` node for
  each name in its `api.yaml` endpoints' `credentials` and connections'
  `credential`; a `postgres` node for its `vault_credential`
  **(choice**: what each node names, as role secrets are; no node holds
  a credential it neither sends nor checks**)**. `_derived_lengths`
  counts the `http_` names (a long credential shortens the game id, as
  a long role does).
- **Login roles a domain creates** get their `role_<role>_password`
  (master spec 9.7 of v0.4, `data_login_roles` reading
  `model.node_creates`, item 1).
- Its two-node fixture: a scheduler caller and an `api` node with one
  alias, declared under `third_parties:` (the node `no-access`), so it
  still loads once chunk 6's checks merge (Preflight corrections,
  items 2 and 4).

**3. `load-data`: the composed load, derivations, history, coherence**
(chunk 8 writes, W2-c records; read by 9, 12 to 16, 18 to 21, 26, 27).
Master spec 8.5, 12.1 item 5, 15; formats.md "Composing domains".

- **Domains and purposes are read from the catalogue (choice)**: each
  `domains:` entry's files from `<catalog>/domains/<id>/`, each
  `purposes:` entry's `history` from `<catalog>/purposes/<id>/` (the
  path its `purpose.yaml` names), the catalogue being the one the
  scenario loads against (`model.REPO_ROOT`, a test's `catalog_root`),
  as compose and `check_domains_entries` read it. Reason: compose
  copies no data; D23's self-sufficiency is "with the full repository";
  domains and faults never bump and are both read from the catalogue.
  The scenario keeps its classification copy (formats.md).
- **The database convention (choice)**: `load-data` creates each `at:`
  database absent from its node (owner `postgres`) and revokes `CONNECT`
  from `PUBLIC` on every database it creates; a domain's `schema.sql`
  and `load.sql` are run connected to their database (`psql -d <db>`),
  never create or `\connect` to one, create their roles at top level,
  and name their database as psql's `:"DBNAME"` (`GRANT CONNECT ON
  DATABASE :"DBNAME" TO vet_app`, as vet-core grants `CONNECT` by name).
  Reason: a part lands in its core's database or its own (`at:`), so
  the name is the scenario's; the shop's v0.4 schema (`CREATE DATABASE
  shop`) stays as built for `domain: shop` and is composed through
  `domains:` by no v0.5 scenario.
- **The core's key functions (choice)**: a core may ship
  `data/keys.sql` (a fixed path, no `domain.yaml` key), defining
  `pg_temp.core_<name>(…)` functions (item 4); `load-data` streams it
  ahead of the core's `load.sql`, each part's `load.sql`, each partner
  `data.sql` and `derive.sql`, in the same session, so the functions
  vanish with it and nothing reaches the catalog the players read.
  Reason: five parts and three stubs compute the same ids "never
  reading `clinic`" (9.2); one text keeps them equal, and the coherence
  check catches the rest.
- **One reference moment (choice)**: every file `load-data` runs gets,
  beside v0.4's `customer_timezone` and `customer_utc_offset`, `-v
  load_epoch=<the run's start, UTC, ISO 8601, to the minute>`; a load's
  "now" is `:'load_epoch'::timestamptz`, never `now()`. Reason: the
  parts load in separate sessions minutes apart, and a stay computed at
  two moments disagrees with itself across instances.
- **A partner's tables and state (choice)**: each composed domain's
  `producers/partners/<prefix>/data.sql` is run into the partners'
  database as `postgres`, after that domain's own load, folders in name
  order: it creates the role `<prefix>` (`LOGIN`, no password: render's
  secret, set by the password step), the schema `<prefix>` owned by it,
  the partner's tables and its planted state (the send-outs open at T0,
  9.3). Reason: no later chunk holds `inject.py`, and wave 3's first
  stubs (chunk 12) need it.
- **The order (choice)**: (1) the nodes' data files, as v0.4 (they
  create the databases no domain holds: `office`, `partners`); (2) the
  domains in `composition.yaml`'s `order`, each database's `schema.sql`
  then `load.sql` (a several-database part in `databases` order), then
  its partners' `data.sql`; (3) the sanctioned derivations, in
  `derive` order; (4) each `purposes:` entry's history, in list order;
  (5) the coherence check; (6) v0.4's passwords, survey, mappings,
  grants and `pg_cron` clean-up (now after the domains' roles exist);
  (7) the standby's clone, last (W1 item 6). Every step skips standbys
  (`standby_plan`, W1-x).
- **Reading another database (choice)**: before a derivation, a history
  file or a coherence query, `load-data` creates in the database it
  runs in, for each source, `postgres_fdw` (dropped after if it created
  it), a server `gm_src_<name>` (the socket `/run/postgresql` on the same
  instance, `<node>:5432` on another), a user mapping for `postgres` as
  `gm_check` with its secret, and imports the source's `public` into
  schema `gm_src_<name>` and each other schema `<s>` into
  `gm_src_<name>_<s>`; afterwards it drops every `gm_src_*` schema and
  server, cascading. `<name>`: a domain id with `-` read as `_`
  (`vet_core`), `<id>_<database>` for a several-database domain,
  `partners` for the partners' database, a purpose part's name
  (`source`). Through `gm_check` because its DO NOT TAMPER lines
  (`local all gm_check scram-sha-256`, and `host all gm_check samenet`
  in every scenario with `governance:`, which every composed scenario
  has, D335) already admit it with `pg_read_all_data`, so no seed
  changes. **Unseen on both ends**: `NO_LOG_SQL`, `NO_STATS_SQL` and
  `NO_AUDIT_SQL` in the local session; on each source, `gm_check`'s
  role settings (`log_statement`, `log_min_duration_statement`,
  `pg_stat_statements.track`, `pgaudit.log`) set before and reset
  after, by `postgres`, unseen. A source needing to be written (none in
  v0.5) is out of this rule.
- **`derive.sql`** runs in its part's database, its sources the
  domains of `derive.after`. **History** runs in the purpose entry's
  `target` location, its sources the entry's other location parts
  (`gm_src_source`). Purpose 14's planted manifests meet the rule by
  naming the partners' database as its target (for W4; Preflight
  corrections, item 9).
- **The coherence queries (choice)**: a domain's optional
  `data/coherence.yaml`:

  ```yaml
  checks:
    - id: stays-placed              # [a-z][a-z0-9-]*, once in the domain
      what: every current stay placed in a unit   # one line, the report's
      database: clinic              # optional: one of databases, for a several-database part
      reads: [vet-core]             # optional: composed domains or partners, through gm_src_<name>
      sql: |                        # one SELECT: the offending rows, none when coherent
        SELECT s.id AS stay_id FROM gm_src_vet_core.stays s ...
  ```

  Run once, after the histories, as `postgres` in the domain's
  database, `READ ONLY`, unseen; a check whose `reads` names a domain
  not composed is skipped and reported so (a cross-part check runs only
  when both are composed). A part carries its references to its core
  and the histories it shares (8.5); the core carries none. Any row
  fails the setup as a design error (`state.SetupFailed`), naming the
  domain, the check, its `what`, the row count and the first ten rows.
- **The record (choice)**: `coherence: {run_at, result}` rewritten in
  `composition.yaml` (that key only, the file's other lines byte for
  byte), each check's outcome in the game's `state.yaml`. Reason: 15
  names the record; the per-check detail is the game's, as its stages
  are.
- A contrib extension in a part's schema runs as `postgres` (24): no
  step of its own.

**4. `vet-core`'s keys and its lookup API** (chunk 9 writes, W2-d
records; read by 12 to 16, 18 to 21, 27). Master spec 9.2,
[vet-core-domain.md](vet-core-domain.md).

- **"Core keys" in `docs/gm.md`**, the chunk's first deliverable: 9.2's
  ranges table, then each function as `pg_temp.core_<name>(…)`, its
  arguments, what it returns and its formula as the SQL of `keys.sql`
  (item 3). **(choice)** The names the parts' "Core keys used" cite:
  `core_staff` (kind, section, specialty), `core_species`,
  `core_microchip`, `core_ueln`, `core_passport`, `core_ear_tag`,
  `core_holding`, `core_death`, `core_consultation`, `core_stay`,
  `core_stay_alert`, `core_request`, `core_referring_practice` (a
  referring vet's practice, the mapping 9.3 reads), each `IMMUTABLE`
  but for its `load_epoch` argument where it computes a time. Reason:
  9.2's function table, one name per row, and nothing a part must
  re-derive.
- **`clinic-api`'s lookup contract (choice)**, on port 8000 under the
  hostname `clinic-api`, connection `clinic` as `vet_lookup`:
  - endpoint `animals`: `GET /animals/{id}` (the animal's identity
    columns `vet_lookup` reads, never the death columns, never a
    contact), `GET /animals?microchip=|ueln=|ear_tag=` (exactly one;
    a JSON list, `[]` when none, so an unknown identifier is told from
    an unknown route), `GET /animals/{id}/owner` (`{id, kind, name}` of
    the current owner);
  - endpoint `stays`: `GET /stays?current=true` (a list of `{stay_id,
    animal_id, section_id, admitted_at, name, species}` by `stay_id`;
    any other `current` 422);
  - JSON keys the column names, times ISO 8601 UTC with `Z`, 404
    `{"detail": "not found"}`, the brick's 401 (W1-z);
  - one credential, `clinic_lookup`, for every caller in the estate.
    Reason: a fragment merges `endpoints.<name>` whole (W1 item 7), so a
    part adding its caller's credential to the core's endpoint would
    conflict; the exchange endpoints and their credentials are chunk
    19's.
- Its fixture deploys `domains: [vet-core]` through `load-data`, so it
  runs once chunks 7 and 8 have merged into its branch (Preflight
  corrections, item 3).

**5. The monitoring breadth** (chunk 10 writes, W2-e records; read by
6, 27). Master spec 7.4, 14; O223, O225, O226.

- **`pgwatch` (choice)**: seed file `sources.yaml`, pgwatch's YAML
  sources format (6.1.0, G9; checked against that release's format by chunk 10), one entry per instance in scope,
  `conn_str: postgresql://monitoring@<node>:5432/postgres` (the URI
  form, no password: libpq's `PGPASSFILE` under `/run`, W1 item 0);
  its Prometheus sink on port **9188**, path `/metrics`. Reason: 9187
  is the exporter's; one port per kind keeps Prometheus' target list
  readable. The scenario's `prometheus.yml` gains `job_name: pgwatch`,
  `targets: ['pgwatch:9188']`; node-health on 9110 on both new nodes
  (7.5).
- **`health-check` (choice)**: seed file `health.yaml`, `instances:` a
  list of `{name, host, port, dbname}` checked as `monitoring`; the
  crontab runs `check_postgres` over them every five minutes; seed
  folder `scripts/`, each customer script a Nagios plugin (one line,
  exit 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN) on its own crontab line,
  its result on the page. The page under `/health/` on port **8080**,
  the brick's interface `{name: ui, protocol: http, port: 8080,
  web_path: /health/}`, routed `health: "health:8080"`. Reason: the
  bastion's front proxies `/<route>/` unchanged (`_check_web_routes`);
  the plugin convention is the tooling the node stands for. The backup
  script asks `GET http://cold-storage:8000/manifests?type=basebackup&from=<yesterday>`
  (item 6, public).
- **pgCluu** folds into the unreleased `postgres` 0.5.0 (6.7); chunk 10
  is the only wave-2 chunk building the `postgres` image (item 7).

**6. The partners' shared nodes and cold storage** (chunk 11 writes,
W2-f records; read by 12, 16, 18 to 21, 23, 26, 27). Master spec 10.2,
10.4, 11.2; access model 10; cold-storage.md 3.

- **The shared nodes**: `partners-api` (`api`), `partners-backend`
  (`scheduler`), `partners-db` (`postgres`), each `no-access`, named as
  10.2 names them.
- **Where the shared material lives (choice)**: a new catalogue folder
  `partners/`, holding `shared/` (the three nodes' base: `partners-db`'s
  `pg_hba.conf`, `postgresql.conf` and data file creating `partners`)
  and `coldstore/` (item below), laid out as a domain's partner folder;
  the GM copies them into a scenario as it copies a purpose's material
  (endpoints into `compose/partners-api/`, DDL into `partners-db`'s data
  file). Reason: cold storage serves the `postgres` brick's archiving in
  any scenario and purpose 14, neither one domain nor one purpose (24
  leaves its home to the build), and a domain's folder would force
  composing that domain for the vault alone.
- **A domain's partner joins** through compose (W1-w): its folder's
  back-end fragments onto `partners-backend`, its `api.yaml`, `routes/`,
  `db/` onto `partners-api`, its `data.sql` into `partners` (item 3);
  its SQL connections `<prefix>-db: {target: partners-db:5432/partners,
  role: <prefix>}`.
- **Ticks (choice)**: the back end's streams call each partner's own
  tick routes on its hostname, endpoints `<prefix>_tick…`, accepting one
  credential, `partners_backend`, mounted on the two partner nodes only.
  Reason: an undocumented route a player finds answers 401 (access model
  10, "refused"), and one credential serves every partner without a
  merge conflict.
- **A partner's calls to the customer (choice)** set `User-Agent: <its
  hostname>` (allowed: only `Authorization` and `Host` are the clients',
  W1-y, W1-z), so the customer's logs show `agent=northfield-lab`. Known
  limit: every partner calls from `partners-api`'s address (one network,
  D275).
- **A misbehaviour key (choice)**: each prefix's table `<prefix>.state
  (hostname text, name text, value text NOT NULL, set_at timestamptz NOT
  NULL DEFAULT now(), PRIMARY KEY (hostname, name))`, planted by its
  `data.sql`, read by its routes at each request; on the back end one
  stream per prefix, `{key: <prefix>.normal, connection: <prefix>-db,
  rate: 1/min, arrivals: even}`, its key upserting the baseline rows. A
  fault's key `<prefix>.<behaviour>` (fault template's
  `partner_behaviour.key`, `xlab.outage`) is a back-end query upserting
  other values, added by its material in `compose/partners-backend/`;
  `placed: timeline` is a timeline change of `<prefix>.normal`'s stream
  to that key at the planting moment, `placed: standing` the same at
  `T0`. Reason: a key the timeline switches, read by the partner's own
  routes, never a stop of a shared node (10.2, 7.2), with the scheduler
  as built.
- **Cold storage (choice)**, prefix `coldstore`, hostname `cold-storage`
  (10.4), on `partners-api`:
  - `POST /shipments`: W1 item 6's headers and body, credential
    `cold_storage` (the customer's one account key: `vault_credential`
    and purpose 14's connection), receipt 201 as W1 item 6;
    `rows_received` the NDJSON lines for a data type, 1 for a non-empty
    `wal` or `basebackup`; a shipment id again replaces its manifest;
  - `GET /manifests` and `GET /`, public (no credential: the bastion's
    route carries none, 7.3, and the health script calls it):
    `/manifests?type=&from=&to=&source=` (dates `YYYY-MM-DD`, inclusive,
    against the manifest's range), a JSON list by `received_at`; `/` an
    HTML page with an inline SVG drawn by the route, the last five weeks
    per type, declared against received;
  - the manifest: `coldstore.manifests (shipment_id text PRIMARY KEY,
    type, source, name, rows_declared, rows_received, size, date_from,
    date_to, received_at)`;
  - planted: `wal` and `basebackup` manifests for the weeks before T0 by
    a snippet in `partners/coldstore/` the GM copies into
    `partners-db`'s data file with the scenario's archiving nodes; the
    data types' by purpose 14's history (item 3).
- **`pg_hba.conf`** as item 1's form, `samenet` its starting address;
  chunk 11 measures it on one Swarm network (and that one slow partner
  never holds another's), records both in W2-f and its seed; the form
  joins `postgres`' `docs/gm.md` at the wave gate (plan).

**7. Wave 2 coordination** (for the driver and chunks 6 to 11)

- **Order**: 6, 7 and 8 first; 10 at the first free slot (G9 cleared);
  9 cut once 6 has merged, its fixture run once 7 and 8 have; 11 cut
  once 6 and 7 have. Chunk 6 merges before 7, 8 and 10 (Preflight
  corrections, item 2; 10 as planned).
- **Files**: `model.py` is chunk 6's; `render.py`, `localimpl.py`,
  `deploy.py` chunk 7's; `inject.py`, `coherence.py` chunk 8's;
  `bricks/postgres/{Dockerfile,docs/}` chunk 10's; the scenario-format
  skill chunk 6's then chunk 8's (Preflight corrections, item 6); the
  root `README.md`'s tables and layout are shared lists.
- **Images**: chunk 10 alone rebuilds `postgres:0.5.0` (pgCluu, folded
  in); chunks 8, 9 and 11 test on the tag as it stands, with or without
  pgCluu, and rebuild it from no branch of theirs.

**Choices made here, not in the spec** (for the driver's review): the
partner prefix and its uses; the database `partners`; `owners`,
`partners`, `gm_src_*`, `pg_temp.core_*` reserved; `model.node_creates`;
monitors' targets read per brick, the primary of a monitored standby,
the exception on the target node; hosts and hostnames agreeing; the
partners' roles theirs alone; the third-party `pg_hba.conf` form, its
address unchecked; HTTP targets, port 8000 on an `api` target, no
credential cross-check; no standby as a location; the receiver rule only
for v0.5-shaped scenarios; the `SECURITY DEFINER` reach;
`register_diff_true`; `data.sql` in a partner folder; `coherence.yaml`
outside `check_domain_dir`; aliases from the `api.yaml` hosts; the
stack's aliases form and `implementation.yaml`'s `aliases`; which nodes
mount which `http_` secret; domains and histories read from the
catalogue; the database convention and `:"DBNAME"`; `data/keys.sql`
streamed ahead of each load; `load_epoch`; partner `data.sql` loaded into
`partners`; the load order; `gm_src_*` through `gm_check`, unseen on both
ends; derive's and history's sources; `coherence.yaml`'s form and run;
the record's two places; the core's function names; `clinic-api`'s
lookup contract and `clinic_lookup`; `pgwatch`'s `sources.yaml` and port
9188; `health.yaml`, Nagios-style scripts, port 8080; the `partners/`
catalogue folder; tick routes and `partners_backend`; the partner's
`User-Agent`; the state table and the misbehaviour key; cold storage's
endpoints, `cold_storage`, public reads, the manifest, its planting.

### Preflight corrections for spec-writer

1. **A partner's tables and planted state have no loader** (master spec
   9.3, 9.7 "the partners' database planted from the same functions";
   chunks 6, 8, 12, 16, 19). No chunk loads a domain's partner state
   into the partners' database, and no chunk after chunk 8 holds
   `inject.py`. Proposal: W2 items 1 and 3: chunk 6's scope gains
   `data.sql` in a partner folder; chunk 8's gains running it, with
   `data/keys.sql` streamed ahead of every part's load and partner
   file, and `load_epoch`; chunk 9's Files gain `data/keys.sql`.
2. **Composed domains create databases and roles the loader does not
   see** (chunks 6, 7, 8). The location, crontab-role and governance
   checks, `localimpl.data_login_roles` and `inject.password_plan` read
   only a node's data file, so every composed scenario's
   `records/clinic` is refused as a location and a domain's login roles
   get no secret. Proposal: W2 item 1's `model.node_creates` in chunk
   6's scope; chunks 7 and 8 switch their reader to it; merge-order
   edges `6 ──> 7` and `6 ──> 8` (no start delayed: 9 and 11 already
   wait for 6).
3. **Chunk 9's fixture needs chunk 8** (dependency graph). It deploys
   `domains: [vet-core]`, which only chunk 8's `load-data` loads; the
   plan has no `8 ──> 9`. Proposal: an in-wave edge `8 ──> 9` for its
   fixture (as the W1-z note already holds it for chunk 7), the branch
   cut once chunk 6 has merged.
4. **Chunk 7's fixture is not in its Files** (its Done when names "a
   two-node fixture"). Proposal: `tools/tests/fixtures/fixture-alias/`
   (new).
5. **Cold storage's `web_routes` exception cannot be built in chunk 6**
   (chunk 6's scope: "none in the bastion's `web_routes` but cold
   storage's read-only paths"). The route's form is chunk 17's (the
   front, `render.web_routes_value`), and the `api` brick declares no
   web interface. Proposal: chunk 6 refuses every third-party node and
   alias in `web_routes`; chunk 17's scope gains the exception in
   `model._check_web_routes` (it holds `model.py` in wave 4).
6. **The scenario-format skill is in no wave-2 chunk's Files**. Chunk 6's
   checks and chunk 8's files (`data/keys.sql`, `data/coherence.yaml`
   with a template, partner `data.sql`, the database convention) need
   the skill's checklist and templates. Proposal: both chunks' Files
   gain `.claude/skills/scenario-format/`, chunk 8 after chunk 6 (item
   2's edge).
7. **formats.md and master spec 5, after the build**: the `partners/`
   catalogue folder (cold storage's home and the shared nodes' base);
   `data/keys.sql`, `data/coherence.yaml`, a partner folder's
   `data.sql`; a domain's schema never creating its database
   (`:"DBNAME"`); and formats.md's "A domain is a design-time source:
   the GM copies its files into the scenario", stale for composed
   domains, which `load-data` reads from the catalogue (W2 item 3).
   Chunk 11's Files gain `partners/` and the root `README.md`'s layout
   row.
8. **No chunk hands an HTTP credential to the players** (10.2: "with the
   credentials the starter pack gives"; access model 10,
   `documented-call`). Every `http_` secret is generated and not handed
   over (W2 item 2). Proposal: chunk 17 adds the documented credentials
   to the bastion's page, or `partners.md` documents public endpoints
   only; to place before wave 4. Blocks no wave-2 chunk.
9. **Ordering risk for W4**: chunk 8 is the last chunk holding
   `inject.py`. Purpose 14's planted manifests (cold-storage.md 2)
   must fit W2's history rule (its target the partners' database);
   should W4 need another form, it is an inserted chunk.
10. **The health node's backup script is first read end to end at G13**:
    chunk 10's fixture has no cold storage, and chunk 11's has no health
    node. Proposal: chunk 10's stack test answers `GET /manifests` with a
    stand-in, as chunk 3's did for `POST /shipments`.

### Questions for the owner

None.

### W2 reviewed by the driver, 2026-11-04

The 35 **(choice)** points taken as written; none needs the owner. The
ten preflight corrections went to `spec-writer` before any chunk was
cut (next entry). Chunks record their as-built outcomes as W2-a to W2-f.

### Plan revision before wave 2, 2026-11-04

`spec-writer`: build plan v4 (8d8273f), spec D360 to D367:
- D360 (corrections 1, 2): chunk 6 adds `model.node_creates` and a
  partner folder's `data.sql`; chunk 8 runs it into `partners`, streams
  `data/keys.sql` ahead of each load, passes `load_epoch`; chunks 7 and
  8 read `node_creates` and merge after chunk 6.
- D361: wave 2 keeps two three-chunk completion chains (6, 7, 11 and
  6, 8, 9), one more than the model's rule; no start delayed, W2 fixes
  every interface they cross. Moving 9 and 11 to wave 3 (seven chunks)
  rejected.
- D362 (corrections 3, 4, 6, 10, 7's Files): Files lines, the edge
  7, 8 → 9 (chunk 9's fixture), the `GET /manifests` stand-in in chunk
  10's stack test.
- D363 (correction 5): chunk 6 refuses every third-party node and alias
  in `web_routes`; chunk 17 adds cold storage's one exception.
- D364 (correction 7): new gate G16, spec-writer writes the as-built
  format items into formats.md and master spec 5 after wave 2's gate;
  blocks release gate item 6 only.
- D365 (correction 8): chunk 17 hands players the credentials
  `partners.md` documents, with the starter pack (the customer's own
  credential with each partner, at its game value; `cold_storage` never
  handed over). By access model 3, 6 and master spec 10.2. **For the
  owner, not blocking**: a separate player credential per partner would
  change chunk 12's `api.yaml` (wave 3); rule before then if wanted.
- D366 (correction 9): purpose 14's ordering risk on chunk 21's capture
  line (W4).
- D367 (from wave 1's gate): the full quality command's
  `smoke-scenario.sh` item judges each scenario against its own design
  within the smoke's minutes.
D359 and O228 reserved by mistake, unused. `doc-ids lint spec`: 0 errors.

### G9 — dependency preflight on the monitoring breadth (security-advisor, 2026-11-04)

**Clear, with conditions; one text correction (pgwatch's line).** Resolved
in throwaway `debian:13-slim` containers (Debian 13.7, PGDG where named);
nothing written, every container removed.

- **pgwatch 6.1.0** (2026-10-26), not a 3.x release: 3.x ended at 3.7.0
  (2025-07-24), with no PostgreSQL 18 metrics (4.0.0), no Grafana v13
  dashboards, and a web token key hard-coded in its source
  (`sampleSecretKey`), fixed in 4.2.0/5.3.0/6.0.0 only, with no CVE or
  GHSA. Pin `ARG PGWATCH_VERSION=6.1.0`, the
  `pgwatch_Linux_x86_64.tar.gz` release asset, `ADD
  --checksum=sha256:8c9bb13978e6e769b2c82f304479c2840bbcb44e9a6ba8209507cdfc24a117da`
  (agrees with `checksums.txt` and GitHub's digest); the tarball, not the
  `.deb`. 0 advisories for pgwatch/v6 6.1.0 and pgx 5.11.0; no CPE.
  Embedded (go1.26.9, static): GO-2026-6809 (`crypto/x509` distrust
  list, a per-game CA has no public intermediate), GO-2026-6860/-6866
  (`x/net/html`, not linked): none reachable. Conditions: the binary
  only, to `/usr/local/bin/` (the chunk may take the
  `grafana/prometheus/v13/` dashboard JSON from the same tarball for
  O223); `--web-disable=all`, nothing on :8080 asserted; never
  `--create-helpers` or `--try-create-listed-exts-if-missing`; a metric
  set with no `init_sql` (`basic` qualifies, `standard` does not); no
  password in the sources file (`PGPASSFILE`, 0600, from the
  `monitoring` secret); the Prometheus sink on the overlay only; build
  assertion on the banner `Version: ${PGWATCH_VERSION}`
  (`pgwatch --web-disable=all` with no sources exits 0).
- **Prometheus 3.13.5**: unchanged, clear; LTS to 2027-07-31, the
  Dockerfile's checksum re-checked; 0 advisories; embedded matches false
  positives or not linked.
- **check_postgres**: Debian `check-postgres=2.26.0-2`, no recommends
  (13 packages: perl 5.40.1-6+deb13u1, `postgresql-client-17` and
  `libpq5` 17.11, readline, gdbm, netbase); no CPE, no tracker entry;
  upstream dormant since 2023 (a watch). Debian's psql 17.11, no PGDG
  (PGDG's `postgresql-client-18` the fallback if an action fails on 18).
  Conditions: every chosen action run against PostgreSQL 18 in the
  brick's tests; `PGPASSFILE`, never `--dbpass`; Debian `cron` as
  `postgres` (one spool crontab); the backup script through curl or core
  HTTP::Tiny; the OpenSSL floor `3.5.7-1~deb13u3` asserted.
- **The health node's web server**: Debian nginx `1.26.3-3+deb13u10`
  (the bastion's; 10 packages); 2 unimportant open trixie issues.
  Rejected: busybox httpd, lighttpd, mini-httpd, `http.server`.
  Conditions: static files only, `autoindex off`, `server_tokens off`,
  GET and HEAD; no proxy/fastcgi/uwsgi/scgi/grpc/dav/charset/rewrite/
  mail/stream, no HTTP/2 or 3; no `libnginx-mod-*` (asserted); sites and
  conf.d cleared; reached only through the bastion's `web_routes`.
- **pgCluu**: PGDG `pgcluu=5.0-1.pgdg13+1` (PostgreSQL 17/18 collection),
  not Debian's 4.0-1; no advisory. +3 packages (`libjs-jquery` 3.6.1,
  `libjs-underscore` 1.13.4: CVE-2026-27601, a recursion DoS in the
  report's own browser JavaScript, not reachable). Conditions: pinned
  exactly, `ARG PG_CLUU_PACKAGE=5.0-1.pgdg13+1`, in the PGDG
  `apt-get install`, `dpkg-query` asserted; no sysstat, `--disable-sar`;
  `/usr/lib/cgi-bin/pgcluu.cgi` and `/etc/apache2/conf-available/pgcluu.conf`
  deleted and asserted gone; run as `player`, no sudo wrapper or
  sudoers rule (`pgcluu_collectd` builds shell commands from its
  arguments); players pass `-f` for the pid file. Cosmetic: a
  `Duplicate specification "no-sysinfo!"` line on every run; `--help`
  exits 1.
- **`.tech` at G10**: monitoring gains pgwatch 6.1, check_postgres 2.26,
  pgCluu 5.0; bricks gain `pgwatch` 0.1.0 and `health-check` 0.1.0;
  platforms pgwatch, check_postgres, pgCluu (no CPE); nginx, libpq 17.11,
  cron, OpenSSL name `health-check`; Prometheus LTS note.

**Text correction** (to `spec-writer`): master spec 7.4 and G9's row
read "pgwatch 3"; they should read pgwatch's latest release at the build
(6.1.0 at G9), which the spec's own rule already says.

**For the owner, not blocking**: (1) if "pgwatch 3" was meant literally,
that is a ruling, advised against; (2) the daily sweep does not see Go
modules embedded in downloaded binaries (Prometheus, Grafana,
`postgres_exporter`, pgwatch); such findings reach `.tech` only through
a check like this one.

G9 **done (2026-11-04)**.

### Chunk 6 — merged (f3eb50d), 2026-11-04

`coding-leader`: 6a `dde1a14` (scenario, brick and fault checks;
`node_creates`; `register_diff_true`; the fixture without its catalogue),
6b `2052e6f` (purpose and domain checks; the fixture's `catalog/`; the
`scenario-format` skill's checklist), merge `f3eb50d`. Unit suite 992 OK
on the branch and on the merged `v0.5-w2` (6a alone 971 OK). Done when:
each refusal shown with its message (`test_model.py`: `TestV05Fixture`,
`TestOptionRefusals`, `TestMonitorRefusals`, `TestStandbyRefusals`,
`TestThirdPartyRefusals`, `TestHttpRefusals`, `TestApiNodeRefusals`,
`TestRegisterDiffRefusals`, `TestV05Composed`, `TestPurposeV05Refusals`,
`TestDomainV05Refusals`); the valid fixture
`tools/tests/fixtures/fixture-v05-refusals/` (eight nodes, three third
parties) accepted; a location in a database a composed domain creates
accepted through `model.node_creates` and refused without `domains:`;
the four scenarios, the fixtures and the catalogue still load.

Deviations (none against W2 or a ruling): `tools/tests/test_render.py`
(chunk 7's) changed: chunk 3's `TestStandbyEnvironment` now builds a real
standby and targets `records:8000`, as the new checks require; the split
is not exact (the skill's lines all in 6b; `PURPOSE_PARTS`,
`PART_ROLES["api"]`, `PURPOSE_KINDS` in 6a, which alone crashes only on a
scenario mapping a `partner` part, none existing); three message strings
in existing `test_model.py` tests; the README template has no slot for
`options:`, `standby_of`, `third_parties:` (the scenario-document skill's,
later). For G16: partner `data.sql`, the prefix rule, `register_diff`
required on a register fault, the `ops` trace rule. Risks: the SQL
splitter and the `search_path` regex are heuristics; the starter-pack scan
is textual; pgwatch's `sources.yaml` read as a top-level list (chunk 10
confirms on 6.1.0).

**Capture W2-a — chunk 6 outcomes (the loader's v0.5 checks; read by 7, 8, 9, 11, 17, 23 and every chunk loading a scenario or fixture)**

- **`model.node_creates(sdir, data, node, catalog_root=REPO_ROOT)`**:
  `node` a node dict or name; returns a `DataFileCreates`, or None when
  nothing creates anything there (a standby gives None). Unions the
  node's data file; each `domains:` entry's `at:` database on that node;
  the roles and databases that entry's schema and load files create
  (`schema`/`load`, or `data/<db>/{schema,load}.sql` for a map `at:`); and,
  on a `postgres` node a `third_parties:` entry lists, each composed
  domain's `producers/{partners,public}/*/data.sql`. `pg_cron` from the
  data file only. `DataFileCreates` gains `sources` (the data file first,
  then `domains/<id>/<path>`). `check_scenario` builds its map from it for
  purposes, governance and crontab roles; `_check_pg_cron` still reads
  `_data_files`. The location message names "the data file or the domains
  placed on it" only when a domain contributed.
- **A standby is no location**: refused as a purpose part's or
  governance location and as an `at:`.
- **Options**: `brick_options(brick_data)`; a node's `options:` a
  non-empty list of unique declared names; `no-access` only in the brick's
  `write_policies` (the bypass gone); `requires_option` /
  `option_absent` option names, never the same one; at instance level the
  brick declares the option and the node chooses it (or not).
- **Monitors**: `model.monitor_targets(node, brick, sdir)`:
  `postgres-exporter` from `exporter.conf`'s `DATA_SOURCE_URI` host;
  `pgwatch` from `sources.yaml`, a top-level list, each entry's `conn_str`
  in URI form unless `is_enabled: false`; `health-check` from
  `health.yaml` `instances[].host`. A `postgres` target, and a standby
  target's primary, choose `monitoring`, excused by an
  `option_absent: monitoring` instance on that node or the monitored
  standby. A third-party target refused.
- **Standby**: `standby_of` names an existing `postgres` node, no
  standby, not itself; only a `postgres` node is a standby; no `data:`;
  the primary's seed `pg_hba.conf` holds exactly `host replication
  replicator samenet scram-sha-256`. `hot_standby_feedback` not checked.
- **`third_parties:`**: `ThirdParties(nodes, hostnames, api_node,
  db_node)`, `hostnames` the entries naming nodes. `id` and `hostname`
  `[a-z][a-z0-9-]*`, unique, never `owners`, a hostname never a node's
  name; `role` inbound, outbound or round-trip; listed nodes exist and are
  `no-access`; more than one `api` or `postgres` third-party node refused.
  `partners.md` and the `partners` database not checked (chunks 11, 17).
- **Out of reach**: `web_routes` refuses a third-party node or alias
  (D363); the starter pack (every non-folder bastion seed file) refuses a
  whole-word third-party node name; a fault instance on a third-party
  node expecting `fix` (issue or `acceptable.fix`) refused; the partners'
  roles (SQL roles in third-party nodes' `schedule.yaml` and `api.yaml`
  connections) named by no other node's SQL connection or
  `crontab_roles`; the third-party `pg_hba.conf` holds only the fixed GM
  lines (`local all postgres peer`, `local replication postgres peer`,
  `local all gm_check scram-sha-256`, `host all gm_check samenet
  scram-sha-256`, the replicator line), `reject` lines, or `host partners
  <their roles> <addr> scram-sha-256`, with `host all all all reject`
  last.
- **HTTP**: `HttpContext(nodes, aliases, api_nodes, third_party_nodes)`;
  aliases every `api` node's `api.yaml` hosts but its own name, plus the
  hostnames of entries with nodes (`owners` only when served). Target
  `<host>:<port>`, a node or alias, port 8000 on an `api` node or alias.
  Credential `[a-z][a-z0-9_]{0,62}`, never `public`; `pool` a positive
  integer; `timeout` `<n>s`, 1 to 60; `role` refused. Same check for
  schedule connections, `api.yaml` connections and the vault
  (`vault_target`/`vault_credential` when not null). `_check_drivers`
  mirrors `driver_problems`: a stream (with its timeline changes) runs a
  call key only on HTTP, any other only on SQL; a job with `connection:`
  neither runs a call key nor names an HTTP connection.
- **The call form** in `queries.yaml`: `{call, params, builder,
  options}`; `CALL_RE`, the `%`/`#` path rule, a param per `%(name)s`, with
  a builder only the path's names; `options` only with a builder.
- **Weighted `choice`**: a non-empty map, integer weights ≥ 1.
- **`api.yaml` on a node**: the fragment's key check reused; at least one
  endpoint, each with `routes/<name>.py` and `db/<name>.py` in the node's
  seed; hosts exactly `[own name]` on a players'-scope node; on the
  partners' node never its own name, and served hosts minus `owners`
  equal the entries' hostnames both ways; credentials never `public`;
  connections checked as a schedule's (reserved roles, `replicator`
  included).
- **Reserved names**: `RESERVED_PARAMETERS` + `options`, `standby_of`;
  `RESERVED_DB_ROLES` + `replicator`; `DRIVERS` + `http`.
- **`register_diff`**: `model.register_diff_true(item)` reads the key
  `True` (`is True`, so `1` is not taken), else `"true"`. A register fault
  is one whose `injection.seed_changes` holds `data-register.md`;
  `register_diff` required on its instance, refused on any other;
  non-empty; each item exactly `entry`, `field`, `true`, `handed_out`
  (never both forms of `true`), or `{absent: true}` alone. `entry` not
  checked against `gm/data-register.yaml` (chunk 17).
- **Purposes**: kinds gain `round-trip`, `round_trips` required exactly
  there; `asks` customer or partner; a customer's `request.job` a job of
  the purpose; `answers` non-empty; `judged` runs, triggers, end-to-end,
  code, definition; as many end-to-end invariants as round trips. HTTP
  connections are the `connections:` keys named `api`, `partner`,
  `receiver`, that part declared, the value a credential or `public`; in a
  scenario it equals the `credential` of the runner's schedule connection
  the job maps it to (`public` if none), and that connection is `http`.
  `feeder` another job of the purpose; a feeder requires `history`, and
  `history` without one refused; the file under `material/`.
  `material/api/<node>/` holds only `routes/` and `db/` with paired files,
  and needs an `api` part. `classification.columns` in the scenario's key
  form, valid classes. With `domains:`, a trace table on a database part
  placed at an `at:` lies in schema `ops`. `receiver` and `partner` parts
  are third-party nodes (`receiver` only with `third_parties:` or
  `domains:`); `api` takes a node of role `api`.
- **Domains**: `model.sql_statements(text)` splits at `;` with comments
  and dollar-quoted bodies blanked (no parser). The `SECURITY DEFINER`
  check covers schema and load files, `data/derive.sql`, `data/keys.sql`
  and partner `data.sql`, requiring `SET search_path =|TO <value>` without
  `"$user"` (`FROM CURRENT` refused). A partner folder accepts `data.sql`;
  a `producers/partners/<name>/` name matches `[a-z][a-z0-9]{0,15}`
  (`public/` names unchecked). A composed domain with a partner
  `data.sql` and no partners' `postgres` node refused.
- **Not here**: register digests, coverage, the partners.md seed mapping
  and the `web_routes` exception (chunk 17); `coherence.yaml` (chunk 8).

### Chunk 7 — merged (a7b76ff), 2026-11-04

`coding-leader` (built 430c1a6, waited on chunk 6; resumed by a fresh
owner): merge of `v0.5-w2` in `9c9155a` (chunk 6's
`TestStandbyEnvironment` kept), `node_creates` switch `2411424`, merge
`a7b76ff`. Unit suite 1013 OK on the branch and the merged `v0.5-w2`.
Done when: render's tests (`TestAliases`, `TestHttpCredentialsRendered`,
`TestArchivingCredential`, `TestNodeCredentials`, `TestDomainLoginRoles`;
`test_deploy`'s `TestHttpCredentialSecrets`, `TestVaultCredentialSecret`)
pass; `fixture-alias`'s short test, under the lock on armenelos, no
filter: **23 passed, 0 failed, 38 s** (the alias `xlab` on partners,
`http_xlab_status` 0:0 0400 on both nodes; the caller waits within its
30 s bound while the api node is down and calls once it resolves, 10.2 s;
4 calls answered 200). Deviations: `tools/tests/test_inject.py` (mocks,
two stand-in scenarios gain `data`); two tests' `vault_target` moved from
`cold-storage:8000` (now refused) to `bastion:8000`; the fixture's one
scenario-local fault; the README template has no Third parties section
(later). Risk: callers stay on the default catalogue (one line each to
thread a scenario's own); a broken parameter fault raises at `fit`.

**Capture W2-b — chunk 7 outcomes (render: aliases and HTTP credentials; read by 11, 12, 15 to 21, 23, 27)**

- Aliases: `localimpl.node_aliases(scenario, node)` returns the hosts in
  an api node's seed `api.yaml` endpoints other than its own name, sorted
  and unique. `fit` records them as `implementation.yaml`
  `nodes.<n>.aliases`, only when there are some. `render.service_networks`
  writes `{<net>: {aliases: [...]}}` for that service and the list form
  for every other. `render` refuses with "node X's hostnames (api.yaml's
  hosts, its network aliases) changed since gmctl fit: fit again".
- HTTP credentials: `localimpl.node_credentials(scenario, node,
  params=None)` gives the credentials in first-use order: a scheduler's
  `schedule.yaml` `driver: http` connections' `credential`; an api node's
  endpoints' `credentials`, then its HTTP connections' `credential`; the
  `vault_credential` parameter of a brick declaring it, read through
  `node_parameters`, so with the parameter faults applied. Each becomes a
  password `http_<credential>` (`http_secret_name`), not handed over, 32
  characters from the dba alphabet, mounted at
  `/opt/gm/secrets/http_<credential>` 0:0 0400 on each node naming it;
  one Swarm secret `<gid>_http_<credential>` per game, ordered after the
  node's brick and role secrets, counted by `_derived_lengths`.
- Fixture `fixture-alias` and its short test `run-short-test.sh` (about
  40 s): a fresh api node at 0.1.0 is healthy and its alias resolves
  about 7 s after the scale-up, inside the scheduler's 30 s wait
  (resolved at 10.2 s in the merged run: 23 passed, 0 failed, 38 s).
- `data_login_roles` reading `model.node_creates`:
  `localimpl.data_login_roles(scenario, node, catalog_root=REPO_ROOT)`
  returns the login roles created on the node with no password of their
  own, through `model.node_creates(Path(scenario.dir), scenario.data,
  node, catalog_root=...)`: the data file's roles in file order, then
  those each `domains:` entry placed on the node creates and, on the
  partners' node, the composed domains' partner `data.sql`, without
  duplicates; the game's own roles and `pg_*` left out; a standby gives
  `[]`. Each gets `role_<role>_password`, not mounted, set by load-data.
  The keyword runs along `_derived_lengths`, `max_game_id_length`,
  `game_secrets`, `check_supported`, `implementation_secrets`; every
  caller (`fit`, `render`, `restart`, `inject.password_plan`) on the
  default `REPO_ROOT`.

### Plan revision: `public/` producer state, 2026-11-04

From chunks 6 and 8: the loader accepted a `producers/public/<name>/data.sql`
(and `node_creates` counted it) while `load-data` runs only
`producers/partners/<prefix>/data.sql`. `spec-writer`, build plan v6
(3c0a9fd):
- D369: the owners' route keeps state (its record of visits) in the
  `partners` database, so its folder is `producers/partners/owners/`
  (role and schema `owners`), loaded by chunk 8's rule as built; nothing
  goes in `public/` in v0.5. Chunk 16's scope, Files and Done when name
  it (no `owners.state`, no `owners.normal`); chunk 17 (17a) makes the
  loader refuse a `public/` `data.sql` and `_partner_data_files` read
  `partners/` only; G16 carries both into formats.md. No wave-3 chunk
  plans a `public/` file, so no urgency.
- D370 (text): chunk 12's Files name `producers/partners/{xlab,practices}/`,
  not `northfield-lab/` (a partner's folder is its prefix, W2 item 0;
  `xlab` serves the hostname `northfield-lab`).
- O229 (for capture W3, before chunk 16; not the owner's): the portal's
  `derive.sql` cannot write the messaging stub's planted notices into
  `partners` under W2 item 3. Recommended: purpose 16's history plants
  them (target `partners`, source `portal`), as D366 for purpose 14.
D371 reserved by mistake, unused. No owner question.
