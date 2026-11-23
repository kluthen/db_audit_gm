---
name: game-master-restart
description: "GM only, invoked by the game master: a restart of the whole db_audit_gm game, asked for and confirmed by a player, from its statement to the restarted game's hand-over."
---

# Game master: a restart

A workflow of the game master. Its definition,
`.claude/agents/game-master.md`, holds the stance and the rules every
workflow shares; they hold here too.

## Restart

A whole-game restart rebuilds the game from scratch: every node shut
down, the game's data destroyed, fresh nodes started under a new game id,
the game set up again. It is the players' operation, after hand-over
(`handed-over`; `gmctl` also allows it at `final-answer` and
`feedback-given`); before hand-over, setting a game up again is a stop
then a start ([The aging](../game-master-setup/SKILL.md#the-aging)). A node reset is not a restart: it
is refused (see [the stance](../../agents/game-master.md#the-stance)).

1. **Who.** Any player in the session may ask and confirm. Someone who
   says they are not playing (a teacher watching, the initiator who is
   not a player) cannot: say that only a player of the game may confirm
   a restart.
2. **The statement, before anything.** Read `gmctl status` (`snapshot:`
   line) and tell them, in plain words, these points, in either mode
   and never naming how the game was made ([the stance](../../agents/game-master.md#the-stance),
   "Never told"):
   - "<!-- player -->The whole game is rebuilt from scratch: the
     system's state and every change you made are lost: your fixes,
     edited files, the databases' changes and your files on the bastion,
     `~/report.md` included. Copy off anything you want to keep
     first."<!-- /player -->
   - "<!-- player -->Your passwords and the bastion's address and port
     stay the same. The session still ends at <end> UTC: a restart gives
     no extra time. The replay may differ in its details."<!-- /player -->
   - **with the hand-over snapshot** (`snapshot: taken`):
     "<!-- player -->The system comes back as it was when you received
     it; its history has a gap from then to the restart, a maintenance
     window."<!-- /player -->
   - **without it** (`snapshot: not-fitting`): there is no copy of the
     system as handed over, so it restarts from nothing (the data loaded
     again, every fault planted again at once and, in a game that ages,
     the load started again at once; in a fake game on the real clock,
     with no fill and no history import, capture W3 item 7). Name the
     evidence that goes with it, as the players would meet it, by place
     and time, never by fault or answer:
     "<!-- player -->There is no copy of the system as you received it,
     so it restarts from nothing: its data loaded again and its
     applications started again. Everything it recorded before the
     restart (its logs, its metrics, its jobs' runs) is gone; only what
     it records from the restart on will exist, and what takes longer to
     build up than the time left in the session will be thin or
     missing."<!-- /player --> (Judge that last point from each fault
     instance's own aging minimum against the time left; in a static
     game, say only that the monitoring's history before the restart
     goes.)
3. **The question.** <!-- player -->"Do you confirm the restart? Say so in so many
   words; anything less and the game goes on."<!-- /player --> Only a player's explicit
   confirmation, given after the statement, counts ("Yes, we confirm:
   restart the game."). A passing mention, a question about restarting,
   a conditional or a hesitation never restarts the game: answer it,
   repeat the question if they want to go on, and otherwise carry on.
4. **The restart**, with the player's words verbatim, inside single
   quotes (a `'` in them written `'\''`), never paraphrased:

   ```sh
   tools/gmctl restart <dir> --playground <pg> --confirmation 'Yes, we confirm: restart the game.'
   ```

   It refuses without a confirmation (or a blank one), before hand-over,
   and when a snapshot copy, an image or a secret file is missing; nothing
   is done then. It prints `Game <old id> restarted from the hand-over
   snapshot | with no history as game <new id> (confirmed: "...")`, what
   it removed (the snapshot kept, every secret's value kept under new
   objects), what it restored, loaded, planted and started, and `Stage
   handed-over; the four hours still count from the first hand-over.` It
   records the restart (old and new game ids, the time, from the snapshot
   or not, the player's words). On several hosts it may refuse because
   the overlay's recorded subnet, or every /24 of its range, is now taken:
   choose another range as in setup step 4 and run it again with
   `--overlay-range <cidr>` added (`gmctl fit --overlay-range` then counts
   only for the playground's next games).
5. **After it**, tell the players the game is back (the address and
   ports unchanged, and every credential on the web front's Access
   section, Grafana's login included, unchanged too) and, from the
   snapshot, the maintenance window:
   "<!-- player -->The system is back, as it was when you received it.
   Your addresses and credentials are unchanged. Its history has a
   maintenance window from 14:00 to 14:20 UTC. The session still ends at
   18:00 UTC."<!-- /player --> Without the snapshot the
   bastion's SSH host key is new, so their SSH client warns of a changed
   host key: that is expected (`ssh-keygen -R '[<address>]:<port>'` clears
   the old one). Repeat the session's end. Their next steps are theirs.
   `restart`'s own output names how the game was rebuilt: it is yours,
   never read out.
6. **A failed restart** (exit 1, "failed"): what it deployed is torn
   down, the stage is `failed`, the snapshot kept. Tell the players, then
   run the same command again (the same words) or, if it fails again for
   a reason you cannot fix with the initiator, tear the game down. A
   second restart, later, starts from the snapshot again.

The rebuilt game is judged like any other at the final answer; without a
snapshot, judge each fault on what the restarted game could still show
([Evaluation](../game-master-evaluation/SKILL.md#evaluation)). **A fake game restarted** (capture W3
item 7) stays the same fake game: from the snapshot, Prometheus' volume
brings the imported history back, with no second import; with no
history, it is rebuilt on the real clock, the refused instances still
out of it and the story keeping its restart line. Either way the
restart record stays the first game's, for the feedback.
