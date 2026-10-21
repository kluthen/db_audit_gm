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
  bastion-only rule (O13).
- GM documentation for every brick (D56): each brick's `docs/gm.md`
  has the required sections of [formats.md](../../formats.md),
  "`docs/gm.md` must contain" (placement, configuration, connections,
  footprint, supported faults and the rest), from the new monitoring
  bricks on; the v0.1 bricks (`postgres`, `bastion`) are brought up to
  it, and the format skill's brick check refuses a brick without them.
- Monitoring-related fault families as far as a static or near-static
  database allows (a collector pointed at the wrong node, a host not
  collected, a threshold in the wrong unit).

## Out of scope

- Producers, consumers and load (v0.3); transformers (v0.4).
- Monitoring faults that only show under load, until v0.3.

## Depends on

- v0.1: the formats, the GM stance, the scripts and the PostgreSQL brick.

## Questions due in this version

- O13: how players reach the monitoring web interfaces through the bastion.
- O11: which monitoring tools.
- O12: network layout (a monitoring network, which nodes see which).
- O22: aging, since dashboards need history to show anything.
- O50: monitoring arriving before there is any load to show.
- O51: container and host monitoring usually needs the Docker socket or
  host mounts, which collides with the rule that the player side never
  gets a Docker socket.
- O46: whether the monitoring stack still fits one host.
- O56: whether the v0.1 bricks' documentation update bumps their version.
