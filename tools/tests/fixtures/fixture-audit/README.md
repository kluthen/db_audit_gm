# DO NOT READ IF YOU ARE A PLAYER OR A STUDENT

This document describes the fixture scenario's planted fault and its
answer. It is a test fixture (`tools/tests/fixtures/fixture-audit`), not a
game: one bastion and one PostgreSQL 18 node.

## Fault

- `f1` (hidden): `random_page_cost` left at 4.0 on SSD-backed storage.
