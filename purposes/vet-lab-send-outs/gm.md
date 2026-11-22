# vet-lab-send-outs — GM notes

Purpose 3 of v0.5 (master spec 12.2;
v0.5's `clinic-purposes.md` section
7; capture W4 items 0 and 3; spec D436). A **round trip the lab asks**, the
consumer-producer the owner ruled: at 16:00 on working days the lab posts
the day's send-outs to the external reference lab (vet-lab's `xlab` stub,
Northfield Veterinary Laboratories, hostname `northfield-lab`), which
accepts at once and posts its result one to five days later to `lab-api`'s
`POST /send-outs/{send_key}/result` (vet-lab's endpoint, not this
purpose's). The chase retries what was not accepted, asks a resend of what
is overdue, then escalates. Fits `vet-lab`.

## Parts and jobs

| Part | The clinic's | |
|---|---|---|
| `source`, `target` | `lab/lab` | the tests routed out, their samples, orders and catalogue read; `lab_send_outs`, the `sent-out` sample events and the `ops` tables written, as vet-lab's `lab_dispatch` |
| `runner` | `interfaces` (scheduler, role `transformer`) | the two script jobs below |
| `partner` | the partners' api node, hostname `northfield-lab` | called with the customer's own key with the external lab, `xlab_customer` |

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `send-outs` | `0 16 * * 1,2,3,4,5` | `scripts/send_outs.py:send`, `source` as `lab_dispatch` (connection `lab-dispatch`), `partner` with `xlab_customer` (connection `northfield-lab`, 10 s) | each test routed `sent-out`, still `sent-out`, whose sample is received and which has no send-out: `POST /orders` with its `send_key`, the order's id, the sample's label, the external code, species, sex and whole years, nothing else (lab rule 11); after the calls one transaction: a `lab_send_outs` row each (`packed`; `sent` once posted; `accepted` with the external accession and `due_by`), a `sent-out` sample event each (`courier, external reference lab`), the run's row. No answer ends the calls; what was not posted stays `packed` for the chase |
| `chase-send-outs` | `*/15 * * * *`, acting 08:00–19:59 Monday to Saturday in the lab's local time | `scripts/send_outs.py:chase`, the same connections | outside its hours it returns at once, writing nothing (no run row, spec D436); in them: a send-out not accepted posted again with its `send_key`, still not accepted from 19:45 local on its packing day one `ops.incidents` row (`kind` `unaccepted`); an accepted one unanswered a working day past `due_by`: `POST /orders/{send_key}/resend`, one row of `kind` `chased` each chase, the second a working day after the first; a working day after the second, still unanswered: one row of `kind` `unanswered`, the escalation, once |

A new send-out's `send_key` is `md5('vet-lab-send-out-test:<order test id>')`,
one per test, so a run stopped between its posts and its commit posts the
same key again and the stub answers the same accession; the history's
send-outs keep theirs (`md5('vet-lab-send-out:<id>')`, W3 item 1), which
the chase reads from `lab_send_outs`. A working day is 24 hours, a day more
when that lands on a local Sunday. The local time is `lab_settings`'
`utc_offset_hours`, the one vet-lab's own jobs use: the 16:00 run is
shifted by render, the chase's window read by the script (W4 item 0).

The answer leg is vet-lab's: the stub's `xlab.answer` tick posts each
answer due to `lab-api`, which records it (`lab_send_outs.status`
`resulted`, `answered_at`) and writes the results; `lis` validates the test
technically once its send-out is resulted, and the pathologist's round
releases it (11:00 every day, 14:00 and 18:00 Monday to Saturday), naming
the lab that performed it; purposes 1 and 2 deliver it.

## What the material holds

- `material/runner/`: `interfaces`' `jobs.yaml`, `queries.yaml`,
  `schedule.yaml` (connections `lab-dispatch`, shared with purposes 2 and
  5 under that name, and `northfield-lab`) and `scripts/send_outs.py`; the
  GM copies them into the runner's scenario layer (`compose/interfaces/`),
  `gmctl compose` writes the node's files.
- `material/target/ddl.sql` (`ddl.target`): the `ops` schema (the shared
  block, `tools/tests/test_purposes.py`) and `lab_dispatch`'s grants on it
  and on `lab_settings (utc_offset_hours)`, for the chase's hours (a grant
  "The roles the purposes add" does not list). `lab_dispatch` is vet-lab's
  role, granted here, never created; it already reads the tests, samples,
  orders and catalogue and writes `lab_send_outs` and the sample events. No
  table of the purpose's own in `lab` (W4 item 3): the chases are
  `ops.incidents` rows.

