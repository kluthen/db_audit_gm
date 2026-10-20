# v1.0 — first release

Status: draft. No master spec, no build plan.

## Scope

The first release (D4) supports and runs a complex scenario:

```
producer -> database -> transformation -> database -> consumer
            + monitoring tools on the stack
            + the bastion
```

How the scenario format and brick model express this topology is in
[formats.md](../../formats.md) ("Expressing the v1.0 pipeline").

## How it is reached

The owner believes v0.2 to v0.5 "should be sufficient to achieve v1.0"
(D47):

| Pipeline part | Arrives in |
|---|---|
| Bastion, one database, the GM stance, the formats | [v0.1](../v0.1/README.md) |
| Monitoring tools | [v0.2](../v0.2/README.md) |
| Producer, consumer | [v0.3](../v0.3/README.md) |
| Transformation, second database | [v0.4](../v0.4/README.md) |
| Catalog breadth, topology fragments, schemas and datasets | [v0.5](../v0.5/README.md) |

Which technology fills each role is decided version by version (O11).

## Gaps between "v0.2–v0.5 is sufficient" and v1.0

Every part of the pipeline has a version. What has no version yet, and may
be needed for v1.0, is put to the owner:

- **Multi-host and the registry** (O46). v0.1 runs on one host and
  deferred both. A full pipeline with monitoring may not fit one laptop,
  and classroom swarms were a hosting target from the start.
- **Generating scenarios** (O47). The GM designing a scenario from a
  partial or empty brief and filling the blanks is settled as a capability
  (D16) but placed in no version; v0.5 prepares for it (topology fragments,
  schemas) without naming it.
- **Aging and the solvability probe** (O48). Both were deferred from v0.1;
  load (v0.3) and generated scenarios need them.
- **Backup tooling** (O49). Backup tools and the backup-tooling fault
  families (D17) are in no version, although backups were a founding
  example of the project and the v0.1 goal speaks of "investigating a
  backup".

## Beyond v1.0

- The GM playing the customer during the game, and the GM giving hints
  (with node resets and extra time): both out of v1.0 scope (D48).
- Other databases and tools: TimescaleDB, columnar databases, MySQL and
  others (D47).

## Open for this version

- A definition of done, once the gaps above are placed.
- O2 (scripts versus agent judgment for generated scenarios), O20 (the
  solvability probe as a gate), O29 (brief format), O30 (preparation time
  before a class), O32 (language of player-facing material), O38 (feedback
  score), O5 (a lighter record of intent).
