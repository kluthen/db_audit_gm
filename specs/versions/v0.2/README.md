# v0.2 — monitoring and usual tooling

Status: draft. No master spec.

## Goal

In the owner's words: "We will first bundle a few bricks with the most
common (free, open-source) monitoring tools: some Grafana dashboard, some
system monitoring tool (docker up and down, load, etc.), eventually log
aggregators." (D47)

## In scope

- Monitoring bricks built from common free, open-source tools: a Grafana
  dashboard, a system-monitoring tool (containers up and down, load), and
  possibly a log aggregator. Which tools: O11.
- Their place in the scenario format: monitoring nodes and *monitors*
  flows, their footprint in the capacity check.
- The players reaching the monitoring interfaces while keeping the
  bastion-only rule: the bastion publishes them (D68; how: O63).
- GM documentation for every brick (D56): each brick's `docs/gm.md`
  has the required sections of [formats.md](../../formats.md),
  "`docs/gm.md` must contain" (placement, configuration, connections,
  footprint, supported faults and the rest), from the new monitoring
  bricks on; the v0.1 bricks (`postgres`, `bastion`) are brought up to
  it, and the format skill's brick check refuses a brick without them.
  That update bumped both bricks to 0.1.1 (D57).
- Brick versioning, partly settled: any change to a brick bumps its
  version, a fault or scenario that only re-pins a brick or widens
  `applies_to` keeps its own (D57, D58), and a fault's `applies_to` is
  the only statement of which faults a brick hosts, so `compatible_faults`
  leaves `brick.yaml` within 0.1.1 (D59). See
  [formats.md](../../formats.md), "Versions and pins". Faults never bump
  (D60), changes to an unreleased brick version fold into it (D61), and a
  brick's GM documentation lists catalog faults only (D62). Still open:
  other changes to scenarios (O61), version lists or ranges in
  `applies_to` (O60).
- Monitoring-related fault families as far as a static or near-static
  database allows (a collector pointed at the wrong node, a host not
  collected, a threshold in the wrong unit).

## Out of scope

- Producers, consumers and any load: monitoring is thin in v0.2 (D67);
  load is v0.3's. Transformers (v0.4).
- Monitoring faults that only show under load, until v0.3.

## Depends on

- v0.1: the formats, the GM stance, the scripts and the PostgreSQL brick.

## Questions due in this version

Settled on 2026-10-21: the tools (D63–D66, D69, D70; O11 narrowed), no
load (D67, O50), the bastion publishing the UIs (D68, O13), per-node
health without the Docker socket (D66, O51). The page is redrafted with
those rulings in the next pass.

- O62: how a silent tooling expectation is written and judged.
- O63: how the bastion publishes the UIs.
- O64: how the node-health brick is packaged and reaches each node.
- O12: network layout (a monitoring network, which nodes see which).
- O22: aging, since dashboards need history to show anything.
- O46: whether the monitoring stack still fits one host.
- O57: what a brick's footprint states (one figure, or limits and
  reservations), before the monitoring bricks enter the capacity check.
- O58: rendered network names, once a scenario has more than one network.
- O61: when a scenario's version changes, beyond D58.
