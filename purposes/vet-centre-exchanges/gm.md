# Purpose 4, the exchanges with the other centres: GM notes

The centre's exchanges with the franchise's other centres (v0.5 master
spec 12.1, 12.2 purpose 4; [clinic-purposes.md](../../specs/versions/v0.5/clinic-purposes.md)
section 8; spec D285, D286, D293, D306, D438, D440): a **round trip both
ways**. The centre asks another centre for a transfer or an examination
its own machines or specialists cannot do (out); the other centres ask it
(in). The core records both in `exchanges`; the centre's integration
engine posts its requests, and its answers and reports to the centres'
requests, to the centres' stub; the centres answer, report and ask at the
purpose's endpoints on `clinic-api`, which only answer (D270). A
design-time source: copy the material into a scenario and adapt the names
there.

## What it is for

A franchise's centres share patients. An exchange may carry the animal's
identity, its record's summary and its current owner's name and contact,
inside the franchise, under its agreement (D293): nothing more. The other
centre answers within a working day (accepted with a date, or declined;
about one examination in ten declined), then reports an examination one
to three days after it. An outbound request unanswered a working day after
sending is resent once under the same key; after a second working day it
becomes an `ops.incidents` row for the requesting vets. Inbound, the
vets decide and report in the practice software (`pms`'s
`exchanges.decide` and `exchanges.report`); the engine posts each answer
and report to the asking centre within ten minutes. About one exchange a
day each way, business hours (D306).

## The material

Written for the clinic's mapping: `source` and `target` `records/clinic`,
`runner` `interfaces`, `api` `clinic-api`, `partner` `partners-api` (the
centres' three hostnames).

| File | Copied to | What |
|---|---|---|
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml) | the runner's `jobs.yaml` (scenario layer `compose/interfaces/`) | `sync-exchanges` `*/5 * * * *`, `chase-exchanges` `0 9 * * 1,2,3,4,5` |
| [`material/runner/queries.yaml`](material/runner/queries.yaml) | the runner's `queries.yaml` | `exchanges.sync` (batch 20), `exchanges.chase` (batch 50), script keys |
| [`material/runner/schedule.yaml`](material/runner/schedule.yaml) | the runner's `schedule.yaml` | connections `clinic` (`records:5432/clinic` as `vet_interfaces`, pool 2: the identical entry purposes 1, 5, 11 and 13 use) and `centres-central`, `centres-south`, `centres-abroad` (`http`, each centre's hostname, `centres_customer`); no stream |
| [`material/runner/scripts/centre_exchanges.py`](material/runner/scripts/centre_exchanges.py) | the runner's `scripts/` | `sync` and `chase` |
| [`material/api/clinic-api/`](material/api/clinic-api/) (`api.yaml`, `routes/exchanges.py`, `db/exchanges.py`) | the scenario layer `compose/clinic-api/`, merged with vet-core's `animals` and `stays` by `gmctl compose` | the endpoint `exchanges` behind `clinic_centres`, connection `clinic-exchanges` (`records:5432/clinic` as `vet_exchange`, pool 2) |
| [`material/target/ddl.sql`](material/target/ddl.sql) | nothing: `ddl.target`, read from the catalogue by `load-data` at step (2b) | the `ops` block, `vet_interfaces` and `vet_exchange` (guarded), `ops.exchange_messages`, the grants, the watermarks `answers` and `reports` at `load_epoch` |

The centres' stub is **not** the purpose's: a partner with streams of its
own stays in its domain, vet-core's
[`producers/partners/centres/`](../../domains/vet-core/producers/partners/centres/)
(prefix `centres`; hostnames `aldermoor-central` site 2, `aldermoor-south`
site 3, `aldermoor-abroad` sites 4 to 6), composed onto the partners' api
and back-end nodes by `gmctl compose`, its `data.sql` planting from
`core_exchange` the exchanges in flight at T0 as each centre holds them
(vet-core's [`docs/gm.md`](../../domains/vet-core/docs/gm.md), "partners/centres").
A scenario declares the three hostnames as three `third_parties:` entries
listing the partners' three nodes, and `centres` on the partners'
`pg_hba.conf` line.

**Names to adapt** when copying: the record's node and database (`clinic`
connection, `clinic-exchanges`, `CLINIC` in EX5, `CLINIC_NODE` and
`CLINIC_DB` in EX1 to EX4), the runner, the api node (`hosts:`), the
centres' hostnames (`HOSTS` in the script, the `CASE` on the site in
EX1's and EX2's SQL, both by site),
the partners' database node (where EX1 to EX4 run).

## The jobs

On the runner, `clinic` as `vet_interfaces`, the three centres' HTTP
connections as `centres_customer` (the stub dispatches by hostname).

