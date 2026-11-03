# v0.5 — the clinic's test selection

Status: draft v1, ready for review. The spec's own pick of faults from
the [traps](clinic-traps.md), for the build's tests and the proof in
play: a fixture, not the canonical scenario (D309). A game's faults are
the GM's to select at deploy, with whoever sets up the game; this
selection binds no game. It keeps D290's cap and mix: ten faults, one
dramatic, two on the verge, seven optimisations and minor frictions,
and a false alarm.

Tested under D314: every check is a short test, under 30 minutes, on
the least environment that proves the fault, one fixture per group
below; the whole clinic is deployed once, as the proof in play, with
the selection planted at once ([README](README.md#testing-in-v05-d314)).

## The selection

| # | Trap | Class | What it covers | Planted | Fixture |
|---|---|---|---|---|---|
| s1 | T40, the urgent priority dropped in the centre's orders | D | a round-trip cascade (D286): urgent tests posted routine, waiting for the pathologist's round | `interfaces`' script (`post-lab-orders`' mapping), seed-file | orders |
| s2 | T35, `archive_command` failing silently | V | replication and the archive; cold storage, the vault's `wal` manifests and its page | `records`' `postgresql.conf` | archive |
| s3 | T69, herd prescriptions dropped from the antimicrobial use | V | a periodic report, its witness the daily feeder (D265); last year's planted report wrong, the cattle the one species due | the feeder's query on `backoffice`, and the planted report | reports |
| s4 | T41, a retry under a new `client_ref` | M | a round trip's correlation key; the held `purpose-retry-without-key` (D201) built | `interfaces`' script | orders |
| s5 | T78, `lab-api`'s idempotency lookup unindexed | M | an `api` node's `db/` side (D271) | `lab-api`'s `db/` | orders |
| s6 | T49, a natural identifier in the send-outs' payload | M | governance towards a third party (lab rule 11) | `interfaces`' script (`send-outs`) | send-outs |
| s7 | T1, statement logging on `records` | M | governance in the logs (core rule 10); the held `governance-statement-log-personal` (D191) built | `records`' `postgresql.conf` | reports |
| s8 | T33, the standby an hour behind (`recovery_min_apply_delay`) | M | the reporting standby (D299): the night's feeders missing the evening | the standby's `postgresql.conf` | reports |
| s9 | T60, the critical calls' watch scheduled by the superuser | M | `pg_cron` on a database node | `lab`'s `cron.job` | lab |
| s10 | T10, `monitoring` not chosen on `lab` | M | the options model (D289) | the topology's `options` | lab |
| fa | "The external lab is slow" | false alarm | a PCR answered on its fourth day, within its one-to-five-day turnaround | an issue in the starter pack, no fault | send-outs |

Calibration for the classes: s1 is the customer's complaint (the
emergency team's blood gases hours late); s2 has no copy of the last
hours in the vault and nothing says so; s3 is a year deep with the next
yearly report due in January; s4 is planted with the partner's standing
slowness only, a few duplicates a week, so it stays minor; s8 an hour's
delay, the customer's "for safety".

## The fixtures

Each fixture holds the nodes its faults touch and those they cannot run
without, every other node left out. A fixture's T0 is placed just before
the job a check needs (D314), never waited for; a WAL segment is
switched by the test.

| Fixture | Nodes | T0 | Faults |
|---|---|---|---|
| orders | `records` (`clinic`), `lab`, `clinic-api`, `lab-api`, `pms`, `lis`, `interfaces` | a weekday, 10:00 | s1, s4, s5 |
| archive | `records`, the partners' `api` node (cold storage's hostname) and database | any | s2 |
| reports | `records` (`clinic`, `office`), the standby, `backoffice` | a Friday, 01:20 (Thursday held herd visits) | s3, s7, s8 |
| send-outs | `lab`, `interfaces`, the partners' `api` node (the external lab's hostname), database and back end | a weekday, 15:50 | s6, fa |
| lab | `lab`, its exporter | any | s9, s10 |

Seven nodes at most, with the bastion every deployment has: the
largest, orders, about 1.5G and 1.6 CPU reserved, so every fixture fits
one host as the tests declare it ([tally](clinic-capacity.md)).

## Each fault's short test

Present, fixed and the time each takes, every one under 30 minutes with
the deployment.