## Trace and checks

`ops.incidents`, `ops.runs` and the runner's log. Outside the trace, as
evidence: `lab_send_outs` and the `sent-out` events in `lab`; the stub's
`xlab.orders` (what it kept of each send-out, its accession, due time,
answer and resends) on `partners-db`.

SO1 runs on the runner node, `interfaces`, as root with `CHECK_SINCE`: the
judged moment from `check-runs since`, `lab` through `check-sql` as
`gm_check`. SO2, SO3 and SO4 run on the partners' database node,
`partners-db`: the stub's tables through `check-psql`, `lab` through
`check-psql --node lab`, `CHECK_SINCE` as given (W4 item 0).

| Invariant | Judged | Check | Witness |
|---|---|---|---|
| SO1 each test received by 15:30 on a weekday accepted that day, or in an incident | triggers | `checks/so1-accepted-that-day.sh` | a test received by 15:30 whose 16:00 run falls after the judged moment, accepted |
| SO2 one `send_key` per send-out: no test with two external accessions | runs | `checks/so2-one-key.sh` (on `partners-db`) | a send-out the stub took |
| SO3 the catalogue's fields only | runs | `checks/so3-catalogue-fields.sh` (on `partners-db`) | a send-out the stub took |
| SO4 end to end, each answer recorded and its test released by the end of the next round | end-to-end | `checks/so4-answers-released.sh` (on `partners-db`) | an answer posted, its test released |

SO1 judges the tests whose 16:00 run falls after the judged moment, so a
sample received before a fix made before 16:00 counts. SO3 compares what
the stub kept (the accession, label, code, species, sex and age) with the
lab's own values: the stub drops any key beyond them, so an identifier or
a name in an extra field never reaches it; a fault placing one must put it
in a kept field (the label, the species) for the check to see it. SO4 is
the round trip's one `end-to-end` invariant; it needs `lis` validating the
test before the round, and holds the round strictly. The request's leg
(posted at 16:00, answered days later) is longer than a session: SO1 and
SO4 judge its two ends, and a fault between them leaves its backlog in the
answer key (D286).

## Candidate faults (traps; a scenario's are the GM's to select)

| Candidate | What the players find | Fixed on |
|---|---|---|
| A natural identifier or the client's surname in the payload | personal data sent to a third party, against lab rule 11 (SO3) | the runner's script |
| A new `send_key` on each retry | the external lab running a test twice; its invoices showing it (SO2) | the runner's script |
| `lab-api`'s answer endpoint matching on the external accession, which a resend changes | answers recorded nowhere (SO4) | `lab-api`'s `db/` |
| The answer written straight as released | a result reaching the record unvalidated (lab rule 1) | `lab-api`'s `db/` |
| `send-outs` in UTC, after the courier has left at a positive shift | send-outs a day late, every day (SO1) | `jobs.yaml` |
| No chase: a lost callback never asked for again | send-outs stuck past their due date (SO4) | the runner (the chase job missing or never escalating) |
| A test mapped to the wrong external code | the external lab returning another test's result | the catalogue, `lab_tests.external_code` |

## Data moved

None classed: a send-out carries the order's id, the sample's label, the
external code and the animal's species, sex and age, never the owner, the
client, an identifier or a note. The purpose's `ops` rows hold ids, kinds
and times only, all `internal` (its `classification:`).
