# <Brick name> brick — GM notes

<!-- Template: bricks/<brick-id>/docs/gm.md (spec D56, specs/formats.md,
"`docs/gm.md` must contain"; v0.2 master spec 6.2; v0.3 master spec 6.4
and capture W1 item 5). Keep the nine level-2 headings, with these
exact names, in this order. Add your own sections as subsections of a
required one, or after Known limits. No required section stays empty: one
that does not apply says so in a sentence, with the reason. Everything
here agrees with brick.yaml and introduces nothing brick.yaml lacks,
and Supported faults agrees with the catalog faults' applies_to.
State placement and connections as requirements, never in a platform's
own syntax. Never shipped to players. Drop this comment once filled. -->

GM documentation of the `<brick-id>` brick (`brick.yaml`). Never shipped
to players.

## Purpose

<What the brick is (technology, engine or tool version, image), the roles it fills, and when the GM picks it.>

## Placement

<What gets installed (a node of its own, and any companion material the GM mounts into other nodes at deploy) and how to build it; how many per scenario; next to which node; stateful or not; which networks it joins.>

## Configuration

<Every parameter and per-scenario or per-node value, the per-node values of mounted companion material included (meaning, default, valid values, where it lands); the knobs and their default envelopes; the secrets (with their kind) and seed files and what they must contain; what start-up does.>

## Connections

<For each interface provided or consumed: the other side, port and protocol, what the GM wires and where, the account it needs and which parameter supplies it, what must exist first; what it exposes to monitoring; whether its image accepts another brick's mounted companion material (brick.yaml `receives`: s6-overlay version, commands). A brick that consumes nothing says so.>

## Access

<How the player reaches it (account, group, sudo wrappers, any web interface and its path through the bastion's web front); writable and protected paths; write policies, and under report-only what `write_overrides` may make fixable (only `writable_paths`) and what the reload and restart wrappers refuse; capabilities added back and why; what the GM itself uses.>

## Footprint

<Default limits (CPU, memory) and reservations (CPU, memory, disk) as brick.yaml's `footprint` declares them, at rest, and its disk growth per hour (`disk_growth_per_hour`, measured or marked provisional); what makes it grow and how to size it for the capacity check; what its mounted companion material adds to each node it lands on; the levers that shrink it.>

### Snapshot

<How each volume is copied at hand-over, as brick.yaml's `snapshot:` declares it (every volume but /run: `pg_basebackup`, `copy` or `stop`; every volume by `stop` when the key is absent); for `stop`, which services stop, for how long, and what players see meanwhile; how the copy is restored.>

## Supported faults

<The catalog faults whose `applies_to` names this brick and version, all of them and no other (D59), in a table whose first column is the fault id, with what each needs from it; catalog faults only: a fault in a scenario's own `faults/` is the scenario's and is not listed (D62); faults it lends itself to without a definition yet; known interactions; where not obvious, faults it cannot host and why.>

## Checks

<Its validator (may be red from the start), health check, companion checks and when to run them, how the GM confirms after deployment that it works and is wired (every scrape target up, the exporter connected), and its stack test.>

## Known limits

<What it does not do, or does surprisingly, in this version; "None known." when so.>
