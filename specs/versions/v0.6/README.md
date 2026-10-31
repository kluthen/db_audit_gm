# v0.6 — the bastion as the players' main activity point

Status: draft. No master spec. Bastion-related items moved in from
v0.5 on 2026-10-31 (D233).

## Goal

In the owner's words, the bastion becomes "the main activity point" (D71):
it publishes the dashboards and monitoring tools, hosts a documentation
website, and provides general-use tooling (`psql`, `pg_dump`, ...).

v0.2 already makes the bastion publish the monitoring web interfaces
(D68); v0.6 turns it from an entry point into the place the players work
from.

## In scope

- **One entry point for every web interface** of the stack: dashboards
  and monitoring tools, published by the bastion as in v0.2, with a
  landing page listing them (proposed).
- **A documentation website** hosted on the bastion. What it carries is
  (proposed): the starter pack (topology, node names, rules and DO NOT
  TAMPER list, the story, the issues) and the player documentation of
  every brick in the topology (`docs/player.md`), rendered as pages.
- **General-use tooling** on the bastion: the PostgreSQL client tools
  (`psql`, `pg_dump` and the rest; the v0.1 bastion already carries the
  PostgreSQL 18 client tools) and other everyday tools, to be chosen.
- **Reports published on the bastion** (proposed, moved here from v0.2):
  reports generated in the stack, such as pgBadger's HTML, readable
  through the bastion's web front rather than copied out with `scp` and
  `sftp`, which is how they leave in v0.2.

## The setup's entry point (D224)

Moved here from v0.5 (D233): the reporting tool settled, the common
Caddy and the homepage proposed (O137).

From v0.4 every game has a web front, its home the starter-pack page.
The owner, ruling on it on 2026-10-30: "i expect a front at every game,
we may have a common caddy to handle multiple front and a homepage
dedicated to the whole setup to dispatch the viewer toward the game
rules(readmes, game informations, data policies, issues), tools and
dashboards available. Keep it simple for now. Expect it to evolve both
with v0.5 and v1.0+ (with the fake aws, which will have its own
entrypoint there)."

None of it built in v0.4:

- **a common Caddy** in front of several games' web fronts (proposed
  here);
- **a homepage for the whole setup**, dispatching the viewer to each
  game's rules (READMEs, game information, data policies, issues), its
  tools and its dashboards (proposed here): the out-of-game side of the
  landing page above;
- **a reporting tool** joining a game's starter-pack page, which v0.4
  builds as a list of elements for it (D221), served by the bastion's web
  front.

After v1.0 the fictional provider's console has its own entry point
there ([roadmap](../README.md#beyond-v10-a-fictional-cloud-provider-d205)).
Open: O135.

## Out of scope

- Any other way in: the bastion stays the only one (bastion-only rule,
  [planes-and-access.md](../../planes-and-access.md)).
- The bastion's tooling as the customer's: it is the players' kit, and
  does not count when judging whether the customer's tooling is
  proportionate (D65, D87).

## Depends on

- v0.2: the bastion publishing the UIs (D68) through its web front (D77),
  which the documentation website and the published reports build on.
- v0.4: the web front in every game, its home the starter-pack page
  (D224), which the reporting tool joins.

## Questions due in this version

- O21: whether the starter documentation, now a website, may itself carry
  faults.
- O32: the language of player-facing material, the website included.
- O135: the setup's entry point (a common Caddy, the setup's homepage,
  a reporting tool on the starter-pack page), moved from v0.5 (D233;
  the Caddy and homepage proposed, O137).
