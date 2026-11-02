# GM notes — tarnbeck-outdoor-campaign

Sealed. Longer explanations for the feedback; the authoritative answer is
`answer-key.yaml`, and each fault's own `gm.md` (under `faults/`) has the
general background. Built as capture W4 of
`specs/versions/v0.4/wave-log.md` settles it (master spec 16.1 to 16.5).

## The shape of the game

Tarnbeck Outdoor six months after `tarnbeck-outdoor-shop`: the same shop,
now with purposes (what the company does with its data), a second
instance run by an agency, jobs in four places (transformer scripts and
statements, a stored procedure over `postgres_fdw`, `pg_cron`, a cron
daemon) and a data policy the players audit against. Ten defects; six
known, four hidden.

| Instance | Defect | Node | Planted | Visibility | Issue |
|---|---|---|---|---|---|
| f1 | shipping notices' window ten minutes for a five-minute job: every notice twice | crm | T0 | known | I1 (fix) |
| f2 | win-back jobs test the opt-in flag, which the web shop's release at T0 stopped clearing | crm (+ producer's timeline) | T0 | known | I2 (fix) |
| f3 | campaign's sending hours read in the company's zone | crm | T0 | known | I3 (fix) |
| f4 | hourly roll-up's watermark on `placed_at`: the noon invoicing never reaches reporting | bi | T0 | known | I4 (propose) |
| f5 | `shop_etl` expired at 09:00: every roll-up refused, dashboards frozen | db | handover-5h | known | I5 (fix) |
| f6 | `db`'s hourly crontab entry connects as `postgres` by peer; `shop_refresh` unused | db | T0 | hidden | — |
| f7 | nightly close cuts the day three hours off the customer's zone | reporting | T0 | hidden | — |
| f8 | escalation handles rejections only; the gateway's 08:00–10:00 outage unnoticed | crm (+ gateway's timeline) | T0 | hidden | — |
| f9 | `pg_cron` job copying names and e-mail addresses into reporting through the back office's login | reporting | T0 | hidden | — |
| f10 | heavy roll-up in reporting's crontab killed for memory at 03:00 by a backfill request | reporting | handover-12h | known | I6 (report) |

The story hints at each hidden item without naming it: the best-sellers
refresh "from its own crontab" (f6), the nightly close at 1:30 and
revenue that never matches (f7, beside f4), "a job every quarter hour
raises an incident ... on any declaration that went wrong" (f8), "a
churn table for a dashboard, refreshed by a job inside the reporting
database" with the data policy (f9). Every validator is green at
hand-over; nothing leaves one red. One silent tooling expectation: `t1`,
`reporting` unscraped by design (master spec 13.4); no issue covers it.

## Whose system is whose

| Node | Policy | So |
|---|---|---|
| `crm` | report-only, overrides `/srv/scheduler/repository` and `/srv/scheduler/jobs` | f1, f2, f3, f8 fixable in the game |
| `producer` | report-only, the same overrides | f2's producer path fixable; `close-day` movable |
| `db`, `pooler` | fixable | f5, f6 fixable |
| `bi` | report-only, enforced | f4 a proposal; its jobs not movable |
| `reporting` | fixable, **Lumen's by the story alone** (16.5) | f7, f9 proposals, f10 a report |
| `consumer` | report-only, `jobs.yaml` override (no job) | nothing planted |
| `gateway` | report-only | f8's outage lives there, the fix is on `crm` |
| `prometheus` | report-only | nothing planted |
| `grafana`, `exporter` | fixable | nothing planted |

**Overstepping on `reporting`** (master spec 16.5, access model 7 and
12). Nothing stops a player, as `dba`, from changing Lumen's database.
The answer key judges the report or proposal the issue asked for; a
sealed check reading fixed after such a change is not the resolution.
The feedback names the overstep positively, as a teacher would: the
change was outside the mandate (Lumen's system, a report or a proposal
was asked for), whether it would have been right as a proposal, and what
it cost. A right change that comes with the proposal still gets the
proposal's credit; a change without it leaves the item unresolved as
asked.

- **f7**: editing `rpt.close_day()` is possible, and so is `CALL
  rpt.close_day()` by hand, a run outside the schedule the rules forbid.
  Either can make the check read 0; not the resolution. `bi`'s log shows
  whether `rollup-close` ran then.
