# Issue: The loader doesn't check that a seed-file fault's lines are in the scenario's copies

**ID:** `ISS-001_20261114_loader_misses_unplanted_seed_faults`
**Ref:** `ISS-001`
**Date:** 2026-11-14
**Severity:** High
**Status:** Open
**Component:** `tools/gm/model.py`
**Affects:** `tools/gm/localimpl.py` (seed rendering), `tools/gm/inject.py`, the `scenario-format` skill's checks, every scenario that selects a `seed-file` fault (`scenarios/*/nodes/*/`), the wave gates' fixtures
**Seen on:** armenelos + VPS; `aldermoor-centre` at G13 run 1 (game `aldermoor-cfdt1n`, 2026-11-13), on main 090ea1f
**Reported by:** found while coding (G13, v0.5 release gate; finding 1 in the wave log's G13 entry)

---

## Summary

A `seed-file` fault is planted at render: its `seed_changes` lines must
already be in the scenario's copies of the seed files (formats.md, fault
"Injection"). Nothing checks that they are. In `aldermoor-centre`, the
lines of s2, s7 and s8 were missing from `nodes/records/postgresql.conf` and
`nodes/standby/postgresql.conf`. The format check, `compose --check`, chunk
27's runs and the whole wave 5 gate all passed anyway. The game deployed
with three of its nine faults absent. Nothing warned about it, and the GM's
answer key still listed them as planted. Only the whole-clinic deployment
saw it, when their sealed checks read `fixed`.

---

## What happens

### Expected

formats.md (fault "Injection", D151): a `seed-file` fault's `seed_changes`
are "in the scenario's copies from T0". The scenario's notes say "planted at
render". A scenario that selects such a fault should be refused, or at least
flagged, when its copies lack the lines.

### Observed

The loader and the format check accept the scenario. `gmctl inject` reports
success. The fault's sealed check reads `fixed` from T0.

### How to reproduce

1. Take `aldermoor-centre` at main 090ea1f (before fix 0118c90), or remove
   s7's `log_statement = 'all'` line from
   `scenarios/aldermoor-centre/nodes/records/postgresql.conf`.
2. Run the scenario's format check and `gmctl compose --check`. Both pass.
3. Deploy, `load-data`, `inject`, `start-load`. Run `gmctl check --instance`
   for s7: it reads `fixed`.

---

## Cause

**Confirmed** (G13 run 1; fix 0118c90 restored the lines). The loader checks
a `seed-file` fault's `seed_changes` materials as files
(`tools/tests/test_model.py:2604` `test_state_seed_changes_materials`).
Nothing compares each change's line with the selected scenario's copy of the
file it names. Seed rendering (`tools/gm/localimpl.py:508`
`seed_entries`, `:592` `seed_configs`) copies the scenario's files as they
are.

### Where this pattern exists today

Every scenario that selects a `seed-file` fault depends on a hand-made copy:
`aldermoor-centre` (s2, s7, s8), and the older scenarios' seed-file faults.
Each fault's own fixture carries its line, which is why the fixtures pass.

---

## Spec and intent

- Specs and decisions: formats.md, fault "Injection" (`seed-file`,
  `seed_changes`, planted at render, D151); master spec v0.5 sections 6.3
  and 17.
- Intent records: none recorded (the repo keeps no intent register).
- Verdict: **spec gap**. The format states the invariant but names no check
  for it. Whether it is a loader refusal or a `scenario-format` skill item is
  for spec-writer to settle, with the owner (v0.6 by default).

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | Medium: any hand-composed scenario that selects a seed-file fault |
| Impact | High: the game runs with faults missing, and the answer key says otherwise |
| Detectability | Low: only a deployment with the fault's check read shows it |
| Current mitigation | fix 0118c90 for `aldermoor-centre`; G13's reading of every fault present |

---

## Recommended fix

**Short term:** in the `scenario-format` skill's checklist, add an item:
grep each selected `seed-file` fault's `seed_changes` lines in the scenario's
copies.

**Medium term:** a loader refusal. For each selected `seed-file` instance,
each `seed_changes` line (after parameter substitution) must appear in the
scenario's copy of the named file on the fault's node.

**Long term:** render the fault's lines into the copies from the fault
itself, so no hand copy is needed.

**Test:** a `test_model` case where a scenario selects a seed-file fault
whose line is missing from its copy is refused. `aldermoor-centre` before
0118c90 is the real example.

---

## Extra data

G13 run 1 (game `aldermoor-cfdt1n`): s2, s7 and s8 read `fixed`; the other
readings matched run 2. Run 2 (after 0118c90) read every fault present.

---

## References

- `tools/gm/model.py`, `tools/gm/localimpl.py:508-620`, `tools/gm/inject.py`
- `tools/tests/test_model.py:2604`
- `specs/formats.md` ("Injection", around line 666)
- `specs/versions/v0.5/wave-log.md`, "G13 — the whole clinic on armenelos
  plus the VPS, 2026-11-13", finding 1; fix commit 0118c90

---

## Change log

- **2026-11-14**: filed.
