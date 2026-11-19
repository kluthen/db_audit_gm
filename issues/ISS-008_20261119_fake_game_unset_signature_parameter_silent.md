# Issue: a fake game whose instance leaves a history signature's optional parameter unset loses that series silently

**ID:** `ISS-008_20261119_fake_game_unset_signature_parameter_silent`
**Ref:** `ISS-008`
**Date:** 2026-11-19
**Severity:** Medium
**Status:** Open
**Component:** `tools/gm/model.py`
**Affects:** `instance_history` (`model.py:8326`) and its callers, `tools/gm/history.py`'s composer (the forged Prometheus past) and the fill; `gmctl render --aging fake`; the faults whose `history:` selects `datname="{DATABASE}"` with an optional `database` parameter: `pg-join-index-missing`, `purpose-mail-overlapping-window`, `scheduler-insert-retry-duplicates`, `scheduler-query-error`, `scheduler-report-unbounded`
**Seen on:** not seen yet (read in the code and the faults; v0.6 wave 3, `v0.6-w3` after 06a5d21)
**Reported by:** found while coding (v0.6 G10.3, `spec-writer`, wave 3); filed as an issue on the owner's word, 2026-11-19

---

## Summary

A history signature's per-database series take the database from an
optional fault parameter (`database`, `default: null`, "read only in a
fake game, so every instance in a scenario played fake sets it"). Nothing
enforces that: the loader, `check_scenario` and `gmctl render --aging
fake` accept an instance without it. The selector then carries no real
database name, matches no series, and that part of the forged past is
missing with no error. Only `tools/tests/test_fake_aging_faults.py`
checks it, and only for the two covered scenarios (the tarnbeck shop and
campaign).

---

## What happens

### Expected

formats.md v39 ("Fault definition", wave 3's optional parameters) and the
faults' own descriptions: every instance in a scenario played fake sets
the parameter its history signature needs. A scenario that doesn't should
be refused before deploying, as other incomplete definitions are
(the `scenario-format` rule: the GM refuses to deploy an incomplete
scenario).

### Observed

No check reads it. `instance_history` fills `{DATABASE}` from the
instance's parameters, else the default (`null`), and returns the entry.

### How to reproduce

1. (Guessed: both covered scenarios set it.) Copy a scenario with one of
   the faults above and remove `database` from that instance's
   `parameters`.
2. `check_scenario` and `gmctl render --aging fake`: both pass.
3. Deploy, fill, `gmctl history`: the instance's `pg_stat_database_*`
   overlay matches no series; the forged past shows no trace of the fault
   on that series, and the seam check doesn't notice (no step to join).

---

## Cause

**Confirmed** (read in the code): `tools/gm/model.py:8326-8341`,
`instance_history`:

```python
values = dict(instance_values(fault.data, inst), **{INSTANCE_NODE: inst.get("node")})
return tuple(HistoryEntry(kind=e.kind, fields=_resolved(e.fields, values),
                          suppressed_by=e.suppressed_by) for e in entries)
```

and, for example, `faults/purpose-mail-overlapping-window/fault.yaml`:

```yaml
  database:
    description: >-
      ... optional, read only in a fake game, so every instance in a
      scenario played fake sets it
    default: null
    required: false
```

**Lead:** what `resolve_placeholders` puts in place of a `null` value
(the literal `{DATABASE}`, `None` or an empty string) wasn't checked; any
of them matches no `datname`.

### Where this pattern exists today

The five faults listed under **Affects**. The exporter's reach (the
`postgres` database only, master spec 9.5) is a separate limit, already
documented.

---

## Spec and intent

- Specs and decisions: master spec 9.5 (the history signature, the
  exporter's reach), 9.7; formats.md v39 ("Fault definition"); spec D580
  (G10.3's forms as built, which names this gap).
- Intent records: none recorded (no intent register).
- Verdict: **code bug** (the spec says every fake instance sets it; no
  check holds it).

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | Low today (both covered scenarios set it, unit-tested); higher for any new scenario played fake with one of these faults |
| Impact | Medium when met: a fault's forged Prometheus trail is missing, a gap a player comparing the past with the logs could see |
| Detectability | Low: no error; the seam check sees nothing to join |
| Current mitigation | `test_fake_aging_faults.py` for the two covered scenarios; formats.md v39 states the rule |

---

## Recommended fix

**Short term:** none needed for v0.6's covered scenarios; a scenario
added to fake play with one of these faults sets `database` by hand.

**Medium term:** `gmctl render --aging fake` (or the scenario check, when
the scenario lists fake play) refuses an instance whose history entries
still hold an unresolved placeholder after `instance_history`, naming the
instance and the parameter.

**Long term:** the fault format marks a parameter `required_in: fake`, so
the loader enforces it from the definition.

**Test:** a `test_model.py` or render test with an instance missing
`database`, expecting the refusal; `test_fake_aging_faults` stays.

---

## Extra data

Reported in G10.3's hand-back (wave log "G10.3 done — 2026-11-19").

---

## References

- `tools/gm/model.py:8316-8341` (`_resolved`, `instance_history`)
- `faults/{pg-join-index-missing,purpose-mail-overlapping-window,scheduler-insert-retry-duplicates,scheduler-query-error,scheduler-report-unbounded}/fault.yaml`
- `tools/tests/test_fake_aging_faults.py`
- `specs/formats.md` v39; `specs/versions/v0.6/master-spec.md` 9.5;
  `specs/decisions.md` D580
- `specs/versions/v0.6/wave-log.md`, wave 3

---

## Change log

- **2026-11-19**: filed (owner chose "file an issue" over a fix before the merge).
