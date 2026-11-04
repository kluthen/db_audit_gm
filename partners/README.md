# partners/ — the partners' shared nodes and cold storage

GM material, never shipped to players. A catalogue folder beside
`domains/` and `purposes/` (v0.5 master spec 10.2, 10.4, 11.2; capture W2
item 6 and its as-built addendum W2-f in
[`specs/versions/v0.5/wave-log.md`](../specs/versions/v0.5/wave-log.md)).
Every third party of a scenario with nodes runs on **three shared nodes**,
all `no-access`: `partners-api` (one `api` node serving every partner under
its own hostname, a network alias), `partners-backend` (one `scheduler`
node, the merged back end, its schedule hidden) and `partners-db` (one
small `postgres` database, `partners`, each partner's tables and role its
own). Cold storage, the vault, is one partner among them, belonging to no
domain: it serves the `postgres` brick's archiving in any scenario and the
clinic's purpose 14.

| Path | What | The GM copies it |
|---|---|---|
| [`shared/nodes.yaml`](shared/nodes.yaml) | the three nodes' declarations, sized as master spec 14 (0.45 CPU, 448M reserved) | into `scenario.yaml`'s `nodes:`, the seed paths and `partners-db`'s `data:` filled; the three listed under each `third_parties:` entry with nodes |
| [`shared/partners-db/`](shared/partners-db/) | `pg_hba.conf` (the partners' roles alone, below), `postgresql.conf` (small: 32MB buffers, 40 connections), `data.sql` (creates `partners`, ends connected to it) | as `partners-db`'s seed files and the start of its data file |
| [`shared/partners-backend/`](shared/partners-backend/) | the back end's base: `schedule.yaml` (`intensity`, no stream), `queries.yaml`, `jobs.yaml` | as `partners-backend`'s seed files, each partner's fragments joined |
| [`coldstore/`](coldstore/) | cold storage's stub, laid out as a domain's partner folder (`producers/partners/<prefix>/`, prefix `coldstore`): `api.yaml`, `routes/`, `db/` (its three endpoints), `schedule.yaml` and `queries.yaml` (its baseline stream), `data.sql` (its role, schema, manifests and state), `planted.sql` (the vault's history) | the endpoints onto `partners-api` (`compose/partners-api/` in a composed scenario), the fragments onto `partners-backend`, `data.sql` then `planted.sql` (its node list filled) after `shared/partners-db/data.sql` in `partners-db`'s data file, `coldstore` added to `pg_hba.conf`'s partners' line |

A domain's own partners join the same nodes through `gmctl compose`
(`producers/partners/<prefix>/`: its back-end fragments onto
`partners-backend`, its `api.yaml`, `routes/` and `db/` onto
`partners-api`); `load-data` runs its `data.sql` in `partners` (chunk 8).
The fixtures [`fixture-partners`](../tools/tests/fixtures/fixture-partners/)
(two sample partners) and [`fixture-archive`](../tools/tests/fixtures/fixture-archive/)
(cold storage and an archiving node) are such copies;
`tools/tests/test_partners.py` keeps them equal to this folder.

## A partner on the shared nodes

- **Its prefix** `[a-z][a-z0-9]{0,15}` (W2 item 0) is its folder's name,
  its role and schema on `partners`, its keys `<prefix>.<...>`, its
  endpoints `<prefix>_<...>` and its connections `<prefix>-<...>`. One
  folder may serve several hostnames.
- **Its database side**: its `data.sql` creates the role `<prefix>`
  (`LOGIN`, no password: render derives `role_<prefix>_password` from the
  connections naming it and mounts it on the partners' nodes only;
  `load-data` sets it), the schema `<prefix>` owned by it, its tables and
  its state. No partner reaches another's schema (each owns its own; the
  fixture checks it).
- **Its connections**: `<prefix>-db: {driver: sql/postgresql, target:
  partners-db:5432/partners, role: <prefix>}`, on `partners-api` and on
  the back end, each partner's pool its own.
- **A partner's state and its misbehaviour key**: the table
  `<prefix>.state (hostname, name, value, set_at, PRIMARY KEY (hostname,
  name))`, its baseline planted by its `data.sql`, read by its routes at
  each request; on the back end one stream per prefix, `{key:
  <prefix>.normal, connection: <prefix>-db, rate: 1/min, arrivals: even}`,
  upserting the baseline. A fault's key `<prefix>.<behaviour>` upserts
  other values; `placed: timeline` is a timeline change of
  `<prefix>.normal` to it at the planting moment, `placed: standing` the
  same at `T0`. The names in the state are each stub's own (cold
  storage's below; `fixture-partners`' `delay_ms`). A route reads its
  state, returns its session to the pool, then applies the behaviour
  (sleeps for `delay_ms`), so a slow partner holds one worker thread per
  request in flight and never a database session.
- **Ticks**: the back end calls a partner's own tick routes
  (`<prefix>_tick...`) on its hostname, with the one credential
  `partners_backend` (mounted on `partners-api` and `partners-backend`
  only); anyone else gets 401.
- **Out of reach**: no `player` account on the three nodes, none on the
  bastion's routes (cold storage's read-only route is chunk 17's), none
  in the starter pack; the partners' roles named by no other node.

## `partners-db`'s `pg_hba.conf` on one Swarm network (measured)

