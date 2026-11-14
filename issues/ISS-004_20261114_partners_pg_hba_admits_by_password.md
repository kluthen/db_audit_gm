# Issue: The partners' database admits by role and password, not by address, and the access model still calls it unverified

**ID:** `ISS-004_20261114_partners_pg_hba_admits_by_password`
**Ref:** `ISS-004`
**Date:** 2026-11-14
**Severity:** Low
**Status:** Open
**Component:** `specs/versions/v0.5/access-model.md`
**Affects:** the partners' seed `pg_hba.conf` (`samenet` line), `bricks/postgres/docs/gm.md` (the partners' `pg_hba` form), the access model's known gaps
**Seen on:** main a56e5ac; the access model at lines 528-531
**Reported by:** found while coding (v0.5 release gate, item 6)

---

## Summary

Access model section 13 says that how the partners' database admits only
their own nodes "is the build's to verify". Chunk 11 has since measured it:
on the one Swarm network, the `samenet` line admits any task by role and
password, not by address. The guarantee still rests on the partners' role
passwords being mounted only on the partners' nodes. The gap stands, but it
is now verified, and the text still calls it open.

---

## What happens

### Expected

The access model states the gap as it was measured: admitted by role and
password from any node on the network, with the passwords mounted only on
the partners' nodes. It records it as a known gap.

### Observed

"… is the build's to verify; until then the guarantee rests on the roles'
passwords being mounted on the partners' nodes only."

### How to reproduce

1. Read `specs/versions/v0.5/access-model.md:528-531`.
2. Compare it with the partners' `pg_hba` form in `bricks/postgres/docs/gm.md`
   and chunk 11's record in the build plan.

---

## Cause

**Confirmed**: the access model was written before chunk 11. Nobody
reworded it once the measurement landed.

---

## Spec and intent

- Specs and decisions: access model v0.5 section 13; chunk 11's record;
  wave 2's gate (the partners' `pg_hba` form).
- Intent records: none recorded.
- Verdict: **spec gap**. spec-writer rewords it. If address-based admission
  is wanted, that is an open question for v0.6 (the bastion and network
  overhaul).

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | Low: a player would need a partner role's password, mounted only on the partners' nodes |
| Impact | Medium: forging a partner's data |
| Detectability | Low |
| Current mitigation | the passwords are mounted only on the partners' nodes; `no-access` rules; the checks name an overstep |

---

## Recommended fix

**Short term:** spec-writer rewords section 13 to state the measured
behaviour and adds it to v0.5's release notes' known gaps.

**Medium term:** v0.6 (network overview, D480-D488) decides whether the
partners get a network of their own or address-based `pg_hba` lines.

**Test:** v0.6's network fixture: a customer node holding no partner secret
is refused by `partners-db`.

---

## References

- `specs/versions/v0.5/access-model.md:528-531`
- `bricks/postgres/docs/gm.md` (the partners' `pg_hba` form)
- `specs/versions/v0.5/build-plan.md`, chunk 11

---

## Change log

- **2026-11-14**: filed.
