---
name: scenario-document
description: Use whenever a db_audit_gm scenario's README.md (the scenario document) has to be generated or regenerated — once scenario.yaml and gm/answer-key.yaml are complete, after any change to either, before deploying a scenario whose README is missing or stale, or when grounding a GM on a restart or a re-spawn elsewhere. Fills the template from the authoritative files; the README is never edited by hand and always opens with the "do not read" warning.
---

# Scenario document

A scenario's `README.md` is its **scenario document**: the readable whole
of the scenario, for the GM and the lead. It is **generated** from the two
authoritative files, `scenario.yaml` and `gm/answer-key.yaml`, with this
skill's [template](template.md). This is its **v0.2 version**, expected
to evolve as games are played; when a game shows the document
is missing something, change the template and this skill together, and
the [format skill](../scenario-format/SKILL.md)'s templates first if the
missing thing is not in the authoritative files yet.

Source of the shape: v0.1's master spec (`specs/versions/v0.1/master-spec.md`,
section 6, and 6.2 for the content) and v0.2's
(`specs/versions/v0.2/master-spec.md`, 6.3: evidence `where` and `source`,
tooling expectations; 7.1 and 7.6: the node-health map and the web front's
routes, rendered as "Map-valued parameters" below). The template's sections follow the
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
   One exception: a node's parameter whose value is a map is rendered by
   its `shape`, read from the pinned brick's `brick.yaml` (see
   "Map-valued parameters" below).
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
     appears, and every answer-key entry, one per fault instance, with
     each evidence entry's `where` and `source`, and every tooling
     expectation;
   - every entry of a map-valued parameter appears, in the order of the
     YAML and as `scenario.yaml` writes it: each `node-map` entry with
     its node and its services (or `default`), each `web-routes` route
     with its `ui:<name>`, its path, its node and its port;
   - every value matches its key (versions pinned, knobs' initial values
     and envelopes, reservations, placement);
   - each file path it names exists in the folder (`local/` excepted: it
     is never named);
   - the document is not named in any node's `seed_files` and nothing
     under `player/` quotes it.

## Map-valued parameters

A node parameter whose value is a map (capture W1 item 2 of
`specs/versions/v0.2/wave-log.md`) is not written inline as YAML. Its
rendering is keyed on the parameter's `shape` in the **pinned brick's
`brick.yaml`**: the scenario's `bricks/<id>/brick.yaml` when the
scenario carries the brick, the catalog's `bricks/<id>/brick.yaml`
otherwise. That file is read for this alone, and is the one catalog file
the skill reads; a scenario-local brick's map is covered the same way.
On the node's **Parameters** line the parameter is named and pointed
below ("node_health: the node-health map, below"); its block follows the
node's bullets, before its resources (see the template).

- **`node-map`** (`prometheus`'s `node_health`): one item per entry, in
  YAML order, the node and its services, comma-separated; `default` is
  kept as written and glossed as the brick's s6 processes ("`default`
  (its brick's s6 processes)"). Then one line, in master spec 7.1's and
  the access model's wording: "The node-health script is mounted into
  every node listed, read-only for players; its endpoint is readable
  from every node of the game, the bastion included." The map is shown
  as `scenario.yaml` states it, before any parameter fault: a fault
  leaving a node or a service out is listed in section 5, never applied
  here.
- **`web-routes`** (the bastion's `web_routes`): a table, one row per
  route, in YAML order: the route as `ui:<name>` (the name the answer
  key's evidence uses), its path `/<name>/` on the web front, the
  upstream node and port (the value `"<node>:<port>"` split). Then one
  line, in master spec 7.6's and access model 5 and 7's wording:
  "Published on the bastion's web front port, behind HTTP basic
  authentication on the tools password; a request without it is refused
  with HTTP 401." An empty map (`{}` written in `scenario.yaml`): no
  table, and the line "Web front routes (`<NAME>`): none. The web front
  does not run, the bastion publishes SSH only and no tools password is
  handed over." A parameter the scenario leaves out (its brick's default
  applies) is not rendered: the Parameters line says what
  `scenario.yaml` writes.

A shape not listed here is a change to this skill and its template
first; never invent its rendering.

## What it does not describe

- **A playground.** The document describes the host topology and capacity
  the scenario was **designed for** (`designed_for`). The local
  implementation of a deployment (`local/<playground>/`: rendered stack,
  state, ports actually used) is separate, git-ignored, written by the GM
  at deployment, and never appears in the document.
- **Catalog internals.** Bricks and fault definitions are named by id and
  pinned version; their own docs (`docs/gm.md`, `gm.md`) stay where they
  are.
