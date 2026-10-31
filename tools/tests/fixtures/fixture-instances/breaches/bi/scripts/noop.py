"""Transformer script of the copy's bi node (tools/tests/smoke-governance.sh,
v0.4 chunk 12): reads and writes nothing; never run (the copy's load never
starts)."""


def run(conns, options, log):
    """Does nothing; returns the rows written, none."""
    log("noop")
    return 0
