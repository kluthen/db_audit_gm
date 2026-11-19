# Issue: the fill drops a hidden fault's `queue` entry from T0, ignoring when the hiding instance is planted

**ID:** `ISS-007_20261119_fill_queue_plan_ignores_hider_planting`
**Ref:** `ISS-007`
**Date:** 2026-11-19
**Severity:** Low
**Status:** Open
**Component:** `tools/gm/fill.py`
**Affects:** `fill.queue_plan` → the fill's queue model (`gm_scheduler fill`), the fill's `<node>.metrics.jsonl` records, which `tools/gm/history.py`'s composer reads for the forged Prometheus past; any scenario whose selection holds a `suppressed_by` pair
**Seen on:** not seen yet (read in the code; v0.6 wave 3, `v0.6-w3` at 552259f)
**Reported by:** found while coding (v0.6 chunk 10b's owner, wave 3); filed as an issue on the owner's word, 2026-11-19

---

## Summary

`fill.queue_plan` leaves out a fault instance's `queue` history entry for
the whole fill as soon as any selected fault is listed in that entry's
`suppressed_by`, whenever the hiding instance is planted. Spec D543 says a
`suppressed_by` entry stops at the hiding instance's planting: before it,
the hidden fault's effect should be in the fill. A hiding fault planted
late in the virtual span would therefore erase the hidden fault's queue
effect (its slowed key, its lock waits) from the whole forged past, and the
scheduler metrics would show no trace where the real system would have.
Chunk 10's history composer applies D543 correctly to the Prometheus
overlays, so the two would disagree for the same pair.

No covered fault uses `suppressed_by` in v0.6 (spec D548, D578), so no
game meets it today.

---

## What happens

### Expected

Master spec 9.5 and formats.md v37 (spec D543): an entry with
`suppressed_by` applies from its instance's planting until the planting of
the first selected instance of a hiding fault; a hiding instance planted in
the tail hides nothing in the past.

### Observed

`queue_plan` skips the entry outright whenever a hiding fault is selected
(`set(entry.suppressed_by) & selected`), with no look at the hiding
instance's `planted_at`.

### How to reproduce

1. (Guessed: no covered scenario has a pair.) Give a fixture fault A a
   `history:` `queue` entry with `suppressed_by: [B]`, and select A planted
   at T0 and B planted at a pause partway through the fill.
2. `gmctl render --aging fake`, deploy, load, inject, `gmctl fill`.
3. Read the fill plan / `<node>.metrics.jsonl`: A's key carries no queue
   effect at any point, though it should until B's pause.

---

## Cause

**Confirmed** (read in the code): `tools/gm/fill.py:504-506`, in
`queue_plan` (since chunk 8b, 4d78db8):

```python
for entry in model.instance_history(scenario, iid) or ():
    if entry.kind != "queue" or set(entry.suppressed_by) & selected:
        continue
```

`selected` is the set of selected fault ids; the hiding instance's plant
time (T0, a pause's instant, or the tail) is never consulted, and the item
the function emits has a `planted_at` but no end.

### Where this pattern exists today

`tools/gm/history.py` (chunk 10a, 18c85f0) handles `suppressed_by` for the
Prometheus overlays from the hiding instance's planting, as D543 says;
only the fill's queue items differ.

---

## Spec and intent

- Specs and decisions: master spec 9.5 (fault eligibility,
  `suppressed_by`), 6.3 and 6.9; formats.md v37; spec D543 (from the
  hiding instance's planting), D548 and D578 (no covered fault uses it).
- Intent records: none recorded (no intent register).
- Verdict: **code bug** (the fill breaks D543).

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | Low: no v0.6 scenario has a `suppressed_by` pair |
| Impact | Medium when met: the hidden fault's queue trail is missing from the forged past for the whole span; a player comparing scheduler metrics with the logs could see the gap |
| Detectability | Low: no error; only a comparison of the fill's metrics with the fault's planting shows it |
| Current mitigation | D578: no covered fault carries `suppressed_by`; the composer's overlays follow D543 |

---

## Recommended fix

**Short term:** none needed while no covered fault uses `suppressed_by`;
a fault definition gaining one must come with this fix.

**Medium term:** in `queue_plan`, find the earliest planting (virtual
instant) among the selected instances of the hiding faults; if it falls
before the fill's end, emit the item with an end (`until`) at that instant
and have the scheduler's fill mode stop the effect there; if the hider is
planted in the tail, emit the item unchanged. Share the "hiding instance's
planting" helper with `history.py` so both read it the same way.

**Long term:** one function resolving every instance's effective window
(planting to suppression), used by the fill, the composer and the checks.

**Test:** a `test_fill.py` case with a pair (hider at T0, at a pause, in
the tail) checking the queue items' windows; the scheduler's fill-mode
unit test honouring `until`.

---

## Extra data

Found while building chunk 10 (wave log "Chunk 10 — merged (552259f),
2026-11-19", finding (b)).

---

## References

- `tools/gm/fill.py:487-514` (`queue_plan`)
- `tools/gm/history.py` (the composer's `suppressed_by` handling)
- `specs/versions/v0.6/master-spec.md` 9.5; `specs/formats.md` v37;
  `specs/decisions.md` D543, D548, D578
- `specs/versions/v0.6/wave-log.md`, wave 3

---

## Change log

- **2026-11-19**: filed (owner: "file it as an issue").
