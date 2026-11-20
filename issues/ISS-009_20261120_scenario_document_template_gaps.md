# Issue: the scenario-document template has no case for five things scenarios carry, so regenerated documents drop or improvise them

**ID:** `ISS-009_20261120_scenario_document_template_gaps`
**Ref:** `ISS-009`
**Date:** 2026-11-20
**Severity:** Medium
**Status:** Open
**Target:** v0.7 (the owner, at v0.6's G11; spec D601)
**Component:** `.claude/skills/scenario-document/template.md`
**Affects:** `.claude/skills/scenario-document/SKILL.md`; every scenario's `README.md` (the scenario document) generated from the template: the 34 fixture documents chunk 16 regenerated (`tools/tests/fixtures/*/README.md`), `scenarios/aldermoor-centre/README.md` on its next regeneration
**Seen on:** v0.6 wave 4, `v0.6-w4` after chunk 16's merge (d24715c); fixtures `fixture-monitoring-v05`, `fixture-reports`, `fixture-register`, `fixture-clinic-load`, `fixture-archive`
**Reported by:** found while coding (v0.6 chunk 16's owner, regenerating every fixture's document from chunk 12c's template); filed at G10.4 by `spec-writer`

---

## Summary

The scenario document is filled from the authoritative files by the
`scenario-document` skill's template. Chunk 16 regenerated every
fixture's document from it and found five places where a scenario
carries something the template has no case for. Where an older document
carried the information by hand, the regenerated one lost it; the
clinic's document (aldermoor-centre) carries two lines the template
doesn't define, so its next regeneration may drop or reword them. The
GM reads this document to run the game, so a lost standby or option line
is information the GM no longer has.

---

## What happens

### Expected

The document shows what the scenario's files set (formats.md
"Scenario", "The scenario document"; the skill's rule "from the
authoritative files only"), the same way on every regeneration.

### Observed

From chunk 16's record (wave log, "Chunk 16 — merged (d24715c)"):

1. A node's `options:` (9 fixtures) and `standby_of:` have no place in
   the template. `scenarios/aldermoor-centre/README.md` shows
   "**Options**" and "**Standby of**" lines (lines 152, 223, 228, 295)
   the template doesn't define; `fixture-monitoring-v05` and
   `fixture-reports` lost theirs.
2. "Column classification" (`template.md:643-645`) handles only
   `domain:`; a `domains:` scenario gets "the scenario's own", and
   `fixture-register`, `fixture-clinic-load` and `fixture-archive` lost
   richer wording.
3. Nothing says which database each composed domain loads into except
   the Composition table's "At"; "Restored-backup data"
   (`template.md:639`) reads "none." where the data comes only from
   domains.
4. No wording for an empty `pg_cron` jobs table (chunk 16 kept the
   existing "— | none | … | nothing scheduled in the baseline" row).
5. Calls the chunk's owner made where the template is ambiguous, not
   yet written into it: totals at the end of the placement table;
   scenario-only bricks and faults kept in their existing order; the
   starter-pack line's ", and the data policy"; `cron.schedule` jobs
   listed with role `postgres` in `cron.database_name`.

Also seen in `scenarios/*`, outside chunk 16's scope:
aldermoor-centre lists `s6` under the vault limit though its evidence
reads the data register; bookshop-new-server writes one total as
"2.25G".

### How to reproduce

1. Regenerate a fixture's document with node `options:` (e.g.
   `fixture-monitoring-v05`) from the template as it stands.
2. Compare with its document before d24715c (`git show
   d24715c^:tools/tests/fixtures/fixture-monitoring-v05/README.md`).
3. The options line is gone.

---

## Cause

**Confirmed** (read in the template and chunk 16's diff): the template
predates these keys' use in fixtures (`options:` and `standby_of:` from
v0.5, composed domains from v0.5) and was never given cases for them;
earlier documents carried them because they were written or patched by
hand.

### Where this pattern exists today

Any scenario or fixture with node `options:`, `standby_of:`, or
`domains:`; any `pg_cron` node scheduling nothing.

---

## Spec and intent

- Specs and decisions: formats.md "Scenario" ("The scenario document",
  the skill's template its form); v0.6 master spec 7.6; spec D538 (every
  fixture's document regenerated, chunk 16), D597 (G10.4, routing this).
- Intent records: none (no intent register).
- Verdict: **code bug** in the template: no spec decision is needed;
  the document shows what the files set. The five renderings below are
  proposals for the fix's owner.

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | High: every regeneration of an affected document |
| Impact | Low to Medium: GM-side information lost (a standby, an option, where a domain's data lands); fixtures mostly, the clinic on its next regeneration |
| Detectability | Low: nothing checks the document against the files for these keys |
| Current mitigation | chunk 16's documents reproduce byte for byte with its uncommitted script (scratchpad `gen/scendoc.py`); the clinic's lines still present |

---

## Recommended fix

**Short term:** add the five cases to `template.md`, matching the
clinic's existing lines: per node "**Options**: `<options as
written>`" and "**Standby of**: `<primary>` (no data of its own: cloned
from its primary after the load)"; "Column classification" per domain
for a `domains:` scenario (each domain's classification file named);
"Restored-backup data" naming each composed domain's database (or
"none: the data comes from the domains, see Composition"); the empty
`pg_cron` row as chunk 16 kept it; chunk 16's four calls written as the
template's rules. Then regenerate the affected fixtures' documents and
the clinic's, checking only these lines change. No Docker. Fits the
release gate's fix list or the next chunk touching the skill; the
owner placed it in v0.7 (spec D601).

**Medium term:** commit a generator for the scenario document (chunk
16 used an uncommitted script), so regeneration is mechanical and
testable.

**Long term:** a check that every scenario key the template knows
appears in the document.

**Test:** a unit test rendering a fixture with `options:`,
`standby_of:`, `domains:` and an empty `pg_cron` node, asserting each
line.

---

## Extra data

Chunk 16: 34 fixture documents from chunk 12c's template (32
regenerated, 2 unchanged); a second run reproduces all 34 byte for byte.

---

## References

- `.claude/skills/scenario-document/template.md:211-215`, `:639-645`
- `scenarios/aldermoor-centre/README.md:152`, `:223`, `:228`, `:295`
- `specs/versions/v0.6/wave-log.md`, "Chunk 16 — merged (d24715c)"
- `specs/archive/v0.6/build-plan.md`, chunk 16; spec D538, D597

---

## Change log

- **2026-11-20**: filed at v0.6's G10.4 from chunk 16's record.
- **2026-11-20**: target set to v0.7 by the owner at v0.6's G11 (spec
  D601).
