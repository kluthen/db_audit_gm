# purpose-herd-use-dropped — GM notes

**What.** The back office's antimicrobial feeder
([`vet-antimicrobial-use`](../../purposes/vet-antimicrobial-use/gm.md),
`feed-antimicrobial-use`, 02:00, yesterday) joins each dispensing's
prescription to `animals` with an inner join
([`inject/queries.yaml.diff`](inject/queries.yaml.diff), one line of
`amu.feed.read`). A herd treatment, a herd visit's prescription, names a
herd and no animal: it falls out of the day before the herd's species is
looked up (the `LEFT JOIN herd_species` after it is dead code). The
cattle, the one species due to the authority, are under-reported every
day; and last year's report, summed from those days, was sent and
acknowledged short, the next one due in January (T69 of the clinic's
traps, class V; AM2 and AM1 break).

**How it is planted.** Two parts (a `state` fault with a seed change,
spec D254, and a script on another node, spec D459):
- the seed change, the runner's `queries.yaml`, in place from T0: the
  feeder writes every day short from its first run;
- the script [`inject/20-planted-report.sh`](inject/20-planted-report.sh),
  run by `gmctl inject` on the node holding the target (`target_node`,
  the clinic's `records`), as root, querying as `postgres` unseen
  (statement logging, `pg_stat_statements` and pgaudit off, as
  `load-data`'s sessions), after the history and the coherence check:
  from 1 January of the year last reported to the last planted day, each
  `antimicrobial_use` row set to what the faulty query computes from the
  record (a herd-only row removed, each feeder run's counts with it); then
  that year's `amu_reports` lines summed again, its copy in
  `regulatory_submissions` with them, the reference and its form
  (`AMU<year>-NNNN`, D451) kept. The authority's stub keeps no planted
  report, so nothing on the partners' side disagrees. Idempotent.

**Writing it into a scenario.**
- The instance's node is the purpose's runner (`backoffice`, `scheduler`
  0.3.0); `target_node` names the node holding the target and the source
  (`records`, `postgres` 0.5.0: both bricks are in `applies_to`). The
  scenario names `vet-antimicrobial-use` in its `purposes:`.
- In a composed scenario the runner's files are `gmctl compose`'s: apply
  the diff to the scenario layer's `compose/backoffice/queries.yaml` (the
  purpose's material as copied; `patch -p1` from `compose/backoffice/`)
  and rerun `gmctl compose`, never edit `nodes/backoffice/` (capture W5
  item 0).
- Parameters: `source` (`records/clinic`), `target` (`records/office`),
  `job` (`feed-antimicrobial-use`), `target_node` (`records`, required).
- **Aging minimum (spec D189).** `0m` counted from the feeder's first run
  after a day with a herd treatment: herd visits fall on Tuesdays and
  Thursdays, so raise the instance's `aging_minimum` to cover the 02:00
  run after the first such day following planting. The planted report is
  short from the planting.
- Visibility: hidden, or known through the authority's inspector. The
  runner's repository is fixable (`fixable-file`, D456); an issue may
  expect `fix`, `propose` or `report`.
- **With `pg-standby-apply-delay`** (the clinic's s8): both bite feeders
  reading the standby; s8 never hides a herd treatment from the 02:00
  feeder, so this fault's witness stands with it.

**Why it matters.** The yearly report to the authority is a legal duty:
under-reporting the one species due, year after year, is what an
inspection finds, and the report already sent stays wrong until corrected.

**Why it happens.** The query was written for the doses, which always
have an animal, and extended to the dispensings by copy; the herd's
species was added later as a `LEFT JOIN` after the inner one, so it never
had a row to apply to.

**What a good answer says.** Compares the record's herd treatments with
the daily use, finds the inner join, proposes a `LEFT JOIN`, reruns the
short days, and recommends correcting last year's report with the
authority: the fix of the query leaves the report sent wrong (spec D277).

**Fix path.** Edit `/srv/scheduler/repository/queries.yaml` (the
repository is fixable), `sudo gm-reload-scheduler`, then, to see it work,
move `feed-antimicrobial-use` a minute ahead in `/srv/scheduler/jobs/jobs.yaml`
and reload: a day the feeder has written is held (it writes its day
once), so a day written short is rerun by removing its rows and its run
row first (as the GM in a test, capture W5 item 0; by the players with
the customer's consent in a game).

**Sealed check.** On the runner, as root, judging the feeder's runs since
`CHECK_SINCE` raised to the runner's last reload (`judges: runs`). Each
run's day (local yesterday): every herd treatment the record holds
(dispensings of an antimicrobial on a prescription with a herd and no
animal) counted in `antimicrobial_use` under the herd's species and
ATCvet code, dispensings and herds. *Present* (1) with more violating
days than the threshold (0); *fixed* (0) with a judged day holding a herd
treatment and none violating; *too soon* (3) until the feeder has run
after such a day. The planted report is never judged.
