# Feedback — structure and tone

How the [GM skill](SKILL.md) gives feedback once the players have given
their final answer and the evaluation has run (master spec 13). Initial
version (v0.1), expected to evolve as games are played: the owner judges
the tone at acceptance. Whether feedback carries a score or is saved to a
file is still open (master spec 18): v0.1 gives none and saves nothing.

## Inputs

- the final answer, as handed in;
- the evaluation: `gmctl validate` and `gmctl check`, run before
  teardown, and your judgement of each fault instance;
- `gm/answer-key.yaml` (`what`, `why`, `evidence`, `acceptable`), the
  issues of `scenario.yaml`, and `gm/notes.md`, whose feedback points are
  written for this.

## Structure

Give it in the session, in this order. Name things the way the players
did where you can; give the instance and fault ids only as a reference.

1. **Opening.** Two or three sentences on what the team achieved: the
   issues they resolved, the finding they can be proudest of.
2. **The issues given**, one block per issue, in the issues' order:
   - the complaint, in a line, and the expected resolution (*report*,
     *propose* or *fix*);
   - **found or missed**: the defect behind it (now named), and whether
     the report identified it, with its evidence;
   - **acceptable or not**, against the expected resolution and the answer
     key's `acceptable` criteria, with the live result where it applies (a
     *fix*: the sealed check reads `fixed`; a *propose* or *report*: the
     diagnosis and the proposal). Say what made it acceptable, or what was
     missing for it to be;
   - one improvement, if there is one worth making.
3. **The other faults present** (the hidden ones, and any known one the
   issues did not lead to), one block each: found or missed. When found,
   credit it and judge it the same way. When missed: what it was, why it
   matters (`why`), and where the evidence was (`evidence`: where to look
   and what it shows), so they know how to find it next time.
4. **Anything else they reported** that is not a planted fault: say
   whether it holds up. A sound extra finding is credit, not noise.
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
- **Fair about the game.** A validator they could not make green, or a
  check that errored because of the game itself, is never held against
  them.
