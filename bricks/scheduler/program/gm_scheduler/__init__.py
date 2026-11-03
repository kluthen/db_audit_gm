"""gm_scheduler: the db_audit_gm scheduler program (v0.3 master spec 7.1).

Runs one rendered schedule (read on standard input, never opened) against
one query repository (`queries.yaml`, `builders/`, `scripts/`) and the
fixed-time operations of `jobs.yaml`. Holds no business logic: the SQL and
the transformer scripts are the scenario's. Interfaces: capture W1 item 7
and W1-y (specs/versions/v0.3/wave-log.md), as extended by v0.4's W1 item
7 and W1-y (specs/versions/v0.4/wave-log.md).
"""

VERSION = "0.3.0"


class ConfigError(Exception):
    """A file the program reads is not valid; the message names the file
    and the place, never a value of the schedule."""
