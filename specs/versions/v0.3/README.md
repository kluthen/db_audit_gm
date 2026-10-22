# v0.3 — producers and consumers

Status: draft. No master spec.

## Goal

In the owner's words (D47):

- Producers, "the first being the most important: they will schedule data
  ingestion, load spikes, etc. and are the main opportunity for
  ill-formatted requests, misbehaving requests, or ill-targeted requests."
- "Consumers have it similar, albeit on their end it is more probably a
  question of breadth of query: taking in too much, transactions taking
  too long, BI queries, etc."

## In scope

- Producer bricks: scheduled ingestion, load spikes, and faulty request
  patterns (ill-formatted, misbehaving, ill-targeted).
- Consumer bricks: broad queries, long transactions, BI-style queries.
- Load calibrated against the nerfed databases: enough to show symptoms,
  not enough to saturate the host.
- Fault families that need activity: contention, lock waits, bloat
  growing, data-flow defects (duplicates, dropped records).
- Report-only nodes in practice: producers and consumers are typically
  observed, not fixed.
- Report-only monitoring nodes (proposed, D108): the renderer passing a
  node's write policy to its container, so that `prometheus`,
  `postgres-exporter` and `grafana`, fixable only in v0.2, can also run
  report-only.
- Restarting a game on the players' request (proposed, D110): the GM
  tears down and rebuilds the whole stack. The owner allows it from this
  version, and only on the players' **explicit confirmation**: "we can't
  have a passing comment just restart the game, as it's highly breaking
  change". The GM states what a restart loses and restarts only once the
  players confirm it in so many words; a passing mention, or a question
  about restarting, never restarts a game. The mechanics are O81. Until
  then the stance stays v0.2's: no restarts.

## Out of scope

- Transformers between databases (v0.4).
- A message queue, unless a producer needs one (decided with O11).

## Depends on

- v0.1; v0.2 for monitoring that shows the load.

## Questions due in this version

- O11: producer and consumer technologies, and whether a queue is needed
  (NATS, Redpanda; the latter is memory-hungry).
- O22: aging and time compression; scheduled ingestion makes compressed
  schedules visible to the auditor.
- O23: number and mix of faults, and what difficulty means, once faults
  multiply.
- O45: `ALTER SYSTEM` by a superuser on report-only database nodes.
- O48: where aging and the solvability probe enter the roadmap.
- O46: capacity on one host once load runs.
- O81: how a game restart works: the explicit confirmation, what the
  rebuild keeps and redoes, how it is recorded.

Possible input: Bluebox ships its own load generator (Python,
realistic web-traffic patterns), but Bluebox itself is planned for v0.5
(O53).
