# vet-imaging-orders — GM notes

Purpose 13 of v0.5 (master spec 12.2; [vet-machinery-domain.md](../../specs/versions/v0.5/vet-machinery-domain.md#vet-imaging-orders-the-imaging-requests-and-their-reports),
"`vet-imaging-orders`"; capture W4 items 0 and 6): the imaging requests the
vets write at a consultation's close posted into the PACS's worklist by the
centre's integration engine, and the final reports copied back. **A round
trip inside the centre**, as `vet-lab-centre-orders`: there is no API node,
the engine writes the order as an HL7 order to a RIS would.

## What it is for

A closed consultation's imaging request must reach the modality's worklist
(the radiographers' list, the identity filled by the machinery's own
lookup job), and the request must show the vet when its final report is
signed, or that the imaging team cancelled it. A sent request is cancelled
by the imaging team only (D315, D324).

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `post-imaging-orders` | `* * * * *` | script `scripts/imaging_orders.py:post`, `clinic` as `vet_interfaces`, `pacs` as `mach_orders` | the requests still `requested` whose consultation has closed (oldest first, at most `batch`): one `mach_worklist` entry each (accession `I-<request id>`, request, consultation, animal, requesting vet, the procedure of its study code, priority; ids only), `ON CONFLICT (accession) DO NOTHING`, with the run's `ops.runs` row in `pacs`, committed first; then the requests `sent` in `clinic` with the run's row there |
| `fetch-imaging-reports` | `*/5 * * * *` | `:fetch`, the same two connections | from `pacs`, the finals signed since the watermark `finals` and the entries cancelled since `cancellations` (each less ten minutes; a final already in `ops.imaging_results` skipped); in one `clinic` transaction: each final's copy in `ops.imaging_results` and its request `resulted` (an addendum is copied, the request already resulted), each cancelled entry's request `cancelled` when still `sent`, each request `sent` past its turnaround with no final one `ops.incidents` row (`overdue`, ref the request's id), once; the watermarks and the run's row |

The turnarounds (D376): urgent, 18 hours after its posting (the option
`urgent_hours`); routine, three working days after its local date
(`routine_working_days`, Monday to Friday, the zone read from
`business_settings`). Watermarks (`finals`, `cancellations`, in `clinic`)
start at `load_epoch`: every final and cancellation before it is the
load's, already on its request.

**Choices made at the build** (W4-e): the run row of `post` is written in
`pacs` first, in the worklist's transaction, then in `clinic` with the
same `job` and `started_at`; a study code the PACS's catalogue lacks is
logged and left `requested`; `fetch` reads the customer's zone from
`business_settings`, so `vet_interfaces` reads it; the joins need the ids
of `mach_worklist`, `mach_studies` and `mach_reports` and the catalogue's
`(id, code)`, granted beside the roles table's columns.

## What the material holds

Written for the clinic's names; adapt them when copying.

| File | Goes to | Names to adapt |
|---|---|---|
| `material/runner/queries.yaml`, `jobs.yaml`, `schedule.yaml`, `scripts/imaging_orders.py` | the runner's (`interfaces`) scenario layer `compose/interfaces/`, merged by `gmctl compose` | the targets `records:5432/clinic` and `machines:5432/pacs`; the options `urgent_hours`, `routine_working_days` |
| `material/source/ddl.sql` | nowhere: `ddl.source`, read from the catalogue by `load-data` at step (2b) | none (`:"DBNAME"`) |
| `material/target/ddl.sql` | nowhere: `ddl.target`, likewise | none |
| `checks/*.sh` | the sealed checks of the faults attached to the purpose | the constants at the top of each (`DB`, `PACS`) |

The source DDL creates (guarded) `ops`, its three shared tables and
`ops.imaging_results`, the role `vet_interfaces` (shared with purposes 1,
4, 5 and 11), `CONNECT` by name, and grants it `SELECT` on `requests` and
`business_settings`, `SELECT (id, state, ended_at)` on `consultations`,
`UPDATE (state, sent_at, resulted_at, cancelled_at)` on `requests`, and
the `ops` grants. The target DDL creates `ops` in `pacs`, the role
`mach_orders`, `CONNECT`, the `ops` grants, `INSERT` on the worklist's
order columns, and `SELECT` on the columns named in `purpose.yaml`'s
roles.

The scenario must give `records`' and `machines`' `pg_hba.conf` lines
admitting `vet_interfaces` and `mach_orders` from `interfaces`, and
`gm_check` from the game network (every fixture's `host all all` line
does).

## How it goes wrong

The candidate faults are the domain's T227 to T233 (vet-machinery-domain.md,
"Traps", 5): T227 requests marked `sent` before the `pacs` entry commits
(IO1); T228 the priority dropped (IO4, an urgent study past 18 hours);
T229 a preliminary read as final (IO3); T230 the accession's unique index
dropped, then a retry (IO2); T231 the reports' watermark taken from the
run's start (IO3); T232 cancellations never read back (IO4); T233 the post
job on business hours only (IO1). A scenario's faults are the GM's to
select.

## The checks

Each runs on `interfaces` as root (`gmctl check`), reads `clinic` and
`pacs` as `gm_check` (`check-sql`) and the runs' moment (`check-runs`);
exit 0 fixed, 1 present, 2 cannot judge, 3 too soon.

| Check | Invariant | Judged | Witness |
|---|---|---|---|
| `io1-requests-sent.sh` | a closed consultation's imaging requests `sent` with their entry within 5 minutes of the close (2 urgent), or cancelled | triggers | a request of a consultation closed since the judged moment, about 11 a day |
| `io2-one-entry.sh` | one entry per request, carrying its accession | runs | an entry posted since the judged moment |
| `io3-finals-resulted.sh` | each final's request `resulted` within 10 minutes of the first final; none resulted without a final signed before | runs | a final signed since the judged moment, about 11 a day |
| `io4-end-to-end.sh` | each request posted since the judged moment resulted on a final within its turnaround, or cancelled | end-to-end | a request posted since the judged moment; urgent ones by the next morning |

IO1 dates the close by the later of the consultation's end and the
request's time. IO4 judges a settled request at once and an open one at
its turnaround, so on a short run it shows urgent requests resulted
within the run and leaves the routine ones to their working days.
