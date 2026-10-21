# GM notes — bookshop-new-server

Sealed. Longer explanations for the feedback; the authoritative answer is
`answer-key.yaml`, and each fault's own `gm.md` (under `faults/`) has the
general background.

## The shape of the game

Six defects, all on `db`, all visible without any activity:

| Instance | Defect | Visibility | Issue |
|---|---|---|---|
| f1 | `trust` for every remote address in `pg_hba.conf` | known | I2 (propose) |
| f2 | `work_mem = 256MB`, envelope 1MB..64MB | known | I1 (fix) |
| f3 | no index on `order_lines (order_id)` | known | I3 (fix) |
| f4 | `shop_app` is a superuser | hidden | — |
| f5 | autovacuum off on `orders` | hidden | — |
| f6 | inactive replication slot `standby1` | hidden | — |

The story hints at the hidden ones without naming them: an application
role (`shop_app`), a busy shop, and a standby that existed before the move
and was switched off. A good team reads `pg_hba.conf`, the roles, the
tables' options and the replication views as a matter of routine.

The validator is red from the start (`work_mem`): that is part of I1, and
it turns green once f2 is fixed. Nothing in this scenario leaves a
validator the players cannot make green.

## Feedback points

- **I1 (f2).** The arithmetic is the point: `work_mem` × operations ×
  connections against 1 GB. Credit the two paths equally (file and reload,
  `ALTER SYSTEM` and reload). A team that only lowers it without saying
  why has fixed it but not explained it to Samira, who asked to
  understand. Per-session `SET work_mem` for the reports is the mark of a
  thorough answer.
- **I2 (f1).** A proposal is expected; fixing it as well is fine. The best
  answers say "yes, today anyone can", show the password-less login from
  the bastion, and propose the change with a test. Watch for a fix that
  drops the GM's `peer` line (the validator turns red) or that locks the
  players out (`dba` from the bastion must still work).
- **I3 (f3).** Credit the plan as evidence: `EXPLAIN` before and after.
  `CONCURRENTLY` is the production habit; in the game a plain `CREATE
  INDEX` is fine.
- **f4.** Removing the attribute is enough: the role already holds its
  grants (data file). Dropping the role or its grants would break the
  website; say so if a team did it.
- **f5.** Easy to miss because the server setting is on. A manual `VACUUM`
  is a catch-up, not a fix.
- **f6.** Ties the story's retired standby to the server's state. Dropping
  the slot is the fix; `max_slot_wal_keep_size` is the safety net.

Interactions: none in the strict sense (no fault hides another). f1 makes
f4 worse in principle (password-less logins as `shop_app`), but with
`trust` anyone can already log in as `dba`, a superuser, so it changes
nothing in practice.

## After the game

The `shop_app` password is in `data/db.sql` (GM side). The players do not
need it: they work as `dba`, and `SET ROLE shop_app` tests the
application's rights.
