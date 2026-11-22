# vet-lab-practice-results — GM notes

Purpose 2 of v0.5 (master spec 12.2;
v0.5's `clinic-purposes.md` section
6; capture W4 items 0 and 3). A **round trip the partner asks**: a
practice's back end (vet-lab's `practices` stub, 120 accounts on one
hostname) posts its order to the lab's order API, `lab-api`, and gets the
accession; the centre's half, the one that can go wrong, is delivering the
results to the practice's callback, which the integration engine does.
Fits `vet-lab`.

## Parts and jobs

| Part | The clinic's | |
|---|---|---|
| `source`, `target` | `lab/lab` | the practices' orders, tests, results and accounts read, `lab_callbacks` and the `ops` tables written, as vet-lab's `lab_dispatch` |
| `runner` | `interfaces` (scheduler, role `transformer`) | the script job below |
| `partner` | the partners' api node, hostname `practices` | every account's callback `http://practices:8000/results`, called with the customer's own key with the practices, `practices_customer` |

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `deliver-practice-results` | `* * * * *` | `scripts/practice_results.py:deliver`, `source` as `lab_dispatch` (connection `lab-dispatch`), `partner` with `practices_customer` (connection `practices`, 30 s) | the deliveries due on the practices' orders of the last 30 days: an **interim** when a test of a several-test order is released before the order completes, the **final** at completion, one **amended** per amendment (numbered in time order), each with no acknowledged attempt; posted four at a time, oldest event first, to the account's callback, keyed `delivery_key`; the order's references and each test's status, the results in force of its released tests only; one `lab_callbacks` row per attempt (HTTP status, none on a timeout; `acknowledged_at` on a 2xx); a key whose last attempt is under 5 minutes old waits; after six failed attempts one `ops.incidents` row (`kind` `undelivered`, `ref` the key), no seventh |

`delivery_key` is the history's: `md5('vet-lab-delivery:<order>:<kind>:<revision>')`
(vet-lab's `keys.sql`), so a delivery the history acknowledged before T0 is
never posted again, and one due between the history's end and T0 is
delivered at the first run. The stub acknowledges a repeated key again
without a second record (`practices.deliveries.repeats`).

## What the material holds

- `material/runner/`: `interfaces`' `jobs.yaml`, `queries.yaml`,
  `schedule.yaml` (connections `lab-dispatch`, shared with purposes 3 and
  5 under that name, and `practices`) and `scripts/practice_results.py`;
  the GM copies them into the runner's scenario layer
  (`compose/interfaces/`), `gmctl compose` writes the node's files.
- `material/target/ddl.sql` (`ddl.target`): the `ops` schema (the shared
  block, byte-identical in every purpose, `tools/tests/test_purposes.py`)
  and `lab_dispatch`'s grants on it. `lab_dispatch` is vet-lab's role,
  granted here, never created; it already reads the orders, tests,
  results, accounts and writes `lab_callbacks` (vet-lab's schema). No table
  of the purpose's own in `lab` (W4 item 3), no watermark.

## Trace and checks

`ops.incidents`, `ops.runs` and the runner's log (each call's `http
job=...` line). Outside the trace, as evidence: `lab_callbacks` (the
ledger: order, kind, key, attempt, posted, HTTP status, acknowledged) in
`lab`; the stub's `practices.deliveries` (key, account, accession, kind,
first and last receipt, repeats) on `partners-db`.

PR1, PR2, PR3 and PR5 run on the runner node, `interfaces`, as root with
`CHECK_SINCE`: the judged moment from `check-runs since`, `lab` through
`check-sql` as `gm_check`. PR4 runs on the partners' database node,
`partners-db`: the stub's deliveries through `check-psql`, `lab` through
`check-psql --node lab`, `CHECK_SINCE` as given (W4 item 0).

| Invariant | Judged | Check | Witness |
|---|---|---|---|
| PR1 each delivery a release made due acknowledged within 15 minutes, or in an incident after six attempts | triggers | `checks/pr1-delivered-in-time.sh` | a delivery made due at least 15 minutes ago |
| PR2 one `delivery_key` per order, kind and revision, kept across attempts | runs | `checks/pr2-one-key.sh` | an attempt since the judged moment |
| PR3 no unreleased result delivered: a final after completion, an interim after a release, an amendment after it is made | runs | `checks/pr3-released-only.sh` | an attempt since the judged moment |
| PR4 each delivery to its own order's account | runs | `checks/pr4-own-account.sh` (on `partners-db`) | a delivery the stub received |
| PR5 end to end, each order's final acknowledged within its tests' turnaround, the next round and 15 minutes | end-to-end | `checks/pr5-orders-delivered.sh` | a practice order received and delivered |

PR1 reads the spec's "each released test acknowledged in a final within 15
minutes" as the delivery each release makes due: a test released neither
first nor last on a several-test order makes none (it travels in the
final). PR3 judges by time: the stub keeps a delivery's key, account,
accession and kind, not its tests, so the check reads when each attempt was
posted against what the lab had released by then. PR5 is the round trip's
one `end-to-end` invariant: judged on the trace after the fix; the
deliveries a fault left undone before it are the answer key's backlog.

## Candidate faults (traps; a scenario's are the GM's to select)

| Candidate | What the players find | Fixed on |
|---|---|---|
| The callback joined on the wrong key (`lab_accounts.id` against the order's `practice_id`) | one practice receiving another's clients' results: a breach a practice reported (PR4) | the runner's script |
| Deliveries made one after the other with a long timeout | one practice's dead callback holding every delivery (PR1, PR5) | the runner's script |
| A new `delivery_key` on each attempt | duplicates at the practices after every slow answer (PR2) | the runner's script |
| Amendments never delivered (the query takes `final` only) | practices holding a superseded result (PR1) | the runner's script |
| No incident after the sixth attempt, the delivery dropped silently | released results a practice never got, nobody told (PR1) | the runner's script |
| A technically validated test sent as final | the release gate broken towards the practices (PR3) | the runner's script |

## Data moved

`lab_orders.patient_ref` and `client_surname` (personal in `lab`) and the
results go back to the practice that sent them only (the lab its processor
under GDPR Art 28); nothing of the centre's own orders. The purpose's `ops`
rows hold ids, kinds and times only, all `internal` (its
`classification:`).