- **f9**: unscheduling the job by its id and dropping the copies makes
  the check read 0; the GM judges the proposal and names the change.
  Dropping the table alone reads 1: the job recreates it.
- **f10**: moving the heavy entry to another hour, deleting it, or moving
  the same `CALL` to `bi` does not move the computation (or stops Lumen's
  roll-up). The incident check is unaffected by the crontab. A player who
  deletes or alters the backfill request takes away what the check dates
  the incident from, and it reads 2 (spec D282): after the hand-over that
  is this overstep, never a failed planting; read the kill and the
  recovery in `reporting`'s log yourself and judge the report as if
  nothing had changed.
- **Running any job by hand** (a `CALL`, a `cron.alter_job` to the next
  minute, a crontab entry set to run now) is the same overstep on any
  node.

## The jobs the players may move (W4 item 5)

`crm`'s five (`leads-extract`, `mail-shipped`, `mail-campaign`,
`declare-exports`, `escalate-customs`) and the producer's `close-day`,
through `jobs.yaml` and `sudo gm-reload-scheduler`; `db`'s crontab entry
`popular-products` (:17), through `sudo gm-crontab`, which is how a team
confirms f6's fix runs. Not `bi`'s two (report-only, Lumen's), nor
`reporting`'s crontab entry and `pg_cron` job (Lumen's by the story);
`consumer` and `gateway` have none. Asked "may we change X?", repeat
what the starter pack says.

## The designed day (scenario time, the customer's zone)

T0 is 22:00 the evening before; hand-over 14:00; aging 16h.

| Time | What happens | Seen by |
|---|---|---|
| 22:00 (T0) | load starts; f1–f4, f6–f9 planted by the seed files at render; the producer's release (f2's `consent.unsubscribe-v2`) | — |
| 22:05 on | `mail-shipped` every five minutes: duplicates from the first shipments (about T0 + 20 min) | f1 (65m) |
| 22:17 | `db`'s first refresh as `postgres` | f6 (77m) |
| 22:20 on | `leads-extract` hourly: lapsed withdrawn customers extracted | f2 |
| 22:30 | `customer-activity` fills `rpt.customer_activity` | f9 (1h) |
| 01:30 | `rollup-close` closes yesterday three hours off | f7 (270m) |
| 02:00 (handover-12h) | the backfill request (`gmctl inject --at`) | f10 |
| 03:00 | the sales-detail roll-up takes it, killed for memory; `reporting` recovers in seconds; every session on it ended, the 03:05 hourly run lost | f10 (90m from planting) |
| 08:00 | the campaign's first batch: withdrawn leads mailed (f2), recipients eight hours behind at night (f3) | f2, f3 (11h) |
| 08:00–10:00 (handover-6h to -4h) | the gateway's outage: nothing acknowledged, nothing escalated | f8 (11h) |
| 09:00 (handover-5h) | `shop_etl` expired (`gmctl inject --at`); every hourly run fails from 09:05 | f5 (65m from planting) |
| 12:00 | the producer's close of day invoices; the 12:05 hourly run fails (f5) | f4 (15h) |
| 14:00 | hand-over | — |

Instance minima are 16.2's rule (spec D189, W4 item 3), exact minutes;
f1's hour from its first five-minute run (D247).

## Interactions (the answer key's, W4 item 4)

- **f5 masks f4, f7 and f10's roll-up while present.** `shop_etl` is the
  hourly script's source login and the remote role of `bi_etl`'s mapping
  on `shop_db`, through which `rpt.close_day()` and
  `rpt.sales_detail_rollup()` read. f7's close (01:30) and f10's run
  (03:00) come before f5 (09:00), but every hourly run fails from 09:05,
  the 12:05 run after the noon invoicing among them: **f4 reads 3 (too
  soon) at the hand-over check**, as its answer key expects (spec O146,
  recommendation (a), pending the owner's ruling). The frozen dashboards
  hide the watermark gap until the players fix f5; the next hourly run
  then shows the gap in the figures, while f4's check stays too soon (no
  close in the game). If f5's planting failed, f4 would read 1 and
  fail the hand-over check a second time: look at f5 first.
