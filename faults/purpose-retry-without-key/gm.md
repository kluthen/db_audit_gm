# purpose-retry-without-key — GM notes

**What.** The integration engine posts the record's closed analysis
requests to the lab's order API
([`vet-lab-centre-orders`](../../purposes/vet-lab-centre-orders/gm.md),
`post-lab-orders`, every minute), keyed `C-{consultation}-{priority}`;
the lab answers the same key again with the same accession, so a post
the runner gave up on (no answer within its ten seconds) is safely
posted again at the next run. Planted at render, the retry takes a
reference of its own: `post()` reads the ledger's references whose last
attempt timed out and posts their group again as
`C-{consultation}-{priority}-{HHMM}`
([`inject/lab_orders.py.diff`](inject/lab_orders.py.diff)). When the
lab took the first post after all, as it usually does, the consultation
has two orders, the same requests on both, and the lab waits for a
second tube that never comes (T41, LO2; the fault held since D201).

**Writing it into a scenario.**
- The node is the purpose's runner (`interfaces`), `scheduler` 0.3.0,
  seeding `scripts/`; the scenario names `vet-lab-centre-orders` in its
  `purposes:`. In a composed scenario apply the diff to the scenario
  layer's `compose/interfaces/scripts/lab_orders.py` (`patch -p1` from
  `compose/interfaces/`) and rerun `gmctl compose` (capture W5 item 0).
  With `purpose-urgent-priority-dropped` planted too, both diffs apply to
  the one file, in either order.
- Parameters: `source` (`records/clinic`), `lab` (`lab/lab`), `job`
  (`post-lab-orders`), the clinic's names.
- **Aging minimum (spec D189), unbounded.** The definition's `0m`
  counts from the first post answered later than the runner's timeout.
  The clinic plants no slow answer: the partner's standing slowness gives
  a few a week (class M by the calibration), so a game of hours may show
  none. A scenario wanting the evidence plants the slowness (locks or a
  slow answer at the lab's order API, a partner behaviour) and states it;
  otherwise the players find the fault by reading the script, and the
  check reads *too soon* (3) for want of a retry.
- **Backlog** (master spec 6.3; the answer key's `backlog:`): the
  duplicate orders the retries left before the fix, found by the
  ledger's `-{HHMM}` references beside their timed-out first; cleaned up
  by cancelling the second order of each pair at the lab. Credited,
  never counted.
- Visibility: hidden by default (nobody at the clinic connects a second
  order to a slow night). The runner's repository is fixable through its
  write override.

**Why it matters.** A second order for the same samples costs the lab a
worklist entry, a phone call and a reagent run when it is not caught,
and the record shows one order where the lab holds two.

**Why it happens.** A retry that once met a "duplicate" refusal was
given a fresh key to get through, and nobody checked that the lab had
taken the first.

**What a good answer says.** Reads the ledger's timed-out reference
beside its suffixed twin, the two orders at the lab, finds the new key
in `post()`, proposes retrying under the same `client_ref` (the lab's
idempotency answers it with the first accession), and names the
duplicate orders to cancel.

**Fix path.** Edit `/srv/scheduler/repository/scripts/lab_orders.py`
(the repository's write override, or as root for the GM), `sudo
gm-reload-scheduler`. A short test proves it with the same delay, then
the retry answered with the first accession, one order. The delay: the
lab's order endpoint runs each statement under a five-second
`statement_timeout` (a statement waiting longer is cancelled, the order
rolled back, answered 503, retried under the same key even by the planted
script: no evidence), so the orders fixture's test holds locks on
`lab_orders`, `lab_samples` and `lab_order_tests` in turn, each until the
endpoint's insert into it has waited four seconds: about twelve seconds in
all, past the runner's ten, the order committed after the runner gave up
(`run-planted-test.sh`).

**Sealed check.** On the runner, as root, judging the runs since
`CHECK_SINCE` raised to the runner's last reload (`judges: runs`).
*Present* (1) while more requests than the threshold (0) are on two lab
order tests, one on an order received since then (LO2). *Fixed* (0)
with none and a retry since then of a post the lab took unanswered: a
ledger reference with more than one attempt, answered since then with an
accession the lab had received at least 20 seconds before the answering
run (a post answered 503 was rolled back and is no witness). *Too soon*
(3) without such a retry: nothing then tells a fixed script from a
planted one.
