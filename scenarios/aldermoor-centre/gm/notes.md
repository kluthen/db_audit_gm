# GM notes — aldermoor-centre

Sealed. Longer explanations for the feedback; the authoritative answer is
`answer-key.yaml`, and each fault's own `gm.md` (under `faults/`) has the
general background. Built in chunk 27 of the v0.5 build plan as captures
W1 to W5 of `specs/versions/v0.5/wave-log.md` settle it (master spec 14,
17.1 to 17.4; W5 item 6, "What chunk 27 reads").

## The shape of the game

One centre of Aldermoor Veterinary Hospitals, Aldermoor Veterinary
Hospital North (`ALD-N`), composed of the six clinic domains in the
`regional-franchise` variant: the record, housing and scheduling in
`records/clinic`, the back office's registers in `records/office`, the
owners' portal in `records/portal`, the laboratory in `lab/lab`, the
machines in `machines/{pacs,vitals,biomed}`. A standby of `records` in the
off-site room (the VPS), where the back office's reports read. Sixteen
purposes, nine partners on the three shared `no-access` nodes, the
monitoring breadth (an exporter per database server, pgwatch, the health
checks). The faults: the test selection of master spec 17.2 but s4 (spec
D466), nine and the false alarm, within the owner's budget (ten at most:
one dramatic and noticed, two on the verge, the rest minor).

| Instance | Defect | Node | Planted | Visibility | Class | Issue |
|---|---|---|---|---|---|---|
| s1 | urgent lab orders posted routine (`lab_orders.py`'s mapping) | interfaces | render (seed file) | known | dramatic | I1 (fix) |
| s2 | `archive_command` failing silently (`vault-post` arguments swapped, `\|\| true`) | records | render | hidden | on the verge | — |
| s3 | herd treatments dropped from the antimicrobial use; last year's report short | backoffice (script on records) | after the load | hidden | on the verge | — |
| s5 | the portal's animals policy ignores an ownership's end | records (`portal`) | handover-3h (`inject --at`) | hidden | minor | — |
| s6 | Cold Storage declared nowhere in the handed-out register | bastion | the register's generation | hidden | minor | — |
| s7 | `log_statement = 'all'` on records: owners' names and phones in the log | records | render | hidden | minor | — |
| s8 | the reports' standby an hour behind (`recovery_min_apply_delay`) | standby | render | hidden | minor | — |
| s9 | unit 7's display (65) reading its board about once a second | ward | render (seed file) | hidden | minor | — |
| s10 | `monitoring` not chosen on lab: the exporter, pgwatch and the health checks refused | lab | the topology | hidden | minor | — |
| fa | "the external lab is slow": a PCR panel on its fourth day, within its 96-hour turnaround | — | the issue | — | false alarm | I2 (report) |

Difficulty: score 9 (the false alarm counts in none), hard.

## Whose system is whose

- **The centre's, fixable**: the four database servers, `interfaces` and
  `backoffice` (their repository and jobs), the database side of `lab-api`
  and `portal-api`, the exporters, pgwatch, health, Grafana.
- **The vendors', report-only**: `pms`, `lis`, `ward`, `equipment`,
  `clinic-api`; Prometheus. s9 sits on `ward`: reported, never fixed (the
  display's firmware is no layer of the players'); the GM never switches
  the display off during play.
- **The partners', no-access**: `partners-api`, `partners-backend`,
  `partners-db`. Played by no one: their stubs answer by themselves, their
  support never answers, and you never speak for one. A message the
  players would send a partner's support is credited when it is right; no
  fix ever needs a partner to change (D274). The players may call the
  partners' public endpoints with the credentials of `partners.md`, which
  are the customer's own (D365; a DBA may find it odd to be handed them:
  accepted).

## The designed day (scenario time, the centre's zone)

T0 23:00, aging at least 10h, hand-over 09:00, four hours of play.

