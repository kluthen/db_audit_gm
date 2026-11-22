---
name: game-master-setup
description: "GM only, invoked by the game master: designing a db_audit_gm scenario, then setting a game up and deploying it through tools/gmctl, up to and including the hand-over to the players."
---

# Game master: setup and deploy

A workflow of the game master. Its definition,
`.claude/agents/game-master.md`, holds the stance and the rules every
workflow shares; they hold here too.

## Designing a scenario

When the initiator asks for a new scenario, or none of those under
`scenarios/` fits, you design it before any setup, with the
**scenario-format skill**: its templates, its layouts and its
completeness checklists hold every rule; this section says what you
decide. Record what came from the initiator in `brief.md`, as given,
and fill the blanks they left. The design dialogue is all spoilers:
players should not be watching it.

- **A domain** (`domain:`, from `domains/<id>/`): the business the data
  comes from. Copy its files in and adapt them to the scenario's names:
  `schema.sql` then `load.sql` make the data file of the node holding
  the business, its producer fragments the producer's files, its
  classification `data/classification.yaml`. `domain:` itself is
  provenance only. A static scenario has none.
- **Purposes** (`purposes:`, from `purposes/<id>/`): what the customer
  does with the data, each a job or a chain of jobs whose runs the
  checks judge. Map each part the purpose declares onto the scenario's
  nodes and locations, then **copy its `material/` in**, adapted to the
  scenario's names: each part's fragments into that node's
  `queries.yaml`, `scripts/`, `jobs.yaml` and `schedule.yaml`, a
  database part's `data.sql` into that node's data file. A fault
  instance whose fault lists `applies_to.purposes` needs each of them.
  In a composed scenario (`domains:`, below) a scheduler or `api` node's
  fragments go into `compose/<node>/`, never `nodes/<node>/`; a
  purpose's `ddl:` files and its `history` are run by `load-data` from
  the catalogue, never copied.
