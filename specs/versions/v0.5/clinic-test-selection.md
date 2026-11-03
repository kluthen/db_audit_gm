# v0.5 — the clinic's test selection

Status: draft v4, ready for review; the ten are what v0.5 builds (D316), s5 and s9 swapped for the portal's T270 and housing's T150 when the four parts were folded in (D325), s6 for the data register's T307 (D332). The spec's own pick of faults from
the [traps](clinic-traps.md), for the build's tests and the proof in
play: a fixture, not the canonical scenario (D309). A game's faults are
the GM's to select at deploy, with whoever sets up the game; this
selection binds no game. It keeps D290's cap and mix: ten faults, one
dramatic, two on the verge, seven optimisations and minor frictions,
and a false alarm. These ten are the faults v0.5 builds, the false
alarm's material with them; the other traps stay listed for the GM
(D316).

Tested under D314: every check is a short test, under 30 minutes, on
the least environment that proves the fault, one fixture per group
below; the whole clinic is deployed once, as the proof in play, with
the selection planted at once ([README](README.md#testing-in-v05-d314)).

## The selection

| # | Trap | Class | What it covers | Planted | Fixture |
|---|---|---|---|---|---|
| s1 | T40, the urgent priority dropped in the centre's orders | D | a round-trip cascade (D286): urgent tests posted routine, waiting for the pathologist's round | `interfaces`' script (`post-lab-orders`' mapping), seed-file | orders |
| s2 | T35, `archive_command` failing silently | V | replication and the archive; cold storage, the vault's `wal` manifests and its page | `records`' `postgresql.conf` | archive |
| s3 | T69, herd prescriptions dropped from the antimicrobial use | V | a periodic report, its witness the daily feeder (D265); last year's planted report wrong, the cattle the one species due | the feeder's query on `backoffice`, and the planted report | reports |
| s4 | T41, a retry under a new `client_ref` | M | a round trip's correlation key; the held `purpose-retry-without-key` (D201) built | `interfaces`' script | orders |
| s5 | T270 ([vet-portal](vet-portal-domain.md#3-who-sees-what-the-policies)), the animals' policy without the ownership's end | M | row-level security and owner-scoped access, "the clinic's richest governance case" (D293), new in the clinic | the policy on `portal` (DDL), a few hours before T0 | portal-scope |
| s6 | T307 ([data register](data-register-handout.md#4-the-trap-family-the-register-itself-t300t308)), cold storage, the vault, declared nowhere in the players' data register | M | the data register (D330) and its skill (D331): a planted deviation, the true and handed-out registers, the answer key's diff; resolved by *propose* | the bastion's `data-register.md` (seed-file), written by the `data-register` skill | archive |
| s7 | T1, statement logging on `records` | M | governance in the logs (core rule 10); the held `governance-statement-log-personal` (D191) built | `records`' `postgresql.conf` | reports |
| s8 | T33, the standby an hour behind (`recovery_min_apply_delay`) | M | the reporting standby (D299): the night's feeders missing the evening | the standby's `postgresql.conf` | reports |
| s9 | T150 ([vet-housing](vet-housing-domain.md#1-the-ward-service-and-the-displays-d287)), a faulty display reading its board in a loop | M | D287's own case, the owner's: many small consumers behind one service, found through the redundant query and the box → stay → animal chain; reported, never fixed | the display's key in `ward`'s profile layer (D264) | housing |
| s10 | T10, `monitoring` not chosen on `lab` | M | the options model (D289) | the topology's `options` | lab |
| fa | "The external lab is slow" | false alarm | a PCR answered on its fourth day, within its one-to-five-day turnaround | an issue in the starter pack, no fault | send-outs |

Calibration for the classes: s1 is the customer's complaint (the
emergency team's blood gases hours late); s2 has no copy of the last
hours in the vault and nothing says so; s3 is a year deep with the next
yearly report due in January; s4 is planted with the partner's standing
slowness only, a few duplicates a week, so it stays minor; s8 an hour's
delay, the customer's "for safety"; s5 is planted a few hours before T0,
so only the day's sales are exposed and it stays minor; s9 at one
display looping about once a second, below what saturates the ward's
pool (V if it did, at a feeding round).

Replaced by D332, back among the traps for the GM: T49 (a natural
identifier in the send-outs, s6 until then): it adapts v0.4's
`governance-personal-copied`, whose outbound `fields` check v0.4
already proved, while no clean register proves the register's planted
deviation; governance stays with s5, s7 and s6
([data register](data-register-handout.md#5-the-test-selection-d332-the-gms-under-d309)).

Replaced by D325, back among the traps for the GM: T78 (`lab-api`'s
idempotency lookup unindexed, s5 until then; its growth was not shown
in v0.5 anyway) and T60 (the critical calls' watch as superuser, s9
until then; `pg_cron` on a database node was v0.4's already). With T78
gone, no fault of the ten sits on an `api` node's `db/` side (D271);
the `api` brick's own build checks cover that side instead (D328; the
owner: "ok agreed"). s1 and s4 cross `clinic-api` and `lab-api` in the
orders fixture, but neither is planted on a `db/` side. Machinery's T208 (no
partition created ahead) was proposed for s9 too and stays a trap
(D325).

## The fixtures

Each fixture holds the nodes its faults touch and those they cannot run
without, every other node left out. A fixture's T0 is placed just before
the job a check needs (D314), never waited for; a WAL segment is
switched by the test.

| Fixture | Nodes | T0 | Faults |
|---|---|---|---|
| orders | `records` (`clinic`), `lab`, `clinic-api`, `lab-api`, `pms`, `lis`, `interfaces` | a weekday, 10:00 | s1, s4 |
| archive | `records`, the partners' `api` node (cold storage's hostname) and database | any | s2, s6 |
| reports | `records` (`clinic`, `office`), the standby, `backoffice` | a Friday, 01:20 (Thursday held herd visits) | s3, s7, s8 |
| send-outs | `lab`, `interfaces`, the partners' `api` node (the external lab's hostname), database and back end | a weekday, 15:50 | fa |
| lab | `lab`, its exporter | any | s10 |
| portal-scope | `records` (`clinic`, `portal`), `portal-api` | a weekday, a few hours after the fault is planted | s5 |
| housing | `records` (`clinic`, the core and housing loaded), `pms`, `ward` | any | s9 |

Seven nodes at most, with the bastion every deployment has: the
largest, orders, about 1.5G and 1.6 CPU reserved, so every fixture fits
one host as the tests declare it ([tally](clinic-capacity.md)); the
new two are small: portal-scope three nodes with the bastion, housing
four, about 0.8 CPU and 0.75G.

**The parts' own build checks**, on fixtures their pages describe
(D314), beside these:

| Part | Fixture | Nodes (with the bastion) | What it proves |
|---|---|---|---|
| `vet-scheduling` | bookings | `records`, `pms`, `interfaces`: about 0.8 CPU and 0.8G | the exclusion constraints, the slot function, `vet-bookings-sync`'s check-in and imaging bookings |
| `vet-housing` | housing | `records`, `pms`, `ward`: about 0.8 CPU and 0.75G | the load's placements, the board, placement and release, the care log; s9 |
| `vet-machinery` | imaging | `records`, `clinic-api`, `pms`, `machines`, `equipment`, `interfaces`: about 1.5 CPU and 1.4G | the three databases and loads, identity and census, the imaging round trip |
| `vet-machinery` | vault | `machines`, `equipment`, `interfaces`, the partners' `api` node and database: about 1.1 CPU and 1.1G | partitions ahead, the nightly shipping and its receipt, the vault's manifests |
| `vet-portal` | portal | `records`, `lab`, `interfaces`, `portal-api`, the partners' `api` node, back end and database: about 1.75 CPU and 1.7G | the copies, the release gate, owner scope, accounts, messages |

## Each fault's short test

Present, fixed and the time each takes, every one under 30 minutes with
the deployment.

- **s1, urgent priority dropped.** The fixture raises the rate of
  emergency and in-hospital consultations on `pms` (its profile layer,
  D264) so an urgent request closes within minutes. *Present*: a lab
  order `routine` whose request is `urgent`, within ten minutes.
  *Fixed*: after the mapping's fix, the next urgent order is `urgent`
  and released at once by `lab.release.urgent`, its request `resulted`
  within ten minutes (LO1, LO3); the routine-posted ones left waiting
  for the next round are the backlog, a creditable consequence (D286).
  LO4 end to end for the urgent orders posted after the fix. About 25
  minutes.
- **s2, `archive_command` silently failing.** *Present*: the test
  switches a segment (`pg_switch_wal()`); `pg_stat_archiver` reports it
  archived, no `wal` manifest names it, the vault's page shows the gap.
  *Fixed*: after the fix, the next switched segment's manifest present;
  the gap stays, a finding the players report. About 10 minutes.
- **s3, herd prescriptions dropped.** *Present*: the 02:00 feeder's day
  (Thursday, herd visits) short of the herd treatments the source holds;
  last year's planted report short of the cattle's herd use. *Fixed*:
  after the query's fix, the feeder moved to the next minute (D132) and
  its day complete; the planted report stays wrong, its rerun
  recommended (D277). About 20 minutes.
- **s4, retry without a key.** The test delays one post past the
  runner's ten-second timeout (a lock held on `lab_orders`). *Present*:
  two lab orders for one consultation, two `client_ref`s (LO2). *Fixed*:
  after the fix, the same delay gives one order, the second post
  answered with the first accession. About 15 minutes.
- **s5, former owners still see sold animals.** The fixture plants
  the policy a few hours before T0 and a sale in that window. *Present*:
  as the planted former owner, `GET /animals` on `portal-api` returns
  the horse they sold. *Fixed*: after the policy's fix, it does not, and
  the buyer still sees it. About 10 minutes.
- **s6, the vault not declared.** *Present*: the bastion serves
  `data-register.md` (`/home/player` and the page) with cold storage
  among no entry's recipients; the true register (`gm/`) names it on
  every entry it holds; the vault's page lists `records`' `wal` and
  `basebackup` manifests. *Cleared*: the handout regenerated without
  the fault names it, proving the change reversible. *Proposed*: the
  corrected entries, judged at the final answer against the answer
  key's `register_diff:` (D333). With s2 planted too, the vault still
  holds the planted manifests and the base backups. About 10 minutes.
- **s7, statement logging.** *Present*: an owner's name and phone in
  `records`' log after a few `pms`-style writes run by the test as
  `vet_app`. *Fixed*: after the fix and a reload, the same writes leave
  no personal data in the log. About 10 minutes.
- **s8, the standby behind.** *Present*: `pg_stat_replication`'s replay
  lag at an hour; the 01:30 feeder's day missing the supplies of the
  evening's last hour. *Fixed*: the delay removed, the lag near zero, the
  feeder moved and its day complete. About 20 minutes.
- **s9, a faulty display.** Reported, never fixed: a display's
  firmware is no layer of the players' (D209's precedent). *Present*:
  the board statement's calls well above 64 a minute in
  `pg_stat_statements`, from `ward`; the unit's parameter logged for
  `vet_display` alone. *Reported*: the chain from the parameter to the
  unit, its display's serial and the animal, the answer key's
  criteria. *Cleared*: the test itself switching the display's key off
  in the profile layer, the calls back to 64 a minute, proving the key
  reversible. In a game nobody clears it: the GM judges the report at
  the final answer and never switches the display off during play
  (gm-stance, "Stop only", "No events outside the schedule"). About 15
  minutes.
- **s10, `monitoring` not chosen.** *Present*: the exporter's login
  errors against `lab`. *Fixed*: the option chosen and the node
  redeployed, the exporter's metrics present. About 15 minutes.
- **fa, the external lab is slow.** The fixture plants a PCR send-out
  answered on its fourth day; the check reads its `due_by` against
  `answered_at`, within its turnaround. About 5 minutes, on the
  send-outs fixture.

## The proof in play (D314)

The whole clinic deployed once on armenelos plus the VPS, every part
built, the ten faults and the false alarm planted at once. Its checks
(ruled, D339): the deployment and `fit`; every producer, partner and
purpose running for about 30 minutes, each one's first run read; each
fault's present reading where it reads within the window (s2, s5, s6,
s7, s8, s9 and s10 at once, s5 as a planted former owner's visit, s6
the handout against the vault's page, s9 the display's excess calls;
s1 at the first urgent order, if one comes; s3 only with T0 placed
before its feeder, so it rests on its fixture). No fault is fixed there.
None of the ten may exhaust a node's memory, so none sets
`needs_unshared_host` and the placement is free on that count; the VPS
rules still bind the run (D159).

Unproven in v0.5 (the major test before the v1.0 tag): the ten faults
at once through their cycles after a full aging, the classes as the
hand-over finds them (s1 noticed, s2 and s3 on the verge), s5's
exposure over days of sales, the feeders at their own hours, s9 found
across a hand-over.
