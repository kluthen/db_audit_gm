"""The driver interface (master spec 7.1, "Drivers"; D137; v0.5 master
spec 7.2, the HTTP driver).

A driver opens sessions to a target. A SQL session runs one statement with
its parameters, begins, commits and rolls back a transaction, and closes;
an HTTP session sends one request (`request`, a repository.CallPlan). Each
reports its latency, and every failure is a DriverError carrying an error
code: an SQLSTATE for SQL drivers (`field` "sqlstate"), the answer's three
digits, `timeout` or `refused` for HTTP (`field` "status"). v0.3 shipped
`sql/postgresql`, v0.5 adds `http`; a new target adds a module here and a
name in DRIVERS, the repository format unchanged.
"""

import asyncio
import importlib
import threading

# connection error codes when the driver reports none (SQLSTATE class 08)
CONNECT_FAILED = "08001"
CONNECTION_LOST = "08006"


class DriverError(Exception):
    def __init__(self, code, message, connect=False, lost=False, field="sqlstate"):
        super().__init__(message)
        self.code = code or "-"
        self.message = message
        self.connect = connect       # the session could not be opened
        self.lost = lost             # the session is no longer usable
        self.field = field           # the log's field for the code: sqlstate (SQL), status (HTTP)


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

    async def request(self, call):
        raise NotImplementedError

    async def close(self):
        raise NotImplementedError


class Driver:
    name = None

    async def connect(self, connection, secret, application_name):
        """`connection`: a schedule.Connection; `secret`: its role's password
        (SQL) or its credential (HTTP, None for a public endpoint). Returns a
        Session."""
        raise NotImplementedError


DRIVERS = {"sql/postgresql": "gm_scheduler.drivers.postgresql", "http": "gm_scheduler.drivers.http"}


def get_driver(name):
    return importlib.import_module(DRIVERS[name]).DRIVER


def in_thread(fn, *args, name="gm-script"):
    """Runs `fn(*args)` in a daemon thread; returns an asyncio future of its
    result (or its exception). A daemon: a program stopping mid-call does
    not wait for it."""
    loop = asyncio.get_running_loop()
    future = loop.create_future()

    def settle(result, exc):
        if future.cancelled():
            return
        if exc is not None:
            future.set_exception(exc)
        else:
            future.set_result(result)

    def target():
        try:
            result, exc = fn(*args), None
        except BaseException as e:  # handed to the awaiting task, which logs it
            result, exc = None, e
        try:
            loop.call_soon_threadsafe(settle, result, exc)
        except RuntimeError:
            pass  # the loop is gone: the program is stopping and nobody awaits the call

    threading.Thread(target=target, name=name, daemon=True).start()
    return future
