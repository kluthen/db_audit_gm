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
  database, `READ ONLY`, unseen (except a check whose `reads` names
  `partners`: it runs in `partners` on the partners' node, D383); a check whose `reads` names a domain
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
  referring vet's practice, the mapping vet-scheduling's `sched_trainees`
  reads, master spec 9.4; D378), each `IMMUTABLE`
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

- **Amended 2026-11-04, after chunk 9 stopped (spec D372 to D380)**:
  the core has **eighteen** key functions, the thirteen above plus
  `core_animal`, `core_owner`, `core_ownership`, `core_exchange` and
  `core_shifts` (the rota pattern's shifts for a staff member and local
  day, with an `absence` column for the history's absences); no
  `core_withdrawal` (the request carries the withdrawal end). What each
  returns and who reads it: vet-core-domain.md, "The key functions (D374,
  D375, D379)", which this item now cites rather than restates.
  `core_request` returns each request's state at T0 with its times
  (`resulted` or `cancelled`; one of the last 24 hours `sent`, or
  `cancelled` by the vet; none `requested`; `sent_at` set on a cancelled
  one means the part cancelled it after sending), the consultation's
  priority (urgent for emergencies and stays), its vet, its animal, the
  request time (the consultation's close) and `withdrawal_ends_on` (the
  milk inhibitor test only); the parts fit their times inside the core's
  (D375). The codes it draws come from the parts' catalogues:
  vet-lab-domain.md "The test catalogue (D372)" and vet-machinery-domain.md
  "The procedure catalogue (D372, D373)" (codes 26 and 27 and machines 10
  and 16 horse-only, `species_group` `horse`; a farm animal draws DX, US,
  CT only, its CT on machine 8; an urgent request never 26 or 27; the
  imaging split about 60 % domestic, 30 % horses, 10 % farm). Identifiers
  (D379): every dog, cat, horse and ferret chipped, two rabbits in three
  not (rabbits about 3 % of domestic animals); `XA` on ear tags and
  passports, one numeric code 900 to 998 (never 999) as a chip's first
  three digits and a UELN's country part; time functions take `(n,
  load_epoch, utc_offset)`, the offset in hours; all `IMMUTABLE`. The
  variant's `parts: []`, each part chunk 12 to 16 adding its id (D380).

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
  - the manifest: `coldstore.manifests (shipment_id text, source,
    PRIMARY KEY (source, shipment_id) (D381), type, name, rows_declared, rows_received, size, date_from,
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
  caller (`fit`, `render`, `restart`) on the default `REPO_ROOT`;
  `inject.password_plan` passes `load_plans`' `catalog_root` (chunk 8,
  1a7f1ab; W2-c).

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

### Chunk 8 — merged (4b22401), 2026-11-04

`coding-leader` (built fab4f5f, waited on chunk 6; resumed by a fresh
owner): merge of `v0.5-w2` (chunk 6) `7da2e45`, its one conflict in the
scenario-format skill's Domain item resolved with both chunks' rules;
`61b1b90` (`password_plan` on `node_creates`, `TestFixtureChecks`); merge
of `v0.5-w2` (chunk 7) `6432c6d`, clean; `1a7f1ab` (`password_plan` passes
the same `catalog_root` to chunk 7's `data_login_roles`); merge `4b22401`.
Unit suite 1055 OK (2 skipped, the env-gated composed load), 166 s. The
composed test load under the lock: 2 OK in 10.6 s (loads 2.7 s passing,
2.1 s with the broken range), on `postgres:0.5.0` as it stood. Done when:
the load order follows `composition.yaml` (fx-core, the xlab partner
`data.sql`, fx-docs, fx-ward); `records/docs` created with `CONNECT`
revoked from `PUBLIC`; the derivation unseen in the log, pgaudit's trail
and `pg_stat_statements`, its foreign servers gone; `partners.xlab.requests`
5001 to 5004 from the core's key functions, the `core_*` functions gone
after; coherence 5/5 passing and recorded, a broken range failing with
its ids and recorded `result: fail`. Choices taken (none against W2): a
failing check recorded before the setup fails; `database:` required only
on a several-database part; a `derive` on one refused; a domain file
creating a database or using `\connect` refused (line scan); `gm_check`
also gets `log_min_error_statement = panic`. Deviations: two merges of the
wave and two code commits, not one (chunk 7 merged mid-way); the password
step now also sets the domains' and the partner's login roles' passwords
(consistent with chunk 7's secrets); W2-b's caller line corrected above.
Risks: a restart with no snapshot reruns the composed steps and rewrites
`composition.yaml`'s record; the line scan; a `;` inside a check's string
literal refused.

**Capture W2-c — chunk 8 outcomes (`load-data`'s composed load, derivations, histories, the coherence check; read by 9, 12 to 16, the purpose chunks)**

- Entry points: `inject.load_plans(scenario, impl, catalog_root=model.REPO_ROOT,
  now=None)` adds `LoadPlans.composed = inject.composed_plan(...)`; the
  plans' variables gain `load_epoch` (`inject.load_epoch()`,
  `%Y-%m-%dT%H:%MZ`, UTC); `inject.load_data(..., catalog_root=)`.
  `inject.load_steps` runs: data files, then `composed_steps`, then the
  v0.4 passwords, survey, mappings, access, grants and `pg_cron` clean-up,
  then the standbys' clone. `restart.py`'s `load_plans(scenario, impl)`
  call unchanged. New helpers `data_argv(variables, database="postgres")`
  and `read_argv(database)`.
- Domain loads: for each `at:` database, a session as `postgres` on
  `-d postgres` runs `\gset`/`\if`: if absent, `CREATE DATABASE … OWNER
  postgres`, `REVOKE CONNECT … FROM PUBLIC`, printing
  `gm-database-created`. Then `schema.sql` alone, then the core's
  `keys.sql` plus `load.sql` in one session (`psql -d <db>`, all three
  variables), streamed through a temporary file. Partner files
  `<catalog>/domains/<id>/producers/partners/<prefix>/data.sql`, in name
  order, run with keys first into `-d partners` on the one `postgres`
  node the `third_parties:` entries list (`inject.partners_node`; two such
  nodes refused); the owners' route's `producers/partners/owners/` is one
  of them (D369). A `producers/public/<name>/data.sql`, which chunk 6's
  loader accepts and `node_creates` counts, is not run; chunk 17 refuses
  it (D369). A domain's schema or load that creates a database or
  uses `\connect` is refused before anything runs, naming the line (a
  line scan, not a parser).
- Sourced runs (derive, history, each check): on every source node, once
  before the first read, `ALTER ROLE gm_check SET` `log_statement`,
  `log_min_duration_statement`, `log_min_error_statement` (`panic`),
  `pg_stat_statements.track`, `pgaudit.log` (a placeholder accepted where
  pgaudit is not loaded), and `GRANT CONNECT` to `gm_check` on each source
  database; reset once after the coherence check (on a failure the game is
  torn down instead). Per run, the source's schemas listed unseen; then
  `UNSEEN_SQL` (`NO_LOG`, `NO_AUDIT`, `NO_STATS`, `QUIET`); `postgres_fdw`
  (`\gset` notes whether it existed); per source a server `gm_src_<name>`
  (host `/run/postgresql` on the same node, else `<node>`; port 5432), a
  user mapping for `postgres` as `gm_check` with `gm_check_password`,
  schema `gm_src_<name>` importing `public` and `gm_src_<name>_<s>` each
  other schema (`pg_*`, `information_schema`, `gm_src_*` excluded; a name
  over 63 characters refused); the body; then schemas and server dropped
  `CASCADE`, the extension only if the session created it. psql output on
  failure redacted. Keys streamed ahead of derive only, never a history.
  A `derive` on a several-database part is refused (none in v0.5).
- Coherence (`tools/gm/coherence.py`): `read_checks(path, domain,
  databases)`, strict YAML, exactly `{checks: [non-empty]}`, keys
  id/what/database/reads/sql; one SELECT or WITH query (no `;` but a
  trailing one, so none inside a literal; no psql meta-command);
  `database:` required on a several-database part, refused otherwise;
  `reads` may name the domain itself. `query_sql` wraps it as `BEGIN
  TRANSACTION READ ONLY; WITH gm_rows AS (…) SELECT
  jsonb_build_object('count',…, 'rows', first 10)`, `psql -A -t`.
  Outcomes pass, fail, skipped (a catalogue domain not composed, or
  `partners` with no partners' node); a name that is no catalogue domain
  refused. `record_composition` rewrites only the `coherence:` key (flow
  form, other bytes kept, read back; an aliased value refused);
  `state.yaml` gets `coherence: {run_at, result, checks: [{domain, check,
  what, result[, rows, first_rows, reason]}]}`. A failure is recorded
  `result: fail` in both before the setup fails. Source names: `<id, - as
  _>`, `<id>_<db>` for a several-database part, `partners`, or a purpose
  part's name (`source`).
- Skill: templates `keys.sql`, `coherence.yaml`, `partner-data.sql`; the
  Domain section gains the database convention, the core's keys, a
  partner's state, the coherence queries; the Composition section gains
  load-data's order and its record (chunk 6's `SECURITY DEFINER` rule kept
  in the same item, D362). `fixture-composed` passes `check_domain_dir`
  (each domain) and `check_composition` (`test_coherence.TestFixtureChecks`).
- `password_plan` reading `model.node_creates`:
  `inject.password_plan(scenario, impl, catalog_root=model.REPO_ROOT)`,
  `catalog_root` passed through from `load_plans`: a connection through a
  node that is no database node (a pooler) sets its role on the database
  nodes where `node_creates` finds its target database created (the data
  file, a `domains:` entry's `at:` database or its schema and load files),
  else on every database node; the login roles step calls
  `localimpl.data_login_roles(scenario, node, catalog_root)` with the same
  root, so the domains' and the partner files' login roles get their
  passwords set (`test_coherence.TestPasswordPlanReadsNodeCreates`).

### Chunk 10 — merged (35e8bf7), 2026-11-04

`coding-leader`: 10a `65dae42` (`pgwatch` 0.1.0; `grafana` 0.3.0's pgwatch
dashboard), 10b `88485c6` (`health-check` 0.1.0; pgCluu in `postgres`
0.5.0; the fixture), merge of `v0.5-w2` (chunks 6 to 8) `3d11433`, merge
`35e8bf7`. Unit suite 1061 OK (2 skipped) after the merge in. Stack tests:
`pgwatch` 72/72, `health-check` 95/95 (every check_postgres action on
PostgreSQL 18.6, `hot_standby_delay` on a streaming standby, over TLS),
`grafana` 0.3.0 130/130, `postgres` 0.5.0 rebuilt with pgCluu 302/302.
Fixture `fixture-monitoring-v05` (6 nodes) through
`tools/tests/smoke-monitoring-v05.sh`: 27/27, 139 s. Done when: Prometheus
scrapes `pgwatch:9188` (`pgwatch_instance_up{dbname="records"}` 1, 29
db_stats series); the dashboard's 10 panel queries return data (60 s, two
fetches); `/health/` through the bastion 401 without the tools password,
200 with, 7 records checks with UTC times (`last_autovacuum` UNKNOWN on a
fresh cluster), the disk alarm OK; a pgCluu report (26 files) in the
player's home, copied by `scp`, no collector left, no CGI; a node
without the option refused for both monitors; each new brick started
before its peer waits 30 s, fails honestly, then works (D356); the backup
script reads the stand-in's `GET /manifests` found (`BACKUP OK`), missing
(`BACKUP CRITICAL`), broken or unreachable (UNKNOWN) (D362). Footprints at
rest: `pgwatch` 12–17 MiB (peak 24 MB), `health` 5 MiB (peak 34 MB).

**`postgres:0.5.0` rebuilt** under the lock: `sha256:05b52e42…` →
`sha256:7cca24d4…`, 262 → 265 MB. Sizes: `pgwatch:0.1.0` 167 MB,
`health-check:0.1.0` 195 MB, `grafana:0.3.0` 866 MB.

Deviations (none against the spec): Files beyond the line —
`bricks/grafana/{brick.yaml,rootfs/,validator/}` (the dashboard an
optional seed), `tools/tests/test_model.py` (two grafana seed checks),
`tools/tests/smoke-monitoring-v05.sh` (the gate's runner),
`tools/tests/test_monitoring_v05.py`, `bricks/health-check/companion/`;
`health.yaml` gains an optional `primary:` on a standby (replay delay is
measured against it); G9's text: `pgwatch --web-disable=all` with no
sources exits 1, not 0 (the build asserts the banner only). Found for
others:
- **pgwatch 6.1.0 skips a source with no `is_enabled`** (its default is
  disabled), while W2-a's `model.monitor_targets` counts every entry
  but `is_enabled: false`: the loader may refuse a target pgwatch would
  not watch (too strict, never too lax). **Driver**: a wave-gate fix,
  `monitor_targets` counting only `is_enabled: true`.
- The loader requires `crontab_roles` on any node seeding a `crontab`:
  the health node needs `crontab_roles: []` (chunk 27, the format skill,
  G16).
- pgCluu needs `--disable-pidstat` with `--disable-sar`, and its `-o`
  directory must exist (in `postgres`' `docs/gm.md`).
Risks: on a fixable health node a player's script runs as `postgres`,
which can read the monitoring password (documented, as the scheduler's
scripts, access model 8); `pgwatch` and `health` keep master spec 14's
starting footprint rows, well above the measured.

**Capture W2-e — chunk 10 outcomes (the monitoring breadth; read by 6, 27)**

- **`pgwatch` 0.1.0**: pgwatch 6.1.0, binary only in `/usr/local/bin`,
  its built-in metric definitions. Build assertions: the banner (exit 1
  with no sources), `metric print-init basic` printing nothing. Started
  as `pgwatch` 990:990 with `--sources=/etc/pgwatch/sources.yaml
  --refresh=60 --sink=prometheus://0.0.0.0:9188 --web-disable=all
  --emergency-pause-triggerfile=/run/gm-pgwatch/emergency-pause`, the
  environment only `PATH`, `HOME`, `PGPASSFILE`; password file
  `/run/gm-pgwatch/pgpass` (`*:*:*:monitoring:<pw>`, `:` and `\` escaped,
  owner-only), written at every start; player group `pwconf` 991.
- **Sources format** (checked on 6.1.0): a top-level YAML list of
  `{name, conn_str, kind, preset_metrics, is_enabled}`; `is_enabled:
  true` required (the default is disabled); unknown keys ignored. The
  brick reads `is_enabled` itself (`pgwatch source resolve` lists every
  source); each enabled entry a `postgresql://` URI with one host. Series
  `pgwatch_<metric>_<column>{dbname=<source>}` with explicit timestamps,
  about 39 per source with `basic`; the file reread every 60 s.
- **Waits**: 30 s on `getent ahosts` for the sources' hosts; past the
  bound, `pgwatch_instance_up 0` until the refresh after the name
  resolves. Wrappers `gm-restart-pgwatch`, `gm-validate`; validator rules
  `config`, `server` (9188), `web` (nothing on 8080).
- **`grafana` 0.3.0**: `pgwatch.json` an optional seed (uid `pgwatch`, 7
  panels over the `basic` series); `PROV_OPTIONAL` in `grafana-files`;
  Prometheus job `pgwatch`, target `<node>:9188`.
- **`health-check` 0.1.0**: as `postgres` 990:990, player group
  `healthconf` 991, nginx as `www-data`. Seeds: `health.yaml`
  (`instances:` `{name, host, port, dbname}`, optional `primary` on a
  standby), `crontab` (postgres's, `crontab -u`; the scenario writes
  `crontab_roles: []`), `scripts/` (optional, 0775). `health-run checks |
  script <name> [args] | hosts | check-config | page`. check_postgres
  `--timeout=15`, each run bounded 30 s, scripts 120 s: `connection`;
  `backends` 80%/90%; `locks` 100/150; `txn_wraparound` 1.3e9/1.4e9;
  `last_autovacuum`, `last_analyze` 1d/7d on primaries; `database_size`
  5GB/10GB; `hot_standby_delay` 16MB/128MB on standbys against the
  primary. Scripts get `PGUSER=monitoring`, `PGPASSFILE=/run/gm-health/pgpass`,
  `PGCONNECT_TIMEOUT=10`, `HEALTH_YAML`, `TZ=UTC`; result the first output
  line and the exit status (0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN).
  Results `/var/lib/health/results/*.json`; page
  `/var/lib/health/www/health/index.html` (and `status.txt`) on 8080
  under `/health/`, GET and HEAD, refreshed every 60 s; at start a 30 s
  wait on the hosts, a first run, then cron. `status.txt` lines `<UTC>
  <STATE> <instance> <check>: <line>`. Wrappers `gm-crontab` (refuses a
  replacement unless `/etc/health` is fixable), `gm-run-checks`,
  `gm-validate`; validator rules `config`, `scripts`, `cron`, `web`,
  `fresh` (15 min). Companion scripts `disk-alarm <warn MB> <crit MB>
  <host>...` and `backup-there <URL> [<source>]` (`GET
  <URL>/manifests?type=basebackup&from=<yesterday>[&source=]`, counting
  manifests with `rows_received` ≥ 1).
- **pgCluu**: `pgcluu=5.0-1.pgdg13+1` in `postgres` 0.5.0, CGI and Apache
  files removed and asserted, no sysstat; players run `pgcluu_collectd -h
  localhost -U dba -d postgres --disable-sar --disable-pidstat -i N -E T
  -f <pid> <dir>`, then `pgcluu --disable-sar -o <existing dir> <dir>`, in
  their home.
- **Fixture** `tools/tests/fixtures/fixture-monitoring-v05` (6 nodes), run
  by `tools/tests/smoke-monitoring-v05.sh`. The backup script's first
  read against cold storage itself stays G13's.

### Chunk 9 — blocked, then settled, 2026-11-04

The chunk owner stopped at WIP `0a3e43b` (`v0.5-c9-vet-core`, worktree
kept): writing `core_request` needed decisions no capture or spec
settled. These were the code catalogues it draws from (imaging's 30
procedures, the lab's tests and panels), the further functions the parts
read, three conflicts (routine imaging lead time 2 or 3 working days;
intensive-care sessions about 13 at once against "about five" and 8
monitors; `core_referring_practice`'s reader), and its own identifier
choices. Built by then: `domain.yaml`, `data/schema.sql` (25 tables and a
view, the five roles, `vet_lookup`'s column grants), classification,
register, governance, policy, the variant, `clinic-api`, `pms`'s
`schedule.yaml`, `keys.sql` (`core_staff`) and part of `load.sql`, run
into `postgres:0.5.0` at shift +2.

`spec-writer` (12418f7), no owner question:
- D372: the catalogues live in the parts' domain documents (vet-lab
  "The test catalogue", vet-machinery "The procedure catalogue"); chunk
  9's `keys.sql` draws from them, chunks 12 and 15 load them;
- D373: codes 26 and 27 horse-only;
- D374: eighteen key functions;
- D375: `core_request`'s states and fields;
- D376: a routine imaging study booked within two working days, its
  report within one more (master spec 9.4 and vet-scheduling's
  `book-requests` corrected);
- D377: intensive-care sessions (one domestic stay in two, one horse
  stay in four, never farm; about 5 at once; trap T206's witness about
  one a day);
- D378 (text): `core_referring_practice`'s reader;
- D379: chunk 9's identifier and signature choices confirmed;
- D380: the variant's `parts:` a shared list in chunks 12 to 16.
Master spec 9.2, 9.4 and 9.6 corrected as text (cited in their headers).
D371 and O230 reserved by mistake, unused. W2 item 4 amended above
(driver). The chunk resumes with a fresh owner from `0a3e43b`.

### Gate fix made early: pgwatch's `is_enabled`, 2026-11-04

`coding-executor`, `9131cc4` (chunk 6): `model.monitor_targets` counts a
`pgwatch` source only with `is_enabled: true` (YAML boolean), as pgwatch
6.1.0 watches it (W2-e); no key, `false` or the string `'true'` is no
target; an enabled source still needs the `monitoring` option. Tests in
`test_monitoring_v05.py` (fail 3 times on the old rule); the
scenario-format skill's Options paragraph says so. Only
`fixture-monitoring-v05` seeds pgwatch, and it already writes
`is_enabled: true`. Unit suite 1063 OK (2 skipped). W2-a's Monitors line
reads accordingly from here.

### G10 — dependency post-change check (security-advisor, 2026-11-04)

**Clear.** `.tech` updated on `v0.5-w2` (4353683, `.tech` only). The
resolved versions match G9's pins and conditions as image inspection
shows. `pgwatch:0.1.0`: the binary only (`pgwatch/v6` v6.1.0, commit
`742aaf9`, go1.26.9, the `ADD --checksum` `8c9bb139…`, banner `Version:
6.1.0`), nothing else from the tarball, no libpq (Go's `crypto/tls`); 0
advisories for pgwatch/v6 and pgx/v5; osv-scanner on the binary finds
exactly G9's three, none reachable (`x/net/html` not linked).
`health-check:0.1.0`: `check-postgres 2.26.0-2` pinned and asserted,
`postgresql-client-17`/`libpq5` 17.11-0+deb13u1, perl 5.40.1-6+deb13u1,
nginx 1.26.3-3+deb13u10, cron 3.0pl1-197, curl 8.14.1-2+deb13u7; the
OpenSSL floor asserted; no `libnginx-mod-*`, the nginx configuration
static only (checked on `nginx -T`); no sysstat. `postgres:0.5.0`
(`05b52e42…` → `7cca24d4…`): exactly +3 packages (`pgcluu
5.0-1.pgdg13+1`, `libjs-jquery` 3.6.1, `libjs-underscore` 1.13.4),
nothing else moved; the CGI and Apache files gone, no apache2, no
sysstat; underscore's CVE-2026-27601 not reachable (G9). `grafana`
0.3.0, `prometheus`: no package change. Already present elsewhere, now
also here, not reachable: curl's open trixie "no DSA" issues (`backup-there`
runs `curl -fsS -m 20` with no `-L`, proxy, auth or cookies), perl's
three (Pod::Text, Archive::Tar, a 286 MB regex subject), nginx's NVD hits
(Debian backports; the modules they hit excluded). `cve-watch check`: 60
→ 60 at or above medium, the same IDs; `cve-watch lint` 0 errors.
`SECURITY_TODO.md` unchanged. G9's text corrected: `pgwatch
--web-disable=all` with no sources exits 1.

**For the owner, not blocking**: (1) the daily sweep does not see Go
modules embedded in downloaded binaries (Prometheus, Grafana,
`postgres_exporter`, pgwatch); the `.tech` header now says they are
checked at each version bump; (2) check_postgres (no release since
2023-04-03) and underscore (CVE-2026-27601 open in trixie) may get fixes
only as Debian patches; the tracker is the watch.

G10 **done (2026-11-04)**.

### Chunk 11 — merged (dc4fdd5), 2026-11-04

`coding-leader`: 11a `1f000c1` (the shared nodes, the `pg_hba` form, the
slow partner), 11b `b42448c` (cold storage, the vault, the archive
fixture), merge `dc4fdd5`. Unit suite 1075 OK on the branch, 1083 OK on
the merged `v0.5-w2` (11a alone passes too). Fixtures on armenelos under
the lock, after `fit` on 2 CPU / 4G / 8G: `fixture-partners` 52/52 in
128 s, `fixture-archive` 42/42 in 326 s, both with chunk 8's `load-data`.
Done when:
- two sample partners answer under their hostnames, each reading its
  own `<prefix>.state` as its own role, neither able to use the other's
  schema; the back end's ticks 200, a tick without `partners_backend`
  401;
- **one slow, the other in time (measured)**: alpha switched to slow
  66–67 s after T0; with 30 of alpha's requests in flight, alpha
  4005–4091 ms, beta 20 of 20 at a median of 3–4 ms, slowest 5 ms; with
  45 in flight (past the server's 40 worker threads) beta's median 4 ms,
  its slowest 3620 ms;
- **`partners-db` refuses all but the partners' roles (measured)**:
  `dba`, `postgres`, `gm_check`, and `alpha` on another database refused
  ("pg_hba.conf rejects connection"), right password or not. The form:
  `samenet` covers the game network (10.0.1.0/24) and the host's
  `docker_gwbridge` (172.18.0.0/16), so `alpha` with its password gets in
  even from the bastion; through a service name every client on a host
  arrives from the network's load-balancer address (10.0.1.10); through
  `tasks.partners-db` from its task address, which changes on restart; a
  host-name line never matches. **The guard is the password**, mounted on
  the partners' nodes only;
- a switched segment and a base backup yield manifests naming `records`
  (a refused segment kept and shipped on the archiver's retry after
  `load-data`; a 49,425,920-byte backup streamed, `partners-api` at 43.4
  of 128 MiB);
- `GET /` draws declared against received, one inline SVG per type, no
  script, a short day (520/480) marked and named (looked at in headless
  Chrome; the dataviz palette);
- `GET /manifests` filters by type, date and source, a bad date 422;
  uploads 401 without the credential, NDJSON rows counted, a repeated id
  replacing its manifest, a bad header 400, `uploads=refuse` 503 until
  `coldstore.normal` restored it (57 s);
- the planted manifests show the 35 days before T0 (35 base backups,
  1064 WAL manifests);
- `partners-api`'s start-up wait on `partners-db` resolved in 3–4 s, its
  requests 503 in 26–32 ms until the database was loaded.

Deviations: the upload body is streamed by an `async` FastAPI dependency,
the route plain `def` (a large base backup on a 128M node);
`fixture-partners`' sample partners live in its own data file in a
partner `data.sql`'s form, not through a composed domain. **Findings,
routed to `spec-writer`** (entry below):
1. the manifest's `shipment_id PRIMARY KEY` (W2 item 6) collides when two
   nodes archive (the clinic's `records` and `lab` post the same segment
   names); proposed key `(source, shipment_id)` before chunks 20, 21, 23;
2. the shared `pg_hba.conf` has no `gm_check` host line (Done when,
   access model 14), but W2-c's sourced runs reach `partners-db` over TCP
   as `gm_check`, so a coherence check reading `partners` from another
   node is refused.
Risks: isolation rests on the passwords (measured, not assumed); past 40
slow requests in flight other partners wait (3.6 s measured); the address
readings are Docker 29 on one host.

**Capture W2-f — chunk 11 outcomes (the partners' shared nodes and cold storage; read by 12, 16, 18 to 21, 23, 26, 27)**

- **The `partners/` catalogue folder**: `shared/nodes.yaml`, the three
  nodes, all `no-access`, sized as master spec 14 (0.45 CPU, 448M in
  all: `partners-api` 0.1/128M, `partners-backend` 0.1/64M, `partners-db`
  0.25/256M with 512M disk; only `partners-db`'s knob envelopes
  tightened); `shared/partners-db/` (`pg_hba.conf`; `postgresql.conf`, 32MB
  shared buffers, 40 connections, connections logged; `data.sql`,
  `CREATE DATABASE partners` then `\connect partners`);
  `shared/partners-backend/` the back end's base (`intensity 1.0`, no
  stream, no job). `tools/tests/test_partners.py` keeps the fixtures'
  copies equal to the catalogue.
- **The `pg_hba.conf` form**: the GM's DO NOT TAMPER `local` lines, then
  `host partners <roles, comma-separated> samenet scram-sha-256`, then
  `host all all all reject`; no `gm_check` host line. The roles are
  exactly those the partners' nodes connect as, filled by the GM: each
  composed partner's prefix, `coldstore` with a vault, `owners`.
  Measured figures: the chunk entry above.
- **A partner's state**: `<prefix>.state (hostname, name, value, set_at,
  PRIMARY KEY (hostname, name))`, owned by `<prefix>`. A route reads its
  state for the request's `Host`, returns its session, then applies the
  behaviour (e.g. sleeping `delay_ms`): a slow partner holds a thread per
  request, never a session. Each partner's connection `<prefix>-db`, its
  own pool. `<prefix>.normal` upserts the baseline once a minute (even
  arrivals); a fault's key `<prefix>.<behaviour>` other values; placed
  standing as a T0 timeline change of `<prefix>.normal`, seen about a
  minute later. The limit is the server's 40 worker threads, shared.
- **Ticks**: endpoints `<prefix>_tick`, `POST /tick` on the partner's
  hostname, credential `partners_backend`, mounted by render on
  `partners-api` and `partners-backend` only.
- **Cold storage** (`partners/coldstore/`, prefix `coldstore`, hostname
  `cold-storage`): endpoints `coldstore_shipments` (credential
  `cold_storage`), `coldstore_manifests` and `coldstore_page` (public);
  connection `coldstore-db`, pool 2. `POST /shipments` reads `Shipment-Id`,
  `-Type`, `-Rows`, `-From`, `-To`, `-Source` (required) and `-Name`
  (defaults to the id); rows received 1 for a non-empty `wal` or
  `basebackup`, else the non-empty NDJSON lines; 201 with W1 item 6's
  receipt (`received_at` ISO UTC with milliseconds and `Z`), 400 on a bad
  header, 503 when `uploads` is not `accept`. `GET
  /manifests?type=&source=&from=&to=`: a manifest whose range meets
  `[from, to]`, ordered by `received_at` then `shipment_id`. `GET /`: the
  last 35 days including today (UTC), each shipment counted on its
  `date_from`. State `delay_ms`, `uploads` (`accept`|`refuse`), restored by
  `coldstore.normal`. Tables `coldstore.manifests` (W2 item 6, `CHECK
  (date_from <= date_to)`, indexed on `received_at` and `(type,
  date_from)`) and `coldstore.state`. The GM copies `data.sql`, then
  `planted.sql`, after the shared `data.sql` in `partners-db`'s data file.
- **`planted.sql`**: one VALUES list for the GM, `(pos, node, wal,
  backup, at, segs, mb)` (`records` the example row), planting the 35
  days before T0's day: about `segs` segments a day (±3, deterministic),
  16 MiB each, one backup a night at `at` of about `mb` MB. T0 is
  `:'load_epoch'` when passed, else `now()`. Segment names on timeline 1
  from log `0x40 + 16 × pos`: never a live name, but sorting above the
  live names (a known limit).
- **Fixtures**: `fixture-partners` (bastion, the three partner nodes;
  local fault `fixture-partner-slow` with a `partner_behaviour` block,
  standing); `fixture-archive` (bastion, `records` with `vault_target
  cold-storage:8000`, `vault_credential cold_storage`, a crontab,
  `crontab_roles: []`, the three partner nodes; local fault
  `fixture-basebackup-log-unread`), each with `run-short-test.sh`.
- **Known limits**: every partner calls from `partners-api`'s address;
  the planted segment names sort above the live ones (D382: no check
  orders by name). The manifest key across archiving nodes and
  `gm_check`'s reach into `partners` were settled by D381 and D383 and
  fixed at wave 2's gate.
- **For the wave gate**: the `pg_hba` form written into
  `bricks/postgres/docs/gm.md` in its own commit (text in
  `partners/README.md`).

### Plan revision: chunk 11's findings, 2026-11-04

`spec-writer`, build plan v8 (f5c8fd5), no owner question:
- D381: cold storage's manifest keyed on `(source, shipment_id)`,
  `source` the node holding the data (the archiving node for
  `wal`/`basebackup`, `machines` for purpose 14's types); the same id from
  the same source replaces its manifest (`received_at` the new receipt's),
  from another source makes a second; `GET /manifests` ordered by
  `received_at`, `source`, `shipment_id`; the page unchanged (counts per
  type and day across sources); the receipt and `planted.sql` unchanged.
- D382: planted segment names sorting above the live ones stays a known
  limit; no check orders by name (a check for a node's latest `wal`
  manifest orders by `received_at`); s2's answer key records the jump as a
  setup limit (chunk 23's scope). `pg_resetwal -l` rejected.
- D383: no `gm_check` host line on `partners-db` (master spec 10.2,
  access model 8, chunk 6's `pg_hba` check). A coherence check whose
  `reads` names `partners` runs in `partners` on the partners' node as
  `postgres`, read-only, unseen: `gm_src_partners` over that node's
  socket (the local `gm_check` line), its other reads over TCP as
  `gm_check` (the customer nodes' lines admit it); every table read
  through `gm_src_*` (its own domain's through `reads` naming the domain);
  `database:` refused on such a check. A derivation or history reading
  `partners` from another node refused at plan time (none in v0.5).
  Access model 8 reworded ("off the partners' database from the
  network"), with 14 and the header. First met by chunk 12.
Both fixes go to wave 2's gate on `v0.5-w2` (the gate row names them):
chunk 11's code for D381, chunk 8's (`inject.composed_plan`,
`coherence.read_checks`, the skill) for D383, the composed test load
started with the shared `pg_hba.conf`. W2 items 3 and 6 and W2-f's known
limits amended above (driver). **For the owner, information only**:
access model 8 reworded after approval to match what chunk 11 built.

### Gate fixes made early: D381, D383, the `pg_hba` form, 2026-11-04

`coding-executor`, on `v0.5-w2`:
- `c1f7d2f` (D381, chunk 11): `coldstore.manifests` `PRIMARY KEY (source,
  shipment_id)`, the upsert on that key (no longer updating `source`,
  `received_at` the new receipt's), `GET /manifests` ordered by
  `received_at, source, shipment_id`; `partners/README.md` (the key, D382's
  order rule); fixture-archive's copies; `TestManifestKey`; the short
  test posts one segment from `records` and `lab` (two manifests) and
  `lab` again (replaces its own). **fixture-archive 45/45 in 311 s.**
- `2035b0e` (D383, chunk 8): a check whose `reads` names `partners` runs
  on the partners' node in `partners`, `gm_src_partners` over the node's
  socket, other sources over TCP as `gm_check`;
  `_refuse_partners_from_afar` refuses a derivation or history reading
  `partners` from another node; `read_checks` refuses `database:` on such
  a check; the skill and template. The composed test load now starts
  `partners-db` on `partners/shared/partners-db/pg_hba.conf` (`xlab`
  filled in), asserts `gm_check` over TCP from `records` is rejected,
  that fx-ward's `requests-on-current-stays` ran in `partners-db/partners`,
  and that nothing is left in `partners`. **2 OK in 10.7 s.**
- `990941b` (chunk 11): "The partners' database: `partners-db`'s
  `pg_hba.conf`" in `bricks/postgres/docs/gm.md` (the form, no `gm_check`
  host line, the measured facts); `test_brick_docs` passes.
Unit suite 1090 OK (2 skipped), 161 s.

### Chunk 9 — paused again, resumed by a third owner, 2026-11-04

The second owner merged `v0.5-w2` in (`948d0b9`) and wrote the eighteen
key functions in `data/keys.sql` (WIP `16246ae`, over `0a3e43b`), all
`IMMUTABLE`, with internal `pg_temp.vc_*` helpers: a 53-week local
calendar cut at `load_epoch` (ramp 0.6 to 1.0), inverse lookups without
year scans, 589 consultations and 58 stays a week, stays and animals by
affine bijections (at T0 2026-11-04 10:00Z, +2: 2 421 stays, 36
current), identifiers `941…`/`941001…`/`XA` (D379), requests from the
D372/D373 catalogues with D375's states. Timings: `core_consultation`
about 1.7 ms a call, `core_request` 1.8 ms (`MATERIALIZED` CTEs and
`OFFSET 0` fences needed; 800 ms before). It paused, context heavy; a
third owner resumed from `16246ae`. Two of its choices went to
`spec-writer`: the weekend vet cover (the scheduling pattern leaves
Saturday afternoon without a vet), and requests per consultation (vet-core's
"about two in three" averaging 0.65 cannot hold with the lab's 1.8
tests per order; built as about 37 % at 1.8, repeating every 40 ids),
with the core's load time (likely 1–2 minutes, against "a few seconds").

### Chunk 9's second set of points settled, 2026-11-04

`spec-writer` (8a15c8e, spec files only), no owner question; relayed to
the chunk owner at once:
- D384: one duty vet per section on Saturday and Sunday, 08:00–20:00,
  rotating, never that weekend's night vets; the two domestic Saturday
  morning vets stay (vet-scheduling's rota, vet-core's `core_shifts`).
- D385: about four in ten consultations make requests, 0.65 per
  consultation (0.68 in the history); three in ten have one lab order of
  about 1.8 analyses (about 7 700 orders, within `lab_orders`' 1–14 000
  with the practices' 6 300); one in eight one imaging study; analyses and
  imaging decided per consultation. vet-core's "two in three" corrected.
- D386: no fixed id period (ids run in time order): fixed counts per block
  shuffled by a hash of the block, or a hash of the id; the stays'
  section and outcome draws likewise; the current-stay caps rechecked.
- D387 (text): the core's load expected at one to two minutes (master
  spec 9.2, vet-core's Loading).
- D388: the nurses' four-week cycle stands within the working-time rules;
  absences as one-day to two-week periods, about 600 a year, leave about
  five weeks a person (Directive 2003/88/EC Art 7).
- D389: MINH's line on the herd's latest earlier consultation early
  enough for the withdrawal to end; MINH never drawn without one.
- D390: inbound exchanges examinations only; exchange ids in
  `requested_at` order.
- D391: `given_by` a nurse of the stay's section.

### Chunk 9 paused a third time; D393, D394, 2026-11-04

The third owner applied D384–D391 (WIP `b9dcfaf`, over the `v0.5-w2`
merges `02b610f` and `fd706bd`): the full `load.sql` and `gm.md`'s "Core
keys". The core's load: **89.4 s, 49 MB, 299 255 rows at +2; 88.8 s,
49 MB, 299 448 rows at shift 0** (`postgres:0.5.0` 7cca24d4, a throwaway
container). Requests at +2: 42.5 % of consultations, 7 432 lab orders of
1.83 tests, 3 033 imaging studies (59.5/29.3/11.2); the nurses' cycle
re-made as `(n + week) mod 4`, every shift held, 47.3 h a week on average;
absences 633 periods, 90 % leave; no fixed id period (most stays at once
17/9/23 under 21/10/31). It paused, context heavy; a fourth owner resumed
from `b9dcfaf`. Its two deviations went to `spec-writer` (6862d32, no
owner question):
- D393: the history's 61 241 administrations kept ("about 60 000"); the
  live `administrations.round` doses each active line at its frequency
  (about 35 a round, 210 a day), not one a round per stay, so there is no
  step at T0; MR1 and T65's "about 240 a day" become about 210.
- D394: D388's every-shift rule is the nurses' and technicians'; the
  carers keep the cycle (4/2/4 per section), the farm's nurses holding
  the phases its two carers cannot.

### Chunk 9 stopped on a defect; gate fixes to `load-data` and `compose`, 2026-11-04

The fourth owner built the rest (WIP `ce7ad08` over the `v0.5-w2` merge
`dccec41`): `pms`' 23 keys run as `vet_app`, `fixture-core`, `gm.md` whole,
the variant figures, the README row. Its fixture failed one check of 32
three times: the load was not unseen (records' server log held 39 lines
of the load, `log_min_duration_statement = 100ms`). Cause: chunk 8's
`run_file` streamed a domain's files with no `UNSEEN_SQL` prelude, against
master spec 9.2 and D265. Its other finding: `compose` read only the
string form of a node's `brick:`. Driver: both are code brought to the
spec, so gate fixes on `v0.5-w2` by a `coding-executor`, not an inserted
chunk:
- `e5d158c` (chunk 8): `stream_files(paths, prelude=)`; `run_file` and
  `create_database_sql` start with `UNSEEN_SQL`: each domain's
  `schema.sql`, the core's `keys.sql` + `load.sql`, each partner
  `data.sql`, the `CREATE DATABASE` sessions. v0.4's node data files are
  unchanged: no spec says they run unseen. The composed test load now
  asserts records' and partners-db's logs and `pg_stat_statements` hold
  none of the domain or partner statements, and a guard that a data
  file's `CREATE DATABASE office` is still logged (the assertion failed on
  the unfixed code). 2 OK in 10.7 s.
- `5900212` (chunk 2): `compose._brick_id` reads the mapping form `{id,
  version}` (the loader's) as well as the fixtures' `api@0.1.0`;
  `test_bricks_in_the_mapping_form`. `compose`'s refusal of a scenario
  lacking a node for one of the domain's producer folders is the stated
  rule (W1-w; master spec 5, 8.4): `fixture-core` gains a `pms` node
  rather than a hand-copied fragment.
Unit suite 1092 OK (2 skipped). One trace left: the brick's
`log_temp_files = 0` still writes "temporary file" lines (no statement
text) from a big unseen session. **Driver**: the unseen prelude turns
temp-file logging off as well (next fix).
- `26bcbba` (chunk 8): `NO_LOG_SQL` ends with `SET log_temp_files = -1`
  (every session it starts runs as `postgres`), and `CHECK_ROLE_SETTINGS`
  gains `log_temp_files = -1` for `gm_check`'s remote sessions (set by a
  superuser, cleared on reset). The composed test load (server at
  `log_temp_files = 0`, as the seeds) forces a spill with and without the
  prelude and asserts only the plain session's temporary file is logged,
  and that `gm_check` logs in with `-1` (the mutation fails as expected).
  Unit suite 1092 OK.

### Chunk 9 — merged (7f95c5b), 2026-11-04

Five owners (stopped on gaps, paused twice on context, stopped on the
`load-data` defect, finished): 9a `86bbc16` (`domain.yaml`, `data/`,
`docs/`), 9b `ded1b67` (`producers/`, `variants/`, `fixture-core`, the
root README's domains row), squashed linear on `f63899a`, merge `7f95c5b`.
Unit suite 1092 OK (2 skipped); `check_domain_dir` clean.
`fixture-core` (bastion, records, `clinic-api`, `pms`; composed by
`gmctl compose`, aging `{minimum: 8h, handover_at: "14:00"}`) under the
lock after `fit` (2 CPU / 4G / 8G; 4.19G disk, 6.97G with the snapshot):
**40/40 in 157 s**, deploy 14 s, `load-data` 97 s, 49 MB, the load
unseen, `clinic_lookup`'s answers (41 current stays, slowest 83 ms, no
contact ever), `role_vet_app_password` on `pms` only, `pms` started with
its jobs and no error (quiet at intensity 0.1: its keys were checked as
`vet_app` in SQL, not live). Done when:
- the load at +2 (T0 2026-11-04T10:00Z) 88.6 s and at 0 (T0
  2026-03-18T15:37Z) 89.5 s or 112.7 s, 49 MB, 274 235 and 274 404 rows
  (exact counts);
- all 213 columns classed (20 personal, 15 customer-linked, 178
  internal), 25 tables in seven activities;
- `pms`' 23 keys (21 streams, 2 jobs) each run as `vet_app`, 0 errors;
- the lookups answer for loaded animals and never return a contact;
- the GM notes carry every function and range (`gm.md`, 759 lines);
- the catalogues' shares measured: analyses 13 584 (routine codes within
  2.2/3.0/4.7 points of their weights, the gap from distinct codes per
  consultation; 0 urgent out-of-hours analyses not night-capable),
  imaging 3 033 (59.5/29.3/11.2; routine DX 44.7, US 31.2, CT 14.9, MR
  7.0, NM 2.2); the 13 validity checks zero at both shifts;
- measured administrations 218.6 a day (D393's 210).
Own decisions: `prescriptions.expire`'s rule (antimicrobials past five
days; others past their lines' days or validity), matching `load.sql`'s
`expired`; live staff picked by parameter (as D391); a live transfer
records the outbound exchange `requested` (purpose 4 sends it); live
consultations draw no `MINH` and emergencies no referral; `vet_app` gets
`USAGE` on the owners' and animals' sequences. Risks: the core's load
about 90 s and every part's load calls the same functions; the shift-0
time varied by 23 s; the fixture keeps a copied fault
(`fixture-random-page-cost`); `domains:` scenarios carry no data register
until chunk 17.

**Capture W2-d — chunk 9 outcomes (`vet-core`'s keys and its lookup API; read by every part and purpose)**

- **The eighteen functions** (`data/keys.sql`, `pg_temp.core_*`; `docs/gm.md`
  "Core keys" holds their formulas and salts). Id functions take `(n)`:
  `core_staff`, `core_species`, `core_microchip` ('941' ‖ lpad((7 919 813 n
  + 104 729) mod 10¹², 12)), `core_ueln` ('941001' ‖ lpad((7 919 n + 1 009)
  mod 10⁹, 9)), `core_passport` ('XA' ‖ lpad((104 723 n + 7) mod 10¹⁰, 10)),
  `core_ear_tag` ('XA' ‖ lpad((9 973 n + 31) mod 10¹², 12)), `core_holding`
  ('XA' ‖ lpad(7 883 h + 100 003, 9)), `core_referring_practice` ((v + 1)/2).
  Timed functions take `(n, load_epoch, utc_offset)`: `core_animal`,
  `core_owner`, `core_ownership`, `core_stay`, `core_stay_alert`,
  `core_death`, `core_consultation`, `core_request`, `core_exchange`,
  `core_shifts`. All `IMMUTABLE`, no row outside their range or after T0;
  the `pg_temp.vc_*` helpers are internal (item 0 reserves `core_*`).
- **Ranges**: sites 1–6; sections 1 horse, 2 farm, 3 domestic; staff
  1–85 in `core_staff`'s layout (carers 57–60 horse, 61–62 farm, 63–66
  domestic, D394); owners 1–10 000; herds 1–200 (keeper h+1); animals
  1–17 000; consultations 1–25 000 (sparse); a referral's id its first
  consultation's; requests 1–17 000; stays 1–2 500; exchanges 1–700;
  prescriptions 1–15 000; administrations 1–70 000 (61 241 used). The
  sequences resume after their ranges.
- **`clinic-api`'s contract**, as `vet_lookup` (animals without the death
  columns, ownerships, owners' `id`, `kind`, `name`, stays' census
  columns), behind `clinic_lookup`: `GET /animals/{id}` (13 columns, ISO
  8601 UTC with `Z`; 404 `{"detail":"not found"}`); `GET
  /animals?microchip=|ueln=|ear_tag=` (exactly one, else 422 `{"detail":
  "exactly one of microchip, ueln or ear_tag"}`; a list, `[]` when none);
  `GET /animals/{id}/owner` (the current owner's `id`, `kind`, `name`;
  404); `GET /stays?current=true` (`stay_id`, `animal_id`, `section_id`,
  `admitted_at`, `name`, `species`; 422 otherwise); `statement_timeout` 5
  s, pool 4, 401 without the credential, 503 before `load-data`.
- **Rulings as built**:
  - D384: one weekend duty vet per section.
  - D385: per block of 40 consultation ids, 17 places make 27 requests;
    a one-request place is imaging by a section rate (0.395 / 0.68 /
    0.41), otherwise one lab order per consultation. At +2: 42.5 % of
    consultations, 7 432 orders of 1.83 tests.
  - D386: places, counts, stay sections and outcomes shuffled per block
    by hashes (`vc_stay_place`/`vc_stay_at`, `vc_stay_outcome`); most
    stays at once 17/9/23.
  - D388: nurses' cycle `(n + week) mod 4`, every shift held, 47.3 h a
    week; `vc_absence`, 633 periods, 90 % leave.
  - D389: `vc_herd_visit_on`; `withdrawal_ends_on` = visit + 10.
  - D390: examinations placed in office time inside their interval, ids
    in time order.
  - D391: `given_by` by a hash.
  - D393: the round doses each active ward line at its frequency
    (measured 218.6 a day, 36 a round).
  - D394: the carers' split.
- **`pms`**: 21 streams and 2 jobs (`administrations-round` `0
  2,6,10,14,18,22 * * *`, `prescriptions-expire` `15 0 * * *`), 23 keys,
  no builder, each run as `vet_app`.
- **Load figures**: 88.6 s at +2, 89.5–112.7 s at 0; 49 MB; 274 235 and
  274 404 rows; through `load-data` on Swarm 91–97 s; `core_consultation`
  about 41 s, `core_request` about 38 s of it.

### Wave gate — results, 2026-11-04

`coding-executor` (steps 1 to 5), then the driver (step 6), armenelos
alone, 2026-11-04 04:57Z to 07:21Z, the laptop suspended from about
06:35Z to 07:15Z (the executor stopped while step 6 began, resumed by
the driver from its scripts); κ = 1, every step under the host lock and
the sleep inhibitor, each bounded at 29 minutes. Branch at `c486fb8`
throughout; no fix was needed during the gate (the early gate fixes are
logged above). Logs:
`/tmp/claude-1001/-home-bastien-work-db-audit-gm/626ab41f-a466-4175-9a28-a4f76cedff0e/scratchpad/gate-w2/`,
copied to `db_audit_gm-wt/v0.5-resume-2026-11-04/gate-w2/` (not kept).

| Item | Result | Wall |
|---|---|---|
| Unit suite (`tools/tests`) | 1092 OK, 2 skipped (the composed-load pair, run in step 5) | 157 s |
| `bricks/scheduler` unit runner | 91 OK | 215 s |
| `bricks/api` unit runner | 36 OK | 3 s |
| `sh -n` (212 files), `perl -c` (13), `py_compile` (67 outside `tools/`, 82 in it), no `__pycache__` left | 0 fail | — |
| `postgres` 0.5.0 build / stack test | ok / 302 PASS | 0 s / 492 s |
| `scheduler` 0.3.0 | ok / 178 PASS | 0 s / 828 s |
| `bastion` 0.5.0 | ok / 90 PASS | 0 s / 83 s |
| `grafana` 0.3.0 | ok / 130 PASS | 0 s / 158 s |
| `api` 0.1.0 | ok / 88 PASS | 0 s / 194 s |
| `pgbouncer` 0.1.1 | ok / 120 PASS | 0 s / 174 s |
| `prometheus` 0.2.0 | ok / 131 PASS | 0 s / 78 s |
| `postgres-exporter` 0.2.0 | ok / 103 PASS | 0 s / 98 s |
| `pgwatch` 0.1.0 | ok / 72 PASS | 0 s / 252 s |
| `health-check` 0.1.0 | ok / 95 PASS | 1 s / 159 s |
| `smoke.sh` | 61/61 | 30 s |
| `smoke-monitoring.sh` | 43/43 | 52 s |
| `smoke-governance.sh armenelos` | 121/121 | 104 s |
| `smoke-load.sh armenelos` | 73/73 | 405 s |
| `smoke-scenario.sh bookshop-new-server` | 19/19 | 21 s |
| `smoke-scenario.sh fernway-clinics-monitoring` | 18/18 | 30 s |
| `smoke-scenario.sh tarnbeck-outdoor-shop` | 26/26 | 822 s |
| `smoke-scenario.sh tarnbeck-outdoor-campaign` | 33/33 | 313 s |
| fixture-alias (chunk 7) | 23/23 | 38 s |
| the composed test load (chunk 8, `GM_TEST_COMPOSED_LOAD=1`: a composed load passing, a broken range failing) | 2 OK | 11 s |
| `smoke-monitoring-v05.sh` (chunk 10) | 27/27 | 144 s |
| fixture-partners (chunk 11) | 51/51 | 129 s |
| fixture-archive (chunk 11) | 45/45 | 339 s |
| fixture-core (chunk 9) | 40/40 | 151 s |
| `vet-core`'s load, shift 0 / +2 (`load_epoch` 2026-11-04T07:18Z) | 89.0 s / 89.5 s; 49 MB; 273 970 / 274 003 rows in the 25 tables | — |

Chunk 6's refusal fixture is a unit-suite item (`test_model.py`, the
v0.5 refusal classes), passed in the suite. Row counts differ from
chunk 9's (274 235 at +2, epoch 2026-03-18T15:37Z) by design: the history
runs to `load_epoch`.

The gate fixes made early, confirmed: fixture-archive shows one segment
name posted by two sources making two manifests and the same shipment
id again replacing its own (D381); fixture-partners shows `gm_check`
granted CONNECT on `partners-db` and refused from the network and from
the bastion (D383); the composed test load ran the partners' coherence
check on the partners' node; `bricks/postgres/docs/gm.md` carries the
partners' `pg_hba` form (`990941b`).

Image sizes (armenelos, 2026-11-04): `postgres:0.5.0` 265 MB (pgCluu
added), `scheduler:0.3.0` 171 MB, `bastion:0.5.0` 186 MB, `grafana:0.3.0`
866 MB, `api:0.1.0` 218 MB, `pgbouncer:0.1.1` 182 MB, `prometheus:0.2.0`
488 MB, `postgres-exporter:0.2.0` 165 MB, `pgwatch:0.1.0` 167 MB,
`health-check:0.1.0` 195 MB. `/var` 34 GB free; nothing pruned; no
container, stack or volume of the gate's left.

Wave 2's gate **passed (2026-11-04)**, at `c486fb8`. Wave sync: none (no
intent register); dependency post-change check: G10, done. G16 next
(`spec-writer`). Not merged into `main`: the owner's word.

### G16 — wave 2's formats as built (spec-writer, 2026-11-04)

`430d554`: formats.md draft v29 (a "Partners (from v0.5)" section; "Loading
a composed domain": `:"DBNAME"`, `load_epoch`, `keys.sql` ahead of each
load, a partner's `data.sql` into `partners`, the load order, `gm_src_*`;
`coherence.yaml` and D383's placement; the prefix rule; the owners'
traffic in `producers/partners/owners/`, D369; "a domain is a
design-time source" corrected for composed domains; `register_diff`
required on a register fault; the `ops` trace rule; `crontab_roles: []`);
master spec 5 and 6.1, and 9.7's and 24's "chosen at the build" markers,
settled to match. No decision added. Left out as not file formats: W2-b's
aliases and secrets, W2-d's functions, W2-e's seed contents, D381 (master
spec 10.4 already). G16 **done (2026-11-04)**.

Found, not settled by G16:
1. `model.GM_HBA_LINES` still accepts `host all gm_check samenet
   scram-sha-256` in a third party's `pg_hba.conf`, against D383 and
   access model 8: a gate fix (chunk 6's check, chunk 11's ruling) sent to
   a `coding-executor` on the wave branch, with two checks the formats
   state and the loader lacks (a partner `data.sql` never creating a
   database or `\connect`ing; `partners` refused as a domain id).
2. A `public/` `data.sql` is accepted, not yet refused: chunk 17's, as
   planned.
3. Drift outside the spec, sent with item 1: the scenario-format skill's
   `templates/keys.sql` (`STABLE`, against D379's `IMMUTABLE`) and
   `templates/layouts.md` (no `keys.sql`, `coherence.yaml`, partner
   `data.sql`; "made at the build"); the root README's `domains/` row.
4. formats.md's scenario layout lacks wave 1's `compose/<node>/` layer:
   back to `spec-writer`.

### The owner's answers on the open points, 2026-11-04

1. `a100f5a` (wave 1's harness ruling, `smoke-scenario.sh`): **confirmed**.
2. G6, the PyPI lockfile for `api`: the owner is on the fence and keeps
   the current set ("we will follow your current usage and see how it
   goes"); no Debian-only policy.
3. pgBadger: in `.tech` (13.3, unpinned) since G8; the owner asked for it
   on the tech list, which it is.
4. D365, the customer's own partner credentials in the starter pack:
   kept as is, **tracked**: a DBA may find it odd and report it; the game
   may keep some distance from ground truth. Sent to `spec-writer` to
   record as an open item.
5. G9, pgwatch: the latest release for now (6.1.0). From v1+, versions
   become a game-wide concern (PostgreSQL 13, older and manual tools,
   migrating up to standard). Sent to `spec-writer` to record for v1+.
6. G9/G10, the Go modules in downloaded binaries: the owner asked that
   they be put where the daily sweep sees them; sent to
   `security-advisor`.

### Gate fixes after G16, 2026-11-04

- `9a41056` (`spec-writer`): formats.md v30, wave 1's `compose/<node>/`
  scenario layer; D395 (D365 kept, tracked as O231; access model 13's
  known gap); D396 (latest version per brick until v1.0, versions a
  game-wide concern from v1.0; O11).
- `5a3765f` (`coding-executor`): the loader refuses a `host` line naming
  `gm_check` in a third party's `pg_hba.conf` (D383, access model 8); a
  partner `data.sql` creating a database or `\connect`ing; `partners` as
  a domain id; each with a unit test; the scenario-format skill's
  `keys.sql` (`IMMUTABLE`, D379) and `layouts.md` (v29 domain tree, D369),
  the root README's `domains/` row. Unit suite 1094 OK, 2 skipped;
  fixture-core loaded by hand (not in the suite).
- `8a23bef` (`security-advisor`, the owner's ask on G9/G10's Go
  modules): one CycloneDX SBOM per downloaded Go binary (prometheus,
  promtool, postgres_exporter, grafana, grafana's bundled Prometheus
  data-source plugin, pgwatch) in `bricks/*/sbom/`, listed in `.tech`'s
  `lockfiles`; `tools/go-sbom generate|check` (the exact archive by the
  Dockerfile's checksum, `go version -m`; every binary's hash equal to
  the built image's); `tools/tests/test_go_sbom.py` fails when an SBOM
  disagrees with its Dockerfile. `cve-watch check .`: 110 at or above
  medium, 50 of them Go; triaged per binary: none reachable, grafana's
  kin-openapi and go-jose unknown (behind the login, players already
  admin). The daily sweep reads `main` only: about 50 items after the
  merge, to triage from the `.tech` notes. For the owner: Grafana
  13.2.4 → 13.2.5 (four Grafana CVEs not yet on NVD/OSV) or 13.3.0
  (also go-jose's fix); postgres_exporter 0.20.1 is upstream's latest,
  watch.

### The owner's restore ruling; chunk 28 inserted, 2026-11-04

The owner, on D352: "a restoration procedure that doesn't work means as
much as no procedure at all [...] For now: ensure that restoration works
well (including replications)." A snapshot of the whole game as a
feature of play, with game time, waits (O232). Also: check_postgres kept,
a switch expected some day (D399); pgBadger left unpinned (D400).
`spec-writer` `71eef17`: D397 (supersedes D352), D398 (chunk 28 into wave
2, plan v9), master spec 7.1, 15 ("The restore from the hand-over
snapshot"), 18.2, release gate items 1 and 12. Found besides the standby:
a primary's planted slots lost on restore (`pg_replslot/` not in a base
backup), a false WAL gap in the vault when its database is copied before
an archiving node; the WAL backlog and the cumulative statistics reset
(a known difference, measured by the chunk). Wave 2 is **in progress**
again until chunk 28 merges and its reruns pass.

**Capture W2-g — chunk 28 (read by chunk 28; any later chunk touching
the snapshot or the restart)**
1. **The snapshot record** gains `slots:`, beside `volumes`: a list of
   `{node, name}`, each a persistent physical replication slot on a
   primary (a `postgres` node that is no standby), read when that
   node's copy is taken; a standby's own slot (re-created by its clone)
   and temporary slots left out. A record without `slots:` is read as
   none. Nodes with a `vault_target` are copied first, then the rest in
   `nodes` order.
2. **The restart from a snapshot**, its new steps in this order: (a)
   before the stack starts, each standby's restored data volume gets
   `standby.signal` (owner `postgres`, mode `0600`), so it never runs as
   a primary; (b) once the stack is healthy, on each primary its
   recorded slots re-created (`pg_create_physical_replication_slot(name,
   true)`: reserving WAL at once, inactive); (c) then each standby, in
   topology order, cloned through `inject.clone_standby` in restore mode
   (`replicator` set, the clone, the wait until its sender streams);
   (d) the restart's text and record name the slots re-created and the
   standbys cloned. A failure in (a)–(c) is a failed restart as today
   (torn down, recorded, the snapshot kept, a retry accepted). A restart
   without a snapshot is unchanged.
3. **`clone-standby`'s restore mode**: one argument, `clone-standby
   --restore`; with it, the standby's own `postgresql.auto.conf` is saved
   before PGDATA is emptied and put back after `pg_basebackup -R`, the
   conninfo check still applied to the result; without arguments it is
   `load-data`'s mode, unchanged; any other argument a usage error (exit
   2). `inject.clone_standby` takes `restore=False`, passing `--restore`
   when true.

### Chunk 28 — merged (1cfd371), 2026-11-04

`53f4e63`, merged `--no-ff` as `1cfd371` (no conflict; worktree removed,
branch kept). Done when, from the owner's report:
- unit tests (`test_snapshot`, `test_restart` on fixture-restore,
  `test_inject`): `records` (the `vault_target` node) copied first; only
  the primaries' persistent physical slots recorded (`old_reports`; the
  standby's own, the temporary `gm_snapshot` and a logical slot left
  out), a failed slot read a failed snapshot; the restart writing
  `standby.signal` (`install -o postgres -g postgres -m 0600`) into the
  restored standby volume before `stack deploy`, re-creating the slot,
  then `replicator`, `clone-standby --restore` and the streaming wait;
  record and text naming `slots` and `standbys`; a clone or slot failure
  a failed restart (snapshot kept, the retry completing); a record
  without `slots:` restoring with none; a standby without its `pgdata`
  copy failing before the stack; no snapshot, unchanged. Suite 1105 OK,
  2 skipped, 174 s.
- `postgres` 0.5.0 rebuilt, stack test passed, 467 s: `--bogus` exit 2;
  a `statement_timeout` written into the standby's `postgresql.auto.conf`
  kept by `--restore` (600 `postgres:postgres`, the conninfo naming the
  password file only), streaming after it; the default mode keeping
  nothing and streaming.
- fixture-restore (`run-short-test.sh`): 36/36, 93 s (the restart 37 s):
  the standby's log since the restore in standby mode only, never
  promoted or on a new timeline; its slot active, its sender streaming;
  a read answered, a write refused; a row written after the restart read
  on the standby at once, one written between the snapshot and the
  restart gone; `old_reports` back, inactive, reserving; a switched
  segment's manifest `records:wal`, `failed_count` unchanged, the vault's
  earlier manifests kept; teardown leaving nothing, the copies included.
- measured after a restore (`docs/gm.md`, "Snapshot"): WAL held by the
  planted slot 48 MB → 33 MB (from its new `restart_lsn`), `pg_wal` 65M →
  49M, `pg_stat_archiver` counting from the restore, `n_tup_ins` 22000 →
  1: the backlog and the counters start again, as master spec 15 says.
- `docs/gm.md` ("The standby", "Snapshot", "Stack test"; D352's known
  limit removed) and `gmctl.md`'s `restart` row.
Own choices within W2-g: `slots: []` always written on a taken snapshot;
the restart record's `slots: [{node, name}]` and `standbys: [{node,
primary, slot}]`; `--restore` puts the saved file back whole; slots read
just before each primary's first copy; `tools/tests/__init__.py`'s
`FakeDocker` answers the slot query (outside Files, three lines). Left:
`gmctl.md`'s `snapshot` row (copy order, `slots:`) not updated (not in
Files); the `scenario-document` template has no row for `standby_of` or
`third_parties` (fixture-restore's README shows the standby through its
node and flows, as fixture-archive's); `shellcheck` not installed on
armenelos (only `sh -n`). Risks: a standby whose `postgresql.auto.conf`
lacks `primary_conninfo` fails the restart at the streaming wait (by
design); a logical slot is neither recorded nor re-created (W2-g:
physical).

### Wave 2 gate — reruns after chunk 28, 2026-11-04

On `1cfd371`, armenelos alone, under the lock and the inhibitor: unit
suite 1105 OK, 2 skipped (169 s); `sh -n` 213 files, 0 fail (no
`shellcheck` on armenelos); `postgres` 0.5.0 build (image `2ee628d58ded`,
chunk 28's) and stack test 314 PASS / 1 FAIL (465 s); `smoke.sh` 61/61 (29
s, the snapshot's new copy order); fixture-restore 36/36 (83 s). The one
failure is the stack test's own race, no chunk 28 code: "db2: the
postmaster's children" read `/proc/<pid>/oom_score_adj` of a child that
had exited between the listing and the read (`cat: /proc/446/...: No
such file`); it passed in chunk 28's run and at the gate. Sent to a
`coding-executor`: the check skips a child gone before its read, then
the stack test rerun.

Gate fixes `ed863df` (the stack test's `oom_score_adj` checks skip a
process gone before its read: the children's, the postmaster/s6/sshd/cron
line's, db2's cron daemon's with `sort -u`; the script isn't in the
image, no rebuild) and `1a7562e` (`gmctl.md`'s `snapshot` row: the copy
order and `slots:`; the root README's `purposes/` row as the `domains/`
row, and rows for `tools/go-sbom` and `bricks/<brick>/sbom/`). `postgres`
stack test rerun: **315/315**, 459 s; unit suite 1105 OK, 2 skipped, 174
s. Wave 2's gate **passed again (2026-11-04)**, at `ed863df`, chunk 28
in.

### Wave 2 — report to the owner, 2026-11-04

- **Chunks merged**: 6 (f3eb50d), 7 (a7b76ff), 8 (4b22401), 9 (7f95c5b),
  10 (35e8bf7), 11 (dc4fdd5), and 28 (1cfd371), inserted after the gate
  on the owner's restore ruling (D397, D398). None moved. Chunk 9
  stopped three times on spec gaps (catalogues and functions; rota and
  requests; administrations and carers), each settled by `spec-writer`
  without the owner, and once on a defect in `load-data`; chunks 7, 8
  and 9 were resumed by fresh owners from WIP commits.
- **Gates**: G9, G10 and G16 done. The wave gate passed at `c486fb8`
  (no fix during it), then its touched items were rerun after chunk 28
  (above). Gate fixes: early, while chunks ran, `9131cc4`, `c1f7d2f`
  (D381), `2035b0e` (D383), `990941b`, `e5d158c`, `5900212`, `26bcbba`;
  after G16, `5a3765f` (the loader enforcing D383, a partner `data.sql`
  and the `partners` id; skill templates), `8a23bef` (the Go binaries'
  SBOMs in the daily sweep), `ed863df` and `1a7562e`.
- **Figures** (armenelos, 2026-11-04): `vet-core`'s load 89.0 s at shift
  0, 89.5 s at +2, 49 MB, about 274 000 rows; the restore fixture 83–93
  s (the restart 37 s); `postgres:0.5.0` 265 MB, `pgwatch:0.1.0` 167 MB,
  `health-check:0.1.0` 195 MB (the rest above); `/var` 34 GB free,
  nothing pruned.
- **Rulings**: spec D360 to D400 (plan v4 to v9); D371 and D392 unused.
  The owner's this wave: D395 (D365 kept, tracked as O231), D396 (latest
  versions until v1.0, versions game-wide from v1.0), D397 (the restore
  gives back replication, superseding D352), D398 (chunk 28), D399
  (check_postgres kept, a switch expected), D400 (pgBadger unpinned);
  O232 (a snapshot of the whole game as a feature of play, with game
  time; later). Information only: access model 8 reworded (D383) and 13's
  new known gap (D395); master spec 9.2, 9.4, 9.6 text corrections (D372
  to D380, D387); formats.md draft v30 (G16, `compose/<node>/`).
- **Settled by the owner on 2026-11-04**: `a100f5a` confirmed; G6's PyPI
  set kept ("see how it goes"); pgBadger listed, unpinned; D365 kept and
  tracked; pgwatch the latest; the Go modules in the sweep (done); the
  restore fixed (chunk 28); check_postgres kept.
- **For the owner, open**:
  1. Grafana 13.2.4 → 13.2.5 (four Grafana CVEs, not yet on NVD/OSV) or
     13.3.0 (go-jose's fix too; D396's "latest"). The driver recommends
     13.3.0 as a gate fix with Grafana's stack test and the monitoring
     smokes rerun, or as wave 3's first fix.
  2. After the merge, the daily sweep will write about 50 Go items into
     `SECURITY_TODO.md` (none reachable, triaged in `.tech`), and about
     18 OpenSSL ones (Debian backports): a triage pass then, or `.tech`
     ignore entries with a review date if a quieter list is preferred.
- **Wave sync**: none (no intent register). `doc-ids compare main
  v0.5-w1` and `main v0.5-w2`: 0 collisions.
- **Merge**: `v0.5-w1` then `v0.5-w2` → `main` on the owner's word (w2
  holds w1; merging w2 alone takes both). Wave 3 starts in a fresh
  session, from `main` once merged.

### Grafana 13.3.0, on the owner's word, 2026-11-04

The owner: "bump grafana up" (the report's open point 1; D396). `75c195d`
(`coding-executor`): `grafana` 0.3.0 on Grafana 13.3.0 (the latest
release, 2026-10-27; build 40412481033; sha256 from grafana.com's
package list, `ADD --checksum` at build), no brick version bump (0.3.0
unreleased). 13.3's one breaking change (`[marketplace]` renamed) unused
by the brick; the `$__file{}` password, the time zone refusal, the root
policy's receiver and a provisioned rule's `for` rechecked on 13.3.0.
SBOMs regenerated (Grafana 520 components, the bundled Prometheus plugin
13.2.4 104; both Go 1.27.3). Stack test 130/130 (155 s),
`smoke-monitoring.sh` 43/43 (47 s), `smoke-monitoring-v05.sh` 27/27 (138
s), unit suite 1105 OK, 2 skipped; image 866 MB → 845 MB (the old image
left untagged). `2c0adc3`: grafana-alert-for-too-long's GM note names
13.3.0. `f7f9f99` (`security-advisor`, post-change): **clear**; 13.3.0
fixes the four 13.2.x CVEs (CVE-2026-103506 by the advisory's range, and
its toggle unset in the brick), go-jose 4.1.6 and kin-openapi 0.151.0
clear their 11 GHSAs, Go 1.27.3 clears the stdlib set; no advisory
names 13.3.0; the findings left (x/crypto openpgp, x/net html,
aws-sdk-go S3 crypto) not reachable; `.tech` updated, lint clean. The
report's open point 1 is closed.

The owner then: "commit and merge when done". `v0.5-w1` and `v0.5-w2`
merged into `main` (below, in the merge messages).

## Wave 3 — started 2026-11-04

Branch `v0.5-w3`, worktree `/home/bastien/work/db_audit_gm-wt/v0.5-w3`,
cut from `main` at fece30c, after waves 1 and 2 merged into it (167fec0,
f89eb73) on the owner's word. Chunks 12 to 16. No intent register, so no
documentalist preflight; the driver drafted capture W3 from the chunks'
**Architecture capture** lines, as W1 and W2. Gates checked at the
start: G4, the swarm (armenelos `Active`, the leader; `vps-5718ad52`
`Drain`; both `Ready`; engine 29.9.2); `/var` 30G free on armenelos. No
dependency preflight is planned for wave 3: its chunks add no package
beyond the `postgres` image's contrib extensions (`btree_gist`,
`pgcrypto`) and the `api` and `scheduler` bricks as built, and rebuild
no image; G11 stands.

### Capture W3 — the five parts: their keys, the lab's results and stubs, bookings, the board, the machines' days, the portal's scope (chunks 12–16; read by 16 to 27)

Recorded 2026-11-04, before any code; drafted for the wave driver from
the **Architecture capture** lines of chunks 12 to 16 (plan v9, with its
header, "Read first", the gates, the dependency graph, wave 3's order,
the shared lists, "Left for the build" and "The partners, and where each
stub is built"), master spec 8.5, 9.1, 9.3 to 9.7, 10.2, 10.4, 13.1 and
14, access model 9.3, [clinic-purposes.md](clinic-purposes.md), the five
domain documents ([vet-lab](vet-lab-domain.md),
[vet-scheduling](vet-scheduling-domain.md),
[vet-housing](vet-housing-domain.md),
[vet-machinery](vet-machinery-domain.md),
[vet-portal](vet-portal-domain.md)) with
[vet-core-domain.md](vet-core-domain.md), [formats.md](../../formats.md)
v30, O229 ([open-questions.md](../../open-questions.md)), and the code on
`v0.5-w3` at fece30c (`domains/vet-core/`, `partners/`,
`tools/gm/{model,inject,coherence,compose}.py`, `bricks/api/`, the
scenario-format skill). W1's and W2's rules: cited, not restated;
**(choice)** marks a point the sources left open, settled here with its
reason; each item names the chunk that writes it and those that read
it. Held: W1 and W2 with their addenda W1-w to W1-z and W2-a to W2-g;
where the merged code differs from them, the code and the addenda win.
The domain documents stay the column-level input: an item fixes only
what they leave open or what the code forces. Chunks
record their as-built outcomes as **W3-a** (chunk 12), **W3-b** (chunk
13), **W3-c** (chunk 14), **W3-d** (chunk 15) and **W3-e** (chunk 16);
chunk 29, if inserted (Preflight corrections, item 1), as **W3-f**.

**0. Rules shared by the five parts** (read by 12 to 27)

- **Column names (choice)**: a column a domain document lists in words
  takes those words in snake_case ("booked at" `booked_at`, "released
  by and at" `released_by`, `released_at`, "numeric value or text value"
  `numeric_value`, `text_value`); a time ends `_at`, a date `_on`, a
  staff member `_by` (the core's staff id), a key `<thing>_id`. Reason:
  chunks 18 to 25 query these tables from the documents alone; one rule
  replaces five column lists.
- **Roles (choice)**: a part's schema creates, at top level, exactly the
  roles of its document's "Application roles and grants" table, and
  grants the core's roles what that table says (`vet_display`,
  `vet_reports` on housing's and scheduling's tables). A several-database part creates its roles
  once, in its first database's `schema.sql` (`pacs`, in `databases`
  order), the others only granting: roles are the instance's, and a
  second `CREATE ROLE` fails. The roles of clinic-purposes' "The roles
  the purposes add" (`lab_release`, `lab_watch`, `sched_interfaces`,
  `mach_orders`, `mach_archive`, `portal_sync`, `portal_dispatch`), their
  grants and policies, and the `ops` schema are not the parts'
  (Preflight corrections, item 4). Reason: `model.node_creates` reads a
  top-level `CREATE ROLE` (W2-a), so each role gets its secret; a part's
  chunk cannot know a purpose's grants.
- **A part's key functions (choice)**: a part may ship `data/keys.sql`,
  defining `pg_temp.<its table prefix>_*` functions only (`lab_`,
  `portal_`), on the core's conventions (`(n integer)` or `(n integer,
  load_epoch timestamptz, utc_offset integer)`, `IMMUTABLE`, no row
  outside its range: vet-core's GM notes, "Core keys"), listed in a "Part
  keys" section of its GM notes; `load-data` streams it after the
  core's, ahead of that part's `load.sql`, its partners' `data.sql` and
  its `derive.sql`. The lab (its load and its two stubs, item 1) and the
  portal (its load, its derivation and the owners' state, item 5) need
  it; scheduling, housing and machinery compute from the core's alone.
  Today `inject._keys` streams the core's file only: chunk 29's (a).
  Reason: W2 item 3's own, one text for every file computing the same
  ids.
- **Producers left out of a fixture (choice)**: `composition.yaml` gains
  an optional `left_out:` list of `{domain, producer, reason}`,
  `producer` a folder under that domain's `producers/` (`pms`,
  `api/clinic-api`, `partners/xlab`); `gmctl compose` merges nothing from
  it and needs no node for it; a left-out partner folder's `data.sql`
  still runs when the scenario has a partners' database and is skipped
  when it has none (the loader's refusal then not applying; a coherence
  check reading `partners` skipped, as today). For fixtures: the clinic
  leaves nothing out. Chunk 29's (b). Reason: compose needs a node for
  every producer folder of every composed domain (`compose.py`, W1-w;
  chunk 9 added `pms` to `fixture-core` for it), which puts the lab's
  fixture at ten nodes and the portal's at twelve, against "Read
  first"'s eight and D314's least environment (Preflight corrections,
  item 2).
- **Shapes and connections on a shared node (choice)**: a part's
  fragment on `pms` names the core's shapes (`clinic-day`, `office`,
  `flat`) and never writes them; on its own node (`lis`, `ward`,
  `equipment`) it writes every shape it uses, the core's copied
  unchanged; connections are unique per node (`sched`, `housing`,
  `portal-api` beside `clinic` on `pms`). Reason: compose merges
  identical entries silently and stops on two different ones (W1-w).
- **HTTP credentials (choice)**, each named by the fragment owning the
  endpoint, since compose merges `endpoints.<name>` whole (W2 item 4):

  | Endpoint (host) | Accepts | Sent by |
  |---|---|---|
  | `orders` (`lab-api`) | `lab_centre`, `lab_practices` | purpose 1 on `interfaces` (account 1); the practices' stub |
  | `send_outs` (`lab-api`) | `lab_xlab` | the external lab's stub |
  | `xlab_orders` (`northfield-lab`) | `xlab_customer` | purpose 3 |
  | `practices_results` (`practices`) | `practices_customer` | purpose 2 |
  | each stub's `<prefix>_tick` | `partners_backend` | the back end (W2-f) |
  | `desk` (`portal-api`) | `portal_desk` | `pms`' `portal.desk-consent` |
  | `portal-api`'s owner endpoints | public, the session cookie (item 5) | the owners' route |

  The brick tells a route no caller apart (`gm_api` checks a bearer
  against the endpoint's list only), so `lab-api` takes the account from
  the request and trusts it: the 120 practices share one credential, and
  rule 10 ("each practice seeing only its own orders") holds by the stub
  asking for its own, a known limit for the lab's GM notes. The
  `*_customer` credentials are the customer's own with each partner,
  which chunk 17 hands over (D365, O231).

**1. `vet-lab`** (chunk 12 writes, W3-a records; read by 16, 18, 19, 20,
22, 25)

- **Keys**: the document's "Deterministic key ranges (D249, D266)" and
  "The test catalogue (D372)"; of the core's, `core_request` (a
  consultation's analysis requests, one order per priority) and the
  identity and staff functions its "Core keys used" names. Its
  `data/keys.sql` **(choice)** holds at least `pg_temp.lab_order(n,
  load_epoch, utc_offset)` (order 1–14 000: account, `client_ref`,
  priority, its times and state at T0, the centre's consultation and
  animal or a practice's patient fields) and `pg_temp.lab_send_out(n,
  load_epoch, utc_offset)` (its order test, `send_key`, the external
  lab's accession, its times, `status` and `due_by` at T0), called by
  the load and by both stubs' `data.sql`. A `send_key` is computed from
  the send-out's id (`md5(...)::uuid`), never `gen_random_uuid()`: the
  stub holds the same key.
- **The released results** (read by 16's derivation, purpose 15 as
  `lab_release`, purposes 9 and 10): `lab_orders`, `lab_order_tests` and
  `lab_results` named by item 0 (`lab_orders.account_id`, 1 the centre;
  `lab_order_tests.order_id`, `status`, `not_performed_reason`,
  `released_by`, `released_at`; `lab_results.order_test_id`,
  `numeric_value`, `text_value`, `flag`, `interval_id`, `supersedes_id`,
  `amended_at`). The result in force is the one no row supersedes; a
  centre result's gate is `released_at` with `account_id = 1`
  (vet-portal, "Cross-part assumptions").
- **`lab-api`'s contract (choice)**, port 8000 under its own hostname,
  connection `lab` as `lab_api`; JSON keys the column names, times ISO
  8601 UTC with `Z`, 404 `{"detail": "not found"}`, the brick's 401 and
  503 (as `clinic-api`'s, W2-d):
  - endpoint `orders`: `POST /orders` `{account, client_ref, priority,
    tests: [{code, request_id?}], ...}` (the rest `lab_orders`' columns,
    each optional) → 201 `{accession, account, client_ref, tests: [{order_test_id, code,
    request_id}]}`; the same account and `client_ref` again → 200, the
    same body, nothing written; an unknown code or account 422.
    `GET /orders/{accession}`: the order, its state, its tests with
    their results in force. **The feed**, `GET
    /orders?account=<id>&released_since=<time>` (both required, else
    422): the account's order tests whose status became `released`,
    `not-performed` or `cancelled` at or after the time, ordered by that
    time then `order_test_id`, each `{accession, client_ref,
    order_test_id, request_id, code, status, at, reason, results:
    [{analyte, numeric_value, text_value, unit, flag, low, high}]}`
    (`results` empty unless released). Inclusive, so a poller's margin
    re-reads and its ledger deduplicates (purpose 1, W4); an amendment
    after release lists no test again (the portal reads amendments in
    the lab, purpose 15);
  - endpoint `send_outs`: `POST /send-outs/{send_key}/result` `{accession,
    resulted_at, results: [{analyte, numeric_value?, text_value?, unit?,
    flag?}]}` → 200 `{send_key, status: "resulted"}`; the same key again
    200 with nothing written twice; an unknown key 404.
- **The stubs (choice)**: `xlab` serving `northfield-lab` (D370),
  `practices` serving `practices`; every practice account's
  `callback_url` `http://practices:8000/results` (one stub, D293; the
  delivery names its account). On `partners-db`, each schema its
  prefix's:
  - `xlab.orders (send_key uuid PRIMARY KEY, accession text UNIQUE,
    lab_accession integer, label, test_code, species, sex, age,
    received_at, due_at, answered_at, answer jsonb, resends integer)`,
    `xlab.state` (W2-f);
  - `practices.orders (account_id, client_ref, accession, priority,
    tests, posted_at, PRIMARY KEY (account_id, client_ref))`,
    `practices.deliveries (delivery_key text PRIMARY KEY, account_id,
    accession, kind, first_at, last_at, repeats integer)`,
    `practices.state`;
  - planted by their `data.sql` from `pg_temp.lab_*`: every send-out the
    history leaves open (about twenty) and every practice order not yet
    completed at T0 (D304). Purposes 2 and 3's checks (chunk 18) read
    these tables as evidence.
- **Coherence** (W2-c's form): every `request_id`, `animal_id` and staff
  id within the core's, reading `vet-core`; the stubs' open send-outs
  and orders against the lab's, reading `partners` and `vet-lab`, so
  run in `partners` on `partners-db` (D383).
- **Fixture** `fixture-lab-core`: the bastion, `records`, `clinic-api`,
  `lab`, `lis`, `lab-api`, `partners-db` (seven); `left_out` vet-core's
  `pms` and vet-lab's `partners/xlab` and `partners/practices`: the
  stubs' state loaded and checked, their fragments composed in a unit
  test only (Preflight corrections, item 2).

**2. `vet-scheduling`** (chunk 13 writes, W3-b records; read by 20, 21)

- **The bookings' tables**: the document's "Entities" and "Deterministic
  key ranges (D249, D266)", names by item 0; `sched_bookings.state`
  `booked`, `arrived`, `no-show`, `cancelled`, `held`; an attended
  history booking's id is its consultation's (`core_consultation`'s
  `booking_id`), an imaging one's `30 000 + request_id`; live bookings
  take the sequence, above 50 000; `sched_allocations.during`
  `tstzrange(starts_at, ends_at, '[)')`, the four exclusion constraints
  named `sched_allocations_{staff,room,machine,animal}_excl`.
- **The slot function (choice)**: `sched_free_slots(type_id integer,
  after timestamptz, how_many integer DEFAULT 1) RETURNS TABLE
  (starts_at timestamptz, ends_at timestamptz, staff_ids integer[],
  room_id integer, machine_id integer)`, `LANGUAGE sql STABLE`, security
  invoker, `SET search_path = public, pg_temp`; `staff_ids` in the
  type's order (the vet first, then the nurse or the theatre team); no
  slot past `now()` plus the horizon. Executed by `sched_app` and, from
  W4, `sched_interfaces` (purpose 11's `book-requests`).
- **The booking horizon (choice; "Left for the build")**:
  `sched_settings`' 42 days bind `sched_free_slots` only, so the phone,
  desk, follow-up and referral bookings and the purposes' imaging ones.
  Session days (planned three months ahead, `open` eight weeks ahead)
  and theatre plans are inserted directly, by the load and their
  streams, under the same exclusion constraints, so a slot search
  within 42 days sees them taken. Reason: the document holds both
  figures; the horizon is reception's rule, the training centre's
  planning no slot search.
- **The rota's published weeks (choice)**: a week runs Monday 00:00 to
  Monday 00:00 in the customer's zone (`core_shifts`' own week);
  `sched.rota.publish`, Friday 12:00, publishes the week starting ten
  days later, `published_at` that Friday 12:00, idempotent on
  (`staff_id`, `starts_at`). The load writes every shift to the end of
  the week the last Friday 12:00 before T0 published, each week's
  `published_at` its own Friday, clocked up to T0: at T0 the rota runs
  to the end of next week before Friday noon, of the week after next
  from it (the document's "to the end of the week after next" holds from
  Friday noon; the job's rule wins). A `core_shifts` row with an absence
  becomes a `sched_absences` period, never a shift. Purpose 12 (chunk
  20) reads `clocked_in_at` and `clocked_out_at` against `starts_at` and
  `ends_at`.
- **Fixture** `fixture-bookings`: the plan's four nodes and `clinic-api`
  (compose's need for vet-core), T0 a weekday at 09:50.

**3. `vet-housing`** (chunk 14 writes, W3-c records; read by 20, 25)

- **The board's statement (choice)**: the key `ward.board` in
  `producers/ward/queries.yaml`, its SQL exactly `SELECT * FROM
  housing_unit_board WHERE unit_id = %(unit)s`, `unit` `{int: [1, 64]}`,
  on connection `ward-board` (`records:5432/clinic` as `vet_display`,
  `pool: {size: 4}`); its stream 3 840/h, even, `flat`, concurrency 4.
  Reason: s9's calls must be this one statement (one `queryid` in
  `pg_stat_statements`), its `$1` the unit (D287's chain).
- **The display's key (choice)**, s9's (chunk 25): a stream in the
  fixture's or scenario's `compose/ward/` layer, its key the fault's,
  whose `sql` is `ward.board`'s byte for byte with `unit` fixed (`{int:
  [u, u]}`), on `ward-board`, at a rate well above one a minute;
  "cleared" removes it from that layer. Chunk 14 provides nothing for it
  but the statement and the GM notes' "D287 applied: finding a faulty
  display".
- **The occupancy measure (choice)**, purpose 9's feeder (chunk 20), on
  the standby as `vet_reports`, per section at each local midnight `t`:
  units in service, `housing_units` with `state <> 'out-of-service'`;
  units occupied, distinct `unit_id` of `housing_placements` with
  `from_at <= t AND (until_at IS NULL OR until_at > t)`. `state` keeps
  no history (out of service at load only), so its present value stands
  for every midnight; counting out-of-service units as available is
  T171. The GM notes give the query; the schema grants `vet_reports`
  `SELECT` on every housing table.
- **Fixture** `fixture-housing`: the plan's four nodes and `clinic-api`
  (five); chunk 25 adds s9's instance and its answer key.

**4. `vet-machinery`** (chunk 15 writes, W3-d records; read by 21, 23)

- **The tables purposes 13 and 14 use**: in `pacs`, `mach_worklist`
  (`accession` `I-<request_id>`, `UNIQUE`, the idempotency key; `state`),
  `mach_studies` (`worklist_id`, `state`), `mach_reports` (`study_id`,
  `kind`, `status`, `signed_at`, `supersedes_id`); in `vitals`,
  `mach_vitals` (`session_id`, `at`, the measures); in `biomed`,
  `mach_readings` (`machine_id`, `read_at`, `status`, `channels`) and
  `mach_readings_daily` (`machine_id`, `day`, `rows`, `channels`,
  `PRIMARY KEY (machine_id, day)`); names by item 0.
- **The daily partitions (choice)**: `mach_vitals` on `at` and
  `mach_readings` on `read_at` by the customer's local day (`[d 00:00,
  d+1 00:00)` at `customer_utc_offset`, a fixed offset), each named
  `<table>_<yyyymmdd>` by that date, beside `<table>_default`, empty by
  design; `mach_events` monthly, `mach_events_<yyyymm>`. In `vitals` and
  `biomed`, `mach_create_partitions(days integer) RETURNS integer` (the
  partitions it created, today to today plus `days`, idempotent) and
  `mach_drop_shipped(day date) RETURNS boolean` (that day's partition of
  the database's shipped table detached and dropped; false when none),
  both `SECURITY DEFINER`, owned by `mach`, `SET search_path = public,
  pg_temp`. The window is "today and the last full day": at T0 the
  partitions from yesterday to today plus three exist, none older.
- **The summaries kept on site**: `mach_readings_daily`, loaded for every
  day of the year (`rows` the day's raw count), and `mach_vitals_chart`,
  kept five years. **A history day's rows (choice)**, for purpose 14's
  planted manifests (chunk 21): readings, `mach_readings_daily.rows`
  summed over the machines; vitals, the `vitals.sample` ticks (one row
  per open session every 10 seconds on the UTC minute's grid) within
  each `mach_sessions` interval that day, a query on `mach_sessions` the
  GM notes give, which the window's raw rows obey (a coherence query
  checks the window's days against it). Reason: a dropped day keeps no
  raw row, and a history reads its sources through `gm_src_*` alone,
  without keys (W2-c).
- **Its `pg_cron` jobs (choice)**: `vitals-partitions`,
  `readings-partitions` and `events-partitions`, as `mach_maint`, in
  `data/cron.sql` (`cron.schedule_in_database(...)` calls and nothing
  else), which `load-data` runs on the part's node in its
  `cron.database_name` after the part's load (chunk 29's (d)). Reason:
  the node's data file runs before `load-data` creates `vitals`,
  `biomed` and `mach_maint`, and pg_cron refuses a job whose database
  or user it cannot check (Preflight corrections, item 5). `machines`
  preloads pg_cron in the fixture and the clinic.
- **Fixture** `fixture-imaging` as planned (seven nodes, compose's needs
  met).

**5. `vet-portal`** (chunk 16 writes, W3-e records; read by 21, 25)

- **The copies**: `portal_animals`, `portal_ownerships`, `portal_herds`
  as the document's "Entities"; written by the derivation at T0 (the
  core's state at `load_epoch`), then by purpose 15; `synced_at` on each.
- **Row-level security (choice)**: on and forced on every table; the
  tables owned by `portal`, `NOLOGIN BYPASSRLS`, so the `SECURITY
  DEFINER` functions it owns reach every row and nobody logs in as it;
  `portal_api` neither owns nor bypasses. The asker is
  `NULLIF(current_setting('portal.owner_id', true), '')::integer`,
  inline in each policy (unset: no row), set by the API as text with
  `SELECT set_config('portal.owner_id', %s, true)`, first in each
  request's transaction after `portal_session(token)`; `gm_api` rolls
  it back with the request. Policies are named `<table>_scope` for
  `portal_api`, `portal_sessions_purge` for `portal_housekeeping`.
  `portal_animals_scope` holds the ownership's end as `until_at IS NULL`
  on the asker's ownership row (s5, T270, edits that policy by name);
  `portal_documents_scope` reads the animal's visibility through
  `portal_animals`, so T270 returns the buyer's new records too, as the
  trap says, and `record_at` against the current ownership's `from_at`
  (T271). The keeper's clause needs the current owner's latest
  `keeper-access` event, which own-rows policies hide from a keeper:
  chunk 16 settles it (a consent-events policy also admitting the events
  naming the asker as keeper, or a pinned definer helper) and records it
  in W3-e; T274 and T275 bite wherever it lands. The purposes' roles'
  policies: Preflight corrections, item 4.
- **`portal-api`'s endpoints (choice)**, hostname `portal-api`,
  connection `portal` (`records:5432/portal`, `portal_api`), the
  document's "The applications and their nodes" grouped as endpoints
  `session` (`POST /login`, `POST /logout`), `me` (`GET /me`, `PUT
  /me/preferences`, `POST /me/consents`, `POST /me/close`), `animals`
  (`GET /animals`, `GET /animals/{id}/documents`), `documents` (`GET
  /documents/{id}`), `accounts` (`POST /accounts/activate`, `POST
  /password-reset`, `POST /password-reset/{token}`, `POST
  /unsubscribe/{message_key}`), all public at the brick, and `desk`
  (`POST /desk/consents`, `portal_desk`). `POST /login` `{email,
  password}` → 201 `{token}` with `Set-Cookie: portal_session=<token>`,
  401, or 423; an owner endpoint reads `Cookie: portal_session=<token>`,
  401 when `portal_session` refuses it; `GET /animals` → `[{animal_id,
  name, species, sex, born_on, status}]` by `animal_id`. Reason:
  `gm_api`'s client never lets a caller set `Authorization`
  (`FORBIDDEN_HEADERS`), so the owners' route sends a cookie, as a
  browser does; s5's check (chunk 25) logs in and lists.
- **Passwords and tokens (choice)**: master spec 9.7's "game's seed"
  reaches neither `load-data` nor an `api` node (Preflight corrections,
  item 6). The key is `encode(sha256(convert_to('vet-portal ' ||
  :'load_epoch', 'UTF8')), 'hex')`, computed by `pg_temp.portal_*` in the
  load (bcrypt cost 6 of each active account's password, SHA-256 of the
  planted invitations' and resets' tokens), the derivation (the tokens
  in the outbox's payloads) and `owners`' `data.sql`, which alone keeps
  it (`owners.settings`, name `password_key`). A password is
  `encode(hmac('<account id>', key, 'sha256'), 'hex')`, a planted token
  the same of `'<template>:<account id>'`; tokens made in play
  (purposes 15 and 16) are random and reach the owners' route through
  the messaging stub. Known limit, for the GM's notes: the key follows
  from T0, so it guards nothing from a reader of the notes; no player
  sees the formula.
- **The outbox and its id order (choice; "Left for the build")**: the
  load writes no `portal_outbox` row; the derivation writes the year's
  whole outbox, invitations, resets, closures and reminders (from the
  load's accounts and consent events) and notices (from the documents
  it writes), numbered 1 to n in `queued_at` order, ties by
  `message_key`, the sequence set after; `message_key`
  `md5(<template>:<account id>:<reference>)::uuid`, a sent row's
  `provider_id` likewise. Reason: one writer numbers one sequence in
  time order, and the notices hang off documents only the derivation
  writes.
- **O229, adopted (choice)**: `derive.sql` writes `portal` only. The
  messaging stub's planted messages (the last 14 days' sent rows, the
  180 open invitations' tokens among them) are purpose 16's history
  (chunk 21), its `target` the partners' database, its source `portal`,
  run after the derivation (W2 item 3's order), copying `portal_outbox`'s
  sent rows through `gm_src_source`. As merged, the loader refuses a
  `history` on a purpose with no job naming a feeder (`model.py`,
  "history: only on a periodic purpose"); purpose 16 has none, nor
  purpose 14 (D366): chunk 29's (c). The stub, prefix and hostname
  `messaging`, its DDL purpose 16's receiver material copied into
  `partners-db`'s data file (W2 item 6's way), holds `messaging.messages
  (message_key uuid PRIMARY KEY, provider_id, channel, address,
  template, account_id, payload jsonb, received_at)` and grants `SELECT`
  on it to `owners`; the owners' route reads it when it exists
  (`to_regclass`), else picks at random. Reason: T0's state is the same
  either way (O229); a history is the one loader writing `partners`
  from a source it reads through `gm_src_*`.
- **The owners' traffic** (`producers/partners/owners/`, D369): role and
  schema `owners`; `owners.settings (name text PRIMARY KEY, value
  text)`; `owners.visits (id bigint GENERATED ALWAYS AS IDENTITY, at,
  account_id, call, status, animal_ids integer[], document_ids
  integer[])`, one row per call, RL6's evidence (chunk 21); no
  `owners.state`, no `owners.normal`; endpoint `owners_tick` (`POST
  /tick`, `partners_backend`); connections `owners-db` and
  `owners-portal` (`portal-api:8000`, no credential).
- **Its `pg_cron` job**: `portal.sessions.purge` as `portal_housekeeping`
  in `data/cron.sql`, on `records` (item 4's rule).
- **Fixture** `fixture-portal`: the bastion, `records`, `lab`,
  `interfaces`, `portal-api` and the partners' three nodes (eight);
  `left_out` vet-core's `pms` and `api/clinic-api`, vet-lab's `lis`,
  `api/lab-api`, `partners/xlab` and `partners/practices`, vet-portal's
  `pms` (the desk stream, proven by its fragment's unit check only); the
  lab's stubs' state loaded.

**6. The tool support wave 3 needs** (chunk 29, proposed: Preflight
corrections, item 1; W3-f records; read by 12, 15, 16, 21 and every
composed fixture after)

(a) A part's `data/keys.sql` streamed after the core's (`inject._keys`,
item 0). (b) `composition.yaml`'s `left_out:` (item 0): `compose`,
`model.check_composition` (each entry a producer folder of a composed
domain), `model.node_creates` and the partner-database refusal,
`inject.composed_plan`. (c) `history` accepted on a purpose with no
feeder, its `target` on the partners' database accepted (item 5); "a
feeder requires `history`" kept. (d) A domain's `data/cron.sql`, run
after its load on its node in `cron.database_name`, unseen; a composed
domain shipping one on a node that does not preload pg_cron refused
(item 4). The scenario-format skill and its templates follow; no image
changes.

**7. Wave 3 coordination** (for the driver and chunks 12 to 16, 29)

- **Order**: chunk 29 first (its decisions first, `spec-writer`), beside
  12 and 13; 14 and 15 at the next free slots (κ = 3). 12a and 15a run
  their SQL into the image by hand meanwhile, keys streamed by hand;
  12's composed check and fixture, 15's `cron.sql` and chunk 16 wait for
  29's merge; 16 is cut once 12 and 29 have merged.
- **Files**: `tools/gm/{inject,compose,model}.py` and the scenario-format
  skill are chunk 29's alone in wave 3; each part chunk holds its
  `domains/<id>/` and its fixture; shared lists `regional-franchise.yaml`'s
  `parts:` and the root README's domain table (D380), each chunk adding
  its line at its merge.
- **Images**: none rebuilt; every load and fixture on `postgres:0.5.0`,
  `api:0.1.0` and `scheduler:0.3.0` as they stand; each part loaded with
  the core (its 89 s each time, W2-d's risk).

**Choices made here, not in the spec** (for the driver's review): the
23 marked **(choice)** above, items 0 to 5, and chunk 29's scope
(item 6).

### Preflight corrections for spec-writer

1. **Four tool gaps no wave-3 chunk holds** (W3 item 6): `inject._keys`
   streams the core's `keys.sql` only (formats.md: "a core's"); compose
   needs a node for every producer folder of every composed domain;
   `model.py` refuses `history` without a feeder (O229's recommendation
   and D366 alike); a composed domain's `pg_cron` jobs have no place
   (item 5 below). Proposal: decisions for item 6's (a) to (d); an
   inserted **chunk 29** in wave 3 for a `coding-executor` ("Read
   first"), Files `tools/gm/{inject,compose,model}.py`, their tests in
   `tools/tests/` and the scenario-format skill (SKILL.md, its
   `composition.yaml` and `keys.sql` templates), Done when each
   acceptance and refusal shown by a unit test and the composed test
   load passing with a part's keys and a `cron.sql`; edges `29 ──> 12`
   (its composed check and fixture), `29 ──> 15` (its fixture's
   `cron.sql`), `29 ──> 16` in wave, and `29 ──> 21`; a gate row like
   G16 for formats.md and master spec 5, blocking release gate item 6.
   Item 4's mechanism joins it if ruled before it is cut. Fallbacks if
   rejected: the part's functions inlined in each file with a test
   keeping the copies equal; fixtures above eight nodes (the owner's,
   D314); (c) in chunk 17 (`model.py` in wave 4), with `17 ──> 21`.
2. **Fixtures against compose's rule** (chunks 12 to 16; the plan's
   fixture lists from chunk 18 on). Chunks 13's and 14's fixtures lack
   `clinic-api`, which composing vet-core requires: add it (five nodes
   each). Chunks 12 and 16: the nodes and `left_out:` of items 1 and 5.
   Chunk 15's is complete. Chunk 12's Done when "the stubs' fragments
   parse on the shared back end" is met by a unit test composing vet-lab
   onto a stand-in with the partners' three nodes and loading the
   output, no deployment: chunk 12's Files gain
   `tools/tests/test_compose.py` (a case). For W4: 18's orders fixture
   needs `left_out` for the lab's stubs, its send-outs fixture lacks
   `records` (vet-lab is composed only with its core), 19 to 21 to be
   counted the same way.
3. **O229** (chunks 16, 21): record its adoption as a decision (item 5)
   and close it. Plan text: chunk 16's scope, "`data/derive.sql` ...
   writing `portal` only, the whole outbox included"; chunk 21's scope
   and capture line, "purpose 16's `history` plants the messaging stub's
   messages, `target` the partners' database, source `portal`; the
   stub's DDL its receiver material in `partners-db`'s data file, with
   `SELECT` granted to `owners`". Master spec 9.7 and vet-portal's
   "Loading" and "The history before T0" move "the messaging stub's
   planted notices" from the derivation to purpose 16; vet-portal's
   purpose 16 gains a `target` and a `history`. D366 (purpose 14) meets
   the same feeder refusal: chunk 21's capture line names chunk 29's
   (c).
4. **The purposes' roles, grants, policies and `ops` tables have no
   loader in a composed domain's database** (chunks 18 to 21; W4).
   Formats.md "Purpose definition" copies a target's DDL into its node's
   data file, which runs before `load-data` creates `clinic`, `lab`,
   `portal`, `pacs`, `vitals` and `biomed`; a history runs only for a
   periodic purpose, in its target alone; vet-core's schema, merged,
   creates none of `vet_interfaces`, `vet_portal_sync`, `vet_exchange`.
   Proposal: settle before wave 4 (W4 cannot without a loader): a
   `load-data` step after the domains' loads and before the
   derivations, running each `purposes:` entry's DDL for every database
   part mapped to a composed domain, as `postgres`, unseen, joining
   chunk 29 if ruled in time, else an inserted chunk ahead of wave 4.
   W3 keeps the parts out of it (item 0).
5. **A composed domain's `pg_cron` jobs** (chunks 15, 16; purpose 6's
   watch, chunk 18): `cron.schedule_in_database` checks the job's
   database and user (`CONNECT`) when scheduling, and the data file that
   would schedule them runs before their databases and roles exist.
   Proposal: chunk 29's (d), `data/cron.sql`; vet-machinery's and
   vet-portal's "Loading" say so; purpose 6's job rides item 4's step.
6. **"The game's seed" has no path to the load or to the owners' route**
   (master spec 9.7 "Keys and scale"; vet-portal "Deterministic key
   ranges (D249, D266)"): render's seed sits in `implementation.yaml`
   and the schedulers' `schedule.yaml`; `load-data` passes the zone, its
   offset and `load_epoch` only. Proposal: both texts read "a key
   computed from the load's `load_epoch`, kept only in `owners`' schema
   on the partners' database" (item 5).
7. **Wave 3's gate: the six domains' load-only run has no fixture**
   ("Per-wave gate contents", wave 3; no chunk's Files). Proposal: the
   row names `tools/tests/fixtures/fixture-clinic-load/`, uncomposed (no
   producer node, so no compose; `composition.yaml` written by hand):
   the bastion, `records`, `lab`, `machines`, `partners-db`, built at
   the gate's start by a `coding-executor` from the merged parts; the
   row's fixtures gain `fixture-lab-core` beside bookings, housing,
   imaging and portal.

### Questions for the owner

None.

### W3 reviewed by the driver, 2026-11-04

The 23 **(choice)** points taken as written; none needs the owner. The
seven preflight corrections accepted and sent to `spec-writer` before any
chunk was cut, correction 4's mechanism (the purposes' DDL in a composed
database) joined to chunk 29, the only chunk holding `inject.py` before
wave 4 (next entry).

### Plan revision before wave 3, 2026-11-04

`spec-writer`: build plan v10 (6e4a0b3), spec D401 to D407:
- D401: chunk 29 inserted into wave 3 for a `coding-executor` (W3 item
  6's (a) to (d), plus (e) the purposes' DDL step), split 29a (the
  `pg_cron` premise, (a), (b), (d)) and 29b ((c), (e)); gate G17 (its
  format items into formats.md and master spec 5 after wave 3's gate,
  blocking release gate item 6).
- D402: the chain 29, 12, 16 kept, three chunks long (as D361): no start
  delayed, W3 items 0 and 6 fix the interfaces.
- D403 (correction 2): fixtures follow compose's rule; 13 and 14 gain
  `clinic-api`, 12 and 16 use `left_out:`, chunk 12 a `test_compose.py`
  case; chunks 18 to 21 carry the W4 notes.
- D404: O229 adopted and closed (derive.sql writes `portal` only; purpose
  16's history plants the messaging stub's messages).
- D405: a composed domain's `pg_cron` jobs in `data/cron.sql`, subject to
  chunk 29's premise check.
- D406 (text): the portal's key from `load_epoch`, not "the game's seed".
- D407: wave 3's gate runs `fixture-clinic-load` and adds
  `fixture-lab-core`.
Master spec 9.7, vet-portal's and vet-machinery's "Loading" reworded;
chunk 27's `fixture-clinic-load/` now "changed here". O233 reserved by
mistake, unused. Wave 3 holds six chunks, the model's maximum.
`doc-ids lint spec`: 0 errors. No owner question.

### W3 addendum, item 6 (e): the purposes' DDL step (for chunk 29b), 2026-11-04

Asked by chunk 29's capture line, settled by the driver before the chunk
starts:

- **The key (choice)**: `ddl:` in `purpose.yaml`, beside `history:`, a
  mapping from one of the purpose's part names (the names its `parts:`
  uses, `target` among them) to a file under the purpose folder
  (`ddl: {target: material/target-ddl.sql}`). Read from the catalogue at
  every load, as `history:` is (formats.md "Purpose definition"), never
  copied into the scenario. Reason: the same reading rule as the
  history, one key per database the purpose adds tables to.
- **Where it runs**: only for a part the scenario maps to a database a
  composed domain's `at:` holds. A `ddl:` entry whose part maps to a
  database no domain holds (`office`, `partners`) is refused by the
  loader, naming the purpose and the part: there the DDL stays in the
  node's data file, as v0.4 copies it (one place each, never both).
- **The step's place**: new step **(2b)** of "Loading a composed
  domain"'s order, after every domain's load and partner `data.sql`
  (step 2), before the derivations (step 3); the `purposes:` entries in
  list order, each entry's `ddl:` parts in the order its `parts:` lists
  them. Reason: a derivation or a history may write into the purpose's
  `ops` tables.
- **How it runs**: as `postgres`, connected to the mapped database
  (`psql -d`), unseen, with `customer_timezone`, `customer_utc_offset`
  and `load_epoch` set; no `keys.sql` streamed (as a history). The
  schema's rules hold: never `CREATE DATABASE` nor `\connect` (refused,
  naming the line), the database named `:"DBNAME"`, roles at top level.
  Roles are cluster-wide: a role two purposes' DDL create on one node is
  created guarded (`DO … IF NOT EXISTS`), the purpose's material's
  concern; the loader doesn't police it.
- **The loader sees it**: `model.node_creates` counts the roles and
  objects a `ddl:` file creates on its node, so render gives its login
  roles their secrets and the location and crontab-role checks see them
  (W2 item 1).
- **For 29a**: check that the jobs a `data/cron.sql` schedules survive
  step (6)'s `pg_cron` clean-up, and record it in W3-f.

### Chunks 29, 12, 13 dispatched; chunk 13 stopped, 2026-11-04

Dispatched at 72c1f80: chunk 29 (`coding-executor`, 29a then 29b),
chunks 12 and 13 (`coding-leader`). Chunk 12 does 12a first; its
composed check, `test_compose.py` case and fixture wait for 29's merge.

**Chunk 13 stopped before any code** (no commit; branch and worktree
removed). The merged core's `vc_vet_at` (`domains/vet-core/data/keys.sql`,
chunk 9) draws an on-shift section vet per consultation regardless of
that vet's other consultations, so the history's bookings cannot take
their consultation's vet without overlapping: on a core load at +2 (94
s; 17 395 scheduled consultations, every vet on a covering shift), one
vet's bookings overlap in 1 684 pairs at 10-minute slots, 4 461 at 20,
7 127 at 30; 545 more have the same vet's emergency or ward round within
15 minutes. `sched_allocations_staff_excl` would refuse the load, and
T100's witness (one vet's consultations overlapping) would show with no
fault. Rooms short too at 20 minutes (farm 204 moments with 2–3 at once
for one crush; horse 32 with 4–5 for two stalls and the arena). Further
gaps: the booking horizon against a rota published only 10 to 17 days
ahead (most six-week bookings find no shift); no `sched_` table holds a
staff member's kind or specialty; `sched_free_slots`' signature returns
no teaching animals; inbound examinations carry no study kind
(`core_exchange`'s reason is a hash no part reads); W3 item 0 names
`vet_reports` grants the domain's table doesn't. Owner's options: change
the core's draw (an inserted chunk, core figures rerun), let the
booking's vet differ for the colliding ones, or shorter slots (fails).
Sent to `spec-writer`. Chunk 14 takes the slot.

### Chunk 29 — merged (46ee425), 2026-11-04

`coding-executor`: 29a `34a46b7`, 29b `67535a4`, merged `--no-ff` at
`46ee425`, no conflict. Unit suite 1135 OK, 2 skipped (1127 before);
`GM_TEST_COMPOSED_LOAD=1` `TestComposedLoad` OK (2 tests, ~23 s, the load
13.6 s), part keys, the cron call and the DDL's role, table and policy
absent from the server log and `pg_stat_statements`; py_compile, YAML
(PyYAML and `strict_load`) clean.

**Premise (D405)**: in `postgres:0.5.0` (pg_cron 1.6),
`cron.schedule_in_database` refuses a missing database, a missing role
and a role without `CONNECT` on the database (load-data revokes it from
`PUBLIC`: a part's schema grants its job role `CONNECT`). So
`data/cron.sql` stays; chunks 15 and 16 keep it. Its jobs survive step
(6) (`clean_launcher_lines` never touches `cron.job`; shown by the
composed load).

**W3-f, as built** (read by 12, 15, 16, 18–21):
- (a) A part's `data/keys.sql` streams after the core's, in the same
  session, ahead of the part's `load.sql`, partner `data.sql` and
  `derive.sql`; never ahead of a schema, a `cron.sql`, another domain's
  file, a DDL file or a history. `check_domain_dir` refuses in it any
  line-start `CREATE` but `CREATE [OR REPLACE] FUNCTION pg_temp.<p>_…(`,
  more than one prefix, the prefix `core`, or a prefix the core's
  `keys.sql` uses (vet-core's: `core`, `vc`). A part's function may call
  the core's.
- (b) `composition.yaml`'s `left_out:`: a non-empty list of `{domain,
  producer, reason}`, each producer once; `producer` is `<node>`,
  `api/<node>`, `partners/<prefix>` or `public/<name>`, an existing
  folder under the domain's `producers/`. `gmctl compose` skips it (domain
  and variant layers) and needs no node for it. A left-out
  `partners/<prefix>/data.sql` still runs (and counts in `node_creates`)
  where a partners' database exists; with none it is skipped and the
  partner-database refusal does not apply.
- (d) `data/cron.sql`: `SELECT cron.schedule_in_database(…)` calls only,
  at least one; runs last in the domain's load (after its partner
  files), as `postgres`, on the node's `cron.database_name` (from its
  seed `postgresql.conf`, `postgres` when unset), unseen, no keys.
  Refused when the domain's `at:` spans several nodes, the seed doesn't
  preload pg_cron, or the node's data file doesn't create the extension.
- (c) `history` without a feeder accepted, its target on the partners'
  database too; such a history runs on the partners' node and reads its
  source over TCP.
- (e) `ddl:` in `purpose.yaml` maps `source` or `target` to a file under
  `material/`; runs at step (2b), after every domain's load, partner file
  and `cron.sql`, before the derivations; `purposes:` in list order, each
  entry's parts in its `purpose.yaml`'s `parts:` order; as `postgres`,
  `-d` the mapped database, unseen, every variable, no keys. Refused: a
  part mapped to a database no domain's `at:` holds; `CREATE DATABASE`
  or `\connect` (naming the line). `node_creates` counts a DDL file's
  roles (a guarded `CREATE ROLE` in a `DO` block counts when at the
  start of its own line). `LoadResult.ddl` reports each run.
- Deviations (the executor's, none against the spec): most new loader
  tests in `tools/tests/test_coherence.py` (not in Files; the composed
  plan's tests live there); fx-ward's schema gains `GRANT SELECT, DELETE
  ON ward_placements TO ward_app`; `cron.sql`'s two extra refusals above.
- Risks: the composed test's fixed `log_filename` leaves the pg_cron log
  switch unexercised there (covered by `TestLoadDataPgCronNoise`);
  `cron.database_name` read from the seed as written, a templated value
  unresolved. formats.md and master spec 5: G17, after the gate.

Chunk 15 takes the slot.

### W3 item 2, revised: chunk 13's stop settled (spec D408–D414), 2026-11-04

Written by `spec-writer` from chunk 13's report, before chunk 30 and
chunk 13's restart; plan v11. Where it differs from W3 item 2 or item
0, it wins for chunks 13, 20, 21 and 30. The column-level text is in
[vet-scheduling-domain.md](vet-scheduling-domain.md) ("The history on
the agenda", "An inbound examination's booking", `sched_types`, the
rooms' hours, `sched_free_slots`, the rota's lifecycle) and
[vet-core-domain.md](vet-core-domain.md) ("The key functions"). Chunk
30 records its as-built outcome as **W3-g**.

Why the vet draw alone could not be fixed: on the core as merged
(reference T0 2026-11-04 09:50 at +2, 17 395 scheduled consultations),
even an optimal assignment of free section vets leaves 1 474 domestic
scheduled consultations (11 %) with no vet free at their drawn times
and lengths, and at 1 380 starts more domestic consultations are under
way than all 25 section vets on shift: the domestic demand at weekday
17:00–20:00, 09:00–10:00 and Saturday mornings exceeds the rota's vets.
Re-timing the domestic shifts does not help (1 382 to 1 920 left), nor
does option 2 (the booking's vet differing), which meets the same lack
of vets. So the history caps the agenda, the only draw within the
approved figures.

- **(a) The agenda (D408; chunk 30 writes it, 13 reads it).** A
  scheduled consultation sits in the half-hour slot (on the hour or
  the half-hour, local) of its drawn time; the section's scheduled ones
  of that slot, in id order, take its vets on a `day` shift covering
  the slot with no absence, in an order hashed by the slot, while both
  a vet and a consultation space are left (domestic 4, horse 3, farm
  2); past that, no row. Started in the slot's first five minutes,
  closed by its end. Measured on the same T0 as a half-hour count: 666
  fewer (domestic 616, horse 35, farm 15), about 3.8 %. An unbooked
  consultation takes an on-shift vet with no placed scheduled
  consultation over it when one exists (all but about 110 emergencies a
  year at the evening peak, which keep the present draw).
- **(b) The attended bookings (D408, D410; chunk 13).** Booking `id` =
  the consultation's; `starts_at` the slot's start, `ends_at` 30
  minutes later; the vet allocation the consultation's `vet_id`; the
  room the section's consultation space of the consultation's rank
  among the slot's placed ones (id order; domestic 1–4, horse 8, 9, 10,
  farm 12, 13); arrived at its `started_at`. The cancelled and no-show
  consultation bookings (25 001–28 000), the theatre plans, imaging
  bookings, blocks and session days are placed by the part's load in
  what the agenda leaves free, a no-show's allocations live, a
  cancelled one's released. The four exclusion constraints exist before
  the load runs.
- **(c) Consultation types and spaces (D410).** Every consultation type
  30 minutes, on its room's half-hour grid; a type's room kind is its
  section's consultation spaces as in (b); the procedure room and the
  theatres take no consultation, but the farm's standing-surgery
  theatre (13) is both a space and a theatre, so a farm theatre plan
  avoids its consultations. The farm's rooms open Monday to Friday
  08:00–16:00 (the core's farm consultations run to 16:00).
- **(d) The rota (D411; corrects item 2's "The rota's published
  weeks").** The load writes every shift from the history's first week
  to the end of the seventh week after the week of the last Friday
  12:00 before T0, `published_at` set (that week's Friday 12:00) on the
  weeks published by then (to the end of the week after next from that
  Friday), null on the later ones, which are planned. Each Friday
  12:00, `sched.rota.publish` generates the seventh week after the
  current one as planned shifts and publishes the week after next,
  removing first its planned shifts a live absence covers; both steps
  idempotent on (`staff_id`, `starts_at`). `sched_shifts.id` 1–24 000.
  `sched_free_slots` reads planned and published shifts alike, so the
  42-day horizon always meets the rota. Purpose 12 reads published,
  clocked shifts only.
- **(e) The slot function (D412).** Signature as item 2. A staff
  member's kind, section and specialty from the core's layout copied
  into its text (`core_staff`'s CASE, the GM notes saying the two are
  one formula, as for the rota), never from the core's `staff`. For a
  session type it returns a slot only when the course's number of
  teaching animals of its species are free within their limits; it
  returns no animal; the caller picks them (the lowest ids free), the
  animals' exclusion constraint the guard.
- **(f) The inbound examinations (D413; chunk 30 the function, 13 and
  21 the mapping).** `core_exchange` gains `reason` and
  `partner_species`, the values the core's load writes; the machine by
  reason and species as vet-scheduling's "An inbound examination's
  booking" maps it; a second opinion or an endoscopy a consultation
  booking of the species' section. Purpose 11's `book-requests` reads
  `exchanges.reason` and the species in `partner_patient` and maps
  alike.
- **(g) Grants (D414; corrects chunk 13's reading, item 0 stands).**
  Master spec 9.2 and vet-core's grants give `vet_reports` the tables
  of the parts in `clinic`, granted by their schemas: scheduling's
  `schema.sql` grants `SELECT` on every `sched_` table to `vet_reports`
  inside a `DO` block when the role exists (not in a database of its
  own on an instance without the core). The domain document's grants
  table now has the row.
- **Unchanged**: item 2's tables and states, ids, slot function
  signature, booking horizon and fixture.

### Chunk 13's stop settled; chunk 30 inserted, 2026-11-04

`spec-writer`: plan v11 (52dcaf0), spec D408 to D414; its "W3 item 2,
revised" note above. The driver's lean (the core drawing a free vet) does
not fit: even an optimal assignment leaves 1 474 domestic scheduled
consultations (11 %) with no section vet free (weekdays 17:00–20:00,
09:00–10:00, Saturday mornings); re-timed shifts still leave 1 382 to
1 920. D408: the history's scheduled consultations sit on half-hour
slots, each slot taking the section's covering vets and its consultation
spaces in id order, the rest dropped (666, about 3.8 %; attended bookings
about 16 700); T100's witness reads scheduled consultations only. D409:
chunk 30 inserted ahead of chunk 13 (`coding-executor`; `9 ──> 30`,
`30 ──> 13` in wave; W3-g); wave 3 holds seven chunks, one past the
model's six. D410: 30-minute types; the consultation spaces; the farm's
rooms Monday to Friday 08:00–16:00. D411: the rota planned to the end of
the seventh week ahead, the week after next published, the slot function
reading both. D412: `sched_free_slots` carries the core's staff layout,
checks teaching animals free and returns none. D413: `core_exchange`
gains `reason` and `partner_species`. D414: `vet_reports` granted every
`sched_` table (W3 item 0 stands; the domain's grants table corrected).

Peeks for the inserted chunk: no intent register (no `documentalist`), no
data register, no dependency (no `security-advisor`). Running chunks 12,
14, 15: no code change (core ids through the core's functions); load
figures taken before chunk 30 are about 3 % off, superseded by the
gate's reruns. **For the owner, information only** (no ruling asked):
the history's agenda is capped (about 4 % fewer scheduled consultations,
closing 25–30 minutes after they start); the farm's rooms close at 16:00,
not 13:00. Chunk 30 waits for the next free slot (κ = 3: 12, 14, 15 in
flight).

### Chunk 12 — 12a built, paused before 12b, 2026-11-04

Owner paused at about 160k tokens. Branch `v0.5-c12-vet-lab` (worktree
kept): 12a `1e6431c`, then `c441776` merging `v0.5-w3` (chunk 29 in, the
log to 557e803). The two stubs' `data.sql` moved into 12a
(`check_domain_dir` and `test_catalog_domains_are_complete` need the
`producers/` folder). Loads in a throwaway `postgres:0.5.0`, keys
streamed by hand: +2 71 s, 54 MB, 330 077 rows; shift 0 64–70 s, 329 916
rows; each stub's `data.sql` about 60 s (xlab 8 open send-outs; practices
39 orders, 12 deliveries). The five coherence checks clean by hand (one
fix in `keys.sql`: two lab cancellations after the core's
`cancelled_at`). Unit tests `test_model`, `test_coherence`, `test_inject`,
`test_compose`: 613 OK, 2 skipped.

W3-a so far (the 12a owner's): one pass, `pg_temp.lab_order_tests(load_epoch,
utc_offset)` (about 60 s, 17 000 `core_request` calls), called once by the
load and once by each stub; `lab_order(n, …)` and `lab_send_out(n, …)`
lookups over it (about 60 s each, a GM's query, not a loop);
`lab_catalogue()`, `lab_delivery(accession, kind, revision, event_at)`;
`send_key = md5('vet-lab-send-out:'‖id)::uuid`; `delivery_key =
md5('vet-lab-delivery:'‖accession‖':'‖kind‖':'‖revision)::uuid::text`; the
external accession `NL` 400000 + n, codes `NL-<code>`, labels `ALD` + 8
digits; `client_ref` `C-<consultation>-<priority>` (centre),
`<YYMMDD>-<m>` (practices); `lab_order_tests` gains `not_performed_at`,
`cancelled_at`; `lab_orders` has no status column (state from its times);
amendments by `supersedes_id`, `amended_by`, `amended_at`,
`amendment_reason`; indexes `(account_id, client_ref)`, `released_at`
(T78, T80 baselines); the centre's last-24-hour tests unreleased at T0 (32
technical, 14 in progress, 8 sent out), purpose 1's first backlog; stubs
as W3 item 1 (`practices.orders.tests` `text[]`, `xlab.orders.age` whole
years; open items only; `delay_ms` 0; roles LOGIN); `lab_callbacks` about
9 500 rows keyed by `lab_delivery` (chunk 18); `lab_charges` kinds `test`,
`handling`, `urgent`, `billable_on` a local date, `voided_at`, fees in
`lab_settings` (chunk 20). Risk: a composed load pays the pass three
times (about 3 minutes on top of the core's 89 s).

Deviations, sent to `spec-writer` (documents to as-built): `lab_samples`
about 20 800, not 1–18 000 (the core's centre orders give 11 777 alone);
figures below the document's "about" (open send-outs 8 not about twenty,
results about 161 000 not 192 000, batches 9 776 not 22 000, intervals
61–456, 457–460 unused); column grants beyond the read list
(`lab_instruments` on `lab_orders (id, species, priority)` and
`lab_tests (id, code, discipline)`; `lab_dispatch` the catalogue). A fresh
owner resumes 12b.

### vet-lab's document to 12a as built (D415), 2026-11-04

`spec-writer` (7b2783d): `vet-lab-domain.md` and master spec 9.3 —
`lab_samples` about 20 800, no fixed range; results about 161 000 (range
1–192 000 kept, the sequence set after it), batches about 9 800,
intervals 61–456 in force, about eight send-outs open at T0 (the
practices'); sample events about 63 000; the load about 0.33 million
rows; `lab_instruments` and `lab_dispatch` grants as built. No trap or
fault witness quotes them. **For wave 4's capture (chunk 18)**:
`clinic-purposes.md` SO4 still reads "about twenty send-outs in flight at
T0"; it should read about eight, the practices', so the answer leg has
little to judge at T0 until new send-outs arrive. Left as is: QC runs
7 861 (document 7 000), amendments 813 ("a thousand").

### Chunk 15 — 15a built, 15b paused at WIP; usage limit, 2026-11-04

Chunk 15's owner paused on context (and long waits on the host lock):
branch `v0.5-c15-vet-machinery`, 15a `c95523a` (complete: three
databases, loads, classification, register, rules, 7 coherence checks, GM
notes, `parts:`, README row), 15b WIP `d60e472` (`equipment`'s
fragments, `scripts/lookup.py`, `data/cron.sql`). Not merged. Loads
(throwaway `postgres:0.5.0`, keys streamed by hand): +2 50.8 s (pacs
40.1, vitals 9.1, biomed 1.6), 282 020 rows, 75.4 MB; shift 0 50.3 s,
291 087 rows, 76.3 MB. Coherence clean by hand. Related unit tests 511
OK, 2 skipped. **O227 settled: 11 machines reporting** (machine 10 a
status row a minute with empty channels, 48 bytes against 116.5; about 70
kB on a 2.4 MB readings day; 15 840 readings a day, the spec's figure).

W3-d so far (chunks 21, 23): roles once in `pacs/schema.sql`; `mach_maint`
LOGIN (pg_cron refuses a NOLOGIN role), a secret no node mounts;
`CONNECT` pacs `mach_pacs_app`, vitals `mach_vitals_app` + `mach_maint`,
biomed `mach_biomed_app` + `mach_maint` + `mach_service`; `mach_orders`,
`mach_archive`, `ops` left to chunk 21. Partitions `mach_vitals_<yyyymmdd>`,
`mach_readings_<yyyymmdd>`, `mach_events_<yyyymm>`, each a `_default`;
the load creates yesterday to today+3 and the event months to next
month; `mach_create_partitions(days)`, `mach_drop_shipped(day)` SECURITY
DEFINER owned by `mach`, `search_path = public, pg_temp`, over
`mach_partition_day(d)` (biomed also `mach_partition_month(d)`), EXECUTE
revoked from PUBLIC; biomed's creates the months its days touch;
`mach_drop_shipped` DETACH then DROP, false when none. A history day's
readings `sum(mach_readings_daily.rows)` (1 440 a machine-day before the
window); vitals by the GM notes' tick count over `mach_sessions`.
Purpose 13: `mach_worklist(accession UNIQUE, state, cancelled_at,
cancelled_because)`, `mach_reports(kind, status, signed_at,
supersedes_id, why)`; a history final signed 1–9 minutes before the
core's `resulted_at`. `mach_census`: stays current at T0 plus those left
within the window.

Deviations, sent to `spec-writer`: (1) `mach_vitals_settings` and
`mach_pacs_settings` beside biomed's `mach_settings` (names unique across
a part's databases); (2) `mach_worklist.cancelled_at` (purpose 13's
watermark); (3) the PACS can't read biomed's registry (another database):
`pacs.worklist.schedule` and `pacs.study.acquire` never check a machine
in service, a down machine's studies just wait; (4) about 2 intensive-care
sessions a day by D377's rule (not 2.7), about 42 700 raw vitals rows a
day (not 52 000), about 2 980 imaging requests reaching the worklist
(not 3 400); (5) some history finals outside reporting hours (the core's
turnaround draw).

**Driver's ruling on the fixture's T0**: the shift moves whole hours and
the minute is the clock's, so `fixture-imaging` aims within 30 minutes of
08:50 local on a weekday (refusing to run on a weekend day), not exactly
08:50; accepted, since the checks read jobs that run after it.

**Usage limit**: chunks 12b and 14 stopped mid-work on the account's
5-hour limit; both resumed from where they stopped once it reset. A
fresh owner resumes 15b.

### Chunk 12b — paused for rotation (9ef2683), 2026-11-04

On the owner's word ("rotate them": contexts at 444k and 300k), chunks
12b and 14 asked to pause at a safe point. 12b: WIP `9ef2683` on
`v0.5-c12-vet-lab` (after `ae01c40`, merging `v0.5-w3` at 7e93aa3). Built:
`lab-api` (`orders`: `POST /orders` 201 new / 200 same `client_ref`,
nothing written, 422 unknown or closed account or code; `GET
/orders/{accession}`; the feed `GET /orders?account=&released_since=`,
both required; `send_outs`: `POST /send-outs/{send_key}/result`, once,
200 again, 404 unknown; connection `lab` as `lab_api`, pool 4; all pass
`gm_api check`); the stubs `xlab` (`northfield-lab`: `POST /orders`,
`POST /orders/{send_key}/resend`, `xlab_tick`) and `practices`
(`POST /results` counting repeats per `delivery_key`, `practices_tick`
posting an order a tick, retrying under the same `client_ref`); streams
`xlab.normal`, `practices.normal` 1/min, `xlab.answer` 6/h,
`practices.order` 2.9/h poisson; connections `xlab-lab`, `practices-lab`;
`TestLabStubs.test_the_stubs_on_the_shared_nodes` passing;
`fixture-lab-core` (7 nodes, `left_out:` pms and both stubs; hand-over
20:00, T0 11:00–12:00 local; `run-short-test.sh` never run). A
`coding-executor` the owner started is still dry-running `lis`'s keys in
container `c12pg` (uncommitted changes under `producers/lis/`); asked to
report to the driver. Next: `lis` verified, `lab-release-round`'s cron
`1-6` written `1,2,3,4,5,6` (the loader refuses ranges), compose again
(no `__pycache__`), the fixture's README, `@@LIS@@` in the GM notes, the
full checks, `fit` and the short test, the composed figure, commit and
merge. Deviations, for `spec-writer`: `lab_api` reads
`lab_reference_intervals` (the feed's `low`, `high`); `practices.state`
gains a `utc_offset` row; `lab.identity` writes no food-chain status
(`lab_orders` has no column); the fixture's `partners-db` `pg_hba.conf`
has no `host partners` line (both stubs left out). Risk: the ticks hold
a session while they post over HTTP (the back end serializes them).

### Chunk 14 — merged (82c8c6d), 2026-11-04

Paused for rotation at `f18517b` with every check passing, only the merge
left; the driver amended it into the chunk's one commit `7b3eeab` (no
content change; `v0.5-w3` had gained only wave-log lines since its
base) and merged it `--no-ff` at `82c8c6d`; worktree removed.
`check_domain_dir` clean (vet-housing, vet-core; `parts: [vet-housing]`
beside the others); `lands_with` refusing `records/wards` (in the short
test too). Loads after the core (92–96 s): 7.6 s at shift 0, 7.4 s at +2;
138 863 / 138 752 rows, 17 MB (`clinic` 67 MB); at +2 64 units, 66
displays, 3 032 placements, 2 795 plans, 132 795 care events; through
`load-data` on Swarm core + housing + coherence 102–122 s, the three
checks clean. `fit` 5 nodes, 0.9 CPU, 864M. The board 63.9–64.0 calls a
minute, one queryid, 4 sessions at most. Place run (T0 10:04 local)
39/39, 19.4 min; care run (T0 16:48) 40/40, 22.3 min (an earlier place
run's two failures were the test's, fixed). Unit suite 1135 OK, 2
skipped.

W3-c (chunks 20, 25): `ward.board` is exactly `SELECT * FROM
housing_unit_board WHERE unit_id = %(unit)s`, `unit` `{int: [1, 64]}`, on
`ward-board` (`vet_display`, pool 4), 3840/h even `flat`, concurrency 4;
s9's display a stream in `compose/ward/` with that SQL byte for byte and
`{int: [u, u]}` (units 7 and 41 had two displays: the chain takes the row
with no `removed_on`; serials `WD7-` + `(7919·id + 1301) mod 100000`);
occupancy as W3 item 3, its query in `docs/gm.md` "The occupancy
measure", `vet_reports` reading every housing table and the board; the
columns as built (units `state_since_at`; displays `serial`,
`installed_on`, `removed_on`; placements `from_at`, `until_at`, `reason`,
`placed_by`; plans `kind`, `diet`, `meals_a_day`, `set_by`, `note`; care
events `kind`, `eaten`, `done_at`, `done_by`, `note`); the board adds
`meals_due`, `plan_kind`, `plan_until_at`, `age_years`; unit choice
isolation first for a current infectious alert, else ordinary, intensive
care, isolation last, lowest id. Housing reads only `core_stay`,
`core_species`, `core_stay_alert`, `core_staff`: D408 changes nothing
here.

Deviations, sent to `spec-writer`: (1) grants beyond the table (`housing`
reads `stays.reason`, `animals.born_on`, `business_settings`;
`housing_ward` USAGE on the care events' sequence); (2) a move out of
isolation when the alert ends (the farm's six cattle at once against five
stalls), 157 stays moving twice, 47 of 249 infectious animals waiting for
isolation and 5 never reaching it (a background for T163's witness); rows
about 139k and 17 MB against 0.16 million and 50 MB; (3) "its unit
disinfected within the hour" not shown for a unit released live under 30
minutes (the 30-minute rule, a 15-minute call); (4) T0 placed to the
hour, "just before 17:00" built as 16:00–16:59; (5) the handover planned 9
hours out (past the 8-hour aging floor). Incident: chunk 14's loop ran
chunk 15's `runload.sh` (shared scratchpad) against `c15pg`, creating an
empty database `housing` there and nothing else; chunk 15's owner told.

Chunk 30 takes the slot.

### Documents to as built: machinery and housing (D416–D419), 2026-11-04

`spec-writer`: `e32bcb8` (D416, vet-machinery to 15a as built: the two
settings tables, `mach_worklist.cancelled_at`, `mach_maint` LOGIN, O227 at
11, the scale, the loaded counts, growth about 7.3 MB a day; master spec 7
and `cold-storage.md` figures too), `4f7ae7b` (D417, vet-housing to chunk
14 as built: grants, columns, the move out of isolation, rule 2 "as soon
as one is free", about 0.14 million rows and 17 MB, the testing section's
limits), `952408d` (D418, D419). The driver's rulings on the two points
`spec-writer` left open:
- **D418 (O235)**: the `pacs` load keeps the history's studies out of
  `biomed`'s downtime windows (salts 502, 505, 506), checked inside
  `pacs`; live, the PACS reads no registry and a story taking a machine
  down stops its acquisitions itself. Built by chunk 15b (its owner told,
  with the GM notes' correction: acquire has no machine filter).
- **D419 (O236)**: T163's witness becomes "an infectious animal outside
  isolation while an isolation unit of its section has stood clean and
  free for more than a day" (the waits D417 records are its baseline
  otherwise). T163 is not among the ten.
Chunk 21's text gains the W4 points (`mach_archive` SELECT on
`mach_vitals_settings` and `mach_settings` if `ship-partitions` reads
them; `mach_orders` reads `cancelled_at` and cancelled because).

**Gate fix listed**: `domains/vet-housing/docs/gm.md` still calls the
infectious waits "T163's baseline, so a T163 instance is told by its rate
and its story"; reword to D419 at the wave gate.

Chunk 12b: the executor's dry run committed by the paused owner at
`13ee9a3` (17 of 18 `lis` keys and `lab.identity` working as their roles;
`lab.analyser.run` refused as `lab_instruments` on `lab_results`).
**Driver's ruling**: `GRANT SELECT (order_test_id) ON lab_results TO
lab_instruments`, a D415-style grant, recorded with 12b's deviations
after it merges. A fresh owner resumes 12b.

### Chunk 15 — merged (4734f32, 9b4daee), 2026-11-04

15b by a fresh owner: `667a6f1` on the WIP `d60e472`, `c7c1504` (the T0
placement fix); `v0.5-w3` merged in twice (`3b2aae8`, `1ce0f77`, the
shared lists: `parts: [vet-housing, vet-machinery]`); merged `--no-ff` at
`4734f32`, the fix at `9b4daee`; worktree and `c15pg` removed (the stray
`housing` database dropped first). `check_domain_dir` clean; three
databases and `jobs` with `CONNECT` revoked from `PUBLIC`, each role's
`CONNECT` as W3-d. Fixture `fixture-imaging` runs 47/3 (507 s: a
`vitals.sample` bug and two test patterns), 50/0 (455 s), 49/1 (602 s,
T0 08:19, outside the window), 50/0 (619 s, the fix): deploy 14–16 s,
`load-data` core + machinery 222–228 s (385 s beside other loads); pacs
13 MB, vitals 32 MB, biomed 26 MB, jobs 7.9 MB, clinic 49 MB. Identity:
three planted worklist entries filled from `clinic-api`, 6 lookups all
200; census's first run 200, its current stays equal the record's (42);
partitions yesterday to today+3, events to next month, the defaults
empty; `cron.job` the three jobs as `mach_maint`; 11 machines reporting.
Unit suite 1135 OK, 2 skipped.

**D418 built**: history studies inside a recorded downtime 6 of 2 914 at
+2 and 6 of 2 911 at 0, now 0 and 0, counts unchanged; `pacs`' copy of the
downtimes equals `biomed`'s 33; a study moves just after the downtime if
its final still follows, else just before if its entry had its identity,
else onto the section's other machine of its modality (CT 7–8, DX
11–12–13, US 14–15), else just after; the `pacs` load refuses a study
left inside a downtime; GM notes corrected.

W3-d additions (chunks 21, 23): `machines`' seed preloads
`pg_stat_statements` and `pg_cron` (`cron.database_name = 'jobs'`,
`cron.use_background_workers = on`, `cron.timezone =
'{{customer_timezone}}'`, `cron.log_run = on`); `data/machines.sql`
creates `jobs` (`CONNECT` revoked) and `pg_cron` there; `gm_check`'s read
policy on `cron.job` by `load-data`. `interfaces` idle, through
`compose/interfaces/`, one HTTP connection (`clinic-api` behind
`clinic_lookup`) and one key `interfaces.idle` nothing sends (the
scheduler refuses to start with none); chunk 21 replaces it. `equipment`
at intensity 1.0, mounting `http_clinic_lookup` and the three
application roles' passwords; `mach_maint`'s and `mach_service`'s on no
node. The short test's planted worklist entries use request ids
990001–990003.

**For every keys author, and the gate**: a key with no parameters must
not use `%%` (the scheduler passes no parameters to psycopg, so `%%`
reaches the server as written: `vitals.sample` failed with 42883, now
`mod(s.id, 64)`). Gate item: grep every domain's `queries.yaml` for `%%`
in a parameterless key.

Deviations: two 15b commits; the `interfaces` placeholder connection and
key (the owner's choice); **gate fix**: the `scenario-document` template
reads `pg_cron` jobs from a node's data file only, not a domain's
`data/cron.sql` (the fixture's README lists them by hand); the
`vitals.sample` fix. Risks: an MR or NM study (machines 9, 10, 16, no
other machine) whose downtime covers its whole window stops the `pacs`
load (loud, not met at any tested epoch).

No chunk ready for the free slot: 13 waits on 30, 16 on 12.

### Chunk 12 — merged (2dc2317), 2026-11-04

12b by a third owner: `0216092` on the WIP `9ef2683` and `13ee9a3`;
`v0.5-w3` merged in at `8e27f1e` and `564a50a` (chunk 15; the shared
lists: `parts: [vet-lab, vet-housing, vet-machinery]`); merged `--no-ff`
at `2dc2317`; worktree and `c12pg` removed. `check_domain_dir` clean on
vet-lab, vet-core, vet-housing, vet-machinery on the merged branch.
Composed core + lab + stubs through `load-data` on the fixture: 405 s,
coherence `pass`; the lab 55 MB, 13 684 orders, 23 406 order tests,
160 890 results, 8 open send-outs. `fixture-lab-core` 44/44 in 530 s
(wall 18 min 25 s, mostly the host lock behind chunks 30 and 15b), deploy
15 s, the slowest API answer 115 ms, the feed 71 ms; `fit` 2 CPU / 4G /
8G. At T0 (Wed 12:02 local) `lis` loaded 7 jobs; `lab.identity` filled
the posted order's animal from `clinic-api` within 90 s; one test
released after T0; an order posted twice with one `client_ref`: 201,
then 200 with the same body, one row; the feed since a time 34 tests,
equal to the lab's rows in order (released with results and low/high,
not performed and cancelled without), 422 without `released_since`; the
stubs' state equal to the lab's (8 send-outs; 39 orders, 12
deliveries), each role owning only its schema; `TestLabStubs` passing.
Unit suite 1137 OK, 2 skipped.

W3-a additions (chunks 16, 18–20): `lis`'s connections `lab` as
`lab_app` (pool 4), `lab-instruments` as `lab_instruments` (pool 2),
`clinic-api` over HTTP (`clinic_lookup`); 18 SQL keys plus the script
key `lab.identity`, 14 streams; jobs `lab-qc-morning` `45 6 * * *`,
`lab-qc-night` `15 21 * * *`, `lab-samples-dispose` `0 6 * * *`,
`lab-identity` `* * * * *`; the release rounds on `lab.release.round` as
three jobs, `lab-release-round` `0 11 * * *` (Sunday's single round
too), `lab-release-round-14` `0 14 * * 1,2,3,4,5,6`,
`lab-release-round-18` `0 18 * * 1,2,3,4,5,6` (the loader refuses a day
of week with ranges or with more than one hour). The intake: `lab-api`
writes the order, one sample per sample type, one order test per test,
no charge, no event; `lab.samples.receive` (centre, 15/h) and
`lab.courier.receive` (practices, 40/h, `courier-waves`, charging)
accession them; both write a `stored` event for an unfit sample at
receipt (the document's lifecycle; at `now()`, the history 10 minutes
after the tests' final time). Written up in `domains/vet-lab/docs/gm.md`.

Deviations, sent to `spec-writer`: `lab_instruments` `SELECT
(order_test_id)` on `lab_results` (the driver's ruling; on the fixture
`lab.analyser.run` inserted 108/108/61/61/9/0 results on machines 1–6);
the release rounds as three jobs; `lab_api` reading
`lab_reference_intervals`; `practices.state`'s `utc_offset` row; no
food-chain column on `lab_orders`; the fixture's `partners-db`
`pg_hba.conf` without a `host partners` line. Risks: the composed load
405 s (more than the estimate, inside 30 minutes); the run exercises
releases through `lab.release.urgent`, not the 14:00 round; the ticks
hold a session while posting over HTTP.

Chunk 16 is cut from `v0.5-w3` now (chunks 12 and 29 merged).

### vet-lab's document to 12b as built (D420), 2026-11-04

`spec-writer` (63d6979): `lab_instruments` reads `lab_results
(order_test_id)`; the release rounds three jobs; `lab_api` reads the
intervals; the practices' `client_ref` `<local YYMMDD>-<m>` with
`practices.state`'s `utc_offset`; the lab keeps no food-chain status (no
trap or fault reads one); SO4 and master spec 9.3 "about eight
send-outs in flight at T0, all the practices'". The fixture's
`partners-db` `pg_hba.conf` without `host partners` is the fixture's own
(both stubs left out): no document change.

### Chunk 30 — merged (8566267), 2026-11-04

`coding-executor`: `3df1e01`, `v0.5-w3` merged in at `47464b3`, merged
`--no-ff` at `8566267`; worktree and `c30pg` removed. `check_domain_dir`
clean. Core loads: +2 131.4 / 122.2 s, 49 MB, 269 397 rows; shift 0
133.6 / 136.6 s, 270 260 rows (today's code on the same host the same
day 94–95 s, 274 235 / 274 404 rows): within twice 89 s. Every slot
invariant 0 on both loads (no vet twice in a slot; each start in its
slot's first five minutes and closing by its end; no slot over its
covering vets or spaces; every vet of its section on a covering `day`
shift with no absence; within the rooms' hours; `booking_id` the id;
`vc_vet_shifts` equal to `core_shifts`). Scheduled consultations at
07:50Z +2: 16 729 against 17 395 (666 fewer, `spec-writer`'s figure); at
the GM notes' reference T0 16 747 against 17 414 (domestic 616, horse 36,
farm 15); shift 0 734 fewer (4.2 %). Unbooked consultations whose vet has
a booking over them: 98 of 7 219 (+2), 96 (shift 0), all the domestic
evening's emergencies. `exchanges.reason` and `partner_patient`
byte-identical. Unit suite 1137 OK, 2 skipped. `fixture-core` not rerun
(reads none of the changed columns); the wave gate reruns it.

W3-g (chunks 12, 13, 15, 16, 20, 21): every `core_*` signature unchanged;
`core_exchange` gains `reason` (`transfer for specialist care`, or for an
examination `CT examination`, `MRI examination`, `scintigraphy`, `second
opinion`, `endoscopy`, `cardiology examination`) and `partner_species`
(`dog`, `cat`, `horse`, `cow`; null outbound). A scheduled consultation:
its half-hour slot (`vc_slot`), its rank among the section's scheduled
ones of the slot in id order (`vc_slot_rank`), the slot's vets ordered by
a hash (`vc_slot_vets` over `vc_vet_shifts(d)`), placed while its rank is
under both the vet count and the spaces (`vc_spaces`: domestic 4, horse 3,
farm 2) and taking the vet at its rank, else no row; start `s+(t−s)/6`,
close `start+25min+u6·(s+5min−start)`. `vc_agenda(s, load_epoch,
utc_offset)` returns a slot's placed rows (`c, sec, vet, started,
closed`). **For chunk 13**: an attended booking per placed scheduled
consultation (its id, the slot's start for 30 minutes, the consultation's
vet, the space at its rank, `vc_slot_rank`'s `rk`); inbound examinations
mapped from `reason` and `partner_species`. Unbooked ones take
`vc_free_vet` (on shift, no placed consultation over them; else
`vc_vet_at`, unchanged, still the stays' admitting vet). Ids now in drawn
time order (only scheduled ones move, within their slot); about 4 % of
scheduled ids have no row and no requests. The parts' counts move (+2:
requests 16 617 → 16 167, analyses 13 584 → 13 196, imaging 3 033 →
2 971, lab orders 7 432 → 7 214) and every `core_request` caller pays
the slower `core_consultation` (59 s and 49 s on 25 000 / 17 000 calls).
Deviations: internal `vc_*` helpers (`STRICT`, an `OFFSET 0` to stop
inlining); a scheduled consultation's patient checked at its new start.
Risks: the core's load about 35 % slower; the agenda relies on
`vc_before` being exact, checked at both shifts only.

Chunk 13 restarts from `v0.5-w3` (fresh owner).

### Chunk 16 — 16a built, paused before 16b, 2026-11-04

Owner paused at about 200k tokens. Branch `v0.5-c16-vet-portal` (worktree
kept): 16a `2cd9479`, `62b452e` merging `v0.5-w3` at 8389dd6 (chunk 30
in, no conflict); `c16pg` removed. `check_domain_dir` clean on the five
domains. Load and derivation by hand, as `load-data` runs them
(`derive.sql` reading `gm_src_vet_core`, `gm_src_vet_lab` as `gm_check`
through postgres_fdw); the real `load-data` and `compose` path, with the
`derive:` record, is 16b's fixture. Figures (`load_epoch` 08:50 local,
Wednesday): shift 0 load 18 s, derivation 134–142 s, 78 MB, 241 900 rows;
+2 19 s / 130 s, same; after chunk 30, shift 0 17 s / 129 s, 77 MB,
237 904 rows (38 973 documents, 65 032 views, 38 169 outbox rows); six
coherence queries clean (`results-gated` rewritten: 158 s to 38 ms).
Owner scope in SQL as `portal_api` with `portal.owner_id`: a seller 0
rows of the horse sold, the buyer it and 8 of its 9 documents, a granted
keeper the animal and 7 documents, a withdrawn or never-granted keeper 0,
the setting unset 0 everywhere, another owner's document by id 0.
Accounts: login `ok`; an old token (`session-1`) refused; the fifth wrong
password `locked`, then the right one refused; an invitation token works
once. `portal.sessions.purge` (`30 3 * * *`, `portal`,
`portal_housekeeping`) registered by `data/cron.sql`; a forced pg_cron
run needs `cron.use_background_workers = on` in `records`' seed (16b).

**The keeper clause (W3 left it to the chunk)**: two `SECURITY DEFINER`
helpers owned by `portal` (`STABLE`, `search_path = public, pg_temp`,
`EXECUTE` for `portal_api` only): `portal_keeper_granted(animal,
keeper)` (the current owner's latest `keeper-access` event for them is a
grant) and `portal_owner_since(animal)`; `portal_animals_scope` an owner
branch (`until_at IS NULL`, T270 drops it) and a keeper branch;
`portal_documents_scope` through `portal_animals` and `record_at >=
portal_owner_since(animal)` (T271 drops it). **The outbox's id order**:
the load writes no outbox row; the derivation writes the year's outbox
numbered 1..n by `queued_at`, ties by `message_key`, the sequence set
after; the `outbox-order` coherence check enforces it; `message_key =
md5('<template>:<account>:<reference>')::uuid`, a sent row's
`provider_id = md5('messaging:' || message_key)::uuid`; one in fifty two
attempts (a 503, then the same key); the last two minutes unsent.

W3-e so far (chunks 21, 25): roles `portal` (NOLOGIN BYPASSRLS),
`portal_api`, `portal_housekeeping` (LOGIN, `CONNECT` by name); RLS
enabled and forced on all ten tables; policies `<table>_scope`, and
`portal_sessions_purge`; no policy for the purposes' roles (chunk 21).
**For W4 (chunk 21)**: `gm_check` sees no portal row (`pg_read_all_data`
does not bypass RLS), so purpose 16's history reading `portal_outbox`
through `gm_src_*` needs a `gm_check` policy on that table, which its
`ddl:` can create; the coherence check, as `postgres`, is unaffected.
Functions `portal_login(email, password)` → `(result, token)` (201, 401,
423), `portal_session(token)`, `portal_logout(token)` (added: the
sessions table has no grant), `portal_activate(token, password,
reminders)`, `portal_request_reset(email)`, `portal_reset(token,
password)`, `portal_unsubscribe(message_key)`, `portal_close()`,
`portal_desk_consent(owner_id, purpose, granted)` (`reminders` only). One
link slot (`invite_hash`, `invite_expires_at`) for an invitation's or a
reset's link, a reset lasting 14 days. Tokens: invitations and resets
`portal_hmac('<template>:<id>', key)`, sessions `portal_hmac('session-<rank>:<account>',
key)`, passwords `portal_hmac('<id>', key)` stored bcrypt cost 6 with a
deterministic salt; the key `portal_key(load_epoch)` only in
`owners.settings` (`password_key`). Session ids from 39 301; links
`https://portal.example.net/{activate,password-reset,documents,unsubscribe}/…`.
Indexes `portal_ownerships_current_owner_idx` (T262),
`portal_outbox_notice_idx`, `portal_outbox_reminder_idx` (T288),
`portal_consent_events_keeper_idx` (T275), `portal_documents_animal_idx`
(T294). Choices where the documents are silent (for `spec-writer` with
16b's): `portal_logout`; the reset reusing the invitation's slot and
life; the activation event only on a grant; the database settings in
`schema.sql`, `pgaudit.log` left to the seed. Risks: the fixture's
composed load about 6–7 minutes; `n_live_tup` on `portal_outbox` reads
double (trust `count(*)`). A fresh owner resumes 16b.

### Chunk 16b — paused for rotation (a5a1877), stopped on a tool gap, 2026-11-04

On the owner's word (rotate), 16b's owner paused at WIP `a5a1877` (on
62b452e). Built and tried in dev (api 0.1.0 under uvicorn against a
loaded portal): `portal-api` (`session`, `me`, `animals`, `documents`,
`accounts`, `desk`): owner scope through the API (seller 1 animal, not the
horse sold, its documents 404; buyer the horse, 8 of 9; granted keeper 11;
withdrawn and never-granted keepers 404; planted owner 6; another owner's
document 404 every time); activation 200 then 401, login 201 with the
`portal_session` cookie, four wrong 401, the fifth 423, then the right
one 423, a past token 401; desk 201 (`portal_desk`), 422 for
`keeper-access`, 401 without the credential; preferences, consents,
unsubscribe, reset, logout (204, cookie cleared) as the GM notes list;
1–10 ms each. The desk's `pms` fragment (connection `portal`, stream
`portal.desk-consent` 0.28/h; `TestPortalDesk` 2 OK). The owners' traffic
(`producers/partners/owners/`: `owners_tick`, six streams, `POST /tick
{kind}`; `data.sql` gains `owners.accounts`, loaded equal to
`portal_accounts`), not yet run end to end. `fixture-portal` drafted (8
nodes, `derive:`, seven `left_out:`; `compose --check` passes; the short
test never run; no README). Dev load at shift 0: core 124 s, lab 76 s,
portal 20 s, derivation 128 s; 77 MB, 238 278 rows. Dev containers
`c16pg`, `c16portal`, `c16owners` left for the next owner.

**Stopped on a tool gap** (against W3 item 5's fixture): `compose._shared_nodes`
finds `partners-api` and `partners-backend` only through a `third_parties:`
entry listing them, and `model._check_api_nodes` requires the partners'
api node to serve every listed third party's hostname; with both lab
stubs left out and the messaging stub chunk 21's, no third party can list
the shared nodes in `fixture-portal`, and listing the lab's two is
refused ("no endpoint answers under northfield-lab / practices"). The
owner's options: (a) a fix-sized inserted chunk on `tools/gm/`
recognising the partners' nodes when only `owners` is served; (b)
`lab-api` in place of `interfaces` and the lab's stubs composed for real;
(c) a placeholder messaging third party (chunk 21's material). **Driver's
ruling: (a)** — (b) changes the fixture chunk 21 builds on and returns
when chunk 21 adds `interfaces`' purposes; (c) builds chunk 21's material
early. Sent to `spec-writer` as an inserted chunk 31 for a
`coding-executor`, ahead of 16b's restart.

Choices where the documents are silent (for `spec-writer` with 16b's
merge): `owners.accounts (account_id, email, status, link, activates_at)`
(the route can't read `portal`); `PUT /me/preferences` through gm_api's
private `_call` (the client has only `get()` and `post()`: for the api
brick's next bump); constants as one-value choices; the document list
including superseded versions, no herd listing route; the status codes
(activation 200, logout 204, reset 202 and 401, desk refusal 422, a
refused `keeper-access` 403); without the messaging stub resets are asked
but never used; the desk 422 for a closed account's owner (about one call
in thirty, an error in `pms`' log); `interfaces`' placeholder connection
to `portal-api` (`interfaces.idle`, `GET /animals`).

### Chunk 13 — paused for rotation (5c730b2), 2026-11-04

On the owner's word, the restarted chunk 13's owner paused: branch
`v0.5-c13-vet-scheduling` (cut at 8389dd6), 13a `a53f395` (GM notes,
schema with the slot function, load, classification, register,
governance, policy), 13b WIP `5c730b2` (`pms` fragments, coherence,
variant manifest, `parts:` and the README row, `fixture-bookings`, 5
nodes: bastion, records, clinic-api, pms, idle `interfaces`; README by
hand from the template). `check_domain_dir` clean on the five domains;
unit suite 1137 OK, 2 skipped. Loads (`c13pg`, the four exclusion
constraints in place before the load): +2 (09:50 local, Wednesday) core
121 s, part 99 s, 103 500 rows, 20 MB, 16 729 attended bookings (the
core's placed count); shift 0 115 s / 92 s, 103 538 rows, 16 698. At +2
24 922 bookings, 51 653 allocations, 23 826 shifts (21 793 published),
794 absences. Six coherence queries clean at both shifts (slowest 1.8 s).
The slot function about 150 ms a call; every `pms` key ran as
`sched_app` (one fix: the trainee phone formula overflowed);
`sched.rota.publish` in a transaction planned the seventh week (440),
removed 6 absence-covered shifts, published 392 of the week after next,
booked 7 blocks, a rerun changing nothing, its pattern equal to
`core_shifts` for that week; `23P01` on `sched_allocations_staff_excl`
and a booking 40 days ahead on a planned shift, both dry-run. **Left**:
the fixture's short test (written, `sh -n` clean, never run; it places
T0 in the 09:00 hour local, refusing a weekend; start at UTC minute
40–45), then the final 13b commit and the merge.

W3-b so far (chunks 20, 21): columns as W3 item 0 (`sched_bookings`
`type_id`, `kind`, `animal_id`, `section_id`, `starts_at`, `ends_at`,
`state`, `source`, `request_id`, `exchange_id`, `session_id`,
`booked_at`, `booked_by`, `notes`, `arrived_at`, `cancelled_at`,
`cancel_reason`; `sched_allocations` one of `staff_id`/`room_id`/
`machine_id`/`animal_id`, `role`, `during` generated `'[)'`,
`released_at`; `sched_shifts` with `published_at`, unique
`sched_shifts_staff_start_key`; additions `sched_rooms.consultation_space`,
`sched_types.staff` and `course_id`, `sched_machines.operator_kind` and
`around_the_clock`); `sched_free_slots` as W3 item 2, slots in time
order, `staff_ids` [vet], [operator], [surgeon, anaesthetist, nurse],
[instructor], none for a block type, `EXECUTE` to `sched_app` only;
booking ids: inbound examinations 28 000 + exchange id, imaging 30 000 +
request id, the rest ahead of T0 49 001+; types 1–12 consultations,
13–24 imaging, 25–27 surgery, 28–29 blocks, 30–45 sessions; machines 7,
8, 11–15 around the clock, 9, 10, 16 Monday–Friday 08:00–18:00; blocks'
`notes` `service: machine 7` etc. (the Friday job's idempotence); the
booking horizon settled: the 42 days bind `sched_free_slots` only,
session days and theatre plans inserted directly; grants: `sched_reports`
and `vet_reports` (guarded) read every `sched_` table, `sched_app` writes
bookings, allocations, absences, trainees, enrolments, updates only
`published_at`, `clocked_in_at`, `clocked_out_at` on shifts and `state`
on sessions.

Deviations, for `spec-writer`: theatre plans about 800, not 1 250 (the
core's agenda keeps the domestic surgeons consulting); shift ids can pass
24 000 (a T0 between Friday noon and Sunday plans about 24 230; the
sequence resumes past both); the inbound examinations' id range
28 001–28 700 (the owner's choice); future absences recorded before T0;
an urgent night MRI or scintigraphy booked on the next imaging day;
equine sessions searching six weeks then the next course (the arena busy
about half the weekdays); the load reads `vc_agenda`. A fresh owner
runs the short test and merges.

### Chunk 31 inserted (D421), 2026-11-04

`spec-writer`: plan v12 (045cc6e), D421: with no `third_parties:` entry
listing a scheduler or api node, the partners' shared nodes are the
`no-access` nodes named `partners-backend` and `partners-api` (the plan's
names for chunk 11's nodes); `compose` puts a composed
`producers/partners/owners/` onto them, `partners-api` serving exactly
`owners`, both joining the third parties' nodes for every out-of-reach
check; with an entry listing them, every rule as today. Taken by the
driver (a `composition.yaml` key naming them would change the format).
Edges `29 ──> 31`, `31 ──> 16` (16b's restart and fixture only); wave 3
eight chunks (row 3 says why). Peeks: no intent register, no data
register, no dependency. Known limit: a scenario with the owners' route
and no third party at all is still refused for the owners' `data.sql`
(no v0.5 scenario is). 16b's restart merges `v0.5-w3` first and changes
`fixture-portal`'s lab entries to `[partners-db]`. Chunk 31 dispatched
to a `coding-executor`.

### Chunk 31 — merged (b4c5221), 2026-11-04

`coding-executor`: `d6ffc8f`, merged `--no-ff` at `b4c5221`, no conflict;
worktree removed. Unit suite 1151 OK, 2 skipped (14 new tests; 12 fail on
the old code). `TestOwnersAlone` (`test_compose.py`): the owners' route
alone composes and loads (a copy of `fixture-lab-core`, third parties
`[partners-db]`, `partners-api` serving `owners_tick` under `[owners]`
only); the existing refusals unchanged; the new ones (a node missing, of
another brick, not `no-access`; answering under another hostname or not
under `owners`; a bastion seed file or route naming `partners-api`).
`TestOwnersAloneLoader` (`test_model.py`). The skill's "Third parties"
item gains "The owners alone".

W3-h (for 16b and chunk 21): `model.owners_alone_nodes(data,
left_out=frozenset(), catalog_root=REPO_ROOT) -> OwnersAlone | None`
(`None` when an entry lists a scheduler or api node, or no composed
`producers/partners/owners/` is left in; else `OwnersAlone(scheduler,
api, routes, problems)`); constants `PARTNERS_BACKEND_NODE`,
`PARTNERS_API_NODE`, `OWNERS_ROUTE`; `model.node_brick_id` (compose's
`_brick_id` moved). The loader reports the helper's problems too (a stale
`nodes/` refused); both nodes required whenever an owners' route is
composed. **For `fixture-portal`**: both lab entries list `[partners-db]`
only; `partners-api` and `partners-backend` kept (`no-access`, api and
scheduler); compose again; `partners-db`'s `pg_hba.conf` admits `owners`
on `partners`; the header comment updated. Risk: `inject.py` and
`localimpl` find partner nodes through `third_parties:` entries and may
not see these two; 16b's deployment shows it.

16b restarts on its paused branch.

### Chunk 16 — merged (1ee1a8d), 2026-11-04

16b by a fourth owner (resumed once after the account's usage limit):
`56b86a5` merging `v0.5-w3` at 5e51776 (one conflict in
`tools/tests/test_compose.py`, both `TestPortalDesk` and chunk 31's
`OwnersAloneCase` kept), `207e548` the final 16b commit, merged `--no-ff`
at `1ee1a8d`; worktree and every `c16*` container and `c16net` removed.
`check_domain_dir` clean. `fixture-portal` per W3-h (both lab entries
`[partners-db]`; `partners-db`'s `pg_hba.conf` already admitting
`owners`); the `derive:` entry needed a `reason` (the loader requires
one). Chunk 31's risk did not come up (secrets, mounts, `pg_hba`, the
back end's credential all worked with no third party listing the two
nodes). Through `load-data`: the core, the lab and its partners'
`data.sql`, the portal, the owners' `data.sql`, `cron.sql`, then the
derivation unseen; 11/11 coherence checks. Short test 61/61 in 1008 s (T0
Wed 11:23 local, shift −6; a first run 1038 s with one script bug,
fixed): owner scope through the API (planted owner 6 documents; seller
omits horse 234, 404; buyer 8 of 9; keeper with consent 11; withdrawn and
never-granted 404; another owner's document 404; 401 without a cookie);
activation 200 then 401, login 201 with the HttpOnly cookie, the fifth
wrong password 423 and the right one then 423, a past token 401, the desk
201 / 401; `portal_api` over TLS; in 360 s after T0, 36 calls by 9
accounts, every document opened a `portal_views` row, every login a
session, every listing equal to the policy; `portal-api` 84 requests, 0
errors. The owners' tick in dev: six kinds 200, `PUT /me/preferences`
through `_call` 200, 401 without or with a wrong bearer, 422 for an
unknown kind, 2–49 ms a tick. Unit suite 1153 OK, 2 skipped. `fit` 2 CPU
/ 4G / 8G (the hand-over snapshot 10.84G of 8G: a fixture's, fine).

Figures: the composed load and derivation through `load-data` 632 s and
603 s (`portal` 78 MB, `clinic` 48 MB, `lab` 54 MB); reference loads after
chunk 30 (08:50 local, shift 0 and +2 alike) load 17–18 s, derivation
121 s, 77 MB, 237 904 rows (38 973 documents, 65 032 views, 38 169 outbox
rows); the core ahead 118–119 s, the lab 73–75 s. W3-e additions:
`owners.accounts.account_id` = `portal_accounts.id` = `owner_id`; about
54 % of keeper ticks find a consent to change (222 of 414 active horse
owners). Choices beyond the earlier list: the `derive` reason; two fixes
in the short test. Risks: the fixture's composed load about 10 minutes,
about 13 of the 30 minutes left; the owners' traffic low in a 6-minute
watch (4–9 visits at intensity 10); `n_live_tup` on `portal_outbox`
reads double. **For the gate**: the bastion, api and postgres images
predate their bricks' last commits (rebuild and stack-test them).

### Chunk 13 — merged (fa9a480), 2026-11-04

The finishing owner (resumed once after the usage limit): 13b `5a3e192`
(the WIP amended, with the test fixes), `ca38c80` merging `v0.5-w3` at
af881c5 (the shared lists: `parts: [vet-lab, vet-housing, vet-machinery,
vet-portal, vet-scheduling]`, the README row), merged `--no-ff` at
`fa9a480`; worktree and `c13pg` removed, no stack left. `fixture-bookings`
on the merged branch 39/39 in 1 186 s (T0 18:45:09Z, 09:45 local,
Wednesday, shift −9): `load-data` 233 s, coherence six of six; scheduling
20 MB, `clinic` 71 MB; 24 923 bookings, 51 655 allocations, 23 826 shifts,
794 absences; an overlapping allocation refused `23P01`; the four
exclusion constraints before the allocations; a booking through
`sched_free_slots` (50002) and one 40 days ahead on a planned shift
(50003); the cancellation releasing both allocations and the slot offered
again; `sched.rota.publish` moved to the next minute (94 ms: 392 published,
6 removed, 440 planned, 7 blocks), moved again with no duplicate; no live
overlap, no error in `pms` or `interfaces`. A first run (30/6) found three
test bugs, fixed: the `jobs.yaml` rewrite through `docker exec` without
`-i` (the job never moved; now checked through `/run/scheduler/loaded`),
a boolean read as `true` not `t`, `start-load` holding until 09:00 local.
`fit` fits; unit suite 1153 OK, 2 skipped; `check_domain_dir` clean on
all six clinic domains. **Gate item**: `fixture-bookings`' README was
written by hand from the template, never generated with the
`scenario-document` skill.

**All wave 3's chunks merged**: 29, 14, 15, 12, 30, 16, 31, 13. Next: the
wave gate (a `coding-executor`, verification level: wave gate), and
`spec-writer` bringing vet-scheduling's and vet-portal's documents to as
built.

### Documents to as built: scheduling and portal (D422–D428), 2026-11-04

`spec-writer`: `256de8e` — D422 (vet-scheduling to chunk 13 as built:
W3-b's columns and types, the machines' hours, `sched_app`'s column
grants, `sched_free_slots`' `EXECUTE`, the horizon binding the slot
function only, inbound examinations 28 001–28 700, shift ids to about
24 300, the load reading `vc_agenda`, about 800 theatre plans, 103 500
rows, 20 MB; master spec 9.4's `sched.rota.publish` brought to D411),
D423 (vet-portal to chunk 16 as built: the policies and the two helpers,
`portal_logout`, one link slot, the activation event only on a grant,
`BYPASSRLS`, the status codes, the outbox order and keys,
`owners.accounts`; about 0.20 million rows by `count(*)`, 77 MB).
`bd56599` — the driver's rulings on the four points it left open, each as
recommended: **D424** (O239) an urgent imaging request booked at its
machine's first free slot (the same day on a machine around the clock,
else the next imaging day's opening), BS3, `book-requests` and T113's
witness so; **D425** (O240) the future absences kept, a false-alarm line;
**D426** (O241) the desk's 422 for a closed account's owner kept, a
false-alarm line; **D427** (O242) T274's witness at about one withdrawal
every five or six days, fixed on `portal_keeper_granted` and
`portal_animals_scope`; **D428** access model 9.3's closed-account line to
as built (login 401; a reset request 202 like any address, sending
nothing; unsubscribe 404 like an unknown key). Chunks 21 and 25 carry
notes for wave 4's capture.

**Open for wave 4's capture: O243** — `gm_check` reads no portal row
(forced RLS; `pg_read_all_data` doesn't bypass it): purpose 16's
history, the RL1–RL6 and MS1–MS6 checks and s5's check; any `gm_check`
policy shows in `pg_policies` and can be dropped by a player. May need
the owner's view. The portal GM notes' doubled row count is a gate fix
(sent to the gate's executor).

### Wave gate — first part, 2026-11-04

`coding-executor`, armenelos alone (the VPS drained), under the lock and
the inhibitor. Gate fixes: `8894771` (vet-housing's GM notes, T163 as
D419; chunk 14), `b338c5e` (the `scenario-document` skill lists a
composed domain's `data/cron.sql` jobs; the READMEs of `fixture-imaging`,
`fixture-portal` and `fixture-bookings` regenerated; chunks 15, 16, 13),
`8e1be6a` (vet-portal's GM notes 199 735 rows by `count(*)`; chunk 16),
`231900b` (`fixture-clinic-load`, D407: uncomposed, the 13 producer
folders in `left_out:`, the bastion, `records`, `lab`, `machines`,
`partners-db`; `cron.timezone` `'UTC'` since the loader refuses the
template with no scheduler node), `50692ef` (`fixture-lab-core`'s feed
window: no not-performed test fell in it on the merged branch; chunk 12;
its rerun queued). The `%%` grep: 457 statements in 62 `queries.yaml`,
none to fix.

Results so far: unit suite 1153 OK, 2 skipped (201 s, before the last
three commits); `sh -n` 225, `perl -c` 13, `py_compile` 221, 0 failures;
`postgres` 0.5.0 (cache, `2ee628d58ded`) 315 PASS, 460 s; `bastion` 0.5.0
(cache, `8ffc0bf43d36`) all pass, 82 s; `scheduler` 0.3.0 178/0, 851 s;
`check_domain_dir` clean on the six clinic domains and the shop;
`TestComposedLoad` 2 OK; **`fixture-clinic-load` 23/23, `load-data` 865 s,
27/27 coherence checks (886 s)**; `fixture-housing` place 40/40 (1184 s);
`fixture-imaging` 50/50 (480 s); `fixture-portal` 61/61 (1022 s);
`fixture-core` 40/40 (177 s, as chunk 30 asked); `fixture-bookings` 39/39
(1176 s); `fixture-lab-core` 43/1 (the test bug above).

Each domain's load (load-data's plans and steps into throwaway
`postgres:0.5.0` containers, no CPU limit), shift 0 / +2 in seconds: core
116.3 / 114.8; housing 7.4 / 7.4; scheduling 93.5 / 92.3; lab 72.2 /
72.7; the lab's partner files practices 64.1 / 63.6, xlab 64.1 / 64.2;
pacs 49.6 / 49.4, vitals 9.7 / 9.8, biomed 1.8 / 1.8; portal 17.8 / 17.8,
owners 0.5 / 0.5, the portal's derivation 120.5 / 120.4; total 668 / 666
s; coherence passing at both. By `count(*)` at shift 0: `clinic` 93.4 MB,
512 344 rows (housing 138 970, scheduling 103 569, the core about
269 800); `portal` 82.7 MB, 200 144; `lab` 56.6 MB, 325 993; `pacs` 14.2
MB, 15 950; `vitals` 36.5 MB, 182 130; `biomed` 28.9 MB, 106 327;
`partners` 10.1 MB, 9 782. On Swarm the 0.5-CPU limits on `machines` and
`partners-db` about double the slow steps (each lab partner file about
133 s, pacs about 102 s). **Risk for chunk 27**: `fixture-clinic-load`
takes 886 s of its 30 minutes.

Still running unattended (the executor's queue in the scratchpad's
`gate3/`): the `api` stack test, the scheduler's and `api`'s unit tests,
six bricks' builds and stack tests, the five smokes, `smoke-scenario.sh`
on the four scenarios, `fixture-housing` care, then `fixture-lab-core`
again and the full unit suite on the final head.

### Wave gate — results, 2026-11-05

Second part, a fresh `coding-executor` (armenelos alone, the VPS drained,
under the lock and the inhibitor). **The gate passes**, at `fcd4c66`.

- **The one failure**: `fixture-housing` care 38/1 (1059 s): the queue
  started it at UTC minute 40, setup took 143 s (not about four minutes),
  T0 16:42 local, the 1200 s window ending before 17:05, so the loop
  stopped before the 17:00 round and the feeding check failed instead of
  printing "not reached" (the test's own contract). Gate fix `fcd4c66`
  (chunk 14; the check reports not reached when the window ends before
  17:05, the header says start at minute 43–50); rerun 40/40, 1358 s (T0
  16:46, 7 feedings, 2 nil-by-mouth skipped, the board 64.0 a minute).
- Confirmed: `fixture-lab-core` again 44/44, 587 s (gate fix `50692ef`);
  the unit suite 1153 OK, 2 skipped, 178 s (on `425fadc`; only a shell
  change after); the superseded first runs (`fixture-clinic-load` 22/1,
  the first per-domain harness's `pg_hba`, `fixture-lab-core` 43/1)
  replaced by passing reruns.
- Scenario smokes (D367): `bookshop-new-server` 19/19 (21 s, f1–f6
  present); `fernway-clinics-monitoring` 18/18 (30 s, f1–f8 present);
  `tarnbeck-outdoor-shop` 26/26 (837 s, f1–f10 present, two slow
  consumer keys not judged by design); `tarnbeck-outdoor-campaign` 33/33
  (314 s; f1–f4, f7, f8 `too-soon`, f10 `error` under 12.7 as designed,
  f5 present, none `absent` or `fixed`).
- Stack tests, all 0 FAIL: `postgres` 315 (460 s), `bastion` 90 (82 s),
  `scheduler` 178 (851 s), `api` 88 (194 s), `grafana` 130 (152 s),
  `pgbouncer` 120 (168 s), `prometheus` 131 (78 s), `postgres-exporter`
  103 (99 s), `pgwatch` 72 (249 s), `health-check` 95 (164 s). Smokes:
  `smoke.sh` 61 (29 s), `smoke-monitoring.sh` 43 (46 s),
  `smoke-monitoring-v05.sh` 27 (149 s), `smoke-governance.sh` 121 (120 s),
  `smoke-load.sh` 73 (392 s). Unit tests: scheduler 91 (168.5 s), `api` 36
  (3.0 s).
- Images (`127.0.0.1:5000/dbagm/`): `postgres:0.5.0` 2ee628d58ded 265 MB;
  `bastion:0.5.0` 8ffc0bf43d36 186 MB; `scheduler:0.3.0` b3d7a845addd
  171 MB; `api:0.1.0` dd9698761f70 218 MB; `grafana:0.3.0` 37e7b4789aa7
  845 MB; `pgbouncer:0.1.1` 182 MB; `prometheus:0.2.0` 488 MB;
  `postgres-exporter:0.2.0` 165 MB; `pgwatch:0.1.0` 167 MB;
  `health-check:0.1.0` 195 MB. `/var` 30 GB free; nothing pruned; nothing
  of the gate left (containers, networks, volumes, stacks, units,
  configs, secrets).

Gate fixes in all: `8894771`, `b338c5e`, `8e1be6a`, `231900b`, `50692ef`,
`fcd4c66`. **Wave sync**: none (no intent register); no dependency
changed in wave 3 (no `security-advisor` post-change check). G17 next
(`spec-writer`: chunks 29's and 31's format items into formats.md and
master spec 5).

### G17 — wave 3's formats as built (spec-writer, 2026-11-05)

formats.md draft v31: "Purpose definition" (a history with no feeder, a
history on the partners' database running there; `ddl:`, its refusals,
its roles counted; `ddl:` read from the catalogue, never copied);
"Domain" (the tree's part `keys.sql` and `cron.sql`; `cron.sql` among
the files never copied); "Loading a composed domain" (the core's
`keys.sql` as built, with its `vc_` helpers; a part's `keys.sql`, the
prefix rule and when it streams; a left-out partner's `data.sql`; a
domain's `cron.sql`, its content, where and when it runs, the job role
`LOGIN` with `CONNECT`, the refusals; step (2b) in the order; the
reserved names); "Producer material" (a left-out folder is not merged);
"`docs/gm.md`" (the core keys a part relies on); "Composing domains"
(`left_out:` in the record, its form and effects); "Partners" (the
owners alone, D421); "Versions and pins" (a purpose's DDL read from the
catalogue). Master spec 5, and 6, 6.1, 6.2, 6.6 to match. No decision
added. G17 **done (2026-11-05)**.

Checked, nothing added: formats.md does not describe the scenario
document's contents (the `scenario-document` skill's template holds
them), so `b338c5e`'s `cron.sql` listing needs no line there; formats.md
has no `schedule.yaml` or `queries.yaml` section (their shapes are v0.3
master spec 6.7 and 7.1 and the `scenario-format` skill's templates).
The cron subset (a day of week only with a single-number hour) is in
the skill's `SKILL.md` and `templates/jobs.yaml`, as
`model._cron_problem` checks it. The `%%` rule is the scheduler's, not
the loader's (`execute(statement, params if params else None)`), stated
in `bricks/scheduler/docs/gm.md` ("a statement with no parameter is sent
as written"), not in the skill's `templates/queries.yaml`.

Found, not settled by G17:
1. formats.md v30 held a core's `keys.sql` to `pg_temp.core_*` "and
   nothing else"; vet-core's ships 34 `pg_temp.vc_*` helpers beside its
   18 `core_*` functions (chunk 9), and vet-scheduling's `load.sql` calls
   `pg_temp.vc_agenda` (chunk 30). v31 states it as built; nothing
   checks a core's file.
2. A `cron.sql` names its jobs' databases literally (it runs in
   `cron.database_name`, so `:"DBNAME"` is not theirs), and both files'
   header comments say the GM renames them as the scenario's `at:` does;
   the file is read from the catalogue, never copied, so a scenario
   placing vet-machinery or vet-portal in databases of other names fails
   at the `cron.sql` step, and no loader check catches it earlier. v31
   states the consequence; a check, or the comments corrected, is the
   driver's call.

### Wave 3 — report to the owner, 2026-11-05

- **Chunks merged** (8): 29 (46ee425, inserted at the preflight: the
  loader's support for the parts and the purposes), 14 (82c8c6d), 15
  (4734f32, 9b4daee), 12 (2dc2317), 30 (8566267, inserted: the core's
  agenda on half-hour slots), 16 (1ee1a8d), 31 (b4c5221, inserted: the
  partners' nodes serving `owners` alone), 13 (fa9a480). None moved.
  Chunk 13 stopped once before code (the core's vet draw; D408–D414);
  chunk 16b once on a tool gap (D421). Five rotations on the owner's word
  or on context (12, 14, 15, 13, 16b), two pauses on the account's usage
  limit; every resume from a WIP commit.
- **Gate**: passed at `fcd4c66` (wave log above); gate fixes `8894771`,
  `b338c5e`, `8e1be6a`, `231900b`, `50692ef`, `fcd4c66`. G17 done
  (`b1d53c7`, formats.md v31). No wave sync (no intent register); no
  dependency changed.
- **Figures** (armenelos, 2026-11-04/05): the six domains' composed load
  through the coherence check 865 s on `fixture-clinic-load` (886 s with
  the test), 27/27 checks; the loads in throwaway containers 668 s at
  shift 0, 666 s at +2 (core 116 s, scheduling 93 s, lab 72 s plus 2 × 64
  s of partner files, pacs 50 s, the portal's derivation 121 s); `clinic`
  93 MB / 512 344 rows, `portal` 83 MB / 200 144, `lab` 57 MB / 325 993,
  `pacs` 14 MB, `vitals` 37 MB, `biomed` 29 MB, `partners` 10 MB. Every
  fixture under 30 minutes (the longest `fixture-housing` care 1358 s,
  `fixture-bookings` 1176 s). Images unchanged in size; `/var` 30 GB free.
- **Rulings**: spec D401 to D428 (plan v10 to v12). The owner's
  information: D408 (the core's history caps its agenda, about 4 % fewer
  scheduled consultations, closing 25–30 minutes after they start); D410
  (the farm's rooms close at 16:00, not 13:00). The driver's, taken as
  `spec-writer` recommended: O229 (D404), O235 (D418), O236 (D419),
  O239–O242 (D424–D427).
- **For the owner, open**:
  1. **O243, for wave 4's capture**: `gm_check` reads no portal row under
     forced row-level security (`pg_read_all_data` doesn't bypass it),
     which hits purpose 16's history, the RL and MS checks and s5's
     check; any `gm_check` policy shows in `pg_policies` and a player
     could drop it. Wave 4's capture will bring options.
  2. Information: a `cron.sql` names its jobs' databases literally, so a
     scenario placing vet-machinery or vet-portal under other database
     names fails at that step with no earlier check (G17); proposed for
     chunk 17 (which holds `model.py` in wave 4): a loader refusal and
     the files' header comments corrected. No built fixture is affected.
- `doc-ids compare main v0.5-w3`: 0 collisions. **Merge**: `v0.5-w3` →
  `main` on the owner's word; then wave 4 in a fresh session.

The owner: "merge". `v0.5-w3` merged into `main` `--no-ff` at `b9fe67e`; its worktree and the wave's branches removed. Wave 4 starts in a fresh session, from `main`.

## Wave 4 — started 2026-11-09

Branch `v0.5-w4`, worktree `/home/bastien/work/db_audit_gm-wt/v0.5-w4`,
cut from `main` at 972c4ec, after wave 3 merged into it (b9fe67e) on the
owner's word. Chunks 17 to 21 (κ = 3; no in-wave edge; chunk 17, the
largest, first). No intent register, so no documentalist preflight; the
driver has capture W4 drafted from the chunks' **Architecture capture**
lines, as W1 to W3. Carried over from wave 3: O243 (`gm_check` and the
portal's forced row-level security), settled by W4; chunk 17 gains a
loader refusal for a domain's `cron.sql` naming databases other than
its placement (wave 3's report, item 2).

Gates checked at the start (2026-11-09): G3, Debian's trixie and
`trixie-pgdg` `Release`, PyPI and GitHub answer 200 (chunk 17 rebuilds
the bastion); G4, the swarm (armenelos `Active`, the leader;
`vps-5718ad52` `Drain`; both `Ready`; engine 29.9.2; `tailscale status`
shows the VPS active, direct); `/var` 29G free, `/` 9.6G, about 7.3G of
memory available. No dependency preflight is planned for wave 4: chunk
17 rebuilds `bastion` 0.5.0 with no new package unless its front needs
one (then a G11 row before its branch); chunks 18 to 21 add purposes and
fixtures on built bricks. G11 stands. The security advisor works in
parallel on `main`'s `SECURITY_TODO.md`; the wave touches neither it
nor `.tech` unless a chunk changes a dependency.

### Capture W4 — the purposes' material, parts and `ops` tables, the office, the register and the bastion, `gm_check` under row-level security (chunks 17–21; read by 22 to 27)

Recorded 2026-11-09, before any code; drafted for the wave driver from
the **Architecture capture** lines of chunks 17 to 21 (plan v12, with its
header, "Read first", the gates, the dependency graph, wave 4's order,
the shared lists, "Left for the build" and "The partners, and where each
stub is built"), chunks 22 to 27 as far as they read W4, master spec
6.2, 6.3, 6.6, 7.3, 10.2 to 10.4, 11.1, 11.3, 12, 12.1, 12.2, 13.2,
13.3, access model 3, 6, 7, 8, 9.3, 9.4 and 13,
[data-register-handout.md](data-register-handout.md) 1 to 7,
[clinic-purposes.md](clinic-purposes.md) (3, 4, 9, 11 to 16, "The roles
the purposes add", "`office` at T0"), [cold-storage.md](cold-storage.md),
the domain documents where the purposes are defined (vet-core "The
partners the core meets"; vet-machinery purpose 14; vet-portal "Who sees
what" and purposes 15, 16; vet-scheduling purpose 12),
[formats.md](../../formats.md) v31 ("Scenario", "Purpose definition",
"Domain" with "Loading a composed domain", "Composing domains",
"Partners"), spec D363 to D428 as cited, O243
([open-questions.md](../../open-questions.md)), v0.4's
[database-node-jobs.md](../../archive/v0.4/database-node-jobs.md)
("Row-level security"), and the code on `v0.5-w4` at d2c0f03
(`tools/gm/{model,inject,coherence,compose,render,localimpl}.py`, v0.4's
four `purposes/`, `partners/`, `domains/vet-*/data/cron.sql` and
`producers/`, the composed fixtures, `bricks/bastion/`, the check helpers
`check-sql` and `check-runs` (`scheduler`) and `check-psql` (`postgres`),
the scenario-format skill). W1 to W3's rules: cited, not restated;
**(choice)** marks a point the sources left open, settled here with its
reason; each item names the chunk that writes it and those that read
it. Held: W1, W2 and W3 with their addenda W1-w to W1-z, W2-a to W2-g
and W3-a to W3-h (W3's item 2 as revised); where the merged code differs
from them, the code and the addenda win. Chunks record their as-built
outcomes as **W4-a** (chunk 17), **W4-b** (chunk 18), **W4-c** (chunk
19), **W4-d** (chunk 20) and **W4-e** (chunk 21); chunk 32, if inserted
(Preflight corrections, item 1), as **W4-f**.

**What the sources leave short.** Read against the merged loader, four
of the sixteen purposes have no form: purposes 5, 9, 14 and 15 reach a
third database (`DATABASE_PARTS` is `source` and `target` only, and
`ddl:` and a history's sources follow the parts), purpose 5 runs on two
runners (a job's `part` is `runner` only), and purpose 6 has no scheduler
runner at all (every job must be in the runner's `jobs.yaml`). Every
monthly or yearly job is outside the cron subset (`_cron_problem`: day of
month and month `*`). `gm_check` reads no `portal` row (O243). Adding
`producers/partners/centres/` to `vet-core` (chunk 19) puts every
composed fixture against compose's rule. Items 0, 4, 7 and 8 settle
them; Preflight corrections, items 1 to 3, carry them to the plan.

**0. Rules shared by the purposes** (chunks 18 to 21 write them,
chunk 32 checks them; read by 18 to 27)

- **Where a purpose's material sits (choice; "Left for the build")**:
  v0.4's per-part folders under `material/`, one folder per part named
  for it, plus two files at its root:

  | Path | What | How it reaches a game |
  |---|---|---|
  | `material/runner/` (`jobs.yaml`, `queries.yaml`, `schedule.yaml`, `scripts/`) | the runner's jobs, as v0.4 | the GM copies them into the runner's seed files |
  | `material/runner_<w>/` | a second runner's (item 0, "Parts") | likewise, into that runner's |
  | `material/<part>/ddl.sql` | a database part's DDL, named by `ddl:` (`ddl: {source: material/source/ddl.sql}`) | read from the catalogue by `load-data` at step (2b) (W3-f (e)) |
  | `material/target/data.sql`, `material/target/office.sql` | the DDL of a database no domain holds (`office`), v0.4's form | copied into the node's data file (`office.sql` first, once) |
  | `material/history.sql` | the planted past, named by `history:` | read from the catalogue at step (4) |
  | `material/api/<node>/` (`api.yaml`, `routes/`, `db/`) | endpoints the purpose brings to a customer's `api` node, a domain's `producers/api/<node>/` layout | copied into the scenario layer `compose/<node>/`, merged by `gmctl compose` |
  | `material/receiver/<prefix>/`, `material/partner/<prefix>/` | a stub with no stream of its own, laid out as `producers/partners/<prefix>/` (`api.yaml`, `routes/`, `db/`, `queries.yaml`, `schedule.yaml`, `data.sql`) | as `partners/coldstore/` is: its fragments into `compose/partners-api/` and `compose/partners-backend/`, its `data.sql` after `partners/shared/partners-db/data.sql` in `partners-db`'s data file |
  | `checks/`, `gm.md` | as v0.4 | |

  Reason: one rule, v0.4's folders kept, and the two files `load-data`
  reads (`ddl:`, `history:`) named by the part they serve or at the
  root; `<receiver|partner>` is the part that names the stub's node.
- **Parts beyond v0.4's (choice; chunk 32's (a) to (c))**: a purpose may
  declare more database parts named `source_<w>` and more runners named
  `runner_<w>` (`<w>` `[a-z][a-z0-9]*`), each checked as its base part
  (`source`: a location, never a standby; `runner_<w>`: a scheduler node
  of role `transformer`, its jobs in its own `jobs.yaml`) and usable
  wherever the base is (`jobs[].source`/`target`, `jobs[].part`,
  `roles[].part`, `trace[].part`, `data_moved.writes`, `ddl:` keys; a
  history reads every mapped database part but `target`, as
  `gm_src_<part>`). A job of `method: pg_cron` names as its `part` the
  database part it runs in, is in no runner's `jobs.yaml`, and is
  scheduled by that part's `ddl:` (item 3); a purpose whose jobs are all
  such declares no `runner`. Reason: purposes 5, 6, 9, 14 and 15 as the
  spec defines them; `inject.py` already maps any part name to a
  source and any `ddl:` key to a run, so only `model.py`'s vocabulary
  and the template change. The clinic's mapping:

  | Purpose | Database parts | Runners | `ddl:` | `history:` |
  |---|---|---|---|---|
  | 1, 4, 11 | `source` = `target` = `records/clinic` | `interfaces` | `target` | — |
  | 2, 3 | `source` = `target` = `lab/lab` | `interfaces` | `target` | — |
  | 5 | `source` `records/clinic`, `source_lab` `lab/lab`, `target` `records/office` | `runner` `interfaces`, `runner_reports` `backoffice` | `source`, `source_lab` | — |
  | 6 | `source` = `target` = `lab/lab` | none (`pg_cron`) | `target` | — |
  | 7, 8, 12 | `source` `records/clinic`, `target` `records/office` | `backoffice` | — | yes |
  | 9 | `source` `records/clinic`, `source_lab` `lab/lab`, `target` `records/office` | `backoffice` | — | yes |
  | 10 | `source` `lab/lab`, `target` `records/office` | `backoffice` | — | yes |
  | 13 | `source` `records/clinic`, `target` `machines/pacs` | `interfaces` | `source`, `target` | — |
  | 14 | `source` `machines/vitals`, `source_biomed` `machines/biomed`, `target` `partners-db/partners` | `interfaces` | `source`, `source_biomed` | yes |
  | 15 | `source` `records/clinic`, `source_lab` `lab/lab`, `target` `records/portal` | `interfaces` | all three | — |
  | 16 | `source` `records/portal`, `target` `partners-db/partners` | `interfaces` | `source` | yes |

  A report job reading the standby keeps its part on the primary (a
  standby is no location, W2 item 1): its scheduler connection targets
  the standby, the part names `records/clinic`, which the history
  reads.
- **The `ops` schema (choice)**, in every domain database a purpose
  writes, created by each `ddl:` file that needs it, guarded, the same
  text in every file (between the lines `-- ops: begin` and `-- ops:
  end`, which a unit test keeps byte-identical across `purposes/`,
  Preflight corrections, item 4):

  ```sql
  -- ops: begin
  DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ops') THEN
  CREATE ROLE ops NOLOGIN;   -- owns the purposes' tables
  END IF; END $$;
  CREATE SCHEMA IF NOT EXISTS ops AUTHORIZATION ops;
  REVOKE ALL ON SCHEMA ops FROM PUBLIC;
  SET ROLE ops;
  CREATE TABLE IF NOT EXISTS ops.runs (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      purpose text NOT NULL, job text NOT NULL,
      started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL DEFAULT now(),
      rows_read integer NOT NULL DEFAULT 0, rows_written integer NOT NULL DEFAULT 0);
  CREATE INDEX IF NOT EXISTS runs_job_idx ON ops.runs (purpose, job, started_at);
  CREATE TABLE IF NOT EXISTS ops.incidents (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      purpose text NOT NULL, job text NOT NULL, kind text NOT NULL, ref text NOT NULL,
      opened_at timestamptz NOT NULL DEFAULT now(), reason text NOT NULL,
      run_id bigint REFERENCES ops.runs (id));
  CREATE INDEX IF NOT EXISTS incidents_ref_idx ON ops.incidents (purpose, kind, ref);
  CREATE TABLE IF NOT EXISTS ops.watermarks (
      purpose text NOT NULL, name text NOT NULL,
      at timestamptz, last_id bigint, run_id bigint REFERENCES ops.runs (id),
      PRIMARY KEY (purpose, name));
  RESET ROLE;
  -- ops: end
  ```

  `purpose` is the purpose's id, `job` its job's name, `kind` and
  `ref` the incident's reason class and the id it names (a request, a
  `send_key`, a message key: ids only, never a name), `at` and
  `last_id` a keyset position (a time, then an id breaking ties, as
  `lab-api`'s feed orders). No unique constraint on incidents: "one
  incident each" (CC2, ND4, MS5) is the jobs' care and the checks'
  judgement, so a fault can break it. **Grants**, in each purpose's own
  DDL for each of its roles: `USAGE` on `ops`, `SELECT, INSERT` on
  `ops.runs` and `ops.incidents`, `SELECT, INSERT, UPDATE` on
  `ops.watermarks`, and what its own tables need. **A purpose's own
  tables** (`ops.lab_orders_sent`, `ops.request_results`,
  `ops.exchange_messages`, `ops.notifications`,
  `ops.booking_consultations`, `ops.imaging_results`, `ops.shipments`)
  are its alone, owned by `ops`, each with `run_id bigint NOT NULL
  REFERENCES ops.runs (id)`, its trace's `run_column`. **Every run** writes
  one `ops.runs` row in the transaction of its output; a job writing two
  databases writes one in each, in each database's transaction, with
  the same `job` and `started_at` (the script's own start), which ties
  them (12.1). **Watermarks start at `load_epoch`**: the DDL inserts each
  of its watermarks (`ON CONFLICT DO NOTHING`) at `:'load_epoch'`,
  since the domains' state at T0 is their state at that moment (W2
  item 3). `office` keeps v0.4's form: its `runs` (the same columns) in
  `public`, owned by `office` (item 5). Reason: three purposes write
  `ops.runs` in `clinic` and three in `lab`, so the first DDL to run
  defines a shared table for all; one text, guarded, makes any subset
  of purposes load alike, as v0.4's `etl_runs` (`id, job, started_at,
  finished_at, rows_read, rows_written`) with the purpose's name added.
- **`trace:` on a domain database lists `ops` tables only (choice)**:
  the loader refuses any other table there (`_check_purpose_ops`, as
  formats.md states it), so the domain tables a purpose writes
  (`requests`' state, `lab_callbacks`, `sched_bookings`,
  `mach_worklist`, `portal_documents`, `portal_outbox`) appear in
  `data_moved.writes` and in `gm.md`, and the evidence outside the trace
  (`cron.job_run_details`, a partner's tables, the vault's manifests) in
  the invariants' witnesses and checks. Trace kinds: `run-ledger` for
  `ops.runs`, `office`'s `runs` and `ops.watermarks`; `outbox-rows` for
  a per-request ledger and `ops.incidents`; `published-results` for a
  copy others read (`ops.request_results`, `ops.imaging_results`,
  `ops.booking_consultations`, `office`'s tables). Reason: the merged
  check and the four kinds as they stand; 12.2's "Trace:" lists stay the
  prose they are.
- **The purposes' roles (choice)**: created by their purpose's DDL at
  top level of its own line inside a `DO … IF NOT EXISTS` block
  (counted by `node_creates`, W3-f (e)), `LOGIN`, `CONNECT` granted by
  name on each database they use (`load-data` revokes it from
  `PUBLIC`): `vet_interfaces` (1, 4, 5, 11, 13, each guarded),
  `sched_interfaces` (11), `vet_portal_sync` (15), `vet_exchange` (4) in
  `clinic`; `lab_watch` (6), `lab_release` (15) in `lab`; `mach_orders`
  (13) in `pacs`; `mach_archive` (14) in `vitals` and `biomed`;
  `portal_sync` (15), `portal_dispatch` (16) in `portal`. A purpose's DDL
  never creates or alters a role a domain creates (`vet_reports`,
  `sched_reports`, `lab_dispatch`, `lab_reports`, `portal_api`), only
  grants to it; and it grants only what clinic-purposes' "The roles the
  purposes add" lists, column grants where the list names columns.
- **Cadences inside the cron subset (choice)**: `_cron_problem` takes no
  day of month or month and a day of week only with a single-number
  hour. So a monthly or yearly job runs daily at its hour (`"0 3 * *
  *"`) and does nothing unless the customer's local date, read from its
  source (`business_settings.timezone` in `clinic`, the lab's settings
  in `lab`), is its day (the 1st; the 1st to the 5th; 15 January;
  1 January), writing neither output nor run row on other days; a job
  with an hour window and a day of week (`chase-send-outs`, 08:00–19:00
  Monday to Saturday) runs `*/15 * * * *` and returns at once outside
  it; a day-of-week range is written as a list (`0 16 * * 1,2,3,4,5`).
  The calendar is stated in `computes:` and `gm.md`. Reason: render
  shifts hours only, and a shifted hour may cross midnight, which a
  day-of-month field cannot follow; the script reads the customer's
  date, which the shift keeps.
- **HTTP credentials and hostnames in wave 4 (choice)**, beside W3 item
  0's table, which stands:

  | Endpoint (host) | Accepts | Sent by | Chunk |
  |---|---|---|---|
  | `exchanges` (`clinic-api`: `POST /exchanges`, `/exchanges/{key}/answer`, `/exchanges/{key}/report`), connection `clinic-exchanges` as `vet_exchange` | `clinic_centres` | the centres' stub | 19 |
  | `centres_exchanges` (each centre's hostname: the same three routes) | `centres_customer` | purpose 4 | 19 |
  | `authority_notifications` (`authority`: `POST /notifications`) | `authority_customer` | purpose 5 | 19 |
  | `authority_amu_reports` (`authority`: `POST /amu-reports`) | `authority_customer` | purpose 8 | 20 |
  | `headoffice_figures` (`head-office`: `POST /figures`) | `headoffice_customer` | purpose 9 | 20 |
  | `messaging_messages` (`messaging`: `POST /messages`) | `messaging_customer` | purpose 16 | 21 |
  | each stub's `<prefix>_tick` | `partners_backend` | the back end | 19 |

  Prefixes `centres` (one folder, three hostnames, chunk 19 naming them
  from the core's partner sites, recorded in W4-c), `authority`,
  `headoffice`, `messaging`. **The authority is one prefix for two
  purposes**: purposes 5 and 8 each ship `material/receiver/authority/`
  whose `data.sql` creates the role, the schema and `authority.state`
  guarded (`IF NOT EXISTS`, the same text), each its own table
  (`authority.notifications`, `authority.amu_reports`), endpoint and
  route; `authority.normal` byte-identical in both (compose merges
  identical entries silently, W1-w); the 503 one call in fifty a state
  value both routes read. The handed-over credentials are the six
  `*_customer` (item 1).
- **Where a check runs (choice)**: as v0.4, on the runner node, the
  runs from `check-runs`, the customer's databases through `check-sql`
  as `gm_check`. A check needing a partner's side runs on the partners'
  database node (`partners` through `check-psql`, the customer's
  databases through `check-psql --node`) and judges runs from
  `ops.runs`, its `CHECK_SINCE` as given; the purpose's `gm.md` names
  which. A node a check or a history reads from another node admits
  `gm_check` from the network (a `host` line matching it, as every
  fixture's `host all all` line does today). Reason: access model 8
  (the partners' side through the GM's own plane, D383), and `ops.runs`
  is the run ledger 12.1 makes it.

**1. The data register and `bastion` 0.5.0** (chunk 17 writes, W4-a
records; read by 23, 26, 27)

- **The skill's inputs (choice)**: the scenario's `scenario.yaml`,
  `composition.yaml`, the files `governance:` names (the classification
  copy, the policy), `player/partners.md` when mapped, and
  `gm/answer-key.yaml`; from the catalogue each composed domain's
  `data/register.yaml` and each `purposes:` entry's `purpose.yaml`
  (its `classification:` and `data_moved:`). The header's controller
  and contact come from the story.
- **Its outputs**: `gm/data-register.yaml`, opening with
  `generated_from:`, a map from each input's path (scenario-relative;
  `catalog/<path>` for a catalogue file) to `sha256:<hex>` of the file's
  bytes; then the header, `entries` (one per register-fragment
  activity, its `id` the fragment's), the internal table and the
  `node/database` index; each entry's fields named `purpose`, `people`,
  `data` (by class), `where`, `shared_with`, `kept_for`, which are
  `register_diff:`'s `field` values **(choice)**. `player/data-register.md`,
  the entries rendered with each `register_diff:` item's `handed_out`
  in place of its `true`, or absent for `{absent: true}`.
- **The order (choice)**: the skill builds the true entries, derives
  each register fault instance's `register_diff:` and writes it into
  the answer key, then digests every input (the answer key now final),
  then writes both files. Reason: the answer key is an input and an
  output; written first, a plain byte digest stays current, and any
  later edit to it makes the register stale, as 13.3's triggers say.
- **A register fault's change (choice)**: the fault definition's
  parameters say the change (`governance-register-flow-undeclared`:
  `recipient`, the `partners.md` name dropped from every entry's
  `shared_with`, default cold storage); the skill computes the
  `register_diff:` items from them against the true register, one per
  entry changed. `seed_changes: data-register.md` stays the injection
  (6.4): the scenario's handout carries the change, regenerating
  without the fault clears it. The skill's `SKILL.md` gives T300 to
  T308's transforms, so it applies any of them; s6 is chunk 23's.
- **Purposes' tables in the register (choice)**: a purpose table
  holding a `personal` or `customer-linked` column joins, under
  `where`, the entry of the activity whose tables its `data_moved`
  reads those columns from (the back office's medicines register under
  the core's medicines entry, the portal's copies under the core's
  owners and records); one holding only `internal` columns goes in the
  internal table, one line per purpose. Reason: 13.3's inputs then
  suffice; no register key for purposes.
- **The loader's checks** (`model.py`): every `generated_from` digest
  recomputed and every expected input listed, else "stale register:
  regenerate with the data-register skill", naming the file; coverage
  as 13.3 (every `personal` and `customer-linked` column of the
  classification copy and the purposes' `classification:` in exactly
  one entry under its class; every `governance:` location and outbound
  flow present; every `node/database` holding a classified table in an
  entry's `where`); the handout mapped and present unless the answer
  key's `{absent: true}`; a scenario listing `domains:` without
  `governance:` and a register refused, **a scenario whose id starts
  `fixture-` exempt (choice)**, as the released shop is, a fixture with
  a register checked in full. Reason: D335 binds played scenarios; the
  seven composed fixtures and wave 4's have no `governance:`, and
  chunk 17 holds none of them (Preflight corrections, item 5).
- **The partners' credentials (choice; D365)**: a `third_parties:` entry
  gains `credentials: [<name>, ...]`, the HTTP credentials `partners.md`
  documents for that partner, the customer's own (the four `*_customer`
  of item 0 and W3 item 0's `xlab_customer`, `practices_customer`).
  Render marks each `http_<name>` handed over (16 characters, the
  players' alphabet) and mounts it on the bastion too, the one node
  holding a credential it neither sends nor checks; `partners.md` names
  each as `{{credential:<name>}}`, which the bastion's entrypoint
  replaces by the mounted value when it copies the file into
  `/home/player` and onto the page, failing its start on a name with no
  secret. The loader refuses: a placeholder naming a credential no entry
  lists, a listed one `partners.md` does not name, one no endpoint
  serving that entry's hostname accepts, `partners_backend`, and any
  node's `vault_credential` (cold storage's `cold_storage`). `gmctl
  status` lists them as "password, handed over". Reason: "given with
  `partners.md`" (D365), a value per game, the page and the home copy
  the same text.
- **The bastion (7.3; D363, D369)**: `seed.optional` gains `partners.md`
  and `data-register.md`, "Partners" then "Data register" after the data
  policy, each only when mapped. The cold-storage route **(choice)**: a
  `web_routes` entry `cold-storage: cold-storage:8000` (the partner's
  hostname, so the API dispatches it); the front proxies only `GET
  /cold-storage/` to `/` and `GET /cold-storage/manifests` (its query
  string kept) to `/manifests`, with `Host: cold-storage`, every other
  path or method 404; the loader's one exception in
  `_check_web_routes` is a route whose target is the hostname an
  `api.yaml` endpoint of `partners/coldstore/` (`coldstore_manifests`)
  is served under, every other third-party node and alias refused.
  `public/` holds no `data.sql` (`_check_fragments`, naming the file and
  `producers/partners/<prefix>/` as its home; `_partner_data_files`
  and so `node_creates` reading `partners/` only).

**2. A domain's `cron.sql` against its placement** (chunk 17 writes,
W4-a records; carried from wave 3's report, item 2, and G17's note)

- **What is parsed (choice)**: each statement of `data/cron.sql`, all of
  them `SELECT cron.schedule_in_database(…)` calls (`check_cron_file`),
  its arguments split at top-level commas outside quotes, dollar quotes
  and parentheses; the database is the fourth positional argument, or
  the one named `database` (`=>` or `:=`), and must be a single-quoted
  literal (`check_domain_dir` refuses anything else, naming the line).
- **What counts as the domain's databases**: the database part of each
  location its `domains:` entry's `at:` gives (`records/portal` gives
  `portal`; vet-machinery's map gives `pacs`, `vitals`, `biomed` as
  placed), all on its one node (W3-f (d)).
- **The refusal**, in `_check_domain_cron`, so `load-data` meets it
  through `load_scenario` before anything runs: `scenario.yaml:
  domains[<id>]: domains/<id>/data/cron.sql:<line>: job <name> runs in
  database <db>, which this entry's at: does not place on <node> (it
  places <db>, ...): a cron.sql is read from the catalogue and names its
  jobs' databases as written, so at: must name them so`.
- **The headers corrected**: vet-machinery's and vet-portal's
  `data/cron.sql` say the file is read from the catalogue, never copied,
  so a scenario placing the part names its databases `vitals` and
  `biomed` (`portal`), the loader refusing other names; "the GM renames
  them" goes (T254's note kept). Reason: G17's finding; the check
  catches it at the format check, not at the `cron.sql` step.

**3. The lab's round trips: purposes 1, 2, 3, 6** (chunk 18 writes,
W4-b records; read by 19 to 22)

- **The material and the `ops` tables**: item 0's layout and text,
  written first here: chunk 18 holds the `ops` block's equality test
  (Preflight corrections, item 4). Its own tables:
  `ops.lab_orders_sent` and `ops.request_results` in `clinic` (1); none
  beyond the shared three in `lab` (2, 3, 6).
- **Purpose 1**: `lab-api` connection `lab-api` with `lab_centre` (W3
  item 0); the feed's watermark `(at, last_id)` = (`released_since`,
  `order_test_id`), inclusive with a margin, deduplicated by
  `ops.request_results`; a history `sent` request's result maps by the
  feed's `request_id`, so no planted ledger is needed.
- **Purpose 6 (choice)**: `lab`'s `pg_cron` lives in `lab` itself: the
  node's seed preloads it with `cron.database_name = 'lab'`,
  `cron.timezone` the customer's and `cron.log_run = on`; purpose 6's
  `target` DDL runs `CREATE EXTENSION IF NOT EXISTS pg_cron`, creates
  `lab_watch` (`LOGIN`, `CONNECT` on `lab`), its grants, and schedules
  `cron.schedule_in_database('lab-critical-calls', '*/10 * * * *',
  $job$…$job$, current_database(), 'lab_watch')`, one statement writing
  each incident and its run. Reason: the DDL runs connected to the
  mapped database (W3-f (e)), and pg_cron's functions exist only in
  `cron.database_name`; D405's premise holds there (database, role and
  `CONNECT` exist at step (2b)), and load-data's survey then finds
  pg_cron in `lab` (its read policy for `gm_check`, the launcher's
  clean-up).
- **Cadences**: `send-outs` `0 16 * * 1,2,3,4,5`; `chase-send-outs`
  `*/15 * * * *`, windowed (item 0).
- **Fixtures (choice; D403)**: `fixture-orders` as planned, eight nodes
  (the bastion, `records`, `lab`, `clinic-api`, `lab-api`, `pms`, `lis`,
  `interfaces`), `left_out` vet-lab's `partners/xlab` and
  `partners/practices`; `fixture-send-outs` the bastion, `records`,
  `lab`, `lab-api` (the external lab's answer arrives there),
  `interfaces` and the partners' three nodes (eight), `left_out`
  vet-core's `pms` and `api/clinic-api`, vet-lab's `lis`: the test
  releases a practice's test itself, as `lis` would (time placed).
  Both: vet-core's `partners/centres` once chunk 19 has merged (item 4).
- **SO4**: about eight send-outs in flight at T0 (D420): the answer leg
  is judged on the planted ones answered after T0 and those the test
  sends.

**4. The exchanges and the notifications: purposes 4, 5** (chunk 19
writes, W4-c records; read by 22, 27)

- **The centres' stub**: `domains/vet-core/producers/partners/centres/`,
  prefix `centres`, three hostnames on one folder; `data.sql` plants
  from `core_exchange` (D374) the exchanges in flight at T0 as each
  centre holds them, with the core's keys streamed ahead; its ticks
  post the centres' own requests (about one a day, `office` hours) to
  `clinic-api` with `clinic_centres`, answer within a working day and
  report one to three days after an examination.
- **Every composed fixture meets it (choice)**: a new producer folder of
  vet-core puts every fixture composing vet-core against compose's rule
  (W3 item 0). The fixtures' `composition.yaml` `left_out:` lists are a
  shared list in wave 4: at its merge chunk 19 adds `{domain: vet-core,
  producer: partners/centres, reason: …}` to every composed fixture on
  `v0.5-w4` that does not compose the centres (today `fixture-core`,
  `fixture-lab-core`, `fixture-bookings`, `fixture-housing`,
  `fixture-imaging`, `fixture-portal`, `fixture-clinic-load`, and
  whichever of 17, 18, 20, 21's have merged); a chunk merging after it
  adds the line to its own new fixtures when it takes `v0.5-w4` in.
  Where a fixture has a partners' database, the left-out `data.sql`
  still runs (W3-f (b)). Reason: a `left_out` entry naming a folder not
  yet merged is refused, so no other chunk can add it earlier; the
  shared-list form keeps the suite green at every merge.
- **Purpose 4's endpoints**: `material/api/clinic-api/` (item 0's
  `exchanges` endpoint and connection), merged with vet-core's
  `animals` and `stays` by compose; `vet_exchange` and the grants on
  `exchanges` in `clinic` by purpose 4's DDL.
- **Purpose 5**: `material/receiver/authority/` (item 0); its
  `office` copy needs `office.sql` (item 5) in `records`' data file; in
  `fixture-exchanges` `runner_reports` maps to `interfaces`, which then
  holds `office` as `office_jobs`, and the test moves the 02:15 copy to
  the next minute. Fixture nodes as planned (eight), `left_out`
  vet-core's `pms`, vet-lab's `lis`, `api/lab-api`, `partners/xlab`,
  `partners/practices`; the centres composed.

**5. The periodic reports: purposes 7 to 10, 12** (chunk 20 writes,
W4-d records; read by 24, 27)

- **`office` (choice)**: `material/target/office.sql`, byte-identical
  in purposes 5, 7, 8, 9, 10 and 12 (the test of item 3 compares them),
  copied once at the head of the purposes' share of `records`' data
  file: `CREATE ROLE office NOLOGIN`, `office_jobs LOGIN`,
  `office_reader LOGIN`; `CREATE DATABASE office OWNER office`,
  `CONNECT` revoked from `PUBLIC` and granted to the two; `\connect
  office`; as `office`, `runs` (item 0's columns) and
  `regulatory_submissions (id bigint GENERATED ALWAYS AS IDENTITY
  PRIMARY KEY, kind text NOT NULL, source text NOT NULL, ref text NOT
  NULL, payload jsonb NOT NULL, sent_at timestamptz, reference text,
  copied_at timestamptz NOT NULL DEFAULT now(), run_id bigint NOT NULL
  REFERENCES runs (id))` (purposes 5 and 8); `office_jobs` `SELECT,
  INSERT, UPDATE` on both, `office_reader` `SELECT`; `\connect
  postgres`. Each purpose's `material/target/data.sql` follows it:
  `\connect office`, its tables as `office`, its grants, `\connect
  postgres`. `vet_reports`, `sched_reports` and `lab_reports` are the
  domains' roles, created by their schemas after the data file: the
  office's DDL never creates them (Preflight corrections, item 6).
  Reason: one `CREATE DATABASE` the loader sees, any subset of the six
  purposes loading.
- **The tables**: clinic-purposes' names (`medicines_register`,
  `controlled_movements`, `register_extracts`, `controlled_balances`,
  `controlled_inventories`; `lab_charge_lines`, `lab_statements`;
  vet-scheduling's `working_time_days`, `rest_breaches`,
  `working_time_months`), and **(choice)** `antimicrobial_use` (one row
  per local day, species and ATCvet code), `amu_reports` (one per year
  and species due, its reference), `daily_figures` (one per day,
  section and measure, HO2), `monthly_figures` (one per month and
  measure, its reference); columns by W3 item 0's rule, each output
  row's `run_id`; each table's local day `day` (`date`), a month
  `month` (its first day).
- **The feeders and periodic jobs** (`material/runner/`, keys
  `<prefix>.<job>` with prefixes `meds`, `amu`, `figures`, `charges`,
  `worktime`): `feed-medicines-register` `30 1 * * *`,
  `feed-controlled-drugs` `45 1 * * *`, `close-medicines-register`
  `0 3 * * *` (the 1st), `balance-controlled-drugs` `15 3 * * *` (the
  1st), `inventory-controlled-drugs` `30 3 * * *` (1 January);
  `feed-antimicrobial-use` `0 2 * * *`, `report-antimicrobial-use`
  `0 4 * * *` (15 January); `feed-daily-figures` `30 0 * * *`,
  `send-monthly-figures` `0 5 * * *` (the 1st to the 5th);
  `feed-lab-charges` `30 2 * * *`, `close-lab-statements` `0 4 * * *`
  (the 1st); `feed-working-time` `30 9 * * *`, `close-working-time`
  `0 5 * * *` (the 1st). Each feeder one SQL key reading as its
  `*_reports` role and one writing as `office_jobs`, in a script
  holding both connections (v0.4's `rollup-hourly`); the feeder's
  reading query is a named key in `queries.yaml`
  (`amu.feed.read`, …), the place s3's fault edits (chunk 24).
- **The planted periods (choice)**: the history plants exactly what the
  periodic jobs would have written before `load_epoch`: a feeder's day
  `d` when `d + 1` at its hour (local) is before `load_epoch`, a close
  when its 1st at its hour is, last year's report when 15 January's
  run is, each with its run row and a reference where the partner
  answered (`<prefix>-<period>`); from the history's first day. So a
  T0 just before a feeder finds its day unplanted, the feeder's to
  write. The history reads `gm_src_source` (and purpose 9
  `gm_src_source_lab`), never the standby. s3's "last year's report
  short" is s3's own injection rewriting `amu_reports` and its days
  (chunk 24).
- **The head office's stub** `material/receiver/headoffice/`
  (hostname `head-office`); purpose 8's route on the authority (item
  0).
- **Fixture `fixture-reports` (choice)**: the bastion, `records`
  (`clinic`, `office`), `standby`, `backoffice`, `lab`, the partners'
  three nodes (eight; the authority's and head office's routes need
  them); T0 a Friday at 01:20; vet-core, vet-scheduling, vet-housing,
  vet-lab composed, `left_out` every producer folder of the four (as
  `fixture-clinic-load`'s), the centres added after chunk 19's merge.

**6. The parts' flows: purposes 11, 13 to 16** (chunk 21 writes, W4-e
records; read by 23, 25, 27)

- **Purpose 11**: vet-core as built has no stream opening scheduled
  consultations (D317; its `pms` schedule says so): nothing to remove.
  `book-requests`: an inbound examination's booking id `28 000 +
  exchange id` (D422), its machine by `exchanges.reason` and the
  species in `partner_patient` (D413); an urgent request at its
  machine's first free slot, the same day on one around the clock,
  else the next imaging day's opening (D424), BS3 reading it so.
- **Purpose 13**: `mach_orders` reads `mach_worklist` (accession,
  request, state, `cancelled_at`, cancelled because: column grants,
  D416); `ops.imaging_results` and its watermark in `clinic`, the
  worklist inserts in `pacs` with its `ops.runs` row there.
- **Purpose 14 (choice; D366, D418)**: its history plants
  `coldstore.manifests` for every day before the kept window (before
  yesterday, local, at `load_epoch`) from the history's first day,
  types `vitals` and `machine-readings`, `shipment_id` `<type>-<day>`,
  rows declared and received equal (W3 item 4's counts: readings
  `mach_readings_daily.rows` summed from `gm_src_source_biomed`,
  vitals the ticks within `mach_sessions` from `gm_src_source`), its
  `source` the node name read from `gm_src_source`'s `host` option, so
  no name is written in the file. `ship-partitions` reads the zone and
  the window from `mach_vitals_settings` and `mach_settings`: the DDL
  grants `mach_archive` `SELECT` on them. Cadence `40 0-5 * * *`; its
  connection to `cold-storage` with `cold_storage` (the
  customer's account key, never handed over).
- **Purpose 15**: `portal_sync`'s policies `<table>_sync`, `USING
  (true)`, `WITH CHECK (true)` where it writes; the watermarks at
  `load_epoch` (item 0), the derivation having written T0's copies.
- **Purpose 16 (choice; D404)**: the stub `material/partner/messaging/`
  (W3 item 5's `messaging.messages` and `messaging.state`), its
  `data.sql` in `partners-db`'s data file; `portal_dispatch`'s
  policies `<table>_dispatch`. The history (`target` `partners-db/partners`,
  `source` `records/portal`, on the partners' node, `portal` over TCP)
  inserts the last 14 days' sent `portal_outbox` rows (`received_at` =
  `sent_at`) and then `GRANT USAGE ON SCHEMA messaging, SELECT ON
  messaging.messages TO owners` when `to_regrole('owners')` is set:
  the data file runs before vet-portal's `owners` `data.sql` creates
  the role, the history after. It reads `portal_outbox` through item
  7's read policy. With the stub, resets are used and unsubscribes
  sent; `owners.activate` reads the stub's messages (`to_regclass`).
  `fixture-portal` gains a `third_parties:` entry for `messaging`
  listing the three nodes, which ends W3-h's owners-alone form there
  (the API node then serves `messaging` and `owners`); its T0 just
  before 09:00 local for `queue-reminders`.
- **The fixtures (D403)**: bookings five nodes, imaging seven, portal
  eight, as built, `interfaces`' placeholder (`interfaces.idle`)
  replaced by the purposes; `fixture-vault` the bastion, `records`,
  `machines`, `interfaces`, `partners-api`, `partners-db` (six;
  vet-machinery composes with its core), `left_out` vet-core's `pms`
  and `api/clinic-api` and vet-machinery's `equipment` (the shipped day
  is loaded), T0 21:55, shipping moved to the next minute; each with
  vet-core's `partners/centres` after chunk 19 (item 4). Not in W4:
  the `api` brick's `put()` (`PUT /me/preferences` through `_call`
  until its next bump).

**7. O243: `gm_check` under the portal's row-level security** (chunk
32 writes the mechanism, W4-f records; read by 21, 25, 27)

The facts in the code: `gm_check` is `LOGIN`, `pg_read_all_data`, no
`BYPASSRLS`, re-applied at every container start (`postgres`' GM
notes); every check reads as it (`check-sql` from a scheduler node,
`check-psql` on a database node); every derivation, history and
coherence source is read through `postgres_fdw` as `gm_check`
(`inject.fdw_sql`, W2 item 3), the coherence query itself running as
`postgres` in its own database; `load-data` already gives `gm_check` a
permissive read policy, `gm_check_read`, on `cron.job` and
`cron.job_run_details` (`inject.policy_sql`), "narrower than
`BYPASSRLS`" (v0.4 database-node-jobs.md, chunk 7, W2-x). The options:

| Option | Mechanism and files | Players see | Faults |
|---|---|---|---|
| A. A `gm_check` read policy on each table with row security | `load-data` adds `gm_check_read` (`FOR SELECT TO gm_check USING (true)`) where it finds `relrowsecurity`; `inject.py` | ten more `gm_check_read` rows in `pg_policies` beside `portal_sync`'s and `portal_dispatch`'s `USING (true)`, as `cron.job`'s today | T270, T271, T273, T274 edit or drop `portal_api`'s policies only, permissive policies adding up: unaffected. A dropped `gm_check_read` or a `RESTRICTIVE` policy for `public` blinds the checks (guarded below) |
| B. `BYPASSRLS` on `gm_check` | the `postgres` brick's entrypoint and docs, an image rebuild | `rolbypassrls` on a login role in `pg_roles` | T272's very shape ("granted `BYPASSRLS` for a support script"): a false alarm in the portal's audit, the clinic's richest governance case |
| C. `SECURITY DEFINER` functions or views owned by `portal` | per table, in the domain or a purpose's DDL; every check and the history rewritten to them | a `gm_check` schema of views or functions | droppable likewise; ties the GM's reads to one domain's owner role |
| D. The reads as `postgres` (the coherence check's way) | checks run on the database node by peer; the FDW mappings as `postgres` | sessions as `postgres` in the log | `postgres` has no `host` line: purpose 16's history (on the partners' node, `portal` over TCP) cannot read; the checks lose `check-runs`; W2 item 3 rewritten |

- **Settled: A (choice)**. Access model 8 keeps `gm_check`'s v0.4 reads,
  and v0.4's way for a table row security hides is this policy,
  chosen over `BYPASSRLS`; vet-portal already gives each purpose role
  a `USING (true)` policy, so the GM's sits among its kind; B is T272's
  witness, C and D change the checks' mechanism for no gain in what
  players can tamper with (access model 8 and 13: `dba` bypasses every
  rule and may drop any policy, accepted). Not the owner's: nothing a
  player sees or may do changes in kind, the role and its `cron.job`
  policy being in sight since v0.4. Reported to the owner as
  information.
- **The step**: step **(2c)**, after the purposes' DDL (2b) and before
  the derivations (so purpose 16's history reads `portal_outbox`): in
  every database a `domains:` entry's `at:` holds, as `postgres`,
  unseen, for every table (`relkind` `r` or `p`) outside `pg_catalog`,
  `information_schema` and `gm_src_*` with `relrowsecurity`: `DROP
  POLICY IF EXISTS gm_check_read`, `CREATE POLICY gm_check_read … AS
  PERMISSIVE FOR SELECT TO gm_check USING (true)`, and `COMMENT ON
  POLICY` "the game master's read access: DO NOT TAMPER". Recorded in
  `LoadResult`, printed as `<node>/<db>: gm_check may read every row of
  <n> table(s) with row security (policy gm_check_read)`. A database
  of a node's data file is the data file's to cover (none in v0.5).
- **The guard**, in every check reading a table with row security (RL,
  MS, s5's if it reads `portal`): first, from `pg_policies`, that
  `gm_check_read` is on each such table and no `RESTRICTIVE` policy
  names `public` or `gm_check` there; else exit 2, "cannot judge: the
  GM's read policy on <table> is gone", never a verdict on an empty
  read (as a dropped `gm_check` errs, `postgres`' GM notes).
- **Told to the players**: `postgres`' `docs/player.md` "Do not tamper"
  gains the role `gm_check` and its `gm_check_read` policies, the GM's
  reads (chunk 32).

**8. The tool support wave 4 needs** (chunk 32, proposed: Preflight
corrections, item 1; W4-f records; read by 18 to 21 and every fixture
after)

(a) `source_<w>` database parts and (b) `runner_<w>` runners, through
`model.py`'s purpose checks (`PURPOSE_PARTS`, `DATABASE_PARTS`, jobs'
`part`, `source`, `target`, `roles`, `trace`, `data_moved`, `ddl:`,
`_check_purposes`' mapping and its per-runner `jobs.yaml` check); (c)
`pg_cron` jobs on a database part, no `runner` needed (item 0);
(d) item 7's step (2c) and its tests (`inject.py`); the scenario-format
skill (`SKILL.md`'s purpose items, `templates/purpose.yaml`),
`game-master/gmctl.md`'s `load-data` lines and `postgres`' `docs/gm.md`
and `docs/player.md` follow. No image changes.

**9. Wave 4 coordination** (for the driver and chunks 17 to 21, 32)

- **Order**: chunk 17 and chunk 32 first (κ = 3), with one of 18 to 21;
  the others at the next free slots. Each starts at once; what waits
  for chunk 32's merge is only the format check and fixture of the
  purposes it serves: 18's purpose 6, 19's purpose 5, 20's purpose 9,
  21's purposes 14, 15 and 16 (`32 ──> 18, 19, 20, 21` in wave, those
  only). Chunk 17 takes `v0.5-w4` in after 32 has merged, before its own
  merge (`32 ──> 17`, merge order, spec D360's form).
- **Files**: `tools/gm/{model,render,localimpl}.py` chunk 17's,
  `model.py`'s purpose checks and `inject.py` chunk 32's (the shared
  `model.py`, `tools/tests/test_model.py` and the scenario-format
  `SKILL.md` under the merge order above); each purpose chunk holds its
  `purposes/<id>/` and its fixtures, chunk 21 the bookings, imaging and
  portal fixtures, chunk 18 the new `tools/tests/test_purposes.py`;
  `domains/vet-core/` chunk 19's alone, vet-machinery's and vet-portal's
  `data/cron.sql` chunk 17's. Shared lists: the root `README.md`'s
  purpose table, and (item 4) the composed fixtures' `left_out:` lines
  for vet-core's `partners/centres`.
- **Images**: `bastion` 0.5.0 rebuilt by chunk 17; no other.

**Choices made here, not in the spec** (for the driver's review): the
28 marked **(choice)** above, items 0 to 7, and chunk 32's scope (item
8).

### Preflight corrections for spec-writer

1. **The purposes' format and `gm_check`'s reads under row-level
   security have no chunk** (W4 items 0, 7, 8). Proposal: decisions
   for `source_<w>` and `runner_<w>` parts, `pg_cron` jobs on a database
   part, and step (2c) (O243 closed as W4 item 7, information to the
   owner); an inserted **chunk 32** in wave 4 for a `coding-executor`,
   Files `tools/gm/{model,inject}.py`, `tools/tests/{test_model,test_inject,test_coherence}.py`,
   `.claude/skills/scenario-format/{SKILL.md,templates/purpose.yaml}`,
   `.claude/skills/game-master/gmctl.md` (the `load-data` lines),
   `bricks/postgres/docs/{gm.md,player.md}`; Done when each acceptance
   and refusal shown by a unit test (a `source_lab` part with its `ddl:`
   and history source, a `runner_reports` with its own `jobs.yaml`, a
   `pg_cron` job with no runner, the refusals as for the base parts),
   and the composed test load showing `gm_check` reading a row of a
   forced row-security table through `gm_src_*` in a history, the
   policy and its comment present; split 32a (d), 32b (a) to (c);
   edges `29 ──> 32`, `32 ──> 17` (merge order), `32 ──> 18, 19, 20, 21`
   (in wave, the purposes of W4 item 9 only); a gate row like G17 for
   its format items (Preflight corrections, item 8). Wave 4 then holds
   six chunks, the model's maximum. Fallback: (a) to (c) in chunk 17,
   then `17 ──> 19, 20, 21`, which serialises the wave behind its
   largest chunk.
2. **Chunk 17's scope, Files and Done when** (W4 items 1, 2): scope
   gains the `cron.sql` database refusal and the two headers corrected,
   `third_parties[].credentials:` with `partners.md`'s placeholders and
   their loader checks, the `fixture-*` exemption from the register
   requirement; Files gain `domains/vet-machinery/data/cron.sql`,
   `domains/vet-portal/data/cron.sql` and
   `.claude/skills/scenario-format/templates/scenario.yaml`; Done when
   gains "a `cron.sql` job naming a database its entry's `at:` does not
   place refused, naming the file, the line and the database; a
   non-literal database refused by `check_domain_dir`"; the handed-over
   credential check reads "a placeholder in `partners.md` replaced by
   its value on the page and in `/home/player`".
3. **Chunk 19 adds a producer folder every composed fixture must name**
   (W4 item 4). Proposal: the plan's "Shared lists" gain the composed
   fixtures' `left_out:` lines for vet-core's `partners/centres`; chunk
   19's Files gain every composed fixture's `composition.yaml` (that
   line only), `domains/vet-core/docs/gm.md` (the centres' stub) and
   `tools/tests/test_compose.py`; its Done when gains "every composed
   fixture on `v0.5-w4` loads with the centres left out or composed";
   chunks 17, 18, 20 and 21 add the line to their new fixtures when they
   merge after 19. `fixture-exchanges` maps `runner_reports` to
   `interfaces` and carries `office.sql` in `records`' data file.
4. **One text for shared material** (W4 items 0, 5): chunk 18's Files
   gain `tools/tests/test_purposes.py` (new): every purpose's `-- ops:
   begin` to `-- ops: end` block byte-identical, every
   `material/target/office.sql` byte-identical (by glob, so later
   purposes are checked as they merge).
5. **D335 and the fixtures** (W4 item 1): record that the register
   requirement binds played scenarios, a scenario whose id starts
   `fixture-` exempt, a fixture with a register checked in full (master
   spec 13.2, 13.3; formats.md "Scenario").
6. **Chunk 20's roles line** (W4 item 5): "`office`'s DDL, its roles
   `office_jobs`, `office_reader`, `vet_reports`, `sched_reports`,
   `lab_reports`" reads "`office`'s DDL (`office`, `office_jobs`,
   `office_reader`), the reads as the domains' `vet_reports`,
   `sched_reports`, `lab_reports`": a data file creating a domain's role
   makes that domain's schema fail. Its fixture: eight nodes with `lab`
   and the partners' three (W4 item 5); its Files gain nothing else.
7. **Chunk 18's send-outs fixture** (W4 item 3): the bastion, `records`,
   `lab`, `lab-api`, `interfaces`, the partners' three nodes, `lis` left
   out; the orders fixture's `lab` preloading `pg_cron` in `lab`.
   Chunk 21's vault fixture gains `records` and leaves `equipment` out
   (six nodes), its portal fixture a `messaging` third party (W4 item
   6).
8. **formats.md and master spec after the build**: a gate row G18
   (`spec-writer`, after wave 4's gate, blocking release gate item 6):
   the purposes' parts and material layout, the `ops` block, the
   calendar-gated cadences (formats.md "Purpose definition"; master
   spec 6.6, 12.1), step (2c) ("Loading a composed domain"), the
   register's form, digests and the fixture exemption, the
   `credentials:` key and placeholders ("Scenario", "Partners"), the
   `cron.sql` refusal ("Domain"); master spec 5 and 6.
9. **Master spec 12.2's cadences** (W4 item 0): purposes 3, 7 to 10 and
   12 state their monthly, yearly and windowed jobs as daily or
   every-15-minute runs gated by the customer's date, so the text
   matches the cron subset.

### Questions for the owner

None. O243 is settled by the sources (W4 item 7: access model 8, v0.4's
read policy, T272); for the owner's information, the players will see a
`gm_check_read` policy on each of the portal's ten tables in
`pg_policies`, as on `cron.job` since v0.4, marked DO NOT TAMPER and
listed in the `postgres` player notes. Meanwhile nothing waits on the
owner: every wave-4 chunk can start, chunk 32 serving the six purposes
item 9 names.

### W4 reviewed by the driver, 2026-11-09

The 28 **(choice)** points taken as written; none needs the owner. O243
settled by item 7 as option A (a `gm_check_read` policy per table with
row security, v0.4's `cron.job` mechanism, `inject.policy_sql`,
checked in the code): not the owner's, since nothing a player sees or
may do changes in kind; reported to the owner as information. The nine
preflight corrections accepted and sent to `spec-writer` before any
chunk is cut: chunk 32 inserted for a `coding-executor` (item 8), with
the merge-order edge `32 ──> 17` on `model.py` and the partial edges
`32 ──> 18, 19, 20, 21` (format check and fixture of purposes 5, 6, 9,
14, 15, 16 only); wave 4 then holds six chunks, the model's maximum.

### Plan revision before the chunks, 2026-11-09

`spec-writer`: build plan v13 (98f9f30), spec D431 to D437:
- D431: chunk 32 inserted into wave 4 for a `coding-executor` (W4 item
  8: `source_<w>` and `runner_<w>` parts, `pg_cron` jobs on a database
  part, step (2c)), split 32a (2c) and 32b (the parts); edges `29 ──> 32`,
  `32 ──> 17` (merge order on `model.py`), `32 ──> 18, 19, 20, 21`
  (the format check and fixture of purposes 5, 6, 9, 14, 15, 16 only).
- D432: O243 closed as option A (W4 item 7): `gm_check_read` per table
  with row security, the checks' guard (exit 2), `postgres`' player
  notes. Information for the owner, not a ruling.
- D433: chunk 17's added scope: the `cron.sql` database refusal and the
  two headers corrected (W4 item 2), `third_parties[].credentials:` with
  `{{credential:<name>}}` placeholders in `partners.md` (W4 item 1).
- D434: D335's register requirement binds played scenarios only;
  `fixture-*` exempt, a fixture with a register checked in full.
- D435: wave 4's fixtures and shared material (corrections 3, 4, 6, 7):
  vet-core's centres' `left_out:` line a shared list added by chunk 19;
  chunk 18's `test_purposes.py`; `office`'s DDL creating `office`,
  `office_jobs`, `office_reader` only; the send-outs, vault, portal and
  reports fixtures' nodes.
- D436: monthly, yearly and windowed jobs run daily (or every 15
  minutes), acting on their own date or window in the customer's local
  time; master spec 12.2 reworded.
- D437: gate G18 (wave 4's format items into formats.md and master spec
  5 and 6), `spec-writer`'s after wave 4's gate, blocking release gate
  item 6.
Also: chunk 25 depends on 32 (its O243 note); chunk 27's `partners.md`
line names the placeholders. `doc-ids lint spec`: 0 errors. D429, D430,
O244 and O245 found reserved and unused, so recorded. No owner question.
Wave 4 holds six chunks, the model's maximum. No documentalist peek for
chunk 32 (no intent register); W4 is its capture.

### Chunks 32, 17, 19 dispatched, 2026-11-09

At the commit holding this entry: chunk 32 (`coding-executor`, 32a then
32b), chunks 17 and 19 (`coding-leader`). Chunk 19 first among 18 to 21:
its vet-core centres' `left_out:` line is the shared list the other
fixtures take in when they merge after it.

### Chunk 32 — merged (2b200c0), 2026-11-09

`coding-executor`: 32a `70086b4`, 32b `c9061eb`, merged `--no-ff` at
`2b200c0`, no conflict. Unit suite 1170 OK, 2 skipped (1151 before);
`GM_TEST_COMPOSED_LOAD=1` 2 OK (22.5 s, the load 13.3 s): `gm_check_read`
on fx-intake's `stays` (row security forced for the test), PERMISSIVE,
SELECT, TO `gm_check`, `USING (true)`, its comment; the history read all
six stays through `gm_src_source`; `gm_check` reads 6 rows, 0 after the
policy is dropped. py_compile and the templates (PyYAML, `strict_load`)
clean. No dependency added, no image touched.

**W4-f, as built** (read by 17 to 21, 25, 27):
- Step (2c), `tools/gm/inject.py`: `ComposedPlan.read_policies` lists
  every database a `domains:` entry's `at:` holds, once each, in order;
  `read_policy_sql()` runs as `postgres`, unseen, in one transaction,
  on every table `relkind` r/p with `relrowsecurity` outside
  `pg_catalog`, `information_schema` and `^gm_src_`; after the (2b)
  loop, before `gm_check`'s role settings and the derivations.
  `LoadResult.read_policies` is `[(node, db, n)]`, one line printed per
  database, 0 included. Constants `CHECK_POLICY` (`gm_check_read`) and
  `READ_POLICY_COMMENT`. (choice) runs on every held database without
  checking for `gm_check` (every `postgres` node has it).
- Parts, `tools/gm/model.py`: `EXTRA_PART_RE`
  `^(source|runner)_([a-z][a-z0-9]*)$`, `base_part()`,
  `is_database_part()`, `is_runner_part()`, `PG_CRON_METHOD`,
  `RUNNER_PART`; `PART_TABLE_RE` accepts `source_<w>:`. Each runner part
  is checked for its own jobs only; a job with no `part` is `runner`'s
  (v0.4); a runner running none of the purpose's jobs needs no
  `jobs.yaml`. (choice) a `pg_cron` job's part needs its own
  `ddl.<part>`; a `pg_cron` job naming a runner is refused, and only a
  `pg_cron` job may name a database part; a runner declared beside
  all-`pg_cron` jobs is refused; `jobs[].source` and `target` stay
  single-valued, any declared database part.
- History sources (`inject.composed_plan`): the entry's database parts
  other than `target` (`model.is_database_part`), each as
  `gm_src_<part>`.
- Templates: `purpose.yaml`'s `parts.runner` optional, placeholders
  `<source_lab>`, `<runner_reports>`, `ddl:` keyed `<target>:`;
  `scenario.yaml`'s `purposes[].parts.runner` optional.
- Deviations (none against the spec): `templates/scenario.yaml` outside
  the Files list (needed for (c); chunk 17 edits another section of it);
  `fixture-composed`'s fx-intake DDL and README; v0.4's `policy_sql` on
  the cron tables unchanged (no comment; none of v0.5's domain databases
  holds `pg_cron`). The checks' guard (exit 2) is documented in
  `postgres`' `docs/gm.md` and written by chunks 18 to 21. G18 carries
  the parts and (2c).

Chunk 18 takes the slot. Chunks 17 and 19 told nothing new: their
briefs already wait on this merge.

### Chunk 19 — stopped on loader gaps (WIP ce468eb), 2026-11-09

The owner stopped at WIP `ce468eb` on `v0.5-c19-exchanges` (worktree
kept), on five gaps and a heavy context (about 125 tool calls). Both
purposes fail `test_catalog_purposes_are_complete`, so not merged.
Built so far: the centres' stub (`domains/vet-core/producers/partners/centres/`),
the two purposes' `purpose.yaml`, material and DDL (run clean in a
throwaway `postgres:0.5.0`, the planted rows matching the clinic's),
`office.sql` per W4 item 5, the authority stub's shared block, the
centres' `left_out:` line in the seven composed fixtures (`test_model`,
`test_partners`, `test_inject`, `test_compose` pass). Not built: the ten
checks, the two `gm.md`, `fixture-exchanges`.

The gaps:
1. `model.INVARIANT_ID_RE` (`^[A-Z][0-9]+$`) refuses the spec's
   two-letter ids (EX1, ND1, and every clinic purpose's: LO, PR, SO, CC,
   MR, ...): chunks 18, 20 and 21 meet it too. Loader.
2. `_check_endpoint_material` refuses `api.yaml` in
   `material/api/<node>/`, which W4 item 0's table places there; purpose
   4 needs it (the `exchanges` endpoint's `clinic_centres` credential,
   the `clinic-exchanges` connection as `vet_exchange`). Loader or W4.
3. Spec: purpose 4 carries two round trips (master spec 12.1), each
   naming exactly one end-to-end invariant, but 12.2 gives it one (EX5;
   EX2 is "triggers").
4. `data_moved.reads` keys must match `CLASSIFICATION_KEY_RE` (three
   parts), refusing an `ops` column (`clinic.ops.notifications.payload`,
   purpose 5's copy). Loader.
5. Spec: clinic-purposes' roles table lists for `vet_interfaces` only
   `animals (id, species, status, died at)` and no `owners`, while
   purpose 4's data moved and EX4, and purpose 5's keeper, need more;
   the owner granted the column-level minimum in the two DDL files.
Sent to `spec-writer` (decisions, an inserted loader chunk, the spec's
two corrections), with a sweep of every wave-4 purpose for the same
class of loader gap so one inserted chunk covers them. Chunk 19 resumes
from `ce468eb` with a fresh owner once settled. Its as-built so far
(for W4-c): connection names `clinic` (`vet_interfaces`, pool 2) and
`lab-dispatch`, which chunk 18 must use identically; `office.sql` the
reference text chunk 20 matches byte for byte; the authority's shared
block, byte-identical in purpose 8.

Chunk 21 takes the free slot (2026-11-09), its brief noting the loader gaps being settled (its format check and fixtures wait for them, its material does not).

### Chunk 17 — merged (46bd5c1), 2026-11-09

`coding-leader`: 17a `041d59a`, v0.5-w4 taken in `a30eee1` (chunk 32),
17b `cd6b8d1`, merged `--no-ff` at `46bd5c1`, no conflict. Unit suite
1211 OK, 2 skipped (198 s); bastion 0.5.0 built and its stack test 114
PASS, 0 FAIL; `check_domain_dir` clean on vet-machinery and vet-portal;
py_compile, `sh -n` (no shellcheck installed), `perl -c`, YAML clean. No
package added (G11 not needed).

Done when: both seed files on the page when present and absent
otherwise; `/cold-storage/` and `/cold-storage/manifests` forwarded (Host
`cold-storage`, query kept, Authorization stripped), `POST /shipments`,
other methods and paths, `/northfield-lab/`, `/partners-api/` 404 never
forwarded; the loader accepting the console route, refusing another
port, a cold storage without `coldstore_manifests`, another partner's
hostname and a third party's node; `public/` `data.sql` refused; a
`{{credential:demo_customer}}` filled in `~/partners.md` and the page,
accepted by the stub partner (200; a wrong value 401), the start refused
with the secret unmounted; `cold_storage` never mounted on the bastion;
the `cron.sql` refusal through `load_scenario` (and a non-literal
database by `check_domain_dir`); `fixture-*` exempt, the same fixture
renamed refused; fixture-register: 20 entries, 9 internal lines, 6
locations, a 226-line handout, a stale digest refused (four ways), a
declared absence passed, six coverage refusals shown.

**W4-a, as built** (read by 23, 26, 27):
- Console route `web_routes: {cold-storage: "cold-storage:8000"}`,
  accepted when the target is a hostname an api node's
  `coldstore_manifests` endpoint answers under (`HttpContext.consoles`),
  port 8000; render's token `name=host:port:console`
  (`render.CONSOLE_SUFFIX`, `web_routes_value(routes, nodes)`). (choice)
  nginx `location = /<name>/` and `= /<name>/manifests` with
  `limit_except GET { deny all; }`, `error_page 403 =404`, the prefix
  denied (404); Host the partner's hostname, Authorization stripped.
- Credentials: `model.handed_over_credentials(data)`,
  `model.partners_placeholders(text)`, `CREDENTIAL_PLACEHOLDER_RE`;
  localimpl gives the bastion (role `bastion`) them in
  `node_credentials`, each `http_<name>` declared `handed_over: true`
  (16 characters); the entrypoint writes `/run/gm/starter/partners.md`
  (root, 0700), the source of the home copy and the page; a missing
  secret stops the start (`partners.md: {{credential:<n>}}: no secret …`).
- `gm/data-register.yaml`: `generated_from`, `controller`, `contact`,
  `policy`, `entries` (id, department, name, purpose, people,
  data{personal, customer-linked}, where[{at, tables} | {copy}],
  shared_with[{recipient, fields, flow?, processor?, outside_eu?}],
  kept_for{period, then}), `internal` (id, department, name, where,
  kept_for), `index` (location → ids). Helpers `model.register_inputs`,
  `model.file_digest`, `model.register_absent`, `REGISTER_FIELDS`,
  `FIXTURE_PREFIX`; the stale message "stale register: regenerate with
  the data-register skill". (choice) A register fault whose
  `seed_changes` name `data-register.md` is accepted unmapped when
  `governance.register` exists, `_check_data_register` then requiring
  the answer key's `{absent: true}` (T305).
- `model.cron_jobs(text)` → `(line, job, database literal | None, as written)`.
- Deviations (none against the spec or W4): a skill rule that a view
  joins the activity its classified column comes from (`animal_board`,
  `housing_unit_board`); scenario-document's SKILL.md line on cron jobs
  "renamed as at: maps it" corrected to W4 item 2; the fixture's handout
  226 lines against the spec's "about 150" for the clinic (chunk 27's
  to weigh); the fixture's register generated by an uncommitted scratch
  script applying the skill's rules ("gmctl gains no generator").
- Open: fixture-register needs vet-core's centres' `left_out:` line
  when chunk 19 merges (shared list). Risks: the handed-over credentials
  proven against a stub partner, not the `api` brick (chunk 27 first end
  to end); **the bastion has no `curl`**: players hold partner
  credentials with no convenient HTTP client on the bastion (bash's
  `/dev/tcp` only), against access model 4's "HTTP clients" on the
  bastion: a fix on the wave branch, Debian `curl` added to `bastion`
  0.5.0 after a G11.2 preflight (below).

### Plan revision: chunk 19's gaps settled; chunk 33 inserted, 2026-11-09

`spec-writer`: build plan v14 (34d8620), spec D438 to D441, every gap
confirmed in the code and the spec:
- D438: chunk 33 inserted into wave 4 for a `coding-executor`, cut from
  `v0.5-w4` after 17 and 32 (`17, 32 ──> 33`; `33 ──> 18, 19, 20, 21`
  for their format checks): (a) invariant ids `^[A-Z]{1,2}[0-9]+$`; (b)
  `data_moved.reads` in the scenario's key form (three or four parts);
  (c) HTTP connections `<part>_<w>` (`^(api|partner|receiver)(_[a-z][a-z0-9]*)?$`),
  each checked as its base part, so D354's credential check runs on
  them (they were skipped, not refused); (d) `material/api/<node>/api.yaml`
  accepted (W4 item 0's table right; compose and localimpl already read
  it), its endpoints matching `routes/` exactly. Master spec 12.1 items
  3 and 4.
- D439: chunk 33's place in the wave (seven chunks, one past the
  model's six: a fix-sized gap every purpose of 18 to 21 fails without;
  the chain 32/17, 33, 18–21 three long, kept on D402's reasoning).
- D440: purpose 4's inbound round trip judged end to end by EX2,
  reworded from the centre's side ("each request recorded at once, its
  answer and report posted within 10 minutes of the vets'"); EX5 the
  outbound's; EX2 added to T54 in `clinic-traps.md`. Information for the
  owner: nothing players see or may do changes.
- D441: the roles table ("The roles the purposes add") matched to chunk
  19's DDL: `vet_interfaces`' and `vet_exchange`'s column reads and
  writes, `vet_reports` and `lab_reports` on `ops.notifications`, a
  shared role holding the union of its purposes' columns, `ops.*` as
  W4's grants; `mach_archive`'s `SELECT` on the two settings tables
  (chunk 21, purpose 14) added.
The sweep found nothing else of the kind across purposes 1 to 16. G18
gains D438's and D440's items. No owner question.

### Chunk 33 dispatched, 2026-11-09

`coding-executor`, cut from `v0.5-w4` at the commit holding this entry,
taking chunk 19's slot (κ: 18, 21, 33). Chunk 19 resumes from `ce468eb`
with a fresh owner once 33 has merged; chunk 20 at the next free slot.

### G11.2 — dependency preflight on `curl` in `bastion` 0.5.0 (security-advisor, 2026-11-09)

Asked by the driver after chunk 17's report (the bastion has no HTTP
client, against access model 4's "HTTP clients"; players now hold
partner credentials, D365). **Verdict: NEEDS-HUMAN-DECISION**, the
advisor recommending acceptance:
- Version: Debian trixie `curl`/`libcurl4t64` 8.14.1-2+deb13u7
  (trixie-security's latest), the same build, and the same 13 pulled-in
  packages, as in `api`, `grafana`, `health-check`, `pgwatch`,
  `scheduler` (checked with `dpkg-query`), `prometheus` and
  `postgres-exporter`. New to the bastion: libbrotli1, libidn2-0,
  libnghttp2-14, libnghttp3-9, libpsl5t64, librtmp1, libssh2-1t64,
  libgnutls30t64, libtasn1-6, libp11-kit0, libffi8, libunistring5.
- Findings at or above medium with no fix in trixie: curl 39 advisories
  (Debian: 32 "no DSA", 7 unimportant; curl's own ratings Low but three
  Medium — Negotiate reuse, unused; cross-origin Digest state; a proxy
  password, no proxy used; the one High already fixed in deb13u7);
  rtmpdump 2 (only an `rtmp://` URL), gnutls28 4 and p11-kit 2 (loaded
  by librtmp only), nghttp2 1 (nghttpx, unreachable).
- Why accepting is proportionate: an interactive client run by the
  unprivileged `player`, no listener; the bugs need a hostile server the
  player chooses; the worst outcome (code as `player`, a credential
  leaked to a host the player picked) gives nothing the player lacks.
  Alternatives worse: trixie-backports 8.21 (no security support, half
  the batch), `wget` (2 high unfixed).
- Coverage gap noted: the seven other images' curl was never checked;
  `.tech` has no curl `[[platform]]`. At wave 4's post-change check the
  advisor proposes adding one (all eight images), after which a sweep
  opens about 30 curl items needing one triage pass or the owner's
  `[[ignore]]`.

**For the owner** (gate G11.2): accept shipping curl 8.14.1-2+deb13u7
in `bastion` 0.5.0, and by extension the seven images already carrying
it, with these trixie-unfixed issues (record: reason as above,
approved by the owner, until 2027-02-01 or the next trixie curl security
upload)? The driver recommends **accept**: refused, the bastion keeps no
HTTP client until Debian 14, against access model 4 and chunk 17's
handed-over credentials. Until the answer, the fix (curl in the
bastion's Dockerfile, its stack test calling the partner with `curl`,
`docs/player.md`) is held; nothing else in the wave waits on it.

### Chunk 33 — merged (c92bd13), 2026-11-09

`coding-executor`: `120d1c3`, merged `--no-ff` at `c92bd13`, no
conflict. Unit suite 1216 OK, 2 skipped (209 s; 1211 before);
py_compile and the template (PyYAML, `strict_load`) clean. Chunk 19's
two purposes at `ce468eb`, checked by hand in a scratch catalogue: only
the missing `gm.md` and checks remain, and purpose 4's "1 judged
end-to-end (EX5) for 2 round trip(s)" (D440, chunk 19's).

**W4-g, as built** (read by 18 to 21 and every purpose after):
- `INVARIANT_ID_RE` `^[A-Z]{1,2}[0-9]+$`.
- `data_moved[].reads` checked with `SCENARIO_CLASSIFICATION_KEY_RE`
  (three or four parts); `CLASSIFICATION_KEY_RE` removed.
- `HTTP_CONNECTION_RE` `^(api|partner|receiver)(_[a-z][a-z0-9]*)?$`
  (from `HTTP_PARTS`), `model.http_part(name)` giving the base part;
  `_check_purpose_v05` and `_check_purpose_http` check a `<part>_<w>`
  exactly where the bare name is (its part declared, its credential,
  an http connection in the scenario calling with that credential).
  Risk: a database connection named `api_*`, `partner_*` or
  `receiver_*` now reads as HTTP (none exists).
- `material/api/<node>/api.yaml` optional, `strict_load`, keys within
  `API_YAML_KEYS`, then `_check_api_fragment`; its endpoints and
  `routes/` stems match exactly; anything else "not endpoint material
  (api.yaml, routes/, db/)". Not checked against the topology (the
  scenario's, once compose merges it).
- The scenario-format skill's items and `templates/purpose.yaml`
  follow. G18 carries the four forms.

Chunk 19 resumes from `ce468eb` with a fresh owner, taking `v0.5-w4` in
first (κ: 18, 21, 19); chunk 20 at the next free slot.

### Chunk 21 — paused on context (WIP c05e079), 2026-11-09

The first owner paused at about 180k tokens (WIP `c05e079` on
`v0.5-c21-parts-flows`, worktree kept); nothing merged. Built: purpose
11 complete (`vet-bookings-sync`: DDL, runner material and script
`bookings_sync.py`, BS1–BS5, `gm.md`; its format check failed then only
on the two-letter ids, since fixed by chunk 33); purpose 13's DDLs,
runner material and `imaging_orders.py` (no `purpose.yaml`, checks or
`gm.md` yet). Not started: purpose 14, the bookings, imaging and vault
fixtures, all of 21b. Its DDL test in a throwaway `postgres:0.5.0` was
queued behind the host lock and not seen: the next owner reruns it.

Four grants beyond D441's roles table, each minimal, reported (the
class of chunk 19's gap 5): `sched_interfaces` `SELECT` on
`sched_courses` and `sched_rooms` (`sched_free_slots` runs with the
caller's rights) and `UPDATE (released_at)` on `sched_allocations` (the
release trigger runs as its invoker); `vet_interfaces` `SELECT (id,
booking_id, section_id)` on `consultations` and `SELECT` on
`business_settings` (purpose 13's working days); `mach_orders` `SELECT
(id, code)` on `mach_procedures` and the join ids of `mach_worklist`,
`mach_studies`, `mach_reports`. Sent to `spec-writer` with the owner's
reading of the vault fixture (the test lowers `window_days` to 0 so a
shipped day exists at T0, the job reading the window from the settings,
D418) to confirm. The chunk resumes with a fresh owner at once (21a
first; the halves stay in order).

### Chunk 21's grants recorded (D442), 2026-11-09

`spec-writer` (96e6b00): the four grants confirmed against the schemas
(`sched_free_slots` and `sched_release_allocations()` run with the
caller's rights; `mach_worklist.procedure_id` NOT NULL) and added to the
roles table, master spec 9.4 and 9.6, the scheduling and machinery
documents; `mach_orders` on `mach_reports` narrowed to the columns read.
The vault reading confirmed: the load keeps the last full day and today,
so the test sets `window_days` to 0 in both settings tables and
yesterday ships; the planted manifests stop before it (no shipment-id
clash). Chunk 21's text reworded to say so. Nothing changes what the
resumed owner builds; nothing for the owner.

### Chunk 21 — second owner paused (WIP 02450a2), 2026-11-09

The second owner paused on context: `444aba1` (v0.5-w4 taken in),
`02450a2` (WIP: purposes 13 and 14, the root README's row). Purposes
11, 13 and 14 pass `check_purpose_dir`; the DDL test (core and
scheduling with purpose 11's DDL twice, pacs with 13's, vitals and
biomed with 14's twice) exits 0, every role's reads and writes shown
(`mach_archive` dropping a partition through `mach_drop_shipped`).
Not yet run on a load: the three scripts, purpose 14's history, any
check. Its `coding-executor`, extending `fixture-bookings` with purpose
11 and running its short test, was still running in the chunk's
worktree (uncommitted) when the owner reported; the third owner starts
once it has finished, reads and verifies its edits, then the imaging
and vault fixtures, the unit suite, the 21a commit; 21b after.

**W4-e so far** (purposes 13 and 14; purpose 11 in the first pause's
entry): purpose 13 `imaging.post` every minute, `imaging.fetch` every 5
(`urgent_hours: 18`, `routine_working_days: 3`), watermarks `finals`,
`cancellations`, `ops.imaging_results` its `published-results`,
incidents `overdue`; IO1–IO4 on `interfaces` by `check-sql`; (choices)
IO1 dates the close as the later of `ended_at` and `requested_at`, IO3
from the entry's first final, IO4 a routine turnaround ending with the
third working day in `business_settings.timezone`. Purpose 14: one job
`ship-partitions`, key `archive.ship`, `40 0-5 * * *`, options `source:
machines`, `last_hour: 5`; the job declared `source: source`, `target:
source_biomed` (single-valued); `roles:` lists `mach_archive` once per
database part; `ops.shipments` (type, day, shipment_id, rows_sent,
rows_received, attempts, posted_at, receipt_at, dropped_at, run_id), key
(type, day), in both databases; shipment ids `<type>-<YYYYMMDD>`, types
`vitals`, `machine-readings`; (choices) rows read through the parent
between the day's bounds at the settings' offset (no grant on a
partition); the readings' aggregate per machine, each numeric channel's
min, max, mean to two places, committed before the POST; one closing
transaction per database (run row, upserts, drops, `unshipped`
incidents), a run row even on a no-op; the history plants vitals
manifests from the first session's day (10-second ticks within
sessions) and readings manifests from the `mach_readings_daily` days,
received 00:40 the night after the window, the source from the foreign
server's `host`, sizes estimated (170 and 130 bytes a row); CA1–CA4
POSIX sh on partners-db by `check-psql` (`--node machines`); CA4 reads
`window_days` live. Known flaw: the checks' `remaining=` counts to the
next 40-past run between 00:00 and 05:00, wrong once the job is moved.

### Chunk 18 — 18a built, paused before 18b (90d9b84), 2026-11-09

The first owner paused on context after 18a: `3057e11` (its own widening
of `INVARIANT_ID_RE`, made before chunk 33 merged: superseded by
`c92bd13`, to be reverted by the next owner) and `90d9b84` (18a:
purposes 1 and 6, `fixture-orders`, `tools/tests/test_purposes.py`, the
root README's row), cut from `v0.5-w4` at 061af83; not merged. Unit
suite 1179 OK, 2 skipped. `fixture-orders` (`fit` 1.5 CPU, 1440M of
2 CPU / 4G): second run 30 PASS, 0 FAIL in 1225 s (deploy 14 s,
load-data 194 s); the first (23/7, 1555 s) found a precedence error in
fetch's watermark SQL and CC1/CC2 written in Python on a node with
none (now shell and SQL). Both urgent requests sent 57 s after the
consultation closed and `resulted` 294 s after the release; LO1–LO4,
CC1, CC2 exit 0; the critical-call watch wrote one incident for the
placed unread result, still one after two runs. `test_purposes.py`
holds every `-- ops:` block and `office.sql` copy byte-identical.

**W4-b so far**: each purpose's DDL `material/target/ddl.sql` (`ddl:
{target: ...}`), runner material in `material/runner/`, copied by a
fixture into `compose/interfaces/` (`gmctl compose` writes
`nodes/interfaces/`). Purpose 1: script connections `source` (clinic,
`vet_interfaces`) and `api` (lab-api, `lab_centre`), in the schedule
`clinic` and `lab-api` (10 s); keys `lab-orders.post`, `.fetch`
(`scripts/lab_orders.py`); `ops.lab_orders_sent` (PK `client_ref`,
`request_ids int[]`), `ops.request_results` (PK `request_id`);
watermark `('vet-lab-centre-orders', 'lab-results')` at `load_epoch`,
15-minute margin; incidents `overdue`, ref the request; column-level
grants (the withdrawal end read through `administrations`,
`prescriptions` not in the roles table). (choice) A run writes its
domain rows, then its `ops.runs` row with final counts, then the rows
referencing it (no UPDATE on `ops.runs`); every run writes one. Purpose
6: job `watch-critical-calls`, (choice) its `key` the pg_cron jobname
`lab-critical-calls` (W4 item 3); incidents `uncalled`, ref the result;
`lab_watch` with W4's grants on the three ops tables; the lab node
preloads pg_cron (`cron.database_name='lab'`, background workers,
`cron.timezone`, `cron.log_run`); (choice) CC checks on the lab node by
`check-psql`, runs from `cron.job_run_details`, CC2 present after two
cadences with no successful watch. `fixture-orders`: `left_out` vet-lab's
`partners/xlab`, `partners/practices`; T0 about 10:00 local, a weekday
only when the host's day is one. **Every database-node check is shell
and SQL** (no Python in `postgres`).

Points: the scenario-document template has no row for a pg_cron job a
purpose's DDL schedules (listed in the node's jobs table by analogy;
for G18). Risk, for chunk 22 (s1) and the gate: `lis`' analysers did
not release the urgent order within 5–10 minutes at intensity 4 in
either run; the test released it itself "as lis would"; LO4 judges only
completed orders (a routine one cannot complete in a session). 18b
(purposes 2 and 3, `fixture-send-outs`) goes to a fresh owner now.

### Driver handover, 2026-11-09

The driver's session closes mid-wave. State for the next driver:
- **Merged into `v0.5-w4`**: 32 (`2b200c0`, W4-f), 17 (`46bd5c1`, W4-a),
  33 (`c92bd13`, W4-g).
- **Running when the driver left** (each `coding-leader` in its own
  worktree; their reports did not reach this driver): 18b (fresh owner,
  branch `v0.5-c18-lab-round-trips`, last `cf72cbd`: 3057e11 reverted
  and `v0.5-w4` taken in, 18a `90d9b84` verified); 19 (second owner,
  `v0.5-c19-exchanges`, last WIP `3a1747e`: checks, `gm.md`, EX2 end to
  end, `fixture-exchanges`, fixture-register's centres line); 21 (third
  owner, `v0.5-c21-parts-flows`, last `02450a2`, the bookings fixture's
  uncommitted edits being verified). Before acting, check each branch's
  log and whether it merged into `v0.5-w4`; a branch with no new commit
  and no live owner is resumed from its last commit with a fresh owner
  and the brief in the session scratchpad's `brief-18r.md`,
  `brief-19r.md`, `brief-21r2.md` (or rebuilt from the plan and these
  entries).
- **Not started**: chunk 20 (next free slot; its `office.sql` must match
  chunk 19's byte for byte, `test_purposes.py` enforcing it; the
  authority's shared block from purpose 5 likewise in purpose 8).
- **Open for the owner**: G11.2, curl in `bastion` 0.5.0 (entry above;
  recommended: accept). The fix is held until then.
- **For the gate**: the full quality command (workflow deltas) and wave
  4's row; G11.2's post-change check (and the advisor's proposed curl
  `[[platform]]` in `.tech`); then G18 by `spec-writer` (W4's format
  items, D438, D440, and the scenario-document row for a purpose's
  pg_cron job). No wave sync (no intent register).

### Driver resumed; chunks 18, 19, 21 resumed with fresh owners, 2026-11-09

A fresh driver took the wave at `9d74de5`. No chunk branch had a new
commit or a live owner; each worktree held uncommitted work (18b's
purposes 2 and 3 and `fixture-send-outs`; 19's exchanges short test;
21's bookings, imaging and vault fixtures and the CA checks' fix). The
stopped owners' background runs were still alive on the host lock (21's
bookings run running, its imaging run, 19's exchanges run and 18b's DDL
test queued); left to finish, their logs handed to the new owners as
first evidence. Fresh `coding-leader`s resume 18 (18b), 19 and 21 (21a,
then 21b), each from its brief plus a resume note (scratchpad
`brief-18r.md`, `brief-19r.md`, `brief-21r2.md`, `resume-*.md`): review
and commit the uncommitted state as WIP if sound, then continue. Chunk
20 starts at the first free slot once chunk 19 has merged (its
`office.sql` and the authority's block are 20's byte-for-byte
reference); its brief is `brief-20.md`. G11.2 still with the owner.

### Third driver resumed after the rate-limit kill, 2026-11-09 22:05

The second driver and its fresh owners (18, 19, 21) were killed by an
account rate limit at about 21:00, with no handover. State found: 18 at
WIP `b653cf4` (18b, clean; its SQL check passed, its first send-outs run
30 PASS / 2 FAIL); 19 at WIP `e2d45f4` with its first fixture-exchanges
run live on the host lock (21:37, stack `fixture-ex-mm7knz`); 21 at WIP
`e875634` plus three uncommitted check edits (bs5, io1, io2; imaging
64/66). Cross-chunk finding: the bricks' `check-sql` prints values with
Python `str()`, so booleans are `True`/`False`, never `t`; checks parsing
`== "t"` (18's so1 and pr1, 21's bs5 and io2) were wrong. To save the
account's rate, at most two chunk owners run at once: fresh owners now
for 18 and 19 (resume notes `resume-18c.md`, `resume-19c.md`), 21 and 20
next as slots free. Host-lock windows are reserved per hour in the
scratchpad's `lock-slots.md` (19 at :37, 18 at :40 collide). G11.2 still
with the owner.

### Driver handover (third driver), 2026-11-09 22:22

The third driver's run is ending early (its session was told to hand
back). Nothing merged since `211c898`. Two chunk owners it started at
22:05 are still LIVE, each waiting on its own fixture run; their reports
will not reach this driver, so the next driver checks the branches and
the scratchpad, and does not start a second owner on 18 or 19 while
these are alive (`pgrep -af run-short-test`, `docker stack ls`, the
reservations in the scratchpad's `lock-slots.md`):
- **18** (`v0.5-c18-lab-round-trips`, WIP `dda2396`: check-sql booleans
  and the grants' expected text fixed): its send-outs launcher holds the
  22:40 slot. Note `resume-18c.md`.
- **19** (`v0.5-c19-exchanges`, WIP `4565516`: the test now answers the
  centre's own request, no wait ends the run): run1 ended exit 1 in
  1703 s, stack removed; its rerun holds the 23:37 slot. Note
  `resume-19c.md`.
- **21** (`v0.5-c21-parts-flows`, WIP `e875634` + three uncommitted
  check edits): no owner. Ready to start when a slot frees, with
  `brief-21r2.md` + `resume-21c.md` (keep the bs5/io2 `True` fixes;
  revert the io1 judged-set change, a spec departure; fix the plant).
- **20**: not started; `brief-20.md` is current with plan v14; start
  after 19 merges.
- Rate rule from the owner: at most two chunk owners at once.
- G11.2 still with the owner. The gate, G18 and the report to the owner
  as in the second driver's handover above.

### Driver resumed from the top-level session, 2026-11-09 22:25

Background drivers kept ending mid-wave with their chunk owners' reports
orphaned (they come back to the top-level session), so the owner's own
session drives the rest of wave 4 itself, as the wave-execution skill
intends. Chunk owners 18 (WIP `dda2396`) and 19 (WIP `4565516`) are still
live, waiting on their fixture runs (slots 22:40 and 23:37 in
`lock-slots.md`). Chunk 21: fresh owner dispatched now with
`brief-21r2.md` + `resume-21c.md`. Chunk 20 waits for 19's merge. At
most two owners actively working at once (owner's rate rule); owners
idling on a launcher don't count.

### Chunk 18 merged, 2026-11-09 23:10

Merge `c7f6dc9` (18a `90d9b84`, 18b `d3ffb53`). fixture-send-outs run 2:
32 PASS, 0 FAIL, 1426 s (slot 22:40-23:04); fixture-orders not rerun
(only the `clinic` pool 1→2, unused by script jobs). Unit suite 1224 OK.
Root cause of run 1's failures, shared with chunk 21: the bricks'
`check-sql` prints booleans as `True`/`False` (Python `str()`); checks
compare to `"True"`, the existing convention. For G18 / spec-writer: the
extra grant `SELECT (utc_offset_hours) ON lab_settings TO lab_dispatch`;
the interpretations PR1 per delivery made due, PR3 by posting time, SO1
on tests whose 16:00 run falls after the judged moment, SO4 strict
release round; risk SO3 cannot see an extra payload key (stub drops
unknown fields). Chunk 19 adds the centres `left_out:` line to
fixture-orders and fixture-send-outs when it merges (D435).

### Chunk 21a merged, 2026-11-09 23:45

Merge `702bd40` (21a `ecaff1a`; v0.5-w4 taken in at `e0e9edd`, root
README's purpose table resolved as a shared list). Fixtures: bookings
54/54 in 1202 s, imaging 67/67 in 1518 s (IO1 as specified; the test now
plants on an open consultation and closes it after T0; IO2's failure was
check-sql's `True`), vault 48/48 in 327 s. Unit suite 1224 OK. Worktree
kept for 21b; fresh owner dispatched with `resume-21d.md`.
For G18 / spec-writer: vault's T0 lands at 21:MM local (test asserts
"before the 22:00 partition jobs"); partners-db has no gm_check pg_hba
line (D383); CA checks' exit-3 cadence path never ran; the vault fixture
follows the chunk text (no `equipment`), unlike vet-machinery-domain.md's
Testing table.
Driver ruling (format skill, not a spec change): a fixture whose third
party has a `player_doc` maps `partners.md` on its bastion. 21b fixes
fixture-portal (its README lists the page as shipped); fixture-vault and
fixture-restore go on the wave gate's fix list.
Chunk 19 adds the centres `left_out:` line to fixture-bookings, -imaging
and -vault too when it merges.

### Chunk 21b paused, 2026-11-10 00:55

21b owner paused on context at WIP `465c97a` (purposes 15, 16, the
messaging stub, twelve RL/MS checks, fixture-portal extended; format
checks clean, unit 1224 OK, DDL/scripts checked in a throwaway postgres).
fixture-portal run 1 (00:40-00:52) passed load-data (613 s) and died
after T0 on a test-script heredoc bug, fixed, not rerun. Fresh owner
dispatched; rerun booked 02:38-03:15 (`resume-21e.md`). Chunk 19's run 3
holds 01:37-02:15 (EX1-EX4 rewritten in shell+SQL, WIP `7ee565c`).
For G18 / spec-writer (21b): extra grants (`vet_portal_sync`:
`animals.registered_at`, `consultations.state`, `sections (id, kind)`;
`lab_release`: `lab_samples (id, collected_at)`; `portal_dispatch`:
accounts `(id, owner_id, display_name)`); send-messages "stops" rows
whose consent/owner/animal/account changed (failed_at + reason, no
incident), unspecified in the spec; RL2, RL3, RL5, MS5 judge a satisfied
trigger at once; the lab's two third parties list `nodes: []` in
fixture-portal; the W4-e build choices in the 21b report (stub id, 503
cadence, `messaging.message_calls`, watermarks). Risk: the portal run
sits at the 30-min limit.

### Chunk 19 merged, 2026-11-10 02:10

Merge `c9abb0e` (19 `6ae6fa7`). fixture-exchanges run 3 (01:37): 42 PASS,
0 FAIL, 1480 s; EX1-EX5, ND1-ND5 exit 0 unfaulted. Run 2 had failed only
on EX1-EX4 (`python3: not found` on partners-db): rewritten in shell with
the verdict in SQL, verdicts identical on the loaded data. Unit suite
1226 OK. Centres `left_out:` now in every composed fixture but
fixture-exchanges (which composes them); seven READMEs' "left out" phrase
edited in place (scenario files unchanged). For G18 / spec-writer: ND3
(surname + keeper.account, no address in vet-lab), ND4 (quarter hour at
or after the deadline + 3 min), EX5 (09:00 chase + 15 min, Mon-Fri),
EX1-EX4's mechanism (shell + SQL), the inbound leg on the centre's own
request. Rerun note: fixture-exchanges' launcher starts at :37.
Chunk 20 dispatched (`brief-20.md`).

### Chunk 20 paused, 2026-11-10

Owner paused on context at WIP `0620551` (branch
v0.5-c20-periodic-reports, cut from `cdf8a80`): purposes 7, 8, 12 built,
format checks clean, histories and compute keys checked in a throwaway
postgres (planted periods present, a month sums its days), checks MR1-4,
AM1-4, WT1-3 exit 0 planted / exit 1 corrupted on a harness; unit 1227
OK. Not done: fixture-reports and its run, 20b (purposes 9, 10). Fresh
owner dispatched with `resume-20b.md`.
For G18 / spec-writer, and two for the owner's report:
- WT2: on-call shifts take no part in the rest comparison (counting
  call-outs gives ~494 breaches a year, against vet-scheduling's
  false-alarm line on the 11 hours' rest).
- Data: vet-core's controlled batches receive far less than a year
  moves; 938 of 1 260 planted balances close negative, a likely false
  trap for players. MR4 judges the identity, not the stock. Domain data
  fix to route to spec-writer.
- AM4: up to 3 attempts in the 15 January run, then `escalated_at`.
- MR4, AM3, WT3 judge the job's loaded SQL against the check's rule on
  the last planted period; planted figures not judged.
- Balances signed by the lowest-id employed vet; planted references
  `amu-<year>` vs live `AMU<year>-NNNN`.
- `clinic-reports` targets the standby here, records in purpose 5: a
  scenario with both retargets purpose 5's (its gm.md says so).
- AM2 needs a herd treatment on the judged day (herd visits Tue/Thu):
  fixture takes T0 on a local Wednesday or Friday, or plants one.

### Chunk 20a merged, 2026-11-10 04:15

Merge `a8df8ee` (20a `d365213`): purposes 7, 8, 12 and fixture-reports
(8 nodes, standby, backoffice). Run 1 (03:50-04:10): 65 PASS, 0 FAIL,
766 s (load-data 581 s); every feeder writes its day once from the
standby, a second move writes 0; a monthly job off its date writes
nothing; MR1-4, AM1-4, WT1-3 exit 0 unfaulted; WT3 exit 1 with corrupted
SQL. Unit 1227 OK; gmctl fit 1.75/2 CPU, 2G/4G, 7.86G/8G disk.
New: the fixture's standby reserves 1.75G disk, not the capacity table's
2.25G (8.36G would not fit 8G); `backoffice` is `no-access` like every
fixture runner, though the access model gives scheduler nodes
`fixable-file` (chunk 24 may change it). 20b risk: purpose 9's feeder at
00:30 versus T0 ~01:07 (resume-20c.md). Fresh 20b owner dispatched.

### Chunk 21 merged, 2026-11-10 05:10

21b merge `d55429c` (21b `34d0694`). fixture-portal run 3 (04:40-05:02):
108 PASS, 0 FAIL, 1307 s; copies, release gate, RL6 visits, messages
(503 retried, 27 reminders, closure) shown; the 12 RL/MS checks exit 0,
and exit 2 with gm_check_read dropped. Run 2's failure: the `messaging`
role not admitted on partners-db's pg_hba. Unit 1227 OK. New for G18:
RL5 judges "touched since closure" from the judged moment, since the
load stamps every account's `synced_at` with the load epoch. Risks: the
portal run needs launch at host minute :40 (T0 08:52 local, ~8 min
margin); RL6/MS1 depend on traffic arriving within the run.
Gate fix list so far: fixture-vault and fixture-restore map
`partners.md` on their bastion (format skill).

### Chunk 20 merged, 2026-11-10 06:20

20b merge `2738845` (20b `74910fd`). fixture-reports run 2 (05:50-06:11):
94 PASS, 0 FAIL, 848 s; HO1-3, ST1-3 and 20a's checks exit 0 unfaulted;
feeders write once then 0; jobs off their date write nothing. Unit 1227
OK. gmctl fit 1.95/2 CPU, 2.4G/4G, 7.86G/8G (hand-over snapshot doesn't
fit: no snapshot in this fixture). For G18 / spec-writer: discount
brackets (game values 3/5/10/15 % from 0/200/400/600); voids count only
for charges stated by month's end (every planted `voided` is 0);
the month's turnaround is the median of the days' medians; monthly_figures
grain month x section x measure (684 rows, vs clinic-purposes' estimate
of 12); measure readings (tests at release, turnaround receipt→release,
units in service from `state_since_at`); escalation sets `escalated_at`
only (no incidents table in `office`). Risk: fixture-reports needs
load-data to start before 00:30 local (~30 min margin).
All wave-4 chunks merged (32, 17, 33, 18, 19, 21, 20). Next: wave gate.

### Wave gate — results, 2026-11-10

Gate owner (`coding-leader`), armenelos alone, under the lock and the
inhibitor, κ = 1: one queue (`gate-w4/queue.py` in the scratchpad) runs
every docker item one at a time, the time-placed fixtures at their
reserved minutes (`lock-slots.md`), the rest filling the gaps.

Part 1 (06:20-08:36), all passing:
- **G3** hand check: Debian trixie, PGDG trixie-pgdg, s6-overlay's
  releases, pgwatch's latest release, PyPI all answer 200. **G4**:
  armenelos `Leader`, the VPS `Drain` (`docker node ls` only).
- **Gate fixes** (the known pair, format skill, driver's ruling at chunk
  21a): `4ac27ad` fixture-vault and `9ee55dd` fixture-restore (chunk 28)
  map `partners.md: player/partners.md` on their bastion, as
  fixture-portal does; no `{{credential:}}` placeholder, nothing mounted;
  READMEs regenerated (scenario-document). Loader clean on both, 542
  docker-free unit tests OK. Reruns: **fixture-vault 48/48 (325 s)**,
  **fixture-restore 36/36 (85 s)**.
- Unit suite 1227 OK, 2 skipped (205 s); scheduler 91 OK (201 s); `api`
  36 OK (3.0 s). `sh -n` 303 files, `perl -c` 13, `py_compile` 339, 0
  failures.
- Builds, all from cache at their present versions (no patch bump;
  `bastion` 0.5.0 without `curl`, G11.2 with the owner): bastion,
  postgres, api, scheduler, grafana, pgbouncer, prometheus,
  postgres-exporter, pgwatch, health-check, 9-21 s each.
- Stack tests, all 0 FAIL: `bastion` 114 (87 s; both seed files, the
  cold-storage route's refusals, `partners.md`'s placeholders),
  `postgres` 315 (425 s), `scheduler` 178 (822 s), `api` 88 (195 s),
  `grafana` 130 (166 s), `pgbouncer` 120 (170 s), `prometheus` 131
  (78 s), `postgres-exporter` 103 (98 s), `pgwatch` 72 (250 s),
  `health-check` 95 (199 s).
- Smokes: `smoke.sh` 61 (29 s), `smoke-monitoring.sh` 43 (47 s),
  `smoke-monitoring-v05.sh` 27 (138 s), `smoke-governance.sh` 121
  (126 s), `smoke-load.sh` 73 (374 s).
- Scenario smokes (D367): `bookshop-new-server` 19/19 (22 s);
  `fernway-clinics-monitoring` 18/18 (29 s); `tarnbeck-outdoor-campaign`
  33/33 (301 s; f1-f4, f7, f8 `too-soon`, f10 `error` under 12.7 as
  designed, f5, f9 present).
- Chunk 32's composed test load (`TestComposedLoad`) 2 OK (23 s). The
  register tests in the unit suite (`TestRegisterFixture`,
  `TestRegisterRefusals`: generated, stale digest refused, declared
  absence passed).
- Every composed fixture with the centres: `gmctl compose --check` exit 0
  on all 13 (`left_out:` vet-core's `partners/centres` in 12,
  fixture-exchanges composing them); loads so far: fixture-core 40/40
  (176 s), fixture-exchanges (below).
- **fixture-exchanges** (launcher 06:37): 42/42, 1467 s from the
  deployment; EX1-EX5, ND1-ND5 exit 0.
- **fixture-send-outs** (launcher 07:38, lock taken by the test at
  07:40): 32/32, 1426 s from the deployment.

### Owner's rulings, 2026-11-10 09:25

- **G11.2 accepted:** Debian `curl` goes into `bastion` 0.5.0 (no version
  bump: 0.5.0 is unreleased), risk accepted until 2027-02-01 or the next
  trixie curl security upload. Built, stack-tested and post-change
  checked after the gate queue; the advisor records it in `.tech`.
- **Security decisions (advisor's triage of 2026-11-09), all as
  recommended:** the 50 `[[ignore]]` entries until 2027-05-01; patch bump
  whenever an image's content changes (tag kept only for an identical
  `dpkg-query` list); Prometheus to 3.16.x in a later wave, never wave 4;
  python3.13 upgraded on armenelos (the owner's command); c-ares into
  `.tech` with its ignore; the 19 orphan items deleted from
  `SECURITY_TODO.md`. `.tech` is edited on this wave branch, so it reaches
  main with the wave. grafana 0.3.1 (plugin 13.2.5) and Prometheus 3.16
  go to spec-writer for placement (wave 5 or the release gate) with G18.
- **Fake aging:** the weekend test did not run; the owner plans it for
  the coming weekend or the next. D114/D132 stand meanwhile.

### Gate: BS1 timing, owner's ruling, 2026-11-10 14:10

fixture-lab-core rerun: 44/44, 694 s (the 09:24 failure was the owner's
`apt upgrade` restarting Docker 29.9.2 -> 29.9.3 mid-test). curl in
`bastion` 0.5.0: `91aad3f`, stack test 116/116 (86 s), curl and
libcurl4t64 8.14.1-2+deb13u7 (libldap2, libsasl2-2 also pulled in; for
the post-change check).
fixture-bookings failed BS1 twice (booking 49137, 120 s, deterministic on
a Tuesday run): pms's `sched.bookings.arrive` stamps
`least(now(), starts_at + δ)`, so a booking reached late in the 10:00
burst is back-dated before commit and a correct check-in looks late; in a
real game BS1 would report false "present". **Owner's ruling (option A):
the producer stamps when it records**: the arrive stream takes a booked
booking whose hashed arrival moment has passed and sets
`arrived_at = now()`; BS1's 2-minute rule stands. spec-writer records it
(vet-scheduling-domain.md row 816) with G18; the fix lands on the wave
branch as a gate fix (chunk 13b's fragment and the fixture copies).

### Wave gate — part 2 and result, 2026-11-10 17:05

Queue part 2 (08:40-12:15, then reruns), on the merged branch:
- **unit-final** 1227 OK (209 s); after the BS1 fix 1227 OK (204 s).
- **Fixtures:** portal 108/108 (1297 s); tarnbeck-outdoor-shop smoke
  26/26 (827 s); orders 30/30 (1194 s); clinic-load 23/23 (1302 s);
  reports 94/94 (910 s from the deployment); housing (place) 40/40
  (1248 s); imaging 67/67 (1286 s); lab-core 44/44 on rerun (694 s; the
  first run died on the owner's Docker upgrade at 09:24); bookings 54/54
  on the second rerun (1183 s; BS1 43 s) after gate fix `7840cb8`.
- **Gate fixes:** `4ac27ad`, `9ee55dd` (partners.md on fixture-vault and
  fixture-restore); `91aad3f` (curl in `bastion` 0.5.0, G11.2, stack test
  116/116); `7840cb8` (pms stamps an arrival when it records it, owner's
  ruling; `sched.bookings.arrive` in vet-scheduling's pms and
  fixture-bookings' copy; the domain's gm.md stream row reworded;
  compose --check clean on all 13).
- Every item under 30 minutes. **Gate passed.**
For G18 / spec-writer from the BS1 fix: T115's witness (check-in's
watermark against arrivals committed later) relied on the back-dating;
the stamp-to-commit gap is now milliseconds, so the trap needs a held
transaction on `sched.bookings.arrive` in its variant or a restated
witness. fixture-bookings now sees fewer arrivals in its window (3, BS1
judged 1); lengthening the window past 10:00 local would restore
evidence.
Next: wave sync (security-advisor's post-change check; no intent
register, no documentalist), G18, the owner's report.

### Wave sync and G18, 2026-11-10

- **Security post-change check** (`efcd336`, `.tech` only): `bastion`
  0.5.0 rebuilt with curl/libcurl4t64 8.14.1-2+deb13u7 (14 new
  packages, nothing open that is reachable); prometheus 0.2.0 and
  postgres-exporter 0.2.0 read (curl as recorded); the wave's only new
  dependency is curl in the bastion; python3.13 upgraded on armenelos
  (deb13u5), CVE-2026-0864's ignore added. 97 open, 73 set aside.
  `bastion` keeps 0.5.0 (unreleased, never deployed outside the wave's
  tests).
- **No intent register:** no documentalist sync.
- **G18 done** (`e2381be`): formats.md v32; master spec 5, 6, 6.2, 6.6,
  12.1 (and 6.7, 7.3, 7.5, 9.4, 12.2 by the rulings). D443-D457; O247
  open (grafana 0.3.0 rebuilt or 0.3.1; rec. 0.3.0, unreleased); O248
  reserved unused. Wave 5 grows to chunks 22-27, 34 (grafana plugin,
  prometheus 0.2.1 on 3.16.x) and 35 (vet-core's controlled receipts
  sized to the year's use; planted partner references in the stubs'
  live form). `doc-ids compare main v0.5-w4`: 0 collisions.

### Wave 4 — report to the owner, 2026-11-10

Chunks merged: 32, 17, 33, 18, 19, 21, 20 (inserted: 32, 33). Gate passed
(all items under 30 min; fixes `4ac27ad`, `9ee55dd`, `91aad3f`,
`7840cb8`). Owner decisions open: O247 (grafana tag); 20 curl
false-positive ignores (`curl-fp-ignore.toml`); CVE-2026-123158's ignore
(OpenSSH, musl-only). Merge into main on the owner's word; wave 5 in a
fresh session.

### Wave 4 merged into main, 2026-11-10

On the owner's word ("merge"), after D458: `v0.5-w4` merged `--no-ff` as
`b4f35cc`; worktrees and the wave's branches removed; not pushed. Next:
wave 5 (chunks 22-27, 34, 35; 34 and 35 first) in a fresh session, cut
from main; read this log's entries from "Wave 4 — report to the owner"
and the plan's wave-5 notes (D456, D457). Known for wave 5: the host lock
protocol (one docker run at a time, `/tmp/dbagm-docker.lock`, time-placed
fixtures booked in hourly windows); check-sql prints booleans as
`True`/`False`; postgres nodes have no Python; drive the wave from the
top-level session (background drivers lost their chunk owners' reports).

## Wave 5 — started 2026-11-12

Branch `v0.5-w5`, worktree `/home/bastien/work/db_audit_gm-wt/v0.5-w5`,
cut from `main` at a5d912d, after wave 4 merged into it (b4f35cc) on the
owner's word. Chunks 22, 23, 24, 25, 26, 27, 34, 35 (plan v15, spec
D457): 34 and 35 first, beside one of 22 to 26; 27 cut once the seven
others have merged. Driven from the top-level session; at most two chunk
owners working at once (owner's standing preference, κ = 3 the plan's
ceiling); docker runs serialised by `/tmp/dbagm-docker.lock`.

Gates checked at the start (2026-11-12): G3, Debian trixie's and
`trixie-pgdg`'s `Release`, PyPI, GitHub's Prometheus releases and
grafana.com's plugin catalogue answer 200; G4, the swarm (armenelos
`Active`, `Leader`, engine 29.9.3; `vps-5718ad52` `Drain`, 29.9.2; both
`Ready`). `/var` 24G free, `/` 9.0G, about 4G of memory available (the
owner's own containers running beside: ollama and others; fixtures may
need them stopped). G11.3 and G11.4 dispatched to `security-advisor` at
once (chunk 34's branch waits for both). No intent register, so no
documentalist preflight: capture W5 drafted for the driver from the
chunks' **Architecture capture** lines, as W1 to W4. Chunk 35's capture
is spec D451 and none of W5's items touch its files, so it is dispatched
beside the capture's drafting.

### Capture W5 — the ten faults and the false alarm, the GM's composition, the monitoring images, what the clinic reads (chunks 22–26, 34, 35; read by 27)

Recorded 2026-11-12, before any fault chunk starts; drafted for the
wave driver from the **Architecture capture** lines of chunks 22 to 26,
34 and 35 (plan v15, with its header, "Read first", the gates, the
dependency graph, wave 5's order, "Per-wave gate contents" row 5, the
shared lists, "Left for the build"), chunk 27 as far as it reads W5,
master spec 6.3, 6.4, 6.7, 7.1 ("Options"), 12, 13.3, 13.4, 14, 15, 16,
17.1 to 17.4 and 18.1 to 18.3, [clinic-test-selection.md](clinic-test-selection.md),
[clinic-traps.md](clinic-traps.md) (T1, T10, T33, T35, T40, T41, T69,
T150, T270, T307, section 9's false alarms),
[data-register-handout.md](data-register-handout.md) 4 and 5, access
model 2, 5 and 9.3, vet-portal's document (D423, T270, T274) and
vet-housing's GM notes ("finding a faulty display"),
[formats.md](../../formats.md) v32 ("Scenario", "Fault definition",
"Purpose definition", "Composing domains"), spec D443 to D458, and the
code on `v0.5-w5` at 01b0385: `faults/` (the 29 definitions, their
kinds), `tools/gm/{model,inject,compose,render,localimpl}.py`
(`check_fault_dir`, `_check_fault_options`, `_check_monitors`,
`_check_fault_instance_options`, `_check_issues`, the template schema's
`allow_empty`, `inject_plan`), `tools/tests/test_brick_docs.py`, the
fixtures `fixture-{orders,send-outs,archive,reports,housing,portal,clinic-load,register}`
(their `scenario.yaml` and `run-short-test.sh` headers), the purposes
the faults touch (`vet-lab-centre-orders`, `vet-antimicrobial-use`,
`vet-medicines-registers`), `domains/vet-portal/data/{schema,derive}.sql`,
`domains/vet-housing/producers/ward/`, `bricks/{postgres,scheduler,bastion,api,postgres-exporter,grafana,prometheus}/`
(`docs/gm.md` "Supported faults", `vault-post`, `gm-entrypoint`'s
option step, the two Dockerfiles), the skills `scenario-format`
(templates `fault.yaml`, `scenario.yaml`, `answer-key.yaml`,
`composition.yaml`), `data-register`, `game-master`,
`scenario-document`; and G11.3 and G11.4's results as the driver relayed
them. W1 to W4's rules: cited, not restated; **(choice)** marks a point
the sources left open, settled here with its reason; each item names
the chunk that writes it and those that read it. Held: W1 to W4 with
their addenda W1-w to W1-z, W2-a to W2-g, W3-a to W3-h, W4-a to W4-g;
where the merged code differs from them or from the spec, the code and
the addenda win. Chunks record their as-built outcomes as **W5-a**
(chunk 22), **W5-b** (23), **W5-c** (24), **W5-d** (25), **W5-e** (26),
**W5-f** (34), **W5-g** (35), **W5-h** (chunk 36, if inserted:
Preflight corrections, item 1) and **W5-i** (27).

**What the sources leave short.** Read against the merged loader, three
of the eleven have no form: s3 is planted on two nodes (the feeder's
query on `backoffice`, the planted report in `office` on `records`),
while a fault instance has one node and its `state` scripts run there
only (`inject_plan`); s10's absence is a topology fact, and no
injection kind (`seed-file`, `state`, `parameter`) expresses a change
with no seed file, script or parameter; the false alarm is an issue
covering no fault, and `issues[].covers: []` is refused ("empty": the
template's comment does not allow it). Read against the bricks and the
data: with a one-hour `recovery_min_apply_delay` the 01:30 feeder's day
is complete (the standby has replayed to 00:30); a redeployed `lab`
choosing `monitoring` creates nothing on an existing `pgdata`
(`postgres` `docs/gm.md`, "Changed later"); the portal copies every
ownership, so T270 exposes every past sale, not the day's. Items 0, 3,
4 and 6 settle what can be settled; Preflight corrections, items 1 to
5, carry the rest to the plan.

**0. Rules shared by the fault chunks** (22 to 25 write them; read by
26, 27)

- **Ids and families (choice; formats.md "Fault definition", the
  catalogue's prefixes)**: a fault living in a database node's files or
  state `pg-`, in a scheduler node's files `scheduler-`, a purpose fault
  `purpose-`, governance `governance-`, row-level and credential faults
  `security-`:

  | # | Trap | Id | Family | Kind | Instance node | `applies_to` |
  |---|---|---|---|---|---|---|
  | s1 | T40 | `purpose-urgent-priority-dropped` | rules | seed-file | `interfaces` | `scheduler` 0.3.0; purposes `vet-lab-centre-orders` |
  | s2 | T35 | `pg-archive-command-silent` | backups | seed-file | `records` | `postgres` 0.5.0 |
  | s3 | T69 | `purpose-herd-use-dropped` | data-flow | state with seed changes (D254) | `backoffice` | `scheduler` 0.3.0, `postgres` 0.5.0 (its office script, item 3); purposes `vet-antimicrobial-use` |
  | s4 | T41 | `purpose-retry-without-key` | data-flow | seed-file | `interfaces` | `scheduler` 0.3.0; purposes `vet-lab-centre-orders` |
  | s5 | T270 | `security-policy-ownership-end-dropped` | security | state | `records` | `postgres` 0.5.0 |
  | s6 | T307 | `governance-register-flow-undeclared` | security | seed-file (`data-register.md`) | `bastion` | `bastion` 0.5.0 |
  | s7 | T1 | `governance-statement-log-personal` | security | seed-file | `records` | `postgres` 0.5.0 |
  | s8 | T33 | `pg-standby-apply-delay` | replication | seed-file | `standby` | `postgres` 0.5.0 |
  | s9 | T150 | `scheduler-display-refresh-loop` | performance | seed-file | `ward` | `scheduler` 0.3.0 |
  | s10 | T10 | `pg-monitoring-option-absent` | monitoring | `topology` (item 4) | `lab` | `postgres` 0.5.0 only |

  Versions: v0.5's only (`0.5.0`, `0.3.0`), each fault needing a v0.5
  feature or a v0.5 domain; `postgres`' "Supported faults" sentence "all
  also name `0.4.0`" is amended by the first chunk adding to it.
  **s10 never names `postgres-exporter`**: `test_brick_docs.py` would
  then require its `docs/gm.md` to list it, and a documentation change
  bumps a released brick (master spec 6.7); the exporter's side is
  s10's `gm.md` and the scenario's answer key.
- **Where a seed change is written (choice)**: on a node `gmctl compose`
  writes (a scheduler or `api` node of a composed scenario), in the
  scenario layer `compose/<node>/`, never in `nodes/<node>/`, so
  `gmctl compose --check` stays clean and the change survives a
  recompose; elsewhere (`records`, `standby`, `lab`, the bastion) in
  `nodes/<node>/` as v0.4. Each fault's `seed_changes[].change` says
  the one edit and its `material` is that edit alone (a function, a
  setting line, a stream), never a whole file, since s1 and s4 change
  the same script and s2 and s7 the same `postgresql.conf`: the clinic's
  copy carries both, each sealed check judging its own edit's behaviour
  or setting, so fixing one leaves the other present.
- **The fixtures' committed form (choice)**: an existing fixture keeps
  its committed files unfaulted, so its wave-4 short test and the gate's
  rerun stand; a fault's short test plants on a copy, from an overlay
  committed in the fixture under `planted/<fault-id>/` (the fault
  instance and issue as `scenario.yaml` fragments, the answer-key entry,
  the seed change at its scenario path), merged into the copy by the
  test (host Python, PyYAML), the README of the copy not regenerated
  (no commit). The loader never reads `planted/`. A fixture built for
  its fault (`fixture-portal-scope`, `fixture-lab`) commits the
  instance, and `fixture-lab` must (the loader refuses its topology
  without it). One short test per fault, one at a time (gate row 5),
  but s2 and s6 together (17.2).
- **Time placed (master spec 18.1)**: every seed-file fault is planted
  at render, so its moment is the fixture's start, before T0; a `state`
  fault at `gmctl inject` after `load-data` and its coherence check,
  before `start-load`; s5's game moment three hours before hand-over
  (item 6). Each fault's readings fall after T0, at moments the test
  places (the table in item 7).
- **A feeder's day as present and fixed reading (choice)**: a feeder
  writes its day once (W4-d), so a test reading a short day and then a
  complete one removes, between the two, that day's output rows and its
  run row in `office`, as the GM, in one transaction, unseen (the
  players' rerun, which the answer key credits), before moving the
  feeder again. s3 and s8 use it.
- **Checks**: as W4 item 0, "Where a check runs", and the scheduler's
  convention (`check-sql` prints booleans as `True`/`False`; database
  nodes have no Python: shell and SQL). A check reading the portal
  first finds `gm_check_read` in place (W4 item 7, D432). A check may
  read a partner's side as evidence, never judge it (6.3); a public
  partner endpoint is read with the node's own client (`postgres`: Perl
  `HTTP::Tiny`, as `vault-post`; no `curl` there).
- **Brick documentation**: each new fault is a row in the "Supported
  faults" of every brick its `applies_to` names (`test_brick_docs.py`):
  `postgres` s2, s3, s5, s7, s8, s10; `scheduler` s1, s3, s4, s9;
  `bastion` s6, whose section today says the bastion hosts no fault and
  none should be written: chunk 23 rewrites it for register faults
  (6.4, 13.4: the handout only, nothing on the bastion changing).
  `api` and `postgres-exporter` gain none.

**1. The orders faults: s1, s4 and the false alarm** (chunk 22 writes,
W5-a records; read by 26, 27)

- **s1** `purpose-urgent-priority-dropped`: in `scripts/lab_orders.py`,
  `post`'s body field `"priority": priority` sent as `routine` whatever
  the group's priority (the mapping's one line; the `client_ref`
  `C-<consultation>-<priority>` unchanged, so the grouping still splits
  urgent from routine). Seed change `scripts/` on `interfaces`, in
  `compose/interfaces/`. Sealed check on `interfaces`, `judges: runs`:
  each `urgent` request posted since the judged moment went out
  `urgent` (`ops.lab_orders_sent` against `requests` through
  `check-sql`), and LO4's end to end on those completed (D456). Fixed
  on the runner's repository (write override), `gm-reload-scheduler`.
- **s1's backlog** (6.3; the answer key's `backlog:`): `what`: the
  urgent requests posted `routine` before the fix, waiting at `lab` for
  the next pathologist's round (`ops.lab_orders_sent`'s `-routine`
  references whose requests are `urgent`, against `lab_orders.priority`);
  `cleanup`: each identified from the trace and raised to `urgent` at
  `lab` (or its release asked of the lab), credited, never counted.
  **(choice)** s4's instance lists one too: the duplicate orders the
  retries left before the fix, cleaned up by cancelling the second
  order of each pair at `lab`.
- **s4** `purpose-retry-without-key`: the same file, the `client_ref`
  built anew on a retry (the run's minute appended after a timeout), so
  a timed-out post posted again is a new order. Seed change `scripts/`
  as s1's. Sealed check `judges: runs`: one order per consultation and
  priority since the judged moment (LO2), the orders read at `lab`
  through `check-sql`. In a game its witness needs an answer slower
  than the runner's ten seconds; the clinic plants none, so its rate is
  "a few a week" by the calibration, unproven until v1.0 (and it is
  not read at G13, 18.3).
- **The false alarm, fa**: no fault definition. An issue "The external
  lab is slow", `expected_resolution: report`, covering no fault (the
  form is Preflight corrections, item 1 (c)); the answer key's
  `false_alarms:` entry: why it is no fault (a PCR answered on its
  fourth day, within its one-to-five-day turnaround), the evidence
  (`lab_send_outs`' `due_by` against `answered_at`, as `dba` on `lab`),
  what counts (the players report no fault behind it, citing the
  turnaround). Its PCR: one the load already planted (vet-lab's 1 937
  send-outs), found by a query the answer key gives; on the send-outs
  fixture, if the load holds none, the test places one, as it places a
  due send-out today. fa's check is the fixture test's own query, not a
  sealed check.
- **Fixtures**: `fixture-orders` (T0 about 10:00 local, a weekday when
  the host's is; as built) for s1 and s4, each its overlay, the
  emergencies raised in its own `compose/pms/` layer for s1 only;
  `fixture-send-outs` (T0 15:45–15:51, as built) for fa.

**2. The archive faults: s2 and s6** (chunk 23 writes, W5-b records;
read by 26, 27)

- **s2** `pg-archive-command-silent` **(choice)**: `records`'
  `postgresql.conf`, `archive_command = 'vault-post wal %p %f || true'`:
  the arguments swapped (the name `pg_wal/…` refused by `vault-post`'s
  name rule, exit 2, its reason on standard error, so in the server log)
  and `|| true`, added so a vault outage never fills `pg_wal`: the
  archiver counts every segment archived and none reaches the vault.
  One line, both mistakes visible in the file, deterministic. Sealed
  check on `records`, live state: the latest segment
  `pg_stat_archiver` counts archived (`check-psql`) has a `wal`
  manifest from source `records` (cold storage's public `GET
  /manifests?type=wal&source=records`, Perl `HTTP::Tiny`, the latest
  by `received_at`, never by name, D382); evidence only, the vault
  never judged.
- **s6** `governance-register-flow-undeclared`: parameter `recipient`
  (default cold storage's `partners.md` name). **(choice)** T307's
  change drops the recipient from every entry's `shared_with` and its
  `{copy: cold storage (WAL archive, nightly base backup)}` item from
  every entry's `where`, so the vault is named nowhere (handout 4, T307;
  the skill's table names `shared_with` only); `register_diff:` one item
  per entry and field changed. Sealed check on the bastion, live: the
  served handout (`/home/player/data-register.md`, read as root) names
  the recipient on no entry: exit 1; never cleared in play.
- **The archive fixture gains a register (choice)**: a register with no
  domain has no entry to drop cold storage from, so `fixture-archive`
  composes vet-core at `records/clinic` (uncomposed, every producer
  `left_out:` with the centres, `composition.yaml` written by hand as
  `fixture-clinic-load`'s), with vet-core's `governance:`, its default
  policy as `player/data-policy.md`, `governance.register` and both
  registers generated by the skill. Its data file stops creating
  `clinic` (now vet-core's `at:`): the test's filler table moves to a
  database of its own. Five nodes, unchanged. The load adds vet-core's
  (about three minutes).
- **Readings**: s2 and s6 planted together (17.2); present: a segment
  switched by the test (`pg_switch_wal()`), counted archived, no
  manifest, the gap on the page; the served handout without cold
  storage while the page lists `records`' planted `wal` and
  `basebackup` manifests (the base backup is the crontab's, unaffected
  by s2). Fixed (s2): the line corrected and reloaded, the next switched
  segment's manifest present, the gap staying a finding. **Cleared (s6;
  choice)**: the skill has no `gmctl` generator (13.3), so the test
  cannot regenerate; the chunk owner runs the skill on a copy without
  the instance, its handout naming cold storage on every entry the true
  register does and the loader passing, recorded in W5-b; the short
  test reads present only. The answer key notes the interaction (the
  vault still holding the planted manifests and base backups) and the
  setup limit of D382.

**3. The reports faults: s3, s7, s8** (chunk 24 writes, W5-c records;
read by 27; after chunk 35 for its fixture run)

- **The fixture as built** (W4-d, 20a, 20b; the code wins over the
  plan's "a Friday at 01:20"): T0 about 00:10 local, any day, the test
  recording a herd treatment yesterday when the load holds none; eight
  nodes. `backoffice` takes `fixable-file` (D456).
- **s3** `purpose-herd-use-dropped`: `amu.feed.read` in `backoffice`'s
  `queries.yaml` (in `compose/backoffice/`), the dispensings' `LEFT JOIN
  animals` made an inner join, so a herd prescription (no animal)
  drops. **The planted report short**: a `state` script rewriting, in
  `office`, last year's planted `antimicrobial_use` days and the
  `amu_reports` lines as the faulty query would have written them
  (the herd dispensings subtracted per day, species and code; the
  reference and its form kept, chunk 35's `AMU<year>-NNNN`), run as
  `postgres` over the socket, unseen (statement logging, pgaudit and
  `pg_stat_statements` off for the session, as `load-data`'s are),
  after the history and the coherence check. It must run on `records`
  while the instance's node is `backoffice`: the loader's gap,
  Preflight corrections, item 1 (a). Sealed check on `backoffice`,
  `judges: runs`: each day the feeder wrote since the judged moment
  counts every herd treatment under its herd's species (AM2's rule).
- **s7** `governance-statement-log-personal`: `records`'
  `postgresql.conf`, `log_statement = 'all'`. Sealed check on
  `records`, live: no `log_statement` but `none` or `ddl` in effect,
  server-wide or in `pg_db_role_setting` for a role or database
  writing personal data. Present: the test's `pms`-style writes as
  `vet_app` (an owner's name and phone) in the log; fixed after a
  reload.
- **s8** `pg-standby-apply-delay`: the standby's `postgresql.conf`,
  `recovery_min_apply_delay = '1h'`, from its first start; the clone
  reaches consistency undelayed (PostgreSQL applies no delay before
  consistency), so the setup is unaffected: chunk 24 verifies
  `load-data`'s standby wait with the delay in effect (risk). Sealed
  check on `standby`, live: the delay in effect is 0. **Present in a
  short test (choice)**: the delay in effect, WAL received and not
  replayed (`pg_last_wal_receive_lsn()` ahead of
  `pg_last_wal_replay_lsn()`), and the feeder's day missing rows the
  test records after T0, dated yesterday's last hour (late entries, as
  `pms`' staff enter them after midnight), present on `records`, absent
  on the standby. "The replay lag at an hour" reads only after an hour
  of the delay: Preflight corrections, item 2. Fixed: the delay
  removed, reloaded, the backlog replayed at once, the day removed and
  the feeder moved again (item 0), its day complete.
- **Interactions** (for 27's answer key): s3 and s8 both bite feeders
  reading the standby; s8 never hides a herd treatment, s3's witness
  stands with it. s7 and s2 share `records`' file (item 0).

**4. The scope faults: s5, s9, s10** (chunk 25 writes, W5-d records;
read by 26, 27)

- **s5** `security-policy-ownership-end-dropped`: a `state` fault
  (parameters `database` default `portal`), its script `ALTER POLICY
  portal_animals_scope ON portal_animals USING (…)` with the owner
  branch's `o.until_at IS NULL` left out, the keeper branch untouched
  (T274's is `portal_keeper_granted`, D427), as `postgres`, unseen;
  planted after the coherence check. **Fixture `fixture-portal-scope`
  (choice)**: the bastion, `records` (`clinic`, `portal`), `portal-api`;
  vet-core and vet-portal composed (the derivation, D322), every
  producer `left_out:`; T0 a weekday morning. **The sale**: the test,
  after `load-data` and before `inject`, records a horse's sale dated
  two hours back in `clinic` and its copy in `portal`, as `pms` and
  purpose 15 would. Present: as the former owner (its password
  `portal_password(n, load_epoch)`, vet-portal's GM notes), `POST
  /login` then `GET /animals` on `portal-api` returns the horse; fixed:
  not, the buyer still sees it. **Sealed check** on `records`, live, as
  `gm_check` (guard first), never as `portal_api` or `dba`: it judges
  whether the live policy admits a former owner; the mechanism is
  chunk 25's, recorded in W5-d (`gm_check` holds no `EXECUTE` on
  `portal_keeper_granted`, so the policy's text cannot simply be
  evaluated as `gm_check`).
- **s9** `scheduler-display-refresh-loop`: parameters `unit` (a unit
  with a display) and `rate` (default `3600/h`, about once a second):
  a key `ward.board-loop` whose `sql` is `ward.board`'s byte for byte
  with `unit` fixed, and a stream on `ward-board` at `rate`, both in
  `compose/ward/` (seed changes `queries.yaml`, `schedule.yaml`;
  vet-housing's GM notes, W3 item 3). Resolution `report` only, every
  write policy; never cleared in play (6.3). Sealed check on `ward`,
  `behavioural: true`: `ward.board`'s `queryid` calls a minute on
  `records` through `check-sql`, window and threshold in the answer key
  (64 a minute and a margin). Cleared by the test only: the stream
  removed by the GM's path the brick allows (the live schedule as root
  and `gm-reload-scheduler`, or `ward` redeployed from the recomposed
  layer), recorded in W5-d. On `fixture-housing` (as built).
- **s10** `pg-monitoring-option-absent`: `option_absent: monitoring`;
  `injection.kind: topology` (Preflight corrections, item 1 (b)); the
  scenario's `lab` without `options: [monitoring]`, which
  `_check_monitors` accepts for every monitoring node targeting the
  instance's node. **Resolution (choice)**: `report` and `propose`,
  never `fix`: players read no service credential (access model 5), so
  they cannot give a role the exporter's password, and choosing the
  option later creates nothing on an existing `pgdata` (`postgres`'
  GM notes). Acceptance: the `monitoring` role, a member of
  `pg_monitor`, with the exporter's credential (the option chosen at the
  next build). Sealed check on `lab`, live: `monitoring` exists, `LOGIN`,
  a member of `pg_monitor`. **Fixture `fixture-lab` (choice)**: the
  bastion, `lab` (a plain `postgres` 0.5.0 node with a small data file,
  no domain), a `postgres-exporter` 0.2.0 node; no Prometheus, so no
  `prometheus` pin. Present: the exporter's login errors, `pg_up 0`.
  Fixed (Preflight corrections, item 3): the test creates the role as
  the option's initdb step does, with the game's `monitoring_password`,
  the GM applying an accepted proposal; the exporter's metrics present.
  Risk: `monitoring_password` exists in a game where only the exporter
  declares it (`postgres`' notes say so); chunk 25 shows it.

**5. The GM's composition and setup** (chunk 26 writes, W5-e records;
read by 27)

The steps as the GM runs them, for `game-master` `SKILL.md`
("Designing a scenario", "Setup") and `gmctl.md`:
1. **At design**: `domains:` in `scenario.yaml` (the core's `variant:`,
   each `at:`); each purpose's material copied into `compose/<node>/`,
   each third party's stub folders into `compose/partners-api/` and
   `compose/partners-backend/` with their `data.sql` in `partners-db`'s
   data file (W4 item 0); the faults' seed changes on composed nodes in
   `compose/<node>/` (item 0).
2. `gmctl compose <dir>`: on a conflict between two sources of one
   layer, it stops naming both; the GM resolves it in `merge.yaml` and
   reruns, until it merges.
3. `composition.yaml`, written by the GM: `domains` (as `domains:`),
   `keys` (each part's core ranges and functions, against the core's
   notes), `scale` (`checked`), `order`, `derive` (sanctioned steps),
   `left_out` (fixtures only); `coherence:` is written by `load-data`.
4. **Setup step 2**: the format check, `gmctl compose <dir> --check`
   (exit 0: up to date) with it, then the register (chunk 17's), then
   the scenario document.
5. **At setup**: `load-data` runs the coherence check after the loads,
   (2b), (2c), the derivations and the histories; a failure is a design
   error: the setup stops, the GM tears down, fixes the composition (a
   range, a function, a scale) or a domain, and reloads; never a fault.
   Faults are planted after it (`gmctl inject`).
Beside these, chunk 26 writes what its scope lists (third parties
played by no one, their support never answering, an overstep on a third
party's node refused; a report-only fault judged at the final answer; a
register fault judged on *propose*; the scenario document's "Third
parties" and "Composition" sections, the jobs table's row for a
`ddl:`-scheduled `pg_cron` job), and, once chunk 36 has merged, the
false alarm: judged at the final answer (Evaluation), shown in the
scenario document's issues and answer key, and `gmctl.md`'s `inject`
row for a script run on another node and a `topology` fault ("planted
by the topology; nothing to run").

**6. What chunk 27 reads** (chunks 22 to 26, 34, 35 leave it; W5-i
records)

- **The instances**: the ten of item 0's table, on its nodes; s3's
  office node `records`; s5 planted three hours before hand-over (a
  `state` fault within the aging); every other at render. The seed
  changes in the clinic's copies: `compose/interfaces/` s1 and s4 in
  one `lab_orders.py`; `compose/backoffice/` s3; `compose/ward/` s9;
  `nodes/records/postgresql.conf` s2 and s7; `nodes/standby/postgresql.conf`
  s8; `lab` without `options: [monitoring]` (the other three database
  nodes with it); the handout with s6 by the skill.
- **The answer key**: s1's and s4's `backlog:`; s6's `register_diff:`
  (the skill's); s9 `report` only; s10 `propose`; fa's `false_alarms:`
  entry; interactions: s1 and s4 (one file), s2 and s7 (one file), s2
  and s6 (the vault's planted manifests and base backups stand), s3 and
  s8 (item 3), **s7 and s9** (with `log_statement = 'all'` the board's
  parameter is already in the log, so s9's careful step is unneeded
  while s7 stands; s9's acceptance "no instance-wide logging left
  behind" is met by s7's fix), **s10 beyond the exporter** (pgwatch's
  `lab` source and the health check's `lab` check fail too; one
  instance covers every monitoring node targeting `lab`). The aging
  minima: s3 from the 02:00 feeder's first run, s1 from the first
  urgent order, s8 from the 00:30 feeder's (item 3, Preflight
  corrections item 2), s4 unbounded (stated).
- **Pins**: every brick at the version its chunk leaves: `postgres`
  0.5.0, `scheduler` 0.3.0, `api` 0.1.0, `bastion` 0.5.0 (with `curl`,
  D443), `pgwatch` 0.1.0, `health-check` 0.1.0, `grafana` 0.3.0
  (Grafana 13.3.1, item 7), `prometheus` 0.2.1, `postgres-exporter`
  0.2.0; each fault at 0.1.0.
- **From wave 4** (D456): purpose 5's `clinic-reports` targets the
  standby, as purpose 7's; the story names the vet signing the
  controlled-drugs balances, the lowest-id vet employed, read on
  vet-core's load as chunk 35 leaves it (D451, D454).
- **`left_out:`**: none in the clinic (every producer composed); no
  shared `left_out:` line is added in wave 5 (no new producer folder).

**7. The monitoring images: chunk 34** (W5-f records; read by 27)

G11.3 and G11.4 cleared (the driver's relay, 2026-11-12); the values:

- **(a) `grafana` 0.3.0, the first route**: Grafana **13.3.1** (build
  42849527790) bundles the Prometheus data-source plugin at **13.2.5**
  (brotli 1.2.7). Tarball
  `https://dl.grafana.com/grafana/release/13.3.1/grafana_13.3.1_42849527790_linux_amd64.tar.gz`,
  sha256 `6acf8939dd2f73332cbcafc27a33973fb1115b8867e7ffa3223c6e2ecbed8531`.
  In `bricks/grafana/`: the Dockerfile's two `GRAFANA_VERSION` (13.3.0
  to 13.3.1), `GRAFANA_BUILD` (40412481033 to 42849527790) and the
  archive's `--checksum`; `brick.yaml`'s upstream version 13.3.1, the
  label 0.3.0 kept (D458); the archive's layout is 13.3.0's, so the
  trim step and `tools/go-sbom` are unchanged but for the pins; both
  SBOMs regenerated (`grafana.cdx.json`, the plugin's); no catalogue
  plugin pinned; `docs/gm.md`.
- **(b) `prometheus` 0.2.1 on Prometheus 3.16.0**: tarball
  `https://github.com/prometheus/prometheus/releases/download/v3.16.0/prometheus-3.16.0.linux-amd64.tar.gz`,
  sha256 `68727009472a2c02e1ff7f062fd5b3e637285bffc8fc2d340c76fb449d6e0f34`.
  In `bricks/prometheus/`: the Dockerfile's `PROMETHEUS_VERSION` (3.13.5
  to 3.16.0) and `--checksum`; `brick.yaml` version 0.2.1, upstream
  3.16.0; both SBOMs; `docs/gm.md` drops the 3.13 LTS wording. **No
  seed-file or flag change**: `promtool` 3.16.0 `check config` passes
  all eight seed files, and the runtime information and endpoints are
  unchanged. The re-pins as the plan lists them.
- Chunk 34 was dispatched on its plan's Files: W5 assigns it nothing
  more. A chunk merging after it pins `prometheus` 0.2.1 in a new
  fixture of its own; wave 5 plans none with a `prometheus` node
  (`fixture-lab` has the exporter only).

**8. Chunk 35** (W5-g records; read by 24, 27): its capture is spec
D451; W5 adds nothing. No conflict found: the fault chunks edit no
domain or purpose file (item 9); s3's state script runs after the
histories chunk 35 corrects and keeps their reference form; chunk 24's
fixture runs after 35's merge (D457).

**9. Wave 5 coordination** (for the driver and chunks 22 to 27, 34 to
36)

- **Files**: `faults/<id>/` each its chunk's; `tools/gm/*.py`, the
  `scenario-format` skill (`SKILL.md`, templates) chunk 36's alone in
  wave 5, `tools/tests/test_model.py` shared with chunk 34's tag lines
  (the second to merge takes `v0.5-w5` in); the `data-register` skill
  chunk 23's (T307's row); `game-master` and `scenario-document` chunk
  26's alone; no fault chunk edits a domain's or a purpose's files
  (`domains/`, `purposes/`: chunk 35's in wave 5), each fault's needs
  stated in its own `gm.md`; fixtures: 22 `fixture-orders`,
  `fixture-send-outs`; 23 `fixture-archive` (and `tools/tests/test_partners.py`,
  which loads it); 24 `fixture-reports`; 25 `fixture-housing`,
  `fixture-portal-scope`, `fixture-lab`; 27 `fixture-clinic-load`; 34
  its four.
- **Shared lists**, the second to merge taking `v0.5-w5` in first:
  `bricks/postgres/docs/gm.md` "Supported faults" (23, 24, 25: each its
  rows, the first amending the "`0.4.0`" sentence);
  `bricks/scheduler/docs/gm.md` "Supported faults" (22, 24, 25); the
  root `README.md`'s fault table (22 to 25) and brick table (34).
  `bricks/bastion/docs/gm.md` is chunk 23's alone.
- **Order**: 34 and 35 running; 22, 23, 25 and 26 can start at once
  on what does not wait for chunk 36; 24 once a slot frees. Waiting for
  chunk 36's merge (if inserted): 22's fa issue in a fixture, 24's s3
  (its format check, overlay and run), 25's s10 (its format check and
  fixture), 26's false-alarm and `inject` lines; chunk 27 for all.

**Choices made here, not in the spec** (for the driver's review): the
13 marked **(choice)** above, items 0 to 4, and chunk 36's scope
(Preflight corrections, item 1).

### Preflight corrections for spec-writer

1. **Three fault forms the loader cannot express; no chunk** (W5
   "What the sources leave short", items 1, 3, 4). Proposal: an
   inserted **chunk 36** for a `coding-executor`, cut from `v0.5-w5`
   now: (a) a `state` script run on another node: `injection.scripts[]`
   items may be `{script: <path>, on: <parameter>}`, the parameter a
   required one whose value names a node of the topology, whose brick
   `applies_to` names; `gmctl inject` (and `inject --at`) streams that
   script there under the same contract (s3); (b) `injection.kind:
   topology`, planted at render by the scenario's topology, no seed
   change, script or parameter, valid only with `option_absent` (s10);
   (c) a false alarm: an issue with `covers: []` and
   `expected_resolution: report`, accepted when the answer key's
   `false_alarms:` lists it (`issue`, `why`, `evidence[]` as an
   instance's, `acceptable`), counted in no score or cap. Files
   `tools/gm/{model,inject}.py` (and `aging.py` if `--at` plants
   apart), `tools/tests/{test_model,test_inject}.py`, the
   `scenario-format` skill (`SKILL.md`, `templates/{fault,scenario,answer-key}.yaml`);
   Done when each acceptance and refusal is shown by a unit test (a
   script on another node, its parameter naming no node or a node whose
   brick `applies_to` omits refused; a `topology` fault without
   `option_absent` refused; `covers: []` without a `false_alarms:`
   entry, or with another resolution, refused). Edges `36 ──> 22` (fa's
   issue), `36 ──> 24` (s3), `36 ──> 25` (s10), `36 ──> 26` (merge
   order: the false alarm and `inject` lines), `36 ──> 27`. Wave 5 then
   holds nine chunks. Fallback: (b) and (c) in chunk 22 and (a) in
   chunk 24, with 25 waiting on 22's merge: serialises three chunks.
   formats.md ("Fault definition", "Scenario") and master spec 6.3, 6.4
   carry them after the gate: a gate row **G19** like G18, `spec-writer`'s,
   blocking release gate item 6.
2. **s8's witness and reading** (W5 item 3): with a one-hour delay the
   standby has replayed to 00:30 when the 01:30 feeder runs, so its day
   is complete; the 00:30 feeder (`feed-daily-figures`) misses the
   commits after 23:30, and every feeder misses entries made late for
   yesterday. And "the replay lag at an hour" reads only after an hour
   of the delay, never in a short test or G13's thirty minutes.
   Proposal: master spec 17.2, 17.3 and 18.3, the test selection and
   chunk 24's Done when: present, the delay in effect, WAL received and
   not replayed, the feeder's day missing the rows committed within the
   hour (in the short test, late entries the test records after T0);
   the game's witness the 00:30 feeder. The class (an hour, "for
   safety") unchanged.
3. **s10's fix** (W5 item 4): "the option chosen and the node
   redeployed" creates nothing on an existing `pgdata` (`postgres`'
   GM notes), and players read no service credential (access model 5).
   Proposal: s10's resolutions `report` and `propose`; 17.3's fixed
   reading "the role the option brings created on `lab` with the game's
   monitoring password, as the option's initdb step does (the GM
   applying the accepted proposal), the exporter's metrics present";
   chunk 25's Done when likewise.
4. **s5's calibration** (W5 item 4): the portal copies every ownership
   (vet-portal's `derive.sql`), so without `until_at IS NULL` every
   former owner with an account sees every animal sold, not only the
   day's. Proposal: master spec 17.2, the test selection's calibration
   and vet-portal's document read "planted a few hours before T0, so
   former owners have had hours, not days, to look"; the class M
   unchanged.
5. **Chunk texts to the code** (W5 items 0 to 3): chunk 24 and master
   spec 18.2's reports row: T0 about 00:10 local, any day, a herd
   treatment recorded when the load holds none (as built, D435's
   fixture); chunk 23's Files gain `.claude/skills/data-register/SKILL.md`
   (T307's `where` item) and `tools/tests/test_partners.py`, its scope
   vet-core composed on the archive fixture with its register; chunk 25
   `fixture-lab` without a domain or Prometheus; chunks 22 to 25 the
   `planted/<fault-id>/` overlays; chunk 26's scope gains the false
   alarm and the `inject` rows (after chunk 36).

### Questions for the owner

None. The test selection is the spec's, and selecting a game's faults
is the GM's (master spec 17.1, the owner's standing word): s8's witness,
s10's resolution and s5's wording are the spec's to correct (Preflight
corrections, items 2 to 4), none changing a class or what players see
in kind. For the owner's information: if chunk 36 is inserted, wave 5
holds nine chunks, three past the model's six.

### G11.3 and G11.4 — dependency preflights (security-advisor, 2026-11-12)

Both CLEAR; nothing for the owner to rule.
- **G11.3**: the first route. Grafana 13.3.1 (2026-11-10, build 42849527790) bundles the
  Prometheus data-source plugin at 13.2.5 (brotli 1.2.7: GO-2026-6888 fixed).
  `https://dl.grafana.com/grafana/release/13.3.1/grafana_13.3.1_42849527790_linux_amd64.tar.gz`,
  sha256 `6acf8939dd2f73332cbcafc27a33973fb1115b8867e7ffa3223c6e2ecbed8531`. Same archive
  layout as 13.3.0 (trim step and go-sbom unchanged but the pins). Its Go modules as at G9
  but x/net 0.61.0 -> 0.62.0 (GO-2026-6860/6866 leave the binary); nothing new. 13.3.1 also
  fixes six Grafana CVEs (NVD 2026-11-11), none reachable here. `grafana` stays 0.3.0 (D458).
  The catalogue plugin 13.2.6 exists; not pinned (no security reason).
- **G11.4**: Prometheus 3.16.0 (2026-11-05; no 3.16.1 yet),
  `https://github.com/prometheus/prometheus/releases/download/v3.16.0/prometheus-3.16.0.linux-amd64.tar.gz`,
  sha256 `68727009472a2c02e1ff7f062fd5b3e637285bffc8fc2d340c76fb449d6e0f34`; go1.27.3;
  klauspost/compress 1.20.3 (GO-2026-6865 fixed), grpc 1.84.0 (GHSA-2v4p-qf9q-27wj fixed);
  nothing new and reachable. The run file's flags unchanged in meaning; `promtool check config
  --syntax-only` passes all 8 seed files; `runtimeinfo.storageRetention` form unchanged;
  `/-/ready`, `/api/v1/status/runtimeinfo`, `/metrics`, SIGHUP reload unchanged.
- Noted, not blocking: GO-2026-6859 (Go stdlib < 1.27.4, net/http MaxBytesReader race) is in
  every Go SBOM, already in SECURITY_TODO.md (2026-11-11), untriaged; neither candidate fixes it
  (both go1.27.3). Leaving the 3.13 LTS line means following minor releases (D446 accepted it).

### Chunks 35 and 34 dispatched, 2026-11-12

Chunk 35 (`coding-executor`, worktree `db_audit_gm-wt/v0.5-c35-planted-data`)
at the wave's start, its capture spec D451. Chunk 34 (`coding-leader`,
`db_audit_gm-wt/v0.5-c34-monitoring-images`, 34a then 34b) once G11.3
and G11.4 cleared, its W5 item settled by them. Two chunk owners at
work; 22 to 26 take the next slots.

### W5 reviewed by the driver, 2026-11-12

Capture W5 (807c794) accepted as drafted, its 13 **(choice)** points
included: the ids and families of item 0, seed changes on composed nodes
in `compose/<node>/`, the existing fixtures kept unfaulted with each
fault planted from a `planted/<fault-id>/` overlay, a feeder's day
removed between the present and fixed readings, s10 never naming
`postgres-exporter`. Its five preflight corrections go to `spec-writer`
before any of 22 to 26 starts: chunk 36 inserted (a `state` script on
another node, `injection.kind: topology`, a false alarm with
`covers: []` and `false_alarms:`), with gate row G19 for formats.md;
s8's witness and present reading; s10's resolution (`report`,
`propose`) and fixed reading; s5's calibration wording; the chunk texts
brought to the code. No owner question; the owner is told of the ninth
chunk in the report.

### Plan v16: W5's corrections applied, chunk 36 inserted, 2026-11-12

`spec-writer` at c2edbc6 (D459–D464, the driver's acceptance of W5's
preflight corrections): chunk 36 inserted (the loader's three fault
forms: a `state` script on another node, `injection.kind: topology`, a
false alarm with `false_alarms:`), gate G19 (formats.md and master spec
6.3, 6.4 after the gate); wave 5 at nine chunks (D460); s8's witness the
00:30 feeder (D461); s10 resolved by *report* or *propose*, its fixed
reading the GM applying the proposal (D462); s5's calibration "hours,
not days" (D463); chunks 22 to 26 brought to the code and W5 (D464).
**Chunk 36's peek** (no intent register): its files are
`tools/gm/{model,inject}.py` (and `aging.py`), their tests and the
`scenario-format` skill, held by no running chunk; `test_model.py`
shared with chunk 34's tag lines (the second to merge takes `v0.5-w5`
in); no data, no dependency (no G11 row). It takes the first free slot,
ahead of 22 to 26.

### Chunk 34 merged (09fa2ee), 2026-11-12

34a `5781fff`: `grafana` 0.3.0 on Grafana 13.3.1, bundled plugin 13.2.5
(brotli 1.2.7); 34b `2ddb34a`: `prometheus` 0.2.1 on 3.16.0, the three
monitoring scenarios, four fixtures, three `prometheus-*` faults, smokes'
`IMAGES=`, `test_model.py`/`test_render.py` re-pinned. Stack tests:
grafana 130/130 (171 s, on prometheus 0.2.1), prometheus 131/131 (79 s);
smoke-monitoring 43 (49 s), smoke-monitoring-v05 27 (~148 s),
fernway-clinics-monitoring 18 (33 s), tarnbeck-outdoor-campaign 33
(283 s, verdicts as wave 4), tarnbeck-outdoor-shop 26 (804 s); unit
suite 1227 OK; SBOMs match the advisor's candidates. For the gate: the
READMEs' pin lines were hand-edited, so each is compared to a fresh
regeneration. G11.4's post-change check dispatched. Chunk 36 takes the
slot.

### G11.4 — post-change check (security-advisor, 2026-11-12)

CLEAR over chunk 34 as merged; `.tech` at 982ebe0. The built images'
binaries match their SBOMs; `prometheus` 0.2.1's `dpkg-query` list is
identical to 0.2.0's (126 packages), `grafana` 0.3.0's 129. Fixed:
GO-2026-6888 (plugin), GHSA-2v4p-qf9q-27wj and GO-2026-6865
(prometheus, promtool), GO-2026-6860/6866 in `grafana.cdx.json` only
(Prometheus 3.16.0 keeps x/net 0.61.0, no x/net/html symbol linked).
Pre-existing, none reachable: GO-2026-5932, GO-2022-0635/0646,
GO-2026-6859 (Go < 1.27.4, untriaged in SECURITY_TODO.md). For the
owner, informational: CVE-2026-110289 (Grafana Git Sync SSRF by an Org
Admin, 2026-11-11, no fixed range yet) is listed in `.tech` to watch;
no Git Sync here and the Org Admin is the players' own account.

### Chunk 36 merged (1fb6e49), W5-h, 2026-11-12

`41dc320`, merge `1fb6e49`; unit suite 1252 OK, 2 skipped; every
scenario and fixture loads. Outside its Files: `tools/gm/restart.py`
(`plant_everything` unpacks `inject_plan`'s node; W5 item 9 gives
`tools/gm/*.py` to 36). Three choices, confirmed by the driver: a false
alarm's `acceptable` is one string (as `tooling_expectations`); the
`on:` node's brick must be in `applies_to` at its version (as the
instance's node); a topology fault takes no `seed_changes`, `scripts`
or `parameter_changes` but may declare `parameters:` for its check.

**W5-h, as built** (read by 22, 24, 25, 26, 27):
- (a) `injection.scripts[]` item: a bare path or
  `{script: <path>, on: <parameter>}`, no other key; the parameter
  declared with `required: true`; in the scenario its value (else the
  default) names a topology node whose brick at its version
  `applies_to` names. `inject_plan` returns `(script, text, node)`; the
  script runs there with the same `run_as` and `FAULT_*`, in the fault's
  order, from `inject`, `inject --at` and `restart`'s replant; a node the
  game lacks refused before anything runs. Helpers `model.script_on`,
  `script_path`, `script_node`.
- (b) `injection.kind: topology`: needs `option_absent`; `stage` `seed`
  or absent; no `seed_changes`, `scripts`, `parameter_changes`;
  `run_as` still required; the instance's node must not choose the
  option. `inject` lists it under `InjectResult.topology` and runs
  nothing; `inject --at` refuses it.
- (c) false alarm: an issue with `covers: []` must expect `report` and
  have one entry in `gm/answer-key.yaml`'s optional, non-empty
  `false_alarms:`: `issue`, `why`, `evidence[]` (an instance's form,
  `where` checked), `acceptable` (a string). Refused: an entry for no
  issue, for an issue covering a fault, twice. Never counted in
  `difficulty.score` or the cap. Helper `model.false_alarm_ids`.
Chunk 22 dispatched in the slot.

### Chunk 35 merged (e1dd102), W5-g, 2026-11-12

`7d05eb6`, merge `e1dd102`. (a) vet-core's load raises each batch's
`quantity_received` (only when short) to its history's draws plus, in
date at `load_epoch`, 30 days of average use (one unit at least),
rounded up to ten; the load's check block fails on a receipt below its
draws; receipts now up to 3 550 (mean 1 338). (b) purpose 8's history
plants `AMU<year>-NNNN` (the stub's count in posting order, the
`regulatory_submissions` copy alike), purpose 9's `HO<YYYYMM>-NNNN`;
the sweep corrected vet-lab's planted `lab_notifications.authority_ref`
(`VS-<year>-…` to the live `N<year>-<6 digits>`, the digits the order
test's id so no planted value repeats a live one; driver confirmed);
the centres', practices' and external lab's references already matched.
Figures: vet-core load +2 139.1 s, shift 0 120.6 s, 49 MB (busy host;
the unchanged load 139.9 s there); vet-lab 84-88 s, 54 MB;
`check_domain_dir` clean on both; 0 of 1 260 balances below zero;
fixture-reports 95/95 (948 s, the forms and balances asserted),
fixture-core 40/40 (277 s), fixture-clinic-load 23/23 (1115 s); unit
1227 OK (before 36's merge).
For the gate: fixture-exchanges (asserts a non-null `authority_ref`)
reruns on the merged branch. **Minor, for spec-writer with G19**: the
stubs' live counters restart at 0001 after the planted series (no
repeat, the year or month is in the reference, but a player may see the
count not continue); a gate fix could seed the stubs' counters. Chunk
23 dispatched in the slot.

### Chunk 23 — stopped on a loader gap (WIP 009b864), 2026-11-12

Everything built and checked but one loader gap: `load-data` rewrites
`composition.yaml`'s `coherence:` key (formats.md, "Loading a composed
domain"), a file the true register digests (`register_inputs`), so any
deployed scenario with a register reads stale after its load and
`inject`/`start-load`/`check` refuse it. With `composition.yaml`
restored after `load-data` (a temporary workaround, not committed):
`run-planted-test.sh` (s2+s6) 30/30 (161 s), `run-short-test.sh` 45/45
(527 s). Unit suite 1256 OK. Branch `v0.5-c23-archive-faults` at
009b864, worktree kept. **Driver's decision**: the register's digest of
`composition.yaml` leaves out its `coherence:` key (the result never
feeds the register; the format's two records of it kept); option (b),
the result in `state.yaml` only, rejected. `spec-writer` records it and
inserts chunk 37 (a `coding-executor`); 23 resumes from 009b864 with a
fresh owner once 37 has merged, reruns both archive tests without the
workaround, and merges. Chunk 23's own choices accepted by the driver:
the `data-register` skill's three rules (copies on entries only, never
internal lines; cold storage's recipient form; an emptied diff value
written as the handout words it, "no one"); the s2/s6 interaction
recorded as `conflicts-with`; s6's check reading the players' home
copy (its gm.md notes a player's edit flips it; the verdict is
`register_diff` at the final answer).

**W5-b, as built (chunk 23, pending its merge)**: s2
`pg-archive-command-silent` (backups, high, `postgres` 0.5.0; aging 1 h,
`archive_timeout`): one line in `nodes/records/postgresql.conf`,
material `inject/postgresql.conf.snippet`; sealed check reads
`pg_stat_archiver` (`check-psql`) and the vault's
`GET /manifests?type=wal&source=<host>&from=<day before>` (Perl
`HTTP::Tiny`, target from `/run/gm-vault/target`): 0 the last archived
segment has a manifest, 1 not (naming the latest by `received_at`), 3
nothing archived yet, 2 unreadable; D382 a setup limit in the answer
key. s6 `governance-register-flow-undeclared` (security, medium,
`bastion` 0.5.0): parameter `recipient` (default `Cold Storage`),
*propose* only; sealed check `awk` over `/home/player/data-register.md`'s
`###` entries, case-insensitive. Fixture: instances `s2` (records), `s6`
(bastion), both at render, read after T0; overlays merged by
`planted/merge.py` (s2 then s6; output byte-stable, s6's overlay holds
the register generated for that merge); vet-core at `records/clinic`,
hand-written `composition.yaml` leaving out `pms`, `api/clinic-api`,
`partners/centres`; 6 register entries, each copy "cold storage (WAL
archive, nightly base backup)" and recipient `{Cold Storage, [the whole
instance, archived], processor: true}`; filler in database `fill`.
For chunk 27: that recipient and copy form; `register_diff` values in
the handout's words, an empty `shared_with` written "no one"; the base
backup through `partners-api` at 0.25 CPU took ~300 s for ~100 MB.
Shared lists: `postgres`' "Supported faults" (s2 row, the "`0.4.0`"
sentence amended), the root README (31 faults), `bastion`'s section
rewritten. Noted: `load-data` loads vet-core's other-centres data and
the `centres` role onto `partners-db` though that producer is left out
(existing behaviour, harmless here; for the gate's eye).

### Plan v17: chunk 37 inserted (D465), its peek, 2026-11-12

`spec-writer` at 69bd80d: D465 (the register's digest of
`composition.yaml` without its `coherence:` key), chunk 37 inserted
(`tools/gm/{model,coherence}.py`, their tests, the `data-register`
skill's `SKILL.md` and `template.md`), G19 extended (formats.md and
master spec 6.2), wave 5 at ten chunks; chunk 23 `blocked (on chunk
37)`. **Chunk 37's peek** (no intent register): `tools/gm/*.py` held by
no running chunk (36 merged; 22 touches none); the `data-register`
skill shared with the stopped chunk 23, which takes `v0.5-w5` in after
37 merges; no data, no dependency. Dispatched to a `coding-executor`.

### Chunk 22 merged (722ffb5), W5-a, 2026-11-12

`69dede1`, merge `722ffb5`; unit suite 1260 OK on the merged branch
(`tools/tests/test_planted.py` new, 8 tests). Short tests: s1
`fixture-orders/run-planted-test.sh purpose-urgent-priority-dropped`
21/21 (1193 s, load-data 453 s beside other work); s4 22/22 (529 s,
after a first run failed on the delay, below); fa
`fixture-send-outs/run-false-alarm-test.sh` 9/9 (514 s).

**W5-a, as built**: s1 `purpose-urgent-priority-dropped` (rules, high)
and s4 `purpose-retry-without-key` (data-flow, medium), seed-file on
`interfaces`, `applies_to` `scheduler` 0.3.0 and purpose
`vet-lab-centre-orders`, optional parameters `source`, `lab`, `job`;
sealed checks `judges: runs`. Each `material` is
`inject/lab_orders.py.diff`, a one-line-context unified diff against the
purpose's `runner/scripts/lab_orders.py`; the two apply in either order
(`test_planted.py`). **Chunk 27** applies both with `patch -p1` from
`compose/interfaces/` (or `tools/tests/planted.py`'s `apply_diff`), then
reruns `gmctl compose`. s1 keeps the `-urgent` reference and sends
`routine`; s4 suffixes a retried reference `-HHMM`. s1's aging minimum
0m from the first urgent order (raise the instance's); s4's unbounded in
effect (needs an answer slower than the runner's timeout). Backlogs: s1
the `-urgent` references routine and unreleased at the lab (W5 item 1's
"`-routine`" wording corrected); s4 the `-HHMM` twin orders. Overlay
helper `tools/tests/planted.py` (appends instances, issues,
`false_alarms`, etc.; reusable by 24, 25). fa: issue `I1`, `covers: []`,
its `false_alarms:` entry naming the PCRSA panel (96 h; the load holds
72 h PCRs genuinely late on day four), committed in `fixture-send-outs`.
Deviations accepted by the driver: s4's delay held by `EXCLUSIVE` locks
on `lab_orders`, `lab_samples`, `lab_order_tests` in turn (~12 s; one
lock trips lab-api's 5 s `statement_timeout`, a 503 and rollback); s1's
raised emergency rates kept but the test places its urgent
consultations (`consultations.close` at 25 min at the earliest); the
fixture overlays carry no issue (`interfaces` is `no-access` there).
**For spec-writer before chunk 27**: s4's reading at hand-over in the
clinic (too-soon without planted slowness; `at_handover` allows 3 only
when masked). Noted: `lis` again released no urgent test within 5
minutes; the lock-slot slip at 12:36 (a waiter matched "done" in another
reservation), no harm. Chunk 24 dispatched in the slot.

### Chunk 37 merged (cd660dd); chunk 23 resumed, 2026-11-12

`0dca23f`, merge `cd660dd`; unit suite 1258 OK (before 22's tests were
counted together; 84 register and coherence tests OK on the merged
branch). `model.coherence_span(lines)` is the one finder of the
`coherence:` span (`coherence.rewrite_record` calls it);
`model.register_digest(rel, path)` digests `composition.yaml` without
it, every other input as `file_digest`. The `data-register` skill's
step 3: "`sha256sum <file>`, except `composition.yaml`, digested
without its top-level `coherence:` key …: `python3 -c 'from tools.gm
import model; print(model.register_digest("composition.yaml",
"<dir>/composition.yaml"))'`". Risk: a `composition.yaml` without a
final newline reads stale once when the record is appended (none such
in the repo). Chunk 23 resumed by a fresh `coding-leader` from WIP
009b864, its branch taking `v0.5-w5` in first.

### Chunk 23 merged (2282aac), 2026-11-12

Fresh owner from WIP 009b864, after chunk 37: the WIP squashed into
`b8be1df`, merge `2282aac`. With no workaround: `run-planted-test.sh`
(s2+s6) 30/30 (175 s), `run-short-test.sh` 45/45 (563 s); registers
current with the loader (no `coherence:` key in the fixture's
`composition.yaml`), none regenerated. Unit suite 1270 OK. Integration
fix accepted: chunk 22's `test_planted.py` sweep skips `__pycache__` and
any fixture whose `planted/` brings its own `merge.py` (s2's and s6's
overlays load only together; `test_partners.TestArchivePlanted` covers
them). Root README: 33 faults. W5-b stands as logged. Risk: s6's
overlay register is tied to `merge.py`'s output byte for byte; an edit
to the fixture or its fragments needs it regenerated (the test catches
it). Chunk 25 dispatched in the slot.