| Time | What happens | Why it matters |
|---|---|---|
| 23:00 | T0: the load starts; the night's emergency consultations post urgent orders | s1's first urgent order (its aging minimum 0m from it) |
| 00:30 | `feed-daily-figures` reads yesterday on the standby | s8's consequence: the day short of its last hour (T0 must fall before 00:30) |
| 01:30, 01:45 | the medicines and controlled-drugs registers' feeders | read the standby, an hour behind with s8 |
| 02:00 | `feed-antimicrobial-use` | s3's first faulty run after a day with a herd treatment (T0 before it) |
| 02:30 | `feed-lab-charges` | |
| night | the nightly base backups (the crontabs, in UTC: records 03:30, lab 03:45, machines 04:00) | s2: the backups ship, the WAL does not |
| 06:00 | s5 planted (`gmctl inject --at`, three hours before the hand-over) | former owners have had hours to look |
| 08:00 | the day's traffic starts | |
| 09:00 | hand-over | |
| 09:30 | `feed-working-time` | in play |

On the 1st of a month the monthly jobs run (balances at 03:15 signed by
Dr Lars Wagner, staff 1, the lowest-id vet employed; the head office's
figures from 05:00); on 1 and 15 January the yearly ones. None is needed
by a fault of this selection.

## Interactions (the answer key's, W5 item 6)

- **s2 and s7**: one file, `records`' `postgresql.conf`; credit either fix
  independently, and check the other's line survived the players' edit.
- **s2 and s6**: planted together on the vault: the archive fails silently
  while the vault still holds the planted manifests and the nightly base
  backups, so s6's witness stands. The players may find either alone.
- **s3 and s8**: both bite feeders reading the standby; s8 never hides a
  herd treatment, so s3's check stands with s8 present or fixed.
- **s7 and s9**: while `log_statement = 'all'` stands, the board's
  parameter is already in the log; s9's careful step (the parameter logged
  for `vet_display` alone, then reset) is unneeded until s7 is fixed, and
  s9's "no instance-wide logging left behind" is met by s7's fix.
- **s10 beyond the exporter**: pgwatch's `lab` source and the health
  checks' `lab` instance fail too; one instance covers every monitoring
  node targeting `lab`. Resolution report or propose (D462): the role
  `monitoring` is the game's; you create it, unseen, on an accepted
  proposal, with the exporter's `monitoring_password`.

## Setup notes

- **The timeline**: T0 must fall before 00:30 local (s3's and s8's
  feeders); with the hand-over at 09:00 and the aging's 10h, T0 23:00.
- **s5** is a `state` fault within the aging: plant it with `gmctl inject
  --at` three hours before the hand-over (`plant_at: handover-3h`).
- **s9's check** sleeps its one-minute window: expect it to take a minute
  at the hand-over check.
- **s10** is a topology fault: `inject` lists it, nothing runs.
- **s6** is the register's: the handout is generated with it planted; the
  true register is `gm/data-register.yaml`.
- `load-data` loads vet-core's other centres' state and the `centres`
  role onto `partners-db` (vet-core's partners folder), as in every
  composition with that domain.
- **Known limit** (spec D467, O249): the partners' stubs' live reference
  counters restart at 0001 after the planted series (no repeat: the year
  or the month is in each reference). A player noticing it found a stub's
  limit, not a fault.
- The scenario document leaves out the coherence check's result (spec
  D468): read it in `composition.yaml`'s `coherence:` after the load.

## Feedback points

- **s1** is the one the customer noticed: a round-trip cascade. Credit
  the backlog's clean-up (the urgent orders posted routine and not yet
  released), never counted.
- **s2** is the most dangerous: every signal PostgreSQL gives says the
  archive works. Credit reading the archiver against the vault.
- **s3** leaves last year's report wrong at the authority: the fix
  covers tomorrow, the report needs a correction (a proposal).
- **s6**: credit a register read against the systems, the policy and
  `partners.md`; the proposal is judged against `register_diff`.
- **fa**: the right answer is "no fault", with the turnaround as
  evidence; a fix to the send-outs is a miss.
