---
name: scenario-document
description: Use whenever a db_audit_gm scenario's README.md (the scenario document) has to be generated or regenerated — once scenario.yaml and gm/answer-key.yaml are complete, after any change to either, before deploying a scenario whose README is missing or stale, or when grounding a GM on a restart or a re-spawn elsewhere. Fills the template from the authoritative files; the README is never edited by hand and always opens with the "do not read" warning.
---

# Scenario document

A scenario's `README.md` is its **scenario document**: the readable whole
of the scenario, for the GM and the lead. It is **generated** from the two
authoritative files, `scenario.yaml` and `gm/answer-key.yaml`, with this
skill's [template](template.md). It is the **initial version (v0.1)** and
is expected to evolve as games are played; when a game shows the document
is missing something, change the template and this skill together, and
the [format skill](../scenario-format/SKILL.md)'s templates first if the
missing thing is not in the authoritative files yet.

Source of the shape: the master spec (`specs/versions/v0.1/master-spec.md`,
section 6, and 6.2 for the content). The template's sections follow the
keys of the format skill's
[scenario.yaml](../scenario-format/templates/scenario.yaml) and
[answer-key.yaml](../scenario-format/templates/answer-key.yaml) templates,
so the document is filled field by field.

## What it is for

- **Grounding.** On a session restart, or when the scenario is spawned
  again on another playground or later, the GM reads the document first
  for the whole picture, then the authoritative files for the detail.
  With the repository (for the catalog) and the GM skills, the scenario
  folder is enough to start the exercise again.
- **Review.** The lead reviews the defects, issues and answer key in one
  place.
- **Not for players.** It holds every hidden fault and every answer. It
  opens with a prominent warning that students and players should not
  read it; enforcement goes no further (scenarios live in the repository
  in bulk, which is accepted). The starter pack under `player/` does not
  carry the warning, and nothing of this document goes into it.

## When to generate or regenerate

- When the scenario is first complete: the format skill's step 6, once
  `scenario.yaml` and `gm/answer-key.yaml` pass its completeness checklist.
  An incomplete scenario gets the format skill's list of missing items,
  not a document.
- After **any** change to `scenario.yaml`, `gm/answer-key.yaml` or
  `brief.md`, in the same change.
- Before deploying, when `README.md` is missing or does not match the
  authoritative files (its scenario version, or any value, differs).
- After this template changes, for the scenarios the GM is about to use.

## Never edit it by hand

The document is output. To change what it says, change `scenario.yaml` or
`gm/answer-key.yaml` (or `brief.md`) and regenerate. When the document and
the authoritative files disagree, the files win: regenerate, do not
reconcile by hand. A hand-written note that belongs to the GM goes to
`gm/notes.md`, which the document links to.

## Generating it

1. **Check completeness** with the format skill. Stop on any missing item.
2. **Read the inputs**: `scenario.yaml`, `gm/answer-key.yaml`, and
   `brief.md` (quoted as given). Nothing else is a source: the document
   names the other files of the folder by path, it does not copy them.
3. **Copy [template.md](template.md)** to `scenarios/<id>/README.md` and
   fill it top to bottom. Each section names the keys it comes from.
   Repeat a block once per entry where its comment says so, in the order
   of the YAML. Write an empty list or map as the comment says ("None.",
   "No issues given."); never drop a section because it is empty.
4. **Keep the warning first**, as the template has it: nothing above it,
   not even the title.
5. **Clean up**: the generated file keeps no `<placeholder>` and no
   template comment (`<!-- ... -->`).
6. **Check by reading**:
   - the warning is the first thing in the file;
   - every node, flow, fault instance and issue of `scenario.yaml`
     appears, and every answer-key entry, one per fault instance;
   - every value matches its key (versions pinned, knobs' initial values
     and envelopes, reservations, placement);
   - each file path it names exists in the folder (`local/` excepted: it
     is never named);
   - the document is not named in any node's `seed_files` and nothing
     under `player/` quotes it.

## What it does not describe

- **A playground.** The document describes the host topology and capacity
  the scenario was **designed for** (`designed_for`). The local
  implementation of a deployment (`local/<playground>/`: rendered stack,
  state, ports actually used) is separate, git-ignored, written by the GM
  at deployment, and never appears in the document.
- **Catalog internals.** Bricks and fault definitions are named by id and
  pinned version; their own docs (`docs/gm.md`, `gm.md`) stay where they
  are.