- **`sync-exchanges`**, every five minutes. One read, its transaction
  ended before any call: the outbound requests still `requested` (oldest
  first, 20 at most), each with what the agreement lets it carry (EX4:
  the animal's identity, its last three closed or signed consultations'
  dates and findings, its current owner's id, name, e-mail and phone); the
  inbound exchanges answered since the `answers` watermark and reported
  since the `reports` watermark with no 2xx post of that kind yet. Then
  the posts (`POST /exchanges`, `.../answer`, `.../report` to the site's
  hostname: 2 `aldermoor-central`, 3 `aldermoor-south`, 4 to 6
  `aldermoor-abroad`). Then one transaction: its `ops.runs` row (counts
  known before it: the role inserts a run, never updates one), one
  `ops.exchange_messages` row a post (`direction` out, the HTTP status,
  none for no answer), each request taken marked `sent` with `sent_at`,
  each watermark moved to the oldest post still failing (or the read's
  time less ten minutes).
- **`chase-exchanges`**, at 09:00 Monday to Friday (a day-of-week list,
  W4 item 0). Working days are the customer's local dates, Monday to
  Friday: an outbound request `sent` and unanswered a working day after
  sending is resent once with the same key and body (`resend`); two
  working days after, one `ops.incidents` row (`kind` unanswered, `ref`
  the key), once. One transaction after the calls.

**The endpoints** (`clinic-api`, as `vet_exchange`, behind
`clinic_centres`): `POST /exchanges` files a centre's request as an
inbound exchange `received` (201; the same key again 200, nothing filed;
an unknown site 422); `POST /exchanges/{key}/answer` records a centre's
answer on one of the clinic's requests (404 for a key that is not one);
`POST /exchanges/{key}/report` its report on an accepted examination (409
otherwise). Each call writes one `ops.runs` row (`job`
`exchanges-endpoint`) and one `ops.exchange_messages` row (`direction`
in, `centre` the site's code) in the transaction of what it writes, the
exchange locked while read.

## The invariants and where they run

| Id | Judged | Runs on | Reads |
|---|---|---|---|
| EX1 | triggers | `partners-db` | the clinic's outbound requests (`--node records`), `centres.exchanges` |
| EX2 | end-to-end (the inbound trip, D440) | `partners-db` | `centres.exchanges` (the centres' own requests and what they hold), the clinic's inbound exchanges |
| EX3 | runs | `partners-db` | the judged runs' posts (`ops.runs`, `ops.exchange_messages`), `centres.messages`, `centres.exchanges` |
| EX4 | runs | `partners-db` | `centres.messages`' bodies as received, the record (animals, ownerships, owners, consultations) |
| EX5 | end-to-end (the outbound trip) | the runner | `exchanges`, `ops.exchange_messages`, `ops.incidents` |

A check on `partners-db` takes `CHECK_SINCE` as given (no runner there,
W4 item 0) and reads the clinic through `check-psql --node records`: the
record's node admits `gm_check` from the network. That node has no
Python (the `postgres` brick): EX1 to EX4 are shell, each side read in one
statement, handed to the other as a psql variable, the verdict computed in
SQL. EX5 raises it to the
runner's last reload. Every check guards its reads (spec D432): a table
with row security and no `gm_check_read` (or a restrictive policy naming
`public` or `gm_check`) exits 2. **The witnesses**: the exchanges in
flight at T0, planted on both sides (the clinic's `sent` requests and
accepted examinations; the centres' own `received` and accepted ones),
then about one a day each way. The 10-minute legs are two sync cycles; a
working day is the chase's.

## The faults this purpose carries

From [clinic-purposes.md](../../specs/versions/v0.5/clinic-purposes.md)
section 8 (the selection is the scenario's): `clinic-api`'s endpoint
answering 201 from a transaction it never commits (EX2 present at once:
the centre told "received", the clinic holding nothing; fixed on
`db/exchanges.py`); answers posted to the wrong centre, the site map off
by one (EX2: the stub answers 404, the asking centre never answered;
fixed in the script); an exchange carrying the owner's other animals'
records (EX4; the script's `RECORD`); a new key on the resend (EX3: the
centre holds one exchange under two keys; the script's `chase`).

## Trace

`exchanges` (the core's), `ops.exchange_messages` (each post either way),
`ops.incidents`, `ops.watermarks`, `ops.runs`, the runner's
`/var/log/scheduler/scheduler.log` (exchange ids, keys and statuses only)
and `clinic-api`'s `/var/log/api/api.log`; the centres' `centres.exchanges`
and `centres.messages` (evidence, out of the players' reach).

## Fixture

`tools/tests/fixtures/fixture-exchanges/` runs it with purpose 5 on eight
nodes; its short test posts and answers an outbound exchange, answers and
reports inbound ones within ten minutes, and reads every check fixed.
