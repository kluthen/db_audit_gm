# Issue: grafana 0.3.0's and prometheus 0.2.1's footprint sections quote only older versions' figures

**ID:** `ISS-005_20261114_grafana_prometheus_footprints_old`
**Ref:** `ISS-005`
**Date:** 2026-11-14
**Severity:** Low
**Status:** Open
**Component:** `bricks/grafana/docs/gm.md`
**Affects:** `bricks/prometheus/docs/gm.md`, `fit`'s inputs for scenarios using them
**Seen on:** main a56e5ac; grafana 0.3.0 (Grafana 13.3.1), prometheus 0.2.1 (Prometheus 3.16.0)
**Reported by:** found while coding (v0.5 release gate, item 7)

---

## Summary

The footprint sections of both bricks quote measurements from the v0.2 game
(`fernway-clinics-monitoring`, 2026-10-21) on earlier versions. Neither has
been measured at rest on its current version. G13 read grafana at
220/223M (mean/peak) and prometheus at 96/102M, both under their 384M limits.
Those are smoke readings, though, not footprints.

---

## What happens

### Expected

Each brick's `docs/gm.md` footprint reflects its released version, or says
that the earlier figures stand and why (format skill, `docs/gm.md` check).

### Observed

`bricks/grafana/docs/gm.md:478` onwards quotes v0.2's measures, and
`bricks/prometheus/docs/gm.md:433` does the same, with no note about 13.3.1 or
3.16.0.

### How to reproduce

1. Read both Footprint sections and compare them with `brick.yaml`'s
   versions.

---

## Cause

**Confirmed**: chunk 34 (wave 5) bumped Grafana and Prometheus with stack
tests, but not a measurement at rest.

---

## Spec and intent

- Specs and decisions: master spec v0.5 section 14; release gate item 7;
  D448 (chunk 34).
- Intent records: none recorded.
- Verdict: **code bug** in the docs (the `docs/gm.md` check expects current
  figures). It passed `test_brick_docs`, which checks the shape only.

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | Low |
| Impact | Low: G13 shows both well under their limits |
| Detectability | Low |
| Current mitigation | G13's smoke readings in the wave log |

---

## Recommended fix

**Short term:** in each section, add a sentence quoting G13's reading and
saying that the earlier figures stand until a measurement at rest (as
9dfaa45 did for pgwatch and health-check).

**Medium term:** measure at rest the next time either brick is touched
(v0.6).

**Test:** the format skill's `docs/gm.md` check could compare the version
quoted in the footprint with `brick.yaml`.

---

## References

- `bricks/grafana/docs/gm.md:478`, `bricks/prometheus/docs/gm.md:433`
- `specs/versions/v0.5/wave-log.md`, G13's smoke readings; commit 9dfaa45

---

## Change log

- **2026-11-14**: filed.
