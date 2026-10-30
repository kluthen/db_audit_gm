# v0.4 — a first scenario sketch

Status: draft v5 (a sketch on the settled purposes, D197, the
reporting instance, D198, the instances and sizing of D202 and D204,
the jobs on a database node of D206 and D207, the crontab fault of D208
and the out-of-memory incident of D209)

A first v0.4 scenario, to test that the purposes, the data model and the
governance cut make a game. Working id `tarnbeck-outdoor-campaign`.

## Story

Tarnbeck Outdoor, six months after the v0.3 audit. The shop now sells
abroad, including outside the customs union. Lumen Analytics, a BI
agency, moved the back office's figures to a reporting database and
runs the nightly and hourly roll-ups; it also built a "churn" table for
a dashboard, refreshed by a job inside the reporting database, and a
nightly "customer value" roll-up run from the reporting server's own
crontab. The marketing team, in-house, runs a win-back campaign by
e-mail and the shop's shipping notices; the shipping manager runs the
export declarations to the customs gateway. Ines Varga asks for an
audit after complaints: customers who unsubscribed still get mail,
some get every shipping notice twice, a customer abroad got a promotion
at 3 a.m., the accountant's revenue never matches the dashboard, and the
dashboards froze this morning. Lumen also mentions that the reporting
database "restarted itself" one night this week and says it is fine
now. She hands over the company's data policy
with the story.

## Topology (proposed)

Two PostgreSQL instances (D202), each distinct producer on a node of
its own sized down, the transformer that moves volume sized up (D204).

| Node | Brick | Role | Write policy | Sizing (limit / reservation) | New in v0.4 |
|---|---|---|---|---|---|
| `bastion` | `bastion` | bastion | report-only | as v0.3 | |
| `db` | `postgres` 0.4.0 | database (`shop`) | fixable | as v0.3, 1G / 512M | the data model of shop-domain.md; the cron daemon, one light hourly entry, the shop's own (f6) |
| `pooler` | `pgbouncer` | pooler | fixable | as v0.3 | |
| `producer` | `scheduler` | producer (web shop) | report-only, repository and jobs fixable | 96M / 48M, down from 128M / 64M (peak 39M in v0.3) | consent streams, shipping and destination columns |
| `consumer` | `scheduler` | consumer (back office) | report-only, jobs fixable | as v0.3, 128M / 64M | KPIs read from `reporting` |
| `reporting` | `postgres` 0.4.0 | database (`reporting`) | report-only (the agency's) | 512M / 256M | yes (D198); `pg_cron` on, holding f9's job (D206); the cron daemon, the agency's nightly roll-up at 03:00 (f10, D209) |
| `bi` | `scheduler` 0.2.0 | transformer: P1's script and procedure call | report-only (the agency's) | 384M / 192M | yes |
| `crm` | `scheduler` | transformer: P2, P3 and P5's SQL jobs | report-only, repository and jobs fixable | 128M / 64M | yes |
| `gateway` | `scheduler` | producer: the customs gateway stub, writing acknowledgements | report-only | 96M / 48M | yes |
| `prometheus`, `exporter`, `grafana` | as v0.3 | monitoring | as v0.3 | as v0.3 | the reporting instance not scraped (O125) |

Every scheduler node runs `scheduler` 0.2.0, the one version v0.4
ships (D203), and every database node `postgres` 0.4.0 (D206). Both
database nodes run the cron daemon (D208): `db` a light entry, as the
placement guideline allows, `reporting` a heavy one, as it does not
(D207). The figures are starting points, set from v0.3's
rehearsal peaks and measured at v0.4's.

About 600 MB of reservations more than tarnbeck's 1.25 GB (`reporting`
256 MB, `bi` 192 MB, `crm` 64 MB, `gateway` 48 MB, the producer 16 MB
less, the data's growth). On two designed hosts, `reporting`, `bi` and
`gateway` on host 2; on a one-host playground every node on that host,
as v0.3 places them. A node is a scenario node, not a host (D204).

The agency's nodes are report-only: its faults are *report* or
*propose*, as tarnbeck's I5 was.

## Time

As tarnbeck: T0 22:00, hand-over 14:00, sixteen hours of aging, four
hours of play. During the aging: one nightly close (01:30), sixteen
hourly roll-ups and extractions, the campaign from 08:00, the notices
and declarations all along. During the game: hourly and quarter-hour
runs; the nightly close only if the players move it (D132).

The incident (f10, D209): the backfill request is planted at
`handover-12h` (02:00), the roll-up runs at 03:00 and is killed, the
reporting instance recovers within seconds, the next night runs
normally. At hand-over it is eleven hours old. The early check and the
nightly close (01:30) stay clear of it.

## Fault instances (proposed; ten, difficulty normal)

| # | Fault | Purpose | Visibility |
|---|---|---|---|
| f1 | `purpose-mail-overlapping-window` | P3 | known (I1) |
| f2 | `purpose-leads-stale-consent` | P2 → P3 | known (I2) |
| f3 | `purpose-mail-outside-hours` | P3 | known (I3) |
| f4 | `purpose-watermark-misses-updates` | P1 | known (I4, propose: the agency's) |
| f5 | `purpose-etl-role-expired`, planted `handover-5h` | P1 | known (I5) |
| f6 | `security-crontab-superuser`: `db`'s hourly refresh of the web shop's small "popular products" view runs as `postgres` by peer, while the role prepared for it sits unused (D208) | the shop's own job | hidden |
| f7 | `purpose-day-boundary-wrong-zone` | P1 | hidden |
| f8 | `purpose-receiver-down-unnoticed` | P5 | hidden |
| f9 | `governance-personal-copied`, its refresh a `pg_cron` job on `reporting` that no runner lists (`purpose-pg-cron-hidden-job`'s form) | P1, policy | hidden |
| f10 | `purpose-heavy-job-on-database-node`: the out-of-memory incident on `reporting`, once, during the aging (D209) | P1's neighbour, the agency's roll-up | known (I6, report) |

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
- **I6** (report): "Lumen says the reporting database restarted itself
  one night this week and that it is fine now. Is it? Tell us what
  happened and what should change."

## What it tests

- every trace kind: outbox rows (f1, f3), published results (f4,
  f7), a run ledger (f5), triggers and acknowledgements (f8), a
  definition (f9);
- four places jobs run from: a transformer script (f4, f5), a stored
  procedure over `postgres_fdw` (f5, f7; D202), a `pg_cron` job on a
  database node (f9; D206), and a cron daemon on a database node (f6,
  f10; D208). f9 is fixed only when the job is found too: dropping the
  table alone lets the job refill it;
- placement (D207): `db`'s light entry is well placed and wrongly
  privileged (f6, a fix); `reporting`'s heavy roll-up is wrongly placed
  and shows it once (f10, a report);
- an incident in the recent past, real and recovered from, judged by
  the players' report rather than a live state (f10);
- the judged moment: f1 to f3 fixed and confirmed within the game by
  quarter-hour runs; f7 confirmable only by moving the nightly close;
- governance against a stated policy (I2 cites it; f9 is found only by
  reading it);
- shift invariance: f3 and f7 hold at any shift (O122).

## What was dropped for D208 and D209

The count stays at ten, difficulty normal. Two faults left the sketch
and stay in the catalogue:

- `purpose-mail-payload-other-customer` (was f6): P3 keeps two faults
  (f1, f3) and f2's chain into it; its outbox trace is still tested.
- f10's open choice (`security-definer-procedure-open`,
  `security-fdw-mapping-public` or `prometheus-scrape-target-missing`):
  the stored procedure stays tested through f5 and f7.
