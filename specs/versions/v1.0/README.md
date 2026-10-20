# v1.0 — first release

Status: scoping. No master spec, no build plan.

## Scope

The first release (D4) supports and runs a complex scenario:

```
producer -> database -> transformation -> database -> consumer
            + monitoring tools on the stack
            + the bastion
```

How the scenario format and brick model express this topology is in
[formats.md](../../formats.md) ("Expressing the v1.0 pipeline"). v1.0
builds on [v0.1](../v0.1/README.md).

## Open for this version

- O11 — which technology fills each role (producer, the two databases,
  transformation, consumer, monitoring), and which versions.
- Whether v1.0 has the GM design scenarios from a partial or empty brief,
  filling the blanks (D16), or scenarios are still hand-written (O2, O29).
- O12 (network layout), O22 (aging defaults), O23 (fault mix and
  difficulty), O25 (agent-built bricks and faults).
- A definition of done, once v0.1's is settled.
