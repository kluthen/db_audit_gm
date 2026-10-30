# v0.4 — a first scenario sketch

Status: draft v1 (a sketch: the purposes are O107's, the topology
O120's)

A first v0.4 scenario, to test that the purposes, the data model and the
governance cut make a game. Working id `tarnbeck-outdoor-campaign`.

## Story

Tarnbeck Outdoor, six months after the v0.3 audit. The shop now sells
abroad, including outside the customs union. Lumen Analytics, a BI
agency, moved the back office's figures to a reporting database and
runs the nightly and hourly roll-ups; it also built a "churn" table for
a dashboard. The marketing team, in-house, runs a win-back campaign by
e-mail and the shop's shipping notices; the shipping manager runs the
export declarations to the customs gateway. Ines Varga asks for an
audit after complaints: customers who unsubscribed still get mail,
some get every shipping notice twice, a customer abroad got a promotion
at 3 a.m., the accountant's revenue never matches the dashboard, and the
dashboards froze this morning. She hands over the company's data policy
with the story.

## Topology (proposed)

| Node | Brick | Role | Write policy | New in v0.4 |
|---|---|---|---|---|
| `bastion` | `bastion` | bastion | report-only | |
| `db` | `postgres` | database (`shop`) | fixable | the data model of shop-domain.md |
| `pooler` | `pgbouncer` | pooler | fixable | |
| `producer` | `scheduler` | producer (web shop) | report-only, repository and jobs fixable | consent streams, shipping and destination columns |
| `consumer` | `scheduler` | consumer (back office) | report-only, jobs fixable | KPIs read from `reporting` |
| `reporting` | `postgres` | database (`reporting`) | report-only (the agency's) | yes (O120) |
| `bi` | `scheduler` | consumer: P1's runner | report-only (the agency's) | yes |
| `crm` | `scheduler` | consumer: P2, P3 and P5's runner | report-only, repository and jobs fixable | yes |
| `gateway` | `scheduler` | consumer: the customs gateway stub | report-only | yes |
| `prometheus`, `exporter`, `grafana` | as v0.3 | monitoring | as v0.3 | the reporting instance not scraped (O125) |

About 600 MB of reservations more than tarnbeck's 1.25 GB (a `postgres`
node at 256 MB, three scheduler nodes at 64 MB, the data's growth), on
the same two designed hosts: `reporting`, `bi` and `gateway` on host 2.
To measure at the rehearsal.

The agency's nodes are report-only: its faults are *report* or
*propose*, as tarnbeck's I5 was.

## Time

As tarnbeck: T0 22:00, hand-over 14:00, sixteen hours of aging, four
hours of play. During the aging: one nightly close (01:30), sixteen
hourly roll-ups and extractions, the campaign from 08:00, the notices
and declarations all along. During the game: hourly and quarter-hour
runs; the nightly close only if the players move it (D132).

## Fault instances (proposed; ten, difficulty normal)

| # | Fault | Purpose | Visibility |
|---|---|---|---|
| f1 | `purpose-mail-overlapping-window` | P3 | known (I1) |
| f2 | `purpose-leads-stale-consent` | P2 → P3 | known (I2) |
| f3 | `purpose-mail-outside-hours` | P3 | known (I3) |
| f4 | `purpose-watermark-misses-updates` | P1 | known (I4, propose: the agency's) |
| f5 | `purpose-mapping-password-expired`, planted `handover-5h` | P1 | known (I5) |
| f6 | `purpose-mail-payload-other-customer` | P3 | hidden |
| f7 | `purpose-day-boundary-wrong-zone` | P1 | hidden |
| f8 | `purpose-receiver-down-unnoticed` | P5 | hidden |
| f9 | `governance-personal-copied` | P1, policy | hidden |
| f10 | `prometheus-scrape-target-missing` (the reporting instance), or `governance-fdw-imports-personal` | monitoring or policy | hidden |

## Issues (sketch)

- **I1** (fix): "Customers say they get every shipping notice twice."
- **I2** (fix): "People who unsubscribed last week still get our win-back
  e-mails. That is exactly what the data policy forbids."
- **I3** (fix): "A customer abroad, eight hours behind us, complained
  about a promotion at 3 a.m. his time." (Relative, never a city: the
  customer's zone moves with the shift, O122.)
- **I4** (propose): "The accountant's invoiced revenue never matches the
  dashboard's, and the gap grows. The figures are Lumen's: tell us what
  they should change."
- **I5** (fix): "The dashboards stopped updating this morning."

## What it tests

- every trace kind: outbox rows (f1, f3, f6), published results (f4,
  f7), a run ledger (f5), triggers and acknowledgements (f8), a
  definition (f9);
- the judged moment: f1 to f3 fixed and confirmed within the game by
  quarter-hour runs; f7 confirmable only by moving the nightly close;
- governance against a stated policy (I2 cites it; f9 is found only by
  reading it);
- shift invariance: f3 and f7 hold at any shift (O122).