The form (W2 item 1; [`shared/partners-db/pg_hba.conf`](shared/partners-db/pg_hba.conf)):
the GM's DO NOT TAMPER `local` lines, then one line

    host    partners  <the partners' roles, comma-separated>    samenet     scram-sha-256

and last `host all all all reject`. No `host ... gm_check` line: the GM's
check role reaches every instance in scope, not the partners' (access
model 14); it still reads `partners` over the local socket.

Measured by `fixture-partners`' short test on armenelos, 2026-11-04
(Docker Swarm, one host; W2-f holds the figures):

- every other role is refused from the network by `pg_hba.conf` itself,
  with or without its password: `dba`, `postgres`, `gm_check`, and a
  partner's own role on any other database (`pg_hba.conf rejects
  connection for host ...`);
- `samenet` admits every task of the game's network and the host's
  `docker_gwbridge` (the server's two subnets, `10.0.1.0/24` and
  `172.18.0.0/16` in the run): a partner's role from the bastion, with
  the right password, gets in. **The guard is the password**, a secret
  mounted on the partners' nodes only, never on the bastion or a
  player's node (access model 13's known gap, now measured);
- through a node's name (its service's virtual address) every client on
  a host arrives from that host's load-balancer address on the network
  (the network's `<network>-endpoint`, `10.0.1.10` in the run): the
  bastion and `partners-api` look the same to the server. Only through
  `tasks.partners-db` does a client arrive from its task's address, and
  that address changes when the task restarts (`10.0.1.3` to
  `10.0.1.11`). No address form tells the partners' nodes apart;
- a host name never matches: Swarm's reverse lookup of a task's address
  names the task (`<game>_<node>.<slot>.<task id>.<game>_<network>`) and
  the load-balancer address has none, so `host partners <roles>
  partners-api scram-sha-256` refuses `partners-api` itself.

The form and these figures are also in `postgres`' GM notes,
[`bricks/postgres/docs/gm.md`](../bricks/postgres/docs/gm.md) ("The partners'
database: `partners-db`'s `pg_hba.conf`").

## Cold storage, the vault (`coldstore/`)

Hostname `cold-storage`, prefix `coldstore`, on `partners-api`
(cold-storage.md 3; master spec 10.4, 11.2).

| Endpoint | Credential | What it does |
|---|---|---|
| `POST /shipments` | `cold_storage` (the customer's one account key: `postgres`' `vault_credential`, purpose 14's connection) | headers `Shipment-Id`, `Shipment-Type`, `Shipment-Rows`, `Shipment-From`, `Shipment-To` (dates, inclusive), `Shipment-Source`, `Shipment-Name` (optional, the id when absent); the body streamed, counted and discarded (`wal` and `basebackup`: 1 row when non-empty; a data type: its non-empty NDJSON lines); a manifest written, the same shipment id from the same source again replacing that source's, from another source making a second; the receipt 201 `{shipment_id, type, rows_declared, rows_received, size, received_at}`, as `vault-post` checks it (W1 item 6). A header missing or malformed: 400 |
| `GET /manifests` | public | `?type=&source=&from=&to=` (each optional; dates `YYYY-MM-DD`, a manifest listed when its range meets `[from, to]`; a bad date 422): a JSON list in the order received (`received_at`, then `source`, then `shipment_id`) |
| `GET /` | public | an HTML page, one inline SVG chart per type over the last 35 days (today included, UTC), rows declared against received per day (a shipment on its range's first day), a day where they differ marked and named, a table under each chart; no script |

- **The manifest**: `coldstore.manifests (shipment_id, type, source,
  name, rows_declared, rows_received, size, date_from, date_to,
  received_at, PRIMARY KEY (source, shipment_id))` (spec D381). The
  source is the node holding the data (the archiving node for `wal` and
  `basebackup`, `machines` for purpose 14's types): two archiving nodes
  post the same segment names (each cluster starts at its first segment),
  and each keeps its own manifest. The same id from the same source
  replaces that source's manifest, `received_at` the new receipt's; the
  page sums the sources (counts per type and day).
- **Its state** (`coldstore.state`, host `cold-storage`): `delay_ms`
  (added before every answer) and `uploads` (`accept`, or `refuse`:
  `POST /shipments` answers 503, an outage); `coldstore.normal` restores
  `0` and `accept` once a minute. A fault's key `coldstore.<behaviour>` is
  its own material.
- **Planted** (`planted.sql`): for each archiving node the GM lists, the
  35 days before T0's day: its WAL segments (about `segs` a day, 16 MB
  each, received through the day) and its nightly base backup (at its
  crontab time, about `mb` megabytes). T0 is `load_epoch` when `load-data`
  passes it, else the moment the data file runs. The data types'
  manifests are their purpose's history (purpose 14), not this file's.
- **The body is never held**: an `async` dependency streams it and keeps
  only its size and line count (a base backup is the whole instance;
  the route itself is plain `def`, as the brick requires).

## Known limits

- One partner's slow answers hold none of the others' while the server's
  40 worker threads last: past 40 requests in flight to slow partners, a
  further request waits for a thread (measured, W2-f). A caller's pool
  bounds what it keeps in flight.
- Every partner calls from `partners-api`'s address (one network).
- The planted segment names start at log `0x40`, above a fresh cluster's
  live names: the history's names are higher than the live ones (spec
  D382). No check reads the manifests in name order: **a check finding a
  node's latest `wal` manifest orders by `received_at`, never by name**.
