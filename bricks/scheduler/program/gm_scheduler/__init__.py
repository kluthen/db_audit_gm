"""gm_scheduler: the db_audit_gm scheduler program (v0.3 master spec 7.1).

Runs one rendered schedule (read on standard input, never opened) against
one query repository (`queries.yaml`, `builders/`) and the fixed-time
operations of `jobs.yaml`. Holds no business logic: the SQL is the
scenario's. Interfaces: capture W1 item 7 and W1-y
(specs/versions/v0.3/wave-log.md).
"""

VERSION = "0.1.0"


class ConfigError(Exception):
    """A file the program reads is not valid; the message names the file
    and the place, never a value of the schedule."""
