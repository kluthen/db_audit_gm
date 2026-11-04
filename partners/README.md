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
own). Cold storage, the vault, joins them
as one more partner (`coldstore/`, next).

| Path | What | The GM copies it |
|---|---|---|
| [`shared/nodes.yaml`](shared/nodes.yaml) | the three nodes' declarations, sized as master spec 14 (0.45 CPU, 448M reserved) | into `scenario.yaml`'s `nodes:`, the seed paths and `partners-db`'s `data:` filled; the three listed under each `third_parties:` entry with nodes |
| [`shared/partners-db/`](shared/partners-db/) | `pg_hba.conf` (the partners' roles alone, below), `postgresql.conf` (small: 32MB buffers, 40 connections), `data.sql` (creates `partners`, ends connected to it) | as `partners-db`'s seed files and the start of its data file |
| [`shared/partners-backend/`](shared/partners-backend/) | the back end's base: `schedule.yaml` (`intensity`, no stream), `queries.yaml`, `jobs.yaml` | as `partners-backend`'s seed files, each partner's fragments joined |


A domain's own partners join the same nodes through `gmctl compose`
(`producers/partners/<prefix>/`: its back-end fragments onto
`partners-backend`, its `api.yaml`, `routes/` and `db/` onto
`partners-api`); `load-data` runs its `data.sql` in `partners` (chunk 8).
The fixtures [`fixture-partners`](../tools/tests/fixtures/fixture-partners/)
(two sample partners) is such a copy;
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

The form joins `bricks/postgres/docs/gm.md` at wave 2's gate.

## Known limits

- One partner's slow answers hold none of the others' while the server's
  40 worker threads last: past 40 requests in flight to slow partners, a
  further request waits for a thread (measured, W2-f). A caller's pool
  bounds what it keeps in flight.
- Every partner calls from `partners-api`'s address (one network).