- **Domains, composed** (`domains:`, v0.5 master spec 8.4, 8.5, 15;
  capture W5 item 5): a customer whose business comes from a core and
  its parts is composed by `gmctl compose`, never copied by hand. The
  format skill's "Composition" holds the rules; you take these steps,
  in this order, and their files are the record that makes the
  composition reproducible:
  1. **`domains:`** in `scenario.yaml`: the core's entry with its
     `variant:`, each part after its core, each entry's `at:` (a
     `node/database`, or a part's map from each of its databases).
  2. **The scenario layer, `compose/<node>/`**: each purpose's material
     for a scheduler or `api` node, and each scheduler node's
     `intensity` and `timeline`; a third party that belongs to no domain
     (cold storage, `partners/coldstore/`) its stub's folders into
     `compose/partners-api/` and `compose/partners-backend/`, its
     `data.sql` (then `planted.sql`) into `partners-db`'s data file
     after `partners/shared/partners-db/data.sql`, as
     `partners/README.md` says (a domain's own partners come through
     `gmctl compose`); a fault's seed change on a node `gmctl compose`
     writes, as the one edit its `seed_changes[].change` states and its
     `material` holds (a diff, a function, a line; never a whole file).
     A seed change on any other node (a database node, a standby, the
     bastion) goes into `nodes/<node>/`, as before.
  3. **`tools/gmctl compose <dir>`** writes each composed node's
     `nodes/<node>/` (never edited by hand: change a layer and run it
     again) and prints every override and resolution. On a conflict
     between two sources of one layer it stops, naming the unit and
     both sources: resolve it in `merge.yaml` (`node`, `file`, `entry`,
     `take` a source or write a `value`, a `reason`) and run it again,
     until it merges. A resolution meeting no conflict is refused as
     stale: remove it.
  4. **The composition record, `composition.yaml`**, which you write:
     `domains` (as `domains:`, in its order, `lands_with` for a domain
     declaring it), `keys` (each part's core ranges and functions, by
     the names the core's `docs/gm.md` gives them), `scale` (`checked:
     true` once the parts' combined scale is checked against the core
     variant's, with a one-line `note`), `order` (the load order: a part
     after its core, a derivation's domain after its `after`), `derive`
     (the sanctioned derivation steps, only for a domain declaring one)
     and, in a fixture only, `left_out` (a game composes every
     producer). Never write `coherence:`: `load-data` writes it at
     setup ([Setup](#setup), step 11).

  Then, as for any scenario, the register, the network overview and the
  document, in Setup step 2's order.
- **Third parties** (`third_parties:`, v0.5 master spec 10; access
  model 10): the customer's partners, on the three shared `no-access`
  nodes, played by no one: their stubs answer by themselves, and you
  never speak for one. Write each one's entry of `player/partners.md` as
  a company knows its partner (its name and what it does for the
  business, the contract, the interface, the customer's credentials
  with it), with an in-world **support contact that never answers
  during the game**; never its internals (no node name, no schedule, no
  code). No answer key's *fix* names a partner's node; a check may read a
  partner's side as evidence, never judge it.
- **Where each job runs**, the placement guideline (v0.4 master spec
  8.7): a database node's cron (`pg_cron` or the crontab) runs only
  light, well-scheduled work (partitions, small clean-ups, a small
  materialized view, a set-based procedure off-peak); heavy or row-by-row
  transformation goes to a transformer node sized for it; heavy work on
  the source instance is the worst placement. A scenario departs from it
  only to plant a fault, which its answer key names.
- **Several instances**: each `postgres` node is an instance of its own
  (about 256 MB reserved), with its own seed files and data file. A
  second instance is monitored by a `postgres-exporter` node of its own
  (about 42 MB reserved, scraped by the `prometheus` node), or left
  unscraped by design, which the answer key then states as a tooling
  expectation naming the instance (master spec 13.4).
- **Another party's system**: a database node the story gives another
  party (the first v0.4 scenario's `reporting`, the agency's) is
  report-only by the story and the answer key alone, since `postgres`
  has no report-only write policy: the story names whose node it is,
  and the issues on it ask for a report or a proposal (master spec
  16.5). A scheduler node keeps the write policy its brick enforces.
- **Governance and the data policy** (`governance:`): per class
  (`personal`, `customer-linked`, `internal`), its locations, its
  readers and its outbound flows. Add `separation: instance` to a class
  **only where the story's policy demands an instance of its own** (its
  own audit logging, TLS, superuser, backups or failure; master spec
  11.4): G1 then finds a breach in every other database of a node
  holding one of the class's locations, the maintenance database
  `postgres` aside (spec D253). Then **write the data policy**,
  `player/data-policy.md`, from `governance:`: the company speaking to
  its staff, in the story's voice; what it holds, the classes in plain
  words, where each may live, who may read it, what may leave and to
  whom. It states `governance:` faithfully (a policy carrying a fault is
  not allowed in v0.4), may add rules no check verifies (encryption at
  rest, retention) without marking which are audited, speaks of
  application and staff accounts only, and names no hidden fault. The
  bastion maps it as its `data-policy.md` seed file exactly when the
  scenario has `governance:`; the players read it in their home and on
  the starter-pack page.
- **The jobs the players may move**: the starter pack's `README.md`
  names every job the players may edit (each job of a `jobs.yaml` they
  may change: its node and its name) and says that moving a job's time,
  then reloading its runner, is how they verify a fix to it at its next
  run, never running it by hand (master spec 12.8). It names no
  database-node job unless the story does: a job nobody lists is a
  finding.
- **A fault that may exhaust its node's memory** (`needs_unshared_host`,
  the out-of-memory incident): the designed placement puts its node on
  the first host, the manager, and `fit` refuses it on a host declared
  `shared` (master spec 13.3). Measure its window for this scenario as
  the fault's `gm.md` says before it is played.

Then generate `README.md` with the scenario-document skill, and set it
up.

## Setup

The initiator (a teacher, or a student playing alone) runs the setup. The
setup dialogue and the commands' output are full of spoilers (fault ids,
injection script names): players should not be watching it.

**First, the time and who plays** (v0.6 master spec 9.1, 9.2). Before
step 1, ask the initiator, in one message and **once** for the whole
setup:

<!-- player -->
> When should the game be ready for its players (a date and
> an hour, in UTC), or how much time do you have until then? And will
> you play the game yourself, or set it up for others?<!-- /player -->

They may also ask for a quick or an extended game. Never ask whether
they play a second time. An answer that leaves it open ("maybe", "I
might join") counts as **may play**. From then on:

- **An initiator who may play** is a player for everything the GM's
  files say about what players are told: every word of the setup dialogue to
  them follows [the stance](../../agents/game-master.md#the-stance)'s "Never told" rule. A game
  that ages is a **quick game** or an **extended game**, named by its
  duration only; never its mode, its mechanics or its limits. Tell them
  once, before the commands start:

  <!-- player -->
  > The setup's commands and their output are my working
  > notes and full of spoilers. If you will play, look away until I say
  > the game is ready.<!-- /player -->

- **An initiator who will not play** (a teacher, the owner) may be told
  the mode, real aging or fake aging, and its limits (master spec 9.10,
  the scenario document's "Fake aging" section).

The initiator never picks faults or a mode's mechanics (master spec
9.1): the selection and the tail are yours, and so is the mode, their
wish for a quick or an extended game taken into account.

1. **The scenario.** List the scenario folders under `scenarios/` (those
   holding a `scenario.yaml`), showing id, title, session length,
   `designed_for` capacity and, for a scenario that ages, when it could
   be ready: to an initiator who may play, the quick game's and the
   extended game's durations only (step 3; one only, when the scenario
   offers one), as in
   "<!-- player -->quick game: ready in about an hour and a half;
   extended game: ready in about 16 hours"<!-- /player -->; to one who
   will not play, its aging minimum (`aging.minimum`) and whether a fake
   game of it is possible (step 3). Have the initiator choose one; confirm
   it when there is only one. A new one is designed first
   ([Designing a scenario](#designing-a-scenario)).
2. **Is it complete?** In this order: the format, the register, the
   document. Check it with the scenario-format skill's
   completeness checklists. If anything is missing, list every missing
   item and stop: you do not deploy an incomplete scenario (`gmctl fit`
   refuses one too, listing what is missing). With the format, for a
   scenario listing `domains:`, run `tools/gmctl compose <dir> --check`:
   exit 0 (`up to date`) says every composed node's files are what the
   layers, `merge.yaml` and `composition.yaml` give; a `differs:` line
   or a refusal is a design step left undone: go back to
   [Designing a scenario](#designing-a-scenario), compose again, and
   start this step over. Then, for a scenario with a
   data register (every scenario listing `domains:`, a `fixture-` one
   exempt; one with `governance.register`), check it is current and
   generate or regenerate it with the data-register skill when it is
   missing or stale (the loader refuses it: "stale register: regenerate
   with the data-register skill"): the true register
   `gm/data-register.yaml`, the handout `player/data-register.md` and each
   register fault's `register_diff:` (master spec 13.3). Then, for a
   scenario with a network overview (every scenario listing `domains:`,
   a `fixture-` one exempt; v0.6 master spec 8.4), check it is current
   and generate or regenerate it with the network-overview skill when it
   is missing or stale (the loader refuses it: "stale overview:
   regenerate with the network-overview skill"), after the register,
   which it digests: the true overview `gm/network-overview.yaml`, the
   handout `player/network-overview.md` and each overview fault's
   `overview_diff:`. The order is format, register, overview, document.
   Then check that
   `README.md` exists and matches the authoritative files; if not,
   regenerate it with the scenario-document skill, which reads the
   register's and the overview's outputs: a restarted GM grounds itself
   on it, and reads the true register and the true overview with it,
   never showing or quoting either during the game. The
   three monitoring bricks are *fixable* only in v0.2 (a known limit,
   spec D108): never offer a *report-only* write policy for a
   `prometheus`, `postgres-exporter` or `grafana` node; the loader refuses
   one.
3. **Feasibility and the mode** (a game that ages only; skip it for a
   static game, which has no aging and so no mode). The time the
   initiator gave (the hand-over: a date and a whole hour, which you
   state in UTC) is the time available. Judge, for this scenario and
   this game, which mode it allows, then propose the default:
   **real aging** when the time available covers the scenario's declared
   aging and the setup (below); **fake aging** when it doesn't, or when
   the initiator asked for a quick game (master spec 9.1). Your judgment
   of whether a game's aging is affordable stands; fake aging is one more
   option before declining.

   **Real aging** (an extended game):
   - the load must run, from T0 (step 13), for at least the scenario's
     aging minimum before the hand-over. Add the setup before T0 (image
     builds, `deploy`, the data load: count tens of minutes, more for a
     first build) and a margin: lost time beyond thirty minutes moves the
     earliest hand-over later ([The aging](#the-aging)). The faults
     planted during the aging are covered by the aging minimum: the
     loader checks it against them;
   - the playground's hosts must stay up from deployment, through the
     aging, to the end of the game (always-on hosts: a laptop that sleeps
     or leaves is no host for a game that ages);
   - when the scenario's traffic differs by weekday (its scenario
     document says which days the story needs), choose the start so the
     aged hours are the ones the story needs.

   **Fake aging** (a quick game), master spec 9.3 to 9.6:
   - **An eligible selection.** Read the scenario document's "Fake
     aging" section (`<dir>/README.md`, heading `## Fake aging`, generated
     by the scenario-document skill; a document without it is stale for a
     fake game: regenerate it, and with no such section a fake game of the
     scenario is not offered): each
     instance's support (`supported`, `tail-only`, `real-only`) with its
     reason, its tail needs and `plant_in`, the tail the full selection
     needs, the instances refused with their reasons, and the setup's
     measured time from the deploy to the restart. Every instance of
     the game must be eligible (9.5): you compose the selection, or
     replace an instance, through
     [Designing a scenario](#designing-a-scenario), never asking the
     initiator. **An instance a handout names** (an issue of
     `player/issues.md`, or any handout) that fake aging can't make is
     never left to `render`'s refusal, which would hand the players an
     issue with no cause: play a variant designed without that instance
     and its issue, play the game real, or decline (spec D542; the
     campaign's f10 and its issue 6 go together, 9.8). `render`'s
     refusal is the safety net for an instance no handout names: the
     game runs without it, and it is out of the game
     ([Evaluation](../game-master-evaluation/SKILL.md#evaluation)). If no acceptable selection fits,
     decline the scenario or propose another.
   - **The tail** is the longest of one hour, each selected fault's
     `tail_minimum`, the lead each `tail_covers` instant needs and the
     span each instance planted in the tail needs (9.6). For the full
     selection the section states it; `render` prints the tail of the
     selection the game has (step 7).
   - **The time it takes**: the setup's measured time from the deploy
     to the restart (the section's figure, the fill's duration within
     it; image builds before it count apart, as for a real game), then
     the tail. So H, the planned hand-over, is the first whole UTC hour
     at or after now plus that time plus a margin, and the restart (the
     **anchor**, H minus the tail) must fall after the fill can have
     ended: an anchor passed before `fill` starts means a new game. A
     quick game's stated duration (master spec 9.2, spec D544) is that
     setup time plus the selection's tail.
   - the playground's hosts stay up from the deployment to the end of
     the game, the tail included (always-on hosts are not needed for
     long: the game is ready in about the setup plus the tail).

   **Offer the mode.** To an initiator who may play, by duration only,
   the default first, then the other where it fits:

   <!-- player -->
   > This scenario can be a quick game, ready in about an
   > hour and a half (at 14:00 UTC), or an extended game, ready in about
   > 16 hours (tomorrow at 06:00 UTC). With the time you have, I propose
   > the quick game. Which would you like?<!-- /player -->

   (with this game's figures: the quick game's from the setup time and
   the tail above, the extended game's from the aging minimum and the
   setup). To one who will not play, name the mode, say what it is, and
   give the limits that touch this scenario's evidence (the section's
   limits; master spec 9.10), and any instance refused or replaced. A
   question about how a quick game differs, from an initiator who may
   play, is answered by duration only:
   "<!-- player -->Both are played the same way; the quick one is ready
   sooner."<!-- /player -->

   When neither mode fits, say so, with the figures, and decline the
   scenario, or propose another that fits: one with a shorter aging
   minimum, one whose quick game fits, or a static one, which has no
   aging. Never offer to shorten a real aging: it is real time. When
   it fits, agree the **planned hand-over** with the initiator: a whole
   UTC hour, in the future, at or after the earliest hand-over the
   timing above gives; `render` takes it (step 7) and shifts the
   schedules so the designed hand-over hour falls on it. Say the start
   time that follows, or, to an initiator who may play,
   "<!-- player -->The game will be ready at 14:00 UTC."<!-- /player -->
4. **The playground.** Ask where the Docker engines are and what they
   may use (a game lasts at most four hours, after its aging): one host,
   the local engine or an SSH endpoint `ssh://user@host`, or **several
   hosts**, each by its swarm node name, one of them the swarm's manager
   (where `gmctl` runs, the images are built and the ports are
   published) and the others reached by an SSH endpoint over the hosts'
   private link. Endpoints are reached with the initiator's own SSH
   configuration and keys; never store a key. On several hosts each
   remote endpoint must answer **without an SSH agent and without a
   terminal** (a timer's run reaches it so; `deploy` probes it and
   refuses otherwise): a host alias in the SSH configuration with a key
   of its own, which the initiator sets up. For each host, ask for the
   capacity to declare (CPU, memory, disk), memory at what the host has
   **available**, not its total. You may propose CPU and memory from
   `docker info --format '{{.NCPU}} {{.MemTotal}}'` (with `--host
   <endpoint>` for an SSH endpoint) and the scenario's `designed_for`;
   disk is the initiator's call. Ask too whether each host is **shared**,
   carrying other applications that must stay up (the VPS carries
   filetstudio.com): declare it so (`--host <name>,shared,...`, step 6),
   and no node that may exhaust its memory is placed on it (master spec
   13.3). On several hosts, map each host the
   scenario's `designed_for` names onto a declared host (several may
   share one); a node that publishes ports (the bastion) must land on the
   manager. A game that ages also needs the manager's user systemd
   manager to run with no session open (lingering), since its host
   timers plant faults and run the early check there: check `loginctl
   show-user "$USER" --property=Linger` reads `Linger=yes`, and ask the
   initiator to enable it if not. Choose the playground slug (`laptop`,
   `classroom`, `duo`; lowercase) and say it: it names `local/<pg>/`.

   **The overlay's range** (several hosts only). A game whose nodes span
   several hosts gets its network's /24 from a private range that you
   choose for the execution environment (spec D183): `10.20.0.0/16` is
   proposed by default. Keep it unless you know it is taken there (a
   network or route of a placed host, or of the swarm, inside it; `docker
   network ls` and `docker network inspect` on each host show theirs);
   otherwise choose another IPv4 range inside 10/8, 172.16/12 or
   192.168/16, from /8 to /24, that overlaps none of them, declare it
   with `fit --overlay-range` (step 6) and tell the initiator which and
   why. `deploy` refuses rather than overlap, naming what is taken: see
   step 10.
5. **Images.** Each brick's image must exist on the target engine (on
   several hosts, the manager) before `fit`: `fit` reads every image's
   size there, and refuses a missing one (as `deploy` does: deployment
   never pulls an image). Check with `docker image ls` (`docker -H
   <endpoint> image ls` for an SSH endpoint). Build a missing one, the
   new v0.3 bricks' (`scheduler`, `pgbouncer`) included, with the
   **Build** line of the pinned brick's `docs/gm.md` (section
   "Placement"), `docker build -t <image> bricks/<id>`, run from the
   repository root against the target engine (`docker -H <endpoint>
   build ...` for an SSH endpoint). The images are large (Grafana's is
   about 0.9G) and count against the declared disk. On several hosts you
   build on the manager only: `deploy` copies each other host the images
   of its nodes.
