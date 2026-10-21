# v0.6 — the bastion as the players' main activity point

Status: draft. No master spec.

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

## Out of scope

- Any other way in: the bastion stays the only one (bastion-only rule,
  [planes-and-access.md](../../planes-and-access.md)).
- The bastion's tooling as the customer's: it is the players' kit, and
  does not count when judging whether the customer's tooling is
  proportionate (D65) (proposed).

## Depends on

- v0.2: the bastion publishing the UIs (D68) and how it does so (O63); if
  v0.2 settles on SSH forwarding, v0.6 still needs a web front for the
  documentation website.

## Questions due in this version

- O63: how the bastion publishes, if v0.2 leaves anything open.
- O21: whether the starter documentation, now a website, may itself carry
  faults.
- O32: the language of player-facing material, the website included.
