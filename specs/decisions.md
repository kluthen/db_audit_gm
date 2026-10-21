# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived: D1–D54 (v0.1), verbatim in
[archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md);
where each one now lives is in
[archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
Archived IDs keep their meaning and are cited as they are. Numbering
continues from D55; no ID is reused.

- **D55 (2026-10-21, set by spec-writer at the v0.1 archive, as built;
  acknowledged by the owner the same day):
  `/run` is a named volume, not a tmpfs.** A stack file's tmpfs is
  `noexec` and s6-overlay must execute from `/run`, so chunk 2 took the
  build plan's fallback (a): a named volume the entrypoint empties at each
  start (wave-log capture W1-E). Replaces the tmpfs wording of D30 and D41;
  the read-only root stands. Sections 9.1 and 9.2 also list the volumes as
  built (the players' homes, the bastion's host key) and drop a `sudo` log
  target on the bastion, which has no `sudo`. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md) sections
  9.1 and 9.2, [planes-and-access.md](planes-and-access.md) "Node
  hardening".
- **D56 (2026-10-21, owner ruling): Every brick ships GM documentation
  with required sections.** `docs/gm.md` must have nine: purpose,
  placement, configuration, connections, access, footprint, supported
  faults, checks, known limits, so the GM knows what to install where and
  how to configure and wire it; the format skill refuses a brick that
  lacks one. Applies from v0.2; the v0.1 bricks are brought up to it.
  Access and known limits were added by spec-writer to the owner's seven,
  under the ruling's leave to refine. Now in: [formats.md](formats.md)
  "`docs/gm.md` must contain", [versions/v0.2/README.md](versions/v0.2/README.md).
- **D57 (2026-10-21, owner ruling; resolves O56): A documentation update
  to a brick bumps its version.** "Well they need to be updated, so it
  updates the brick version." Applied in dd2c7b4: `postgres` and `bastion`
  0.1.0 → 0.1.1 wherever pinned; for `postgres`, 0.1.1 also covers the
  RG-1 rebuild (D54), which had kept 0.1.0. The 0.1.1 images are
  byte-identical to 0.1.0. Now in: [formats.md](formats.md) "Versions and
  pins", "`docs/gm.md` must contain".
- **D58 (2026-10-21, owner ruling): The bump rule is for bricks only.** Any
  change to a brick bumps its version. A fault or a scenario keeps its
  version when it only re-pins a brick or widens `applies_to`, so the
  catalog's six faults, the two fixture faults and both scenarios are
  right to have kept theirs in dd2c7b4. Other changes to a fault or a
  scenario are not ruled (O59). Now in: [formats.md](formats.md) "Versions
  and pins".
- **D59 (2026-10-21, owner ruling): A fault's `applies_to` is the only
  source of which faults a brick hosts.** The code already reads only that
  (`tools/gm/model.py`); `compatible_faults` leaves `brick.yaml`, its
  template, both bricks and the format skill, and the brick's GM
  documentation lists the faults whose `applies_to` names it. 0.1.1 is not
  yet released (`v0.2-draft` is unmerged), so the removal folds into it
  with no further bump. Now in: [formats.md](formats.md) "`brick.yaml`
  must contain", "`docs/gm.md` must contain", "Versions and pins".
- **D60 (2026-10-21, owner ruling; resolves O59 for faults): Faults never
  bump.** A fault keeps its version whatever changes; git history is the
  record. A scenario's fault pin then names the fault, not a state of it.
  Scenarios' own versions beyond D58 stay open as O61. Now in:
  [formats.md](formats.md) "Versions and pins".
- **D61 (2026-10-21, owner ruling): The fold rule is general.** While a
  brick's new version is unreleased (its branch not merged into `main`),
  further changes fold into it with no extra bump; D59 had applied it to
  0.1.1 only. Now in: [formats.md](formats.md) "Versions and pins".
- **D62 (2026-10-21, owner ruling): A brick's "Supported faults" lists
  catalog faults only.** A fault defined in a scenario's own `faults/`
  folder is the scenario's, not the brick's, and is not listed. Both v0.1
  bricks' `docs/gm.md` already say so. Now in: [formats.md](formats.md)
  "`docs/gm.md` must contain", section 7.
- **D63 (2026-10-21, owner rulings): v0.2's reference, gap and limits.**
  `~/audits/bluebox-lab` is the reference setup; a general per-node health
  view (CPU, RAM, disk, services) is the gap v0.2 fills; monitoring bricks
  may carry faults of their own (ill-configured, missing nodes, starved of
  information); free tools only, a free tool or a script replacing a paid
  one. Now in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring
  bricks (v0.2)", "Example families".
- **D64 (2026-10-21, owner ruling): One brick per need, chosen by
  footprint.** Research may list the top three per need; v0.2 ships about
  one, and footprint on a 2 CPU / 4G / 8G laptop is a main criterion. Now
  in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring bricks
  (v0.2)", [platform.md](platform.md) "Resources and nerfing".
- **D65 (2026-10-21, owner ruling): Optional, proportionate tooling;
  under-tooling is no fault kind.** Monitoring bricks are optional in a
  topology. Under-tooling is an issue the customer raises, a silent
  expectation of the GM, or both; tooling about three times the compute
  and disk of what it watches is overkill, also a finding. Rejected: a
  fault kind `absent`. How an expectation is written: O62. Now in:
  [bricks-and-faults.md](bricks-and-faults.md) "Tooling proportionate to
  the topology".
- **D66 (2026-10-21, owner ruling; resolves O51): Per-node health is a
  daemon script on every node.** Provided at initialisation, it reports the
  node's CPU, RAM, disk and the status of the services the GM names for
  that node, and feeds Prometheus; no cAdvisor, no Docker socket. Other
  open-source health tools (Nagios or others) are for v0.5. Packaging:
  O64. Now in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring
  bricks (v0.2)", [planes-and-access.md](planes-and-access.md) "Rules and
  validators".
- **D67 (2026-10-21, owner ruling; resolves O50): Thin monitoring, no load
  in v0.2.** Dashboards watch a static database; load stays v0.3's. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Out of scope".
- **D68 (2026-10-21, owner ruling; resolves O13): The bastion publishes
  the UIs.** Every monitoring web interface is reached through the
  bastion; no other node publishes a port. The mechanism: O63. Now in:
  [planes-and-access.md](planes-and-access.md) "Bastion only",
  [scenario-lifecycle.md](scenario-lifecycle.md) "Hand-over".
- **D69 (2026-10-21, owner ruling after the tooling research; narrows
  O11): v0.2's tools.** `postgres_exporter`, Prometheus, PostgreSQL logs
  to files with pgBadger as a one-shot job and no log aggregator, Grafana
  with its own alerting; the health script feeds Prometheus. The ruling
  names neither pgwatch nor pgCluu, so neither is a v0.2 brick. Now in:
  [bricks-and-faults.md](bricks-and-faults.md) "Monitoring bricks (v0.2)".
- **D70 (2026-10-21, owner ruling): v0.5 extends the tooling.** Other
  tools and hand-made scripts come in v0.5, beyond v0.2's basic defaults.
  Now in: [versions/v0.5/README.md](versions/v0.5/README.md) "In scope".
- **D71 (2026-10-21, owner ruling): v0.6, the bastion as the players'
  main activity point.** A new version, after v0.5: the bastion publishes
  the dashboards and monitoring tools, hosts a documentation website, and
  provides general-use tooling (`psql`, `pg_dump` and the like). v0.2
  only publishes the monitoring UIs (D68). Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md),
  [versions/README.md](versions/README.md).
