# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived: D1–D54 (v0.1), verbatim in
[archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md);
where each one now lives is in
[archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
Archived IDs keep their meaning and are cited as they are. Numbering
continues from D55; no ID is reused.

- **D55 (2026-10-21, set by spec-writer at the v0.1 archive, as built):
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