6. **Capacity check and local implementation.** Every engine must
   answer: `fit` cannot run offline. On one host:

   ```sh
   tools/gmctl fit <dir> --playground <pg> [--endpoint ssh://user@host] --cpu N --memory SIZE --disk SIZE
   ```

   On several hosts, or on one host that is shared (`--host` once per
   host, `manager` on exactly one, `shared` on each shared host, no
   `endpoint=` for the local engine; `--map` once per designed host;
   `--overlay-range` only when you chose another range than the
   default):

   ```sh
   tools/gmctl fit <dir> --playground <pg> --host <name>,manager,cpu=N,memory=SIZE,disk=SIZE --host <name>,shared,endpoint=ssh://<alias>,cpu=N,memory=SIZE,disk=SIZE --map <designed host>=<host> --map <designed host>=<host> [--overlay-range <cidr>]
   ```

   Exit 0: it fits; note the game id it prints. The disk line counts the
   images with the volumes' reservations and, for a game that ages, the
   growth over the aging plus a four-hour game (`disk: reservations <r>
   + images <i> + growth <g> (<n>h) + headroom <h> = <total> of
   <disk>`), each shared layer once; on several hosts, per host. The
   last line is the hand-over snapshot's: when its copies do not fit,
   the game still fits but **will have no snapshot, and a restart starts
   from nothing** ([Restart](../game-master-restart/SKILL.md#restart)): tell the initiator, who may
   declare more disk and `fit` again. Exit 1 with "does not fit": tell
   the initiator the capacity is insufficient, with the figures it
   prints, and do not deploy. Exit 1 otherwise: a refusal, which you
   report: an incomplete scenario, a game already on this playground, an
   image missing on the engine (it prints the build command: run it as
   in step 5, then `fit` again), the engine not reachable (start it or
   correct `--endpoint`, then `fit` again), a declaration it cannot
   place the scenario on (no or two managers, a designed host unmapped,
   a host the swarm does not list, a node publishing ports off the
   manager: correct the declaration), a **node refused on a shared
   host** (it carries a fault that needs an unshared host: the line
   names the mapping to change, `--map <designed host>=<host>`, onto a
   host that is not shared: map it so, then `fit` again; never drop the
   `shared` mark to make it fit), a playground whose only hosts are
   shared for such a scenario (declare a host that is not shared, or
   choose another scenario), or an `--overlay-range` it refuses (not
   IPv4, wider than /8, narrower than /24, host bits set, outside the
   private ranges). These write nothing.
7. **Render.** In a game that ages, with the planned hand-over of step 3
   (a whole UTC hour, in the future):

   ```sh
   tools/gmctl render <dir> --playground <pg> --handover 2026-10-27T14:00Z
   ```

   It prints `planned hand-over <instant>, shift <+N>, customer's time
   zone UTC+N (Etc/GMT-N)`, and fills that zone into the story and the
   starter pack. A `warning:` line means the planned hand-over is earlier
   than the earliest hand-over the game could have if the load started
   now: go back to step 3 with the initiator (another hand-over, or
   another scenario) and render again; do not deploy a game that cannot
   age in time. You may render again, with another `--handover`, until
   `deploy`; after it, a new hand-over hour means a new game (stop, then
   start).

   In a **fake game**, add `--aging fake` (W2 item 7):

   ```sh
   tools/gmctl render <dir> --playground <pg> --handover 2026-10-27T14:00Z --aging fake
   ```

   It prints, besides, the virtual T0, the anchor and the tail, and each
   instance it refuses with its reason (its `aging.fake.reason`, or `not
   assessed: no aging.fake`), left out of every verb. A refused instance
   a handout names means your selection was wrong (step 3): render again
   after replacing it, or play the game real (render without `--aging
   fake`, which removes the restart record). It writes the restart
   record, appends the restart's line to the bastion's `story.md` (`The
   servers were restarted for maintenance on <date> at <HH:MM> UTC; older
   logs were archived.`, the planned anchor's), and sets the monitoring's
   nodes (Prometheus, Grafana, the exporters, pgwatch) at zero replicas
   until the restart. It refuses an anchor already passed: choose a later
   H. In a static game, render without `--handover`: no planned
   hand-over is needed and nothing is shifted:

   ```sh
   tools/gmctl render <dir> --playground <pg>
   ```

   With a `prometheus` node, it also prints one node-health config per
   node (`mounted/node-health/<node>.conf`); parameter faults are planted
   here.
8. **Brick checks.** For each brick the scenario uses whose `brick.yaml`
   has a `companion` entry, do what `companion.when` says:
   - `prometheus`: at every deployment, the node-health script is mounted
     into every node its `node_health` map lists. `render` and `deploy`
     do the mounting (read-only configs, with each node's own config):
     check that `render` printed a config for every node the map lists,
     except a node a parameter fault leaves out (the answer key says
     which). The script's own checks run after deployment (step 10).
   - `grafana`: its companion files are the Grafana node's seed files,
     copied into `nodes/<grafana>/` when the scenario was written; the
     completeness check (step 2) covers them. Nothing is mounted.
   - `postgres`, `bastion`, `postgres-exporter`, `scheduler`,
     `pgbouncer`: no companion.
9. **Swarm.** `gmctl deploy` refuses when the engine is not part of a
   swarm, or is a worker. On one host, ask the initiator whether you
   should run `docker swarm init` there (step 10 with `--init-swarm`) or
   whether they will do it; on a worker, they must point you at a
   manager. On several hosts the swarm is the initiator's: `deploy`
   refuses `--init-swarm`, and a host that is not `Ready` and `active`
   (it names `docker node update --availability active <host>`, which the
   initiator runs; you never change a node's availability or the swarm's
   membership).
10. **Deploy and health checks.**

    ```sh
    tools/gmctl deploy <dir> --playground <pg> [--init-swarm] [--timeout SECONDS] [--overlay-range <cidr>]
    ```

    It creates the credentials, configs and secrets (the mounted
    node-health material with them), deploys the stack and waits for every
    health check (300 s by default). It prints the bastion's published
    ports: SSH's (container port 22) and the web front's (container port
    8080), in every game. On several hosts it first lists the
    hosts, copies each other host the images of its nodes (`images on
    <host>: <n> copied ...`) and prints the overlay's subnet and the
    range it came from.

    **When the range is taken.** On several hosts `deploy` refuses, with
    nothing created, when no /24 of the range in force is free, or when
    the game's recorded subnet now overlaps a network; it names the
    networks taken and their hosts. Choose another private range that
    overlaps none of them (as in step 4), tell the initiator which, and
    either run `deploy` again with `--overlay-range <cidr>` (this run
    only) or, before deployment, declare it for the playground with
    `tools/gmctl fit <dir> --playground <pg> --overlay-range <cidr>` (a
    re-fit given only that option keeps the declared hosts and mapping,
    and the game id) and go on from step 7, rendering with the same
    `--handover`.

    In a **fake game** the monitoring's nodes are deployed at zero and
    left out of the health wait, and once the nodes are healthy the
    **hold** turns off each primary `postgres` node's `pg_cron`
    launches, archiving and cron daemon (`hold:` in `state.yaml`) until
    the restart. Confirm the wiring below without the monitoring (no
    scrape target, exporter, Grafana or pgwatch to read yet): you confirm
    the monitoring's after the restart
    ([Fake mode: the steps](#fake-mode-the-steps)).

    Then **confirm the wiring** as each brick's `docs/gm.md` says ("After
    deployment", and `prometheus`'s "Companion checks"), with the reads of
    [Operating the nodes and the monitoring tools](../../agents/game-master.md#operating-the-nodes-and-the-monitoring-tools):
    every Prometheus scrape target up, the node-health endpoints included;
    the exporter connected (`pg_up 1`); Grafana's data source healthy and
    its dashboards and alert rules provisioned; the web front's
    starter-pack page answering with the tools password, and each route
    through it; each scheduler node
    `idle` (its load is not started yet); a pooler's console answering.
    Targets can take up to
    two minutes to come up: read again before concluding. A reading that a
    planted fault explains (the answer key says which: a node left out of
    a map, a target missing) is expected. Anything else is a setup problem:
    report it to the initiator, who decides whether to stop the setup
    ([Setup failures](#setup-failures)).
11. **Data load.** `tools/gmctl load-data <dir> --playground <pg>`. Each
    database node's data file, with the customer's time zone and its
    offset as `psql` variables; then each customer login role's password
    from its secret (every login role a data file creates, unless it
    sets its own password, and every role a schedule or a node's
    `crontab_roles` names); each user
    mapping's password from its remote role's secret; the GM check role's
    read policy on `pg_cron`'s tables and its mapping-roles function,
    where they apply; its `CONNECT` on every database of every instance.
    Last, on a database node holding `pg_cron`, it waits up to 60 s for
    the `pg_cron` launcher (not connected: the step fails and the game is
    torn down, as for any failed setup step), has the server log switch
    files, and removes the launcher's start-up failures, and only them,
    from the closed files (spec D258). A `warning:` line means the log
    did not switch files and was left as it was: the players will see
    those lines; tell the initiator. Where it switched, the players see
    a second log file starting at `load-data`.

    **With `domains:` (v0.5), the coherence check.** After the data
    files, `load-data` runs the composed load (each domain in
    `composition.yaml`'s `order`, the purposes' DDL (2b), the GM check
    role's read policy on the tables with row security (2c), the
    sanctioned derivations, the purposes' histories), then **the
    coherence check**: each composed domain's coherence queries, which
    must return no row. Its line reads `coherence check: pass (<n>
    passed, 0 failed, <k> skipped; recorded in composition.yaml)`; a
    skipped check (one reading a domain not composed) names its reason.
    The result is recorded in `composition.yaml`'s `coherence:` key
    (`load-data` rewrites that key only: the register's digest leaves it
    out, so the register stays current) and in `state.yaml`. **A failure
    is a design error, never a fault**: the setup stops (`the coherence
    check failed on <n> check(s): a design error, never a fault ...`,
    each failing check with its rows; the game is torn down and recorded
    `failed`, as any failed setup step). Run the confirming teardown
    ([Setup failures](#setup-failures)), then fix the cause at design:
    the composition (a part's `keys`, a range, a function, the `scale`)
    or a domain, composed again when a layer changed, the register and
    the document regenerated when their inputs changed; then fit a new
    game and load again. You never hand an incoherence over as something
    to find, and never plant one: the faults come after the check.
12. **State faults planted.** `tools/gmctl inject <dir> --playground <pg>`.
    In a game that ages, only the faults due at T0 are planted here (in
    a fake game, at the virtual T0, on its clock). The
    stage is now `injected`. A static game goes to
    [Hand-over](#hand-over); a real game to step 13; a fake game to
    [Fake mode: the steps](#fake-mode-the-steps), then step 13. A `state`
    fault's script written `{script, on: <parameter>}` runs on the node
    that parameter names, not the instance's (its line names the node it
    ran on; a node the game lacks is refused before anything runs). A
    `topology` fault (an option a node does not choose, spec D459) runs
    nothing: the topology planted it at render, and `inject` lists it so.
13. **Start the load** (a game that ages; `start-load` refuses a static
    game, which has no load to start). Right after `inject` (in a fake
    game, right after `clean-restart`, below):

    ```sh
    tools/gmctl start-load <dir> --playground <pg>
    ```

    It starts every scheduler at once and records **T0**, the moment it
    began, and the stage `load-started`, once every scheduler reads
    running. It schedules the early check on a host timer and prints its
    time, then, for every fault instance planted during the aging, the
    command that plants it at its planned instant: **run each one**, as
    printed (`--at now` when that instant has already passed):

    ```sh
    tools/gmctl inject <dir> --playground <pg> --at 2026-10-27T08:00Z --instance <id>
    ```

    Each schedules that one instance's planting on a host timer on the
    manager (`the planting of <id> is scheduled at ...`); nothing else is
    replayed. Then `tools/gmctl status <dir> --playground <pg>` shows the
    aging: T0, the earliest hand-over, each planting with its timer and
    the early check's. Tell the initiator the earliest hand-over and the
    early check's time, and go to [The aging](#the-aging).

    An **incident fault** (its sealed check an incident check, master
    spec 12.7: the out-of-memory incident,
    `purpose-heavy-job-on-database-node`) is planted this way too: what
    `inject --at` plants is its trigger (a one-off backfill request), and
    the incident itself happens for real, once, at its job's next run on
    its own schedule (master spec 16.3). Nothing makes it happen sooner.

    A scheduler that does not start (`FAILED: <reason>` on its line, exit
    1) tears nothing down: the stage stays `injected` and no T0 is
    recorded. Read its logs (`tools/gmctl logs <dir> --playground <pg>
    --node <scheduler> --tail 50`) and tell the initiator. A cause outside
    the game (a host down, an engine not answering) is fixed with the
    initiator, then `start-load` runs again (it restarts every scheduler
    under one new T0). A cause in the scenario (a schedule or a repository
    that does not load) cannot be fixed in this game: stop it ([Setup
    failures](#setup-failures)), fix the scenario, and set it up again.

The initiator, or anyone, may ask to stop at any point of the setup: see
[Setup failures](#setup-failures).

### Fake mode: the steps

A fake game's setup, in master spec 9.4's order (captures W2 items 7,
11 and 12, W3 items 1, 2, 6 and 11). Steps 1 to 4 are the setup above:

1. **`render --aging fake`** (step 7), H agreed at step 3.
2. **`deploy`** (step 10): the monitoring at zero, the hold on.
3. **`load-data`** (step 11), on the virtual T0's clock and unseen: no
   statement log, no pgaudit, no `pg_stat_statements`.
4. **`inject`** (step 12): the faults due at the virtual T0, on its
   clock.
5. **The fill**:

   ```sh
   tools/gmctl fill <dir> --playground <pg>
   ```

   One virtual clock on every scheduler node, from the virtual T0 to the
   anchor, the load run as fast as the databases allow, the real-clock
   actors and the statistics off; it pauses at each `state` fault due in
   that span and plants it on the pause's instant (`plantings.<id>`, `by:
   fill`). Minutes, the scenario document's setup time; `state.yaml`'s
   `fill` records it (`started_at`, `ended_at`, `outcome`, `reason`,
   `quiet`). Exit 0 `ok` (an end restore that failed is listed in
   `fill.reason`, left for `clean-restart`). Exit 1 refused (the anchor
   passed, a key without its service time, a fill already recorded:
   nothing done) or **failed**: tear the game down and set it up again
   ([Setup failures](#setup-failures)); a fill is never resumed.
6. **The wait, then the maintenance restart.** Wait out what is left
   to the planned anchor (`gmctl status`: `anchor ... (planned)`), then:

   ```sh
   tools/gmctl clean-restart <dir> --playground <pg>
   ```

   It is refused before the anchor (the fill's rows run up to it):
   nothing done, run it again once the anchor has come. In order, it
   restores what the fill left, pads the WAL and checkpoints, resets the
   statement and shared statistics, stops every service, removes the
   fill's PostgreSQL, pooler and cron logs, dates the data files, and
   starts **every service of the game at one instant**, the monitoring
   with them: that instant is `restart.at` in the record, and the tail
   counts from it. Exit 1 failed (recorded with its reason): tear the
   game down and set it up again. Then **confirm the monitoring's
   wiring**, as step 10 says for the rest: every Prometheus scrape
   target up, the exporters connected, Grafana's data source healthy,
   pgwatch where the scenario has it.
7. **`start-load`** (step 13), right after the restart:

   ```sh
   tools/gmctl start-load <dir> --playground <pg>
   ```

   T0 is recorded as the virtual T0 and `load.anchor` as `restart.at`.
   It schedules the history import and the early check on host timers
   and prints, for each instance planted in the tail (the fill planted
   the rest; `plant_in: tail` faults among them), the `inject --at`
   command: run each one, as in step 13.
8. **The history import** runs by its host timer,
   `dbagm-<game_id>_history`, about 12 minutes after the restart: it
   reads the tail's first 10 minutes from Prometheus, writes the past
   from the virtual T0 to the restart, imports it and checks the seam.
   You don't run it: read its result in `gmctl status` (`history import:
   <result> at <at>, seam <seam>`, then the reason when there is one) and
   in the record's `history`. A failed import is recorded, never a
   teardown; a retry by hand, before the hand-over, is the `history`
   row of the [command reference](gmctl.md). A game with no `prometheus`
   node has no import.
9. **The early check** by its host timer, as in a real game: halfway
   through the tail and no later than an hour before the earliest
   hand-over, never before the import (right after it in a tail under
   two hours). It checks what a real game's does, the fill's plantings
   included, and reads the import's result (`history import: ok, seam
   ok`; anything else fails it). Then the hand-over check, the snapshot
   and the hand-over, as in a real game, from the **earliest hand-over**:
   `restart.at` plus the tail ([The aging](#the-aging)).

Tell an initiator who will not play the restart's instant, the import's
time, the early check's and the earliest hand-over. Tell one who may
play only <!-- player -->"The game will be ready at 14:00 UTC."<!-- /player -->
(H, or the earliest hand-over when the restart came late and it falls
after H), and nothing of the steps.

### Setup failures

- **Before deployment** (`fit`, `render`, a brick check, a missing image,
  an engine not reachable, no swarm): nothing is deployed. Report what failed and why; fix the
  cause with the initiator and run the step again.
- **During `deploy`, `load-data` or `inject`** (including a health check
  that never passes): `gmctl` itself tears down what the game deployed and
  records stage `failed` with the reason (its output ends "Recorded in
  state.yaml"). Report the step and the reason to the initiator. Then run
  `tools/gmctl teardown <dir> --playground <pg>` to confirm nothing
  carrying the game's label is left (it keeps the failure record and
  also records the teardown), and
  `tools/gmctl status <dir> --playground <pg>` to show what is recorded.
  For a node that did not come up, read its logs:
  `tools/gmctl logs <dir> --playground <pg> --node <node> --tail 50`
  (for a PostgreSQL node, sshd and the server's start-up only; once the
  server has started, its log is in files: see
  [Operating the nodes and the monitoring tools](../../agents/game-master.md#operating-the-nodes-and-the-monitoring-tools)).
- **Trying again.** After a failed `deploy`, fix the cause and run
  `deploy` again: it is allowed from that failure. After a failed
  `load-data` or `inject`, once the confirming teardown above has run,
  fit a new game on the same playground (`fit` gives it a new game id)
  and go on from step 6 (in a game that ages, render with a planned
  hand-over still far enough ahead: step 3); `fit` refuses until that
  teardown is recorded. The same works after a failed `deploy`, instead
  of retrying it.
- **During a fake game's `fill` or `clean-restart`**: a failure is
  recorded with its reason and leaves the game deployed. Report the
  step and the reason to the initiator (to one who may play, only that
  the setup failed and is started again, never the step's name), then
  tear it down with the reason (`tools/gmctl teardown <dir> --playground
  <pg> --reason "set up again: <why>"`), fit a new game and go on from
  step 3, with the time now left: a fill is never resumed and a restart
  never repeated. An anchor passed before `fill` could start is the
  same.
- **From `start-load` on, nothing tears the game down.** A scheduler that
  does not start, a planting that fails or is missed, a failed early
  check, a failed hand-over check or snapshot: each is recorded in its own
  record, leaves the game running and its stage unchanged, and heads
  `gmctl status` (step 13, [The aging](#the-aging),
  [Hand-over](#hand-over)). Only the setup before T0 (`render` to
  `inject`) tears down on failure, as in v0.2, since nothing has aged
  yet. A static game has no T0: a failure in `deploy`, `load-data` or
  `inject` tears it down, as above.
- **A stop request during setup or the aging** is obeyed at once, without asking for
  confirmation. At whatever setup stage the game is, run `tools/gmctl
  teardown <dir> --playground <pg> --reason "stopped on request"` (add
  who asked and why, if said, on the same line); it removes nothing when
  nothing was deployed. Then report to the initiator the stage reached
  and that the setup was stopped on request. `state.yaml` records the
  teardown with the stage reached and the reason, which `gmctl status`
  prints (`torn down: at ..., from stage <stage>: <reason>`). If a
  `gmctl` command was interrupted while running, it records `failed`
  with "stopped on request" itself: run the same `teardown --reason` to
  confirm and record it, as above.

## The aging

A game that ages, from T0 (`load-started`) to the hand-over. The stack
runs unattended on its hosts, which stay up; this session may end. Between
sessions you act only through the setup actions you scheduled: the host
timers on the manager plant each fault due during the aging (`inject --at
now --instance <id>`, run by its timer) and run the early check. A timer
whose run was due while the host was down runs when it is back. Nobody is
notified of anything: the results are in the local implementation and
head `gmctl status`.

**In a fake game this is the tail** (v0.6 master spec 9.3, 9.4): from
the restart (`restart.at`) to the hand-over, in real time, everything
running. What follows holds for it, with these differences:

- `status`'s `aging:` lines read `aging: fake` with the record's
  instants; T0 is the virtual T0, the tail counts from `restart.at`, and
  the **earliest hand-over is `restart.at` plus the tail** (moved later
  by lost time beyond thirty minutes, as below). The early check runs
  halfway through the tail, never before the import. The outages count
  from the restart, never from the virtual T0.
- The plantings due in the tail are made by their host timers, as in a
  real game; the earlier ones were made by the fill
  (`plantings.<id>`, `by: fill`) and are never re-planted.
- **The history import** runs by its timer about 12 minutes after the
  restart ([Fake mode: the steps](#fake-mode-the-steps), step 8). The
  early check fails on anything but `history import: ok, seam ok` (or
  `none (no Prometheus node)`); the hand-over check prints the same line
  and never fails on it. A failed import, or a failed seam, leaves the
  forged past missing or visibly wrong in Prometheus and Grafana, which
  a player would notice. A failed import: retry it by hand before the
  hand-over (the `history` row of the [command reference](gmctl.md)).
  If it fails again, or the seam failed with the import `ok` (don't
  rerun it then: it never imports again, a rerun only prints the
  recorded result), tell the initiator and offer to set the game up
  again, or, if they choose, hand it over as it is. To an initiator who may play, say
  only <!-- player -->"A check of the game's preparation failed: the
  monitoring's history is incomplete. I can set the game up again, ready
  at 16:00 UTC, or hand it over as it is."<!-- /player --> (with your
  figures).
- **Setting the game up again** is a new game, as below; its mode is
  chosen again at step 3 with the time now left.

- **Resuming a session during the aging**: run `tools/gmctl status <dir>
  --playground <pg>` first, and tell the initiator of every failure and
  outage it heads with, before anything else (see
  [Start](../../agents/game-master.md#start-is-a-game-in-progress)). Then the aging's progress:
  `aging: T0 ...; ran <time> ... of the <minimum> minimum`, the lost time,
  `earliest hand-over: <instant> (reached | in <time> | provisional,
  waiting for the planting of <id>)`, the planned hand-over with the
  shift and the customer's time zone, each planting and the early check.
  Advise the initiator to come back after the early check (its time is in
  `status`) when they can: its result says early whether the game will be
  playable.
- **The early check** runs halfway through the aging minimum, or later
  once every fixed-time operation due before the earliest hand-over has
  run once, and no later than an hour before the earliest hand-over. It
  checks that every fault planted so far reads present, every scheduler
  runs its keys, every node is healthy, and reads the outages so far. A
  fault due later is listed, not a failure; a "too soon to tell" reading
  is recorded. You may run it again yourself, after acting on a failure:

  ```sh
  tools/gmctl check <dir> --playground <pg> --early-check
  ```

  Exit 0 passed, 1 failed (`FAILED early check ...` heads `status` until
  a hand-over check passes), 2 refused.
- **An incident fault's check reads `error` (exit 2) until the incident
  is in the log** (spec D256): once its trigger is planted and before
  its job's run has been killed and the server has recovered ("no kill
  since the request", "a kill without its recovery yet"), and on a
  failed planting ("not planted", no request). An early check that runs
  between its planting and its job's run fails on that line: read the
  reason and the job's time (the rendered crontab, in UTC); while the run
  is still ahead it is no failure to act on: tell the initiator so, and
  that the hand-over check must find the incident. After the run, the
  same reading means the incident did not happen: see the hand-over
  check ([Hand-over](#hand-over)).
- **A failed, missed or unscheduled planting** (`FAILED|MISSED|UNSCHEDULED
  planting: ...`, with the command): re-plant that one instance now, with
  the command `status` gives,

  ```sh
  tools/gmctl inject <dir> --playground <pg> --at now --instance <id>
  ```

  when the instance's own aging minimum, counted from now, still ends
  before the time the initiator has: the earliest hand-over is recomputed
  from the actual planting. When it does not, tell the initiator: the
  hand-over moves later, or the game is set up again (below). A planting
  that fails again is recorded, nothing torn down: read the reason it
  prints and the node's logs before trying once more. A fault due at T0
  is never re-planted this way (`inject --at` refuses it). **Nor is an
  incident fault, ever, within the aging** (`inject --at` does not refuse
  it: you do not run it): its job runs nightly, so a trigger planted
  again would be taken only at the next night's run, past the hand-over
  (master spec 16.3, access model 7). Its failed planting, like an
  incident that did not happen, means the game is set up again: tell the
  initiator, and look at why first (the fault's `gm.md`, "When it did not
  happen").
- **A scheduler not running or a node unhealthy** (the early check's
  failures): read the node's logs (`tools/gmctl logs <dir> --playground
  <pg> --node <node> --tail 50`) and tell the initiator. Restarting a node
  is not a `gmctl` operation: a host to bring back up is the initiator's;
  a scheduler restarted with its host resumes by itself, from the current
  time (missed fixed-time runs are not replayed). When it does not come
  back, the game is set up again.
- **Outages.** A minute is in outage when a node of the game was not
  running or a scheduler wrote no per-minute summary (a host down or
  rebooted, the hosts' link cut, a crashed node). `gmctl` reads them at
  the early check, at each hand-over check and on `status`
  (`OUTAGES: <n> min lost in <k> period(s)`, one line per period with its
  causes; `at least` when a node's task history may have been pruned;
  `OUTAGES NOT READ` when a node could not be reached: read again once
  it is back). The **lost time** is the outage minutes in all.
  - **Up to thirty minutes** in all is recorded and does not move the
    earliest hand-over: a real system has blips.
  - **Beyond thirty minutes**, the excess moves the earliest hand-over
    later, and **you judge at hand-over** whether the evidence the issues
    rely on survived: compare the outage periods with each fault
    instance's planting and its own minimum (`status`, the answer key's
    `evidence`), and with the fixed-time operations the evidence relies
    on (the rendered `local/<pg>/rendered/<scheduler>/jobs.yaml`, in UTC).
    A fault whose evidence fell in the gap, or a fixed-time run missed
    that the evidence needs, means it did not. Then either hand over, the
    story telling the gap as an incident ([Hand-over](#hand-over)), or
    set the game up again. Say which, and why, to the initiator.
- **The earliest hand-over** is the later of T0 plus the aging minimum
  and each fault's own minimum since its actual planting, moved later by
  the lost time beyond thirty minutes. While a planting is awaited it is
  provisional, and not reached. When it falls after the planned
  hand-over, or the initiator wants a later hand-over, the rendered
  schedule stays: what was planted or changed before the planned
  hand-over is older, never younger, but the game window then sees
  another part of the designed day unless the move is by whole days.
  Tell the initiator so.
- **No early hand-over.** Asked to hand over before the earliest
  hand-over, or while it is provisional, refuse, and say when the game
  can be handed over (the `earliest hand-over` line). `snapshot` and
  `status --set handed-over` refuse it too.
- **Setting the game up again** (before hand-over) is a stop then a
  start, asked or agreed by the initiator: a new game, its aging
  starting from zero. Tear it down with the reason (`tools/gmctl teardown
  <dir> --playground <pg> --reason "set up again: <why>"`), then fit a new
  game on the playground and go on from setup step 3 (the feasibility,
  with the time now left). Never use `restart` for it: a restart is the
  players' operation, after hand-over. Re-planning the hand-over hour
  after `deploy` is setting up again too.
- **No load control.** Nobody pauses, speeds up or triggers the load
  during the aging either, to catch up lost time or for any other
  reason (see [the stance](../../agents/game-master.md#the-stance)).

## Hand-over

### Before the hand-over: the checks and the snapshot

A game that ages is handed over at or after its earliest hand-over
(`status`: `earliest hand-over: ... (reached)`); a static game at stage
`injected`, once its faults are planted (its faults' own aging minima are
not counted). Before giving the players anything, in this order:

1. **The hand-over check**, every planted fault included:

   ```sh
   tools/gmctl check <dir> --playground <pg> --handover-check
   ```

   It judges every planted fault by its sealed check (it passes when the
   fault reads present), every node healthy and, in a game that ages,
   every scheduler running its keys and every fixed-time operation due
   run once, a missed or failed planting, and reads the outages (never a
   failure on their own: you judge them). Exit 0 passed. Exit 3: it
   failed only on "too soon to tell" readings: wait the longest remaining
   window it names, then run it again (the load runs on; you never
   trigger it). Exit 1 failed: **do not hand over.** Re-plant a fault
   whose planting failed or was missed (`tools/gmctl inject <dir>
   --playground <pg> --at now --instance <id>`, as in
   [The aging](#the-aging)) when its own aging minimum can still be
   reached in the time the initiator has, then wait the new earliest
   hand-over and run the check again. Otherwise (a fault not reading
   present, a scheduler or node down that does not come back, a planting
   that cannot age in time), tell the initiator and offer to set the game
   up again: a stop, then a start ([The aging](#the-aging)). **A failed
   incident** is one of these: an incident fault's line reading `error`
   after its job's run (the run completed, never ran, or its trigger is
   unreadable; or its trigger's planting failed) means the incident did
   not happen. It is never re-planted within the aging: look at why with
   the fault's `gm.md` ("When it did not happen": the window against the
   node's limit, the entry's time, the cron daemon, the password file),
   tell the initiator, and offer to set the game up again. Exit 2:
   refused (another stage); run `gmctl status`. In a game that ages, the
   check must have run at or after the earliest hand-over.
2. **The outages**, a game that ages: with more than thirty minutes lost
   in all, make the judgement of [The aging](#the-aging) now: hand over
   with the gap told as an incident, or set the game up again.
3. **The hand-over snapshot**:

   ```sh
   tools/gmctl snapshot <dir> --playground <pg>
   ```

   It copies every volume of the game by its brick's method, each on its
   own host. Prometheus and Grafana, where the scenario has them, are
   **stopped briefly** while their volumes are copied (a few seconds),
   then started again (`<node>: <services> stopped <instant>, started
   again <instant>`): their history shows a scrape gap there, which you
   tell the players as a maintenance window. Exit 0: `taken`, or `not
   fitting` (`fit` said the copies do not fit: nothing copied, and a
   restart will start from nothing). Exit 1: refused (before the earliest
   hand-over, or while a planting is awaited: wait), or failed (its copies
   removed, nothing torn down: run it again). It is taken right before
   the starter pack is handed over (taking it again then replaces the
   copies): once handed over it is refused, as it would capture the
   players' changes.

### What you give the players

Then give the players, in the session:

- **the bastion's address and port**: the host of the SSH endpoint, or,
  for the local engine, the address of this machine that the players can
  reach (ask the initiator if unsure); on several hosts, the manager's,
  where the bastion publishes its ports; the port is the bastion's
  `published_ports[*].published` whose `target` is 22 in
  `local/<pg>/implementation.yaml` (also printed by `deploy`, "container
  port 22"). As a command: `ssh -p <port> player@<address>`;
- **the password**: the content of `local/<pg>/secrets/player_password`.
  It is per game and cannot be changed during the game;
- **the web front**, in every game (spec D224; see
  [What you may do](../../agents/game-master.md#what-you-may-do)):
  - its address and port: the bastion's address, and the bastion's
    `published_ports[*].published` whose `target` is 8080 in
    `local/<pg>/implementation.yaml` (also printed by `deploy`, "container
    port 8080"). Its home, `http://<address>:<port>/`, is the
    **starter-pack page**: the starter pack as handed over, easier to read
    than in a terminal. With a web interface, the page links to each
    route, and each has its own address, `http://<address>:<port>/<route>/`
    for each key of the bastion's `web_routes` (for example `/prometheus/`
    and `/grafana/`). Plain HTTP;
  - the **tools password**, always, with the bastion password: the
    content of `local/<pg>/secrets/tools_password`, with the user name
    `player`. It is per game and cannot be changed during the game. With
    a Grafana node, Grafana asks for its own login as well: user `admin`,
    the same tools password, which makes them Grafana administrators;
- **the starter pack**: in their home on the bastion (`~/README.md`,
  `~/story.md`, `~/issues.md`, and `~/data-policy.md`, the company's data
  policy, when the scenario has `governance:`), and on the web front's
  page; `README.md` first. Its `README.md` names the jobs, if any, whose
  time they may move to verify a fix;
- **the DO NOT TAMPER rule**: what the starter pack marks DO NOT TAMPER
  must stay as it is. With a Grafana node, say it in the hand-over too:
  do not change Grafana's users or the administrator's password; your
  checks log in as `admin` with the tools password, and repeated failed
  logins lock that account for a few minutes. It is not enforced: it is
  theirs to keep;
- **the issues, with their expected resolutions**: each issue of
  `scenario.yaml` as the players' `issues.md` states it, its id, its
  complaint and whether a *report*, a *proposal* or a *fix* is expected.
  Never its `covers`, never a fault id;
- **the session length** (`session_length_minutes`) and the time it ends,
  in UTC, and that every time in the game is UTC (the nodes, PostgreSQL's
  logs, Grafana). With monitoring, in a real or a static game, also
  "<!-- player -->The monitoring's history starts when the system was
  installed: the dashboards' first 10 to 15 minutes are
  thin."<!-- /player --> In a fake game, say nothing of where the
  history starts;
- **in a fake game, the maintenance restart**, the in-world fact the
  story states (its line, `restart.story_line` in the record), with the
  restart's time:
  "<!-- player -->The servers were restarted for maintenance today at
  11:00 UTC; older logs were archived."<!-- /player --> (today, or its
  date). Nothing more: no reason for it, and no word of how the game
  was made ([the stance](../../agents/game-master.md#the-stance), "Never told");
- **in a game that ages, the customer's time zone**: the zone `status`
  prints (`customer's time zone UTC+N (Etc/GMT-N)`), as the starter pack
  states it: the story's times of day are the customer's, every clock in
  the system is UTC. A static game has none: say nothing of one;
- **the maintenance window**, when the snapshot stopped Prometheus or
  Grafana: a short maintenance at hand-over (the time `snapshot` printed,
  in UTC), which leaves a gap of a few seconds in their history;
- **an incident**, when you handed over a game that lost more than
  thirty minutes ([The aging](#the-aging)): the system had an outage
  from ... to ... UTC (the outage periods, in the story's words: the
  customer's system was down, or its applications stopped), so its
  history has a gap there. Say when, not why it matters;
- **in a game that ages, that the system is live**: its applications
  keep running throughout the game, on their own schedule; nobody pauses,
  speeds up or triggers them, and nobody runs a job by hand. Where the
  starter pack says they may, they move a job's time and watch its next
  run;
- **the rules of the game with you**: the only things they can do with
  you are hand in their report (pasted here, in `~/report.md` on the
  bastion, or by talking it through), ask to stop, and ask for a restart
  of the whole game, which loses their changes ([Restart](../game-master-restart/SKILL.md#restart)); you
  answer no other question until their final answer.

Then record the stage:

```sh
tools/gmctl status <dir> --playground <pg> --set handed-over
```

It refuses (exit 1, nothing changed, saying which condition) unless, in a
game that ages, the earliest hand-over is reached, the last hand-over
check passed and ran at or after it, and the snapshot is taken or
recorded as not fitting; in a static game, unless the last hand-over check
passed and the snapshot is taken or recorded as not fitting. The aging
ends here: the load runs on through the game, untouched.

**Recommended, not enforced:** end this setup session here, and take the
report in a fresh session (the GM started by name again, `tools/play gm`:
it picks up the game at
`handed-over`). The setup dialogue stays out of the players' sight, and
the session pick-up path is exercised. Say so to the initiator.
