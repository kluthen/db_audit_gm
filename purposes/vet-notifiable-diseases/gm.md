# Purpose 5, the notifiable diseases: GM notes

The notifications of listed diseases to the national veterinary authority
(v0.5 master spec 11.3, 12.1, 12.2 purpose 5; v0.5's `clinic-purposes.md`
section 9; Regulation (EU) 2016/429 Art 18; spec D302, D304, D306,
D308): a **pushed obligation**, the owner's own example of the kind. Two
triggers, one receiver and one rule: a vet's notifiable diagnosis,
suspected or confirmed (core rule 7), and a lab notification of any
customer's (lab rule 7), each notified within its deadline (an hour for
category A, a day otherwise), referenced by the authority or escalated;
yesterday's notifications copied into the back office's `office` at 02:15.
A design-time source: copy the material into a scenario and adapt the
names there.

## What it is for

The law puts the duty on the vet and on the lab alike. The core's
`diagnosis_codes.notifiable` (`none`, `A`, `other`) says which diagnoses
trigger, the lab's `lab_notifications` (written by its information
system's `lab.notify` on a positive or suspect result for a listed
disease's test) which results do. The authority answers each notification
with a reference, the same `notification_key` again the same reference;
it answers 503 to one call in fifty as standing behaviour, so retries and
escalations have a witness (D214's precedent). A notification left
without a reference past its deadline, or rejected, becomes an
`ops.incidents` row; the back office keeps a copy of every notification
sent (D300's copies), regulatory evidence on its own database.

## The material

Written for the clinic's mapping: `source` `records/clinic`, `source_lab`
`lab/lab`, `target` `records/office`, `runner` `interfaces`,
`runner_reports` `backoffice`, `receiver` `partners-api` (hostname
`authority`).

| File | Copied to | What |
|---|---|---|
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml), [`queries.yaml`](material/runner/queries.yaml), [`schedule.yaml`](material/runner/schedule.yaml), [`scripts/notifiable_diseases.py`](material/runner/scripts/notifiable_diseases.py) | the runner's files (scenario layer `compose/interfaces/`) | `notify-vet`, `notify-lab` `*/5 * * * *`, `escalate-notifications` `*/15 * * * *`; connections `clinic` (`vet_interfaces`, pool 2, purpose 4's identical entry), `lab-dispatch` (`lab:5432/lab` as `lab_dispatch`, pool 1, the entry the lab's purposes share), `authority` (`http`, `authority:8000`, `authority_customer`) |
| [`material/runner_reports/`](material/runner_reports/) (the same four kinds, `scripts/notifications_copy.py`) | the report runner's files (`compose/backoffice/`) | `copy-notifications` `15 2 * * *`; connections `clinic-reports` (`vet_reports`; the standby where the scenario has one: retarget it), `lab-reports` (`lab_reports`), `office` (`records:5432/office` as `office_jobs`) |
| [`material/source/ddl.sql`](material/source/ddl.sql), [`material/source_lab/ddl.sql`](material/source_lab/ddl.sql) | nothing: `ddl.source`, `ddl.source_lab`, read from the catalogue by `load-data` at step (2b) | the `ops` block, `ops.notifications` (the same text in both), the grants (`vet_interfaces` guarded; `lab_dispatch`, `vet_reports`, `lab_reports` the domains', granted only), the `vet` watermark at `load_epoch` |
| [`material/target/office.sql`](material/target/office.sql) | the head of the purposes' share of `records`' data file, once | `office`, `office_jobs`, `office_reader`, the database `office`, its `runs` and `regulatory_submissions`; byte-identical in purposes 5, 7, 8, 9, 10 and 12 (W4 item 5) |
| [`material/receiver/authority/`](material/receiver/authority/) (`api.yaml`, `routes/`, `db/`, `queries.yaml`, `schedule.yaml`, `data.sql`) | `compose/partners-api/` and `compose/partners-backend/`; `data.sql` after `partners/shared/partners-db/data.sql` in `partners-db`'s data file | the authority's stub (prefix `authority`, hostname `authority`): `POST /notifications` behind `authority_customer`, its state `authority.normal` |

The **authority is one prefix for two purposes** (W4 item 0): purpose 8
(`vet-antimicrobial-use`) ships the same folder with its own route,
table and endpoint. The block between `-- authority: begin` and
`-- authority: end` of `data.sql` (the role, the schema, `authority.state`
with `delay_ms` 0 and `fail_one_in` 50, the calls' sequence
`authority.calls`), `queries.yaml` and `schedule.yaml` are byte-identical
in both; compose merges identical entries silently.

**Names to adapt** when copying: the record's and the lab's nodes
(`clinic`, `lab-dispatch`, `clinic-reports`, `lab-reports`, `office`
connections; `CLINIC`, `LAB`, `OFFICE` in the checks), the runners, the
authority's hostname, `CENTRE` in the script (the notifier's practice).

## The jobs

- **`notify-vet`** (`clinic` as `vet_interfaces`) and **`notify-lab`**
  (`lab` as `lab_dispatch`), every five minutes. One read, its
  transaction ended before any call: the new triggers (the vets' since the
  `vet` watermark less ten minutes; the lab's not yet notified, every
  customer's), each with no `ops.notifications` row, 20 at most; and the
  retries, the unreferenced notifications of the last two days whose last
  post got no answer or a 5xx. Then `POST /notifications`, keyed
  `vet-<diagnosis id>` or `lab-<notification id>`. Then one transaction:
  its `ops.runs` row, one `ops.notifications` row a new trigger (category,
  deadline, payload as posted, attempts, last status, reference), each
  retry's row updated; for the lab, a referenced notification's
  `notified_at`, `channel` (`authority-api`) and `authority_ref` written
  back; the `vet` watermark moved.
- **`escalate-notifications`**, every fifteen minutes, both databases:
  each notification with no reference past its deadline, or rejected (a
  4xx), and no incident yet: one `ops.incidents` row (`kind` unreferenced
  or rejected, `ref` the key), once; one `ops.runs` row in each database,
  the same job and `started_at`.
- **`copy-notifications`**, at 02:15 on the report runner: yesterday's
  notifications (the customer's local date, `business_settings.timezone`),
  both databases, not yet copied: one `regulatory_submissions` row each
  (`kind` notifiable-disease, `source` clinic or lab, `ref` the key, the
  payload as sent, `sent_at` its first post, the authority's reference),
  and one `office` `runs` row.

**What a notification carries** (ND3): the disease (code, label,
category), suspected or confirmed, the date, the species, the holding
(its number, its keeper's name and address) for a herd or the keeper's
name and address for an animal, the notifier (the vet's name and the
practice; the lab). **The lab holds no address**: its notification
carries the keeper's surname and the account of the practice that holds
it (`keeper.account`), the vet-lab record holding nothing more; ND3
judges the lab's on those. Never the findings or a lab order's
`clinical_notes`.

## The authority's stub

`POST /notifications` under `authority` behind `authority_customer`: each
call numbered by `authority.calls`; a number that is a multiple of
`fail_one_in` (50) answers 503, every other files the notification (201
with its reference `N<year>-<6 digits>`, the same key again the same
reference, `accepted` counted). Its records: `authority.notifications`,
`authority.notification_calls` (every call, its status). No stream of its
own: the back end upserts `authority.normal` once a minute; a fault's
timeline change of it is the scenario's (an outage: `fail_one_in` 1).

## The invariants and where they run

| Id | Judged | Runs on | Reads |
|---|---|---|---|
| ND1 | triggers | the runner (`interfaces`) | `diagnoses` with their codes, `lab_notifications`, `ops.notifications` (both) |
| ND2 | runs | the runner | `ops.notifications` (both), `lab_notifications`' reference; `notify-vet`'s and `notify-lab`'s runs |
| ND3 | runs | the runner | `ops.notifications.payload` (both), the triggers' findings and clinical notes |
| ND4 | triggers | the runner | `ops.notifications`, `ops.incidents` (both), the triggers' categories |
| ND5 | runs | the report runner (`backoffice`; in `fixture-exchanges`, `interfaces`) | `copy-notifications`' runs, `ops.notifications` (both), `office`'s `regulatory_submissions` |

Each raises `CHECK_SINCE` to its runner's last reload (`check-runs
since`) and reads through `check-sql` as `gm_check`; every check guards
its reads (spec D432), exit 2 on a table with row security lacking
`gm_check_read`. A deadline is always the trigger's own (the disease's
category), never the one the job wrote. ND4's "next escalation run" is
the quarter hour at or after the deadline (or the rejection; or the first
sending, for one sent after its deadline) plus three minutes. **The
witnesses**: rare (a few a month, D306 point 6); the lab notifications
open at T0, planted by vet-lab, are posted at the first run after T0; the
503s, one call in fifty.

## The faults this purpose carries

From v0.5's `clinic-purposes.md`
section 9 (the selection is the scenario's): category A treated as
another listed disease (ND1, a day late; the script's `DEADLINE`);
`notify-vet` taking confirmed diagnoses only (ND1; `VET_NEW`); `notify-lab`
taking the centre's account only (ND1; `LAB_NEW`); the authority down
for hours with nothing escalating (ND4; v0.4's
`purpose-receiver-down-unnoticed`, adapted: `authority.normal`'s
timeline, then the escalation job); the findings' free text in the
payload (ND3; `_vet_payload`).

## Trace

The triggers; `lab_notifications`, `ops.notifications`, `ops.incidents`,
`ops.watermarks`, `ops.runs` in `clinic` and `lab`; `office`'s
`regulatory_submissions` and `runs`; the runners' logs (keys and statuses
only); the stub's `authority.notifications` and
`authority.notification_calls` (evidence, out of the players' reach).

## Fixture

`tools/tests/fixtures/fixture-exchanges/` runs it with purpose 4 on eight
nodes, `runner_reports` mapped to `interfaces` (which then holds `office`
as `office_jobs`); its short test places T0 just before local midnight,
notifies a vet's diagnosis and a lab notification, forces one 503
(`setval('authority.calls', ...)`) and its retry, moves the 02:15 copy to
just after midnight, and reads every check fixed.
