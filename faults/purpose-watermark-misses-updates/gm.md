# purpose-watermark-misses-updates — GM notes

**What.** The agency's hourly roll-up
([`shop-sales-reporting`](../../purposes/shop-sales-reporting/gm.md),
R1) re-reads the orders changed since its watermark and recomputes their
hours and days. Planted at render, the scenario's `scripts/rollup.py`
selects the orders *placed* past the watermark instead of those
*updated* past it ([`inject/rollup.py`](inject/rollup.py), the whole
file, with an in-world docstring). New orders still arrive, so the
dashboards look alive; but the producer invoices shipped orders at its
12:00 close, days after they were placed, and those changes are never
read again: each past day's invoiced revenue stays as it was when the
day was last published, and the gap with the source grows every noon
(master spec 16.2).

**Writing it into a scenario.**
- The node is the purpose's runner (`bi`), `scheduler` 0.2.0, seeding
  `scripts/`; the scenario names `shop-sales-reporting` in its
  `purposes:`. Copy `inject/rollup.py` as the runner's
  `nodes/bi/scripts/rollup.py`.
- Parameters: `source` (`db/shop`), `target` (`reporting/reporting`),
  `job` (`rollup-hourly`), the purpose's material names.
- Visibility: known (I4 in the first v0.4 scenario). The runner is the
  agency's and report-only by the story (master spec 16.5): the issue
  expects `propose`; restating the past days is the `improve`.
- **Aging minimum (spec D189).** The definition's 1h counts from the
  first close of day after planting (the producer's `close-day`, 12:00
  scenario time): raise the instance's `aging_minimum` to that close's
  offset from T0 plus 1h. With T0 at 22:00: `aging_minimum: 15h`. The
  first hourly run after the load publishes the whole history right, so
  nothing is wrong before that noon.
- **The judged moment.** R1 needs a past day re-invoiced after it ended
  as its witness, and the only invoicing is the noon close: after a
  14:00 hand-over the next counted one is the next day's, so the check
  reads 3 for the rest of a four-hour game (it reads 1 at the hand-over
  check, judged since the planting). The players' proposal is what the
  feedback judges.

**Why it matters.** The accountant's revenue never matches the
dashboard's, and the difference grows without anyone changing a
figure: the reports silently drift from the books.

**Why it happens.** An incremental loader written against an append-only
mental model of orders; `placed_at` indexed and `updated_at` not; a
watermark column chosen for speed.

**What a good answer says.** Reads the script's watermark column, sees
that orders change after they are placed (invoicing, by the close's
`updated_at`), compares a past day's invoiced revenue on both sides, and
proposes the watermark on `updated_at` (keeping the overlap), plus one
restatement of the days already published.

**Fix path.** The runner is report-only: a proposal. A GM confirming it
(or a fixable variant) edits `/srv/scheduler/repository/scripts/rollup.py`
as root, reloads the runner (on a report-only node, s6's `SIGHUP`, as
`gm-reload-scheduler` does), and waits for (or moves) the next close of
day and the hourly run after it. The close must re-invoice a *past*
local day: it invoices the orders shipped since the previous close, and
the warehouse ships the last few thousand orders, so two closes on the
same local day re-invoice only that day and give no witness; the next
close after a local midnight does.

**Sealed check.** R1, adapted from the purpose's
`checks/r1-reconciled.sh` with the parts and the job as parameters; on
the runner, as root, judging the hourly job's runs since `CHECK_SINCE`
raised to the runner's last reload (`judges: runs`). *Present* (1) while
more buckets than the threshold (0) differ from the source at the latest
run, the run due to publish them having run since the judged moment;
*too soon* (3) until the runs since have both witnesses (an hour of
orders, and a past day invoiced after it ended); *fixed* (0) then. A
fixed script does not restate the days it missed before the fix: those
are past violations, never counted.
