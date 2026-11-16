# Issue: formats.md's status line says draft v32 while its text is at v33

**ID:** `ISS-003_20261114_formats_status_line_stale`
**Ref:** `ISS-003`
**Date:** 2026-11-14
**Severity:** Low
**Status:** Resolved
**Component:** `specs/formats.md`
**Affects:** readers judging which format version a scenario follows; G19's record
**Seen on:** main a56e5ac, line 3
**Reported by:** found while coding (v0.5 release gate, item 6)

---

## Summary

`specs/formats.md` opens with "Status: draft v32". G19 (2026-11-12) brought
the text to v33, and the wave log and the build plan say v33. Readers can't
tell from the file which version they're reading.

---

## What happens

### Expected

The status line names the version the text is at (v33, after G19).

### Observed

`Status: draft v32; its v0.5 items ruled with the v0.5 master spec (D339), …`

### How to reproduce

1. `sed -n 3p specs/formats.md`

---

## Cause

**Confirmed**: G19's edit updated the body and the later status sentences,
but not the version number at the head of the line.

---

## Spec and intent

- Specs and decisions: G19 (build plan v0.5), D459, D465, D468, D469.
- Intent records: none recorded.
- Verdict: **spec gap**. A documentation slip; spec-writer fixes it.

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | High: every reader |
| Impact | Low |
| Detectability | Medium |
| Current mitigation | the wave log records v33 |

---

## Recommended fix

**Short term:** spec-writer sets the status line to v33 when writing v0.5's
release notes.

**Test:** none; checked at the next release gate's item 6.

---

## References

- `specs/formats.md:3`
- `specs/versions/v0.5/wave-log.md`, "Release gate — results, 2026-11-13"

---

## Change log

- **2026-11-14**: filed.
- **2026-11-14**: resolved in 146429e (spec-writer, at v0.5's close): the status line reads draft v33. No test; checked by reading at the next release gate's item 6.
