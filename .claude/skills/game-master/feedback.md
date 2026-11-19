# Feedback — structure and tone

How the [GM skill](SKILL.md) gives feedback once the players have given
their final answer and the evaluation has run (v0.1 master spec 13; v0.2
master spec 6.3 and 9 add the tooling expectations; v0.3 master spec 11
adds the fault undetermined at the final answer, and 12 the judgement
after a restart with no history; v0.4 master spec 11.7 adds what "fixed"
means for a governance fault, 12.8 a check judging runs undetermined at
the final answer, 16.3 a report judged against an incident and 16.5 an
overstep on another party's system; v0.5 master spec 6.3, 10.3, 13.4 and
17.2 add a register fault judged on *propose*, a report-only fault on a
display, a partner's support that never answered, traffic forged as a
partner's, and a false alarm; v0.6 master spec 10 splits it into **two
parts**, the customer side then the teaching moment, 9.11 says when a
fake game's making may be explained, and 11 that it is in English).
v0.6 version, expected to evolve as games are played: the owner judges
the tone and the tooling's usefulness at acceptance. A players' score is
deferred (after v1.0, v0.3 master spec 2; a scenario's difficulty score
is not the players'): v0.6 gives no score and saves nothing, and whether
the feedback is also written to a file stays open.

## Inputs

- the final answer, as handed in;
- the evaluation: `gmctl validate` and `gmctl check`, run before
  teardown, and your judgement of each fault instance (`fixed`,
  `present`, or **undetermined**: a check still reading `too-soon` when
  you could wait no longer);
- whether the game was restarted, and from the hand-over snapshot or
  with no history (`gmctl status`, its `restart` lines);
- the times the report gives its fixes, and the `--since` you passed for
  each fix made outside a job's runner (master spec 12.1);
- what you read on a node the story gives another party, and any job
  run by hand: the players' changes there, an overstep or none; and any
  traffic forged as a partner's (a partner's side read as evidence);
- `gm/answer-key.yaml` (`what`, `why`, `evidence`, `acceptable`; and
  `tooling_expectations`: `need`, `expected`, `acceptable`, `notes`; a
  register fault's `register_diff:`; `false_alarms`: `issue`, `why`,
  `evidence`, `acceptable`), the issues of `scenario.yaml`, and
  `gm/notes.md`, whose feedback points are written for this.
- in a fake game: the restart record `local/<pg>/fake-aging.yaml`
  (`refused`; `restart.at`, `story_line` and `explains`, each
  `{observation, where, in_world}`; `history` with its `result`, `seam`
  and `reason`), the scenario document's "Fake aging" section (each
  instance's support and the limits that touch its evidence), and each
  selected fault's `aging.fake.reason` and its `gm.md`'s `**Fake
  aging.**` note;
- the tells the report names, if any, and any suspicion of a forged
  history it voices (the evaluation, step 4).

## Structure

Give it in the session, in English, in **two parts, in this order**,
both after the final answer: the customer side, then the teaching
moment. No reveal came before the final answer; the teaching moment is
where the reveals live. Name things the way the players did where you
can. Every time you mention is in UTC, as the nodes, the logs and
Grafana show it.

### Part 1: the customer side

The in-world assessment, in your voice from the customer's point of
view: how the customer sees the work it asked for. It **never steps out
of the story**: no fault or instance id, no GM document, no "planted",
no word of how the game was made (none of aging, fill, forged, virtual
clock or fake, in a fake game or a real one; the [skill](SKILL.md)'s
"Never told"), and no refused instance. Say what the customer's system
had, in the customer's terms. For example:

<!-- player -->
> Speaking for the customer: you were asked about three
> issues. The slow afternoon report is resolved: you found the missing
> index on the orders' join, added it and showed the report's time back
> under a second, which is what we asked for. On the nightly export you
> gave us a sound diagnosis but no proposal, so we can't act on it yet.
> There were five problems in our system in all, and you found four;
> your note that our monitoring keeps no history of the pooler is right,
> and your proposal would cover it.<!-- /player -->

1. **Opening.** Two or three sentences on what the customer got: the
   issues resolved, the finding it values most.
2. **The issues given**, one block per issue, in the issues' order:
   - the complaint, in a line, and the expected resolution (*report*,
     *propose* or *fix*);
   - **found or missed**: the defect behind it (now named, in the
     customer's terms), and whether the report identified it, with its
     evidence;
   - **acceptable or not**, against the expected resolution and the answer
     key's `acceptable` criteria, with the live result where it applies (a
     *fix*: the sealed check reads `fixed`, on a Grafana node in Grafana's
     live state; a *propose* or *report*: the diagnosis and the
     proposal). Say what made it acceptable, or what was missing for it
     to be. Each kind's verdict follows [Judging each kind](#judging-each-kind).
3. **The other faults present** (the hidden ones, and any known one the
   issues did not lead to): the faults found against those present,
   each found one credited and judged the same way; a missed one named,
   in the customer's terms, as something its system had. How it could
   have been seen belongs to the teaching moment.
4. **The tooling expectations**, where the answer key lists any, one
   block each; one an issue covers is judged inside that issue's block.
   Say the need, what the customer's tooling covers and lacks, and
   whether the report addressed it, as [Judging each kind](#judging-each-kind)
   says.
5. **An overstep**, named and judged, never credited: what the customer
   asked for, and what was changed outside that mandate.
6. **Anything else they reported** that is not a planted fault: whether
   it holds up, in-world. A sound extra finding is credit, not noise.
   **A reported tell** (the evaluation, step 4, master spec 9.11)
   matches no fault here: neither credited nor counted as a mistake.
   Where it reads the restart's consequences soundly, acknowledge it
   in-world from the record's `explains` (`in_world`):
   "<!-- player -->Yes: the maintenance restart at 11:00 reset those
   statistics, so they cover the last three hours only."<!-- /player -->
   A suspicion naming no observation is noted as not backed by the
   report's evidence, in a fake game as in a real one.

### Part 2: the teaching moment

Out of the story now, as a teacher to students. Give the instance and
fault ids here, as a reference only.

1. **What they missed, and how they could have seen it**: for each
   fault missed, what it was, why it matters (`why`), and where the
   evidence was (`evidence`: where to look and what it shows), so they
   know how to find it next time, **from the evidence this game actually
   held**, never from evidence a real aging would have left and this
   game didn't.
2. **What they found correctly**: the method that got them there, the
   evidence they used well.
3. **What they identified but couldn't explain**, explained: the
   cause, from the fault's `gm.md` and the scenario's notes, and the
   method points of [Judging each kind](#judging-each-kind) (a fix
   proved over time, a job's fix proved by its next run, a mandate).
4. **Why things looked as they did**: from a planted fault (its `gm.md`,
   `gm/notes.md`), or, in a fake game, from how the game was made, only
   as [Fake aging in the teaching moment](#fake-aging-in-the-teaching-moment)
   says.
5. **Validators.** Each node's official result. A validator still red is a
   finding: credit the team if they reported it (or it was beyond their
   reach, the answer key's `validators_left_red`); if they caused it (an
   envelope broken, a DO NOT TAMPER item changed), say so plainly, as a
   point to improve, not as a failure.
6. **What could have been done better**: two to four points of method,
   drawn from what you saw (an area never inspected, a fix not verified, a
   change not explained, evidence missing from the report, an envelope
   broken). Each with what to do next time.
7. **Close** on what they should take away, positively.

### Fake aging in the teaching moment

v0.6 master spec 9.11, the tell rule:

- **A reported tell** (an observation from the documented limits,
  master spec 9.10 and the record's `explains`, or from the research's
  tells, whatever cause the players gave it) is explained here, and only
  here: that the game was fake-aged, how, and why the thing looked as it
  did, from the "Fake aging" section, the fault's `aging.fake.reason`
  and `**Fake aging.**` note, and the restart record, naming this game's
  instants (`restart.at`, the history import's `at`). For example the
  statistics reset seconds before the restart, the logs starting at it,
  `pg_cron`'s history starting there, Prometheus' own series stepping
  about 12 minutes later at the import (its lowest timestamp, its
  blocks loaded), negative or jumping values at the seam where the
  record's `history.seam` failed. Credit the observation as good
  noticing, and say what a real system would have shown.
- **No tell reported: no mention of it.** Explain each missed or
  unexplained finding from the evidence this game actually held. If
  explaining a finding the report did make would be false without it,
  that finding rests on a tell, and the previous rule applies.
- **A suspicion naming no observation** ("this history looks
  generated") reports no tell: answer it as any unsupported claim,
  noted as not backed by the report's evidence, and say what evidence
  would have backed or refuted it.
- **In a real game**, a report claiming a forged history gets the same
  customer side, and the teaching moment explains why the thing really
  looked as it did.
- **A refused instance** is never named, here either.

## Judging each kind

The verdict on each goes in the customer side, in-world; the method and
the explanation (what to watch, how a fix is proved, the mandate) go in
the teaching moment.

- **undetermined**, for a fault whose check still read "too soon to
  tell" at the final answer: say so plainly, without a verdict. The
  fix was made too recently for its effect to show over the window
  the check judges, so the live system cannot say yet whether it
  holds. Judge the diagnosis and what they did on the report; say what
  to watch, and for how long, to confirm such a fix (the `evidence`),
  and, where it helps, that checking a fix over time before calling it
  done is part of the method. Never count the missing verdict against
  them. For a check judging a job's runs (an exit 3 at the final
  answer, master spec 12.8), it means no run, or none that could have
  violated, since the fix: say that a fix to a job is proved by its
  next run, that their lever was moving the job's time where the
  starter pack allows it (then watching the run), never running it by
  hand;
- **a governance fault**, judged by the live state ("fixed" as master
  spec 11.7): a definition (a classed column where it may not be, a
  grant, a mapping, a job copying data) is fixed when the live state
  complies, so removing what was copied is part of the fix, not only
  stopping the flow; say so when they stopped the flow and left the
  copy. What their fix itself created is judged too: a replacement job
  run as a superuser, or a mapping to a role that may read the class,
  is a new path, a point to improve even when the old one is gone.
  What already left (an outbox's payloads) is judged as a purpose is:
  no new violation since the judged moment; the old rows stay as the
  evidence they found. A breach naming a whole database (G1's line
  with the word `database`) is a class that must have an instance of
  its own sharing it with another database: the finding is the shared
  instance, whatever the database holds, so the database leaving the
  instance is the fix and emptying it is not;
- **a report judged against an incident** (master spec 16.3, 12.7):
  the check reads `present` whatever was changed since, as it proves
  only that the incident happened; the report is the resolution.
  Judge it on the answer key's criteria: the incident named (when,
  which process, killed for memory, the recovery that followed), its
  cause (on `purpose-heavy-job-on-database-node`, the backfill computed
  on the database node at its memory limit) and the recommendation
  (move the transformation's computation off the database node, to a
  transformer node sized for it that reads the window in batches, and
  bound backfills). A proposal moving only the schedule (another hour,
  or the same `CALL` from another node) does not move the computation,
  which still runs in the database's own backend: say so, kindly.
  **Its check reads `error` (exit 2) until the incident is in the
  log** (spec D256): before its job's run, after a kill whose recovery
  is not complete yet, and on a failed planting, none of which reaches
  a game handed over, since the hand-over check fails on it. After the
  hand-over it reads `error` too **if a player deleted the backfill
  request's row** in `reporting` (the check dates the incident's
  planting from it): that is the players' change, not the game's failure. Judge the report as if
  nothing had changed, never count the missing reading against them,
  and name the deletion as an overstep;
- **an overstep** (master spec 16.5), named positively, as a teacher
  would: the change was outside the mandate the issue gave (another
  party's system, a report or a proposal asked for). Say whether the
  change itself would have been right as a proposal, and what it cost
  (a roll-up stopped, another party's job edited behind its back). A
  sealed check reading `fixed` after it is never counted as the
  resolution. A change that is right and comes with the report still
  gets the report's credit; a change without the report leaves the
  issue unresolved as asked. A job run by hand on any node (a `CALL`, a job
  set to run at once) is the same overstep: a run outside the
  schedule, which the rules forbid; a check reading `fixed` through
  it is not taken as the fix, and the point to make is that moving a
  job's time is how to see a fix work. Traffic forged as a partner's
  (results or acknowledgements posted in its name from a node) is the
  same: it earns nothing, and the point is that a partner's side is
  evidence to read, never the customer's to write;
- **a register fault** (*propose*): the corrected entry in their
  report against the answer key's `register_diff:` (the entry, the
  field, the true value; or the register missing). Say what the
  register declared and what the system does, and whether their
  correction would close the gap; their copy of the handout in their
  home changed nothing, which is no fault of theirs;
- **a report-only fault on a display** (a component no layer of
  theirs, its firmware): judged on the report alone. Credit the chain
  they followed (the statement, the excess, the unit, the display, the
  animal) and the care taken (no instance-wide logging left behind);
  say that the customer's technician would replace the display, and
  that you never switched it off during the game;
- **a false alarm** (an issue covering no fault, `false_alarms`):
  credit a report that concluded nothing is wrong, with the evidence
  (the entry's `why` and `evidence`); when they named a cause that
  is not there, say what showed it is not, kindly: telling a customer
  "this is working as agreed", with the proof, is a finding too. A
  change they made for it is judged as any change, never as a fix;
- **a partner's support**, which never answered during the game: credit
  the message they would have sent, where the answer key says so;
  a partner's internals were never theirs to reach;
- **a tooling expectation**: not a fault, no sealed check; the
  feedback is where it is judged. Credit a diagnosis and a proposal that
  meet `acceptable` (for example any of the top three tools for the
  need); when it was missed, say what was expected (`expected`, and
  `notes` where it helps), so they look for it next time.
  **Under-tooling** (a need no tool covers) and **overkill** (tooling
  needing about three times the compute and disk of what it watches) are
  findings: credit the players who stated one, and judge a tool they
  proposed by the same yardstick, as findings, never as faults. The
  bastion and its tools are the players' kit, not the customer's
  tooling.

## Tone

A teacher's, speaking to students:

- **Positive.** Start from what they did, and keep that thread: a missed
  fault is something to learn to find, not a mark against them.
- **Specific.** Point at their own words and the system's evidence; never
  a vague "good job" or "could be better".
- **Honest.** An answer that does not meet the criteria is not called
  acceptable. Say what is missing, kindly, and how to get there.
- **Proportionate.** Most words go to what helps them improve; no
  lecture, no wall of text. A short block per issue and per fault.
- **Fair about the game.** A validator they could not make green, a
  check that errored because of the game itself, a fault left undetermined
  by a window that had not elapsed, or, after a restart with no history,
  evidence the restarted game could not build up again in the time left,
  is never held against them. Say which faults that restart affected.
- **An overstep is a lesson in mandate**, not a penalty: name it once,
  say what it cost and whether it would have made a good proposal, and
  judge the issue on what it asked for.
- **In-world, then teaching.** The customer side never steps out of the
  story; the teaching moment is where the game's mechanics, a fault's
  cause and, for a reported tell only, a fake game's making are
  explained.
