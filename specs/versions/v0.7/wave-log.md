# db_audit_gm v0.7 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: the wave driver records the captures here (plan, "Read
first").

On 2026-11-19 the owner approved the master spec, the access model and
build plan v1 ("approved. you may merge. ok"; spec D574) and settled
`main`'s history (spec D575). `v0.7-spec` was merged into `main` as
03429d9 the same day (G2).

## Wave 1 — started 2026-11-19

Chunks 1, 2, 3, κ = 1 (v0.6's wave 3 is at its gate and wave 4 follows,
driven from another session; at most two active chunk owners in total).
Branch `v0.7-w1`, worktree `/home/bastien/work/db_audit_gm-wt/v0.7-w1`,
cut from `main` at 03429d9. Order: 1, 2, 3.

### Gates checked at the start

- G1: done (2026-11-19, spec D574).
- G2: done (2026-11-19): `v0.7-spec` merged into `main` as 03429d9 after
  `doc-ids compare main v0.7-spec` (0 collisions, 0 warnings).
- Heads-up given to the owner: `v0.6-w3`'s merge into `main` will meet
  text conflicts in `specs/README.md`, `specs/decisions.md` and
  `specs/formats.md` (both sides append; no ID collision,
  `doc-ids compare v0.6-w3 v0.7-spec` 0/0). They are resolved by taking
  both sides' lines.

### Capture W1: the assistant's files and settings, the spoiler word list, `tools/play`'s command line, `game-mode/paths` and `publish.py` (chunks 1, 2, 3; read by 4, 5, 7)

Recorded 2026-11-19 by the wave driver, before any code, from the
capture lines of chunks 1 to 3 and master spec 6.10, 7.3, 7.4, 7.6, 8.2
and 8.3. Where a point below is not in the master spec, it is the
capture's choice, and a chunk that needs it changed stops and reports
it.

1. **The assistant's files.** `.claude/agents/game-assistant.md`
   (Claude Code), `.opencode/agents/game-assistant.md` (OpenCode),
   `.claude/game-assistant.settings.json` (committed, session-only,
   passed with `--settings`). The settings file holds exactly these
   keys:
   ```json
   {
     "skillOverrides": {
       "game-master": "off",
       "scenario-format": "off",
       "scenario-document": "off",
       "data-register": "off",
       "network-overview": "off"
     },
     "autoMemoryEnabled": false,
     "permissions": {
       "deny": ["Bash(psql:*)", "Bash(docker:*)", "Bash(tools/gmctl:*)"]
     }
   }
   ```
   Chunk 4 adds every `game-master-<workflow>` skill to `skillOverrides`
   in the commit that creates it.