- **s1, urgent priority dropped.** The fixture raises the rate of
  emergency and in-hospital consultations on `pms` (its profile layer,
  D264) so an urgent request closes within minutes. *Present*: a lab
  order `routine` whose request is `urgent`, within ten minutes.
  *Fixed*: after the mapping's fix, the next urgent order is `urgent`
  and released at once by `lab.release.urgent`, its request `resulted`
  within ten minutes (LO1, LO3); the routine-posted ones left waiting
  for the next round are the backlog, a creditable consequence (D286).
  LO4 end to end for the urgent orders posted after the fix. About 25
  minutes.
- **s2, `archive_command` silently failing.** *Present*: the test
  switches a segment (`pg_switch_wal()`); `pg_stat_archiver` reports it
  archived, no `wal` manifest names it, the vault's page shows the gap.
  *Fixed*: after the fix, the next switched segment's manifest present;
  the gap stays, a finding the players report. About 10 minutes.
- **s3, herd prescriptions dropped.** *Present*: the 02:00 feeder's day
  (Thursday, herd visits) short of the herd treatments the source holds;
  last year's planted report short of the cattle's herd use. *Fixed*:
  after the query's fix, the feeder moved to the next minute (D132) and
  its day complete; the planted report stays wrong, its rerun
  recommended (D277). About 20 minutes.
- **s4, retry without a key.** The test delays one post past the
  runner's ten-second timeout (a lock held on `lab_orders`). *Present*:
  two lab orders for one consultation, two `client_ref`s (LO2). *Fixed*:
  after the fix, the same delay gives one order, the second post
  answered with the first accession. About 15 minutes.
- **s5, the idempotency lookup unindexed.** *Present*: `lab-api`'s
  lookup by `client_ref` alone, a sequential scan in
  `pg_stat_statements` on `lab`, its time per post read against the
  history's 14 000 orders. *Fixed*: the lookup on the account and the
  reference, the unique index used. About 10 minutes. Its growth over a
  year of posts is not shown in v0.5.
- **s6, an identifier in the send-outs.** *Present*: the 16:00
  `send-outs` run's payloads at the external lab's stub carry the
  microchip (SO3). *Fixed*: after the fix, `send-outs` moved to the next
  minute, a send-out tested that day carries the catalogue's fields
  only. About 20 minutes.
- **s7, statement logging.** *Present*: an owner's name and phone in
  `records`' log after a few `pms`-style writes run by the test as
  `vet_app`. *Fixed*: after the fix and a reload, the same writes leave
  no personal data in the log. About 10 minutes.
- **s8, the standby behind.** *Present*: `pg_stat_replication`'s replay
  lag at an hour; the 01:30 feeder's day missing the supplies of the
  evening's last hour. *Fixed*: the delay removed, the lag near zero, the
  feeder moved and its day complete. About 20 minutes.
- **s9, the watch as superuser.** *Present*: `cron.job.username`
  `postgres` for the critical calls' watch. *Fixed*: the job scheduled
  as `lab_watch`, its next run in `cron.job_run_details` under that
  role. About 10 minutes.
- **s10, `monitoring` not chosen.** *Present*: the exporter's login
  errors against `lab`. *Fixed*: the option chosen and the node
  redeployed, the exporter's metrics present. About 15 minutes.
- **fa, the external lab is slow.** The fixture plants a PCR send-out
  answered on its fourth day; the check reads its `due_by` against
  `answered_at`, within its turnaround. About 5 minutes, on the
  send-outs fixture.

## The proof in play (D314)

The whole clinic deployed once on armenelos plus the VPS, every part
built, the ten faults and the false alarm planted at once. Its checks
(proposed): the deployment and `fit`; every producer, partner and
purpose running for about 30 minutes, each one's first run read; each
fault's present reading where it reads within the window (s2, s5, s7,
s8, s9 and s10 at once; s1 at the first urgent order, if one comes; s3
and s6 only with T0 placed before their jobs, which the window cannot
hold for both, so they rest on their fixtures). No fault is fixed there.
None of the ten may exhaust a node's memory, so none sets
`needs_unshared_host` and the placement is free on that count; the VPS
rules still bind the run (D159).

Unproven in v0.5 (the major test before the v1.0 tag): the ten faults
at once through their cycles after a full aging, the classes as the
hand-over finds them (s1 noticed, s2 and s3 on the verge), s5's growth
over a year of posts, the feeders at their own hours.
