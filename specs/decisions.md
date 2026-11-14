# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived, verbatim, with where each one now lives in its milestone's
README:

- D1–D54 (v0.1):
  [archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md),
  mapped in [archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
- D55–D106 (v0.2):
  [archive/v0.2/decisions-D55-D106.md](archive/v0.2/decisions-D55-D106.md),
  mapped in [archive/v0.2/README.md](archive/v0.2/README.md#where-it-now-lives).
- D108–D112 and D114–D189 (v0.3):
  [archive/v0.3/decisions-D108-D112.md](archive/v0.3/decisions-D108-D112.md)
  and [archive/v0.3/decisions-D114-D189.md](archive/v0.3/decisions-D114-D189.md),
  mapped in [archive/v0.3/README.md](archive/v0.3/README.md#where-it-now-lives).
- D190–D191, D193–D195, D197–D200, D202–D231, D239–D247, D252–D258,
  D281–D284, D305 and D310–D313 (v0.4), one file per range in
  [archive/v0.4/](archive/v0.4/README.md#archived-files), mapped in
  [archive/v0.4/README.md](archive/v0.4/README.md#where-it-now-lives).
- D107, D113, D192, D196, D201, D233–D238, D248–D251, D260–D280,
  D285–D304, D306–D309 and D314–D476 (v0.5), one file per range in
  [archive/v0.5/](archive/v0.5/README.md#archived-files), mapped in
  [archive/v0.5/README.md](archive/v0.5/README.md#where-it-now-lives).

Archived IDs keep their meaning and are cited as they are. Never issued:
D232 and D259 (v0.4); D337, D341, D359, D371, D392, D429, D430 and D470
(reserved during v0.5 and never used); D477–D479 (set aside for v0.5's
close, unused at its archive). Take the next number from `doc-ids`; no ID is
reused.