2. **The spoiler word list** lives in `game-mode/spoiler-words` (dev-only:
   `game-mode/` is in 8.2's dev-only paths). Chunk 3 creates it with
   exactly the lines below. Chunk 1 checks its definitions against the
   same list (copied from here into a scratch file) before chunk 3 lands.
   - Format: one term per line, `#` comments and blank lines ignored.
   - Matching is case-insensitive and whole-word, as `grep -i -w -f`
     does. A term of two words matches as a phrase.

   ```
   # The words the GM never uses in front of players (D494, D496, D504)
   aging
   ageing
   aged
   fill
   filled
   forged
   forge
   fake
   faked
   virtual clock
   vclock
   gm_vclock
   # The GM side of a scenario
   answer key
   answer-key
   answer_key
   gm.md
   planted
   sealed check
   restart record
   ```
   - **Fault names** are not in the file. `publish.py` reads them at
     check time from the directory names under `faults/` and scans for
     them as whole words.
   - **SQL injection** is a legitimate DBA subject. That is why
     `inject`/`injection` are not listed.
   - Because the match is whole-word, the assistant's definitions also
     avoid the listed words in harmless senses ("fill in the report":
     write "complete the report").

3. **`tools/play`'s command line.** `tools/play <verb> [--opencode]
   [--dev]`.
   - **Verbs:** `gm` and `assistant`. The flags may come in any order
     after the verb. `-h` or `--help` prints the usage and exits 0.
   - **Before running anything,** it `cd`s to the repository root (the
     script's own directory's parent), so the relative `.claude/...`
     paths resolve.
   - **Branch check:** `git symbolic-ref --short -q HEAD`. On branch
     `dev` without `--dev` it prints `tools/play: this checkout is on
     branch dev; a game is played from a fresh clone of main (--dev
     overrides, for the build's tests)` to stderr and exits 1.
   - **Unknown verb or flag:** the usage goes to stderr, exit 2.
   - **Running an agent:** it `exec`s the tool, so the tool's exit
     status is the launcher's.
     - `assistant` runs `claude --agent game-assistant --settings
       .claude/game-assistant.settings.json`; with `--opencode`,
       `opencode --agent game-assistant`.
     - `gm`, until chunk 5, prints `tools/play gm: not yet available` to
       stderr and exits 1.

4. **`game-mode/paths`.**
   - **Format:** one entry per line, relative to the repository root;
     `#` comments and blank lines ignored.
   - **Matching:** each entry is a git pathspec in glob magic (as
     `:(glob)<entry>`). A trailing `/` names a directory and everything
     under it, and `*` and `**` follow git's glob rules. Examples:
     `specs/`, `bricks/*/sbom/`, `tools/tests/`.
   - **What it lists:** the dev-only paths of master spec 8.2, itself,
     `game-mode/` and the `publish-main` skill included.

5. **`game-mode/publish.py`'s command line.** `python3
   game-mode/publish.py [--check-only] [--from <rev>] [--repo <path>]`.
   - **Defaults:** `--from HEAD`; `--repo` is the repository holding the
     script.
   - **The run:** it builds `main`'s tree from `<rev>` (8.3 step 1) in a
     temporary worktree or index, never in the caller's checkout, then
     runs every check of 8.3 step 2. Each finding is printed on one line,
     as `<check>: <path>[:<line>]: <what>`.
   - **Exit codes:**
     - 0: no finding;
     - 1: findings;
     - 2: a usage or git error.
   - **`--check-only`:** it stops after the checks, and writes nothing to
     any branch or to the caller's checkout.
   - **Without `--check-only`,** on no finding, it commits the tree as
     one new commit on `main`, the message naming the `<rev>` it came
     from (8.3 step 3). Then it prints the push command and never runs it
     (step 4). Wave 1 tests this mode only against a fixture repository,
     never against this repository's `main`.

### Chunk 1 — merged 2026-11-19

- Commit ecccbbf, merged `--no-ff` as e89a7f2. Both dialects load:
  - OpenCode: `opencode debug agent game-assistant` shows the
    permissions of 7.4.
  - Claude Code: `claude -p --agent game-assistant --settings …` reports
    its tools as exactly `Read, Write, Edit, Bash, WebFetch, WebSearch`,
    sees no skill, and prints 6.11's opening message word for word.
- The two prompts are byte-identical, and the new
  `tools/tests/test_game_assistant.py` (5 tests) asserts it.
- **Spoiler scan:** clean against capture W1's list plus the 39 fault
  names.
- **History filter:** drops 11 of 11 credential fixture lines and keeps
  7 of 7 ordinary ones.
- **The grid** moved to `references/`; its text is unchanged against the
  owner's file.
- **No model is pinned** in either dialect: the player's tool and
  provider choose it.
- **Deviation 1 (a check method, not behaviour):**
  - `claude agents` no longer lists agent definitions (Claude Code
    2.1.328: it manages background sessions).
  - The plan's "agent definition touched" delta and chunk 1's Done when
    need another check; the headless `claude -p --agent <name>` run is
    the one used.
  - Sent to spec-writer for a plan revision.
- **A failing test on v0.6's side, not caused by this chunk:**
  `test_model.TestV06Templates.test_domain_and_overview_templates`. It
  also fails on `v0.6-w3` at 192f3d9: v0.6's wave 2 gate (f6e14ab) made
  the template's `overview` field required without updating the test.
  - It is v0.6's to fix.
  - Wave 1's gate records it as pre-existing unless `main` has the fix
    by then.
- **Risks noted:**
  - OpenCode's `websearch` tool appears only when the player's setup
    enables it.
  - `read: allow` overrides OpenCode's default "ask" on `.env` files.
  - The history filter drops too much rather than too little ("bypass"
    goes).
  - The `psql*` deny doesn't catch `ssh … 'psql …'` (on the trust line,
    as specified).
- Figures: 1 agent, 41 tool calls, 3.6M tokens in / 38k out, max context
  112k, $1.98 at API prices.
