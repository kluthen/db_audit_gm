---
name: game-master-evaluation
description: "GM only, invoked by the game master: taking the players' report and final answer in a db_audit_gm game, and evaluating it."
---

# Game master: the final answer and its evaluation

A workflow of the game master. Its definition,
`.claude/agents/game-master.md`, holds the stance and the rules every
workflow shares; they hold here too.

## Report and final answer

The players hand in the report in one of three ways:

- **pasted** into the session;
- **left in `~/report.md` on the bastion**: fetch it with
  ```sh
  printf '%s\n' 'cat ~/report.md' | tools/gmctl exec <dir> --playground <pg> --node <bastion> --user player
  ```
  Exit 1 with "No such file": tell them nothing is at `~/report.md` and
  ask how they want to hand it in. Exit 125: the command could not start
  (reason on stderr); check `gmctl status`;
- **by discussion**: let them talk it through, then restate it as a
  structured summary (per issue, then anything else found) and ask them
  to confirm or correct it.

**When each fix was made.** If the report says they fixed something
outside a job's runner (a constraint, a grant, a role, a `pg_cron` job,
a database procedure, a crontab entry) without saying when, ask the time
of each such change, in UTC, as part of taking the report: the
evaluation judges a job's runs from it (`--since`,
[Evaluation](#evaluation)). It is a question about their own report,
not a hint: ask it of every fix they list, never only of some.

Then the **final-answer question**: unless they have said it is their
final answer, ask <!-- player -->"Is this your final answer? Once it is, I evaluate it
against the live system and the game ends."<!-- /player --> If it is not, the game goes
on and you say nothing about the content. When it is, record it:

```sh
tools/gmctl status <dir> --playground <pg> --set final-answer
```

From now on, nothing is secret: the feedback may name every fault. The
game is **concluded** once you have processed the final answer (the
evaluation below); how the game was made is still spoken of only as the
[feedback note](../game-master-feedback/SKILL.md) says: never in the customer side, and in
the teaching moment only to explain a tell the report names (v0.6
master spec 9.11).

## Evaluation

Compare the final answer with the answer key and the live system, before
teardown. In a game that ages the load still runs: readings drift between
two runs, and you never pause or trigger it for a check. The checks
judge causes where they can, and behaviour over a trailing window where
only behaviour shows the fault; on a PostgreSQL node they connect as the
GM check role, inside its reserve, so they get a connection even when
the players' slots are full.

1. **Re-read** `gm/answer-key.yaml` (each instance's `what`, `why`,
   `evidence`, `acceptable`, `sealed_check`, `interactions`,
   `validators_left_red`, a register fault's `register_diff:`, the
   `tooling_expectations` and the `false_alarms`), `gm/notes.md`,
   and the issues in `scenario.yaml` (`expected_resolution`, `covers`).
   In a fake game, also the restart record (`local/<pg>/fake-aging.yaml`:
   `refused`, `restart.at`, `story_line`, `explains`, `history` with its
   reason), the scenario document's "Fake aging" section, and each
   selected fault's `aging.fake.reason` and its `gm.md`'s `**Fake
   aging.**` note.
2. **The official validator run:**
   `tools/gmctl validate <dir> --playground <pg>`. Exit 0 every node
   green, 1 a node red, 2 a validator errored or the run was refused.
3. **The sealed checks:** `tools/gmctl check <dir> --playground <pg>`. One
   line per fault instance, `fixed`, `present`, `error` or `too-soon`;
   exit 0 all fixed, 1 any present, 3 any too soon to tell (none present
   or errored), 2 any error or refused. A sealed check on a
   Grafana node judges **Grafana's live state through its API** (what
   Grafana runs, the players' changes in its UI included), not only its
   provisioned files.

   **The judged moment** (master spec 12.1). A check whose answer-key
   entry has `judges: runs` or `triggers` judges a job's runs (or a
   pushed obligation's triggers) since a moment, `CHECK_SINCE`: the
   hand-over by default, raised by the check itself to the runner's last
   successful reload (a fix to a job's SQL or time takes effect only
   through a reload). **When the report dates a fix made outside the
   runner** (a constraint, a grant, a role, a `pg_cron` job, a procedure
   the job calls), raise it to that time, from the report, one instance
   per run:

   ```sh
   tools/gmctl check <dir> --playground <pg> --since 2026-10-27T15:20:00Z --instance <id>
   ```

   `--since` (`YYYY-MM-DDTHH:MM:SSZ` or `YYYY-MM-DDTHH:MMZ`, UTC) only
   raises the judged moment of the instances run that judge runs or
   triggers; it is refused in the future, malformed, when no instance run
   judges runs or triggers, and with `--early-check` or
   `--handover-check`. Without `--instance` it raises every judging
   instance's, so date each fix with its own instance. A `pg_cron` job
   keeps no change time, and a job whose ledger lives on a database node
   is not raised to a reload: their fixes are dated by `--since` alone.
   Past violations never count: `fixed` means no new violation since the
   judged moment, with at least one run that could have violated.

   **"Too soon to tell"** is an answer: `<instance> <fault-id>: too-soon —
   <N> s of the window remain`. The check judges behaviour over a window
   that has not elapsed since the last change (a fix made shortly before
   the final answer). Wait the longest N among those lines, with the
   load running as it is, then run `check` again: tell the players the
   evaluation needs that many more minutes of the system's own traffic.
   When the wait is longer than the session allows them to stay, or the
   check reads too soon again for a reason that will not end, do not
   wait: that fault is **undetermined**, and the feedback says so
   ([feedback note](../game-master-feedback/SKILL.md)).
   For a check judging runs, too soon reads `<instance> <fault-id>:
   too-soon — the job's next run is in <N> s (<duration>), judged since
   <CHECK_SINCE>`: no completed run since the judged moment, or none that
   could have violated. Wait for that run when the session allows it,
   as for a window; a nightly job's next run is often past the session:
   then do not wait, the fault is undetermined at the final answer
   (master spec 12.8), and the job is never run by hand. When the players
   moved the job's time to see their fix work, wait for the moved time
   they report rather than `N`, which may count to the job's designed
   time (a job whose ledger lives on a database node), if the session
   allows it.
   Where judging an answer needs a reading the checks do not give (a
   scrape target, a rule's state, a line of the server log, what a fix
   changed), read it yourself, as
   [Operating the nodes and the monitoring tools](../../agents/game-master.md#operating-the-nodes-and-the-monitoring-tools)
   says, before teardown.
4. **Judge each fault instance**:
   - **found?** Does the report identify it (the defect, not just a
     symptom), with evidence?
   - **acceptable?** Against the answer key's `acceptable` criteria and
     the issue's expected resolution: for a *fix*, the sealed check must
     read `fixed` and the report say what was done; for a *report* or a
     *propose*, the diagnosis (and the proposal) must meet the criteria,
     and `present` is the expected reading (the answer key's
     `sealed_check.notes` says when `fixed` is fine too). A hidden fault
     is judged on the same criteria, as far as the players went.
   - **interactions**: where the answer key lists one, check whether a
     fix of one instance changed another's reading.
   - **a governance fault** (its check runs the governance check set, G1
     to G4, master spec 11.6): a definition (G1 location, G2 readers, G3
     reach) is `fixed` when the live state complies, what was copied
     removed too, not only the flow stopped; what a fix itself creates is
     judged as well (a replacement job run as a superuser is a new path).
     An outbound flow (G4) is judged as a purpose is: no new violation
     since the judged moment, what was already sent staying as evidence
     (master spec 11.7). A G1 breach line whose object is a whole
     database names it with the word `database` (a class with
     `separation: instance`: sharing the instance is the finding).
   - **an incident fault** (master spec 12.7, 16.3): its check reads
     `present` while the incident is in the log since its planting,
     whatever the players changed since: it proves the incident happened,
     never 0 or 3, and no in-game fix is expected. The report is the
     resolution, judged against the incident by the answer key. It reads
     `error` after hand-over when its trigger can no longer be read: on
     `purpose-heavy-job-on-database-node`, when a player deleted the
     backfill request's row on the node. Run it once more (a server
     recovering at that very moment reads the same); if it stays so,
     that is the players' change, not the game's failure: read the node
     to confirm it, judge the report as if nothing had changed, and name
     the change as an overstep.
   - **an overstep** (master spec 16.5, access model 7 and 12): a change
     the players made on a node the story gives another party, where its
     issue asked for a report or a proposal (its data, DDL, roles,
     settings, `pg_cron` jobs or crontab, a reload or a restart), or a
     job they ran by hand on any node (a `CALL`, a `cron.alter_job` or a
     crontab entry set to run at once). Read what changed from the node
     itself ([Operating the nodes](../../agents/game-master.md#operating-the-nodes-and-the-monitoring-tools):
     its crontab, `cron.job`, the procedure, the rows the fault planted,
     the server log). A sealed check reading `fixed` after such a change
     tells you what changed; **it is never the resolution and never
     credited as one**: the answer key judges the report or proposal the
     issue asked for, and the feedback names the overstep
     ([feedback note](../game-master-feedback/SKILL.md)). Traffic forged as a partner's
     from a node (results, shipments or acknowledgements posted in its
     name) is one too: a check reads a partner's side as evidence and
     judges the customer's, so it earns nothing.
   - **a register fault** (`governance-register-*`, master spec 13.4):
     resolved by *propose*, judged at the final answer only. The players
     cannot edit the customer's register: the corrected entry is in
     their report, judged against the instance's `register_diff:` (the
     entry, the field, the true value; or the register left out). The
     sealed check reads only that the change is in the bastion's copy:
     `present` is the expected reading. Their edits to the handout in
     their home change nothing, and are neither credit nor an overstep.
   - **a report-only fault on a display** (a component the story gives
     no layer of the players', master spec 6.3: a ward display's
     firmware): resolved by *report*, judged at the final answer on the
     report alone against `acceptable` (what it names: the display, the
     unit, the animal, the excess shown; what it leaves behind: no
     instance-wide logging). You never cleared it during play, so its
     check reads `present`, as expected; it is never *fixed*, and the
     feedback says the customer's technician would replace the display.
   - **a third party's side**: no *fix* names a partner's node; a
     message the report would send a partner (its support never
     answered) is credited where the answer key's `acceptable` says so.
   - **undetermined**: a *fix* whose check still reads too soon is
     neither acceptable nor not: judge the diagnosis and what they did on
     the report, and never count the missing verdict against them.
   - **after a restart with no history**: a fault whose evidence the
     restarted game could not build up again in the time left (its own
     aging minimum longer than that time) is judged on what the players
     could still see; missing it is not held against them.
   - **a refused instance** (the record's `refused`, a fake game): out of
     the game, neither expected nor credited, and never named to the
     players, in either part of the feedback.
   - **a reported tell** (v0.6 master spec 9.11): the report names an
     observation from fake aging's documented limits (master spec 9.10,
     the record's `explains`, the "Fake aging" section's limits: the
     statistics reset at the restart, no log before it, `pg_cron`'s
     history starting there, Prometheus' own series stepping at the
     import, the forged past's shape, ...) or from the research's tells,
     whatever cause the players gave it. It matches no fault: neither
     credited nor counted as a mistake. Where it is a sound reading of
     the restart's consequences ("the statistics were reset at 11:00, so
     the statement figures cover the last three hours only"), it is
     acknowledged in-world from the record's `explains`. It is explained
     in the teaching moment only ([feedback note](../game-master-feedback/SKILL.md)).
   - **a suspicion naming no observation** ("this history looks
     generated"), in either mode: judged as any unsupported claim, noted
     as not backed by the report's evidence; it reports no tell. In a
     real game, a report claiming a forged history gets the same
     customer side, and the teaching moment explains why the thing really
     looked as it did.
5. **Judge each false alarm** (`false_alarms`, where the answer key
   lists any: an issue whose `covers` is `[]`, expecting *report*; spec
   D459). There is no fault behind the complaint: no instance, no sealed
   check, nothing counted in the difficulty. It is judged at the final
   answer only, on the report: did the players conclude that nothing is
   wrong, for the reason the entry's `why` gives, with evidence like its
   `evidence`, as its `acceptable` says? A report naming a cause that is
   not there is a miss, judged kindly; a change they made "fixing" it is
   judged as any change is (what it did, whether it harmed), never as a
   resolution. Asked during play whether a complaint is real, you
   answer as for any reveal.
6. **Judge each tooling expectation** (`tooling_expectations`, where the
   answer key lists any). It is not a fault: it has no sealed check and is
   judged in the feedback only. Did the report address the `need`, say
   what the customer's monitoring covers and lacks against `expected`,
   and is what they noted or proposed `acceptable`? Under-tooling (a need
   no tool covers) and overkill (tooling needing about three times the
   compute and disk of what it watches) are findings, whoever states
   them, never faults. The bastion and its tools are the players' kit,
   not the customer's tooling.
7. **Validators.** A red validator is a finding to report, not a failure
   of the players: credit them if they reported it (the answer key's
   `validators_left_red` lists those they cannot make green). A red the
   players caused (an envelope broken, the GM's line removed) is a point
   for "what could be done better".
8. **Errors.** A `check` line `error`, or a validator `error`, means the
   result is unknown. Read the reason, and the node's logs:
   `tools/gmctl logs <dir> --playground <pg> --node <node> --tail 50`
   (for a PostgreSQL node whose server log is in files, read them through
   `exec` instead: `gmctl logs` shows only its start-up; see
   [Operating the nodes](../../agents/game-master.md#operating-the-nodes-and-the-monitoring-tools)).
   On a Grafana node, an `error` because Grafana refused the
   administrator's login (HTTP 401 from the helper, or the validator's
   `ERROR: Grafana refused the administrator's login`) means its password
   is no longer the tools password: the DO NOT TAMPER rule was broken.
   Call Grafana's API no more: each call is one more failed login towards
   the lockout. A
   restart would set the password back, but restarting a node is not a
   `gmctl` operation: do not. If the players broke something marked DO
   NOT TAMPER, or left the server down, say so in the feedback, and judge
   the instances it hides on the report alone; if it is the game's own
   failure, say that, and judge the instance on the report alone. Never
   count a game failure against the players.
