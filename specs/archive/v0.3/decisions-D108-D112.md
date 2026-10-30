> **Archived 2026-10-30.** v0.3 closed (released at its release gate on 2026-10-30, merged into `main` as cba7be3); entries D108–D112, verbatim: rulings left live at the v0.2 close and since applied or settled. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; no link here needed repair.

- **D108 (2026-10-21, owner ruling after the v0.2 wave 3 gate): The
  monitoring bricks are fixable only in v0.2**, a known limit: nothing
  passes a node's write policy to its container, so the report-only
  Grafana gap cannot arise. Report-only monitoring nodes are later work
  (proposed: v0.3). Now in: master spec 7, 7.4, 10, 16;
  [versions/v0.2/access-model.md](versions/v0.2/access-model.md) 6, 7,
  11, 12; [versions/v0.3/README.md](versions/v0.3/README.md).
- **D109 (2026-10-22, owner ruling at the v0.2 release close; clears
  G11): The tooling and the feedback are judged good.** The owner, on
  fernway's feedback (release gate item 12): "the feedback is good".
  Now in: [versions/v0.2/README.md](versions/v0.2/README.md) "Release
  notes".
- **D110 (2026-10-22, owner ruling at the v0.2 release close): The GM may
  restart a game from the next version, on explicit confirmation only.**
  A restart tears down and rebuilds the whole stack. The owner: "next
  version is okay, annotate that it need an explicit confirmation (we
  can't have a passing comment just restart the game, as it's highly
  breaking change)". v0.2 keeps no restarts; its restart refusal check
  went untested at the release gate, a known gap. Mechanics open: O81.
  Now in: [versions/v0.3/README.md](versions/v0.3/README.md) "In scope",
  [gm-stance.md](gm-stance.md), [versions/v0.2/README.md](versions/v0.2/README.md)
  "Known issues".
- **D111 (2026-10-22, owner ruling at the v0.2 release close; RG-4):
  `bookshop-new-server`'s seed meets the `postgres` 0.2.0 requirement.**
  Its seed `postgresql.conf` gains the brick's logging and preload
  settings (e7c2c3e), and the GM skill says where the server log is in
  each case (412f5a2); scenario version and answer key unchanged (D75).
  Now in: master spec 11.2, [versions/v0.2/README.md](versions/v0.2/README.md)
  "Release notes".
- **D112 (2026-10-22, owner ruling at the v0.2 release close): RG-2 and
  RG-3 are accepted as known issues.** A player's `sed -i` leaves a
  config owned by `player`; `gmctl status` labels the tools password
  "handed over" in a game without a web front. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Known issues".
