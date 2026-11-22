# vet-portal-release — GM notes

Purpose 15 of v0.5 (master spec 12.2; v0.5's `vet-portal-domain.md`,
"`vet-portal-release`: the copies and the release gate"; capture W4 items 0,
6 and 7): the owners' portal filling its own store from the core's record
and the lab, **pulled** (v0.4's P1 shape) with a **release gate** (v0.4's
stress test). The results are read from the lab's release, never from the
core's `requests` state, so the core's copy of the lab's fact (T43) cannot
break the gate.

## What it is for

An owner sees, through the portal, the animals the core says they own now
(or keep with consent) and what the centre released about them: a
consultation once signed, a discharge once the stay has ended, a centre
result once released by the pathologist (an urgent result technically
validated and shown inside is not released yet). Every new owner gets an
account and an invitation.

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `sync-portal-identity` | `*/5 * * * *` | script `scripts/portal_release.py:sync_identity`, `clinic` as `vet_portal_sync`, `portal` as `portal_sync` | the owners registered since the watermark `identity` (but the clinic): an account `invited` each, unless the owner has one (a closed account is never touched), its one-time link random, kept as its SHA-256, expiring after `invitation_days`, its invitation queued in `portal_outbox` (random key, the link in the payload); the animals registered or dead, the ownerships started or ended (the ends first), the herds whose keeper differs: upserted into the copies |
| `publish-records` | `*/5 * * * *` | `:publish_records`, the same two | the consultations `signed` since `records` and the stays ended since it: a document each, version 1, `C-<id>` or `S-<id>`, its body built in `clinic` as the derivation builds it (the diagnoses' codes and labels, the prescriptions with their withdrawal ends; the stay's section, dates and outcome; never the findings) |
| `publish-results` | `*/5 * * * *` | `:publish_results`, `lab` as `lab_release` too | account 1's order tests with an animal released since `results`: `T-<test id>` version 1, the values in force at the release; each amendment after the release since it (grouped by its `amended_at`): a new version, its `supersedes_id` the former, whose `superseded_at` is set; the vet's name the releasing or amending pathologist's, from `clinic`'s `staff` |

Each run reads its sources in one repeatable-read snapshot from its
watermark and writes, in one `portal` transaction, its rows, the watermark
(the latest gate time read, less `margin_minutes`, two; unchanged when it
read nothing) and its `ops.runs` row. A document already published is
skipped by its `source_ref` and version (the job's own check; the unique
`(source_ref, version)` behind it), so the margin's re-reads publish
nothing twice. The three watermarks start at `load_epoch` (the DDL): the
derivation wrote T0's copies and documents. Known limit: a gate within the
few minutes before `load_epoch` whose publication the derivation placed
after it has no document (outside any judged window).

## What the material holds

- `material/source/ddl.sql` (`clinic`), `material/source_lab/ddl.sql`
  (`lab`): the roles `vet_portal_sync` and `lab_release`, `CONNECT` and the
  column grants of "The roles the purposes add". **Beyond the list**
  (reported, W4-e): `animals.registered_at` (the registrations since the
  watermark), `sections (id, kind)` (the body's section, as the
  derivation's), `lab_samples (id, collected_at)` (a result's record time,
  as the derivation's), `consultations.state`.
- `material/target/ddl.sql` (`portal`): the `ops` schema, `portal_sync`,
  its grants and its policies `<table>_sync` (`USING (true)`, `WITH CHECK
  (true)`) on accounts, the copies, documents and the outbox, a `SELECT`
  one on the settings; the three watermarks at `load_epoch`.
- `material/runner/`: `jobs.yaml`, `queries.yaml`, `schedule.yaml`
  (connections `portal-clinic`, `portal-lab`, `portal-sync`, written for
  `records` and `lab`), `scripts/portal_release.py`.

Mapping: `source` the core's database, `source_lab` the lab's, `target`
`portal`, `runner` the integration engine (`interfaces`). The GM adapts
the connections' targets.

## How it goes wrong

The portal's traps (vet-portal-domain.md, "Traps") bite here: a gate read
from the wrong column or the core's request state (RL1), a watermark
skipping rows or the uniqueness dropped (RL2, RL3), a column grant widened
to an address or an identifier, a body built with the findings (RL4), the
copy lagging or a closed account reopened (RL5), a policy or a function
widened or dropped (RL6, the owner scope end to end). The owners' route
records every call it makes (`owners.visits` in `partners`), RL6's
evidence.

## The checks

Every check reads `portal` as `gm_check`, through the `gm_check_read`
policies `load-data` adds at step (2c); each first finds them in place on
every table it reads, and no restrictive policy hiding rows from
`gm_check`, else exits 2, "cannot judge" (spec D432). RL1 to RL5 run on the
runner node (`interfaces`), the judged moment `CHECK_SINCE` raised to the
runner's last reload; RL6 runs on the partners' database node
(`partners-db`), `CHECK_SINCE` as given, reading `owners.visits` there and
the core and the portal through `check-psql --node`. The copies lag the
core by design by up to ten minutes: RL6 tolerates that window.
