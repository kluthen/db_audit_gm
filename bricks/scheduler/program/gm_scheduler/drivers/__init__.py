"""The driver interface (master spec 7.1, "Drivers"; D137).

A driver opens sessions to a target. A session runs one statement with
its parameters, begins, commits and rolls back a transaction, and closes;
each statement reports its latency, and every failure is a DriverError
carrying an error code (an SQLSTATE for SQL drivers). v0.3 ships
`sql/postgresql`; a new target adds a module here and a name in DRIVERS,
the repository format unchanged.
"""

import importlib

# connection error codes when the driver reports none (SQLSTATE class 08)
CONNECT_FAILED = "08001"
CONNECTION_LOST = "08006"


class DriverError(Exception):
    def __init__(self, code, message, connect=False, lost=False):
        super().__init__(message)
        self.code = code or "-"
        self.message = message
        self.connect = connect       # the session could not be opened
        self.lost = lost             # the session is no longer usable


class Result:
    def __init__(self, rows, latency):
        self.rows, self.latency = rows, latency     # rows affected or returned; seconds


class Session:
    """What a driver's session offers; every method raises DriverError."""

    broken = False

    async def execute(self, statement, params):
        raise NotImplementedError

    async def begin(self, isolation):
        raise NotImplementedError

    async def commit(self):
        raise NotImplementedError

    async def rollback(self):
        raise NotImplementedError

    async def close(self):
        raise NotImplementedError


class Driver:
    name = None

    async def connect(self, connection, password, application_name):
        """`connection`: a schedule.Connection. Returns a Session."""
        raise NotImplementedError


DRIVERS = {"sql/postgresql": "gm_scheduler.drivers.postgresql"}


def get_driver(name):
    return importlib.import_module(DRIVERS[name]).DRIVER
