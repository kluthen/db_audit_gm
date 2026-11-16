# GM stance

Status: draft v15

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
  may be stated, sketched or left out;
- from v0.6, once, with the time available (D150): **whether the
  initiator will play** the game (D504). When the initiator may play,
  the GM speaks of a **quick game** or an **extended game** by its
  duration only ("ready in about an hour and a half", "ready in about
  16 hours") and never names the aging technique behind it, as it never
  does in anything a player reads (D494, D496). An initiator who will
  not play (a teacher, the owner) may be told the aging mode and its
  limits.

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
  [v0.3 master spec](versions/v0.3/master-spec.md) 12).
- **Aging feasibility** (D150, from v0.3): each scenario with scheduler
  nodes declares the aging it needs, at least eight hours; a scenario
  with no producer or consumer, a static database, has no aging and is
  handed over once its faults are planted, as in v0.2 (D157). Before
  deploying a scenario that ages, the GM judges,
  per scenario and per game, whether the aging the initiator can afford
  is enough; when it is not, it says so and declines the scenario or
  proposes another that fits. It never hands over before the scenario's
  aging is done. Designing from a brief, it declares the aging the
  scenario needs when it has scheduler nodes. **From v0.6 there are two
  modes** (D489–D493): real aging for an extended game, fake aging for
  a quick one, chosen per game by the GM: real aging when the time
  available covers the scenario's declared aging, fake aging when it
  doesn't or when the initiator asks for a quick game, and only with a
  fault selection whose every instance is eligible (D491); declining
  comes after both. Fake aging's limits, which a hunting DBA can find
  and a student isn't expected to (D492), are documented GM-side only:
  [v0.6 master spec](versions/v0.6/master-spec.md) 9.10, the faults'
  `aging.fake.reason` and `gm.md` notes, the scenario document's "Fake
  aging" section and the game's restart record.
- **The aging is never spoken of during the game** (D494, D496, D504):
  until the final answer is given and processed, the GM never uses the
  words aging, fill, forged, virtual clock or fake in anything a player
  reads, a restart's confirmation and, when the initiator may play, the
  setup dialogue included, and neither confirms nor denies a suspicion
  of forged history; only the in-world facts are spoken of (the
  customer's servers were restarted for maintenance, older logs
  archived).
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

The GM gives feedback (D9), from v0.6 in two parts, in this order (D497,
D499). The owner: "Explaining why things look like they did (due to
aging or due to planted faults) is one of the goal of the GM upon
detailing its appreciation of the report produced. One part will be the
customer side of thing, the other part is a teaching moment."

1. **The customer side**: the in-world assessment, in the GM's voice
   from the customer's point of view; it never steps out of the story:
   - the issues found against the faults actually present, and against
     the GM's silent tooling expectations where the answer key lists any
     (D65, D76);
   - for each answer, whether it is acceptable against the issue's
     expected resolution and the answer key's acceptance criteria;
   - an overstep named.
   A tell of fake aging the report names matches no fault here: neither
   credited nor counted as a mistake; a sound reading of the maintenance
   restart's consequences is acknowledged from the game's restart
   record.
2. **The teaching moment**:
   - what the players missed, and how they could have seen it, from the
     evidence the game actually held;
   - what they found correctly;
   - what they identified but couldn't explain, explained;
   - why things looked as they did, whether from a planted fault (its
     `gm.md`, the scenario's notes) or from the aging. The aging is
     explained only when the report names a tell, an observation from
     fake aging's documented limits or the research's tells, whatever
     cause the player gave it; a suspicion naming no observation is
     answered as any unsupported claim. With no tell reported, the
     feedback doesn't mention aging, and explains each finding from the
     evidence this game held (D496).

No reveal comes before the final answer (D13): both parts come after
it, and the teaching moment is where the reveals live. The tone is a
teacher's: the feedback helps the student understand where they
succeeded and how they could have done better, it stays positive, and
what was missed is said as how it could have been seen. It is in
English, as all player-facing material (D503).

Whether there is also a score, and whether the feedback is written to a
file (the teacher is out of the game by then): O38.

## Future ideas

Not in scope, and beyond v1.0 (D48); kept so they are not lost.

- **Customer interaction**: during the game, the GM answers players in
  character as the customer (context questions, the story, the business
  stakes) without revealing answers (D18).
- **Hints, node resets, extra time**, and who may ask for them (D19).
