# purpose-urgent-priority-dropped — GM notes

**What.** The integration engine posts the record's closed analysis
requests to the lab's order API
([`vet-lab-centre-orders`](../../purposes/vet-lab-centre-orders/gm.md),
`post-lab-orders`, every minute), one order a consultation and priority,
keyed `C-{consultation}-{priority}`. Planted at render, the mapping of
the order's priority keeps only the lab's old word for urgent, `stat`
([`inject/lab_orders.py.diff`](inject/lab_orders.py.diff), one line of
`post()`), so every order reaches the lab `routine`. The lab releases an
urgent test as soon as it is measured and a routine one at the
pathologist's next round (11:00, 14:00, 18:00 on weekdays): the
emergency team's blood gases come back hours late. The grouping and the
reference still follow the record's priority, so the trace is plain:
`C-{consultation}-urgent` orders `routine` at the lab (T40, D286's
round-trip cascade; class D in the clinic, the customer's complaint).

**Writing it into a scenario.**
- The node is the purpose's runner (`interfaces`), `scheduler` 0.3.0,
  seeding `scripts/`; the scenario names `vet-lab-centre-orders` in its
  `purposes:` and maps its `api` part to the lab's order API. In a
  composed scenario the runner's files are `gmctl compose`'s: apply the
  diff to the scenario layer's `compose/interfaces/scripts/lab_orders.py`
  (the purpose's material as copied; `patch -p1` from `compose/interfaces/`)
  and rerun `gmctl compose`, never edit `nodes/interfaces/` (capture W5
  item 0). With `purpose-retry-without-key` planted too, both diffs apply
  to the one file, in either order.
- Parameters: `source` (`records/clinic`), `lab` (`lab/lab`), `job`
  (`post-lab-orders`), the clinic's names.
- **Aging minimum (spec D189).** The definition's `0m` counts from the
  first urgent request posted after planting: an emergency or
  in-hospital consultation closing with a lab request (about 20 urgent
  orders a day in the clinic). Raise the instance's `aging_minimum` to
  cover the first one; its lateness shows at the next round after it.
- **Backlog** (master spec 6.3; the answer key's `backlog:`): the urgent
  requests posted `routine` before the fix wait at the lab for the next
  round. The ledger finds them: `ops.lab_orders_sent`'s
  `C-{consultation}-urgent` references whose accession is a `routine`
  order at `lab` (`lab_orders.priority`), its tests not yet released.
  Cleaned up: each raised to `urgent` at the lab, or its release asked of
  the lab; credited, never counted.
- Visibility: known in the clinic (the emergency team's complaint).
  The runner's repository is fixable through its write override; an
  issue may expect `fix`, `propose` or `report`.

**Why it matters.** An urgent test is urgent because a treatment waits
for it: a blood gas read three hours late is a decision taken blind.

**Why it happens.** The lab's first interface called urgent `stat`; the
mapping was written against it and never revisited when the record and
the lab agreed on `urgent`; the default made the miss silent.

**What a good answer says.** Reads the lab's orders against the record's
requests, sees the urgent references routine at the lab, finds the
mapping in `post()`, proposes sending the request's own priority, and
names the orders already posted routine as the backlog to raise or have
released.

**Fix path.** Edit `/srv/scheduler/repository/scripts/lab_orders.py`
(the repository's write override, or as root for the GM), `sudo
gm-reload-scheduler`, and wait for the next urgent request (or place one
in a test). An urgent order is released by `lis` as soon as measured; in
a short test the test releases it itself after five minutes, as `lis`
would (D456).

**Sealed check.** On the runner, as root, judging the runs since
`CHECK_SINCE` raised to the runner's last reload (`judges: runs`):
the centre's orders the lab received since then, their requests'
priority read in the record. *Present* (1) while more violations than
the threshold (0): an urgent request on an order not `urgent`, or an
urgent order the lab answered whose test came back past its turnaround
(LO4 end to end on completed orders only, D456). *Fixed* (0) with a
completed urgent order and no violation. *Too soon* (3) until an urgent
order since the judged moment is complete. The backlog (routine orders
posted before the judged moment) is never judged.
