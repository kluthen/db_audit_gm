# Issue: The clinic's load-data takes about 28 minutes and leaves a vault outage before T0

**ID:** `ISS-002_20261114_clinic_load_slow_vault_503`
**Ref:** `ISS-002`
**Date:** 2026-11-14
**Severity:** Medium
**Status:** Open
**Component:** `partners/` (vet-lab's partners' order build in `partners-db`)
**Affects:** `gmctl load-data` for `aldermoor-centre`, cold storage (`partners-api`), lab's archiver (`pg_stat_archiver`), game setup time, v1.0 gating's setup
**Seen on:** armenelos + VPS; `aldermoor-centre`, G13 runs 1 and 2 (2026-11-13), main 090ea1f + 0118c90
**Reported by:** found while coding (G13, v0.5 release gate; finding 4 in the wave log's G13 entry)

---

## Summary

`load-data` for the whole clinic took 1671 s and 1652 s. About 17 minutes
of that is `partners-db`, at its 0.5 CPU limit, building vet-lab's partners'
orders (`pg_temp.lab_order_tests(...)` into a temp table). During the same
stretch, cold storage answered 503 to lab's `vault-post` 66 times
(09:30–09:51 in run 2). Lab's archiver therefore counts 66 failures before T0,
then recovers. A player who reads `pg_stat_archiver` sees an archiving outage
that no fault and no story explains: a false trail. Setup also takes long
for a class.

---

## What happens

### Expected

Setup leaves no trace that the game's story doesn't explain. Master spec 18
and the GM notes expect only the planted faults' traces. A clinic's setup
fits a GM's preparation time (no target is set yet).

### Observed

- `load-data` takes about 28 min. 
- Lab's `pg_stat_archiver.failed_count` is 66 at T0, and cold storage logged
  503s during the load.

### How to reproduce

1. Deploy `aldermoor-centre` on armenelos + the VPS (G13's `duo` playground).
2. Run `gmctl load-data`, watching `docker stats` on `partners-db` and
   cold storage's log.
3. At T0, read lab's `pg_stat_archiver`.

---

## Cause

**Confirmed** for the time (G13's per-step timings, `partners-db` at its CPU
limit). **Lead** for the 503s: cold storage is served by the same `partners`
nodes (VPS). It is probably starved while `partners-db` is saturated, or it
refuses posts while its tables load. Not traced yet.

---

## Spec and intent

- Specs and decisions: master spec v0.5 sections 14 (resources), 18.3 and
  18.4; D322 (initial load, GM-adjudicated); cold storage
  (`specs/versions/v0.5/cold-storage.md`).
- Intent records: none recorded.
- Verdict: **spec gap**. No setup-time target exists, and no rule says that
  setup must leave no unexplained trace. spec-writer settles both, with the
  owner. Proposed: a v0.5 known limit, plus an open question for v1.0's
  setup.

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | High: every clinic deployment |
| Impact | Medium: a misleading archiver history; a long setup |
| Detectability | Medium: visible in `pg_stat_archiver` and cold storage's log |
| Current mitigation | none; G13 recorded it |

---

## Recommended fix

**Short term:** name it in the release notes as a known limit. In the GM
notes, say that lab's archiver shows failures from setup, and reset lab's
archiver stats (`pg_stat_reset_shared('archiver')`) after the load, before
T0.

**Medium term:** start lab's archiving (or its `vault-post`) only after the
partners' load. Speed up `lab_order_tests`: a set-based insert instead of a
per-order function, or more CPU for `partners-db` during the load only.

**Long term:** fold this into the fake-aging fill (approach C), where setup
is its own phase with clean-up before T0.

**Test:** the whole-clinic run (v1.0 gating) asserts that lab's
`pg_stat_archiver.failed_count` is 0 at T0, and records `load-data`'s time.

---

## Extra data

G13 run 1: `load-data` 1671 s. Run 2: 1652 s. Coherence 27/27 both times. The
composed load-only fixture (`fixture-clinic-load`) takes 903–908 s on one
host.

---

## References

- `specs/versions/v0.5/wave-log.md`, "G13 — …", finding 4, and "Release
  gate — results, 2026-11-13"
- `partners/` (vet-lab partners' data), `tools/gm/` (`load-data`)

---

## Change log

- **2026-11-14**: filed.
