# fixture-compose

Fixture of the unit tests (`tools/tests/test_compose.py`, v0.5 chunk 2):
not a game and not a complete scenario. `catalog/` is a test catalog root
with a core, `fx-core` (variant `big`), and its part `fx-part`;
`scenario/` names them in `domains:`, with the scenario layer
`compose/<node>/` and the composition record. The base composes without a
conflict: the tests change one input at a time (a colliding part, a
`merge.yaml`, an `api` node's endpoints).
