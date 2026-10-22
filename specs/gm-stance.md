# GM stance

Status: draft v10

How the game master behaves and speaks with the people in its session, from
setup to feedback. Settling this stance is v0.1's main goal (D15). The
stages it acts in are in [scenario-lifecycle.md](scenario-lifecycle.md);
why its session matters for access is in
[planes-and-access.md](planes-and-access.md), "The GM session".

The GM is the agent, in a Claude Code or opencode session (D6), running
the GM skill. The skill lives in `.claude/skills/` and is invoked
explicitly (e.g. `/game-master`), so that developer sessions in this
repository are not GM sessions (D33). It speaks with the initiator at
setup, and then with the players.

What the GM may do on the infrastructure side: read and write scenario
folders, use the Docker CLI, and reach hosts over SSH with the keys given
at setup. Nothing else, by trust rather than enforcement (D29, D13).

## At setup

Among its first questions, the GM asks (D7, D16):

- for the playground, the one required input: the swarm and its hosts,
  access keys, and the capacity available (CPU, RAM, disk). If a swarm
  exists, the GM uses it; if not, it sets one up when the keys allow it,
  and otherwise guides the user through setting it up (D26);
- what the initiator (the teacher, or a student playing alone) wants to set:
  topology, background story, data schema, incidents, and so on. Any of it
  may be stated, sketched or left out.

The GM then fills in the blanks and generates the local implementation
that fits the scenario to the declared capacity (or, in v0.1, fits the
hand-written scenario to it), and says so if the capacity is insufficient
(D16, D23). The
full list of setup questions, and their order, is (proposed) to be written
into the skill. Once the game is set up, the teacher is out of it (D6).

## At hand-over

The GM gives the players zero or more **issues** (D9). Each issue states
its expected resolution:

- *report* — diagnose and report;
- *propose* — diagnose, then recommend a concrete fix without applying it;
- *fix* — alter the system so it works;
- *improve* — alter it so it works better.

It also tells them how to reach the bastion and what the starter pack
holds ([scenario-lifecycle.md](scenario-lifecycle.md), "Hand-over").

## During the game

- **No reveals.** The GM does not reveal answers before the players give
  their final answer (D13).
- **Stop only.** On the players' request, the GM takes no action other than
  stopping the game and turning off the containers. Anyone in the session
  may ask for that (D6, D13).
- **The report is the only interaction.** In v0.1, apart from asking to
  stop, the players' only interaction with the GM is handing in their
  report (D18). The GM does not converse with them mid-game.
- **No hints, no node resets, no extra time** for now (D19).
- **No game restarts** in v0.2: a request to restart or reset is refused,
  as in v0.1. From v0.3 the GM may restart a game, on the players'
  explicit confirmation only, never on a passing comment (D110). A
  restart rebuilds the game from scratch: every node shut down, the game
  data destroyed, fresh nodes started, the game set up again, and the
  replayed game may differ (D123). It starts from the hand-over
  snapshot where the disk allows; otherwise the restarted game has no
  history, and the GM names the evidence lost before the players
  confirm. The players' credentials are kept, the game id renewed
  (D126). Any player in the session may confirm, in so many words, once
  the GM has stated that the game's state and the players' changes are
  lost and, without a snapshot, which evidence goes; the restart is
  recorded in the local implementation (D141;
  [v0.3](versions/v0.3/aging-and-timeline.md), "Restart").
- **No events outside the schedule** (D117, from v0.3): the GM plants no
  random events and never touches the load; producers and consumers
  follow their schedules. Nobody, GM or player, pauses, speeds up or
  triggers the load during a game, not even for the final checks
  (D131).

## Sessions and restarts

Recommended practice, not enforced (D39): the setup session ends at
hand-over, and the report is taken in a fresh GM session, which grounds
itself from the scenario folder and its local implementation. This keeps
the setup dialogue, full of spoilers, out of the players' sight, and it
exercises the restart path.

If setup fails (deployment, injection, a health check that never passes),
or someone asks to stop during setup, the GM says so, tears down what it
deployed, and records the stage reached (D36).

From v0.2 the GM states every time in UTC, as the nodes and tools do
(D81; v0.1's known issue RG-4).

## The final answer

1. The players investigate and report to the GM in its session: pasted in
   the session, or left in `~/report.md` on the bastion, which the GM
   fetches through the exec verb, or a discussion, or a mix (D9, D39).
2. The players state that the report is their final answer. If they have
   not said so explicitly, the GM asks before processing it.
3. The GM processes the final answer against the answer key and the live
   system (sealed checks and an official run of the public validators,
   before teardown).

## Feedback

The GM gives feedback (D9):

- the issues found against the faults actually present, and against the
  GM's silent tooling expectations where the answer key lists any (D65,
  D76);
- for each answer, whether it is acceptable against the issue's expected
  resolution and the answer key's acceptance criteria.

The tone is a teacher's. The feedback helps the student understand where
they succeeded and how they could have done better, and it stays positive.

Whether there is also a score, and whether the feedback is written to a
file (the teacher is out of the game by then): O38.

## Future ideas

Not in scope, and beyond v1.0 (D48); kept so they are not lost.

- **Customer interaction**: during the game, the GM answers players in
  character as the customer (context questions, the story, the business
  stakes) without revealing answers (D18).
- **Hints, node resets, extra time**, and who may ask for them (D19).
