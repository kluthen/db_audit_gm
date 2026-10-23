"""The `sql/postgresql` driver: psycopg 3 from Debian, asynchronous.

Sessions run in autocommit; a transaction is an explicit `BEGIN ISOLATION
LEVEL ...` and `COMMIT`. Parameters are psycopg's `%(name)s`; a statement
without parameters is sent as written (a literal `%` needs no escaping).
No server-side prepared statements (`prepare_threshold=None`), so the
same client works directly or through PgBouncer in any pool mode.
"""

import time

import psycopg

from . import CONNECT_FAILED, CONNECTION_LOST, Driver, DriverError, Result, Session

CONNECT_TIMEOUT = 10
ISOLATION_SQL = {
    "read committed": "BEGIN ISOLATION LEVEL READ COMMITTED",
    "repeatable read": "BEGIN ISOLATION LEVEL REPEATABLE READ",
    "serializable": "BEGIN ISOLATION LEVEL SERIALIZABLE",
}


def _message(exc):
    diag = getattr(exc, "diag", None)
    primary = getattr(diag, "message_primary", None) if diag is not None else None
    text = primary or str(exc) or type(exc).__name__
    return " ".join(text.split())


# libpq reports no SQLSTATE for a refused connection: the server's message
# says which it was (the codes PostgreSQL itself uses for these messages)
CONNECT_MESSAGES = (
    ("too many clients", "53300"),
    ("too many connections for role", "53300"),
    ("remaining connection slots are reserved", "53300"),
    ("password authentication failed", "28P01"),
    ("no pg_hba.conf entry", "28000"),
    ("pg_hba.conf rejects connection", "28000"),
    ("the database system is starting up", "57P03"),
    ("the database system is shutting down", "57P03"),
    ("the database system is in recovery mode", "57P03"),
)


def _connect_code(message):
    for text, code in CONNECT_MESSAGES:
        if text in message:
            return code
    if "does not exist" in message:
        return "28000" if "role" in message else "3D000"
    return CONNECT_FAILED


def _error(exc, conn=None, connect=False):
    code = getattr(exc, "sqlstate", None)
    if not code and connect:
        code = _connect_code(str(exc))
    lost = connect or (conn is not None and (conn.broken or conn.closed))
    if not code and (connect or lost):
        code = CONNECT_FAILED if connect else CONNECTION_LOST
    return DriverError(code, _message(exc), connect=connect, lost=lost)


class PgSession(Session):
    def __init__(self, conn):
        self.conn = conn

    @property
    def broken(self):
        return self.conn.broken or self.conn.closed

    async def _run(self, statement, params):
        start = time.monotonic()
        try:
            async with self.conn.cursor() as cur:
                await cur.execute(statement, params if params else None)
                if cur.description is not None:
                    rows = len(await cur.fetchall())
                else:
                    rows = max(cur.rowcount, 0)
        except psycopg.Error as exc:
            raise _error(exc, self.conn) from None
        except (OSError, ValueError, TypeError) as exc:
            # a parameter psycopg cannot adapt, a socket error
            raise DriverError("-", f"{type(exc).__name__}: {exc}", lost=self.broken) from None
        return Result(rows, time.monotonic() - start)

    async def execute(self, statement, params):
        return await self._run(statement, params)

    async def begin(self, isolation):
        await self._run(ISOLATION_SQL[isolation], None)

    async def commit(self):
        await self._run("COMMIT", None)

    async def rollback(self):
        await self._run("ROLLBACK", None)

    async def close(self):
        try:
            await self.conn.close()
        except (psycopg.Error, OSError):
            pass


class PgDriver(Driver):
    name = "sql/postgresql"

    async def connect(self, connection, password, application_name):
        try:
            conn = await psycopg.AsyncConnection.connect(
                host=connection.host, port=connection.port, dbname=connection.database,
                user=connection.role, password=password, application_name=application_name,
                connect_timeout=CONNECT_TIMEOUT, autocommit=True, prepare_threshold=None)
        except psycopg.Error as exc:
            raise _error(exc, connect=True) from None
        except OSError as exc:
            raise DriverError(CONNECT_FAILED, f"{type(exc).__name__}: {exc}", connect=True, lost=True) from None
        return PgSession(conn)


DRIVER = PgDriver()