- **f2 and f3 share `mail.campaign`.** Each check judges its own
  invariant (M2, M3): a fix of one leaves the other present.
- **f10's recovery at 03:00** ends every session on `reporting`: f9's
  job run of 03:00 (its check reads definitions, unaffected), `bi`'s and
  `consumer`'s kept sessions, which fail at their next call (the 03:05
  roll-up lost, 16.3's accepted risk) and reconnect at the one after.
  Every cumulative statistic on `reporting` restarts at 03:00.
- **A runner's reload raises the judged moment** of every check reading
  that runner (12.1): on `crm`, f1, f2, f3 and f8, so a fix of one, or a
  job moved, makes the others read too soon for a while; on `bi`, f4 (no
  player reload). f5's and f7's checks judge the ledger on `reporting`
  and never are (D241).

## The judged moment and `--since`

At report time, ask for the time of every fix made outside a runner and
pass it to `gmctl check --instance <id> --since <UTC instant>`:

- **f5**: `ALTER ROLE shop_etl VALID UNTIL 'infinity'` on `db`; without
  `--since` the game's refused runs still count.
- **f2 by the producer's path**: `consent.unsubscribe-v2` restored and
  the drifted flags repaired on `db` (D244); the runner's path needs
  none (crm's reload raises the moment). The producer restored alone,
  flags left, reads 1: say so in the feedback.
- **f7, f9** (oversteps): a change on the procedure is judged with
  `--since` its time; f9 judges the live state.

## Feedback points

- **I1 (f1).** The window against the cadence; the duplicates in
  `mail_outbox`. Best: `NOT EXISTS` on the outbox, with a unique
  `(order_id, template)` and `ON CONFLICT DO NOTHING` as the guard; a
  unique index alone makes every overlapping run fail.
- **I2 (f2).** The flag against the history, the release in the
  producer's repository (`consent.unsubscribe-v2`) and log. Either path
  is a fix (D244); the jobs reading the latest event is the policy's own
  rule and the stronger one. The best teams do both: jobs fixed, flags
  repaired (the improvement), the producer clearing the flag again.
- **I3 (f3).** The zone column. Moving the job's times is not a fix.
- **I4 (f4).** A proposal to Lumen: watermark on `updated_at`, the past
  days restated once. The gap shows only once f5 is fixed and an hourly
  run follows a close: a team that reasons from the script and the
  invoicing without the gap in the figures has read it well.
- **I5 (f5).** The frozen dashboards back to the refused logins and the
  role's expiry; that the role is also the mapping's remote role (the
  close and the sales-detail roll-up would fail too). A team that fixes
  f5 then sees f4 appear: the layered game.
- **I6 (f10).** The report: when, which process, killed for memory, the
  recovery; the cause (the backfill, the single aggregate, the node's
  limit); the recommendation to move the computation off the database
  node to a transformer sized for it, reading in batches, with backfills
  bounded. Moving the schedule only is not it.
- **Hidden.** f6 from `gm-crontab -l` and the peer logins at :17; f7
  from a closed day against the source and `\sf rpt.close_day`; f8 from
  the declarations against answers and incidents (the 08:00–10:00 hole
  foremost); f9 by reading the policy against what `reporting` holds,
  then `\des+`, `\deu+`, `cron.job`. f9 is found only with the policy.
- **`t1`.** `reporting` unscraped: the incident of I6 would have shown on
  an exporter's dashboards.

## Sealed checks at a glance

At the hand-over check: every instance 1 but f4, 3 (O146 (a)). In the
game: f1, f2, f3, f8 go 3 then 0 after a fix and a reload (f8 waits an
hour or two for a missing acknowledgement); f5 needs `--since`; f6 reads
0 at once; f4 and f7 stay 3 or 1 (no close in the game, `bi` not
movable; the proposals are judged); f9 stays 1 unless overstepped; f10
stays 1 (2 once the request is altered, D282).

## Smoke runs and the rehearsal (test harness only)

Chunk 17 records them (W4 items 6 to 9): every fault planted at once on
one host and on armenelos plus the VPS, `reporting` on armenelos (`fit`
refuses a shared host for it); the rehearsal runs without f7 and f10
(D283).
