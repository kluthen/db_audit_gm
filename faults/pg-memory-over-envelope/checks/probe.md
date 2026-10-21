# Probe — pg-memory-over-envelope

Descriptive only in v0.1. As `player` on the database node:

1. `sudo gm-validate` exits 1 with a `RED {SETTING}:` line.
2. `psql -XAt -c 'SHOW {SETTING}'` prints a value above the envelope's
   maximum.

Expected: both, from the start of the game.
