# Feedback — structure and tone

How the [GM skill](SKILL.md) gives feedback once the players have given
their final answer and the evaluation has run (v0.1 master spec 13; v0.2
master spec 6.3 and 9 add the tooling expectations; v0.3 master spec 11
adds the fault undetermined at the final answer, and 12 the judgement
after a restart with no history; v0.4 master spec 11.7 adds what "fixed"
means for a governance fault, 12.8 a check judging runs undetermined at
the final answer, 16.3 a report judged against an incident and 16.5 an
overstep on another party's system). v0.4 version, expected to evolve as
games are played: the owner judges the tone and the tooling's usefulness
at acceptance. A players' score is deferred (after v1.0, v0.3 master
spec 2; a scenario's difficulty score is not the players'): v0.4 gives no
score and saves nothing.

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
  run by hand: the players' changes there, an overstep or none;
- `gm/answer-key.yaml` (`what`, `why`, `evidence`, `acceptable`; and
  `tooling_expectations`: `need`, `expected`, `acceptable`, `notes`), the
  issues of `scenario.yaml`, and `gm/notes.md`, whose feedback points are
  written for this.

## Structure

Give it in the session, in this order. Name things the way the players
did where you can; give the instance and fault ids only as a reference.
Every time you mention is in UTC, as the nodes, the logs and Grafana show
it.

1. **Opening.** Two or three sentences on what the team achieved: the
   issues they resolved, the finding they can be proudest of.
2. **The issues given**, one block per issue, in the issues' order:
   - the complaint, in a line, and the expected resolution (*report*,
     *propose* or *fix*);
   - **found or missed**: the defect behind it (now named), and whether
     the report identified it, with its evidence;
   - **acceptable or not**, against the expected resolution and the answer
     key's `acceptable` criteria, with the live result where it applies (a
     *fix*: the sealed check reads `fixed`, on a Grafana node in Grafana's
     live state; a *propose* or *report*: the diagnosis and the
     proposal). Say what made it acceptable, or what was missing for it
     to be;
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
     job's time is how to see a fix work;
   - one improvement, if there is one worth making.
3. **The other faults present** (the hidden ones, and any known one the
   issues did not lead to), one block each: found or missed. When found,
   credit it and judge it the same way. When missed: what it was, why it
   matters (`why`), and where the evidence was (`evidence`: where to look
   and what it shows), so they know how to find it next time.
4. **The tooling expectations**, where the answer key lists any, one
   block each; one an issue covers is judged inside that issue's block,
   the same way. They are not faults and have no sealed check: the
   feedback is where they are judged. Say the need, what the customer's
   tooling covers and lacks, and whether the report addressed it: credit
   a diagnosis and a proposal that meet `acceptable` (for example any of
   the top three tools for the need); when it was missed, say what was
   expected (`expected`, and `notes` where it helps), so they look for it
   next time. **Under-tooling** (a need no tool covers) and
   **overkill** (tooling needing about three times the compute and disk
   of what it watches) are findings: credit the players who stated one,
   and judge a tool they proposed by the same yardstick, as findings,
   never as faults. The bastion and its tools are the players' kit, not
   the customer's tooling.
5. **Anything else they reported** that is not a planted fault: say
   whether it holds up. A sound extra finding is credit, not noise.
6. **Validators.** Each node's official result. A validator still red is a
   finding: credit the team if they reported it (or it was beyond their
   reach, the answer key's `validators_left_red`); if they caused it (an
   envelope broken, a DO NOT TAMPER item changed), say so plainly, as a
   point to improve, not as a failure.
7. **What could have been done better**: two to four points of method,
   drawn from what you saw (an area never inspected, a fix not verified, a
   change not explained, evidence missing from the report, an envelope
   broken). Each with what to do next time.
8. **Close** on what they should take away, positively.

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
