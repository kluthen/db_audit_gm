# vet-lab-centre-orders — GM notes

Purpose 1 of v0.5 (master spec 12.2;
v0.5's `clinic-purposes.md` section
5; capture W4 items 0 and 3). A **round trip** inside the centre, the core
asking: the practice software records a consultation's analysis requests in
`clinic`; the integration engine posts them to the lab's order API,
`lab-api`, as the centre's account 1 (never charged), and copies the
released results' state back into the record. The lab never writes
`clinic`. Fits `vet-core` and `vet-lab`.

## Parts and jobs

| Part | The clinic's | |
|---|---|---|
| `source`, `target` | `records/clinic` | the requests and consultations read, the requests' state and the purpose's `ops` tables written, as `vet_interfaces` |
| `runner` | `interfaces` (scheduler, role `transformer`) | the two script jobs below |
| `api` | `lab-api` | called with the credential `lab_centre` (the centre's account) |

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `post-lab-orders` | `* * * * *` | `scripts/lab_orders.py:post`, `source` as `vet_interfaces`, `api` with `lab_centre` | the requests still `requested` whose consultation has closed (or been signed), grouped by consultation and priority, urgent first; each group `POST /orders` with `client_ref` `C-<consultation>-<priority>`, its tests carrying the requests' ids, a residue screening (`MINH`) the animal's latest withdrawal end; the read's transaction ended before the calls; after them one transaction: the requests `sent`, the run's `ops.runs` row, each attempt in `ops.lab_orders_sent` |
| `fetch-lab-results` | `*/5 * * * *` | `scripts/lab_orders.py:fetch`, the same connections | `GET /orders?account=1&released_since=<watermark - 15 min>`; each request on a test of the feed copied once into `ops.request_results` and moved from `sent` to `resulted` (released) or `cancelled` (not performed, cancelled by the lab: the reason in the copy); the watermark to the latest (time, `order_test_id`) read; a request `sent` unanswered past its test's turnaround plus two hours, one `ops.incidents` row (`kind` `overdue`, `ref` the request id), once |

`lab-api` answers the same `client_ref` again with the same accession (200,
nothing written), so a timed-out post is simply posted again at the next
run. The feed is read back 15 minutes before the watermark: a release
committing after its `released_at` is never missed, the copies' primary key
keeping each request once. A `sent` request from the history maps by the
feed's `request_id`, so no planted ledger is needed (W4 item 3); the
watermark starts at `load_epoch` (the DDL).

## What the material holds

- `material/runner/`: `interfaces`' `jobs.yaml`, `queries.yaml`,
  `schedule.yaml` (connections `clinic`, `lab-api`) and
  `scripts/lab_orders.py`; the GM copies them into the runner's scenario
  layer (`compose/interfaces/`), `gmctl compose` writes the node's files.
- `material/target/ddl.sql` (`ddl.target`): the `ops` schema (the shared
  block, byte-identical in every purpose, `tools/tests/test_purposes.py`),
  `vet_interfaces` (guarded, `LOGIN`, `CONNECT` on `clinic`), its grants
  (`requests` read, `UPDATE` on its four state columns only;
  `consultations (id, state, ended_at)`; `administrations (id, animal_id,
  prescription_line_id)`; `prescription_lines (id, withdrawal_ends_on)`;
  the `ops` tables), `ops.lab_orders_sent` and `ops.request_results`, the
  watermark `lab-results` at `load_epoch`. Read by `load-data` at step (2b)
  from the catalogue, in the database the scenario maps `target` to.

## Trace and checks

`ops.lab_orders_sent`, `ops.request_results`, `ops.watermarks`,
`ops.incidents`, `ops.runs` (each row's `run_id`, the run's `id`) and the
runner's log (each call's `http job=...` line). Outside the trace, as
evidence: `requests`' state and times in `clinic`; on the lab's side the
account 1 orders and their tests' `request_id`.

Every check runs on the runner node, `interfaces`, as root, with
`CHECK_SINCE`: the judged moment from `check-runs since`, `clinic` and `lab`
through `check-sql` as `gm_check` (W4 item 0).

| Invariant | Judged | Check | Witness |
|---|---|---|---|
| LO1 sent within 5 minutes of the close, 2 urgent, or cancelled | triggers | `checks/lo1-sent-in-time.sh` | a consultation closed with analysis requests, its deadline passed |
| LO2 each request id on one lab order test | runs | `checks/lo2-one-order-test.sh` | a `post-lab-orders` run and a centre order since the judged moment |
| LO3 each release `resulted` within 10 minutes, none `resulted` unreleased | runs | `checks/lo3-resulted-on-release.sh` | a centre test released at least 10 minutes ago |
| LO4 end to end, each test answered within turnaround plus the next round (urgent: turnaround) | end-to-end | `checks/lo4-orders-answered.sh` | a centre order with every test answered |

LO4 is the round trip's one `end-to-end` invariant: judged on the trace
after the fix, wherever the players fixed it. The orders a fault left stuck
before the fix are the answer key's backlog, never the purpose's.

## Candidate faults (traps; a scenario's are the GM's to select)

| Candidate | What the players find | Fixed on |
|---|---|---|
| Requests marked `sent` before the call returns, in a transaction committed first | requests `sent` with no lab order behind them: results that never come (LO4) | the runner's script |
| The priority dropped in the mapping | urgent tests posted routine, waiting for the round (LO4) | the runner's script |
| A retry under a new `client_ref` (`purpose-retry-without-key`) | two lab orders for one consultation (LO2) | the runner's script |
| The watermark taken from the run's start, or from the latest time read with no margin, while a release commits later | a few requests stuck `sent` though released (LO3) | the runner's script |
| A technically validated test read as final | requests `resulted` before release (LO3) | the runner's script |
| `post-lab-orders` at `*/15` or on business hours only | the night's emergencies posted in the morning (LO1) | `jobs.yaml` |
| `lab-api`'s idempotency lookup on `client_ref` alone, unindexed | every post slower as `lab_orders` grows | `lab-api`'s `db/` |
| `vet_interfaces` granted `UPDATE` on all of `requests` | a grant beyond the state columns (minor) | the grants |

## Data moved

`requests.animal_id` (customer-linked in `clinic`) reaches
`lab_orders.animal_id`, which the lab's identity job makes personal there;
no name, contact or identifier leaves the core with the order (the lab
reads them through the lookup API). The purpose's `ops` tables hold ids,
times and statuses only, all `internal` (its `classification:`).
