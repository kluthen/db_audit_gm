# security-policy-ownership-end-dropped — GM notes

**What.** The owners' portal (vet-portal, a database `portal` on the
record's node, D320) lists an owner's animals through `portal_animals`
under row-level security: `portal_animals_scope` admits the asker's
current `owner` ownership (`until_at IS NULL`) or a current `keeper`
ownership the owner has granted (`portal_keeper_granted`, D427)
([vet-portal `docs/gm.md`](../../domains/vet-portal/docs/gm.md), "Who sees
what"). Planted after the data load, the owner branch loses `o.until_at
IS NULL` ([`inject/10-drop-ownership-end.sh`](inject/10-drop-ownership-end.sh)):
a former owner logged into the portal still lists the animals they sold
or gave away, and opens their records since the ownership began (T270;
class m in the clinic). The keeper branch is untouched: a keeper's
withdrawal is `portal_keeper_granted`'s (T274), not this policy's text.

**Writing it into a scenario.**
- The node is the record's (`records`), `postgres` 0.5.0, holding
  vet-portal's database (`database`, default `portal`); load-data's step
  (2c) puts `gm_check_read` on the portal's tables (D432), which the
  sealed check needs.
- **Planting moment (spec D463).** The portal copies every ownership
  (vet-portal's `derive.sql`), so the fault exposes every past sale, not
  only the day's. Plant it a few hours before hand-over (the clinic: three
  hours, `gmctl inject --at`, W5 item 6), so former owners have had
  hours, not days, to look. The owners' traffic is thin in a short watch
  (4 to 9 visits in six minutes at intensity 10): a test makes the former
  owner's call itself.
- Parameters: `database` (`portal`).
- Visibility: hidden or known (a former owner's complaint, the template).
  `records` is fixable; an issue may expect `fix`, `propose` or `report`.

**Why it matters.** An owner who sold a horse keeps reading its record:
its new owner's treatments, its stays, where it is. That is personal data
of the new owner's leaking to a stranger (GDPR Art. 5(1)(f)), through the
one gate the portal has.

**Why it happens.** The policy was "simplified" when someone read the
owner and keeper branches side by side; the copies' own index reads
`until_at IS NULL`, so nobody looked twice.

**What a good answer says.** Reads the policy, finds the owner branch
without the ownership's end, shows a former owner passing it (as
`portal_api` with `portal.owner_id` set, or through the API with a
former owner's login), restores the condition, checks the buyer still
sees the animal, and raises the review of what former owners read since
the change.

**Fix path.** As `dba`, `ALTER POLICY portal_animals_scope ON
portal_animals USING (...)` with the owner branch's `o.until_at IS NULL`
restored (vet-portal's `data/schema.sql` writes it); any equivalent
policy counts.

**Sealed check.** On the node, as root, through `check-psql` as
`gm_check` (never `portal_api` or `dba`), after finding `gm_check_read`
in place on `portal_animals` and `portal_ownerships` (else 2, "cannot
judge"). It judges the live policies, whichever way they were fixed: the
permissive `SELECT` policies on `portal_animals` that apply to
`portal_api` OR'ed, the restrictive ones AND'ed, evaluated with
`portal.owner_id` set to a witness, the most recent ended `owner`
ownership whose owner neither owns nor keeps the animal now while another
owner does. `gm_check` holds no `EXECUTE` on `portal_keeper_granted`, so
each call to it reads as a session-local function answering false (the
witness keeps nothing, so the keeper's branch could never admit them).
*Present* (1) while the witness passes, or while row-level security does
not hold `portal_api` at all, or when the current owner no longer
passes either; *fixed* (0) when the witness does not pass and the current
owner does; *too soon* (3) when no ownership has ended yet.
